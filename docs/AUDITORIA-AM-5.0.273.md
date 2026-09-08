# Auditoria com Alight Motion 5.0.273.1028425

Data: 8 de setembro de 2026. Estado: **instalação concluída; comparação visual do editor aguardando login do usuário no Google Play**.

## Referência confirmada

O usuário identificou explicitamente `Alight+Motion_5.0.273.1028425_APKPure.xapk`, em Downloads. SHA-256: `EC2C7E47F49F49642D7DFAD2687256288DE9670CF7CCD2D45B84E1D40286057C`.

Foram instalados os quatro APKs internos: base, arm64_v8a, en e mdpi. O Android confirmou `com.alightcreative.motion`, versionCode `1028425`, versionName `5.0.273.1028425`. A versão 5.0.279 foi desinstalada do emulador anterior, incluindo os dados locais, após autorização explícita do usuário. Não deve ser usada como referência final desta auditoria.

## Ambiente e impedimento atual

O emulador original `am2test` não possuía a Play Store oficial; a versão confirmada recusou abrir com a mensagem de verificar Google Play. A captura está em `tmp/am-audit/am-official-start.png`.

Foi preparado um emulador separado `am_google_play`, serial `emulator-5556`, com imagem oficial Google Play Android 14/API 34/revisão 14. O arquivo de sistema foi baixado de `dl.google.com`, conferido pelo tamanho e SHA-1 do catálogo oficial e extraído para `tmp/am-audit/play-system`. O AVD fica em `tmp/am-audit/avds`. Essa organização está de acordo com a distinção entre imagens Google APIs e Google Play na [documentação Android](https://developer.android.com/studio/run/managing-avds).

O XAPK confirmado e o APK debug atual do Aurea foram instalados nesse segundo emulador. Ao abrir o AM, ele encaminhou ao login do Google Play. A captura `tmp/am-audit/am-google-play-ready.png` registra a tela. O usuário foi solicitado a entrar diretamente na janela; não foram coletadas credenciais, nem alterado o APK ou seus requisitos de inicialização. Não interagir com essa janela enquanto o usuário estiver entrando.

Para reabrir o ambiente após encerrá-lo, definir `ANDROID_AVD_HOME` como o caminho absoluto de `tmp/am-audit/avds` e executar o emulador com `-avd am_google_play -port 5556 -no-snapshot`. Os auxiliares de inspeção Android em `tmp/am-audit/android_audit.py` guardam screenshots e hierarquias XML; não fazem parte do aplicativo.

## Falhas do Aurea encontradas e corrigidas durante a preparação

### Vídeo começando no meio

O teste `test/video_start_sync_test.dart` reproduziu a falha: com o player ainda no segundo 4 e o cabeçote voltando a zero, o comando nativo era `play@4000` antes de o seek terminar. A falha original está em `tmp/am-audit/video-start-test.log`.

`VideoLayerManager` agora serializa o posicionamento e só inicia play após o seek. Durante um seek pendente guarda o pedido mais recente, sem criar fila de posições intermediárias. Controladores removidos não podem iniciar reprodução quando sua operação atrasada termina. Pausar impede que um início pendente volte a tocar. O temporizador de scrub não pausa uma reprodução iniciada logo depois.

O relógio expõe a revisão de seek, incluindo retorno em loop. `EditorScreen` passa essa revisão para o gerenciador: um salto intencional do cabeçote durante play não é confundido com deriva do decodificador. A origem recortada do arquivo é respeitada — início da camada não significa necessariamente frame zero do arquivo original.

Os quatro casos novos cobrem seek atrasado com ticks intermediários, retorno ao início durante play, origem recortada em 2 s, cancelamento do início e expiração de scrub. São testes de integração Dart com player nativo simulado, não uma comprovação em iPhone físico.

### Compilação do aplicativo completo

O build encontrou um `Future<String?>` atribuído a `String?` em `_FolhaDaContaState._salvar`, na tela da comunidade. O formulário passou a aguardar a operação, impedir envio repetido enquanto salva e conferir `mounted` antes de atualizar a interface. Nenhuma conta real foi criada no servidor durante o teste.

## Verificação concluída

- **129 testes passaram** na regressão consolidada: `tmp/am-audit/full-regression.log`.
- Análise dos arquivos desta correção: sem problemas.
- Build Android debug x64 aprovado: `tmp/am-audit/aurea-build-final.log`.
- Artefato instalado no segundo emulador: `build/app/outputs/flutter-apk/app-debug.apk`. É um build de depuração x64 para o emulador, não o APK de distribuição ARM dos beta testers.
- Nenhum IPA novo foi gerado.

## Comparação visual ainda pendente

Após o login, usar projetos novos de auditoria e comparar, em ambos os aplicativos:

1. Projeto: proporção/resolução, fps, fundo, salvar e reabrir.
2. Camadas: adicionar formas, texto, imagem, vídeo e áudio; selecionar, ordenar, arrastar, recortar, dividir, duplicar, bloquear e ocultar.
3. Transformação: posição/pivô, rotação, escala uniforme e separada, inclinação; espaço da preview e toque nos controles.
4. Animação: inserir/ver/remover keyframes, navegar entre eles, copiar, interpolar, curvas manuais e presets.
5. Aparência: preenchimento, gradiente, borda, sombra, opacidade, mesclagem, máscaras e recorte por camada.
6. Organização: seleção múltipla, grupos, vínculo e nulos; facilidade de encontrar cada comando.
7. Efeitos: adicionar, buscar, ajustar, animar, reordenar, desligar, copiar e remover; diferenciar efeito exposto de efeito com resultado confirmado.
8. Tempo e mídia: play/pausa, começo/fim, scrub, velocidade/reverso, áudio e origem recortada. Confirmar visualmente o primeiro quadro do clipe.
9. Exportação: saída real, duração/orientação, reimportação e limites dos formatos vetoriais.
10. Scene 3D do Aurea: câmeras, cortes, objetos, materiais, luzes, keyframes, retorno ao editor e estabilidade da preview. A existência de um editor de referência não certifica automaticamente o motor 3D próprio.

Os testes já existentes cobrem partes desses fluxos no Aurea, mas ainda não constituem uma comparação visual concluída com a versão confirmada do AM. Não afirmar equivalência completa nem que nenhuma função falta ou falha.
