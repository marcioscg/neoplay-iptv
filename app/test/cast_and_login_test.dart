import 'package:flutter_test/flutter_test.dart';
import 'package:miaunet/services/accounts_repository.dart';
import 'package:miaunet/services/cast_service.dart';
import 'package:miaunet/services/storage.dart';
import 'package:miaunet/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CastService.sniff', () {
    test('HLS pelo cabeçalho #EXTM3U (com BOM)', () {
      final b = [0xEF, 0xBB, 0xBF, ...'#EXTM3U\n'.codeUnits];
      expect(CastService.sniff(b, ''), CastStreamKind.hls);
    });

    test('MP4 pelo box ftyp', () {
      final b = [0, 0, 0, 0x20, ...'ftypisom'.codeUnits];
      expect(CastService.sniff(b, ''), CastStreamKind.mp4);
    });

    test('MKV pela assinatura EBML', () {
      expect(CastService.sniff([0x1A, 0x45, 0xDF, 0xA3, 1], ''),
          CastStreamKind.matroska);
    });

    test('MPEG-TS pelo byte de sincronia a cada 188', () {
      final b = List<int>.filled(200, 0)
        ..[0] = 0x47
        ..[188] = 0x47;
      expect(CastService.sniff(b, ''), CastStreamKind.ts);
    });

    test('sem assinatura usa o content-type', () {
      expect(CastService.sniff([1, 2, 3], 'application/vnd.apple.mpegurl'),
          CastStreamKind.hls);
      expect(CastService.sniff([1, 2, 3], 'text/html'), CastStreamKind.unknown);
    });
  });

  test('login bloqueia após 5 tentativas erradas', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await Storage.open();
    final state = AppState(storage, LocalAccountsRepository(storage));

    for (var i = 1; i < AppState.maxLoginAttempts; i++) {
      final msg = await state.login('x@y.com', 'errada', remember: false);
      expect(msg, startsWith(kInvalidCredentials));
    }
    final locked = await state.login('x@y.com', 'errada', remember: false);
    expect(locked, startsWith('Muitas tentativas'));
    // Mesmo com credencial qualquer, segue bloqueado até expirar.
    final still = await state.login('x@y.com', 'outra', remember: false);
    expect(still, startsWith('Muitas tentativas'));
  });
}
