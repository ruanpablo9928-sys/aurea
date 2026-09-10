# O painel de transformação e efeitos, medido no Alight Motion real

Seis capturas do editor em uso (iPhone, 1179×2556 físicos → 393 px
lógicos de largura). As medidas abaixo já estão convertidas para px
lógicos: **1 px lógico = 1,88 px da captura**.

Este documento é a **especificação de implementação**. Onde ele e o
código discordarem, o código está errado.

## A regra que muda tudo: não há deslizante

A versão anterior do Aurea usava `Slider` para tudo. A referência **não
tem um único deslizante**. Ela tem quatro superfícies, e cada uma existe
por um motivo:

| Superfície | Onde aparece | Por quê |
| --- | --- | --- |
| **Almofada** (pad 2D) | mover | posição é 2D; dois deslizantes separados obrigam a pensar em eixos |
| **Dial** | girar | ângulo é circular; uma barra reta mente sobre o que é 0° e 360° |
| **Fita** (jog) | escalar, inclinar, parâmetro de efeito | valor sem limite natural: a fita é **relativa e infinita**, o deslizante é absoluto e limitado |
| **Campo** | todos, no topo | ler e digitar o número exato |

Um deslizante tem começo e fim. Escala, posição e a maioria dos
parâmetros de efeito **não têm** — e quando têm, o limite é arbitrário.
A fita resolve isso: ela não mostra "onde no intervalo", mostra "quanto
andou", e por isso funciona igual para 0–1 e para 0–4000.

## Estrutura do painel

Os três painéis (transformação, efeitos, curva) compartilham a moldura:

```
┌──────┬────────────────────────────────────┬──────┐
│ rail │            miolo                   │ rail │
│ esq. │                                    │ dir. │
│ 46px │                                    │ 40px │
└──────┴────────────────────────────────────┴──────┘
```

- **Rail esquerdo** (46 px), sempre: `‹` voltar · `◇` keyframe ·
  `∿` curva. O `◇` e o `∿` ficam apagados quando não há o que marcar
  ou curvar.
- **Rail direito** (40 px), só na transformação: os quatro modos,
  empilhados, o vigente aceso em verde.
- **Miolo**: os campos de valor no topo, e a superfície embaixo.

Altura do painel: **260 px**. O cabeçalho da tela troca de título junto
(`Movimentação e…`, `Efeitos`, `Curva de gradação`) e o `‹` do cabeçalho
volta para a linha do tempo.

## Os quatro modos de transformação

O rail direito, de cima para baixo:

| Ícone | Modo | Campos no topo | Superfície |
| --- | --- | --- | --- |
| ✥ | Mover | `X` `Y` `Z` | almofada 2D |
| ⟳ | Girar | — | dial com o ângulo no centro |
| ⤢ | Escalar | `Largura` 🔗 `Altura` | fita horizontal |
| ▱ | Inclinar | `X Skew` `Y Skew` | duas fitas empilhadas |

### Campos de valor

Caixa de cantos arredondados (raio 8), fundo `#242436`, **número em
verde/teal sublinhado**, rótulo minúsculo embaixo em cinza. Altura 24,
largura 61. Formato pt-BR: vírgula decimal, uma casa (`540,0`), duas nos
ângulos de inclinação (`0,00°`).

O campo é **tocável**: abre o teclado para digitar o valor exato.

Entre Largura e Altura há um **botão de corrente** (🔗): ligado, os dois
andam juntos; desligado, cada um por si.

### A almofada (mover)

Área grande com **quatro cantos em L** marcando o retângulo e o texto
`Deslize aqui para mover a camada` no centro. Arrastar o dedo move a
camada — **relativo**, 1 px de dedo = 1 px de composição na escala 1.

O texto some enquanto o dedo está na almofada.

### O dial (girar)

Círculo de contorno fino ocupando a altura do miolo, com:
- o valor no centro, dentro de uma caixa arredondada (`0°`, em verde);
- um **botão branco** de raio 15 na borda do círculo, na posição do
  ângulo.

