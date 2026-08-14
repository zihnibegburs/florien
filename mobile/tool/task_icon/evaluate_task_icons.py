#!/usr/bin/env python3
"""Offline quality/performance evaluation for the shipped LEALLA assets."""

from __future__ import annotations

import argparse
from collections import defaultdict
import json
from pathlib import Path
import struct
import time

import numpy as np
from onnxruntime import InferenceSession, SessionOptions
from transformers import AutoTokenizer

from category_examples import CATEGORY_ACTIONS
from export_lealla import MAX_SEQUENCE_LENGTH, MODEL_ID, MODEL_REVISION


# Hand-authored, non-prototype task titles spanning the requested languages.
MULTILINGUAL_HOLDOUT: list[tuple[str, str]] = [
    # Turkish
    ("gym", "gym"), ("run", "running"), ("oku", "reading"),
    ("koş", "running"), ("uyku", "sleep"),
    ("Arabayı yıka", "car_wash"), ("Arabayı bakıma götür", "car_maintenance"),
    ("Arabanın frenlerini tamir ettir", "car_repair"), ("Benzin al", "fuel"),
    ("Anneme doğum günü hediyesi al", "gift"), ("Market alışverişi yap", "groceries"),
    ("Dişçi randevusu al", "dentist"), ("Doktora görün", "doctor"),
    ("Eczaneden ilaç al", "pharmacy"), ("Elektrik faturasını öde", "bills"),
    ("Sabah koşuya çık", "running"), ("Otuz dakika yoga yap", "yoga"),
    ("Çamaşırları yıka", "laundry"), ("Bulaşıkları makineye koy", "dishes"),
    ("Paris için otel ayır", "hotel"), ("Roma uçuşunu satın al", "flight"),
    ("Patronuma e-posta gönder", "email"), ("Uygulamadaki hatayı düzelt", "bug_fix"),
    ("Sunum slaytlarını hazırla", "presentation"), ("Kediyi veterinere götür", "pet"),
    # English
    ("Get the vehicle inspected", "car_maintenance"), ("Replace the broken headlight", "car_repair"),
    ("Pick up vegetables and bread", "groceries"), ("Choose a present for my wife", "gift"),
    ("Arrange a dental cleaning", "dentist"), ("Reserve a room in Berlin", "hotel"),
    ("Book the morning train", "train"), ("Renew my passport", "passport"),
    ("Debug the checkout crash", "bug_fix"), ("Call Sarah after lunch", "phone_call"),
    # German
    ("Auto zur Werkstatt bringen", "car_maintenance"), ("Zahnarzttermin vereinbaren", "dentist"),
    ("Lebensmittel für das Wochenende kaufen", "groceries"), ("Ein Geschenk für Mama besorgen", "gift"),
    ("Ein Hotel in Wien buchen", "hotel"), ("Die Stromrechnung bezahlen", "bills"),
    # French
    ("Emmener la voiture au garage", "car_maintenance"), ("Réserver un hôtel à Paris", "hotel"),
    ("Acheter un cadeau pour ma mère", "gift"), ("Prendre rendez-vous chez le dentiste", "dentist"),
    ("Faire les courses pour le dîner", "groceries"), ("Envoyer un courriel au client", "email"),
    # Spanish
    ("Lleva el coche al taller", "car_maintenance"), ("Comprar un regalo para mi madre", "gift"),
    ("Comprar comida para esta noche", "groceries"), ("Reservar un vuelo a Roma", "flight"),
    ("Lavar la ropa", "laundry"), ("Pedir cita con el médico", "doctor"),
    # Italian
    ("Prenota un volo per Roma", "flight"), ("Portare la macchina dal meccanico", "car_maintenance"),
    ("Comprare un regalo di compleanno", "gift"), ("Lavare i piatti", "dishes"),
    # Portuguese
    ("Levar o carro para revisão", "car_maintenance"), ("Comprar mantimentos", "groceries"),
    ("Marcar consulta no dentista", "dentist"), ("Pagar a conta de água", "bills"),
    # Dutch
    ("Breng de auto naar de garage", "car_maintenance"), ("Boodschappen doen", "groceries"),
    ("Een cadeau voor mijn moeder kopen", "gift"), ("De was doen", "laundry"),
    # Polish
    ("Oddaj samochód do serwisu", "car_maintenance"), ("Kupić prezent dla mamy", "gift"),
    ("Umówić wizytę u dentysty", "dentist"), ("Zapłacić rachunek za prąd", "bills"),
    # Russian / Ukrainian
    ("Отвезти машину в сервис", "car_maintenance"), ("Оплатить счет за электричество", "bills"),
    ("Купить маме подарок", "gift"), ("Записаться к стоматологу", "dentist"),
    ("Відвезти автомобіль на сервіс", "car_maintenance"), ("Купити продукти", "groceries"),
    ("Записатися до лікаря", "doctor"), ("Оплатити рахунок", "bills"),
    # Arabic / Persian / Hindi
    ("خذ السيارة إلى الصيانة", "car_maintenance"), ("اشتر دواء", "medicine"),
    ("احجز فندقاً", "hotel"), ("اشتر هدية لأمي", "gift"),
    ("ماشین را به تعمیرگاه ببر", "car_maintenance"), ("برای مادرم هدیه بخر", "gift"),
    ("قبض برق را پرداخت کن", "bills"), ("وقت دندانپزشکی بگیر", "dentist"),
    ("कार को सर्विस के लिए ले जाओ", "car_maintenance"), ("माँ के लिए उपहार खरीदो", "gift"),
    ("किराने का सामान खरीदो", "groceries"), ("डॉक्टर की अपॉइंटमेंट लो", "doctor"),
    # Indonesian / Malay / Vietnamese / Thai
    ("Bawa mobil ke bengkel", "car_maintenance"), ("Beli hadiah untuk ibu", "gift"),
    ("Belanja bahan makanan", "groceries"), ("Cuci pakaian", "laundry"),
    ("Bawa kereta ke bengkel", "car_maintenance"), ("Beli hadiah untuk ibu", "gift"),
    ("Bayar bil elektrik", "bills"), ("Tempah hotel", "hotel"),
    ("Mang xe đi bảo dưỡng", "car_maintenance"), ("Mua quà cho mẹ", "gift"),
    ("Đặt lịch nha sĩ", "dentist"), ("Thanh toán hóa đơn điện", "bills"),
    ("เอารถไปเข้าศูนย์", "car_maintenance"), ("ซื้อของขวัญให้แม่", "gift"),
    ("นัดหมอฟัน", "dentist"), ("จ่ายค่าไฟ", "bills"),
    # Chinese / Japanese / Korean
    ("把车送去保养", "car_maintenance"), ("给妈妈买生日礼物", "gift"),
    ("预约医生", "doctor"), ("支付电费", "bills"),
    ("車を点検に出す", "car_maintenance"), ("母にプレゼントを買う", "gift"),
    ("歯医者を予約する", "dentist"), ("電気代を払う", "bills"),
    ("차를 정비소에 맡기기", "car_maintenance"), ("엄마 생일 선물 사기", "gift"),
    ("치과 예약하기", "dentist"), ("전기 요금 내기", "bills"),
]

