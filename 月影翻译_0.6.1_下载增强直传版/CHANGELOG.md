# 月影翻译 CHANGELOG

## v0.6.1

- 修复 Qwen GGUF 模型下载连接超时配置：显式设置 90 秒连接超时。
- 模型下载自动在 Hugging Face 与备用镜像之间回退。
- 支持 `.part` 断点续传，下载中断后再次点击可继续。
- 新增“导入本地 GGUF”：可先用浏览器/电脑下载模型，再通过 Android 系统文件选择器导入。
- 下载错误改为中文可读提示，不再直接显示冗长 DioException。
- 本地 AI 翻译仍为 Qwen3-0.6B + llama.cpp，不需要 API Key。

# 月影翻译 CHANGELOG

## v0.6.0 — 本地 AI 翻译版

- **移除 ML Kit Translation 本地翻译链路**，不再使用其语言模型、Language ID 与 Translator API。
- 新增 **本地 AI（无需 Key）** 引擎：`Qwen3-0.6B Q4_0 + llama.cpp`。
- 模型约 429 MB，首次在设置中下载一次，之后翻译推理完全在设备上进行，不需要 API Key，也不需要网络。
- 本地 AI 支持现有三种风格：自然 / 正式 / 学术。
- 保留 Google ML Kit **Text Recognition** 作为 Android 本地 OCR；OCR 与翻译现在是两条独立链路。
- Android 最低版本调整为 API 26（Android 8.0），NDK 固定为 r27c 以满足 llama.cpp Flutter 插件要求。
- 旧设置中的 `mlkit_local` / `mock` 会自动迁移到 `local_qwen`。
- 保留 DeepL、Microsoft Translator、Google Cloud Translation 与 OpenAI-compatible 在线引擎。
- GitHub Actions 改为自动查找 `version: 0.6.0+*` 的月影翻译工程，并构建 ARM64 APK。

## v0.5.x

- Android 悬浮球、截图、OCR、语音输入、TTS、多在线引擎等 MVP 能力。
