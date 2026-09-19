import 'package:dio/dio.dart';

import '../../core/models.dart';
import 'translation_engine.dart';

class DeepLTranslationEngine implements TranslationEngine {
  DeepLTranslationEngine({
    required this.apiKey,
    required this.useFreeEndpoint,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  final String apiKey;
  final bool useFreeEndpoint;
  final Dio _dio;

  @override
  String get id => 'deepl';

  @override
  String get displayName => 'DeepL';

  @override
  bool get supportsContextualStyles => false;

  @override
  Future<TranslationResult> translate(TranslationRequest request) async {
    final endpoint = useFreeEndpoint ? 'https://api-free.deepl.com/v2/translate' : 'https://api.deepl.com/v2/translate';
    final payload = <String, dynamic>{
      'text': [request.text],
      'target_lang': _deeplLanguage(request.targetLanguage, target: true),
    };
    if (request.sourceLanguage != 'auto') {
      payload['source_lang'] = _deeplLanguage(request.sourceLanguage, target: false);
    }

    try {
      final response = await _dio.post<dynamic>(
        endpoint,
        data: payload,
        options: Options(headers: {
          'Authorization': 'DeepL-Auth-Key $apiKey',
          'Content-Type': 'application/json',
        }),
      );
      final body = response.data as Map<String, dynamic>;
      final translations = body['translations'] as List<dynamic>? ?? const [];
      if (translations.isEmpty) throw const TranslationEngineException('DeepL 没有返回译文。');
      final first = translations.first as Map<String, dynamic>;
      return TranslationResult(
        text: first['text'] as String? ?? '',
        engineId: id,
        detectedLanguage: first['detected_source_language'] as String?,
      );
    } on DioException catch (error) {
      throw TranslationEngineException(_dioMessage('DeepL', error), statusCode: error.response?.statusCode);
    }
  }
}

String _deeplLanguage(String code, {required bool target}) {
  return switch (code) {
    'zh-Hans' => target ? 'ZH-HANS' : 'ZH',
    'zh-Hant' => target ? 'ZH-HANT' : 'ZH',
    'en' => 'EN',
    'ja' => 'JA',
    'ko' => 'KO',
    'de' => 'DE',
    'fr' => 'FR',
    'es' => 'ES',
    'it' => 'IT',
    'pt' => 'PT',
    'ru' => 'RU',
    'ar' => 'AR',
    _ => code.toUpperCase(),
  };
}

String _dioMessage(String provider, DioException error) {
  final response = error.response;
  if (response == null) return '$provider 网络请求失败：${error.message ?? '未知网络错误'}';
  final data = response.data;
  var detail = data?.toString() ?? '';
  if (data is Map<String, dynamic>) {
    detail = (data['message'] ?? data['error'] ?? data).toString();
  }
  return '$provider 请求失败 (${response.statusCode ?? '-'})：$detail';
}
