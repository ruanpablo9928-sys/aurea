# O que mudou no Aurea — beta 76

## Edição mais fácil

- A parte de baixo tem mais espaço para editar.
- A prévia mantém o tamanho quando você seleciona uma camada ou abre ferramentas.
- Os botões de transformação e o editor de curvas cabem melhor em celulares pequenos.
- Foram retirados da régua os botões de ímã, busca, entrada e saída pedidos pelos testadores.
- O painel completo de formas voltou, com cantos individuais, traço, desenho e pontos.
- Toque no número de um canto para digitar o valor: ele altera somente aquele canto.
- A linha vermelha ajuda a alinhar o objeto pelo painel de movimento e some quando você solta.
- O botão de adicionar ganhou uma identificação acessível.

## Prévia, vídeos e animação

- Agora há Full, 1/2, 1/4 e 1/8 no canto da prévia. As opções menores aliviam a renderização dos efeitos e do 3D, sem diminuir a resolução do vídeo exportado.
- O vídeo reverso liga ao tocar. A preparação que ajuda a deixá-lo mais rápido acontece em segundo plano.
- As curvas de velocidade preservam os ajustes feitos com as alças, inclusive depois de salvar e abrir o projeto.
- Adicionar um keyframe de velocidade grava a marca no tempo certo do clipe.
- Abrir o painel de velocidade não muda sozinho o projeto.
- Congelar um trecho mantém o quadro parado; inverter preserva os tempos da curva.
- O campo Z foi liberado para imagens. Editá-lo ativa a profundidade e continua permitindo desfazer.

## Scene 3D

- Corrigida a tela vermelha causada por certas luzes direcionais.
- A visão pela câmera respeita a proporção do projeto e mostra a borda do quadro.
- Os modelos são lidos fora da interface, reduzindo bloqueios durante a importação.
- Foram retiradas opções e partes de objetos que mostravam nomes sem corresponder ao que realmente existia.
- Os erros de importação são informados e o painel não fecha como se tivesse dado certo.
- Os controles de posição, materiais e animação usam os dados reais do objeto.
- O gráfico mostra os keyframes reais, permite escolher o eixo, adicionar, excluir e abrir a curva.
- Os ajustes da câmera atingem a câmera escolhida e o instante em edição.
- É possível escolher cada luz separadamente, inclusive quando há várias do mesmo tipo.
- Intensidade, cone da luz spot e iluminação ambiente têm controles próprios funcionando.
- Vincular uma camada não altera sem querer o vínculo separado da câmera.

## Galeria, áudio e exportação

- Corrigida uma falha ao carregar miniaturas depois de atualizar a galeria. O carregamento de álbuns e fotos foi conferido no Android.
- Corrigido o modulador de áudio, que podia gerar valores inválidos e atrapalhar o processamento.
- A exportação voltou a usar a composição real do editor. O caminho novo e incompleto do motor nativo não é mais escolhido automaticamente.
- Resolução, FPS e formato escolhidos no Scene 3D chegam corretamente à exportação.
- A opção de imagens está identificada como sequência PNG.
- Foram adicionadas verificações internas para impedir o uso de ponteiros ou dimensões inválidos no motor nativo.
- O aviso ao abrir o aplicativo resume as novidades desta versão.

## Sobre a mesclagem

Os modos mostrados pelos betas foram conferidos por comparação de pixels. Uma forma branca em **Clarear** cobre a imagem; em **Escurecer** deixa a imagem abaixo aparecer. Esse resultado é esperado. A explicação no painel foi melhorada.

## O que ainda precisa de atenção

Esta é uma versão beta. A auditoria geral ainda tem 90 falhas de teste pendentes de revisão, e nem todas foram classificadas como testes antigos ou problemas reais. Os novos testes das correções acima passaram. Ainda falta validação em iPhone físico e testes prolongados de desempenho; não há garantia de que qualquer modelo pesado rode sem travar em todo celular.

O IPA é sem assinatura, para instalação com uma ferramenta como Sideloadly. Os APKs são builds release para teste, usando a assinatura Android de desenvolvimento já configurada no projeto.
