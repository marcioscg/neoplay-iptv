# MIAU NET 1.0.5 — Filtros, tema, renovação e faturamento

Versão: `1.0.5 (versionCode 8)`

Este é o **lote seguro** (só Dart + um plugin padrão). O player flutuante
(Picture‑in‑Picture) e as melhorias de transmissão ficam para a 1.0.6.

## App do usuário comum

- **Filtros por gênero** nas abas Canais, Filmes e Séries. Uma faixa de chips
  ("Ação", "Novelas", "+18", "Aventura"…) abre todo o conteúdo daquele gênero
  cruzando **todas as pastas** da lista. O reconhecimento é por palavra‑chave no
  nome da categoria e do item (`services/genres.dart`). Com o controle parental
  ocultando conteúdo adulto, o chip "+18" some.
- **Tema claro / escuro.** Em Configurações → Aplicativo → *Tema de cores*:
  "Do sistema" (padrão, acompanha o Android), "Claro" ou "Escuro". A troca é
  imediata (`appIsDark` em `theme.dart`; `AppColors` virou getter).
- **Área "Meu plano"** em Configurações: mostra o plano, a data de vencimento e
  quantos dias faltam. Botão **"Renovar pelo WhatsApp"** abre a conversa com o
  suporte (41 99992‑8132) já com a mensagem *"Meu plano está vencendo, preciso
  renovar."*.
- **Faixa de aviso** na Home quando o plano vence em 7 dias ou menos (ou já
  venceu), também com botão de renovação.

## Painel de controle (master)

- **Central de uso** agora mostra a **série inteira** — "Nome da série · T01E03
  · Título do episódio" — além do nome de filmes e canais. (`UsageEvent.seriesName`).
- **Renovações**: bloco no topo da aba Contas lista quem está **vencido** ou
  **vencendo em ≤ 7 dias**, com botão *Renovar* (adiciona um período do plano e
  reativa o acesso). Conta vencida continua **bloqueada no login** até o master
  renovar. No menu de cada conta: *Renovar (+1 período)*, *Bloquear* /
  *Desbloquear*.
- **Correção**: editar uma conta não zera mais a data de vencimento. Agora só
  recalcula se você trocar o plano ou marcar *"Renovar por mais um período"*.
- **Aba Pagamentos**: valores editáveis de cada plano (mensal, trimestral,
  semestral, anual). No Firebase ficam em `config/pricing`; no modo local, no
  aparelho.
- **Aba Faturamento**: receita mensal estimada (MRR), receita por plano,
  situação das contas (ativas / vencidas / bloqueadas) e novos cadastros nos
  últimos 6 meses, em gráficos de barra simples.
- **Aparelho da conta**: quando disponível, o painel mostra o sistema/versão do
  último acesso de cada conta. No modo local é limitado ao próprio aparelho;
  com Firebase, vem de `users/{uid}.lastDevice` / `lastSeenAt`. String rica
  (marca/modelo) fica para quando adicionarmos `device_info_plus`.

## Regras do Firestore (adicionar no console)

A tabela de preços fica em `config/pricing`. Libere leitura para contas
autenticadas e escrita só para o e‑mail do master, por exemplo:

```
match /config/{doc} {
  allow read: if request.auth != null;
  allow write: if request.auth.token.email == "marcioscg@hotmail.com";
}
```

E permita que cada conta grave o próprio `lastDevice`/`lastSeenAt` em
`users/{uid}` (merge), mantendo o resto do documento só para o master.

## Fica para a 1.0.6

- Player flutuante (Picture‑in‑Picture estilo YouTube Premium) com
  avançar/retroceder/pause/play; ou, se o build nativo não fechar, reprodução
  em segundo plano com controles na notificação.
- Transmissão: timeout e mensagem de erro quando o Chromecast trava na tela
  azul; discovery mais robusto. **TVs Samsung não usam Google Cast** — o
  plugin atual só enxerga Chromecast / Android TV / Google TV / TVs com Cast
  embutido.
