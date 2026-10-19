import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/download_item.dart';
import '../services/download_manager.dart';

class PlatformVisual {
  final IconData icon;
  final Color color;
  const PlatformVisual(this.icon, this.color);
}

PlatformVisual platformVisual(String platform) {
  switch (platform) {
    case 'tiktok':
      return const PlatformVisual(Icons.music_note_rounded, Color(0xFFFF2D6F));
    case 'facebook':
      return const PlatformVisual(Icons.facebook_rounded, Color(0xFF1877F2));
    case 'instagram':
      return const PlatformVisual(Icons.camera_alt_rounded, Color(0xFFE1306C));
    case 'threads':
      return const PlatformVisual(Icons.alternate_email_rounded, Color(0xFF8E8E93));
    case 'x':
      return const PlatformVisual(Icons.tag_rounded, Color(0xFF8E8E93));
    case 'youtube':
      return const PlatformVisual(Icons.smart_display_rounded, Color(0xFFFF0000));
    case 'pinterest':
      return const PlatformVisual(Icons.push_pin_rounded, Color(0xFFE60023));
    case 'reddit':
      return const PlatformVisual(Icons.forum_rounded, Color(0xFFFF4500));
    case 'snapchat':
      return const PlatformVisual(Icons.chat_bubble_rounded, Color(0xFFFFC400));
    default:
      return const PlatformVisual(Icons.link_rounded, AppColors.primary);
  }
}

String platformLabel(String p) {
  switch (p) {
    case 'tiktok':
      return 'TikTok';
    case 'facebook':
      return 'Facebook';
    case 'instagram':
      return 'Instagram';
    case 'threads':
      return 'Threads';
    case 'x':
      return 'X';
    case 'youtube':
      return 'YouTube';
    case 'pinterest':
      return 'Pinterest';
    case 'reddit':
      return 'Reddit';
    case 'snapchat':
      return 'Snapchat';
    default:
      return 'Web';
  }
}

class PlatformIconBox extends StatelessWidget {
  final String platform;
  final double size;
  const PlatformIconBox({super.key, required this.platform, this.size = 46});

  @override
  Widget build(BuildContext context) {
    final v = platformVisual(platform);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: v.color.withOpacity(.16),
        borderRadius: BorderRadius.circular(size * .3),
      ),
      child: Icon(v.icon, color: v.color, size: size * .52),
    );
  }
}

/// صورة مصغرة للفيديو (مسار محلي أو رابط)، وإن لم توجد تظهر أيقونة المنصة.
class VideoThumb extends StatelessWidget {
  final String thumb;
  final String platform;
  final double size;
  const VideoThumb({super.key, required this.thumb, required this.platform, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final fallback = PlatformIconBox(platform: platform, size: size);
    if (thumb.isEmpty) return fallback;
    Widget err(BuildContext _, Object __, StackTrace? ___) => fallback;
    final Widget img = thumb.startsWith('http')
        ? Image.network(thumb,
            width: size, height: size, fit: BoxFit.cover, errorBuilder: err)
        : Image.file(File(thumb),
            width: size, height: size, fit: BoxFit.cover, errorBuilder: err);
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .26),
      child: SizedBox(width: size, height: size, child: img),
    );
  }
}

/// بطاقة بخلفية وحدود متناسقة مع الوضع الليلي/النهاري.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: context.cardColor2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: box);
  }
}

class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;
  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.height = 54,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: enabled || loading ? 1 : .55,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            gradient: AppColors.gradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.secondary.withOpacity(.28),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: enabled ? onPressed : null,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: Colors.white, size: 22),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: context.textColor,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// زر اختيار على شكل حبة (للجودة/النوع/اللغة...).
class PillOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  const PillOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.gradient : null,
          color: selected ? null : context.bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.transparent : context.borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: selected ? Colors.white : context.mutedColor),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : context.textColor,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// شريط يعرض أشهر المنصات (للتعريف فقط).
class PlatformChips extends StatelessWidget {
  const PlatformChips({super.key});

  static const _list = ['tiktok', 'facebook', 'instagram', 'threads', 'x', 'youtube'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _list.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final p = _list[i];
          return Column(
            children: [
              PlatformIconBox(platform: p, size: 58),
              const SizedBox(height: 6),
              Text(
                platformLabel(p),
                style: TextStyle(color: context.mutedColor, fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// حركة التحميل (12 إطارًا من النسخة الأصلية).
class DownloadAnimation extends StatefulWidget {
  final double size;
  const DownloadAnimation({super.key, this.size = 120});

  @override
  State<DownloadAnimation> createState() => _DownloadAnimationState();
}

class _DownloadAnimationState extends State<DownloadAnimation> {
  int _i = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 110), (_) {
      if (mounted) setState(() => _i = (_i + 1) % 12);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _i == 4
          ? 'assets/anim/frame_04_alt.png'
          : 'assets/anim/frame_${_i.toString().padLeft(2, '0')}.png',
      width: widget.size,
      height: widget.size,
      gaplessPlayback: true,
    );
  }
}

/// بطاقة تحميل جارٍ مع شريط التقدم وأزرار التحكم.
class DownloadTile extends StatelessWidget {
  final DownloadItem item;
  const DownloadTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final mgr = DownloadManager.instance;
    final failed = item.status == DownloadStatus.failed;
    final paused = item.status == DownloadStatus.paused;
    final p = item.progress;
    final pct = p == null ? '' : '  •  ${(p * 100).round()}%';
    final sizeText = '${formatBytes(item.downloaded)} / ${item.total > 0 ? formatBytes(item.total) : '?'}';
    final statusKey = failed ? 'failed' : (paused ? 'paused' : 'downloading');
    final statusColor =
        failed ? AppColors.danger : (paused ? Colors.orange : AppColors.primary);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              VideoThumb(thumb: item.thumbUrl, platform: item.platform),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.fileName,
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
                      '${context.tr(statusKey)}$pct${failed && item.error != null ? '\n${item.error}' : ''}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: statusColor, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              if (failed)
                IconButton(
                  tooltip: context.tr('retry'),
                  onPressed: () => mgr.resume(item),
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                )
              else if (paused)
                IconButton(
                  tooltip: context.tr('resume'),
                  onPressed: () => mgr.resume(item),
                  icon: const Icon(Icons.play_arrow_rounded, color: AppColors.primary),
                )
              else
                IconButton(
                  tooltip: context.tr('pause'),
                  onPressed: () => mgr.pause(item),
                  icon: Icon(Icons.pause_rounded, color: context.mutedColor),
                ),
              IconButton(
                tooltip: context.tr('cancel'),
                onPressed: () => mgr.cancel(item),
                icon: const Icon(Icons.close_rounded, color: AppColors.danger),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: failed ? 0 : (paused ? (p ?? 0) : p),
              minHeight: 7,
              backgroundColor: context.borderColor,
              valueColor: AlwaysStoppedAnimation(statusColor),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              sizeText,
              style: TextStyle(color: context.mutedColor, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

void showSnack(BuildContext context, String msg, {String? actionLabel, VoidCallback? onAction}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(msg),
    action: actionLabel == null
        ? null
        : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
  ));
}
