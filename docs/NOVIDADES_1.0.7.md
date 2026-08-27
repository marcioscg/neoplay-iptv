# MIAU NET 1.0.7 — Player flutuante (Picture-in-Picture)

Versão: `1.0.7 (versionCode 10)`

## Janela flutuante estilo YouTube Premium

Ao **minimizar o app** (Home / recentes) com um vídeo tocando, o player vira uma
**janelinha flutuante** por cima dos outros apps. Funciona em **Android 8 ou
superior**.

- Botões na janelinha: **voltar 10s**, **play/pause**, **avançar 10s**.
- Toque na janelinha para voltar ao app em tela cheia.
- Também dá para acionar na mão pelo botão de **janela flutuante** na barra de
  controles do player (ao lado do botão de tela cheia).
- O vídeo/áudio **continua tocando em segundo plano** enquanto a janelinha está
  aberta. Ao sair do player, para normalmente.

### Por dentro

- Nativo: `MainActivity.kt` implementa PiP com `PictureInPictureParams` +
  `RemoteAction`s; os botões voltam para o Flutter pelo canal `miaunet/pip`.
- `AndroidManifest.xml`: `supportsPictureInPicture="true"` +
  `resizeableActivity="true"`.
- Flutter: `services/pip_service.dart` (ponte) e `player_screen.dart` observa o
  ciclo de vida — quando o app fica inativo com o vídeo tocando, pede PiP; em
  PiP mostra só o vídeo, sem a interface.
- `video_player` passou a usar `allowBackgroundPlayback: true` no player.

### Limitações

- Android 7 ou anterior não tem PiP — o botão não aparece e ao minimizar o app
  o vídeo apenas continua em áudio.
- Puxar a central de notificações rápido pode abrir a janelinha sem querer;
  toque nela para voltar.

## Feito nas versões anteriores (resumo)

- 1.0.5: filtros por gênero, tema claro/escuro, "Meu plano" + WhatsApp,
  renovação no painel, abas Pagamentos/Faturamento, série completa na central
  de uso.
- 1.0.6: correção da senha (não zera mais ao editar; master define no painel no
  modo local), "Esqueci minha senha" no login, timeouts e mensagens no
  Chromecast, `docs/firestore.rules`.
