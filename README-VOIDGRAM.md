# VoidGram Arabic — separate from AyuGram

This branch targets the uploaded **VoidGram 27.6.9 (build 185)** IPA,
bundle one.ayugram.unofficial.ios, Telegram base 13.1.1.

Do not merge the runtime hook from this branch into AyuGram's main branch.
The original src/AyuGramArabic.m, original dictionaries and existing AyuGram
build remain unchanged.

## Scope

- Arabic translation starts only from VoidGram's unique settings intro
  sentence. Once the root appears, a settings-session flag follows Telegram's
  custom navigation controller across nested ItemList screens (Appearance,
  Messages, Chat list, filters and deeper pages). The regular UIKit
  navigationController property is insufficient for this custom stack.
- The session stops immediately when a stock Telegram screen appears
  (Settings, Chats, Contacts, Calls, user profiles). The guarded dictionary
  cannot translate ordinary chat content outside VoidGram settings.
- Back-navigation restores the session when the actual marked root appears.
- The unique exteraGram intro sentence is used as a root-detection anchor.
  Generic words like Privacy, Messages, Ghost Mode by chat and generic
  ItemListController classes are not valid anchors.
- Outside this stack, the tweak must not translate normal Telegram settings,
  chats, usernames, message content, account screens, or feature state.
- English labels surrounded by emoji/bullets retain the original decoration.
  Numeric counters keep their numbers and MB/GB units.
- Most inherited AyuGram dictionary entries are reused. VoidGram-specific
  names are generated as aliases, plus locale entries for changed/new text.
  The external references AyuGram Desktop, AyuGram-IOS and ayugram.db retain
  their actual spelling.

## Build

Use the GitHub Actions workflow "Build VoidGram Arabic dylib" on the
voidgram-arabic branch. Or on macOS with Xcode:

    python3 tools/build_voidgram_translations.py
    python3 tools/test_voidgram_translations.py
    SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
    xcrun --sdk iphoneos clang -arch arm64 -miphoneos-version-min=15.0 \
      -isysroot "$SDK" -fobjc-arc -fmodules -O2 -dynamiclib \
      src/VoidGramArabic.m -framework Foundation -framework UIKit \
      -Wl,-install_name,@rpath/VoidGramArabic.dylib -o VoidGramArabic.dylib

Inject only VoidGramArabic.dylib for this VoidGram version. Do not inject it
together with AyuGramArabic.dylib; both hook the same methods, which can
change runtime behavior or reliability.

Bool UserDefaults VoidGramArabicEnabled defaults to enabled.
Bool VoidGramArabicDiagnostics enables a brief on-device load toast.

## Static IPA audit

    python3 tools/audit_voidgram_ipa.py VoidGram.ipa --output coverage-voidgram

The audit reads Mach-O __cstring and examines an app-specific text cluster
larger than the old AyuGram audit. It reports exact-key matches and
unmatched string candidates. Some candidates are implementation strings
and some Swift-generated labels and emoji are not contiguous C strings.

**A successful build does not guarantee 97% translation or device stability.**
97% is an objective that must be measured by on-device tests. Walk through
every root category and nested screen, pop-up, plugin, hidden option,
validation error and dynamic counter. Confirm ordinary Telegram settings
and chats are unaffected after leaving VoidGram.

## Files

- src/VoidGramArabic.m — standalone, settings-scoped hooks
- tools/build_voidgram_translations.py — packed inherited and new dictionary
- locales/voidgram-extra.json — new labels and error messages
- tools/test_voidgram_translations.py — validation checks
- tools/audit_voidgram_ipa.py — IPA inventory and candidate report
- .github/workflows/build-voidgram-arabic.yml — iOS arm64 dylib artifact
