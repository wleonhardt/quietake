#!/usr/bin/env python3
"""Inspect the actual Play bundle without printing matching private content."""

import argparse
from pathlib import Path
import re
import struct
import subprocess
import sys
import xml.etree.ElementTree as ET
import zipfile


def manifest_errors(xml, expected_id):
    root = ET.fromstring(xml)
    application = root.find("application")
    sdk = root.find("uses-sdk")
    if application is None or sdk is None:
        raise ValueError("Missing Android manifest nodes")
    android = "{http://schemas.android.com/apk/res/android}"
    errors = []
    if root.get("package") != expected_id:
        errors.append("Package ID does not match the approved public identity")
    if expected_id.endswith(".dev") or expected_id.startswith("com.example."):
        errors.append("Development/example package ID is not a public release identity")
    if int(sdk.get(android + "targetSdkVersion", "0")) < 36:
        errors.append("Target SDK is below the current Play minimum (36)")
    broad_storage = {"READ_EXTERNAL_STORAGE", "WRITE_EXTERNAL_STORAGE", "MANAGE_EXTERNAL_STORAGE",
                     "READ_MEDIA_IMAGES", "READ_MEDIA_VIDEO", "READ_MEDIA_AUDIO"}
    if any(node.get(android + "name", "").removeprefix("android.permission.") in broad_storage
           for node in root.findall("uses-permission")):
        errors.append("Broad shared-media/storage permissions are not needed for private capture")
    if any(node.get(android + "name", "").endswith(".MediaNotificationService")
           for node in application.findall("service")):
        errors.append("Obsolete Cast notification service is declared")
    if any(node.get(android + "name", "").startswith("android.permission.FOREGROUND_SERVICE")
           for node in root.findall("uses-permission")):
        errors.append("Ordinary backup workers do not need foreground-service permissions")
    if any(node.get(android + "name") == "androidx.work.impl.foreground.SystemForegroundService"
           for node in application.findall("service")):
        errors.append("Unused WorkManager foreground service is declared")
    if application.get(android + "debuggable", "false") != "false":
        errors.append("Debuggable builds are not public release artifacts")
    if (application.get(android + "allowBackup") != "false"
            or application.get(android + "fullBackupContent") != "false"
            or not application.get(android + "dataExtractionRules")):
        errors.append("Explicit OS backup and transfer exclusions are required")
    return errors


def archive_errors(bundle, forbidden=()):
    errors = []
    with zipfile.ZipFile(bundle) as archive:
        for entry in archive.infolist():
            name = entry.filename
            parts = Path(name).parts
            if any(p in {"test_fixtures", "test_support", "integration_test", ".git", "plans"}
                   or p.startswith(".env") for p in parts):
                errors.append(f"Non-production content: {name}")
                continue
            if re.search(r"(?:key\.properties|\.keyfile\.json|\.shtr|\.(?:jks|keystore|p12|pfx|pem))$", name):
                errors.append(f"Private file: {name}")
                continue
            if entry.is_dir():
                continue
            data = archive.read(entry)
            if any(term.lower() in data.lower() for term in forbidden):
                errors.append(f"Forbidden content: {name}")
            if name.endswith(".so") and any(abi in parts for abi in ("arm64-v8a", "x86_64")):
                try:
                    if data[:6] != b"\x7fELF\x02\x01":
                        raise ValueError()
                    offset = struct.unpack_from("<Q", data, 32)[0]
                    size, count = struct.unpack_from("<HH", data, 54)
                    loads = 0
                    for index in range(count):
                        header = offset + index * size
                        if struct.unpack_from("<I", data, header)[0] != 1:
                            continue
                        loads += 1
                        file_offset, address = struct.unpack_from("<QQ", data, header + 8)
                        alignment = struct.unpack_from("<Q", data, header + 48)[0]
                        if alignment < 16384 or (address - file_offset) % 16384:
                            errors.append(f"Native LOAD segment is not 16 KB aligned: {name}")
                            break
                    if not loads:
                        raise ValueError()
                except (ValueError, struct.error):
                    errors.append(f"Invalid native ELF headers: {name}")
    return errors


def command(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.PIPE).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", type=Path)
    parser.add_argument("--application-id", required=True, help="Approved permanent Play package ID")
    parser.add_argument("--forbid-text", action="append", default=[], help="Local audit term; matches are redacted")
    args = parser.parse_args()
    try:
        errors = archive_errors(args.bundle, tuple(t.encode() for t in args.forbid_text))
        command("bundletool", "validate", f"--bundle={args.bundle}")

        manifest = command("bundletool", "dump", "manifest", f"--bundle={args.bundle}")
        errors.extend(manifest_errors(manifest, args.application_id))
        config = command("bundletool", "dump", "config", f"--bundle={args.bundle}")
        if "PAGE_ALIGNMENT_16K" not in config:
            errors.append("Bundle does not request 16 KB native ZIP alignment")
        verification = command("jarsigner", "-J-Duser.language=en", "-verify", str(args.bundle))
        if "jar verified." not in verification:
            errors.append("Bundle is unsigned or its JAR signature is invalid")
        else:
            certificate = command("keytool", "-J-Duser.language=en", "-printcert", "-jarfile", str(args.bundle))
            if "CN=Android Debug" in certificate:
                errors.append("Bundle uses an Android debug signing certificate")
    except (OSError, ValueError, ET.ParseError, zipfile.BadZipFile, subprocess.CalledProcessError):
        print("Bundle inspection failed; check the file and bundletool/JDK installation.", file=sys.stderr)
        return 1
    for error in errors:
        print(error, file=sys.stderr)
    if errors:
        return 1
    print("Bundle checks passed. Store policy declarations and runtime device tests remain separate gates.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
