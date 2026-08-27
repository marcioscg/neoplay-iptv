import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/admin/admin_panel_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/setup_screen.dart';
import 'services/accounts_repository.dart';
import 'services/cast_service.dart';
import 'services/firebase_accounts_repository.dart';
import 'services/storage.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  PaintingBinding.instance.imageCache.maximumSize = 220;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 48 << 20;

  var firebaseOk = false;
  try {
    await Firebase.initializeApp();
    firebaseOk = true;
  } on Object catch (e) {
    debugPrint('Firebase indisponível, usando modo local: $e');
  }

  await CastService.instance.init();

  final storage = await Storage.open();
  final AccountsRepository accounts = firebaseOk
      ? FirebaseAccountsRepository()
      : LocalAccountsRepository(storage);
  runApp(MiauNetApp(storage: storage, accounts: accounts));
}

class MiauNetApp extends StatelessWidget {
  const MiauNetApp({super.key, required this.storage, required this.accounts});

  final Storage storage;
  final AccountsRepository accounts;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(storage, accounts),
      child: MaterialApp(
        title: 'MIAU NET',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const RootGate(),
      ),
    );
  }
}

/// Decide a primeira tela: carrega o estado, exige login e, para a conta
/// master, abre direto o painel de controle.
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  late final Future<void> _boot = context.read<AppState>().bootstrap();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _boot,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BootSplash();
        }
        return Consumer<AppState>(
          builder: (context, state, _) {
            if (!state.isLogged) return const LoginScreen();
            if (state.isMaster && !state.masterAppMode) {
              return const AdminPanelScreen();
            }
            return const _AppEntry();
          },
        );
      },
    );
  }
}

/// Entrada do app comum depois do login.
class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      // Lista salva mas cache vazio: importa agora.
      if (state.hasPlaylist &&
          !state.isBusy &&
          state.stage != LoadStage.loading &&
          state.live.isEmpty &&
          state.movies.isEmpty &&
          state.series.isEmpty) {
        state.refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Master usando como app, ainda sem lista própria: mostra o cadastro.
    if (state.isMaster && !state.hasPlaylist) return const SetupScreen();

    // Conta comum sem lista atribuída pelo painel.
    if (!state.isMaster && !state.hasPlaylist) {
      return Scaffold(
        appBar: AppBar(title: const MiauLogo()),
        body: EmptyState(
          icon: Icons.playlist_remove,
          title: 'Nenhuma lista atribuída',
          message:
              'O administrador ainda não vinculou uma lista M3U a esta conta. '
              'Fale com ele para liberar o conteúdo.',
          action: OutlinedButton(
            onPressed: context.read<AppState>().logout,
            child: const Text('Sair'),
          ),
        ),
      );
    }

    return const HomeScreen();
  }
}

class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MiauLogo(size: 28),
            SizedBox(height: 20),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(minHeight: 3),
            ),
          ],
        ),
      ),
    );
  }
}
