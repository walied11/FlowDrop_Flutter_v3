import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download_item.dart';

/// سجل التحميلات المكتملة (محفوظ في SharedPreferences).
class HistoryStore extends ChangeNotifier {
  HistoryStore._();
  static final HistoryStore instance = HistoryStore._();

  static const _key = 'history_v2';
  static const _maxEntries = 300;

  final List<HistoryEntry> entries = [];

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    entries.clear();
    for (final s in p.getStringList(_key) ?? const <String>[]) {
      final e = HistoryEntry.decode(s);
      if (e != null) entries.add(e);
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_key, entries.map((e) => e.encode()).toList());
  }

  Future<void> add(HistoryEntry e) async {
    entries.insert(0, e);
    if (entries.length > _maxEntries) {
      entries.removeRange(_maxEntries, entries.length);
    }
    notifyListeners();
    await _save();
  }

  Future<void> remove(int id) async {
    entries.removeWhere((e) => e.id == id);
    notifyListeners();
    await _save();
  }

  Future<void> removeByPath(String path) async {
    entries.removeWhere((e) => e.filePath == path);
    notifyListeners();
    await _save();
  }

  Future<void> clear() async {
    entries.clear();
    notifyListeners();
    await _save();
  }
}
