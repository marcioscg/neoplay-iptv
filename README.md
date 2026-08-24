# NEOPLAY — Player de listas IPTV

Aplicativo Flutter que reproduz listas IPTV informadas pelo próprio usuário: **Xtream Codes** (host + usuário + senha) ou **URL M3U/M3U8**. Inclui canais ao vivo, conteúdo sob demanda, EPG curto por canal, favoritos, histórico, busca global e suporte a Android TV.

> Este aplicativo **não fornece, hospeda ou distribui conteúdo**. Todo o conteúdo vem da lista cadastrada pelo usuário final.

## Estrutura do repositório

| Caminho | Descrição |
| --- | --- |
| `app/` | Projeto Flutter (código do aplicativo, Android e iOS) |
| `docs/ESTRUTURA_APP_IPTV.md` | Especificação técnica completa: arquitetura, modelo de dados, integrações, backend, monetização, roadmap e QA |
| `docs/ATUALIZAR_NO_CELULAR.md` | Passo a passo para instalar e atualizar o APK no celular ou TV Box |
| `docs/CORRECOES_1.0.1.md` | O que travava na versão 1.0.0 e como foi corrigido |
| `design/mockup/` | Mapa de telas navegável (HTML/CSS estático) |
| `design/exports/NEOPLAY_telas.png` | Imagem única com as 22 telas projetadas (20 mobile + 2 Android TV) |
| `.github/workflows/android.yml` | Pipeline que compila o APK automaticamente |

## Gerar o APK sem instalar nada (recomendado)

O repositório já vem com GitHub Actions configurado:

1. Faça um push na branch `main` (ou abra a aba **Actions** e rode **Build APK** manualmente em *Run workflow*).
2. Aguarde o job terminar (cerca de 5 a 10 minutos na primeira execução).
3. Abra a execução e baixe o artefato **neoplay-apk**. Dentro dele estão:
   - `app-release.apk` — APK universal, serve para qualquer aparelho;
   - `app-arm64-v8a-release.apk`, `app-armeabi-v7a-release.apk`, `app-x86_64-release.apk` — versões menores por arquitetura.
4. Copie o APK para o celular/TV Box e instale habilitando "fontes desconhecidas".

O APK é assinado com uma **chave fixa** guardada nos Secrets do repositório (`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`), o que permite instalar cada versão nova por cima da anterior sem desinstalar e sem perder favoritos. O detalhamento está em `docs/ATUALIZAR_NO_CELULAR.md`.

Para compilar assinado na sua máquina, coloque a keystore em `app/android/app/neoplay-release.jks` e crie `app/android/key.properties`:

```properties
storeFile=neoplay-release.jks
storePassword=SUA_SENHA
keyAlias=neoplay
keyPassword=SUA_SENHA
```

Esses dois arquivos estão no `.gitignore` e nunca devem ser enviados ao repositório. Sem eles, o build cai automaticamente na chave de debug.

## Gerar o APK na sua máquina

Pré-requisitos: [Flutter stable](https://docs.flutter.dev/get-started/install), Android SDK (platform 34+) e JDK 17.

```bash
cd app
flutter pub get
flutter build apk --release
# saída: app/build/app/outputs/flutter-apk/app-release.apk
```

Para rodar em um aparelho conectado por USB:

```bash
cd app
flutter devices
flutter run --release
```

## Arquitetura do código

```
app/lib/
  main.dart                  ponto de entrada, injeção do estado global
  theme.dart                 paleta e tema escuro (destaque #FFC93C)
  models/models.dart         Playlist, MediaItem, MediaCategory, PlaylistContent
  services/
    importer.dart            importação em isolate (parse + cache) — evita travar a UI
    m3u_parser.dart          parser de #EXTINF com atributos tvg-*
    xtream_api.dart          cliente player_api.php (auth, categorias, streams, EPG curto)
    storage.dart             persistência local (lista, favoritos, histórico, cache)
  state/app_state.dart       ChangeNotifier com importação, busca e favoritos
  screens/
    splash_screen.dart       decide entre onboarding e home
    setup_screen.dart        cadastro da lista (Xtream / M3U)
    home_screen.dart         abas Canais / Filmes / Favoritos
    items_screen.dart        lista de canais e grid de filmes
    player_screen.dart       player, controles, zapeamento e EPG
    search_screen.dart       busca global
    settings_screen.dart     configurações e exclusão de dados
  widgets/common.dart        componentes de UI reutilizáveis
```

## Desempenho da importação

A importação de uma lista roda inteira em um *isolate* separado (`app/lib/services/importer.dart`): download, parse, montagem das URLs e serialização do cache. A thread da interface fica livre, então o app mostra o progresso em vez de congelar, mesmo com listas de dezenas de milhares de itens. O cache vai para um arquivo JSON no diretório do app, e não para as preferências. Categorias, favoritos e histórico são indexados uma única vez por importação.

## O que já funciona nesta versão

- Cadastro de lista por Xtream Codes com validação de conta (status, validade e conexões) ou por URL M3U/M3U8
- Importação de canais ao vivo e filmes, agrupados pelas categorias da própria lista
- Cache local da lista: o app abre offline com o último conteúdo importado
- Player com ExoPlayer (`video_player`): play/pause, tela cheia com rotação, zapeamento entre canais da categoria, recarregar e mensagens de erro tratadas (403, 404, timeout)
- EPG curto por canal em listas Xtream (`get_short_epg`) com barra de progresso do programa atual
- Favoritos e histórico persistidos, busca global, atualização manual da lista e exclusão de dados
- Manifest preparado para Android TV (leanback launcher e touchscreen opcional)
- Testes automatizados da importação (`app/test/importer_test.dart`), executados no CI antes de gerar o APK

## Próximos passos previstos na especificação

Séries com temporadas e episódios, guia EPG em grade a partir de XMLTV, múltiplas listas e perfis, controle parental por PIN, backup em nuvem, Chromecast, PiP, temas alternativos e o backend de ativação por Device Key. O detalhamento de cada item está em `docs/ESTRUTURA_APP_IPTV.md`.

## Aviso legal

O projeto é um reprodutor de mídia. O usuário é responsável pelo conteúdo das listas que cadastrar e deve possuir autorização para acessá-lo. Consulte a seção de riscos legais e políticas de loja na especificação técnica antes de distribuir o aplicativo.
