#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
  echo "错误：未找到 Flutter。请先安装 Flutter，并确保 flutter 已加入 PATH。" >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "错误：未找到 python3。" >&2
  exit 1
fi

mkdir -p dist

echo "[1/8] Flutter 环境检查"
flutter --version
flutter doctor -v || true

echo "[2/8] 生成 Android 平台工程"
flutter create --platforms=android --org com.moonshadow.translate --no-pub .

echo "[3/8] 获取依赖"
flutter pub get

echo "[4/8] 生成月影翻译应用图标"
dart run flutter_launcher_icons -f tooling/flutter_launcher_icons_android.yaml

echo "[5/8] 安装 Android 原生桥接、权限、本地 OCR 与本地 AI 运行配置"
python3 tooling/apply_android_patch.py

echo "[6/8] 源码结构自检"
python3 tooling/verify_source.py

echo "[7/8] Flutter 静态分析"
flutter analyze --no-fatal-infos --no-fatal-warnings

echo "[8/8] 构建 Release APK"
flutter build apk --release --target-platform android-arm64

SRC="build/app/outputs/flutter-apk/app-release.apk"
DST="dist/月影翻译-Android-v0.6.0.apk"
cp "$SRC" "$DST"
printf '\n构建完成：%s\n' "$(pwd)/$DST"
