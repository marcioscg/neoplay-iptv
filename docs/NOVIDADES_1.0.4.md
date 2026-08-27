# MIAU NET 1.0.4 — Contas e uso no Firebase

Versão: `1.0.4 (versionCode 7)`

## O que muda

Na 1.0.3 as contas e as estatísticas ficavam só no aparelho. Agora usam o
**Firebase** (projeto `iptv-f90b5`), então:

- A conta que o master cadastra no painel **funciona no celular de outra
  pessoa** — ela entra com o mesmo e-mail e senha em qualquer aparelho e recebe
  a lista M3U vinculada.
- A **central de uso** do painel mostra o que as contas assistiram **de todos
  os aparelhos**, não só do aparelho do master.

## Como funciona por dentro

- **Firebase Auth (e-mail/senha):** a senha nunca é gravada em texto; fica só no
  Auth. A conta master (`marcioscg@hotmail.com`) é criada automaticamente no
  primeiro login.
- **Firestore:**
  - `users/{uid}` — perfil da conta (nome, e-mail, lista M3U, plano, status).
  - `usage_events/{id}` — um registro por conteúdo aberto.
- Criar conta no painel usa um app Firebase secundário, para o master não ser
  deslogado ao criar o usuário.
- Editar conta altera só o perfil (nome, lista, plano, status). Para trocar a
  senha de alguém, use **"Enviar redefinição de senha"** — a pessoa recebe um
  e-mail do Firebase.
- Excluir marca a conta como removida (o login dela para de funcionar). Apagar
  o usuário do Auth de vez é feito pelo console do Firebase.

## Regras de segurança do Firestore

Coladas no console (Firestore Database → Regras). Só o e-mail do master lê a
lista de contas e a telemetria; cada conta comum só enxerga o próprio perfil.

## Modo offline / sem Firebase

Se o Firebase não inicializar (sem `google-services.json` real no build), o app
cai automaticamente no modo local da 1.0.3 — tudo continua funcionando, só sem
sincronizar entre aparelhos.

## Infra

- Plugin Gradle `com.google.gms.google-services`.
- `google-services.json` entra no build via secret do repositório
  (`GOOGLE_SERVICES_JSON_BASE64`), não fica versionado.
- Pacotes: `firebase_core`, `firebase_auth`, `cloud_firestore`.
