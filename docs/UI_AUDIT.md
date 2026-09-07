# UI_AUDIT — Auditoria da interface do editor (Fase 0)

Data: 2026-09-07 · Base: commit `55062f3` na branch `codex/beta-media-ui-45` · Versão do app: 1.4.10+50 (beta 50).

Este documento responde à Fase 0 do `PROMPT_CLAUDE_CODE.md`: o que o app usa de stack, como o motor expõe o modelo, onde a UI está acoplada a ele, a árvore de navegação atual, o inventário de 100% das funcionalidades com o caminho e a contagem de toques de cada uma, e os problemas de UX por gravidade. O plano de redesign está em `UI_REDESIGN_PLAN.md`.

O que foi lido para escrever isto: as 34 capturas de `design-reference/` (13 do Alight Motion, 11 do Blurrr, 10 do Node Video), o `README.md` delas, o PDF `Pesquisa_UI_Editores_Mobile.pdf` (26 páginas), o código de `lib/` (220 arquivos, 123.456 linhas), os 174 arquivos de teste, e os 17 documentos de `docs/`. Três varreduras independentes do código (navegação, inventário do controlador, arquitetura) foram cruzadas entre si; os números abaixo são os delas.

---

## 1. Stack (não inventar nada: é isto que existe)

| Item | Valor |
|---|---|
| Framework | Flutter **3.47.2** stable, Dart `^3.13.2`. SDK em cópia local (`.tooling/flutter`, junction `C:\Users\SnyX\.aurea\flutter`). Sem FVM. |
| Estado | **Riverpod 2.6** sem codegen. `editorControllerProvider` (`NotifierProvider<EditorController, VideoProject>`), `selectedLayerProvider`, `multiSelectProvider`, `autoKeyframeProvider`, `debugOverlayProvider`, `freehandRequestProvider`, `onionSkinProvider`, `sharedPreferencesProvider`, `projectsControllerProvider`, `settingsControllerProvider`. |
| Estado fora do Riverpod | `PlaybackController` (`ValueNotifier` de tempo/tocando/loop, estático `tocandoAgora`), `PreviewStats` (estáticos), `RecentSheets.instance`, `GlobalKey`s `paramSheetHostKey` e `previewStageKey`, singletons de 3D/preferências carregados no `main()`. |
| Navegação | Imperativa: `MaterialApp(home: HomeShell)` + `Navigator.push(MaterialPageRoute)` em 14 lugares. Sem rotas nomeadas, sem `go_router`. **Painéis de parâmetro não são rotas**: são bottom sheets persistentes hospedadas no `Scaffold` do editor (`showParamSheet`, `am_widgets.dart:137`). |
| Tema | Material 3 com estética iOS forçada (`NoSplash`, transições Cupertino nas duas plataformas, tipografia SF-like). **Dois sistemas de cor coexistem**: `AppColors` (marca: fundo `#12151A`, lima `#B8FF3D`, violeta `#7C62FF`) nas telas de projeto/ajustes, e `AmColors` (editor: fundo `#191A1C`, acento teal `#1ED6B1`, playhead coral `#FF6B6B`) no editor. Só tema escuro. |
| Cores por tipo de camada | Já existem: `am/layer_look.dart` (`layerTypeColor`, `layerTypeStripe`, `layerTypeIcon`) para os 12 tipos. Usadas na timeline; **não** usadas no menu de adicionar nem no cabeçalho do painel. |
| Build / testes | `flutter test` puro, 1.466 casos verdes hoje. Convenções: tamanhos reais de tela (iPhone SE 375×667, 13 390×844, 15 Pro Max 430×932), `ProviderContainer` + `UncontrolledProviderScope`, testes de pixel via `CompositionView` + `toImage`. **Dois testes leem o código-fonte como texto** (`ui_1011_test.dart`, `nivel10_1_ui_final_test.dart`). Lints: só `flutter_lints` padrão. Nenhum workflow de CI roda testes. |
| Distribuição | APK `--split-per-abi` (Moto G05) e IPA por tag `ipa-*` na conta `ueeruan` (iPhone 13). Sem emulador. |

---

## 2. Como o motor expõe o modelo (o que a UI lê e escreve)

Tudo está em `lib/src/features/editor/domain/` e é imutável (cada edição devolve um objeto novo; o controlador troca o estado e empilha o undo).

**Projeto** — `VideoProject` (`video_project.dart:92`): `layers` (índice 0 = camada de cima), `links` (vínculos/pickwhip), `markers`, `beats`/`bpm`, `guides`, `motionBlur`, `palette`, `textStyles`, `exposed`, `aspectRatio`, `fps`, `resolutionHeight`. A duração é derivada (fim da última camada, piso de 5 s). **Não existe cor de fundo da composição.**

**Camada** — `sealed class Layer` (`layer.dart:29`) com 12 subclasses: Video, Image, Text, Shape, Group (precomp), Caption, Audio, Null, Particles, Element3D, Scene3D, Adjustment. Base: `position` (AnimatedOffset), `scaleX/scaleY`, `rotation`, `rotationX/Y`, `opacity`, `skewX/Y`, `pivot`, `positionZ`, `blendMode`, `customBlend`, `is3D`, `effects[]`, `masks[]`, `matteMode`, `startTime`, `duration`. Derivados prontos: `keyframeTimes`, `positionTimesUs` … `maskTimesUs`, `hasAnimation`, `activeAt`, `localTime`.

**Keyframes** — `AnimatedDouble` / `AnimatedOffset` (`keyframe.dart:451`, `:660`): `base`, `keyframes` (ordenada, imutável), `loop`, `expression`; `valueAt(t)` é o único ponto de leitura; `withKeyframe`, `withoutKeyframe`, `edited` (auto-key AE), `easeAt`, `withEase`, `withEaseAll`, `hasKeyframeAt` (tolerância 8 ms). `Easing` (`:21`): 8 tipos (bezier, bounce, elastic, cyclic, random, steps, elasticSteps, spring), 14 presets, `speedAt` para o gráfico. `LoopSpec`: 5 modos. Modelo Alight: N keyframes = N−1 curvas, a curva pertence ao segmento que sai do keyframe.

**Efeitos** — `effect.dart`: 47 `EffectType` com `EffectSpec` (id estável, parâmetros tipados `number/color/point/choice/seed/toggle`, categoria, sinônimos, custo). **Três profundidades** `EffectDepth { pronto, montar, avancado }` (pronto = 3 presets; montar = até 3 números com nome humano; avançado = ficha inteira). `EffectInstance.withParamEdited` = keyframe universal (um diamante por efeito). Só **11 dos 47** efeitos têm `montar`/`presets` preenchidos.

**Máscaras e recorte** — `mask.dart`: `LayerMask` (7 modos, feather X/Y, expansão, opacidade, caminho animado), 7 presets de revelar, `MatteMode` (5).

**Vínculos e parenting** — `PropertyLink` (`video_project.dart:17`) para posição/escala/rotação/opacidade/skew/pivô/pai, com `delay` e base do pai no instante do vínculo. `effectiveTransform` (`:372`) resolve a cadeia inteira com perspectiva (focal 1200). `depthSortPaintOrder` ordena vizinhas 3D por Z.

