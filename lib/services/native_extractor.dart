import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/utils.dart';

/// جودة واحدة متاحة فعليًا للفيديو.
class MediaOption {
  final String url;
  final String label; // نص قصير ASCII مثل 720p أو HD (يُستعمل أيضًا في اسم الملف)
  final int height; // 0 إذا غير معروف (للترتيب فقط)
  final int sizeBytes; // 0 إذا غير معروف
  final bool hasAudio;
  final bool audioOnly; // ملف صوت فقط
  final String? ext; // امتداد مُحدَّد إن لم يظهر من الرابط
  final String thumb; // صورة مصغرة (رابط) إن وُجدت
  const MediaOption({
    required this.url,
    required this.label,
    required this.height,
    this.sizeBytes = 0,
    this.hasAudio = true,
    this.audioOnly = false,
    this.ext,
    this.thumb = '',
  });

  MediaOption withSize(int size) => MediaOption(
        url: url,
        label: label,
        height: height,
        sizeBytes: size,
        hasAudio: hasAudio,
        audioOnly: audioOnly,
        ext: ext,
        thumb: thumb,
      );
}

/// اختيار المستخدم من نافذة الجودات: فيديو بجودة محددة أو صوت فقط.
class MediaPick {
  final MediaOption? option; // null عند اختيار الصوت
  final bool audio;
  const MediaPick.video(MediaOption o)
      : option = o,
        audio = false;
  const MediaPick.audio()
      : option = null,
        audio = true;
}

/// مستخرِج الروابط المدمج (منقول من MainActivity.java).
/// يعمل بدون Cobalt وبدون مفتاح API: يجلب صفحة المنصة أو يستعمل واجهات
/// خارجية (tikwm / mobifb / snapfb) ويُرجع رابط ملف الفيديو المباشر.
class NativeExtractor {
  static const String _ua =
      'Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

  static const Map<String, String> _headers = {
    'User-Agent': _ua,
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9,ar;q=0.8',
    'sec-ch-ua': '"Chromium";v="124", "Google Chrome";v="124"',
    'sec-ch-ua-mobile': '?1',
    'sec-ch-ua-platform': '"Android"',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'none',
    'Upgrade-Insecure-Requests': '1',
  };

  /// يُرجع الجودات المتاحة فعليًا للرابط (الأعلى أولًا). قائمة فارغة إذا فشل الاستخراج.
  static Future<List<MediaOption>> options(String url) async {
    List<MediaOption> list;
    try {
      list = await _extract(url.trim());
    } catch (_) {
      list = [];
    }
    list = list.where((o) => o.url.startsWith('http')).toList();
    if (list.isEmpty) return list;

    // حجم كل ملف الفعلي عبر HEAD (بالتوازي) إن لم يكن معروفًا.
    final sized = await Future.wait(list.map((o) async {
      if (o.sizeBytes > 0) return o;
      final size = await _probeSize(o.url);
      return size > 0 ? o.withSize(size) : o;
    }));
    sized.sort((a, b) {
      if (a.audioOnly != b.audioOnly) return a.audioOnly ? 1 : -1;
      return b.height.compareTo(a.height);
    });
    return sized;
  }

