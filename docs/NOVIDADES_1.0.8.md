# MIAU NET 1.0.8 — o que mudou

## Acesso e contas

- **Master 1** (`marcioscg@hotmail.com`) agora entra com a senha `27062015EmillY#`.
  Se o usuário do Firebase ainda estiver com a senha antiga, o app migra sozinho
  no primeiro login.
- **Master 2** (`nunestrc09@gmail.com`, senha `Nunes@2026`): faz tudo que o
  Master 1 faz **menos ver/limpar a aba "Central de uso"** — essa aba nem aparece
  para ele.
- **Trava de aparelho do Master 1**: no primeiro login o app registra um
  identificador do aparelho. Depois disso, o Master 1 só entra nesse celular.
  Para trocar de aparelho, o **Master 2** usa "Liberar trava de aparelho do
  Master 1" na aba Contas (ou apaga o documento em `master_bindings` no Firestore).
- **Bloqueio por tentativas**: 3 senhas erradas para o mesmo e‑mail travam o
  acesso por **24 h**. O Master libera antes disso pelo campo "Tentativas de
  login" na aba Contas. Quando o Firebase está ligado, a trava vale em qualquer
  aparelho.
- **Excluir conta**: o e‑mail continua reservado no servidor (o Firebase não
  deixa o app apagar o usuário do Auth). Se recadastrar o mesmo e‑mail, a conta é
  **reativada** e a pessoa recebe um e‑mail para definir a nova senha — some o
  antigo "e‑mail já existe".
- **Diagnóstico**: o rodapé da aba Contas mostra qual backend está em uso
  (Firebase ou LOCAL). Se aparecer "LOCAL", o APK está sem `google-services.json`
  e o e‑mail de recuperação não funciona (ver `CONFIG_FIREBASE_1.0.8.md`).

## Login mais prático e seguro

- **Preenchimento automático**: e‑mail e senha voltam preenchidos quando o
  "Manter conectado" está ligado, e o gerenciador de senhas do Android passa a
  oferecer salvar/preencher.
- A senha do "Manter conectado" saiu do texto puro e agora fica no
  **armazenamento protegido do sistema** (Keystore).

## App mais leve

- Release com **R8 + remoção de recursos não usados** e **APKs por arquitetura**
  (`--split-per-abi`): instala bem mais leve.
- **Abre mais rápido**: o Google Cast só inicializa depois da primeira tela e o
  login automático não prende mais o splash em rede ruim.

## Interface

- **Tema fixo escuro**: a troca claro/escuro foi removida (dava bug). O app
  ignora o modo claro do sistema.

## Pagamentos

- A aba **Pagamentos** não trava mais no "Salvando…": agora tem tempo limite e
  mostra o erro quando não consegue gravar.

## Lembrete de mensalidade

- Botão de renovar fica **vermelho** quando faltam **3 dias ou menos** (ou já
  venceu), na tela do plano e no painel.
- Faltando **1 dia** (ou vencida), ao abrir o app a pessoa recebe um **popup com
  o botão do WhatsApp** para pagar — no máximo uma vez por dia.
