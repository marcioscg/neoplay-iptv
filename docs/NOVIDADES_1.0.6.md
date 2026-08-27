# MIAU NET 1.0.6 — Senha e transmissão

Versão: `1.0.6 (versionCode 9)`

Lote seguro (só Dart). O player flutuante (Picture‑in‑Picture) fica para a 1.0.7.

## Senha / "Esqueci minha senha"

O problema: no **modo local** (APK atual, sem o secret do Firebase) o botão
"Enviar redefinição de senha" **não fazia nada** — não existe servidor de
e‑mail — mas mostrava "enviado". E editar uma conta no painel **zerava a senha**
dela, porque o formulário salvava o campo de senha vazio por cima.

O que mudou:

- **Bug corrigido:** editar uma conta **não apaga mais a senha**. O campo agora
  é "Nova senha (em branco = manter)".
- **Modo local:** o master define/redefine a senha de qualquer conta direto no
  painel (campo "Nova senha" ao editar). É a forma de "resetar senha" sem
  e‑mail.
- **Modo Firebase:** o formulário mostra "Enviar e‑mail de redefinição" com um
  aviso de que o e‑mail vem de `noreply@iptv-f90b5.firebaseapp.com` e pode cair
  no spam (dá para trocar o remetente em Authentication → Templates no console).
- **Tela de login:** novo link **"Esqueci minha senha"**. Abre um diálogo com
  botão de **WhatsApp** (fala com o administrador, já com o e‑mail na mensagem)
  e, no modo Firebase, a opção de receber o e‑mail de redefinição.
- Mensagens honestas: nada mais de "e‑mail enviado" quando não foi.

`AccountsRepository` ganhou `canMasterSetPassword`, `canEmailPasswordReset` e
`setPassword(user, novaSenha)`.

## Transmissão (Chromecast)

- **Timeout em cada etapa** (`cast_service.dart`): 20s para conectar, 25s para
  o vídeo carregar. Sem isso o app ficava preso na "tela azul do Chromecast"
  quando a TV aceitava a conexão mas o vídeo não abria.
- **Mensagens claras** quando falha: "a TV não respondeu / mesmo Wi‑Fi?",
  "conectou mas o vídeo não abriu — MKV/AVI o Chromecast recusa", "bloqueio do
  provedor ou formato não suportado". Em qualquer erro, a sessão é encerrada
  (não fica meio conectado).
- **Folha "Enviar para TV"**: aviso de que só aparecem Chromecast, Android TV,
  Google TV e TVs com Chromecast embutido — **TVs Samsung/LG com sistema
  próprio não são detectadas** (protocolo diferente, fora do alcance do
  plugin). Botão "Procurar de novo".

## Firebase — regras do Firestore

Arquivo pronto para colar no console: **`docs/firestore.rules`**. Cobre
`users/{uid}` (master vê tudo; a pessoa só o próprio doc e só grava
`lastDevice`/`lastSeenAt`), `usage_events` (qualquer conta cria; só o master
lê/limpa) e `config/pricing` (todos leem; só o master escreve).

## Fica para a 1.0.7

- Player flutuante / Picture‑in‑Picture estilo YouTube Premium com
  avançar/retroceder/pause/play; fallback para reprodução em 2º plano com
  controles na notificação se o build nativo não fechar.