Arrastar o botão gira. O ângulo cresce no sentido horário, e **não
enrola**: passar de 360° continua em 361°, porque duas voltas é uma
animação diferente de meia volta.

### A fita (escalar, inclinar, efeito)

Faixa de **linhas verticais finas** de 1 px, espaçadas 9 px, cinza a 25%.
No centro, uma linha de 2 px:

- **verde** (`#1ED6B1`) quando a fita é a que está sendo editada;
- **branca** quando é a outra do par (inclinação Y, por exemplo).

Arrastar horizontalmente muda o valor de forma **relativa**: cada pixel
de dedo vale um passo. O passo sai da faixa do parâmetro, para que
atravessar a fita inteira dê o intervalo útil sem exigir dez arrastos.

As linhas **rolam com o valor** — é isso que diz que algo está mudando
quando o número é grande demais para o olho acompanhar.

## O painel de efeitos

Cartão por efeito:

```
▼ Brilho de luz                       •••   🗑
┌─────────┐  ┃┃┃┃┃┃│┃┃┃┃┃┃   ┌────────┐
│ Difusão │  fita                     │  0,250 │
└─────────┘                  └────────┘
[ Limite ]   fita             [ 0,700 ]
[Intensidade] fita            [  1,00 ]
[ Cor ]      ▼          255 85 102  ■
```

- título com `▼` para recolher, `•••` para o menu e `🗑` para tirar;
- cada parâmetro é uma **linha de três partes**: chip com o rótulo à
  esquerda, fita no meio, caixa de valor à direita;
- o chip do parâmetro **em edição** fica com fundo escuro e o texto verde
  sublinhado;
- parâmetro de cor mostra os três números RGB e uma **amostra** clicável.

O cabeçote fica **rosa** nesta tela, e a cápsula do tempo ganha contorno
rosa: é o sinal de que o que se está editando pertence àquele instante.

## O editor de curva

```
┌────┬──────────────────────────┬────┬──────┐
│ ‹  │  grade tracejada         │ ▱  │ ▣    │
│    │  curva verde, dois       │ ▱  │      │
│ ⇄  │  botões brancos grandes  │ ▱  │PROVAR│
│••• │                          │ ▱  │PROVAR│
│    │ ‹ Efeito Ease de Cúbico-Bezier ›     │
└────┴──────────────────────────┴────┴──────┘
```

- grade **tracejada**, e não contínua;
- a curva é verde, grossa (3 px), com **pontos verdes** nas duas pontas;
- os dois pontos de controle são **círculos brancos de raio 18** — alvos
  grandes, porque é um gesto de precisão num dedo;
- linha ligando cada ponta ao seu ponto de controle;
- embaixo, o nome da curva entre setas `‹ ›` — trocar de preset sem
  soltar o dedo da região;
- rail à direita: **miniaturas dos presets**, cada uma desenhando a
  própria curva numa caixa tracejada; a vigente com borda verde.

## O navegador de camada, na linha do tempo

Uma **pílula branca** flutuando sobre a trilha:

```
( ‹  [Círculo 1]  › )
```

- fundo branco, cantos totalmente arredondados;
- o nome da camada num chip ciano;
- `‹` e `›` pretos nas pontas trocam de camada.

É o que substitui as duas setas cinzas nas bordas da faixa.

## Cores

| onde | valor |
| --- | --- |
| campo de valor / chip | `#242436` |
| número do campo | verde `#1ED6B1`, sublinhado |
| rótulo do campo | `#8B94A3`, 9 px |
| linha da fita | `#8B94A3` a 25% |
| centro da fita, ativo | `#1ED6B1` |
| centro da fita, par | branco |
| modo aceso (rail direito) | `#1ED6B1` sobre `#242436` |
| cabeçote em efeitos | rosa `#FF6B6B` |
