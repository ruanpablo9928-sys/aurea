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

| Recusado | Motivo | Onde |
| --- | --- | --- |
| Draco | `KHR_draco_mesh_compression` não suportado | importador |
| Meshopt | `EXT_meshopt_compression` não suportado | importador |
| KTX2 / BasisU | `KHR_texture_basisu` não suportado | importador |
| GLB com cauda | tamanho declarado ≠ tamanho do arquivo | importador |

Draco e meshopt são o padrão de fato de qualquer glTF otimizado para a
web — Sketchfab, Poly, a maioria dos exportadores com "compress". KTX2 é
o formato de textura que existe justamente para **não** estourar memória
em celular. São exatamente os arquivos que o usuário baixa e tenta abrir.

O caso da cauda é mais cruel porque a mensagem culpa o arquivo: um GLB
íntegro, com dezesseis bytes sobrando no fim, é recusado como
"incompleto". Ler os blocos até o fim declarado e ignorar o resto abriria
esse arquivo sem afrouxar nada.

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

### 3. A memória estoura no heap do Dart, não na GPU

| Asset | Arquivo | Heap estimado | Multiplicador |
| --- | ---: | ---: | ---: |
| Pesado (250k tri) | 6.9 MB | 45.7 MB | 6,6× |
| Complexo (60 materiais) | 0.1 MB | 35.2 MB | 350× |
| Textura 2048² | 4.0 MB | 10.8 MB | 2,7× |
| Textura 4096² | 16.0 MB | **42.8 MB** | 2,7× |

Duas causas, ambas nossas:

**Geometria em `List<double>` com boxing.** O formato interno guarda
posições, normais e UVs como listas de `double` do Dart, não como
`Float32List`. `ModelAsset3D.estimatedBytes` cobra **320 bytes por
vértice** — contra 32 bytes num buffer tipado. **Dez vezes.**

**Textura como texto.** O importador converte a imagem para um data URI
em base64 e guarda numa `String`. Base64 acrescenta um terço; a `String`
do Dart usa dois bytes por caractere. Resultado: **2,67× o arquivo**, e a
tabela confirma — 16 MB de PNG viram 42,7 MB de String.

Uma textura 8K seguiria a mesma conta: ~64 MB de arquivo → ~171 MB de
heap, mais 64 MB do GLB que a ponte fabrica. **235 MB para uma textura**,
antes de a GPU existir. Num iPhone 13 isso é o app fechado, e o culpado
aparente é o renderizador.

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

1. **Aceitar GLB com cauda.** Ler blocos até o fim declarado, ignorar o
   resto. Uma condição.
2. **Trocar `List<double>` por `Float32List`/`Uint32List`** no formato
   interno. Corta a memória de geometria por dez.
3. **Guardar textura como bytes, não como base64.** Corta a memória de
   textura por 2,7 e some com a re-codificação.
4. **Levar skin, animação e morph pela ponte** (`JOINTS_0`, `WEIGHTS_0`,
   `skins`, `animations`, `targets`) e incluir o tempo na chave de cache.
   Devolve animação de modelo importado, que hoje simplesmente não existe.
5. **Levar os mapas PBR** (normal, AO, metal-rugosidade, emissivo). O
   Filament já sabe usá-los.
6. **Draco e meshopt.** São decodificadores bem definidos; dá para
   implementar ou vendorizar só o decodificador, sem trocar de motor.
7. **KTX2/BasisU** por último — é o mais trabalhoso e o que mais devolve
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
