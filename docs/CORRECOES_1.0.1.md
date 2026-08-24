# Correções da versão 1.0.1

Sintoma relatado: ao adicionar a lista, o app travava.

Causa raiz: todo o processamento da lista acontecia na thread da interface (UI thread). Uma lista de IPTV comum tem entre 5 mil e 60 mil itens; o download, o parse, a montagem das URLs e principalmente a serialização para o cache consumiam de vários segundos a alguns minutos com a interface bloqueada. Para o Android isso é um app sem resposta (ANR), e para o usuário é um travamento.

## O que foi corrigido

| # | Problema | Correção |
| --- | --- | --- |
| 1 | Parse do M3U e mapeamento dos streams Xtream rodavam na UI thread | Criado `lib/services/importer.dart`: todo o trabalho roda em *isolate* via `compute`, devolvendo de uma vez o conteúdo pronto e o JSON do cache |
| 2 | Cache da lista inteira (podia passar de 10 MB) era gravado em `SharedPreferences`, que serializa XML de forma síncrona | O cache passou para um arquivo JSON no diretório de suporte do app, gravado de forma assíncrona depois de a tela já estar liberada |
| 3 | Na abertura, o cache era decodificado na UI thread — o app já nascia travado com lista grande | Leitura e decodificação do cache também em isolate |
| 4 | `bootstrap()` era chamado duas vezes (no `main` e na splash), decodificando tudo em dobro | Passou a rodar uma única vez, com guarda `_booted` |
| 5 | Categorias, favoritos e "assistido recentemente" eram recalculados varrendo todos os itens a cada reconstrução de tela | Índices (`_byId`, `_liveByGroup`, `_movieByGroup`, listas de categorias) calculados uma vez por importação; as telas apenas leem |
| 6 | Timeout de 25 s para o catálogo inteiro derrubava a importação em 4G | 90 s para os catálogos, com `Accept-Encoding: gzip`; se o catálogo de filmes falhar, os canais ainda entram |
| 7 | Dois toques em "Testar e conectar" disparavam duas importações simultâneas | Guarda `_busy` no `AppState` |
| 8 | IDs de filme podiam colidir com IDs de canal (o mesmo `stream_id` existe nas duas listas), embaralhando favoritos e histórico | IDs de VOD passaram a ter prefixo `vod_`; duplicados do servidor são descartados |
| 9 | Milhares de logos remotos decodificados em tamanho cheio causavam travadas e estouro de memória | `cacheWidth` nas miniaturas e limite global do cache de imagens (220 itens / 48 MB) |
| 10 | Cada build do CI assinava o APK com uma chave nova, impedindo atualizar por cima | Chave de assinatura fixa em Secrets do repositório e `signingConfig` de release no Gradle |
| 11 | Sem retorno visual durante a importação | Rótulos de progresso por etapa: conectando, lendo categorias, baixando canais, baixando filmes, processando |
| 12 | Erros apareciam como texto cru de exceção | Mensagens tratadas e resumidas, com botão de tentar novamente |

## Migração automática

Quem já usou a 1.0.0 tem um cache grande gravado nas preferências. Na primeira abertura da 1.0.1 essas chaves antigas (`cache_live`, `cache_movies`) são apagadas e o app volta a ler o cache do arquivo novo. Nenhuma ação é necessária, e a lista cadastrada, os favoritos e o histórico são preservados.

## Verificação

- `flutter analyze` — sem nenhum problema (0 erros, 0 avisos, 0 infos)
- `flutter test` — 4 testes da importação passando: M3U, Xtream (com URLs e descarte de duplicados), ida e volta do cache com 500 itens e resposta inválida sem quebrar
- Ambos rodam no CI antes de o APK ser gerado
