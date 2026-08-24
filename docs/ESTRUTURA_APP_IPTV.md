# Estrutura técnica — App player IPTV multiplataforma

**Objetivo:** especificar um player de listas IPTV no estilo IBO Player, Televizo e XCIPTV para Android (celular e tablet), Android TV/Fire TV e, em fase futura, iOS. Este produto é um **player/organizador**: não embute, vende, indica nem hospeda canais, filmes, séries ou listas. Cada usuário adiciona uma fonte própria por URL M3U/M3U8, arquivo local M3U/M3U8 ou credenciais Xtream Codes, podendo associar um EPG XMLTV.

> **Regra de produto e compliance:** exibir no onboarding, na página de adicionar fonte e na loja: “Este aplicativo não fornece conteúdo, canais, listas ou credenciais. O usuário é responsável por possuir os direitos e autorizações para as fontes adicionadas.” Não incluir lista de demonstração com conteúdo de terceiros; para QA, usar apenas streams abertas/licenciadas e curtas.

## 1. Visão geral e proposta de valor

O app importa fontes, normaliza metadados, navega bem em TV/celular e recupera fluxos instáveis. Entrega TV ao vivo, VOD, séries, EPG, favoritos, continuidade e controle parental.

**Públicos:** usuário final que já possui uma fonte lícita; revendedor/operador que entrega acesso autorizado ao cliente; e administrador da empresa que gerencia ativações, suporte e planos. O painel web nunca deve se apresentar como fornecedor de conteúdo: ele administra dispositivos, licenças, configurações e, se habilitado, referências de listas cadastradas pelo próprio cliente.

**Princípios:** catálogo local após sync; origem do usuário como verdade; favoritos/ocultações como sobreposição local; erros classificados e recuperáveis; fluxo essencial por D-pad em até duas decisões; e detecção em tempo de execução para variações de stream, codec, DRM, catchup e Xtream.

## 2. Stack recomendada

### Recomendação principal: Flutter + Dart