**Formas** — `shape.dart`: árvore vetorial (`ShapeItem`), 5 geometrias paramétricas, 7 operadores de caminho, Trim Paths, Repeater, Merge, morph. Biblioteca de 30 formas (`shape_library.dart`).

**Texto** — `TextLayer` com `fontSize`, `bold`, `fontFamily`, `TextPathSpec`, 35 animações de catálogo (`text_anim.dart`) e animadores modelo AE com seletores (`text_animator.dart`, 973 linhas).

**Áudio** — `AudioSpec` (ganho, fades, mudo, ducking, normalização LUFS, `AudioProcessing` de voz), batidas, `voice_ops.dart` (compressor, de-esser, EQ).

**3D** — `scene3d.dart` (grafo de nós, materiais PBR, luzes, ambiente), `camera3d.dart` (câmeras, `lookAtNodeId`, DOF, tomadas/cortes), `Element3DLayer` (14 sólidos), partículas.

**Serialização** — `project_store.dart` (2.786 linhas): `projectToJson/projectFromJson`, migrações de versão de efeito embutidas. Um JSON por projeto, escrita atômica.

**Controlador** — `EditorController` (`editor_controller.dart`, 6.152 linhas, ~321 membros públicos): undo/redo com coalescência de 450 ms, `beginGesture/endGesture` (um gesto = um passo), `runAsOneUndo`. É a única porta de escrita.

---

## 3. Onde a UI está acoplada ao motor

Regra do prompt: o motor não muda. Os pontos abaixo são lógica de domínio ou de render que hoje mora na apresentação; a UI nova precisa de um adaptador para cada um, não de uma cópia.

| Onde | O que faz | O que o adaptador precisa expor |
|---|---|---|
| `widgets/preview_stage.dart` (4.735 linhas) | `CompositionView` (`:775`) é **o render de verdade** e é reusado pela exportação (`export_video_screen.dart:561`). `_buildLayer` (`:1504`) resolve links, parenting, grid rig, perspectiva, skew, pivô, máscaras — com matemática duplicada de `effectiveTransform` e a focal 1200 repetida três vezes. | Não tocar. A UI nova só substitui o `PreviewStage` (gestos e escala do palco, ~250 linhas: `:112-256`) e continua montando `CompositionView`. |
| `preview_stage.dart:129-224` | Gestos do palco: pinça, rotação, arrasto com trava de eixo e encaixe contra bordas/centros de todas as camadas e guias. | `StageGestures` (view-model): `beginTransformGesture`, `applyDrag` com `snapCandidates`, `stageToComp/compToStage`. |
| `preview_stage.dart:281-292` | Política de raster do preview (1080 tocando / 2160 parado) injetada como `devicePixelRatio`. | Manter como está (função pura em `preview_raster.dart`). |
| `am/am_timeline.dart` (1.860 linhas) | `_timeToPx/_pxToTime`, zoom por pinça, `_snap` contra marcas/batidas/bordas (busca binária), `_snapMove`, `magneticProvider` (regra de edição num provider de widget), `_encaixarNasMarcas`. | `TimelineAxis` + `SnapTargets` puros em `application/`; `magneticProvider` sobe para o controlador/prefs. |
| `editor_screen.dart` | `enum _Mode` (9 modos) e `enum _HeaderKind` privados; `PlaybackController` nasce no `State` e é passado por parâmetro a 7 widgets; `_syncVideos` (sincronismo A/V) no widget; aritmética de layout crua (`workspaceHeight-100`, `lowerHeight/2`, dock `clamp(…,202)`, painel `lowerHeight-88`); `_onForeignKeyframe` descobre a propriedade dona de um keyframe e roteia. | `EditorSession` (modo, seleção, ferramenta, painel de retorno), `playbackProvider`, `EditorLayoutMetrics`, `keyframeOwner(layer, t)`. |
| `am/am_widgets.dart:110-134` | `_sheetMaxHeight` mede o `RenderBox` do palco pela `GlobalKey` para a folha nunca cobrir o preview (piso 42% da tela, mínimo 180 px). | Regra de layout fica, mas passa a ler `EditorLayoutMetrics`. |
| `am/property_keyframe_context.dart:19-70` | `keyframeTimesForProp(layer, prop)` e o texto "keyframe N de M · entre marcas" (tolerância 8000 µs fixa). | Mover para o domínio (`layer.dart`). |
| `am/layer_menu.dart:531-640` | `LayerToolsDock` e `_fileiras` consomem `secoesDe(layer)` (domínio) e calculam altura de tile. | Consumidor certo; vira `CategoryGrid`. |
| `am/scene3d_studio.dart` | Chama `resolveNodeTransform` direto do widget (pivô, gizmo, foco). | Já está separado em `estudio_ux.dart` (2026-09-07). Fica. |
| `widgets/fx_lote2.dart`, `*_painter.dart`, `blend_mask.dart`, `masked_box.dart`, `custom_blend.dart`, `dither_layer.dart` (≈11.400 linhas) | Motor de render vivendo em `presentation/widgets/`. | Não tocar. Só mudar a pasta seria refatoração de motor; fica para depois. |

Risco concreto: qualquer mudança em `CompositionView` altera o MP4 exportado e quebra ~20 testes de pixel (`render_*`, `mescla_no_palco`, `nivel3_seis_efeitos`, `export_cor`). A UI nova não passa por lá.

---

## 4. Árvore de navegação atual

`T=n` = toques a partir do estado padrão do editor (projeto aberto, nada selecionado).

### 4.1 Raiz
```
main.dart → AureaApp → HomeShell (IndexedStack + tab bar com blur)
├── Inicio   (projects_tab.dart)
│   ├── 'Novo projeto' → showNewProjectSheet (nome · proporção · resolução · fps) → EditorScreen
│   ├── 'AutoEdit' → AutoEditScreen (vídeo → estilo → ritmo → 'Abrir no editor') → EditorScreen
│   ├── 'Template' (.json/.aurea) → EditorScreen · 'Preset XML' (Alight) → diálogo → EditorScreen
│   ├── pílulas 16:9 / 9:16 / 1:1 / 4:5 → novo projeto
│   ├── Recentes (cartões; toque longo = excluir) → EditorScreen
│   ├── Modelos (12 cartões: CAMPO, FLOR, PRISMA, DERIVA, MONOLITO, COLINA, ABISMO, VHF, Dnyx, Codex, Notes, Pindown)
│   └── 'O que há de novo' · 'Próxima att' · 'Achou um problema?' (report_sheet)
├── Ajustes  (settings_tab.dart): padrões de novos projetos · salvar na galeria · Motor 3D · Qualidade 3D ·
│            teste de estresse 3D · OpenGL ES (Android) · vibração · limpar cache
├── Usuario  (perfil local, 'Editar perfil')
└── Sobre    ('Como usar o AUREA' → QuickGuideScreen · reportar · licenças)
```

### 4.2 Editor — as faixas de hoje, de cima para baixo (`editor_screen.dart:538-720`)

