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
    # The user-reported failure was not missing keys; it was an inactive
    # translation context on Telegram's custom nested ItemListController stack.
    "Chat list", "Panels", "Navigation and composer", "Glass and bubbles",
    "Themes, colours & badges", "No story camera on pull", "Square avatars",
    "OLED mode", "Sticker size", "INTERFACE", "Beside the time",
    "Pulling the chat list does not open the camera",
    # Reported untranslated labels/footers in player, Tools and camera.
    "Link rewriting", "Starting zoom", "No live preview",
    "Watermark text", "Track on the Lock Screen",
    "VoidGram settings, plugins and saved deleted/edited messages in one file (AES-GCM). Save it to Files or iCloud Drive. Import from a computer: ayugram.db from the AyuGram Desktop data folder.",
    "The player menu (⋯ next to the lyrics) also has a sleep timer and the equalizer.",
    "No plugins found.\n\nTap + to install a .iosplug, .plugin or .js code plugin, or open the catalog (the bag icon).",
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
    'atomic_bool AGInVoidStack',
    'atomic_store(&AGInVoidStack, true);',
    'atomic_store(&AGInVoidStack, false);',
    '@selector(viewWillAppear:)',
    'AGRefreshAyuPage(page)',
):
    if gate not in source:
        raise SystemExit(f"Missing scope guard: {gate}")
# Regression checks for menu/gesture freeze: a string clone must never
# trigger translated copy constructors recursively. Keep the rendering hooks,
# but don't swizzle global attributed-copy initializers.
for forbidden in (
    "AGHookConcrete(immutableClass, @selector(initWithAttributedString:)",
    "AGHookConcrete(mutableClass, @selector(initWithAttributedString:)",
):
    if forbidden in source:
        raise SystemExit(f"Unsafe attributed-copy hook reintroduced: {forbidden}")
for required_source in (
    "static _Thread_local BOOL agInsideTextConversion",
    "if (objc_getAssociatedObject(vc, &AGRootMarker)) {",
    "if (atomic_load(&AGInVoidStack)) return YES;",
):
    if required_source not in source:
        raise SystemExit(f"Missing anti-freeze or async-text guard: {required_source}")
if "AGInAyuStack" in source:
    raise SystemExit("Old sticky global scope remains")
header = ROOT / "src" / "generated_voidgram_ar.h"
if not header.is_file():
    raise SystemExit("Generated translation header missing; run build script first")
print(f"PASS: {len(translations)} VoidGram translation keys, nested page scope + exit guard, iOS source present")
