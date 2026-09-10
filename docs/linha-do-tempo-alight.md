# A linha do tempo, medida no Alight Motion real

Este documento existe porque a interface anterior foi desenhada por
descrição — "parecido com o Alight" — e errou o que mais importava. As
medidas abaixo saíram de uma **gravação de tela do editor em uso**
(27 s, 576×1024, 30 fps), quadro a quadro, com contas e não com o olho.
Onde o código deste repositório se afasta delas, o comentário no código
diz por quê.

## Como as medidas foram tiradas

Os quadros foram extraídos a 1 fps com o ffmpeg embutido do
`imageio_ffmpeg` e medidos com um perfil por linha (média RGB de cada
linha da imagem) para achar as fronteiras entre as faixas, e por busca
de pixels para achar marcas e cores.

O vídeo tem 576 px de largura para a largura inteira da tela. Assumindo
um aparelho de 1080 px a 3× — o caso comum —, **1 px lógico = 1,6 px de
quadro**. Todas as medidas abaixo já estão convertidas para px lógicos.

A altura NÃO pode ser convertida em proporção da tela: o vídeo é um
corte central de uma captura mais alta (a barra de status e a de
navegação foram cortadas). Por isso as alturas valem como valores
absolutos, e não como fração.

## As quatro faixas

| faixa      | quadro (px) | lógico (px) | o que tem dentro                          |
|------------|-------------|-------------|-------------------------------------------|
| cabeçalho  | 0–74        | 46          | `<`, nome, engrenagem, botão verde        |
| prévia     | 74–632      | 349         | composição centrada, fundo mais escuro    |
| transporte | 632–683     | 32          | 7 ícones dividindo a largura              |
| régua      | 683–753     | 44          | barra de rolagem, marcas, cápsula         |
| trilhas    | 753–…       | passo 30    | clipes de 26 px, pílulas flutuando        |

A composição ocupa **toda a altura** da faixa de prévia e é centrada na
horizontal — o vazio fica nas laterais, nunca em cima ou embaixo.

## O transporte

Sete alvos dividindo a largura, nesta ordem: desfazer, refazer, ir ao
início, play/pause, ir ao fim, duplicar, enquadrar. Ícones finos,
brancos, o de play do mesmo tamanho dos outros.

**O Aurea usa 48 px, e não 32.** Quarenta e oito é o piso de alvo
tocável, e há um teste que cobra isso. Dezesseis pixels a mais numa tela
de setecentos é barato; um toque errado no controle que a mão mais
repete, não.

## A régua

De cima para baixo, dentro dos 44 px:

- **barra de rolagem** — y 2 a 6, 4 px de altura, cinza `#606068`,
  cantos arredondados. Mostra que pedaço da composição está à vista;
- **marcas** — começam em y 10 e descem. Duas alturas alternadas: 9 px
  na marca do passo e 5 px na do meio-passo. Na gravação o passo era
  1 s (21,8 px de quadro = 13,6 lógicos) e o meio-passo 0,5 s;
- **cápsula do tempo** — y 21 a 37, 16 px de altura, ~70 px de largura,
  fundo `#242430`, dígitos brancos em negrito, formato `mm:ss:qq` com
  **quadros** na terceira casa (00:24:12). Fica centrada no cabeçote.

**Sem números na régua.** A gravação não tem nenhum: a cápsula já diz o
instante exato, e dígitos pequenos em toda marca só enchem a faixa.

### As marcas rosa

Além da grade cinza regular, a gravação mostra linhas magenta altas
(25 px) em posições **irregulares** — 12, 21, 41, 56, 82, 115, 137, 166,
197, 214 px de quadro, sem passo constante. Não são escala de tempo: são
marcadores de batida, uma função do Alight que o Aurea não tem. Por isso
não foram copiadas. Copiar a aparência de uma função que não existe
seria desenhar uma promessa falsa.

## As trilhas

- **passo de 30 px** por camada, com o clipe ocupando 26 e 4 de respiro;
- clipe com cantos de raio ~5, cor cheia, nome em branco pequeno dentro
  dele, cortado com reticências;
- **a pílula da camada flutua por cima do começo da faixa**, não ocupa
  coluna própria: 62 px de largura, altura de ~24, formato de cápsula,
  fundo `#242436`, com o olho à esquerda e a identidade da camada à
  direita. O clipe passa POR BAIXO dela — dá para ver o nome do mp3
  sendo comido pela pílula conforme o tempo anda;
- na referência a identidade é uma **miniatura renderizada** da camada
  (ou uma nota musical, no áudio). O Aurea usa um quadradinho da cor do
  tipo: a maior parte das camadas daqui (texto, forma, cena 3D) não tem
  quadro para miniaturar, e gerar miniatura de vídeo custa caro no
  aparelho.

## O que muda tudo: o cabeçote não anda

Medido: o clipe de áudio recuou **21 px de quadro por segundo** de
reprodução (bordas em 391 → 370 → 349 nos quadros f024, f025 e f026),
enquanto o cabeçote ficou parado em x = 287 de 576 — **o centro exato da
largura**.

Ou seja: a escala é constante (13,1 px lógicos por segundo naquele
projeto), o cabeçote é fixo no meio, e **quem se move é o conteúdo**.

Isso não é detalhe visual, é o modelo inteiro. A linha do tempo anterior
do Aurea espremia a composição inteira na largura (`x = largura · t /
duração`), o que significa que:

- um clipe de 2 s num projeto de 3 min virava um risco de 4 px;
- a mesma camada mudava de tamanho na tela porque OUTRA camada esticou a
  duração do projeto;
- não havia como aproximar para trabalhar num trecho.

O `MapaDoTempo` implementa o modelo medido. A escala inicial é a que faz
a composição caber; a partir daí o belisco na régua muda, e o botão
"enquadrar" volta.

## Cores medidas

| onde                         | valor     |
|------------------------------|-----------|
| fundo atrás da composição    | `#121218` |
| cromo (cabeçalho, transporte, linha do tempo) | `#18181E` |
| pílula da camada             | `#242436` |
| cápsula do tempo             | `#242430` |
| barra de rolagem / marcas    | `#606068` |
| cabeçote                     | branco    |

O verde do botão de exportar da referência **não** foi copiado. O Aurea
usa o lima da própria logo no mesmo lugar e com o mesmo peso visual:
estrutura, medida e comportamento se aprendem; identidade, não.
