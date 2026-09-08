# Trocar o Filament? — a auditoria antes da decisão

**Resposta curta: ainda não, e a evidência é forte.** Dos quatro modelos
que não abrem na bancada, **nenhum chega ao Filament** — todos são
recusados pelo nosso importador. Dos dois que estouram memória, **nenhum
gasta memória de GPU** — o custo está no heap do Dart, antes de qualquer
textura subir. E o esqueleto do personagem chega ao formato interno e é
**descartado pela nossa própria ponte** antes de virar GLB.

Trocar o renderizador hoje moveria o último elo de uma corrente que
arrebenta nos dois primeiros.

A tabela crua está em [`motor3d-auditoria.md`](motor3d-auditoria.md),
gerada por `test/motor3d_auditoria_test.dart` — reproduzível, mesmo byte
toda vez.

## A corrente

```
arquivo  →  IMPORTADOR  →  formato interno  →  PONTE GLB  →  Filament
             (nosso)         (nosso)            (nosso)
```

`scene_glb.dart:encodeNodeGlb` **reescreve um GLB novo** a partir do
nosso formato interno. O Filament nunca vê o arquivo da pessoa. Isso
significa que a compatibilidade do aplicativo é, por construção, a
compatibilidade do nosso importador **interseccionada com** a do nosso
escritor — e o escritor é o elo mais estreito de todos.

## O que a bancada mostrou

### 1. Quatro em quatorze não abrem, e o Filament não foi consultado

| Recusado | Motivo | Onde | Situação |
| --- | --- | --- | --- |
| Draco | `KHR_draco_mesh_compression` | importador | aberto |
| Meshopt | `EXT_meshopt_compression` | importador | aberto |
| KTX2 / BasisU | `KHR_texture_basisu` | importador | aberto |
| GLB com cauda | tamanho declarado ≠ arquivo | importador | **corrigido** |

Draco e meshopt são o padrão de fato de qualquer glTF otimizado para a
web — Sketchfab, Poly, a maioria dos exportadores com "compress". KTX2 é
o formato de textura que existe justamente para **não** estourar memória
em celular. São exatamente os arquivos que o usuário baixa e tenta abrir.

O caso da cauda era o mais cruel porque a mensagem culpava o arquivo: um
GLB íntegro, com dezesseis bytes sobrando no fim, recusado como
"incompleto". **Corrigido**: leio os blocos até o fim declarado e ignoro
o resto, e o alinhamento de bloco passou a ser problema de quem escreve,
não de quem lê. O contrário — cabeçalho que promete mais bytes do que o
arquivo tem — continua recusado, porque aí a quebra é real.

### 2. A ponte descarta esqueleto, animação e morph — em 100% dos casos

O personagem rigado importa com **1 esqueleto e 1 clipe**. A coluna
"Esq. na ponte" e "Anim. na ponte" dá **não** em todas as quatorze
linhas, sem exceção.

`encodeNodeGlb` escreve apenas `POSITION`, `NORMAL`, `TEXCOORD_0`,
índices e material. Não escreve `JOINTS_0`, `WEIGHTS_0`, `skins`,
`animations`, `targets`, `TANGENT`, `COLOR_0` nem `TEXCOORD_1`.

Pior: a chave de cache da geometria (`_geometryKey`) não inclui o tempo, e
`encodeNodeGlb` avalia sempre em `Duration.zero`. **Um modelo animado
fica congelado no primeiro quadro na GPU** — que é exatamente o
"esqueleto sai explodido / pose crua" que já estava anotado.

Nenhuma troca de motor conserta isso. O Filament carrega glTF com skin e
animação nativamente; nós é que não mandamos.

### 3. A memória: o que era, e o que ficou

A primeira leitura desta auditoria acusou o dobro do custo real de
textura, e um custo de geometria que já não existia. As duas coisas
foram corrigidas — a segunda pelo Codex, antes de eu chegar. Os números
de agora:

