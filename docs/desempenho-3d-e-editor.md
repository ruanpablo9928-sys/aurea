# Desempenho: medir, achar o gargalo, corrigir, medir de novo

Este documento é o registro da missão P0 de otimização. Ele segue a
ordem que a missão pediu — **primeiro medir**, depois achar o gargalo,
depois otimizar, depois medir de novo — e guarda os números, para que a
próxima pessoa não precise adivinhar.

Nenhuma das correções abaixo reduziu resolução, qualidade de textura,
contagem de polígonos ou sombra. Todas atacaram trabalho **desperdiçado**.

## As bancadas

| Bancada | O que mede | Rodar |
|---|---|---|
| `test/bancada_pipeline3d_test.dart` | O custo de CPU do pipeline 3D por quadro: transformação dos nós, escolha da malha, material por face, montagem dos buffers da GPU e o pintor de reserva. | `flutter test test/bancada_pipeline3d_test.dart` |
| `test/bancada_editor_test.dart` | O custo de um quadro do **editor**: parado, tocando, arrastando; e o palco e a linha do tempo isolados. | `flutter test test/bancada_editor_test.dart` |

As duas rodam sem aparelho e sem GPU: elas medem o trabalho de
**processador** que acontece antes de qualquer pixel — que é onde as
travadas relatadas nasciam. Os números abaixo são deste PC; um iPhone 13
é mais lento neste tipo de trabalho, então a ordem de grandeza importa
mais que o valor absoluto.

O perfilador (`lib/src/features/editor/application/perfil3d.dart`) mede
fases e conta alocações; desligado, custa um `if`.

## Gargalo 1 — as vistas fixas desenhavam no processador

**Como apareceu.** A bancada do pipeline mediu o pintor de reserva
(`renderScene`), o caminho que não usa GPU:

| cena | nós | faces | pintor de CPU |
|---|---|---|---|
| 1 objeto simples | 1 | 192 | 6,3 ms |
| 5 objetos médios | 5 | 3.840 | 14,8 ms |
| 20 objetos médios | 20 | 15.360 | 18,9 ms |
| 50 objetos médios | 50 | 38.400 | **44,0 ms** |
| 5 objetos pesados | 5 | 34.560 | 41,9 ms |

**A causa.** `Scene3DGpuView` mandava para esse pintor toda câmera
ortográfica:

```dart
if (!_pronto || widget.renderCamera.orthographic) { ...pintor de CPU... }
```

E **todas** as vistas fixas do Estúdio — Frente, Trás, Esquerda,
Direita, Topo, Baixo — são ortográficas (`vistaDe` monta
`orthographic: true`). Ou seja: trocar de vista tirava a cena da GPU e a
jogava no processador. Não era qualidade, não era o modelo: era a vista.

**A correção.** `camera_ortografica.dart`: uma lente ortográfica de
verdade para o motor (ele aceita qualquer `CameraProjection`), com o
mesmo enquadramento do pintor — `orthoScale` continua sendo pixel por
unidade, provado em `test/camera_ortografica_test.dart`. As vistas fixas
passaram a desenhar pela GPU, e o pintor voltou a ser o que era: reserva.

**Depois.** O caminho de 6–44 ms por quadro deixou de ser usado nas
vistas fixas.

## Gargalo 2 — o objeto parado alocava a cena inteira, todo quadro

**Como apareceu.** Com o perfilador ligado, numa cena de 20 objetos
médios:

```
sincronia.malha       0,32 ms/quadro
alocacao.materiais    15.360 /quadro
alocacao.normais       8.500 /quadro
```

Vinte e três mil objetos por quadro, jogados fora no quadro seguinte —
só para concluir que nada tinha mudado. Isso quase não aparece na média
do tempo de quadro; aparece como **engasgo**, quando o coletor de lixo
passa. Era o "stutter mesmo com FPS bom" que a missão descreve.

**A causa.** Montar a fonte da malha de um nó alocava, a cada quadro,
uma lista de normais por vértice e uma de material por face — mesmo com
o objeto parado, a malha idêntica e o material idêntico.

**A correção.** `fonte_de_malha.dart` (`CacheDeMalhas`): a malha de cada
nó fica guardada e só é refeita quando o que a define muda — outra
malha, outro material, outro quadro do modelo. Um objeto parado passou a
custar uma comparação de identidade.

