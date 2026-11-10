# AyuGram Arabic

Arabic translation tweak for AyuGram's own settings, compiled as an iOS arm64 dynamic library.
Target IPA: one.ayugram.unofficial.ios (Telegram base 13.1.1); AyuGram UI 27.5.0.

## Scope

- Only strings explicitly listed in locales/ar-*.json are translated.
- The hook covers UIKit labels, titles, alerts, text views, and attributed text.
- Common English words are translated only when an Ayu-named controller is visible.
- The translation does not change Telegram account state, message content, or app feature switches.
- No external translator, internet requests, or API keys are used.
- The default is always-on Arabic translation for mapped AyuGram strings. A user-defaults
  boolean named AyuGramArabicEnabled can disable it.

## Build

Use the public GitHub Actions workflow named Build AyuGram Arabic dylib.
The workflow uses Apple's iOS SDK and produces the AyuGramArabic.dylib artifact for
iOS 15+ arm64. The dylib must be injected and the application signed by a normal
iOS signing/injection tool; a standalone dylib is not an installable IPA.

Local macOS development:
1. python3 tools/build_translations.py
2. Compile src/AyuGramArabic.m with the iOS SDK, UIKit, Foundation and ARC.

## Coverage

This is an initial dictionary and runtime hook implementation, NOT a verified 100%
translation. The uploaded IPA contains many more settings literals. A static
inventory plus on-device review of every nested screen and pop-up is required
before claiming complete coverage. Images, dynamic strings and some custom
Swift components may need additional translation strategies.

Only the user-provided IPA should be used to validate compatibility. Do not
confuse this unofficial IPA with the App Store AyuGram bundle.
