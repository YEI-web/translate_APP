import '../../core/models.dart';
import 'translation_engine.dart';

class LocalQwenTranslationEngine implements TranslationEngine {
  @override
  String get id => 'local_qwen';

  @override
  String get displayName => '本地 AI（无需 Key）';

  @override
  bool get supportsContextualStyles => true;

  @override
  Future<TranslationResult> translate(TranslationRequest request) {
    throw const TranslationEngineException('本地 AI 翻译当前先支持 Android。');
  }
}
