# NEOPLAY — Player de listas IPTV

Aplicativo Flutter que reproduz listas IPTV informadas pelo próprio usuário: **Xtream Codes** (host + usuário + senha) ou **URL M3U/M3U8**. Inclui canais ao vivo, conteúdo sob demanda, EPG curto por canal, favoritos, histórico, busca global e suporte a Android TV.

> Este aplicativo **não fornece, hospeda ou distribui conteúdo**. Todo o conteúdo vem da lista cadastrada pelo usuário final.

## Estrutura do repositório

| Caminho | Descrição |
| --- | --- |
| `app/` | Projeto Flutter (código do aplicativo, Android e iOS) |
| `docs/ESTRUTURA_APP_IPTV.md` | Especificação técnica completa: arquitetura, modelo de dados, integrações, backend, monetização, roadmap e QA |
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

O APK de release é assinado com a chave de debug do Flutter, o que serve para testes e instalação manual. Para publicar em loja, gere uma keystore própria e configure `android/key.properties` conforme a [documentação oficial de assinatura](https://docs.flutter.dev/deployment/android#signing-the-app).

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

## O que já funciona nesta versão

- Cadastro de lista por Xtream Codes com validação de conta (status, validade e conexões) ou por URL M3U/M3U8
- Importação de canais ao vivo e filmes, agrupados pelas categorias da própria lista
- Cache local da lista: o app abre offline com o último conteúdo importado
- Player com ExoPlayer (`video_player`): play/pause, tela cheia com rotação, zapeamento entre canais da categoria, recarregar e mensagens de erro tratadas (403, 404, timeout)
- EPG curto por canal em listas Xtream (`get_short_epg`) com barra de progresso do programa atual
- Favoritos e histórico persistidos, busca global, atualização manual da lista e exclusão de dados
- Manifest preparado para Android TV (leanback launcher e touchscreen opcional)

## Próximos passos previstos na especificação

Séries com temporadas e episódios, guia EPG em grade a partir de XMLTV, múltiplas listas e perfis, controle parental por PIN, backup em nuvem, Chromecast, PiP, temas alternativos e o backend de ativação por Device Key. O detalhamento de cada item está em `docs/ESTRUTURA_APP_IPTV.md`.

## Aviso legal

O projeto é um reprodutor de mídia. O usuário é responsável pelo conteúdo das listas que cadastrar e deve possuir autorização para acessá-lo. Consulte a seção de riscos legais e políticas de loja na especificação técnica antes de distribuir o aplicativo.
