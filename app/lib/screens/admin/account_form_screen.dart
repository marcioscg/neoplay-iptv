import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';

/// Cadastro / edição de uma conta comum.
class AccountFormScreen extends StatefulWidget {
  const AccountFormScreen({super.key, this.user});

  final AdminUser? user;

  @override
  State<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends State<AccountFormScreen> {
  late final TextEditingController _name =
      TextEditingController(text: widget.user?.name ?? '');
  late final TextEditingController _email =
      TextEditingController(text: widget.user?.email ?? '');
  final TextEditingController _pass = TextEditingController();
  late final TextEditingController _m3u =
      TextEditingController(text: widget.user?.m3uUrl ?? '');

  late UserPlan _plan = widget.user?.plan ?? UserPlan.mensal;
  late UserStatus _status = widget.user?.status ?? UserStatus.active;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.user != null;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    _m3u.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final email = _email.text.trim();
    final pass = _pass.text;
    final m3u = _m3u.text.trim();

    if (!email.contains('@')) {
      setState(() => _error = 'Informe um e-mail válido.');
      return;
    }
    if (!_isEdit && pass.length < 4) {
      setState(() => _error = 'A senha precisa de pelo menos 4 caracteres.');
      return;
    }
    if (m3u.isNotEmpty && !m3u.startsWith('http')) {
      setState(() => _error = 'A lista M3U deve começar com http:// ou https://');
      return;
    }

    final now = DateTime.now();
    final base = widget.user;
    final expiresAt =
        _plan.days == null ? null : now.add(Duration(days: _plan.days!));

    final user = AdminUser(
      id: base?.id ?? 'u${now.microsecondsSinceEpoch}',
      name: _name.text.trim(),
      email: email,
      password: pass,
      m3uUrl: m3u,
      plan: _plan,
      status: _status,
      createdAt: base?.createdAt ?? now,
      expiresAt: expiresAt,
    );

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppState>().saveAdminUser(user);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _friendly('$e');
      });
    }
  }

  String _friendly(String raw) {
    if (raw.contains('email-already-in-use')) {
      return 'Já existe uma conta com esse e-mail.';
    }
    if (raw.contains('invalid-email')) return 'E-mail inválido.';
    if (raw.contains('weak-password')) return 'Senha muito fraca.';
    if (raw.contains('network')) return 'Sem conexão com o servidor.';
    return 'Não foi possível salvar: $raw';
  }

  Future<void> _resetPassword() async {
    try {
      await context.read<AppState>().accounts.sendPasswordReset(_email.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mail de redefinição enviado.')),
      );
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao enviar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Editar conta' : 'Nova conta')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _field('Nome', _name, hint: 'Como identificar essa pessoa'),
          _field('E-mail', _email,
              hint: 'usuario@email.com',
              keyboard: TextInputType.emailAddress,
              enabled: !_isEdit),
          if (!_isEdit)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _pass,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton.icon(
                onPressed: _resetPassword,
                icon: const Icon(Icons.mail_outline, size: 18),
                label: const Text('Enviar redefinição de senha'),
              ),
            ),
          _field('Lista M3U / M3U8', _m3u,
              hint: 'http://servidor.com/get.php?...',
              keyboard: TextInputType.url),
          const SizedBox(height: 4),
          DropdownButtonFormField<UserPlan>(
            initialValue: _plan,
            decoration: const InputDecoration(labelText: 'Plano'),
            items: [
              for (final p in UserPlan.values)
                DropdownMenuItem(value: p, child: Text(p.label)),
            ],
            onChanged: (v) => setState(() => _plan = v ?? _plan),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<UserStatus>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: [
              for (final s in UserStatus.values)
                DropdownMenuItem(value: s, child: Text(s.label)),
            ],
            onChanged: (v) => setState(() => _status = v ?? _status),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!,
                style: const TextStyle(fontSize: 12.5, color: AppColors.bad)),
          ],
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy
                ? 'Salvando…'
                : _isEdit
                    ? 'Salvar alterações'
                    : 'Criar conta'),
          ),
          const SizedBox(height: 10),
          const Text(
            'A pessoa entra no app com este e-mail e senha. A lista M3U é '
            'carregada automaticamente no aparelho dela.',
            style: TextStyle(fontSize: 11, color: AppColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String hint = '',
    TextInputType? keyboard,
    bool enabled = true,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          keyboardType: keyboard,
          enabled: enabled,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(labelText: label, hintText: hint),
        ),
      );
}
