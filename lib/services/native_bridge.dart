import 'dart:async';
import 'package:flutter/services.dart';

/// جسر بسيط مع كود Android (Kotlin) للحفظ في Downloads واستقبال المشاركة.
class NativeBridge {
  NativeBridge._();
  static final NativeBridge instance = NativeBridge._();

  static const MethodChannel _ch = MethodChannel('com.smali.fox/native');
  final StreamController<String> _shared = StreamController<String>.broadcast();
  bool _inited = false;

  Stream<String> get sharedText => _shared.stream;

  void init() {
    if (_inited) return;
    _inited = true;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'sharedText' && call.arguments is String) {
        _shared.add(call.arguments as String);
      }
      return null;
    });
  }

  /// النص الذي فُتح به التطبيق عبر "مشاركة" (إن وُجد).
  Future<String?> initialText() async {
    try {
      return await _ch.invokeMethod<String>('getInitialText');
    } catch (_) {
      return null;
    }
  }

  /// ينسخ ملفًا إلى Downloads/FlowDrop. يعيد true عند النجاح.
  Future<bool> saveToDownloads(String path, String name, String mime) async {
    try {
      final ok = await _ch.invokeMethod<bool>('saveToDownloads', {
        'path': path,
        'name': name,
        'mime': mime,
      });
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  /// ينسخ مسار الصوت من فيديو إلى ملف M4A (بدون إعادة ترميز).
  Future<bool> extractAudio(String src, String dst) async {
    try {
      return (await _ch.invokeMethod<bool>('extractAudio', {'src': src, 'dst': dst})) == true;
    } catch (_) {
      return false;
    }
  }

  /// يحفظ صورة مصغرة JPEG من الفيديو.
  Future<bool> thumbnail(String src, String dst) async {
    try {
      return (await _ch.invokeMethod<bool>('thumbnail', {'src': src, 'dst': dst})) == true;
    } catch (_) {
      return false;
    }
  }
}
