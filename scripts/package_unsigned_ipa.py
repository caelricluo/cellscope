#!/usr/bin/env python3
"""Package an unsigned iPhoneOS archive as a verifiable IPA and manifest."""
import hashlib
import json
import plistlib
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import zipfile


def package(archive: Path, output: Path) -> Path:
    app = archive / "Products/Applications/cellscope.app"
    with (app / "Info.plist").open("rb") as file:
        info = plistlib.load(file)
    if info.get("CFBundleSupportedPlatforms") != ["iPhoneOS"]:
        raise ValueError("Only an iPhoneOS device build can be packaged; simulator builds are rejected.")
    if (app / "embedded.mobileprovision").exists() or (app / "_CodeSignature").exists():
        raise ValueError("Expected an unsigned app without provisioning assets.")
    binary = app / info["CFBundleExecutable"]
    architectures = subprocess.check_output(["xcrun", "lipo", "-archs", str(binary)], text=True).strip()
    if "arm64" not in architectures.split():
        raise ValueError("Expected the iPhone arm64 architecture.")
    build_info = subprocess.check_output(["xcrun", "vtool", "-show-build", str(binary)], text=True)
    if "platform IOS\n" not in build_info:
        raise ValueError("Mach-O platform is not iOS device.")
    version = info["CFBundleShortVersionString"]
    if not all(c.isalnum() or c in ".-_" for c in version):
        raise ValueError("Invalid version for artifact filename.")
    output.mkdir(parents=True, exist_ok=True)
    ipa = output / f"cellscope-{version}-unsigned.ipa"
    with tempfile.TemporaryDirectory(prefix="cellscope-ipa-") as temporary:
        payload = Path(temporary) / "Payload"
        payload.mkdir()
        shutil.copytree(app, payload / app.name, symlinks=True)
        subprocess.run(["/usr/bin/ditto", "-c", "-k", "--norsrc", "--keepParent", str(payload), str(ipa)], check=True)
    with zipfile.ZipFile(ipa) as archive_zip:
        if archive_zip.testzip() is not None:
            raise ValueError("IPA ZIP integrity validation failed.")
        packed_info = plistlib.loads(archive_zip.read("Payload/cellscope.app/Info.plist"))
        for language in ["en", "zh-Hans"]:
            if f"Payload/cellscope.app/{language}.lproj/Localizable.strings" not in archive_zip.namelist():
                raise ValueError(f"Missing application localization: {language}")
        if packed_info["CFBundleIdentifier"] != info["CFBundleIdentifier"]:
            raise ValueError("Packaged bundle identifier does not match the archive.")
    digest = hashlib.sha256(ipa.read_bytes()).hexdigest()
    manifest = {
        "artifact": ipa.name,
        "displayName": info["CFBundleDisplayName"],
        "languages": info.get("CFBundleLocalizations", []),
        "author": "caelricluo",
        "coAuthor": "Codex GPT-6.1 Sol",
        "version": version,
        "build": info["CFBundleVersion"],
        "bundleIdentifier": info["CFBundleIdentifier"],
        "minimumOSVersion": info["MinimumOSVersion"],
        "platform": "iPhoneOS",
        "architectures": architectures.split(),
        "signing": "unsigned",
        "installableWithoutSigning": False,
        "sha256": digest,
        "sizeBytes": ipa.stat().st_size,
        "note": "Requires valid Apple code signing and a matching provisioning profile before installation.",
    }
    ipa.with_suffix(".json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    ipa.with_suffix(".ipa.sha256").write_text(f"{digest}  {ipa.name}\n")
    print(json.dumps(manifest, indent=2, ensure_ascii=False))
    return ipa


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: package_unsigned_ipa.py ARCHIVE_PATH OUTPUT_DIRECTORY")
    package(Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve())
