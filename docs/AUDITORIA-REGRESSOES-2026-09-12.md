# Auditoria de regressões — 12/09/2026

Base analisada: `1c226f8`, versão `1.0.0-beta.3+75`. A comparação das mudanças recentes (`c3fc372..HEAD`) inclui 142 arquivos, aproximadamente 17,8 mil linhas adicionadas e 1 mil removidas. O trabalho combinou leitura das integrações Dart/C++, análise estática, suíte Flutter, testes com FFmpeg e execução de um APK de depuração no emulador Android.

**Há correções importantes implementadas, mas isto não é uma certificação de ausência de bugs. A suíte completa ainda apresenta falhas.** Os testes antigos não foram desativados para produzir um resultado verde. Os resultados finais e a lista de falhas estão no fim deste documento.

## Correções implementadas

| Área | Problema encontrado | Correção |
| --- | --- | --- |
| Exportação | O novo caminho C++ era escolhido automaticamente, embora a sincronização ainda criasse retângulos brancos e não transferisse toda a composição, mídia, efeitos e cenas. Podia exportar um resultado diferente da prévia. | Exportação voltou a capturar a composição real do editor; o encoder acelerado continua disponível. O protótipo nativo não é selecionado como renderizador de produção. |
| Renderização GPU 3D | Uma segunda luz direcional com direção personalizada provocava uma asserção de `DirectionalLightComponent`. Em release, a direção seria ignorada. | Uso de `DirectionalLightComponent.aimed` nas luzes adicionais, incluindo a troca da luz principal. A cena ABISMO deixou de abrir com tela vermelha e voltou a renderizar no emulador. |
| Prévia do editor | Abrir ferramentas reduzia a prévia até 96 px. | O orçamento do layout mantém o tamanho da prévia e ajusta o espaço das ferramentas/timeline. |
| Câmera no estúdio | O enquadramento usava a proporção do viewport do celular, diferente da proporção de exportação. | A vista pela câmera usa a proporção do projeto, com borda e recorte. Vistas livres e ortográficas continuam usando o espaço disponível. |
| Telas estreitas | Barra de transporte, ações da camada, campos X/Y/Z e trilho da curva podiam ultrapassar o espaço disponível. | Distribuição flexível dos controles e rolagem do trilho quando necessário; a prévia permanece fixa. |
| Importação 3D | A análise nativa síncrona lia modelos antes do processamento em isolate e anunciava otimizações não conectadas ao fluxo. | A leitura e interpretação ficam no isolate; retirada a etapa síncrona e suas mensagens imprecisas. |
| Catálogo de objetos | Rótulos como Carro e Texto 3D criavam apenas primitivas sem correspondência. Modelos mostravam partes falsas, como Telhado e Porta. | Catálogo e lista exibem os tipos/objetos realmente existentes. |
| Erros ao importar | Exceções eram engolidas e a folha fechava mesmo sem importar. | Erro visível, cancelamento mantém a folha e o estado de carregamento é liberado em `finally`. |
| Curvas de velocidade | O gráfico tinha alças, mas a gravação perdia o easing e o playback não seguia a curva mostrada. | Conversão bidirecional das curvas, preservação de easing, avaliação pelo mesmo `AnimatedDouble` do projeto e persistência JSON verificada. |
| Tempo dos keyframes | O painel de remapeamento usava tempo global e podia ignorar a velocidade original do clipe. O comando explícito de adicionar podia ficar apenas pendente. | Tempo local da camada, preservação da velocidade e adição explícita com `withKeyframe`. Abrir a ferramenta não altera o projeto. |
| Congelar/inverter vídeo | Congelamento não tinha interpolação de retenção; inverter podia atribuir a curva ao trecho errado. | Interpolação `hold` adicionada ao fim do enum para preservar índices antigos. Inversão mantém os tempos e espelha a direção da origem. |
| Animação 3D | Gráfico ilustrativo, ações inertes e adição limitada a X. | Gráfico das trilhas reais; seleção de propriedade do objeto/câmera; adicionar, excluir, buscar tempo e ajustar curvas. |
| Abrir curva 3D | A ação preenchia um provider, mas o editor de curvas havia desaparecido da árvore da interface. | A curva abre numa folha própria e fecha corretamente, retornando ao painel de animação. |
| Propriedades 3D | Valores e nomes fixos, texturas fictícias e gravação direta de base ignoravam a edição animada. | Reutilização da ficha real de transformação, material, textura e animação; a aba solicitada é respeitada. |
| Câmeras | Campos que pareciam editáveis não editavam; operações atingiam a câmera principal em vez da selecionada e ignoravam o instante. | Campos numéricos reais, câmera selecionada e comandos de edição das trilhas no tempo local. |
| Luzes | Só a primeira luz de cada tipo era selecionável; intensidade ignorava o tempo; ângulo não fazia nada. | Seleção de cada instância, inclusive spots; intensidade animada, cone real e ambiente da cena separado. |
| Exportar pelo estúdio | Resolução, FPS e formato escolhidos não chegavam à tela de exportação. | `ExportSettings` encaminhado; a opção de imagens é identificada como Sequência PNG. |
| Parenting | Vincular a camada de cena também modificava o vínculo independente da câmera. | Os vínculos da camada e da câmera são independentes. |
| Áudio | O modulador podia produzir amostras não finitas com FFmpeg. | Oscilador baseado em índice de amostra e proteção contra NaN/infinito na entrada. |
| Segurança nativa | Ponte aceitava ponteiro nulo FFI como engine válida; dimensões do export eram compartilhadas entre instâncias; inicialização GPU podia anunciar sucesso sem contexto EGL. | Validação de ponteiro/dimensões/índice de frame, dimensões por instância e inicialização honesta da GPU. |
| Aviso de atualização | Resumo anterior não descrevia as correções desta rodada. | Nova revisão do aviso, em linguagem curta, exibida uma vez e acessível novamente. |

