import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../core/utils.dart';

/// مشغّل بسيط للفيديو والصوت المحمّل.
class PlayerScreen extends StatefulWidget {
  final String path;
  final String title;
  const PlayerScreen({super.key, required this.path, required this.title});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final VideoPlayerController _c;
  bool _ready = false;
  bool _error = false;
  bool _showUi = true;
  Timer? _hide;

  bool get _isAudio => isAudioExt(extensionOf(widget.path) ?? '');

  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.file(File(widget.path));
    _c.addListener(() {
      if (mounted) setState(() {});
    });
    _c.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _c.play();
      _scheduleHide();
    }).catchError((_) {
      if (mounted) setState(() => _error = true);
    });
  }

  @override
  void dispose() {
    _hide?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _scheduleHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 3), () {
      if (mounted && _c.value.isPlaying) setState(() => _showUi = false);
    });
  }

  void _toggleUi() {
    setState(() => _showUi = !_showUi);
    if (_showUi) _scheduleHide();
  }

  void _seekBy(int seconds) {
    final dur = _c.value.duration;
    var t = _c.value.position + Duration(seconds: seconds);
    if (t < Duration.zero) t = Duration.zero;
    if (t > dur) t = dur;
    _c.seekTo(t);
    _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    final v = _c.value;
    final dur = v.duration.inMilliseconds;
    final pos = v.position.inMilliseconds.clamp(0, dur > 0 ? dur : 1).toDouble();

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleUi,
        child: Stack(
          children: [
            Center(
              child: _error
                  ? Text(context.tr('player_error'), style: const TextStyle(color: Colors.white70))
                  : !_ready
                      ? const CircularProgressIndicator()
                      : _isAudio
                          ? const Icon(Icons.music_note_rounded, size: 120, color: AppColors.primary)
                          : AspectRatio(aspectRatio: v.aspectRatio, child: VideoPlayer(_c)),
            ),
            AnimatedOpacity(
              opacity: _showUi ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_showUi,
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.fromLTRB(4, MediaQuery.of(context).padding.top + 4, 12, 12),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black87, Colors.transparent],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                          ),
                          Expanded(
                            child: Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (_ready)
                      Container(
                        padding: EdgeInsets.fromLTRB(
                          12, 12, 12, MediaQuery.of(context).padding.bottom + 12,
                        ),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, Colors.black87],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  formatDuration(v.position),
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                                Expanded(
                                  child: Slider(
                                    value: pos,
                                    max: dur > 0 ? dur.toDouble() : 1,
                                    activeColor: AppColors.primary,
                                    inactiveColor: Colors.white24,
                                    onChanged: (x) => _c.seekTo(Duration(milliseconds: x.toInt())),
                                    onChangeEnd: (_) => _scheduleHide(),
                                  ),
                                ),
                                Text(
                                  formatDuration(v.duration),
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  iconSize: 34,
                                  onPressed: () => _seekBy(-10),
                                  icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  iconSize: 56,
                                  onPressed: () {
                                    v.isPlaying ? _c.pause() : _c.play();
                                    _scheduleHide();
                                  },
                                  icon: Icon(
                                    v.isPlaying
                                        ? Icons.pause_circle_filled_rounded
                                        : Icons.play_circle_fill_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  iconSize: 34,
                                  onPressed: () => _seekBy(10),
                                  icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
