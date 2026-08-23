#!/usr/bin/env python3
"""Wrap every catalog key quoted in Dart lib/ with l10n lookups."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"
IMPORT = "import 'package:florien/core/l10n/app_strings.dart';"

SERVICE_PREFIXES = (
    "lib/core/services/",
    "lib/core/data/",
    "lib/core/models/",
    "lib/core/repositories/",
)

SKIP_EXACT = {
    LIB / "core/l10n/catalog.dart",
    LIB / "core/l10n/app_strings.dart",
    LIB / "core/l10n/app_language.dart",
    LIB / "core/data/routine_catalog.dart",
}

SKIP_SUBSTRINGS = (
    "/task_icon/data/",
)


def load_keys() -> list[str]:
    catalog = (ROOT / "lib/core/l10n/catalog.dart").read_text(encoding="utf-8")
    raw = re.findall(r'^  ("(?:\\.|[^"\\])*"):', catalog, re.M)
    return sorted((json.loads(item) for item in raw), key=len, reverse=True)


def dart_single(value: str) -> str:
    return (
        "'"
        + value.replace("\\", "\\\\")
        .replace("'", "\\'")
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        + "'"
    )


def ensure_import(text: str) -> str:
    if "package:florien/core/l10n/app_strings.dart" in text:
        return text
    lines = text.splitlines(keepends=True)
    insert_at = 0
    for i, line in enumerate(lines):
        if line.startswith("import "):
            insert_at = i + 1
    lines.insert(insert_at, IMPORT + "\n")
    return "".join(lines)


def should_skip_file(path: Path) -> bool:
    if path in SKIP_EXACT:
        return True
    rel = str(path).replace("\\", "/")
    return any(part in rel for part in SKIP_SUBSTRINGS)


def is_service(path: Path) -> bool:
    rel = str(path.relative_to(ROOT)).replace("\\", "/")
    return rel.startswith(SERVICE_PREFIXES)


def already_wrapped(text: str, pos: int) -> bool:
    prefix = text[max(0, pos - 72) : pos]
    return bool(
        re.search(
            r"(?:context\.l10n|ActiveLanguage\.s|\.l10n|strings|_s|(?<![A-Za-z])s|this)\(\s*$",
            prefix,
        )
    )


def inside_value_key(text: str, pos: int) -> bool:
    prefix = text[max(0, pos - 48) : pos]
    return bool(re.search(r"ValueKey\(\s*$", prefix))


def drop_nearby_const(text: str, pos: int) -> str:
    """Remove const from Text/InputDecoration/SnackBar immediately wrapping this string."""
    window_start = max(0, pos - 80)
    prefix = text[window_start:pos]
    match = re.search(
        r"const\s+(Text|InputDecoration|SnackBar|Center|Row|Column|Padding|Icon)\(\s*$",
        prefix,
    )
    if not match:
        return text
    abs_pos = window_start + match.start()
    return text[:abs_pos] + text[abs_pos + 6 :]  # drop 'const '


def wrap_file(path: Path, keys: list[str]) -> bool:
    text = path.read_text(encoding="utf-8")
    original = text
    call_fn = "ActiveLanguage.s" if is_service(path) else "context.l10n"
    for key in keys:
        quoted = dart_single(key)
        if quoted not in text:
            continue
        call = f"{call_fn}({quoted})"
        start = 0
        while True:
            pos = text.find(quoted, start)
            if pos < 0:
                break
            if already_wrapped(text, pos) or inside_value_key(text, pos):
                start = pos + len(quoted)
                continue
            text = drop_nearby_const(text, pos)
            # const drop may have shifted pos left by 6
            pos = text.find(quoted, max(0, pos - 8))
            if pos < 0 or already_wrapped(text, pos):
                start = (pos if pos >= 0 else start) + len(quoted)
                continue
            text = text[:pos] + call + text[pos + len(quoted) :]
            start = pos + len(call)
    if text == original:
        return False
    if "context.l10n(" in text or "ActiveLanguage.s(" in text:
        text = ensure_import(text)
    path.write_text(text, encoding="utf-8")
    return True


def main() -> int:
    keys = load_keys()
    changed = 0
    for path in sorted(LIB.rglob("*.dart")):
        if should_skip_file(path):
            continue
        if wrap_file(path, keys):
            changed += 1
            print(path.relative_to(ROOT))
    print(f"updated {changed} files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
