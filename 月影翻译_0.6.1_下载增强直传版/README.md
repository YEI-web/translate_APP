# 月影翻译

月影翻译是一个面向个人使用的跨平台翻译工具。当前重点把 Android 做到可日用，同时保留 Windows / macOS / Linux / Web / iOS 的 Flutter 共用核心。

## v0.6.0 重点：真正无 Key 的本地翻译

本版不再使用 ML Kit Translation。Android 的默认翻译引擎改为：

**本地 AI（无需 Key） = Qwen3-0.6B Q4_0 + llama.cpp**

使用方式：

1. 首次安装后打开 **设置**。
2. 找到 **本地 AI 翻译模型（无需 API Key）**。
3. 点击 **下载**，下载约 429 MB 的 GGUF 模型。
4. 回到翻译页，把引擎选为 **本地 AI（无需 Key）**。
5. 之后翻译推理在手机本机完成；模型已下载时可以断网使用。

> 模型下载本身第一次需要联网。模型文件较大，而且本地推理会占用明显高于普通翻译 App 的内存；老旧/32 位 Android 设备不作为当前支持目标。

## 当前翻译引擎

- **本地 AI（无需 Key）**：Android 本地运行，默认推荐。
- DeepL：需要用户自己的 API Key。
- Microsoft Translator：需要用户自己的 API Key。
- Google Cloud Translation：需要用户自己的 API Key。
- AI / OpenAI-compatible：需要用户自己的 API Key / 兼容服务。

演示引擎已删除。

## 翻译风格

只保留三个：

- 自然
- 正式
- 学术

其中本地 AI 与 OpenAI-compatible 引擎能更明显地响应风格指令；传统机器翻译引擎对风格控制较弱。

## Android 当前能力

- 文本翻译
- 本地 AI 无 Key 翻译
- 分享文字 / Android“处理文字”入口
- 悬浮球快捷面板
- 屏幕截图翻译
- 本地 OCR（ML Kit Text Recognition，仅 OCR）
- 单次语音输入翻译
- 系统 TTS 朗读译文
- 翻译历史、本地设置

## 本地翻译与本地 OCR 的区别

v0.6.0 起：

- **翻译**：Qwen3 + llama.cpp
- **OCR**：ML Kit Text Recognition

因此即使以后 OCR 仍显示 ML Kit，它也只负责从图片识别文字，不再负责翻译。

## Android 构建要求

- Flutter 3.24+
- Android API 26+
- Java 17
- Android NDK r27+
- CMake

GitHub Actions 已配置 NDK r27c（`27.2.12479018`）。

### GitHub Actions

把项目目录上传到你的源码分支（例如 `dev1`），并将：

`.github/workflows/build-android-apk.yml`

放到仓库默认分支可识别的位置。运行工作流时把 `source_ref` 选成包含 v0.6.0 源码的分支。

构建成功后附件名：

`月影翻译-Android-v0.6.0`

其中 APK：

`月影翻译-Android-v0.6.0-arm64.apk`

## 隐私

- 本地 AI 模式：模型推理在设备上完成。
- 本地 OCR：图片 OCR 在设备上完成。
- 开启“本地 OCR 失败后允许云端回退”后，失败截图才可能发送到你配置的 AI 服务。
- 在线翻译引擎会把待翻译文本发送到对应服务商。

## 仍在开发

- 连续实时字幕
- Android 内部音频翻译
- 完整悬浮译文面板
- 桌面端本地 AI 模型支持
- iOS 本地推理适配
- 模型下载断点续传 / 镜像源选择


## 新仓库结构

推荐把本项目文件直接放在 GitHub 仓库根目录，不再使用版本号子目录。GitHub Actions 配置位于 `.github/workflows/build-android-apk.yml`。详见《新仓库上传说明.md》。

## v0.6.1 模型下载增强

本地 AI 模型下载现在支持：

- 90 秒连接超时；
- Hugging Face → 备用镜像自动回退；
- `.part` 断点续传；
- Android 系统文件选择器手动导入 GGUF。

如果手机网络无法访问 Hugging Face，可在浏览器或电脑下载 `Qwen3-0.6B-Q4_0.gguf`，传到手机后在“设置 → 本地 AI 翻译模型 → 导入本地 GGUF”中选择即可。
