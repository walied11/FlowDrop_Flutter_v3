import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_scope.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/download_item.dart';
import '../services/cobalt_service.dart';
import '../services/download_manager.dart';
import '../services/native_extractor.dart';
import '../services/history_store.dart';
import '../widgets/common.dart';
import '../widgets/sheets.dart';
import 'player_screen.dart';

class HomeTab extends StatefulWidget {
  final VoidCallback onOpenSettings;
  const HomeTab({super.key, required this.onOpenSettings});

  @override
  State<HomeTab> createState() => HomeTabState();
}

class HomeTabState extends State<HomeTab> {
  final TextEditingController _ctrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// يستدعيه الهيكل عند استقبال رابط مشارك أو "إعادة تحميل" من السجل.
  void setUrl(String url, {bool openOptions = false}) {
    _ctrl.text = url;
    setState(() {});
    if (openOptions) _onDownload();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final t = data?.text;
    if (t == null || t.trim().isEmpty) return;
    setState(() => _ctrl.text = extractUrl(t) ?? t.trim());
  }

  Future<void> _onDownload() async {
    if (_busy) return;
    final settings = AppScope.of(context);
    final mgr = DownloadManager.instance;

    final url = extractUrl(_ctrl.text.trim());
    if (url == null) {
      showSnack(context, context.tr('invalid_url'));
      return;
    }
    if (!mgr.canStart) {
      showSnack(context, context.tr('max_active'));
      return;
    }

    // رابط مباشر لملف وسائط: لا حاجة لأي محرك.
    if (isDirectMediaUrl(url)) {
      await mgr.start(
        directUrl: url,
        sourceUrl: url,
        isAudio: isAudioExt(extensionOf(Uri.parse(url).path) ?? ''),
        quality: 'original',
      );
      if (mounted) setState(() => _ctrl.clear());
      return;
    }

    // محرك API خاص: نسأل عن النوع/الجودة أولًا (المحرك لا يعرض الجودات مسبقًا).
    DownloadChoice? choice;
    if (settings.useEngine) {
      choice = await showDownloadOptions(context);
      if (choice == null || !mounted) return;
      await settings.saveChoice(
        audio: choice.audio,
        quality: choice.quality,
        bitrate: choice.bitrate,
      );
    }

    setState(() => _busy = true);
    CobaltException? engineError;
    try {
      if (choice != null) {
        try {
          final result = await CobaltService.resolve(
            url: url,
            endpoint: settings.endpoint,
            apiKey: settings.apiKey,
            audio: choice.audio,
            quality: choice.quality,
            bitrate: choice.bitrate,
          );
          if (!mounted) return;
          CobaltPickerItem? picked;
          if (result.isPicker) {
            picked = await showPickerSheet(context, result.items);
            if (picked == null) return;
          } else {
            picked = result.items.first;
          }
          await mgr.start(
            directUrl: picked.url,
            sourceUrl: url,
            isAudio: choice.audio || picked.type == 'audio',
            quality: choice.quality,
            suggestedName: result.isPicker ? null : result.filename,
          );
          if (mounted) setState(() => _ctrl.clear());
          return;
        } on CobaltException catch (e) {
          engineError = e; // نجرب التحميل المدمج بعده
        }
      }

      // التحميل المدمج: نفحص الرابط ونعرض الجودات الحقيقية المتاحة له.
      final options = await NativeExtractor.options(url);
      if (!mounted) return;
      if (options.isEmpty) {
        throw engineError ?? CobaltException(platformOf(url) == 'web' ? 'unsupported' : 'fetch');
      }
      final picked = await showQualitySheet(context, options);
      if (picked == null || !mounted) return;
      final thumb = options.first.thumb;

      if (picked.audio) {
        MediaOption? direct;
        for (final o in options) {
          if (o.audioOnly) {
            direct = o;
            break;
          }
        }
        if (direct != null) {
          await mgr.start(
            directUrl: direct.url,
            sourceUrl: url,
            isAudio: true,
            quality: 'audio',
            forceExt: direct.ext,
            thumbUrl: thumb,
          );
        } else {
          // نحمّل أصغر فيديو فيه صوت ثم نستخرج منه الصوت.
          final vids = options.where((o) => !o.audioOnly && o.hasAudio).toList()
            ..sort((a, b) => a.height.compareTo(b.height));
          if (vids.isEmpty) {
            showSnack(context, context.tr('audio_err'));
            return;
          }
          await mgr.start(
            directUrl: vids.first.url,
            sourceUrl: url,
            isAudio: true,
            quality: 'audio',
            extractAudio: true,
            thumbUrl: thumb,
          );
        }
      } else {
        final o = picked.option!;
        await mgr.start(
          directUrl: o.url,
          sourceUrl: url,
          isAudio: false,
          quality: o.label,
          thumbUrl: thumb,
        );
      }
      if (mounted) setState(() => _ctrl.clear());
    } on CobaltException catch (e) {
      if (!mounted) return;
      final key = 'err_${e.code}';
      final msg = context.tr(key);
      final needsSettings = e.code == 'auth' || e.code == 'network';
      showSnack(
        context,
        msg == key ? context.tr('err_generic') : msg,
        actionLabel: needsSettings ? context.tr('open_settings') : null,
        onAction: needsSettings ? widget.onOpenSettings : null,
      );
    } catch (_) {
      if (mounted) showSnack(context, context.tr('err_generic'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _play(HistoryEntry e) async {
    if (!await File(e.filePath).exists()) {
      if (mounted) showSnack(context, context.tr('file_missing'));
      return;
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerScreen(path: e.filePath, title: e.fileName)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        children: [
          _header(context),
          const SizedBox(height: 18),
          const PlatformChips(),
          const SizedBox(height: 6),
          Text(
            context.tr('platforms_hint'),
            style: TextStyle(color: context.mutedColor, fontSize: 11.5),
          ),
          const SizedBox(height: 16),
          _urlField(context),
          const SizedBox(height: 14),
          GradientButton(
            label: _busy ? context.tr('preparing') : context.tr('download'),
            icon: Icons.download_rounded,
            loading: _busy,
            onPressed: _onDownload,
          ),
          AnimatedBuilder(
            animation: Listenable.merge([DownloadManager.instance, HistoryStore.instance]),
            builder: (context, _) => _lists(context),
          ),
          const SizedBox(height: 22),
          Text(
            context.tr('legal'),
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedColor, fontSize: 11.5, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset('assets/images/logo.png', width: 54, height: 54, fit: BoxFit.cover),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (r) => AppColors.gradient.createShader(r),
                child: const Text(
                  'FlowDrop',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                context.tr('tagline'),
                style: TextStyle(color: context.mutedColor, fontSize: 13),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: widget.onOpenSettings,
          icon: Icon(Icons.settings_rounded, color: context.mutedColor),
        ),
      ],
    );
  }

  Widget _urlField(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 2, 6, 2),
      decoration: BoxDecoration(
        color: context.cardColor2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.link_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _ctrl,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _onDownload(),
              style: TextStyle(color: context.textColor, fontSize: 15),
              decoration: InputDecoration(
                hintText: context.tr('paste_hint'),
                hintStyle: TextStyle(color: context.mutedColor),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          if (_ctrl.text.isNotEmpty)
            IconButton(
              onPressed: () => setState(() => _ctrl.clear()),
              icon: Icon(Icons.close_rounded, color: context.mutedColor, size: 20),
            ),
          IconButton(
            onPressed: _paste,
            icon: const Icon(Icons.content_paste_rounded, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _lists(BuildContext context) {
    final active = DownloadManager.instance.active;
    final recent = HistoryStore.instance.entries.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (active.isNotEmpty) ...[
          SectionTitle(context.tr('active_downloads')),
          for (final it in active) DownloadTile(key: ValueKey(it.id), item: it),
        ],
        SectionTitle(context.tr('recent')),
        if (recent.isEmpty && active.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  const DownloadAnimation(size: 110),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('no_recent'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.mutedColor, height: 1.6),
                  ),
                ],
              ),
            ),
          )
        else
          for (final e in recent)
            AppCard(
              margin: const EdgeInsets.only(bottom: 10),
              onTap: () => _play(e),
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
                          '${platformLabel(e.platform)}  •  ${formatBytes(e.sizeBytes)}',
                          style: TextStyle(color: context.mutedColor, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    e.isAudio ? Icons.music_note_rounded : Icons.play_circle_fill_rounded,
                    color: AppColors.primary,
                    size: 30,
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
