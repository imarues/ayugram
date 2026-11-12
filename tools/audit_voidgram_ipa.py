#!/usr/bin/env python3
"""Audit VoidGram 27.6.9's actual Mach-O C string section against Arabic keys.

Run:
    python3 tools/audit_voidgram_ipa.py /path/to/VoidGram.ipa --output coverage-voidgram

Static candidates are NOT verified visible UI strings; interactive iPhone review
is needed before advertising any percentage of runtime translation coverage.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import struct
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from build_voidgram_translations import build  # noqa: E402

def macho_section(data: bytes, section: str = "__cstring") -> tuple[int, int]:
    if len(data) < 32 or data[:4] != b"\xcf\xfa\xed\xfe":
        raise ValueError("Not a thin little-endian arm64 Mach-O executable")
    ncmds = struct.unpack_from("<I", data, 16)[0]
    offset = 32
    for _ in range(ncmds):
        command, command_size = struct.unpack_from("<II", data, offset)
        if command_size < 8 or offset + command_size > len(data):
            raise ValueError("Bad Mach-O load command")
        if command == 0x19:  # LC_SEGMENT_64
            count = struct.unpack_from("<I", data, offset + 64)[0]
            for index in range(count):
                pos = offset + 72 + index * 80
                if pos + 80 > offset + command_size:
                    raise ValueError("Bad Mach-O section header")
                name = data[pos:pos+16].partition(b"\0")[0].decode("ascii")
                if name == section:
                    size, file_offset = struct.unpack_from("<QI", data, pos+40)
                    if file_offset + size > len(data):
                        raise ValueError("Mach-O section exceeds executable")
                    return file_offset, file_offset + size
        offset += command_size
    raise ValueError("Mach-O __cstring section not found")

def candidate(value: str) -> bool:
    value = value.strip()
    if not (2 <= len(value) <= 1500) or not re.search(r"[A-Za-z]", value):
        return False
    if "\n" in value or "\r" in value:
        return True
    if value.startswith(("https://", "http://", "SettingsUI.", "_$s", "objc_", "submodules/")):
        return False
    if re.search(r"\.(?:swift|m|mm|h|dylib|framework|png|jpg|json)$", value, re.I):
        return False
    if re.fullmatch(r"[a-zA-Z][\w.$/:<>-]*", value) and not value[0].isupper():
        return False
    if len(value) > 500 and value.count("/") > 10:
        return False
    # Note that identifiers can still pass; the report is a *candidate* list.
    return True

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("ipa", type=pathlib.Path)
    parser.add_argument("--output", default="coverage-voidgram", type=pathlib.Path)
    args = parser.parse_args()
    with zipfile.ZipFile(args.ipa) as archive:
        names = [n for n in archive.namelist()
                 if n.endswith("/TelegramUIFramework.framework/TelegramUIFramework")]
        if len(names) != 1:
            raise SystemExit("Expected exactly one TelegramUIFramework executable")
        raw = archive.read(names[0])

    first, last = macho_section(raw)
    chunks = []
    base = first
    for piece in raw[first:last].split(b"\0"):
        if piece:
            try:
                value = piece.decode("utf-8")
            except UnicodeDecodeError:
                value = ""
            if value and candidate(value):
                chunks.append((base, value))
        base += len(piece) + 1

    # Objective-C/Swift app-local string group. Avoid claiming general Telegram
    # framework strings outside the settings cluster belong to VoidGram.
    markers = [offset for offset, value in chunks
               if "VoidGram" in value or value == "Ghost Mode by chat"
               or "Just an exteraGram based client" in value]
    if not markers:
        raise SystemExit("VoidGram settings markers were not found in __cstring")
    start = max(first, min(markers) - 60000)
    end = min(last, max(markers) + 80000)
    settings = [(off, value) for off, value in chunks if start <= off < end]

    translations = build()
    distinct = {value for _, value in settings}
    matched = distinct.intersection(translations)
    unmatched = distinct.difference(translations)
    output = args.output
    output.mkdir(parents=True, exist_ok=True)

    def save(name: str, rows: list[tuple[int, str]]) -> None:
        (output / name).write_text(
            "offset\ttext_json\n" +
            "\n".join(f"{off}\t{json.dumps(value, ensure_ascii=False)}"
                      for off, value in rows) + "\n",
            encoding="utf-8")

    save("app-candidates.tsv", settings)
    save("untranslated-candidates.tsv",
         [(off, text) for off, text in settings if text in unmatched])
    names = [k for k in distinct if "VoidGram" in k]
    report = {
        "dictionary_entries": len(translations),
        "macho_cstring_section_offsets": [first, last],
        "examined_app_region_offsets": [start, end],
        "raw_candidates_in_region": len(settings),
        "unique_candidates": len(distinct),
        "exact_translated_candidates": len(matched),
        "untranslated_candidates": len(unmatched),
        "app_named_candidates": len(names),
        "app_named_translated": len([x for x in names if x in translations]),
        "warning": ("Heuristic candidate inventory, NOT a valid percentage of UI coverage. "
                    "Swift-composed labels, plural forms, emoji labels, formatting, alerts "
                    "and hidden screens also need interactive on-device tests.")
    }
    (output / "summary.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
