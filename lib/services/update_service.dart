import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import '../core/utils.dart';

class UpdateInfo {
  final String current;
  final String latest;
  final String minimum;
  final String url;
  final String message;
  final bool force;

  const UpdateInfo({
    required this.current,
    required this.latest,
    required this.minimum,
    required this.url,
    required this.message,
    required this.force,
  });

  bool get available => latest.isNotEmpty && compareVersions(latest, current) > 0;
  bool get belowMinimum => compareVersions(current, minimum) < 0;
  bool get mustUpdate => belowMinimum || (force && available);
  bool get shouldShow => mustUpdate || available;
}

/// فحص التحديث من Firebase Realtime Database عبر REST (بدون حزم Firebase).
/// العقدة: /app_update  — انظر FIREBASE_UPDATE_SETUP_AR.md
class UpdateService {
  static const String configUrl =
      'https://walied-f4f1b-default-rtdb.firebaseio.com/app_update.json';

  /// يعيد null إذا تعذر الاتصال أو لم تُضبط العقدة (لا نوقف التطبيق).
  static Future<UpdateInfo?> check() async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      final res = await http
          .get(Uri.parse(configUrl))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final body = res.body.trim();
      if (body.isEmpty || body == 'null') return null;
      final j = jsonDecode(body);
      if (j is! Map) return null;
      String pick(List<String> keys, String fallback) {
        for (final k in keys) {
          final v = j[k];
          if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
        }
        return fallback;
      }

      bool pickBool(List<String> keys) => keys.any((k) => j[k] == true);

      return UpdateInfo(
        current: pkg.version,
        latest: pick(['latestVersion', 'latest_version_name'], ''),
        minimum: pick(['minimumVersion', 'minVersion', 'min_version_name'], '0.0.0'),
        url: pick(['updateUrl', 'apkUrl', 'update_url'], ''),
        message: pick(['message', 'releaseNotes', 'update_message'], ''),
        force: pickBool(['forceUpdate', 'update_force']),
      );
    } catch (_) {
      return null;
    }
  }
}