## Evidências de execução

- Baseline: **1.874 testes aprovados / 111 falhas**. Parte das falhas de áudio era provocada por um caminho de FFmpeg inexistente; foi instalado um executável isolado para os testes. Isso é uma correção do ambiente de verificação, não uma correção do aplicativo.
- `test/gemini_regressions_test.dart`: regressões de enquadramento, câmera, parenting, luzes, configuração de exportação, curvas/JSON, tempo local e adição/exclusão/abertura da curva 3D.
- Último conjunto focado de editor, regressões, remapeamento e aviso: **18 aprovados** (`tmp/gemini-final-focused.log`).
- Fluxo completo do editor em 375×667 e 430×844, incluindo efeitos: **3 aprovados**, após corrigir o trilho da curva (`tmp/gemini-rail-test.log`).
- Timeline com 3.000 camadas: virtualização e sincronização vertical aprovadas. O teste foi corrigido para usar a altura atual da linha, em vez de 38 px fixos. Isso não prova 3.000 camadas com efeitos renderizando em tempo real.
- Teste de arrasto da timeline aprovado após apontar o gesto para o conteúdo real do clipe, em vez da faixa inteira. Não foi alterada a lógica de arrasto para acomodar o teste.
- APK Android x64 de depuração compilado e instalado no emulador `am2test`. Abertura da composição ABISMO, seleção da camada, estúdio GPU e aviso de atualização inspecionados. A captura anterior mostra a asserção da luz; a posterior mostra a cena renderizada.
- Evidências visuais: `tmp/am-audit/gemini-studio.png` (antes), `tmp/am-audit/gemini-gpu-studio-loaded.png` (depois), `tmp/am-audit/gemini-gpu-relaunch.png` (aviso). O log de erros da sessão corrigida está em `tmp/gemini-emulator-errors.log`.

## Limites e trabalho que permanece

- A suíte completa não está verde. Há testes procurando telas/nomes removidos (`Scene3DStudio`, `Mais`, réguas e atalhos antigos) e testes exigindo keyframes automáticos que contradizem `docs/keyframe-explicito.md` e os testes atuais de edição explícita. **Não classifiquei todas as falhas restantes como obsoletas.** A lista final abaixo deve ser tratada como pendência de auditoria/migração, não apagada ou ignorada.
- O novo motor C++ continua incompleto como substituto integral do compositor Flutter. A correção impede que ele estrague a exportação; não o transforma num motor equivalente ao editor atual.
- Não houve validação em iPhone físico, teste térmico prolongado nem medição de memória de GPU em celulares de diferentes classes. O build feito aqui é de depuração para emulador, não um IPA ou APK de distribuição.
- Não há promessa de aceitar qualquer arquivo 3D, de suportar toda extensão GLTF ou de manter FPS fixo com carga ilimitada. Os formatos e extensões efetivamente suportados continuam sendo os do importador existente.

