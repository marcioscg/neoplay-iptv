# BUILD NOTES — NEOPLAY

## Ambiente validado

- Flutter: **3.47.1** (canal stable; framework `6655482ec0`)
- Dart: **3.13.1**
- DevTools: **2.60.0**
- Dependências: resolvidas com `flutter pub get` em 23/08/2026.

## Validação final

Comando executado no diretório `app`:

```text
flutter analyze
No issues found! (ran in 6.7s)
```

Resultado: **0 erros, 0 warnings e 0 infos**.

Também foi executado `dart format lib/`; os 15 arquivos Dart da pasta `lib/` estão formatados. O conteúdo final de `app/lib/` foi copiado para `src/lib/`.

## Arquivos alterados e motivo

### Scaffold e dependências

- `app/`: projeto Flutter gerado com plataformas Android e iOS, organização e application ID `br.com.neoplay.neoplay`.
- `app/pubspec.yaml`: substituído pelo `src/pubspec.yaml` fornecido.
- `app/pubspec.lock`: criado/atualizado por `flutter pub get`.
- `app/test/`: removido, pois continha o teste padrão incompatível com o app fornecido.

### Android

- `app/android/app/src/main/AndroidManifest.xml`:
  - permissões `INTERNET` e `ACCESS_NETWORK_STATE`;
  - `usesCleartextTraffic="true"` para streams IPTV HTTP;
  - rótulo `NEOPLAY`;
  - orientação `fullSensor` na atividade principal;
  - recursos opcionais de Android TV (`leanback` e touchscreen não obrigatório);
  - intent filter `LEANBACK_LAUNCHER` para inicialização em Android TV.
- `app/android/app/build.gradle.kts`: `minSdk = 21`, requerido pelo `video_player`; namespace e application ID gerados foram mantidos como `br.com.neoplay.neoplay`.

### Código Dart

- `app/lib/screens/items_screen.dart`: removido import não utilizado.
- `app/lib/services/xtream_api.dart`: exceções estáticas transformadas em construções `const`, sem alterar comportamento.
- `app/lib/screens/player_screen.dart`: acrescentadas chaves em condicionais para satisfazer a regra de lint, sem alterar a lógica.
- `app/lib/**/*.dart`: formatação aplicada pelo `dart format`.
- `src/lib/`: sincronizado integralmente a partir da versão validada em `app/lib/`.

## Ressalvas para gerar o APK

- O APK **não foi gerado neste ambiente**, conforme solicitado, para não instalar o Android SDK e preservar o espaço disponível. A geração deve ocorrer no GitHub Actions.
- O projeto exige Android API mínima 21. O `ndkVersion` permanece no valor compatível fornecido pelo Flutter (`flutter.ndkVersion`); não houve erro de Gradle que justificasse sobrescrevê-lo.
- Para APK de distribuição, configure uma assinatura de release no workflow/segredos do GitHub Actions. O scaffold mantém assinatura debug para builds release locais de teste.
