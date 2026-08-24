# Como atualizar o NEOPLAY no celular

## O caminho normal (3 minutos)

1. Abra o repositório no GitHub e vá na aba **Actions**.
2. Clique na execução mais recente do fluxo **Build APK** e espere o sinal verde (5 a 10 minutos após o push).
3. No fim da página, em **Artifacts**, baixe **neoplay-apk**. Vem um `.zip`.
4. Descompacte e escolha o arquivo:
   - `app-arm64-v8a-release.apk` — praticamente todo celular de 2018 para cá (menor e mais leve);
   - `app-release.apk` — universal, funciona em qualquer aparelho, inclusive TV Box antiga.
5. Abra o arquivo no celular e toque em **Atualizar**. O Android reconhece que é o mesmo app e instala por cima.
6. **Não precisa desinstalar.** Sua lista, favoritos e histórico continuam salvos.

Dica: baixar direto pelo navegador do celular economiza um passo. Se preferir o computador, mande o APK pelo WhatsApp Web para você mesmo e abra no celular.

## Por que antes daria erro ao instalar por cima

Até a versão 1.0.0 o APK era assinado com a chave de debug gerada na hora pelo servidor do CI — uma chave diferente a cada build. O Android compara a assinatura na hora de atualizar e recusa quando ela muda, com a mensagem "app não instalado" ou "pacote conflitante".

A partir da 1.0.1 existe uma chave de assinatura fixa, guardada nos **Secrets** do repositório (`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`). Todos os próximos APKs saem com a mesma assinatura, então atualizar é só instalar por cima.

> Guarde o arquivo `neoplay-release.jks` e a senha em lugar seguro. Se perder a chave, nenhuma versão futura conseguirá atualizar as instalações existentes — o único caminho seria desinstalar e reinstalar, perdendo os dados salvos.

## Se aparecer "app não instalado"

| Situação | O que fazer |
| --- | --- |
| Instalou a 1.0.0 antes desta correção | Desinstale o NEOPLAY uma última vez e instale a 1.0.1. A partir daí as atualizações são por cima. |
| Baixou o APK de outra arquitetura | Use o `app-release.apk` universal. |
| Android bloqueou a origem | Ative "instalar apps desconhecidos" para o app de onde você abriu o arquivo (navegador, gerenciador de arquivos ou WhatsApp). |
| Play Protect avisou | Toque em "mais detalhes" e "instalar mesmo assim". É esperado em app fora da loja. |

## Como saber qual versão está instalada

O número aparece embaixo na tela de abertura e no fim de **Configurações**. Esta correção é a **1.0.1 (build 2)**.

## Publicar uma versão nova (para você, dono do repo)

1. Altere o código.
2. Suba o número em `app/pubspec.yaml`, no campo `version:` — por exemplo `1.0.2+3`. O número depois do `+` precisa sempre aumentar, senão o Android não aceita como atualização.
3. Faça o push na `main`. O APK novo sai pronto e assinado nas Actions.
