$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)
flutter create --platforms=android --org com.moonshadow.translate .
flutter pub get
dart run flutter_launcher_icons
if (Get-Command py -ErrorAction SilentlyContinue) { py tooling/apply_android_patch.py } else { python tooling/apply_android_patch.py }
flutter devices
flutter run
