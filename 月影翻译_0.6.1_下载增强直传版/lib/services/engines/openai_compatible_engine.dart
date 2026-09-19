import 'package:dio/dio.dart';

import '../../core/languages.dart';
import '../../core/models.dart';
import 'translation_engine.dart';

class OpenAiCompatibleTranslationEngine implements TranslationEngine {
  OpenAiCompatibleTranslationEngine({
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  final String apiKey;
  final String baseUrl;
  final String model;
  final Dio _dio;

  @override
  String get id => 'openai';

  @override
  String get displayName => 'AI / OpenAI-compatible';

  @override
  bool get supportsContextualStyles => true;

  @override
  Future<TranslationResult> translate(TranslationRequest request) async {
    final cleanBaseUrl = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final sourceDescription = request.sourceLanguage == 'auto' ? 'automatically detected language' : languageLabel(request.sourceLanguage);
    final targetDescription = languageLabel(request.targetLanguage);
    final prompt = '''Translate the following text from $sourceDescription to $targetDescription.
Style: ${request.style.promptHint}.
Preserve meaning, names, numbers, formatting, code, URLs, and technical terms unless translation is clearly appropriate.
Return only the translated text. Do not add commentary, quotation marks, headings, or explanations.

TEXT:
${request.text}''';

    try {
      final response = await _dio.post<dynamic>(
        '$cleanBaseUrl/chat/completions',
        data: {
          'model': model.trim(),
          'messages': [
            {
              'role': 'system',
              'content': 'You are a high-precision translation engine. Follow the requested target language and style exactly.'
            },
            {'role': 'user', 'content': prompt},
          ],
        },
        options: Options(headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        }),
      );
      final root = response.data as Map<String, dynamic>;
      final choices = root['choices'] as List<dynamic>? ?? const [];
      if (choices.isEmpty) throw const TranslationEngineException('AI 接口没有返回译文。');
      final choice = choices.first as Map<String, dynamic>;
      final message = choice['message'] as Map<String, dynamic>?;
      final content = message?['content'];
      final text = _extractText(content).trim();
      if (text.isEmpty) throw const TranslationEngineException('AI 接口返回了空译文。');
      return TranslationResult(text: text, engineId: id);
    } on DioException catch (error) {
      throw TranslationEngineException(_dioMessage('AI 接口', error), statusCode: error.response?.statusCode);
    }
  }
}

String _extractText(dynamic content) {
  if (content is String) return content;
  if (content is List<dynamic>) {
    final buffer = StringBuffer();
    for (final part in content) {
      if (part is Map<String, dynamic>) {
        final text = part['text'];
        if (text is String) buffer.write(text);
      }
    }
    return buffer.toString();
  }
  return '';
}

String _dioMessage(String provider, DioException error) {
  final response = error.response;
  if (response == null) return '$provider 网络请求失败：${error.message ?? '未知网络错误'}';
  final data = response.data;
  var detail = data?.toString() ?? '';
  if (data is Map<String, dynamic>) {
    final nestedError = data['error'];
    if (nestedError is Map<String, dynamic>) {
      detail = (nestedError['message'] ?? nestedError).toString();
    } else {
      detail = (data['message'] ?? data).toString();
    }
  }
  return '$provider 请求失败 (${response.statusCode ?? '-'})：$detail';
}
