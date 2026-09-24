# MIAU NET 1.0.9 — Visual roxo, navegação, player, Chromecast e push

Versão: `1.0.9 (versionCode 12)`

## Visual
- Amarelo trocado por roxo inspirado no Roku (`#662D91` no tema claro,
  `#9061DD` no escuro, texto branco nos botões). Cores centralizadas em
  `lib/theme.dart`; app e painel usam o mesmo tema.
- Ícone do app (Android adaptativo, Android legado e iOS) e logo em roxo.

## Login
- Bloqueio local após **5** tentativas erradas seguidas, por 5 minutos
  (persiste ao fechar o app). Antes não havia limite no app — só o do próprio
  Firebase Auth, que continua valendo. Nenhuma senha é gravada.

## Navegação
- TV: Favoritos → Recentes → Gêneros → Todos os canais → Categorias.
- Filmes: Favoritos → Recentes (com progresso) → Gêneros → Todos → Categorias.
- Séries: Continuar assistindo → Favoritos → Gêneros → Todas → Categorias;
  temporadas e episódios ao tocar na série.
- Atalho de busca no topo de cada aba. Favoritos/recentes agora são por tipo e
  respeitam o filtro adulto.

## Player
- Tela fica ligada só enquanto o vídeo toca (`wakelock_plus`:
  FLAG_KEEP_SCREEN_ON no Android, idleTimer no iOS). Não impede o bloqueio
  manual; ao pausar/sair volta ao normal.
- Toques no vídeo: 2 toques = ±10s, 4 = ±20s, 6 = ±30s (lado direito avança,
  esquerdo volta), com aviso "+20"/"-10". Um toque continua mostrando os
  controles. Funciona também com os controles visíveis; os botões atuais
  foram mantidos.

## Chromecast
Antes de conectar, o app lê os primeiros bytes do stream (com o User-Agent do
Chromecast) e decide o que mandar:
- **Ao vivo** em MPEG-TS (`/usuario/senha/123` ou `.ts`): tenta a variante HLS
  do painel (`/live/usuario/senha/123.m3u8`). Se só houver TS, avisa que o
  Chromecast não reproduz esse formato, sem conectar à toa.
- **Filmes/episódios**: tipo real pelo conteúdo (MP4, HLS). MKV/AVI e TS
  progressivo são recusados com aviso: o app **não converte** vídeo e o
  receptor padrão não suporta esses containers.
- Erros 401/403/404 do provedor aparecem antes de conectar.
- Depois do `loadMedia`, espera o status da TV: se o receptor der erro
  (ex.: HLS sem CORS/HTTPS no servidor), mostra a causa e encerra a sessão.
- Limite real: o receptor padrão do Google não toca HLS de servidores sem
  CORS. Resolver isso exige um receptor próprio (Cast Console) ou proxy.
- **Não testado em Chromecast real.** A troca TS → `.m3u8` depende de o
  painel do provedor servir HLS nesse caminho; só um aparelho confirma.

## Notificações push (FCM)
- App: pede permissão, grava `push_profiles/{uid}` com token, sugestões reais
  do catálogo do aparelho (mesmo gênero do último filme/série, sem adulto, sem
  já vistos, ordem variando por dia) e o último episódio de série.
- Backend: `functions/index.js` com duas funções agendadas (fuso
  America/Sao_Paulo): **15h** sugestão, **22h** "Que tal continuar assistindo
  sua série?". Uma por dia cada (`lastSuggestDay`/`lastSeriesDay`), não repete
  título (`sentSuggestionIds`), pula contas bloqueadas/vencidas/removidas e
  descarta tokens inválidos.
- Tocar na notificação abre o título/episódio no app.
- Chave em Configurações → Notificações para desligar.

### O que falta configurar (fora do código)
1. Plano **Blaze** no projeto `iptv-f90b5` (agendamento de funções exige).
2. `cd functions && npm install` e `firebase deploy --only functions`.
3. Publicar as regras: `firebase deploy --only firestore:rules`
   (inclui `push_profiles`).
4. **iOS** (só validável em macOS/Xcode):
   - adicionar `GoogleService-Info.plist` em `ios/Runner`;
   - em Signing & Capabilities: *Push Notifications* e *Background Modes →
     Remote notifications* (o `Info.plist` já declara o modo);
   - enviar a chave APNs (.p8) em Firebase Console → Configurações do projeto →
     Cloud Messaging.
   O build/teste iOS **não** foi feito (ambiente Windows).
