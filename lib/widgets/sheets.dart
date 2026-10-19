import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_scope.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../services/cobalt_service.dart';
import '../services/native_extractor.dart';
import '../core/utils.dart';
import '../services/settings_store.dart';
import '../services/update_service.dart';
import 'common.dart';

class DownloadChoice {
  final bool audio;
  final String quality;
  final String bitrate;
  const DownloadChoice({required this.audio, required this.quality, required this.bitrate});
}

Future<DownloadChoice?> showDownloadOptions(BuildContext context) {
  return showModalBottomSheet<DownloadChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _OptionsSheet(),
  );
}

class _SheetFrame extends StatelessWidget {
  final String title;
  final Widget child;
  const _SheetFrame({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: context.cardColor2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: context.borderColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                title,
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 6),
            child,
          ],
        ),
      ),
    );
  }
}

class _OptionsSheet extends StatefulWidget {
  const _OptionsSheet();

  @override
  State<_OptionsSheet> createState() => _OptionsSheetState();
}

class _OptionsSheetState extends State<_OptionsSheet> {
  late bool audio;
  late String quality;
  late String bitrate;
  bool _inited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inited) {
      final s = AppScope.of(context);
      audio = s.audioMode;
      quality = s.quality;
      bitrate = s.bitrate;
      _inited = true;
    }
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(
          t,
          style: TextStyle(
            color: context.mutedColor,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: context.tr('choose_type'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: PillOption(
                  label: context.tr('video_mp4'),
                  icon: Icons.movie_rounded,
                  selected: !audio,
                  onTap: () => setState(() => audio = false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PillOption(
                  label: context.tr('audio_mp3'),
                  icon: Icons.music_note_rounded,
                  selected: audio,
                  onTap: () => setState(() => audio = true),
                ),
              ),
            ],
          ),
          if (!audio) ...[
            _label(context.tr('video_quality')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final q in AppSettings.qualities)
                  PillOption(
                    label: q,
                    selected: quality == q,
                    onTap: () => setState(() => quality = q),
                  ),
              ],
            ),
          ] else ...[
            _label(context.tr('audio_bitrate')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final b in AppSettings.bitrates)
                  PillOption(
                    label: b,
                    selected: bitrate == b,
                    onTap: () => setState(() => bitrate = b),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 22),
          GradientButton(
            label: context.tr('start_download'),
            icon: Icons.download_rounded,
            onPressed: () => Navigator.pop(
              context,
              DownloadChoice(audio: audio, quality: quality, bitrate: bitrate),
            ),
          ),
        ],
      ),
    );
  }
}

/// الجودات المتاحة فعليًا لهذا الفيديو + خيار "صوت فقط".
Future<MediaPick?> showQualitySheet(BuildContext context, List<MediaOption> options) {
  final videos = options.where((o) => !o.audioOnly).toList();
  final audios = options.where((o) => o.audioOnly).toList();
  final MediaOption? audioOpt = audios.isEmpty ? null : audios.first;
  final canExtract = videos.any((o) => o.hasAudio);

  Widget row(BuildContext ctx, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: ctx.bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ctx.borderColor),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: ctx.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: ctx.mutedColor, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<MediaPick>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SheetFrame(
      title: ctx.tr('choose_quality'),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.65),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(top: 12),
          children: [
            for (final o in videos)
              row(
                ctx,
                icon: Icons.movie_rounded,
                title: o.label,
                subtitle: [
                  o.sizeBytes > 0 ? formatBytes(o.sizeBytes) : ctx.tr('size_unknown'),
                  if (!o.hasAudio) ctx.tr('no_audio'),
                ].join('  •  '),
                onTap: () => Navigator.pop(ctx, MediaPick.video(o)),
              ),
            if (audioOpt != null || canExtract)
              row(
                ctx,
                icon: Icons.music_note_rounded,
                title: ctx.tr('audio_only'),
                subtitle: audioOpt != null && audioOpt.sizeBytes > 0
                    ? formatBytes(audioOpt.sizeBytes)
                    : ctx.tr('audio_from_video'),
                onTap: () => Navigator.pop(ctx, const MediaPick.audio()),
              ),
          ],
        ),
      ),
    ),
  );
}

/// عند إرجاع المحرك أكثر من ملف (picker).
Future<CobaltPickerItem?> showPickerSheet(BuildContext context, List<CobaltPickerItem> items) {
  return showModalBottomSheet<CobaltPickerItem>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      String label(CobaltPickerItem it, int i) {
        final key = {
          'video': 'item_video',
          'photo': 'item_photo',
          'gif': 'item_gif',
          'audio': 'item_audio',
        }[it.type] ?? 'item_file';
        return '${ctx.tr(key)} #${i + 1}';
      }

      IconData icon(String t) {
        switch (t) {
          case 'photo':
            return Icons.image_rounded;
          case 'audio':
            return Icons.music_note_rounded;
          case 'gif':
            return Icons.gif_rounded;
          default:
            return Icons.play_circle_rounded;
        }
      }

      return _SheetFrame(
        title: ctx.tr('picker_title'),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .55),
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.only(top: 10),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final it = items[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  onTap: () => Navigator.pop(ctx, it),
                  child: Row(
                    children: [
                      Icon(icon(it.type), color: AppColors.primary, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label(it, i),
                          style: TextStyle(
                            color: ctx.textColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Icon(Icons.download_rounded, color: AppColors.primary),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    },
  );
}

/// نافذة التحديث (اختيارية أو إجبارية).
Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) {
  final force = info.mustUpdate;
  return showDialog<void>(
    context: context,
    barrierDismissible: !force,
    builder: (ctx) {
      return PopScope(
        canPop: !force,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1C2D6B), Color(0xFF2A1852)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'FLOWDROP  •  UPDATE',
                  style: TextStyle(
                    color: Color(0xFFBCAEFF),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  ctx.tr('update_title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  info.message.isEmpty ? ctx.tr('update_default_msg') : info.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFD8D0EA), fontSize: 14.5, height: 1.5),
                ),
                if (info.latest.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${info.current}  →  ${info.latest}',
                    style: const TextStyle(color: Color(0xFF9F8FFF), fontSize: 13),
                  ),
                ],
                const SizedBox(height: 20),
                GradientButton(
                  label: ctx.tr('update_now'),
                  icon: Icons.system_update_alt_rounded,
                  onPressed: () async {
                    final u = Uri.tryParse(info.url.trim());
                    if (u != null && (u.scheme == 'https' || u.scheme == 'http')) {
                      await launchUrl(u, mode: LaunchMode.externalApplication);
                    }
                    if (force) {
                      SystemNavigator.pop();
                    } else if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                  },
                ),
                if (!force)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      ctx.tr('later'),
                      style: const TextStyle(color: Color(0xFFA9A0BE)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
