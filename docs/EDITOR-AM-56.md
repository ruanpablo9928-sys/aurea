# Reconstrução da edição a partir da beta 56

Base: código 1.5.5+56. Este trabalho altera a estrutura de edição, o Scene 3D e caminhos de renderização da prévia. O IPA 56 já distribuído não contém estas alterações.

## Referências e aplicação

O vídeo fornecido, `WhatsApp Video 2026-09-06 at 16.57.29.mp4`, foi consultado pelos quadros em `output/am-ui-reference/frames`. As três imagens de transformação e a imagem de movimentação fornecidas pelo usuário orientam os controles laterais e a área de arrasto.

O [guia oficial do Alight Motion](https://support.alightmotion.com/hc/en-us/articles/10536777320337-Alight-Motion-Quick-Start-Guide) descreve o fluxo adicionar, ajustar e animar. O [guia de curvas](https://support.alightmotion.com/hc/en-us/articles/10536934703889-Animation-Easing-Curves) mostra os diamantes da propriedade, o editor de curvas e os controles de presets. A correspondência visual foi avaliada com as referências do usuário; estes artigos não demonstram equivalência de implementação dos motores.

## Alterações

- Cabeçalho com voltar, nome/contexto e ações do projeto; desfazer e refazer ficam junto da reprodução.
- Barra de reprodução com início, play, fim, duplicar e expandir. O botão circular de adicionar fica na timeline.
- Adicionar abre o seletor diretamente. Formas, mídia, áudio e objetos compartilham o painel. Texto e desenho ficam na lateral direita; fechar sai do seletor em um passo.
- A seleção revela a grade de ferramentas e mantém a pilha visível para reordenar. Abrir uma ferramenta concentra a timeline na camada selecionada, com arrasto horizontal e recorte disponíveis. Comandos extras ficam em Mais.
- A prévia mantém a mesma geometria durante seleção, troca de ferramentas e abertura do seletor. Projetos largos respeitam sua proporção; telas pequenas reservam espaço útil para os controles.
- Transformação usa quatro ícones à direita, valores e área de arrasto no centro, voltar/keyframe/curva à esquerda. Pivô, opacidade, 3D e vínculo permanecem acessíveis. O indicador do menu reflete modos ativos.
- Curvas manuais ficam disponíveis também sem ativar controles avançados. Presets básicos aparecem antes das molas e presets adicionais.
- Timeline com cores por tipo de camada, relógio menor, olho e indicador da camada. Segurar o indicador bloqueia/desbloqueia; o cadeado mostra o estado. Os diamantes continuam nas faixas.
- Um efeito expandido por vez. Adicionar um efeito abre seus controles; trocar ou remover efeitos limpa a seleção de parâmetro anterior.
- As folhas de parâmetros usam um único cabeçalho de retorno. A barra de atalhos de painéis recentes foi removida da interface.
- A configuração de controles avançados fica nos ajustes do projeto.

## Estrutura compartilhada e Scene 3D

- Paleta Aurea: ação em lima, seleção em violeta, animação em teal, superfícies escuras. A referência orienta a organização, sem trocar a identidade do app.
- Em paisagem, a coluna das ferramentas fica reservada: selecionar uma camada ou abrir um painel não muda a largura da prévia. A largura dos controles acompanha a tela, entre 280 e 380 pontos.
- Composição 2D e câmera do Scene 3D compartilham o cálculo da área de saída. Uma margem de edição e uma borda visível identificam o enquadramento, inclusive em imagens pretas. A proporção da câmera passa a corresponder à saída, em vez de depender do retângulo disponível no aparelho.
- As guias de área segura configuradas no projeto aparecem também no Scene 3D. Margens, bordas e guias de edição não são acrescentadas à exportação.
- No Scene 3D, adicionar, focar, hierarquia, desfazer e refazer ficam numa barra fora da imagem. Contexto, valores e ferramentas ocupam a região inferior ou lateral. Controles avançados rolam dentro dessa região, sem diminuir a câmera.
- Faixa 3D com diamantes de objeto/câmera, cabeçote e busca por toque ou arrasto. Um toque perto do diamante busca seu instante exato. Os marcadores são pintados em uma única superfície; não criam um widget por keyframe.
- Posição e rotação XYZ, escala de objetos e lente da câmera têm edição numérica direta. A edição respeita auto-key e bloqueio do objeto, mantém a pose inicial e preserva outros keyframes.
- Abrir o teclado de um diálogo numérico não redimensiona o editor que está atrás dele.
- Botões de operadores vetoriais quebram em linhas quando falta largura; foi corrigido o estouro encontrado nos painéis laterais.

## Trabalho de renderização

- Corrigido o piso fixo de 0,25 na razão de pixels dos efeitos. Ele anulava o teto de 1080 pixels em projetos 8K/16K. A captura passa a respeitar os pixels exibidos e o teto, com mínimo de um pixel. Isso não muda a resolução de exportação.
- Transições resolvem os participantes por índice em uma passagem, removendo a busca completa por vídeo a cada corte. O teste com 2.000 clipes valida a quantidade de leituras e o resultado da transição, sem depender de uma meta de tempo da máquina de teste.
- O relógio 3D atualiza os elementos dependentes do tempo, sem reconstruir os menus e ferramentas estáticos em cada tick.
- O viewport nativo deixa de submeter quadros e de reagir à pressão de composição quando a rota está oculta. Retoma ao voltar. A fila de último quadro e a qualidade adaptativa existentes continuam sendo usadas.

As mudanças seguem a orientação de reduzir reconstruções e trabalho de renderização desnecessários nas [boas práticas oficiais do Flutter](https://docs.flutter.dev/perf/best-practices). O teste de custo de cortes não é um benchmark de GPU: não comprova milhares de camadas com efeitos a 60 fps. A documentação do Flutter orienta avaliar esses tempos em [aparelhos físicos e modo profile](https://docs.flutter.dev/tools/devtools/performance).

## Verificação

A rodada seguinte, com os oito relatos beta de 8 de setembro, passou em **117 testes**. Inclui os seis testes de `beta_reports_test.dart`, a regressão de gestos verticais em `sair_da_aba_e_ordem_na_timeline_test.dart` e um teste novo do shader de pixelização. O resultado está em `tmp/beta-regression.log`. A análise em `tmp/beta-analyze.log` terminou sem erros ou avisos, com uma informação preexistente de import redundante em `qualidade3d_controller.dart`. Detalhes e limites em [BUGS-BETA-56.md](BUGS-BETA-56.md).

105 testes passaram na regressão consolidada: navegação, estabilidade da prévia, importação de mídia, desenho, keyframes, curvas, gestos, expansão de efeitos, renderização dos shaders, fila nativa e resolução adaptativa. Os 20 testes do estúdio foram repetidos e passaram depois do ajuste final que remove a altura vazia em projetos horizontais. A análise estática não apresentou problemas. A matriz 2D inclui 320×568, 375×667, 430×844, 667×375, 844×390 e 1024×768. A edição 3D e o teclado são exercitados em 320×568, 390×844 e 667×375. Não houve execução em iPhone físico nesta rodada.

Comando principal:

```text
flutter test --no-pub test/am_reference_layout_test.dart test/editor_hierarchy_test.dart test/transform_workspace_test.dart test/editor_preview_keyframe_visibility_test.dart test/am_gallery_ui_test.dart test/imported_media_preview_test.dart test/freehand_preview_session_test.dart test/gallery_import_test.dart test/pixel_effect_engine_test.dart
```

Testes adicionais: `editor_responsive_frame_test.dart`, `preview_raster_test.dart`, `scene3d_studio_motion_test.dart`, `estudio3d_ux_test.dart`, `abrir_estudio_3d_test.dart`, `renderer_architecture_test.dart`, `transition_preview_cost_test.dart`, `shell_fase1_test.dart`. Resultado consolidado em `tmp/editor-engine-regression-final.log`; análise em `tmp/editor-engine-analyze.log`.

Captura de transformação: `output/am-redesign-56/posicao.png`. Regeneração: executar `test/am_reference_layout_test.dart` com `--dart-define=AM_CAPTURE=posicao`, selecionando o teste da tela de 430×844. Recarregar a fonte dos ícones antes do readback evita glyphs ausentes nas capturas do runner de testes.

Nenhum IPA novo foi gerado neste trabalho. A estabilidade e o consumo de memória na GPU do iPhone/Android ainda precisam de medição em hardware. Não se afirma que os motores internos proprietários do Alight Motion, CapCut ou Node Video foram reproduzidos.
