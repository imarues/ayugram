#!/usr/bin/env python3
"""Conservative static audit: python3 tools/audit_ipa.py AyuGramm-last.ipa"""
import argparse, json, pathlib, re, zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
a = argparse.ArgumentParser()
a.add_argument("ipa")
a.add_argument("--output", default="coverage")
args = a.parse_args()
with zipfile.ZipFile(args.ipa) as z:
    matches = [n for n in z.namelist() if n.endswith(
        "TelegramUIFramework.framework/TelegramUIFramework")]
    if len(matches) != 1:
        raise SystemExit("Expected a single TelegramUIFramework executable")
    raw = z.read(matches[0])

needles = [raw.find(s) for s in (b"AyuGram settings\x00",
    b"Ghost Mode by chat\x00", b"SettingsUI.AyuCodePluginDetailsController\x00")]
needles = [p for p in needles if p >= 0]
if not needles:
    raise SystemExit("AyuGram settings text was not found")
start = max(0, min(needles) - 25000)
end = min(len(raw), max(needles) + 185000)
excluded = ("SettingsUI.", "submodules/", "AyuGram.", "AyuGram/",
    "Item List/", "Chat/", "Chat List/", "https://", "http://", "ayu.")
strings = set()
for m in re.compile(rb"[\x20-\x7e]{4,}\x00").finditer(raw, start, end):
    x = m.group()[:-1].decode("utf-8", "ignore").strip()
    if not x or len(x) > 280 or x.startswith(excluded): continue
    if not re.search(r"[A-Za-z]", x): continue
    if " " not in x and not x[0].isupper(): continue
    if re.search(r"^[a-z]+\.[A-Za-z][A-Za-z0-9._]+$", x): continue
    strings.add(x)

translations = {}
for p in sorted((ROOT/"locales").glob("ar-*.json")):
    translations.update(json.loads(p.read_text(encoding="utf-8")))
covered = strings & translations.keys()
missing = strings - translations.keys()
dest = pathlib.Path(args.output)
dest.mkdir(parents=True, exist_ok=True)
(dest/"all-candidates.txt").write_text("\n".join(sorted(strings))+"\n")
(dest/"untranslated-candidates.txt").write_text("\n".join(sorted(missing))+"\n")
report = {"extracted_candidates":len(strings), "dictionary_matches":len(covered),
          "unmatched_candidates":len(missing),
          "static_estimated_coverage":round(100*len(covered)/max(1,len(strings)),1),
          "disclaimer":"Conservative heuristic; some entries are not actual UI text and some UI text is not extracted."}
(dest/"summary.json").write_text(json.dumps(report,indent=2)+"\n")
print(json.dumps(report,indent=2))
