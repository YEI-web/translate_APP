#!/usr/bin/env python3
from __future__ import annotations

import ast
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []


def check_manifest() -> None:
    path = ROOT / "android_patch/app/src/main/AndroidManifest.xml"
    try:
        ET.parse(path)
    except Exception as exc:
        errors.append(f"AndroidManifest.xml invalid: {exc}")


def check_python() -> None:
    path = ROOT / "tooling/apply_android_patch.py"
    try:
        ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    except Exception as exc:
        errors.append(f"apply_android_patch.py invalid: {exc}")


def check_dart_relative_imports() -> None:
    import_re = re.compile(r"(?:import|export|part)\s+['\"]([^'\"]+)['\"]")
    for dart in (ROOT / "lib").rglob("*.dart"):
        text = dart.read_text(encoding="utf-8")
        for match in import_re.finditer(text):
            target = match.group(1)
            if target.startswith(("dart:", "package:")):
                continue
            candidate = (dart.parent / target).resolve()
            if not candidate.exists():
                errors.append(f"Missing Dart relative import: {dart.relative_to(ROOT)} -> {target}")


def check_required_files() -> None:
    required = [
        "lib/main.dart",
        "lib/app.dart",
        "lib/services/mobile/mobile_runtime_io.dart",
        "lib/services/engines/local_qwen_engine.dart",
        "lib/services/local_model/local_ai_model_manager.dart",
        "android_patch/app/src/main/kotlin/com/omnitranslate/omnitranslate/MainActivity.kt",
        "android_patch/app/src/main/kotlin/com/omnitranslate/omnitranslate/OverlayService.kt",
        "android_patch/app/src/main/kotlin/com/omnitranslate/omnitranslate/ScreenCaptureService.kt",
        "android_patch/app/src/main/AndroidManifest.xml",
        "tooling/apply_android_patch.py",
    ]
    for name in required:
        if not (ROOT / name).exists():
            errors.append(f"Missing required file: {name}")


def main() -> int:
    check_required_files()
    check_manifest()
    check_python()
    check_dart_relative_imports()
    if errors:
        print("Source verification FAILED")
        for error in errors:
            print(f"- {error}")
        return 1
    print("Source verification OK")
    print("Note: this is a structural check, not a replacement for flutter analyze/Gradle build.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
