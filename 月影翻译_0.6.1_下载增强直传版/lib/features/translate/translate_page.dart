import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/languages.dart';
import '../../core/models.dart';
import '../../services/capture/screen_capture_service.dart';
import '../../services/desktop/desktop_runtime.dart';
import '../../services/engine_router.dart';
import '../../services/mobile/mobile_runtime.dart';
import '../../services/ocr/ocr_service.dart';
import '../../services/ocr/vision_ocr_service.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_page.dart';
import 'translate_controller.dart';

class TranslatePage extends ConsumerStatefulWidget {
  const TranslatePage({super.key});

  @override
  ConsumerState<TranslatePage> createState() => _TranslatePageState();
}

class _TranslatePageState extends ConsumerState<TranslatePage> {
  final _sourceController = TextEditingController();
  final _sourceFocus = FocusNode();
  StreamSubscription<DesktopAction>? _desktopSubscription;
  StreamSubscription<MobileIncomingText>? _mobileTextSubscription;
  StreamSubscription<MobileAction>? _mobileActionSubscription;
  bool _screenWorking = false;
  bool _voiceWorking = false;
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    _desktopSubscription = desktopRuntime.actions.listen(_handleDesktopAction);
    _mobileTextSubscription = mobileRuntime.incomingText.listen(_handleMobileIncomingText);
    _mobileActionSubscription = mobileRuntime.actions.listen(_handleMobileAction);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initialText = await mobileRuntime.consumeInitialText();
      if (initialText != null && mounted) {
        await _handleMobileIncomingText(initialText);
      }
      final initialAction = await mobileRuntime.consumeInitialAction();
      if (initialAction != null && mounted) {
        await _handleMobileAction(initialAction);
      }
      final warnings = desktopRuntime.startupWarnings;
      if (!mounted || warnings.isEmpty) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(warnings.join('\n'))),
      );
    });
  }

  @override
  void dispose() {
    _desktopSubscription?.cancel();
    _mobileTextSubscription?.cancel();
    _mobileActionSubscription?.cancel();
    unawaited(mobileRuntime.stopSpeaking());
    _sourceController.dispose();
    _sourceFocus.dispose();
    super.dispose();
  }

  Future<void> _handleDesktopAction(DesktopAction action) async {
    if (!mounted) return;
    switch (action) {
      case DesktopAction.toggleQuickPanel:
        _sourceFocus.requestFocus();
        return;
      case DesktopAction.translateClipboard:
        await _translateClipboard();
        return;
      case DesktopAction.screenTranslate:
        await _captureOcrAndTranslate();
        return;
      case DesktopAction.toggleSubtitles:
        _showComingSoon(context, '实时字幕入口已绑定到 Alt+S；下一阶段接系统音频/麦克风与流式语音识别。');
        return;
      case DesktopAction.showMainWindow:
        _sourceFocus.requestFocus();
        return;
    }
  }



  Future<void> _handleMobileAction(MobileAction action) async {
    if (!mounted) return;
    switch (action) {
      case MobileAction.screenTranslate:
        await _captureOcrAndTranslate();
        return;
      case MobileAction.voiceTranslate:
        await _voiceTranslate();
        return;
      case MobileAction.showMainWindow:
        _sourceFocus.requestFocus();
        return;
    }
  }

  Future<void> _handleMobileIncomingText(MobileIncomingText incoming) async {
    if (!mounted) return;
    final text = incoming.text.trim();
    if (text.isEmpty) return;
    await ref.read(settingsControllerProvider.notifier).ready;
    if (!mounted) return;
    final controller = ref.read(translateControllerProvider.notifier);
    _sourceController.text = text;
    controller.setSource(text);
    _sourceController.selection = TextSelection.collapsed(offset: text.length);
    _sourceFocus.requestFocus();
    await controller.translate(ref.read(settingsControllerProvider));
  }

  Future<void> _startAndroidOverlay() async {
    if (!mobileRuntime.isAndroid) return;
    var allowed = await mobileRuntime.hasOverlayPermission();
    if (!allowed) {
      allowed = await mobileRuntime.requestOverlayPermission();
    }
    if (!mounted) return;
    if (!allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('需要先授予“显示在其他应用上层”权限，才能使用悬浮翻译球。')),
      );
      return;
    }
    final started = await mobileRuntime.startOverlay();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(started ? '安卓悬浮翻译球已启动' : '悬浮翻译球启动失败')),
    );
  }

  Future<void> _translateClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!mounted) return;
    if (text.isEmpty) {
      _showComingSoon(context, '剪贴板里没有可翻译的文字。');
      return;
    }
    final controller = ref.read(translateControllerProvider.notifier);
    _sourceController.text = text;
    controller.setSource(text);
    _sourceController.selection = TextSelection.collapsed(offset: text.length);
    _sourceFocus.requestFocus();
    await controller.translate(ref.read(settingsControllerProvider));
  }

  Future<void> _captureOcrAndTranslate() async {
    if (_screenWorking) return;
    if (!screenCaptureService.isSupported) {
      _showComingSoon(context, '当前平台暂不支持系统截图翻译。');
      return;
    }
    setState(() => _screenWorking = true);
    try {
      final capture = await screenCaptureService.captureRegion();
      await desktopRuntime.showQuickPanel();
      if (!mounted || capture == null) return;

      await ref.read(settingsControllerProvider.notifier).ready;
      if (!mounted) return;
      final settings = ref.read(settingsControllerProvider);
      final ocr = OcrService(ref.read(settingsRepositoryProvider));
      final text = await ocr.recognize(capture.bytes, settings);
      if (!mounted) return;

      final controller = ref.read(translateControllerProvider.notifier);
      _sourceController.text = text;
      controller.setSource(text);
      _sourceController.selection = TextSelection.collapsed(offset: text.length);
      await controller.translate(settings);
      if (!mounted) return;
      _sourceFocus.requestFocus();
    } on OcrException catch (error) {
      await desktopRuntime.showQuickPanel();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          action: SnackBarAction(
            label: '设置',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ),
      );
    } catch (error) {
      await desktopRuntime.showQuickPanel();
      if (!mounted) return;
      _showComingSoon(context, '截图翻译失败：$error');
    } finally {
      if (mounted) setState(() => _screenWorking = false);
    }
  }

  Future<void> _voiceTranslate() async {
    if (!mobileRuntime.isAndroid || _voiceWorking) return;
    setState(() => _voiceWorking = true);
    try {
      await ref.read(settingsControllerProvider.notifier).ready;
      if (!mounted) return;
      final settings = ref.read(settingsControllerProvider);
      final text = await mobileRuntime.recognizeSpeech(
        languageTag: _speechLanguageTag(settings.sourceLanguage),
      );
      if (!mounted || text == null || text.trim().isEmpty) return;
      final controller = ref.read(translateControllerProvider.notifier);
      _sourceController.text = text.trim();
      controller.setSource(text.trim());
      _sourceController.selection = TextSelection.collapsed(offset: text.trim().length);
      await controller.translate(settings);
    } on PlatformException catch (error) {
      if (!mounted) return;
      _showComingSoon(context, error.message ?? '语音识别失败。');
    } catch (error) {
      if (!mounted) return;
      _showComingSoon(context, '语音识别失败：$error');
    } finally {
      if (mounted) setState(() => _voiceWorking = false);
    }
  }

  Future<void> _speakResult(String text, String targetLanguage) async {
    if (!mobileRuntime.isAndroid || text.trim().isEmpty) return;
    if (_speaking) {
      await mobileRuntime.stopSpeaking();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    try {
      final ok = await mobileRuntime.speak(
        text,
        languageTag: _speechLanguageTag(targetLanguage),
      );
      if (!mounted) return;
      setState(() => _speaking = ok);
      if (ok) {
        Future<void>.delayed(const Duration(seconds: 12), () {
          if (mounted) setState(() => _speaking = false);
        });
      } else {
        _showComingSoon(context, '系统朗读引擎暂不可用。');
      }
    } catch (error) {
      if (!mounted) return;
      _showComingSoon(context, '朗读失败：$error');
    }
  }

  String? _speechLanguageTag(String code) {
    return switch (code) {
      'auto' => null,
      'zh-Hans' => 'zh-CN',
      'zh-Hant' => 'zh-TW',
      'en' => 'en-US',
      'ja' => 'ja-JP',
      'ko' => 'ko-KR',
      'de' => 'de-DE',
      'fr' => 'fr-FR',
      'es' => 'es-ES',
      'it' => 'it-IT',
      'pt' => 'pt-PT',
      'ru' => 'ru-RU',
      _ => code,
    };
  }

  Future<void> _requestDesktopAction(DesktopAction action) async {
    if (mobileRuntime.isAndroid) {
      switch (action) {
        case DesktopAction.translateClipboard:
          await _translateClipboard();
          return;
        case DesktopAction.screenTranslate:
          await _captureOcrAndTranslate();
          return;
        case DesktopAction.toggleQuickPanel:
          await _startAndroidOverlay();
          return;
        case DesktopAction.toggleSubtitles:
          _showComingSoon(context, '当前版本已支持一句话语音输入翻译；连续实时字幕将在下一阶段接入 AudioPlaybackCapture。');
          return;
        case DesktopAction.showMainWindow:
          return;
      }
    }
    if (!desktopRuntime.isSupported) {
      switch (action) {
        case DesktopAction.translateClipboard:
          await _translateClipboard();
          return;
        case DesktopAction.screenTranslate:
          _showComingSoon(context, '当前平台暂未接入系统截图翻译。');
          return;
        case DesktopAction.toggleSubtitles:
          _showComingSoon(context, '移动端实时字幕将在媒体阶段单独接入。');
          return;
        case DesktopAction.toggleQuickPanel:
        case DesktopAction.showMainWindow:
          _showComingSoon(context, '悬浮工具目前支持 Windows、macOS、Linux 和 Android。');
          return;
      }
      return;
    }
    await desktopRuntime.perform(action);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DesktopWindowMode>(
      valueListenable: desktopRuntime.mode,
      builder: (context, desktopMode, _) {
        return _buildPage(context, desktopMode == DesktopWindowMode.quickPanel);
      },
    );
  }

  Widget _buildPage(BuildContext context, bool quickMode) {
    final state = ref.watch(translateControllerProvider);
    final controller = ref.read(translateControllerProvider.notifier);
    final settings = ref.watch(settingsControllerProvider);
    final settingsController = ref.read(settingsControllerProvider.notifier);
    final wide = !quickMode && MediaQuery.sizeOf(context).width >= 900;

    final input = _Pane(
      header: Row(
        children: [
          const Icon(Icons.notes, size: 18),
          const SizedBox(width: 8),
          _LanguageDropdown(
            value: settings.sourceLanguage,
            options: sourceLanguages,
            onChanged: (value) {
              if (value != null) settingsController.patch((s) => s.copyWith(sourceLanguage: value));
            },
          ),
          const Spacer(),
          if (mobileRuntime.isAndroid)
            IconButton(
              tooltip: '语音输入翻译',
              onPressed: _voiceWorking ? null : _voiceTranslate,
              icon: _voiceWorking
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.mic_none_outlined),
            ),
          IconButton(
            tooltip: '粘贴',
            onPressed: () async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              final text = data?.text ?? '';
              if (text.isNotEmpty) {
                _sourceController.text = text;
                controller.setSource(text);
              }
            },
            icon: const Icon(Icons.content_paste_go_outlined),
          ),
          IconButton(
            tooltip: '清空',
            onPressed: state.source.isEmpty
                ? null
                : () {
                    _sourceController.clear();
                    controller.clear();
                  },
            icon: const Icon(Icons.clear),
          ),
        ],
      ),
      child: TextField(
        controller: _sourceController,
        focusNode: _sourceFocus,
        minLines: quickMode ? 3 : (wide ? 14 : 7),
        maxLines: null,
        autofocus: true,
        onChanged: controller.setSource,
        decoration: InputDecoration(
          hintText: mobileRuntime.isAndroid ? '输入、粘贴，或从其他 App 分享/处理文字…' : '输入、粘贴，或按 Alt+Q 翻译剪贴板…',
          filled: false,
          border: InputBorder.none,
        ),
      ),
    );

    final output = _Pane(
      header: Row(
        children: [
          const Icon(Icons.translate, size: 18),
          const SizedBox(width: 8),
          _LanguageDropdown(
            value: settings.targetLanguage,
            options: targetLanguages,
            onChanged: (value) {
              if (value != null) settingsController.patch((s) => s.copyWith(targetLanguage: value));
            },
          ),
          const Spacer(),
          if (state.usedEngineId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                engineLabel(state.usedEngineId),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          if (mobileRuntime.isAndroid)
            IconButton(
              tooltip: _speaking ? '停止朗读' : '朗读译文',
              onPressed: state.result.isEmpty ? null : () => _speakResult(state.result, settings.targetLanguage),
              icon: Icon(_speaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined),
            ),
          IconButton(
            tooltip: '复制译文',
            onPressed: state.result.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: state.result));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('译文已复制')));
                  },
            icon: const Icon(Icons.copy_all_outlined),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          state.result.isEmpty ? '译文会显示在这里' : state.result,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.65),
        ),
      ),
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () => controller.translate(settings),
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): () => controller.translate(settings),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: Text(quickMode ? '快速翻译' : '月影翻译'),
            actions: [
              IconButton(
                onPressed: _screenWorking ? null : () => _requestDesktopAction(DesktopAction.screenTranslate),
                tooltip: mobileRuntime.isAndroid ? '屏幕翻译' : '截图翻译（Alt+A）',
                icon: _screenWorking
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.crop_free),
              ),
              if (!quickMode)
                IconButton(
                  onPressed: () => _requestDesktopAction(DesktopAction.toggleSubtitles),
                  tooltip: mobileRuntime.isAndroid ? '实时字幕' : '实时字幕（Alt+S）',
                  icon: const Icon(Icons.subtitles_outlined),
                ),
              if (!quickMode)
                IconButton(
                  onPressed: () => _showHistory(context, ref, _sourceController),
                  tooltip: '历史记录',
                  icon: const Icon(Icons.history),
                ),
              if (!quickMode)
                IconButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
                  tooltip: '设置',
                  icon: const Icon(Icons.settings_outlined),
                ),
              if (quickMode && desktopRuntime.isSupported)
                IconButton(
                  onPressed: desktopRuntime.showMainWindow,
                  tooltip: '打开主窗口',
                  icon: const Icon(Icons.open_in_full),
                ),
              if (quickMode && desktopRuntime.isSupported)
                IconButton(
                  onPressed: desktopRuntime.hideWindow,
                  tooltip: '隐藏',
                  icon: const Icon(Icons.close),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(quickMode ? 10 : 16, 8, quickMode ? 10 : 16, quickMode ? 10 : 16),
              child: Column(
                children: [
                  if (!quickMode) ...[
                    _FeatureStrip(
                      isAndroid: mobileRuntime.isAndroid,
                      onAction: _requestDesktopAction,
                      onUnavailable: (message) => _showComingSoon(context, message),
                      onVoice: mobileRuntime.isAndroid ? _voiceTranslate : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_screenWorking) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                  ],
                  if (state.error != null) ...[
                    MaterialBanner(
                      content: Text(state.error!),
                      leading: const Icon(Icons.error_outline),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
                          child: const Text('打开设置'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Expanded(
                    child: quickMode
                        ? Column(
                            children: [
                              Expanded(child: input),
                              const SizedBox(height: 8),
                              Expanded(child: output),
                            ],
                          )
                        : wide
                            ? Row(
                                children: [
                                  Expanded(child: input),
                                  const SizedBox(width: 12),
                                  Expanded(child: output),
                                ],
                              )
                            : ListView(
                                children: [
                                  SizedBox(height: 320, child: input),
                                  const SizedBox(height: 12),
                                  SizedBox(height: 300, child: output),
                                ],
                              ),
                  ),
                  const SizedBox(height: 10),
                  _BottomBar(
                    settings: settings,
                    isLoading: state.isLoading,
                    compact: quickMode,
                    onEngineChanged: (value) {
                      if (value != null) settingsController.patch((s) => s.copyWith(selectedEngineId: value));
                    },
                    onStyleChanged: (value) {
                      if (value != null) settingsController.patch((s) => s.copyWith(style: value));
                    },
                    onTranslate: () => controller.translate(settings),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.settings,
    required this.isLoading,
    required this.compact,
    required this.onEngineChanged,
    required this.onStyleChanged,
    required this.onTranslate,
  });

  final AppSettings settings;
  final bool isLoading;
  final bool compact;
  final ValueChanged<String?> onEngineChanged;
  final ValueChanged<TranslationStyle?> onStyleChanged;
  final VoidCallback onTranslate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final controls = [
          DropdownButton<String>(
            value: settings.selectedEngineId,
            underline: const SizedBox.shrink(),
            items: [
              for (final engine in engineOptions) DropdownMenuItem(value: engine.id, child: Text(engine.label)),
            ],
            onChanged: isLoading ? null : onEngineChanged,
          ),
          const SizedBox(width: 10),
          if (!compact)
            DropdownButton<TranslationStyle>(
              value: settings.style,
              underline: const SizedBox.shrink(),
              items: [
                for (final style in TranslationStyle.values)
                  DropdownMenuItem(value: style, child: Text('风格：${style.label}')),
              ],
              onChanged: isLoading ? null : onStyleChanged,
            ),
          if (!compact) const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: isLoading ? null : onTranslate,
            icon: isLoading
                ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: Text(compact || mobileRuntime.isAndroid ? '翻译' : '翻译  Ctrl/⌘ + Enter'),
          ),
        ];

        if (!compact && constraints.maxWidth >= 720) {
          return Row(children: [const Text('翻译引擎'), const SizedBox(width: 8), ...controls]);
        }
        return Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: controls);
      },
    );
  }
}