| Asset | Arquivo | Heap antes | Heap depois |
| --- | ---: | ---: | ---: |
| Pesado (250k tri) | 6.9 MB | 45.7 MB | **13.9 MB** |
| Complexo (60 materiais) | 0.1 MB | 35.2 MB | **10.6 MB** |
| Médio (50k tri) | 1.4 MB | 9.1 MB | **2.8 MB** |
| Textura 4096² | 16.0 MB | 42.8 MB | **21.4 MB** |

**Geometria: já estava resolvida.** `PackedModelVectors` guarda os
vetores contíguos num `Float64List` e continua sendo uma `List<double>`
para quem lê — a correção certa, feita no lugar certo. O que sobrava era
a ESTIMATIVA: `estimatedBytes` ainda cobrava 320 bytes por vértice, a
medida da época do boxing, treze vezes o real. Ela alimenta o orçamento
que escolhe o nível de qualidade, então o exagero **rebaixava a cena por
memória que ninguém estava usando**. Agora a conta pergunta ao próprio
buffer quanto ele ocupa.

**Textura: a metade do que eu disse.** O data URI em base64 é ASCII, e a
máquina virtual guarda texto ASCII em um byte por caractere, não dois. O
custo real é 1,33× o arquivo, não 2,67×. Corrigi a conta do app e a da
bancada.

Ainda assim, uma 4K custa **21 MB de heap mais 16 MB** do GLB que a ponte
fabrica: 37 MB para uma textura, antes de a GPU existir. Guardar os bytes
em vez do texto em base64 elimina os dois de uma vez — é o próximo passo
de memória, e o de melhor retorno.

### 4. A ponte custa quase meio segundo por nó

424 ms para re-codificar o modelo pesado, 377 ms para o de 60 materiais —
num desktop. É trabalho puro de CPU num isolate, então não trava a
interface, mas é o tempo entre "importei" e "apareceu", e num celular
multiplica.

### 5. PBR é só cor-base

O importador avisa: *"Mapas normal/oclusão/metal-rugosidade/emissivo não
são aplicados"*. O Filament faz PBR completo; o que falta é a nossa
ponte carregar os mapas. A queixa de "qualidade gráfica" tem endereço, e
não é o motor.

## O que isso significa para a decisão

Os critérios que o pedido define, com os pesos dados:

| Critério | Peso | Onde está o problema hoje |
| --- | ---: | --- |
| Estabilidade | 30% | heap do Dart (importador), não GPU |
| Compatibilidade de assets | 25% | importador + ponte, não GPU |
| Qualidade gráfica | 15% | ponte (mapas PBR não enviados) |
| Performance | 15% | ponte (re-codificação) + heap |
| Memória | 10% | importador (boxing + base64) |
| Integração | 5% | já existe (`Renderer3D`) |

**85% do peso está em camadas nossas.** Trocar o backend endereça, no
melhor caso, os 15% restantes — e ainda assim só se o novo backend for
alimentado por um pipeline melhor, que teríamos de escrever de qualquer
jeito.

## As alternativas, honestamente

O pedido manda investigar Godot, bgfx, wgpu, Unity e Unreal. Não tenho
como rodar benchmark real de nenhuma delas aqui: exigiria um protótipo
por engine, integrado ao app, medido em aparelho. Prometer números que
não medi seria o oposto do que a auditoria serve. O que dá para dizer com
segurança é o que cada caminho **implica**, e o que faltaria medir.

**Godot (RenderingDevice / renderer Mobile).** Vulkan e Metal, feito para
celular, e um importador de glTF maduro — que é justamente a peça que nos
falta. O custo é embutir um runtime de engine dentro de um app Flutter:
tamanho do APK, tempo de partida, duas árvores de cena a manter em
sincronia e um ciclo de vida próprio. Para um editor de vídeo isso é
carregar uma game engine inteira para usar o importador dela.