| Faixa | Altura | Conteúdo | Observação |
|---|---|---|---|
| A · `_TopBar` | 52 | **Quatro estados** (`_HeaderKind`): *projeto* = voltar · nome do projeto · engrenagem (overlay de diagnóstico) · **exportar**; *camada* = voltar · nome projeto + camada · vincular · grade de seções; *múltipla* = X · "N camadas" · cascata · agrupar · vincular · excluir; *painel* = voltar · título do painel. | Exportar **some** ao selecionar uma camada. Os ícones trocam de lugar por estado. |
| B · `PreviewStage` | `Expanded` (o que sobra) | `CompositionView` + guias + editor de nós + desenho livre; gestos de mover/escalar/girar com encaixe. | Sem alça de redimensionar; sem badge de qualidade; sem zoom/fit do canvas (o preview é sempre "fit"). |
| C · `_TransportBar` | 48 | desfazer · refazer · ◀◀ (marca anterior/início) · play · ▶▶ · loop · duplicar camada · casca de cebola · expandir preview. | Undo/redo aqui (não na top bar). Sem timecode tocável (o relógio fica na régua). Sem losango de keyframe. |
| D · `_ActionBar` | 44 | **só com seleção**: `+` · dividir · duplicar · subir/descer · agrupar · vincular · magnético · marca (toque longo = menu das marcas) · alinhar · contador · excluir. | Aparece e some; muda a altura da timeline. |
| E · `AmTimeline` | `lowerHeight − ações − dock` (mín. 88) | régua com marcas e batidas · relógio central · playhead fixo central · ações do cabeçote (dividir, congelar) · pílulas fixas (olho + miniatura) · barras por camada com **forma de onda e tira de miniaturas**, losangos de keyframe da propriedade ativa, alças de trim, chip de transição na junção, setas de vizinhas no modo compacto. | Modelo Alight: uma linha por camada, sem trilhas. Sem entrar em grupos. |
| F · `LayerToolsDock` | até 202 | **só com seleção**: "Ferramentas da camada" + 'Mais ações' + a grade de seções (`secoesDe`). | É o E2 de hoje. |
| G · painel do `_Mode` | `lowerHeight − 88` | um dos 8 painéis (abaixo). | Ocupa o lugar do dock + parte da timeline (timeline vira 88 px, uma linha). |
| H · FAB `+` | 48 | só sem seleção. | |
| I · `AddLayerPanel` | `lowerHeight − 38` | abas Forma · Mídia · Áudio · Objeto · Modelo + trilho (Desenho livre, Desenho vetorial, Texto, Legendas, Fechar). | Inline, não modal. |

Aritmética: `workspaceHeight = altura − 100`, `lowerHeight = workspaceHeight / 2`. O preview fica com a metade de cima sempre; não há alça.

### 4.3 Os painéis (`_Mode`) — todos na metade de baixo, nunca cobrem o preview

| Modo | Widget | Abre por | Sub-abas |
|---|---|---|---|
| `transform` | `TransformPanel` | tile 'Mover e transf.' (T=2) | trilho direito: Mover · Girar · Escalar · Inclinar · Pivô · Opacid. |
| `blending` | `BlendingPanel` | tile 'Mesclar e opacidade' (T=2) | Opacidade · Mesclagem · Máscara · Recorte por camada |
| `colorFill` | `ColorFillPanel` | tile 'Cor e preench.' (T=2) | paleta + 'Escolher qualquer cor' + Trim Paths/Repeater (forma) |
| `effects` | `EffectsPanel` | tile 'Efeitos' (T=2) | pilha de cartões + 'Adicionar efeito' (catálogo com busca/categorias, T=3) |
| `curve` | `CurvePanel` | ícone de curva no trilho de qualquer painel (T=3) | presets com miniatura, alças, copiar/colar, todos os segmentos, overshoot |
| `animators` | `TextAnimatorsPanel` | 'Animar' no menu da camada de texto (T=3) | Entrada · Ênfase · Saída (35 animações) + animadores AE |
| `editShape` | `ShapePanel` | tile 'Editar forma' / 'Borda e sombra' em forma (T=2) | Tamanho · Cantos · Pontas · Ângulo · Rotação · Traço · Desenhar · Pontos |
| `editPoints` | `PointsPanel` | 'Abrir Edit Points' (T=4) · 'Desenho vetorial' (T=2) | trackpad + mover/alça/adicionar/canto/apagar/fechar |

Casca comum: `AmPanelChrome` = trilho esquerdo (Voltar com nome · diamante · curva) + corpo com cantos em L + abas à direita.

### 4.4 Catálogo de folhas (46) — resumo

Detalhe completo (título, conteúdo, quem abre, arquivo, toques) está na tabela do inventário (§5). Folhas de **2 toques**: Exportar, menu da camada, Vincular ao pai, Alinhar, Som (Volume/Fade), Estilos de camada, Clonar (Módulo Grade), Editar legendas, Partículas, Elemento 3D, Cena 3D (ficha), Presets de efeito, Estúdio 3D, Editar texto, Transição (1). Folhas de **3 toques** (só pelas utilidades do menu modal): Velocidade, Cortes (Decupagem), Batidas, Pulsar na batida, Legendar, Reenquadrar, Estabilizar, Extrude 3D, Loop de keyframes, Organizar, Fonte, Caminho, Animar, Câmeras, Tempo (precomp), Desagrupar, Excluir e fechar, Fechar buracos, Catálogo de efeitos, Estilo da legenda, Seletor de cor. Folhas de **4 toques**: Pilha de máscaras, Edit Points pela forma, Geometria da forma, Editar nós, Curva do efeito/grid, Nome do preset, Animação de modelo 3D.

### 4.5 Estúdio 3D (rota em tela cheia, reestruturado em 2026-09-07)
`← Cena | Câmera ▾ | menu com estado` · vista com gizmo, faixa de câmeras, ações rápidas (+, Focar, Cena, desfazer, refazer), dicas (4, uma vez), barra de contexto pela seleção · linha do tempo · `Selecionar | Mover | Girar | Escalar` · modo avançado (vistas, mini-vista, grade, eixo, comandos). Folhas: adicionar, hierarquia com busca, ações do item, material/luz/lente simples com "Avançado" para a ficha completa.

---

## 5. Inventário de 100% das funcionalidades

Legenda: **T** = toques a partir do estado padrão · **Camadas** = tipos afetados · ✅ alcançável · 🟡 alcançável com problema · 🔴 existe no motor e **não tem UI** (nenhum chamador em `lib/`).

Fonte: `editor_controller.dart` (~321 membros) cruzado com `presentation/`. Contagem: **60 métodos públicos do controlador sem nenhum chamador de UI**; 2 trechos de UI mortos.

