import 'dart:io';
import 'package:flutter/material.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/download_manager.dart';
import '../services/history_store.dart';
import '../services/native_bridge.dart';
import '../widgets/common.dart';
import 'player_screen.dart';

class _FileInfo {
  final File file;
  final int size;
  final DateTime modified;
  const _FileInfo(this.file, this.size, this.modified);
  String get name => baseName(file.path);
  bool get isAudio => isAudioExt(extensionOf(file.path) ?? '');
}

/// الملفات المحملة داخل مجلد التطبيق.
class FilesTab extends StatefulWidget {
  const FilesTab({super.key});

  @override
  State<FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<FilesTab> {
  List<_FileInfo> _files = [];
  bool _loading = true;
  int _lastDone = -1;

  @override
  void initState() {
    super.initState();
    DownloadManager.instance.addListener(_onManager);
    _load();
  }

  @override
  void dispose() {
    DownloadManager.instance.removeListener(_onManager);
    super.dispose();
  }

  void _onManager() {
    final d = DownloadManager.instance.doneCounter;
    if (d != _lastDone) {
      _lastDone = d;
      _load();
    }
  }

  Future<void> _load() async {
    final dir = await DownloadManager.instance.downloadsDir();
    final list = <_FileInfo>[];
    await for (final e in dir.list()) {
      if (e is File && !e.path.endsWith('.part')) {
        final st = await e.stat();
        list.add(_FileInfo(e, st.size, st.modified));
      }
    }
    list.sort((a, b) => b.modified.compareTo(a.modified));
    if (mounted) {
      setState(() {
        _files = list;
        _loading = false;
      });
    }
  }

  Future<void> _delete(_FileInfo f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.cardColor2,
        title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        content: Text(ctx.tr('delete_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.tr('delete'), style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await f.file.delete();
    } catch (_) {}
    await HistoryStore.instance.removeByPath(f.file.path);
    await _load();
  }

  Future<void> _export(_FileInfo f) async {
    final ext = extensionOf(f.file.path) ?? 'mp4';
    final ok = await NativeBridge.instance.saveToDownloads(f.file.path, f.name, mimeForExt(ext));
    if (mounted) showSnack(context, context.tr(ok ? 'exported' : 'export_failed'));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(
              context.tr('tab_files'),
              style: TextStyle(color: context.textColor, fontSize: 24, fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _files.isEmpty ? _empty(context) : _list(context),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) => ListView(
        children: [
          const SizedBox(height: 90),
          Center(child: Icon(Icons.folder_open_rounded, size: 72, color: context.mutedColor)),
          const SizedBox(height: 12),
          Center(
            child: Text(context.tr('files_empty'), style: TextStyle(color: context.mutedColor)),
          ),
        ],
      );

  Widget _list(BuildContext context) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        itemCount: _files.length,
        itemBuilder: (context, i) {
          final f = _files[i];
          return AppCard(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PlayerScreen(path: f.file.path, title: f.name)),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: AppColors.gradient,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    f.isAudio ? Icons.music_note_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${formatBytes(f.size)}  •  ${formatDate(f.modified)}',
                        style: TextStyle(color: context.mutedColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: context.mutedColor),
                  color: context.cardColor2,
                  onSelected: (v) {
                    if (v == 'export') _export(f);
                    if (v == 'delete') _delete(f);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'export', child: Text(context.tr('export'))),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(context.tr('delete'), style: const TextStyle(color: AppColors.danger)),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
}
