import '../../core/models.dart';

abstract interface class TranslationEngine {
  String get id;
  String get displayName;
  bool get supportsContextualStyles;

  Future<TranslationResult> translate(TranslationRequest request);
}

class TranslationEngineException implements Exception {
  const TranslationEngineException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