### 5.1 Projeto e composição
| Feature | Onde hoje | T | Camadas | Estado |
|---|---|---|---|---|
| Novo projeto (nome, proporção 16:9/9:16/1:1/4:5, resolução 720/1080/2160, fps 24/30/60) | `new_project_sheet.dart` | 2 (fora do editor) | — | ✅ |
| Padrões de novos projetos | Ajustes › 'Padrões de novos projetos' | — | — | ✅ |
| Alterar proporção/resolução/fps de projeto existente | — | — | — | 🔴 não existe (nem no motor) |
| Cor de fundo da composição | — | — | — | 🔴 campo não existe |
| Renomear projeto | — | — | — | 🔴 `renameProject` sem UI |
| Duração da composição | derivada da última camada | — | — | ✅ (não editável) |
| Guias e grade do palco | desenhadas e usadas no encaixe (`_GuidesPainter`) | — | — | 🔴 `setGuides`/`addGuide` sem UI |
| Motion blur do projeto (shutter, samples) | — | — | — | 🔴 `setMotionBlur` sem UI |
| Overlay de diagnóstico (marcha, RSS, comp/s) | top bar › engrenagem | 1 | — | 🟡 ocupa o lugar de "configurações do projeto" |
| Marcas: pôr/tirar | barra de ações › marca (com play andando = no ritmo); duplo toque na régua | 1–2 | — | ✅ |
| Marcas: nome, cor, mover, apagar | toque longo na marca da régua | 1 (longo) | — | 🟡 só por toque longo |
| Marcas: próxima, cortar em todas, distribuir camadas, limpar | toque longo no ícone de marca | 2 (longo) | — | 🟡 só por toque longo |
| Navegar entre marcas | transporte ◀◀ ▶▶ | 1 | — | ✅ |
| Batidas: detectar (faixa, sensibilidade, subdivisão, andamento), cortar nas batidas, limpar | menu da camada › 'Batidas' › `beats_sheet` | 3 | Audio, Video | ✅ |
| Desfazer / refazer | transporte; estúdio 3D | 1 | — | ✅ |
| Cancelar gesto em andamento | — | — | — | 🔴 `cancelGesture` só em teste |

### 5.2 Adicionar (menu `+`)
| Feature | Onde hoje | T | Camadas | Estado |
|---|---|---|---|---|
| Forma (30 da biblioteca, 2 páginas) | `+` › Forma | 2 | Shape | ✅ |
| Desenho livre / Desenho vetorial | `+` › trilho | 2 | Shape | ✅ |
| Texto | `+` › trilho 'Texto' | 2 | Text | ✅ |
| Legendas (Whisper no aparelho / SRT colado) | `+` › trilho 'Legendas' | 2 | Caption | ✅ |
| Imagem / Vídeo (galeria integrada, álbuns, acesso limitado) | `+` › Mídia | 2–3 | Image, Video | ✅ (atalhos `importVideoFromGallery`/`importImageFromGallery` do controlador não são usados) |
| Áudio (arquivo) | `+` › Áudio | 2 | Audio | ✅ (`addAudioLayer` só em teste) |
| Ícone vetorial (Iconify, busca, licença) | `+` › Objeto › 'Ícones' | 3 | Shape | ✅ (único caminho de "SVG"; não lê arquivo .svg) |
| Nulo · Grid (nulo com Clonar) · Ajuste · Partículas · Cena 3D · Câmera · Luz | `+` › Objeto | 2 | Null, Adjustment, Particles, Scene3D | ✅ (Câmera/Luz só com cena existente) |
| Elemento 3D (sólidos) | `+` › Objeto › 'Formas 3D' | 2 | Element3D | 🟡 9 dos 14 sólidos |
| Modelo pronto | `+` › Modelo | 2 | — | 🟡 aba inerte (texto "abrem pela tela inicial") |
| Importar modelo 3D (GLB/glTF/OBJ/FBX) | ficha Cena 3D › Objetos; estúdio › + › Objeto 3D | 3–4 | Scene3D | ✅ |
| Importar fonte | menu › 'Fonte' › 'Importar fonte' | 4 | Text | ✅ |
| Importar panorama / fotografar ambiente | ficha Cena 3D › Ambiente | 3 | Scene3D | ✅ |
| Importar preset Alight (XML) · Abrir template | tela Início | — | — | ✅ |
| Código morto | `showAddLayerSheet`, `_SecaoFormas` (`add_layer_sheet.dart`) | — | — | 🔴 sem chamador |

### 5.3 Camadas: seleção, ordem, estrutura
| Feature | Onde hoje | T | Camadas | Estado |
|---|---|---|---|---|
| Selecionar (barra), seleção múltipla (toque longo) | timeline | 1 | todas | ✅ |
| Selecionar vizinha | setas no modo compacto | 1 | todas | ✅ |
| Duplicar | transporte; barra de ações | 1–2 | todas | ✅ |
| Excluir (com Desfazer) | barra de ações; cabeçalho múltiplo | 2 | todas | ✅ (`removeLayer` singular sem UI) |
| Subir / descer na pilha | barra de ações; menu 'P/ frente'/'P/ trás'; arrasto vertical da barra | 2 | todas | ✅ (três entradas desde beta 50) |
| Agrupar (precomp) / Desagrupar | barra de ações · cabeçalho múltiplo / menu 'Desagrupar' | 2 / 3 | ≥2 / Group | ✅ (`groupLayer` singular sem UI) |
| Entrar num grupo (editar filhos) | — | — | Group | 🔴 não existe (sem breadcrumb; filhos só pelo desagrupar) |
| Vincular ao pai / soltar | top bar (camada); barra de ações; menu | 2 | todas | ✅ |
| Vincular seleção inteira a um alvo | cabeçalho múltiplo › link | 2 | ≥2 | ✅ |
| Cascata (escalonar seleção, ordem, vínculo com atraso, curva compartilhada) | cabeçalho múltiplo › cascata | 2 | ≥2 | ✅ |
| Alinhar / distribuir / espaço exato | barra de ações › alinhar | 2 | ≥1 | ✅ |
| Organizar: rótulo colorido, solo, tímida, bloquear | menu › 'Organizar' | 3 | todas | ✅ |
| Buscar camadas | — | — | — | 🔴 `searchLayers` sem UI (busca só na cena 3D) |
| Renomear em lote · pasta da camada | — | — | — | 🔴 `renameLayers`, `setLayerFolder` sem UI |
| Renomear uma camada | — | — | — | 🔴 sem campo de nome no editor |
| Magnético (fecha buracos ao arrastar) | barra de ações | 2 | — | ✅ (provider de UI) |
| Casca de cebola (0/1/2) | transporte | 1 | — | ✅ |
| Expandir preview | transporte | 1 | — | ✅ |

