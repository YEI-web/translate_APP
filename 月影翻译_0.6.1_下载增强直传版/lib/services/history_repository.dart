import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/models.dart';

class HistoryRepository {
  static const _historyKey = 'translation.history.v1';
  static const maxItems = 200;

  Future<List<TranslationHistoryItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_historyKey) ?? const <String>[];
    final items = <TranslationHistoryItem>[];
    for (final row in raw) {
      try {
        items.add(TranslationHistoryItem.fromJson(jsonDecode(row) as Map<String, dynamic>));
      } catch (_) {
        // Skip a corrupt history row rather than making the app unusable.
      }
    }
    return items;
  }

  Future<void> add(TranslationHistoryItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_historyKey) ?? <String>[];
    current.insert(0, jsonEncode(item.toJson()));
    if (current.length > maxItems) current.removeRange(maxItems, current.length);
    await prefs.setStringList(_historyKey, current);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}
