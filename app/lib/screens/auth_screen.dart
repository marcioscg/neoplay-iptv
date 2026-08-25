import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'admin_dashboard_screen.dart';
import 'home_screen.dart';
import 'setup_screen.dart';

/// Tela de Login — Ponto de entrada do MIAUNET.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('Informe o e-mail e a senha');
      return;
    }

    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final state = context.read<AppState>();

    // 1. Acesso Admin Master
    if (email == 'marcioscg@hotmail.com' && password == '27062015EmillY') {
      const adminMaster = AdminUser(
        id: 'admin_master',
        name: 'Administrador Master',
        email: 'marcioscg@hotmail.com',
        password: '27062015EmillY',
        plan: AdminPlan.vitalicio,
        createdAt: DateTime(2026, 1, 1),
        expiresAt: DateTime(2099, 12, 31),
        isActive: true,
        notes: 'Conta Master',
      );
      await state.setLoggedUser(adminMaster);
      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const AdminDashboardScreen()),
      );
      return;
    }

    // 2. Acesso de Usuários Cadastrados
    final user = state.adminUsers.firstWhere(
      (u) => u.email.toLowerCase() == email && u.password == password,
      orElse: () => const AdminUser(
        id: '',
        name: '',
        email: '',
        password: '',
        plan: AdminPlan.mensal,
        createdAt: DateTime(2000, 1, 1),
        expiresAt: DateTime(2000, 1, 1),
      ),
    );

    if (user.id.isEmpty) {
      setState(() => _loading = false);
      _showError('E-mail ou senha incorretos.');
      return;
    }

    if (!user.isActive) {
      setState(() => _loading = false);
      _showError('Sua conta está bloqueada pelo administrador.');
      return;
    }

    if (user.isExpired) {
      setState(() => _loading = false);
      _showError(
        'Sua assinatura venceu em ${_date(user.expiresAt)}. Contate o administrador.',
      );
      return;
    }

    // Sucesso
    await state.setLoggedUser(user);
    if (!mounted) return;
    setState(() => _loading = false);

    final target = state.hasPlaylist ? const HomeScreen() : const SetupScreen();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => target),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.bad,
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.0,
            colors: [Color(0x22FFC93C), AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const MiauLogo(size: 34),
                  const SizedBox(height: 10),
                  const Text(
                    'Seu player IPTV completo e inteligente',
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                  const SizedBox(height: 36),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface1,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.line),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Acessar Conta',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'E-mail',
                            hintText: 'ex: usuario@miaunet.com',
                            prefixIcon: Icon(Icons.email_outlined,
                                color: AppColors.muted),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Senha',
                            prefixIcon: const Icon(Icons.lock_outline,
                                color: AppColors.muted),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: AppColors.muted,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _loading ? null : _login,
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Text('ENTRAR NO MIAUNET'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    icon: const Icon(Icons.add_link, size: 18),
                    label: const Text('Entrar sem conta / Configurar Lista M3U'),
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => const SetupScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';