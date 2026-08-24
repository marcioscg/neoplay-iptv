# NEOPLAY 1.0.2 — Séries e transmissão para TV

Versão: `1.0.2 (versionCode 3)`

## 1. Aba Séries

A home passou a ter quatro abas: **Canais · Filmes · Séries · Favoritos**.

### Em listas Xtream Codes
A importação agora consulta também `get_series_categories` e `get_series`. Cada
série entra como um "container" sem URL própria (`id = series_<id>`), organizado
por categoria igual aos filmes.

Ao tocar em uma série, o app chama `get_series_info&series_id=<id>` e monta a
tela de detalhe:

- capa, sinopse, gênero, nota e ano;
- seletor de temporadas (chips T1, T2, T3…);
- lista de episódios com miniatura, `S01E03 · Título` e duração;
- ao tocar num episódio, ele toca no player normal e o botão de próximo/anterior
  passa a zapear entre os episódios da temporada.

A URL do episódio segue o padrão do Xtream:
`{host}/series/{usuario}/{senha}/{episode_id}.{extensão}`.

O resultado de `get_series_info` fica em cache na memória, então reabrir a mesma
série não bate no servidor de novo.

### Em listas M3U
Listas M3U não têm API de temporadas. O parser passou a marcar como série tudo
que tem `/series/` na URL ou categoria com "série", "novela", "anime" ou
"temporada". Esses itens saem de Filmes e aparecem na aba Séries, com os
episódios direto na grade da categoria (é o máximo que o formato M3U permite).

### Cache
O arquivo de cache subiu para a versão 2 e agora guarda `series` junto com
`live` e `movies`. Cache antigo (v1) continua sendo lido — a aba Séries só fica
vazia até a próxima atualização da lista.

## 2. Enviar para TV / Chromecast

Implementado com o SDK oficial do Google Cast através do plugin
`flutter_chrome_cast` (1.4.x), encapsulado em `lib/services/cast_service.dart`
para que as telas não dependam do plugin direto — se o Cast falhar num aparelho,
o app continua funcionando normalmente na tela do celular.

Como funciona:

1. No player, o ícone de transmissão (canto superior direito) abre a folha
   **Enviar para TV**.
2. O app procura aparelhos Google Cast, Chromecast, Google TV e TVs com Cast
   embutido na mesma rede Wi‑Fi.
3. Ao escolher a TV, o player do celular pausa, a sessão é aberta e o stream é
   enviado já na posição em que você estava (em VOD e séries; canais ao vivo
   sempre começam do vivo).
4. Enquanto transmite, a tela mostra o painel "Transmitindo em <TV>" com
   play/pause e parar. Parar encerra a sessão e volta a tocar no celular.

Detalhes técnicos importantes:

- `contentType` é escolhido pela extensão (`m3u8` → `application/x-mpegurl`,
  `mpd` → `application/dash+xml`, resto → `video/mp4`), porque o Chromecast
  escolhe o decodificador por esse campo — enviar errado dá tela preta com áudio.
- Canais ao vivo usam `streamType: LIVE`; filmes e episódios usam `BUFFERED`.
- Arquivos `.mkv` e `.avi` mostram um aviso amarelo: o Chromecast normalmente
  não abre esses formatos. Não é bug do app, é limitação do aparelho.

### Mudanças no Android

- `minSdk` subiu de 21 para **23** (Android 6), exigência do SDK do Cast.
- Manifest ganhou `ACCESS_WIFI_STATE`, `FOREGROUND_SERVICE`,
  `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, o `OPTIONS_PROVIDER_CLASS_NAME` do plugin
  e o `MediaNotificationService`.
- O CI passou a compilar só para `android-arm` e `android-arm64` (celulares, TV
  box e Fire Stick). Isso evita falhas de build do Cast em x86 e deixa o APK
  menor. Emulador x86_64 não roda mais esta build.

## 3. Testes

`flutter test` cobre agora 10 casos, incluindo: séries do Xtream como container,
M3U caindo na aba correta, cache v2 com séries, montagem da URL de episódio,
rótulo `S01E03` e escolha de `contentType` do Cast.

## 4. Como atualizar no celular

Mesmo procedimento de sempre (`docs/ATUALIZAR_NO_CELULAR.md`): baixar
`app-release.apk` em Actions → última execução → Artifacts → `neoplay-apk` e
instalar por cima. A assinatura é a mesma desde a 1.0.1, então não precisa
desinstalar.

Atenção: se o aparelho for Android 5 (API 21/22), esta versão não instala mais.
