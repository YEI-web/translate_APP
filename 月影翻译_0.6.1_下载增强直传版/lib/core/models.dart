import 'dart:convert';

class TranslationRequest {
  const TranslationRequest({
    required this.text,
    required this.targetLanguage,
    this.sourceLanguage = 'auto',
    this.style = TranslationStyle.natural,
  });

  final String text;
  final String sourceLanguage;
  final String targetLanguage;
  final TranslationStyle style;
}

enum TranslationStyle { natural, formal, academic }

extension TranslationStyleX on TranslationStyle {
  String get label => switch (this) {
        TranslationStyle.natural => '自然',
        TranslationStyle.formal => '正式',
        TranslationStyle.academic => '学术',
      };

  String get promptHint => switch (this) {
        TranslationStyle.natural => 'natural and idiomatic',
        TranslationStyle.formal => 'formal and professional',
        TranslationStyle.academic => 'academic, precise, and terminology-aware',
      };
}

class TranslationResult {
  const TranslationResult({
    required this.text,
    required this.engineId,
    this.detectedLanguage,
    this.notes,
  });

  final String text;
  final String engineId;
  final String? detectedLanguage;
  final String? notes;
}

class AppSettings {
  const AppSettings({
    this.selectedEngineId = 'local_qwen',
    this.sourceLanguage = 'auto',
    this.targetLanguage = 'zh-Hans',
    this.style = TranslationStyle.natural,
    this.deeplUseFreeEndpoint = true,
    this.azureEndpoint = 'https://api.cognitive.microsofttranslator.com',
    this.azureRegion = '',
    this.openAiBaseUrl = 'https://api.openai.com/v1',
    this.openAiModel = 'gpt-5-mini',
    this.keepHistory = true,
    this.androidUseLocalOcr = true,
    this.androidAllowCloudOcrFallback = false,
  });

  final String selectedEngineId;
  final String sourceLanguage;
  final String targetLanguage;
  final TranslationStyle style;
  final bool deeplUseFreeEndpoint;
  final String azureEndpoint;
  final String azureRegion;
  final String openAiBaseUrl;
  final String openAiModel;
  final bool keepHistory;
  final bool androidUseLocalOcr;
  final bool androidAllowCloudOcrFallback;

  AppSettings copyWith({
    String? selectedEngineId,
    String? sourceLanguage,
    String? targetLanguage,
    TranslationStyle? style,
    bool? deeplUseFreeEndpoint,
    String? azureEndpoint,
    String? azureRegion,
    String? openAiBaseUrl,
    String? openAiModel,
    bool? keepHistory,
    bool? androidUseLocalOcr,
    bool? androidAllowCloudOcrFallback,
  }) {
    return AppSettings(
      selectedEngineId: selectedEngineId ?? this.selectedEngineId,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      style: style ?? this.style,
      deeplUseFreeEndpoint: deeplUseFreeEndpoint ?? this.deeplUseFreeEndpoint,
      azureEndpoint: azureEndpoint ?? this.azureEndpoint,
      azureRegion: azureRegion ?? this.azureRegion,
      openAiBaseUrl: openAiBaseUrl ?? this.openAiBaseUrl,
      openAiModel: openAiModel ?? this.openAiModel,
      keepHistory: keepHistory ?? this.keepHistory,
      androidUseLocalOcr: androidUseLocalOcr ?? this.androidUseLocalOcr,
      androidAllowCloudOcrFallback: androidAllowCloudOcrFallback ?? this.androidAllowCloudOcrFallback,
    );
  }

  Map<String, dynamic> toJson() => {
        'selectedEngineId': selectedEngineId,
        'sourceLanguage': sourceLanguage,
        'targetLanguage': targetLanguage,
        'style': style.name,
        'deeplUseFreeEndpoint': deeplUseFreeEndpoint,
        'azureEndpoint': azureEndpoint,
        'azureRegion': azureRegion,
        'openAiBaseUrl': openAiBaseUrl,
        'openAiModel': openAiModel,
        'keepHistory': keepHistory,
        'androidUseLocalOcr': androidUseLocalOcr,
        'androidAllowCloudOcrFallback': androidAllowCloudOcrFallback,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final styleName = json['style'] as String?;
    var selectedEngineId = json['selectedEngineId'] as String? ?? 'local_qwen';
    if (selectedEngineId == 'mock' || selectedEngineId == 'mlkit_local') {
      selectedEngineId = 'local_qwen';
    }
    TranslationStyle? style;
    for (final value in TranslationStyle.values) {
      if (value.name == styleName) {
        style = value;
        break;
      }
    }
    return AppSettings(
      selectedEngineId: selectedEngineId,
      sourceLanguage: json['sourceLanguage'] as String? ?? 'auto',
      targetLanguage: json['targetLanguage'] as String? ?? 'zh-Hans',
      style: style ?? TranslationStyle.natural,
      deeplUseFreeEndpoint: json['deeplUseFreeEndpoint'] as bool? ?? true,
      azureEndpoint: json['azureEndpoint'] as String? ?? 'https://api.cognitive.microsofttranslator.com',
      azureRegion: json['azureRegion'] as String? ?? '',
      openAiBaseUrl: json['openAiBaseUrl'] as String? ?? 'https://api.openai.com/v1',
      openAiModel: json['openAiModel'] as String? ?? 'gpt-5-mini',
      keepHistory: json['keepHistory'] as bool? ?? true,
      androidUseLocalOcr: json['androidUseLocalOcr'] as bool? ?? true,
      androidAllowCloudOcrFallback: json['androidAllowCloudOcrFallback'] as bool? ?? false,
    );
  }

  String encode() => jsonEncode(toJson());
}

class TranslationHistoryItem {
  const TranslationHistoryItem({
    required this.id,
    required this.sourceText,
    required this.translatedText,
    required this.engineId,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.createdAt,
  });

  final String id;
  final String sourceText;
  final String translatedText;
  final String engineId;
  final String sourceLanguage;
  final String targetLanguage;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceText': sourceText,
        'translatedText': translatedText,
        'engineId': engineId,
        'sourceLanguage': sourceLanguage,
        'targetLanguage': targetLanguage,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TranslationHistoryItem.fromJson(Map<String, dynamic> json) => TranslationHistoryItem(
        id: json['id'] as String,
        sourceText: json['sourceText'] as String,
        translatedText: json['translatedText'] as String,
        engineId: json['engineId'] as String,
        sourceLanguage: json['sourceLanguage'] as String? ?? 'auto',
        targetLanguage: json['targetLanguage'] as String? ?? 'zh-Hans',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}
