import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/launcher.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Tela de login. A conta master abre o painel de controle; contas comuns
/// entram no app com a lista atribuída pelo administrador.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _remember = true;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await context.read<AppState>().login(
          _email.text,
          _pass.text,
          remember: _remember,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
    // Sucesso: o RootGate troca de tela sozinho ao ouvir o AppState.
  }

  Future<void> _forgotPassword() async {
    FocusScope.of(context).unfocus();
    final state = context.read<AppState>();
    final email = _email.text.trim();
    final canEmail = state.canEmailPasswordReset;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface2,
        title: const Text('Redefinir senha'),
        content: Text(
          canEmail
              ? 'Podemos enviar um link de redefinição para o seu e-mail, ou '
                  'você fala com o administrador.'
              : 'Sua senha é definida pelo administrador. Fale com ele para '
                  'criar uma nova.',
          style: TextStyle(fontSize: 13, color: AppColors.text, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fechar'),
          ),
          if (canEmail && email.contains('@'))
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _sendReset(email);
              },
              child: const Text('Enviar e-mail'),
            ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              Launcher.whatsapp(
                'Esqueci minha senha do MIAU NET'
                '${email.contains('@') ? ' (e-mail $email)' : ''}. '
                'Pode redefinir pra mim?',
              );
            },
            icon: const Icon(Icons.chat, size: 18),
            label: const Text('WhatsApp'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendReset(String email) async {
    try {
      await context.read<AppState>().sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Se o e-mail estiver cadastrado, o link chega em minutos. '
            'Confira o spam.',
          ),
        ),
      );
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceAll('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: CatMark(size: 76)),
                const SizedBox(height: 18),
                const Center(child: MiauLogo(size: 26)),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'Entre para acessar sua lista',
                    style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface1,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _email,
                        autocorrect: false,
                        enableSuggestions: false,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: Icon(Icons.alternate_email, size: 18),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pass,
                        obscureText: _obscure,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          if (!_busy) _submit();
                        },
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(Icons.lock_outline, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 18,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      CheckboxListTile(
                        value: _remember,
                        onChanged: (v) =>
                            setState(() => _remember = v ?? false),
                        title: const Text('Manter conectado',
                            style: TextStyle(fontSize: 13)),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _error!,
                          style: TextStyle(
                              fontSize: 12, color: AppColors.bad),
                        ),
                      ],
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Color(0xFF171207)),
                              )
                            : const Text('Entrar'),
                      ),
                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: _busy ? null : _forgotPassword,
                          child: const Text('Esqueci minha senha',
                              style: TextStyle(fontSize: 12.5)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Este aplicativo não fornece, hospeda ou distribui conteúdo. '
                  'As listas são cadastradas pelo administrador da conta.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 10.5, color: Color(0xFF5B6274), height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
