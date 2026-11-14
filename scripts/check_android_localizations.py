#!/usr/bin/env python3
"""Validate Android translations, format arguments and UI resource references."""
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "android/app/src/main/res"

def read(folder):
    entries = ET.parse(RES / folder / "strings.xml").getroot().findall("string")
    result = {entry.attrib["name"]: "".join(entry.itertext()) for entry in entries}
    assert len(result) == len(entries), f"Duplicate string in {folder}"
    return result

def main():
    en, zh = read("values"), read("values-zh")
    assert en.keys() == zh.keys(), "Android localization key sets differ"
    arguments = re.compile(r"%(?:\d+\$)?[dsf]")
    retired = ["仅供参考", "免责声明", "逐一复核", "已确认框选", "已逐一", "请自行", "不用于诊断",
               "for research use only", "not medical advice", "at your own risk", "please verify"]
    for key in en:
        assert en[key] and zh[key], f"Empty translation: {key}"
        assert sorted(arguments.findall(en[key])) == sorted(arguments.findall(zh[key])), f"Format mismatch: {key}"
        for value in (en[key], zh[key]):
            assert not any(word.casefold() in value.casefold() for word in retired), f"Retired UI copy: {key}"
    used = set()
    for source in (ROOT / "android/app/src/main").rglob("*.kt"):
        used.update(re.findall(r"R\.string\.(\w+)", source.read_text()))
    assert not used - en.keys(), f"Missing Android keys: {used - en.keys()}"
    print(f"Android: {len(en)} bilingual keys; {len(used)} referenced keys validated.")

if __name__ == "__main__":
    main()