<!-- FINAL_RESULTS -->
## Resultado final registrado

- Análise estática de `lib` e `test`: sem problemas (`tmp/beta-final-analysis.log`).
- Suíte completa: **1,912 aprovados e 91 falhas**, de 2003 testes. Registro: `tmp/beta-complete-tests.log`.
- Build Android x64 debug: registro em `tmp/beta-final-build.log`; não é pacote de distribuição para os testadores.
- Nenhum commit, publicação ou envio a serviços externos foi feito nesta rodada.

As falhas abaixo continuam explícitas no resultado. A planilha CSV ao lado deste documento contém o nome de cada teste para reprodução individual.

| Arquivo de teste | Falhas |
| --- | ---: |
| `abrir_estudio_3d_test.dart` | 1 |
| `beta_reports_test.dart` | 2 |
| `editor_hierarchy_test.dart` | 5 |
| `editor_preview_keyframe_visibility_test.dart` | 4 |
| `efeitos_fase4_test.dart` | 2 |
| `effect_preset_store_test.dart` | 1 |
| `effect_universal_keyframe_test.dart` | 3 |
| `export_fluxo_test.dart` | 1 |
| `gestos_do_painel_test.dart` | 3 |
| `girar_da_volta_test.dart` | 1 |
| `inicio_redesenho_test.dart` | 1 |
| `keyframe_dez_testes_test.dart` | 1 |
| `keyframe_test.dart` | 1 |
| `keyframes_fase5_test.dart` | 2 |
| `largura_arrastavel_test.dart` | 2 |
| `layer_menu_navigation_test.dart` | 14 |
| `manual_auto_key_test.dart` | 2 |
| `nivel1_shapes_test.dart` | 6 |
| `nivel3_seis_efeitos_test.dart` | 1 |
| `ordem_das_camadas_test.dart` | 1 |
| `painel_cabe_na_tela_test.dart` | 6 |
| `painel_fase3_test.dart` | 5 |
| `palco_direto_test.dart` | 1 |
| `projeto_export_fase6_test.dart` | 1 |
| `qa_fase7_8_test.dart` | 5 |
| `quick_guide_test.dart` | 1 |
| `rastreio_ui_test.dart` | 1 |
| `sair_da_aba_e_ordem_na_timeline_test.dart` | 4 |
| `scene3d_studio_motion_test.dart` | 3 |
| `scene_motion_authoring_test.dart` | 2 |
| `shell_fase1_test.dart` | 1 |
| `timeline_fase2_test.dart` | 2 |
| `transform_workspace_test.dart` | 2 |
| `ui_1011_test.dart` | 2 |
| `widget_test.dart` | 1 |

## Capturas beta recebidas durante a auditoria

Detalhes em [CORRECOES-BETA-2026-09-12.md](CORRECOES-BETA-2026-09-12.md).

- A suíte completa mais recente terminou com 1.912 aprovados e 91 falhas. Depois dela, a expectativa de ímã/busca foi atualizada conforme a remoção solicitada, e seu teste substituto passou. **90 falhas desse inventário permanecem pendentes**; a suíte completa não foi repetida após essa mudança apenas no teste.
- Validação direcionada final: **47 aprovados e uma falha preexistente** no teste de navegação de grupo `E2 do grupo tem Entrar; Voltar sai do grupo` (`tmp/beta-final-focused.log`). Todas as novas regressões das capturas passaram.
- Análise estática: sem problemas. Build Android x64 debug concluído e instalado no emulador preservando os projetos. Este build é de verificação, não um IPA nem pacote para distribuição.
- Captura do painel atual: `output/am-redesign-56/camada.png`. Aviso inicial: `tmp/am-audit/beta-final-launch.png`. Abertura real do editor de curvas 3D: `tmp/am-audit/beta-native-curve.png`.
- Nenhuma garantia de ausência total de bugs ou de desempenho em iPhone físico é inferida desses resultados.