AMBIGUOUS = [
    "John ile konuş", "Bunu yap", "Kontrol et", "Bir şeye bak", "Sonra hallet",
    "Talk to John", "Check it", "Do this later", "Look into something", "Handle it",
    "Mach das später", "Vérifier ça", "Haz esto", "Fallo dopo", "Проверить это",
    "افعل هذا لاحقاً", "あとでやる", "나중에 하기", "稍后处理", "Làm việc này sau",
]


def load_prototypes(asset_dir: Path) -> tuple[np.ndarray, list[dict[str, object]]]:
    manifest = json.loads((asset_dir / "category_embeddings_manifest.json").read_text())
    raw = (asset_dir / "category_embeddings.i8").read_bytes()
    magic, version, dimensions, total = struct.unpack_from("<4sHHI", raw, 0)
    assert magic == b"TIE1" and version == 1 and dimensions == 128
    vectors = np.empty((total, dimensions), dtype=np.float32)
    offset = 12
    for row in range(total):
        scale = struct.unpack_from("<f", raw, offset)[0]
        offset += 4
        vectors[row] = np.frombuffer(raw, dtype=np.int8, count=dimensions, offset=offset) * scale
        offset += dimensions
    return vectors, manifest["categories"]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset-dir", type=Path, default=Path("assets/task_icons"))
    parser.add_argument("--cache-dir", type=Path, default=Path(".dart_tool/task_icon_model/hf_cache"))
    parser.add_argument("--runs", type=int, default=30)
    parser.add_argument("--include-failures", action="store_true")
    args = parser.parse_args()
    options = SessionOptions()
    options.intra_op_num_threads = 1
    session = InferenceSession(
        args.asset_dir / "lealla_small_int8.onnx",
        sess_options=options,
        providers=["CPUExecutionProvider"],
    )
    tokenizer = AutoTokenizer.from_pretrained(
        MODEL_ID, revision=MODEL_REVISION, cache_dir=args.cache_dir,
        local_files_only=True, use_fast=True,
    )
    prototypes, category_manifest = load_prototypes(args.asset_dir)

    def classify(texts: list[str]) -> tuple[np.ndarray, np.ndarray]:
        encoded = tokenizer(
            texts, return_tensors="np", max_length=MAX_SEQUENCE_LENGTH,
            truncation=True, padding="max_length",
        )
        ids = encoded["input_ids"].astype(np.int64)
        embeddings = session.run(["sentence_embedding"], {
            "input_ids": ids,
            "attention_mask": encoded["attention_mask"].astype(np.int64),
            "token_type_ids": encoded.get("token_type_ids", np.zeros_like(ids)).astype(np.int64),
        })[0]
        embeddings /= np.maximum(np.linalg.norm(embeddings, axis=1, keepdims=True), 1e-12)
        similarities = embeddings @ prototypes.T
        scores = np.empty((len(texts), len(category_manifest)), dtype=np.float32)
        for index, category in enumerate(category_manifest):
            start = int(category["offset"])
            count = int(category["count"])
            scores[:, index] = np.sort(similarities[:, start:start + count], axis=1)[:, -3:].mean(axis=1)
        order = np.argsort(-scores, axis=1)
        return scores, order

    texts = [text for text, _ in MULTILINGUAL_HOLDOUT]
    scores, order = classify(texts)
    correct = 0
    parent_correct = 0
    manual_accepted = 0
    manual_accepted_correct = 0
    confusion: dict[tuple[str, str], int] = defaultdict(int)
    failures: list[dict[str, object]] = []
    for row, (_, expected) in enumerate(MULTILINGUAL_HOLDOUT):
        predicted = category_manifest[order[row, 0]]["name"]
        expected_entry = next(item for item in category_manifest if item["name"] == expected)
        predicted_entry = category_manifest[order[row, 0]]
        correct += predicted == expected
        parent_correct += predicted_entry["parent"] == expected_entry["parent"]
        best = float(scores[row, order[row, 0]])
        second = float(scores[row, order[row, 1]])
        is_accepted = best >= .47 and best - second >= .05
        manual_accepted += is_accepted
        manual_accepted_correct += is_accepted and predicted == expected
        if predicted != expected:
            confusion[(expected, str(predicted))] += 1
            failures.append({
                "text": MULTILINGUAL_HOLDOUT[row][0],
                "expected": expected,
                "predicted": predicted,
                "top": [
                    {
                        "category": category_manifest[index]["name"],
                        "score": round(float(scores[row, index]), 4),
                    }
                    for index in order[row, :3]
                ],
            })

    ambiguous_scores, ambiguous_order = classify(AMBIGUOUS)
    fallback = 0
    false_high_confidence = 0
    for row in range(len(AMBIGUOUS)):
        best = float(ambiguous_scores[row, ambiguous_order[row, 0]])
        second = float(ambiguous_scores[row, ambiguous_order[row, 1]])
        accepted = best >= .47 and best - second >= .05
        fallback += not accepted
        false_high_confidence += accepted

    # Add two deterministic smoke titles per category so the suite stays at
    # 200+ examples while the holdout metric remains honestly separated.
    smoke = []
    for category, actions in CATEGORY_ACTIONS.items():
        smoke.append((f"Remember to {actions[2]}", category))
        smoke.append((f"Today's task is to {actions[4]}", category))
    smoke_scores, smoke_order = classify([text for text, _ in smoke])
    smoke_correct = sum(
        category_manifest[smoke_order[row, 0]]["name"] == expected
        for row, (_, expected) in enumerate(smoke)
    )

    timings = []
    benchmark_text = "Anneme doğum günü hediyesi al"
    classify([benchmark_text])
    for _ in range(args.runs):
        started = time.perf_counter()
        classify([benchmark_text])
        timings.append((time.perf_counter() - started) * 1000)

    report = {
        "manual_multilingual_holdout_count": len(MULTILINGUAL_HOLDOUT),
        "manual_top1_accuracy": correct / len(MULTILINGUAL_HOLDOUT),
        "manual_parent_accuracy": parent_correct / len(MULTILINGUAL_HOLDOUT),
        "manual_fallback_rate": 1 - manual_accepted / len(MULTILINGUAL_HOLDOUT),
        "manual_accepted_accuracy": manual_accepted_correct / max(manual_accepted, 1),
        "manual_wrong_high_confidence_rate": (manual_accepted - manual_accepted_correct) / len(MULTILINGUAL_HOLDOUT),
        "ambiguous_count": len(AMBIGUOUS),
        "ambiguous_fallback_rate": fallback / len(AMBIGUOUS),
        "ambiguous_false_high_confidence_rate": false_high_confidence / len(AMBIGUOUS),
        "prototype_paraphrase_smoke_count": len(smoke),
        "prototype_paraphrase_smoke_accuracy": smoke_correct / len(smoke),
        "total_evaluation_tasks": len(MULTILINGUAL_HOLDOUT) + len(AMBIGUOUS) + len(smoke),
        "desktop_cpu_mean_ms": float(np.mean(timings)),
        "desktop_cpu_p95_ms": float(np.percentile(timings, 95)),
        "largest_confusions": [
            {"expected": key[0], "predicted": key[1], "count": count}
            for key, count in sorted(confusion.items(), key=lambda item: -item[1])[:15]
        ],
    }
    if args.include_failures:
        report["failures"] = failures
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
