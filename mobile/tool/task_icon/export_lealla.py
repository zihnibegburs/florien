#!/usr/bin/env python3
"""Export and quantize the pinned LEALLA-small model for mobile inference.

The word embedding table dominates LEALLA-small's size. ONNX Runtime's dynamic
quantizer intentionally leaves Gather weights in FP32, so this script applies
row-wise symmetric INT8 quantization to that table and inserts only standard
ONNX nodes to dequantize the selected rows. Remaining MatMul/Gemm weights are
then quantized by ONNX Runtime.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil

import numpy as np
import onnx
from onnx import TensorProto, helper, numpy_helper
from onnxruntime import InferenceSession, SessionOptions
from onnxruntime.quantization import QuantType, quantize_dynamic
import torch
from transformers import AutoModel, AutoTokenizer


MODEL_ID = "setu4993/LEALLA-small"
MODEL_REVISION = "cf79e3610690ff9d66b8695bc6d298f10973b845"
MAX_SEQUENCE_LENGTH = 48


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while chunk := source.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def export_fp32(output: Path, cache_dir: Path) -> tuple[AutoTokenizer, AutoModel]:
    tokenizer = AutoTokenizer.from_pretrained(
        MODEL_ID,
        revision=MODEL_REVISION,
        cache_dir=cache_dir,
        use_fast=True,
    )
    model = AutoModel.from_pretrained(
        MODEL_ID,
        revision=MODEL_REVISION,
        cache_dir=cache_dir,
    ).eval()
    encoded = tokenizer(
        "Take the car for service",
        return_tensors="pt",
        max_length=MAX_SEQUENCE_LENGTH,
        truncation=True,
        padding="max_length",
    )
    input_names = ["input_ids", "attention_mask", "token_type_ids"]
    inputs = tuple(
        encoded.get(name, torch.zeros_like(encoded["input_ids"]))
        for name in input_names
    )
    dynamic_axes = {
        name: {0: "batch", 1: "sequence"} for name in input_names
    }
    dynamic_axes.update(
        {
            "last_hidden_state": {0: "batch", 1: "sequence"},
            "sentence_embedding": {0: "batch"},
        }
    )
    class ExportWrapper(torch.nn.Module):
        def __init__(self, inner: AutoModel) -> None:
            super().__init__()
            self.inner = inner

        def forward(
            self,
            input_ids: torch.Tensor,
            attention_mask: torch.Tensor,
            token_type_ids: torch.Tensor,
        ) -> tuple[torch.Tensor, torch.Tensor]:
            result = self.inner(
                input_ids=input_ids,
                attention_mask=attention_mask,
                token_type_ids=token_type_ids,
                use_cache=False,
            )
            return result.last_hidden_state, result.pooler_output

    wrapper = ExportWrapper(model).eval()
    with torch.inference_mode():
        torch.onnx.export(
            wrapper,
            inputs,
            output,
            input_names=input_names,
            output_names=["last_hidden_state", "sentence_embedding"],
            dynamic_axes=dynamic_axes,
            opset_version=17,
            do_constant_folding=True,
            dynamo=False,
        )
    return tokenizer, model


def quantize_word_embeddings(source: Path, output: Path) -> None:
    graph = onnx.load(source, load_external_data=True)
    initializer_by_name = {item.name: item for item in graph.graph.initializer}
    gather_index = None
    embedding_name = None
    for index, node in enumerate(graph.graph.node):
        if node.op_type != "Gather" or not node.input:
            continue
        initializer = initializer_by_name.get(node.input[0])
        if initializer is None:
            continue
        shape = tuple(initializer.dims)
        if len(shape) == 2 and shape[0] > 100_000 and shape[1] == 128:
            gather_index = index
            embedding_name = initializer.name
            break
    if gather_index is None or embedding_name is None:
        raise RuntimeError("Could not locate LEALLA word embedding Gather node")

    initializer = initializer_by_name[embedding_name]
    weights = numpy_helper.to_array(initializer).astype(np.float32)
    row_scale = np.max(np.abs(weights), axis=1, keepdims=True) / 127.0
    row_scale[row_scale == 0] = 1.0
    quantized = np.clip(np.rint(weights / row_scale), -127, 127).astype(np.int8)
    scales = row_scale[:, 0].astype(np.float32)

    old_node = graph.graph.node[gather_index]
    token_ids = old_node.input[1]
    original_output = old_node.output[0]
    quantized_name = f"{embedding_name}.rowwise_int8"
    scales_name = f"{embedding_name}.rowwise_scale"
    axes_name = f"{embedding_name}.scale_axes"
    gathered_int8 = f"{original_output}.int8"
    gathered_float = f"{original_output}.float"
    gathered_scale = f"{original_output}.scale"
    expanded_scale = f"{original_output}.scale_expanded"

    replacement = [
        helper.make_node(
            "Gather",
            [quantized_name, token_ids],
            [gathered_int8],
            axis=0,
            name=f"{old_node.name}.rowwise_int8",
        ),
        helper.make_node(
            "Cast",
            [gathered_int8],
            [gathered_float],
            to=TensorProto.FLOAT,
            name=f"{old_node.name}.cast",
        ),
        helper.make_node(
            "Gather",
            [scales_name, token_ids],
            [gathered_scale],
            axis=0,
            name=f"{old_node.name}.scale_gather",
        ),
        helper.make_node(
            "Unsqueeze",
            [gathered_scale, axes_name],
            [expanded_scale],
            name=f"{old_node.name}.scale_unsqueeze",
        ),
        helper.make_node(
            "Mul",
            [gathered_float, expanded_scale],
            [original_output],
            name=f"{old_node.name}.dequantize",
        ),
    ]

    graph.graph.node.remove(old_node)
    for offset, node in enumerate(replacement):
        graph.graph.node.insert(gather_index + offset, node)
    graph.graph.initializer.remove(initializer)
    graph.graph.initializer.extend(
        [
            numpy_helper.from_array(quantized, quantized_name),
            numpy_helper.from_array(scales, scales_name),
            numpy_helper.from_array(np.asarray([2], dtype=np.int64), axes_name),
        ]
    )
    onnx.checker.check_model(graph)
    onnx.save_model(graph, output)


def verify_model(path: Path, tokenizer: AutoTokenizer, model: AutoModel) -> float:
    texts = [
        "Take the car for service",
        "Arabayı servise götür",
        "母にプレゼントを買う",
        "Zahnarzttermin vereinbaren",
    ]
    encoded = tokenizer(
        texts,
        return_tensors="np",
        max_length=MAX_SEQUENCE_LENGTH,
        truncation=True,
        padding="max_length",
    )
    inputs = {
        "input_ids": encoded["input_ids"].astype(np.int64),
        "attention_mask": encoded["attention_mask"].astype(np.int64),
        "token_type_ids": encoded.get(
            "token_type_ids", np.zeros_like(encoded["input_ids"])
        ).astype(np.int64),
    }
    options = SessionOptions()
    options.intra_op_num_threads = 1
    session = InferenceSession(path, sess_options=options, providers=["CPUExecutionProvider"])
    actual = session.run(["sentence_embedding"], inputs)[0]
    with torch.inference_mode():
        torch_inputs = {name: torch.from_numpy(value) for name, value in inputs.items()}
        expected = model(**torch_inputs).pooler_output.detach().cpu().numpy()
    actual /= np.linalg.norm(actual, axis=1, keepdims=True)
    expected /= np.linalg.norm(expected, axis=1, keepdims=True)
    cosine = np.sum(actual * expected, axis=1)
    minimum = float(np.min(cosine))
    if minimum < 0.985:
        raise RuntimeError(f"Quantized model validation failed: min cosine={minimum:.6f}")
    return minimum


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, default=Path("assets/task_icons"))
    parser.add_argument("--work-dir", type=Path, default=Path(".dart_tool/task_icon_model"))
    args = parser.parse_args()
    output_dir = args.output_dir.resolve()
    work_dir = args.work_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    work_dir.mkdir(parents=True, exist_ok=True)

    fp32 = work_dir / "lealla_small_fp32.onnx"
    embedding_int8 = work_dir / "lealla_small_embedding_int8.onnx"
    final_model = output_dir / "lealla_small_int8.onnx"
    tokenizer, model = export_fp32(fp32, work_dir / "hf_cache")
    quantize_word_embeddings(fp32, embedding_int8)
    quantize_dynamic(
        embedding_int8,
        final_model,
        weight_type=QuantType.QInt8,
        per_channel=True,
        reduce_range=False,
        extra_options={"MatMulConstBOnly": True},
    )
    vocabulary = Path(tokenizer.vocab_file)
    shutil.copyfile(vocabulary, output_dir / "vocab.txt")
    minimum_cosine = verify_model(final_model, tokenizer, model)
    metadata = {
        "model": MODEL_ID,
        "revision": MODEL_REVISION,
        "license": "Apache-2.0",
        "embedding_dimensions": 128,
        "max_sequence_length": MAX_SEQUENCE_LENGTH,
        "model_bytes": final_model.stat().st_size,
        "model_sha256": sha256(final_model),
        "vocabulary_bytes": (output_dir / "vocab.txt").stat().st_size,
        "vocabulary_sha256": sha256(output_dir / "vocab.txt"),
        "minimum_reference_cosine": minimum_cosine,
    }
    (output_dir / "model_manifest.json").write_text(
        json.dumps(metadata, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(metadata, indent=2))


if __name__ == "__main__":
    main()
