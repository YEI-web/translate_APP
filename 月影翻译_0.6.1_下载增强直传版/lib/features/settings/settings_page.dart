import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../services/app_settings_repository.dart';
import '../../services/mobile/mobile_runtime.dart';
import '../../services/local_model/local_ai_model_manager.dart';
import 'settings_controller.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _deeplKey = TextEditingController();
  final _azureKey = TextEditingController();
  final _googleKey = TextEditingController();
  final _openAiKey = TextEditingController();
  late final TextEditingController _azureEndpoint;
  late final TextEditingController _azureRegion;
  late final TextEditingController _openAiBaseUrl;
  late final TextEditingController _openAiModel;

  bool _deeplConfigured = false;
  bool _azureConfigured = false;
  bool _googleConfigured = false;
  bool _openAiConfigured = false;
  bool _saving = false;
  bool _overlayPermission = false;
  bool _overlayRunning = false;
  bool _overlayBusy = false;
  final LocalAiModelManager _localAiModelManager = LocalAiModelManager();
  bool _localAiModelInstalled = false;
  bool _localAiModelBusy = false;
  int _localAiModelBytes = 0;
  double? _localAiDownloadProgress;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsControllerProvider);
    _azureEndpoint = TextEditingController(text: settings.azureEndpoint);
    _azureRegion = TextEditingController(text: settings.azureRegion);
    _openAiBaseUrl = TextEditingController(text: settings.openAiBaseUrl);
    _openAiModel = TextEditingController(text: settings.openAiModel);
    _loadSecretStatus();
    _loadAndroidStatus();
    _loadLocalAiModelStatus();
  }

  Future<void> _loadSecretStatus() async {
    final repository = ref.read(settingsRepositoryProvider);
    final statuses = await Future.wait([
      repository.hasSecret(SecretKeys.deepl),
      repository.hasSecret(SecretKeys.azure),
      repository.hasSecret(SecretKeys.google),
      repository.hasSecret(SecretKeys.openAiCompatible),
    ]);
    if (!mounted) return;
    setState(() {
      _deeplConfigured = statuses[0];
      _azureConfigured = statuses[1];
      _googleConfigured = statuses[2];
      _openAiConfigured = statuses[3];
    });
  }


  Future<void> _loadLocalAiModelStatus() async {
    if (!mobileRuntime.isAndroid) return;
    try {
      final status = await _localAiModelManager.status();
      if (!mounted) return;
      setState(() {
        _localAiModelInstalled = status.installed;
        _localAiModelBytes = status.sizeBytes;
      });
    } catch (_) {}
  }

  Future<void> _downloadLocalAiModel() async {
    if (_localAiModelBusy || !mobileRuntime.isAndroid) return;
    setState(() {
      _localAiModelBusy = true;
      _localAiDownloadProgress = 0;
    });
    try {
      await _localAiModelManager.download(
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _localAiModelBytes = received;
            _localAiDownloadProgress = total > 0 ? received / total : null;
          });
        },
      );
      await _loadLocalAiModelStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('本地 AI 模型下载完成，现在可以离线翻译。')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('模型下载失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _localAiModelBusy = false;
          _localAiDownloadProgress = null;
        });
      }
    }
  }

  Future<void> _importLocalAiModel() async {
    if (_localAiModelBusy || !mobileRuntime.isAndroid) return;
    setState(() {
      _localAiModelBusy = true;
      _localAiDownloadProgress = null;
    });
    try {
      await _localAiModelManager.importFromFilePicker();
      await _loadLocalAiModelStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GGUF 模型导入完成，现在可以离线翻译。')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('模型导入失败：$error')),
      );
    } finally {
      if (mounted) setState(() => _localAiModelBusy = false);
    }
  }

  Future<void> _deleteLocalAiModel() async {
    if (_localAiModelBusy || !mobileRuntime.isAndroid) return;
    setState(() => _localAiModelBusy = true);
    try {
      await _localAiModelManager.deleteModel();
      await _loadLocalAiModelStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('本地 AI 模型已删除。')),
      );
    } finally {
      if (mounted) setState(() => _localAiModelBusy = false);
    }
  }

  Future<void> _loadAndroidStatus() async {
    if (!mobileRuntime.isAndroid) return;
    final values = await Future.wait([
      mobileRuntime.hasOverlayPermission(),
      mobileRuntime.isOverlayRunning(),
    ]);
    if (!mounted) return;
    setState(() {
      _overlayPermission = values[0];
      _overlayRunning = values[1];
    });
  }

  Future<void> _requestOverlayPermission() async {
    if (!mobileRuntime.isAndroid || _overlayBusy) return;
    setState(() => _overlayBusy = true);
    try {
      final granted = await mobileRuntime.requestOverlayPermission();
      if (!mounted) return;
      setState(() => _overlayPermission = granted);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(granted ? '悬浮窗权限已授权' : '未授予悬浮窗权限')),
      );
    } finally {
      if (mounted) setState(() => _overlayBusy = false);
    }
  }

  Future<void> _toggleOverlay(bool enabled) async {
    if (!mobileRuntime.isAndroid || _overlayBusy) return;
    setState(() => _overlayBusy = true);
    try {
      if (enabled) {
        var granted = await mobileRuntime.hasOverlayPermission();
        if (!granted) granted = await mobileRuntime.requestOverlayPermission();
        if (!granted) {
          if (mounted) setState(() => _overlayPermission = false);
          return;
        }
        final started = await mobileRuntime.startOverlay();
        if (!mounted) return;
        setState(() {
          _overlayPermission = true;
          _overlayRunning = started;
        });
      } else {
        await mobileRuntime.stopOverlay();
        if (!mounted) return;
        setState(() => _overlayRunning = false);
      }
    } finally {
      if (mounted) setState(() => _overlayBusy = false);
    }
  }

  @override
  void dispose() {
    _deeplKey.dispose();
    _azureKey.dispose();
    _googleKey.dispose();
    _openAiKey.dispose();
    _azureEndpoint.dispose();
    _azureRegion.dispose();
    _openAiBaseUrl.dispose();
    _openAiModel.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final repository = ref.read(settingsRepositoryProvider);
    final current = ref.read(settingsControllerProvider);
    final updated = current.copyWith(
      azureEndpoint: _azureEndpoint.text.trim().isEmpty
          ? 'https://api.cognitive.microsofttranslator.com'
          : _azureEndpoint.text.trim(),
      azureRegion: _azureRegion.text.trim(),
      openAiBaseUrl: _openAiBaseUrl.text.trim().isEmpty ? 'https://api.openai.com/v1' : _openAiBaseUrl.text.trim(),
      openAiModel: _openAiModel.text.trim().isEmpty ? 'gpt-5-mini' : _openAiModel.text.trim(),
    );

    await ref.read(settingsControllerProvider.notifier).update(updated);
    await _saveIfEntered(repository, SecretKeys.deepl, _deeplKey.text);
    await _saveIfEntered(repository, SecretKeys.azure, _azureKey.text);
    await _saveIfEntered(repository, SecretKeys.google, _googleKey.text);
    await _saveIfEntered(repository, SecretKeys.openAiCompatible, _openAiKey.text);
    await _loadSecretStatus();
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('设置已保存到本机')));
  }

  Future<void> _saveIfEntered(AppSettingsRepository repository, String key, String value) async {
    if (value.trim().isNotEmpty) await repository.writeSecret(key, value);
  }

  Future<void> _clearKey(String key) async {
    await ref.read(settingsRepositoryProvider).writeSecret(key, '');
    await _loadSecretStatus();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: '隐私与本地数据',
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('保存翻译历史'),
              subtitle: const Text('仅保存在当前设备，最多保存最近 200 条。'),
              value: settings.keepHistory,
              onChanged: (value) => ref
                  .read(settingsControllerProvider.notifier)
                  .patch((current) => current.copyWith(keepHistory: value)),
            ),
          ),
          if (mobileRuntime.isAndroid)
            _Section(
              title: '本地 AI 翻译模型（无需 API Key）',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      _localAiModelInstalled ? Icons.check_circle_outline : Icons.memory_outlined,
                    ),
                    title: const Text('Qwen3-0.6B Q4_0'),
                    subtitle: Text(
                      _localAiModelInstalled
                          ? '已安装 · ${LocalAiModelManager.formatBytes(_localAiModelBytes)} · 推理完全在本机进行'
                          : '约 429 MB。首次需要联网下载一次；之后无需 Key、无需网络。',
                    ),
                    trailing: _localAiModelBusy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : FilledButton.tonal(
                            onPressed: _localAiModelInstalled ? _deleteLocalAiModel : _downloadLocalAiModel,
                            child: Text(_localAiModelInstalled ? '删除' : '下载'),
                          ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _localAiModelBusy ? null : _importLocalAiModel,
                      icon: const Icon(Icons.file_open_outlined),
                      label: const Text('导入本地 GGUF'),
                    ),
                  ),
                  if (_localAiModelBusy) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: _localAiDownloadProgress),
                    const SizedBox(height: 6),
                    Text(
                      _localAiDownloadProgress == null
                          ? '正在下载模型… ${LocalAiModelManager.formatBytes(_localAiModelBytes)}'
                          : '正在下载 ${(100 * _localAiDownloadProgress!).toStringAsFixed(0)}% · ${LocalAiModelManager.formatBytes(_localAiModelBytes)}',
                    ),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    '下载会自动尝试 Hugging Face 和备用镜像，并支持断点续传。也可以先用浏览器下载 GGUF，再点“导入本地 GGUF”。翻译推理完全在 Android 本机运行。',
                  ),
                ],
              ),
            ),
          if (mobileRuntime.isAndroid)
            _Section(
              title: 'Android 系统工具',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(_overlayPermission ? Icons.check_circle_outline : Icons.layers_outlined),
                    title: const Text('显示在其他应用上层'),
                    subtitle: Text(_overlayPermission ? '已授权' : '悬浮翻译球需要此系统权限'),
                    trailing: OutlinedButton(
                      onPressed: _overlayBusy ? null : _requestOverlayPermission,
                      child: Text(_overlayPermission ? '重新检查' : '授权'),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('悬浮翻译球'),
                    subtitle: const Text('可拖动；点击后展开“打开 / 截图 / 语音 / 关闭”快捷面板。'),
                    value: _overlayRunning,
                    onChanged: _overlayBusy ? null : _toggleOverlay,
                  ),
                  const Divider(),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.text_fields),
                    title: Text('长按文字 / 分享翻译'),
                    subtitle: Text('支持 Android 标准“处理文字”和文字分享入口，收到文字后自动翻译。'),
                  ),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.screenshot_monitor_outlined),
                    title: Text('屏幕翻译'),
                    subtitle: Text('每次由 Android 显示系统屏幕捕获授权，抓取一帧后进入 OCR → 翻译流程。'),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('优先使用本地 OCR'),
                    subtitle: const Text('默认开启。Android 使用设备端 ML Kit 识别截图，图像不上传。'),
                    value: settings.androidUseLocalOcr,
                    onChanged: (value) => ref
                        .read(settingsControllerProvider.notifier)
                        .patch((current) => current.copyWith(androidUseLocalOcr: value)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('本地 OCR 失败后允许云端回退'),
                    subtitle: const Text('开启后，识别失败时会把截图发送给已配置的 AI 视觉模型。默认关闭。'),
                    value: settings.androidAllowCloudOcrFallback,
                    onChanged: settings.androidUseLocalOcr
                        ? (value) => ref
                            .read(settingsControllerProvider.notifier)
                            .patch((current) => current.copyWith(androidAllowCloudOcrFallback: value))
                        : null,
                  ),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.mic_none_outlined),
                    title: Text('语音输入翻译'),
                    subtitle: Text('调用 Android 系统语音识别，一句话识别完成后自动进入翻译。'),
                  ),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.volume_up_outlined),
                    title: Text('译文朗读'),
                    subtitle: Text('使用 Android 系统 Text-to-Speech 朗读当前译文。'),
                  ),
                ],
              ),
            )
          else
            const _Section(
              title: '桌面工具',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ShortcutRow(keys: 'Alt + Space', label: '切换快速悬浮翻译窗'),
                  _ShortcutRow(keys: 'Alt + Q', label: '翻译当前剪贴板文字'),
                  _ShortcutRow(keys: 'Alt + A', label: '区域截图 → OCR → 翻译'),
                  _ShortcutRow(keys: 'Alt + S', label: '实时字幕入口（下一阶段接音频）'),
                  SizedBox(height: 8),
                  Text('截图 OCR 当前会把所选截图发送到你在下方配置的 AI / OpenAI-compatible 服务。敏感截图请不要使用该功能；后续会增加本地 OCR 模式。'),
                ],
              ),
            ),
          _Section(
            title: 'DeepL',
            child: Column(
              children: [
                _SecretField(
                  controller: _deeplKey,
                  configured: _deeplConfigured,
                  label: 'API Key',
                  onClear: () => _clearKey(SecretKeys.deepl),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('使用 DeepL API Free 端点'),
                  subtitle: const Text('如果你的 Key 是 Pro 版，请关闭。'),
                  value: settings.deeplUseFreeEndpoint,
                  onChanged: (value) => ref
                      .read(settingsControllerProvider.notifier)
                      .patch((current) => current.copyWith(deeplUseFreeEndpoint: value)),
                ),
              ],
            ),
          ),
          _Section(
            title: 'Microsoft Translator',
            child: Column(
              children: [
                _SecretField(
                  controller: _azureKey,
                  configured: _azureConfigured,
                  label: 'Subscription Key',
                  onClear: () => _clearKey(SecretKeys.azure),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _azureRegion,
                  decoration: const InputDecoration(labelText: 'Region（按 Azure 资源填写，可留空）'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _azureEndpoint,
                  decoration: const InputDecoration(labelText: 'Endpoint'),
                ),
              ],
            ),
          ),
          _Section(
            title: 'Google Cloud Translation',
            child: _SecretField(
              controller: _googleKey,
              configured: _googleConfigured,
              label: 'API Key',
              onClear: () => _clearKey(SecretKeys.google),
            ),
          ),
          _Section(
            title: 'AI / OpenAI-compatible',
            child: Column(
              children: [
                _SecretField(
                  controller: _openAiKey,
                  configured: _openAiConfigured,
                  label: 'API Key',
                  onClear: () => _clearKey(SecretKeys.openAiCompatible),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _openAiBaseUrl,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: 'https://api.openai.com/v1',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _openAiModel,
                  decoration: const InputDecoration(labelText: '模型名称', hintText: 'gpt-5-mini'),
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('兼容采用 /chat/completions 的服务，可改 Base URL 和模型名。'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: const Text('保存设置'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({required this.keys, required this.label});

  final String keys;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: Text(keys, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _SecretField extends StatelessWidget {
  const _SecretField({
    required this.controller,
    required this.configured,
    required this.label,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool configured;
  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: true,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: configured ? '$label（已配置，留空则保持不变）' : label,
        suffixIcon: configured
            ? IconButton(
                tooltip: '清除已保存 Key',
                onPressed: onClear,
                icon: const Icon(Icons.delete_outline),
              )
            : null,
      ),
    );
  }
}
