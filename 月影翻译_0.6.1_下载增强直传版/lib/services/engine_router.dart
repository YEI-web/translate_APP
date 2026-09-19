import '../core/models.dart';
import 'app_settings_repository.dart';
import 'engines/azure_engine.dart';
import 'engines/deepl_engine.dart';
import 'engines/google_engine.dart';
import 'engines/local_qwen_engine.dart';
import 'engines/openai_compatible_engine.dart';
import 'engines/translation_engine.dart';

class EngineOption {
  const EngineOption(this.id, this.label, {this.requiresApiKey = true});

  final String id;
  final String label;
  final bool requiresApiKey;
}

const engineOptions = <EngineOption>[
  EngineOption('local_qwen', '本地 AI（无需 Key）', requiresApiKey: false),
  EngineOption('deepl', 'DeepL'),
  EngineOption('azure', 'Microsoft Translator'),
  EngineOption('google', 'Google Cloud Translation'),
  EngineOption('openai', 'AI / OpenAI-compatible'),
];

String engineLabel(String id) {
  for (final engine in engineOptions) {
    if (engine.id == id) return engine.label;
  }
  return id;
}

class EngineRouter {
  EngineRouter(this.settingsRepository);

  final AppSettingsRepository settingsRepository;

  Future<TranslationEngine> create(String id, AppSettings settings) async {
    switch (id) {
      case 'local_qwen':
        return LocalQwenTranslationEngine();
      case 'deepl':
        final key = await _requiredSecret(SecretKeys.deepl, 'DeepL');
        return DeepLTranslationEngine(apiKey: key, useFreeEndpoint: settings.deeplUseFreeEndpoint);
      case 'azure':
        final key = await _requiredSecret(SecretKeys.azure, 'Microsoft Translator');
        return AzureTranslationEngine(
          apiKey: key,
          endpoint: settings.azureEndpoint,
          region: settings.azureRegion,
        );
      case 'google':
        final key = await _requiredSecret(SecretKeys.google, 'Google Cloud Translation');
        return GoogleTranslationEngine(apiKey: key);
      case 'openai':
        final key = await _requiredSecret(SecretKeys.openAiCompatible, 'AI / OpenAI-compatible');
        if (settings.openAiModel.trim().isEmpty) {
          throw const TranslationEngineException('请先在设置中填写 AI 模型名称。');
        }
        return OpenAiCompatibleTranslationEngine(
          apiKey: key,
          baseUrl: settings.openAiBaseUrl,
          model: settings.openAiModel,
        );
      default:
        throw TranslationEngineException('未知翻译引擎：$id');
    }
  }

  Future<String> _requiredSecret(String key, String provider) async {
    final value = await settingsRepository.readSecret(key);
    if (value.isEmpty) {
      throw TranslationEngineException('请先在设置中填写 $provider 的 API Key。');
    }
    return value;
  }
}
