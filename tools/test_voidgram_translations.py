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
    # New VoidGram 27.8.2 strings verified against the supplied IPA.
    "The plugin asks for:\n", "Copy diagnostics",
    "Delete my messages?", "The cover is not loaded yet. Scroll to the track and try again.",
    "Download video · ", "VoidGram · Copy Message IDs",
    "MessageShot Appearance", "The player opens with the lyrics",
    "The folder was created; it is at the top of the chat list.",
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
    # Exact labels left untranslated in user's screenshots, including cached pages.
    "Reset Settings", "Delete Account", "Wait at most", "Reset sources",
    "LOOKUP", "Karaoke", "No animation", "Wave", "Glow", "Cascade",
    "Highlight the current line without motion",
    "Smooth word fill without moving letters",
    "Letters rise in a wave as words are sung",
    "Soft light follows the sung words",
    "Spring scrolling with blurred surrounding lines",
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
external_map = __import__("json").loads((ROOT / "locales" / "voidgram-chat-ui.json").read_text(encoding="utf-8"))
for action_key in (
    "Enable Ghost Mode in this chat",
    "Disable Ghost Mode in this chat",
    "Read receipts, typing and uploads are hidden in this chat. Online status is set separately.",
    "Delete My Messages", "Send as a video message", "Send as a voice message",
    "VoidGram · Copy Message IDs", "Send Logs", "Year in review",
):
    if action_key not in external_map:
        raise SystemExit(f"Missing external chat UI action: {action_key}")
for sensitive in ("Today", "Copy", "OK", "Reply", "Delete", "Message", "Privacy"):
    if sensitive in external_map:
        raise SystemExit(f"Unsafe generic external chat UI label: {sensitive}")
# The earlier implementation never translated chat actions: those labels are
# created BEFORE their Swift display nodes attach to the menu hierarchy.
# Assert that exact matches are resolved before the settings-only scope gate.
source = (ROOT / "src" / "VoidGramArabic.m").read_text(encoding="utf-8")
external_lookup = source.find("NSString *outside = AGExternalUIMap()[text];")
strict_scope = source.find("if (!AGIsOnAyuPage()) return text; // full dictionary remains settings-only")
if external_lookup < 0 or strict_scope < 0 or external_lookup >= strict_scope:
    raise SystemExit("VoidGram action translation still blocked by settings-only gate")
if "AGTranslateYearReview(text)" not in source:
    raise SystemExit("Dynamic Year in Review localization missing")
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
    "static char AGChildMarker;",
    "BOOL knownVoid = objc_getAssociatedObject(vc, &AGRootMarker) != nil ||",
    "objc_getAssociatedObject(vc, &AGChildMarker) != nil;",
    "objc_setAssociatedObject(vc, &AGChildMarker, @YES,",
    "if (objc_getAssociatedObject(vc, &AGRootMarker) ||",
    "AGNormalizedMap()[AGNormalizedUILabel(text)]",
    "NSUInteger remaining = 650;",
    "if (atomic_load(&AGInVoidStack)) return YES;",
):
    if required_source not in source:
        raise SystemExit(f"Missing anti-freeze or async-text guard: {required_source}")
# Root-only footer visibility. Upper feature rows remain clickable; only the
# standalone LINKS and following acknowledgements should be suppressed.
for required_source in (
    "static void AGHideLinksAndCreditsOnRoot(UIViewController *root)",
    "AGForegroundVoidController != root",
    "objc_getAssociatedObject(root, &AGRootMarker)",
    '@"links", @"الروابط", @"acknowledgments"',
    '@"credits", @"thanks", @"thanks & credits", @"شكر وتقدير"',
    "item.userInteractionEnabled = NO;",
    "item.hidden = YES;",
    "AGForegroundVoidController = vc;",
    "AGMonitorRootFooter(vc);",
    "AGCaptureFooterHeader(obj, value.string);",
    "AGKeepFooterOutsideViewport(root)",
    "AGApplyFooterCover(root)",
    "AGLinksHeaderObject",
    "AGFooterHeaderViewIn",
    "static BOOL AGIsLinksHeaderText(NSString *value)",
    "AGForegroundVoidController = vc;",
    "if (objc_getAssociatedObject(vc, &AGRootMarker)) {",
    "AGForegroundVoidController != root",
):
    if required_source not in source:
        raise SystemExit(f"VoidGram root footer suppression guard is missing: {required_source}")
if "AGInAyuStack" in source:
    raise SystemExit("Old sticky global scope remains")
for external_guard in (
    "static NSDictionary<NSString *, NSString *> *AGExternalUIMap(void)",
    "static BOOL AGIsExternalActionNode(id node)",
    "static BOOL AGIsExternalActionView(UIView *view)",
    "AGTranslateExternalActionAttributed(obj, value)",
    "AGTranslateActionTitle(title)",
    "static NSString *AGTranslateYearReview(NSString *value)",
    "if (!match || match.range.location != 0) return nil;",
    "AGExternalExactText(value)",
    "AGIsExternalActionView(obj)",
    "if (settings) visible = AGTranslate(value);",
):
    if external_guard not in source:
        raise SystemExit(f"Missing external UI isolation guard: {external_guard}")
header = ROOT / "src" / "generated_voidgram_ar.h"
if not header.is_file():
    raise SystemExit("Generated translation header missing; run build script first")
print(f"PASS: {len(translations)} VoidGram translation keys, nested page scope + exit guard, iOS source present")