### 5.4 Timeline e montagem (NLE)
| Feature | Onde hoje | T | Camadas | Estado |
|---|---|---|---|---|
| Dividir no cabeçote | ação do playhead; barra de ações; Decupagem | 1 | todas | ✅ |
| Mover, aparar (alças), encaixe em marcas/batidas/bordas | timeline | 1 | todas | ✅ |
| Zoom da timeline (pinça) | timeline | 1 | — | ✅ |
| Congelar quadro (duração, separado/dentro) | ação do playhead; toque longo = folha | 1 | Video | ✅ |
| Transição na junção (7 tipos + 44 efeitos, duração, alinhamento, curva, áudio junto) | chip da junção | 1 | Video | ✅ (curva: só 5 easings; `setTransitionEffect`, `updateTransition`, `transitionHandleReport` sem UI) |
| Juntar pedaços (join) | toque longo na junção | 1 (longo) | Video | 🟡 sem caminho visível |
| Ripple delete · Fechar buracos | menu 'Excluir e fechar' · 'Fechar buracos'; excluir com magnético | 3 | todas | ✅ |
| Decupagem (entrada/saída, manter/remover trecho, cortar por cena/silêncio, só marcar, encostar) | menu › 'Cortes' | 3 | Video, Audio | ✅ |
| Edição de 3 pontos: inserir, sobrescrever, lift, extract | — | — | — | 🔴 `insertLayerAt`, `overwriteLayerAt`, `liftTimeRange`, `extractTimeRange` sem UI |
| Velocidade, rampas prontas (4), reverso (proxy), manter tom, time remap com keyframes, blur por velocidade | menu › 'Velocidade' | 3 | Video, Audio | ✅ (`clipHasTimeRemap`, `reverseNeedsProxy` sem chamador) |
| Estabilizar · Reenquadrar sozinho | menu | 3 | Video | ✅ (`clearStabilization` sem UI: não dá para desfazer sem undo) |

### 5.5 Transformar
| Feature | Onde hoje | T | Camadas | Estado |
|---|---|---|---|---|
| Mover (pad), Girar (dial, conta voltas), Escalar (largura/altura, vínculo), Inclinar, Pivô, Opacidade | painel Transformar (abas no trilho direito) | 2 | todas menos Audio | ✅ |
| Posição Z, rotação X/Y | painel Transformar (com 3D ligado) | 2–3 | is3D | ✅ |
| Ligar 3D · Motion blur da camada · Extrude 3D | menu | 3 | todas | ✅ (dois "Motion blur": o de Organizar não liga o interruptor da composição) |
| Manipulação direta no palco (arrastar, pinça, girar, encaixe) | preview | 1 | todas | ✅ (sem alças de canto desenhadas; caixa + encaixe) |
| Seguir a posição de… (pickwhip por propriedade) | painel Transformar › 'Vincular' | 3 | todas | ✅ |
| Auto-key, keyframe anterior/próximo, resetar propriedade | painel › menu com estado | 3 | todas | ✅ |
| Cravar/tirar keyframe | diamante do trilho | 2 | todas | ✅ |

### 5.6 Keyframes, curvas, loops, expressões
| Feature | Onde hoje | T | Camadas | Estado |
|---|---|---|---|---|
| Editor de curvas (14 presets com miniatura, alças, velocidade, copiar/colar, todos os segmentos, overshoot) | trilho › curva | 3 | todas | ✅ |
| Curvas de efeito, de forma, de grid | mesmos painéis | 3–4 | — | ✅ |
| Easing `random`, `elasticSteps`; parâmetros finos (count, smooth, intensity, response, damping, initialVelocity) | — | — | — | 🔴 sem controle |
| Loop de keyframes (5 modos) · inverter no tempo | menu › 'Loop de keyframes' | 3 | todas | ✅ (só 4 propriedades; `LoopWhen`/`count` sem UI) |
| Expressões (motor de 1.022 linhas: time, value, wiggle, seedRandom, linear/ease…) | — | — | — | 🔴 nenhuma UI |
| Campo numérico que aceita expressão ("1080/3", "50%") | — | — | — | 🔴 `evalExpression` só em teste |
| Keyframes na barra da camada (losangos) + navegação | timeline | 1 | todas | ✅ |

### 5.7 Mesclagem, opacidade, máscaras, recorte
| Feature | Onde hoje | T | Camadas | Estado |
|---|---|---|---|---|
| Opacidade | painel Mesclar › Opacidade; Transformar › Opacid. | 2 | todas menos Audio | ✅ (duplicado) |
| 17 modos nativos + 10 modos Aurea (shader) | painel Mesclar › Mesclagem (chips Montar/Avançado) | 2 | todas menos Audio | ✅ (sem miniatura de prévia) |
| Máscara pronta (7 revelações) · montar (retângulo, elipse, da forma, desenhar, inverter, feather, expansão) | painel Mesclar › Máscara | 2 | todas menos Audio | ✅ |
| Pilha de máscaras (modo, inverter, feather X/Y, expansão, opacidade, ordem, keyframe de caminho, presets) | 'Abrir pilha de máscaras' | 4 | todas menos Audio | ✅ (`cycleMaskMode` sem chamador) |
| Editar nós da máscara | `path_edit_sheet` + trackpad + editor no palco | 4 | — | ✅ |
| Recorte por camada (matte: acima ou qualquer, alfa/luma/invertidos) | painel Mesclar › Recorte por camada | 2 | todas menos Audio | ✅ |

### 5.8 Cor, preenchimento, traço, estilos
| Feature | Onde hoje | T | Camadas | Estado |
|---|---|---|---|---|
| Cor principal (paleta + seletor com hex/alfa/rápidas) | painel Cor e preench. | 2 | Shape, Text | ✅ |
| Gradiente vetorial (cores e posições, animar cores, radial, ângulo, centro, alcance) | Editar forma › 'Gradiente' | 3 | Shape | ✅ |
| Traço (espessura, tracejado, espaço, deslocamento, opacidade, cor) | Editar forma › Traço | 3 | Shape | ✅ |
| Estilos de camada (sombra suave/projetada/interna, brilho externo, contorno; Pronto/Montar/Avançado) | tile 'Borda e sombra' | 2 | todas menos Audio/Shape | ✅ (`setLayerStyles` sem chamador) |
| Paleta do projeto (cores nomeadas, vincular cor da camada) | — | — | — | 🔴 `setPaletteColor`, `removePaletteColor`, `linkLayerColor` sem UI |
| Estilos de texto nomeados | — | — | — | 🔴 `upsertTextStyle`, `linkTextStyle` sem UI |

### 5.9 Efeitos
| Feature | Onde hoje | T | Camadas | Estado |
|---|---|---|---|---|
| Adicionar efeito (47; busca com sinônimos; categorias com contador) | painel Efeitos › 'Adicionar efeito' | 3 | todas | ✅ (lista de nomes, **sem miniatura**) |
| Profundidades Pronto / Ajustar (montar) / Avançado | cartão do efeito | 3 | todas | 🟡 só 11 de 47 têm as três; 36 abrem direto em Avançado |
| Editar parâmetros (réguas, chips, seed 'Sortear', toggles, cor, cores extras), keyframe universal, ordem, ligar/desligar, duplicar, remover, resetar | cartão do efeito | 3 | todas | ✅ (`toggleEffectParamKeyframe` por parâmetro sem UI) |
| Presets de fábrica (6) e presets salvos | tile 'Presets'; painel › 'Presets' | 2 | todas | ✅ |
| Salvar como preset | cartão › 'Salvar preset' | 4 | todas | ✅ (via domínio; `saveEffectPresetFrom` do controlador morto) |
| Favoritar efeito | — | — | — | 🔴 não existe (nem motor) |
| Assar efeito procedural em keyframes | — | — | — | 🔴 `bakeEffectToKeyframes` sem UI |
| Blob Tracker: analisar vídeo | cartão › 'Analisar o vídeo' | 3 | Video | ✅ |
| Ajuda dos efeitos | trilho › '?' → guia | 3 | — | ✅ |

