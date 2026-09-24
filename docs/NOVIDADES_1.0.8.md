# MIAU NET 1.0.8 — Conta master segura e Firebase visível

Versão: `1.0.8 (versionCode 11)`

## Segurança da conta master

- A senha master **não fica mais no código** (estava em texto puro no
  repositório público).
- **Firebase:** o master entra só com a senha cadastrada no Firebase Auth. O
  app não cria mais a conta master sozinho; se ela não existir, crie em
  Authentication → Users → Add user com `marcioscg@hotmail.com`.
- **Modo local:** o primeiro login master no aparelho define a senha master
  daquele aparelho (guardada como hash).
- **Ação obrigatória:** troque a senha master no console do Firebase — a antiga
  continua no histórico do Git.

## Firebase conectado ou não

- O painel master mostra o aviso **"Modo local: Firebase desconectado"** quando
  o APK foi gerado sem `google-services.json` real.
- O CI emite um *warning* no build quando o secret
  `GOOGLE_SERVICES_JSON_BASE64` está ausente.

## Regras do Firestore

- `usage_events`: cada conta só registra eventos com o próprio `uid`.
- `firebase.json` e `.firebaserc` na raiz: publique as regras com
  `firebase deploy --only firestore:rules`.
