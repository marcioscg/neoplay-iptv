import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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

  // Listas trazem milhares de logos remotos: limitar o cache evita estouro de
  // memória e travadas ao rolar as grades.
  PaintingBinding.instance.imageCache.maximumSize = 220;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 48 << 20;

  // Cast é opcional: se o aparelho não suportar, o app segue normal.
  await CastService.instance.init();

  final storage = await Storage.open();
  runApp(NeoplayApp(storage: storage));
}

class MiauNetApp extends StatelessWidget {
  const MiauNetApp({super.key, required this.storage});

  final Storage storage;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(storage),
      child: MaterialApp(
        title: 'MIAUNET',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const SplashScreen(),
      ),
    );
  }
}

typedef NeoplayApp = MiauNetApp;
