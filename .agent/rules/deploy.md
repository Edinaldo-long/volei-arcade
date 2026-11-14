# Regra de Deploy e Publicação Contínua

## Gatilhos Verbais
Sempre que o usuário enviar mensagens como:
- "publicar atualização"
- "lançar versão"
- "publicar nova versão"
- "fazer deploy"
- "gerar release"
- "publicar jogo"

## Comportamento Obrigatório do Agente
1. **Execução Autônoma Imediata**: Execute diretamente o script `publicar.ps1` usando PowerShell:
   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File .\publicar.ps1
   ```
   *(ou `cd volei; powershell.exe -ExecutionPolicy Bypass -File .\publicar.ps1`)*

2. **Zero Burocracia**:
   - NÃO solicite confirmações intermediárias para incrementar versão ou subir arquivos.
   - NÃO peça para o usuário editar manualmente o `pubspec.yaml`.
   - NÃO peça para o usuário rodar comandos Git manuais (`add`, `commit`, `tag`, `push`).

3. **Fluxo do Script**:
   - O script lê o `pubspec.yaml`, incrementa o patch (`Z + 1`) e o build number (`N + 1`).
   - Salva o arquivo, cria o commit `release: vX.Y.Z`, gera a tag `vX.Y.Z` e faz o push para a branch `main` com `--tags`.
   - O envio da tag dispara automaticamente a pipeline do GitHub Actions em `.github/workflows/release.yml`, que compila o APK de produção e cria a release com o binário `app-release.apk` pronto para auto-update.

4. **Retorno ao Usuário**:
   - Ao finalizar a execução do script, informe a versão anterior e a nova versão gerada (ex: `1.0.1+2` -> tag `v1.0.1`).
   - Forneça o link direto da esteira no GitHub Actions para acompanhamento em tempo real:  
     `https://github.com/Edinaldo-long/volei-arcade/actions`
