import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/history_store.dart';
import '../widgets/common.dart';

/// سجل التحميلات المكتملة.
class HistoryTab extends StatelessWidget {
  final void Function(String url) onRedownload;
  const HistoryTab({super.key, required this.onRedownload});

  Future<void> _clear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.cardColor2,
        content: Text(ctx.tr('clear_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.tr('clear_all'), style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) await HistoryStore.instance.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: AnimatedBuilder(
        animation: HistoryStore.instance,
        builder: (context, _) {
          final list = HistoryStore.instance.entries;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('tab_history'),
                        style: TextStyle(
                          color: context.textColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (list.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => _clear(context),
                        icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.danger, size: 20),
                        label: Text(
                          context.tr('clear_all'),
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history_rounded, size: 72, color: context.mutedColor),
                            const SizedBox(height: 12),
                            Text(context.tr('history_empty'), style: TextStyle(color: context.mutedColor)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final e = list[i];
                          return AppCard(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                            child: Row(
                              children: [
                                VideoThumb(thumb: e.thumb, platform: e.platform),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e.fileName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: context.textColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${platformLabel(e.platform)}  •  ${formatDate(e.date)}',
                                        style: TextStyle(color: context.mutedColor, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert_rounded, color: context.mutedColor),
                                  color: context.cardColor2,
                                  onSelected: (v) async {
                                    if (v == 'copy') {
                                      await Clipboard.setData(ClipboardData(text: e.sourceUrl));
                                      if (context.mounted) showSnack(context, context.tr('copied'));
                                    } else if (v == 'again') {
                                      onRedownload(e.sourceUrl);
                                    } else if (v == 'remove') {
                                      await HistoryStore.instance.remove(e.id);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(value: 'again', child: Text(context.tr('redownload'))),
                                    PopupMenuItem(value: 'copy', child: Text(context.tr('copy_link'))),
                                    PopupMenuItem(value: 'remove', child: Text(context.tr('remove'))),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
