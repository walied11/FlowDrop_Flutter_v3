import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// إعدادات التطبيق المحفوظة (اللغة، المظهر، الجودة، محرك Cobalt...).
class AppSettings extends ChangeNotifier {
  static const defaultEndpoint = '';
  static const _legacyEndpoint = 'https://api.cobalt.tools/';
  static const qualities = ['360p', '480p', '720p', '1080p', '1440p', '2160p', 'MAX'];
  static const bitrates = ['128', '192', '256', '320'];

  SharedPreferences? _p;

  String lang = 'ar';
  String themeKey = 'system'; // system | light | dark
  String quality = '720p';
  String bitrate = '128';
  bool audioMode = false;
  bool autoSave = true;
  String endpoint = defaultEndpoint;
  String apiKey = '';

  bool get isArabic => lang == 'ar';

  /// true إذا أضاف المستخدم محرك API خاصًا به.
  bool get useEngine => endpoint.trim().isNotEmpty;

  ThemeMode get themeMode {
    switch (themeKey) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _p = p;
    lang = p.getString('app_lang') ?? 'ar';
    themeKey = p.getString('theme') ?? 'system';
    quality = p.getString('video_quality') ?? '720p';
    bitrate = p.getString('audio_bitrate') ?? '128';
    audioMode = p.getBool('audio_mode') ?? false;
    autoSave = p.getBool('auto_save') ?? true;
    endpoint = p.getString('cobalt_endpoint') ?? defaultEndpoint;
    // المحرك العام القديم كان يتطلب مفتاحًا: نفرّغه ليعمل التحميل المدمج.
    if (endpoint.trim() == _legacyEndpoint || endpoint.trim() == 'https://api.cobalt.tools') {
      endpoint = defaultEndpoint;
      await p.setString('cobalt_endpoint', endpoint);
    }
    apiKey = p.getString('cobalt_api_key') ?? '';
    if (!qualities.contains(quality)) quality = '720p';
    if (!bitrates.contains(bitrate)) bitrate = '128';
  }

  Future<void> setLang(String v) async {
    lang = v;
    await _p?.setString('app_lang', v);
    notifyListeners();
  }

  Future<void> setTheme(String v) async {
    themeKey = v;
    await _p?.setString('theme', v);
    notifyListeners();
  }

  Future<void> setQuality(String v) async {
    quality = v;
    await _p?.setString('video_quality', v);
    notifyListeners();
  }

  Future<void> setAutoSave(bool v) async {
    autoSave = v;
    await _p?.setBool('auto_save', v);
    notifyListeners();
  }

  /// يحفظ آخر اختيار في نافذة التحميل.
  Future<void> saveChoice({
    required bool audio,
    required String quality,
    required String bitrate,
  }) async {
    audioMode = audio;
    this.quality = quality;
    this.bitrate = bitrate;
    await _p?.setBool('audio_mode', audio);
    await _p?.setString('video_quality', quality);
    await _p?.setString('audio_bitrate', bitrate);
    notifyListeners();
  }

  Future<void> setEngine(String url, String key) async {
    endpoint = url.trim();
    apiKey = key.trim();
    await _p?.setString('cobalt_endpoint', endpoint);
    await _p?.setString('cobalt_api_key', apiKey);
    notifyListeners();
  }
}
