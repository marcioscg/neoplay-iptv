# MIAU NET 1.0.3 — Login, painel de controle e player melhorado

Versão: `1.0.3 (versionCode 5)`

## 1. Marca

O app passou a se chamar **MIAU NET**. Logo novo: um gatinho estilizado
(`CatMark`, desenhado em código) no lugar do antigo losango. Ícone do Android
virou um adaptive icon com o mesmo gato sobre o amarelo da marca.

## 2. Login e conta master

- Toda entrada agora passa por uma **tela de login** (e-mail + senha) com opção
  **Manter conectado**. O PIN fixo 1234 da versão anterior saiu.
- A conta **master** (`marcioscg@hotmail.com`) abre direto o **painel de
  controle**. No painel há o botão *Usar como aplicativo*, que dá ao master
  acesso a todas as funções de um usuário comum.
- Contas comuns entram no app já com a lista M3U que o master cadastrou para
  elas — não veem a tela de cadastrar lista.

## 3. Painel de controle

- **Contas:** criar/editar/excluir acessos com nome, e-mail, senha, **lista
  M3U/M3U8**, plano (mensal a vitalício) e status (ativo/bloqueado). A validade
  é calculada a partir do plano.
- **Central de uso:** quem assiste mais, divisão por tipo de conteúdo (canais,
  filmes, séries), categorias mais acessadas e os últimos acessos com usuário e
  horário. Os eventos são gravados quando alguém abre um conteúdo.

> **Local por enquanto.** Contas e estatísticas ficam **neste aparelho**
> (`SharedPreferences`), atrás de uma interface `AccountsRepository`. Para
> cadastrar a lista no celular de outra pessoa e ver o uso dela à distância é
> preciso um backend — o plano é ligar o Firebase na 1.0.4 implementando a
> mesma interface, sem mexer nas telas.

## 4. Player

- **Controles em tela cheia:** antes só havia o botão de sair. Agora há
  play/pause, ±10s, episódio anterior/próximo, barra de progresso, velocidade,
  qualidade e aspecto, com auto-ocultar.
- **±10s:** por botão e por **duplo toque** — lado direito avança 10s, lado
  esquerdo retrocede 10s, com indicador na tela.
- **Velocidade:** 0,5x a 2,0x.
- **Qualidade:** quando o canal/filme é HLS com várias faixas, o app lê o
  *master playlist* e deixa escolher a resolução (ou "Automática"). Em MP4 não
  há troca de faixa e o menu não aparece.
- **Próximo episódio automático:** ao terminar um episódio ou filme com lista de
  irmãos, o player já abre o próximo sem fechar a tela. Botão *Próximo
  episódio* também no painel de controles.

## 5. Controle parental (conteúdo adulto)

- Em **Configurações › Controle parental**: ativar/desativar, definir/alterar
  PIN (padrão 1234) e *Ocultar conteúdo adulto*.
- Categorias com nome adulto (xxx, +18, adulto, porn…) aparecem com **cadeado**
  e pedem o PIN para abrir. Com *Ocultar* ligado, somem da navegação e da busca.
- O desbloqueio vale só para a sessão; há a opção *Bloquear conteúdo adulto
  agora*.

## 6. Séries

- Listas **M3U** agora **agrupam os episódios por série**. O parser reconhece
  `S01E02`, `1x02`, `T1 E2`, `EP 2` e limpa marcações de qualidade/idioma para
  achar o nome da série.
- Cada série vira um card com capa e **temporadas separadas**; dentro, os
  episódios ordenados. Xtream Codes continua usando `get_series_info`.

## 7. Como atualizar

Mesmo procedimento: Actions → última execução → Artifacts → `neoplay-apk` →
`app-release.apk`, instalar por cima. A assinatura é a mesma desde a 1.0.1.
