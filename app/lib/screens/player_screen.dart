import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../services/cast_service.dart';
import '../services/xtream_api.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/cast_sheet.dart';
import '../widgets/common.dart';

enum PlayerAspect { fit, fill, stretch, ratio16x9, ratio4x3 }

extension on PlayerAspect {
  String get label => switch (this) {
        PlayerAspect.fit => 'Fit',
        PlayerAspect.fill => 'Fill',
        PlayerAspect.stretch => 'Stretch',
        PlayerAspect.ratio16x9 => '16:9',
        PlayerAspect.ratio4x3 => '4:3',
      };

  PlayerAspect get next => PlayerAspect
      .values[(index + 1) % PlayerAspect.values.length];
}

/// Tela 07 — Player (ao vivo e VOD) com EPG do canal e zapeamento.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.item, this.siblings = const []});

  final MediaItem item;
  final List<MediaItem> siblings;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  VideoPlayerController? _controller;
  late MediaItem _current;

  bool _loading = true;
  bool _fullscreen = false;
  String? _error;
  List<XtreamProgram> _epg = const [];
  bool _casting = false;
  double _speed = 1.0;
  PlayerAspect _aspect = PlayerAspect.fit;
  String? _seekHint;
  Timer? _progressTimer;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _current = widget.item;
    _open(_current);
    _progressTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _persistProgress(),
    );
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _hintTimer?.cancel();
    _persistProgress();
    _controller?.removeListener(_onVideo);
    _controller?.dispose();
    _restoreOrientation();
    super.dispose();
  }

  /// Manda o conteúdo para a TV e pausa a reprodução no celular.
  Future<void> _startCast() async {
    final position = _controller?.value.position ?? Duration.zero;
    await _controller?.pause();
    if (!mounted) return;
    final started = await showCastSheet(
      context,
      _current,
      position: _current.kind == MediaKind.live ? Duration.zero : position,
    );
    if (!mounted) return;
    setState(() => _casting = started);
  }

  Future<void> _stopCast() async {
    await CastService.instance.disconnect();
    if (!mounted) return;
    setState(() => _casting = false);
    await _controller?.play();
  }

  Future<void> _open(MediaItem item) async {
    await _persistProgress();
    setState(() {
      _current = item;
      _loading = true;
      _error = null;
      _epg = const [];
      _speed = 1.0;
      _seekHint = null;
    });

    _controller?.removeListener(_onVideo);
    await _controller?.dispose();
    _controller = null;

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(item.url),
      httpHeaders: const {'User-Agent': 'NEOPLAY/1.0 (Android)'},
      videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: false),
    );

    try {
      await controller.initialize();
      await controller.setVolume(1);
      await controller.setPlaybackSpeed(_speed);
      if (item.kind != MediaKind.live && mounted) {
        final saved = context.read<AppState>().getProgress(item.id);
        if (saved != null && saved.positionSeconds > 10) {
          final target = Duration(seconds: saved.positionSeconds);
          if (controller.value.duration == Duration.zero ||
              target < controller.value.duration) {
            await controller.seekTo(target);
          }
        }
      }
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(_onVideo);
      setState(() {
        _controller = controller;
        _loading = false;
      });
      _loadEpg(item);
    } on Exception catch (e) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError('$e');
      });
    }
  }

  void _onVideo() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (!c.value.isPlaying) {
      _persistProgress();
    }
  }

  Future<void> _persistProgress() async {
    final c = _controller;
    if (!mounted || c == null || !c.value.isInitialized) return;
    if (_current.kind == MediaKind.live) return;
    await context.read<AppState>().saveProgress(
          _current,
          c.value.position.inSeconds,
          c.value.duration.inSeconds,
        );
  }

  String _friendlyError(String raw) {
    if (raw.contains('403')) {
      return 'Acesso recusado (403). Limite de conexões da lista ou credencial inválida.';
    }
    if (raw.contains('404')) {
      return 'Stream não encontrado (404). O canal pode ter mudado de endereço.';
    }
    if (raw.toLowerCase().contains('timeout')) {
      return 'O servidor não respondeu em tempo.';
    }
    return 'Não foi possível abrir este stream.';
  }

  Future<void> _loadEpg(MediaItem item) async {
    final state = context.read<AppState>();
    final playlist = state.playlist;
    if (playlist == null ||
        playlist.kind != PlaylistKind.xtream ||
        item.kind != MediaKind.live) {
      return;
    }
    final epg = await XtreamApi(playlist).shortEpg(item.remoteId);
    if (!mounted) return;
    setState(() => _epg = epg);
  }

  void _zap(int delta) {
    final list = widget.siblings;
    if (list.isEmpty) return;
    final i = list.indexWhere((e) => e.id == _current.id);
    if (i < 0) return;
    final next = (i + delta) % list.length;
    _open(list[next < 0 ? list.length - 1 : next]);
    context
        .read<AppState>()
        .markWatched(list[next < 0 ? list.length - 1 : next]);
  }

  Future<void> _toggleFullscreen() async {
    setState(() => _fullscreen = !_fullscreen);
    if (_fullscreen) {
      await SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
      );
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await _restoreOrientation();
    }
  }

  Future<void> _restoreOrientation() async {
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _seekBy(int seconds) {
    final c = _controller;
    if (c == null || _current.kind == MediaKind.live) return;
    var next = c.value.position + Duration(seconds: seconds);
    if (next < Duration.zero) next = Duration.zero;
    final total = c.value.duration;
    if (total > Duration.zero && next > total) next = total;
    c.seekTo(next);
    setState(() => _seekHint = seconds < 0 ? '${seconds}s' : '+${seconds}s');
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _seekHint = null);
    });
  }

  void _onDoubleTap(TapDownDetails details, Size size) {
    if (_current.kind == MediaKind.live) return;
    final left = details.localPosition.dx < size.width / 2;
    _seekBy(left ? -10 : 10);
  }

  Future<void> _setSpeed(double speed) async {
    _speed = speed;
    await _controller?.setPlaybackSpeed(speed);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isLive = _current.kind == MediaKind.live;

    if (_fullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(child: _video()),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton(
                icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                onPressed: _toggleFullscreen,
              ),
            ),
          ],
        ),
      );
    }

    if (_casting) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_current.name, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: 'Parar transmissão',
              icon: const Icon(Icons.cast_connected, color: AppColors.accent),
              onPressed: _stopCast,
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: CastPanel(
                title: _current.name,
                deviceName: CastService.instance.deviceName ?? 'sua TV',
                onStop: _stopCast,
              ),
            ),
            Expanded(child: _epgSection(_current.kind == MediaKind.live)),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_current.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: _casting ? 'Parar transmissão' : 'Enviar para TV',
            icon: Icon(_casting ? Icons.cast_connected : Icons.cast),
            color: _casting ? AppColors.accent : null,
            onPressed: _casting ? _stopCast : _startCast,
          ),
          IconButton(
            tooltip: 'Recarregar',
            icon: const Icon(Icons.refresh),
            onPressed: () => _open(_current),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(aspectRatio: 16 / 9, child: _video()),
          _controls(state, isLive),
          Expanded(child: _epgSection(isLive)),
        ],
      ),
    );
  }

  Widget _video() {
    if (_loading) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppColors.bad, size: 30),
                const SizedBox(height: 10),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.muted, height: 1.4),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _open(_current),
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final c = _controller!;
    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTapDown: (d) =>
                _onDoubleTap(d, Size(constraints.maxWidth, constraints.maxHeight)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _aspectVideo(c),
                if (_seekHint != null)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _seekHint!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _aspectVideo(VideoPlayerController c) {
    final size = c.value.size;
    final w = size.width == 0 ? 16.0 : size.width;
    final h = size.height == 0 ? 9.0 : size.height;
    final box = SizedBox(width: w, height: h, child: VideoPlayer(c));

    switch (_aspect) {
      case PlayerAspect.fit:
        return FittedBox(fit: BoxFit.contain, child: box);
      case PlayerAspect.fill:
        return ClipRect(child: FittedBox(fit: BoxFit.cover, child: box));
      case PlayerAspect.stretch:
        return SizedBox.expand(
          child: FittedBox(fit: BoxFit.fill, child: box),
        );
      case PlayerAspect.ratio16x9:
        return Center(
          child: AspectRatio(aspectRatio: 16 / 9, child: VideoPlayer(c)),
        );
      case PlayerAspect.ratio4x3:
        return Center(
          child: AspectRatio(aspectRatio: 4 / 3, child: VideoPlayer(c)),
        );
    }
  }

  Widget _controls(AppState state, bool isLive) {
    final c = _controller;
    final playing = c?.value.isPlaying ?? false;
    final fav = state.isFavorite(_current);

    return Container(
      color: AppColors.surface2,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isLive
                      ? (_epg.isNotEmpty ? _epg.first.title : 'Ao vivo')
                      : 'Sob demanda',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              if (c != null)
                ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: c,
                  builder: (_, value, __) => Text(
                    _fmt(value.position),
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.accent),
                  ),
                ),
            ],
          ),
          if (c != null && !isLive) ...[
            const SizedBox(height: 8),
            VideoProgressIndicator(
              c,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: AppColors.accent,
                bufferedColor: Color(0x33FFFFFF),
                backgroundColor: AppColors.surface3,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                onPressed: c == null
                    ? null
                    : () => setState(() => playing ? c.pause() : c.play()),
              ),
              IconButton(
                tooltip: '-10s',
                icon: const Icon(Icons.replay_10),
                onPressed: c == null || isLive ? null : () => _seekBy(-10),
              ),
              IconButton(
                icon: const Icon(Icons.skip_previous),
                onPressed: widget.siblings.isEmpty ? null : () => _zap(-1),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next),
                onPressed: widget.siblings.isEmpty ? null : () => _zap(1),
              ),
              IconButton(
                tooltip: '+10s',
                icon: const Icon(Icons.forward_10),
                onPressed: c == null || isLive ? null : () => _seekBy(10),
              ),
              IconButton(
                icon: Icon(
                  fav ? Icons.favorite : Icons.favorite_border,
                  color: fav ? AppColors.accent : null,
                ),
                onPressed: () => state.toggleFavorite(_current),
              ),
              IconButton(
                icon: const Icon(Icons.fullscreen),
                onPressed: _controller == null ? null : _toggleFullscreen,
              ),
            ],
          ),
          if (!isLive && c != null)
            Row(
              children: [
                PopupMenuButton<double>(
                  tooltip: 'Velocidade',
                  initialValue: _speed,
                  onSelected: _setSpeed,
                  itemBuilder: (_) => [
                    for (final s in _speeds)
                      PopupMenuItem(
                        value: s,
                        child: Text('${s}x'),
                      ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    child: Text(
                      '${_speed}x',
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.accent),
                    ),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _aspect = _aspect.next),
                  child: Text(
                    _aspect.label,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _epgSection(bool isLive) {
    if (!isLive) {
      return const EmptyState(
        icon: Icons.movie_outlined,
        title: 'Reprodução sob demanda',
        message:
            'Toque duas vezes à esquerda/direita para ±10s. Ajuste velocidade e aspecto abaixo do vídeo.',
      );
    }
    if (_epg.isEmpty) {
      return const EmptyState(
        icon: Icons.event_note_outlined,
        title: 'EPG não disponível',
        message: 'Este canal não tem guia de programação na lista atual.',
      );
    }
    return ListView.builder(
      itemCount: _epg.length,
      itemBuilder: (context, i) {
        final p = _epg[i];
        final now = i == 0;
        return Container(
          decoration: BoxDecoration(
            color: now ? const Color(0x12FFC93C) : AppColors.surface1,
            border: const Border(bottom: BorderSide(color: AppColors.line)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 46,
                child: Text(
                  p.start == null ? '--:--' : _hhmm(p.start!),
                  style:
                      const TextStyle(fontSize: 11.5, color: AppColors.muted),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.title.isEmpty ? 'Sem dados' : p.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: now ? FontWeight.w700 : FontWeight.w500,
                        color: now ? AppColors.accent : AppColors.text,
                      ),
                    ),
                    if (now && p.start != null && p.end != null) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                            value: p.progress, minHeight: 3),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
