# Build iOS (GitHub Actions)

Workflow: `.github/workflows/ios.yml` — **Build iOS**, runner `macos-latest`.
Roda ao mudar `app/ios/**` ou o próprio workflow na `main`, e manualmente em
**Actions → Build iOS → Run workflow**. Artefato: **miaunet-ios**.

Bundle ID: `br.com.neoplay.neoplay` (igual ao `applicationId` do Android).
iOS mínimo: 15.0. Push/APNs **não** configurado nesta versão.

## Sem conta Apple Developer (padrão)
Gera `MIAU-NET-unsigned.ipa` (`flutter build ios --no-codesign`).
**Não instala direto no iPhone.** Para testar, reassine no computador com
Sideloadly ou AltStore usando um Apple ID gratuito (validade de 7 dias, até
3 apps). Sem Apple Developer não há outra forma legítima de instalar.

## Com Apple Developer (US$ 99/ano) — IPA assinado
Cadastre em Settings → Secrets and variables → Actions:

| Secret | Conteúdo |
|---|---|
| `IOS_P12_BASE64` | certificado de distribuição (.p12) em base64 |
| `IOS_P12_PASSWORD` | senha do .p12 |
| `IOS_PROFILE_BASE64` | provisioning profile (.mobileprovision) em base64, do App ID `br.com.neoplay.neoplay` |
| `IOS_TEAM_ID` | Team ID da conta |

Opcional: variável `IOS_EXPORT_METHOD` (`ad-hoc` padrão; `development` ou
`app-store` para TestFlight). No ad-hoc, o UDID do iPhone precisa estar no
profile. Base64 no macOS: `base64 -i arquivo | pbcopy`.

## Firebase no iOS
Secret `GOOGLE_SERVICE_INFO_PLIST_BASE64` = `GoogleService-Info.plist` (app
iOS `br.com.neoplay.neoplay` no projeto `iptv-f90b5`) em base64. O CI o
adiciona ao projeto só durante o build; nunca vai para o Git. Sem ele o app
compila e roda em modo local (sem login na nuvem).
