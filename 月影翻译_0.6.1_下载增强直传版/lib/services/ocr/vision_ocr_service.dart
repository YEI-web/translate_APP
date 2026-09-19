import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/models.dart';
import '../app_settings_repository.dart';

class OcrException implements Exception {
  const OcrException(this.message);
  final String message;
  @override
  String toString() => message;
}

class VisionOcrService {
  VisionOcrService(this.settingsRepository, {Dio? dio}) : _dio = dio ?? Dio();

  final AppSettingsRepository settingsRepository;
  final Dio _dio;

  Future<String> recognize(Uint8List imageBytes, AppSettings settings) async {
    final apiKey = await settingsRepository.readSecret(SecretKeys.openAiCompatible);
    if (apiKey.trim().isEmpty) {
      throw const OcrException('截图 OCR 目前使用你配置的 AI / OpenAI-compatible 视觉模型。请先在设置中填写 API Key。');
    }
    if (settings.openAiModel.trim().isEmpty) {
      throw const OcrException('请先在设置中填写支持图片输入的 AI 模型名称。');
    }

    final baseUrl = settings.openAiBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final dataUrl = 'data:image/png;base64,${base64Encode(imageBytes)}';
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$baseUrl/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': settings.openAiModel,
          'temperature': 0,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': 'Extract every readable piece of text from this screenshot in natural reading order. Preserve line breaks where useful. Return only the extracted text, with no commentary.',
                },
                {
                  'type': 'image_url',
                  'image_url': {'url': dataUrl},
                },
              ],
            },
          ],
        },
      );
      final raw = response.data?['choices'];
      if (raw is! List || raw.isEmpty) throw const OcrException('AI OCR 没有返回可用结果。');
      final first = raw.first;
      if (first is! Map) throw const OcrException('AI OCR 返回格式无法识别。');
      final message = first['message'];
      if (message is! Map) throw const OcrException('AI OCR 返回格式无法识别。');
      final content = message['content'];
      final text = _extractContent(content).trim();
      if (text.isEmpty) throw const OcrException('没有从截图中识别到文字。');
      return text;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final detail = _responseMessage(error.response?.data);
      throw OcrException('截图 OCR 请求失败${status == null ? '' : '（HTTP $status）'}${detail.isEmpty ? '' : '：$detail'}');
    }
  }

  String _extractContent(dynamic content) {
    if (content is String) return content;
    if (content is List) {
      final parts = <String>[];
      for (final item in content) {
        if (item is Map && item['text'] is String) parts.add(item['text'] as String);
      }
      return parts.join('\n');
    }
    return '';
  }

  String _responseMessage(dynamic data) {
    if (data is Map) {
      final error = data['error'];
      if (error is Map && error['message'] is String) return error['message'] as String;
      if (data['message'] is String) return data['message'] as String;
    }
    return '';
  }
}
