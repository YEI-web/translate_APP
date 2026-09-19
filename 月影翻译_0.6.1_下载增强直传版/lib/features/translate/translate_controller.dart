import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/models.dart';
import '../../services/engine_router.dart';
import '../../services/engines/translation_engine.dart';
import '../../services/history_repository.dart';
import '../settings/settings_controller.dart';

final engineRouterProvider = Provider<EngineRouter>((ref) {
  return EngineRouter(ref.watch(settingsRepositoryProvider));
});

final historyRepositoryProvider = Provider<HistoryRepository>((ref) => HistoryRepository());

class TranslateState {
  const TranslateState({
    this.source = '',
    this.result = '',
    this.usedEngineId = '',
    this.detectedLanguage,
    this.error,
    this.isLoading = false,
    this.history = const [],
  });

  final String source;
  final String result;
  final String usedEngineId;
  final String? detectedLanguage;
  final String? error;
  final bool isLoading;
  final List<TranslationHistoryItem> history;

  TranslateState copyWith({
    String? source,
    String? result,
    String? usedEngineId,
    String? detectedLanguage,
    bool clearDetectedLanguage = false,
    String? error,
    bool clearError = false,
    bool? isLoading,
    List<TranslationHistoryItem>? history,
  }) {
    return TranslateState(
      source: source ?? this.source,
      result: result ?? this.result,
      usedEngineId: usedEngineId ?? this.usedEngineId,
      detectedLanguage: clearDetectedLanguage ? null : (detectedLanguage ?? this.detectedLanguage),
      error: clearError ? null : (error ?? this.error),
      isLoading: isLoading ?? this.isLoading,
      history: history ?? this.history,
    );
  }
}

class TranslateController extends StateNotifier<TranslateState> {
  TranslateController(this.router, this.historyRepository) : super(const TranslateState()) {
    loadHistory();
  }

  final EngineRouter router;
  final HistoryRepository historyRepository;
  final Uuid _uuid = const Uuid();

  void setSource(String value) => state = state.copyWith(source: value, clearError: true);

  void clear() => state = state.copyWith(source: '', result: '', usedEngineId: '', clearError: true, clearDetectedLanguage: true);

  Future<void> loadHistory() async {
    final items = await historyRepository.load();
    state = state.copyWith(history: items);
  }

  Future<void> clearHistory() async {
    await historyRepository.clear();
    state = state.copyWith(history: const []);
  }

  void restore(TranslationHistoryItem item) {
    state = state.copyWith(
      source: item.sourceText,
      result: item.translatedText,
      usedEngineId: item.engineId,
      clearError: true,
      clearDetectedLanguage: true,
    );
  }

  Future<void> translate(AppSettings settings) async {
    final text = state.source.trim();
    if (text.isEmpty || state.isLoading) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final request = TranslationRequest(
        text: text,
        sourceLanguage: settings.sourceLanguage,
        targetLanguage: settings.targetLanguage,
        style: settings.style,
      );
      final engine = await router.create(settings.selectedEngineId, settings);
      final result = await engine.translate(request);
      state = state.copyWith(
        result: result.text,
        usedEngineId: result.engineId,
        detectedLanguage: result.detectedLanguage,
      );

      if (settings.keepHistory) {
        final item = TranslationHistoryItem(
          id: _uuid.v4(),
          sourceText: text,
          translatedText: result.text,
          engineId: result.engineId,
          sourceLanguage: settings.sourceLanguage,
          targetLanguage: settings.targetLanguage,
          createdAt: DateTime.now(),
        );
        await historyRepository.add(item);
        state = state.copyWith(history: [item, ...state.history].take(HistoryRepository.maxItems).toList());
      }
    } on TranslationEngineException catch (error) {
      state = state.copyWith(error: error.message);
    } catch (error) {
      state = state.copyWith(error: '翻译失败：$error');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}

final translateControllerProvider = StateNotifierProvider<TranslateController, TranslateState>((ref) {
  return TranslateController(
    ref.watch(engineRouterProvider),
    ref.watch(historyRepositoryProvider),
  );
});
