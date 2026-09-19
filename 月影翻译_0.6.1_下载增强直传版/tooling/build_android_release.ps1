$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "未找到 Flutter。请先安装 Flutter，并把 flutter\bin 加入 PATH。"
}

New-Item -ItemType Directory -Force -Path "dist" | Out-Null

Write-Host "[1/8] Flutter 环境检查"
flutter --version
flutter doctor -v

Write-Host "[2/8] 生成 Android 平台工程"
flutter create --platforms=android --org com.moonshadow.translate --no-pub .

Write-Host "[3/8] 获取依赖"
flutter pub get

Write-Host "[4/8] 生成月影翻译应用图标"
dart run flutter_launcher_icons -f tooling/flutter_launcher_icons_android.yaml

Write-Host "[5/8] 安装 Android 原生桥接、权限、本地 OCR 与本地 AI 运行配置"
if (Get-Command py -ErrorAction SilentlyContinue) {
    py tooling/apply_android_patch.py
} elseif (Get-Command python -ErrorAction SilentlyContinue) {
    python tooling/apply_android_patch.py
} else {
    throw "未找到 Python。请安装 Python 3。"
}

Write-Host "[6/8] 源码结构自检"
if (Get-Command py -ErrorAction SilentlyContinue) {
    py tooling/verify_source.py
} else {
    python tooling/verify_source.py
}

Write-Host "[7/8] Flutter 静态分析"
flutter analyze --no-fatal-infos --no-fatal-warnings

Write-Host "[8/8] 构建 Release APK"
flutter build apk --release --target-platform android-arm64

$src = "build\app\outputs\flutter-apk\app-release.apk"
$dst = "dist\月影翻译-Android-v0.6.0.apk"
Copy-Item $src $dst -Force
Write-Host ""
Write-Host "构建完成：$PWD\$dst"