### 5.10 Formas vetoriais
| Feature | Onde hoje | T | Camadas | Estado |
|---|---|---|---|---|
| Parâmetros (tamanho, cantos, pontas, ângulo, rotação, unidade do canto), trocar geometria, converter para paramétrica | painel Editar forma | 2–3 | Shape | ✅ |
| Edit Points (trackpad, mover/alça/adicionar/canto/apagar/fechar) | 'Abrir Edit Points' | 4 | Shape | ✅ |
| Geometria composta, Combinar caminhos (Merge), 7 operadores de caminho, Trim Paths, Repeater, Morph com progresso | Editar forma / Cor e preench. | 2–3 | Shape | ✅ (`firstShapeBezier` sem chamador) |

### 5.11 Texto
| Feature | Onde hoje | T | Camadas | Estado |
|---|---|---|---|---|
| Editar conteúdo | tile 'Editar texto' (sheet sem título) | 2 | Text | ✅ |
| Fonte (do app / importada) | menu › 'Fonte' | 3 | Text | ✅ |
| Cor | Cor e preench. | 2 | Text | ✅ |
| **Tamanho da fonte** · **Negrito** | — | — | Text | 🔴 `fontSize`/`bold` sem controle (só por Escala) |
| Texto em caminho (raio, começo, abertura, deslizar, espaço, alinhar, girar, inverter) | menu › 'Caminho' | 3 | Text | ✅ |
| Animações de catálogo (35; unidade, ordem, curva, duração, atraso, início, semente, mola) | menu › 'Animar' | 3 | Text | ✅ |
| Animadores modelo AE: criar/ligar/remover | 'Animador cru' | 4 | Text | 🟡 beco sem saída |
| Propriedades do animador · seletores (Range/Wiggly/Expression/Stagger, 6 modos, 6 formas, 5 ordens) | — | — | Text | 🔴 9 métodos sem UI |
| Presets de texto (7) | — | — | Text | 🔴 `applyTextPreset` sem UI |

### 5.12 Legendas
| Feature | Onde hoje | T | Camadas | Estado |
|---|---|---|---|---|
| Transcrever (Whisper) · Criar do SRT | `+` › Legendas; menu do vídeo › 'Legendar' | 2–3 | Caption | ✅ |
| Editar cues (texto, tempo, remover) | tile 'Editar legendas' | 2 | Caption | ✅ |
| Estilo do destaque (pronto, cor, tamanho, layout, caixa, maiúsculas, tracking, entrelinha, inflar, contexto) | › 'Estilo' | 3 | Caption | ✅ |
| Exportar SRT | — | — | — | 🔴 `exportCaptionsSrt` sem UI |

### 5.13 Áudio
| Feature | Onde hoje | T | Camadas | Estado |
|---|---|---|---|---|
| Mudo, ganho, fades, abaixar pela voz (ducking), normalizar LUFS, remover silêncio, ver batidas | tiles 'Volume'/'Fade' › folha 'Som' | 2 | Audio, Video | ✅ (dois tiles, uma folha; ataque/release/threshold do ducking sem UI) |
| Pulsar na batida (força, faixa, aplicar, tirar keyframes) | menu › 'Pulsar na batida' | 3 | todas | ✅ |
| Limpeza de voz, de-esser, EQ 3 bandas (`AudioProcessing`, `voice_ops.dart`) | — | — | Audio, Video | 🔴 sem controle manual (só o AutoEdit "Podcast" liga) |
| Volume de vídeo direto | — | — | — | 🔴 `editVideoVolume` redundante, sem UI |

### 5.14 Partículas, Elemento 3D, Cena 3D
| Feature | Onde hoje | T | Camadas | Estado |
|---|---|---|---|---|
| Partículas (emissor, vida, física, aparência: ~30 parâmetros) | tile 'Partículas' | 2 | Particles | ✅ |
| Elemento 3D (14 tipos, tamanho, arestas, material, brilho, reflexo, modelo OBJ/FBX) | tile 'Elemento 3D' | 2 | Element3D | ✅ |
| Estúdio 3D (vista, ferramentas, hierarquia, câmeras, luzes, materiais, olhar para, agrupar, grade, dicas) | tile 'Cena 3D' | 2 | Scene3D | ✅ |
| Ficha da cena (Objetos, Luzes, Ambiente, Câmera, Foco, Ajudas; rigs em um toque; array 3D; extrudar forma; animar rig) | 'Cor e preench.' da cena; estúdio › Ajustes avançados | 2–4 | Scene3D | ✅ (`addGlbNode`, `alignCameraToRender`, `setScene3DView` sem chamador) |
| Câmeras e cortes (nova câmera, tomadas, transição, seguir nulo) | menu › 'Câmeras' | 3 | Scene3D | ✅ |
| Nulo com Módulo Grade (retangular/radial/esférico, morph, proximidade, stagger, semente, camadas da grade, controlador) | tile 'Clonar' | 2 | Null | ✅ |
| Precomp: duração interna, remapear tempo, congelar, de trás para frente, colapsar, recortar | menu › 'Tempo' | 3 | Group | ✅ |

### 5.15 Exportação e templates
| Feature | Onde hoje | T | Estado |
|---|---|---|---|
| Exportar MP4 (formato MP4/PNG seq., tamanho, fps, codec H.264/HEVC, qualidade, taxa; corte puro sem recodificar; galeria) | top bar › exportar › 'Exportar vídeo (MP4)' | 2 | ✅ (só sem camada selecionada) |
| Lottie (validador "sobrevive") · SVG animado | folha Exportar | 2 | ✅ |
| Exportar template | folha Exportar › 'Template' | 2 | 🟡 exporta sempre 0 campos |
| Expor propriedades para o template | — | — | 🔴 `exposeProperty`, `unexposeProperty`, `setExposedValue` sem UI |
| AutoEdit (6 estilos, ritmo, zoom; tudo em um undo) | Início › AutoEdit | — | ✅ |

### 5.16 Ofício, dados e responsivo (área inteira sem UI)
🔴 `setDataSource`, `addDataBinding`, `removeDataBinding`, `applyDataBindings`, `repeatForEachRow` (CSV/JSON), `setTextBox`/`TextBoxSpec`, `setContainer`/`applyContainer`, `setStack`/`applyStack`, `CounterSpec`/`NumberFormatSpec`. `Bone`/IK e `TubeLimb` em `layer_meta.dart` não são referenciados nem pelo `project_store` (órfãos totais).

### 5.17 Os 60 métodos do controlador sem nenhum chamador de UI (lista nominal)
Verificado com `grep -rn "\.<nome>(" lib` excluindo o próprio `editor_controller.dart`: zero ocorrências. Cada um recebe destino no plano (§3 de `UI_REDESIGN_PLAN.md`).

