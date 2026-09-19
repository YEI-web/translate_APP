import 'package:dio/dio.dart';

import '../../core/models.dart';
import 'translation_engine.dart';

class GoogleTranslationEngine implements TranslationEngine {
  GoogleTranslationEngine({required this.apiKey, Dio? dio}) : _dio = dio ?? Dio();

  final String apiKey;
  final Dio _dio;

  @override
  String get id => 'google';

  @override
  String get displayName => 'Google Cloud Translation';

  @override
  bool get supportsContextualStyles => false;

  @override
  Future<TranslationResult> translate(TranslationRequest request) async {
    final query = <String, dynamic>{
      'key': apiKey,
      'q': request.text,
      'target': _googleLanguage(request.targetLanguage),
      'format': 'text',
    };
    if (request.sourceLanguage != 'auto') query['source'] = _googleLanguage(request.sourceLanguage);

    try {
      final response = await _dio.post<dynamic>(
        'https://translation.googleapis.com/language/translate/v2',
        queryParameters: query,
      );
      final root = response.data as Map<String, dynamic>;
      final data = root['data'] as Map<String, dynamic>?;
      final translations = data?['translations'] as List<dynamic>? ?? const [];
      if (translations.isEmpty) throw const TranslationEngineException('Google Cloud Translation 没有返回译文。');
      final translated = translations.first as Map<String, dynamic>;
      return TranslationResult(
        text: _decodeBasicHtmlEntities(translated['translatedText'] as String? ?? ''),
        engineId: id,
        detectedLanguage: translated['detectedSourceLanguage'] as String?,
      );
    } on DioException catch (error) {
      throw TranslationEngineException(_dioMessage('Google Cloud Translation', error), statusCode: error.response?.statusCode);
    }
  }
}

String _googleLanguage(String code) => switch (code) {
      'zh-Hans' => 'zh-CN',
      'zh-Hant' => 'zh-TW',
      _ => code,
    };

String _decodeBasicHtmlEntities(String value) => value
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&');

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
