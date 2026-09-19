# 月影翻译 Android 配置说明（v0.6.1）

## 本地翻译方案

v0.6.1 已彻底移除 ML Kit Translation，改用：

- `llama_flutter_android ^0.2.6`
- llama.cpp
- Qwen3-0.6B Q4_0 GGUF

本地 OCR 仍使用 ML Kit Text Recognition，与翻译引擎无关。

## Android 要求

- Android 8.0 / API 26 或更高
- 当前 APK 重点构建 ARM64
- NDK r27+
- 首次下载本地模型时需要联网与约 450 MB 可用存储空间
- 本地推理还会占用额外运行内存，具体速度取决于 CPU/内存

## 本地构建

项目根目录：

```bash
flutter create --platforms=android --org com.moonshadow.translate --no-pub .
flutter pub get
dart run flutter_launcher_icons -f tooling/flutter_launcher_icons_android.yaml
python3 tooling/apply_android_patch.py
python3 tooling/verify_source.py
python3 tooling/preflight_android.py
flutter build apk --release --target-platform android-arm64
```

Windows 可以运行：

```powershell
.\tooling\build_android_release.ps1
```

macOS/Linux：

```bash
bash tooling/build_android_release.sh
```

## 首次使用本地 AI

安装 APK 后：

1. 打开 **设置**。
2. 点击 **本地 AI 翻译模型 → 下载**。
3. 等待约 429 MB 模型下载完成。
4. 回到主页选择 **本地 AI（无需 Key）**。
5. 翻译“你好”等文本进行测试。

模型下载完成后可以关闭网络继续使用本地翻译。
