# A linha do tempo: dois modos e o contrato de gestos

A linha do tempo tem dois modos, e eles respondem a perguntas diferentes.
Nenhum substitui o outro.

| | **Detalhado** | **Geral** |
| --- | --- | --- |
| Responde | "o que acontece NESTA camada?" | "como as camadas se arrumam no tempo?" |
| Mostra | uma trilha, alta | todas, baixas |
| Keyframes | losangos, manipuláveis | riscos, só de leitura |
| Edita | sim | não |

O **geral é uma vista, não um editor**. Nele não se arrasta keyframe, não
se apara, não se reordena. Quem quer mexer volta ao detalhado — e o
caminho de volta é o mesmo botão que trouxe, sempre na primeira posição
do transporte.

O modo vive **só na sessão**. Sair do editor volta ao detalhado, que é
onde se edita. Guardar a escolha em disco seria migração de dados.

## O cabeçote não anda

Desde a medição do Alight Motion real (`docs/linha-do-tempo-alight.md`),
os dois modos compartilham o mesmo `MapaDoTempo`, e nele:

- a **escala é constante** — um segundo ocupa sempre o mesmo tanto de
  tela, seja qual for a duração do projeto;
- o **cabeçote fica preso no meio da largura** e não se move;
- **quem anda é o conteúdo**, deslizando por baixo dele.

Por isso arrastar para o lado é navegar no tempo, e o mesmo arrasto
funciona na régua e nas trilhas. Beliscar aproxima e afasta, mas **só na
régua**: nas trilhas o belisco brigaria com a rolagem vertical da lista
de camadas, e quem perderia seria a rolagem. O botão **Enquadrar**, no
transporte, devolve a escala que faz a composição inteira caber.

## Contrato de gestos

### Modo detalhado

| Gesto | O que faz |
| --- | --- |
| Toque num losango | leva o cabeçote **em cima** daquele keyframe |
| Arraste a partir de um losango | move a marca no tempo, presa à camada |
| Toque longo num losango | apaga a marca |
| Toque fora de um losango | leva o cabeçote ao instante daquele pixel |
| Arraste fora de um losango | desliza o conteúdo, e com ele o tempo |
| Toque nas setas | troca a camada selecionada |
| Toque na pílula (olho) | esconde ou mostra a camada |

**Durante o arrasto de um keyframe o cabeçote fica parado**, e só alcança
a marca quando o dedo solta. Com o cabeçote preso no meio, segui-la a
cada passo significaria rolar o conteúdo — e a marca fugiria do dedo,
saltando para o centro a cada quadro.

Um losango só responde ao arrasto e ao toque longo quando **tudo** que há
naquele instante é transformação. Marca de efeito, máscara ou módulo não
se move: cada uma guarda o tempo do seu jeito, e mover metade das marcas
de um instante seria pior que não mover.

### Modo geral

| Gesto | O que faz |
| --- | --- |
| Toque numa trilha | seleciona aquela camada |
| Toque na trilha **já selecionada** | abre as ferramentas daquela camada |
| Toque na pílula (olho) | esconde ou mostra aquela camada |
| Toque na régua | leva o cabeçote ao instante daquele pixel |
| Arraste na régua ou nas trilhas | desliza o conteúdo, e com ele o tempo |
| Belisco na régua | aproxima e afasta a escala |
| Arraste vertical nas trilhas | rola a lista de camadas |
| Arraste na alça da direita | muda a camada de lugar na pilha |
| Toque no `+` redondo | abre o menu de adicionar |

O segundo toque abria o modo detalhado até a faixa "Ferramentas da
camada" ser removida do rodapé. O modo já tem botão próprio no cabeçalho;
quem ficou sem caminho foi as ferramentas, e por isso são elas que herdam
o gesto.

**Não há toque duplo**, e isso é decisão, não esquecimento. Um
`onDoubleTap` obriga o Flutter a segurar todo toque simples por uns
trezentos milissegundos esperando o segundo — e o toque simples é o gesto
mais comum desta vista. Trocar trezentos milissegundos de atraso em cada
seleção por um atalho é um mau negócio. O primeiro toque escolhe, o
segundo entra: mesma economia de gesto, sem atraso nenhum.

**Toque e arrasto não brigam.** Nas trilhas, o toque seleciona e o
arrasto horizontal navega: a arena de gestos separa os dois pela direção
do primeiro movimento, e o dedo parado nunca vira arrasto. O toque na
régua continua levando o cabeçote — lá não há o que selecionar.

**A pílula ganha do toque de seleção**, porque ela é desenhada por cima:
esconder uma camada não pode, de quebra, selecioná-la.

## Como o pouso do dedo é lido

Escolher um keyframe depende de saber onde o dedo **pousou**, e nenhum
retorno de gesto do Flutter entrega isso a tempo:

- `onTapDown` **não dispara** quando o dedo sai andando logo — o toque é
  rejeitado antes do prazo dele;
- `onHorizontalDragStart` só chega depois de uns dezoito pixels, e já com
  a posição **nova**.

Quem arrastasse rápido perdia a marca e acabava navegando no tempo sem
querer. A solução é um `Listener` no `onPointerDown` cru, que chega no
instante do pouso e **não entra na arena de gestos** — então não rouba o
toque das setas, que ficam por cima.

`onPanDown` foi tentado e descartado: ele entra na arena e as setas
pararam de funcionar.

## Estados vazios

| Situação | O que aparece |
| --- | --- |
| Projeto sem camadas (qualquer modo) | "Nenhuma camada neste projeto ainda." |
| Detalhado, camadas existem, nenhuma selecionada | "Nenhuma camada selecionada. Abra a visão geral para escolher uma." |
| Geral, nenhuma camada selecionada | a pilha aparece normalmente, sem destaque |

Uma trilha vazia sem explicação parece defeito. Dizer o que falta — e
onde resolver — custa duas linhas.

## A alça de ordem

Três riscos na ponta direita de cada trilha, presos na borda da tela —
como na referência. Arrastá-los para cima ou para baixo muda a camada de
lugar na pilha.

**A pilha só se reorganiza quando o dedo solta.** Durante o arrasto o
retorno é uma linha de destino desenhada, e nada mais. Mexer a cada
degrau daria retorno imediato, mas cada degrau viraria um lance de
desfazer: arrastar cinco linhas custaria cinco toques para voltar.

Ela só escuta arrasto **vertical**. O horizontal atravessa para quem está
atrás e continua navegando no tempo, como em qualquer outro ponto da
pilha.

## O que este pacote não faz

Mover camada no tempo, aparar pontas, dividir, efeitos, e migração de
dados. Fora a ordem e a visibilidade, o geral **lê** o projeto — e as
duas coisas que ele escreve são comandos que já existiam
(`reorderLayer`, `toggleHidden`).