  static Future<int> _probeSize(String url) async {
    try {
      final res = await http
          .head(Uri.parse(url), headers: const {'User-Agent': _ua})
          .timeout(const Duration(seconds: 6));
      if (res.statusCode >= 400) return 0;
      return int.tryParse(res.headers['content-length'] ?? '') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<List<MediaOption>> _extract(String url) async {
    switch (platformOf(url)) {
      case 'facebook':
        return _facebook(url);
      case 'tiktok':
        return _tiktok(url);
      case 'youtube':
        return _youtube(url);
      case 'reddit':
        return _reddit(url);
      case 'x':
      case 'instagram':
      case 'threads':
      case 'pinterest':
      case 'snapchat':
        final page = await _fetchHtml(url);
        final og = ogVideo(page);
        return og == null
            ? []
            : [MediaOption(url: og, label: 'MP4', height: 360, thumb: ogImage(page) ?? '')];
      default:
        return [];
    }
  }

  // ───────────────────────── شبكة ─────────────────────────

  static Future<String> _fetchHtml(String url, {int timeoutSec = 15}) async {
    try {
      final res = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(Duration(seconds: timeoutSec));
      return utf8.decode(res.bodyBytes, allowMalformed: true);
    } catch (_) {
      return '';
    }
  }

  /// يتتبع التحويلات يدويًا ويُرجع آخر رابط.
  static Future<String> _followRedirects(String url, {int maxHops = 10}) async {
    var current = url;
    final client = http.Client();
    try {
      for (var i = 0; i < maxHops; i++) {
        final req = http.Request('GET', Uri.parse(current))
          ..followRedirects = false
          ..headers.addAll(_headers);
        final res = await client.send(req).timeout(const Duration(seconds: 10));
        await res.stream.drain();
        final code = res.statusCode;
        if (code == 301 || code == 302 || code == 303 || code == 307 || code == 308) {
          var loc = res.headers['location'];
          if (loc == null || loc.isEmpty) break;
          if (loc.startsWith('/')) {
            final u = Uri.parse(current);
            loc = '${u.scheme}://${u.host}$loc';
          }
          current = loc;
        } else {
          break;
        }
      }
    } catch (_) {
      // نكتفي بآخر رابط وصلنا إليه.
    } finally {
      client.close();
    }
    return current;
  }

  // ───────────────────────── Facebook ─────────────────────────

  static Future<List<MediaOption>> _facebook(String raw) async {
    var url = raw;
    if (url.contains('/share/') || url.contains('fb.watch')) {
      var resolved = await _followRedirects(url);
      resolved = resolved.split('?').first;
      final m = RegExp(r'facebook\.com/(reel|videos|watch|story|photo\.php)/[^/?]+')
          .firstMatch(resolved);
      url = m != null ? 'https://www.facebook.com/${m.group(0)!.replaceFirst('facebook.com/', '')}' : resolved;
    }

    // 1) من صفحة الفيديو مباشرة
    final pageHtml = await _fetchHtml(url);
    final thumb = ogImage(pageHtml) ?? '';
    final fromPage = _facebookOptions(pageHtml, thumb);
    if (fromPage.isNotEmpty) return fromPage;

    // 2) واجهات خارجية
    final enc = Uri.encodeComponent(url);
    var json = await _fetchHtml('https://mobifb.org/api/convert?url=$enc', timeoutSec: 12);
    final hd = jsonKey(json, 'hd');
    final sd = jsonKey(json, 'sd');
    final out = <MediaOption>[];
    if (hd != null && hd.startsWith('http')) out.add(MediaOption(url: hd, label: 'HD', height: 720, thumb: thumb));
    if (sd != null && sd.startsWith('http') && sd != hd) {
      out.add(MediaOption(url: sd, label: 'SD', height: 360, thumb: thumb));
    }
    if (out.isNotEmpty) return out;
    final one = jsonKey(json, 'url');
    if (one != null && one.startsWith('http')) return [MediaOption(url: one, label: 'MP4', height: 360, thumb: thumb)];

    json = await _fetchHtml('https://api.snapfb.com/api/convert?url=$enc', timeoutSec: 12);
    final v2 = jsonKey(json, 'url');
    if (v2 != null && v2.startsWith('http')) return [MediaOption(url: v2, label: 'MP4', height: 360, thumb: thumb)];

    // 3) tikwm كحل أخير
    json = await _fetchHtml('https://www.tikwm.com/api/?url=$enc&hd=1', timeoutSec: 12);
    final v3 = jsonKey(json, 'hdplay');
    if (v3 != null && v3.startsWith('http')) return [MediaOption(url: v3, label: 'HD', height: 720, thumb: thumb)];
    return [];
  }

  static List<MediaOption> _facebookOptions(String html, String thumb) {
    if (html.isEmpty) return [];
    final clean = html
        .replaceAll(r'\/', '/')
        .replaceAll(r'\u0026', '&')
        .replaceAll(r'\u0025', '%')
        .replaceAll('&amp;', '&');

    String? firstOf(List<String> keys) {
      for (final key in keys) {
        final m = RegExp('"$key"\\s*:\\s*"(https:[^"]+)"').firstMatch(clean);
        if (m != null) return m.group(1);
      }
      return null;
    }

    final hd = firstOf(const ['browser_native_hd_url', 'playable_url_quality_hd', 'hd_src']);
    final sd = firstOf(const ['browser_native_sd_url', 'playable_url', 'sd_src']);
    final out = <MediaOption>[];
    if (hd != null) out.add(MediaOption(url: hd, label: 'HD', height: 720, thumb: thumb));
    if (sd != null && sd != hd) out.add(MediaOption(url: sd, label: 'SD', height: 360, thumb: thumb));
    if (out.isNotEmpty) return out;

    // بحث عام عن روابط mp4 في الصفحة
    final seen = <String>{};
    final labels = <String>{};
    for (final cand in allMp4(clean)) {
      final key = cand.split('?').first;
      if (!seen.add(key)) continue;
      final int h;
      final String label;
      if (cand.contains('1080') || cand.contains('fhd')) {
        h = 1080;
        label = '1080p';
      } else if (cand.contains('720')) {
        h = 720;
        label = '720p';
      } else if (cand.contains('hd') || cand.contains('HD') || cand.contains('high')) {
        h = 720;
        label = 'HD';
      } else {
        h = 360;
        label = 'SD';
      }
      if (labels.add(label)) out.add(MediaOption(url: cand, label: label, height: h, thumb: thumb));
    }
    if (out.isNotEmpty) return out;
    final og = ogVideo(clean);
    return og == null ? [] : [MediaOption(url: og, label: 'MP4', height: 360, thumb: thumb)];
  }

  /// كل روابط .mp4 الموجودة في الصفحة (منقولة من findMp4 في Java).
  static List<String> allMp4(String html) {
    final out = <String>[];
    var from = 0;
    while (true) {
      final idx = html.indexOf('.mp4', from);
      if (idx < 0) break;
      final hIdx = html.lastIndexOf('https://', idx);
      if (hIdx >= 0 && idx - hIdx < 800) {
        var en = idx + 4;
        while (en < html.length) {
          final ch = html[en];
          if (ch == '"' || ch == "'" || ch == ')' || ch == '<' || ch == ' ' || ch == '\n') break;
          en++;
        }
        final cand = html.substring(hIdx, en).replaceAll('&amp;', '&');
        if (cand.startsWith('https://') && cand.contains('.mp4')) out.add(cand);
      }
      from = idx + 4;
    }
    return out;
  }

  // ───────────────────────── TikTok ─────────────────────────

  static Future<List<MediaOption>> _tiktok(String url) async {
    final enc = Uri.encodeComponent(url);
    final json = await _fetchHtml('https://www.tikwm.com/api/?url=$enc&hd=1', timeoutSec: 14);
    String? hd, sd, music;
    var thumb = '';
    var hdSize = 0, sdSize = 0;
    try {
      final data = (jsonDecode(json) as Map)['data'];
      if (data is Map) {
        hd = data['hdplay']?.toString();
        sd = data['play']?.toString();
        music = data['music']?.toString();
        thumb = (data['cover'] ?? data['origin_cover'] ?? '').toString();
        hdSize = (data['hd_size'] as num?)?.toInt() ?? 0;
        sdSize = (data['size'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {
      hd = jsonKey(json, 'hdplay');
      sd = jsonKey(json, 'play');
    }
    final out = <MediaOption>[];
    if (hd != null && hd.isNotEmpty) {
      out.add(MediaOption(url: _normalizeTik(hd), label: 'HD', height: 720, sizeBytes: hdSize, thumb: thumb));
    }
    if (sd != null && sd.isNotEmpty && sd != hd) {
      out.add(MediaOption(url: _normalizeTik(sd), label: 'SD', height: 360, sizeBytes: sdSize, thumb: thumb));
    }
    if (music != null && music.isNotEmpty && out.isNotEmpty) {
      out.add(MediaOption(
        url: _normalizeTik(music),
        label: 'MP3',
        height: 0,
        audioOnly: true,
        ext: 'mp3',
        thumb: thumb,
      ));
    }
    return out;
  }

  static String _normalizeTik(String v) {
    if (v.startsWith('http')) return v;
    if (v.startsWith('//')) return 'https:$v';
    if (v.startsWith('/')) return 'https://www.tikwm.com$v';
    return v;
  }

  // ───────────────────────── YouTube ─────────────────────────

  static String? _youtubeId(String url) {
    for (final p in [
      RegExp(r'youtu\.be/([a-zA-Z0-9_-]{6,})'),
      RegExp(r'[?&]v=([a-zA-Z0-9_-]{6,})'),
      RegExp(r'/shorts/([a-zA-Z0-9_-]{6,})'),
    ]) {
      final m = p.firstMatch(url);
      if (m != null) return m.group(1);
    }
    return null;
  }

  static Future<List<MediaOption>> _youtube(String url) async {
    final vid = _youtubeId(url);
    if (vid == null) return [];
    final html = await _fetchHtml('https://www.youtube.com/watch?v=$vid&hl=en&has_verified=1');
    final player = _between(html, 'ytInitialPlayerResponse = ', '</script>');
    if (player == null) return [];
    try {
      final data = jsonDecode(player) as Map<String, dynamic>;
      final sd = data['streamingData'];
      if (sd is! Map) return [];

      List<MediaOption> collect(String key, bool hasAudio) {
        final list = sd[key];
        final out = <MediaOption>[];
        if (list is! List) return out;
        final labels = <String>{};
        for (final f in list) {
          if (f is! Map) continue;
          final mime = (f['mimeType'] ?? '').toString();
          final u = (f['url'] ?? '').toString();
          if (!mime.startsWith('video') || !u.contains('googlevideo.com')) continue;
          final h = (f['height'] as num?)?.toInt() ?? 0;
          final label = (f['qualityLabel'] ?? (h > 0 ? '${h}p' : 'MP4')).toString();
          if (!labels.add(label)) continue;
          out.add(MediaOption(
            url: u,
            label: label,
            height: h,
            thumb: 'https://i.ytimg.com/vi/$vid/hqdefault.jpg',
            hasAudio: hasAudio,
            sizeBytes: int.tryParse((f['contentLength'] ?? '').toString()) ?? 0,
          ));
        }
        return out;
      }

      final muxed = collect('formats', true);
      final videos = muxed.isNotEmpty ? muxed : collect('adaptiveFormats', false);

      // أفضل مسار صوت فقط (M4A)
      MediaOption? audio;
      final af = sd['adaptiveFormats'];
      if (af is List) {
        var bestRate = -1;
        for (final f in af) {
          if (f is! Map) continue;
          final mime = (f['mimeType'] ?? '').toString();
          final u = (f['url'] ?? '').toString();
          if (!mime.startsWith('audio/mp4') || !u.contains('googlevideo.com')) continue;
          final rate = (f['bitrate'] as num?)?.toInt() ?? 0;
          if (rate > bestRate) {
            bestRate = rate;
            audio = MediaOption(
              url: u,
              label: 'M4A',
              height: 0,
              audioOnly: true,
              ext: 'm4a',
              sizeBytes: int.tryParse((f['contentLength'] ?? '').toString()) ?? 0,
            );
          }
        }
      }
      return [...videos, if (audio != null) audio];
    } catch (_) {
      return [];
    }
  }

  static String? _between(String text, String start, String end) {
    final s = text.indexOf(start);
    if (s < 0) return null;
    final from = s + start.length;
    final e = text.indexOf(end, from);
    if (e < 0) return null;
    var chunk = text.substring(from, e).trim();
    if (chunk.endsWith(';')) chunk = chunk.substring(0, chunk.length - 1);
    return chunk;
  }

  // ───────────────────────── Reddit ─────────────────────────

  static Future<List<MediaOption>> _reddit(String url) async {
    var clean = url.split('?').first;
    if (!clean.endsWith('.json')) clean = '$clean.json';
    final json = await _fetchHtml(clean, timeoutSec: 12);
    final fb = jsonKey(json, 'fallback_url');
    if (fb != null && fb.startsWith('http')) {
      final h = int.tryParse(RegExp(r'DASH_(\d+)').firstMatch(fb)?.group(1) ?? '') ?? 0;
      return [
        MediaOption(
          url: fb.replaceAll('&amp;', '&'),
          label: h > 0 ? '${h}p' : 'MP4',
          height: h,
          hasAudio: false,
        )
      ];
    }
    final od = jsonKey(json, 'url_overridden_by_dest');
    if (od != null && (od.endsWith('.mp4') || od.contains('v.redd.it'))) {
      return [MediaOption(url: od, label: 'MP4', height: 360)];
    }
    final og = ogVideo(await _fetchHtml(url));
    return og == null ? [] : [MediaOption(url: og, label: 'MP4', height: 360)];
  }

  // ───────────────────────── أدوات ─────────────────────────

  static String? ogImage(String html) {
    if (html.isEmpty) return null;
    final h = html.replaceAll('&amp;', '&');
    for (final marker in const [
      'property="og:image" content="',
      'property="og:image:secure_url" content="',
      'name="twitter:image" content="',
    ]) {
      final idx = h.indexOf(marker);
      if (idx >= 0) {
        final st = idx + marker.length;
        final e = h.indexOf('"', st);
        if (e > st) return h.substring(st, e);
      }
    }
    return null;
  }

  static String? ogVideo(String html) {
    if (html.isEmpty) return null;
    final h = html.replaceAll('&amp;', '&');
    for (final marker in const [
      'property="og:video:secure_url" content="',
      'property="og:video" content="',
      'property="og:video:url" content="',
    ]) {
      final idx = h.indexOf(marker);
      if (idx >= 0) {
        final s = idx + marker.length;
        final e = h.indexOf('"', s);
        if (e > s) return h.substring(s, e);
      }
    }
    return null;
  }

  /// منقولة من extractJson في Java (استخراج قيمة مفتاح بدون تحليل كامل).
  static String? jsonKey(String json, String key) {
    if (json.isEmpty) return null;
    final pat = '"$key"';
    final idx = json.indexOf(pat);
    if (idx < 0) return null;
    final colon = json.indexOf(':', idx + pat.length);
    if (colon < 0) return null;
    var i = colon + 1;
    while (i < json.length && (json[i] == ' ' || json[i] == '\n')) {
      i++;
    }
    final quoted = i < json.length && json[i] == '"';
    if (quoted) i++;
    final start = i;
    var end = start;
    if (quoted) {
      end = json.indexOf('"', start);
    } else {
      while (end < json.length && json[end] != ',' && json[end] != '}' && json[end] != ']') {
        end++;
      }
    }
    if (end < start) return null;
    return json.substring(start, end).replaceAll(r'\/', '/').replaceAll(r'\u0026', '&').trim();
  }
}
