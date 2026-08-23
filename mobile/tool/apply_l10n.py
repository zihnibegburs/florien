#!/usr/bin/env python3
"""Wrap catalog source strings with context.l10n() in selected Dart files."""

from __future__ import annotations

import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
CATALOG = ROOT / "lib/core/l10n/catalog.dart"
IMPORT = "import 'package:florien/core/l10n/app_strings.dart';"

SKIP_DIRS = {"l10n"}
TARGETS = [
    ROOT / "lib/features",
    ROOT / "lib/core/widgets",
    ROOT / "lib/core/data",
]


def catalog_keys() -> list[str]:
    keys: list[str] = []
    for match in re.finditer(r'^\s+("(?:\\.|[^"\\])*"): <String>\[', CATALOG.read_text(), re.M):
        keys.append(bytes(match.group(1), "utf-8").decode("unicode_escape").strip('"'))
    keys.sort(key=len, reverse=True)
    return keys


def dart_quote(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n")
    return f"'{escaped}'"


def transform(source: str, keys: list[str]) -> str:
    updated = source
    for key in keys:
        quoted = dart_quote(key)
        wrapped = f"context.l10n({quoted})"
        if wrapped in updated:
            continue
        patterns = [
            (rf"const Text\(\s*{re.escape(quoted)}\s*\)", f"Text({wrapped})"),
            (rf"Text\(\s*{re.escape(quoted)}\s*\)", f"Text({wrapped})"),
            (rf"(label|title|tooltip|hintText|subtitle|message):\s*{re.escape(quoted)}", rf"\1: {wrapped}"),
        ]
        for pattern, repl in patterns:
            updated = re.sub(pattern, repl, updated)
    if updated != source and IMPORT not in updated:
        updated = updated.replace(
            "import 'package:flutter/material.dart';",
            "import 'package:flutter/material.dart';\n" + IMPORT,
            1,
        )
    return updated


def main() -> None:
    keys = catalog_keys()
    changed = 0
    for folder in TARGETS:
        for path in folder.rglob("*.dart"):
            if any(part in SKIP_DIRS for part in path.parts):
                continue
            if path.name.endswith(".g.dart"):
                continue
            original = path.read_text(encoding="utf-8")
            updated = transform(original, keys)
            if updated != original:
                path.write_text(updated, encoding="utf-8")
                changed += 1
                print("updated", path.relative_to(ROOT))
    print(f"changed {changed} files")


if __name__ == "__main__":
    main()
