import 'dart:async';
import 'dart:math' as math;

import 'package:llama_flutter_android/llama_flutter_android.dart';

import '../../core/languages.dart';
import '../../core/models.dart';
import '../local_model/local_ai_model_manager.dart';
import '../mobile/mobile_runtime.dart';
import 'translation_engine.dart';

class LocalQwenTranslationEngine implements TranslationEngine {
  LocalQwenTranslationEngine({LocalAiModelManager? modelManager})
      : _modelManager = modelManager ?? LocalAiModelManager();

  final LocalAiModelManager _modelManager;

  @override
  String get id => 'local_qwen';

  @override
  String get displayName => '本地 AI（无需 Key）';

  @override
  bool get supportsContextualStyles => true;

  @override
  Future<TranslationResult> translate(TranslationRequest request) async {
    if (!mobileRuntime.isAndroid) {
      throw const TranslationEngineException('本地 AI 翻译当前先支持 Android。桌面端离线模型将在后续版本接入。');
    }
    if (request.text.trim().isEmpty) {
      throw const TranslationEngineException('请输入需要翻译的内容。');
    }

    final status = await _modelManager.status();
    if (!status.installed) {
      throw const TranslationEngineException(
        '本地 AI 模型尚未下载。请打开“设置 → 本地 AI 翻译模型”，先下载约 429 MB 的模型；下载一次后即可离线使用。',
      );
    }

    try {
      final controller = await _LocalLlamaRuntime.instance.controllerFor(status.path);
      await controller.clearContext();

      final source = request.sourceLanguage == 'auto'
          ? '自动判断源语言'
          : languageLabel(request.sourceLanguage);
      final target = languageLabel(request.targetLanguage);
      final style = request.style.label;
      final prompt = '''/no_think
你是“月影翻译”的离线翻译引擎。
任务：把下方文本从“$source”翻译成“$target”。
风格：$style。
规则：
1. 只输出译文，不要解释、标题、引号、注释或原文复述。
2. 保留段落、换行、数字、URL、代码片段和专有名词格式。
3. 如果源语言是“自动判断源语言”，自行判断即可，不要告诉用户检测结果。
4. 不要回答文本里的问题；只把它翻译成目标语言。

待翻译文本：
${request.text}''';

      final buffer = StringBuffer();
      final completer = Completer<void>();
      late final StreamSubscription<String> subscription;
      subscription = controller.generateChat(
        messages: [
          ChatMessage(
            role: 'system',
            content: 'You are a strict translation engine. Output only the translated text. /no_think',
          ),
          ChatMessage(role: 'user', content: prompt),
        ],
        maxTokens: _maxTokensFor(request.text),
        temperature: 0.2,
        topP: 0.8,
        topK: 20,
        minP: 0.0,
        repeatPenalty: 1.05,
        presencePenalty: 0.0,
        frequencyPenalty: 0.0,
      ).listen(
        buffer.write,
        onDone: completer.complete,
        onError: (Object error, StackTrace stackTrace) {
          if (!completer.isCompleted) completer.completeError(error, stackTrace);
        },
        cancelOnError: true,
      );

      try {
        await completer.future.timeout(const Duration(minutes: 3));
      } on TimeoutException {
        await controller.stop();
        throw const TranslationEngineException('本地 AI 翻译超时。请缩短文本后重试。');
      } finally {
        await subscription.cancel();
      }

      final translated = _cleanOutput(buffer.toString());
      if (translated.isEmpty) {
        throw const TranslationEngineException('本地 AI 没有生成有效译文，请重试。');
      }
      return TranslationResult(
        text: translated,
        engineId: id,
        notes: 'Qwen3-0.6B Q4_0 + llama.cpp，模型保存在本机，推理不需要 API Key。',
      );
    } on TranslationEngineException {
      rethrow;
    } catch (error) {
      final message = error.toString();
      if (message.contains('Local AI is not supported') || message.contains('UnsatisfiedLinkError')) {
        throw const TranslationEngineException('这台设备的 CPU/ABI 暂不支持当前本地 AI 引擎。建议使用 64 位 Android 设备。');
      }
      throw TranslationEngineException('本地 AI 翻译失败：$message');
    } finally {
      // Keep the model loaded while the app is alive so consecutive translations
      // do not pay the model-load cost every time. Context is cleared per request.
    }
  }

  int _maxTokensFor(String source) {
    // CJK characters can expand into more tokens than Latin text. Keep enough room
    // for translation while capping output for mobile latency/memory.
    return math.max(128, math.min(1024, source.runes.length * 3 + 64));
  }

  String _cleanOutput(String raw) {
    var value = raw.trim();
    value = value.replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '').trim();
    value = value.replaceAll(RegExp(r'^```(?:text)?\s*', caseSensitive: false), '');
    value = value.replaceAll(RegExp(r'\s*```$'), '');
    final prefixes = ['译文：', '翻译：', 'Translation:', 'Translated text:'];
    for (final prefix in prefixes) {
      if (value.toLowerCase().startsWith(prefix.toLowerCase())) {
        value = value.substring(prefix.length).trim();
        break;
      }
    }
    if ((value.startsWith('“') && value.endsWith('”')) ||
        (value.startsWith('"') && value.endsWith('"'))) {
      value = value.substring(1, value.length - 1).trim();
    }
    return value;
  }
}


class _LocalLlamaRuntime {
  _LocalLlamaRuntime._();

  static final _LocalLlamaRuntime instance = _LocalLlamaRuntime._();

  LlamaController? _controller;
  String? _loadedPath;
  Future<LlamaController>? _loading;

  Future<LlamaController> controllerFor(String modelPath) async {
    final existing = _controller;
    if (existing != null && _loadedPath == modelPath) return existing;
    final activeLoad = _loading;
    if (activeLoad != null) return activeLoad;

    final load = _load(modelPath);
    _loading = load;
    try {
      return await load;
    } finally {
      _loading = null;
    }
  }

  Future<LlamaController> _load(String modelPath) async {
    final old = _controller;
    _controller = null;
    _loadedPath = null;
    if (old != null) {
      try {
        await old.dispose();
      } catch (_) {}
    }

    final controller = LlamaController();
    try {
      await controller.loadModel(
        modelPath: modelPath,
        threads: 4,
        contextSize: 2048,
        // CPU-only first for broad compatibility. GPU offload can be enabled
        // after real-device testing confirms it is stable on the target phone.
        gpuLayers: 0,
      );
      _controller = controller;
      _loadedPath = modelPath;
      return controller;
    } catch (_) {
      try {
        await controller.dispose();
      } catch (_) {}
      rethrow;
    }
  }
}