class _Pane extends StatelessWidget {
  const _Pane({required this.header, required this.child});

  final Widget header;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const Divider(height: 20),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _LanguageDropdown extends StatelessWidget {
  const _LanguageDropdown({required this.value, required this.options, required this.onChanged});

  final String value;
  final List<LanguageOption> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = options.any((option) => option.code == value) ? value : options.first.code;
    return DropdownButton<String>(
      value: safeValue,
      underline: const SizedBox.shrink(),
      items: [
        for (final language in options) DropdownMenuItem(value: language.code, child: Text(language.label)),
      ],
      onChanged: onChanged,
    );
  }
}

class _FeatureStrip extends StatelessWidget {
  const _FeatureStrip({required this.isAndroid, required this.onAction, required this.onUnavailable, this.onVoice});

  final bool isAndroid;
  final ValueChanged<DesktopAction> onAction;
  final ValueChanged<String> onUnavailable;
  final VoidCallback? onVoice;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const Chip(avatar: Icon(Icons.translate, size: 18), label: Text('文本翻译')),
          const SizedBox(width: 8),
          ActionChip(
            avatar: Icon(isAndroid ? Icons.share_outlined : Icons.content_paste_go_outlined, size: 18),
            label: Text(isAndroid ? '分享/长按文字翻译' : '剪贴板 Alt+Q'),
            onPressed: isAndroid
                ? () => onUnavailable('在其他 App 中长按选中文字，选择“月影翻译”；或通过“分享”把文字发送到 月影翻译，会自动翻译。')
                : () => onAction(DesktopAction.translateClipboard),
          ),
          const SizedBox(width: 8),
          ActionChip(
            avatar: const Icon(Icons.screenshot_monitor, size: 18),
            label: Text(isAndroid ? '屏幕翻译' : '截图 OCR Alt+A'),
            onPressed: () => onAction(DesktopAction.screenTranslate),
          ),
          const SizedBox(width: 8),
          ActionChip(
            avatar: const Icon(Icons.picture_in_picture_alt_outlined, size: 18),
            label: Text(isAndroid ? '悬浮翻译球' : '悬浮窗 Alt+Space'),
            onPressed: () => onAction(DesktopAction.toggleQuickPanel),
          ),
          const SizedBox(width: 8),
          if (!isAndroid) ...[
            ActionChip(
              avatar: const Icon(Icons.content_cut, size: 18),
              label: const Text('划词'),
              onPressed: () => onUnavailable('真正的“选中文字后自动复制并弹窗”仍需要各桌面的辅助功能/输入模拟桥接；当前先用 Alt+Q 翻译剪贴板。'),
            ),
            const SizedBox(width: 8),
          ],
          if (isAndroid) ...[
            ActionChip(
              avatar: const Icon(Icons.mic_none_outlined, size: 18),
              label: const Text('语音翻译'),
              onPressed: onVoice,
            ),
            const SizedBox(width: 8),
          ],
          ActionChip(
            avatar: const Icon(Icons.graphic_eq, size: 18),
            label: Text(isAndroid ? '实时字幕' : '实时字幕 Alt+S'),
            onPressed: () => onAction(DesktopAction.toggleSubtitles),
          ),
        ],
      ),
    );
  }
}

void _showComingSoon(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<void> _showHistory(BuildContext context, WidgetRef ref, TextEditingController sourceController) async {
  final state = ref.read(translateControllerProvider);
  final controller = ref.read(translateControllerProvider.notifier);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final items = state.history;
      return SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.72,
          child: Column(
            children: [
              ListTile(
                title: const Text('翻译历史'),
                subtitle: Text(items.isEmpty ? '暂无历史记录' : '${items.length} 条，仅保存在本机'),
                trailing: TextButton.icon(
                  onPressed: items.isEmpty
                      ? null
                      : () async {
                          await controller.clearHistory();
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                        },
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('清空'),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('完成一次翻译后会显示在这里'))
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return ListTile(
                            title: Text(item.sourceText, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              '${item.translatedText}\n${engineLabel(item.engineId)} · ${DateFormat('MM-dd HH:mm').format(item.createdAt)}',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            isThreeLine: true,
                            onTap: () {
                              controller.restore(item);
                              sourceController.text = item.sourceText;
                              Navigator.pop(sheetContext);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