| Camada | Escolha | Papel |
|---|---|---|
| UI | Flutter, Material 3 e widgets próprios para TV | Uma base para Android mobile, Android TV/Fire TV e futuro iOS; layouts responsivos por breakpoint/controle de foco. |
| Player | `media_kit`/`media_kit_video` como fachada multiplataforma; implementação Android via Media3/ExoPlayer quando necessário | Abstrair player e manter acesso a recursos Android específicos por platform channel. O pacote `media_kit_video` declara suporte a Android e iOS, além de desktop/web, e é uma implementação nativa para vídeo do ecossistema media_kit ([pub.dev](https://pub.dev/packages/media_kit_video)). |
| Estado | Riverpod (`Notifier`/`AsyncNotifier`) | Estado testável, DI explícita, cache por provider e boa separação de UI. |
| Rede | Dio + interceptors | Timeouts, cancelamento, cabeçalhos por playlist (`User-Agent`), retry controlado, download progressivo. |
| Persistência | Isar **ou** Drift/sqflite | Isar para leitura rápida de objetos e índices; Drift/SQLite quando consultas EPG relacionais e paginação SQL forem prioridade. |
| Imagens | `cached_network_image` + cache em disco limitado | Logos/capas com placeholder, TTL e limpeza LRU. |
| Segredos | `flutter_secure_storage` + Android Keystore / iOS Keychain | Credenciais e tokens, nunca em texto claro no banco. |
| Observabilidade | Sentry/Crashlytics opcional, analytics com opt-in | Crash, tempo de importação, erro por classe, sem registrar URL ou senha da lista. |

**Por que:** Flutter reduz custo de manutenção de interfaces e domínio compartilhados. Use uma interface `PlayerPort`; `MediaKitPlayerAdapter` atende o caso comum e `AndroidMedia3PlayerAdapter` libera configurações que dependem de Media3, como seleção de decoder, `LoadControl`, track selector e integração robusta com PiP/Cast. Media3 suporta HLS com MPEG-TS, fMP4/CMAF, WebVTT e reprodução ao vivo; DASH também é suportado, condicionado ao formato/codec do manifesto ([HLS no Android Developers](https://developer.android.com/media/media3/exoplayer/hls), [DASH no Android Developers](https://developer.android.com/media/media3/exoplayer/dash)).

**Alternativa nativa:** Kotlin + Jetpack Compose/Compose for TV + Media3/ExoPlayer. É a melhor escolha se Android TV/Fire TV for 80%+ do negócio, se haverá Cast/DRM/decoders muito customizados, ou se a equipe já é Android. Prós: acesso direto e previsível às APIs do sistema e melhor depuração do player. Contras: iOS exigirá Swift/AVPlayer e duplicação de domínio/telas; custo inicial e de manutenção maior.

**React Native:** é viável com `react-native-video` e módulos nativos, mas não é a primeira escolha aqui. Prós: equipe JavaScript/TypeScript existente, ecossistema de UI e possível compartilhamento com web. Contras: integração de player, foco de Android TV, PiP, Cast e diagnósticos de codecs tende a passar por bridges/módulos nativos; portanto, perde a principal vantagem justamente no componente de maior risco. Escolher React Native apenas com experiência comprovada da equipe em TV e vídeo nativo.

## 3. Arquitetura em camadas

Adotar Clean Architecture pragmática, por *feature*. Dependências apontam para dentro: `presentation → domain ← data`. A presentation jamais parseia M3U ou chama Dio; o domain não conhece Flutter, HTTP, Isar nem JSON.

- **presentation:** páginas, widgets, view models/providers Riverpod, rotas, tema, focus e adaptações TV/mobile.
- **domain:** entidades imutáveis, casos de uso (`ImportPlaylist`, `SyncEpg`, `PlayItem`, `SearchCatalog`, `ValidatePin`), regras de negócio e contratos de repositório/player.
- **data:** DTOs, parsers M3U/XMLTV, cliente Xtream/Dio, banco, cache, mapeadores e implementações dos contratos.
- **core:** erros tipados, `Result`, logger sanitizado, relógio, URL normalizer, DI, constantes e serviços de plataforma.

```text
lib/
├── app/                 # bootstrap, router, DI, tema, ambientes
├── core/
│   ├── error/           # AppFailure e códigos recuperáveis
│   ├── network/         # DioFactory, interceptors, timeout/retry
│   ├── security/        # secure storage, crypto envelope
│   ├── utils/           # normalização, clock, debounce
│   └── platform/        # PiP, Cast, device key, TV focus bridge
├── features/
│   ├── playlists/{presentation,domain,data}/
│   ├── live/{presentation,domain,data}/
│   ├── vod/{presentation,domain,data}/
│   ├── series/{presentation,domain,data}/
│   ├── epg/{presentation,domain,data}/
│   ├── player/{presentation,domain,data}/
│   ├── search/{presentation,domain,data}/
│   ├── library/{presentation,domain,data}/
│   ├── settings/{presentation,domain,data}/
│   ├── parental/{presentation,domain,data}/
│   └── premium/{presentation,domain,data}/
├── shared/              # UI reutilizável: cards, skeletons, empty/error
└── main.dart
assets/                  # fontes, ícones, imagens próprias; sem conteúdo IPTV
```

Cada repositório expõe `Stream`/paginação local quando aplicável. Uma sincronização escreve em transação por lote e emite somente o estado consolidado; isso evita reconstruir a Home milhares de vezes.

## 4. Modelo de dados completo

Use UUID v7 como chave; datas são UTC; IDs de origem permanecem `String`. `*` indica índice.

| Entidade | Campos e tipos |
|---|---|
| **Playlist** | `id:String`, `profileId:String*`, `name:String`, `type:enum(m3uUrl,m3uFile,xtream)`, `baseUrl:String?`, `m3uUrl:String?`, `localPath:String?`, `usernameEncrypted:String?`, `passwordEncrypted:String?`, `userAgent:String?`, `epgUrl:String?`, `status:enum(active,error,refreshing)`, `lastSyncAt:DateTime?`, `lastEpgSyncAt:DateTime?`, `lastError:String?`, `contentHash:String?`, `createdAt`, `updatedAt`. |
| **Perfil** | `id:String`, `name:String`, `avatarColor:Int`, `isChild:bool`, `pinRequired:bool`, `language:String`, `playlistIds:List<String>`, `createdAt`, `updatedAt`. |
| **Canal** | `id:String`, `playlistId:String*`, `sourceId:String*`, `name:String*`, `normalizedName:String*`, `streamUrl:String`, `logoUrl:String?`, `categoryId:String*`, `tvgId:String?*`, `tvgName:String?`, `userAgent:String?`, `catchupMode:String?`, `catchupDays:int?`, `isAdult:bool`, `isHidden:bool`, `sortOrder:int`, `lastSeenAt:DateTime?`, `rawAttrsJson:String?`. Índice composto `(playlistId, categoryId, sortOrder)` e único lógico `(playlistId, sourceId)`. |
| **Categoria** | `id:String`, `playlistId:String*`, `kind:enum(live,vod,series)`, `sourceId:String`, `name:String*`, `parentId:String?`, `sortOrder:int`, `isAdult:bool`, `isHidden:bool`. |
| **Filme/VOD** | `id:String`, `playlistId:String*`, `sourceId:String*`, `name:String*`, `streamUrl:String`, `containerExtension:String?`, `categoryId:String*`, `posterUrl:String?`, `backdropUrl:String?`, `plot:String?`, `year:int?`, `rating:double?`, `durationSec:int?`, `tmdbId:int?`, `isAdult:bool`, `addedAt:DateTime?`, `rawJson:String?`. |
| **Série** | `id:String`, `playlistId:String*`, `sourceId:String*`, `name:String*`, `categoryId:String*`, `posterUrl:String?`, `backdropUrl:String?`, `plot:String?`, `genre:String?`, `rating:double?`, `tmdbId:int?`, `isAdult:bool`, `lastSyncAt:DateTime?`. |
| **Temporada** | `id:String`, `seriesId:String*`, `sourceId:String?`, `number:int*`, `name:String?`, `posterUrl:String?`, `sortOrder:int`. Único `(seriesId, number)`. |
| **Episódio** | `id:String`, `seriesId:String*`, `seasonId:String*`, `sourceId:String*`, `title:String`, `streamUrl:String`, `containerExtension:String?`, `episodeNumber:int?`, `plot:String?`, `durationSec:int?`, `posterUrl:String?`, `airDate:DateTime?`, `sortOrder:int`, `rawJson:String?`. |
| **Favorito** | `id:String`, `profileId:String*`, `contentType:enum(channel,movie,series)`, `contentId:String*`, `createdAt:DateTime`. Único `(profileId, contentType, contentId)`. |
| **HistoricoReproducao** | `id:String`, `profileId:String*`, `contentType:enum(live,movie,episode)`, `contentId:String*`, `positionMs:int`, `durationMs:int?`, `completed:bool`, `watchedAt:DateTime*`, `lastStreamUrlHash:String?`. Para live, guardar canal e momento, não retomar posição comum. |
| **ProgramaEPG** | `id:String`, `playlistId:String*`, `channelTvgId:String*`, `channelId:String?`, `startAt:DateTime*`, `endAt:DateTime*`, `title:String`, `subtitle:String?`, `description:String?`, `category:String?`, `iconUrl:String?`, `episodeNum:String?`, `isNew:bool?`, `rawXmlHash:String?`. Índice composto `(playlistId, channelTvgId, startAt)`; apagar janelas expiradas. |
| **Configuracoes** | `profileId:String` (PK), `theme:enum(system,dark,light,custom)`, `primaryColor:Int`, `locale:String`, `defaultAspect:enum(contain,cover,fill,16_9,4_3)`, `decoder:enum(auto,hardware,software)`, `minBufferMs:int`, `maxBufferMs:int`, `autoPlayNext:bool`, `pipEnabled:bool`, `parentalEnabled:bool`, `epgDays:int`, `analyticsConsent:bool`, `updatedAt:DateTime`. |
| **ControleParental** | `profileId:String` (PK), `pinHash:String`, `pinSalt:String`, `failedAttempts:int`, `lockedUntil:DateTime?`, `adultCategoryIds:List<String>`, `blockedContentIds:List<String>`, `requirePinOnStart:bool`, `updatedAt:DateTime`. Nunca armazenar PIN reversível. |

Limite `rawJson`/`rawAttrsJson` e elimine segredos; usar `ExternalIdMap` se uma fonte reciclar IDs.

## 5. Integrações e pipeline de ingestão

### M3U/M3U8

1. Baixar para arquivo temporário com timeout, limite e `User-Agent` da fonte.
2. Ler em *stream*, linha a linha; para cada `#EXTINF`, associar a próxima URL e extrair `tvg-id`, `tvg-name`, `tvg-logo`, `group-title`, `catchup`, `catchup-days`, `user-agent` e atributos desconhecidos.
3. Normalizar URL/nome; mapear EPG por `tvg-id`, depois `tvg-name` e, por último, nome com confiança alta.
4. Classificar MIME/extensão e fazer upsert de 250–1.000 itens por transação.

### Xtream Codes (interoperabilidade de facto)

Trate Xtream como integração de compatibilidade, não como especificação formal: servidores podem divergir. Comece validando `GET {host}/player_api.php?username={u}&password={p}`. As chamadas usuais incluem:

```text
player_api.php?username={u}&password={p}&action=get_live_categories
player_api.php?username={u}&password={p}&action=get_live_streams[&category_id={id}]
player_api.php?username={u}&password={p}&action=get_vod_categories
player_api.php?username={u}&password={p}&action=get_vod_streams[&category_id={id}]
player_api.php?username={u}&password={p}&action=get_vod_info&vod_id={id}
player_api.php?username={u}&password={p}&action=get_series[&category_id={id}]
player_api.php?username={u}&password={p}&action=get_series_info&series_id={id}
player_api.php?username={u}&password={p}&action=get_short_epg&stream_id={id}
{host}/xmltv.php?username={u}&password={p}
```

A nomenclatura acima é documentada por implementações comunitárias do protocolo ([Fermata/Xtream discussion](https://github.com/AndreyPavlenko/Fermata/discussions/434)); implemente feature flags e logs sanitizados para variações. Forme URLs apenas após o retorno da API: live normalmente `{host}/live/{u}/{p}/{streamId}.{ts|m3u8}`, filme `{host}/movie/{u}/{p}/{streamId}.{ext}` e episódio `{host}/series/{u}/{p}/{episodeId}.{ext}`. Faça URL-encoding de usuário/senha nos query parameters, preserve apenas o host validado e nunca registre essas URLs completas.

Mapeie `stream_icon`, `epg_channel_id`, `category_id`, `stream_id`, `container_extension`, `added`, `rating`, `plot`, `backdrop_path` e dados de séries. Para `get_series_info`, substituir temporadas/episódios da série em transação; para catálogo grande, buscar detalhes apenas quando o usuário abrir a série.

### XMLTV e TMDB

XMLTV usa registros `channel` e `programme`, sendo que `programme` carrega atributos de transmissão como `start`, `stop` e `channel` ([XMLTV Format](https://wiki.xmltv.org/index.php/XMLTVFormat)). Use parser SAX/streaming; extraia `channel/@id`, `display-name`, `icon`, e em `programme`: `start`, `stop`, `title`, `sub-title`, `desc`, `category`, `icon`, `episode-num`, `previously-shown`.

Converta `YYYYMMDDHHmmss ±HHMM` para UTC preservando o offset; sem offset, use o fuso configurado e marque baixa confiança. Manter 3–7 dias futuros/1 passado, deduplicar por `(tvgId,startAt,title)`, usar hash/ETag e exibir “Sem guia” quando necessário.

TMDB é opcional e desligado por padrão. Enriquecer apenas IDs/conferências confiáveis, guardar idioma/origem e respeitar os termos; metadado não prova autorização da stream.

## 6. Telas, conteúdo e rotas

Rotas declarativas (GoRouter) e parâmetros por ID, nunca objetos gigantes no `extra`:

| Rota | Tela e conteúdo | Navegação |
|---|---|---|
| `/splash` | Inicializa banco, migra schema, lê perfil/licença e restaura estado. | Sem playlist → `/onboarding`; com playlist → `/home/live`. |
| `/onboarding` e `/playlists/add` | Aviso de responsabilidade, escolher URL/arquivo/Xtream, nome, User-Agent, EPG opcional, validar e importar. | Sucesso → `/playlists`; primeira fonte → `/home/live`. |
| `/playlists` | Gerenciar playlists: status, última sync, editar, atualizar, duplicar, remover com confirmação e erro detalhado. | Adicionar → `/playlists/add`; tocar → troca de fonte/Home. |
| `/home/:tab` | Abas **Canais**, **Filmes**, **Séries**; hero com último item, atalhos Favoritos/Busca/Guia e categorias. | Canais → `/live/categories`; filmes/séries → grids. |
| `/live/categories` | Categorias de canais, contagem, filtro “ocultar adultos”. | Categoria → `/live/category/:categoryId`. |
| `/live/category/:categoryId` | Lista virtualizada: logo, nome, favorito, programa agora/próximo e progresso EPG. | Tocar → `/player/live/:channelId`; Guia → `/epg`. |
| `/player/live/:channelId` | Vídeo, nome, resolução/estado, EPG atual/próximo, zapping anterior/próximo, favorito, faixa, legenda, aspect, PiP e controles auto-hide. | Guia → `/epg?channelId=`; back retorna à origem. |
| `/epg` | Grade temporal horizontal + canais vertical, agora, filtro de categoria/data, detalhes, tocar programa/canal e catchup quando disponível. | Programa → player ou detalhe de catchup. |
| `/movies` | Grid paginado de filmes, categorias, ordenação, filtros e busca local. | Card → `/movie/:movieId`. |
| `/movie/:movieId` | Capa, backdrop, sinopse, ano, duração, gêneros, progresso, favorito e “Assistir”. | Assistir → `/player/vod/movie/:movieId`. |
| `/series` | Grid de séries, filtros e busca. | Card → `/series/:seriesId`. |
| `/series/:seriesId` | Metadados, temporadas em seletor, episódios, progresso e botão retomar. Buscar `get_series_info` sob demanda. | Episódio → `/player/vod/episode/:episodeId`. |
| `/player/vod/:kind/:id` | Player VOD, seek, 10s, velocidade, capítulos se disponíveis, áudio, legendas, aspecto, próximo episódio e salvar posição. | Final → próximo episódio/voltar detalhe. |
| `/search` | Busca global com debounce em canais, filmes, séries e EPG; filtros por tipo. | Resultado → detalhe/player. |
| `/favorites` | Favoritos do perfil em seções por tipo, reorder local opcional. | Item → destino correspondente. |
| `/recent` | “Continuar assistindo” e assistidos recentemente; limpar item/tudo. | Item → player com posição. |
| `/settings` | Perfil, playlist, aparência, player, EPG, dados, privacidade, premium e sobre. | Subrotas abaixo. |
| `/settings/player` | Buffer, decoder HW/SW/auto, aspect, áudio, legenda, tamanho de texto, autoplay, PiP. | Aplicar; alertar que decoder pode exigir reinício do player. |
| `/settings/backup` | Exportar backup local cifrado, importar com pré-visualização, conectar nuvem e sincronizar manual. | Nunca exportar senha sem confirmação explícita. |
| `/settings/theme` e `/settings/language` | Tema claro/escuro/sistema/cor e idioma/locale. | Retorna configurações. |
| `/parental` | Criar/alterar PIN, bloquear categorias/itens, perfil infantil, bloqueio por tentativas. | PIN → conteúdo desbloqueado temporariamente. |
| `/premium` | Benefícios, device key, ativar código, compra/restauração de assinatura. | Web checkout ou billing nativo conforme plataforma. |
| `/about` e `/help` | Versão, licenças open source, política de privacidade, termos, disclaimer, diagnóstico copiável e suporte. | Links externos seguros. |

## 7. Funcionalidades do player

`PlayerPort`: `open`, `play`, `pause`, `seek`, tracks, legenda, aspecto, decoder, buffer, PiP, cast, `dispose` e streams de posição/estado/erro. Manter um player ativo por perfil.

- Protocolos: HLS, MPEG-TS/progressive e MPEG-DASH, com MIME explícito quando extensão estiver ausente. Media3 documenta suporte a HLS e DASH, mas codec, container e proteção ainda dependem do dispositivo ([formatos suportados](https://developer.android.com/media/media3/exoplayer/supported-formats)).
- **Reconexão:** 2–3 tentativas com jitter (1, 2, 5 s) só para erro transitório; cancelar ao trocar canal e não repetir em 401/403, URL inválida ou codec ausente.
- **Buffer:** perfis 1–5 s, 3–15 s e 8–30 s, respeitando memória; valores avançados em modo técnico.
- **Áudio e legendas:** enumerar faixas, preservar escolha por playlist quando possível, suportar WebVTT/SRT externos via URL/arquivo e desativar sempre disponível. A compatibilidade final depende do container/stream.
- **Aspect/zoom:** contain, cover/zoom, stretch, 16:9 e 4:3; aplicar transformação apenas visual, sem reencodar.
- **Timeshift/catchup:** habilitar somente se a lista/API declarar `catchup` e houver janela/URL válida; gerar URL a partir da convenção do provedor isolada em `CatchupUrlBuilder`, nunca assumir suporte universal. Não chamar uma transmissão ao vivo de DVR se a fonte não fornece segmentos passados.
- **PiP:** Android 8+ quando permitido pelo dispositivo; ao entrar, esconder UI pesada e manter serviço/foreground conforme as regras do sistema. **Chromecast:** implementar com Google Cast SDK em Android e manter o receiver/URLs apenas para fontes autorizadas; não é simplesmente espelhar o `Player` local.
- **Decoder:** `auto` por padrão; hardware primeiro, fallback software somente quando Media3/engine permitir e após erro de decoder. Exibir modelo do dispositivo, codec e erro, mas não dados da lista.

## 8. Android TV e Fire TV

Criar 10-foot UI com cards grandes, contraste e foco inequívoco. Cada tela tem `FocusNode`, ordem direcional explícita, restauração ao voltar e fallback se item sumir. OK abre/toca; Back fecha overlay; setas movem abas/filtros; no player, cima/baixo faz zapping. Na grade EPG, horizontal altera hora e vertical altera canal.
- Declarar `android:isLeanback="true"`, banner `320x180` sem texto ilegível, ícone TV e atividade launcher própria. Testar Fire TV separadamente: não assumir Google Play Services nem Google Cast; ocultar recursos indisponíveis.
- Integrar recomendações/“continuar assistindo” por canais do sistema somente se o lançamento justificar a manutenção e todas as fontes forem permitidas. A recomendação deve conter apenas metadados locais mínimos e respeitar perfil/PIN; nunca publicar nome de canal adulto ou URL.

## 9. Performance e escala

Meta: Home <2 s em catálogo quente e 10.000+ canais sem ANR. Usar listas/grid virtualizados, paginação e placeholders; parsing/normalização/gravação rodam em `Isolate.run` com progresso por estágio.
- Banco: índices descritos acima, busca por nome normalizado/tokenizado (FTS5 em SQLite/Drift se necessário), consultas paginadas e projeções leves em vez de carregar `rawJson`.
- EPG: cache por playlist/dia/canal, janela móvel, hash+ETag, TTL e limpeza de programas expirados. O item de canal busca apenas “agora” e “próximo” em lote, não uma query por card.
- Imagens: dimensões de decode próximas ao card, cache de disco com limite (ex. 200 MB), LRU e cancelamento quando card sai da viewport. Validar `Content-Type`/tamanho e usar placeholder.
- Rede: máximo de conexões/sync paralelo configurável, timeout e cancel tokens; importação em foreground com notificação de progresso quando longa. Medir tempo de sync, linhas/s, memória, frame time e taxa de falhas por tipo.

## 10. Monetização e implicações

| Modelo | Oferta | Exigência |
|---|---|---|
| Freemium | 1 playlist, recursos básicos; premium libera múltiplas fontes, backup nuvem, tema, perfis ou suporte. | Entitlements locais + validação de licença. Não bloquear acesso já pago offline de forma agressiva. |
| Vitalícia por dispositivo | Chave vinculada a `deviceId`/device key, semelhante ao modelo de ativação de players. | Serviço de ativação, painel de revenda, política de troca de dispositivo, antiabuso e suporte. |
| Assinatura in-app | Mensal/anual por Google Play Billing (e StoreKit no iOS). | Backend valida recibos, armazena estado de entitlement e trata renovação/cancelamento. |

Não vender listas/canais nem associar preço a conteúdo. Vincular licença a chave aleatória de instalação, não MAC; permitir poucas trocas assistidas com auditoria.

## 11. Backend mínimo necessário

**Stack:** NestJS/Node + Postgres + Redis/BullMQ, ou Laravel + Postgres + Redis/Queue; migrations, OpenAPI e storage S3 para backup cifrado. Tabelas: `users`, `devices`, `licenses`, `plans`, `resellers`, `activations`, `subscriptions`, `playlist_references`, `backup_manifests`, `audit_events` e analytics agregados.

| Método e endpoint | Autorização | Comportamento |
|---|---|---|
| `POST /v1/devices/register` | instalação/device key | Registra instalação, devolve desafio/ID opaco; rate limit. |
| `POST /v1/licenses/activate` | código + device | Consome/associa licença, retorna JWT curto e entitlement assinado. |
| `POST /v1/licenses/validate` | bearer + device | Valida status, plano, expiração e lista de capacidades; cache local por período de carência. |
| `POST /v1/billing/google/verify` | usuário | Recebe purchase token, verifica server-to-server e atualiza entitlement idempotentemente. |
| `GET/POST/DELETE /v1/me/playlist-references` | usuário | Salva referência de lista cifrada, jamais repassa catálogo para terceiros; opcional por consentimento. |
| `POST /v1/backups` / `GET /v1/backups/:id` | usuário | Upload/download pré-cifrado, metadados, versionamento e limite. |
| `POST /v1/analytics/events` | opt-in | Eventos pseudonimizados e agregáveis; schema allowlist. |
| `POST /v1/reseller/activations` | papel revendedor | Cria ativação dentro de créditos, com auditoria. |

Painel: MFA, licenças, saldo, logs, troca e exportação LGPD; referência de lista mostra só domínio mascarado, nunca senha.

## 12. Segurança e privacidade

- Criptografar `username`, `password`, URL contendo credenciais e backup com chave aleatória por instalação guardada no Keystore/Keychain; cifrar conteúdo com AES-GCM e versionar o envelope. Não usar “base64” como proteção.
- Redigir logs: remover query string, cabeçalhos `Authorization`, `Cookie`, `username`, `password`, token e URLs assinadas. Em crash report, enviar somente host hash, código HTTP e classe do erro.
- TLS obrigatório para API própria; permitir `http` de fonte do usuário apenas com alerta explícito e sem misturar credenciais do app. Validar esquema, host e redirecionamentos; bloquear `file://`, loopback e redes privadas em serviços backend para evitar SSRF.
- PIN: hash com Argon2id/PBKDF2+safeguard salt, rate limit e bloqueio temporário. Controle parental é barreira de produto, não mecanismo de DRM.
- LGPD: URLs/credenciais, identificadores de dispositivo e analytics podem ser dados pessoais ou associados a pessoa. Definir finalidade, base legal, retenção, encarregado/canal de direitos, consentimento para analytics/backup e exclusão/exportação. A LGPD regula tratamento de dados pessoais também em meios digitais ([Lei nº 13.709/2018](https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm)). Publicar política de privacidade clara antes da coleta e aplicar minimização por padrão.

## 13. Políticas de loja e riscos legais no Brasil

Esta seção é orientação de produto; obter parecer de advogado especializado antes da publicação, principalmente se houver revenda, catálogo, publicidade ou qualquer operação que transcenda um player neutro.

1. **Google Play:** não existe garantia de aprovação por usar a palavra “IPTV” ou por alegar neutralidade. A política proíbe apps/contas que infrinjam direitos autorais ou induzam infração, e a Google pode exigir prova de licença para material de terceiros ([Política de Propriedade Intelectual do Google Play](https://support.google.com/googleplay/android-developer/answer/9888072?hl=en)). Reduzir risco: nenhum conteúdo/lista pré-carregado; não usar logos/capas/canais de terceiros na ficha; sem alegação “todos os canais”; mecanismo de denúncia/contato; termos, privacy policy e disclaimer coerentes; documentação das licenças de quaisquer assets de marketing.
2. **APK/sideload:** distribuição direta pode atender Android TV/Fire TV fora da Play, mas não elimina obrigações de direitos autorais, proteção de dados, segurança, termos das plataformas ou responsabilidade comercial. Assinar APK/AAB, publicar hash, instruções de atualização, política de revogação e canal de suporte; não instruir o usuário a burlar proteções de loja.
3. **Direito autoral:** a Lei nº 9.610/98 regula direitos autorais e conexos e inclui comunicação ao público entre seus conceitos ([texto legal no Planalto](https://www.planalto.gov.br/ccivil_03/leis/l9610.htm)). Um player neutro diminui exposição por não distribuir obra, mas não torna lícito conteúdo sem autorização nem neutraliza fatos como promoção, curadoria, hospedagem, suporte orientado a pirataria ou revenda de acesso. Criar processo de notice-and-takedown para qualquer conteúdo, imagem, lista ou metadado hospedado/controlado pela empresa.
4. **ECAD e ANCINE:** se a empresa efetivamente disponibilizar/transmitir programação musical/audiovisual ao público, o risco regulatório muda substancialmente. O ECAD afirma que uso de obras musicais/fonogramas em aplicativos e streaming caracteriza execução pública e atribui a responsabilidade a quem disponibiliza/transmite ([ECAD — serviços digitais](https://www4.ecad.org.br/servicos-digitais-informacoes-gerais/)). A ANCINE já tratou a regulação de vídeo sob demanda como tema próprio e recomenda legislação específica para estabilidade jurídica ([ANCINE](https://www.gov.br/ancine/pt-br/assuntos/noticias/ancine-faz-recomendacoes-para-regulacao-do-video-sob-demanda)). Para o player sem catálogo/stream próprio, não declarar que ECAD/ANCINE “não se aplicam”; avaliar caso a caso com assessoria jurídica.

## 14. Roadmap e esforço

Estimativas para 1 dev Flutter pleno/sênior + 1 QA parcial; integrações de billing, Cast, painel e TV podem exigir especialistas. Não incluem negociação de direitos de conteúdo, que não faz parte deste produto.

| Fase | Prazo estimado | Escopo e critérios de aceite |
|---|---:|---|
| Descoberta e fundação | 1 semana | UX flows TV/mobile, arquitetura, schema, CI/CD, design system, política/disclaimer e streams licenciadas de teste. |
| **MVP** | **6–8 semanas** | Android mobile + Android TV básico; adicionar M3U URL/arquivo e Xtream; parser em background; canais/categorias; EPG XMLTV; player HLS/TS básico, favoritos, histórico, busca, settings essenciais, PIN local, logs sanitizados e QA em 3–5 dispositivos. Sem backend obrigatório, Cast, nuvem ou billing. |
| **v1 comercial** | 4–6 semanas | Painel/API de licenças, premium/billing, backup cifrado, filmes/séries/episódios completos, perfil, Fire TV, decoder/buffer avançado, erros diagnósticos, analytics opt-in e hardening LGPD. |
| **v2** | 6–10 semanas | iOS, Cast, PiP refinado, catchup por provedores suportados, recomendações TV, nuvem multi-dispositivo, TMDB opt-in, acessibilidade ampla e testes de carga 10k+ canais. |

Planejar sprints de 1–2 semanas com demo em TV real. Riscar cedo: autenticação Xtream de provedores de teste autorizados, fontes de EPG grandes, codecs em Fire TV e estado de foco em grids.

## 15. Checklist de QA pré-lançamento

### Importação e dados

- [ ] M3U URL/arquivo e Xtream validam/cancelam e exibem erro HTTP/DNS/credencial; parser preserva atributos relevantes.
- [ ] 10.000+ canais não bloqueiam/não duplicam e preservam favoritos/histórico; XMLTV com/sem offset exibe horário correto.
- [ ] Remover fonte limpa dados associados com confirmação; backup/restauração migram versão.

### Player

- [ ] HLS, TS, DASH e VOD licenciados de teste; troca rápida de canal; erro 401/403/404/timeout/codec é classificado.
- [ ] Buffer, HW/SW/auto, aspect, áudio, legendas externas, reconexão, salvar posição e próximo episódio funcionam ou ficam indisponíveis com motivo claro.
- [ ] PiP, áudio em background e Cast são testados apenas nos dispositivos/versões elegíveis; não há vazamento de player ao sair/trocar perfil.
- [ ] Não há URL de stream, senha ou token em logs, tela de erro, analytics, clipboard ou crash reports.

### TV, acessibilidade e qualidade

- [ ] Fluxo completo por D-pad em Android TV e Fire TV: onboarding, importação, Home, busca, EPG, player, PIN e settings.
- [ ] Foco nunca some, não cai atrás de modal e retorna ao card correto; Back tem comportamento consistente.
- [ ] Layout em celular, tablet, 1080p e 4K; contraste, leitor de tela, tamanho de texto e estados vazios/erro carregando.
- [ ] Testes unitários para parsers/mapeadores/URL builder, integração para banco/repos, widget para fluxos críticos e teste manual de devices reais.

### Segurança, operação e loja

- [ ] Segredos cifrados, TLS para API própria, rate limit e autenticação/MFA do painel; teste de restauração e rotação de chave.
- [ ] Política de privacidade, termos, disclaimer de conteúdo do usuário, consentimento analytics e processo de direitos/LGPD revisados.
- [ ] Ficha da Play sem conteúdo de terceiros não licenciado, sem promessa de canais e com screenshots próprios; APK/AAB assinado, versionado e com rollback.
- [ ] Dashboards de crash, tempo de importação, falhas do player e ativações monitorados; runbook de incidente e suporte prontos.

---

## Decisões para iniciar o desenvolvimento

1. Aprovar Flutter + Riverpod + Drift/SQLite (EPG/busca SQL) ou Isar (objetos/simplicidade), mantendo repositórios abstratos.
2. Implementar Media3 atrás de `PlayerPort` no Android e usar media_kit onde agregar valor no iOS.
3. Lançar apenas como player de fontes do usuário, sem catálogo próprio, e validar estratégia jurídica/loja e matriz de dispositivos antes do sprint 1.
