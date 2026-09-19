#!/usr/bin/env python3
"""Apply 月影翻译's Android native bridge after `flutter create .`.

The script detects the generated Android namespace, rewrites Kotlin package names,
installs the Android manifest/services and adds the on-device ML Kit OCR dependencies. Local translation runs through llama.cpp in Flutter, not ML Kit Translation.
"""
from __future__ import annotations

import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ANDROID = ROOT / "android"
APP = ANDROID / "app"
PATCH = ROOT / "android_patch" / "app" / "src" / "main"
DEFAULT_PACKAGE = "com.omnitranslate.omnitranslate"


def detect_namespace() -> str:
    candidates = [APP / "build.gradle.kts", APP / "build.gradle"]
    patterns = [
        re.compile(r'namespace\s*=\s*["\']([^"\']+)["\']'),
        re.compile(r'namespace\s+["\']([^"\']+)["\']'),
        re.compile(r'applicationId\s*=\s*["\']([^"\']+)["\']'),
        re.compile(r'applicationId\s+["\']([^"\']+)["\']'),
    ]
    for path in candidates:
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8")
        for pattern in patterns:
            match = pattern.search(text)
            if match:
                return match.group(1)
    return DEFAULT_PACKAGE


def patch_gradle() -> None:
    kotlin = APP / "build.gradle.kts"
    groovy = APP / "build.gradle"
    path = kotlin if kotlin.exists() else groovy if groovy.exists() else None
    if path is None:
        raise SystemExit("找不到 android/app/build.gradle.kts 或 build.gradle")

    text = path.read_text(encoding="utf-8")
    backup = path.with_name(path.name + ".before_moonshadow")
    shutil.copy2(path, backup)

    # Local llama.cpp requires Android API 26+; ML Kit OCR also works at this level.
    text = re.sub(r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 26', text)
    text = re.sub(r'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 26', text)
    text = re.sub(r'minSdk\s*=\s*\d+', 'minSdk = 26', text)
    text = re.sub(r'minSdkVersion\s+\d+', 'minSdkVersion 26', text)

    # llama_flutter_android requires NDK r27+ (r27c pinned for reproducible CI builds).
    text = re.sub(r'ndkVersion\s*=\s*flutter\.ndkVersion', 'ndkVersion = \"27.2.12479018\"', text)

    dependency_specs = [
        ("com.google.mlkit:text-recognition:16.0.1", "text-recognition:16.0.1"),
        ("com.google.mlkit:text-recognition-chinese:16.0.1", "text-recognition-chinese:16.0.1"),
        ("com.google.mlkit:text-recognition-japanese:16.0.1", "text-recognition-japanese:16.0.1"),
        ("com.google.mlkit:text-recognition-korean:16.0.1", "text-recognition-korean:16.0.1"),
    ]
    missing = [(marker, suffix) for marker, suffix in dependency_specs if marker not in text]
    if missing:
        if path.suffix == ".kts":
            body = "\n".join(f'    implementation("com.google.mlkit:{suffix}")' for _, suffix in missing)
        else:
            body = "\n".join(f"    implementation 'com.google.mlkit:{suffix}'" for _, suffix in missing)
        text += f"\n\ndependencies {{\n{body}\n}}\n"

    # Keep release shrinking disabled while the native llama.cpp path is being validated
    # across more devices. This favors reliability over APK size for the personal build.
    if path.suffix == ".kts":
        marker = "// MOONSHADOW_LOCAL_AI_RELEASE"
        if marker not in text:
            text += f"""\n\n{marker}\nandroid {{\n    buildTypes {{\n        getByName(\"release\") {{\n            isMinifyEnabled = false\n            isShrinkResources = false\n        }}\n    }}\n}}\n"""
    else:
        marker = "// MOONSHADOW_LOCAL_AI_RELEASE"
        if marker not in text:
            text += f"""\n\n{marker}\nandroid {{\n    buildTypes {{\n        release {{\n            minifyEnabled false\n            shrinkResources false\n        }}\n    }}\n}}\n"""

    path.write_text(text, encoding="utf-8")
    print(f"Patched Gradle -> {path.relative_to(ROOT)} (minSdk 26 + NDK r27c + ML Kit OCR)")


def main() -> None:
    if not APP.exists():
        raise SystemExit(
            "android/ 不存在。请先在项目根目录运行 `flutter create --platforms=android --org com.moonshadow.translate .`，然后再运行本脚本。"
        )

    namespace = detect_namespace()
    main_dir = APP / "src" / "main"
    manifest_target = main_dir / "AndroidManifest.xml"
    if manifest_target.exists():
        backup = manifest_target.with_suffix(".xml.before_moonshadow")
        shutil.copy2(manifest_target, backup)
        print(f"Backed up manifest -> {backup.relative_to(ROOT)}")

    shutil.copy2(PATCH / "AndroidManifest.xml", manifest_target)

    target_kotlin = main_dir / "kotlin" / Path(*namespace.split("."))
    target_kotlin.mkdir(parents=True, exist_ok=True)
    source_kotlin = PATCH / "kotlin" / Path(*DEFAULT_PACKAGE.split("."))
    for source in source_kotlin.glob("*.kt"):
        text = source.read_text(encoding="utf-8").replace(
            f"package {DEFAULT_PACKAGE}", f"package {namespace}"
        )
        # Keep explicit broadcast action unique if the generated package differs.
        text = text.replace(
            "com.omnitranslate.omnitranslate.CAPTURE_COMPLETE",
            f"{namespace}.CAPTURE_COMPLETE",
        )
        target = target_kotlin / source.name
        target.write_text(text, encoding="utf-8")
        print(f"Installed {target.relative_to(ROOT)}")

    # Remove the default MainActivity if the namespace changed and it lives elsewhere.
    for existing in (main_dir / "kotlin").rglob("MainActivity.kt"):
        if existing.parent != target_kotlin:
            try:
                existing.unlink()
                print(f"Removed old {existing.relative_to(ROOT)}")
            except OSError:
                pass

    patch_gradle()

    print(f"Android native bridge installed for namespace: {namespace}")
    print("Next: flutter pub get && flutter analyze && flutter run -d <android-device>")


if __name__ == "__main__":
    main()
