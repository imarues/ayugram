#!/usr/bin/env python3
"""Static safety checks for VoidGram 27.6.9 Arabic. No device required."""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from build_voidgram_translations import build, rename_app_brand  # noqa: E402

translations = build()
required = (
    "Just an exteraGram based client with ToS breaking features in mind.",
    "Privacy", "Messages", "Media & Calls", "Appearance", "Security",
    "More", "Sending", "Translation", "Filters", "Menu & gestures",
    "Chats", "Find channels and people", "Local notifications",
    "Hide matching messages", "Private chats and groups", "Ignore case",
    "Add Rule", "VoidGram settings", "Face ID for VoidGram settings",
    "Could not start the Python plugin.", "Could not start the WebAssembly plugin.",
)
missing = [key for key in required if key not in translations]
if missing:
    raise SystemExit(f"Missing screenshot/feature entries: {missing}")
if len(translations) < 2800:
    raise SystemExit(f"Too few entries ({len(translations)})")
for key in required:
    if not translations[key].strip():
        raise SystemExit(f"Empty entry: {key}")
if rename_app_brand("Import from AyuGram Desktop") != "Import from AyuGram Desktop":
    raise SystemExit("AyuGram Desktop brand must stay intact")
if rename_app_brand("Open AyuGram settings") != "Open VoidGram settings":
    raise SystemExit("VoidGram brand alias failed")
source = (ROOT / "src" / "VoidGramArabic.m").read_text(encoding="utf-8")
for gate in (
    'if (!AGIsOnAyuPage()) return text;',
    '@"Just an exteraGram based client with ToS breaking features in mind."',
    'AGControllerIsWithinMarkedRoot',
    'atomic_store(&AGPendingAyuRoot, false);',
):
    if gate not in source:
        raise SystemExit(f"Missing scope guard: {gate}")
if "AGInAyuStack" in source:
    raise SystemExit("Old sticky global scope remains")
header = ROOT / "src" / "generated_voidgram_ar.h"
if not header.is_file():
    raise SystemExit("Generated translation header missing; run build script first")
print(f"PASS: {len(translations)} VoidGram translation keys, strict root guard, iOS source present")
