# O Estúdio da Cena 3D

> Redesenho de **interação**, 2026-09-10. O motor não muda; muda o
> caminho até ele. O inventário do que existe está em
> [`motor-3d-inventario.md`](motor-3d-inventario.md) — 860 recursos,
> **701 sem uma única porta na tela** quando este trabalho começou.

## O diagnóstico

A Cena 3D não é difícil de usar. Ela é **inalcançável**.

O estúdio 3D foi apagado inteiro junto com a UI antiga (`7fe26b6`) e
nunca voltou. O que sobrou é um cartão de 468 linhas com oito botões —
vista, lente, câmeras, rigs, enquadrar. Fora dele:

- `addScene3DLayer` cria uma cena **vazia**, e não existe caminho
  nenhum na tela para pôr um objeto dentro dela;
- os três comandos de luz (`addSceneLight`, `updateSceneLight`,
  `removeSceneLight`) não têm **um** chamador no repositório inteiro,
  nem em teste;
- o material PBR (18 campos, 12 presets prontos) tem **zero** controles;
- as 31 trilhas animáveis da cena não têm losango, nem curva, nem
  trilha na linha do tempo;
- `orbitCamera`, `panCamera`, `dollyCamera` e `resolveTouch` existem,
  estão testados, e **ninguém os chama**: navegar a cena com o dedo não
  existe no app.

O domínio do estúdio (`domain/estudio_ux.dart`) sobreviveu inteiro —
encaixe na grade, eixo travado, as quatro ferramentas, a hierarquia, a
busca, as vistas, as dicas. Falta só a apresentação.

## A regra do desenho

```
ESSENCIAL     sempre na tela, sem toque nenhum
CONTEXTUAL    aparece quando há seleção
AVANÇADO      atrás de um toque nomeado, nunca atrás de quatro
```

E a pergunta que decide cada tela:

> **A ação mais comum está a no máximo dois toques?**

## A forma

Uma tela inteira, empurrada como rota (o mesmo caminho da exportação).
A viewport é o elemento principal — nunca encolhe para caber painel.

```
┌──────────────────────────────────────────┐
│ ←  Cena          Câmera ▾           ⋮    │  52
├──────────────────────────────────────────┤
│                                          │
│               VIEWPORT                    │
│  ⟲                            ◉ Focar    │  o resto
│                                          │
├──────────────────────────────────────────┤
│  Cubo · Mover Girar Escalar Animar Mais  │  48   com seleção
├──────────────────────────────────────────┤
│ Selecionar │ Mover │ Girar │ Escalar │ + │  62
└──────────────────────────────────────────┘
```

### Os três níveis, item a item

| nível | o que fica | onde |
|---|---|---|
| essencial | voltar, câmera em uso, viewport, as quatro ferramentas, `+` | barra de cima e de baixo |
| contextual | o nome do selecionado e as ações dele | faixa que só existe com seleção |
| avançado | mundo, render, vistas, encaixe, eixo, mini-vista, ficha completa | `⋮` e o botão `Mais` |

Nada importante mora em `Menu → Mais → Avançado → Ajustes`. O caminho
mais fundo do estúdio tem **dois** toques.

## Os gestos

Herdados do estúdio antigo, onde já tinham sido acertados:

```
dedo sobre o objeto selecionado  → move o objeto (com uma ferramenta)
dedo sobre outro objeto          → seleciona ele E já arrasta
dedo em área vazia               → ORBITA a câmera
dois dedos                       → deslizam
pinça                            → aproxima (move no Z; NUNCA mexe na lente)
toque duplo num objeto           → enquadra
toque duplo no vazio             → enquadra a cena inteira
toque longo                      → entra/sai da seleção múltipla
```

A ferramenta **Selecionar** é o modo de navegar: um dedo sempre gira, o
toque sempre escolhe.

E, como o pedido exige: **não depender só de gesto**. Toda navegação
tem botão — o gizmo de vista (seis faces), `Focar`, `Enquadrar tudo`,
e as vistas fixas.

## O keyframe continua explícito

A regra de [`keyframe-explicito.md`](keyframe-explicito.md) vale igual
na cena 3D:

```
ALTERAR VALOR  ≠  CRIAR KEYFRAME
```

Arrastar um objeto no viewport **não** crava marca. Cada linha da ficha
tem o seu `◇`, e é só ele que crava. Fora de uma marca, o valor fica
**pendente** — a prévia mostra, a linha do tempo não muda.

Isto exigiu comandos novos, tipados, para as 31 trilhas da cena: até
hoje o único caminho era `updateSceneNode` com uma função crua, que
escrevia por cima do que quisesse.

## Dois defeitos que o levantamento achou

- `setCameraFocalLength` escrevia `AnimatedDouble(v)` **cru**: mexer na
  lente apagava os keyframes de lente que o rig "Dolly zoom" tinha
  acabado de criar — e o controle de lente já estava na tela.
- `frameBounds` fazia o mesmo com a distância de foco.

## O que o estúdio NÃO faz

Registrado para não parecer esquecimento:

- **Não** mexe no renderizador, no orçamento de qualidade nem na
  composição. Os ajustes de qualidade continuam onde estavam
  (Ajustes → Qualidade 3D), e o estúdio só os mostra.
- **Não** cria um segundo sistema de curvas: `Gráfico` abre o editor de
  curva que já existe.
- **Não** inventa recurso que o motor não tem. Onde o inventário diz
  "campo salvo que nenhum renderizador lê" (`normalStrength`,
  `packedChannels`, `textureLayerId`, `autoOrient`, `dof.lockToZoom`),
  o estúdio não finge que funciona.
