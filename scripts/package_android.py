#!/usr/bin/env python3
"""Package verified Android APK outputs with a manifest and SHA-256 checksums."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parent.parent
VERSION = "0.7.0"

def main():
    sdk = Path(os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT") or Path.home()/"Library/Android/sdk")
    versions = sorted((sdk/"build-tools").glob("*"), key=lambda p: tuple(int(n) for n in p.name.split(".") if n.isdigit()))
    assert versions, "Android SDK build-tools are required"
    tools = versions[-1]
    dist = ROOT/"dist"
    dist.mkdir(exist_ok=True)
    artifacts = []
    for source, name, signed in [
        ("preview/app-preview.apk", f"cellscope-{VERSION}-android.apk", True),
        ("release/app-release-unsigned.apk", f"cellscope-{VERSION}-android-unsigned.apk", False),
    ]:
        apk = ROOT/"android/app/build/outputs/apk"/source
        assert apk.is_file(), f"Build missing: {apk}"
        with zipfile.ZipFile(apk) as archive:
            assert archive.testzip() is None
            assert "AndroidManifest.xml" in archive.namelist()
        badging = subprocess.check_output([str(tools/"aapt"), "dump", "badging", str(apk)], text=True)
        assert "name='com.cellscope.counter'" in badging
        assert f"versionName='{VERSION}'" in badging
        assert "sdkVersion:'26'" in badging and "targetSdkVersion:'36'" in badging
        assert "application-label:'cellscope'" in badging
        assert "application-debuggable" not in badging
        assert "android.permission.INTERNET" not in badging
        result = subprocess.run([str(tools/"apksigner"), "verify", "--verbose", "--print-certs", str(apk)], capture_output=True, text=True)
        assert (result.returncode == 0) == signed, f"Unexpected signature: {name}"
        subprocess.run([str(tools/"zipalign"), "-c", "-P", "16", "4", str(apk)], check=True)
        target = dist/name
        shutil.copyfile(apk, target)
        artifacts.append({"file": name, "bytes": target.stat().st_size, "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
                          "signing": "Android development certificate; non-debuggable build" if signed else "unsigned"})
    manifest = dist/f"cellscope-{VERSION}-android-manifest.json"
    manifest.write_text(json.dumps({"project": "cellscope", "platform": "Android", "version": VERSION,
        "minimumAndroid": "8.0 (API 26)", "targetApi": 36, "applicationId": "com.cellscope.counter",
        "author": "@caelricluo", "coauthor": "Codex GPT-6.1 Sol", "artifacts": artifacts}, indent=2)+"\n")
    checksum = dist/f"cellscope-{VERSION}-android-SHA256SUMS.txt"
    checksum.write_text("".join(f"{item['sha256']}  {item['file']}\n" for item in artifacts)+
                        f"{hashlib.sha256(manifest.read_bytes()).hexdigest()}  {manifest.name}\n")
    print(json.dumps({"artifacts": artifacts, "manifest": str(manifest), "checksums": str(checksum)}, indent=2))

if __name__ == "__main__":
    main()
