import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/auth_screen.dart';
import 'screens/splash_screen.dart';
import 'services/cast_service.dart';
import 'services/storage.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  PaintingBinding.instance.imageCache.maximumSize = 220;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 48 << 20;

  await CastService.instance.init();

  final storage = await Storage.open();
  runApp(NeoplayApp(storage: storage));
}

class NeoplayApp extends StatelessWidget {
  const NeoplayApp({super.key, required this.storage});

  final Storage storage;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(storage),
      child: MaterialApp(
        title: 'MIAUNET',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const RootGate(),
      ),
    );
  }
}

class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  bool _authenticated = false;

  @override
  Widget build(BuildContext context) {
    if (!_authenticated) {
      return AuthScreen(
        onAuthenticated: () {
          setState(() {
            _authenticated = true;
          });
        },
      );
    }
    return const SplashScreen();
  }
}
