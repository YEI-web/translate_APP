import 'package:dio/dio.dart';

import '../../core/models.dart';
import 'translation_engine.dart';

class AzureTranslationEngine implements TranslationEngine {
  AzureTranslationEngine({
    required this.apiKey,
    required this.endpoint,
    this.region = '',
    Dio? dio,
  }) : _dio = dio ?? Dio();

  final String apiKey;
  final String endpoint;
  final String region;
  final Dio _dio;

  @override
  String get id => 'azure';

  @override
  String get displayName => 'Microsoft Translator';

  @override
  bool get supportsContextualStyles => false;

  @override
  Future<TranslationResult> translate(TranslationRequest request) async {
    final cleanEndpoint = endpoint.trim().replaceFirst(RegExp(r'/+$'), '');
    final query = <String, dynamic>{
      'api-version': '3.0',
      'to': request.targetLanguage,
    };
    if (request.sourceLanguage != 'auto') query['from'] = request.sourceLanguage;

    final headers = <String, dynamic>{
      'Ocp-Apim-Subscription-Key': apiKey,
      'Content-Type': 'application/json',
    };
    if (region.trim().isNotEmpty) headers['Ocp-Apim-Subscription-Region'] = region.trim();

    try {
      final response = await _dio.post<dynamic>(
        '$cleanEndpoint/translate',
        queryParameters: query,
        data: [
          {'Text': request.text}
        ],
        options: Options(headers: headers),
      );
      final rows = response.data as List<dynamic>? ?? const [];
      if (rows.isEmpty) throw const TranslationEngineException('Microsoft Translator 没有返回译文。');
      final row = rows.first as Map<String, dynamic>;
      final translations = row['translations'] as List<dynamic>? ?? const [];
      if (translations.isEmpty) throw const TranslationEngineException('Microsoft Translator 没有返回译文。');
      final translated = translations.first as Map<String, dynamic>;
      final detected = row['detectedLanguage'] as Map<String, dynamic>?;
      return TranslationResult(
        text: translated['text'] as String? ?? '',
        engineId: id,
        detectedLanguage: detected?['language'] as String?,
      );
    } on DioException catch (error) {
      throw TranslationEngineException(_dioMessage('Microsoft Translator', error), statusCode: error.response?.statusCode);
    }
  }
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
