# Configuração do Firebase para a 1.0.8

Coisas que precisam ser feitas **no console do Firebase / GitHub** — o código do
app já está pronto para elas.

## 1. Regras do Firestore (obrigatório)

Abra **Firestore Database ▸ Regras**, cole o conteúdo de `docs/firestore.rules` e
**Publicar**. As novidades desta versão:

- `isMaster()` agora inclui `nunestrc09@gmail.com` (Master 2).
- `isMasterPrimary()` (só Master 1) continua sendo quem lê/limpa `usage_events`.
- `usage_events`: cada conta só grava evento em nome de si mesma.
- Novas coleções `master_bindings` (trava de aparelho) e `login_locks`
  (bloqueio de 24 h por senha errada).

## 2. Master 2 no Authentication

O app cria o usuário `nunestrc09@gmail.com` no primeiro login, **desde que**
em **Authentication ▸ Sign-in method** o provedor **E-mail/Senha** esteja
**ativado**. Se preferir, crie o usuário manualmente com a senha `Nunes@2026`.

## 3. Por que o e-mail de recuperação de senha não chega

Confira, nesta ordem:

1. **O APK está usando o Firebase?** Abra o painel, aba **Contas**, rodapé. Se
   aparecer `Backend: LOCAL …`, o APK foi gerado **sem** `google-services.json`
   real — nesse modo não há e‑mail. Configure o secret
   `GOOGLE_SERVICES_JSON_BASE64` no repositório (Settings ▸ Secrets ▸ Actions)
   com o `google-services.json` do projeto `iptv-f90b5` em base64 e gere o APK de
   novo.
2. **E-mail/Senha ativado** em Authentication ▸ Sign-in method.
3. **Authentication ▸ Templates ▸ Redefinição de senha**: confira o idioma e o
   remetente. O padrão vem de `noreply@iptv-f90b5.firebaseapp.com`.
4. **Proteção contra enumeração de e-mail** (Authentication ▸ Settings): quando
   ligada, o Firebase responde "enviado" **mesmo para e-mails que não existem** e
   não manda nada. Para uma conta que existe de verdade, o e‑mail sai normalmente.
5. **Caixa de spam / lixo eletrônico** do destinatário.
6. **Entregabilidade**: para reduzir spam, configure um **SMTP próprio** ou um
   **domínio verificado** em Authentication ▸ Templates ▸ (ícone de lápis) ▸
   "Personalizar domínio".

## 4. Exclusão de conta que "não some"

Sem o plano **Blaze** não dá para o app apagar o usuário do Firebase Auth (isso
exige uma Cloud Function com o Admin SDK). A 1.0.8 contorna assim: ao excluir, a
conta é marcada como removida; ao recadastrar o **mesmo e‑mail**, o perfil é
**reativado** e a pessoa recebe e‑mail para definir a nova senha.

Se um dia ativar o Blaze, dá para adicionar a Function `deleteAuthUser`
(callable, só Master 1) e chamar no `deleteUser` — é uma mudança pequena.

## 5. (Opcional) Segredos das senhas master no build

As senhas master têm um default no código. Para não deixá-las no fonte, defina os
secrets `MASTER1_PASS` e `MASTER2_PASS` no repositório — o workflow passa via
`--dart-define` automaticamente.

## 6. Índices do Firestore

A busca de conta por e‑mail (`users where email == …`) usa índice de campo único,
criado automaticamente. Não precisa de índice composto.
