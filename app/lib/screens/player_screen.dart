import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../services/cast_service.dart';
import '../services/hls_quality.dart';
import '../services/pip_service.dart';
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

  PlayerAspect get next =>
      PlayerAspect.values[(index + 1) % PlayerAspect.values.length];
}

/// Tela 07 — Player (ao vivo e VOD) com EPG do canal, zapeamento, controle de
/// velocidade, seleção de qualidade e avanço automático de episódio.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.item, this.siblings = const []});

  final MediaItem item;
  final List<MediaItem> siblings;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with WidgetsBindingObserver {
  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
  static const _autoQuality = 'Automática';

  VideoPlayerController? _controller;
  late MediaItem _current;

  bool _loading = true;
  bool _fullscreen = false;
  bool _pipSupported = false;
  bool _pipActive = false;
  String? _error;
  List<XtreamProgram> _epg = const [];
  bool _casting = false;
  double _speed = 1.0;
  PlayerAspect _aspect = PlayerAspect.fit;
  String? _seekHint;
  bool _seekHintLeft = false;
  bool _advancing = false;

  // Qualidade (só quando o stream é um master playlist HLS com várias faixas).
  List<HlsVariant> _qualities = const [];
  String _qualityLabel = _autoQuality;
  String? _sourceUrl; // URL "Automática" original do item atual.

  // Overlay de controles em tela cheia.
  bool _showControls = true;
  Timer? _controlsTimer;
  Timer? _progressTimer;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _current = widget.item;
    WidgetsBinding.instance.addObserver(this);
    PipService.instance.attach(
      onAction: _onPipAction,
      onModeChanged: _onPipMode,
    );
    PipService.instance.isSupported().then((v) {
      if (mounted) setState(() => _pipSupported = v);
    });
    _open(_current);
    _progressTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _persistProgress(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PipService.instance.detach();
    _progressTimer?.cancel();
    _hintTimer?.cancel();
    _controlsTimer?.cancel();
    _persistProgress();
    _controller?.removeListener(_onVideo);
    _controller?.dispose();
    _restoreOrientation();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App indo para segundo plano com o vídeo tocando: abre a janelinha (PiP).
    if (state == AppLifecycleState.inactive &&
        !_pipActive &&
        !_casting &&
        _error == null &&
        (_controller?.value.isInitialized ?? false) &&
        (_controller?.value.isPlaying ?? false)) {
      _enterPip();
    } else if (state == AppLifecycleState.resumed && _pipActive) {
      setState(() => _pipActive = false);
    }
  }

  void _onPipMode(bool inPip) {
    if (mounted) setState(() => _pipActive = inPip);
  }

  void _onPipAction(String control) {
    switch (control) {
      case 'rewind':
        _seekBy(-10);
      case 'forward':
        _seekBy(10);
      case 'playpause':
        _togglePlay();
    }
    PipService.instance.setPlaying(_controller?.value.isPlaying ?? false);
  }

  Future<void> _enterPip() async {
    if (!_pipSupported) return;
    final ok = await PipService.instance.enter(
      playing: _controller?.value.isPlaying ?? false,
    );
    if (ok && mounted) setState(() => _pipActive = true);
  }

  bool get _isLive => _current.kind == MediaKind.live;
  bool get _hasSiblings => widget.siblings.length > 1;

  /// Manda o conteúdo para a TV e pausa a reprodução no celular.
  Future<void> _startCast() async {
    final position = _controller?.value.position ?? Duration.zero;
    await _controller?.pause();
    if (!mounted) return;
    final started = await showCastSheet(
      context,
      _current,
      position: _isLive ? Duration.zero : position,
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

  /// Abre um item. [overrideUrl] é usado só para trocar de qualidade sem mexer
  /// no restante do estado (EPG, zapeamento, favorito).
  Future<void> _open(MediaItem item, {String? overrideUrl}) async {
    await _persistProgress();
    final isQualitySwitch = overrideUrl != null;
    final resumeAt = isQualitySwitch
        ? (_controller?.value.position ?? Duration.zero)
        : Duration.zero;

    setState(() {
      _current = item;
      _loading = true;
      _error = null;
      _advancing = false;
      if (!isQualitySwitch) {
        _epg = const [];
        _speed = 1.0;
        _seekHint = null;
        _qualities = const [];
        _qualityLabel = _autoQuality;
        _sourceUrl = item.url;
      }
    });

    _controller?.removeListener(_onVideo);
    await _controller?.dispose();
    _controller = null;

    final url = overrideUrl ?? item.url;
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: const {'User-Agent': 'MIAUNET/1.0 (Android)'},
      // Mantém o áudio/vídeo tocando quando o app vai para a janelinha (PiP)
      // ou segundo plano. Ao sair do player o controller é liberado.
      videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: true),
    );

    try {
      await controller.initialize();
      await controller.setVolume(1);
      await controller.setPlaybackSpeed(_speed);

      if (!_isLive && mounted) {
        Duration? target;
        if (isQualitySwitch && resumeAt > Duration.zero) {
          target = resumeAt;
        } else {
          final saved = context.read<AppState>().getProgress(item.id);
          if (saved != null && saved.positionSeconds > 10) {
            target = Duration(seconds: saved.positionSeconds);
          }
        }
        if (target != null) {
          final total = controller.value.duration;
          if (total == Duration.zero || target < total) {
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
      _bumpControls();
      if (!isQualitySwitch) {
        _loadEpg(item);
        _loadQualities(url);
      }
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

    // Fim do vídeo: passa para o próximo episódio sem sair do player.
    if (!_isLive && _hasSiblings && !_advancing) {
      final dur = c.value.duration;
      final pos = c.value.position;
      final ended = c.value.isCompleted ||
          (dur > Duration.zero && pos >= dur - const Duration(milliseconds: 900));
      if (ended) {
        _advancing = true;
        _zap(1);
        return;
      }
    }

    if (!c.value.isPlaying) _persistProgress();
  }

  Future<void> _persistProgress() async {
    final c = _controller;
    if (!mounted || c == null || !c.value.isInitialized) return;
    if (_isLive) return;
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

  Future<void> _loadQualities(String url) async {
    final list = await HlsQuality.variants(url);
    if (!mounted || list.isEmpty) return;
    setState(() => _qualities = list);
  }

  Future<void> _switchQuality(String label) async {
    if (label == _qualityLabel) return;
    final url = label == _autoQuality
        ? _sourceUrl
        : _qualities.firstWhere((q) => q.label == label,
            orElse: () => HlsVariant(label: label, url: _sourceUrl ?? '')).url;
    if (url == null || url.isEmpty) return;
    setState(() => _qualityLabel = label);
    await _open(_current, overrideUrl: url);
  }

  void _zap(int delta) {
    final list = widget.siblings;
    if (list.length < 2) return;
    final i = list.indexWhere((e) => e.id == _current.id);
    if (i < 0) return;
    var n = i + delta;
    if (n < 0) n = list.length - 1;
    if (n >= list.length) n = 0;
    final next = list[n];
    context.read<AppState>().markWatched(next);
    _open(next);
  }

  Future<void> _toggleFullscreen() async {
    setState(() => _fullscreen = !_fullscreen);
    if (_fullscreen) {
      _bumpControls();
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

  void _bumpControls() {
    _controlsTimer?.cancel();
    if (!_showControls && mounted) setState(() => _showControls = true);
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _bumpControls();
  }

  void _seekBy(int seconds) {
    final c = _controller;
    if (c == null || _isLive) return;
    var next = c.value.position + Duration(seconds: seconds);
    if (next < Duration.zero) next = Duration.zero;
    final total = c.value.duration;
    if (total > Duration.zero && next > total) next = total;
    c.seekTo(next);
    setState(() {
      _seekHint = seconds < 0 ? '-10s' : '+10s';
      _seekHintLeft = seconds < 0;
    });
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _seekHint = null);
    });
  }

  void _onDoubleTap(TapDownDetails details, Size size) {
    if (_isLive) return;
    final left = details.localPosition.dx < size.width / 2;
    _seekBy(left ? -10 : 10);
  }

  Future<void> _setSpeed(double speed) async {
    _speed = speed;
    await _controller?.setPlaybackSpeed(speed);
    if (mounted) setState(() {});
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    setState(() => c.value.isPlaying ? c.pause() : c.play());
    _bumpControls();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (_pipActive) {
      final c = _controller;
      return ColoredBox(
        color: Colors.black,
        child: (c != null && c.value.isInitialized)
            ? Center(
                child: AspectRatio(
                  aspectRatio:
                      c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
                  child: VideoPlayer(c),
                ),
              )
            : const SizedBox.expand(),
      );
    }

    if (_fullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleControls,
          child: Stack(
            children: [
              Positioned.fill(child: _video()),
              Positioned.fill(child: _overlay(state, fullscreen: true)),
            ],
          ),
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
              icon: Icon(Icons.cast_connected, color: AppColors.accent),
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
            Expanded(child: _epgSection(_isLive)),
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
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                  Positioned.fill(child: _video()),
                  Positioned.fill(child: _overlay(state, fullscreen: false)),
                ],
              ),
            ),
          ),
          _controls(state, _isLive),
          Expanded(child: _epgSection(_isLive)),
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
                Icon(Icons.error_outline, color: AppColors.bad, size: 30),
                const SizedBox(height: 10),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
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
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTapDown: (d) => _onDoubleTap(d, size),
            onTap: _toggleControls,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _aspectVideo(c),
                if (_seekHint != null)
                  Align(
                    alignment:
                        _seekHintLeft ? Alignment.centerLeft : Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: 0.5,
                      child: Container(
                        color: Colors.black26,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _seekHintLeft ? Icons.fast_rewind : Icons.fast_forward,
                              color: Colors.white,
                              size: 34,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _seekHint!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
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

  /// Overlay sobre o vídeo: play/pause central, ±10s, faixa de progresso e,
  /// em tela cheia, velocidade/qualidade/aspecto.
  Widget _overlay(AppState state, {required bool fullscreen}) {
    final c = _controller;
    if (_loading || _error != null) return const SizedBox.shrink();
    final visible = _showControls || !(c?.value.isPlaying ?? false);

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x99000000), Color(0x22000000), Color(0x99000000)],
            ),
          ),
          child: Column(
            children: [
              if (fullscreen)
                SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.fullscreen_exit,
                            color: Colors.white),
                        onPressed: _toggleFullscreen,
                      ),
                      Expanded(
                        child: Text(
                          _current.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cast, color: Colors.white),
                        onPressed: _startCast,
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_hasSiblings)
                    _round(Icons.skip_previous, () => _zap(-1)),
                  if (!_isLive)
                    _round(Icons.replay_10, () => _seekBy(-10)),
                  const SizedBox(width: 6),
                  _round(
                    (c?.value.isPlaying ?? false)
                        ? Icons.pause
                        : Icons.play_arrow,
                    _togglePlay,
                    big: true,
                  ),
                  const SizedBox(width: 6),
                  if (!_isLive) _round(Icons.forward_10, () => _seekBy(10)),
                  if (_hasSiblings) _round(Icons.skip_next, () => _zap(1)),
                ],
              ),
              const Spacer(),
              if (fullscreen) ...[
                if (c != null && !_isLive)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        ValueListenableBuilder<VideoPlayerValue>(
                          valueListenable: c,
                          builder: (_, v, __) => Text(
                            _fmt(v.position),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: VideoProgressIndicator(
                              c,
                              allowScrubbing: true,
                              colors: VideoProgressColors(
                                playedColor: AppColors.accent,
                                bufferedColor: const Color(0x55FFFFFF),
                                backgroundColor: const Color(0x33FFFFFF),
                              ),
                            ),
                          ),
                        ),
                        Text(
                          _fmt(c.value.duration),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _menuSpeed(dark: true),
                      if (_qualities.isNotEmpty) _menuQuality(dark: true),
                      TextButton(
                        onPressed: () =>
                            setState(() => _aspect = _aspect.next),
                        child: Text(_aspect.label,
                            style: const TextStyle(color: Colors.white)),
                      ),
                      IconButton(
                        icon: Icon(
                          state.isFavorite(_current)
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: state.isFavorite(_current)
                              ? AppColors.accent
                              : Colors.white,
                        ),
                        onPressed: () => state.toggleFavorite(_current),
                      ),
                    ],
                  ),
                ),
              ] else
                const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _round(IconData icon, VoidCallback onTap, {bool big = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.black38,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(big ? 12 : 8),
            child: Icon(icon, color: Colors.white, size: big ? 34 : 24),
          ),
        ),
      ),
    );
  }

  Widget _menuSpeed({bool dark = false}) {
    return PopupMenuButton<double>(
      tooltip: 'Velocidade',
      initialValue: _speed,
      onSelected: _setSpeed,
      itemBuilder: (_) => [
        for (final s in _speeds) PopupMenuItem(value: s, child: Text('${s}x')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.speed,
                size: 16, color: dark ? Colors.white : AppColors.accent),
            const SizedBox(width: 4),
            Text('${_speed}x',
                style: TextStyle(
                    fontSize: 12.5,
                    color: dark ? Colors.white : AppColors.accent)),
          ],
        ),
      ),
    );
  }

  Widget _menuQuality({bool dark = false}) {
    return PopupMenuButton<String>(
      tooltip: 'Qualidade',
      initialValue: _qualityLabel,
      onSelected: _switchQuality,
      itemBuilder: (_) => [
        const PopupMenuItem(value: _autoQuality, child: Text(_autoQuality)),
        for (final q in _qualities)
          PopupMenuItem(value: q.label, child: Text(q.label)),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hd,
                size: 16, color: dark ? Colors.white : AppColors.accent),
            const SizedBox(width: 4),
            Text(
              _qualityLabel == _autoQuality ? 'Auto' : _qualityLabel,
              style: TextStyle(
                  fontSize: 12.5,
                  color: dark ? Colors.white : AppColors.accent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controls(AppState state, bool isLive) {
    final c = _controller;
    final playing = c?.value.isPlaying ?? false;
    final fav = state.isFavorite(_current);
    final isEpisode = _current.kind == MediaKind.series;

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
                      : isEpisode
                          ? _current.name
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
                    style: TextStyle(fontSize: 12, color: AppColors.accent),
                  ),
                ),
            ],
          ),
          if (c != null && !isLive) ...[
            const SizedBox(height: 8),
            VideoProgressIndicator(
              c,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: AppColors.accent,
                bufferedColor: const Color(0x33FFFFFF),
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
                onPressed: c == null ? null : _togglePlay,
              ),
              IconButton(
                tooltip: '-10s',
                icon: const Icon(Icons.replay_10),
                onPressed: c == null || isLive ? null : () => _seekBy(-10),
              ),
              IconButton(
                tooltip: 'Anterior',
                icon: const Icon(Icons.skip_previous),
                onPressed: _hasSiblings ? () => _zap(-1) : null,
              ),
              IconButton(
                tooltip: 'Próximo',
                icon: const Icon(Icons.skip_next),
                onPressed: _hasSiblings ? () => _zap(1) : null,
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
          Row(
            children: [
              _menuSpeed(),
              if (_qualities.isNotEmpty) _menuQuality(),
              const Spacer(),
              if (_pipSupported)
                IconButton(
                  tooltip: 'Janela flutuante',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.picture_in_picture_alt, size: 20),
                  onPressed: _controller == null ? null : _enterPip,
                ),
              TextButton(
                onPressed: () => setState(() => _aspect = _aspect.next),
                child: Text(
                  _aspect.label,
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ],
          ),
          if (isEpisode && _hasSiblings)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _zap(1),
                icon: const Icon(Icons.playlist_play, size: 18),
                label: const Text('Próximo episódio'),
              ),
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
            'Toque duas vezes à esquerda/direita para ±10s. Ajuste velocidade, qualidade e aspecto abaixo do vídeo.',
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
            border: Border(bottom: BorderSide(color: AppColors.line)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 46,
                child: Text(
                  p.start == null ? '--:--' : _hhmm(p.start!),
                  style: TextStyle(fontSize: 11.5, color: AppColors.muted),
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
