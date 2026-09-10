# Keyframe explícito

> Decisão do dono do produto, 2026-09-10. Vale acima de qualquer
> convenção, inclusive a do After Effects.

## A regra

**Nenhuma edição de valor cria keyframe.**

Keyframe só nasce, muda de tempo ou morre por **comando explícito**: o
losango do rail, um gesto na linha do tempo, ou uma ação nomeada.

A regra mental que a interface tem de ensinar:

```
SEM BOTÃO DE KEYFRAME → SEM NOVO KEYFRAME
COM BOTÃO DE KEYFRAME → CRIA OU ATUALIZA KEYFRAME
```

## O que estava errado

Não era o interruptor "Keyframe automático" — ele já nascia desligado.
Era a raiz, em `domain/keyframe.dart`:

```dart
/// Editar = keyframe automatico se a propriedade ja anima (comportamento AE).
AnimatedDouble edited(Duration t, double v) =>
    isAnimated ? withKeyframe(t, v, easeAt(t)) : withBase(v);
```

Toda propriedade **já animada** cravava um keyframe sozinha a cada
mudança de valor, em qualquer instante, sem depender de interruptor
nenhum — e sem nenhum sinal na tela. Arrastar uma fita por um segundo
podia deixar uma dúzia de marcas que ninguém pediu.

O mesmo padrão existia em `AnimatedOffset.edited` e em
`AnimatedPath.edited`, e o caminho passava por 36 pontos de chamada.

E havia um segundo, pior: `EffectInstance.withParamEdited`. Num efeito
que já animasse, mexer em **um** parâmetro em **qualquer** instante
cravava a marca universal ali — *todos* os parâmetros de uma vez, num
tempo que ninguém escolheu.

Havia ainda o caso da **âncora**: com o automático ligado, uma trilha
ainda estática ganhava um keyframe em ZERO além do do instante atual —
dois de uma vez, um deles num tempo que a pessoa nunca visitou.

## Os três estados de uma propriedade

Só existem três. Nada de estado intermediário.

| estado | o que é | como se lê na tela |
|---|---|---|
| **Estática** | um valor, sem marca nenhuma | o número, e o losango vazado `◇` |
| **Animada, sobre um keyframe** | o cabeçote está em cima de uma marca | o número, e o losango cheio `●` |
| **Animada, fora de um keyframe** | o valor vem da interpolação | o número interpolado, e o `◇` |

## O que cada gesto faz

### Propriedade estática

Mudar o valor muda **a base**. Nenhum keyframe. Nunca.

### Propriedade animada, cabeçote SOBRE um keyframe

Mudar o valor **atualiza aquele keyframe**. Não cria um segundo, não
duplica. Tocar no `●` **remove** a marca.

### Propriedade animada, cabeçote FORA de um keyframe

Este é o caso que decidiu o desenho. Mudar o valor entra como
**edição pendente**:

- a **prévia** já mostra o valor novo;
- a **linha do tempo não muda** — nenhuma marca nasce;
- o `◇` **crava** o que estiver na tela, naquele instante;
- sair daquele tempo, ou mexer noutra propriedade, **descarta**.

É o único desenho que atende as duas frases do pedido ao mesmo tempo —
"alterar a propriedade temporariamente, mas não inventar um keyframe" e
"definir valor → adicionar keyframe" — sem mentir sobre o que está
gravado.

### Como isso funciona por dentro

A edição pendente guarda o projeto **derivado** — o que o projeto seria
se a marca tivesse sido cravada. Ele nunca entra no `_mutate`, então:

- não vai para o desfazer;
- não vai para o arquivo salvo;
- não vai para a exportação.

A prévia lê `projetoVisivelProvider`, que é `pendente ?? real`. O ponto
de leitura do palco é **um só** (`palco_de_previa.dart`), e é por isso
que a opção mais fiel ao pedido acabou sendo também a mais barata de
desenhar.

### Onde isso mora, no código

Uma só peça em cada camada, e nenhum caminho paralelo:

| peça | arquivo | o que faz |
|---|---|---|
| `edited()` | `domain/keyframe.dart`, `domain/mask.dart` | recusa: devolve a trilha intacta fora de marca |
| `aceitaEdicaoEm()` | os mesmos | a pergunta que separa os três casos |
| `editada()` | `application/editor_controller.dart` | escreve **como se** houvesse marca, e **anota a recusa** |
| `_mutate` | o mesmo | vê a anotação e desvia para a pendência, em vez de gravar |
| `_cravarPendencia` | o mesmo | o `◇` grava o projeto derivado, num passo de desfazer só |
| `projetoVisivelProvider` | o mesmo | `pendente ?? real` |
| `camadaReal` | `presentation/widgets/rails_do_painel.dart` | o rail lê o projeto de verdade |

Todas as 36 edições de valor do controlador passam por `editada`, e
todo losango passa por `_cravarPendencia`. Não há uma segunda porta.

A pendência morre quando:

- o `◇` a crava;
- o cabeçote anda (inclusive tocando) — o ouvinte está em
  `editor_screen.dart`, no `playback.time`;
- a pessoa muda de foco: camada, categoria, modo, efeito, máscara,
  parâmetro ou cor — a lista de `ref.listen` está na mesma tela;
- qualquer edição de verdade entra pelo `_mutate` — senão a pendência
  seria um retrato de um projeto que não existe mais.

O `◇` só crava a pendência **da camada dele, naquele instante**. Fora
disso ele faz o que sempre fez — e a pendência morre junto, porque
cravar é uma edição de verdade.

## Keyframes GERADOS

Escolher "Subir" no catálogo de animação de texto, tocar em "Criar a
cena do rastreio" ou aplicar um rig de câmera **são** comandos
explícitos. Os keyframes que nascem daí são o resultado pedido, e
continuam editáveis um a um.

A regra proíbe keyframe por **edição de valor**, não por ação nomeada.

## O que a interface não pode fazer

- Não mostrar "quase animada". Ou tem marca, ou não tem.
- Não criar marca invisível, em nenhum instante — inclusive no zero.
- Não deixar o `◇` mentir: ele diz o que o toque vai fazer, sempre.
- Não deixar o auto-keyframe voltar como padrão. Se um dia voltar como
  recurso, nasce desligado, é anunciado enquanto está ligado, e sai com
  um toque.

## Movimento e cópia

Arrastar uma marca muda **só o tempo**. O valor não se mexe.

Copiar preserva valor, relação de tempo, interpolação e alças.

Aplicar curva (Linear, Suave, Acelerar, Desacelerar, Mola, Quicar) muda
**a interpolação entre marcas existentes**, e não cria nenhuma.

O editor de curva **nunca** cria marca: ele só edita a curva das que já
existem.

## O que NÃO existe (e por isso não foi testado como se existisse)

Três itens do relatório não têm porta no app. Nenhum deles cria
keyframe escondido — eles simplesmente não estão lá:

- **Copiar e colar keyframe.** Não há método, gesto nem menu. O que
  existe é *arrastar* uma marca, e é sobre ele que o TESTE 7 cobra a
  mesma promessa: valor, relação de tempo, interpolação e alças ficam
  de pé.
- **Editar no palco.** As alças de mover, escalar e girar saíram com a
  UI antiga (está escrito no cabeçalho de `palco_de_previa.dart`). O
  caminho que um arrasto no palco usaria — `editPosition` e companhia —
  já obedece à regra.
- **Movimento de câmera e de cena 3D.** `editCameraMotion` e
  `editMotionValue` não têm nenhum chamador em `presentation/`. A regra
  já vale neles (e há teste), mas ninguém os alcança pela tela.
