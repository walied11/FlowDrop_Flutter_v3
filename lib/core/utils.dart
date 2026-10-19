/// دوال مساعدة عامة.

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  double v = bytes.toDouble();
  int i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
}

String formatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}  ${two(d.hour)}:${two(d.minute)}';
}

String formatDuration(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// يستخرج أول رابط http/https من نص (مفيد عند المشاركة من التطبيقات).
String? extractUrl(String text) {
  final m = RegExp(r'https?://[^\s]+').firstMatch(text);
  if (m == null) return null;
  return m.group(0)!.replaceAll(RegExp(r'[)\]}>.,;]+$'), '');
}

const _mediaExts = [
  '.mp4', '.m4v', '.webm', '.mkv', '.mov',
  '.mp3', '.m4a', '.aac', '.ogg', '.wav', '.flac',
];
const _audioExts = ['mp3', 'm4a', 'aac', 'ogg', 'wav', 'flac'];

/// هل الرابط يشير مباشرة إلى ملف وسائط؟
bool isDirectMediaUrl(String url) {
  final u = Uri.tryParse(url);
  if (u == null) return false;
  final p = u.path.toLowerCase();
  return _mediaExts.any(p.endsWith);
}

bool isAudioExt(String ext) => _audioExts.contains(ext.toLowerCase().replaceAll('.', ''));

String? extensionOf(String nameOrPath) {
  final clean = nameOrPath.split('?').first;
  final slash = clean.lastIndexOf('/');
  final base = slash >= 0 ? clean.substring(slash + 1) : clean;
  final dot = base.lastIndexOf('.');
  if (dot <= 0 || dot == base.length - 1) return null;
  final ext = base.substring(dot + 1).toLowerCase();
  if (ext.length > 5) return null;
  return ext;
}

String stripExtension(String name) {
  final dot = name.lastIndexOf('.');
  return dot > 0 ? name.substring(0, dot) : name;
}

String baseName(String path) {
  final i = path.lastIndexOf('/');
  return i >= 0 ? path.substring(i + 1) : path;
}

String sanitizeFileName(String s) {
  var out = s.replaceAll(RegExp(r'[\\/:*?"<>|\n\r\t]'), '_').trim();
  if (out.length > 100) out = out.substring(0, 100);
  return out.isEmpty ? 'file' : out;
}

String mimeForExt(String ext) {
  switch (ext.toLowerCase()) {
    case 'mp3':
      return 'audio/mpeg';
    case 'm4a':
      return 'audio/mp4';
    case 'aac':
      return 'audio/aac';
    case 'ogg':
      return 'audio/ogg';
    case 'wav':
      return 'audio/wav';
    case 'flac':
      return 'audio/flac';
    case 'webm':
      return 'video/webm';
    case 'mkv':
      return 'video/x-matroska';
    case 'mov':
      return 'video/quicktime';
    default:
      return 'video/mp4';
  }
}

/// اسم المنصة من الرابط (للعرض وتسمية الملفات).
String platformOf(String url) {
  final host = (Uri.tryParse(url)?.host ?? '').toLowerCase();
  bool has(String s) => host == s || host.endsWith('.$s');
  if (has('tiktok.com')) return 'tiktok';
  if (has('facebook.com') || has('fb.watch') || has('fb.com')) return 'facebook';
  if (has('instagram.com')) return 'instagram';
  if (has('threads.net') || has('threads.com')) return 'threads';
  if (has('x.com') || has('twitter.com') || has('t.co')) return 'x';
  if (has('youtube.com') || has('youtu.be')) return 'youtube';
  if (has('pinterest.com') || has('pin.it')) return 'pinterest';
  if (has('reddit.com') || has('redd.it')) return 'reddit';
  if (has('snapchat.com')) return 'snapchat';
  return 'web';
}

/// يقارن إصدارين مثل 1.0.1 و 1.2.0 (يتجاهل +build).
int compareVersions(String a, String b) {
  List<int> parts(String v) => v
      .replaceAll('v', '')
      .split('+')
      .first
      .split('-')
      .first
      .split('.')
      .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9].*'), '')) ?? 0)
      .toList();
  final x = parts(a);
  final y = parts(b);
  final n = x.length > y.length ? x.length : y.length;
  for (var i = 0; i < n; i++) {
    final xv = i < x.length ? x[i] : 0;
    final yv = i < y.length ? y[i] : 0;
    if (xv != yv) return xv < yv ? -1 : 1;
  }
  return 0;
}
