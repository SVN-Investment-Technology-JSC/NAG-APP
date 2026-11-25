import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

/// Plays a camera clip of a fleet event inside the app (signed media link, no login needed).
/// If the phone cannot decode it, the user can still open it in the browser.
Future<void> openFleetVideo(BuildContext context, String url, {String? title, String? subtitle}) {
  return Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => FleetVideoPage(url: url, title: title, subtitle: subtitle),
  ));
}

class FleetVideoPage extends StatefulWidget {
  final String url;
  final String? title;
  final String? subtitle;
  const FleetVideoPage({super.key, required this.url, this.title, this.subtitle});

  @override
  State<FleetVideoPage> createState() => _FleetVideoPageState();
}

class _FleetVideoPageState extends State<FleetVideoPage> {
  late final VideoPlayerController _c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
  bool _ready = false;
  Object? _error;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _c.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _c.setLooping(false);
      _c.play();
    }).catchError((e) {
      if (mounted) setState(() => _error = e);
    });
    _c.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final v = _c.value;
    final done = _ready && v.position >= v.duration && v.duration > Duration.zero;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title ?? 'Video camera', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            if (widget.subtitle != null) Text(widget.subtitle!, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Mở bằng trình duyệt',
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 48),
                  const SizedBox(height: 12),
                  const Text('Không phát được video trong app', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text('Liên kết có thể đã hết hạn (mở lại sự kiện để lấy liên kết mới) hoặc điện thoại không giải mã được định dạng.',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 12.5)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Mở bằng trình duyệt'),
                  ),
                ]),
              ),
            )
          : !_ready
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _showControls = !_showControls),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(child: AspectRatio(aspectRatio: v.aspectRatio == 0 ? 16 / 9 : v.aspectRatio, child: VideoPlayer(_c))),
                      if (_showControls || !v.isPlaying)
                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.transparent, Color(0xAA000000)],
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  iconSize: 64,
                                  color: Colors.white,
                                  icon: Icon(done
                                      ? Icons.replay_circle_filled_rounded
                                      : v.isPlaying
                                          ? Icons.pause_circle_filled_rounded
                                          : Icons.play_circle_fill_rounded),
                                  onPressed: () async {
                                    if (done) await _c.seekTo(Duration.zero);
                                    v.isPlaying && !done ? await _c.pause() : await _c.play();
                                  },
                                ),
                                const Spacer(),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                                  child: Row(children: [
                                    Text(_fmt(v.position), style: const TextStyle(color: Colors.white, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()])),
                                    Expanded(
                                      child: VideoProgressIndicator(
                                        _c,
                                        allowScrubbing: true,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                        colors: const VideoProgressColors(
                                          playedColor: Color(0xFF2563EB),
                                          bufferedColor: Colors.white30,
                                          backgroundColor: Colors.white12,
                                        ),
                                      ),
                                    ),
                                    Text(_fmt(v.duration), style: const TextStyle(color: Colors.white70, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()])),
                                  ]),
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
