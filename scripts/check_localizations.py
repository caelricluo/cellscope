#!/usr/bin/env python3
"""Validate cellscope localization keys and formatted argument parity."""
from pathlib import Path
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent

def read(language):
    path = ROOT / "cellscope" / f"{language}.lproj" / "Localizable.strings"
    return json.loads(subprocess.check_output(["plutil", "-convert", "json", "-o", "-", str(path)]))

def main():
    english, chinese = read("en"), read("zh-Hans")
    assert english.keys() == chinese.keys(), "Localization key sets differ"
    pattern = re.compile(r"%(?:\d+\$)?(?:ld|@|d|f|s)")
    for key in english:
        assert english[key] and chinese[key], f"Empty translation: {key}"
        assert sorted(pattern.findall(english[key])) == sorted(pattern.findall(chinese[key])), f"Format mismatch: {key}"
    used = set()
    for base in [ROOT / "cellscope", ROOT / "Sources"]:
        for source in base.rglob("*.swift"):
            for match in re.finditer(r'trf?\("((?:[^"\\]|\\.)*)"', source.read_text()):
                used.add(json.loads('"' + match[1] + '"'))
    assert not used - english.keys(), f"Missing keys: {used - english.keys()}"
    print(f"Validated {len(english)} keys in English and Simplified Chinese; {len(used)} referenced keys.")

if __name__ == "__main__":
    main()
