#!/usr/bin/env python3
import json
import pathlib
import re

root = pathlib.Path(__file__).resolve().parent.parent
merged = {}
for path in sorted((root / "locales").glob("ar-*.json")):
    for key, value in json.loads(path.read_text(encoding="utf-8")).items():
        if not isinstance(key, str) or not isinstance(value, str) or not value.strip():
            raise ValueError(f"{path}: invalid translation: {key!r}")
        if key in merged and merged[key] != value:
            raise ValueError(f"Conflicting Arabic translations for {key!r}")
        if re.findall(r"%(\d+\$)?[@dfsu]",key) != re.findall(r"%(\d+\$)?[@dfsu]",value):
            raise ValueError(f"Format placeholders changed: {key!r}")
        merged[key] = value

if not merged:
    raise ValueError("Arabic translation dictionary is empty")
raw = json.dumps(merged, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
lines = [
    "    " + ", ".join("0x%02x" % x for x in raw[i:i+16]) + ","
    for i in range(0, len(raw), 16)
]
(root / "src" / "generated_ar.h").write_text(
    "// Generated. Do not edit.\nstatic const unsigned char AG_AR_BYTES[] = {\n"
    + "\n".join(lines) + "\n};\n", encoding="utf-8"
)
print(f"Packed {len(merged)} localized strings into {len(raw)} UTF-8 bytes")
