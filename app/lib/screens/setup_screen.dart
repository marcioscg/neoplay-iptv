import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_screen.dart';

/// Telas 02 e 03 — Adicionar lista (Xtream Codes ou URL M3U).
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  final _nameXtream = TextEditingController(text: 'Minha lista');
  final _host = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();

  final _nameM3u = TextEditingController(text: 'Minha lista');
  final _url = TextEditingController();

  bool _busy = false;

  @override
  void dispose() {
    _tabs.dispose();
    _nameXtream.dispose();
    _host.dispose();
    _user.dispose();
    _pass.dispose();
    _nameM3u.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _connect(Playlist playlist) async {
    setState(() => _busy = true);
    final state = context.read<AppState>();
    final ok = await state.connect(playlist);
    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.error ?? 'Não foi possível conectar')),
      );
    }
  }

  void _submitXtream() {
    if (_host.text.trim().isEmpty ||
        _user.text.trim().isEmpty ||
        _pass.text.isEmpty) {
      _warn('Preencha servidor, usuário e senha');
      return;
    }
    _connect(Playlist(
      name: _nameXtream.text.trim().isEmpty
          ? 'Minha lista'
          : _nameXtream.text.trim(),
      kind: PlaylistKind.xtream,
      host: _host.text.trim(),
      username: _user.text.trim(),
      password: _pass.text,
    ));
  }

  void _submitM3u() {
    final url = _url.text.trim();
    if (!url.startsWith('http')) {
      _warn('Informe uma URL http(s) válida');
      return;
    }
    _connect(Playlist(
      name: _nameM3u.text.trim().isEmpty ? 'Minha lista' : _nameM3u.text.trim(),
      kind: PlaylistKind.m3u,
      url: url,
    ));
  }

  void _warn(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const NeoLogo(),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Xtream Codes'),
            Tab(text: 'URL M3U'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabs,
          children: [
            _form(children: [
              _hero('Xtream Codes',
                  'Host, usuário e senha fornecidos pelo seu provedor.'),
              _field('Nome da lista', _nameXtream),
              _field('Servidor (host)', _host,
                  hint: 'http://servidor.com:8080'),
              _field('Usuário', _user),
              _field('Senha', _pass, obscure: true),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _busy ? null : _submitXtream,
                child: Text(_busy ? 'Conectando…' : 'Testar e conectar'),
              ),
            ]),
            _form(children: [
              _hero(
                  'URL M3U / M3U8', 'Link direto da sua lista de reprodução.'),
              _field('Nome da lista', _nameM3u),
              _field('URL da lista', _url,
                  hint: 'http://servidor.com/get.php?...'),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _busy ? null : _submitM3u,
                child: Text(_busy ? 'Carregando…' : 'Carregar lista'),
              ),
            ]),
          ],
        ),
      ),
      bottomNavigationBar: _busy
          ? Container(
              color: AppColors.surface2,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      state.progressLabel.isEmpty
                          ? 'Processando…'
                          : state.progressLabel,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _form({required List<Widget> children}) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...children,
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x08FFFFFF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, size: 16, color: AppColors.muted),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'O aplicativo não fornece nem hospeda conteúdo. '
                    'Use apenas listas que você tem direito de acessar.',
                    style: TextStyle(
                        fontSize: 11.5, color: AppColors.muted, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _hero(String title, String subtitle) => Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0x24FFC93C), Color(0x0AFF9A2E)],
          ),
          border: Border.all(color: const Color(0x38FFC93C)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.muted, height: 1.45),
            ),
          ],
        ),
      );

  Widget _field(
    String label,
    TextEditingController controller, {
    String hint = '',
    bool obscure = false,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          obscureText: obscure,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: obscure ? TextInputType.text : TextInputType.url,
          decoration: InputDecoration(labelText: label, hintText: hint),
        ),
      );
}
