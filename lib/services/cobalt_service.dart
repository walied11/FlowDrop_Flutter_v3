import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class CobaltPickerItem {
  final String url;
  final String type; // video | photo | gif | audio
  final String? thumb;
  const CobaltPickerItem({required this.url, required this.type, this.thumb});
}

class CobaltResult {
  final bool isPicker;
  final List<CobaltPickerItem> items;
  final String? filename;
  const CobaltResult({
    required this.isPicker,
    required this.items,
    this.filename,
  });
}

/// code: auth | fetch | rate | duration | unsupported | network | local | generic
class CobaltException implements Exception {
  final String code;
  const CobaltException(this.code);
  @override
  String toString() => 'CobaltException($code)';
}

/// عميل لمحرك Cobalt (https://github.com/imputnet/cobalt).
/// أنت تضبط رابط المحرك ومفتاح API من شاشة الإعدادات.
class CobaltService {
  static Uri endpointUri(String raw) {
    var e = raw.trim();
    if (e.isEmpty) e = 'https://api.cobalt.tools/';
    if (!e.startsWith('http://') && !e.startsWith('https://')) e = 'https://$e';
    if (!e.endsWith('/')) e = '$e/';
    return Uri.parse(e);
  }

  static String qualityValue(String q) {
    if (q.toUpperCase() == 'MAX') return 'max';
    return q.replaceAll('p', '').replaceAll('P', '');
  }

  static Future<CobaltResult> resolve({
    required String url,
    required String endpoint,
    required String apiKey,
    required bool audio,
    required String quality,
    required String bitrate,
  }) async {
    final body = <String, dynamic>{
      'url': url,
      'videoQuality': audio ? '720' : qualityValue(quality),
      'audioFormat': 'mp3',
      'audioBitrate': bitrate,
      'downloadMode': audio ? 'audio' : 'auto',
      'filenameStyle': 'pretty',
      'youtubeVideoCodec': 'h264',
      'youtubeVideoContainer': 'mp4',
    };
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'FlowDrop/1.0 Android',
    };
    if (apiKey.trim().isNotEmpty) {
      headers['Authorization'] = 'Api-Key ${apiKey.trim()}';
    }

    http.Response res;
    try {
      res = await http
          .post(endpointUri(endpoint), headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const CobaltException('network');
    } catch (_) {
      throw const CobaltException('network');
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw CobaltException(res.statusCode == 401 || res.statusCode == 403 ? 'auth' : 'generic');
    }

    final status = (json['status'] ?? '').toString();
    switch (status) {
      case 'tunnel':
      case 'redirect':
        final u = (json['url'] ?? '').toString();
        if (u.isEmpty) throw const CobaltException('generic');
        return CobaltResult(
          isPicker: false,
          items: [CobaltPickerItem(url: u, type: audio ? 'audio' : 'video')],
          filename: json['filename']?.toString(),
        );
      case 'picker':
        final list = <CobaltPickerItem>[];
        final picker = json['picker'];
        if (picker is List) {
          for (final it in picker) {
            if (it is Map && (it['url'] ?? '').toString().isNotEmpty) {
              list.add(CobaltPickerItem(
                url: it['url'].toString(),
                type: (it['type'] ?? 'video').toString(),
                thumb: it['thumb']?.toString(),
              ));
            }
          }
        }
        final audioUrl = (json['audio'] ?? '').toString();
        if (audioUrl.isNotEmpty) {
          list.add(CobaltPickerItem(url: audioUrl, type: 'audio'));
        }
        if (list.isEmpty) throw const CobaltException('generic');
        return CobaltResult(isPicker: true, items: list, filename: json['audioFilename']?.toString());
      case 'local-processing':
        throw const CobaltException('local');
      default:
        final err = json['error'];
        final code = err is Map ? (err['code'] ?? '').toString() : '';
        throw CobaltException(mapError(code, res.statusCode));
    }
  }

  static String mapError(String code, int httpStatus) {
    final c = code.toLowerCase();
    if (c.contains('auth') || httpStatus == 401 || httpStatus == 403) return 'auth';
    if (c.contains('rate')) return 'rate';
    if (c.contains('duration') || c.contains('length')) return 'duration';
    if (c.contains('unsupported') || c.contains('link.invalid') || c.contains('service')) {
      return 'unsupported';
    }
    if (c.contains('fetch') || c.contains('media') || c.contains('content')) return 'fetch';
    return 'generic';
  }
}
