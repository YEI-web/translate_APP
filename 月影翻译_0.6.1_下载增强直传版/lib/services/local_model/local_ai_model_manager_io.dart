import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

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
  LocalAiModelManager({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 90),
                receiveTimeout: const Duration(minutes: 10),
                sendTimeout: const Duration(seconds: 30),
                followRedirects: true,
                maxRedirects: 8,
              ),
            );

  static const modelFileName = 'Qwen3-0.6B-Q4_0.gguf';
  static const modelDownloadUrl =
      'https://huggingface.co/ggml-org/Qwen3-0.6B-GGUF/resolve/main/Qwen3-0.6B-Q4_0.gguf?download=true';
  static const modelMirrorUrl =
      'https://hf-mirror.com/ggml-org/Qwen3-0.6B-GGUF/resolve/main/Qwen3-0.6B-Q4_0.gguf?download=true';
  static const expectedSizeBytes = 429000000;
  static const minimumValidSizeBytes = 400000000;

  static const MethodChannel _nativeChannel = MethodChannel('com.omnitranslate/native');

  final Dio _dio;

  Future<File> modelFile() async {
    final documents = await getApplicationSupportDirectory();
    final directory = Directory('${documents.path}${Platform.pathSeparator}models');
    if (!directory.existsSync()) await directory.create(recursive: true);
    return File('${directory.path}${Platform.pathSeparator}$modelFileName');
  }

  Future<LocalAiModelInfo> status() async {
    final file = await modelFile();
    final size = await file.exists() ? await file.length() : 0;
    return LocalAiModelInfo(
      installed: size >= minimumValidSizeBytes,
      path: file.path,
      sizeBytes: size,
    );
  }

  Future<File> ensureInstalled({
    void Function(int received, int total)? onProgress,
  }) async {
    final file = await modelFile();
    if (await file.exists() && await file.length() >= minimumValidSizeBytes) return file;
    return download(onProgress: onProgress);
  }

  Future<File> download({
    void Function(int received, int total)? onProgress,
  }) async {
    final file = await modelFile();
    final partial = File('${file.path}.part');
    final sources = <String>[modelDownloadUrl, modelMirrorUrl];
    final errors = <String>[];

    for (final source in sources) {
      try {
        await _downloadFromSource(
          source,
          partial,
          onProgress: onProgress,
        );
        final length = await partial.length();
        if (length < minimumValidSizeBytes) {
          throw StateError('模型下载不完整（${_formatBytes(length)}）。');
        }
        if (await file.exists()) await file.delete();
        return partial.rename(file.path);
      } catch (error) {
        errors.add('${_sourceLabel(source)}：${_friendlyError(error)}');
        // Keep .part so the next source or next retry can resume with HTTP Range.
      }
    }

    throw StateError(
      '模型下载失败。已尝试 Hugging Face 与备用镜像。\n'
      '${errors.join('\n')}\n'
      '你也可以点击“导入 GGUF”，从手机本地选择已经下载好的 $modelFileName。',
    );
  }

  Future<void> _downloadFromSource(
    String source,
    File partial, {
    void Function(int received, int total)? onProgress,
  }) async {
    var existing = await partial.exists() ? await partial.length() : 0;
    if (existing >= minimumValidSizeBytes) return;

    Future<Response<dynamic>> run({required bool resume}) {
      final base = resume ? existing : 0;
      final headers = <String, dynamic>{
        'User-Agent': 'MoonShadowTranslate/0.6.1',
        'Accept': 'application/octet-stream,*/*',
      };
      if (resume && existing > 0) headers['Range'] = 'bytes=$existing-';

      return _dio.download(
        source,
        partial.path,
        deleteOnError: false,
        fileAccessMode: resume && existing > 0 ? FileAccessMode.append : FileAccessMode.write,
        onReceiveProgress: (received, total) {
          final current = base + received;
          final whole = total > 0 ? base + total : expectedSizeBytes;
          onProgress?.call(current, whole);
        },
        options: Options(
          headers: headers,
          followRedirects: true,
          receiveTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(seconds: 30),
          validateStatus: (status) => status != null && status >= 200 && status < 400,
        ),
      );
    }

    if (existing > 0) {
      final response = await run(resume: true);
      // A proper ranged response is 206. Some hosts ignore Range and return the
      // whole file with 200; appending that would corrupt the GGUF, so restart.
      if (response.statusCode == HttpStatus.ok) {
        await partial.delete();
        existing = 0;
        await run(resume: false);
      }
    } else {
      await run(resume: false);
    }
  }

  Future<File> importFromFilePicker() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('手动导入模型目前仅支持 Android。');
    }
    final result = await _nativeChannel.invokeMethod<dynamic>('importLocalAiModel');
    if (result == null) {
      throw StateError('没有选择模型文件。');
    }
    final statusNow = await status();
    if (!statusNow.installed) {
      throw StateError('导入的 GGUF 文件不完整或文件过小。');
    }
    return File(statusNow.path);
  }

  Future<void> deleteModel() async {
    final file = await modelFile();
    final partial = File('${file.path}.part');
    if (await file.exists()) await file.delete();
    if (await partial.exists()) await partial.delete();
  }

  static String _sourceLabel(String source) {
    if (source.contains('hf-mirror.com')) return '备用镜像';
    return 'Hugging Face';
  }

  static String _friendlyError(Object error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          return '连接超时';
        case DioExceptionType.receiveTimeout:
          return '下载数据超时';
        case DioExceptionType.connectionError:
          return '无法连接服务器（${error.message ?? '网络错误'}）';
        case DioExceptionType.badResponse:
          return '服务器返回 HTTP ${error.response?.statusCode ?? '错误'}';
        case DioExceptionType.cancel:
          return '下载已取消';
        default:
          return error.message ?? error.toString();
      }
    }
    return error.toString();
  }

  static String formatBytes(int bytes) => _formatBytes(bytes);

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }
}
