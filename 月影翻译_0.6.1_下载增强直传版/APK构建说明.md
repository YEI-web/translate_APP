# 月影翻译 v0.6.1 APK 构建说明

推荐使用项目自带 GitHub Actions：

`.github/workflows/build-android-apk.yml`

## GitHub Actions

1. 把 `MoonShadowTranslate_0.6.0` 上传到源码分支，例如 `dev1`。
2. 把工作流文件放在仓库 `.github/workflows/build-android-apk.yml`。
3. 进入 GitHub → Actions → **Build 月影翻译 Android APK**。
4. 点击 **Run workflow**。
5. `source_ref` 填/选 `dev1`（或你真正上传源码的分支）。
6. 等待构建完成。
7. 页面底部下载 Artifact：`月影翻译-Android-v0.6.1`。

APK 文件：

`月影翻译-Android-v0.6.1-arm64.apk`

## 为什么只构建 ARM64

本地 AI 引擎包含 llama.cpp 原生代码。当前个人测试版先针对主流 64 位 Android 手机，减少 APK 体积和 native ABI 变量。后续稳定后再考虑 Universal APK。

## 注意

Qwen GGUF 模型**不会打包进 APK**。安装 APK 后由用户在“设置”里下载约 429 MB 的模型，这样 APK 本身不会膨胀数百 MB。