**Antes e depois**, mesma cena (20 objetos, 40 quadros):

| | antes | depois |
|---|---|---|
| tempo da fase | 0,32 ms/quadro | **0,11 ms/quadro** |
| materiais alocados | 15.360 /quadro | **384 /quadro** (só o 1º quadro) |
| normais alocadas | 8.500 /quadro | **213 /quadro** |
| malhas remontadas | 20 /quadro | **0,5 /quadro** |

Quarenta vezes menos lixo por quadro, sem tirar nada da tela.

## Gargalo 3 — achar o pai era uma varredura

`resolveNodeTransform` sobe a cadeia de pais uma vez por nó, por quadro,
e `nodeById` percorria a lista inteira: numa cena de cinquenta objetos
pendurados, cinquenta vezes cinquenta consultas por quadro. Agora há um
índice por id, montado na primeira busca e preso à cena por identidade
(ela tem construtor `const`, então o mapa mora fora do objeto).

## Gargalo 4 — a linha do tempo, e não o palco

O relato foi que o lag também acontece **fora** da cena 3D. A bancada do
editor separou as partes, com o relógio andando:

| | parado | tocando | arrastando |
|---|---|---|---|
| editor inteiro (4 camadas) | 0,1 ms | 11,4 ms | 2,9 ms |
| editor inteiro (24 camadas) | 0,1 ms | 12,7 ms | 3,6 ms |
| **só o palco** (24 camadas) | — | 5,2 ms | — |
| **só a linha do tempo** (12 camadas) | — | 6,3 ms | — |
| **linha do tempo sem rolar** | — | **0,5 ms** | — |

A última linha é a prova: a mesma linha do tempo, com o mesmo relógio
andando, custa 6,3 ms quando rola atrás do cabeçote e **0,5 ms quando
não rola**. São ~5,8 ms por quadro — mais de um terço do orçamento de 60
fps — gastos pela rolagem automática, e não por pintura: as quatro
pinturas da timeline (régua, batidas, barra, frente) somam menos de
0,1 ms por quadro, medidas uma a uma.

O custo está no **layout**: cada `jumpTo` muda o deslocamento do
viewport, e o conteúdo tem a largura do projeto inteiro. Além disso, a
primeira montagem da linha do tempo custa 120–140 ms — o engasgo de
abrir o editor.

**Isto está medido e diagnosticado, e ainda não corrigido**: a correção
mexe no modelo de rolagem da timeline (ou trocar o conteúdo largo por
uma lista preguiçosa, ou mover o cabeçote em vez do conteúdo), e as duas
mudam comportamento visível. É a próxima parada, e agora com número para
comparar antes e depois.

## O painel de desempenho

`hud_desempenho.dart` — só em build de desenvolvimento (`kDebugMode` ou
`--dart-define=AUREA_HUD=true`), no canto do Estúdio 3D:

```
FPS 58   quadro 17.1 ms
PIOR 29.4 ms   perdidos 3
CPU 7.2   GPU 9.4 ms
gpu  840K tri  142 chamadas  28 tex
RAM 1420 MB
```

Um toque liga o detalhe por fase (e o perfilador junto); um toque longo
zera as contas. O **pior quadro** aparece em destaque de propósito: uma
cena a 60 fps com um engasgo de 90 ms incomoda mais que uma a 30 fps
constantes, e a média esconde isso.

## O que ainda não foi feito (com o porquê)

- **A rolagem da linha do tempo** (gargalo 4): medida, não corrigida.
- **Instanciação e agrupamento por material**: o motor já faz uma
  chamada por material por nó; juntar nós que compartilham material
  precisa de medição de draw calls no aparelho — o HUD agora mostra esse
  número.
- **LOD por distância**: existe LOD por nível (alto/médio/baixo) e pela
  receita de qualidade, mas não pela distância da câmera.
- **Occlusion culling**: não implementado de propósito — sem medir que
  a economia de GPU paga o custo de CPU, ele piora mais do que ajuda.
- **Compilação de shader no primeiro quadro**: `Scene3DGpu.preparar()`
  já carrega o motor antes, mas falta medir o primeiro quadro no
  aparelho.
