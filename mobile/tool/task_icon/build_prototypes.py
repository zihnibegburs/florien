#!/usr/bin/env python3
"""Precompute normalized category prototype embeddings with the mobile model."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct

import numpy as np
from onnxruntime import InferenceSession, SessionOptions
from transformers import AutoTokenizer

from category_examples import CATEGORY_ACTIONS, examples_for, validate
from export_lealla import MAX_SEQUENCE_LENGTH, MODEL_ID, MODEL_REVISION


MAGIC = b"TIE1"
VERSION = 1
DIMENSIONS = 128
BATCH_SIZE = 32


def digest_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while chunk := source.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def parent_for(index: int) -> str:
    if index <= 9:
        return "work"
    if index <= 19:
        return "education"
    if index <= 29:
        return "shopping"
    if index <= 39:
        return "food"
    if index <= 49:
        return "health"
    if index <= 59:
        return "fitness"
    if index <= 69:
        return "travel"
    if index <= 79:
        return "transportation"
    if index <= 89:
        return "home"
    if index <= 93:
        return "finance"
    if index <= 96:
        return "relationships"
    if index <= 98:
        return "lifestyle"
    return "other"


def embed(
    session: InferenceSession,
    tokenizer: AutoTokenizer,
    texts: list[str],
) -> np.ndarray:
    batches: list[np.ndarray] = []
    for start in range(0, len(texts), BATCH_SIZE):
        encoded = tokenizer(
            texts[start : start + BATCH_SIZE],
            return_tensors="np",
            max_length=MAX_SEQUENCE_LENGTH,
            truncation=True,
            padding="max_length",
        )
        input_ids = encoded["input_ids"].astype(np.int64)
        inputs = {
            "input_ids": input_ids,
            "attention_mask": encoded["attention_mask"].astype(np.int64),
            "token_type_ids": encoded.get(
                "token_type_ids", np.zeros_like(input_ids)
            ).astype(np.int64),
        }
        result = session.run(["sentence_embedding"], inputs)[0].astype(np.float32)
        result /= np.maximum(np.linalg.norm(result, axis=1, keepdims=True), 1e-12)
        batches.append(result)
    return np.concatenate(batches, axis=0)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset-dir", type=Path, default=Path("assets/task_icons"))
    parser.add_argument(
        "--cache-dir", type=Path, default=Path(".dart_tool/task_icon_model/hf_cache")
    )
    args = parser.parse_args()
    asset_dir = args.asset_dir.resolve()
    model_path = asset_dir / "lealla_small_int8.onnx"
    if not model_path.exists():
        raise FileNotFoundError(
            f"{model_path} is missing; run export_lealla.py before this script"
        )

    categories = list(CATEGORY_ACTIONS)
    validate(categories)
    tokenizer = AutoTokenizer.from_pretrained(
        MODEL_ID,
        revision=MODEL_REVISION,
        cache_dir=args.cache_dir.resolve(),
        local_files_only=True,
        use_fast=True,
    )
    options = SessionOptions()
    options.intra_op_num_threads = 1
    session = InferenceSession(
        model_path, sess_options=options, providers=["CPUExecutionProvider"]
    )

    all_texts: list[str] = []
    category_manifest: list[dict[str, object]] = []
    for index, category in enumerate(categories):
        examples = examples_for(category)
        category_manifest.append(
            {
                "name": category,
                "parent": parent_for(index),
                "offset": len(all_texts),
                "count": len(examples),
            }
        )
        all_texts.extend(examples)

    vectors = embed(session, tokenizer, all_texts)
    if vectors.shape != (len(all_texts), DIMENSIONS):
        raise ValueError(f"Unexpected embedding shape: {vectors.shape}")

    binary_path = asset_dir / "category_embeddings.i8"
    with binary_path.open("wb") as output:
        output.write(struct.pack("<4sHHI", MAGIC, VERSION, DIMENSIONS, len(vectors)))
        for vector in vectors:
            scale = float(np.max(np.abs(vector)) / 127.0)
            if scale == 0:
                scale = 1.0
            quantized = np.clip(np.rint(vector / scale), -127, 127).astype(np.int8)
            output.write(struct.pack("<f", scale))
            output.write(quantized.tobytes())

    examples_digest = hashlib.sha256(
        json.dumps(
            {name: examples_for(name) for name in categories},
            ensure_ascii=False,
            separators=(",", ":"),
        ).encode("utf-8")
    ).hexdigest()
    manifest = {
        "format": "TIE1",
        "version": VERSION,
        "dimensions": DIMENSIONS,
        "total_examples": len(all_texts),
        "examples_per_category": 10,
        "model_sha256": digest_file(model_path),
        "examples_sha256": examples_digest,
        "embeddings_sha256": digest_file(binary_path),
        "categories": category_manifest,
    }
    manifest_path = asset_dir / "category_embeddings_manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(json.dumps(manifest, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