- **Ofício / responsivo / dados (18):** `setLayerStyles`, `setPaletteColor`, `removePaletteColor`, `linkLayerColor`, `upsertTextStyle`, `linkTextStyle`, `setTextBox`, `setContainer`, `applyContainer`, `setStack`, `applyStack`, `exposeProperty`, `unexposeProperty`, `setExposedValue`, `setDataSource`, `addDataBinding`, `removeDataBinding`, `applyDataBindings`, `repeatForEachRow`
- **Texto avançado (9):** `applyTextPreset`, `addTextSelector`, `removeTextSelector`, `cycleSelectorMode`, `editSelectorParam`, `setRangeSelectorShape`, `toggleAnimatorPropType`, `editAnimatorPropValue`, `toggleAnimatorPropKeyframe`
- **Montagem / NLE (6):** `insertLayerAt`, `overwriteLayerAt`, `liftTimeRange`, `extractTimeRange`, `removeLayer`, `groupLayer`
- **Transições (3):** `setTransitionEffect`, `updateTransition`, `transitionHandleReport`
- **Efeitos (3):** `bakeEffectToKeyframes`, `saveEffectPresetFrom`, `toggleEffectParamKeyframe`
- **Áudio / vídeo (4):** `editVideoVolume`, `clipHasTimeRemap`, `reverseNeedsProxy`, `clearStabilization`
- **3D (3):** `addGlbNode`, `alignCameraToRender`, `setScene3DView`
- **Projeto / composição (5):** `renameProject`, `setGuides`, `addGuide`, `setMotionBlur`, `searchLayers`
- **Camadas / utilidades (6):** `renameLayers`, `setLayerFolder`, `addAudioLayer`, `importImageFromGallery`, `importVideoFromGallery`, `exportCaptionsSrt`
- **Formas / máscaras (3):** `firstShapeBezier`, `propKeyframeTimes`, `cycleMaskMode`
- **Gesto (1):** `cancelGesture`

Módulos de domínio inteiros sem importador: `domain/voice_ops.dart` (limpeza de voz), `domain/expr.dart` (`evalExpression`, só testes), `domain/text_presets.dart` (só o controlador), `Bone`/`TubeLimb` em `layer_meta.dart`.

---

## 6. Regras já em vigor que a UI nova precisa respeitar (ou revogar explicitamente)

Estas regras nasceram das correções 10.1.1 a 10.1.3 (2026-09-03) e estão codificadas em testes. O prompt novo conflita com três delas; as três viram perguntas abertas no plano.

| Regra | Onde está codificada | Conflito com o prompt |
|---|---|---|
| **Zero sliders**: todo número se ajusta pela superfície de arrasto `AmTickRuler`; `CupertinoSlider`/`Slider(` proibidos em `lib/` | `test/ui_1011_test.dart:32` | Princípio 6 "Slider + número" |
| **No máximo dois menus escondidos** (`CupertinoIcons.ellipsis`), ambos com estado à vista (`AmMenuIcon`); o Estúdio 3D é o terceiro, com estado e caminho visível | `ui_1011_test.dart:110` | E2 pede "duplicar / excluir / mais (⋯)" no cabeçalho |
| **Nenhuma gaveta** (`Drawer`) | `ui_1011_test.dart:145` | — |
| **Folha de adicionar ≤ 40% da tela** (Objeto 50%); painel de parâmetro nunca cobre o preview (piso 42%) | `test/nivel1_shapes_test.dart:258`, `am_widgets.dart:110` | Zona E "arrastável até ~60%" |
| **Painel de transformação cabe sem rolar** em 390×844 e as seis abas aparecem no SE | `test/painel_cabe_na_tela_test.dart` | — (a UI nova tem de manter) |
| **No máximo sete seções por tipo de camada**, ordem fixa pelo enum, nada inerte por tipo | `am_sections.dart`, `test/nivel10_1_ui_final_test.dart` | O grid E2 do prompt tem 6 (+Pro): compatível |
| **Abrir painel nunca retira o editor** (sem pop de rota) e não muda o projeto | `test/layer_menu_navigation_test.dart`, `param_sheet_close_test.dart` | — (manter) |
| **Nenhuma função só dentro de toque longo** | `docs/auditoria-menus-escondidos.md` | Timeline pede "long press = reordenar": aceitável como atalho, com caminho visível |
| **Não há interruptor de núcleo/estúdio**: em 2026-09-03 o `AppMode` e o Laboratório foram apagados a pedido ("implementa TUDO já no app") | `docs/auditoria-menus-escondidos.md`, memória do projeto | Seção 5 pede toggle Simples/Pro |
| Cores da logo no editor (fundo `#12151A`, lima, violeta) foi pedido explícito; hoje `AmColors` usa teal | memória do projeto (2026-08-31) | Fase 1 pede tokens: oportunidade de unificar |

---

## 7. Problemas de UX encontrados, por gravidade

Critério: **Crítico** = impede ou esconde a edição básica (é a queixa do beta); **Alto** = poder existente inacessível ou incoerente; **Médio** = atrito e inconsistência; **Baixo** = polimento. Cada item cita o sintoma do diagnóstico do PDF (§7) quando bate.

### Crítico
1. **Duas superfícies para a mesma grade, e as utilidades só numa delas.** O dock inline mostra a grade de seções; o menu modal ('Mais ações') mostra a mesma grade **mais** a fileira de utilidades (Velocidade, Som, Fonte, Caminho, Animar, Cortes, Batidas, Legendar, Estabilizar, Câmeras, Tempo, Organizar, Loop, Extrude, Pulsar, Excluir e fechar…). Vinte comandos ficam a 3 toques e invisíveis no estado normal. Sintoma: "Onde fica X?". (`layer_menu.dart:66`, `:531`)
2. **Exportar some ao selecionar uma camada.** O ícone só existe no cabeçalho de projeto; com seleção o lugar vira "vincular"+"grade". Sintoma: "Não acha o export". (`editor_screen.dart:1029`)
3. **Texto sem controle de tamanho e negrito**, e o conteúdo se edita numa folha sem título. `TextLayer.fontSize` e `bold` não têm UI. Para uma ferramenta de motion, é a primeira coisa que alguém procura.
4. **Efeitos são nomes sem prévia** (catálogo em lista) e **36 dos 47 abrem direto no "Avançado"** (pilha de réguas cruas). É exatamente o sintoma Node Video: "expõe tudo de uma vez". (`effects_panel.dart:136`)
5. **Sem estado vazio, sem CTA, sem ajuda dentro do editor.** Projeto novo abre com timeline vazia e um `+` sem rótulo no canto; o guia mora na aba Sobre. Sintoma: "Não sabe por onde começar".
6. **Ícones sem rótulo em toda a barra de transporte e de ações** (11 + 12 ícones), com significado por tooltip. Sintoma: "Muitos ícones sem rótulo".

