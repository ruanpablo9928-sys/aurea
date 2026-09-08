# Correções dos relatos beta — 8 de setembro de 2026

Base 1.5.5+56. Correções no código local; o IPA 56 já distribuído não recebe estas alterações automaticamente.

| Relato | Alteração | Verificação |
| --- | --- | --- |
| Camadas não arrastam nos dois eixos | A grade de ferramentas mantém mais de uma linha da pilha visível. Arrasto vertical reordena; horizontal continua disponível dentro da ferramenta. O gesto não é cancelado ao atualizar a timeline compacta. | Arrasto horizontal com painel aberto; arrasto vertical para cima e para baixo; comandos de ordem e início no cabeçote. |
| Puxar camada para frente e para trás | Ações diretas para mover início/fim ao cabeçote e subir/descer na pilha. O início permanece limitado a zero. | Mudança real do início e da ordem no projeto. |
| Importar várias fontes e ver prévia | Seletor permite múltiplos TTF/OTF. Importação sequencial preserva o índice e continua após falha individual. Cada linha mostra o texto da camada na respectiva fonte. | Dois arquivos reais importados e um inválido; primeira fonte aplicada e ambas disponíveis. |
| Linhas centrais vermelhas | Guias horizontal e vertical ao selecionar a camada, com espessura constante na tela. | Pintura das duas linhas no centro da composição e ausência após desmarcar. Guias pertencem ao palco de edição, não à composição exportada. |
| Interface com itens repetidos | Subir/descer ficam na faixa direta e saem do menu Mais. Cabeçalhos repetidos nas folhas de fonte/exportação removidos. | Regressão de navegação, ferramentas, retorno e seleção. O relato genérico não especifica todos os controles dos quais os testadores falavam. |
| Rodapé de projeto vazio cortado | Altura reservada aumentada para acomodar texto e chamada de mídia. | Botão e mensagem cabem em 320×568; tocar abre o seletor. |
| Pedido do efeito de pixelar | Efeito existente Mosaico passa a aparecer como Pixelar (Mosaico), pesquisável por pixelar/pixelizar. | Shader produz blocos quadrados, distingue blocos vizinhos e preserva orientação e alfa. |
| SVG não exporta corretamente | Seletor nativo de salvar recebe os bytes, nome sanitizado e extensão. Cancelamento não é sucesso. SVG inclui escala X/Y, giro, pivô, opacidade, presença temporal e posições amostradas; intervalos SMIL começam em 0 e terminam em 1. Traços abertos permanecem abertos e mantêm terminação/junção. | Gravação real em arquivo temporário, releitura pelo importador, correspondência dos bytes, cancelamento, escala não uniforme, giro, alfa, keyTimes e camada oculta. |
| Teclado não fecha | Texto tem botão de recolher, ação Concluído e fechamento ao tocar fora. Voltar recolhe o teclado antes de sair do painel. | Campo recebe texto e perde foco pelo botão. |

## Evidência

- Regressão consolidada: **117 testes aprovados**, em `tmp/beta-regression.log`.
- Testes novos: `test/beta_reports_test.dart` e o caso de pixelização em `test/pixel_effect_engine_test.dart`.
- Regressões existentes incluem mídia importada, desenho livre entre projetos, keyframes visíveis, curvas, efeitos, layout responsivo e edição de câmera/objeto no Scene 3D.
- Análise estática: nenhum erro/aviso; uma informação de import redundante preexistente em `qualidade3d_controller.dart`.
- Captura revisada da grade, guias e faixa de ações: `output/am-redesign-56/camada.png`.

## Limites de validação

O seletor de arquivos foi simulado nos testes; os bytes e o arquivo salvo foram verificados no computador. A interface nativa de Arquivos/Galeria e o teclado ainda precisam de teste na nova compilação em iPhone e Android físicos.

SVG continua sendo uma saída de formas vetoriais. Texto, imagens, grupos, Scene 3D, máscaras, gradientes e efeitos de pixels não ganharam equivalência integral com a prévia nesta correção. Caminhos são aproximados por segmentos e animações são amostradas com teto de 1.800 intervalos. Um projeto sem formas exportáveis agora informa o problema em vez de salvar um SVG vazio.

Não foi gerado IPA/APK nesta rodada. Os testes não demonstram estabilidade da GPU em hardware móvel nem reprodução de milhares de efeitos a 60 fps.
