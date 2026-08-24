import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_screen.dart';
import 'setup_screen.dart';

/// Tela 01 — Splash: decide entre onboarding e home.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decide());
  }

  Future<void> _decide() async {
    final state = context.read<AppState>();
    await state.bootstrap();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    final target = state.hasPlaylist ? const HomeScreen() : const SetupScreen();
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => target),
    );

    // Se já existe lista mas o cache está vazio, importa em seguida.
    if (state.hasPlaylist && state.live.isEmpty && state.movies.isEmpty) {
      await state.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 0.9,
            colors: [Color(0x1FFFC93C), AppColors.bg],
          ),
        ),
        child: const Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                NeoLogo(size: 30),
                SizedBox(height: 22),
                SizedBox(
                  width: 130,
                  child: LinearProgressIndicator(minHeight: 3),
                ),
                SizedBox(height: 14),
                Text(
                  'Carregando sua lista…',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                ),
              ],
            ),
            Positioned(
              bottom: 40,
              child: Text(
                'v1.0.0',
                style: TextStyle(fontSize: 11, color: Color(0xFF4D5464)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