### Alto
7. **Layout aritmético fixo**: preview = metade de cima, sempre; não há alça de redimensionar nem "expandir timeline"; expandir o preview esconde tudo. (`editor_screen.dart:546`)
8. **Faixas que aparecem e somem**: a barra de ações (44 px) e o dock (até 202 px) só existem com seleção, e a timeline muda de altura a cada seleção. O cabeçalho troca os ícones de lugar em 4 estados. Sintoma: "Painéis que trocam de lugar".
9. **60 métodos do motor sem nenhuma UI** (§5.17) — inclusive edição de 3 pontos, expressões, seletores de texto, paleta do projeto, guias, motion blur do projeto, exportar SRT, limpar estabilização, expor propriedades de template (o template exporta sempre 0 campos).
10. **Dois "Motion blur" com comportamento diferente** (menu da camada liga o interruptor da composição; Organizar não) — um deles parece não fazer nada. (`layer_menu.dart` × `oficio_sheets.dart`)
11. **Três funções só por toque longo** (juntar pedaços na junção, menu das marcas, nome/cor da marca), já listadas na auditoria de 2026-09-03 e ainda abertas.
12. **Sem entrar em grupos**: `GroupLayer` existe (precomp com tempo próprio), mas não há como editar os filhos sem desagrupar; não há breadcrumb. Sintoma: "Timeline vira bagunça".
13. **Sem losango de keyframe na barra de transporte** e sem timecode tocável para digitar; o keyframe só se crava com um painel de propriedade aberto (o diamante do trilho).
14. **Os dois tiles Volume e Fade abrem a mesma folha** (`showAudioSheet`), ocupando 2 das 7 vagas da grade de vídeo e áudio. (`am_sections.dart:20`)
15. **Modos de mescla sem miniatura** (chips de texto); os 27 modos aparecem num painel de 2 toques, sem "6 mais comuns" primeiro.

### Médio
16. Aba 'Modelo' do `+` é um texto sem ação; `showAddLayerSheet` e `_SecaoFormas` são código morto.
17. O atalho de Elemento 3D oferece 9 dos 14 sólidos.
18. As curvas da transição oferecem 5 dos 14 easings; `random` e `elasticSteps` não existem em preset nenhum; nenhum parâmetro fino de mola é editável.
19. `Velocidade` e `Motion blur` usam o mesmo ícone na mesma fileira quando a camada tem som.
20. A engrenagem do cabeçalho liga o overlay de diagnóstico — o lugar onde os três apps põem "configurações do projeto".
21. Cor por tipo existe na timeline, mas o menu `+`, os cabeçalhos de painel e as pílulas não a repetem.
22. Não há chips de proporção com forma (o app usa pílulas de texto) nem tela de novo projeto com fundo; a tela de criação é um sheet.

### Baixo
23. Nomes inconsistentes (Opacid. / Opacidade; 'Mover e transf.' / 'Transformar · Posição').
24. O contador "N camadas" da barra de ações compete com o cabeçalho múltiplo.
25. Duplicar existe na barra de transporte (lugar de reprodução) além da barra de ações.

### O que os testadores beta reportaram (2026-09-06/07) e o que isso diz
| Relato | Causa real | O que o redesign precisa garantir |
|---|---|---|
| "Girar não faz mais de uma volta" | dial gravava o atan2 absoluto | corrigido no beta 50; o painel novo mantém o dial relativo |
| "Não sei mudar a ordem de uma camada" | ordem só existia no controlador | corrigido (3 entradas); a timeline nova precisa de reordenar visível (toque longo + botões) |
| "Como saio dessa aba?" | Voltar era um chevron sem nome | corrigido (Voltar escrito); o cabeçalho de painel novo mantém "‹ voltar" com nome |
| "A mesclagem não funciona" | expectativa (camada sozinha sobre fundo preto) | miniaturas de prévia dos modos (princípio 5) resolvem na raiz |
| "Coloquei o keyframe aqui e apareceu ali" | flag de arrasto presa | corrigido; o playhead central fixo continua |
| "Exportei e não está na galeria" | ajuste não era lido | corrigido; a folha de exportar nova mostra o destino |
| "Deep Glow crashou" | GPU por primitiva | corrigido no motor; fora do escopo de UI |
| "As abas de transformação descem" | painel rolava abaixo de 372 px | corrigido; regra de "cabe sem rolar" mantida em teste |

---

## 8. O que o app já tem do modelo-alvo (para não refazer o que está certo)

| Princípio / zona do prompt | Situação hoje |
|---|---|
| Cinco zonas fixas (top / preview / transporte / timeline / painel contextual) | **Existem** — com duas faixas a mais (barra de ações e dock) que aparecem por seleção |
| "Tudo é layer" | **Sim**: 12 tipos numa timeline só; câmera e luz são nós da cena 3D, não camadas |
| "A ação segue a seleção" | **Parcial**: sem seleção = FAB; com seleção = dock com a grade; categoria aberta = painel com sub-abas no trilho direito |
| Um "+" só | **Sim** (FAB + `+` da barra de ações → mesmo `AddLayerPanel`) |
| Grid de categorias (Alight) | **Sim**: `secoesDe` com teto de 7, ordem fixa, por tipo |
| Playhead fixo no centro, régua em cima, pinça = zoom | **Sim** |
| Losango = keyframe; linha entre keyframes | **Sim** na barra da camada e no trilho do painel; **não** na barra de transporte |
| Cor por tipo | **Sim** na timeline (12 cores); **não** no resto |
| Filmstrip / waveform nas barras | **Sim** |
| Preset antes de parâmetro | **Parcial**: efeitos têm Pronto/Montar/Avançado (11/47), estilos de camada e legendas têm Pronto; curvas têm miniaturas; **efeitos e blend não têm miniatura** |
| Undo/redo sempre visíveis | **Sim** (na barra de transporte, não na top bar) |
| Exportar em dois toques | **Sim** quando nada está selecionado; **não** com seleção |
| Sheets que não cobrem o preview | **Sim** (regra medida) |
| Simples / Pro | **Não** (interruptor apagado a pedido em 2026-09-03) |
| Onboarding no editor | **Não** (só o Estúdio 3D tem dicas) |
| Grupos com breadcrumb | **Não** |
| Alça de redimensionar preview, badge de qualidade, zoom/fit | **Não** (há badge de "rascunho" durante a reprodução) |

---

## 9. Tamanho do trabalho

| Escopo | Arquivos | Linhas |
|---|---:|---:|
| `presentation/am/` (painéis, folhas, timeline, estúdio) | 39 | 31.472 |
| `presentation/editor_screen.dart` | 1 | 1.925 |
| `presentation/widgets/` que são UI (`add_layer_sheet`, `gallery_panel`, `mask_node_editor`, `freehand_overlay`) | 4 | ≈2.400 |
| **Total a tocar no redesign** | | **≈35.800** |
| `presentation/widgets/` que são motor de render (não tocar) | 20 | ≈11.400 |
| `application/` (controlador, playback, serviços) — não muda; ganha adaptadores | 29 | 11.877 |
| `domain/` — não muda | 66 | 33.775 |
| Testes hoje | 174 | 27.706 (1.466 casos) |

Os cinco arquivos que mais custam: `layer_menu.dart` (6.115 linhas, ~20 folhas + 2 painéis), `scene3d_sheet.dart` (3.058), `am_timeline.dart` (1.860), `effects_panel.dart` (1.745), `curve_panel.dart` (1.358).
