class LocalAiModelInfo {
  const LocalAiModelInfo({
    required this.installed,
    required this.path,
    required this.sizeBytes,
  });

  final bool installed;
  final String path;
  final int sizeBytes;
}

class LocalAiModelManager {
  static const modelFileName = 'Qwen3-0.6B-Q4_0.gguf';
  static const modelDownloadUrl = '';
  static const modelMirrorUrl = '';
  static const expectedSizeBytes = 429000000;

  Future<LocalAiModelInfo> status() async =>
      const LocalAiModelInfo(installed: false, path: '', sizeBytes: 0);

  Future<Object> ensureInstalled({void Function(int received, int total)? onProgress}) =>
      Future.error(UnsupportedError('本地 AI 模型管理目前仅支持 Android。'));

  Future<Object> download({void Function(int received, int total)? onProgress}) =>
      Future.error(UnsupportedError('本地 AI 模型管理目前仅支持 Android。'));

  Future<Object> importFromFilePicker() =>
      Future.error(UnsupportedError('手动导入模型目前仅支持 Android。'));

  Future<void> deleteModel() async {}

  static String formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }
}
