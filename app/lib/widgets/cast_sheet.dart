import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../models/models.dart';
import '../services/cast_service.dart';
import '../theme.dart';
import 'common.dart';

/// Abre a folha "Enviar para TV" e devolve true se a transmissão começou.
Future<bool> showCastSheet(
  BuildContext context,
  MediaItem item, {
  Duration position = Duration.zero,
}) async {
  final started = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.surface1,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _CastSheet(item: item, position: position),
  );
  return started ?? false;
}

class _CastSheet extends StatefulWidget {
  const _CastSheet({required this.item, required this.position});

  final MediaItem item;
  final Duration position;

  @override
  State<_CastSheet> createState() => _CastSheetState();
}

class _CastSheetState extends State<_CastSheet> {
  final _cast = CastService.instance;
  String? _connecting;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cast.startDiscovery();
  }

  @override
  void dispose() {
    _cast.stopDiscovery();
    super.dispose();
  }

  Future<void> _send(GoogleCastDevice device) async {
    setState(() {
      _connecting = device.deviceID;
      _error = null;
    });
    try {
      await _cast.castItem(device, widget.item, position: widget.position);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _connecting = null;
        _error = 'Não foi possível transmitir: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_cast.isAvailable) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: EmptyState(
          icon: Icons.cast_connected_outlined,
          title: 'Transmissão indisponível',
          message:
              'Este aparelho não tem suporte ao Google Cast ou os serviços do '
              'Google não estão instalados.',
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.cast, color: AppColors.accent, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Enviar para TV',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'A TV precisa estar no mesmo Wi-Fi do celular. Só aparecem '
              'Chromecast, Android TV, Google TV e TVs com Chromecast embutido — '
              'TVs Samsung/LG com sistema próprio não são detectadas aqui.',
              style: TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
            if (CastService.isRiskyFormat(widget.item.url)) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0x1AFFC93C),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Este arquivo está em MKV/AVI: o Chromecast pode não abrir. '
                  'Se travar, use um episódio em MP4 ou m3u8.',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.accent, height: 1.4),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(fontSize: 11.5, color: AppColors.bad),
              ),
            ],
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: StreamBuilder<List<GoogleCastDevice>>(
                stream: _cast.devicesStream,
                builder: (context, snapshot) {
                  final devices = snapshot.data ?? const <GoogleCastDevice>[];
                  if (devices.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 22),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Procurando aparelhos na rede…',
                                style: TextStyle(
                                    fontSize: 12.5, color: AppColors.muted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () {
                              _cast.stopDiscovery();
                              _cast.startDiscovery();
                            },
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Procurar de novo'),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: devices.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: AppColors.line),
                    itemBuilder: (context, i) {
                      final d = devices[i];
                      final busy = _connecting == d.deviceID;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.tv, color: AppColors.muted),
                        title: Text(
                          d.friendlyName,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          d.modelName ?? 'Google Cast',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.muted),
                        ),
                        trailing: busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.chevron_right, size: 18),
                        onTap: _connecting == null ? () => _send(d) : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Painel exibido no player enquanto o conteúdo toca na TV.
class CastPanel extends StatelessWidget {
  const CastPanel({
    super.key,
    required this.title,
    required this.deviceName,
    required this.onStop,
  });

  final String title;
  final String deviceName;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final cast = CastService.instance;

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cast_connected, size: 42, color: AppColors.accent),
          const SizedBox(height: 12),
          Text(
            'Transmitindo em $deviceName',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          StreamBuilder<GoggleCastMediaStatus?>(
            stream: cast.mediaStatusStream,
            builder: (context, snapshot) {
              final playing =
                  snapshot.data?.playerState == CastMediaPlayerState.playing;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 30,
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    onPressed: () => playing ? cast.pause() : cast.play(),
                  ),
                  const SizedBox(width: 18),
                  IconButton(
                    iconSize: 26,
                    icon: const Icon(Icons.stop_circle_outlined),
                    color: AppColors.bad,
                    onPressed: onStop,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
