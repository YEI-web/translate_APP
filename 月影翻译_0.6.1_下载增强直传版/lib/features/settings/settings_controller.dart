import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../services/app_settings_repository.dart';

final settingsRepositoryProvider = Provider<AppSettingsRepository>((ref) => AppSettingsRepository());

class SettingsController extends StateNotifier<AppSettings> {
  SettingsController(this.repository) : super(const AppSettings()) {
    load();
  }

  final AppSettingsRepository repository;
  final Completer<void> _readyCompleter = Completer<void>();
  bool _loaded = false;
  bool get loaded => _loaded;
  Future<void> get ready => _readyCompleter.future;

  Future<void> load() async {
    try {
      state = await repository.load();
      _loaded = true;
    } finally {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  Future<void> update(AppSettings settings) async {
    state = settings;
    await repository.save(settings);
  }

  Future<void> patch(AppSettings Function(AppSettings current) update) async {
    await this.update(update(state));
  }
}

final settingsControllerProvider = StateNotifierProvider<SettingsController, AppSettings>((ref) {
  return SettingsController(ref.watch(settingsRepositoryProvider));
});