**bgfx.** Camada fina sobre Vulkan/Metal/GL, madura e leve — mas é
**só o backend de desenho**. Não traz importador, nem materiais, nem
animação. Trocar Filament por bgfx significa escrever à mão exatamente
tudo o que a auditoria mostrou que falta. Move o problema, não resolve.

**wgpu.** Mesma observação que bgfx quanto a escopo, com a diferença de
ser Rust: ganharíamos uma cadeia de build a mais em duas plataformas.

**Unity / Unreal.** Não são adotáveis como biblioteca dentro de um app
Flutter sem virar o app do avesso — e o pedido já diz que não queremos
transformar o editor numa game engine. Como referência técnica, o que
elas ensinam é justamente a arquitetura que o pedido descreve: um
**formato interno normalizado** entre o importador e o renderizador. Nós
temos esse formato; ele é que está pobre.

O ponto que fecha o argumento: **um motor novo não abriria os quatro
arquivos que hoje não abrem**, porque quem os recusa é o nosso
importador, e o novo motor receberia o mesmo GLB empobrecido que a ponte
fabrica.

## O que eu proponho

Na ordem, do que dá mais resultado por linha de código:

**Feito nesta passagem:**

1. ~~Aceitar GLB com cauda~~ — **feito**. Um recusado a menos.
2. ~~Buffers tipados na geometria~~ — **já estava feito** pelo Codex
   (`PackedModelVectors`).
3. ~~Corrigir a estimativa de memória~~ — **feito**. Era treze vezes o
   real na geometria e o dobro na textura, e é ela que decide o nível de
   qualidade da cena.

**A seguir, nesta ordem:**

4. **Draco e meshopt.** É o que mais devolve em compatibilidade: são o
   padrão de fato do glTF otimizado, e hoje são um "não abre" seco. São
   decodificadores bem definidos — dá para implementar sem trocar de
   motor. Meshopt primeiro, que é bem menor que Draco.
5. **Guardar textura como bytes**, não como base64 numa `String`. Tira
   21 MB de heap e 16 MB de re-codificação por textura 4K.
6. **Levar skin, animação e morph pela ponte** (`JOINTS_0`, `WEIGHTS_0`,
   `skins`, `animations`, `targets`) e incluir o tempo na chave de cache.
   Devolve animação de modelo importado, que hoje simplesmente não
   existe. É a mudança mais funda da lista e merece uma passagem própria.
7. **Levar os mapas PBR** (normal, AO, metal-rugosidade, emissivo). O
   Filament já sabe usá-los.
8. **KTX2/BasisU** por último — o mais trabalhoso, e o que mais devolve
   em memória de GPU.

Cada item desses é verificável pela mesma bancada: a tabela muda, e a
mudança é a prova.

## Só então, se ainda doer

Se depois de 1–5 os assets reais continuarem quebrando, aí sim o
protótipo de backend se justifica — e a arquitetura para isso **já
existe**: `Renderer3D` em
`lib/src/features/editor/application/renderer3d/renderer3d.dart` é a
interface que o pedido descreve, com o editor falando só com ela. Um
segundo backend entra ao lado do Filament, atrás de um interruptor de
build interna, exatamente como o pedido manda.

## O que falta medir, e precisa de aparelho

Isto a bancada não alcança, e não vou estimar:

- memória de GPU e de texturas por asset;
- FPS e tempo de quadro no iPhone 13 e num Android de referência;
- o teste de abrir/fechar o mesmo modelo **100 vezes** procurando
  crescimento de memória;
- comportamento sob pressão térmica;
- o teste definitivo do pedido: os modelos **reais** que hoje travam.

Este último é o mais valioso e o mais barato: mande os arquivos que
quebram. A bancada aceita arquivo de verdade no lugar dos sintéticos, e
aí a tabela deixa de falar de casos que eu inventei e passa a falar dos
seus.
