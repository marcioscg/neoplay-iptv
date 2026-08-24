import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../services/xtream_api.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Tela 07 — Player (ao vivo e VOD) com EPG do canal e zapeamento.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.item, this.siblings = const []});

  final MediaItem item;
  final List<MediaItem> siblings;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _controller;
  late MediaItem _current;

  bool _loading = true;
  bool _fullscreen = false;
  String? _error;
  List<XtreamProgram> _epg = const [];

  @override
  void initState() {
    super.initState();
    _current = widget.item;
    _open(_current);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _restoreOrientation();
    super.dispose();
  }

  Future<void> _open(MediaItem item) async {
    setState(() {
      _current = item;
      _loading = true;
      _error = null;
      _epg = const [];
    });

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
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
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
    final epg = await XtreamApi(playlist).shortEpg(item.id);
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isLive = _current.kind == MediaKind.live;

    if (_fullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(child: _video()),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_current.name, overflow: TextOverflow.ellipsis),
        actions: [
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
      child: Center(
        child: AspectRatio(
          aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
          child: VideoPlayer(c),
        ),
      ),
    );
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
                Text(
                  _fmt(c.value.position),
                  style: const TextStyle(fontSize: 12, color: AppColors.accent),
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
                icon: const Icon(Icons.skip_previous),
                onPressed: widget.siblings.isEmpty ? null : () => _zap(-1),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next),
                onPressed: widget.siblings.isEmpty ? null : () => _zap(1),
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
        ],
      ),
    );
  }

  Widget _epgSection(bool isLive) {
    if (!isLive) {
      return const EmptyState(
        icon: Icons.movie_outlined,
        title: 'Reprodução sob demanda',
        message: 'Use a barra acima para avançar ou retroceder.',
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
