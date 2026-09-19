#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter create --platforms=android --org com.moonshadow.translate .
flutter pub get
dart run flutter_launcher_icons
python3 tooling/apply_android_patch.py
flutter devices
flutter run
