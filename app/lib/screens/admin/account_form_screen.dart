import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/accounts_repository.dart';
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
  bool _renewNow = false;
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
    final typedPass = _pass.text;
    final m3u = _m3u.text.trim();
    final state = context.read<AppState>();

    if (!email.contains('@')) {
      setState(() => _error = 'Informe um e-mail válido.');
      return;
    }
    if (!_isEdit && typedPass.length < 4) {
      setState(() => _error = 'A senha precisa de pelo menos 4 caracteres.');
      return;
    }
    // Editando: só valida a senha se o master digitou uma nova.
    final changingPass = _isEdit && typedPass.isNotEmpty;
    if (changingPass && typedPass.length < 4) {
      setState(() => _error = 'A nova senha precisa de pelo menos 4 caracteres.');
      return;
    }
    if (m3u.isNotEmpty && !m3u.startsWith('http')) {
      setState(() => _error = 'A lista M3U deve começar com http:// ou https://');
      return;
    }

    final now = DateTime.now();
    final base = widget.user;
    final expiresAt = _resolveExpiry(base, now);

    final user = AdminUser(
      id: base?.id ?? 'u${now.microsecondsSinceEpoch}',
      name: _name.text.trim(),
      email: email,
      // Ao editar sem digitar senha nova, preserva a senha atual (não zera!).
      password: _isEdit ? (base?.password ?? '') : typedPass,
      m3uUrl: m3u,
      plan: _plan,
      status: _status,
      createdAt: base?.createdAt ?? now,
      expiresAt: expiresAt,
      lastDevice: base?.lastDevice ?? '',
      lastSeenAt: base?.lastSeenAt,
    );

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final outcome = await state.saveAdminUser(user);
      if (changingPass && state.canMasterSetPassword) {
        final err = await state.setUserPassword(user, typedPass);
        if (err != null) {
          if (!mounted) return;
          setState(() {
            _busy = false;
            _error = err;
          });
          return;
        }
      }
      if (!mounted) return;
      if (outcome == SaveOutcome.revived) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface2,
            title: const Text('Conta reativada'),
            content: Text(
              'Esse e-mail já tinha sido cadastrado antes. A conta foi reativada '
              'e enviamos um e-mail para $email definir a nova senha '
              '(a senha antiga não pode ser reaproveitada pelo painel).',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Entendi'),
              ),
            ],
          ),
        );
        if (!mounted) return;
      }
      Navigator.of(context).pop();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _friendly('$e');
      });
    }
  }

  /// Regras de vencimento:
  /// - conta nova: hoje + duração do plano;
  /// - vitalício: sem data;
  /// - editando e marcou "renovar agora": um período a partir da validade atual;
  /// - editando e trocou o plano: recalcula a partir de hoje;
  /// - editando sem mexer: mantém a data que já estava.
  DateTime? _resolveExpiry(AdminUser? base, DateTime now) {
    if (_plan.days == null) return null;
    if (base == null) return now.add(Duration(days: _plan.days!));
    if (_renewNow) {
      return base.copyWith(plan: _plan).renewedExpiry(from: now);
    }
    if (_plan != base.plan || base.expiresAt == null) {
      return now.add(Duration(days: _plan.days!));
    }
    return base.expiresAt;
  }

  String _friendly(String raw) {
    final clean = raw.replaceAll('Exception: ', '').trim();
    if (clean.contains('email-already-in-use')) {
      return 'Já existe uma conta com esse e-mail.';
    }
    if (clean.contains('invalid-email')) return 'E-mail inválido.';
    if (clean.contains('weak-password')) return 'Senha muito fraca.';
    if (clean.contains('network')) return 'Sem conexão com o servidor.';
    // Mensagens já em português vindas do repositório passam direto.
    if (RegExp(r'^[A-ZÀ-Ú].*[.!?]$').hasMatch(clean) &&
        !clean.contains('-')) {
      return clean;
    }
    return 'Não foi possível salvar. Tente de novo.';
  }

  Future<void> _resetPassword() async {
    try {
      await context.read<AppState>().sendPasswordReset(_email.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Se o e-mail estiver cadastrado, o link chega em alguns minutos. '
            'Peça para a pessoa conferir a caixa de spam.',
          ),
        ),
      );
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendly('$e'))),
      );
    }
  }

  /// Campo de senha adaptado ao modo:
  /// - conta nova: senha obrigatória;
  /// - editando no modo local: campo "Nova senha" (em branco = manter);
  /// - editando no modo Firebase: botão de e-mail de redefinição.
  Widget _passwordField(BuildContext context) {
    final state = context.watch<AppState>();

    if (!_isEdit || state.canMasterSetPassword) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: _pass,
          obscureText: _obscure,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: _isEdit ? 'Nova senha (em branco = manter)' : 'Senha',
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
      );
    }

    if (state.canEmailPasswordReset) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: _resetPassword,
              icon: const Icon(Icons.mail_outline, size: 18),
              label: const Text('Enviar e-mail de redefinição de senha'),
            ),
            const SizedBox(height: 6),
            Text(
              'O e-mail vem de noreply@iptv-f90b5.firebaseapp.com. Se não chegar, '
              'confira o spam ou personalize o remetente em Authentication > '
              'Templates no console do Firebase.',
              style: TextStyle(
                  fontSize: 11, color: AppColors.muted, height: 1.4),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
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
          _passwordField(context),
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
          if (_isEdit) _renewalSection(),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!,
                style: TextStyle(fontSize: 12.5, color: AppColors.bad)),
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
          Text(
            'A pessoa entra no app com este e-mail e senha. A lista M3U é '
            'carregada automaticamente no aparelho dela.',
            style: TextStyle(fontSize: 11, color: AppColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _renewalSection() {
    final u = widget.user!;
    final expired = u.isExpired;
    final validade = u.plan == UserPlan.vitalicio
        ? 'Plano vitalício'
        : u.expiresAt == null
            ? 'Sem validade definida'
            : '${expired ? 'Venceu' : 'Vence'} em ${_date(u.expiresAt!)}';

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.event_available_outlined,
                        size: 16,
                        color: expired ? AppColors.bad : AppColors.muted),
                    const SizedBox(width: 8),
                    Text(validade,
                        style: TextStyle(
                            fontSize: 12.5,
                            color: expired ? AppColors.bad : AppColors.text)),
                  ],
                ),
                if (u.lastDevice.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.smartphone,
                          size: 16, color: AppColors.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${u.lastDevice}'
                          '${u.lastSeenAt != null ? ' · último acesso ${_date(u.lastSeenAt!)}' : ''}',
                          style: TextStyle(
                              fontSize: 11.5, color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (u.plan != UserPlan.vitalicio)
            CheckboxListTile(
              value: _renewNow,
              onChanged: (v) => setState(() => _renewNow = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              title: const Text('Renovar por mais um período ao salvar',
                  style: TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

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
