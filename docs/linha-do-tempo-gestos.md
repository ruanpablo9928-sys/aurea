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

## Contrato de gestos

### Modo detalhado

| Gesto | O que faz |
| --- | --- |
| Toque num losango | leva o cabeçote **em cima** daquele keyframe |
| Arraste a partir de um losango | move a marca no tempo, presa à camada |
| Toque longo num losango | apaga a marca |
| Toque fora de um losango | leva o cabeçote |
| Arraste fora de um losango | leva o cabeçote |
| Toque nas setas `‹ ›` | troca a camada selecionada |
| Toque no olho | esconde ou mostra a camada |

Um losango só responde ao arrasto e ao toque longo quando **tudo** que há
naquele instante é transformação. Marca de efeito, máscara ou módulo não
se move: cada uma guarda o tempo do seu jeito, e mover metade das marcas
de um instante seria pior que não mover.

### Modo geral

| Gesto | O que faz |
| --- | --- |
| Toque numa trilha | seleciona aquela camada |
| Toque na trilha **já selecionada** | abre no modo detalhado |
| Toque no olho da linha | esconde ou mostra aquela camada |
| Toque na régua | leva o cabeçote |
| Arraste na régua | leva o cabeçote |

**Não há toque duplo**, e isso é decisão, não esquecimento. Um
`onDoubleTap` obriga o Flutter a segurar todo toque simples por uns
trezentos milissegundos esperando o segundo — e o toque simples é o gesto
mais comum desta vista. Trocar trezentos milissegundos de atraso em cada
seleção por um atalho é um mau negócio. O primeiro toque escolhe, o
segundo entra: mesma economia de gesto, sem atraso nenhum.

A régua é a **única** parte que mexe no cabeçote — no toque e no arrasto.
Nas trilhas, o toque seleciona. Se as duas coisas dividissem a mesma área, uma roubaria
a outra — e a que perderia seria a seleção, que é o motivo de a vista
existir.

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

## O que este pacote não faz

Reordenar camadas, mover camada no tempo, aparar pontas, dividir,
efeitos, e migração de dados. O geral lê o projeto e escreve **apenas**
seleção e visibilidade, que são comandos que já existiam.
