# Matriz de paridade com o Alight Motion

> Prompt 01 da especificacao `Aurea_UI_Somente_Alight_Motion_Video.pdf`
> (revisao 02, 10/09/2026). Quinze superficies comparadas em paralelo
> contra o codigo real, cada uma com um conferente adversarial por cima.
>
> **229 exigencias. 88 divergencias ESTRUTURAIS.** 26 correcoes do conferente.
>
> Vocabulario da especificacao: `V` observado no video (com timestamp),
> `D` documentado pelo suporte AM, `P` prescrito pelo PDF, `N` nao observado.
> Uma tela `N` nao pode receber selo de paridade nem de divergencia.

## Resumo

| superficie | exigencias | estruturais | medias |
|---|---:|---:|---:|
| Velocidade | 12 | 1 | 5 |
| Timeline: camadas, selecao e edicao temporal | 12 | 3 | 4 |
| Aparencia: Homogeneizacao e opacidade | 20 | 4 | 7 |
| A grade de acoes muda com o tipo de camada | 14 | 9 | 4 |
| O "+" e o seletor de insercao | 13 | 10 | 2 |
| Transformacao: pad de posicao, dial de rotacao, dimensoes  | 25 | 2 | 8 |
| Aparencia: Borda e sombra, subpainel Traco | 13 | 6 | 4 |
| Aparencia: Cor e preenchimento | 14 | 3 | 6 |
| Camera, Grupo Vazio, Nulo e Elemento / Projeto | 16 | 10 | 3 |
| Shell, anatomia e maquina de estados | 20 | 6 | 8 |
| Efeitos: pilha da camada, + Adicionar efeito, menu de cola | 14 | 5 | 3 |
| Configuracoes do projeto em sheet | 14 | 8 | 4 |
| Presets e modais | 11 | 7 | 3 |
| Curva de gradacao: Bezier, Saltar, Ciclico, Elastico | 18 | 9 | 3 |
| Animacao: keyframes ligados a propriedade atual | 13 | 5 | 4 |

---

## O "+" e o seletor de insercao (Forma, Midia, Audio, Objeto/Elemento, Modelo) — PDF paginas 8 e 9, com o contrato de estado da pagina 7 e a grade 2x2 de Objeto/Elemento vista em V 00:08 (pagina 10)

Li a especificacao (paginas 2, 3, 7, 8, 9 e o trecho da 10 que descreve o conteudo da aba Objeto/Elemento) e li o codigo do Aurea: lib/src/features/editor/presentation/widgets/adicionar_conteudo.dart (622 linhas, inteiro), o ponto de montagem em lib/src/features/editor/presentation/widgets/linha_do_tempo.dart:228-246 e :1458-1503, a abertura do fluxo em lib/src/features/editor/presentation/widgets/painel_da_camada.dart:475-488, o consumo em lib/src/features/editor/presentation/editor_screen.dart:366-379, o catalogo em lib/src/features/editor/domain/shape_library.dart:24-56, e os comandos reais em lib/src/features/editor/application/editor_controller.dart. Resultado: esta superficie NAO tem paridade em nenhum eixo estrutural. O AM abre um seletor INFERIOR com cinco abas (Forma, Midia, Audio, Objeto/Elemento, Modelo), grade paginada 3x5 com cinco indicadores, trilho fixo a direita (Desenho vetorial, Texto, X) e atalho de desenho a mao livre na faixa superior. O Aurea abre uma barra flutuante rolavel de SETE familias (3D, Texto, Formas, Imagens, Videos, Audio, Ferramentas) e, por cima dela, um modal CENTRADO com fundo desfocado e grade de 3 colunas com rolagem vertical. Nao existe aba, nao existe estado de aba ativa, nao existe paginacao, nao existe trilho lateral, nao existe galeria embutida (Midia e Audio chamam o seletor do sistema), nao existe aba Modelo no editor, e nao existe camada de Camera nem insercao de Grupo Vazio. Dois achados de codigo morto pesam nesta superficie: shape_library.dart declara 30 formas com o comentario "modelo Alight Motion: grade de 7 por linha, em paginas" e NAO e referenciada por nenhuma tela (so por um template e um teste), e FreehandOverlay nunca e montado e freehandRequestProvider nunca e ligado por ninguem — o desenho a mao livre esta implementado e sem porta. Trocar de aba hoje e impossivel sem fechar: a barra de familias fica ATRAS do Positioned.fill que fecha o painel ao toque (adicionar_conteudo.dart:389-404). Nao editei arquivo nenhum.

### `!!` O + abre um seletor INFERIOR (moldura ancorada no rodape, a mesma para todos os tipos de insercao); nao abre um menu geral de edicao nem um Inspector.

- evidencia: V 00:02.0 (pagina 8, "O + abre um seletor inferior; nao abre um menu geral de edicao"); V 00:05.5/00:07.0/00:12.0 (pagina 9, "A mesma moldura inferior serve a tipos de insercao diferentes")
- hoje: Dois artefatos empilhados: uma barra flutuante de familias sobre o + (lib/src/features/editor/presentation/widgets/linha_do_tempo.dart:238-246, altura 66 px, BarraDeCategoriasDeAdicao em adicionar_conteudo.dart:287-343) e, por cima dela, um modal CENTRADO na tela com BackdropFilter blur 14 e ConstrainedBox maxWidth 340 / maxHeight 420 (adicionar_conteudo.dart:384-479, Center em :405, constraints em :409-412).
- divergencia: O AM tem UMA moldura inferior; o Aurea tem duas superficies concorrentes, e a segunda e um dialogo centrado no meio da tela com o resto desfocado. Isso viola tambem a invariante da pagina 7 ("nunca exibir dois paineis concorrentes"): enquanto o modal esta aberto a barra de familias continua montada embaixo dele.
- mudanca: Substituir BarraDeCategoriasDeAdicao + PainelCentralDeAdicao por um unico SeletorDeInsercao ancorado ao rodape (bottom: 0, left: 0, right: 0), com altura fixa proxima da area inferior da timeline, sem Center e sem BackdropFilter. Remover o Positioned da barra em linha_do_tempo.dart:238-246 e montar o seletor como uma unica camada na Stack do editor_screen.dart.
- risco: O modal centrado e hoje o unico caminho de criacao de camada; trocar a moldura sem remontar o roteamento derruba a criacao inteira. O blur tambem serve de captura de toque — sem ele, toques que hoje sao absorvidos passam para a timeline embaixo (arrastar keyframe, mover cabecote).
- teste: Teste de widget: abrir o seletor e verificar, pelo RenderBox do container raiz do seletor, que o topo dele fica abaixo de 55% da altura da tela e que a base encosta no rodape; e expect(find.byType(BackdropFilter), findsNothing) dentro do seletor. Somar a isso um expect de que existe exatamente UMA superficie de insercao montada (findsOneWidget para a chave do seletor).

### `!!` Abas superiores, nesta ordem: Forma, Midia, Audio, Objeto / Elemento, Modelo. Cinco, e apenas essas.

- evidencia: V 00:02.0 a 00:14.5 (pagina 8, "Abas superiores — Ordem: Forma, Midia, Audio, Objeto / Elemento, Modelo"; indice da gravacao na pagina 4 confirma a sequencia 00:02, 00:05,5, 00:07, 00:08, 00:11,5)
- hoje: Nao existem abas. Existem SETE familias numa ListView horizontal rolavel: 3D, Texto, Formas, Imagens, Videos, Audio, Ferramentas (adicionar_conteudo.dart:115-267, lista categoriasDeAdicao; barra em :302-341, com o comentario explicito "A BARRA ROLA. Sete familias hoje, mais amanha").
- divergencia: Agrupamento e ordem completamente outros. Forma virou "Formas" na terceira posicao; Midia esta partida em duas familias (Imagens e Videos); Objeto/Elemento nao existe; Modelo nao existe; e foram acrescentadas 3D, Texto e Ferramentas como familias de topo, que a pagina 8 proibe explicitamente ("Nao adicionar categorias dos outros benchmarks"). Texto, na referencia, e trilho lateral e nao aba (ver linha do trilho).
- mudanca: Reduzir o topo do seletor a cinco abas fixas nesta ordem: Forma, Midia, Audio, Objeto/Elemento, Modelo — sem rolagem horizontal, largura repartida. Reancorar o conteudo atual: Formas -> aba Forma; Imagens + Videos -> aba Midia; Audio -> aba Audio; Nulo 3D -> aba Objeto/Elemento; Modelo -> nova aba. As familias 3D, Particulas e Ferramentas precisam de destino contextual aprovado (ver extensoesAurea), nunca de exclusao.
- risco: Fundir Imagens e Videos numa aba unica muda o caminho de importacao: hoje sao dois comandos distintos (importImageFromGallery em editor_controller.dart:2956 e importVideoFromGallery em :609). Se a aba Midia nao distinguir o tipo escolhido, o importador errado e chamado. Perder o acesso a 3D/Particulas/Ajuste sem destino aprovado apaga funcionalidade — proibido pela pagina 2.
- teste: Teste de widget: montar o seletor e verificar que os rotulos das abas, lidos na ordem de posicao horizontal (por RenderBox.localToGlobal(dx)), sao exatamente ['Forma','Midia','Audio','Objeto / Elemento','Modelo'] — e expect de que nenhuma outra aba existe. Um segundo teste garante que o topo NAO rola (nao ha Scrollable horizontal na faixa de abas).

### `!!` Estado da aba: icone e rotulo da aba ativa em verde, demais em tom claro/cinza; trocar a aba substitui APENAS o corpo do seletor.

- evidencia: V 00:07.0 (pagina 9, "Audio: aba destacada"); pagina 8, "Estado da aba — Icone e rotulo ativos em verde; demais em tom claro/cinza. Trocar a aba substitui apenas o corpo do seletor."
- hoje: A barra de familias nao tem estado ativo nenhum: todo icone usa AmColors.text e todo rotulo usa AmColors.muted, sem ramo condicional (adicionar_conteudo.dart:323 e :329-333). Pior: escolher uma familia monta o modal com um Positioned.fill que COBRE a barra e cujo toque chama fecharAdicao (adicionar_conteudo.dart:389-404) — a barra fica visualmente atras do blur e inalcancavel.
- divergencia: Nao ha aba ativa marcada, e nao ha como trocar de aba com o corpo aberto: o unico gesto disponivel sobre a barra fecha o fluxo. A referencia troca so o corpo, mantendo a moldura e as abas.
- mudanca: Guardar a aba ativa num provider unico (reaproveitar categoriaDeAdicaoProvider, adicionar_conteudo.dart:274, com valor inicial 'forma' em vez de null) e pintar a aba ativa com AmColors.action (o lima da Aurea ocupa o lugar do verde do AM — identidade nao se copia, pagina 2). A faixa de abas fica FORA da area coberta pelo fechamento; so o corpo troca.
- risco: categoriaDeAdicaoProvider hoje e o interruptor de visibilidade do painel (adicionar_conteudo.dart:370-371 retorna SizedBox.shrink quando null). Dar-lhe valor inicial nao-nulo faz o painel aparecer sempre; e preciso separar 'seletor aberto' de 'aba ativa' em dois estados, senao o seletor nasce aberto no editor.
- teste: Teste de widget: abrir o seletor, tocar em 'Audio', e verificar (a) que a cor do icone da aba Audio e AmColors.action e a das outras e AmColors.muted, (b) que o seletor continua aberto, (c) que tocar em 'Forma' na sequencia troca o corpo sem fechar (o provider de aberto permanece true) e sem criar camada (layers continua vazio).

### `!!` Catalogo de formas: grade de 3 linhas x 5 itens no conteudo principal, cinco indicadores de pagina, e deslize horizontal que muda o conteudo e o indicador ativo.

- evidencia: V 00:02.0, V 00:04.0, V 00:05.0 (pagina 8, "Grade de 3 linhas x 5 itens no conteudo principal. Cinco indicadores de pagina; deslize horizontal muda o conteudo e o indicador ativo")
- hoje: GridView.count com crossAxisCount: 3 e rolagem VERTICAL, sem paginacao e sem indicadores (adicionar_conteudo.dart:437-468; crossAxisCount em :440, childAspectRatio .92 em :443). A familia Formas tem apenas 6 itens (adicionar_conteudo.dart:160-208), entao nem uma pagina cheia se forma.
- divergencia: 3 colunas com rolagem vertical contra 5 colunas x 3 linhas paginadas horizontalmente. Nao ha PageView, nao ha indicador de pagina, nao ha deslize horizontal.
- mudanca: Trocar o GridView.count por um PageView cujas paginas sao GridView de crossAxisCount: 5 com 15 itens por pagina (3x5), mais uma fileira de indicadores abaixo do corpo. Alimentar as paginas com shapeLibrary (lib/src/features/editor/domain/shape_library.dart:24-56), que ja tem 30 entradas — exatamente duas paginas cheias.
- risco: PageView com GridView aninhado quebra a rolagem se o eixo nao for fixado (physics do filho precisa ser NeverScrollableScrollPhysics). Itens de 5 colunas em tela estreita encolhem o alvo de toque abaixo do minimo confortavel se o aspect ratio nao for recalculado — hoje ele e .92 para 3 colunas.
- teste: Teste de widget: abrir a aba Forma e contar os cartoes visiveis na primeira pagina (expect 15); verificar que existem exatamente 2 indicadores para 30 formas e que o primeiro esta ativo; arrastar horizontalmente (tester.fling no corpo) e verificar que o indicador ativo passou para o segundo e que os rotulos visiveis mudaram.

### `!!` Pagina inicial do catalogo com circulo, quadrilatero arredondado, cruz, arco, triangulo e outras formas geometricas — os proprios GLIFOS das formas sao a referencia visual, nao icones genericos nem nomes internos inventados.

- evidencia: V 00:02.0 (pagina 8, "Pagina inicial — Circulo, quadrilatero arredondado, cruz, arco, triangulo e outras formas geometricas; os proprios glifos sao a referencia visual")
- hoje: A familia Formas oferece 6 formas parametricas (Retangulo, Elipse, Poligono, Estrela, Setor, Anel) desenhadas com ICONES DO MATERIAL: Icons.crop_square_rounded, Icons.circle_outlined, Icons.hexagon_outlined, Icons.star_outline_rounded, Icons.pie_chart_outline_rounded, Icons.donut_large_rounded (adicionar_conteudo.dart:164-207; o cartao pinta Icon em :576-582). A biblioteca real de 30 formas EXISTE — Circulo, Quadrado arredondado, Cruz, Crescente, Triangulo, Balao, Gota, Pizza, Hexagono, Anel, Seta, Setor, Nuvem, Quadrado, Estrela, Linha, X, Triangulo reto, Pontos, Coracao, Engrenagem, Check, Flor, Faisca, Onda, Arco, Retangulo, Poligono, Cursor seta, Cursor mao (shape_library.dart:24-56) — e o proprio comentario do arquivo diz "BIBLIOTECA DE FORMAS do menu de adicionar (modelo Alight Motion: grade de 7 por linha, em paginas)". Ela nao e referenciada por NENHUMA tela: grep por shapeLibrary/shapeLibraryPreviewPath so encontra dnyx_remix_template.dart e dois testes.
- divergencia: O menu mostra 6 de 30 formas, e as mostra com icone do Material em vez do glifo da propria forma. Cruz, arco e quadrilatero arredondado — citados nominalmente na pagina 8 — estao na biblioteca e fora do menu. Existe ja a funcao de preview (shapeLibraryPreviewPath, shape_library.dart:402) que desenharia o glifo verdadeiro, e ela esta morta.
- mudanca: Ligar shapeLibrary ao corpo da aba Forma e trocar o Icon do cartao por um CustomPaint que pinta shapeLibraryPreviewPath(entrada.build()), respeitando shapeLibraryIsStrokeOnly (shape_library.dart:420) para decidir entre preencher e contornar. Criar a camada com c.addShapeLayer(em, contents: entrada.build()).
- risco: Pintar 30 caminhos vetoriais por pagina custa mais que 15 Icons; sem cache de Path por entrada o scroll fica caro (a memoria do projeto ja registra que ImageFilter/saveLayer por item estoura a GPU no iPhone). Formas desenhadas nascem como bezier e nao parametricas: os controles numericos do painel de forma nao se aplicam a elas, e a UI precisa nao prometer o que nao ha.
- teste: Teste de widget: abrir a aba Forma e verificar que os rotulos das 30 entradas de shapeLibrary aparecem ao longo das paginas, e que 'Cruz', 'Arco' e 'Quadrado arredondado' estao entre eles. Teste de pintura: tocar em 'Cruz' e verificar que a camada criada tem contents equivalentes a ShapeLibrary.cross() (comparar o numero e o tipo dos ShapeItem), provando que o glifo mostrado e a forma que entra.

### `!!` Trilho fixo a direita do conteudo, com Desenho vetorial, Texto e X, permanente entre as abas. Texto NAO vai para um submenu generico de ferramentas.

- evidencia: V 00:08.0 (pagina 9, "Atalhos persistentes a direita"); pagina 8, "Trilho a direita — Desenho vetorial, Texto e X permanecem ao lado do conteudo. Nao mover Texto para um submenu generico de ferramentas."
- hoje: NAO EXISTE trilho. O X mora no cabecalho do modal, no canto superior direito (adicionar_conteudo.dart:532-546). Texto e uma das sete familias da barra, com um unico item dentro (adicionar_conteudo.dart:147-159), ou seja, exatamente o submenu generico que a pagina 8 proibe. Desenho vetorial nao tem entrada nenhuma em lugar nenhum do app.
- divergencia: Os tres atalhos persistentes nao existem como trilho; dois deles estao no lugar errado e o terceiro nao existe.
- mudanca: Adicionar uma coluna fixa a direita do corpo do seletor com tres alvos: Desenho vetorial, Texto e X (fechar). Texto chama c.addTextLayer(em) direto, sem passar por familia. Remover a familia 'Texto' de categoriasDeAdicao e o X do cabecalho.
- risco: O trilho come largura do corpo — com 5 colunas de catalogo numa tela de 384 px logicos, os alvos do catalogo podem cair abaixo de 40 px. Tirar o X do cabecalho sem colocar o do trilho no ar deixa o seletor sem saida explicita (so o toque fora, que hoje esta em :389-404).
- teste: Teste de widget: com a aba Forma aberta, expect(find.bySemanticsLabel('Texto'), findsOneWidget) e o mesmo para 'Desenho vetorial' e 'Fechar'; trocar para a aba Audio e repetir os tres expects, provando persistencia. Um segundo teste toca em 'Texto' e verifica que uma TextLayer foi criada sem nenhum nivel intermediario (nenhum toque adicional).

### `!!` Atalho de Desenho a mao livre a direita, na faixa superior do seletor.

- evidencia: V 00:02.0-00:05.0 (pagina 8, "O atalho Desenho a mao livre aparece a direita, na faixa superior"); pagina 9, "Texto / desenho (V): entradas visiveis; editores internos nao filmados"
- hoje: NAO EXISTE porta. O desenho a mao livre esta IMPLEMENTADO — lib/src/features/editor/presentation/widgets/freehand_overlay.dart (FreehandOverlay, com simplificacao do traco e criacao da camada centrada) e lib/src/features/editor/application/freehand_session.dart:4 (freehandRequestProvider) — mas o widget nao e montado em lugar nenhum (grep por FreehandOverlay so encontra a propria declaracao) e ninguem jamais poe o provider em true: as unicas escritas sao 'false' (editor_controller.dart:433, freehand_overlay.dart:35 e :49).
- divergencia: O recurso existe e esta inacessivel. A exigencia nao tem equivalente na UI.
- mudanca: Montar FreehandOverlay na Stack do editor_screen.dart (junto de PainelSobreposto, editor_screen.dart:366) e ligar o atalho da faixa superior do seletor a ref.read(freehandRequestProvider.notifier).state = true, fechando o seletor no mesmo gesto.
- risco: O overlay captura o toque sobre a composicao inteira enquanto ligado; montado sem o desligamento correto ele sequestra o palco (o palco ja tem gesto de arrasto e alcas de selecao — ver a armadilha registrada em 'Aurea editar no palco'). freehandRequestProvider e autoDispose: se ninguem o observar no momento em que for ligado, o estado se perde.
- teste: Teste de widget: abrir o seletor, tocar no atalho de desenho a mao livre, e verificar que freehandRequestProvider ficou true, que o seletor fechou, e que um arrasto sobre o palco cria exatamente uma ShapeLayer com caminho bezier.

### `!!` Aba Midia: galeria DENTRO do seletor, com 'Recentes' como entrada, miniaturas em grade e rolagem.

- evidencia: V 00:05.5-00:06.5 (pagina 9, "Midia: galeria dentro do seletor; 'Recentes' aparece como entrada; miniaturas em grade e rolagem"). N para o resto: nao houve importacao concluida no trecho.
- hoje: NAO EXISTE galeria embutida. As familias Imagens e Videos tem um item cada, 'Da galeria', que chama o seletor do SISTEMA e sai do app: c.importImageFromGallery(em) (adicionar_conteudo.dart:214-219 -> editor_controller.dart:2956-2962, via mediaImportServiceProvider.pickImageFromGallery) e c.importVideoFromGallery(em) (adicionar_conteudo.dart:227-232 -> editor_controller.dart:609).
- divergencia: A referencia mostra a galeria dentro da propria moldura, com miniaturas; o Aurea delega ao picker do sistema. Nao ha nocao de 'Recentes'.
- mudanca: Construir o corpo da aba Midia como grade de miniaturas com a entrada 'Recentes' no topo, lendo a galeria do dispositivo (novo servico de listagem no mediaImportService, alem do pick atual). Manter o picker do sistema como caminho secundario para arquivos fora da galeria.
- risco: Listar a galeria exige permissao de leitura de midia em Android e iOS — negada a permissao, a aba precisa de estado vazio explicativo em vez de grade vazia. Carregar miniaturas em grade e caro em memoria; sem cache e sem decodificacao em tamanho reduzido, o seletor fica lento no aparelho. O conteudo pessoal das miniaturas do video NAO faz parte do design a copiar (pagina 9) — nao replicar layout a partir das fotos do usuario da gravacao.
- teste: Teste de widget com um servico de galeria falso devolvendo 12 itens: abrir a aba Midia e verificar que 'Recentes' aparece como entrada e que 12 miniaturas sao montadas; tocar numa e verificar que a camada correta (ImageLayer ou VideoLayer conforme o tipo do item) entra no instante de insercao. Segundo teste: servico que nega permissao -> estado vazio com texto, sem excecao.

### `!!` Aba Modelo: entradas 'Ver todos' e 'Descobrir mais modelos', com badge NEW; e nao confundir essa area com Presets da camada.

- evidencia: V 00:12.0 (pagina 9, "Modelo: 'Ver todos' e 'Descobrir mais modelos', com badge NEW na captura. Nao confundir essa area com Presets da camada. O destino dessas entradas nao foi demonstrado"). Destino: N.
- hoje: NAO EXISTE aba Modelo no seletor de insercao. O Aurea tem modelos empacotados, mas so na tela de projetos: lib/src/features/projects/application/modelos_empacotados.dart, consumido apenas por lib/src/features/projects/presentation/projects_tab.dart e por lib/src/features/projects/domain/monolito_template.dart. Dentro do editor nao ha nenhum caminho para modelo.
- divergencia: Uma das cinco abas da referencia nao existe nesta superficie. A capacidade existe no app, noutra tela.
- mudanca: Criar a quinta aba com as duas entradas nomeadas ('Ver todos' e 'Descobrir mais modelos'), a primeira ligada aos modelos empacotados ja existentes em modelos_empacotados.dart. O badge NEW so aparece se corresponder a regra real do Aurea (pagina 2: badges e monetizacao so quando ha regra real) — sem regra, sem badge.
- risco: Aplicar um modelo dentro de um projeto aberto e outra operacao que abrir um projeto de modelo na Home: precisa entrar como insercao no instante do cabecote e num unico passo de desfazer (a memoria de QA 1.0 exige runAsOneUndo para acao estrutural). Feito errado, substitui o projeto do usuario.
- teste: Teste de widget: abrir a aba Modelo, expect por 'Ver todos' e 'Descobrir mais modelos'; expect(find.text('NEW'), findsNothing) enquanto nao houver regra de novidade. Teste de controlador: aplicar um modelo empacotado num projeto com 2 camadas e verificar que um unico undo restaura exatamente o estado anterior.

### `!!` Aba Objeto / Elemento com grade 2 x 2: Camera, Grupo Vazio, Nulo e Elemento / Projeto — objetos entram pelo seletor de insercao, sem trocar o editor por uma nova area de trabalho.

- evidencia: V 00:08.0 (pagina 10, "Objeto / Elemento: grade 2 x 2"; indice da pagina 4, 00:08-00:11: "Camera, Grupo Vazio, Nulo, Elemento / Projeto"). Elemento / Projeto: entrada visivel, nao aberta — N.
- hoje: A aba nao existe e so um dos quatro objetos e inserivel. Nulo: existe, mas dentro da familia 3D e com o rotulo 'Nulo 3D' (adicionar_conteudo.dart:127-132 -> c.addNullLayer, editor_controller.dart:1568; NullLayer em domain/layer.dart:1623). Camera: NAO EXISTE como camada de composicao — nao ha CameraLayer em domain/layer.dart (as classes sao Video, Image, Text, Shape, Group, Caption, Audio, Null, Particles, Element3D, Scene3D, Adjustment) e Camera3D (domain/camera3d.dart:304) so vive DENTRO de uma Scene3DLayer. Grupo Vazio: NAO EXISTE como insercao — GroupLayer (domain/layer.dart:1150) so nasce agrupando camadas ja existentes (editor_controller.dart:7402 e :7426, groupLayer/agrupar) ou importando SVG (:550). Elemento / Projeto: NAO EXISTE.
- divergencia: Falta a aba inteira; falta o tipo Camera no motor; falta a insercao de grupo vazio; falta Elemento/Projeto. Nulo existe mas esta rotulado e agrupado como coisa de 3D.
- mudanca: Criar a aba Objeto / Elemento com grade 2 x 2 e as quatro entradas. Mover o Nulo para ela com o rotulo 'Nulo'. Implementar de verdade um tipo de camada de camera de composicao (nao apenas a faixa colorida — pagina 10 e explicita) e um comando de grupo vazio (GroupLayer com children: []). Elemento / Projeto entra como acesso preservado, sem alegar paridade da tela interna.
- risco: Camera de composicao e mudanca de motor, nao de UI: mexe em render, em parenting e no formato de projeto salvo. Precisa de leitura tolerante na abertura (regra de QA 1.0) para projetos antigos que nao conhecem o tipo. GroupLayer com children vazio pode quebrar codigo que assume grupo nao vazio (calculo de duracao a partir dos filhos, editor_controller.dart:7396-7401).
- teste: Teste de widget: abrir a aba Objeto / Elemento e verificar as quatro entradas dispostas em 2 colunas x 2 linhas (comparar dx/dy dos RenderBox). Teste de controlador para cada uma: criar e verificar o tipo da camada resultante, e que o projeto salvo e relido devolve o mesmo tipo (ida e volta pelo serializador). Para Grupo Vazio: criar, salvar, reabrir e verificar que o grupo continua existindo com zero filhos.

### `! ` Aba Audio: aba destacada com a entrada 'Ver todos'.

- evidencia: V 00:07.0 (pagina 9, "Audio: aba destacada e entrada 'Ver todos'"). N explicito: lista de faixas, permissoes, selecao de arquivo, waveform e controles nao foram abertos.
- hoje: A familia Audio tem dois itens de comando direto, 'Arquivo' e 'De um video', ambos chamando c.importAudioFile(em) / (em, fromVideo: true) (adicionar_conteudo.dart:235-253 -> editor_controller.dart:694). Nao ha entrada 'Ver todos' nem qualquer listagem dentro do seletor.
- divergencia: Falta a entrada 'Ver todos'. O que ha atras dela e N no PDF e continua N: nao inventar a tela interna nem declarar que o picker do sistema equivale a ela.
- mudanca: Acrescentar a entrada 'Ver todos' no corpo da aba Audio, ligada a uma listagem real de audio do Aurea. Enquanto a tela interna nao tiver referencia AM adicional, 'Ver todos' pode desaguar no caminho existente de importAudioFile — mas o ponto de entrada precisa estar la, com o rotulo da referencia.
- risco: Criar 'Ver todos' como botao decorativo e explicitamente proibido pela pagina 9 ("Nao criar botoes decorativos"). Se a entrada nao levar a funcao real, e regressao, nao paridade.
- teste: Teste de widget: abrir a aba Audio, expect(find.text('Ver todos'), findsOneWidget), tocar e verificar que o servico de importacao de audio foi efetivamente chamado (dublê que registra a chamada) — provando que a entrada nao e decorativa.

### `! ` O X fecha o seletor; a insercao conduz ao contexto do novo objeto.

- evidencia: V 00:15-00:19.5 (pagina 7, estado Adicionar: "X fecha; insercao conduz ao contexto do novo objeto"; indice da pagina 4 confirma camera criada e ja selecionada)
- hoje: A segunda metade JA CORRESPONDE: criado o item, editor_screen.dart:369-378 chama fecharAdicao(ref), desliga barraDeAdicaoAbertaProvider e chama abrirFerramentasDaCamada(ref) — a camada nova nasce selecionada pelo motor e o contexto dela abre. A primeira metade diverge: o X do cabecalho chama fecharAdicao (adicionar_conteudo.dart:434 e :277-280), que zera categoria e sub-item mas NAO desliga barraDeAdicaoAbertaProvider — o modal some e a barra de familias continua aberta, com o + ainda desenhado como x (linha_do_tempo.dart:1470-1498).
- divergencia: O X nao fecha o seletor: ele volta um nivel e deixa metade do fluxo montado. Fechar de verdade exige um segundo toque, no +.
- mudanca: Fazer o X do trilho fechar o seletor inteiro numa acao (zerar aba/corpo e barraDeAdicaoAbertaProvider juntos, dentro de fecharAdicao). Com o seletor unificado em uma so moldura, o problema desaparece por construcao: nao ha mais dois estados de abertura para desincronizar.
- risco: fecharAdicao e chamado de tres lugares (adicionar_conteudo.dart:397, :434 e linha_do_tempo.dart:1481) com expectativas diferentes; mudar o que ela faz sem revisar os tres deixa o + preso no estado 'x' ou fecha o fluxo quando so se queria voltar um nivel.
- teste: Teste de widget: abrir o seletor, tocar no X e verificar que barraDeAdicaoAbertaProvider ficou false, que nenhuma superficie de insercao continua montada e que o botao voltou a ter o rotulo semantico 'Adicionar conteudo'. Manter o teste ja existente que prova que inserir leva ao contexto da camada (test/painel_da_camada_test.dart:681-701).

### `ok` Posicao e agrupamento do + : inferior direito, no contexto de projeto, junto da timeline completa.

- evidencia: V 00:00.0 (pagina 7, estado Projeto: "Timeline completa e + inferior direito"; pagina 6, anatomia: area inferior e timeline geral)
- hoje: CORRESPONDE. O + e um circulo de 46 px em Positioned(right: 12, bottom: 12) dentro da Stack da timeline (linha_do_tempo.dart:228-233 e :1458-1502), pintado com AmColors.action.
- divergencia: NENHUMA

### Extensoes do Aurea nesta superficie

O PDF manda preservar e dar destino contextual — nunca apagar.

- Familia 3D inteira (Cena 3D, Nulo 3D, Objetos 3D com 17 primitivas, Particulas) — adicionar_conteudo.dart:115-146 e :105-113; o AM nao insere 3D pelo seletor. Precisa de destino contextual aprovado; a pagina 2 proibe apagar funcionalidade.
- Segundo nivel DENTRO do painel: um item com filhos abre mais um nivel na mesma moldura, com botao Voltar — adicionar_conteudo.dart:46-48, :377-382, :448-457 e cabecalho em :498-517. E o que hoje torna os 17 objetos 3D navegaveis; o AM resolve o mesmo problema com paginacao horizontal.
- Camada de ajuste, na familia 'Ferramentas' — adicionar_conteudo.dart:254-266 -> editor_controller.dart:1556. Nao existe categoria equivalente nas cinco abas do AM.
- Audio 'De um video': extrai a trilha de um arquivo de video — adicionar_conteudo.dart:246-251 -> editor_controller.dart:694 (fromVideo: true). A aba Audio do AM so mostrou 'Ver todos'.
- Item desabilitado com o motivo escrito no proprio cartao (campo porQueNao) — adicionar_conteudo.dart:50-53 e :601-616. Nao ha equivalente no AM; e uma regra melhor que a do concorrente e merece sobreviver a reconstrucao.
- Pausa a reproducao e CONGELA o instante de insercao ao abrir o fluxo, para a camada nova entrar onde o cabecote estava no momento do toque — painel_da_camada.dart:475-480 (instanteDeInsercaoProvider). O PDF nao descreve esse comportamento; ele resolve um problema real e nao deve ser perdido.
- Rotulos semanticos em todo alvo do fluxo ('Adicionar conteudo', 'Adicionar <familia>', 'Voltar', 'Fechar', 'Fechar o menu' e o rotulo de cada item) — adicionar_conteudo.dart:310-314, :392-394, :502-503, :536, :559-564. E o ancoradouro de toda a suite de testes atual (test/painel_da_camada_test.dart:624-712); a reconstrucao precisa manter rotulos equivalentes ou reescrever os testes junto.
- Biblioteca de 30 formas ja modelada, com preview vetorial e distincao preenchida/contorno — shape_library.dart:24-56, :402 e :420. Hoje sem porta na UI: e capacidade do Aurea a espera de destino, e e justamente o material que a grade paginada 3x5 do AM exige.
- Desenho a mao livre completo (traco seguido a dedo, simplificacao em vertices, camada centrada no desenho) — freehand_overlay.dart e freehand_session.dart. Implementado e nunca montado: precisa da porta que o trilho lateral do AM da a ele.
- Toque no fundo desfocado fecha o painel — adicionar_conteudo.dart:389-404. Gesto de desistencia que o AM nao mostra (la o X e o caminho); vale preservar como atalho, desde que nao sequestre a faixa de abas como sequestra hoje.

---

## Camera, Grupo Vazio, Nulo e Elemento / Projeto (PDF pagina 10; grade contextual desses tipos na pagina 11; regras das paginas 2, 3 e 7)

Dos quatro objetos da pagina 10, apenas o NULO existe de fato no Aurea, e existe bem: addNullLayer (editor_controller.dart:1568) cria "Nulo 1", o gizmo aparece so no editor e some na exportacao (palco_de_previa.dart:4181), e o painel ja nega cor e mascara a esse tipo. Tudo o mais diverge estruturalmente. Nao existe camera de composicao: a hierarquia de Layer (layer.dart) nao tem CameraLayer, e Camera3D so vive dentro de um Scene3DLayer — logo nao ha "Camera 1", nem faixa rosada, nem wireframe, nem ladrilho "Opcoes de Camera". Nao existe grupo vazio: GroupLayer so nasce embrulhando camada existente (groupLayer/groupLayers, editor_controller.dart:7386 e 7428), e a porta e uma acao de lista dois niveis abaixo, nao um ladrilho. Nao existe "Elemento / Projeto": o mais proximo, TemplatePack, ABRE outro projeto em vez de inseri-lo. E a propria moldura de entrada diverge: a familia "Objeto / Elemento" nao existe em categoriasDeAdicao (adicionar_conteudo.dart:115), o nulo esta arquivado sob "3D" com o rotulo "Nulo 3D", e a grade e de tres colunas num modal centralizado, nao 2x2 numa moldura inferior com abas. As grades contextuais tambem nao batem: o Aurea entrega sempre cartoes baixos em duas colunas, sem ladrilho "Presets" (apesar de EffectPresetStore existir e nao ter porta), sem "Editar grupo" de primeiro nivel, e sem a faixa de acoes temporais acima da grade. O que ja esta certo e a maquina de estados da pagina 7: _push seleciona a camada nova e editor_screen.dart:369-379 abre as ferramentas dela sem empilhar rota.

### `!!` Existe uma aba "Objeto / Elemento" no seletor de insercao, com uma grade 2 x 2 contendo Camera, Grupo Vazio, Nulo e Elemento / Projeto.

- evidencia: V 00:08 (imagem p10_0.png do PDF: abas Forma / Midia / Audio / Objeto / Elemento / Modelo, grade 2 x 2)
- hoje: lib/src/features/editor/presentation/widgets/adicionar_conteudo.dart:115-267 — `categoriasDeAdicao` tem SETE familias: 3D, Texto, Formas, Imagens, Videos, Audio, Ferramentas. Nao existe familia "Objeto / Elemento". A barra de familias e horizontal e rolavel (mesmo arquivo:287-343), nao um conjunto de abas fixas; o corpo e uma grade de TRES colunas (adicionar_conteudo.dart:437-443, `crossAxisCount: 3`).
- divergencia: A categoria de objetos nao existe como agrupamento. Os quatro itens do AM estao dispersos ou ausentes: "Nulo" mora dentro da familia "3D" com o rotulo "Nulo 3D" (adicionar_conteudo.dart:127-132); Camera, Grupo Vazio e Elemento / Projeto nao tem item nenhum. A grade e 3 x N, nao 2 x 2.
- mudanca: Criar em `categoriasDeAdicao` a familia `objeto` com rotulo "Objeto / Elemento" e exatamente quatro itens, nesta ordem: Camera, Grupo Vazio, Nulo, Elemento / Projeto. Mover o item de nulo para essa familia com o rotulo "Nulo". Permitir que a familia declare a contagem de colunas da grade (2 para objetos) em vez do `crossAxisCount: 3` fixo em `PainelCentralDeAdicao`.
- risco: Mover "Nulo 3D" da familia 3D quebra qualquer teste ou fluxo que o procure por rotulo; a grade de 2 colunas com celulas `childAspectRatio: .92` pode estourar o `maxHeight: 420` do painel se a familia tiver mais de 4 itens.
- teste: Teste de widget: abrir o `+`, tocar na familia "Objeto / Elemento" e verificar que a grade tem exatamente quatro cartoes, na ordem Camera, Grupo Vazio, Nulo, Elemento / Projeto, e que o `SliverGridDelegate` do `GridView` reporta crossAxisCount 2.

### `!!` O item Camera cria um objeto de camada chamado "Camera 1", que passa a existir na pilha da composicao.

- evidencia: V 00:18-00:20 ("Entrada, aviso de recurso e Camera 1 criada"); cabecalho "Camera 1" na imagem p10_1.png
- hoje: NAO EXISTE. Nao ha `CameraLayer` na hierarquia de `Layer`: lib/src/features/editor/domain/layer.dart declara VideoLayer:452, ImageLayer:647, TextLayer:764, ShapeLayer:965, GroupLayer:1150, CaptionLayer:1321, AudioLayer:1454, NullLayer:1623, ParticlesLayer:1802, Element3DLayer:2196, Scene3DLayer:2435, AdjustmentLayer:2756 — nenhuma camera. `Camera3D` (lib/src/features/editor/domain/camera3d.dart) so existe DENTRO de um `Scene3DLayer` (editor_controller.dart:1697-1735, `addScene3DCamera`), e lib/src/features/editor/domain/video_project.dart nao tem campo de camera nenhum.
- divergencia: A camera do AM e um objeto da composicao que afeta todas as camadas 3D da pilha. A do Aurea e um parametro interno de uma cena 3D e nao aparece na pilha de camadas. Nao existe caminho para criar "Camera 1".
- mudanca: Implementar de verdade um tipo `CameraLayer extends Layer` (posicao, alvo/orientacao, lente, DOF — reaproveitando `Camera3D` como valor interno) e ensinar o compositor a projetar as camadas `is3D` da composicao pela camera ativa. Acrescentar `addCameraLayer(Duration at)` no `EditorController` com nome "Camera $n" no mesmo padrao de `addNullLayer` (editor_controller.dart:1568-1578), e ligar o item novo da grade a ele. Acrescentar o caso `CameraLayer()` a `tipoDaCamadaEmPalavras` (painel_da_camada.dart:269-282), que e um switch exaustivo e vai quebrar a compilacao ate ser tratado.
- risco: Alto: introduzir uma camera de composicao muda o pipeline de projecao de toda camada 3D e pode deslocar projetos existentes que hoje sao projetados sem camera. Exige migracao de leitura tolerante em project_store.dart para projetos antigos (sem camera) continuarem abrindo iguais. O PDF (pagina 10, P) proibe explicitamente resolver isso so pintando a faixa colorida.
- teste: Teste de unidade do controller: `addCameraLayer` cria uma camada de nome "Camera 1", que fica selecionada, e um segundo chamado cria "Camera 2". Teste de render: um projeto sem CameraLayer produz o MESMO quadro antes e depois da mudanca (nao-regressao).

### `!!` A camera criada mostra um wireframe no preview.

- evidencia: V 00:19.5 ("Wireframe no preview e faixa rosada")
- hoje: NAO EXISTE para camera. O unico gizmo de objeto estrutural desenhado no palco e o do nulo: lib/src/features/editor/presentation/widgets/palco_de_previa.dart:4181-4184 — `NullLayer _ when exporting => const SizedBox.shrink()` e `NullLayer _ => CustomPaint(size: Size(220,220), painter: NullGizmoPainter())`.
- divergencia: Nao ha desenho de camera no palco porque nao ha camera na composicao.
- mudanca: Criar um `CameraGizmoPainter` (corpo, cone de visao, plano de foco) e acrescentar ao switch de palco_de_previa.dart um par de casos `CameraLayer _ when exporting => SizedBox.shrink()` e `CameraLayer _ => CustomPaint(...)`, seguindo exatamente o padrao ja usado pelo nulo.
- risco: O gizmo tem de ser `IgnorePointer` (como o do nulo) para nao roubar o toque das camadas de baixo, e tem de sumir na exportacao — o comentario em palco_de_previa.dart:4176-4180 registra que o gizmo do nulo ja vazou para o video entregue uma vez.
- teste: Teste de widget com `exporting: true`: nenhum `CustomPaint` de camera na arvore. Com `exporting: false`: o painter existe. Mais um teste que confere que o gizmo esta dentro de um `IgnorePointer`.

### `!!` A grade contextual da camera e 2 x 2: Movimentacao e transformacao; Opcoes de Camera; Presets; Efeitos.

- evidencia: V 00:19.5 (imagem p10_1.png; tabela da PAGINA 11: "Camera: Movimentacao e transformacao; Opcoes de Camera; Presets; Efeitos. Disposicao em 2 x 2")
- hoje: lib/src/features/editor/presentation/widgets/painel_da_camada.dart:129-261 — `categoriasDaCamada` nao tem ramo para camera (o tipo nao existe) e nao tem categoria "Presets" nenhuma para tipo algum. A grade e sempre de DUAS colunas com `mainAxisExtent: 56` (painel_da_camada.dart:723-742), ou seja, cartoes baixos em linha, nao ladrilhos altos.
- divergencia: Nao ha grade de camera. Nao ha ladrilho "Opcoes de Camera" (o mais proximo e a categoria `cena` => "Cena e camera", restrita a `Scene3DLayer`, painel_da_camada.dart:185-190). Nao ha ladrilho "Presets", apesar de `EffectPresetStore` existir (lib/src/features/editor/application/effect_preset_store.dart:20).
- mudanca: Acrescentar a `categoriasDaCamada` o ramo `if (camada is CameraLayer)` com exatamente as quatro categorias na ordem do AM, e criar a categoria `presets` (ligada ao `EffectPresetStore` que ja existe) para os tipos que o AM mostra. Trocar `mainAxisExtent: 56` por uma altura que produza ladrilhos, e permitir a grade responder ao numero de colunas do tipo.
- risco: `categoriasDaCamada` alimenta `PainelDaCamada.alturaAberta` (painel_da_camada.dart:302-307), que calcula linhas dividindo por 2. Mudar altura de cartao ou numero de colunas sem mudar essa conta faz o painel abrir com sobra ou cortando a ultima linha. `alturaDaFerramentaAberta` (painel_da_camada.dart:575-592) tira esse espaco do preview.
- teste: Teste de widget: selecionar uma CameraLayer, abrir as ferramentas e verificar a presenca das chaves `cartao-transformar`, `cartao-opcoes-camera`, `cartao-presets`, `cartao-efeitos` e a ausencia de qualquer outra; conferir crossAxisCount 2 e que a altura pedida cabe em `alturaMaxima`.

### `!!` Existe o item "Grupo Vazio", que cria um contedor VAZIO e selecionavel chamado "Grupo 1".

- evidencia: V 00:08 (item na grade 2 x 2) e V 00:26 ("Grupo 1 criado")
- hoje: NAO EXISTE comando de grupo vazio. O tipo `GroupLayer` existe (lib/src/features/editor/domain/layer.dart:1150) e ha dois caminhos de criacao, ambos exigindo camada previa: `groupLayer(String id)` (editor_controller.dart:7428-7447) embrulha UMA camada existente, e `groupLayers(List<String> ids)` (editor_controller.dart:7386-7426) embrulha varias. Nenhum e alcancavel pelo `+`: a porta e a acao "Agrupar" dentro da categoria Camada (controles_da_camada.dart:1249-1255). Nao existe `addGroup`/`addEmptyGroup` — a busca por esses nomes em lib/ nao devolve nada.
- divergencia: No AM o grupo e um objeto que se INSERE e depois se enche; no Aurea ele so nasce embrulhando algo que ja existe. Alem disso `groupLayer`/`groupLayers` nomeiam sempre 'Grupo', sem indice, enquanto o AM cria "Grupo 1".
- mudanca: Acrescentar `addEmptyGroup(Duration at)` no `EditorController` criando `GroupLayer(name: 'Grupo $n', children: const [])` com duracao padrao e `position: AnimatedOffset(_center)`, no mesmo molde de `addNullLayer` (editor_controller.dart:1568-1578), e ligar ao item novo da grade. Passar `groupLayer`/`groupLayers` a numerar tambem, contando `state.layers.whereType<GroupLayer>().length + 1`.
- risco: Grupo com `children` vazio precisa atravessar render, exportacao e gravacao sem quebrar: conferir o ramo de `GroupLayer` em palco_de_previa.dart e a leitura tolerante em project_store.dart:2114. `innerDuration` e `contentTimeAt` (layer.dart:1207-1219) com filhos vazios tem de continuar bem definidos. Renumerar grupos existentes NAO deve acontecer — so os novos.
- teste: Teste de unidade: `addEmptyGroup` cria uma camada `GroupLayer` de nome "Grupo 1", com `children` vazio, selecionada. Teste de render: um projeto com um grupo vazio exporta o mesmo quadro que um projeto sem ele (o grupo vazio nao pinta nada nem estoura).

### `!!` A grade contextual do grupo repete as familias de aparencia da forma e troca "Editar Forma" por "Editar grupo".

- evidencia: V 00:26 (imagem p11_1.png: Cor e preenchimento; Borda e sombra; Homogeneizacao e opacidade / Movimentacao e transformacao; Editar grupo; Presets; Efeitos)
- hoje: Para `GroupLayer`, `categoriasDaCamada` (painel_da_camada.dart:129-261) devolve: transformar ("Mover e transformar"), opacidade ("Opacidade"), camada ("Camada"), borda ("Borda e sombra", DESABILITADA com porQueNao 'Chega numa proxima entrega', linhas 229-235), efeitos, mascara, mistura ("Mistura e recorte"). A categoria `cor` e explicitamente NEGADA a grupo (linhas 220-228). Nao ha ladrilho "Editar grupo": entrar no grupo e uma acao de lista dentro de Camada — controles_da_camada.dart:1239-1248, `_Acao(icone: Icons.login_rounded, rotulo: 'Entrar no grupo')` chamando `c.enterGroup(camada.id)` (editor_controller.dart:761-780).
- divergencia: Sete cartoes em duas colunas contra seis ladrilhos em 3 x 2. "Editar grupo" esta enterrado dois niveis abaixo (grade > Camada > lista de acoes) em vez de ser ladrilho de primeiro nivel. Faltam "Cor e preenchimento" e "Presets"; "Opacidade" e "Mistura e recorte" estao separados onde o AM tem "Homogeneizacao e opacidade"; "Borda e sombra" existe mas apagada.
- mudanca: Promover "Editar grupo" a categoria de primeiro nivel para `GroupLayer` (id `editar-grupo`), disparando `enterGroup` — o motor ja esta pronto. Fundir `opacidade` + `mistura` num ladrilho "Homogeneizacao e opacidade" para os tipos em que o AM os funde. Acrescentar `presets`. Decidir sobre "Cor e preenchimento" no grupo: ou implementar de verdade (tingir o composto) ou registrar a lacuna — nao acender um cartao que abre painel vazio, que e a regra ja escrita em painel_da_camada.dart:214-228.
- risco: `enterGroup` limpa selecao, zera as pilhas de desfazer e empilha um `_QuadroDeGrupo` (editor_controller.dart:761-780). Chamado a partir de um ladrilho da grade, e preciso fechar a ferramenta ANTES (como controles_da_camada.dart:1245 ja faz com `fecharFerramenta(ref)`), senao o painel fica apontando para uma camada que nao esta mais no `state`. A pagina 7 exige que voltar restaure o contexto sem perder valores.
- teste: Teste de widget: selecionar um grupo, abrir as ferramentas, verificar a chave `cartao-editar-grupo` na grade de primeiro nivel; tocar nele e verificar que `dentroDeGrupo` do controller virou true, que o painel se recolheu e que nenhuma referencia morta ficou (o teste ja existente 'camada removida recolhe o painel' cobre o padrao).

### `!!` A grade contextual do nulo e reduzida: Movimentacao e transformacao; Presets; Efeitos — tres areas altas lado a lado.

- evidencia: V 00:31 (imagem p11_0.png; tabela da PAGINA 11)
- hoje: Para `NullLayer`, `categoriasDaCamada` (painel_da_camada.dart:129-261) devolve SEIS cartoes: transformar, opacidade, camada, borda (desabilitada), efeitos, mistura. Renderizados em duas colunas de cartoes de 56 px (painel_da_camada.dart:723-742).
- divergencia: Seis cartoes baixos em 2 colunas contra tres ladrilhos altos em 3 colunas. Sobram opacidade, camada, borda e mistura; falta Presets.
- mudanca: Restringir a lista para `NullLayer` as tres categorias do AM e acrescentar `presets`. As acoes que hoje moram na categoria "Camada" (dividir, duplicar, pai, apagar — controles_da_camada.dart:1223-1259) precisam de destino contextual real, nao podem sumir: o lugar do AM para elas e o cabecalho de camada (parent/excluir) e a barra temporal acima da grade, descrita na PAGINA 11.
- risco: Tirar a categoria "Camada" do nulo remove a UNICA porta para `_Pai` (parenteamento) nesse tipo — e o nulo existe justamente para ser pai. Se as acoes nao forem realocadas ANTES, a funcao fica orfa, exatamente o defeito que o comentario em controles_da_camada.dart:1235-1238 diz ter acabado de corrigir. O PDF (pagina 2) proibe apagar capacidade ao mudar a interface.
- teste: Teste de widget: com um NullLayer selecionado, a grade tem exatamente as chaves `cartao-transformar`, `cartao-presets`, `cartao-efeitos`, nesta ordem, em 3 colunas. Teste separado que prova que parentear um nulo continua alcancavel por algum caminho da interface (busca por semantics 'Seguir outra camada' ou pelo cabecalho de camada).

### `!!` O item "Elemento / Projeto" fica visivel e acessivel na grade; a tela interna dele nao foi filmada e nao pode ser declarada paritaria.

- evidencia: V 00:08 (entrada visivel na grade) + N (nao aberta no video)
- hoje: NAO EXISTE item nenhum de inserir projeto como elemento. O que existe e um caminho de ABRIR um projeto inteiro, nao de inseri-lo: `TemplatePack.decode` em lib/src/features/projects/presentation/projects_tab.dart:206-221 e lib/src/features/community/presentation/community_tab.dart:200-216, que chamam `projectsController.add(novo)` + `editorController.openProject(novo)` — substituem o projeto aberto, nao inserem uma camada.
- divergencia: O ponto de entrada nao existe no seletor de insercao, e a capacidade mais proxima (TemplatePack) tem semantica diferente: abre outro projeto em vez de embutir um.
- mudanca: Acrescentar o quarto item da grade. O destino interno permanece N: implementar a insercao real de um projeto do Aurea como `GroupLayer` (o precomp ja suporta `sourceDuration`, `timeRemap`, `collapse` — layer.dart:1189-1204), reaproveitando `TemplatePack.decode` mas mapeando as camadas do pacote para filhos de um grupo em vez de trocar o projeto. NAO desenhar a tela interna alegando paridade AM.
- risco: Embutir um projeto traz resolucao, fps e paleta proprios: sem conversao explicita a insercao pode escalar errado ou arrastar duracao incoerente. Um item aceso que abre o nada e proibido pela propria regra do arquivo (adicionar_conteudo.dart:23-25): enquanto a insercao nao existir, o item tem de nascer com `porQueNao` preenchido, e nao habilitado.
- teste: Teste de widget: o cartao "Elemento / Projeto" existe na grade de objetos. Teste de unidade da insercao: inserir um pacote de 2 camadas produz UM `GroupLayer` com 2 filhos e nao troca `state.name` nem a resolucao do projeto anfitriao.

### `!!` A barra de acoes temporais fica ACIMA da grade contextual, com os espacamentos, rotulos e a area da camada selecionada preservados — a grade nao e uma lista horizontal de icones sem nome.

- evidencia: V 00:19.5, 00:26, 00:31 (imagens p10_1, p11_0, p11_1: fila com velocimetro, tres cortes e mudo acima dos ladrilhos) + PAGINA 11, P
- hoje: NAO EXISTE essa barra dentro do painel. O painel abre com `_Cabecalho` (nome da camada + tipo + seta de recolher, painel_da_camada.dart:610-701) e logo a grade (`_GradeDeCategorias`, painel_da_camada.dart:703-743). As acoes temporais moram em outro lugar: dividir e duplicar estao na lista da categoria "Camada" (controles_da_camada.dart:1223-1234) e velocidade e uma categoria propria so para video/audio (painel_da_camada.dart:173-178).
- divergencia: A fila de acoes temporais nao existe acima da grade em tipo nenhum, e para camera, grupo e nulo o AM a mostra igual aos outros tipos.
- mudanca: Inserir entre o cabecalho de camada e a grade uma faixa fixa com as acoes temporais (velocidade, os tres cortes, mudo), com os estados desabilitados corretos por tipo — lembrando que a PAGINA 11 avisa que rotulo cinza no video NAO prova botao desabilitado. Descontar a altura dessa faixa em `PainelDaCamada.alturaAberta` (painel_da_camada.dart:302-307) e em `alturaDaFerramentaAberta` (painel_da_camada.dart:575-592).
- risco: Cada linha nova no painel sai do preview, nao da linha do tempo (comentario em painel_da_camada.dart:568-574). Com `alturaMaxima = 300` (painel_da_camada.dart:293), acrescentar uma faixa sem recalcular empurra a ultima linha de ladrilhos para fora da dobra — foi exatamente o defeito que fez o teto subir de 260 para 300.
- teste: Teste de widget por tipo: com camera, grupo e nulo selecionados, a faixa temporal existe acima da grade e a grade inteira continua visivel (nenhum ladrilho com `Offset` abaixo da borda do painel). Fixar fonte em 1 em, como manda a convencao de teste do projeto.

### `!!` Se a engine nao tiver um tipo equivalente, registrar a lacuna funcional e implementa-lo de verdade; nao simular apenas a faixa colorida.

- evidencia: PAGINA 10, nota P
- hoje: Duas lacunas reais confirmadas por leitura: camera de composicao (nenhum `CameraLayer` em lib/src/features/editor/domain/layer.dart; `Camera3D` so vive dentro de `Scene3DLayer`) e insercao de projeto como elemento (so `TemplatePack` abrindo projeto inteiro). Grupo vazio e uma lacuna menor: o TIPO existe, falta o comando de criacao.
- divergencia: Duas capacidades do AM nao tem equivalente no motor do Aurea.
- mudanca: Antes de qualquer trabalho de UI nesta superficie, registrar as duas lacunas em docs/ com o alcance de cada uma (o que a camera de composicao afeta no pipeline; o que a insercao de projeto exige de conversao), e so entao implementar. Nao acrescentar item na grade que crie uma camada inerte so para ter faixa.
- risco: Entregar os quatro ladrilhos com camera falsa passa na inspecao visual e falha no uso: uma camera que nao projeta nada e pior que a ausencia dela, porque quem usa passa a confiar nela.
- teste: Teste de integracao que prova a camera de verdade: uma camada `is3D` a 500 px de distancia muda de tamanho na tela quando a posicao Z da CameraLayer muda. Sem esse teste passando, o ladrilho nao entra.

### `! ` A faixa da camera na linha do tempo e rosada; a do grupo e laranja; a do nulo e azul — cada tipo de objeto tem cor propria.

- evidencia: V 00:19.5 (camera, faixa rosada), V 00:26 (grupo, faixa laranja), V 00:31 (nulo, faixa azul)
- hoje: lib/src/features/editor/presentation/widgets/linha_do_tempo.dart:22-27 — `corDaCamada` so distingue tres tipos: `TextLayer() => AmColors.selection`, `Scene3DLayer() => AmColors.accent`, `ShapeLayer() => AmColors.tealBright`, e `_ => AmColors.teal` para todo o resto. Grupo e nulo caem no mesmo teal. Consumida por visao_geral_das_camadas.dart:703 e linha_do_tempo.dart:1318-1319, 1359. A paleta (lib/src/core/ui/am_colors.dart) tem `pink` (0xFFFF6B6B) mas nao tem laranja nem azul de faixa.
- divergencia: Grupo e nulo sao visualmente indistinguiveis de audio, imagem, video e ajuste. Camera nao tem cor porque nao tem tipo.
- mudanca: Acrescentar casos explicitos em `corDaCamada` para `CameraLayer`, `GroupLayer` e `NullLayer`, com tres cores novas em `AmColors` (rosa de faixa, laranja, azul). Nao reaproveitar `AmColors.pink`, que hoje e cor de estado e nao de trilha, sem conferir contraste.
- risco: Baixo. `sobreACorDaCamada` (linha_do_tempo.dart:48-50) decide texto preto ou branco pela luminancia, entao um laranja claro muda a cor do nome da camada — conferir legibilidade, nao cravar preto.
- teste: Teste de unidade puro sobre `corDaCamada`: um `GroupLayer`, um `NullLayer` e um `CameraLayer` devolvem tres cores distintas entre si e distintas de `AmColors.teal`. Complementar com dump visual por `RepaintBoundary` da pilha com os tres tipos.

### `! ` O rotulo do item de nulo e "Nulo", nao um nome inventado, e ele mora entre os objetos.

- evidencia: V 00:08 (imagem p10_0.png: rotulo "Nulo") — pagina 8 reforca: "os proprios glifos sao a referencia visual, nao nomes internos inventados"
- hoje: adicionar_conteudo.dart:127-132 — `rotulo: 'Nulo 3D'`, `icone: Icons.control_camera_rounded`, dentro da familia `3d` (adicionar_conteudo.dart:116-146).
- divergencia: Rotulo com sufixo "3D" e agrupamento na familia errada. O icone do AM e um quadrado com uma diagonal; `Icons.control_camera_rounded` e outra silhueta.
- mudanca: Trocar o rotulo para "Nulo", mover para a familia `objeto` e trocar o glifo por um que repita a silhueta do AM (quadrado com diagonal).
- risco: O sufixo "3D" hoje comunica que o nulo do Aurea nasce `is3D: true` (editor_controller.dart:1574). Tirar o sufixo sem outro sinal esconde essa diferenca de comportamento.
- teste: Teste de widget: abrir a familia de objetos e encontrar por texto exato "Nulo" (e nao encontrar "Nulo 3D" em lugar nenhum do seletor).

### `! ` A insercao de objeto acontece dentro do editor: nao troca o shell por uma nova area de trabalho, e a insercao conduz ao contexto do novo objeto.

- evidencia: PAGINA 10, abertura ("Objetos entram pelo seletor de insercao, sem trocar o editor por uma nova area de trabalho") + PAGINA 7 ("insercao conduz ao contexto do novo objeto")
- hoje: editor_controller.dart:472-475 — `_push` insere e ja seleciona a camada nova. lib/src/features/editor/presentation/editor_screen.dart:369-379 — depois de criar, `fecharAdicao(ref)`, fecha a barra de familias e chama `abrirFerramentasDaCamada(ref)`, que leva ao estado `EstadoDoPainel.categorias` (painel_da_camada.dart:441-444). Nenhuma rota nova e empilhada.
- divergencia: NENHUMA no comportamento de estado. Diverge so a APRESENTACAO do seletor: o Aurea usa um modal centralizado de 340 x 420 com a tela inteira desfocada (adicionar_conteudo.dart:384-418), enquanto o AM usa uma moldura inferior fixa com abas em cima e trilho a direita.
- mudanca: Manter a maquina de estados como esta. Substituir `PainelCentralDeAdicao` por uma moldura inferior com abas superiores e trilho lateral (Desenho vetorial, Texto, X), conforme a pagina 8 — trabalho da superficie do seletor, mas que esta superficie herda.
- risco: O desfoque de tela inteira e pago em GPU e a reproducao e pausada antes dele (comentario em adicionar_conteudo.dart:351-354). Trocar por moldura inferior remove esse custo, mas o gesto "tocar fora fecha" (adicionar_conteudo.dart:389-403) precisa de substituto explicito, senao o X da direita vira a unica saida.
- teste: Ja existe: 'escolher cria a camada, seleciona e fecha o fluxo' (test/painel_da_camada_test.dart:681). Acrescentar assercao de que nenhuma rota foi empilhada (o `Navigator` continua com a mesma profundidade) apos criar cada um dos quatro objetos.

### `~ ` A entrada de Camera exibe um aviso de recurso antes de criar, e o ladrilho carrega um badge de prova.

- evidencia: V 00:18 ("Entrada, aviso de recurso e Camera 1 criada"); badge PROVAR na imagem p10_0.png
- hoje: NAO EXISTE aviso nem badge nesse fluxo. `ItemDeAdicao` tem `porQueNao` (adicionar_conteudo.dart:50-51), que apaga o cartao e escreve o motivo (adicionar_conteudo.dart:603-616) — e o oposto: bloqueia em vez de avisar e prosseguir.
- divergencia: Nao ha passo de aviso entre o toque e a criacao, nem badge no cartao.
- mudanca: Nao copiar o badge PROVAR: a PAGINA 2 e explicita — badges e monetizacao so aparecem quando correspondem a regras reais do Aurea, e o Aurea nao tem assinatura para camera. Se a camera de composicao vier com limite real (por exemplo, so no modo full do AppMode), acrescentar um aviso contextual antes de criar, reaproveitando o campo de motivo do cartao. Caso contrario, criar direto e registrar aqui a divergencia como deliberada.
- risco: Copiar o badge do concorrente sem regra correspondente e explicitamente proibido pela especificacao e enganaria quem usa.
- teste: Teste de widget: o cartao Camera nao exibe texto de assinatura nem badge enquanto nao existir regra real; se a regra existir, tocar mostra o aviso e so cria apos confirmar.

### `ok` O item Nulo cria "Nulo 1": objeto estrutural, sem painel de preenchimento da forma.

- evidencia: V 00:08 (entrada) e V 00:31 ("Nulo 1 criado")
- hoje: editor_controller.dart:1568-1578 — `addNullLayer` cria `NullLayer(name: 'Nulo $n', duration: 5 s, is3D: true, position: AnimatedOffset(_center))`. O nome bate. `categoriasDaCamada` NEGA a categoria `cor` a nulo (painel_da_camada.dart:220-228, a lista de tipos com cor nao inclui NullLayer) e nega `mascara` (linhas 246-251).
- divergencia: NENHUMA quanto ao nome, a criacao e a ausencia de preenchimento. Divergem so o caminho de entrada e o rotulo, tratados nas linhas 1 e 12 desta matriz.

### `ok` O nulo nao aparece na exportacao.

- evidencia: D4 · Alight Motion · Layer Parenting and Null Objects ("Guia oficial confirma que nao aparece no export")
- hoje: lib/src/features/editor/presentation/widgets/palco_de_previa.dart:4176-4184 — o gizmo do nulo e desenhado so quando `exporting` e falso; o comentario registra que o vazamento ja aconteceu e foi corrigido.
- divergencia: NENHUMA

### Extensoes do Aurea nesta superficie

O PDF manda preservar e dar destino contextual — nunca apagar.

- Nulo com RIG DE GRADE: NullLayer.grid (layer.dart:1711-1712, GridRig) distribui varios assets numa grade dirigida pelo nulo, lido pelo palco em palco_de_previa.dart:433-435. O AM nao tem nada equivalente. Destino: o rig precisa de ladrilho proprio na grade do nulo, ou some junto com a categoria 'Camada' quando a grade for reduzida a tres.
- Nulo nasce 3D de verdade (is3D: true, editor_controller.dart:1574), com posicao Z e giro em X, Y e Z — nao e um nulo 2D. Destino: manter, e sinalizar isso no ladrilho de transformacao em vez de no rotulo do item.
- enterGroup / exitGroup com QUADRO DE DESFAZER PROPRIO por grupo (editor_controller.dart:749-800, _QuadroDeGrupo guarda undo/redo de fora e zera os de dentro), mais caminhoDoGrupo para grupos aninhados. O video nao mostra o interior do grupo do AM. Destino: e o motor de 'Editar grupo'; preservar inteiro e so trocar a porta.
- Precomp de verdade no GroupLayer: sourceDuration, timeRemap com keyframe de tempo, collapse de transformacoes e clipToComp (layer.dart:1189-1204). Nada disso aparece no AM filmado. Destino: subpainel dentro de 'Editar grupo'.
- ungroupLayer (editor_controller.dart:7450) e groupLayers a partir de multi-selecao (7386). Destino: acoes do conjunto, ja com painel proprio (PainelDaSelecao).
- Camera3D completa no padrao After Effects: predefinicoes de lente, dois nos vs um no, profundidade de campo com formato de iris, ganho e limiar de realce (camera3d.dart), cortes de camera com transicao (setCameraShot, editor_controller.dart:1757), varias cameras por cena (addScene3DCamera:1716), rig de orbita em um toque (addOrbitRig:1929) e rastreio de camera a partir de video (categoria 'rastreio', painel_da_camada.dart:194-199). Destino: quando a CameraLayer de composicao existir, 'Opcoes de Camera' deve abrir ISTO, e nao um subconjunto empobrecido.
- Tipos de objeto que o AM nao tem: AdjustmentLayer (camada de ajuste sobre o composto), ParticlesLayer, Element3DLayer com 17 primitivas, Scene3DLayer, CaptionLayer. Destino: cabem na mesma aba 'Objeto / Elemento' como itens adicionais, depois dos quatro do AM, ou numa segunda pagina da grade — nunca apagados.
- addSvgLayers cria automaticamente um GroupLayer quando o SVG tem varias formas (editor_controller.dart:525-558). Destino: nenhuma mudanca; e criacao de grupo por importacao, ortogonal ao item 'Grupo Vazio'.
- Parenteamento que captura o transform EFETIVO do pai no instante do vinculo, para nada pular ao parear (_Pai, controles_da_camada.dart:1266-1300, sobre linkProperty). O AM tem o botao de Layer Parent no cabecalho (D4) mas o video nao mostra o comportamento. Destino: preservar a semantica; mover a porta para o cabecalho de camada, como o AM.

### Correcoes do conferente (3)

- **A camera criada mostra um wireframe no preview.**
  - afirmado: NAO EXISTE para camera. O unico gizmo de objeto estrutural desenhado no palco e o do nulo (palco_de_previa.dart:4181-4184, NullGizmoPainter). Nao ha desenho de camera no palco.
  - verdade: O desenho de camera em wireframe EXISTE no palco e e alcancavel. lib/src/features/editor/presentation/widgets/palco_de_previa.dart:4054 calcula `final ajudas = !exporting && l.showHelpers` e monta o Scene3DPainter em :4091-4099 com `view: l.view` e `showHelpers: ajudas`. Em lib/src/features/editor/presentation/widgets/scene3d_painter.dart:519-523, `_paintEditorHelpers` chama `_paintFrustum` sempre que `view != SceneView.camera`; `_paintFrustum` (mesmo arquivo:1201-1240) traca o apice da camera e os quatro raios ate os cantos do frustum com Paint stroke 0xAAB8FF3D, e a vista de topo desenha o cone da camera em :1335-1345. O caminho GPU faz o mesmo (scene3d_gpu_view.dart:165: 'desenha grade, frustum e caixa do selecionado'). A troca de vista e uma porta real da UI: painel_da_cena.dart:76-82 chama `c.setScene3DView(cena.id, v)` (editor_controller.dart:2561), e `showHelpers` nasce ligado. Ou seja: o Aurea ja sabe desenhar uma camera como wireframe no palco e ja esconde a ajuda na exportacao; o que falta e a camera de COMPOSICAO a que pendurar esse desenho — a lacuna e menor e o desenho e reaproveitavel, ao contrario do que a matriz registrou.
- **A grade contextual do grupo repete as familias de aparencia da forma e troca 'Editar Forma' por 'Editar grupo'.**
  - afirmado: Sete cartoes em duas colunas contra SEIS ladrilhos em 3 x 2.
  - verdade: O alvo do AM tem SETE ladrilhos, nao seis, e o arranjo nao e 3 x 2. A pagina 11 descreve a Forma como 'Linha 1: Cor e preenchimento; Borda e sombra; Homogeneizacao e opacidade. Linha 2: Movimentacao e transformacao; Editar Forma; Presets; Efeitos' — tres na primeira linha e QUATRO na segunda. O Grupo e definido como 'Mesmas familias de aparencia; a acao especifica e Editar grupo, no lugar de Editar Forma', logo: Cor e preenchimento; Borda e sombra; Homogeneizacao e opacidade; Movimentacao e transformacao; Editar grupo; Presets; Efeitos = 7 ladrilhos num arranjo 3+4. A contagem do lado Aurea (sete cartoes: transformar, opacidade, camada, borda, efeitos, mascara, mistura, em painel_da_camada.dart:129-261 com crossAxisCount 2 / mainAxisExtent 56 em :728-731) esta certa; a comparacao 'sete contra seis' e o '3 x 2' erram o alvo, e o texto 'seis' contradiz a propria lista de faltantes que a matriz apresenta em seguida.
- **Existe o item 'Grupo Vazio', que cria um contedor VAZIO e selecionavel chamado 'Grupo 1'.**
  - afirmado: Nenhum dos dois caminhos e alcancavel pelo '+': A PORTA e a acao 'Agrupar' dentro da categoria Camada (controles_da_camada.dart:1249-1255).
  - verdade: Sao DUAS portas, nao uma, e a que a matriz cita nao serve `groupLayers`. controles_da_camada.dart:1251-1255 e a acao 'Agrupar' de camada unica e chama `c.groupLayer(camada.id)`; `groupLayers` tem porta propria em lib/src/features/editor/presentation/widgets/painel_da_selecao.dart:118-125 — `_Acao(icone: Icons.folder_open_rounded, rotulo: 'Agrupar as ${ids.length}')` chamando `c.groupLayers(ids)` e limpando o multiSelect. O comentario do proprio arquivo (:17) registra `groupLayers` entre os comandos que ganharam porta. Isso nao salva a paridade (as duas portas continuam exigindo camada previa, e nenhuma nasce no '+'), mas a afirmacao de porta unica esta errada, e o caminho multi-selecao e justamente o analogo mais proximo do gesto AM de encher o grupo.

---

## A grade de acoes muda com o tipo de camada (PDF pagina 11, secao 06 · CONTEXTO)

O Aurea ja tem o principio certo — a grade muda com o tipo — mas por outro eixo: `categoriasDaCamada` (painel_da_camada.dart:129-261) e montada por existencia de comando no EditorController, nao pelas familias de aparencia do AM. O resultado nao bate em nenhum dos quatro tipos filmados: forma tem 9 cartoes (AM: 7), grupo 7 sem 'Editar grupo', nulo 6 (AM: 3), e camera nao existe como tipo de camada — nao ha `CameraLayer` na hierarquia selada de layer.dart, e o cartao 'Cena e camera' e outro subsistema (cameras dentro de uma cena 3D). Faltam tres coisas em todos os tipos: o tile Presets (o EffectPresetStore ja existe, persistido, com zero chamadores), a fusao de opacidade e mistura num tile so, e a barra de acoes temporais acima da grade (velocidade/corte/audio hoje espalhados entre um cartao, outro cartao e um gesto de arrasto sem affordance). 'Borda e sombra' esta na grade mas nasce inerte, o que o P da pagina 11 desautoriza. O arranjo tambem e unico — 2 colunas de 56 px para todo tipo — onde o AM usa 3+4, 2x2 e tres areas altas; com 9 cartoes a grade da forma rola, e a do AM nao. Achado util: lib/src/features/editor/domain/am_sections.dart ja e exatamente o modelo pedido (familias por tipo, teto de sete, testado em test/nivel10_1_ui_final_test.dart) e nao tem NENHUM consumidor de UI — a reconstrucao deveria ligar a grade nele em vez de manter duas fontes de verdade.

### `!!` A grade de acoes tem de ser especifica por tipo de camada: forma, grupo, camera e nulo nao podem ver o mesmo conjunto de ferramentas.

- evidencia: V 00:40.0 (Forma), V 00:26.0 (Grupo), V 00:19.5 (Camera), V 00:31.0 (Nulo)
- hoje: A grade JA varia por tipo: `categoriasDaCamada(Layer)` monta a lista com `if (camada is X)` em lib/src/features/editor/presentation/widgets/painel_da_camada.dart:129-261. A regra declarada no comentario (linhas 108-128) e CAPACIDADE REAL DE COMANDO, nao familia visual.
- divergencia: O principio existe, mas o eixo e outro. O AM varia por FAMILIA DE OBJETO (forma/grupo/camera/nulo) com um conjunto fixo de 7 familias de aparencia; o Aurea varia por existencia de comando no EditorController, e produz 9 cartoes para forma, 7 para grupo e 6 para nulo, com nomes e ordem diferentes. Nenhum dos quatro conjuntos do AM e reproduzido.
- mudanca: Reescrever `categoriasDaCamada` para partir das familias do AM (cor/preenchimento, borda/sombra, homogeneizacao+opacidade, movimentacao/transformacao, acao do tipo, presets, efeitos) e so entao filtrar por tipo. O modelo ja escrito em lib/src/features/editor/domain/am_sections.dart:16-88 (`AmSecao`, `secoesDe`, teto de 7) e exatamente essa forma e nao tem NENHUM consumidor de UI: ligar a grade nele em vez de manter duas fontes de verdade.
- risco: Cartoes hoje acessiveis (Mascara, Som, Velocidade, Rastreio, Informacoes da midia, Cena e camera, Camada) ficam sem porta se a lista for simplesmente trocada; cada um precisa de destino contextual antes da troca.
- teste: Teste de widget que seleciona uma camada de cada tipo e compara a lista de chaves `cartao-*` renderizadas com a tabela da pagina 11, tipo a tipo; mais o teste ja existente test/nivel10_1_ui_final_test.dart passando contra a grade REAL e nao so contra `secoesDe`.

### `!!` Forma: sete tiles, linha 1 com Cor e preenchimento, Borda e sombra, Homogeneizacao e opacidade; linha 2 com Movimentacao e transformacao, Editar Forma, Presets, Efeitos.

- evidencia: V 00:40.0
- hoje: ShapeLayer recebe 9 cartoes, nesta ordem (painel_da_camada.dart:129-261): transformar 'Mover e transformar' (130-134), opacidade 'Opacidade' (135-139), forma 'Forma' (155-160), camada 'Camada' (209-213), cor 'Cor e preenchimento' (220-228), borda 'Borda e sombra' DESABILITADO (229-235), efeitos 'Efeitos' (236-240), mascara 'Mascara' (246-251), mistura 'Mistura e recorte' (255-260).
- divergencia: Numero (9 x 7), ordem (transformacao vem primeiro no Aurea, e a terceira do AM), rotulos ('Mover e transformar' x 'Movimentacao e transformacao'; 'Forma' x 'Editar Forma'), e conteudo: falta Presets, sobram Camada, Mascara e Mistura e recorte, e Opacidade esta separada da mistura.
- mudanca: Fixar a lista da forma nos sete itens do AM, na ordem 3+2 linhas do video, com os rotulos do AM. Realocar Camada, Mascara e Mistura e recorte para os destinos contextuais que o PDF exige (cabecalho de camada e submodo de blend, paginas 7 e 12) em vez de apagar.
- risco: Mascara e um painel inteiro (painel_de_mascaras.dart) hoje alcancavel so por este cartao; tirar da grade sem destino novo apaga o acesso a mascaras.
- teste: `pumpWidget` com ShapeLayer selecionada; esperar exatamente 7 cartoes, na ordem dos ids do AM, e a quebra de linha 3+4 medida pela posicao Y dos tiles.

### `!!` O tile 'Borda e sombra' e acionavel na grade de forma e de grupo (o PDF avisa que rotulo cinza no video nao prova botao desabilitado).

- evidencia: V 00:40.0 (Forma), V 00:26.0 (Grupo); P da pagina 11: "Rotulos cinza no video nao comprovam que um botao esta desabilitado"
- hoje: O cartao existe mas nasce inerte: painel_da_camada.dart:229-235 declara `disponivel: false, porQueNao: 'Chega numa proxima entrega'`. `_Cartao` (745-824) anula o `onTap` quando `disponivel == false` e pinta o chip com alpha .4. Nao ha caso 'borda' no switch de conteudo de controles_da_camada.dart:105-120, entao ele cairia em `_AindaNao`.
- divergencia: No AM o tile abre um subpainel de familia; no Aurea ele e um placeholder morto em toda camada, inclusive forma e grupo.
- mudanca: Implementar o subpainel de borda e sombra (traco, largura, cor, sombra) ligado a comandos reais e remover `disponivel: false`; enquanto nao houver comando, o cartao nao pode estar na grade — a propria regra escrita em painel_da_camada.dart:102-103 diz isso.
- risco: Se o subpainel for aberto sem comandos por tras, vira painel vazio; se a borda for implementada no render, muda a saida de projetos ja salvos que tenham valores default diferentes de zero.
- teste: Tocar em `cartao-borda` com ShapeLayer selecionada e esperar que `estadoDoPainelProvider` va para `categoria` e que o painel renderize um controle de largura de traco — nao o texto de `_AindaNao`.

### `!!` Grupo: as mesmas familias de aparencia da forma, com 'Editar grupo' no lugar de 'Editar Forma'.

- evidencia: V 00:26.0
- hoje: GroupLayer (lib/src/features/editor/domain/layer.dart:1150) recebe 7 cartoes: transformar, opacidade, camada, borda (desabilitado), efeitos, mascara, mistura. Nao ha cartao 'Editar grupo'. 'Cor e preenchimento' e explicitamente NEGADO ao grupo (painel_da_camada.dart:214-228). Entrar no grupo existe, mas escondido: acao dentro da categoria 'Camada' (controles_da_camada.dart:1241-1249, chamando `c.enterGroup`).
- divergencia: Falta o tile 'Editar grupo' na grade; ele esta a dois toques de distancia dentro de outro cartao. E a familia 'Cor e preenchimento', que o AM mostra no grupo, esta ausente por decisao de codigo.
- mudanca: Promover `enterGroup` a cartao de primeiro nivel 'Editar grupo' na grade do grupo, na mesma posicao que 'Editar Forma' ocupa na forma; decidir o destino de Cor e preenchimento no grupo (o PDF marca o interior do grupo como precisando de referencia adicional, entao a aparencia do grupo pode ficar N ate haver evidencia).
- risco: `enterGroup`/`exitGroup` mudam o escopo de edicao; promover o gesto a um toque aumenta a chance de a pessoa entrar no grupo sem perceber e nao achar a saida — o retorno precisa estar visivel no cabecalho.
- teste: GroupLayer selecionada: existe `cartao-editar-grupo`, um toque nele chama `enterGroup` e o cabecalho mostra o caminho de volta; ShapeLayer nao tem esse cartao.

### `!!` Camera: grade em 2 x 2 com Movimentacao e transformacao, Opcoes de Camera, Presets e Efeitos.

- evidencia: V 00:19.5
- hoje: NAO EXISTE. Nao ha `CameraLayer` na hierarquia selada de lib/src/features/editor/domain/layer.dart (os 12 tipos sao Video, Image, Text, Shape, Group, Caption, Audio, Null, Particles, Element3D, Scene3D, Adjustment) e `tipoDaCamadaEmPalavras` (painel_da_camada.dart:269-282) e exaustivo sem esse caso. O que existe e o cartao 'Cena e camera' apenas para `Scene3DLayer` (painel_da_camada.dart:185-190 -> PainelDaCena), que edita cameras DENTRO de uma cena 3D, nao um objeto camera da composicao.
- divergencia: Falta o tipo de objeto inteiro, e portanto a grade dele. `PainelDaCena` nao e equivalente: ele so aparece para Scene3DLayer e trata de cameras internas da cena.
- mudanca: O PDF (pagina 10) manda registrar a lacuna e implementar de verdade, nao simular a faixa colorida: criar o tipo de objeto camera no motor e, so entao, a grade 2 x 2. Enquanto o tipo nao existir, esta linha permanece uma lacuna funcional aberta, nao uma divergencia de UI.
- risco: Introduzir um tipo novo na hierarquia selada quebra a compilacao em todo switch exaustivo sobre `Layer` (o proprio comentario em painel_da_camada.dart:263-268 conta com isso) e exige migracao do formato de projeto.
- teste: Depois de existir: criar uma camada camera e esperar exatamente 4 cartoes em 2 colunas x 2 linhas, com os ids do AM; e um teste de serializacao ida-e-volta do novo tipo.

### `!!` O tile 'Opcoes de Camera' aparece no contexto da camera criada.

- evidencia: V 00:19.5 (tile visivel); o interior do painel e N — a pagina 3 lista "opcoes internas da camera" como fora da gravacao
- hoje: NAO EXISTE (nao ha tipo camera). O cartao 'Cena e camera' de painel_da_camada.dart:185-190 abre painel_da_cena.dart, cujo conteudo e outro: abrir o estudio, lente, ortografica, lista de cameras da cena, nova camera, cortes de camera, enquadrar a cena.
- divergencia: Ausente. E o conteudo do painel do AM continua N: nao ha o que copiar dentro dele sem referencia adicional.
- mudanca: Junto com o tipo camera, criar o tile 'Opcoes de Camera' com as opcoes comprovadas; nao preencher o interior por analogia com PainelDaCena, que e outro subsistema.
- risco: Reaproveitar PainelDaCena para o objeto camera acoplaria a composicao ao motor 3D de cena e criaria dois donos para 'camera'.
- teste: Presenca do cartao na grade da camera; o interior fica coberto por um teste so quando houver evidencia AM (hoje, N).

### `!!` Nulo: grade reduzida a tres — Movimentacao e transformacao, Presets, Efeitos — em tres areas altas lado a lado, sem painel de preenchimento.

- evidencia: V 00:31.0
- hoje: NullLayer (layer.dart:1623) recebe 6 cartoes em 2 colunas: transformar, opacidade, camada, borda (desabilitado), efeitos, mistura. Mascara e negada ao nulo (painel_da_camada.dart:246-251) e cor tambem (220-228); opacidade e mistura NAO sao negadas.
- divergencia: Sobram tres cartoes (Opacidade, Camada, Mistura e recorte) e um placeholder morto (Borda e sombra); falta Presets. E o arranjo e 2 colunas de 56 px de altura, nao tres areas altas lado a lado.
- mudanca: Reduzir o nulo a tres itens e dar-lhe um arranjo proprio de 3 colunas com tiles altos. Opacidade e mistura num objeto que nao desenha sao exatamente o caso que o proprio comentario de painel_da_camada.dart:241-245 usa para excluir a mascara — aplicar o mesmo criterio.
- risco: Se algum projeto salvo tiver opacidade animada num nulo, tirar o controle esconde dado ja gravado; conferir se o render usa opacidade do nulo antes de remover a porta.
- teste: NullLayer selecionada: exatamente 3 cartoes, ids transformar/presets/efeitos, e as tres caixas com o mesmo Y e larguras iguais (3 colunas).

### `!!` Existe um tile 'Presets' na grade dos quatro tipos (forma, grupo, camera, nulo).

- evidencia: V 00:40.0, 00:26.0, 00:19.5, 00:31.0; a pagina 3 confirma que "presets vazios" foram abertos na gravacao
- hoje: NAO EXISTE na grade. `categoriasDaCamada` (painel_da_camada.dart:129-261) nao tem id 'presets' e `tituloDaFerramenta` (549-566) tambem nao. `AmSecao.presets` esta declarado em am_sections.dart:85 mas nenhum widget le esse enum. Ha um EffectPresetStore completo e persistido em lib/src/features/editor/application/effect_preset_store.dart:20 com ZERO chamadores fora do proprio arquivo.
- divergencia: Tile inteiro ausente nos quatro tipos, apesar de o armazenamento de presets ja existir e estar sem porta.
- mudanca: Criar o cartao 'Presets' na grade dos quatro tipos e ligar o subpainel ao EffectPresetStore (listar, aplicar, salvar o estado atual). O PDF avisa na pagina 9 para nao confundir isto com a aba Modelo do seletor de adicao.
- risco: Aplicar um preset escreve varias propriedades de uma vez: sem `runAsOneUndo` isso vira dezenas de passos de desfazer (regra ja registrada no projeto).
- teste: Os quatro tipos mostram `cartao-presets`; salvar um preset e reabrir o painel noutro projeto encontra o preset; aplicar e desfazer com UM toque de desfazer.

### `!!` Manter a barra de acoes temporais ACIMA da grade — velocidade, controles de corte/limites e audio.

- evidencia: P da pagina 11; V 00:40-00:46 (pagina 12: "Velocidade, controles de corte/limites e audio aparecem acima dos tiles")
- hoje: NAO EXISTE como barra. Acima da grade ha apenas `_Cabecalho` de 44 px com nome da camada, tipo e uma seta de recolher (painel_da_camada.dart:610-701, montado em 522-523). Velocidade e um CARTAO da grade e so para video/audio (painel_da_camada.dart:173-178); dividir no cabecote esta dentro do cartao 'Camada' (controles_da_camada.dart:1223-1230); aparar so existe como gesto de arrasto na trilha (visao_geral_das_camadas.dart:375-396); o transporte da linha do tempo tem desfazer/refazer/inicio/tocar/fim/duplicar/enquadrar (linha_do_tempo.dart:372-431), nenhum controle temporal do clipe.
- divergencia: A faixa de acoes temporais do clipe selecionado nao existe; suas funcoes estao espalhadas entre um cartao da grade, um cartao de acoes e um gesto sem affordance visivel.
- mudanca: Inserir, entre o cabecalho da camada e a grade, uma barra com velocidade, corte/limites e audio, agindo sobre a camada selecionada; os simbolos mudam quando o cabecote esta fora dos limites do segmento (pagina 12). Reaproveitar `trimLayerStart`/`trimLayerEnd`/`splitLayer`/`editVolume`, que ja existem.
- risco: A barra come altura de um painel cujo teto ja e 300 px (painel_da_camada.dart:293) e que ja rola com 9 cartoes; sem recontar `alturaAberta` (302-307) a grade fica cortada. E o PDF marca N para o mapeamento toque-a-icone: nao inventar gestos de toque longo.
- teste: Com uma camada selecionada, a barra aparece entre o cabecalho e a grade; um teste de posicao Y prova a ordem; tocar em dividir com o cabecote fora dos limites nao altera o projeto e o simbolo esta no estado 'fora'.

### `! ` Um unico tile agrupa homogeneizacao (blend) e opacidade.

- evidencia: V 00:40.0 e V 00:26.0
- hoje: Sao dois cartoes separados: 'Opacidade' (painel_da_camada.dart:135-139, painel proprio em controles_da_camada.dart:374 `_Opacidade`) e 'Mistura e recorte' (painel_da_camada.dart:255-260, PainelDeMistura em painel_de_mistura.dart, com familias de blend e o modo de recorte).
- divergencia: Agrupamento e rotulo. O AM tem 1 tile; o Aurea tem 2, e o segundo carrega tambem o RECORTE, que nao aparece na grade do AM.
- mudanca: Fundir num cartao 'Homogeneizacao e opacidade' cujo subpainel traz o deslizante de opacidade e a lista de blend; a categoria de blend vira SUBMODO dentro dele (pagina 7 ja preve 'categoria de blend' como submodo). Recorte precisa de destino proprio.
- risco: Perder o acesso ao recorte se ele for arrastado junto e depois cortado; e quebrar `tituloDaFerramenta` (painel_da_camada.dart:549-566) e os testes que procuram `cartao-opacidade` e `cartao-mistura`.
- teste: Um so cartao com rotulo 'Homogeneizacao e opacidade'; abrir e encontrar tanto o deslizante de opacidade quanto a lista de modos de mistura no mesmo painel; e um teste que prova que mudar de submodo de blend nao altera o projeto.

### `! ` A grade e feita de tiles com rotulo, nao de uma lista horizontal de icones sem nome; espacamentos e area da camada selecionada preservados.

- evidencia: P da pagina 11
- hoje: Cada item e um `_Cartao` (painel_da_camada.dart:745-824): um `Row` com icone de 19 px a esquerda e o rotulo em texto de 12 px a direita, chip de raio 10, altura fixa de 56 px, em `GridView` de 2 colunas com espacamento 8 (725-741).
- divergencia: NENHUMA quanto ao rotulo — todo cartao tem nome escrito. A divergencia e de forma: tile do AM e um bloco com icone acima do rotulo, e o arranjo por tipo e 3+4 (forma/grupo), 2x2 (camera) e 3 colunas altas (nulo), enquanto o Aurea usa 2 colunas fixas para todo tipo.
- mudanca: Trocar `SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisExtent: 56)` por um arranjo que venha do tipo da camada, e o `_Cartao` por um tile com icone sobre o rotulo.
- risco: `PainelDaCamada.alturaAberta` (302-307) calcula linhas como `ceil(itens/2)`; mudar o numero de colunas sem mudar essa conta deixa o painel alto demais ou cortando a ultima linha.
- teste: Teste de layout que le a posicao e o tamanho de cada `cartao-*` e confere colunas e linhas por tipo; e o teste de fonte 1em ja usado no projeto para o rotulo nao truncar.

### `! ` A grade cabe na tela sem rolagem: sete tiles em duas linhas.

- evidencia: V 00:40.0 (forma), V 00:26.0 (grupo)
- hoje: O painel pede altura ate um teto de 300 px (painel_da_camada.dart:293) e a grade e um `GridView.builder` rolavel (725-741). Com os 9 cartoes da forma sao 5 linhas: `alturaAberta` pede 44 + 5*64 + 24 = 388 px, e o clamp em 300 faz a grade ROLAR.
- divergencia: A grade da forma rola; a do AM nao. Consequencia direta do excesso de cartoes.
- mudanca: Com sete tiles em duas linhas o problema some sozinho; ainda assim, travar a grade em nao-rolavel e deixar o teste falhar se algum tipo passar do que cabe — e a mesma regra ja escrita em am_sections.dart:43-45 (`kAmMaximoSecoes = 7`).
- risco: Travar a rolagem antes de reduzir a lista esconde cartoes hoje alcancaveis.
- teste: Para cada tipo de camada, esperar que o `Scrollable` da grade tenha `maxScrollExtent == 0`.

### `! ` Ordem e rotulos dos tiles correspondem aos do AM.

- evidencia: V 00:40.0
- hoje: Rotulos atuais (painel_da_camada.dart:129-261): 'Mover e transformar', 'Opacidade', 'Forma', 'Camada', 'Cor e preenchimento', 'Borda e sombra', 'Efeitos', 'Mascara', 'Mistura e recorte'. Os titulos longos vivem separados em `tituloDaFerramenta` (549-566), onde 'transformar' ja e 'Movimentacao e transformacao'.
- divergencia: 'Cor e preenchimento', 'Borda e sombra' e 'Efeitos' batem. Divergem: 'Mover e transformar' x 'Movimentacao e transformacao' (o nome certo ja existe, mas so no cabecalho), 'Forma' x 'Editar Forma'. E a ordem: no AM a aparencia vem antes da transformacao; no Aurea a transformacao e o primeiro cartao.
- mudanca: Usar um unico rotulo por familia (o do AM) no cartao e no cabecalho, eliminando a duplicidade entre `CategoriaDaCamada.rotulo` e `tituloDaFerramenta`; reordenar a lista.
- risco: Baixo. Os testes existentes ancoram por `ValueKey('cartao-<id>')` (painel_da_camada.dart:738), nao pelo texto, entao renomear nao os quebra — mas os que procuram por texto ('Opacidade') quebram.
- teste: Comparar a sequencia de rotulos renderizados com a lista literal da pagina 11, por tipo.

### `ok` A grade abre a partir da camada selecionada e sair dela restaura a visao geral sem perder selecao, playhead nem valores.

- evidencia: V 00:40-00:46; P da pagina 7 (invariantes de navegacao)
- hoje: `abrirFerramentasDaCamada` (painel_da_camada.dart:441-444) poe o estado em `categorias`; os estados sao mutuamente exclusivos por construcao (58-60, comentario em 55-57); `fecharFerramenta` (600-603) e o `‹` do cabecalho voltam sem tocar em selecao nem em tempo (comentario explicito em 680-681); se a camada some, o painel se recolhe em vez de segurar referencia morta (405-413).
- divergencia: NENHUMA

### Extensoes do Aurea nesta superficie

O PDF manda preservar e dar destino contextual — nunca apagar.

- Cartao 'Camada' (painel_da_camada.dart:209-213 -> controles_da_camada.dart:1139-1265): solo, travar, 3D da camada, espessura de extrusao, dividir no cabecote, duplicar, seguir outra camada (parenting), agrupar/entrar no grupo, apagar. O AM poe parent e excluir no CABECALHO DA CAMADA (pagina 7), nao num tile — destino contextual: cabecalho de camada, nao a grade.
- Cartao 'Mascara' (painel_da_camada.dart:246-251 -> painel_de_mascaras.dart), com sete presets de revelacao e `editMaskParam`. Nao aparece na grade dos quatro tipos do AM; precisa de destino (candidato: dentro da familia de recorte/homogeneizacao).
- Cartao 'Mistura e recorte' (painel_da_camada.dart:255-260 -> painel_de_mistura.dart): lista de blends organizada em familias, incluindo nove modos que o Flutter nao tem (Linear Burn, Vivid Light, Pin Light, Hard Mix, Dividir, Subtrair, as duas 'cor mais', Dissolver) mais o modo de recorte. Superior ao que o video mostra; o blend cabe no tile de homogeneizacao, o recorte precisa de lugar.
- Cartao 'Animacao do texto' (painel_da_camada.dart:149-154 -> painel_de_animacao_de_texto.dart): 35 animacoes em tres posicoes, para TextLayer. O AM nao mostra equivalente nesta gravacao.
- Cartoes por tipo que o AM nao cobre: 'Som' e 'Velocidade' (video/audio), 'Rastrear a camera' (video), 'Informacoes da midia', 'Cena e camera' (Scene3DLayer), 'Forma' com parametros animaveis, 'Particulas', 'Legenda', 'Ajuste'. Tipos de camada inteiros que o AM nao tem: Scene3DLayer, Element3DLayer, ParticlesLayer, CaptionLayer, AdjustmentLayer.
- Cartao desabilitado que EXPLICA por que (`porQueNao`, painel_da_camada.dart:104-105 e 803-815). Convencao propria; conflita com o P da pagina 11 se aplicada a familias que o AM mostra ativas, mas vale preservar para o que realmente nao existe.
- `PainelDaCamada.alturaAberta` (293-307): o painel pede so a altura de que precisa em vez de altura fixa. Nao ha equivalente observado; preservar.
- `am_sections.dart` inteiro (16-88): modelo declarativo das secoes por tipo com teto de sete, testavel fora do widget. E infraestrutura de paridade, nao divergencia — hoje sem consumidor.
- `EffectPresetStore` (application/effect_preset_store.dart:20): presets de efeito do usuario guardados fora do projeto, atravessando projetos e sobrevivendo a exclusao do projeto de origem. Sem porta na UI; e o motor natural do tile 'Presets' do AM.
- Estado proprio para acoes de multipla selecao (`EstadoDoPainel.selecao`, painel_da_camada.dart:46-52 e 370-392) e para ajustes da composicao (`EstadoDoPainel.composicao`, 39-44), ambos mutuamente exclusivos com a grade de camada. Atende a invariante da pagina 7 de nunca exibir dois paineis concorrentes.

### Correcoes do conferente (3)

- **Manter a barra de acoes temporais ACIMA da grade — velocidade, controles de corte/limites e audio.**
  - afirmado: A matriz diz que aparar 'so existe como gesto de arrasto na trilha (visao_geral_das_camadas.dart:375-396)' e conclui a divergencia com 'um gesto sem affordance visivel'.
  - verdade: A afirmacao principal (nao existe a barra temporal acima da grade) esta certa, mas 'sem affordance visivel' e falso. Em lib/src/features/editor/presentation/widgets/visao_geral_das_camadas.dart:733-742 o clipe selecionado ganha contorno claro (drawRRect com AmColors.text, strokeWidth 1.6) e chama `_pintarAlcasDeAparar(canvas, barra)`. Esse metodo (linhas 836-857) desenha DUAS alcas claras de 2,5 px de largura por (altura da barra - 10) nas duas pontas, e o proprio comentario diz 'AS ALCAS DE APARAR, nas duas pontas do clipe escolhido... Sao dois tracinhos claros, do tamanho do alvo que o dedo tem de acertar'. A largura da alca e constante declarada (linha 167, 'A LARGURA DA ALCA DE APARAR, em pixels'). Isso e exatamente o que o PDF pagina 12 exige ('a faixa selecionada tem realce claro e extremidades com controles'): esse pedaco JA e paridade, e a matriz o registrou como ausencia.
- **O tile 'Borda e sombra' e acionavel na grade de forma e de grupo (o PDF avisa que rotulo cinza no video nao prova botao desabilitado).**
  - afirmado: A matriz conclui: 'No AM o tile abre um subpainel de familia; no Aurea ele e um placeholder morto em toda camada, inclusive forma e grupo.'
  - verdade: O diagnostico do tile esta certo (painel_da_camada.dart:230-236 nasce `disponivel: false`, `_Cartao` anula o onTap, e nao ha caso 'borda' no switch de controles_da_camada.dart:105-120). O erro e a conclusao de que nao ha nada atras. O conteudo que o video comprova nesse painel e 'Borda e sombra > Traco' (V · 00:47.5-00:49.5, pagina 4 do PDF), e o Traco JA ESTA IMPLEMENTADO no Aurea — so mora no cartao errado. Em lib/src/features/editor/presentation/widgets/painel_de_cor.dart:319-362 ha a secao `_Titulo('Contorno')` com 'Adicionar contorno', EscolhaDeCor 'Contorno', trilhas 'Espessura' e 'Opacidade' (ambas com keyframe pelo rail, linhas 64-65 e 205) e 'Remover o contorno', sobre os comandos reais `ensureShapeStroke` (editor_controller.dart:7219), `updateShapeStroke` (7234) e `removeShapeStroke` (7244), com `ShapeStroke`/`StrokeStyle` no dominio (layer_meta.dart:223). Ou seja: para FORMA a familia existe e esta viva dentro de 'Cor e preenchimento'; o trabalho e mover/expor, nao construir do zero. (Para GRUPO a matriz esta certa por outro caminho: 'cor' e negado ao grupo em painel_da_camada.dart:220-228, entao la o traco tambem esta fora de alcance.)
- **Forma: sete tiles, linha 1 com Cor e preenchimento, Borda e sombra, Homogeneizacao e opacidade; linha 2 com Movimentacao e transformacao, Editar Forma, Presets, Efeitos.**
  - afirmado: Na divergencia: 'ordem (transformacao vem primeiro no Aurea, e a terceira do AM)'.
  - verdade: No AM 'Movimentacao e transformacao' e a QUARTA da grade, nao a terceira: a linha 1 tem tres tiles (Cor e preenchimento; Borda e sombra; Homogeneizacao e opacidade) e ela abre a linha 2 (Movimentacao e transformacao; Editar Forma; Presets; Efeitos) — pagina 11, tabela TIPO/GRADE OBSERVADA. O erro nao e so de contagem: ele apaga a informacao de layout que a linha da tabela carrega (3 tiles em cima, 4 embaixo), que e justamente o que a reconstrucao precisa saber, e que a matriz nao registra em nenhum outro ponto. O resto do item (9 x 7, rotulos 'Mover e transformar' x 'Movimentacao e transformacao', 'Forma' x 'Editar Forma', falta Presets, sobram Camada/Mascara/Mistura e recorte) foi conferido linha a linha em painel_da_camada.dart:130-260 e esta correto.

---

## Curva de gradacao: Bezier, Saltar, Ciclico, Elastico (PDF paginas 23-24)

Li lib/src/features/editor/presentation/widgets/editor_de_curva.dart (554 linhas, inteiro), lib/src/features/editor/domain/keyframe.dart (classe Easing, linhas 9-264), project_store.dart (serializacao do Easing), controles_da_camada.dart, painel_da_camada.dart, editor_screen.dart, ficha_do_selecionado.dart e painel_de_cor.dart. O esqueleto do AM ja existe e esta certo em tres pontos importantes: a curva e ferramenta no rodape e nao modal (previa e linha do tempo continuam a vista, editor_screen.dart:241-262), o titulo do cabecalho e "Curva de gradacao" (editor_screen.dart:418), e ela abre no TRECHO entre duas marcas, nao numa curva solta (controles_da_camada.dart:274-301). O desenho tambem sai do motor real (transform), nao de um SVG. As divergencias sao quatro, e tres delas sao estruturais. (1) O AM tem DUAS colunas a direita — familia de curva na coluna mais externa, presets graficos daquela familia na coluna interna (confirmado ampliando p23_0 e p24_0/p24_2: com Saltar ativo a coluna externa marca a familia e a interna lista Saltar/Elastico/Ciclico/Aleatorio). O Aurea tem UMA lista chapada de 7 chips misturando presets bezier e familias (editor_de_curva.dart:39-47, 294-337). (2) Ciclico simplesmente nao tem porta na UI: EasingType.cyclic existe no modelo com count e smooth (keyframe.dart:115-121) e nao esta em presetsDeCurva. (3) Nenhuma familia nao-bezier tem os controles amarelos que o video mostra — editor_de_curva.dart:534 (`if (!comBotoes) return;`) sai antes de desenhar qualquer alca, e o comentario nas linhas 69-71 assume essa ausencia como decisao; Saltar e Elastico no modelo sao Curves.bounceOut e Curves.elasticOut fixos, sem parametro nenhum. (4) O botao de familia ativo nao reflete a curva aplicada depois de reabrir um projeto: Easing NAO define operator== (classe inteira, keyframe.dart:22-264), entao o `indexWhere((p) => p.$2 == curva)` de editor_de_curva.dart:100 compara por identidade e o _asEasing de project_store.dart:72 constroi instancia nova em tempo de execucao — o rail nunca destaca nada e o rotulo vira "Bezier ajustada a mao" ate para Linear. Achei ainda dois defeitos menores confirmados: abrirCurvaDoNo/abrirCurvaDaCamera passam `atual: Easing.linear` cravado (ficha_do_selecionado.dart:1214 e 1232), mentindo sobre a curva guardada da trilha 3D; e o `<` do cabecalho, com a curva aberta, chama fecharFerramenta (painel_da_camada.dart:600-603) que nao limpa curvaEmEdicaoProvider — a curva continua na tela e o painel de tras se perde. Faltam tambem a inversao e o menu ••• do canto inferior esquerdo do rail; o botao que ocupa aquele lugar hoje e "Aplicar em todos os trechos", que e outra funcao.

### `!!` A curva exibida tem de ser a curva realmente aplicada naquele intervalo — nao herdar dado do contexto anterior nem inventar um valor.

- evidencia: P (p.23, ultimo paragrafo; p.24 "o botao de familia ativo precisa refletir a curva aplicada")
- hoje: ficha_do_selecionado.dart:1209-1216 (abrirCurvaDoNo) e 1226-1234 (abrirCurvaDaCamera) passam `atual: Easing.linear` CRAVADO, sem consultar o ease guardado no trecho; o setter existe (setSceneNodePropEase / setSceneCameraPropEase) mas o getter nunca e chamado.
- divergencia: Abrir a curva de uma trilha 3D com Saltar aplicado mostra Linear. O grafico, o rail e o rotulo mentem sobre o projeto.
- mudanca: Expor no controller um `sceneNodePropEaseAt(n, p, comeco)` e `sceneCameraPropEaseAt(cam, p, comeco)` e usa-los em `atual:` no lugar de Easing.linear, exatamente como controles_da_camada.dart:277-286 faz com easeAt.
- risco: Se o getter devolver o ease do keyframe errado (o do FIM do trecho em vez do do inicio), o primeiro arrasto sobrescreve o trecho vizinho. Usar a mesma convencao de setSegmentEase: a curva pertence ao keyframe que ABRE o trecho.
- teste: Aplicar Easing.bounce num trecho de uma trilha de SceneNode, fechar, reabrir a curva e `expect(c.read(curvaEmEdicaoProvider)!.atual.type, EasingType.bounce)`.

### `!!` A direita ha DUAS colunas: presets graficos da familia corrente na coluna interna e o SELETOR DE FAMILIA de curva na coluna mais externa.

- evidencia: V 01:33-01:35 e 01:37-01:43 (p.23; confirmado ampliando p23_0, p24_0 e p24_2: com Bezier ativo a coluna interna traz linear/entra/sai/suave e a externa destaca o cartao Bezier; com Saltar ativo a externa destaca o cartao da familia e a interna passa a listar Saltar/Elastico/Ciclico/Aleatorio)
- hoje: editor_de_curva.dart:143 `_RailDePresets(escolhido: iPreset, aoEscolher: aplicar)` — UMA coluna de 54 px (linha 301) com uma ListView chapada de `presetsDeCurva` (linhas 39-47): Linear, Suave, Entra, Sai, Passa do ponto, Quica, Elastico. Familias e presets bezier no mesmo nivel.
- divergencia: Falta a coluna externa inteira. A taxonomia de dois niveis do AM (familia x preset dentro da familia) esta achatada num nivel so, e por isso nao ha onde caber Ciclico e Aleatorio sem esticar a mesma lista.
- mudanca: Quebrar `presetsDeCurva` em duas listas: `familiasDeCurva` (Bezier, Fisica/Saltar, Degraus, ...) para uma coluna externa de cartoes com fundo, e `presetsDaFamilia(familia)` para a coluna interna (bezier -> Easing.bezierPresets, que ja existe em keyframe.dart:68 e hoje e codigo morto; fisica -> bounce, elastic, cyclic, random). Trocar de familia mantem o intervalo e so troca o type; trocar de preset so troca os parametros dentro da familia.
- risco: Se trocar de familia zerar os parametros da familia antiga, o usuario que so quis espiar Saltar volta para Bezier e perde as alcas que tinha ajustado. Guardar o ultimo Easing por familia enquanto o painel esta aberto, ou nao aplicar ao projeto ate o preset ser tocado.
- teste: Com Saltar aplicado, `expect(find.bySemanticsLabel('Familia Saltar'), ...)` selecionado na coluna externa E `find.bySemanticsLabel('Ciclico')` presente na coluna interna; escolher Ciclico e conferir `easeAt(comeca).type == EasingType.cyclic`.

### `!!` Familia Saltar dentro do mesmo editor de intervalos, com modelo de curva e parametros reais — o controle amarelo altera a configuracao visivel.

- evidencia: V 01:37-01:40 (p.24, tabela: "Curva com rebotes; controle amarelo altera a configuracao visivel" / "Usar modelo de curva e parametros reais, nao um SVG estatico")
- hoje: Modelo: keyframe.dart:43 `static const bounce = Easing(type: EasingType.bounce);` e keyframe.dart:105-106 `case EasingType.bounce: return Curves.bounceOut.transform(t);` — sem nenhum parametro (o campo `count` da classe nao e lido pelo caso bounce). UI: rotulo 'Quica' em editor_de_curva.dart:45; editor_de_curva.dart:420 `final bezier = curva.type == EasingType.cubicBezier;` e 459 `comBotoes: bezier`, e o pintor sai em 534 com `if (!comBotoes) return;`.
- divergencia: A curva desenhada e real (vem de transform, nao de SVG) — essa metade esta certa. Mas nao existe controle amarelo nenhum, nem parametro para ele mexer: bounce e um Curves.bounceOut congelado. E o rotulo e 'Quica', nao 'Saltar'.
- mudanca: Dar ao caso bounce um parametro real (numero de rebotes usando o `count` que ja esta na classe, e/ou amortecimento) implementando a queda amortecida em transform no lugar de Curves.bounceOut; desenhar UM disco amarelo no quadro ligado a esse parametro e liberar o arrasto para tipos nao-bezier em vez de sair em editor_de_curva.dart:534. Renomear o preset para 'Saltar'.
- risco: Trocar Curves.bounceOut por formula propria muda a animacao de projetos JA salvos com bounce. Escolher os parametros default de modo que transform() reproduza Curves.bounceOut dentro de ~1e-3, e fixar isso em teste antes de mexer na UI.
- teste: Teste de valor: `Easing(type: bounce).transform(t)` continua igual a Curves.bounceOut em 100 amostras (guarda de regressao). Teste de widget: com Saltar aplicado, arrastar o disco amarelo e `expect(easeAt(comeca).count, isNot(antes))` sem que type, propriedade ou keyframes mudem.

### `!!` Familia Ciclico: curva periodica, nome "Ciclico", com alcas/controles, dentro do mesmo editor.

- evidencia: V 01:40,5 (p.24, tabela: "Curva periodica, nome Ciclico e alcas/controles")
- hoje: Modelo EXISTE e e parametrico: keyframe.dart:11 `cyclic` no enum e 115-121 `case EasingType.cyclic:` usando `count` (ciclos) e `smooth` (1 = senoide, 0 = dente de serra). UI: NAO EXISTE — `presetsDeCurva` (editor_de_curva.dart:39-47) nao tem Ciclico, e o unico outro ponto do app que cita EasingType.cyclic e um importador (cena_xml_import.dart), nunca a interface. `Easing.label` (keyframe.dart:253-262) sabe dizer 'Ciclico' e nunca e chamado por ninguem.
- divergencia: A familia nao tem porta. Um projeto com cyclic (vindo do importador ou de JSON) anima certo mas nao pode ser aberto, visto nem alterado no editor de curva.
- mudanca: Incluir Ciclico na coluna interna da familia de fisica (junto com a mudanca da linha do rail de duas colunas) e ligar `count` e `smooth` a dois controles amarelos no quadro.
- risco: `smooth` fora de 0..1 ou `count` = 0 produzem transform com divisao/valor fora de faixa; o codigo ja protege com `count < 1 ? 1 : count`, mas o clamp de `smooth` nao existe — a UI tem de limitar antes de gravar.
- teste: Escolher Ciclico no rail e `expect(easeAt(comeca).type, EasingType.cyclic)`; arrastar o controle de ciclos e conferir que `count` mudou e que `transform(0)==0` e `transform(1)==1` continuam valendo.

### `!!` Familia Elastico: oscilacao que se estabiliza, DOIS controles amarelos e guias pontilhadas; editar os parametros sem perder keyframes, intervalo, propriedade nem valor de destino.

- evidencia: V 01:41-01:43 (p.24, tabela)
- hoje: Modelo: keyframe.dart:44 `static const elastic = Easing(type: EasingType.elastic);` e 107-108 `case EasingType.elastic: return Curves.elasticOut.transform(t);` — zero parametros (response/damping da classe so sao lidos pelo caso `spring`, keyframe.dart:130-156). UI: preset 'Elastico' em editor_de_curva.dart:46, sem alca nenhuma (editor_de_curva.dart:534) e sem guias pontilhadas alem da grade de fundo.
- divergencia: Faltam os dois controles amarelos, as guias pontilhadas e — antes disso — os parametros que eles moveriam. O AM mostra um controle sobre uma pista tracejada ACIMA do quadro e outro dentro do quadro; no Aurea nao ha nem um.
- mudanca: Fazer o caso elastic usar `response` (periodo) e `damping` (amortecimento), que ja sao campos da classe e ja estao serializados so para spring (project_store.dart:64-68 — passar a gravar sempre); desenhar dois discos amarelos com guia tracejada e liberar o arrasto para tipos nao-bezier. O aplicar continua chamando setSegmentEase, que so troca o ease e nao toca em keyframes.
- risco: project_store.dart:64 so grava response/damping quando type==spring: se a UI passar a editar esses campos em elastic sem corrigir a serializacao, o ajuste some ao salvar e reabrir. Corrigir a gravacao no MESMO commit, com fallback para os defaults antigos na leitura (ja existe em project_store.dart:81-83).
- teste: Aplicar Elastico, arrastar cada um dos dois controles, salvar via project_store, reler e `expect(easeAt(comeca).damping, o valor arrastado)`; e `expect(trilha.keyframes.length, antes)` para provar que nenhuma marca se perdeu.

### `!!` O botao de familia/preset ativo precisa refletir a curva aplicada.

- evidencia: P (p.24, paragrafo final)
- hoje: editor_de_curva.dart:100 `final iPreset = presetsDeCurva.indexWhere((p) => p.$2 == curva);`, e a classe Easing (keyframe.dart:22-264) NAO define `operator ==` nem `hashCode` — o `==` e identidade. project_store.dart:72-83 (`_asEasing`) constroi um Easing NOVO, nao-const, ao abrir o projeto.
- divergencia: Confirmado: depois de salvar e reabrir um projeto, nenhum preset fica destacado (editor_de_curva.dart:326 `i == escolhido`) e editor_de_curva.dart:239 mostra 'Bezier ajustada a mao' mesmo quando a curva e exatamente Linear, Quica ou Elastico. So funciona na mesma sessao, porque ai a instancia const aplicada e a mesma que volta.
- mudanca: Implementar `operator ==` e `hashCode` em Easing sobre os onze campos (com tolerancia nao — igualdade exata basta, os presets sao constantes), ou trocar o indexWhere por comparacao de campos. Preferir o operator==: `_PintorDaCurva.shouldRepaint` (editor_de_curva.dart:552) e `_Miniatura.shouldRepaint` (374) tambem melhoram, deixando de repintar a cada instancia nova identica.
- risco: Easing e usado como parte de Keyframe dentro de listas comparadas em varios pontos do controller; ganhar igualdade por valor pode fazer alguma checagem de "mudou?" passar a dizer "nao mudou" e engolir um passo de desfazer. Rodar a suite inteira, nao so os testes de curva.
- teste: `expect(Easing.bounce == Easing(type: EasingType.bounce), isTrue)`; e teste de widget: salvar/reabrir um projeto com Easing.easeInOut e `expect(find.text('Suave'), findsOneWidget)` no rotulo sob o quadro.

### `!!` A esquerda ficam os controles de retorno, INVERSAO e MENU; o video mostra o menu da curva no canto inferior esquerdo (a captura prevalece sobre o texto de 2023 que fala em canto inferior direito).

- evidencia: V 01:33-01:35 (p.23, caixa "A CAPTURA PREVALECE SOBRE TEXTO ANTIGO"; confirmado ampliando p23_0: `<` no topo, setas cruzadas embaixo, ••• no canto inferior esquerdo)
- hoje: editor_de_curva.dart:150-176 `_RailDaCurva`: SizedBox de 46 px com `MainAxisAlignment.start` e DOIS botoes colados no topo — `Icons.chevron_left_rounded` ('Fechar a curva') e `Icons.repeat_rounded` ('Aplicar em todos os trechos'). Nao ha inversao nem menu.
- divergencia: Tres coisas: (a) inversao da curva NAO EXISTE em lugar nenhum do app; (b) o ••• NAO EXISTE; (c) o segundo botao esta grudado no topo, onde o AM nao poe nada, e a base do rail fica vazia.
- mudanca: Reorganizar `_RailDaCurva` em tres ancoras: `<` no topo (spacer no meio), inversao e ••• no rodape. Implementar inverter como espelho do easing: bezier vira (1-x2, 1-y2, 1-x1, 1-y1); para os tipos nao-bezier, ou aplicar a mesma reflexao sobre transform, ou deixar o botao apagado enquanto nao houver referencia — apagado e honesto, inventar nao.
- risco: Espelhar bezier com y fora de 0..1 (o overshoot que editor_de_curva.dart:429 permite ate 1.5) gera curva que sai da moldura pelo outro lado; o clamp de desenho ja existe (clipRect na linha 515) mas o valor gravado precisa do mesmo limite -0.5..1.5.
- teste: Aplicar easeIn, tocar 'Inverter' e `expect(easeAt(comeca), Easing.easeOut)` (depois do operator== da linha anterior); e `expect(tester.getRect(find.bySemanticsLabel('Mais opcoes da curva')).bottom, closeTo(rectDoRail.bottom, 8))` para provar a ancoragem no rodape.

### `!!` Trocar de propriedade, camada ou intervalo tem de trocar a curva exibida e o estado dela, sem herdar dados do contexto anterior.

- evidencia: P (p.23, ultimo paragrafo; e o invariante de p.7 "nunca reabrir um painel do objeto anterior")
- hoje: `CurvaEmEdicao` (editor_de_curva.dart:16-34) e um INSTANTANEO: guarda `atual` e closures que ja capturaram `comeca` (controles_da_camada.dart:296-300). Nada reconstroi esse objeto quando o cabecote anda ou outra camada e selecionada — e a linha do tempo continua visivel e tocavel com a curva aberta (editor_screen.dart:247-262). Alem disso `_rascunho` (editor_de_curva.dart:82) so e limpo em `fechar()` (linha 96), e a linha 88 le `_rascunho ?? aberta.atual`.
- divergencia: Mover o cabecote para outro trecho, ou selecionar outra camada, deixa o editor escrevendo no trecho ANTIGO e mostrando a curva antiga. Se o provider for trocado por fora (ficha_do_selecionado.dart:1212/1230, painel_de_cor.dart:62), `_rascunho` sobrevive e desenha a curva do contexto anterior.
- mudanca: Duas coisas. (1) Guardar no provider a IDENTIDADE do alvo (layerId, prop/chave, inicio do trecho) em vez do valor, e derivar `atual` por um watch do projeto — assim o cabecote entrando noutro trecho reabre a curva certa ou fecha o editor se nao houver trecho. (2) Zerar `_rascunho` num `didUpdateWidget`/listener do provider, nao so no fechar.
- risco: Se o editor passar a seguir o cabecote, tocar Play com a curva aberta faz a curva piscar de trecho em trecho. Congelar o alvo enquanto o transporte estiver rodando, ou fechar a curva ao dar play.
- teste: Abrir a curva no trecho 0-1 s, aplicar Suave; mover o cabecote para 1,5 s (trecho seguinte) e `expect(c.read(curvaEmEdicaoProvider)!.atual, easeAt(1s))`; arrastar a alca e conferir que quem mudou foi o SEGUNDO trecho, nao o primeiro.

### `!!` Entrar e sair do painel nao pode trocar o tipo de easing, e voltar tem de recuperar o contexto de camada sem perder valores.

- evidencia: P (p.24, paragrafo final; e p.7 "Fechar restaura exatamente o estado anterior")
- hoje: O easing em si esta a salvo: `fechar()` (editor_de_curva.dart:95-98) so anula o provider e nao desfaz nada — coberto por test/efeitos_e_curva_test.dart:299-315. MAS com a curva aberta o cabecalho e `_CabecalhoDaFerramenta(titulo: 'Curva de gradacao')` sem `aoSair` (editor_screen.dart:418), e editor_screen.dart:574 faz `aoSair == null ? fecharFerramenta(ref) : ...`; `fecharFerramenta` (painel_da_camada.dart:600-603) poe estadoDoPainel em `recolhido` e categoriaAberta em null, e NAO limpa curvaEmEdicaoProvider.
- divergencia: Tocar o `<` do cabecalho com a curva aberta nao fecha nada visivel (painel_da_camada.dart:331 checa a curva antes de `estado == recolhido`, linha 345): a curva continua na tela e o painel de tras foi apagado por baixo. Quando a pessoa enfim fecha a curva, cai no editor sem painel nenhum, em vez de voltar para a familia de onde entrou. O tipo de easing nao muda — a perda e de contexto de retorno.
- mudanca: Passar `aoSair` explicito no ramo da curva de editor_screen.dart:417-419, apontando para a mesma saida do `<` do rail (limpar so curvaEmEdicaoProvider); e, por seguranca, fazer `fecharFerramenta` limpar tambem curvaEmEdicaoProvider, para que nenhum outro caminho deixe a curva orfa.
- risco: Se `fecharFerramenta` passar a limpar a curva, algum caminho que hoje conta com a curva sobreviver a um recolhimento muda de comportamento — pelos usos lidos (linha_do_tempo.dart:1467, painel_da_camada.dart:322/576) nao ha nenhum, mas vale rodar a suite.
- teste: Abrir a curva a partir de uma categoria, tocar o `<` do CABECALHO, e `expect(c.read(curvaEmEdicaoProvider), isNull)` e `expect(c.read(estadoDoPainelProvider), EstadoDoPainel.categoria)` — o painel de onde se veio, nao `recolhido`.

### `! ` O menu da curva traz overshoot e copiar/colar curva.

- evidencia: D2 (Alight Motion, Animation Easing Curves) — o PDF avisa: nao aberto no video, "nao inventar a composicao desse menu sem referencia visual"
- hoje: NAO EXISTE. Nao ha menu ••• (editor_de_curva.dart:150-176). Overshoot existe so como preset fixo 'Passa do ponto' (editor_de_curva.dart:44 / keyframe.dart:42) e como o clamp de -0.5..1.5 no arrasto (editor_de_curva.dart:429), nunca como opcao de menu. Copiar/colar curva nao existe em nenhum arquivo lido.
- divergencia: O menu inteiro falta. Mas o proprio PDF proibe compor esse menu sem referencia visual.
- mudanca: Criar o ••• com as DUAS entradas documentadas (overshoot, copiar/colar curva) e nada alem disso; nao inventar itens para preencher. Copiar/colar guarda um Easing num provider e cola no trecho aberto.
- risco: Colar uma curva de outro tipo num trecho pode mudar o type sem o rail acompanhar — depende do operator== da linha do botao ativo estar pronto antes.
- teste: Copiar de um trecho com Elastico, colar noutro trecho e `expect(easeAt(outroComeco).type, EasingType.elastic)` com os keyframes intactos.

### `! ` Setas sob o grafico, com o nome da curva ao centro, para andar entre curvas sem escolher na lista.

- evidencia: V 01:33-01:43 (p.23 "setas sob o grafico"; ampliando p24_0: chips arredondados com fundo, nome 'Saltar' centrado em cinza)
- hoje: editor_de_curva.dart:132-139 + 221-287 `_NomeDoPreset`: altura 34, seta esquerda, texto centrado (AmColors.muted, 12 px, w600), seta direita; as setas andam ciclicamente por `presetsDeCurva`.
- divergencia: A estrutura esta. Duas diferencas: (a) o nome exibido e o do PRESET, enquanto o AM nomeia a FAMILIA ('Efeito Ease de Cubico-Bezier' tanto na linear quanto na bezier ajustada, 'Saltar', 'Ciclico', 'Elastico'); (b) as setas do AM sao chips com fundo arredondado, as do Aurea sao icone puro (editor_de_curva.dart:283).
- mudanca: (a) Trocar o texto por `curva.label` da familia (keyframe.dart:253-262, hoje codigo morto) e fazer as setas andarem entre FAMILIAS, com a coluna interna cuidando dos presets. (b) Envolver o icone das setas num Container com AmColors.chip e raio ~8.
- risco: As setas hoje sao o unico caminho para 'Passa do ponto' num painel estreito; se passarem a andar so por familias, garantir que a coluna interna de presets esteja sempre visivel ou o overshoot fica inalcancavel.
- teste: Com Bezier ajustada a mao, `expect(find.text('Efeito Ease de Cubico-Bezier'), findsOneWidget)`; tocar a seta direita e conferir que o type passou para a proxima familia, nao para o proximo preset.

### `! ` Uma marca vertical pontilhada aparece dentro do grafico, na mesma posicao horizontal em 01:33.0 e em 01:35.0 enquanto as alcas se movem.

- evidencia: V 01:33.0 / 01:35.0 (observado ampliando p23_0 e p23_1; o texto do PDF nao nomeia esse elemento, entao o que ele significa — cabecote dentro do trecho — nao esta provado: essa leitura e N)
- hoje: NAO EXISTE. `_PintorDaCurva.paint` (editor_de_curva.dart:492-549) desenha grade, curva, pontos finais e alcas — nenhuma marca de tempo. `_PintorDaCurva` nem recebe o playhead.
- divergencia: Falta a marca. Como a leitura dela e N, o que se pode afirmar e so a presenca do elemento, nao a funcao.
- mudanca: Passar ao pintor a fracao do cabecote dentro do trecho (playhead local menos `comeca`, sobre a duracao do trecho) e desenhar uma vertical pontilhada branca nessa fracao. So depois de confirmar a funcao com referencia adicional — se a confirmacao nao vier, deixar como esta.
- risco: Se a marca for repintada a cada quadro do transporte, o painel inteiro repinta durante o play; isolar num RepaintBoundary proprio ou so desenhar com o transporte parado.
- teste: Com o cabecote em 25% do trecho, print da UI por teste mostrando a vertical em x = 0,25 da largura do quadro.

### `~ ` Grafico em grade, curva verde, pontos finais e duas alcas brancas com tangentes.

- evidencia: V 01:33.0 e 01:35.0 (p.23)
- hoje: editor_de_curva.dart:494-548: grade tracejada 4x4 em AmColors.muted a 25%; curva com 96 amostras em AmColors.accent (#1ED6B1, am_colors.dart:46) com traco 3; pontos finais em circulos verdes de raio 5 (531-532); tangentes brancas a 50% e discos brancos de raio 18 (539-547), so quando bezier.
- divergencia: A anatomia bate. Sobram diferencas de aparencia: a grade do AM e uma malha pontilhada fina (muitas celulas) com um retangulo tracejado marcando a caixa unitaria, contra 4x4 tracejado aqui; e o verde do AM e mais amarelado que o teal #1ED6B1.
- mudanca: Densificar a malha (pontilhado fino) e desenhar por cima o retangulo tracejado da caixa 0..1. A cor so mexer se houver medida do quadro do video — nao chutar.
- risco: Malha densa e muitas chamadas de linha por quadro num painel repintado a cada movimento do dedo; desenhar a grade num Picture guardado, ou usar drawPoints/drawRawPoints em vez de um drawLine por traco.
- teste: Print da UI por teste (RepaintBoundary com GlobalKey, conforme a rotina do projeto) comparado com o quadro de referencia; e um teste que conta chamadas do canvas para a grade nao passar de um teto.

### `ok` O cabecalho da superficie chama-se "Curva de gradacao".

- evidencia: V 01:33-01:35 (PDG p.23: "titulo Curva de gradacao")
- hoje: lib/src/features/editor/presentation/editor_screen.dart:417-419 — `if (ref.watch(curvaEmEdicaoProvider) != null) return const _CabecalhoDaFerramenta(titulo: 'Curva de gradacao');`, e a checagem vem ANTES de qualquer outro estado de painel.
- divergencia: NENHUMA

### `ok` O contexto temporal e a previa continuam visiveis enquanto a curva e editada; a curva e ferramenta no rodape, nao modal desfocado.

- evidencia: V 01:33-01:35 (PDF p.23, linha de abertura da secao 12)
- hoje: painel_da_camada.dart:331-343 monta EditorDeCurva num Positioned de rodape com altura PainelDaCamada.alturaMaxima; alturaDaFerramentaAberta (painel_da_camada.dart:575-580) devolve essa altura e editor_screen.dart:241-262 desconta do PREVIEW, mantendo transporte + regua + uma trilha da linha do tempo (chaoComFerramenta, linhas 247-250).
- divergencia: NENHUMA

### `ok` A curva aberta e a do INTERVALO selecionado (entre duas marcas), nunca uma curva solta.

- evidencia: P (p.23: "abrir a curva do intervalo selecionado, nao uma curva solta")
- hoje: controles_da_camada.dart:266-301: acha inicioDoTrecho e depois, `temTrecho = inicioDoTrecho != null && depois != null`, e `aoAbrirCurva: !temTrecho ? null : ...` com `atual: easeAt(comeca)` e `aoAplicar: setSegmentEase(camada.id, prop, comeca, e)`. painel_de_cor.dart:45-70 faz o mesmo para trilhas de contorno.
- divergencia: NENHUMA nas propriedades de camada e de contorno.

### `ok` Toda escolha atualiza a previa e o projeto renderizado; manipular alcas atualiza a previa no tempo corrente.

- evidencia: P (p.23 e p.24)
- hoje: editor_de_curva.dart:90-93 `aplicar` chama `aberta.aoAplicar(e)` a cada quadro do arrasto (via `_Quadro.mover`, linhas 422-433, chamado em onPanUpdate 448), e o callback e `setSegmentEase` no editorController — o mesmo estado que a previa observa. Alcas e desenho usam os MESMOS numeros do motor (`curva.transform` em editor_de_curva.dart:510).
- divergencia: NENHUMA

### `ok` Nao declarar "todas as curvas AM" so porque tres paineis foram implementados; outros icones de familia aparecem na lateral e nem todos foram abertos, e as setas e cada preset lateral nao foram todos acionados.

- evidencia: N (p.23 e p.24, notas finais)
- hoje: O modelo tem oito tipos (keyframe.dart:9-18): cubicBezier, bounce, elastic, cyclic, random, steps, elasticSteps, spring. A UI alcanca tres (cubicBezier, bounce, elastic) — editor_de_curva.dart:39-47. Random, steps, elasticSteps e spring nao tem porta nenhuma.
- divergencia: Fica N: o video nao prova o layout dos paineis dessas familias, entao nao ha alvo para comparar. Nao inventar equivalencia.

### Extensoes do Aurea nesta superficie

O PDF manda preservar e dar destino contextual — nunca apagar.

- "Aplicar em todos os trechos" (editor_de_curva.dart:168-172 e controles_da_camada.dart:299-301, `applyEaseToAllSegments`): aplica a curva a TODOS os trechos daquela propriedade de uma vez, e so aparece quando ha mais de dois keyframes. O AM nao mostra isso. Problema: ele ocupa hoje exatamente o lugar do botao de INVERSAO do AM, no rail esquerdo. Destino contextual: mover para dentro do menu ••• (junto com overshoot e copiar/colar), que e onde o AM poe acoes de curva que nao sao gesto direto.
- Editor de curva alcancavel a partir da cena 3D: abrirCurvaDoNo e abrirCurvaDaCamera (ficha_do_selecionado.dart:1199-1234) usam o MESMO editor para trilhas de SceneNode e de Camera3D. Nao ha equivalente filmado no AM. Preservar como esta — e justamente o que evita um segundo sistema de curvas; so precisa parar de cravar Easing.linear.
- Editor de curva alcancavel a partir de trilhas de contorno de forma (painel_de_cor.dart:55-80, `setShapeItemTrackSegmentEase` / `applyEaseToAllShapeItemTrackSegments`): espessura e opacidade do contorno tambem tem curva por trecho. Fora da gravacao. Preservar.
- Preset "Passa do ponto" (overshoot, keyframe.dart:42) como quinto preset bezier: o AM mostra quatro na coluna interna do Bezier (linear, entra, sai, suave) e trata overshoot como item de MENU (D2). Destino: manter o preset, e alem dele expor overshoot no ••• quando o menu existir.
- Alca bezier com y livre entre -0,5 e 1,5 (editor_de_curva.dart:426-429): permite construir o exagero a mao, com o desenho recortado pela moldura (clipRect, linha 515). Nao ha prova de que o AM permita o mesmo alcance. Preservar; o clamp e o que impede o valor de escapar da moldura.
- Lote de desfazer por gesto: `beginGesture`/`endGesture` (editor_de_curva.dart:123-128, editor_controller.dart:389-403) fazem um arrasto inteiro virar UM passo de desfazer em vez de dezenas. Invisivel na referencia, e correto. Preservar.
- Modelo de easing mais largo que o filmado: EasingType.random, steps, elasticSteps e spring, com os campos intensity, response, damping e initialVelocity (keyframe.dart:9-18, 22-35, 130-156). O `spring` sustenta as transicoes de interface do proprio app (appleEntrance, interfaceSpring, softSpring — keyframe.dart:46-66). Preservar inteiro; so nao dar porta na coluna de familias enquanto nao houver referencia.
- Rotulos de acessibilidade em todo controle da superficie (Semantics com label e selected — editor_de_curva.dart:192-197, 272-276, 310-315). Nada disso aparece no video. Preservar, e e o que torna testavel tudo que esta na coluna "teste" desta matriz.
- Codigo morto que a reconstrucao deveria aproveitar em vez de apagar: `Easing.bezierPresets` (keyframe.dart:68) e `Easing.label` (keyframe.dart:253-262) nao sao chamados por ninguem hoje, e sao exatamente as duas pecas que a coluna interna de presets e o rotulo de familia precisam. `CurvaEmEdicao.titulo` (editor_de_curva.dart:25-26) e preenchido por todos os quatro abridores e nunca renderizado — o cabecalho mostra sempre 'Curva de gradacao'. Decidir: ou some, ou vira subtitulo; hoje e promessa nao cumprida.

### Correcoes do conferente (1)

- **Familia Ciclico: curva periodica, nome "Ciclico", com alcas/controles, dentro do mesmo editor.**
  - afirmado: "o unico outro ponto do app que cita EasingType.cyclic e um importador (cena_xml_import.dart), nunca a interface" e, na divergencia, "Um projeto com cyclic (vindo do importador ou de JSON) anima certo mas nao pode ser aberto".
  - verdade: O importador NAO cita cyclic. Grep repo-wide por 'cyclic' em .dart (fora de .tooling/.dart_tool) devolve exatamente quatro ocorrencias, todas em lib/src/features/editor/domain/keyframe.dart: linha 13 (enum), 75 (comentario), 121 (case do transform) e 259 (label). lib/src/features/projects/domain/cena_xml_import.dart nao tem a palavra: seu mapeador Easing _curva(String? e) (linhas 401-422) so produz cubicBezier, elastic, bounce, steps, easeInOut, easeIn e easeOut, com '_ => Easing.linear' no default — nenhum ramo alcanca EasingType.cyclic, entao nenhum XML importado pode gerar a familia. A unica porta real e JSON cru desserializado por _asEasing (lib/src/features/editor/domain/project_store.dart:71-72), que faz 'EasingType.values[(m["t"] as num).toInt()]' e aceita qualquer indice do enum. O veredito da linha (a familia Ciclico nao tem porta na UI: presetsDeCurva em editor_de_curva.dart:39-47 nao a lista e Easing.label nunca e chamado) continua correto — o que esta errado e a evidencia citada para sustenta-lo.

---

## Configuracoes do projeto em sheet (PAGINA 25 - 13 PROJETO)

O Aurea tem o ESTADO certo e o conteudo errado. A maquina de estados exigida na pagina 7 ja existe (EstadoDoPainel.composicao, abrirAjustesDaComposicao em painel_da_camada.dart:456, fecharFerramenta em :601) e respeita as invariantes: abrir e fechar o painel nao mexe em selecao, cabecote nem historico. Mas das quatro opcoes que o video mostra em 01:47 — proporcao, resolucao, fps e plano de fundo — o Aurea implementa UMA: o fundo. As outras tres nao tem caminho de UI nenhum depois que o projeto e criado; o motor ate aceita (EditorController.setComposition, editor_controller.dart:453-462), mas o metodo nao tem um unico chamador em lib/, so em tres testes. O ponto de entrada tambem diverge: nao ha engrenagem, o gesto e o toque no nome do projeto, e a posicao que o AM da a engrenagem esta ocupada pelo AlternadorDeVista, que troca o modo da linha do tempo — o proprio comentario do codigo (editor_screen.dart:511) reconhece a apropriacao. E o sheet nao se comporta como sheet: em editor_screen.dart:433 o estado composicao TOMA o cabecalho inteiro, apagando nome do projeto e botao de exportar, quando no video os dois continuam visiveis; nao ha X dentro do painel; e a linha do tempo, que no AM fica coberta e 'reaparece', no Aurea nunca chega a sumir por decisao deliberada de layout. Faltam ainda o preset 4:3, a proporcao personalizada, a ordem correta das linhas e o rodape 'Tempo Total de Edicao' — para o qual nao existe dado equivalente no VideoProject, e cujo rotulo o PDF proibe expressamente mapear para a duracao da composicao. O risco maior nao esta em desenhar as linhas novas e sim em liga-las: setComposition e um copyWith puro, sem nenhuma conversao de geometria ou de grade de quadros, exatamente a destruicao silenciosa que a pagina 25 proibe.

### `!!` O ponto de entrada das configuracoes do projeto e a ENGRENAGEM do cabecalho de projeto, ao lado do botao de exportar.

- evidencia: V 01:47.0 (p25_0.png: engrenagem entre o titulo 'Nome do Projeto 2' e o botao verde de exportar) + D pagina 7, linha 'Menu / modal / ajustes <- engrenagem do projeto'
- hoje: Nao ha engrenagem. O gesto e o toque no NOME do projeto: lib/src/features/editor/presentation/editor_screen.dart:491 (Semantics label 'Ajustes da composicao') e :494 (onTap: abrirAjustesDaComposicao(ref)); a funcao esta em lib/src/features/editor/presentation/widgets/painel_da_camada.dart:456. O slot que o AM da a engrenagem esta ocupado pelo AlternadorDeVista (editor_screen.dart:516), que troca pilha/detalhado da linha do tempo — o proprio comentario em editor_screen.dart:511-512 admite isso: 'O ALTERNADOR DE VISTA ocupa o lugar que a referencia da a engrenagem'.
- divergencia: Nao existe engrenagem; o alvo de toque e o titulo, que no AM nao abre nada. O icone que ocupa a posicao da engrenagem faz outra coisa (modo da timeline), entao quem conhece o AM toca ali e muda a linha do tempo em vez de abrir as configuracoes.
- mudanca: Inserir um botao de engrenagem no _Cabecalho de editor_screen.dart, entre o Expanded do nome e o botao de exportar, chamando abrirAjustesDaComposicao(ref) com Semantics label 'Configuracoes do projeto'. Realocar o AlternadorDeVista para a barra da linha do tempo (LinhaDoTempo/transporte), onde ele age. Manter o toque no nome como caminho de renomear ou deixa-lo inerte, mas nunca como o unico caminho para o sheet.
- risco: Mover o AlternadorDeVista quebra qualquer teste ou gesto que o procure no cabecalho; o cabecalho ganha mais um alvo de 44 px e pode espremer o nome do projeto em telas estreitas (largura util de 384 px na referencia).
- teste: Teste de widget: montar EditorScreen, esperar find.bySemanticsLabel('Configuracoes do projeto') findsOneWidget, tocar e conferir estadoDoPainelProvider == EstadoDoPainel.composicao; e conferir que tocar no nome do projeto NAO troca modoDaLinhaDoTempoProvider.

### `!!` As configuracoes abrem como SHEET INFERIOR sem sair do editor: o cabecalho do projeto (voltar, nome, engrenagem, exportar) continua visivel e intacto atras/acima do sheet.

- evidencia: V 01:47.0 (p25_0.png: com o sheet aberto o topo ainda mostra '< Nome do Projeto 2', engrenagem e botao de exportar)
- hoje: O cabecalho e TOMADO: editor_screen.dart:433-435 troca a barra inteira por _CabecalhoDaFerramenta(titulo: 'Composicao'), que so tem a seta de voltar e o titulo (editor_screen.dart:541-580). Nome do projeto, alternador e botao de exportar somem enquanto o painel esta aberto.
- divergencia: No AM o sheet e uma camada POR CIMA do editor e o cabecalho de projeto permanece; no Aurea o sheet substitui o cabecalho, o que apaga o botao de exportar e o proprio nome do projeto que se esta configurando.
- mudanca: Em editor_screen.dart:433-435, remover o desvio para _CabecalhoDaFerramenta quando estado == EstadoDoPainel.composicao e deixar o _Cabecalho normal renderizar. O titulo e o X passam a viver dentro do proprio sheet (ver linha do X).
- risco: Sem o titulo 'Composicao' na barra, o sheet precisa se identificar sozinho, senao fica um painel anonimo; e a seta de voltar do cabecalho volta a significar 'sair do editor' com o sheet aberto, o que exige que o X do sheet seja o caminho de fechamento obvio.
- teste: Teste de widget: abrir o sheet e esperar que find.text(<nome do projeto>) e find.bySemanticsLabel('Exportar') continuem findsOneWidget; e que find.bySemanticsLabel('Fechar a ferramenta') NAO seja o unico caminho de saida.

### `!!` Fileira de presets de proporcao no topo do sheet, nesta ordem: 16:9, 9:16, 4:5, 1:1, 4:3, e um botao de lapis para proporcao personalizada; o preset ativo aparece destacado.

- evidencia: V 01:47.5 (p25_1.png: seis pastilhas brancas; a 1:1 pintada de verde; a ultima com icone de lapis)
- hoje: NAO EXISTE no sheet. PainelDaComposicao (painel_de_cor.dart:374-402) so tem o cartao de cor de fundo. Presets de proporcao existem apenas na CRIACAO do projeto: lib/src/features/projects/domain/project_presets.dart:21-48 define quatro opcoes na ordem 16:9, 9:16, 1:1, 4:5 (sem 4:3, sem personalizada) e lib/src/features/projects/presentation/new_project_sheet.dart:139-150 as desenha.
- divergencia: Depois de criado, o projeto nao tem nenhum caminho de UI para trocar de proporcao. Faltam tambem o preset 4:3 e a edicao personalizada, e a ordem dos quatro que existem esta trocada (1:1 antes de 4:5).
- mudanca: Levar a fileira de presets para PainelDaComposicao como primeira linha do sheet, ligada a EditorController.setComposition(aspectRatio: ...) (lib/src/features/editor/application/editor_controller.dart:454). Acrescentar 4:3 e o item de lapis a ProjectPresets.aspects e reordenar para 16:9, 9:16, 4:5, 1:1, 4:3. Destacar o preset cujo ratio bate com project.aspectRatio (tolerancia como a de projects_tab.dart:713).
- risco: Trocar a proporcao de um projeto ja montado reenquadra tudo: as camadas estao em pixels de composicao (VideoProject.outputWidth/outputHeight, video_project.dart:130-132) e nada hoje reposiciona ou reescala nada. Sem tratamento, mudar de 16:9 para 9:16 joga metade do conteudo para fora do quadro. A edicao personalizada e N no PDF — nao inventar o formulario dela sem referencia.
- teste: Teste de widget: abrir o sheet num projeto 16:9, tocar no preset '9:16', conferir editorControllerProvider.aspectRatio == 9/16 e que a moldura ValueKey('moldura-da-previa') mudou de proporcao; teste de unidade conferindo a ordem exata de ProjectPresets.aspects.

### `!!` Linha 'Resolucao' com o valor atual num controle de abrir (dropdown), rotulo a esquerda e valor a direita.

- evidencia: V 01:47.5 (p25_1.png: 'Resolucao' + campo branco '1080p (FHD)' com chevron)
- hoje: NAO EXISTE no sheet. Resolucao so e escolhida na criacao: new_project_sheet.dart:179-187, num CupertinoSlidingSegmentedControl com ProjectPresets.resolutions = [720, 1080, 2160] (project_presets.dart:50) e rotulos 'HD 720p' / 'Full HD 1080p' / '4K 2160p' (project_presets.dart:58-63). O setter existe e nao tem chamador: editor_controller.dart:454 setComposition(resolutionHeight:) so aparece em testes (test/ajustes_da_exportacao_test.dart:31, test/layout_da_tela_test.dart:36).
- divergencia: Nao ha como mudar a resolucao de um projeto ja criado. Quando existir, o controle e um segmented, nao um dropdown com rotulo a esquerda, e o rotulo e 'Full HD 1080p' e nao '1080p (FHD)'.
- mudanca: Adicionar em PainelDaComposicao uma linha rotulo+dropdown 'Resolucao' ligada a setComposition(resolutionHeight:). Alinhar o rotulo curto ao AM ('1080p (FHD)') mantendo os valores extras do Aurea (720p, 4K).
- risco: resolutionHeight e o LADO MENOR (ver a conta em new_project_sheet.dart:36-39 e o comentario em pindown_motion_template.dart:887): trocar o valor muda outputWidth/outputHeight e portanto a escala visual de tudo que estiver em pixels. O AM nao mostrou o dropdown aberto (N) — nao inventar opcoes alem das que o Aurea ja tem.
- teste: Teste de widget: abrir o sheet, tocar em 'Resolucao', escolher 720, conferir editorControllerProvider.resolutionHeight == 720 e que a ficha/moldura da previa reflete o novo quadro.

### `!!` Linha 'Quadros por segundo' com o valor atual num controle de abrir (dropdown).

- evidencia: V 01:47.5 (p25_1.png: 'Quadros por segundo' + campo branco '30 fps' com chevron)
- hoje: NAO EXISTE no sheet. Fps do projeto so na criacao: new_project_sheet.dart:188-195 com ProjectPresets.fpsOptions = [24, 30, 60] (project_presets.dart:51). Ha um fps SEPARADO de exportacao em lib/src/features/export/presentation/export_video_screen.dart:688-701 ('Quadros por segundo', com a opcao 'Do projeto (n)'), que nao altera o projeto.
- divergencia: O fps do projeto e imutavel depois da criacao; o unico campo com esse rotulo vive na tela de exportacao e tem outro significado (override de saida).
- mudanca: Adicionar a linha 'Quadros por segundo' ao PainelDaComposicao, ligada a setComposition(fps:). Manter o override da exportacao como esta, e deixar claro no rotulo de la que e da saida.
- risco: O fps define a grade de imantacao (PlaybackController.snap, playback_controller.dart:147) e o quadro em que os keyframes caem; mudar o fps para baixo pode fazer dois keyframes coincidirem no mesmo quadro. O PDF exige tratar a conversao de tempo explicitamente, sem destruicao silenciosa.
- teste: Teste de widget: abrir o sheet, trocar para 24 fps, conferir editorControllerProvider.fps == 24; e teste de unidade provando que nenhum keyframe some nem muda de Duration apos a troca.

### `!!` Ordem das opcoes no sheet, de cima para baixo: presets de proporcao, Resolucao, Quadros por segundo, Plano de fundo.

- evidencia: V 01:47.5 (p25_1.png) + P pagina 25 ('Refazer o ponto de entrada, o sheet, a ORDEM DAS OPCOES e o retorno')
- hoje: O sheet tem uma opcao so — o fundo (painel_de_cor.dart:384-398) —, entao nao ha ordem a comparar.
- divergencia: Tres das quatro linhas nao existem e a unica que existe esta em primeiro lugar quando deveria ser a ultima.
- mudanca: Montar PainelDaComposicao como uma coluna de quatro blocos nessa ordem exata, com o fundo por ultimo.
- risco: Baixo em si; depende das linhas anteriores existirem. Os 300 px de PainelDaCamada.alturaMaxima (painel_da_camada.dart:293) nao cabem quatro linhas mais o X — o sheet precisa de altura propria ou rolagem.
- teste: Teste de widget lendo a ordem vertical dos rotulos ('16:9', 'Resolucao', 'Quadros por segundo', 'Plano de fundo') por tester.getTopLeft e conferindo dy crescente.

### `!!` Proporcao, resolucao, fps e fundo alteram as CONFIGURACOES REAIS do projeto (nao sao so visual).

- evidencia: P pagina 25 ('Proporcao, resolucao, fps e fundo devem atualizar as configuracoes reais')
- hoje: Parcial. setBackgroundColor esta ligado (editor_controller.dart:464-465, chamado em painel_de_cor.dart:391). setComposition(aspectRatio/resolutionHeight/fps) existe em editor_controller.dart:453-462 mas NENHUM widget o chama — os unicos chamadores no repositorio sao testes (test/ajustes_da_exportacao_test.dart:31, test/imantacao_e_quadro_test.dart:44, test/layout_da_tela_test.dart:36).
- divergencia: Tres dos quatro ajustes nao tem caminho de UI para o motor; o motor ja aceita, falta o painel.
- mudanca: Ligar os tres controles novos do sheet a setComposition. Nao criar setters paralelos — setComposition ja passa por _mutate e portanto entra no historico de desfazer.
- risco: setComposition passa por _mutate: cada toque num preset vira um passo de desfazer. Se o controle for continuo (edicao personalizada), precisa de beginGesture/endGesture como o EscolhaDeCor faz, senao o desfazer enche de passos.
- teste: Teste de widget: para cada um dos tres controles, tocar e conferir o campo correspondente em editorControllerProvider; depois um undo e conferir que volta ao valor anterior num unico passo.

### `!!` Preservar os projetos antigos e tratar explicitamente qualquer conversao de tempo/geometria, sem destruicao silenciosa de keyframes.

- evidencia: P pagina 25 (obrigacao do agente)
- hoje: NAO EXISTE tratamento algum. setComposition (editor_controller.dart:453-462) e um copyWith puro: troca aspectRatio, resolutionHeight e fps e nao toca em camada, keyframe ou geometria. Como nenhum widget o chama hoje, o problema esta latente e so aparece quando o sheet for ligado.
- divergencia: Ligar os controles sem uma etapa de conversao entrega exatamente a destruicao silenciosa que o PDF proibe: mudar a proporcao joga camadas para fora do quadro; mudar o fps reimanta keyframes na nova grade.
- mudanca: Antes de aplicar a troca, calcular o efeito e ou reescalar/reposicionar as camadas pela razao entre os quadros antigo e novo, ou avisar em texto o que vai mudar. Aplicar tudo num unico passo de desfazer (runAsOneUndo), como as demais acoes estruturais.
- risco: Reescalar automaticamente pode estragar composicoes ajustadas a mao; nao reescalar deixa o conteudo fora do quadro. Qualquer das duas precisa caber num unico desfazer, senao a pessoa fica sem volta.
- teste: Teste de unidade: projeto 16:9 com uma camada centrada e dois keyframes; trocar para 9:16; conferir que a contagem de keyframes e os Durations deles nao mudaram e que a camada continua dentro do quadro; conferir que um unico undo restaura tudo.

### `! ` O sheet tem um X de fechar no canto superior esquerdo, dentro do proprio sheet.

- evidencia: V 01:47.0 e V 01:47.5 (p25_1.png: X branco no alto a esquerda do sheet, acima da fileira de proporcoes)
- hoje: NAO EXISTE. lib/src/features/editor/presentation/widgets/painel_da_camada.dart:352-365 monta o estado composicao como um Positioned com DecoratedBox e PainelDaComposicao direto, sem cabecalho nenhum; PainelDaComposicao (lib/src/features/editor/presentation/widgets/painel_de_cor.dart:374-402) comeca direto no _Titulo('Fundo'). O unico fechamento e a seta '<' do cabecalho tomado (editor_screen.dart:566-575 -> fecharFerramenta).
- divergencia: O sheet nao tem X proprio; fecha por uma seta que esta fora dele e que, no AM, significa outra coisa.
- mudanca: Adicionar ao topo de PainelDaComposicao uma linha de 44 px com um botao X (Icons.close_rounded / CupertinoIcons.xmark) a esquerda, Semantics label 'Fechar as configuracoes', chamando fecharFerramenta(ref).
- risco: Baixo. Consome ~44 px dos 300 de PainelDaCamada.alturaMaxima (painel_da_camada.dart:293), o que aperta as quatro linhas de opcao — provavelmente exige subir a altura maxima para este estado.
- teste: Teste de widget: abrir o sheet, find.bySemanticsLabel('Fechar as configuracoes') findsOneWidget, tocar, e esperar estadoDoPainelProvider == EstadoDoPainel.recolhido.

### `! ` Linha 'Plano de fundo' com amostra de cor e o nome da cor ('Preto') num controle de abrir.

- evidencia: V 01:47.5 (p25_1.png: 'Plano de fundo' + campo branco com quadrado preto e a palavra 'Preto', com chevron)
- hoje: EXISTE, com outra forma: painel_de_cor.dart:374-402 (PainelDaComposicao) mostra _Titulo('Fundo'), um EscolhaDeCor(rotulo: 'Fundo da composicao', painel_de_cor.dart:387-392) ligado a setBackgroundColor (editor_controller.dart:464-465), e um _Aviso sobre sequencia PNG (painel_de_cor.dart:394-397). O EscolhaDeCor (lib/src/features/editor/presentation/widgets/escolha_de_cor.dart:19-100) abre a paleta de 12 amostras e os controles RGB direto, sempre expandidos.
- divergencia: Rotulo diferente ('Fundo' / 'Fundo da composicao' em vez de 'Plano de fundo'); o controle nao e uma linha fechada com amostra e nome da cor, e a paleta inteira ocupa o sheet; nao ha nome legivel da cor ('Preto').
- mudanca: Trocar o rotulo para 'Plano de fundo' e colapsar o EscolhaDeCor numa linha rotulo+valor (amostra + nome da cor + chevron) que abre a paleta ao toque, como as outras tres linhas do sheet. Nomear as 12 cores prontas de escolha_de_cor.dart:41-54 para poder escrever 'Preto'.
- risco: O teste existente test/cor_e_preenchimento_test.dart:339-352 procura por find.bySemanticsLabel('Fundo da composicao') e pelas amostras visiveis de imediato; colapsar quebra esse teste e ele precisa ser reescrito, nao removido.
- teste: Teste de widget: abrir o sheet, conferir a linha 'Plano de fundo' com o texto 'Preto', toca-la, escolher roxo, e conferir backgroundColor e a cor da moldura ValueKey('moldura-da-previa') — reaproveitando as asserções de cor_e_preenchimento_test.dart:352-365.

### `! ` Rodape do sheet com 'Tempo Total de Edicao: mm:ss', centrado e discreto — e esse rotulo NAO deve ser reinterpretado como duracao da composicao.

- evidencia: V 01:47.0 mostra 01:27 e V 01:47.5 mostra 01:28 (p25_0.png / p25_1.png: o numero ANDA entre os dois quadros, confirmando que e tempo de sessao e nao duracao)
- hoje: NAO EXISTE. Nao ha rodape nenhum em PainelDaComposicao (painel_de_cor.dart:374-402) e nao ha nenhuma contagem de tempo de edicao no projeto — VideoProject (lib/src/features/editor/domain/video_project.dart:92-135) guarda createdAt e nada de tempo acumulado de sessao. O que o Aurea exibe de tempo e project.duration, na linha do tempo (lib/src/features/editor/presentation/widgets/linha_do_tempo.dart:148,162,188).
- divergencia: O campo inteiro nao existe. Nao ha dado que corresponda: duration e duracao da composicao, que e justamente o que o PDF proibe usar aqui.
- mudanca: Se for reproduzir: acrescentar um campo de tempo acumulado de edicao ao VideoProject (persistido), somando o tempo com o editor aberto, e mostra-lo centrado no rodape do sheet como 'Tempo Total de Edicao: mm:ss'. Nunca mapear para project.duration.
- risco: Mexer no formato serializado de VideoProject afeta projetos antigos — o campo precisa nascer opcional e tolerante a ausencia (regra de leitura tolerante do projeto). Um cronometro vivo no sheet forca rebuild por segundo.
- teste: Teste de unidade: abrir um projeto salvo sem o campo novo e conferir que carrega sem excecao com tempo zero; teste de widget conferindo que o texto do rodape NAO e igual a project.duration formatada.

### `! ` O retorno: o sheet fecha e a linha do tempo reaparece preservando as camadas e o estado (selecao, cabecote, historico).

- evidencia: V 01:47-01:47.5 ('O sheet fecha e a timeline reaparece preservando as camadas') + P pagina 7 (invariantes: nunca perder selecao ao abrir submenu, nunca reiniciar o playhead ao voltar)
- hoje: O estado e preservado: abrirAjustesDaComposicao (painel_da_camada.dart:456-459) so escreve estadoDoPainelProvider e categoriaAbertaProvider, sem tocar em selectedLayerProvider nem no PlaybackController; fecharFerramenta (painel_da_camada.dart:601-604) faz o inverso. Mas a linha do tempo nunca chega a sumir: alturaDaFerramentaAberta (painel_da_camada.dart:580-590) devolve 300 px que saem do PREVIEW, e o comentario de editor_screen.dart:238-245 e explicito — a timeline encolhe ate o chao (transporte + regua + uma trilha) e continua visivel por cima do painel.
- divergencia: Estado: NENHUMA. Cobertura: no AM o sheet cobre a area da timeline (por isso ela 'reaparece'); no Aurea o sheet nunca a cobre — quem cede espaco e a previa. E uma escolha deliberada e documentada do Aurea, contraria ao que o video mostra.
- mudanca: Decidir explicitamente: ou o sheet de COMPOSICAO (so ele, nao as ferramentas de camada) sobe por cima da linha do tempo como no AM, ou se registra como extensao aprovada do Aurea. Se for seguir o AM, tratar EstadoDoPainel.composicao a parte em alturaDaFerramentaAberta e no calculo de editor_screen.dart:241-276.
- risco: Cobrir a linha do tempo com o sheet contraria a regra ja escrita e testada de que a previa nao encolhe ao abrir ferramenta (editor_screen.dart:221-236); mexer no calculo de alturas quebra test/layout_da_tela_test.dart.
- teste: Teste de widget: selecionar uma camada, mover o cabecote para 2 s, abrir o sheet, fechar, e conferir selectedLayerProvider inalterado, playback.time.value == 2 s e project.layers.length inalterado.

### `ok` Nao inventar o conteudo dos dropdowns nem o formulario da proporcao personalizada — nao foram abertos no video.

- evidencia: N (pagina 25: 'os dropdowns e a edicao personalizada nao foram abertos')
- hoje: Nada existe no sheet para comparar; as listas que o Aurea ja tem sao as da criacao (project_presets.dart:50-51: 720/1080/2160 e 24/30/60).
- divergencia: NENHUMA — continua N. Ao construir os dropdowns, usar as listas que o Aurea ja tem, sem acrescentar valores inspirados no AM.

### `ok` Exportar e OUTRA acao, fora deste sheet, disparada pelo botao colorido do cabecalho de projeto.

- evidencia: V 01:47.0 (p25_0.png: botao verde de exportar no cabecalho, e nada de exportacao dentro do sheet) + N (a tela de exportacao nao foi aberta)
- hoje: EXISTE e corresponde: editor_screen.dart:518-538 desenha o botao colorido (AmColors.action) na ponta direita do cabecalho, e editor_screen.dart:285-291 abre a ExportVideoScreen como rota propria. Nada de exportacao dentro de PainelDaComposicao.
- divergencia: NENHUMA na separacao. A unica ressalva e a linha 2 desta matriz: enquanto o sheet esta aberto o cabecalho e tomado e o botao de exportar desaparece — no AM ele continua la.

### Extensoes do Aurea nesta superficie

O PDF manda preservar e dar destino contextual — nunca apagar.

- Escolha de cor de fundo muito alem do dropdown 'Preto' do AM: 12 amostras prontas e tres controles RGB (escolha_de_cor.dart:19-140), com beginGesture/endGesture para caber num unico passo de desfazer. Destino: manter, atras da linha colapsada 'Plano de fundo' — a linha mostra amostra e nome, o toque abre esta paleta.
- Aviso escrito sobre transparencia no sheet: 'A cor do fundo sai no arquivo exportado. Para um fundo transparente, exporte em sequencia PNG' (painel_de_cor.dart:394-397). O AM nao tem nada assim. Destino: preservar como nota de rodape do bloco de fundo.
- Resolucao 4K (2160) e fps 24 e 60 (project_presets.dart:50-51), alem do que o video mostrou. Destino: preservar dentro dos dropdowns novos, sem inventar valores extras.
- Padroes do aplicativo para proporcao, fps e resolucao, persistidos em preferencias (settings_controller.dart:9-11, 58-71) e usados ao criar projeto (new_project_sheet.dart:70-72). Isso e configuracao do APP, nao do projeto. Destino: continua nos Ajustes do Aurea, fora deste sheet.
- Folha de criacao de projeto com moldura desenhada na proporcao real e animada, nome sugerido e ficha viva '1080 x 1920 - 30 fps' (new_project_sheet.dart:104-196). O AM nao teve a criacao filmada (N). Destino: preservar; se a fileira de presets do sheet for extraida como componente, reaproveita-la aqui em vez de duplicar.
- Tela de exportacao completa com formato, tamanho, fps, codec e qualidade, mais estimativa de MB (export_video_screen.dart:652-740). Explicitamente N no PDF ('nao inventar menus de codecs, bitrate ou formatos'). Destino: preservar intacta, como acao separada atras do botao colorido do cabecalho — nunca migrar para dentro do sheet.
- O painel de composicao encolhe a PREVIA e mantem a linha do tempo visivel, em vez de cobri-la (editor_screen.dart:221-276, alturaDaFerramentaAberta em painel_da_camada.dart:580-590). Contraria o que o video mostra. Destino: decisao explicita — ou se alinha ao AM so para este sheet, ou se registra como extensao aprovada com o motivo ja escrito no codigo.
- AlternadorDeVista no cabecalho (editor_screen.dart:516, visao_geral_das_camadas.dart:51-83), que troca pilha/detalhado da linha do tempo. Nao existe no AM e ocupa a posicao da engrenagem. Destino: preservar a funcao, realocando o botao para a barra da linha do tempo, que e sobre o que ele age.
- Renomear, duplicar e excluir projeto pelo menu da lista de projetos (projects_tab.dart:356-419), e a ficha '16:9 - Full HD 1080p - 30 fps' de cada cartao (projects_tab.dart:713-717). Fora desta superficie, mas e onde vive hoje a unica leitura das configuracoes do projeto. Destino: preservar; a ficha passa a ser o espelho do que o sheet edita.

### Correcoes do conferente (2)

- **As configuracoes abrem como SHEET INFERIOR sem sair do editor: o cabecalho do projeto (voltar, nome, engrenagem, exportar) continua visivel e intacto atras/acima do sheet.**
  - afirmado: divergencia: 'No AM o sheet e uma camada POR CIMA do editor e o cabecalho de projeto permanece; no Aurea o sheet substitui o cabecalho, o que apaga o botao de exportar e o proprio nome do projeto que se esta configurando.'
  - verdade: O fato de codigo esta certo (editor_screen.dart:433-435 troca a barra por _CabecalhoDaFerramenta('Composicao'), definido em :541-580, e o botao de exportar so existe dentro de _Cabecalho, :513-536). O erro esta na EXIGENCIA: ela nao vem da especificacao e contraria o proprio PDF. Pagina 2, coluna RETIRAR DA PROPOSTA ANTERIOR (especificacao_am.txt:50): 'Exportacao global persistente mesmo em subpaineis' — e o par na coluna ADOTAR NESTA REVISAO (:51-52): 'Cabecalho de projeto, cabecalho de camada e cabecalho de propriedade distintos'. Ou seja, manter o exportar visivel dentro de subpainel e justamente o que a revisao manda TIRAR, e o cabecalho que muda com o contexto e o que ela manda ADOTAR. Pagina 6 (:264) confirma a regra por zona: 'Projeto: voltar, nome, ajustes, exportar. Camada: nome, parent, excluir. Propriedade: voltar e titulo' — e 'voltar + titulo centrado' e exatamente o que _CabecalhoDaFerramenta desenha. Na pagina 25 o unico registro V e 'sheet inferior com X' e 'O sheet fecha e a timeline reaparece preservando as camadas'; em nenhum ponto o PDF diz que o cabecalho de projeto continua visivel ou intacto atras do sheet. Logo, 'apagar o botao de exportar' nao e divergencia: e o comportamento prescrito. O que sobra de possivel divergencia real e outra coisa (X de fechar vs seta de voltar), que a matriz nao afirmou.
- **O ponto de entrada das configuracoes do projeto e a ENGRENAGEM do cabecalho de projeto, ao lado do botao de exportar.**
  - afirmado: divergencia: 'Nao existe engrenagem; o alvo de toque e o titulo, que no AM nao abre nada.'
  - verdade: O nucleo do item confere (nao ha engrenagem em lugar nenhum do cabecalho do editor — nenhuma ocorrencia de Icons.settings/CupertinoIcons.gear em lib/src/features/editor/; o gesto e o toque no nome, editor_screen.dart:491/494 -> painel_da_camada.dart:456; e o slot da engrenagem esta com o AlternadorDeVista, editor_screen.dart:516, que so troca o modo da linha do tempo, visao_geral_das_camadas.dart:51-82). O que a matriz nao pode afirmar e o trecho 'que no AM nao abre nada': o toque no nome do projeto nunca foi filmado. A gravacao entra no editor com o titulo visivel (pagina 4, 00:00-00:01,5) e nunca o aciona; a pagina 3 define exatamente esse caso como marca N ('botao visivel sem abertura, fluxo ausente'), e a pagina 26 exige 'anexar a referencia AM de cada uma' antes de aprovar ou reprovar paridade. Declarar como fato que no AM o titulo e inerte e evidencia que o PDF nao fornece.

---

## Presets e modais (vazios uteis, avisos com escopo) — PAGINA 20 da especificacao AM ONLY rev.02

A superficie de Presets NAO EXISTE na interface do Aurea. O motor esta pronto e desligado: EffectPreset/effectPresetToJson (lib/src/features/editor/domain/effect_preset.dart:19), a loja em disco fora do projeto (lib/src/features/editor/application/effect_preset_store.dart:20) e os dois comandos saveEffectPresetFrom/applyPreset (lib/src/features/editor/application/editor_controller.dart:941 e :966) nao tem UM chamador na camada de apresentacao — so testes. O enum AmSecao.presets (lib/src/features/editor/domain/am_sections.dart:40,85) declara a secao, mas o enum inteiro so e lido por test/nivel10_1_ui_final_test.dart; a grade que a tela usa de verdade e categoriasDaCamada() (lib/src/features/editor/presentation/widgets/painel_da_camada.dart:129-263) e ela nao tem 'presets'. Logo: nao ha tile, nao ha painel, nao ha vazio e nao ha modal de presets. Sobre modais: o editor nao tem NENHUM modal contextual — o unico dialogo dentro do editor e o teclado numerico do campo de valor (lib/src/features/editor/presentation/widgets/campo_de_valor.dart:229,288); as folhas do estudio 3D (folhas_do_estudio.dart:47) sao bottom sheets; e fora do editor convivem tres idiomas diferentes (AlertDialog Material em release_notice.dart:43, CupertinoAlertDialog em aviso_ao_vivo.dart:53 e projects_tab.dart:254). Os vazios do editor sao uma linha de texto cinza de 11 px sem acao (controles_da_camada.dart:577 e :1498-1511; painel_da_camada.dart:710-722). Do lado bom: o Aurea nao tem paywall nenhum — grep por assinatura/premium/paywall/anuncio na UI nao devolve nada de monetizacao — entao a parte "NAO IMPORTAR AUTOMATICAMENTE" da pagina 20 ja esta cumprida por ausencia, e o que falta e escrever um teste que a proteja. Achado colateral de fechamento/restauracao: catalogoDeEfeitosProvider, efeitoAbertoProvider e parametroAbertoProvider (controles_da_camada.dart:306-308) nunca sao zerados ao fechar a ferramenta nem ao trocar de camada (painel_da_camada.dart:440-460 e editor_screen.dart:150-161 so os escutam para descartar pendencia), o que faz o painel reabrir no estado do objeto anterior — o oposto exato da regra P da pagina 20 e do invariante da pagina 7.

### `!!` A grade de operacoes da camada tem um tile "Presets" que abre a superficie de presets da camada selecionada.

- evidencia: V 01:20.5 (grade inferior do quadro: Cor e preenchimento, Borda e sombra, Homogeneizacao e opacidade, Movimentacao e transformacao, Editar forma, Presets, Efeitos)
- hoje: NAO EXISTE na interface. lib/src/features/editor/domain/am_sections.dart:40 declara AmSecao.presets e :85 inclui presets em secoesDe() para toda camada que nao seja audio nem nulo — mas o enum inteiro so tem um leitor, test/nivel10_1_ui_final_test.dart:35. A grade que a tela monta e categoriasDaCamada() em lib/src/features/editor/presentation/widgets/painel_da_camada.dart:129-263, que nao tem categoria 'presets'; o switch de conteudo em lib/src/features/editor/presentation/widgets/controles_da_camada.dart:104-121 nao tem caso 'presets'; tituloDaFerramenta em painel_da_camada.dart:549-566 nao tem 'presets'.
- divergencia: Nao ha tile, nao ha rota e nao ha painel: nenhum caminho da interface chega a presets de camada. O enum que promete a secao e codigo morto para a UI.
- mudanca: Fazer categoriasDaCamada() derivar de secoesDe()/AmSecao em vez de manter uma segunda lista paralela; acrescentar a CategoriaDaCamada de id 'presets' com rotulo 'Presets', o caso 'presets' => PainelDePresets(...) em ControlesDaCategoria._conteudo e 'presets' => 'Presets' em tituloDaFerramenta.
- risco: As duas listas ja discordam hoje: secoesDe() respeita o teto kAmMaximoSecoes = 7 (am_sections.dart:45) mas categoriasDaCamada() entrega 10 cartoes para TextLayer e 9 para ShapeLayer. Unificar as duas quebra test/nivel10_1_ui_final_test.dart (teto de sete) ou apaga cartoes que hoje funcionam (mascara, mistura, midia, rastreio). Decidir o teto ANTES de mexer, senao a unificacao vira perda de funcionalidade — o que a diretriz vinculante proibe.
- teste: Widget test por tipo de camada: abrir o painel da camada e esperar find.byKey(const ValueKey('cartao-presets')); tocar e esperar 'Presets' no cabecalho da ferramenta. Mais um teste de contagem que prova que categoriasDaCamada(l).map(id) == secoesDe(l) para todo tipo, para o enum deixar de ser codigo morto.

### `!!` Sem nenhum preset salvo, a superficie de Presets abre um modal contextual: cantos arredondados, X no alto centralizado, imagem explicativa, titulo do tipo "Nenhum preset... ainda!", texto de orientacao e um unico botao de confirmacao ("Entendi").

- evidencia: V 01:21.0
- hoje: NAO EXISTE. Os vazios do editor sao uma linha de texto cinza de 11 px, sem titulo, sem imagem e sem acao: lib/src/features/editor/presentation/widgets/controles_da_camada.dart:577 ('Esta camada ainda nao tem efeito nenhum.'), a classe _Aviso em :1498-1511, e lib/src/features/editor/presentation/widgets/painel_da_camada.dart:710-722 ('Esta camada ainda nao tem ferramentas neste painel.'). O unico vazio ilustrado do app inteiro e _Vazio em lib/src/features/community/presentation/community_tab.dart:1380-1412 (icone 42 px + titulo 15/w700 + orientacao 13/1.4) — e ele nao tem botao de acao nem modal, e vive fora do editor.
- divergencia: Nem modal, nem X, nem ilustracao, nem botao; o vazio e texto morto num painel. E o vazio de presets especificamente nao existe porque a superficie nao existe.
- mudanca: Criar o widget do vazio de Presets com ValueKey('presets-vazio'): titulo, corpo de orientacao, ilustracao propria do Aurea (assets/ do proprio app, nunca a arte do AM) e um botao unico 'Entendi' que so fecha. Reaproveitar a tipografia de _Vazio da comunidade para nao inventar uma terceira escala.
- risco: Um modal por cima do painel pode roubar o foco do palco e, se for empurrado como rota, o PopScope do editor (editor_screen.dart:168) passa a receber o pop do modal — o gesto de voltar do Android fecharia o editor em vez do modal. Usar barreira propria dentro do Stack do editor, ou testar o PopScope explicitamente.
- teste: Widget test: abrir Presets com EffectPresetStore.semArquivo = true e lista vazia; esperar ValueKey('presets-vazio'), o titulo, e exatamente UM botao de acao; tocar em 'Entendi' e verificar que o modal saiu, que selectedLayerProvider continua igual e que playback.time nao mudou.

### `!!` A ilustracao/orientacao do vazio aponta o caminho real de criar um preset — no AM ela destaca o menu de operacoes de camada na barra de transporte.

- evidencia: V 01:21.0 (a arte do modal e uma captura do proprio transporte com o botao de operacoes de camada circulado)
- hoje: O slot existe mas e outra coisa: lib/src/features/editor/presentation/widgets/linha_do_tempo.dart:410-421 coloca Icons.copy_all_rounded com rotulo 'Duplicar camada' na sexta das sete posicoes do transporte (a ordem declarada em :332-341 e desfazer, refazer, inicio, PLAY, fim, duplicar, enquadrar). Nao ha menu de operacoes de camada, e nao ha nenhum ponto na interface que chame saveEffectPresetFrom (editor_controller.dart:941).
- divergencia: No AM aquele slot e um MENU de operacoes da camada (e o caminho que o proprio vazio ensina); no Aurea e uma acao unica e irreversivel de duplicar. Nenhuma ilustracao de vazio existe, e o caminho que ela deveria ensinar nao existe.
- mudanca: Transformar o slot em menu de operacoes de camada (duplicar continua la dentro, primeiro item) com 'Salvar como preset' chamando saveEffectPresetFrom; a ilustracao do vazio destaca ESSE botao, com arte gerada do proprio Aurea.
- risco: Trocar um toque que hoje duplica direto por um menu adiciona um toque a um gesto que ja esta na memoria muscular de quem testa. E o transporte tem sete alvos de proposito, com o PLAY no centro exato (linha_do_tempo.dart:332-338): trocar um alvo por um menu nao pode mudar a contagem, senao o play sai do centro.
- teste: Widget test do transporte: contar exatamente 7 alvos e provar que o play e o de indice 3; tocar no alvo 5 e esperar o menu com 'Duplicar camada' e 'Salvar como preset'; um golden ou um teste de chave provando que a arte do vazio referencia ValueKey('transporte-operacoes').

### `!!` O vazio oferece uma acao REAL: salvar as propriedades e os keyframes da camada como preset (P: implementar estados reais, nunca atalhos sem acao).

- evidencia: V 01:21.0 (texto do modal: salvar propriedades das camadas e keyframes como Presets no editor) + P da pagina 20
- hoje: O motor existe e esta DESLIGADO. lib/src/features/editor/application/editor_controller.dart:941 saveEffectPresetFrom(layerId, name, {onlyEffectIds}) e :966 applyPreset(layerId, preset, {at, replace, stretchTo}) nao tem NENHUM chamador em lib/ — grep em lib e test devolve so as proprias definicoes e os testes de unidade. A loja lib/src/features/editor/application/effect_preset_store.dart:20 (add :80, remove :86, rename :94) tambem nao e importada por nenhum widget: o unico import de effect_preset.dart fora do dominio e editor_controller.dart:27.
- divergencia: Alem de nao haver botao, o escopo e menor que o do AM: o preset do Aurea guarda a PILHA DE EFEITOS (effect_preset.dart:19-30, campo effects: List<EffectInstance>), nao as propriedades da camada nem os keyframes de transformacao/opacidade, que e o que o modal do AM promete.
- mudanca: Ligar a acao: 'Salvar como preset' abre o campo de nome, chama saveEffectPresetFrom e EffectPresetStore.instance.add. Depois estender EffectPreset para tambem carregar keyframes de LayerProp (posicao, escala, rotacao, opacidade) com o mesmo contrato ja escrito em effect_preset.dart:9-18 — keyframes relativos ao inicio e distancias normalizadas pelo tamanho da camada.
- risco: Estender o EffectPreset muda o JSON de effect_presets.json (effectPresetToJson em effect_preset_store.dart:110); um arquivo gravado pela versao nova lido pela antiga perde as propriedades caladamente. E applyPreset devolve compat.warnings (editor_controller.dart:975,991) que hoje ninguem le — ligar a UI sem mostrar os avisos aplica preset incompativel em silencio.
- teste: Teste de integracao: camada com dois efeitos e keyframes, salvar como preset, verificar EffectPresetStore.instance.presets.length == 1; abrir OUTRO projeto, aplicar o preset aos 12 s numa camada de tamanho diferente e comparar os valores desnormalizados; e um teste que prova que compat.warnings virou texto na tela quando o preset nao cabe.

### `!!` O vazio tambem oferece o segundo caminho: importar presets criados por outros.

- evidencia: V 01:21.0 ("Ou importe Presets criados por outros!")
- hoje: NAO EXISTE para presets de camada. EffectPresetStore (effect_preset_store.dart:20-108) so tem add/remove/rename e um arquivo interno effect_presets.json; nao ha importar nem exportar. O que existe e outra coisa e mora noutra tela: importarCenaXml (lib/src/features/projects/domain/cena_xml_import.dart:63) chamado por _importarCena em lib/src/features/projects/presentation/projects_tab.dart:229-283, que cria um PROJETO novo inteiro a partir de um XML de outro editor, com dialogo de balanco em :254.
- divergencia: O caminho de importacao existe, mas produz projeto e nao preset, e vive na aba de projetos em vez do vazio de presets. Do vazio de presets nao se importa nada.
- mudanca: Adicionar import/export ao EffectPresetStore usando effectPresetToJson/effectPresetFromJson (:110 e :121) e um segundo botao (ou linha secundaria) no vazio que abra o seletor de arquivo. Reaproveitar o padrao de balanco de importarCenaXml: dizer quantos efeitos entraram e o que ficou de fora.
- risco: JSON de origem desconhecida vira EffectInstance por effectFromJson: efeito de tipo que esta versao nao conhece, parametro fora de faixa, ou lista gigantesca. Pela regra de tolerancia ja adotada no projeto, item ilegivel tem de ser PULADO e reportado, nunca derrubar a leitura — e effectPresetFromJson hoje ja pula o que nao for Map, mas nao valida o tipo do efeito.
- teste: Importar um JSON com um efeito valido e um efeito de tipo inexistente: esperar 1 efeito importado, 1 na lista de 'ficou de fora', e nenhuma excecao. Mais um round-trip: exportar um preset, apagar a loja, importar de volta e comparar campo a campo.

### `!!` Fechar o modal restaura exatamente o estado anterior do editor: nao apaga a selecao, nao reinicia o playhead e nao deixa residuo da operacao que estava em curso.

- evidencia: V 01:21.0 (fecha e o editor volta com Retangulo arredondado 1 selecionado e a grade no mesmo lugar) + P pagina 20 e invariantes da pagina 7
- hoje: O contrato de painel esta certo: EstadoDoPainel (painel_da_camada.dart:19-55) e mutuamente exclusivo, fecharFerramenta (:600-603) so recolhe, abrir uma categoria nao escreve no projeto (:756-768) e a selecao morta recolhe o painel em vez de segurar referencia (:405-413). Mas o estado das ferramentas de efeito VAZA: catalogoDeEfeitosProvider, efeitoAbertoProvider e parametroAbertoProvider (controles_da_camada.dart:306-308) nao sao zerados em fecharFerramenta, nem em abrirFerramentasDaCamada (:440-443), nem quando selectedLayerProvider muda — editor_screen.dart:150-161 apenas os ESCUTA para descartar a edicao pendente.
- divergencia: Abrir Efeitos, tocar em '+ Adicionar efeito' (controles_da_camada.dart:594-598 poe catalogoDeEfeitos = true), fechar a ferramenta pelo cabecalho, selecionar OUTRA camada e reabrir Efeitos cai direto no catalogo, e nao na pilha da camada nova. E o painel do objeto anterior reabrindo — proibido pelo invariante da pagina 7 — e o oposto de 'fechar restaura o estado anterior'.
- mudanca: Zerar catalogoDeEfeitosProvider, efeitoAbertoProvider e parametroAbertoProvider (e os equivalentes de mascara e cor, mascaraAbertaProvider/parametroDaMascaraProvider/itemDaCorProvider/parametroDaCorProvider, ja listados em editor_screen.dart:156-159) em fecharFerramenta e num listener de selectedLayerProvider; o modal de presets nasce fechando por um unico caminho que faz o mesmo.
- risco: Zerar parametroAbertoProvider na troca de camada apaga a escolha de parametro que o usuario acabou de fazer se a troca vier de um comando que reordena a pilha (desfazer, agrupar); e o descarte de pendencia ja pendurado nesses providers pode passar a rodar duas vezes. Zerar so quando o ID da camada MUDA de verdade, nao a cada rebuild.
- teste: Widget test: camada A, abrir Efeitos, abrir o catalogo, fechar a ferramenta, selecionar camada B, abrir Efeitos e esperar o vazio 'Esta camada ainda nao tem efeito nenhum.' em vez do catalogo. E, para o modal: abrir Presets, guardar playback.time e selectedLayerProvider, fechar pelo X e comparar os dois.

### `!!` Existir UM componente de modal contextual do editor — foco, fechamento e restauracao — em vez de popups avulsos (a pagina 20 manda copiar exatamente esse padrao de UI).

- evidencia: V 01:21.0, V 00:18.0 e V 01:36.0 (a mesma casca de modal serve aos tres avisos, mudando so o conteudo) + P da pagina 20
- hoje: NAO EXISTE no editor. O unico dialogo dentro do editor e o teclado numerico: campo_de_valor.dart:229-248 (_abrirDialogo) com _DialogoDeValor em :288, um CupertinoAlertDialog. As folhas do estudio 3D usam outro idioma, showModalBottomSheet limitado a 70% da tela (folhas_do_estudio.dart:47-89). Fora do editor ha mais dois idiomas: AlertDialog Material em release_notice.dart:43-58 e CupertinoAlertDialog em aviso_ao_vivo.dart:53-85 e projects_tab.dart:254 e :303. Nenhum deles tem X no alto centralizado.
- divergencia: Quatro idiomas de sobreposicao no app e zero modal contextual no editor: o padrao que a pagina 20 manda copiar nao tem onde ser aplicado. Alem disso nenhum dos existentes tem contrato escrito de restauracao do estado ao fechar.
- mudanca: Criar o componente unico (X centralizado no alto, canto arredondado, corpo livre, ate dois botoes), com o fechamento passando por um unico caminho que nao toca em selectedLayerProvider, playback nem no historico; montar dentro do Stack do editor para nao competir com o PopScope de editor_screen.dart:168. Migrar os quatro usos existentes por cima.
- risco: Montar no Stack e nao como rota significa que o botao de voltar do Android nao fecha o modal por si — precisa de PopScope proprio, senao o gesto fecha o editor com o modal aberto. E as folhas do estudio 3D dependem do comportamento de bottom sheet (70% da altura, cena visivel atras, folhas_do_estudio.dart:41-46): nao migrar essas.
- teste: Teste do componente: abrir sobre o editor com uma camada selecionada e o playhead em 3 s; provar que o gesto de voltar do sistema fecha o MODAL e nao a tela; e que depois de fechar, selectedLayerProvider, playback.time, estadoDoPainelProvider e controller.canUndo estao identicos ao de antes de abrir.

### `! ` Distinguir fechar o aviso de realizar a acao principal: o X so fecha, o botao principal age, e um nunca faz o trabalho do outro.

- evidencia: V 01:21.0 e V 00:18.0 (X no alto separado do botao verde de baixo) + P da pagina 20
- hoje: Onde existe dialogo, o Aurea ja separa: projects_tab.dart:254-277 (Cancelar / Abrir), :300-317 (_aviso com OK unico), aviso_ao_vivo.dart:53-85 (Abrir / Agora nao), campo_de_valor.dart:288 com _confirmar em :285 devolvendo null quando o texto e ilegivel. release_notice.dart:43 e um AlertDialog so de leitura. No EDITOR, porem, nao ha nenhum modal com essa forma alem do teclado numerico, e os vazios (_Aviso, _AindaNao em controles_da_camada.dart:1498-1525) nao tem nem X nem botao.
- divergencia: O padrao esta certo onde existe, mas o editor nao tem o componente — cada tela reinventa o dialogo em um de tres idiomas (AlertDialog Material, CupertinoAlertDialog, showModalBottomSheet), sem X no alto e sem contrato comum de fechar-versus-agir.
- mudanca: Extrair um unico componente (por exemplo core/ui/modal_do_aurea.dart) com X no alto, corpo e no maximo dois botoes, e converter release_notice, aviso_ao_vivo e os dialogos de projects_tab para ele. O vazio de presets nasce ja usando o componente.
- risco: Trocar CupertinoAlertDialog por um componente proprio muda a aparencia de dialogos que os testadores ja conhecem, e a direcao de design do projeto e Apple/iOS — o componente tem de manter Cupertino por baixo, nao virar Material. E os testes existentes que procuram por texto de acao ('Abrir', 'Agora nao', 'OK') quebram se o rotulo mudar.
- teste: Teste do componente: com dois botoes, tocar no X e provar que o callback principal NAO foi chamado e que o dialogo saiu; tocar no principal e provar que foi chamado uma unica vez. Mais um teste de varredura que falha se showDialog/showCupertinoDialog for chamado direto fora do componente.

### `! ` Aviso de recurso com escopo claro: quando algo nao esta disponivel, o aviso diz exatamente sobre O QUE ele fala e por que, no lugar onde a pessoa tocou.

- evidencia: V 00:18.0 (o aviso nomeia a feature: 'Feature: Camera Layers') — a forma se copia, o motivo comercial nao
- hoje: O Aurea resolve isso sem modal e com escopo no proprio cartao: CategoriaDaCamada tem disponivel/porQueNao (painel_da_camada.dart:88-105), o cartao pinta apagado e escreve o motivo embaixo do rotulo (:803-812), e a regra escrita em :102-104 diz que recurso inexistente fica FORA da lista, nao entra desabilitado. Ha um unico uso hoje: id 'borda' / 'Borda e sombra' com disponivel: false e porQueNao 'Chega numa proxima entrega' (:231-235).
- divergencia: O escopo esta claro, mas o padrao e mais fraco em dois pontos: o motivo e truncado em uma linha (maxLines: 1, :809) e o cartao apagado nao responde ao toque (:761), entao quem toca nao recebe resposta nenhuma — o AM sempre responde, mesmo que seja para dizer que nao da.
- mudanca: Manter o motivo no cartao (e melhor que o modal para o caso comum) e acrescentar resposta ao toque no cartao indisponivel: um AureaSnack (lib/src/core/ui/snack.dart) com o motivo inteiro, ou o modal contextual quando o motivo nao couber em uma linha.
- risco: Dar toque a um cartao apagado confunde com cartao disponivel se o feedback visual nao mudar; e AureaSnack precisa de ScaffoldMessenger na arvore (snack.dart:29 devolve calado se nao houver), o que dentro de um painel sobreposto nem sempre e verdade.
- teste: Widget test: tocar no cartao 'Borda e sombra' e esperar o texto completo de porQueNao na tela; e provar que a categoria NAO abriu (estadoDoPainelProvider continua em EstadoDoPainel.categorias).

### `! ` Nunca telas vazias falsas nem atalhos sem acao: todo estado mostrado tem de ser um estado real do Aurea.

- evidencia: P da pagina 20 ("Implementar estados reais; nunca telas vazias falsas nem atalhos sem acao")
- hoje: Duas violacoes vivas. (1) painel_da_camada.dart:231-235: o cartao 'Borda e sombra' entra na grade com disponivel: false — um atalho que nunca abre, contra a regra escrita tres linhas acima dele em :102-104. (2) controles_da_camada.dart:120 cai em _AindaNao (:1513-1525), 'Os controles desta categoria chegam numa proxima entrega' — uma tela vazia declarada, alcancavel por qualquer categoria sem caso no switch.
- divergencia: O AM abre 'Borda e sombra' de verdade (o tile aparece aceso na grade do quadro 01:21). No Aurea ele e um cartao morto, e o switch tem um caso-lixo que promete entrega futura em vez de estado real.
- mudanca: Ou implementar 'Borda e sombra' de verdade, ou tira-lo da lista conforme a propria regra do arquivo. Trocar _AindaNao por um erro de compilacao: tornar o switch de _conteudo exaustivo sobre um enum de categoria, como ja foi feito para o nome do tipo de camada em painel_da_camada.dart (switch exaustivo, sem caso generico).
- risco: Tirar 'Borda e sombra' da grade some com um item que o AM tem — a paridade da pagina 20 pede vazios uteis, nao remocao de tiles. Preferir implementar. E tornar o switch exaustivo obriga a dar caso a toda categoria nova, o que e o objetivo mas quebra o build de quem adicionar id novo sem painel.
- teste: Teste que percorre categoriasDaCamada(l) para todo tipo de camada, abre cada cartao e falha se aparecer ValueKey('categoria-sem-controles') ou se algum cartao vier com disponivel == false.

### `ok` Nao importar a monetizacao do AM: nenhum botao de assinatura, nenhum 'assista a um anuncio para desbloquear', e nenhuma funcao ja disponivel no Aurea bloqueada so para parecer com o AM.

- evidencia: V 00:18.0 e V 01:36.0 (avisos Feature: Camera Layers e Feature: Advanced Easing Curves, com 'Opcoes de assinatura', 'Assista a um anuncio' e 'Experimente primeiro') — registrados como estado do AM, explicitamente NAO como requisito
- hoje: Nao ha paywall em lugar nenhum: a varredura por assinatura/premium/paywall/anuncio em lib/ so devolve 'assinatura' no sentido de hash de malha 3D (fonte_de_malha.dart:20,34,128; scene3d_gpu.dart:186) e de fonte sfnt (font_service.dart:121,185) — nenhuma monetizacao. E o recurso que o AM cobra em 01:36 esta ABERTO no Aurea: o editor de curva com rail de presets Bezier, Saltar, Ciclico e Elastico vive em lib/src/features/editor/presentation/widgets/editor_de_curva.dart:38-39 e :289-307, livre.
- divergencia: NENHUMA

### Extensoes do Aurea nesta superficie

O PDF manda preservar e dar destino contextual — nunca apagar.

- Presets guardados FORA do projeto: EffectPresetStore (lib/src/features/editor/application/effect_preset_store.dart:10-40) grava em effect_presets.json na pasta do app, entao um preset salvo editando um projeto aparece em todos os outros e sobrevive a apagar o projeto. O AM nao promete isso no vazio de 01:21. Destino: a superficie de Presets tem de mostrar essa lista global (categoria 'Meus'), e o texto do vazio deve dizer que o preset vale para todos os projetos — e uma vantagem que so existe se for dita.
- Normalizacao e reconciliacao do preset: keyframes gravados relativos ao inicio e ponto/distancia/raio normalizados pelo tamanho da camada (effect_preset.dart:9-18), com stretchTo para esticar (editor_controller.dart:966-991) e reconcilePreset devolvendo compat.warnings. O AM nao mostra nada disso. Destino: os warnings, hoje descartados por falta de chamador, precisam virar uma linha visivel ao aplicar um preset que nao cabe — nunca aplicar em silencio.
- Campos builtIn, category, tags e author no EffectPreset (effect_preset.dart:35-43): o Aurea pode nascer com presets de fabrica, o que faria o vazio de 01:21 nunca aparecer. Destino: decidir explicitamente — ou nao ha presets de fabrica e o vazio e o primeiro estado, ou ha e o vazio so aparece na categoria 'Meus'. As duas sao defensaveis; o que nao pode e a tela ficar vazia mentindo que nao existe nada.
- Quatro outras familias de preset JA ligadas a UI, espalhadas por painel: presets de animacao de texto (lib/src/features/editor/domain/text_presets.dart + painel_de_animacao_de_texto.dart:97-105), sete presets de revelacao de mascara (painel_de_mascaras.dart:137-146), presets de rampa de velocidade (painel_de_velocidade.dart:142) e 12 materiais 3D prontos (ficha_do_selecionado.dart:608-621). O AM tem UMA superficie 'Presets'. Destino: decidir se o tile Presets absorve todas ou se as quatro continuam contextuais no painel de cada assunto — sem apagar nenhuma; a leitura mais fiel a pagina 7 e mante-las contextuais e o tile Presets ser o da camada inteira.
- Rail de presets de curva livre: 'Bezier ajustada a mao' mais o rail de miniaturas (editor_de_curva.dart:38-39, 218-239, 289-307). Exatamente o recurso que o AM cobra em V 01:36 com assinatura ou anuncio. Destino: preservar aberto e proteger com teste — nunca ganhar aviso de bloqueio por parecer com o AM.
- AureaSnack (lib/src/core/ui/snack.dart): aviso rapido com fechamento garantido por Timer proprio, um por vez, com acao opcional. O AM nao tem equivalente. Destino: e o lugar certo do resultado reversivel ('Preset salvo · Desfazer', 'Preset aplicado · Desfazer'), que nao merece modal.
- Aviso ao vivo publicado do servidor (lib/src/features/projects/presentation/aviso_ao_vivo.dart:49-86): faixa na Inicio mais uma janela por recado, com Abrir/Agora nao e X que esconde so aquele id. Nao existe no AM. Destino: escopo proprio e separado do aviso de recurso — se os dois passarem a usar o mesmo componente de modal, o de recado do servidor nunca pode aparecer sobre o editor durante uma operacao.
- Importacao tolerante com balanco: importarCenaXml (cena_xml_import.dart:63-108) le o que reconhece, junta em ignored o que nao reconheceu, e o dialogo de projects_tab.dart:254-277 mostra 'X camadas e Y keyframes reconhecidos' mais 'ficou de fora'. E melhor que a promessa nao filmada do AM de importar presets de outros. Destino: reutilizar o mesmo relatorio no import de preset, em vez de inventar outro.
- Cartao indisponivel com motivo escrito no lugar (painel_da_camada.dart:88-105 e 803-812): resposta local e sem modal para 'isso nao da agora', enquanto o AM sempre gasta um modal de tela cheia. Destino: preservar como padrao padrao do Aurea; o modal fica so para o que precisa de foco (o vazio de presets, uma confirmacao destrutiva).
- Vazio ilustrado da comunidade (community_tab.dart:1380-1412): icone, titulo e orientacao ja na tipografia do app. Destino: e a base tipografica do vazio de presets — nao criar uma terceira escala; e o proprio vazio da comunidade ganha o botao de acao que hoje lhe falta ('Publicar'), pela mesma regra da pagina 20.

### Correcoes do conferente (3)

- **Existir UM componente de modal contextual do editor — foco, fechamento e restauracao — em vez de popups avulsos (a pagina 20 manda copiar exatamente esse padrao de UI).**
  - afirmado: NAO EXISTE no editor. O unico dialogo dentro do editor e o teclado numerico (campo_de_valor.dart:229-248). ... Quatro idiomas de sobreposicao no app e zero modal contextual no editor: o padrao que a pagina 20 manda copiar nao tem onde ser aplicado. Alem disso nenhum dos existentes tem contrato escrito de restauracao do estado ao fechar.
  - verdade: O modal contextual do editor EXISTE e e exatamente esse padrao: PainelCentralDeAdicao em lib/src/features/editor/presentation/widgets/adicionar_conteudo.dart:355-477, montado pela propria tela do editor em lib/src/features/editor/presentation/editor_screen.dart:369-374. Ele tem (a) FOCO: Positioned.fill com BackdropFilter blur 14 + preto 45% por cima do editor inteiro (:384-404); (b) cartao centralizado 340x420 com cantos arredondados 18 e fio de borda (:405-418); (c) cabecalho com titulo, voltar-quando-ha-para-onde e X de fechar (_Cabecalho :481-549, X em :532-546 — canto direito, e nao centralizado no alto como no AM); (d) DOIS fechamentos, tocar fora (:395-397) e o X, os dois chamando a MESMA funcao; (e) CONTRATO ESCRITO de restauracao: fecharAdicao(ref) em :277-280 zera so o estado que o modal criou (categoriaDeAdicaoProvider e subItemDeAdicaoProvider), sem tocar em selecao nem no cabecote, e o comentario em :364-366 declara o contrato ('Quem fecha o fluxo e a tela — este painel nao sabe o que mais precisa ser recolhido'). A auditoria so olhou showDialog/showModalBottomSheet e por isso nao viu o modal do editor, que e construido na arvore. A divergencia real e outra e menor: o componente existe e serve so para 'adicionar conteudo' — nao e reusado por presets nem por avisos, e o X esta no canto e nao centralizado no alto.
- **A ilustracao/orientacao do vazio aponta o caminho real de criar um preset — no AM ela destaca o menu de operacoes de camada na barra de transporte.**
  - afirmado: Nao ha menu de operacoes de camada, e nao ha nenhum ponto na interface que chame saveEffectPresetFrom. ... No AM aquele slot e um MENU de operacoes da camada; no Aurea e uma acao unica e irreversivel de duplicar.
  - verdade: Duas afirmacoes falsas dentro do item. (1) O MENU DE OPERACOES DA CAMADA EXISTE: a categoria 'camada' / rotulo 'Camada' em lib/src/features/editor/presentation/widgets/painel_da_camada.dart:207-212 (titulo em :561) abre _AcoesDaCamada (roteado em lib/src/features/editor/presentation/widgets/controles_da_camada.dart:116, classe em :1139-1262), com solo, travar, ligar/desligar 3D, espessura, 'Dividir no cabecote', 'Duplicar', 'Seguir outra camada'/'Agrupar'/'Entrar no grupo' e 'Apagar' — o proprio comentario em painel_da_camada.dart:205-207 diz que e 'o que se faz com a camada inteira'. Ha ainda o painel de acoes da SELECAO (painel_da_selecao.dart, aberto por abrirAcoesDaSelecao em painel_da_camada.dart:448-451). O que diverge do AM e o LUGAR (grade de categorias, nao a barra de transporte), nao a existencia. (2) Duplicar NAO e irreversivel: duplicarCamada (editor_controller.dart:5122-5137) passa por _mutate, que empilha desfazer SEMPRE que a estrutura muda (:318-326, com o comentario 'duplicar e apagar — sao acoes distintas e deliberadas'), e o botao Desfazer e o PRIMEIRO alvo da mesma barra de transporte (linha_do_tempo.dart:374-379).
- **Sem nenhum preset salvo, a superficie de Presets abre um modal contextual com titulo, imagem explicativa, orientacao e botao de confirmacao.**
  - afirmado: Os vazios do editor sao uma linha de texto cinza de 11 px, sem titulo, sem imagem e sem acao (controles_da_camada.dart:577, _Aviso :1498-1511, painel_da_camada.dart:710-722). O unico vazio ilustrado do app inteiro e _Vazio em community_tab.dart:1380-1412 — e ele nao tem botao de acao nem modal, e vive fora do editor.
  - verdade: A generalizacao sobre os vazios do editor e falsa. Dentro do editor existe um vazio COM TITULO E COM ACAO REAL, e dentro de uma folha modal: _NadaSelecionado em lib/src/features/editor/presentation/estudio/ficha_do_selecionado.dart:426-470, usado em :317-321 sob o comentario 'NADA SELECIONADO: o pedido diz o que mostrar aqui — os caminhos de criar, e nao uma ficha vazia'. Ele tem TituloDaFolha('Nada selecionado') (11 px / w700, folhas_do_estudio.dart:935-952), orientacao de 11,5 px ('Toque num objeto da vista para escolher, ou crie um.') e DUAS acoes de verdade — AcaoDaFolha 'Adicionar' (abre a folha de adicionar) e 'Mundo e ambiente' — e e servido pela folha modal mostrarFolha (folhas_do_estudio.dart:47-89) via abrirFichaDoSelecionado (:278). Ha ainda folhas_do_estudio.dart:542 ('A cena esta vazia. Toque no + para criar.'), que aponta o caminho. Falta ilustracao e botao de confirmacao, e nada disso e de presets — a divergencia da superficie de presets continua de pe — mas o padrao 'vazio com titulo + orientacao + acao real' que a auditoria declarou inexistente no editor ja esta implementado ali.

---

## Aparencia: Borda e sombra, subpainel Traco (PDF pagina 14)

A superficie nao existe no Aurea. O cartao "Borda e sombra" (painel_da_camada.dart:229-235) esta declarado com disponivel:false e onTap:null — e um tile inerte, e o despacho de categorias (controles_da_camada.dart:105-121) manda 'borda' para o texto "chega numa proxima entrega". Nao ha subpainel "Traco", nao ha switch, nao ha fileira de seis opcoes, nao ha Iniciar/Fim e nao ha coluna de tres submodos. O que existe hoje e uma SECAO chamada "Contorno" dentro da familia errada, "Cor e preenchimento" (painel_de_cor.dart:318-364), com quatro controles: cor, espessura, opacidade e remover. Duas divergencias sao estruturais alem da ausencia: (1) o AM liga/desliga o traco por switch enquanto o Aurea APAGA o item (removeShapeStroke) e o recria em branco/10 (ensureShapeStroke), perdendo cor, espessura, opacidade e keyframes — quebra direta do aceite "abrir, ajustar, voltar, reabrir e desfazer sem perder valores"; (2) o motor sustenta mais do que a interface abre — cap, join, miterLimit e todo o tracejado sao pintados (shape.dart:1733-1745) e nao tem comando nem porta, e o TrimOperator (inicio/fim/deslocamento) tem comando (ensureShapeTrim) com ZERO chamadores na presentation. A metade "sombra" do nome da familia nao tem modelo nenhum: nao ha sombra de camada em layer.dart; o parente mais proximo e o efeito Glow, que vive em Efeitos. As pecas de moldura ja existem e nao precisam ser inventadas: RailEsquerdo (voltar/keyframe/curva), RailDireito (submodos, hoje so na transformacao), FitaDeAjuste + CampoDeValor (a regua com leitura) e o arranjo do editor_screen que ja mantem previa e linha do tempo visiveis com a ferramenta aberta. Atencao: test/painel_da_camada_test.dart:323-333 afirma hoje que 'borda' e uma categoria INDISPONIVEL — implementar a superficie quebra esse teste de proposito.

### `!!` O tile "Borda e sombra" da grade da camada abre uma familia de edicao de verdade (estado "Familia de edicao" da pagina 7).

- evidencia: V 00:48.0 (familia aberta com o subpainel Traco dentro) + D pagina 7, linha "Familia de edicao / Tocar em um tile, como Borda e sombra"
- hoje: lib/src/features/editor/presentation/widgets/painel_da_camada.dart:229-235 declara a categoria id 'borda', rotulo 'Borda e sombra', com disponivel:false e porQueNao:'Chega numa proxima entrega'; lib/src/features/editor/presentation/widgets/painel_da_camada.dart:762-769 faz onTap:null quando disponivel e falso, e pinta o cartao a 40% de alpha.
- divergencia: O tile existe mas e INERTE: nao ha estado de familia atras dele. O toque nao muda categoriaAbertaProvider nem estadoDoPainelProvider — nao ha painel nenhum para abrir.
- mudanca: Tirar disponivel:false/porQueNao do cartao 'borda' e registrar o conteudo da familia no despacho de lib/src/features/editor/presentation/widgets/controles_da_camada.dart:105-121 (hoje 'borda' cai no ramo _ => const _AindaNao(), controles_da_camada.dart:120 e 1513-1521). O cartao hoje entra para TODO tipo de camada (nao ha guarda de tipo em painel_da_camada.dart:229) enquanto o contorno so existe em ShapeLayer — decidir: ou guardar por tipo, ou a familia precisa ter conteudo para os outros tipos.
- risco: Acender um cartao que abre um painel vazio para imagem, video, texto, audio, nulo e grupo — exatamente o que a regra escrita em painel_da_camada.dart:124-128 proibe. E test/painel_da_camada_test.dart:323-333 afirma HOJE que 'borda' esta na lista de indisponiveis: a mudanca quebra esse teste de proposito e ele precisa ser reescrito junto.
- teste: Teste de widget: selecionar uma ShapeLayer, abrir as ferramentas, tocar no cartao 'Borda e sombra' e esperar que estadoDoPainelProvider vire EstadoDoPainel.categoria e categoriaAbertaProvider vire 'borda'; e que o texto 'Os controles desta categoria chegam numa proxima entrega.' NAO apareca.

### `!!` Dentro da familia, o painel aberto se chama "Traco" e tem linha de titulo propria.

- evidencia: V 00:48.0 (linha de titulo: amostra de cor + a palavra "Traco" + switch)
- hoje: NAO EXISTE como painel. O contorno mora como uma SECAO dentro de outra familia: lib/src/features/editor/presentation/widgets/painel_de_cor.dart:319 imprime const _Titulo('Contorno') dentro do cartao 'cor' ('Cor e preenchimento', painel_da_camada.dart:222-227).
- divergencia: O traco esta na familia errada (Cor e preenchimento) e com o rotulo errado ('Contorno'), como secao e nao como subpainel com entrada propria. Nao ha subpainel 'Traco' em lugar nenhum do codigo.
- mudanca: Criar um painel proprio (por exemplo painel_de_borda.dart) com o titulo 'Traco', ligado ao id 'borda' no despacho de controles_da_camada.dart:105-121, e mover para ele os controles de contorno hoje em painel_de_cor.dart:318-364 — a pagina 14 manda refazer o painel, nao renomear.
- risco: Mover o contorno para fora de 'Cor e preenchimento' deixa quem ja aprendeu o caminho antigo sem ele; e a secao 'Pintura' (painel_de_cor.dart:225-313) e o contorno compartilham hoje o mesmo parametroDaCorProvider/itemDaCorProvider (painel_de_cor.dart:203-206, 32-34), entao separar os paineis sem separar esse estado faz o rail esquerdo de um mirar o parametro do outro.
- teste: Teste de widget: abrir 'borda' e esperar find.text('Traco'); abrir 'cor' e esperar que 'Contorno'/'Espessura' NAO aparecam mais la.

### `!!` A linha de titulo do Traco tem um switch a direita.

- evidencia: V 00:48.0 (switch tipo iOS, visivelmente desligado). Alterar o switch NAO foi demonstrado — o efeito exato dele e N.
- hoje: NAO EXISTE switch. O que ha e um par de acoes destrutivas: painel_de_cor.dart:320-325 mostra _Acao('Adicionar contorno') chamando c.ensureShapeStroke(l.id) (editor_controller.dart:7219-7233) quando nao ha traco, e painel_de_cor.dart:353-362 mostra _Acao('Remover o contorno', perigo:true) chamando c.removeShapeStroke(l.id) (editor_controller.dart:7244-7251). Nao ha nenhum Switch/CupertinoSwitch em lib/src/features/editor/presentation (varredura sem resultado).
- divergencia: Desligar no Aurea significa APAGAR o item: removeShapeStroke filtra fora todo ShapeStroke, e ensureShapeStroke recria um novo com width 10 e branco (editor_controller.dart:7229). Cor, espessura, opacidade e os keyframes das trilhas se perdem no ciclo desligar/ligar — o oposto do aceite da pagina 14 ("abrir, ajustar, voltar, reabrir e desfazer sem perder valores").
- mudanca: Dar ao ShapeStroke um campo de ligado/desligado (lib/src/features/editor/domain/shape.dart:783-846, com copyWith e serializacao em lib/src/features/editor/domain/project_store.dart:452-461 e 603-613) que o pintor respeita em shape.dart:1733-1745, e ligar o switch a ele. Manter Adicionar/Remover como acao explicita, nao como o switch.
- risco: Campo novo no modelo: projeto antigo sem a chave precisa ler como ligado (regra de leitura tolerante do QA 1.0), senao todo contorno existente some ao reabrir o projeto. E o pintor precisa pular o traco desligado sem mudar a ordem da lista plana de itens, que e avaliada de cima para baixo.
- teste: Teste de unidade: gravar cor/espessura/opacidade num traco, desligar o switch, voltar, reabrir, religar e conferir que os tres valores e os keyframes sao os mesmos; e teste de round-trip do project_store lendo um projeto sem a chave nova e obtendo o traco ligado.

### `!!` Abaixo da regua ha uma fileira de SEIS opcoes graficas, com uma selecionada e o estado visivel.

- evidencia: V 00:48.0 (seis botoes lado a lado; o 2o marcado e o 6o em destaque verde). O significado de cada silhueta e N — a pagina 14 proibe deduzi-lo.
- hoje: NAO EXISTE. O modelo tem candidatos naturais e nenhum editor: ShapeStroke.cap e ShapeStroke.join (lib/src/features/editor/domain/shape.dart:788-789, 806-807) nascem StrokeCap.round/StrokeJoin.round e nunca sao alterados por comando nenhum — EditorController.shapeItemTrack (editor_controller.dart:7114-7121) so expoe width, opacity, dashLength, gapLength e dashOffset; cap, join e miterLimit ficam de fora tambem de _shapeItemWithTrack (7136-7143). O pintor le os dois em shape.dart:1745 e arredores.
- divergencia: Nao ha nenhuma fileira de opcoes graficas no painel de contorno, e nao ha comando que escreva cap/join. O usuario nao tem como mudar ponta nem junta.
- mudanca: Criar a fileira de seis botoes no painel Traco e o comando que escreve nela. Enquanto nao houver referencia AM que diga o que as seis silhuetas sao, ligar a fileira ao que o render do Aurea sustenta de fato (cap/join sao os candidatos existentes) e declarar isso como escolha do Aurea — nao como paridade.
- risco: Adivinhar a semantica e criar seis botoes que nao correspondem ao AM e ficam impossiveis de corrigir depois sem quebrar projetos gravados; e cap/join hoje nao sao serializados (project_store.dart:452-461 grava so cor, largura, opacidade e dash), entao expo-los sem gravar faz o valor sumir ao reabrir.
- teste: Teste de widget contando exatamente seis botoes na fileira, com um e so um marcado como selected nos Semantics; e teste de round-trip do project_store provando que a opcao escolhida sobrevive a salvar e reabrir.

### `!!` Uma coluna a direita traz TRES seletores de submodo da familia; so o primeiro (o Traco) estava aberto no trecho.

- evidencia: V 00:48.0 (tres alvos empilhados na borda direita: circulo verde aceso, quadrado arredondado, quadrado em camadas). Os outros dois submodos sao N.
- hoje: NAO EXISTE para esta familia. A peca reusavel existe: RailDireito (lib/src/features/editor/presentation/widgets/rails_do_painel.dart:111-145, largura 40) — mas e usada em UM lugar so, lib/src/features/editor/presentation/widgets/painel_de_transformacao.dart:94. Toda categoria que nao seja 'transformar' e montada por _ComRail (controles_da_camada.dart:171-196), que tem so o rail ESQUERDO.
- divergencia: A familia 'Borda e sombra' nao tem coluna de submodos, logo nao tem os outros dois destinos. E a metade "sombra" do nome nao tem implementacao nenhuma: nao ha sombra de camada no modelo (varredura por shadow/sombra em lib/src/features/editor/domain/layer.dart nao retorna nada); o unico parente e o efeito Glow (lib/src/features/editor/domain/effect.dart:379-400), que vive na familia Efeitos.
- mudanca: Montar o painel da familia com RailDireito de tres posicoes, primeira = Traco. Os outros dois destinos precisam de referencia AM antes de receberem conteudo; ate la, definir explicitamente o que o Aurea poe ali (candidato: sombra de camada, que hoje nao existe no modelo).
- risco: Preencher os outros dois submodos por adivinhacao viola a regra da pagina 14 ("Submodos ainda nao referenciados nao podem receber status de igual ao AM"); e o RailDireito hoje presume que o vigente troca a superficie inteira do miolo, o que exige que cada submodo tenha painel proprio ou a coluna fica com posicao morta.
- teste: Teste de widget contando tres alvos no RailDireito da familia 'borda', com o indice 0 marcado como selected e o miolo mostrando 'Traco'; e um teste que falha se algum submodo sem referencia for anunciado como pronto.

### `!!` Cor, largura e limites do Traco tem de estar ligados ao render REAL, e nao a um painel decorativo.

- evidencia: D pagina 14 ("Ligar cor, largura, limites e opcoes efetivamente suportadas ao render real")
- hoje: Cor, largura e opacidade ja pintam: lib/src/features/editor/domain/shape.dart:1733-1745 le stroke.color, stroke.width.valueAt(t), cap, join, miterLimit e o tracejado (shape.dart:1453-1470) na hora de desenhar. Cor/largura/opacidade tem porta na interface (painel_de_cor.dart:331-352); cap, join, miterLimit, dashLength, gapLength e dashOffset NAO tem porta nenhuma (dashLength existe como chave de trilha em editor_controller.dart:7117 e ninguem a chama na presentation).
- divergencia: O render sustenta mais do que a interface oferece. Qualquer controle novo do painel Traco tem de cair nessas propriedades ja pintadas; e cap/join/miterLimit ainda faltam na serializacao (project_store.dart:452-461 grava cor, largura, opacidade e 'dash' apenas).
- mudanca: Ao montar o painel, ligar cada controle a uma propriedade que shape.dart:1733-1745 realmente le, e completar project_store.dart (gravacao e leitura) para as propriedades novas antes de expo-las.
- risco: Expor um controle cuja propriedade nao e serializada faz o ajuste sumir ao reabrir o projeto — e o valor volta silenciosamente ao padrao (round/round/4), sem erro nenhum.
- teste: Teste de render: montar uma ShapeLayer com traco, mudar cada controle novo e comparar a imagem pintada antes/depois (o dump visual do pintor de CPU); mais um teste de round-trip do project_store para cada propriedade nova.

### `! ` Com a familia aberta, o cabecalho da tela mostra o titulo da familia ("Borda e sombra") com o retorno a esquerda.

- evidencia: V 00:48.0 (barra superior lendo "Borda e sombra" com o chevron a esquerda) + D pagina 7 ("Titulo da familia e subpainel")
- hoje: O mecanismo existe: lib/src/features/editor/presentation/editor_screen.dart:421-426 troca a barra por _CabecalhoDaFerramenta(titulo: tituloDaFerramenta(aberta)). Mas lib/src/features/editor/presentation/widgets/painel_da_camada.dart:549-566 nao tem caso 'borda' — cai no ramo _ => 'Ferramentas' (linha 565).
- divergencia: Se a categoria for aberta hoje, o cabecalho diria "Ferramentas" em vez de "Borda e sombra". O titulo da familia nao existe.
- mudanca: Acrescentar 'borda' => 'Borda e sombra' ao switch tituloDaFerramenta em painel_da_camada.dart:549.
- risco: Nenhum funcional; o unico risco e o titulo da familia competir com o titulo do subpainel (Traco) se os dois forem escritos no mesmo lugar — a referencia poe familia em cima (barra da tela) e subpainel dentro do painel.
- teste: Teste de widget: com 'borda' aberta, esperar find.text('Borda e sombra') no _CabecalhoDaFerramenta e ausencia de find.text('Ferramentas').

### `! ` Abaixo da fileira ha dois botoes de texto sublinhados, "Iniciar" e "Fim".

- evidencia: V 00:48.0 (dois rotulos sublinhados, lado a lado, ocupando a largura do painel). O que cada um faz nao foi demonstrado: N.
- hoje: NAO EXISTE nenhum controle chamado Iniciar/Fim no painel de contorno (painel_de_cor.dart:318-364 tem so cor, Espessura, Opacidade e Remover). O modelo tem um par inicio/fim sem porta: TrimOperator com as trilhas 'start','end','offset' (editor_controller.dart:7107-7112) e o comando ensureShapeTrim (editor_controller.dart:7256-7272) — a varredura por ensureShapeTrim/TrimOperator em lib/src/features/editor/presentation nao retorna NENHUM chamador.
- divergencia: Faltam os dois botoes; e o subsistema que mais se parece com eles (Drawing Progress / Trim, inicio e fim) esta implementado no motor e invisivel na interface.
- mudanca: Colocar os dois botoes na posicao filmada. Ligar Iniciar/Fim ao que o Aurea de fato sustenta e so isso — se for o Trim, chamar ensureShapeTrim e editar as trilhas 'start'/'end' pelo mesmo caminho de editShapeItemTrack; nao inventar comportamento AM nao filmado.
- risco: ensureShapeTrim insere o operador ANTES da primeira pintura na lista plana (editor_controller.dart:7264-7270); inserir no lugar errado muda o desenho de formas que ja tem varios itens. E dois botoes com nome sem funcao ligada e uma promessa vazia, o mesmo defeito do cartao 'borda' de hoje.
- teste: Teste de widget: os dois botoes existem e sao tocaveis; tocar em Iniciar cria/abre exatamente um TrimOperator na camada (contents.whereType<TrimOperator>().length == 1) e um segundo toque nao cria outro.

### `! ` Os controles de retorno e de animacao ficam a esquerda do painel.

- evidencia: V 00:48.0 (coluna esquerda: chevron de voltar, losango de keyframe, e um terceiro alvo abaixo)
- hoje: Existe e ja e a moldura padrao: RailEsquerdo (rails_do_painel.dart:56-100, largura 46) com voltar, losango de keyframe e curva, aplicado a toda categoria por _ComRail (controles_da_camada.dart:187). O que decide o alvo e _alvoDaCategoria (controles_da_camada.dart:129-153), que trata 'opacidade','efeitos','forma','mascara','cor' e devolve const AlvoDoRail() para o resto (linha 152).
- divergencia: A coluna existe, mas para 'borda' o alvo cairia no ramo generico: losango e curva APAGADOS, apesar de espessura, opacidade e o tracejado do traco serem trilhas animaveis de verdade (editor_controller.dart:7114-7121) e de ja existir alvoDaCorDaForma pronto em painel_de_cor.dart:24-75, com keyframe e curva por trecho.
- mudanca: Acrescentar o ramo de 'borda' em _alvoDaCategoria (controles_da_camada.dart:129) apontando para a versao de alvoDaCorDaForma que mira o parametro escolhido do traco, com o par itemDaCorProvider/parametroDaCorProvider proprio do novo painel.
- risco: Se o novo painel reusar os mesmos providers do painel de cor (painel_de_cor.dart:32-34), abrir um e depois o outro faz o rail continuar mirando o parametro do painel anterior — a invariante da pagina 7 de nunca reabrir um painel do objeto anterior.
- teste: Teste de widget: no painel Traco, escolher a espessura, tocar no losango do RailEsquerdo e conferir que ShapeStroke.width ganhou keyframe no instante do cabecote; com dois keyframes e o cabecote entre eles, o botao de curva acende.

### `! ` Entrar e sair da familia conserva o preenchimento e a transformacao da camada; abrir, ajustar, voltar, reabrir e desfazer nao perdem valores.

- evidencia: D pagina 14 (obrigacao do agente e criterio de aceite) + D pagina 7 (invariantes: navegacao nao altera dados)
- hoje: A navegacao ja e limpa: painel_da_camada.dart:759-770 comenta e cumpre que abrir uma categoria nao escreve no projeto (so troca dois providers). A gravacao passa por beginGesture/endGesture (painel_de_cor.dart:216-219) e por _updateShape/_replace (editor_controller.dart:6573-6577).
- divergencia: Duas fugas concretas: (a) o par Adicionar/Remover contorno destroi valores (ver linha do switch); (b) painel_de_cor.dart:354-355 zera parametroDaCorProvider ao remover, mas nada zera itemDaCorProvider/parametroDaCorProvider ao TROCAR de categoria — o alvo do rail sobrevive a saida do painel.
- mudanca: Limpar itemDaCorProvider e parametroDaCorProvider (painel_de_cor.dart:32-34) no aoVoltar do painel, e garantir que a familia so escreva sob gesto explicito.
- risco: Limpar cedo demais apaga a escolha do parametro no meio de um arrasto e o losango pisca; limpar tarde demais deixa o rail mirando um item de outra camada, que e a invariante quebrada da pagina 7.
- teste: Teste de widget: ajustar a espessura, voltar para a grade, reabrir 'borda' e conferir o mesmo valor; desfazer uma vez e conferir que o arrasto inteiro voltou (uma edicao, nao N passos); e que abrir 'cor' logo depois nao vem com o parametro do traco escolhido.

### `~ ` A linha de titulo do Traco tem a amostra de cor a esquerda do nome.

- evidencia: V 00:48.0 (quadrado de amostra imediatamente a esquerda da palavra "Traco")
- hoje: Existe um seletor de cor, mas como linha separada: lib/src/features/editor/presentation/widgets/painel_de_cor.dart:331-339 usa EscolhaDeCor(rotulo:'Contorno', cor: traco.color) e escreve via c.updateShapeStroke(l.id,(s)=>s.copyWith(color: cor)).
- divergencia: A amostra e uma linha de formulario no meio da lista, nao a amostra da linha de titulo. Alem disso a cor escrita por updateShapeStroke (editor_controller.dart:7234-7242) vale para TODOS os tracos da camada, e o painel avisa isso em painel_de_cor.dart:326-330 — na referencia a amostra pertence ao traco do titulo.
- mudanca: Montar a linha de titulo do novo painel como [amostra de cor][Traco][switch], reusando EscolhaDeCor (lib/src/features/editor/presentation/widgets/escolha_de_cor.dart) so como o quadrado que abre o seletor.
- risco: Com mais de um ShapeStroke na camada, a amostra do titulo passa a sugerir um dono unico que o comando nao tem; manter o aviso de painel_de_cor.dart:326-330 ou trocar updateShapeStroke por uma versao por id.
- teste: Teste de widget: na linha de titulo, esperar que a amostra (por Semantics de EscolhaDeCor) e o texto 'Traco' estejam na MESMA Row; e que mudar a cor altere ShapeStroke.color da camada.

### `~ ` O valor do Traco e ajustado por regua de valor com leitura numerica ao lado (na captura, 4).

- evidencia: V 00:48.0 (regua de tracos verticais com marca central e caixa de leitura "4" a direita)
- hoje: A forma existe e e a mesma: lib/src/features/editor/presentation/widgets/linha_de_parametro.dart:24-100 monta chip + FitaDeAjuste (lib/src/features/editor/presentation/widgets/fita_de_ajuste.dart:23-75, regua relativa e infinita, linhas que rolam) + CampoDeValor. O contorno usa isso em painel_de_cor.dart:340-346 ('width','Espessura', porPixel:100/300) escrevendo por c.editShapeItemTrack (trilha 'width' em editor_controller.dart:7114-7117).
- divergencia: O controle e equivalente; o que difere e o enquadramento — no AM a regua ocupa a largura do painel sob a linha de titulo, sem chip de rotulo; no Aurea vem precedida do chip 'Espessura'. O valor 4 da captura e o estado daquele projeto, nao um requisito.
- mudanca: No painel novo, usar LinhaDeParametro para a espessura mas sem chip (ou com o chip so quando houver mais de um parametro escolhivel para o rail), para a regua ocupar a faixa como na referencia.
- risco: O chip e o que marca qual parametro o rail esquerdo esta mirando (linha_de_parametro.dart:61-67); tirar o chip sem outro indicador deixa o losango de keyframe sem dono visivel quando houver mais de uma trilha no painel.
- teste: Teste de widget: no painel Traco, achar a FitaDeAjuste pelo rotulo de acessibilidade, arrastar N pixels e conferir que ShapeStroke.width mudou porPixel*N; e que o CampoDeValor mostra o novo numero.

### `ok` A selecao temporal continua acima do painel: entrar na familia nao esconde a linha do tempo nem a previa.

- evidencia: V 00:48.0 (previa, transporte, regua com 00:00:04 e a faixa da camada permanecem acima do painel Traco)
- hoje: lib/src/features/editor/presentation/editor_screen.dart:241-278 calcula o teto da previa SEMPRE descontando PainelDaCamada.alturaMaxima, de modo que a previa nao muda de tamanho ao abrir a ferramenta; e reserva um chao para a linha do tempo de transporte (48) + regua (44) + uma trilha, com o painel sobreposto por cima do rodape (painel_da_camada.dart:415-431).
- divergencia: NENHUMA no que a pagina 14 exige: os dois blocos continuam visiveis com a ferramenta aberta.

### Extensoes do Aurea nesta superficie

O PDF manda preservar e dar destino contextual — nunca apagar.

- Opacidade PROPRIA do contorno, separada da opacidade da camada e da pintura (shape.dart:810-812), com regua, campo e keyframes (painel_de_cor.dart:347-352). Nao aparece no trecho filmado do AM. Destino: linha de parametro no painel Traco, abaixo da espessura.
- Tracejado animavel completo no modelo — dashLength, gapLength e dashOffset (shape.dart:813-820), com dashOffset feito para a "formiguinha" por keyframe linear, e ja serializado como 'dash' (project_store.dart:461). Hoje sem NENHUMA porta na interface. Destino: um dos submodos da coluna direita da familia, ou um grupo dentro do Traco.
- Drawing Progress / TrimOperator com inicio, fim e deslocamento animaveis (editor_controller.dart:7107-7112, 7256-7272), com easing por TRECHO. Comando existe, chamador nao existe. Destino candidato: os botoes Iniciar e Fim da referencia.
- Espessura e opacidade do contorno como TRILHAS animaveis com curva por trecho (setShapeItemTrackSegmentEase, usado em painel_de_cor.dart:60-75) — o AM nao demonstrou curva dentro do Traco. Destino: manter no rail esquerdo do painel Traco.
- cap, join e miterLimit no modelo e no pintor (shape.dart:788-789, 806-808, 1745) sem editor. Destino: candidatos naturais para a fileira de seis opcoes graficas, desde que declarados como escolha do Aurea e nao como paridade AM.
- Aviso honesto quando a camada tem mais de uma pintura ou mais de um contorno (painel_de_cor.dart:225-231 e 326-330), porque os comandos valem para todos. O AM nao mostra nada disso. Destino: preservar no painel Traco.
- Adicionar / Remover contorno explicitos (ensureShapeStroke, removeShapeStroke). Devem CONVIVER com o switch novo, nao ser substituidos por ele: sao acoes estruturais, e o switch e estado.
- Contorno vindo de importacao SVG, com cor e largura do arquivo (svg_document.dart:130-134), e das formas da biblioteca (shape_library.dart:71, 91, 108, 328). Destino: o painel Traco precisa editar esses tracos importados, nao so os criados a mao.
- Contorno criado pelo desenho a mao livre (freehand_overlay.dart:78). Destino: mesmo painel.
- O ramo de cor por TIPO de camada em painel_de_cor.dart (texto, particulas, elemento 3D e o aviso "Esta camada nao tem cor propria") — se o traco sair para a familia propria, esse ramo continua sendo o unico lugar que responde por tipos sem contorno. Destino: decidir o que a familia 'Borda e sombra' mostra para imagem, video, texto, audio, nulo e grupo, ou guardar o cartao por tipo.

### Correcoes do conferente (2)

- **Pagina 14 — a familia se chama "Borda e sombra"; P exige ligar ao render real o que a familia promete. Afirmacao 5 da matriz ("Uma coluna a direita traz TRES seletores de submodo").**
  - afirmado: "E a metade 'sombra' do nome nao tem implementacao nenhuma: nao ha sombra de camada no modelo (varredura por shadow/sombra em lib/src/features/editor/domain/layer.dart nao retorna nada); o unico parente e o efeito Glow (lib/src/features/editor/domain/effect.dart:379-400), que vive na familia Efeitos."
  - verdade: Existe sombra de camada no modelo, com comando, serializacao e render — a varredura foi feita no arquivo errado. A sombra nao mora em layer.dart e sim em lib/src/features/editor/domain/layer_meta.dart, no bloco LayerStyles (linhas 36-86), pendurado na camada por LayerMeta.styles (layer_meta.dart:889 e 910). LayerStyles carrega dropShadow e innerShadow (classe ShadowStyle, layer_meta.dart:90-136: enabled, color e os AnimatedDouble opacity/angleDeg/distance/size/spread, com offsetAt(t) resolvendo angulo+distancia), alem de outerGlow (GlowStyle, 138-162), colorOverlay, gradientOverlay e stroke (StrokeStyle, 223-248: enabled/color/width/opacity). Nao e modelo morto: (a) ha comando no controlador — EditorController.setLayerStyles e updateLayerStyles, lib/src/features/editor/application/editor_controller.dart:1091-1095, sob o comentario "------ aparencia"; (b) grava e le no projeto — project_store.dart:2444-2475 (_styles, chaves 'ds','is','og','co','go','st') e 2478-2500+ (_asStyles), com _shadow/_asShadow logo acima; (c) PINTA de verdade — palco_de_previa.dart:1265-1278 chama _applyLayerStyles depois dos efeitos, e a implementacao em 1409-1565 desenha contorno por dilate, brilho externo por blur e a sombra projetada em 1528-1560 (silhueta deslocada por offsetAt, tingida e borrada, com teto de 100 px no spread). Ha ainda um template real que usa isso: lib/src/features/projects/domain/notes_motion_template.dart:230-231 monta styles: LayerStyles(dropShadow: ShadowStyle(...)). Portanto a metade "sombra" tem modelo, comando, persistencia e render; o que falta e exclusivamente a PORTA na interface (nenhum arquivo de lib/src/features/editor/presentation constroi um painel de LayerStyles). A divergencia estrutural principal da afirmacao 5 — a familia 'borda' nao tem coluna de submodos, e RailDireito (rails_do_painel.dart:111-145) so e usado em painel_de_transformacao.dart:94, com _ComRail (controles_da_camada.dart:171-196) montando so o rail esquerdo — essa parte esta CERTA e foi confirmada.
- **Pagina 14 P — "Ligar cor, largura, limites e opcoes efetivamente suportadas ao render real"; aceite "abrir, ajustar, voltar, reabrir e desfazer sem perder valores". Afirmacao 6 da matriz (render x painel decorativo).**
  - afirmado: "e cap/join/miterLimit ainda faltam na serializacao (project_store.dart:452-461 grava cor, largura, opacidade e 'dash' apenas)."
  - verdade: cap, join e miterLimit JA sao serializados, e exatamente no trecho citado. lib/src/features/editor/domain/project_store.dart:452-464, no ramo `ShapeStroke st =>`, grava: 'kind':'stroke', 'id', 'color', 'w', e entao 'cap': st.cap.index (linha 457), 'join': st.join.index (458), 'miter': st.miterLimit (459), 'op', 'dash', 'gap' (462) e 'doff' (463) — ou seja, nove campos, nao quatro. A leitura tambem existe e e tolerante: project_store.dart:603-616 reconstroi ShapeStroke com cap: StrokeCap.values[m['cap']] (607), join: m['join'] == null ? StrokeJoin.round : StrokeJoin.values[...] (608-610), miterLimit: (m['miter'] as num?)?.toDouble() ?? 4 (611), mais dashLength/gapLength/dashOffset (613-615). O disco ja guarda tudo o que um subpainel Traco precisaria persistir; o buraco e so de UI e de comando. O resto da afirmacao 6 esta CERTO e foi confirmado: shape.dart:1733-1745 pinta stroke.color/width/cap/join/miterLimit e o tracejado; painel_de_cor.dart:331-352 so oferece cor, espessura e opacidade; e a varredura por dashLength/gapLength/dashOffset/miterLimit em lib/src/features/editor/presentation nao retorna nada.

---

## Shell, anatomia e maquina de estados (PDF paginas 6, 7 e 27)

Li editor_screen.dart (605 linhas), painel_da_camada.dart (832), pilula_de_navegacao.dart (265), linha_do_tempo.dart, visao_geral_das_camadas.dart, controles_da_camada.dart, adicionar_conteudo.dart, rails_do_painel.dart, palco_de_previa.dart e am_colors.dart. O Aurea ja tem a maior parte do VOCABULARIO do AM (cabecalho de propriedade que toma a barra, grade de familias por tipo, submodos de transformacao identicos, curva na faixa da ferramenta e nao em modal, `+` redondo no canto, transporte de sete alvos, cores medidas na propria referencia). O que diverge nao e aparencia: e a MAQUINA DE ESTADOS. Faltam tres coisas estruturais. (1) Nao existe o estado "Camada selecionada" do AM: selecionar uma camada nao troca o cabecalho, nao troca a area inferior e nao abre nada — sao precisos DOIS toques, e o cabecalho continua dizendo o nome do projeto. (2) Nao existe cabecalho de camada: nome, parent, excluir e o menu de tres pontos que o AM poe na faixa de cima moram enterrados no cartao "Camada" da grade. (3) Nao ha fonte unica de verdade para "painel ativo": o estado esta espalhado por onze StateProviders independentes, e a cadeia de prioridade entre eles esta copiada em tres arquivos. Dessa dispersao sai um defeito reprodutivel — trocar de camada com uma familia aberta deixa o titulo da familia antiga no cabecalho enquanto o painel ja mostra a grade da camada nova, violando a invariante "nunca reabrir um painel do objeto anterior". Alem disso, a substituicao da area inferior pelo contexto virou um interruptor MANUAL no cabecalho (modoDaLinhaDoTempoProvider), que e uma extensao do Aurea ocupando o lugar de uma regra do AM. Tres campos do contrato minimo de estado (curveInterval, timelineScroll, previewView) nao existem como estado nomeado. Nao editei nenhum arquivo.

### `!!` O cabecalho no contexto de camada mostra nome da camada, parent, excluir e o menu de tres pontos.

- evidencia: V 00:40
- hoje: NAO EXISTE. Com uma camada selecionada, editor_screen.dart:454 continua desenhando o cabecalho de PROJETO (nome do projeto, alternador, exportar). O nome da camada aparece so dentro do painel, quando ele esta aberto: painel_da_camada.dart:610-701 (_Cabecalho do painel, 44 px, nome + tipo + seta de recolher). Parent mora em controles_da_camada.dart:1273-1326 (_Pai), dentro do cartao 'Camada'; excluir em controles_da_camada.dart:1257. Nao ha nenhum 'mais' (grep por more_vert em lib/src/features/editor/presentation/ so acha estudio_da_cena.dart:266).
- divergencia: O AM troca a faixa inteira de cima ao selecionar uma camada. O Aurea nunca troca: as quatro acoes de camada estao a dois ou tres toques de distancia (selecionar, tocar de novo, abrir o cartao 'Camada'), e o parent — que o PDF corrige explicitamente na pagina 7 como sendo Layer Parent e nao duplicar — nao tem lugar nenhum no shell.
- mudanca: Criar um terceiro caso em _Cabecalho (editor_screen.dart), acionado por selectedLayerProvider != null: nome da camada a esquerda, glifo de parenting (quadrados sobrepostos), lixeira, e menu de tres pontos que reune o resto. Ligar o glifo de parenting ao escolhendoPaiProvider (controles_da_camada.dart) e a lixeira a EditorController.removeLayer. Manter as mesmas acoes dentro do cartao 'Camada' como caminho secundario.
- risco: Uma lixeira no cabecalho apaga camada com um toque. O comando ja passa pelo historico (removeLayer), mas o botao precisa da mesma confirmacao ou do mesmo lote de desfazer que o cartao 'Camada' usa hoje. O parenting captura o transform efetivo no instante do vinculo (linkProperty); chamar do cabecalho tem de passar o playhead corrente, senao a camada pula.
- teste: Teste de widget: selecionar uma camada e verificar que o cabecalho mostra o nome DELA e nao o do projeto, e que existem Semantics de botao para 'Seguir outra camada', 'Apagar' e o menu. Verificar que desselecionar devolve o cabecalho de projeto.

### `!!` Os controles de selecao ficam NO OBJETO, dentro da previa, e nao cobrem a timeline.

- evidencia: V 00:40
- hoje: A previa e editor_screen.dart:293-349 (AspectRatio + FittedBox + CompositionView). O unico sinal de selecao no palco e um contorno branco de 4 px, em palco_de_previa.dart:1283-1298, dentro de um IgnorePointer. O cabecalho do arquivo (palco_de_previa.dart:1-10) declara que a edicao no palco — alcas de mover, escalar e girar — foi apagada junto com a UI antiga.
- divergencia: Nao ha alca nenhuma, e a previa nao recebe toque: IgnorePointer garante que nenhum gesto no palco seleciona, move, escala ou gira. Toda transformacao passa obrigatoriamente pelo painel inferior. O AM mostra o objeto selecionado com controles em cima dele.
- mudanca: Reintroduzir uma camada de gestos sobre a previa (fora da arvore que a exportacao usa, como o contorno ja e): toque seleciona a camada sob o dedo, arraste move, alcas de canto escalam, alca superior gira. Usar beginGesture/endGesture do EditorController para o gesto virar UMA operacao de desfazer.
- risco: Duas armadilhas ja registradas no projeto: um gesto dentro de area rolavel precisa da AreaDeArrasto (memoria 'Aurea editar no palco'), e a selecao desenhada dentro da arvore de composicao vaza para a exportacao. As alcas tem de ficar como decoracao de tela, ao lado da moldura (editor_screen.dart:301), nunca dentro de CompositionView.
- teste: Teste de widget: com duas camadas empilhadas, tocar na previa nas coordenadas da de cima e verificar que selectedLayerProvider passou a ser o id dela; arrastar 40 px e verificar que a posicao mudou e que canUndo desfaz o arrasto inteiro em um passo.

### `!!` O contexto SUBSTITUI a area inferior: no projeto e a timeline geral, na camada e a faixa daquela camada mais o painel.

- evidencia: V 00:00 e V 00:40
- hoje: visao_geral_das_camadas.dart:29-38 define ModoDaLinhaDoTempo {detalhado, geral} e modoDaLinhaDoTempoProvider, que nasce em geral. Quem troca e o AlternadorDeVista (visao_geral_das_camadas.dart:51-70), um botao MANUAL no cabecalho. linha_do_tempo.dart:253-269 (_conteudo) escolhe a pilha ou a faixa unica APENAS por esse provider — a selecao nao entra na conta.
- divergencia: No AM a troca e consequencia da selecao; no Aurea e uma preferencia que a pessoa liga a mao e que fica ligada mesmo sem camada selecionada (linha_do_tempo.dart:298: 'if (atual == null) return const _SemSelecao()'). Selecionar uma camada na pilha nao muda um pixel da area inferior.
- mudanca: Derivar o modo da selecao: selectedLayerProvider != null e painel aberto -> faixa da camada; caso contrario -> pilha. Manter modoDaLinhaDoTempoProvider como sobreposicao opcional (extensao Aurea), com precedencia explicita e documentada, em vez de ser a unica fonte.
- risco: linha_do_tempo.dart:98-106 (alturaDoModo) e editor_screen.dart:267-276 usam o modo para dividir a altura da tela. Se o modo passar a mudar junto com a selecao, a previa e a timeline vao redimensionar a cada toque numa camada — exatamente o que editor_screen.dart:223-240 se esforca para evitar. O teto do preview precisa continuar sendo calculado com a ferramenta aberta, para nada se mexer.
- teste: Teste de widget: com tres camadas e nenhuma selecionada, contar tres trilhas de 30 px; selecionar uma e abrir as ferramentas, e verificar que sobrou uma faixa unica. Verificar por golden ou por medida que a altura da moldura da previa (key 'moldura-da-previa') e IDENTICA nos dois estados.

### `!!` A entrada do estado 'Camada selecionada' e selecionar o objeto na timeline — um gesto.

- evidencia: V 00:40
- hoje: visao_geral_das_camadas.dart:513-520: onTap so abre as ferramentas se a camada tocada JA era a selecionada; se nao era, o toque apenas escreve selectedLayerProvider e nada mais acontece. O comentario acima (:505-512) diz que isso e proposital, para nao pagar o atraso de onDoubleTap.
- divergencia: O AM entra no contexto de camada com UM toque. O Aurea exige dois toques na mesma camada, e entre o primeiro e o segundo a tela nao muda de estado: mesmo cabecalho, mesma area inferior, nenhum painel. Quem selecionou uma camada e nao tocou de novo nao ve que ha um contexto para entrar.
- mudanca: Fazer o primeiro toque selecionar E entrar no contexto de camada, chamando abrirFerramentasDaCamada junto com a escrita de selectedLayerProvider.
- risco: O toque simples e o gesto mais usado na pilha e hoje ele tambem serve para so trocar de camada enquanto se observa a previa. Abrindo o painel a cada toque, a linha do tempo encolhe ao chao a cada troca de camada — e preciso que a previa continue parada (editor_screen.dart:255-259 ja garante isso) e que trocar de camada com o painel aberto NAO reabra a grade por cima da familia que estava aberta (ver a linha da invariante).
- teste: Teste de widget: com duas camadas e a primeira selecionada, tocar UMA vez na segunda e verificar que estadoDoPainelProvider virou categorias e que a grade da segunda camada esta desenhada.

### `!!` Contrato minimo de estado: projectId, selectedLayerIds, propertyId, playhead, activePanel, transformMode, curveInterval, timelineScroll, timelineZoom, previewView e undoHistory.

- evidencia: P (pagina 7)
- hoje: Existem: selecao (selectedLayerProvider, editor_controller.dart:60, mais multiSelectProvider), playhead (PlaybackController.time, um ValueNotifier fora do Riverpod), transformMode (modoDeTransformacaoProvider), timelineZoom (zoomDaLinhaDoTempoProvider, mapa_do_tempo.dart), undoHistory (EditorController). Nao existem como estado nomeado: projectId (implicito no controller), curveInterval (so closures), timelineScroll (derivado — o cabecote fica preso em MapaDoTempo.fracaoDoCabecote e o conteudo desliza), previewView. E propertyId esta partido em quatro providers: parametroAbertoProvider, parametroDaCorProvider, parametroDaMascaraProvider e modoDeTransformacaoProvider.
- divergencia: O contrato existe de fato, mas espalhado e com tres campos ausentes. Nao ha um objeto ou grupo de providers que responda 'onde estou' de uma vez — o que o PDF chama na pagina 27 de 'uma fonte de verdade para selecao e painel ativo'.
- mudanca: Criar um unico provider de sessao do editor com os onze campos (adaptando nomes), e reescrever os StateProviders soltos como projecoes dele. Nao mover o playhead para dentro: ele muda 60 vezes por segundo e rebuildaria a tela inteira; deixar como ponteiro para o PlaybackController.
- risco: O maior desta matriz. Vinte e tantos widgets leem esses providers hoje; um provider unico faz TODOS reconstruirem a cada mudanca de qualquer campo. Precisa de seletores por campo, senao o editor perde quadros ao arrastar. E o descarte da edicao pendente (editor_screen.dart:149-162) escuta dez providers pelo nome — essa lista tem de virar uma regra sobre o objeto novo, sem esquecer nenhum foco.
- teste: Teste unitario do provider: para cada transicao (abrir familia, abrir submodo, abrir curva, abrir adicao, fechar), afirmar o valor esperado dos onze campos, incluindo os que NAO podem mudar (playhead e undoHistory).

### `!!` Invariante: nunca reabrir um painel do objeto anterior.

- evidencia: P (pagina 7)
- hoje: Trocar de camada NAO limpa categoriaAbertaProvider. Nada em lib/src/features/editor/ escreve nele por causa da selecao (o unico ponto que limpa e painel_da_camada.dart:405-412, e so quando a camada some do projeto). _Aberto (painel_da_camada.dart:507-510) resolve 'atual' procurando a categoria aberta na lista da camada NOVA; nao achando, cai na grade — mas o estado continua sendo categoria.
- divergencia: Defeito reprodutivel: com a familia 'Forma' aberta numa ShapeLayer, trocar para uma TextLayer (pela seta da faixa, linha_do_tempo.dart:305-315, que fica visivel acima do painel) deixa o cabecalho da tela dizendo 'Forma' (editor_screen.dart:420-426 le categoriaAbertaProvider, que ficou obsoleto) enquanto o painel ja mostra a grade da camada de texto. Sao duas afirmacoes contraditorias sobre onde a pessoa esta. Alem disso o painel fica com 300 px (painel_da_camada.dart:421-423) para mostrar uma grade que pediria menos.
- mudanca: Ao mudar selectedLayerProvider: se a categoria aberta nao existir na camada nova, limpar categoriaAbertaProvider e voltar estadoDoPainelProvider para categorias; se existir (por exemplo 'opacidade', que toda camada tem), mante-la aberta — que e o que o AM faz.
- risco: Limpar sempre custaria o caso bom: trocar de camada com 'Opacidade' aberta e um fluxo real, e fechar a ferramenta a cada troca obrigaria a reabrir toda vez. A regra tem de ser por existencia da categoria, nao por identidade da camada.
- teste: Teste de widget: abrir 'Forma' numa ShapeLayer, trocar a selecao para uma TextLayer, e verificar que o cabecalho NAO contem 'Forma' e que estadoDoPainelProvider e categorias. Segundo caso: abrir 'Opacidade', trocar de camada, verificar que continua 'Opacidade'.

### `! ` O cabecalho no contexto de projeto tem quatro coisas: voltar, nome do projeto, ajustes e exportar.

- evidencia: V 00:00
- hoje: lib/src/features/editor/presentation/editor_screen.dart:454-541 (_Cabecalho, altura 52 na linha 411): voltar (:458), nome do projeto (:486), AlternadorDeVista (:516), exportar colorido (:517).
- divergencia: Os quatro alvos existem, mas o terceiro NAO e ajustes: e o alternador de vista da linha do tempo, que o AM nao tem. Os ajustes da composicao so abrem tocando no NOME do projeto (:494), sem nenhum glifo que anuncie isso; e o painel que abre (PainelDaComposicao, lib/src/features/editor/presentation/widgets/painel_de_cor.dart:374-402) contem so a cor de fundo — nao ha fps, resolucao nem duracao, que sao o que a engrenagem do AM mostra em 01:47.
- mudanca: Devolver a engrenagem ao quarto slot do cabecalho, chamando abrirAjustesDaComposicao (painel_da_camada.dart:456). Mover AlternadorDeVista para dentro da area inferior ou para o menu de tres pontos, como extensao Aurea. Encher PainelDaComposicao com fps, resolucao e duracao, lendo os campos que ja existem em VideoProject.
- risco: Tirar o toque no nome quebra o unico caminho hoje conhecido para a cor de fundo; manter os dois caminhos durante uma versao. Expor fps/resolucao abre a porta para reescalonar keyframes de projeto antigo — o painel tem de ler e escrever pelos comandos do EditorController, nunca mexer direto no estado.
- teste: Teste de widget: no contexto de projeto, encontrar um Semantics(label:'Ajustes da composicao') que seja um botao proprio no cabecalho (nao o texto do nome); tocar nele e verificar que os campos de fps e resolucao aparecem.

### `! ` O estado Projeto tem a timeline completa e o `+` no canto inferior direito.

- evidencia: V 00:00
- hoje: linha_do_tempo.dart:229-233 (_BotaoRedondoDeAdicao, 46 px, Positioned right:12 bottom:12) e linha_do_tempo.dart:1458-1502. Ele so some com painelDaCamadaLigadoProvider desligado (:1467).
- divergencia: O `+` esta presente em TODOS os estados, inclusive com a ferramenta de uma camada aberta ou com a curva aberta — o AM o mostra so no contexto de projeto. Como ele fica na area da linha do tempo, que continua visivel acima do painel, ele e alcancavel e funcional durante qualquer edicao.
- mudanca: Esconder _BotaoRedondoDeAdicao quando estadoDoPainelProvider != recolhido ou curvaEmEdicaoProvider != null.
- risco: Num projeto vazio o `+` e o unico caminho para comecar (comentario em linha_do_tempo.dart:1471); a condicao nao pode alcancar esse caso. Estados como composicao e selecao tambem precisam de decisao explicita, senao adicionar conteudo fica inalcancavel com uma juncao ativa.
- teste: Teste de widget: abrir a categoria 'Opacidade' e verificar que Semantics(label:'Adicionar conteudo') nao esta na arvore; fechar a ferramenta e verificar que voltou. Com zero camadas, verificar que continua presente.

### `! ` O `+` abre um seletor unico, com abas e atalhos laterais; o X fecha; a insercao leva ao contexto do objeto novo.

- evidencia: V 00:26
- hoje: Sao DOIS passos. Primeiro abrirAdicaoDeConteudo (painel_da_camada.dart:476-482) liga barraDeAdicaoAbertaProvider e linha_do_tempo.dart:236-247 desenha BarraDeCategoriasDeAdicao (adicionar_conteudo.dart:287-343) — uma barra horizontal rolavel de icones logo acima do `+`. Tocar numa familia abre PainelCentralDeAdicao (adicionar_conteudo.dart:355-476), um modal centrado de 340x420 com a tela desfocada atras, grade de 3 colunas, X no cabecalho (:433) e toque no fundo para fechar (:389-404). Depois de criar, editor_screen.dart:371-379 chama abrirFerramentasDaCamada.
- divergencia: Tres diferencas. (a) Sao duas superficies em sequencia, e nao um seletor com abas — a barra de familias faz o papel das abas mas fica noutra peca, e nao ha atalhos laterais. (b) Ao criar, o Aurea cai no estado `categorias` (a grade de ferramentas), e nao no contexto de camada do AM, que mostra a faixa temporal e o cabecalho da camada nova. (c) fecharAdicao (adicionar_conteudo.dart:277-280) so limpa categoriaDeAdicao e subItemDeAdicao; barraDeAdicaoAbertaProvider fica ligado, entao o X do modal volta para a barra em vez de fechar o fluxo.
- mudanca: Fundir a barra e o modal numa superficie so: abas horizontais no topo do painel central, itens na grade abaixo, atalhos frequentes numa coluna lateral. Fazer o X limpar tambem barraDeAdicaoAbertaProvider. Ao criar, entrar no contexto de camada nova (depende da linha 5 desta matriz existir) em vez de na grade de categorias.
- risco: categoriasDeAdicao tem sub-itens (subItemDeAdicaoProvider, adicionar_conteudo.dart:382-386): abas precisam preservar essa navegacao de dois niveis. E instanteDeInsercaoProvider e capturado quando o menu ABRE (painel_da_camada.dart:478-479), nao no toque — refazer o fluxo nao pode mover essa captura, ou o conteudo entra no lugar errado.
- teste: Teste de widget: tocar no `+`, verificar que existe UMA superficie com abas; tocar no X e verificar que barraDeAdicaoAbertaProvider voltou a false e que nenhuma peca de adicao esta na arvore. Criar um texto e verificar que o cabecalho passou a mostrar o nome da camada nova.

### `! ` O conteudo do estado de camada inclui uma grade de acoes por TIPO de objeto.

- evidencia: V 00:40
- hoje: painel_da_camada.dart:106-261 (categoriasDaCamada) monta a grade por tipo real da camada, e o levantamento na doc do proprio codigo (:85-105) amarra cada cartao a um comando existente no EditorController. _GradeDeCategorias (:703-744) desenha em duas colunas, cartoes de 56 px, chave de teste 'cartao-<id>'.
- divergencia: NENHUMA na estrutura. Uma unica excecao de conteudo: o cartao 'Borda e sombra' (painel_da_camada.dart:228-234) esta desabilitado com o texto 'Chega numa proxima entrega', e a pagina 7 do PDF cita justamente 'Borda e sombra' como o exemplo de familia que abre um subpainel no AM.
- mudanca: Nenhuma na grade. A familia 'Borda e sombra' e trabalho de outra superficie (apresentacao por tipo); registrar aqui apenas que ela e uma exigencia V e nao um item opcional.
- risco: Nenhum nesta superficie.
- teste: Ja coberto: test/painel_da_camada_test.dart grupo 'as ferramentas vem da capacidade real'.

### `! ` A curva do intervalo abre um grafico na area inferior, com controles laterais e a previa da MESMA camada; nao existe editor global de curvas.

- evidencia: V 01:33
- hoje: curvaEmEdicaoProvider (editor_de_curva.dart:36) guarda um CurvaEmEdicao (:16-34) com titulo, easing atual e DUAS closures (aoAplicar, aoAplicarEmTodos). PainelSobreposto abre EditorDeCurva na mesma faixa das outras ferramentas (painel_da_camada.dart:308-345), com a previa intacta acima; o cabecalho da tela vira 'Curva de gradacao' (editor_screen.dart:417-419).
- divergencia: A colocacao esta certa e nao ha editor global. A divergencia e de CONTRATO: o PDF pede curveInterval como campo de estado, e o que o Aurea guarda sao closures — nao ha id de camada, de propriedade nem de intervalo. Consequencia observavel: nada invalida a curva quando a selecao muda, entao as closures continuam apontando para a camada anterior, e o estado nao pode ser restaurado nem inspecionado.
- mudanca: Trocar CurvaEmEdicao por um valor identificavel (layerId, propriedade, indice do intervalo) e resolver as acoes a partir dele no momento de aplicar. Fechar a curva automaticamente quando selectedLayerProvider mudar.
- risco: aoAplicarEmTodos so e nao-nulo quando ha mais de um trecho (editor_de_curva.dart:31-33); um identificador tem de saber recalcular isso, senao o botao aparece ou some errado. A curva escreve easing em keyframes reais — resolver o alvo tarde demais pode aplicar no intervalo errado.
- teste: Teste de widget: abrir a curva de uma propriedade da camada A, trocar a selecao para a camada B e verificar que curvaEmEdicaoProvider voltou a null e que o cabecalho nao diz mais 'Curva de gradacao'.

### `! ` Menu, modal e ajustes sao overlay com escopo claro, e fechar restaura EXATAMENTE o estado anterior.

- evidencia: V 01:47
- hoje: abrirAdicaoDeConteudo (painel_da_camada.dart:476-482) forca estadoDoPainelProvider para recolhido antes de abrir a barra de adicao, e nao guarda o que estava aberto. fecharAdicao (adicionar_conteudo.dart:277-280) limpa so a categoria e o sub-item.
- divergencia: Com a ferramenta 'Opacidade' aberta, tocar no `+` (que continua alcancavel, ver a linha do `+`) fecha o painel; desistir pelo X ou pelo fundo desfocado NAO reabre a ferramenta. O estado anterior e perdido, nao restaurado.
- mudanca: Guardar o par (estadoDoPainel, categoriaAberta) ao abrir a adicao e restaura-lo em fecharAdicao quando nenhuma camada foi criada. Se uma camada foi criada, seguir para o contexto dela (que e o que o AM faz).
- risco: Se a camada anterior tiver sido apagada ou substituida enquanto o menu estava aberto, restaurar o par leva a um painel de objeto morto — a restauracao precisa reconferir que a camada e a categoria ainda existem, como painel_da_camada.dart:405-412 ja faz para camada nula.
- teste: Teste de widget: abrir 'Opacidade', tocar no `+`, tocar no X, e verificar que estadoDoPainelProvider voltou a categoria e categoriaAbertaProvider a 'opacidade'.

### `! ` Invariante: nunca exibir dois paineis concorrentes.

- evidencia: P (pagina 7)
- hoje: O desenho e exclusivo: PainelSobreposto (painel_da_camada.dart:298-434) retorna no primeiro caso que casar, e EstadoDoPainel (painel_da_camada.dart:24-53) e um enum. A prioridade e: curva > recolhido > composicao > selecao > camada.
- divergencia: O resultado esta certo, mas a MESMA cadeia de prioridade esta escrita tres vezes, em dois arquivos: editor_screen.dart:417-443 (qual titulo o cabecalho mostra), painel_da_camada.dart:308-345 (qual painel desenhar) e painel_da_camada.dart:636-652 (alturaDaFerramentaAberta, quanto espaco reservar). Sao tres copias que precisam concordar; a linha da invariante acima e o que acontece quando uma delas le um provider que as outras ja ignoraram.
- mudanca: Extrair uma unica funcao — algo como painelAtivo(ref) devolvendo um valor selado — e fazer os tres pontos lerem dela: titulo, corpo e altura.
- risco: alturaDaFerramentaAberta e chamada dentro do LayoutBuilder de editor_screen.dart:241, num caminho que roda a cada layout; a funcao extraida nao pode passar a observar mais providers do que a versao atual, ou a tela reconstroi por mudancas que nao mexem na altura.
- teste: Teste de widget parametrizado por estado: para cada um dos cinco estados mais a curva, afirmar que ha exatamente um painel na arvore e que o titulo do cabecalho e o esperado para aquele painel.

### `! ` Comparacao geometrica das zonas principais com tolerancia de 2% da largura/altura, em mesmo viewport e mesmo estado.

- evidencia: P (pagina 27)
- hoje: NAO EXISTE. Ha testes de layout (test/painel_da_camada_test.dart grupo 'layout do editor', test/linha_do_tempo_test.dart), mas nenhum compara a caixa de cada zona contra medidas de referencia, e nao ha capturas do AM versionadas no repositorio para comparar.
- divergencia: O criterio de aceite proposto pelo PDF nao tem instrumento no projeto.
- mudanca: Criar um teste de bancada que, num viewport de 384x832, meca as caixas de cabecalho, previa, transporte, regua, trilhas e painel, e compare com uma tabela de referencia versionada. Usar o print da UI por teste (RepaintBoundary com GlobalKey e as fontes do cache do SDK) para o dump visual.
- risco: Fixar as caixas em pixels num viewport unico transforma qualquer ajuste responsivo legitimo em teste vermelho. A tabela precisa ser expressa em FRACAO da tela, nao em pixels absolutos, e o teste deve rodar so no viewport de referencia.
- teste: O proprio teste e a entrega: medir cada zona e afirmar que a diferenca para a referencia e menor que 2% da dimensao correspondente.

### `ok` O cabecalho no contexto de propriedade tem so voltar e o titulo da propriedade.

- evidencia: V 01:33
- hoje: editor_screen.dart:548-604 (_CabecalhoDaFerramenta): seta de 48 px, titulo centrado, e um SizedBox(width:48) na direita para o titulo cair no centro de verdade (:601). O titulo sai de tituloDaFerramenta (painel_da_camada.dart:533-556) ou de 'Curva de gradacao' (:418).
- divergencia: NENHUMA

### `ok` Nao empilhar o painel novo sobre os paineis antigos: a area inferior e uma so.

- evidencia: V 00:40
- hoje: editor_screen.dart:241 (alturaDaFerramentaAberta) reserva a altura do painel no Column (:356, SizedBox(height: ferramenta)) e PainelSobreposto (painel_da_camada.dart:292-434) desenha por cima em Positioned(bottom:0). A linha do tempo encolhe ate o chao (transporte + regua + uma trilha, editor_screen.dart:247-250) e continua inteira acima do painel.
- divergencia: NENHUMA

### `ok` Tocar num tile abre o titulo da familia mais o subpainel; voltar recupera o contexto de camada sem perder valores.

- evidencia: V 00:51
- hoje: _Cartao.onTap (painel_da_camada.dart:762-768) escreve categoriaAbertaProvider e passa o estado para categoria; o cabecalho da tela e tomado pelo titulo (editor_screen.dart:420-426 + tituloDaFerramenta em painel_da_camada.dart:533-556). Ha DOIS caminhos de volta e cada um faz uma coisa: o `‹` do RailEsquerdo (rails_do_painel.dart:47-77) volta um nivel para a grade, e o `‹` do cabecalho chama fecharFerramenta (painel_da_camada.dart:600-603), que fecha tudo.
- divergencia: NENHUMA. Nem o voltar do rail nem o do cabecalho escrevem no projeto, e o comentario em painel_da_camada.dart:760-762 registra que abrir uma categoria nao inicializa nem insere keyframe.

### `ok` Submodo (posicao / rotacao / dimensoes / skew) troca so o conteudo local e preserva camada, playhead, propriedades e historico.

- evidencia: V 00:51
- hoje: painel_de_transformacao.dart:15 define exatamente os quatro modos {mover, girar, escalar, inclinar}, e modoDeTransformacaoProvider (:17-19) e um StateProvider de sessao. Trocar de modo (:103) so escreve o provider. editor_screen.dart:149-162 escuta modoDeTransformacaoProvider apenas para descartar a edicao pendente do losango — nao toca no playhead, na selecao nem no historico.
- divergencia: NENHUMA

### `ok` Invariantes: nunca perder a selecao ao abrir um submenu; nunca reiniciar o playhead ao voltar; a troca de painel nao altera o projeto.

- evidencia: P (pagina 7)
- hoje: Selecao: nenhuma abertura de painel escreve selectedLayerProvider (as escritas estao em editor_controller.dart e em linha_do_tempo.dart:312, todas por acao explicita). Playhead: fecharFerramenta (painel_da_camada.dart:600-603) e o voltar do rail nao tocam no PlaybackController. Projeto: _Cartao.onTap (painel_da_camada.dart:760-768) so escreve providers de UI, com o motivo documentado.
- divergencia: NENHUMA. abrirAdicaoDeConteudo chama playback.pause() (painel_da_camada.dart:477), o que e pausar e nao reiniciar — e a captura do instante em :479 depende disso.

### `ok` Responsividade e acesso: respeitar safe areas e proporcoes reais; ampliar a area de toque sem deslocar o glifo; rotulos completos.

- evidencia: P (pagina 27)
- hoje: SafeArea envolve o corpo (editor_screen.dart:186). A previa deriva da proporcao real do projeto (:222, project.outputWidth/outputHeight) e nao de um 1:1 fixo. Alvo maior que desenho: pilula_de_navegacao.dart:58-73 (branco de 32 px centrado num alvo de 48) e linha_do_tempo.dart:80-83 (transporte em 48 e nao nos 32 medidos na referencia). Rotulos: Semantics com label em praticamente todo controle desta superficie.
- divergencia: NENHUMA. As medidas do PDF (cabecalho y=43-89, ou seja ~46 px, contra os 52 do Aurea) sao a referencia de um quadro de 384x832 e a propria pagina 6 manda converter para layout responsivo.

### Extensoes do Aurea nesta superficie

O PDF manda preservar e dar destino contextual — nunca apagar.

- Alternador de vista da linha do tempo (visao_geral_das_camadas.dart:29-70, ModoDaLinhaDoTempo detalhado/geral): o AM so tem a pilha. O modo detalhado responde 'o que esta acontecendo NESTA camada' com keyframes grandes o bastante para o dedo. Destino: manter como sobreposicao opcional, mas tirar do slot da engrenagem no cabecalho — ele ocupa o lugar de um controle do AM.
- Estado EstadoDoPainel.composicao (painel_da_camada.dart:44 e PainelDaComposicao em painel_de_cor.dart:374): ajustes do que nao pertence a camada nenhuma (hoje so a cor de fundo). O AM poe isso na engrenagem do projeto. Destino: fundir com o painel de ajustes do projeto que a engrenagem deve abrir, e acrescentar fps, resolucao e duracao.
- Estado EstadoDoPainel.selecao (painel_da_camada.dart:52 e PainelDaSelecao) com juncao por toque longo (visao_geral_das_camadas.dart:478-495): acoes em lote sobre varias camadas — agrupar, alinhar, distribuir, escalonar. O AM nao mostra multi-selecao no video. Destino: preservar; e a resposta natural ao cabecalho '<n> camadas' (editor_screen.dart:436-443), que ja se comporta como um contexto proprio.
- Duplicar e enquadrar no transporte (linha_do_tempo.dart:409-431): a referencia tem sete alvos e o Aurea os preencheu com duas acoes proprias — duplicar a camada selecionada e enquadrar o TEMPO (o AM enquadra a previa). Destino: preservar; nao ha conflito de posicao, so de significado do setimo glifo.
- Interruptor painelDaCamadaLigadoProvider (painel_da_camada.dart:57): desliga o painel inteiro e devolve a interface anterior sem converter projeto. Destino: preservar como ferramenta de validacao durante a reconstrucao; sem ele nao ha comparacao lado a lado com a UI anterior.
- Cartoes desabilitados que dizem POR QUE (CategoriaDaCamada.porQueNao, painel_da_camada.dart:96-99 e 803-816): o AM nao tem esse padrao. Destino: preservar — ele e o que faz o aceite 'zero controles sem acao' ser verificavel em vez de virar cartao que abre o nada.
- Modo Pro (application/ui/pro_mode.dart, proModeProvider) e o estudio 3D (presentation/estudio/): superficies inteiras que o AM nao tem. Nao aparecem no shell hoje. Destino: dar entrada contextual — o estudio pela familia 'Cena e camera' de uma Scene3DLayer, o modo Pro pelo menu de tres pontos do cabecalho de camada quando ele existir. Nunca apagar.
- Cabecote preso no meio da largura com zoom e enquadramento (linha_do_tempo.dart:206-219 e MapaDoTempo): o AM desliza o cabecote pela regua. A escolha do Aurea permite escala constante em projeto longo. Destino: preservar; e uma decisao de motor de tempo, nao de shell, e o PDF nao a contradiz.
- Marcadores e batidas desenhados na regua (linha_do_tempo.dart:194-198, project.markers e project.beats): nao observados no AM. Destino: preservar na regua.
- Contorno branco de selecao na previa (palco_de_previa.dart:1283-1298), desenhado depois dos efeitos para blur e glow nao pegarem a borda: o AM mostra alcas. Destino: preservar o contorno como base sobre a qual as alcas do AM serao montadas, mantendo-o fora da arvore que a exportacao usa.

### Correcoes do conferente (4)

- **Preview (pag. 6): controles de selecao ficam no objeto, dentro da previa, e nao cobrem a timeline.**
  - afirmado: 'O unico sinal de selecao no palco e um contorno branco de 4 px, em palco_de_previa.dart:1283-1298, dentro de um IgnorePointer. (...) a previa nao recebe toque: IgnorePointer garante que nenhum gesto no palco seleciona, move, escala ou gira.'
  - verdade: O veredito (nao ha alca nenhuma no palco) confere, mas o mecanismo citado esta errado, e a prova oferecida nao prova nada. O IgnorePointer de palco_de_previa.dart:1288-1296 envolve APENAS o Container do contorno branco de 4 px que e empilhado sobre o conteudo da camada selecionada — ele existe para que essa borda decorativa nao coma o toque do que esta embaixo dela. Ele nao cobre o palco, e nao poderia: e um Positioned.fill dentro do Stack de UMA camada. O motivo real de nenhum gesto chegar ao palco e outro, e mais forte: palco_de_previa.dart nao tem UM unico GestureDetector, Listener ou RawGestureDetector (grep 'GestureDetector' no arquivo inteiro retorna 0), e a arvore que editor_screen.dart:293-349 monta em volta da CompositionView (Padding > Center > AspectRatio > DecoratedBox > ClipRect > FittedBox > SizedBox) tambem nao tem nenhum. Nao ha gesto para ignorar. Quem tentasse consertar a divergencia apagando o IgnorePointer apontado nao ganharia toque nenhum — so perderia a borda de selecao para o hit test.
- **Area inferior (pag. 6): o contexto substitui a area inferior — timeline geral no projeto; faixa da camada + painel na camada.**
  - afirmado: 'Selecionar uma camada na pilha nao muda um pixel da area inferior.'
  - verdade: Falso, e nao por detalhe cosmetico. O pintor da pilha em visao_geral_das_camadas.dart:733-741 desenha, SO na camada cujo id e igual a selecionada, um anel branco (AmColors.text, strokeWidth 1.6) em volta da barra e chama _pintarAlcasDeAparar(canvas, barra) (definido em :842) — as alcas de aparar aparecem por causa da selecao. E elas nao sao desenho: _pousar (visao_geral_das_camadas.dart:206-244) comeca com 'if (selecionada == null) return;' e 'if (l.id != selecionada) return;', ou seja, mover o clipe no tempo e aparar as duas pontas so existem como gesto na camada selecionada. O primeiro toque, portanto, muda pixels E capacidade da area inferior. O veredito estrutural do item continua de pe (o modo da timeline e trocado a mao pelo AlternadorDeVista, visao_geral_das_camadas.dart:51-70, e linha_do_tempo.dart:257-291 escolhe pilha ou faixa unica so por modoDaLinhaDoTempoProvider, sem olhar a selecao) — o que esta errado e a frase de fecho, que descreve como inerte uma area que reage.
- **Estado 'Camada selecionada' (pag. 7): a entrada e selecionar o objeto/camada na timeline — um gesto.**
  - afirmado: 'O Aurea exige dois toques na mesma camada, e entre o primeiro e o segundo a tela nao muda de estado: mesmo cabecalho, mesma area inferior, nenhum painel. Quem selecionou uma camada e nao tocou de novo nao ve que ha um contexto para entrar.'
  - verdade: A contagem de toques confere (visao_geral_das_camadas.dart:513-520: o toque so abre as ferramentas se a camada ja era a selecionada), mas 'a tela nao muda de estado' e falso em tres lugares ao mesmo tempo, e o terceiro e o proprio item 2 desta matriz. (1) Na previa: palco_de_previa.dart:1283-1298 desenha o contorno branco de 4 px em volta do objeto — o objeto selecionado passa a estar marcado no palco a partir do PRIMEIRO toque. (2) Na area inferior: visao_geral_das_camadas.dart:733-741 poe anel branco e alcas de aparar naquela faixa, e visao_geral_das_camadas.dart:206-214 so deixa mover/aparar a camada selecionada — o primeiro toque libera gesto que antes nao existia. (3) No transporte: linha_do_tempo.dart:409-419, o botao Duplicar camada nasce 'ativo: camadaSelecionada != null' e acende. So o cabecalho fica igual (editor_screen.dart:415-453 cai no cabecalho de projeto com uma camada so). A divergencia real e mais estreita do que a afirmada: o que falta apos o primeiro toque nao e 'qualquer mudanca de estado', e o painel/faixa da camada — o feedback de selecao existe e e visivel em tres regioes.
- **Contrato minimo de estado (pag. 7 e 27): projectId, selectedLayerIds, propertyId, playhead, activePanel, transformMode, curveInterval, timelineScroll, timelineZoom, previewView e undoHistory; uma fonte de verdade para selecao e painel ativo.**
  - afirmado: 'Nao existem como estado nomeado: projectId (implicito no controller), curveInterval (so closures), timelineScroll (derivado (...)), previewView. (...) O contrato existe de fato, mas espalhado e com tres campos ausentes.'
  - verdade: curveInterval EXISTE como estado nomeado, com outro nome: editor_de_curva.dart:36, 'final curvaEmEdicaoProvider = StateProvider<CurvaEmEdicao?>((ref) => null)', com a classe CurvaEmEdicao em editor_de_curva.dart:15-34 (titulo, Easing atual, aoAplicar, aoAplicarEmTodos). E nao e um provider esquecido: o shell inteiro se governa por ele — editor_screen.dart:415-418 le curvaEmEdicaoProvider ANTES de qualquer outro estado e toma a barra de cima com 'Curva de gradacao'; painel_da_camada.dart:331-345 troca o painel inteiro pelo EditorDeCurva; painel_da_camada.dart:577-579 (alturaDaFerramentaAberta) reserva os 300 px por causa dele. Quem abre escreve nele em quatro pontos (controles_da_camada.dart:294, painel_de_cor.dart:62, ficha_do_selecionado.dart:1212 e :1230) e editor_de_curva.dart:97 o zera ao fechar. Chamar isso de 'so closures' inverte o caso: as closures sao a CARGA do estado (o intervalo alvo nao e identificado — o editor 'nao conhece camada, efeito nem propriedade', comentario em :12-14), mas o slot 'ha uma curva aberta, e esta' e um provider unico e nomeado. Logo 'tres campos ausentes' esta errado por um: ausente de verdade so previewView; timelineScroll e derivado por desenho (mapa_do_tempo.dart:52, fracaoDoCabecote = .5, o cabecote fica preso e o conteudo desliza) e projectId existe dentro do estado (VideoProject.id). O restante do item confere: propertyId realmente esta partido em mais providers do que o citado (parametroAbertoProvider, efeitoAbertoProvider, mascaraAbertaProvider, parametroDaMascaraProvider, itemDaCorProvider, parametroDaCorProvider, modoDeTransformacaoProvider, posicaoDaAnimacaoProvider), e nao ha objeto unico que responda 'onde estou'.

---

## Efeitos: pilha da camada, + Adicionar efeito, menu de colar (PAGINA 21 da especificacao AM ONLY, rev. 02)

Li a pagina 21 (mais 2, 3 e 7) e abri o codigo. O caminho Camada > Efeitos e o cabecalho "Efeitos" ja batem, a faixa da camada continua visivel, e adicionar/habilitar/editar/remover mexem no projeto de verdade. O que falta e o lado direito da pagina: NAO EXISTE menu no canto inferior esquerdo do painel (o RailEsquerdo, rails_do_painel.dart:57-101, ocupa esse canto com tres botoes e nenhuma sobra), NAO EXISTE area de transferencia de efeito em lugar nenhum de lib (nem "Colar Efeito", nem o estado apagado dele), e NAO EXISTE menu junto ao nome de cada efeito para copiar (controles_da_camada.dart:605-690 tem so abrir, olho e lixeira). Duas falhas de estado alem do desenho: catalogoDeEfeitosProvider (controles_da_camada.dart:308) e global e nao e zerado nem por fecharFerramenta (painel_da_camada.dart:600) nem pela troca de camada (editor_screen.dart:150-161), entao sair com o catalogo aberto e voltar — inclusive noutra camada — reabre o catalogo, que e exatamente o invariante da pagina 7; e reorderEffect (editor_controller.dart:5477) existe no motor com ZERO chamadores de UI, enquanto quick_guide_screen.dart:157 ensina uma alca de arrasto que nao existe. Duas divergencias menores de composicao no estado vazio: o Aurea abre com a frase "Esta camada ainda nao tem efeito nenhum" (:577) onde o AM abre vazio, e poe "+ Adicionar efeito" como ULTIMO filho da coluna (:592-598) onde o AM o poe no topo. O catalogo do + segue marcado N: nao declarei paridade e recomendo nao redesenha-lo antes de haver referencia AM.

### `!!` Existe um menu (tres pontos) no CANTO INFERIOR ESQUERDO do painel de Efeitos.

- evidencia: V 01:25.0
- hoje: NAO EXISTE. O canto inferior esquerdo do painel e ocupado pelo RailEsquerdo (lib/src/features/editor/presentation/widgets/rails_do_painel.dart:57-101), que tem exatamente tres botoes em Expanded — voltar, keyframe, curva — e nenhuma sobra; _ComRail (controles_da_camada.dart:172-196) monta rail + conteudo rolavel e nao reserva slot de menu.
- divergencia: O ponto de entrada do menu de efeitos nao existe em lugar nenhum da superficie.
- mudanca: Dar um quarto slot ao rail quando a categoria for 'efeitos' (ou uma barra de rodape propria do painel de efeitos) com o botao de menu no canto inferior esquerdo, abrindo um overlay de escopo claro que fecha restaurando o estado anterior (invariante da pag. 7).
- risco: O rail tem 46 px e altura fixa de painel (300 px); um quarto botao encolhe os tres existentes e pode empurrar o losango de keyframe para fora do alcance confortavel. Um overlay mal escopado viola "nunca exibir dois paineis concorrentes".
- teste: Widget test: abrir Efeitos, esperar find.bySemanticsLabel('Menu de efeitos') findsOneWidget e que getBottomLeft dele esteja no quadrante inferior esquerdo do painel; tocar e conferir que efeitoAberto/parametroAberto/playhead nao mudam.

### `!!` Abrir esse menu mostra o item "Colar Efeito", visualmente apagado quando nao ha efeito copiado.

- evidencia: V 01:25.0 (menu aberto, item apagado, sem colagem no trecho)
- hoje: NAO EXISTE. Varredura em lib por colar/paste/clipboard cruzada com efeito nao retorna nada; nao ha area de transferencia de efeito no editor_controller.dart (so duplicateEffect:5446, que copia dentro da mesma camada). O unico Clipboard do app e de texto (report_sheet.dart:114, export_video_screen.dart:872).
- divergencia: Nao ha item de colar, nem estado de "nada copiado", nem area de transferencia de efeito.
- mudanca: Criar uma area de transferencia de efeito em memoria (provider com List<EffectInstance>) e o item 'Colar Efeito' no menu, apagado quando vazia. O _Acao ja tem o gancho de apagado: o campo `porQueNao` (controles_da_camada.dart:1377,1391) desenha rotulo cinza e desliga o toque. Colar deve inserir no fim da pilha da camada selecionada, num unico passo de desfazer (beginGesture/endGesture ou runAsOneUndo).
- risco: Colar efeito entre camadas de tipos diferentes pode trazer parametro que o tipo destino nao usa; reconcilePreset (editor_controller.dart:975) ja resolve isso para preset e deve ser reaproveitado, senao entra efeito com trilha invalida no projeto salvo.
- teste: Widget test: (a) sem nada copiado, abrir o menu e conferir que 'Colar Efeito' esta com enabled:false na semantica; (b) copiar um efeito da camada A, selecionar B, colar e conferir que B.effects.length subiu em 1 com o mesmo type e valores, e que um unico undo desfaz.

### `!!` Cada efeito tem, junto ao seu nome, um menu de onde se copia aquele efeito.

- evidencia: D3 (Alight Motion, Copy and Paste Effects)
- hoje: NAO EXISTE menu por efeito. _TituloDoEfeito (controles_da_camada.dart:605-690) tem so tres controles: a area de toque que abre/fecha a ficha (:625-660), o olho ligar/desligar (:662-670) e a lixeira (:671-676).
- divergencia: Falta o menu por efeito e a acao Copiar. O motor tambem nao tem comando de copiar para fora da camada.
- mudanca: Acrescentar um _IconeDoTitulo de menu no fim da linha de _TituloDoEfeito, abrindo pelo menos Copiar (e, com o motor que ja existe, Duplicar via duplicateEffect e Reordenar via reorderEffect).
- risco: A linha tem 40 px de altura e ja carrega dois icones de 34 px mais o nome com ellipsis; um quarto elemento pode comer o nome em efeitos de nome longo (ex.: 'Correcao de cor avancada').
- teste: Widget test: adicionar um efeito, tocar em 'Menu de <nome>', escolher 'Copiar', e conferir que o provider de area de transferencia passou a conter uma instancia com o mesmo type e params.

### `!!` Os RETORNOS do caminho Camada > Efeitos restauram exatamente o estado anterior; nunca reabrir um painel do objeto anterior.

- evidencia: P (pag. 21, obrigacao do agente) + P (invariantes, pag. 7)
- hoje: catalogoDeEfeitosProvider (controles_da_camada.dart:308) e um StateProvider GLOBAL, so voltado a false em dois pontos: o _Acao 'Voltar aos efeitos da camada' (:986-991) e apos aplicar um efeito (:1019). fecharFerramenta (painel_da_camada.dart:600-603) e o `aoVoltar` do rail (painel_da_camada.dart:527-533) nao o zeram, e a lista de providers que o editor_screen.dart:150-161 escuta na troca de camada inclui efeitoAbertoProvider e parametroAbertoProvider mas NAO catalogoDeEfeitosProvider.
- divergencia: Sair de Efeitos com o catalogo aberto e voltar reabre o CATALOGO em vez da pilha; e pior entre camadas: abrir o catalogo na camada A, sair, selecionar a camada B e abrir Efeitos mostra o catalogo, e o efeito escolhido cai em B. Isso quebra o invariante "nunca reabrir um painel do objeto anterior".
- mudanca: Zerar catalogoDeEfeitosProvider em fecharFerramenta (painel_da_camada.dart:600) e no `aoVoltar` da categoria, e incluir esse provider na lista de focos de editor_screen.dart:150-161 para que a troca de camada tambem o feche.
- risco: Zerar cedo demais tira a possibilidade de voltar ao catalogo com um toque; e preciso zerar so na SAIDA da categoria e na troca de camada, nao a cada rebuild.
- teste: Widget test: abrir Efeitos, tocar em 'Adicionar efeito', tocar no ‹ do rail, reabrir Efeitos e esperar find.bySemanticsLabel('Adicionar efeito') findsOneWidget (ou seja, a pilha, nao o catalogo). Repetir trocando de camada no meio.

### `!!` Reordenar efeitos precisa alterar o projeto real, e nao so desenhar linhas.

- evidencia: P (pag. 21)
- hoje: O comando existe: reorderEffect(layerId, effectId, delta) em lib/src/features/editor/application/editor_controller.dart:5477-5489. Chamadores na UI: ZERO (varredura em lib). Nao ha alca de arrasto nem setas em _TituloDoEfeito (controles_da_camada.dart:605-690). Pior: lib/src/features/help/presentation/quick_guide_screen.dart:157 ENSINA "Arraste a alca para reordenar" e "Use Resetar", dois controles que nao existem na tela.
- divergencia: A ordem da pilha decide o resultado do render e nao ha nenhum jeito de mudar sem apagar e readicionar; e a ajuda do proprio app descreve um controle inexistente.
- mudanca: Ligar reorderEffect a UI: ou duas setas no menu por efeito, ou ReorderableListView na pilha. Corrigir ou remover a frase de quick_guide_screen.dart:157 no mesmo passo.
- risco: ReorderableListView dentro do SingleChildScrollView de _ComRail (controles_da_camada.dart:187-193) briga por gesto de arrasto e por altura sem limite; a armadilha ja conhecida do projeto (gesto dentro de area rolavel) se aplica. Setas no menu sao o caminho seguro.
- teste: Widget test: adicionar Blur e Glow, mandar o Glow subir pela UI e conferir que camada.effects.map(type).toList() virou [glow, blur]; e que um undo devolve a ordem anterior.

### `! ` "+ Adicionar efeito" fica na PARTE SUPERIOR do painel inferior, acima da pilha.

- evidencia: V 01:23.0
- hoje: lib/src/features/editor/presentation/widgets/controles_da_camada.dart:592-598: o _Acao 'Adicionar efeito' e o ULTIMO filho da Column, depois do aviso e de todos os cartoes de efeito e suas fichas de parametro.
- divergencia: Posicao invertida. Com dois ou tres efeitos abertos (a ficha de parametros e longa) o + sai da dobra do painel de 300 px e so aparece rolando.
- mudanca: Mover o _Acao 'Adicionar efeito' para o topo da Column de _Efeitos (antes do `for (final e in camada.effects)`), mantendo o mesmo rotulo semantico.
- risco: Testes existentes que dependem de ordem (test/efeitos_e_curva_test.dart:105-112, test/painel_da_camada_test.dart:379) usam bySemanticsLabel e nao ordem, entao nao quebram; quebra so se algum teste comparar posicoes.
- teste: Widget test: adicionar dois efeitos e conferir que tester.getTopLeft do botao 'Adicionar efeito' tem dy menor que o do primeiro cartao de efeito.

### `! ` Tambem se copia o CONJUNTO de efeitos da camada (nao so um).

- evidencia: D3
- hoje: NAO EXISTE na UI. O motor tem o mais proximo disso: saveEffectPresetFrom(layerId, onlyEffectIds) em lib/src/features/editor/application/editor_controller.dart:941-960 e applyPreset(...) em :966-995, ambos com ZERO chamadores em lib (so em test/).
- divergencia: A capacidade existe no motor e nao tem porta na interface; o menu do painel nao oferece "copiar todos".
- mudanca: No menu inferior do painel de Efeitos, alem de Colar, expor Copiar todos os efeitos, ligando em saveEffectPresetFrom sem onlyEffectIds (ou guardando a lista crua na area de transferencia).
- risco: Colar um conjunto sobre uma pilha ja cheia pode duplicar efeitos caros (glow, blur) e estourar o orcamento de GPU; decidir explicitamente entre somar e substituir (applyPreset ja tem o parametro replace).
- teste: Widget test: camada com tres efeitos, Copiar todos, selecionar outra camada, Colar, e conferir que a segunda camada ficou com os tres types na mesma ordem.

### `! ` Existe uma entrada "Guide" no contexto do efeito.

- evidencia: D7 (Alight Motion, Effects Guide) — citada dentro do bloco N; layout nao capturado
- hoje: NAO EXISTE no contexto do efeito. A unica ajuda e uma tela geral, lib/src/features/help/presentation/quick_guide_screen.dart:157, alcancada por outro caminho, e o texto dela descreve controles que a tela de efeitos nao tem.
- divergencia: Falta o acesso a explicacao a partir do proprio efeito.
- mudanca: Quando o menu por efeito existir, acrescentar um item que leve a explicacao daquele efeito. Requer texto por efeito: hoje EffectSpec (effect.dart:249-300) tem name, category, params, hasColor, extraColors, e nenhum campo de descricao.
- risco: Sao 76 tipos de efeito; um campo de texto por efeito preenchido pela metade produz item que abre vazio — pior que item ausente (a mesma regra que _ParametrosDoEfeito ja aplica no aviso de parametro sem desenho).
- teste: Teste de tabela: para todo EffectType, se o item de guia estiver aceso, effectSpecs[t].guia nao pode ser vazio.

### `~ ` Pilha vazia: o painel inferior aparece VAZIO, sem texto de aviso ocupando a primeira linha.

- evidencia: V 01:23.0
- hoje: lib/src/features/editor/presentation/widgets/controles_da_camada.dart:576-577: `if (camada.effects.isEmpty) const _Aviso('Esta camada ainda nao tem efeito nenhum.')` como PRIMEIRO filho da Column; o _Aviso e definido em controles_da_camada.dart:1498.
- divergencia: O AM mostra o painel vazio com o + no topo; o Aurea abre com uma frase cinza e empurra o + para baixo dela.
- mudanca: Remover o _Aviso do estado vazio de _Efeitos (controles_da_camada.dart:576-577) e deixar o painel com o + no topo e nada abaixo.
- risco: Perder a unica explicacao textual do estado vazio; quem nunca usou pode achar que o painel nao carregou. Mitigacao: o + no topo passa a ser o unico elemento e vira a instrucao.
- teste: Widget test: camada sem efeito, abrir Efeitos, esperar findsNothing para 'Esta camada ainda nao tem efeito nenhum' e o botao 'Adicionar efeito' como primeiro filho da lista (ordem por getTopLeft).

### `ok` Entrar em Camada > Efeitos troca o cabecalho da tela para o titulo "Efeitos".

- evidencia: V 01:22,5
- hoje: lib/src/features/editor/presentation/editor_screen.dart:425 troca a barra por _CabecalhoDaFerramenta(tituloDaFerramenta(aberta)); lib/src/features/editor/presentation/widgets/painel_da_camada.dart:559 mapeia 'efeitos' => 'Efeitos'; o cartao que entra na categoria esta em painel_da_camada.dart:236-240.
- divergencia: NENHUMA

### `ok` Com Efeitos aberto, a faixa temporal da camada continua visivel na linha do tempo; o painel nao come a timeline.

- evidencia: V 01:22,5-01:26,5
- hoje: lib/src/features/editor/presentation/editor_screen.dart:241-260: a altura da ferramenta sai do preview, e o chao reservado (chaoComFerramenta) garante transporte + regua + UMA trilha; lib/src/features/editor/presentation/widgets/painel_da_camada.dart:551-556 documenta a mesma regra.
- divergencia: NENHUMA na regra. Ressalva: o chao garante apenas UMA trilha, entao numa composicao com muitas camadas a faixa da camada selecionada pode ficar fora da area visivel se o scroll da timeline nao a seguir.

### `ok` Adicionar, habilitar, editar e remover efeito alteram o projeto real.

- evidencia: P (pag. 21)
- hoje: Adicionar: controles_da_camada.dart:1018 -> addEffect (editor_controller.dart:5398). Habilitar: :584 -> toggleEffectEnabled (:5490), com o olho em :662-670. Editar: :767/:790/:806/:822 -> editEffectParam (:5504), mais cor em :845-863 -> setEffectColor (:5619) e setEffectExtraColor (:7489). Remover: :585-588 -> removeEffect (:5467). Keyframe por parametro do efeito: alvoDoParametroDeEfeito (:311-338) -> toggleEffectParamKeyframe (:5599).
- divergencia: NENHUMA

### `ok` O catalogo aberto pelo + NAO foi filmado: nao declarar paridade de biblioteca, busca, categorias, favoritos, cards, parametros e pilha nao vazia; nao reaproveitar o browser hibrido do PDF anterior.

- evidencia: N (pag. 21)
- hoje: EXISTE um catalogo proprio: _CatalogoDeEfeitos (controles_da_camada.dart:970-1060) — um _Acao de voltar no topo, depois grupos por `category` da tabela effectSpecs, com os nomes em chips (Wrap). As categorias sao as 10 strings da tabela e estao EM INGLES (Blur, Color, Distort, Generate, Glitch, Keying, Lens, Light, Stylize, Time — effect.dart), num app em portugues. Nao ha busca, nem favoritos, nem cards com previa.
- divergencia: Nao ha divergencia mensuravel contra o AM porque a tela nao foi observada. A exigencia e de PROCESSO: nao afirmar paridade e obter referencia AM antes de redesenhar.

### `ok` Preservar a biblioteca e a pilha reais do Aurea; mudar a interface nao autoriza apagar funcionalidade.

- evidencia: P (pag. 21) + diretriz vinculante (pag. 2)
- hoje: 76 tipos em effectSpecs (lib/src/features/editor/domain/effect.dart:9+), ficha de parametros gerada da tabela (_ParametrosDoEfeito, controles_da_camada.dart:718-870), keyframe por parametro de efeito, cor e cores extras, aviso do que ainda nao desenha (:860-866).
- divergencia: NENHUMA hoje; e uma restricao sobre a reconstrucao.

### Extensoes do Aurea nesta superficie

O PDF manda preservar e dar destino contextual — nunca apagar.

- Ficha de parametros GERADA da tabela effectSpecs (76 tipos, 10 categorias) em _ParametrosDoEfeito (controles_da_camada.dart:718-870): number, seed, toggle, choice e point viram fita + campo digitavel, sem deslizante. O AM nao mostra nada disso na gravacao. Destino: manter dentro do cartao do efeito aberto.
- Keyframe por PARAMETRO DE EFEITO ligado ao rail esquerdo: alvoDoParametroDeEfeito (controles_da_camada.dart:311-338) + toggleEffectParamKeyframe (editor_controller.dart:5599). Destino: manter; e o que faz o losango mirar o parametro escolhido dentro de Efeitos.
- Seletor de cor e cores extras por efeito (controles_da_camada.dart:845-866 -> setEffectColor:5619, setEffectExtraColor:7489). Destino: manter na ficha do efeito.
- Aviso explicito dos parametros que a ficha ainda nao desenha (controles_da_camada.dart:860-866). Destino: manter enquanto houver ParamKind sem controle.
- Catalogo agrupado por categoria com aplicacao imediata e abertura automatica da ficha do efeito recem-adicionado, com o primeiro parametro ja escolhido (controles_da_camada.dart:1013-1035). Destino: preservar o comportamento mesmo se o layout do catalogo for refeito quando houver referencia AM.
- Motor com capacidade SEM PORTA na UI, que o PDF manda preservar e a que e preciso dar destino contextual: reorderEffect (editor_controller.dart:5477), duplicateEffect (:5446), setEffectDepth com EffectDepth.pronto/montar/avancado (:5413), applyEffectPronto — presets prontos por efeito (:5428), bakeEffectToKeyframes (:996), saveEffectPresetFrom (:941) e applyPreset (:966). Todos com ZERO chamadores em lib hoje. Destino natural: o menu por efeito (duplicar, reordenar, assar) e o menu inferior do painel (copiar todos, salvar preset).
- EffectPresetStore (lib/src/features/editor/application/effect_preset_store.dart:20-107): presets de efeito da pessoa guardados FORA do projeto, em effect_presets.json, com add/remove/rename. Nenhum chamador de UI — so test/effect_preset_store_test.dart. E uma capacidade que o AM nao tem nesta superficie e que hoje esta orfa; destino: item 'Salvar como preset' no menu inferior do painel de Efeitos.

### Correcoes do conferente (2)

- **Abrir o menu inferior esquerdo mostra o item "Colar Efeito", visualmente apagado quando nao ha efeito copiado (V 01:22,5-01:26,5; D3 descreve tambem copiar o CONJUNTO de efeitos).**
  - afirmado: "Varredura em lib por colar/paste/clipboard cruzada com efeito nao retorna nada; nao ha area de transferencia de efeito no editor_controller.dart (so duplicateEffect:5446, que copia dentro da mesma camada)." e a divergencia "Nao ha item de colar, nem estado de 'nada copiado', nem area de transferencia de efeito."
  - verdade: A parte de UI esta certa (nao ha menu nem item Colar), mas a parte do MOTOR esta errada: a area de transferencia existe com outro nome — PRESET. C:/Users/SnyX/Documents/Projetos - Claude/Aurea/lib/src/features/editor/application/editor_controller.dart:941 `EffectPreset? saveEffectPresetFrom(String layerId, String name, {Set<String>? onlyEffectIds})` tira efeitos de uma camada, e :966 `List<String> applyPreset(String layerId, EffectPreset preset, {required Duration at, bool replace = false, Duration? stretchTo})` aplica em OUTRA camada (somando ou trocando a pilha). O nucleo esta em .../lib/src/features/editor/domain/effect_preset.dart (saveEffectPreset:61, applyEffectPreset:96, reconcilePreset:131), com keyframes gravados relativos e parametros de distancia normalizados pelo tamanho da camada. E ha ate um deposito persistente fora do projeto: .../lib/src/features/editor/application/effect_preset_store.dart:20 `EffectPresetStore` (add:81, JSON em effect_presets.json), coberto por test/effect_preset_store_test.dart e test/effects_catalog_test.dart:132-213. A varredura falhou porque procurou "colar/paste/clipboard"; no codigo a coisa se chama preset. O que falta e chamador de UI (zero em lib), nao a capacidade no motor — e isso muda o veredicto da linha: nao e "criar area de transferencia", e "dar porta a que ja existe".
- **Cada efeito tem, junto ao seu nome, um menu de onde se copia aquele efeito (D3 · Alight Motion · Copy and Paste Effects).**
  - afirmado: "Falta o menu por efeito e a acao Copiar. O motor tambem nao tem comando de copiar para fora da camada."
  - verdade: A primeira frase esta certa (_TituloDoEfeito em .../lib/src/features/editor/presentation/widgets/controles_da_camada.dart:605-690 so tem abrir/olho/lixeira). A segunda e falsa: o comando de copiar UM efeito para fora da camada existe. `saveEffectPresetFrom` (editor_controller.dart:941) recebe `onlyEffectIds` e filtra a pilha (:947-953), entao `saveEffectPresetFrom(camadaId, nome, onlyEffectIds: {efeitoId})` copia exatamente aquele efeito, com valores e keyframes; `applyPreset` (:966) cola na camada destino. Dizer que "o motor nao tem comando" inverte o diagnostico: o comando existe e esta testado, o que nao existe e o menu que o chame.

---

## Animacao: keyframes ligados a propriedade atual (PDF AM ONLY rev.02, PAGINA 22, secao 12)

O motor do Aurea ja tem quase tudo o que a PAGINA 22 cobra no plano dos dados: keyframe por camada+propriedade (toggleKeyframe por LayerProp), interpolacao lida no cabecote, timebase encaixado na grade de quadros, desfazer por instantaneo do projeto e curva so quando ha trecho entre duas marcas (exatamente a condicao do D2). O que diverge esta na LEITURA e no GESTO. (1) CONFLITO DE ESPECIFICACAO, nao bug: o video mostra "reposiciona o cabecote, muda a posicao, aparece a segunda chave"; o Aurea recusa isso por decisao escrita do dono em docs/keyframe-explicito.md, da mesma data do PDF — editar valor fora de marca vira edicao PENDENTE e so o losango crava. Isso tambem quebra o criterio "Feedback ... permanecem sincronizados", porque durante a pendencia previa e campos mostram um valor que a faixa nao tem. Nao mexi em nada: essa linha precisa de decisao do dono antes de qualquer codigo. (2) A faixa pinta TODOS os keyframes da camada (transformacao + efeito + mascara + modulo) como losangos brancos iguais — nao existe a distincao "solido = propriedade atual / esmaecido = outra" que o D2 exige. (3) O toque longo e o arrasto do losango na faixa chamam apagarKeyframeDeTransformacao/moverKeyframeDeTransformacao, que agem sobre TODAS as trilhas de transformacao daquele instante: apagar a marca de posicao apaga junto a de rotacao, escala, opacidade, skew e pivo — violacao direta do criterio "Identidade". (4) A trajetoria pontilhada da previa NAO EXISTE (a edicao no palco saiu com a UI antiga). (5) Nao ha comando "chave anterior / proxima chave": as setas que no AM ladeiam a pilula da camada, no Aurea trocam de CAMADA (provado por teste). (6) Com uma ferramenta aberta a linha do tempo continua no modo "geral" (padrao) e nao rola ate a selecionada, entao a faixa visivel pode nao ser a da camada em edicao. Nada foi editado; tudo abaixo saiu de leitura de codigo.

### `!!` Os diamantes da PROPRIEDADE ATUAL sao solidos; os que pertencem a outra propriedade aparecem esmaecidos.

- evidencia: D2 · Alight Motion · Animation Easing Curves, citado na PAGINA 22 ("Diamantes solidos identificam a propriedade atual; os esmaecidos pertencem a outra")
- hoje: lib/src/features/editor/presentation/widgets/linha_do_tempo.dart:1389-1422 (_pintarKeyframes) percorre l.keyframeTimes e pinta TUDO com a mesma tinta branca; a lista vem de lib/src/features/editor/domain/layer.dart:208-221, que e a UNIAO de posicao, escala, rotacao, opacidade, skew, pivo, efeitos, mascaras e modulos. O mesmo em visao_geral_das_camadas.dart:891-912.
- divergencia: Nao existe nenhuma distincao entre a marca da propriedade que o rail esta editando e a marca de outra propriedade (nem de outro dominio: efeito e mascara viram o mesmo losango branco). Quem esta em Rotacao ve os diamantes de Posicao com o mesmo peso e nao sabe quais o losango do rail vai mexer.
- mudanca: Passar a propriedade em foco ate a faixa (o painel ja sabe qual e: propDoModo em controles_da_camada.dart:154-159, e parametroAbertoProvider/efeitoAbertoProvider para as outras familias) e, em _pintarKeyframes, pintar as marcas dessa propriedade com alfa cheio e as demais com alfa reduzido. Sem ferramenta aberta nao ha propriedade em foco: tudo volta a solido.
- risco: Com a ferramenta fechada ou numa categoria sem propriedade (camada, midia, velocidade) o foco e nulo e a faixa nao pode ficar inteira esmaecida; em pilha densa o esmaecido pode sumir contra o fundo da barra.
- teste: Teste de widget sobre o pintor: camada com keyframe de posicao em 0,5 s e de rotacao em 1,0 s; com Transformacao > Mover aberto, contar duas tintas distintas e conferir que a do instante 1,0 s e a de alfa reduzido; ao trocar para Girar, as tintas se invertem.

### `!!` Identidade: cada chave pertence a uma camada e a uma propriedade — animacao de posicao nao vira animacao de rotacao.

- evidencia: P · contrato da PAGINA 22, criterio "Identidade"
- hoje: CRIACAO esta certa: editor_controller.dart:5247-5300 (toggleKeyframe) recebe LayerProp e so mexe nas trilhas daquela propriedade. REMOCAO E MOVIMENTO pela faixa NAO: editor_controller.dart:5149-5183 (moverKeyframeDeTransformacao) e :5186-5208 (apagarKeyframeDeTransformacao) aplicam a TODAS as trilhas de transformacao do instante — position, positionZ, scaleX/Y, rotation/X/Y, opacity, skewX/Y e pivot. Sao esses os metodos ligados ao arrasto e ao toque longo do losango: linha_do_tempo.dart:299-304 e :1168-1176.
- divergencia: Apagar (toque longo) ou arrastar o diamante de Posicao na faixa apaga/move junto as marcas de rotacao, escala, opacidade, skew e pivo que caem no mesmo instante. Uma chave deixa de pertencer a uma propriedade no exato gesto em que a pessoa a manipula.
- mudanca: Dar propriedade ao gesto: a faixa ja pode receber a propriedade em foco (mesma ligacao da linha 2 desta matriz) e chamar variantes por propriedade de apagar/mover. Quando nao ha foco (ferramenta fechada), ou o gesto age so no que o losango representa e pede escolha, ou fica desabilitado — nunca apaga em bloco em silencio.
- risco: Quem hoje usa o toque longo como "limpar este instante" perde esse atalho; com marcas de propriedades diferentes a poucos pixels, dois losangos passam a disputar o mesmo pixel e _keyframeSobODedo (linha_do_tempo.dart:1049-1071) precisa desempatar.
- teste: Camada com keyframe de posicao E de rotacao em 1,0 s; com Transformacao > Mover aberto, toque longo no diamante de 1,0 s: layer.rotation.hasKeyframeAt(1s) continua verdadeiro e layer.position.hasKeyframeAt(1s) passa a falso. Repetir com Girar aberto e conferir o inverso.

### `!!` Com a propriedade ja animada, reposicionar o cabecote e definir outro valor resulta na segunda chave da propriedade (dois diamantes na faixa).

- evidencia: V 01:31.0 ("Dois keyframes e posicao alterada"; texto: "O playhead e reposicionado, outra posicao e definida"). O gesto exato nao esta filmado — o quadro 01:31.0 mostra o rail ja com o losango de '-', que tanto pode vir de um toque no losango quanto de auto-keyframe. N para o gesto.
- hoje: lib/src/features/editor/domain/keyframe.dart:645 e :653 (edited/aceitaEdicaoEm) devolvem a trilha INTACTA quando a propriedade anima e o cabecote esta fora de marca; editor_controller.dart:275-291 (_mutate) desvia o resultado derivado para edicaoPendenteProvider em vez de gravar. Regra escrita em docs/keyframe-explicito.md ("Nenhuma edicao de valor cria keyframe", decisao do dono do produto de 2026-09-10).
- divergencia: No AM o resultado observado e a chave; no Aurea o mesmo caminho exige um toque a mais no losango, e ate la nada aparece na faixa. E um CONFLITO entre a referencia (regra da PAGINA 2: video > codigo legado) e uma extensao Aurea explicitamente aprovada da MESMA data — nao e um defeito a corrigir por conta propria.
- mudanca: NENHUMA sem decisao do dono. Levar o conflito a ele com as duas frases lado a lado. Se a decisao for seguir o AM, o ponto unico e aceitaEdicaoEm em domain/keyframe.dart:653 e domain/mask.dart (e a recusa em _mutate): nao ha caminho paralelo, os 36 pontos de edicao passam todos por 'editada'. Se a decisao for manter o Aurea, registrar a divergencia como extensao aprovada no proprio PDF em vez de fingir paridade.
- risco: Reabrir o auto-keyframe traz de volta exatamente o defeito que a decisao removeu: arrastar uma fita por um segundo deixava uma duzia de marcas nao pedidas, e EffectInstance.withParamEdited cravava TODOS os parametros de uma vez. O caso da ancora (dois keyframes, um deles no zero, num tempo nunca visitado) tambem volta.
- teste: test/keyframe_explicito_test.dart hoje PROVA o comportamento oposto (linhas 46, 93: 'mover sem tocar no losango nao cria keyframe nenhum', 'animada, FORA da marca, editar nao mexe na trilha'). Qualquer mudanca aqui exige reescrever esse arquivo inteiro — o que e, por si, a medida do tamanho da decisao.

### `!!` Feedback: controle lateral, diamantes na faixa, valores e trajetoria no preview permanecem SINCRONIZADOS.

- evidencia: P · contrato da PAGINA 22, criterio "Feedback"
- hoje: Dessincronia deliberada durante a edicao pendente: rails_do_painel.dart:8-16 (camadaReal) faz o rail ler o projeto REAL enquanto os campos e a previa leem projetoVisivelProvider = pendente ?? real (editor_controller.dart; docs/keyframe-explicito.md). Nao ha nenhum indicador na tela de que existe pendencia — nem na faixa, nem no campo, nem no rail.
- divergencia: Enquanto a pendencia esta aberta, campo e previa mostram um valor que a faixa nao registra e o rail nega, e nada na interface conta isso. O criterio do AM exige que as quatro superficies contem a mesma historia.
- mudanca: Se a linha anterior ficar como esta (Aurea mantido), a pendencia precisa de sinal proprio: um losango fantasma no instante do cabecote na faixa e/ou o numero do campo em estado 'nao gravado', mais semantica declarada. Se a decisao for AM, a pendencia deixa de existir e esta linha morre junto.
- risco: Um losango fantasma na faixa pode ser lido como marca de verdade — tem de ser visualmente inconfundivel (vazado/tracejado) ou o remedio piora a mentira.
- teste: Widget test: com a propriedade animada e o cabecote fora de marca, editar o valor; conferir que a faixa NAO ganha keyframe real (l.keyframeTimes inalterado) e que existe exatamente um no com semantica de pendencia; tocar no losango faz o no sumir e a marca nascer.

### `!!` A faixa da camada em edicao, com os diamantes dela, continua visivel ao lado/acima do painel da propriedade.

- evidencia: V 01:28.5 e V 01:31.0 (a pilula 'Retangulo arredo...' com os diamantes fica logo acima do painel de transformacao, com o cabecote atravessando as duas)
- hoje: editor_screen.dart:244-250 reserva o 'chao com ferramenta' = transporte + regua + UMA trilha, e :352 monta LinhaDoTempo com essa altura — o espaco existe. Mas O CONTEUDO depende do modo: linha_do_tempo.dart:126 e :265-268 escolhem entre VisaoGeralDasCamadas (todas as camadas) e _Faixa (a selecionada), e o modo padrao e 'geral' (visao_geral_das_camadas.dart:37-39). Nada troca o modo ao abrir uma ferramenta: o unico ponto que escreve o provider e o AlternadorDeVista (visao_geral_das_camadas.dart:57-70), e a pilha nao rola ate a selecionada (visao_geral_das_camadas.dart:321-329 nao tem ScrollController posicionado).
- divergencia: Com mais de uma camada e a linha do tempo no padrao 'geral', abrir Transformacao mostra ~30 px de pilha que podem nao conter a camada em edicao. O AM garante que a faixa visivel e SEMPRE a da camada selecionada.
- mudanca: Abrir uma ferramenta de camada passa modoDaLinhaDoTempoProvider para 'detalhado' (e devolve ao anterior ao fechar), ou, se a pilha tiver de ficar, rola-la ate a trilha da selecionada. A primeira e a que corresponde a referencia.
- risco: Quem hoje usa a pilha para pular de camada com a ferramenta aberta perde o caminho; o AlternadorDeVista passa a brigar com a troca automatica se a pessoa mudar de vista de proposito.
- teste: Widget test: projeto com 5 camadas, selecionar a ultima, abrir Transformacao; o widget desenhado sob o painel e _Faixa e a camada que ele pinta e a selecionada (conferir pelo nome desenhado ou pela semantica da faixa).

### `! ` A curva aberta e a do intervalo selecionado da propriedade atual — nao uma curva solta nem herdada de outro contexto.

- evidencia: P · PAGINA 23 ("abrir a curva do intervalo selecionado"), aplicavel a mesma maquina de keyframes da PAGINA 22. Curva de parametro de EFEITO no AM: N (a PAGINA 21 registra que a pilha de efeitos nunca foi aberta).
- hoje: Em transformacao e opacidade esta certo: controles_da_camada.dart:288-300 monta aoAplicar como c.setSegmentEase(camada.id, prop, comeca, e) — trecho, propriedade e camada explicitos (editor_controller.dart:5304-5350). Nos demais dominios o botao NAO EXISTE: aoAbrirCurva: null em controles_da_camada.dart:335 (parametro de efeito), :369 (parametro de forma), painel_de_mascaras.dart:45+ e painel_de_cor.dart:55+, com o comentario de que o motor so tem ease por keyframe, nao por segmento.
- divergencia: O mesmo rail promete a curva em Transformacao/Opacidade e a nega para todo parametro de efeito, forma, mascara e cor que anima. Nao ha referencia AM filmada para esses casos, entao isto e lacuna de capacidade do Aurea contra o proprio contrato do rail, nao paridade comprovada.
- mudanca: Dar ease por trecho as trilhas de parametro (withEase por segmento em domain/effect.dart e domain/shape.dart) e ligar aoAbrirCurva nesses quatro alvos. Antes disso, buscar referencia AM da curva de parametro de efeito, como a PAGINA 21 manda.
- risco: O motor de efeito hoje guarda interpolacao por keyframe; mudar para por-segmento sem migracao pode reinterpretar projetos salvos. Precisa de leitura tolerante do projeto (regra de QA 1.0).
- teste: Estender test/efeitos_e_curva_test.dart: parametro de efeito com duas chaves, cabecote no meio, aplicar Acelerar; o valor amostrado no meio do trecho sai diferente do linear e o desfazer devolve a curva anterior.

### `! ` Navegar entre as chaves da propriedade atual (ir para a chave anterior / proxima).

- evidencia: P · PAGINA 22, criterio "Tempo e valores" ("...selecionar, navegar e alterar valores..."). As setas ‹ › que ladeiam a pilula da camada aparecem em V 01:28.5 e V 01:31.0, mas NAO sao acionadas na gravacao — N para o que elas fazem no AM.
- hoje: NAO EXISTE comando de chave anterior/proxima. As setas ‹ › do Aurea, que ocupam a mesma posicao da pilula (linha_do_tempo.dart:843 e :869), TROCAM DE CAMADA: aoTrocar -> _vizinha em linha_do_tempo.dart:306-313 e :320-329, provado por test/linha_do_tempo_test.dart:132 ('a seta troca a camada selecionada, e some na ponta'). O que existe de navegacao por chave e o toque no proprio diamante da faixa, que leva o cabecote ate ele (linha_do_tempo.dart:1145-1152; test/linha_do_tempo_test.dart:308), e o passo de quadro.
- divergencia: Falta o comando de navegacao por chave. E NAO se pode declarar equivalencia com as setas atuais: no AM elas nao foram acionadas (N), e no Aurea elas fazem outra coisa comprovada por teste.
- mudanca: Acrescentar 'chave anterior' e 'proxima chave' sobre propKeyframeTimes (editor_controller.dart:5103-5115) chamando playback.seek(camada.startTime + t). Colocar no rail esquerdo ou junto do losango. NAO reaproveitar as setas da pilula ate haver referencia AM do que elas fazem la.
- risco: Se um dia a referencia mandar por na pilula, a troca de camada perde o unico controle que tem e o teste linha_do_tempo_test.dart:132 cai junto.
- teste: Camada com chaves de posicao em 0,5 s e 1,5 s, cabecote em 0,9 s: 'proxima chave' leva o cabecote a exatamente 1,5 s (encaixado na grade de quadros) e 'anterior' a 0,5 s; nas pontas o comando fica desabilitado.

### `! ` A previa exibe a trajetoria pontilhada da propriedade animada, e ela acompanha os keyframes.

- evidencia: V 01:27,5-01:32,5 ("o preview exibe uma trajetoria pontilhada"); reforcado pelo criterio "Feedback" da mesma pagina
- hoje: NAO EXISTE. O cabecalho de lib/src/features/editor/presentation/widgets/palco_de_previa.dart:1-10 registra que a edicao no palco (alcas, guias, grade, casca de cebola) saiu com a UI antiga e que o arquivo ficou so com o desenho da composicao. Nao ha nenhum pintor de caminho de movimento: os unicos overlays de editor sao NullGizmoPainter (particles_painter.dart:511) e o gizmo de selecao (palco_de_previa.dart:4176-4186). Busca por trajetoria/motion path/pontilhado em lib/src nao retorna nada do genero (so tracejado de grade no editor_de_curva.dart:477 e do traco da forma em domain/shape.dart:804-818).
- divergencia: Nao ha trajetoria nenhuma na previa. Quem anima posicao ve o objeto pular entre instantes sem enxergar o caminho.
- mudanca: Overlay proprio sobre o palco (nao dentro do CompositionView, que e o mesmo codigo da exportacao): amostrar camada.position.valueAt entre a primeira e a ultima chave, converter pela mesma escala visual do preview e pintar pontilhado, com um ponto solido em cada keyframe. So com camada selecionada, propriedade de posicao animada e ferramenta aberta.
- risco: Custo de quadro — pelo medido no iPhone 13 o ambiente da cena 3D ja e 92% do quadro, entao a amostragem precisa de teto de pontos e cache por revisao do projeto. E, sobretudo, NAO pode entrar na composicao: se cair dentro do CompositionView, sai no video exportado, que e o defeito ja registrado no gizmo do nulo (palco_de_previa.dart:4179).
- teste: Print da UI por teste (RepaintBoundary com GlobalKey e fontes do cache do SDK): camada com posicao animada em duas chaves; o overlay pinta pontos entre elas e some quando a camada e desmarcada. Mais um teste de exportacao provando que o quadro renderizado nao contem a trajetoria.

### `! ` Historico: desfazer/refazer recupera chaves, valores e curva; voltar de painel nao cria nem apaga chave.

- evidencia: P · contrato da PAGINA 22, criterio "Historico"
- hoje: Desfazer e por instantaneo do projeto inteiro (editor_controller.dart:416-427), entao chave, valor e curva voltam juntos. Voltar de painel so descarta a pendencia (editor_controller.dart:5242-5245, descartarPendencia), que nunca passou pelo _mutate — nao cria nem apaga marca. POReM: toggleKeyframe -> _replace (:477-486) -> _mutate, e _mutate so empilha um passo de desfazer quando a mudanca e estrutural ou passaram 450 ms da anterior (:319-325). So o caminho da pendencia forca passo proprio (:5227-5233, runAsOneUndo).
- divergencia: Marcar ou tirar uma marca com o losango dentro de 450 ms de outra edicao real e ENGOLIDO pelo mesmo passo de desfazer: um toque em desfazer some com a marca E desfaz a edicao anterior. O criterio do AM pede que desfazer recupere as chaves, e aqui ele recupera chave e mais alguma coisa que a pessoa nao pediu para desfazer.
- mudanca: Tratar toggleKeyframe (e os toggles de efeito, forma, mascara e cor) como acao deliberada no empilhamento — envolver em runAsOneUndo, como _cravarPendencia ja faz, ou marcar a mutacao para forcar o push independentemente da janela de 450 ms.
- risco: Passos de desfazer a mais quando alguem alterna o losango repetidamente; a janela de 450 ms existe para nao transformar um arrasto em dezenas de passos e nao pode ser afrouxada em geral.
- teste: Editar a opacidade, e dentro de 450 ms tocar no losango; um unico desfazer tem de remover SO a marca, deixando o valor editado de pe; o segundo desfazer devolve o valor anterior.

### `~ ` O controle de keyframe do rail esquerdo muda de aspecto conforme o cabecote esteja ou nao sobre uma marca da propriedade atual.

- evidencia: V 01:28.5 e V 01:31.0 (nos dois quadros o rail mostra losango CHEIO com um sinal de MENOS dentro, porque o cabecote esta sobre a marca); faixa V 01:27,5-01:32,5
- hoje: lib/src/features/editor/presentation/widgets/rails_do_painel.dart:79-93 troca icone e cor conforme alvo.temKeyframeAqui/alvo.animado (aceso/meioAceso/apagado em _BotaoDoRail:183-216); o estado vem de alvoDaPropriedade em controles_da_camada.dart:225-300
- divergencia: O estado muda, mas o glifo esta errado: Icons.change_history_rounded/outlined e um TRIANGULO, nao o losango do AM — e nao ha o sinal +/- dentro dele dizendo o que o toque vai fazer. O proprio comentario do arquivo (rails_do_painel.dart:80) diz "O LOSANGO E O SIMBOLO DE KEYFRAME" e o codigo desenha um triangulo.
- mudanca: Trocar o Icon por um CustomPaint (ou icone proprio) de losango em rails_do_painel.dart:79-93: contorno + sinal '+' quando temKeyframeAqui e falso e animado e verdadeiro, preenchido + sinal '-' quando temKeyframeAqui, contorno apagado quando nao anima. O rotulo de acessibilidade ja diz a acao certa e nao muda.
- risco: Testes de widget que localizam o botao por IconData (find.byIcon(Icons.change_history_rounded)) param de achar; o alvo de toque de 46 px do rail nao pode encolher junto.
- teste: Widget test novo em test/keyframe_explicito_test.dart: abrir Transformacao numa camada com marca em 1 s; com o cabecote em 1 s o rail expoe semantica 'Tirar o keyframe daqui' e pinta o losango cheio com traco; com o cabecote em 1,2 s expoe 'Marcar keyframe aqui' e pinta o vazado com cruz.

### `~ ` O diamante que esta sob o cabecote se destaca dos demais na faixa da camada.

- evidencia: V 01:28.5 e V 01:31.0 (o losango no cabecote e BRANCO por dentro com contorno VERDE; os demais sao brancos sem contorno)
- hoje: lib/src/features/editor/presentation/widgets/linha_do_tempo.dart:1392-1421: 'losango' = branco, 'sob' = AmColors.accent, 'contorno' = branco 1,6 px; o do cabecote e desenhado PREENCHIDO de accent e depois contornado de branco (linha 1420-1421).
- divergencia: As duas tintas estao trocadas em relacao ao AM: la o preenchimento continua branco e o CONTORNO e que fica verde. Diferenca so de tinta, mesma geometria.
- mudanca: Em linha_do_tempo.dart:1420-1421, pintar sempre com 'losango' (branco) e, quando 'atual', desenhar o contorno com AmColors.accent em vez de branco.
- risco: Nenhum funcional; a tolerancia de 6 px que decide 'atual' (linha 1399) fica como esta.
- teste: O mesmo teste do pintor da linha anterior, conferindo que a marca no cabecote sai com preenchimento claro e traco de acento.

### `ok` Editar a gradacao exige pelo menos duas chaves da propriedade atual, com o cabecote dentro do intervalo.

- evidencia: D2 · Alight Motion · Animation Easing Curves, citado na PAGINA 22
- hoje: lib/src/features/editor/presentation/widgets/controles_da_camada.dart:260-268: percorre propKeyframeTimes e so considera 'temTrecho' quando ha marca antes (t <= local) E marca depois (t > local); :288-300 deixa aoAbrirCurva NULO fora disso, e rails_do_painel.dart:94-99 + :201-205 desenham o botao quase invisivel quando o callback e nulo.
- divergencia: NENHUMA

### `ok` Adicionar, remover, selecionar, navegar e alterar valores preservam o timebase e a precisao do projeto.

- evidencia: P · contrato da PAGINA 22, criterio "Tempo e valores"
- hoje: lib/src/features/editor/application/playback_controller.dart:150-176 (_naGrade/_instanteDoQuadro/seek) encaixa todo seek no indice do quadro, com o cuidado explicito de a ida e a volta fecharem; :137-145 (stepFrame) anda por indice de quadro. O keyframe e cravado em tempo LOCAL da camada (editor_controller.dart:5251, layer.localTime) em microssegundos, e hasKeyframeAt usa a tolerancia da propria trilha, a mesma que o rail consulta (controles_da_camada.dart:236-258).
- divergencia: NENHUMA

### Extensoes do Aurea nesta superficie

O PDF manda preservar e dar destino contextual — nunca apagar.

- Edicao PENDENTE: com a propriedade animada e o cabecote fora de marca, o valor novo aparece na previa sem entrar no projeto, e o losango crava (docs/keyframe-explicito.md; edicaoPendenteProvider e _cravarPendencia em editor_controller.dart:5219-5234). O AM nao tem esse estado. Destino: se o dono mantiver a regra, ela precisa de sinal na tela (linha 6 da matriz); se nao, ela e removida por decisao, nunca por engano.
- Regra dura 'nenhuma edicao de valor cria keyframe' aplicada aos 36 pontos de edicao do controlador, inclusive efeitos, mascaras, cor e forma (domain/keyframe.dart:645-653, domain/mask.dart). E a extensao Aurea mais forte desta superficie e a que conflita com o video.
- Arrastar um losango na faixa para mudar SO o tempo, e toque longo para apagar (linha_do_tempo.dart:1090-1176). O AM nao demonstra gesto nenhum sobre o diamante. Preservar; falta so dar propriedade ao gesto (linha 4 da matriz).
- Trava de seguranca podeArrastarKeyframeEm (domain/layer.dart:181-187): um instante que carrega marca de efeito, mascara ou modulo nao se arrasta nem se apaga pela faixa. Preservar.
- Tocar num losango leva o cabecote exatamente ate ele (linha_do_tempo.dart:1145-1152) — navegacao por chave que o AM nao mostra.
- Passo de quadro (playback_controller.dart:137-145) e encaixe de todo seek na grade de quadros pelo indice (:150-176), com o cuidado de ida e volta fecharem. Nada equivalente observado no AM. Preservar.
- Keyframe de rotacao GLOBAL aos tres eixos e keyframe de posicao incluindo Z quando a camada e 3D (editor_controller.dart:5260-5292). Extensao 3D do Aurea; o rail ja pergunta as tres trilhas antes de decidir o aspecto do losango (controles_da_camada.dart:245-258).
- applyEaseToAllSegments — aplicar a curva escolhida a TODOS os trechos da propriedade de uma vez, oferecido so quando ha mais de dois keyframes (controles_da_camada.dart:297-299). O AM nao mostra isso.
- O mesmo rail de keyframe servindo cinco dominios (transformacao, opacidade, parametro de efeito, parametro de forma, mascara e cor), com um alvo por dominio (alvoDaPropriedade, alvoDoParametroDeEfeito, alvoDoParametroDaForma, alvoDoParametroDaMascara, alvoDaCorDaForma). Preservar a abstracao; o que falta e a curva nos quatro ultimos.
- Keyframes GERADOS por acao nomeada — catalogo de animacao de texto, 'Criar a cena do rastreio', rig de camera — que continuam editaveis um a um (docs/keyframe-explicito.md, secao 'Keyframes GERADOS'). Nao ha nada assim no material AM.
- Marcadores na regua, cravados por toque longo, com cor propria (linha_do_tempo.dart:507-521, 686-700). Coisa da regua, nao do keyframe, mas divide a mesma superficie e nao pode ser apagada ao refazer a faixa.

### Correcoes do conferente (1)

- **Com a propriedade ja animada, reposicionar o cabecote e definir outro valor resulta na segunda chave da propriedade (dois diamantes na faixa).**
  - afirmado: A matriz trata isso como comportamento OBSERVADO do AM e declara divergencia: 'No AM o resultado observado e a chave; no Aurea o mesmo caminho exige um toque a mais no losango'. Em seguida classifica o item como CONFLITO entre a referencia (regra da PAGINA 2: video > codigo legado) e a extensao Aurea aprovada de 2026-09-10.
  - verdade: A leitura do codigo esta certa (keyframe.dart:643-653 devolve a trilha intacta; editor_controller.dart:275-291 desvia para edicaoPendenteProvider; docs/keyframe-explicito.md e a decisao do dono, 2026-09-10 — tudo conferido). O erro esta no lado AM: o video NAO comprova que a segunda chave nasceu da edicao de valor. O texto V da PAGINA 22 diz apenas 'o controle de keyframe a esquerda muda de aspecto; diamantes aparecem na faixa da camada. O playhead e reposicionado, outra posicao e definida' — o resultado (dois diamantes em 01:31) e observavel, o gesto que o produziu nao. A PAGINA 12 marca isso como N explicitamente: 'o video nao mostra os dedos... a associacao exata de cada toque a cada icone deve ser validada no AM antes de fechar os testes de comandos'. Um segundo toque no losango entre 01:28,5 e 01:31 e inteiramente compativel com todos os quadros descritos — e a PAGINA 16 lista 'controle de keyframe' no rail esquerdo justamente com 'estado dos simbolos depende da propriedade/tempo'. Logo nao ha evidencia de que o AM cria a chave sozinho, e por consequencia nao ha CONFLITO com a extensao aprovada: a regra de precedencia da PAGINA 2 so entra em cena quando o video de fato mostra o comportamento. Declarar divergencia (ainda que rotulada de conflito) sobre material N contraria a PAGINA 3, que manda 'buscar referencia AM correspondente antes de declarar paridade completa' e nao atribuir ao AM como fato observado o que nao foi filmado. O status correto deste item e 'nao observado — obter referencia AM adicional sobre a criacao da segunda chave', nao divergencia.

---

## Aparencia: Homogeneizacao e opacidade (blend + opacidade) — PAGINA 15 do PDF AM ONLY rev.02

A superficie do AM e UMA familia — slider de opacidade fixo no topo, lista rolavel de sete categorias em accordion, categoria aberta expandindo miniaturas com previa, rail de retorno e animacao a esquerda. O Aurea hoje parte isso em DOIS cartoes que nunca se veem ('Opacidade', em controles_da_camada.dart:374-402, e 'Mistura e recorte', em painel_de_mistura.dart:118-187), sem accordion (as seis familias vem sempre abertas como chips de texto), sem miniatura de previa, sem estado de expansao e com os controles de animacao do rail apagados no painel de blend (controles_da_camada.dart:152 devolve AlvoDoRail vazio). O que ja corresponde: a ordem das familias (Normal, Escurecer, Clarear, Contraste, [Comparar], Cor), o conteudo exato de Diferenca (Diferenca, Exclusao, Subtrair, Dividir, painel_de_mistura.dart:79-87), a aplicacao por id na camada certa com desfazer (editor_controller.dart:5046-5063), a composicao na ordem da pilha (palco_de_previa.dart:443-500) e a invariante de que trocar de painel nao altera dados. Divergencias estruturais: 4 (familia partida, opacidade ausente do painel, ausencia de accordion, rail sem alvo). Nenhum teste cobre PainelDeMistura hoje (nenhuma referencia em test/).

### `!!` Uma unica familia de edicao, "Homogeneizacao e opacidade", entrando por UM tile da grade contextual e contendo opacidade e blend juntos.

- evidencia: V 00:53.5 (painel unico com slider + lista) e V 00:40.0 (grade da forma, linha 1: Cor e preenchimento; Borda e sombra; Homogeneizacao e opacidade — PAGINA 11)
- hoje: Sao DOIS tiles separados: lib/src/features/editor/presentation/widgets/painel_da_camada.dart:135-139 (id 'opacidade', rotulo 'Opacidade') e painel_da_camada.dart:256-259 (id 'mistura', rotulo 'Mistura e recorte'). Cada um abre um painel proprio: controles_da_camada.dart:106 ('opacidade' => _Opacidade) e controles_da_camada.dart:119 ('mistura' => PainelDeMistura).
- divergencia: O AM tem uma familia; o Aurea tem duas portas na grade e dois paineis que nunca se veem. Para mudar opacidade e blend do mesmo objeto e preciso voltar a grade e entrar noutro cartao.
- mudanca: Fundir num unico id de categoria (ex.: 'aparencia') com rotulo 'Homogeneizacao e opacidade'; o painel novo monta o bloco de opacidade no topo e a lista de categorias de blend abaixo. Remover o tile 'opacidade' e o tile 'mistura' da lista de categoriasDaCamada, mantendo o corpo do PainelDeMistura como sub-arvore do painel novo.
- risco: Camada de audio hoje recebe 'opacidade' mas nao 'mistura' (painel_da_camada.dart:256 tem `if (camada is! AudioLayer)`); fundir sem cuidado ou remove a opacidade do audio ou passa a oferecer blend para audio. Tambem quebra qualquer teste/rota que abra a categoria por id 'opacidade'/'mistura'.
- teste: Teste de widget: selecionar uma ShapeLayer, abrir a grade, esperar exatamente UM finder com 'Homogeneizacao e opacidade' e NENHUM com 'Opacidade' ou 'Mistura e recorte' como tile; tocar nele e encontrar, no mesmo painel, o controle de opacidade e a linha 'Escurecer'.

### `!!` Controle de opacidade no topo do painel, acima da lista de categorias.

- evidencia: V 00:53.5 e V 00:56.0 (o slider aparece na mesma posicao nos dois quadros, com a lista rolada)
- hoje: PainelDeMistura nao tem opacidade nenhuma: painel_de_mistura.dart:130-185 comeca direto nas familias de mistura. A opacidade vive em outro painel, em controles_da_camada.dart:374-402 (_Opacidade, uma unica LinhaDeParametro).
- divergencia: NAO EXISTE opacidade nesta superficie do Aurea.
- mudanca: Mover o corpo de _Opacidade (controles_da_camada.dart:374-402) para o topo do painel fundido, como primeiro filho fixo da Column, antes da lista de categorias.
- risco: A opacidade e lida no cabecote (`camada.localTime(tempo)`); se o widget subir para fora do ValueListenableBuilder do relogio (controles_da_camada.dart:74-76) o numero congela e passa a mentir em propriedade animada.
- teste: Teste de widget: abrir a familia, verificar que o controle de opacidade aparece ANTES (dy menor) da primeira linha de categoria; mover o cabecote numa opacidade com keyframes e conferir que a leitura muda.

### `!!` As categorias de blend sao um accordion: cada categoria e uma linha com triangulo, e abrir uma expande as opcoes no proprio lugar.

- evidencia: V 00:53.5 (triangulos fechados) e V 00:56.0 (Diferenca aberta, com triangulo para baixo, entre Contraste e Cor)
- hoje: Todas as familias vem SEMPRE expandidas, como titulo + Wrap de chips: painel_de_mistura.dart:133-157 (loop sobre familiasDeMistura) com _Titulo (painel_de_mistura.dart:243-260) que nao e tocavel.
- divergencia: Nao ha accordion nem estado de aberto/fechado: a lista inteira (27 modos) fica escancarada num painel de 300 px.
- mudanca: Trocar o loop por linhas de categoria com disclosure (triangulo), guardando qual esta aberta em estado local do painel; so a categoria aberta constroi as opcoes.
- risco: Esconder modos atras de accordions aumenta o numero de toques para trocar de modo e pode fazer o modo VIGENTE ficar invisivel — a linha da categoria precisa mostrar o modo ativo dela quando fechada. Construir as opcoes so quando abertas altera o que os testes de widget encontram na arvore.
- teste: Teste de widget: com o painel recem-aberto, `find.text('Multiplicar')` nao encontra nada; tocar em 'Escurecer' e encontrar 'Multiplicar'; tocar de novo e ele sumir.

### `!!` Rail lateral esquerdo com seta de retorno e controles de animacao.

- evidencia: V 00:53.5 e V 00:56.0 (coluna estreita a esquerda: '<', losango e um terceiro icone)
- hoje: RailEsquerdo existe e tem exatamente voltar / keyframe / curva: rails_do_painel.dart:57-102. Mas para a categoria 'mistura' o alvo e vazio — controles_da_camada.dart:129-153 devolve `const AlvoDoRail()` para tudo que nao for opacidade/efeitos/forma/mascara/cor, entao losango e curva ficam apagados no painel de blend.
- divergencia: Na familia unificada do AM os controles de animacao estao ativos (a propriedade animavel da familia e a opacidade). No Aurea, ao abrir 'mistura' eles morrem; so o painel 'opacidade' (controles_da_camada.dart:130-139) os acende.
- mudanca: No painel fundido, apontar o rail para LayerProp.opacity via `alvoDaPropriedade(...)`, como ja se faz em controles_da_camada.dart:130-139, independentemente de qual categoria de blend esteja aberta.
- risco: O rail le o projeto REAL e nao o visivel (rails_do_painel.dart:8-16); apontar para a camada errada faz o losango dizer que ha marca onde nao ha e o toque apagar keyframe inexistente.
- teste: Teste de widget: abrir a familia, tocar no losango, conferir keyframe de opacidade no instante do cabecote; tocar de novo e ele sumir; e o botao de curva acende quando ha duas marcas.

### `! ` O bloco de opacidade permanece visivel acima da lista durante a navegacao local (so a lista rola verticalmente).

- evidencia: V 00:53.5 x V 00:56.0 (o topo e identico nos dois; o que muda e a lista, ja rolada ate Contraste/Diferenca)
- hoje: O miolo inteiro de qualquer categoria vai dentro de um unico SingleChildScrollView: controles_da_camada.dart:186-193 (_ComRail). Nada e fixo.
- divergencia: Depois da fusao, a opacidade rolaria para fora da tela junto com a lista — o oposto do observado.
- mudanca: No painel fundido, tirar o topo do scroll: Column [ bloco de opacidade fixo, Expanded(SingleChildScrollView(lista de categorias)) ], em vez de rolar tudo.
- risco: O painel tem teto de 300 px (painel_da_camada.dart:305, PainelDaCamada.alturaMaxima); um topo fixo de ~48 px mais o rail deixa pouco para as miniaturas do accordion aberto e pode nao caber uma miniatura inteira.
- teste: Teste de widget: rolar a lista ate a ultima categoria e verificar que o Finder do controle de opacidade continua com dy dentro do painel e na mesma posicao de antes da rolagem.

### `! ` A opacidade e ajustada por um slider de trilho preenchido com knob, com curso do 0 ao 100.

- evidencia: V 00:53.5 (trilho cheio da esquerda ate o knob na ponta direita)
- hoje: FitaDeAjuste relativa e infinita, sem trilho nem knob: linha_de_parametro.dart:88-101 e fita_de_ajuste.dart. A escolha e deliberada e documentada em controles_da_camada.dart:27-37 ("nenhum deslizante") e linha_de_parametro.dart:20-24.
- divergencia: O controle observado e um deslizante absoluto; o do Aurea e uma fita relativa. Sao dois gestos diferentes (tocar numa posicao do trilho nao leva a opacidade aquele valor).
- mudanca: Para ESTA grandeza (unica com intervalo real 0..100) usar um slider absoluto com trilho preenchido, mantendo o campo digitavel a direita; a fita continua onde nao ha intervalo (posicao, escala, parametros de efeito).
- risco: A regra de gesto do editor (um gesto = um desfazer, beginGesture/endGesture) precisa continuar valendo no slider; um `Slider` do Material dispara onChanged fora de gesto e, alem disso, traz ripple e cores do tema, proibidos pela direcao de design do app.
- teste: Teste de widget: arrastar do meio do trilho ate a ponta esquerda e conferir opacidade 0; conferir que o EditorController registrou UM passo de desfazer no gesto inteiro.

### `! ` A quinta categoria chama-se "Diferenca".

- evidencia: V 00:56.0 (cabecalho da categoria aberta: Diferenca)
- hoje: painel_de_mistura.dart:79-87: a familia se chama 'Comparar' e contem Diferenca, Exclusao, Subtrair, Dividir.
- divergencia: Rotulo da categoria diferente do observado ('Comparar' x 'Diferenca'); no AM o nome da categoria repete o nome do primeiro modo, como acontece em Escurecer e Clarear.
- mudanca: Renomear a familia para 'Diferenca' em painel_de_mistura.dart:80.
- risco: Baixo; o nome da familia so aparece na UI. Confere-se que nenhum teste/dump visual procure 'Comparar'.
- teste: Teste de widget: `find.text('Comparar')` nao encontra nada e a linha de categoria 'Diferenca' existe (distinta do chip/opcao 'Diferenca', separada por chave ou por Semantics).

### `! ` A categoria aberta expande MINIATURAS com previa da opcao, cada uma com o nome embaixo (Diferenca, Exclusao, Subtrair, Dividir).

- evidencia: V 00:56.0 (quatro miniaturas com a imagem da composicao renderizada em cada modo)
- hoje: As opcoes sao chips de TEXTO, sem previa: painel_de_mistura.dart:139-154 (_Chip) e 189-241 (Container com Text).
- divergencia: Representacao da opcao completamente diferente: texto x miniatura com previa.
- mudanca: Trocar o Wrap de chips por uma faixa de miniaturas: cada opcao desenha um quadro pequeno da camada sobre o fundo, com o modo aplicado, e o rotulo embaixo.
- risco: Custo de GPU e o risco central: cada miniatura e um passe de blend (ver a regra de saveLayer/ImageFilter por face); quatro a sete miniaturas vivas por categoria aberta podem repetir o caso de 1 fps. Precisa de imagem estatica cacheada, nao de previa viva por quadro.
- teste: Teste de widget que conta chamadas ao canvas/camadas por quadro no painel aberto e falha se passar de um teto; mais teste de que existem quatro miniaturas rotuladas na categoria aberta.

### `! ` Persistencia do estado do painel: qual categoria estava aberta e a rolagem da lista ao voltar e reabrir a familia.

- evidencia: D (PAGINA 15, P · reconstruir: "persistencia do estado") e PAGINA 32 ("abrir/alterar/voltar/reabrir cada familia sem reset")
- hoje: NAO EXISTE estado de accordion (nao ha accordion). O que existe e categoriaAbertaProvider, zerado no voltar (painel_da_camada.dart:512-516).
- divergencia: Ao ganhar accordion, sem estado guardado a lista voltaria sempre fechada, contrariando o requisito de reabrir sem reset.
- mudanca: Guardar a categoria expandida (e, se possivel, o offset de rolagem) por camada ou por sessao do editor, num provider de UI, restaurando ao reabrir a familia.
- risco: Guardar por camada aumenta o estado da sessao; guardar global faz a camada B abrir com a categoria da camada A. Escolher e testar um dos dois, nao improvisar.
- teste: Teste de widget: abrir 'Diferenca', voltar a grade, reabrir a familia e conferir que 'Diferenca' continua aberta e que a opcao ativa continua marcada.

### `! ` Existe uma categoria chamada "Mascara" na lista de blend — e ela nao e prova do fluxo de criacao de mascaras.

- evidencia: V 00:53.5/00:56.0 para o NOME na lista; N para o conteudo interno (PAGINA 15: "os conteudos de Escurecer, Clarear, Contraste, Cor e Mascara nao foram abertos")
- hoje: Nao ha categoria 'Mascara' na lista: as familias terminam em 'Cor' (painel_de_mistura.dart:88-97) e o recorte vem depois, fora da lista, como secao 'Recortar pela camada de cima' com chips de MatteMode (painel_de_mistura.dart:158-183, rotuloDoMatte em :99-105). O fluxo de mascaras de verdade e outro cartao: painel_da_camada.dart:243-251 (id 'mascara' -> PainelDeMascaras).
- divergencia: Falta a setima linha da lista, com o rotulo observado. O que o Aurea tem de mais proximo (matte alfa/luma pela camada de cima) esta fora do accordion e com outro nome. O catalogo interno do AM nao foi filmado: nao da para declarar paridade de conteudo.
- mudanca: Criar a setima linha do accordion com o rotulo 'Mascara' e, dentro dela, as opcoes de matte ja existentes (Nenhum, Alfa, Alfa invertido, Luma, Luma invertido) com o aviso da fonte; manter o cartao 'Mascara' de desenho de mascaras separado e intocado.
- risco: Colar o nome 'Mascara' na lista de blend e o usuario procurar ali o desenho de mascara — exatamente o que a PAGINA 15 avisa. O aviso de fonte ('Nao ha camada com imagem acima desta') precisa continuar visivel dentro da categoria, senao os chips apagados (painel_de_mistura.dart:179) ficam sem explicacao.
- teste: Teste de widget: a lista tem sete linhas de categoria, a setima e 'Mascara'; abri-la mostra os cinco modos de recorte; e o cartao de desenho de mascaras continua acessivel por outro caminho.

### `! ` Titulo da familia no cabecalho enquanto o painel esta aberto: "Homogeneizacao e opacidade".

- evidencia: D (PAGINA 7: "Familia de edicao — Titulo da familia e subpainel") e V 00:40.0 (rotulo do tile na grade)
- hoje: painel_da_camada.dart:549-566 (tituloDaFerramenta): 'opacidade' => 'Opacidade' (:551) e 'mistura' => 'Mistura e recorte' (:564). O titulo do painel aberto vai para a barra da tela (comentario em painel_da_camada.dart:543-548).
- divergencia: Dois titulos, nenhum com o nome observado.
- mudanca: Uma unica entrada no switch para a categoria fundida, devolvendo 'Homogeneizacao e opacidade'; remover as duas antigas.
- risco: Titulo longo: a barra da tela tem 384 px de largura na referencia e o nome tem 30 caracteres — precisa de reducao/elipse sem cortar a palavra no meio.
- teste: Teste de widget: abrir a familia e conferir `find.text('Homogeneizacao e opacidade')` no cabecalho, sem excecao de overflow.

### `~ ` Leitura numerica da opacidade com uma casa decimal e sinal de porcentagem (100.0%).

- evidencia: V 00:53.5 e V 00:56.0 ("100.0%" a direita do slider)
- hoje: controles_da_camada.dart:387-398: LinhaDeParametro com `casas: 0` e `sufixo: '%'` — desenha "100%".
- divergencia: Falta a casa decimal.
- mudanca: Passar `casas: 1` na LinhaDeParametro da opacidade.
- risco: O campo tambem e de digitacao (`aoDigitar`, controles_da_camada.dart:397); com uma casa a mais o texto cresce e a largura fixa de 68 px em linha_de_parametro.dart:110 pode estourar em telas de 384 px.
- teste: Teste de widget: com opacidade 1.0, `find.text('100.0%')` encontra um; e o campo nao dispara overflow (nenhuma excecao de layout na arvore).

### `~ ` Icone de opacidade a esquerda do slider.

- evidencia: V 00:53.5 (circulo hachurado antes do trilho)
- hoje: NAO EXISTE: a linha usa um chip de TEXTO 'Opacidade' (controles_da_camada.dart:388 e linha_de_parametro.dart:81-86).
- divergencia: Texto no lugar de icone; ocupa largura que na referencia e do trilho.
- mudanca: No bloco de topo, trocar o chip de texto por um icone de opacidade, mantendo o rotulo textual so na semantica (Semantics.label 'Opacidade').
- risco: Perder o rotulo visivel: quem le a tela precisa continuar ouvindo 'Opacidade' — o icone sozinho anuncia nada.
- teste: Teste de widget: `find.bySemanticsLabel('Opacidade')` encontra o controle mesmo sem `find.text('Opacidade')`.

### `~ ` Conteudo da categoria Diferenca: Diferenca, Exclusao, Subtrair e Dividir, nessa ordem.

- evidencia: V 00:56.0
- hoje: painel_de_mistura.dart:79-87: BlendMode.difference, BlendMode.exclusion, AureaBlend.subtract, AureaBlend.divide — os quatro, nesta ordem; rotulos em blend_extra.dart:34-35 ('Dividir','Subtrair').
- divergencia: Conteudo e ordem correspondem. So os rotulos nativos vao sem acento ('Diferenca', 'Exclusao') enquanto a captura mostra 'Diferença' e 'Exclusão'.
- mudanca: Acentuar os rotulos visiveis ('Diferença', 'Exclusão') mantendo os identificadores internos como estao.
- risco: O app tem historico de texto caindo em fonte padrao/retangulo em teste; acentuar exige que a fonte carregada no cache do SDK cubra os glifos nos dumps visuais.
- teste: Teste de widget conferindo os quatro rotulos acentuados, na ordem, dentro da categoria aberta.

### `~ ` O modo atual aparece marcado, com indicacao propria na linha (no AM, texto verde + check).

- evidencia: V 00:53.5 (linha Normal com 'Normal' verde e check circular verde a direita)
- hoje: A marcacao e um fundo de chip mais o texto em accent: painel_de_mistura.dart:148-150 (calculo de `aceso`) e 220-238 (fundo AmColors.chip, texto AmColors.accent). Nao ha check nem eco do modo na linha da familia.
- divergencia: Falta o indicador explicito (marca de selecao) e, com o accordion, faltara o eco do modo ativo na linha da categoria fechada. A COR verde nao e divergencia: a rev.02 proibe adotar o verde do concorrente como identidade; o teal/lima da Aurea ocupa esse lugar.
- mudanca: Na linha da categoria, mostrar a direita o nome do modo ativo quando ele pertence aquela categoria, com um check no tom de destaque da Aurea; manter o realce da opcao selecionada dentro da categoria aberta.
- risco: Duplicar informacao: com a categoria aberta, o modo apareceria marcado duas vezes; e a marca precisa continuar chegando a leitura de tela (hoje via Semantics.selected, painel_de_mistura.dart:210-216).
- teste: Teste de widget: escolher Multiplicar, fechar a categoria e conferir que a linha 'Escurecer' exibe 'Multiplicar'; e que o Semantics do item Multiplicar tem selected: true.

### `ok` Ordem das categorias: Normal; Escurecer; Clarear; Contraste; Diferenca; Cor; Mascara.

- evidencia: V 00:53.5 (Normal, Escurecer, Clarear, Contraste, Diferenca...) e V 00:56.0 (Contraste, Diferenca, Cor)
- hoje: painel_de_mistura.dart:39-97: Normal, Escurecer, Clarear, Contraste, Comparar, Cor — mesma sequencia nas cinco primeiras posicoes; a setima (Mascara) nao esta na lista (ver linha propria).
- divergencia: A ordem das seis primeiras corresponde; so o NOME da quinta diverge (linha seguinte).

### `ok` Accordion LOCAL: abrir/fechar categoria nao navega para outra area do app, e voltar recupera o contexto de camada sem perder valores, playhead, propriedades e historico.

- evidencia: V 00:56.0 (a expansao acontece dentro da mesma lista) + PAGINA 7 (invariantes de estado)
- hoje: A troca de painel mexe so em dois providers de UI — painel_da_camada.dart:507-517 (aoVoltar zera estadoDoPainelProvider/categoriaAbertaProvider) — sem tocar em playback nem no projeto; a selecao vem de selectedLayerProvider (painel_da_camada.dart:398-400).
- divergencia: NENHUMA no que existe hoje: navegar entre grade e categoria nao altera dados nem reinicia o cabecote.

### `ok` Selecionar/abrir uma categoria nao pode alterar o blend atual.

- evidencia: D (PAGINA 15, P · reconstruir: "A simples selecao de uma categoria nao deve alterar o blend atual")
- hoje: Hoje nao ha categoria selecionavel: _Titulo e um Text sem gesto (painel_de_mistura.dart:243-260) e so o toque no chip aplica (painel_de_mistura.dart:151-153, setCustomBlend/setBlendMode).
- divergencia: NENHUMA hoje — mas a invariante passa a correr risco quando a linha da categoria virar botao.

### `ok` O modo escolhido aplica-se a camada correta e respeita a ordem da composicao; a escolha persiste.

- evidencia: D (PAGINA 15, P · reconstruir) e PAGINA 32 (aceite do PROMPT 05: undo/redo e sem reset ao reabrir)
- hoje: editor_controller.dart:5046-5063 (setCustomBlend/setBlendMode por id, um desliga o outro) e a composicao empilha na ordem das camadas em palco_de_previa.dart:443-500. O valor vive na camada (layer.blendMode/customBlend), entao sobrevive a fechar e reabrir o painel.
- divergencia: NENHUMA quanto a aplicacao e persistencia do MODO. O que nao persiste e o estado de UI do accordion — que hoje nem existe (linha seguinte).

### `ok` O painel de blend NAO pode ser um browser generico de efeitos: mantem o rotulo e a estrutura observados.

- evidencia: D (PAGINA 15, chapeu: "sem trocar a familia por um browser de efeitos"; PAGINA 32: "Nao reutilize um painel generico que apenas tenha nomes parecidos")
- hoje: PainelDeMistura e proprio e nao passa pela lista de efeitos: painel_de_mistura.dart:118-187; a categoria 'efeitos' e outra (controles_da_camada.dart:114) com painel proprio.
- divergencia: NENHUMA.

### Extensoes do Aurea nesta superficie

O PDF manda preservar e dar destino contextual — nunca apagar.

- Modo 'Dissolver' (AureaBlend.dissolve) dentro da familia Normal — painel_de_mistura.dart:44; o AM nao mostrou nenhuma opcao dentro de Normal (N). Destino: manter como segunda opcao da categoria Normal ate haver referencia AM.
- Catalogo de blend maior que o filmado: 'Linear Burn' e 'Cor mais escura' em Escurecer; 'Divisao' (screen), 'Somar' (plus) e 'Cor mais clara' em Clarear; 'Vivid Light', 'Linear Light', 'Pin Light' e 'Hard Mix' em Contraste (painel_de_mistura.dart:47-78, rotulos em blend_extra.dart:28-39). Os catalogos internos dessas categorias sao N no PDF: preservar dentro dos accordions correspondentes, nunca apagar por nao aparecerem no video.
- Compositor proprio de dois andares para os 10 modos que o Flutter nao tem (custom_blend.dart / blend_extra.dart), com versao per-pixel para darkerColor/lighterColor/dissolve (blend_extra.dart:41-45). E motor, nao UI: seguir servindo as mesmas opcoes depois da reconstrucao.
- Recorte por matte com cinco modos (Nenhum, Alfa, Alfa invertido, Luma, Luma invertido — painel_de_mistura.dart:99-105) usando automaticamente a vizinha de cima (matteSourceAbove, editor_controller.dart:6036-6046) e desabilitando as opcoes quando nao ha fonte (painel_de_mistura.dart:179). Destino: virar o conteudo da categoria 'Mascara' do accordion, com o aviso de fonte preservado.
- Comando setMatte no motor, capaz de recortar por QUALQUER camada da cena, hoje sem porta na UI (comentario em painel_de_mistura.dart:159-162). Destino: manter desligado ou expor como opcao avancada dentro da categoria Mascara; nao remover.
- Campo numerico digitavel da opacidade com teclado (CampoDeValor via LinhaDeParametro.aoDigitar, controles_da_camada.dart:397) — o AM so mostra leitura. Destino: manter ao lado do slider.
- Doutrina do keyframe explicito: editar valor nunca crava marca; so o losango do rail crava (controles_da_camada.dart:39-48, docs/keyframe-explicito.md). Destino: preservar na familia fundida; nao voltar ao auto-keyframe para 'parecer' com o AM.
- Botao de abrir a curva de interpolacao no rail (rails_do_painel.dart:93-98), ativo quando a opacidade tem duas marcas em volta do cabecote. Destino: manter como terceiro botao do rail desta familia.
- Rotulos de acessibilidade proprios por opcao ('Modo X', 'Recorte X') com Semantics.selected (painel_de_mistura.dart:147, 176-177, 210-216). Destino: carregar para as miniaturas novas, que sozinhas nao anunciam nada.
- Ocultacao da familia de mistura para camada de audio (painel_da_camada.dart:256). Destino: na familia fundida, decidir explicitamente o que a camada de audio ve (opacidade sim, blend nao) em vez de perder a regra na fusao.

---

## Timeline: camadas, selecao e edicao temporal (PDF pagina 12, secao 07)

Li a pagina 12 (mais 2, 3 e 7 para o vocabulario V/D/P/N) e as duas capturas dela (p12_0 = camada em edicao, p12_1 = resultado em duas linhas), e depois abri o codigo: linha_do_tempo.dart (1503 linhas), visao_geral_das_camadas.dart (981), painel_da_camada.dart, controles_da_camada.dart e editor_controller.dart. O motor temporal do Aurea esta inteiro e correto: trimLayerStart/trimLayerEnd/moveLayer/splitLayer operam sobre dados reais, cada gesto vira UM desfazer (beginGesture/endGesture) e dividir gera duas camadas, ou seja duas linhas, exatamente como o AM mostra em 00:44.5. O que diverge e a CASCA e a MAQUINA DE ESTADOS. Tres divergencias estruturais: (1) selecionar uma camada nao muda a linha do tempo — no AM a selecao privilegia a faixa do objeto e ABRE a grade no mesmo gesto, e sair restaura a visao geral; no Aurea a vista e um interruptor manual no cabecalho (AlternadorDeVista) e a grade so abre no SEGUNDO toque; (2) a BARRA TEMPORAL do AM (velocidade, tres controles de corte/limites e audio, acima dos tiles) NAO EXISTE no Aurea — velocidade e som viraram tiles e dividir esta enterrado dentro do tile "Camada"; (3) no unico modo do Aurea que corresponde a "camada em edicao" (detalhado) a faixa nao tem realce de selecao, nao tem alcas de extremidade e nao apara — as alcas so existem no modo geral. Divergencias medias: nao ha alca de ordenacao na extremidade da linha no modo detalhado; a pilula traz cor mas nunca miniatura nem icone de tipo; e aparar o inicio nao remapeia os keyframes locais, o que faz a animacao deslizar junto com a ponta (continuidade, nao perda). O N da pagina 12 continua N: o video nao mostra os dedos, e os tres toques longos do Aurea (marcador na regua, apagar keyframe, juntar camadas) sao invencao nossa e nao podem ser apresentados como paridade.

### `!!` A faixa selecionada tem realce claro e as duas extremidades levam controles.

- evidencia: V 00:40–00:46 (captura p12_0: a barra da camada em edicao aparece destacada, com controle na ponta esquerda)
- hoje: So no modo geral: visao_geral_das_camadas.dart:733-742 desenha o anel branco na camada selecionada e chama _pintarAlcasDeAparar (visao_geral_das_camadas.dart:842-857), dois tracinhos claros nas pontas. No modo detalhado, que e o modo que corresponde a "camada em edicao" do AM, _PintorDaFaixa (linha_do_tempo.dart:1330-1387) desenha so a barra colorida com nome e losangos — sem anel, sem alca — e _mover (linha_do_tempo.dart:1118-1143) so arrasta keyframe ou navega, nunca apara.
- divergencia: O estado de "camada em edicao" do Aurea (detalhado) nao tem realce de selecao nem alcas de extremidade, e o arrasto nas pontas nao apara. O AM tem os dois no estado equivalente.
- mudanca: Levar o realce e as alcas para _Faixa: pintar o anel de selecao e as duas alcas em _PintorDaFaixa reaproveitando _pintarAlcasDeAparar, e estender o pouso de _FaixaState (linha_do_tempo.dart:1072-1074) a decidir entre apararInicio/apararFim/mover/keyframe/navegar, como _Arrasto ja faz em visao_geral_das_camadas.dart:161,206-240. Chamar trimLayerStart/trimLayerEnd/moveLayer do controller.
- risco: A faixa detalhada hoje reserva o arrasto horizontal inteiro para keyframe e navegacao; abrir aparar nas pontas pode roubar o gesto de quem quer navegar com o dedo em cima do clipe, e o keyframe que cair a menos de 12 px da ponta deixa de ser pegavel.
- teste: Widget test em test/linha_do_tempo_test.dart: com uma camada de 0..4 s selecionada no modo detalhado, arrastar da ponta direita 40 px para a esquerda e verificar que layer.endTime encurtou e que layer.startTime nao mudou; repetir na ponta esquerda; e um teste de nao-regressao arrastando do MEIO do clipe provando que o cabecote andou (navegacao preservada).

### `!!` Selecionar um objeto na timeline privilegia a faixa dele e ABRE a grade contextual; sair restaura a visao geral.

- evidencia: V 00:42.0 → 00:44.5 (p12_0 mostra uma camada em edicao com a grade aberta embaixo; p12_1 mostra a visao geral de volta, com duas linhas)
- hoje: Selecionar so pinta o anel: visao_geral_das_camadas.dart:513-520 — o primeiro toque grava selectedLayerProvider e o SEGUNDO toque na mesma camada e que chama abrirFerramentasDaCamada (painel_da_camada.dart:441-444). A vista nao muda com a selecao: quem troca geral/detalhado e um botao manual no cabecalho (AlternadorDeVista, visao_geral_das_camadas.dart:51-83, montado em editor_screen.dart:516). Fechar o painel (painel_da_camada.dart:682-686) so recolhe o painel e nao mexe em vista nenhuma.
- divergencia: No AM selecao e um ESTADO unico: um toque privilegia a faixa e abre a grade, e sair volta a visao geral. No Aurea sao tres coisas independentes — selecao, vista e painel — e a vista depende de um botao que o AM nao tem.
- mudanca: Amarrar os tres: no onTap de visao_geral_das_camadas.dart:513-520, o primeiro toque grava a selecao, muda modoDaLinhaDoTempoProvider para detalhado e chama abrirFerramentasDaCamada; em fecharFerramenta/recolher (painel_da_camada.dart:600-603,682-686) devolver o modo para geral. Rebaixar AlternadorDeVista a atalho opcional ou remove-lo do cabecalho para o estado deixar de ter duas fontes.
- risco: O modo detalhado hoje e o unico lugar com keyframe arrastavel; entrar nele a cada toque pode surpreender quem so queria escolher uma camada. E recolher o painel passando a mudar a vista quebra a promessa escrita em painel_da_camada.dart:680 ("recolher nao tira a selecao nem mexe no tempo") — a regra precisa virar "nao mexe no tempo nem na selecao, mas volta a vista".
- teste: Widget test: com duas camadas, um unico toque na trilha da segunda deve (a) deixar selectedLayerProvider na segunda, (b) deixar modoDaLinhaDoTempoProvider em detalhado, (c) achar find.byKey(ValueKey('cartao-transformar')); tocar no chevron de recolher deve devolver modoDaLinhaDoTempoProvider para geral e manter selectedLayerProvider intacto e playback.time.value inalterado.

### `!!` Acima dos tiles ha uma barra temporal com velocidade, controles de corte/limites e audio.

- evidencia: V 00:42.0 (p12_0: velocimetro, tres icones de corte/limite e alto-falante, numa fileira propria entre a faixa e a grade)
- hoje: NAO EXISTE. _Aberto (painel_da_camada.dart:512-539) vai direto do cabecalho de 44 px (_Cabecalho, painel_da_camada.dart:610-701) para _GradeDeCategorias (painel_da_camada.dart:725-742). Velocidade e Som existem, mas como TILES da grade (painel_da_camada.dart:167-178) e so para VideoLayer/AudioLayer; dividir esta dois niveis abaixo, dentro do tile "Camada" (controles_da_camada.dart:1223-1230).
- divergencia: O AM poe as tres acoes temporais mais repetidas a um toque, numa barra propria acima da grade e para qualquer camada; o Aurea espalha duas delas como tiles condicionais e enterra a terceira (dividir) a tres toques de distancia.
- mudanca: Criar uma BarraTemporalDaCamada entre o cabecalho e a grade em painel_da_camada.dart:522-536, com quatro alvos de icone: velocidade (abre a categoria 'velocidade'), aparar-ate-o-cabecote-a-esquerda (trimLayerStart no cabecote), dividir no cabecote (splitLayer, controller ja existe), aparar-a-direita (trimLayerEnd), e audio (mudo/volume). Somar a altura dela em PainelDaCamada.alturaAberta (painel_da_camada.dart:302-307).
- risco: O painel tem teto de 300 px (painel_da_camada.dart:293) e ele ja sai do preview; uma fileira nova empurra a ultima linha de tiles abaixo da dobra. E as acoes ficam a um toque de distancia sem confirmacao — dividir errado no meio de uma edicao e barato de desfazer, mas aparar ate o cabecote nao e obvio.
- teste: Widget test: abrir as ferramentas de uma ShapeLayer e achar as chaves da barra (ValueKey('barra-temporal-dividir') etc.) ACIMA do primeiro cartao na ordem de pintura; tocar em dividir com o cabecote dentro da camada e verificar que o projeto passou de 1 para 2 camadas e que um unico undo devolve a 1.

### `! ` Alguns simbolos da barra temporal mudam quando o playhead fica fora dos limites do segmento.

- evidencia: V 00:42.0 (em p12_0 o alto-falante aparece apagado enquanto os controles de corte estao acesos)
- hoje: O equivalente logico existe em UM lugar so, e nao numa barra temporal: controles_da_camada.dart:1155 calcula podeDividir = cabecote estritamente dentro da camada e a acao fica desabilitada com o motivo escrito no proprio cartao (controles_da_camada.dart:1226-1228). Nao ha nada parecido para velocidade nem para som, e nao ha barra onde os simbolos morem.
- divergencia: A regra de "o simbolo responde ao cabecote" existe isolada dentro de um subpainel; a superficie que o AM usa para expressar essa regra nao existe.
- mudanca: Na BarraTemporalDaCamada da linha anterior, derivar o estado de cada alvo do cabecote: dentro do segmento acende dividir e as duas alcas; fora, apaga dividir e troca o simbolo das alcas por "ir ate a camada". Reaproveitar a conta de podeDividir em vez de duplica-la.
- risco: Icone que troca de forma conforme o cabecote pode ser lido como defeito se a troca nao for legivel; e duplicar a conta de limites em dois arquivos garante que os dois vao discordar.
- teste: Widget test: com o cabecote em 1 s dentro de uma camada 0..4 s, o alvo de dividir esta habilitado (Semantics enabled: true); levar o cabecote para 5 s e verificar que ficou desabilitado e que o rotulo semantico mudou — sem que um unico toque tenha alterado o projeto.

### `! ` O cabecalho da camada traz olho de visibilidade e miniatura/icone a esquerda.

- evidencia: V 00:42.0 e 00:44.5 (olho e um quadrado colorido a esquerda de cada linha, em p12_0 e p12_1)
- hoje: PilulaDaCamada (linha_do_tempo.dart:1273-1327): capsula de 62 px com olho (Icons.visibility_rounded / _off, alterna hidden) e um retangulo 13x15 pintado por corDaCamada (linha_do_tempo.dart:22-27), que so distingue texto / cena 3D / forma / o resto. Usada nos dois modos (linha_do_tempo.dart:1215-1228 e visao_geral_das_camadas.dart:529-546).
- divergencia: O olho corresponde. O quadrado colorido nao e miniatura nem icone: para imagem e video ele nao diz o que a camada e, e quatro tipos dividem a mesma cor (AmColors.teal).
- mudanca: Manter a cor como fundo e sobrepor um icone por tipo (imagem, video, audio, texto, forma, nulo, grupo, cena 3D) dentro do quadrado; para ImageLayer/VideoLayer, quando MediaPreviewService ja tiver um quadro em cache, desenhar a miniatura no lugar do icone — sem nunca gerar miniatura sob demanda no aparelho.
- risco: Miniatura de video custa caro (o comentario em linha_do_tempo.dart:15-21 registra o porque de nao haver); gerar sincrono na trilha derruba o quadro. E o quadrado tem 13x15 px: um icone ali fica no limite da legibilidade.
- teste: Widget/golden test: uma ImageLayer, uma VideoLayer e uma TextLayer na pilha; verificar que os tres quadrados diferem (por chave ValueKey('marca-tipo-<id>') ou por golden) e que nenhuma chamada de geracao de miniatura foi disparada no build (contador no MediaPreviewService falso).

### `! ` Ha um controle de ordenacao na extremidade da linha.

- evidencia: V 00:44.5 (os tres riscos horizontais na ponta direita de cada uma das duas linhas, em p12_1)
- hoje: So no modo geral: coluna de 26 px presa a direita (visao_geral_das_camadas.dart:549-569) com _AlcaDeOrdem (visao_geral_das_camadas.dart:584-622) — tres riscos pintados por _PintorDaAlca, arrasto vertical, uma unica mutacao reorderLayer no solte (visao_geral_das_camadas.dart:247-265). No modo detalhado _Faixa nao monta alca nenhuma (linha_do_tempo.dart:1180-1257).
- divergencia: A alca some justamente no estado de camada selecionada, que e onde o AM a mostra (p12_0 tambem tem os riscos na ponta da linha).
- mudanca: Montar a mesma _AlcaDeOrdem na ponta direita da faixa em _FaixaState.build (linha_do_tempo.dart:1180-1257), acima do detector de keyframe, chamando reorderLayer na camada atual.
- risco: A faixa detalhada ja disputa arrasto horizontal (keyframe/navegacao) com arrasto vertical nenhum; introduzir uma alca vertical num Stack sem lista rolante pode nao ter para onde arrastar — a ordenacao no detalhado precisa de retorno visual proprio, senao o gesto nao mostra o destino.
- teste: Widget test: no modo detalhado com tres camadas, arrastar a alca da camada do meio 30 px para baixo e verificar que project.layers mudou de ordem uma unica vez e que um undo devolve a ordem original.

### `! ` A edicao temporal nao pode custar efeitos nem keyframes.

- evidencia: V 00:40–00:46 (a camada editada continua sendo a mesma camada, com o mesmo conteudo, nas duas linhas do resultado)
- hoje: Os keyframes sao guardados em tempo LOCAL da camada (layer.dart:208-221 keyframeTimes, sempre somados a startTime na hora de desenhar: linha_do_tempo.dart:1402-1408 e visao_geral_das_camadas.dart:895-899). trimLayerStart (editor_controller.dart:4583-4643) muda startTime e duration e corrige o sourceOffset da midia, mas NAO desloca os tempos locais dos keyframes; splitLayer duplica a camada inteira (efeitos incluidos) e so recorta o time remap de video (editor_controller.dart:4744-4782).
- divergencia: Nada e apagado, mas aparar o INICIO faz a animacao inteira deslizar junto com a ponta: a midia fica parada (sourceOffset compensa) e os keyframes andam com ela. Na segunda metade de um split, os keyframes anteriores ao corte ficam com tempo local negativo em relacao ao novo comeco e somem do desenho (o filtro quando < l.startTime em linha_do_tempo.dart:1407).
- mudanca: Em trimLayerStart, quando delta != 0, remapear os tempos locais de transformacao, efeitos, mascaras e modulos por -delta (e descartar/prender os que ficarem fora), na mesma transacao. Em splitLayer, aplicar o mesmo deslocamento a segunda metade. Nao alterar o comportamento de trimLayerEnd, que nao mexe na origem local.
- risco: Remapear keyframe e mudar dados do projeto: um erro de sinal desloca a animacao de todo mundo que aparar o inicio, e projetos ja salvos com o comportamento antigo passam a se comportar diferente ao serem reaparados. Efeito com keyframe fora do clipe hoje e legitimo (a camada pode ser esticada de volta) — descartar seria perda de verdade.
- teste: Teste de unidade: camada 0..4 s com keyframe de posicao em 1 s (local) e valor distinto; aparar o inicio para 0,5 s e verificar que a posicao avaliada no instante ABSOLUTO 1 s continua a mesma de antes do corte; dividir em 2 s e verificar que a segunda metade avalia os mesmos valores absolutos que a camada original avaliava.

### `ok` O playhead vertical atravessa a regua e a faixa.

- evidencia: V 00:42.0 (a linha branca corta a regua e a barra da camada em p12_0 e p12_1)
- hoje: linha_do_tempo.dart:211-222: um Positioned de 2 px preso em largura*fracaoDoCabecote, top: alturaDoTransporte, bottom: 0, por cima do Stack inteiro e com IgnorePointer — logo atravessa regua e trilhas nos dois modos.
- divergencia: NENHUMA

### `ok` O cabecalho da camada traz cor, nome e a area temporal da camada.

- evidencia: V 00:44.5 (cada linha e uma barra colorida com o nome dentro, ocupando o intervalo de tempo da camada)
- hoje: visao_geral_das_camadas.dart:692-743 pinta a barra de mapa.xDe(startTime) a xDe(endTime) na cor de corDaCamada, e _pintarNome (visao_geral_das_camadas.dart:918-944) escreve o nome DENTRO do clipe, com reticencias e recorte pelo RRect. No detalhado, o mesmo em _PintorDaFaixa (linha_do_tempo.dart:1359-1384).
- divergencia: NENHUMA

### `ok` Depois da edicao, a visao geral apresenta os dois segmentos em DUAS LINHAS; nao reformatar como dois clipes numa unica trilha de montagem.

- evidencia: V 00:44.5 (p12_1: dois retangulos com duracoes e posicoes distintas, um por linha)
- hoje: splitLayer (editor_controller.dart:4731-4801) cria uma segunda camada (layer.duplicated()) e a insere na lista de camadas (editor_controller.dart:4784-4799), selecionando-a. A pilha desenha uma linha por camada (visao_geral_das_camadas.dart:692-743, i * alturaDaTrilha) — nunca dois clipes na mesma linha.
- divergencia: NENHUMA

### `ok` Trim, divisao, deslocamento e duracao funcionam sobre dados reais, com desfazer e refazer.

- evidencia: V 00:40–00:46 (a sequencia de edicao temporal produz um resultado persistente na visao geral)
- hoje: O motor esta inteiro: moveLayer (editor_controller.dart:4576), trimLayerStart (4583), trimLayerEnd (4690) com teto pela sobra da fonte, splitLayer (4731). Os gestos abrem e fecham lote de desfazer: visao_geral_das_camadas.dart:339-349 chama beginGesture no inicio do arrasto e _fecharArrasto (visao_geral_das_camadas.dart:267-273) chama endGesture — um arrasto vira UM undo. O transporte tem desfazer/refazer ligados a canUndo/canRedo (linha_do_tempo.dart:372-383).
- divergencia: NENHUMA para trim, deslocamento, duracao e desfazer. Ressalva de alcance, nao de mecanismo: mover e aparar so respondem na camada JA selecionada (visao_geral_das_camadas.dart:206-213) e so no modo geral; dividir nao tem gesto nem alvo na linha do tempo (fica em controles_da_camada.dart:1223-1230), o que ja esta cobrado nas linhas da barra temporal.

### `ok` A associacao de cada toque a cada icone nao esta observada; nao inventar gestos de long press so pela presenca de um icone.

- evidencia: N (o proprio PDF: "o video nao mostra os dedos")
- hoje: O Aurea ja tem tres toques longos nesta superficie, nenhum deles derivado do AM: regua = cravar/tirar marcador (linha_do_tempo.dart:576 e 193-195); faixa detalhada = apagar o keyframe sob o dedo (linha_do_tempo.dart:1170-1177); trilha na pilha = juntar camadas na multi-selecao (visao_geral_das_camadas.dart:478-496). O contrato de gestos esta escrito em visao_geral_das_camadas.dart:93-112 e em docs/linha-do-tempo-gestos.md.
- divergencia: N continua N. A divergencia nao e ter esses gestos — e apresenta-los como paridade AM: nenhum foi observado no video, e apagar keyframe por toque longo e destrutivo sem confirmacao.

### Extensoes do Aurea nesta superficie

O PDF manda preservar e dar destino contextual — nunca apagar.

- Modo DETALHADO (uma trilha alta de 56 px para a camada selecionada) e o AlternadorDeVista no cabecalho que troca geral/detalhado — o AM so tem a pilha (visao_geral_das_camadas.dart:29-83, linha_do_tempo.dart:964-1264). Destino: se a selecao passar a abrir o detalhado sozinha (linha 3 da matriz), o botao vira atalho opcional ou some; a vista em si precisa ficar.
- PilulaDeNavegacao: capsula branca sobre a faixa com o nome da camada aberta e setas anterior/proxima (linha_do_tempo.dart:1239-1256, pilula_de_navegacao.dart). O AM troca de camada voltando a visao geral. Destino: manter como atalho no estado de camada em edicao, sem competir com o cabecalho de camada.
- Keyframes manipulaveis na propria trilha: losango pegavel em raio de 18 px, toque leva o cabecote ate ele, arrasto move (com lote de desfazer), toque longo apaga (linha_do_tempo.dart:1049-1177). O AM edita keyframe pela curva do intervalo. Destino: preservar; e a unica porta para keyframe fora do editor de curva.
- Marcadores do projeto e batidas de musica desenhados na regua, mais toque longo que crava/tira marcador (linha_do_tempo.dart:504-522, 671-709). Nao observado no AM. Destino: manter na regua; e o que da porta ao detector de BPM e ao corte no ritmo.
- Forma de onda real dentro do clipe de audio/video (contorno min/max + corpo RMS, lida da PeakPyramid em cache, respeitando sourceOffset e speed) — visao_geral_das_camadas.dart:747-807. Destino: preservar; e o que permite cortar no lugar certo.
- Cadeado de camada travada, desenhado no clipe e com o gesto realmente bloqueado no pouso (visao_geral_das_camadas.dart:214-220, 814-834). Destino: preservar.
- Multi-selecao por toque longo, com anel verde no clipe e painel de acoes do conjunto (visao_geral_das_camadas.dart:478-496, 719-732). Destino: preservar como extensao declarada; nao apresentar como comportamento AM.
- Imantacao do clipe a ancoras reais — cabecote, pontas dos outros clipes, comeco/fim do projeto, marcadores e batidas — com tolerancia em pixels (visao_geral_das_camadas.dart:179-202, 356-396). Destino: preservar; e invisivel e so ajuda.
- Barra de proporcao no topo da regua (que pedaco do projeto esta a vista), laco de repeticao, setas de um quadro coladas na capsula do tempo, botao Enquadrar e zoom por belisco (linha_do_tempo.dart:761-795, 812-939, 172-201, 544-566). O AM nao mostra nenhum deles. Destino: preservar; sao o preco de ter o cabecote preso no meio com zoom livre.
- Relogio em minuto:segundo:QUADRO colado ao cabecote, com a hora aparecendo so quando existe (linha_do_tempo.dart:941-962). Destino: preservar.
- Estados vazios com texto — projeto sem camadas, camadas sem selecao, e o aviso "o conteudo novo entra no cabecote" (linha_do_tempo.dart:272-290, 1435-1452; visao_geral_das_camadas.dart:962-981). Destino: preservar; sao ancoradouros de teste e evitam que vazio pareca defeito.

### Correcoes do conferente (1)

- **A faixa selecionada tem realce claro e as duas extremidades levam controles.**
  - afirmado: "No modo detalhado, que e o modo que corresponde a 'camada em edicao' do AM, _PintorDaFaixa desenha so a barra colorida com nome e losangos — sem anel, sem alca — e _mover so arrasta keyframe ou navega, nunca apara. Divergencia: O estado de 'camada em edicao' do Aurea (detalhado) nao tem realce de selecao nem alcas de extremidade, e o arrasto nas pontas nao apara. O AM tem os dois no estado equivalente."
  - verdade: A premissa esta errada e contradiz a propria linha 2 da matriz. O estado do Aurea que corresponde a 'camada em edicao' do AM (camada escolhida + grade contextual aberta) NAO e o detalhado: e o modo GERAL. Provas: (a) modoDaLinhaDoTempoProvider nasce em ModoDaLinhaDoTempo.geral (visao_geral_das_camadas.dart:37-39); (b) selecionar e abrir a grade nao trocam a vista — o proprio teste cobra isso, com as razoes 'escolher nao pode arrastar a pessoa para outra vista' e 'abrir as ferramentas nao troca a vista debaixo do dedo' (test/visao_geral_das_camadas_test.dart:198-215); (c) o painel sobrepoe o rodape tirando espaco da PREVIA, nunca da linha do tempo (painel_da_camada.dart, 'alturaDaFerramentaAberta' / comentario em PainelSobreposto), entao a faixa continua a vista com a grade aberta. Nesse estado real o Aurea CUMPRE a exigencia inteira: anel branco de 1,6 px na camada selecionada (visao_geral_das_camadas.dart:733-742), dois tracinhos claros nas duas pontas (_pintarAlcasDeAparar, 842-857) e arrasto de ponta que APARA de verdade — _pousar classifica as pontas como _Arrasto.apararInicio/_Arrasto.apararFim dentro da tolerancia _alca (linhas 222-238) e o update chama c.trimLayerStart / c.trimLayerEnd com imantacao e lote de desfazer (linhas 375-393). O modo detalhado, que a matriz elegeu como 'equivalente', e uma vista extra do Aurea que o AM nao tem — o proprio codigo diz 'O detalhado e nosso; a referencia so tem a pilha' (visao_geral_das_camadas.dart:26) — e so se entra nela por um botao manual do cabecalho. Medir a paridade contra uma vista que a selecao nunca abre fabrica uma divergencia onde ha paridade.

---

## Aparencia: Cor e preenchimento (PDF pagina 13, secao 08; regras das paginas 2, 3 e 7)

Li a pagina 13 (mais 2, 3 e 7) e os arquivos painel_de_cor.dart (537 linhas), escolha_de_cor.dart (229), painel_da_camada.dart, controles_da_camada.dart, rails_do_painel.dart, editor_screen.dart, shape.dart e editor_controller.dart. Quatro exigencias ja correspondem: o caminho Camada > Cor e preenchimento, o nome da familia no cabecalho, o painel sob a timeline sem modal em tela cheia, e o rail esquerdo de retorno/animacao presente. Tres divergencias sao estruturais: (1) nao existe a fileira de quatro seletores de tipo de preenchimento — e por tras dela nao existe comando de UI que crie um gradiente, entao updateShapeGradient so e alcancavel em projetos vindos de template ou de arquivo; (2) nao existe a coluna direita com conta-gotas e paleta — o painel tem duas colunas onde o AM tem tres; (3) a opacidade do preenchimento nunca aparece nem e editavel, apesar de ShapeFill.opacity e ShapeGradientFill.opacity existirem no modelo. Duas sao medias e de agrupamento: a leitura da cor e decimal ('250 243 180') onde o AM mostra hexadecimal, e o bloco inteiro de CONTORNO mora dentro de Cor e preenchimento enquanto a categoria 'Borda e sombra' — a familia que o AM usa para isso na pagina 14 — esta declarada com disponivel: false. Falta tambem o '+' no fim da linha de cor. Duas observacoes que valem registro fora da matriz: nenhuma cor deste painel e animavel (ShapeGradientFill.colorFrames existe no modelo e nao tem um unico comando que o escreva, entao o losango e a curva ficam mortos exceto para espessura e opacidade do contorno), e whats_new.dart:350-357 anuncia ao usuario um seletor de cor com espectro de matiz, area de saturacao/brilho, transparencia e campo HEX que nao existe em lugar nenhum de lib/ — a interface real e fita R/G/B mais doze amostras fixas. Os itens marcados N no PDF (outros modos, hex, conta-gotas, gestao de paleta) continuam N: recomendo construir posicao e presenca, nunca comportamento deduzido.

### `!!` Quatro seletores graficos de TIPO DE PREENCHIMENTO no alto do painel, com o modo de cor solida selecionado.

- evidencia: V 00:51.0 / V 00:51.5 ("quatro seletores graficos de tipo de preenchimento no alto do painel; o modo de cor solida esta selecionado")
- hoje: NAO EXISTE. painel_de_cor.dart:230-318 escolhe o layout pelo item de pintura que a camada JA tem (switch sobre pinturas.firstOrNull: ShapeFill / ShapeGradientFill / nenhum) — nao ha fileira de modos, nem estado selecionado, nem como trocar. Confirmado no motor: nenhum comando de UI cria um ShapeGradientFill; as unicas construcoes vivas estao em lib/src/features/editor/domain/project_store.dart:617 (desserializacao) e nos templates (colina_tv_template.dart:874, pindown_motion_template.dart:267, etc.). Uma forma criada pelo app so pode ser chapada; gradiente e contorno-como-pintura sao inalcancaveis pela interface.
- divergencia: Falta a fileira inteira de modos e, atras dela, o comando que troca o tipo de pintura. Nao e so um controle ausente: uma capacidade que o motor tem (updateShapeGradient em editor_controller.dart:6580) nao tem porta.
- mudanca: Criar em PainelDeCor uma fileira de modos no topo, antes de qualquer conteudo, com o modo vigente aceso, e um comando novo no EditorController (setShapePaintKind) que substitua o item de pintura NO MESMO INDICE da lista, preservando o que der para preservar (cor A do gradiente vinda da cor chapada, e vice-versa pela cor A). O quarto modo do AM nao foi identificado no video: abrir so os modos que o Aurea sustenta e deixar o quarto slot fora ate haver referencia (ver linha N).
- risco: A lista de itens da forma e avaliada de cima para baixo e uma pintura consome todos os caminhos acumulados ate ali (painel_de_cor.dart:176-186). Trocar o tipo no lugar errado da lista muda o que e pintado, nao so a cor. Trocar ShapeFill por ShapeGradientFill perde evenOdd (shape.dart:770-772); o caminho inverso perde extras, stops, center, radiusScale e colorFrames (shape.dart:849-878). Sem um aviso, e perda de dado silenciosa. E o item novo precisa de id proprio ou os provedores itemDaCorProvider ficam apontando para um item morto.
- teste: test/cor_e_preenchimento_test.dart: numa forma so com ShapeFill, tocar o seletor de gradiente; provar que contents tem ShapeGradientFill no mesmo indice, que a previa mudou de pixel, que desfazer devolve o ShapeFill original com evenOdd intacto, e que voltar para chapado nao apaga colorFrames se o gradiente ja tinha marcas (ou avisa antes).

### `!!` A linha de cor exibe a OPACIDADE do preenchimento junto do valor — '#FAF3B4 (100%)'.

- evidencia: V 00:51.5
- hoje: NAO EXISTE no painel. O dado existe no modelo: shape.dart:763 e 768 (ShapeFill.opacity) e shape.dart:856 (ShapeGradientFill.opacity). Nenhum ponto de lib/ escreve ShapeFill.opacity a partir da UI — painel_de_cor.dart:230-318 so mexe em cor, angulo e radial. EscolhaDeCor tambem nao mexe no alfa: escolha_de_cor.dart:65-75 preserva cor.a e escolha_de_cor.dart:97 recoloca o alfa antigo na amostra pronta. A unica opacidade alcancavel e a da CAMADA (categoria 'opacidade', controles_da_camada.dart:130-139) e a do CONTORNO (painel_de_cor.dart:346-353), que sao outras grandezas.
- divergencia: A opacidade do preenchimento nao aparece nem e editavel; o usuario nao tem como fazer 'vidro com borda' (fill 20% / stroke 100%) que o proprio comentario de shape.dart:810-811 descreve como suportado.
- mudanca: Acrescentar a leitura '(NN%)' na linha de cor e um comando setShapeFillOpacity / o campo equivalente no gradiente, ligado ao mesmo gesto de undo do resto do painel. Decidir explicitamente se a porcentagem edita ShapeFill.opacity ou o alfa da cor — sao dois dados diferentes no modelo e mostrar um numero so para os dois mente.
- risco: Duplicidade real: a cor ja carrega alfa e o item de pintura carrega opacity; multiplicar os dois sem decidir qual a UI controla produz um valor que nao volta ao mesmo lugar depois de salvar/carregar (project_store.dart). Alfa tambem muda o caminho de composicao no render e pode virar saveLayer por camada — atencao a regra de GPU por primitiva.
- teste: Teste de widget: arrastar a fita de opacidade do preenchimento para 20 e provar que ShapeFill.opacity == 0.2, que a leitura diz '(20%)', que a previa clareou o pixel central, e que salvar/reabrir o projeto devolve 0.2.

### `!!` A direita do painel ha uma coluna de controles de cor — conta-gotas e paleta.

- evidencia: V 00:51.0 ("a direita, controles de cor como conta-gotas e paleta"); os fluxos internos sao N
- hoje: NAO EXISTE. controles_da_camada.dart:145-157 (_ComRail) so tem duas colunas — RailEsquerdo e o miolo rolavel. Rail DIREITO existe no codigo (rails_do_painel.dart:111-120) mas e usado apenas pela transformacao (controles_da_camada.dart:79-96). Busca por conta-gotas/eyedropper/pipeta em lib/ nao retorna nada.
- divergencia: Falta a terceira coluna inteira. A composicao espacial do AM nesta tela e rail esquerdo + miolo + coluna direita; o Aurea tem duas colunas.
- mudanca: Reaproveitar RailDireito nesta categoria com os afordances observados (conta-gotas e paleta), respeitando os 46 px do outro rail. Implementar so o que o Aurea consegue sustentar; o resto fica desabilitado com motivo, como painel_da_camada.dart:229-234 ja faz com 'Borda e sombra'.
- risco: Conta-gotas exige ler o pixel da previa. Quando a cena roda em GPU (Scene3DGpu) ou o quadro esta em cache de raster, nao ha bitmap de CPU garantido para amostrar — implementar isso pode forcar um toImage por toque, que e exatamente o custo que a memoria de GPU por primitiva manda evitar. Precisa cair para o caminho de raster ja existente (preview_raster.dart) e falhar em silencio, nao travar. Alem disso o miolo perde ~46 px de largura: as fitas R/G/B de escolha_de_cor.dart:112 tem porPixel calibrado em 300 px de largura e passam a cobrir menos.
- teste: Teste de widget: a coluna direita esta na arvore com os dois botoes e rotulos semanticos; teste de layout provando que a largura do miolo caiu e que nenhuma LinhaDeParametro estourou (sem overflow); teste de calibragem da fita provando que arrastar a largura util ainda percorre 0..255.

### `! ` A esquerda do painel permanecem a seta de retorno e os controles associados a ANIMACAO da propriedade.

- evidencia: V 00:51.0
- hoje: controles_da_camada.dart:145-157 (_ComRail) coloca RailEsquerdo antes do miolo rolavel; rails_do_painel.dart:56-102 desenha voltar + losango de keyframe + curva, em 46 px; painel_de_cor.dart:24-84 (alvoDaCorDaForma) e quem alimenta esse rail na categoria 'cor'.
- divergencia: O rail existe, mas na pratica esta MORTO para a cor: painel_de_cor.dart:31 devolve AlvoDoRail vazio para tudo que nao e ShapeLayer (texto, particulas, Element3D), e painel_de_cor.dart:34-38 so aceita as trilhas de CONTORNO (espessura/opacidade). Nenhuma cor do painel — texto, preenchimento chapado, gradiente, particulas, Element3D — acende o losango ou a curva. O comentario painel_de_cor.dart:17-23 assume isso: ShapeGradientFill.colorFrames existe em lib/src/features/editor/domain/shape.dart:861-875 e nao tem um unico comando que o escreva.
- mudanca: Duas frentes. (a) Curto: manter o rail visivel e apagado, mas so quando a propriedade em foco realmente nao anima — hoje ele fica apagado ate quando o foco esta numa cor de gradiente que TEM estrutura de keyframe no modelo. (b) Real: escrever o comando que falta em EditorController (setShapeGradientColorKeyframe, escrevendo em ShapeGradientFill.colorFrames) e um equivalente para a cor de texto/preenchimento, e ligar alvoDaCorDaForma ao seletor de cor em foco, nao so ao contorno.
- risco: Cor animada muda o caminho de render e de exportacao: shape.dart:877-878 diz que colorFrames preserva o gradiente vetorial na exportacao, entao gravar keyframes de cor mexe no exportador vetorial e no cache 3D. Interpolar cor em sRGB direto produz cinza no meio de complementares. E, pela regra do keyframe explicito (docs/keyframe-explicito.md), editar a cor nunca pode cravar marca sozinho.
- teste: test/cor_e_preenchimento_test.dart: com a camada de forma e o gradiente em foco, tocar o losango do rail, avancar o cabecote, mudar a cor, e provar que g.colorFrames tem duas marcas e que a previa em t=meio devolve a cor interpolada; e um teste negativo provando que mexer na cor SEM tocar o losango nao cria marca.

### `! ` A linha de cor exibe o valor em HEXADECIMAL (#FAF3B4).

- evidencia: V 00:51.5 (ampliacao do painel)
- hoje: escolha_de_cor.dart:160-168 (_Cabecalho) imprime '$r $g $b' em decimal, ao lado de uma amostra de 26 px (escolha_de_cor.dart:170-178). O rotulo semantico usa o mesmo formato (escolha_de_cor.dart:142). Nao ha string hexadecimal em lugar nenhum do subsistema — a busca por 'hex' em lib/ so acha comentario (lib/src/core/theme/tokens.dart:6) e um texto de novidades (lib/src/features/projects/presentation/whats_new.dart:353).
- divergencia: Formato de leitura diferente: '250 243 180' onde o AM mostra '#FAF3B4'.
- mudanca: Trocar a leitura do _Cabecalho de EscolhaDeCor para hexadecimal maiusculo com '#', mantendo tabularFigures. Manter os tres campos R/G/B por fita abaixo (extensao Aurea, ver extensoes).
- risco: Baixo, e nao e cosmetico puro: o rotulo de acessibilidade (escolha_de_cor.dart:142 e 204-208) usa a mesma string. Trocar sem trocar os dois lados deixa a tela falada dizendo um formato e a tela mostrando outro; e ha teste ancorado no formato atual (test/cor_e_preenchimento_test.dart:162, 'digitar um canal muda so aquele canal').
- teste: Teste de widget: pintar a camada com Color(0xFFFAF3B4) e esperar find.text('#FAF3B4'); e um teste de semantica provando que o value do no de cor e a mesma string.

### `! ` A linha de cor termina com um botao '+'.

- evidencia: V 00:51.0 (o '+' e visivel; o que ele abre nao foi filmado — ver a linha N)
- hoje: NAO EXISTE. escolha_de_cor.dart:143-181 tem exatamente tres coisas na linha: rotulo, leitura numerica e amostra. Nao ha nenhum afordance de acrescentar.
- divergencia: Falta o controle. Como o fluxo dele nao foi observado, o que se pode reconstruir com honestidade e a posicao e a presenca, nao o comportamento.
- mudanca: Colocar o '+' no fim da linha de cor. NAO inventar o destino: liga-lo ao unico significado que o Aurea ja sustenta hoje sem referencia nova (acrescentar a cor atual as amostras rapidas do projeto) e registrar no codigo que o comportamento AM continua N.
- risco: Se o '+' do AM for 'adicionar parada de gradiente' e nao 'salvar na paleta', ligar ao destino errado cria uma divergencia funcional pior que a ausencia. Uma paleta por projeto ainda exige campo novo no VideoProject e migracao no project_store — nao pode quebrar a leitura tolerante de projeto (QA 1.0).
- teste: Teste de widget: o botao existe, tem rotulo semantico, e o teste NAO afirma paridade de comportamento — so posicao e presenca. Marcar o teste com o mesmo aviso N.

### `! ` O painel de Cor e preenchimento contem os controles de COR — nao os do traco. Borda/contorno pertence a familia Borda e sombra, no subpainel Traco.

- evidencia: V 00:51.0 (painel de preenchimento) contrastado com V 00:48.0 (familia Borda e sombra / subpainel Traco, p.14)
- hoje: painel_de_cor.dart:319-363 coloca DENTRO de 'Cor e preenchimento' um bloco 'Contorno' completo: adicionar contorno (ensureShapeStroke), cor do contorno, espessura, opacidade e remover. Enquanto isso painel_da_camada.dart:229-234 declara a categoria 'borda' ('Borda e sombra') com disponivel: false e porQueNao 'Chega numa proxima entrega'.
- divergencia: Agrupamento invertido: o Aurea junta preenchimento e contorno num painel so e deixa a familia que o AM usa para isso desligada. O painel de cor do AM na pagina 13 nao mostra espessura, Iniciar/Fim nem opcoes de traco.
- mudanca: Mover o bloco de contorno de painel_de_cor.dart:319-363 para a familia 'borda', ligar a categoria (painel_da_camada.dart:229-234) e deixar em 'Cor e preenchimento' apenas tipo de preenchimento, linha de cor, amostras e a coluna direita. Preservar todas as capacidades — o PDF (p.2) proibe apagar funcionalidade ao mover interface.
- risco: O rail esquerdo desta categoria SO mira as trilhas de contorno (painel_de_cor.dart:34-38): tirar o contorno daqui deixa o rail de 'Cor e preenchimento' sem alvo nenhum ate a linha de keyframe de cor ser feita, e leva alvoDaCorDaForma junto para a outra familia. Os provedores itemDaCorProvider/parametroDaCorProvider (painel_de_cor.dart:14-15) sao lidos por editor_screen.dart:158-159 e por test/cor_e_preenchimento_test.dart:230 — mover sem renomear/religar quebra os dois.
- teste: test/cor_e_preenchimento_test.dart:202 e :223 (o contorno nasce/muda/sai; a espessura anima e o rail mira nela) devem passar com o caminho novo, atraves de 'Borda e sombra'; e um teste novo provando que 'Cor e preenchimento' nao contem mais find.text('Espessura').

### `! ` Voltar recupera o contexto de camada sem perder valores; nunca reabrir um painel do objeto anterior; a troca de painel nao gera alteracao no projeto.

- evidencia: D/P p.7 (invariantes da maquina de estados) + V 00:51 (a seta de retorno visivel a esquerda)
- hoje: painel_da_camada.dart:530-534 faz aoVoltar devolver EstadoDoPainel.categorias e limpar categoriaAbertaProvider — sem tocar em selecao, cabecote ou projeto. rails_do_painel.dart:73-78 e o botao. editor_screen.dart:150-162 escuta selectedLayerProvider, categoriaAbertaProvider, itemDaCorProvider e parametroDaCorProvider so para descartar a edicao pendente.
- divergencia: Parcial. Voltar esta certo, mas itemDaCorProvider e parametroDaCorProvider (painel_de_cor.dart:14-15) NUNCA sao zerados ao trocar de camada ou de categoria — o unico reset e ao remover o contorno (painel_de_cor.dart:359). Selecionar 'Espessura' na forma A, voltar, selecionar a forma B e reabrir Cor deixa parametroDaCorProvider == 'width', e painel_de_cor.dart:194/210 acende a linha de espessura da forma B como se ela tivesse sido escolhida; itemDaCorProvider ainda aponta para o traco da forma A. E resto de estado do objeto anterior.
- mudanca: Zerar itemDaCorProvider e parametroDaCorProvider no mesmo laco de editor_screen.dart:150-162 quando selectedLayerProvider ou categoriaAbertaProvider mudar (hoje esses providers so sao ESCUTADOS ali, nunca escritos).
- risco: Zerar demais apaga o foco do rail no meio de um gesto legitimo — por exemplo, ao entrar/sair de grupo, que tambem troca a camada selecionada. O reset tem de rodar fora do gesto (respeitar beginGesture/endGesture, editor_controller.dart:389-403) para nao partir um passo de desfazer em dois.
- teste: Teste de widget: forma A > Cor > tocar 'Espessura'; voltar; selecionar forma B; abrir Cor; esperar parametroDaCorProvider == null, itemDaCorProvider == null e nenhuma LinhaDeParametro com escolhida == true.

### `! ` Ligar a cor ao objeto selecionado, a previa, ao historico e aos keyframes suportados; nao substituir a area por um picker generico sem a moldura contextual AM.

- evidencia: P p.13 (obrigacao do agente), ancorada em V 00:51
- hoje: Objeto e previa: ligados por comando real — editor_controller.dart:6545 (editTextLayer), :6580 (updateShapeGradient), :6757 (setShapePrimaryColor), :7234 (updateShapeStroke), e updateParticles/updateElement3D via painel_de_cor.dart:126, :163. Historico: painel_de_cor.dart:114-115 e as demais fichas passam beginGesture/endGesture (editor_controller.dart:389-403), e o toque numa amostra pronta (escolha_de_cor.dart:97) cai na janela de 450 ms de editor_controller.dart:320-331, entao tambem vira um passo de desfazer. Moldura: EscolhaDeCor e embutido no painel com rail, sem showDialog/showModalBottomSheet.
- divergencia: Objeto, previa, historico e moldura: NENHUMA. Keyframes: divergente — nenhuma cor deste painel e animavel (ver a linha do rail esquerdo). Alerta separado: lib/src/features/projects/presentation/whats_new.dart:350-357 anuncia ao usuario um 'seletor de cor completo: espectro de matiz, area de saturacao e brilho, transparencia e campo HEX' que NAO existe neste codigo — a busca por espectro/HSV/ColorPicker em lib/ nao encontra widget nenhum.
- mudanca: Manter tudo o que ja liga. Fazer os keyframes de cor (linha do rail). E corrigir whats_new.dart:350-357, ou construir o que ele promete — hoje o texto e uma promessa nao cumprida na tela.
- risco: Cor de amostra pronta hoje depende do coalescimento de 450 ms: dois toques rapidos em duas amostras viram UM passo de desfazer. Se a paridade exigir um passo por toque, envolver a amostra em beginGesture/endGesture — e ai o toque triplo em amostras diferentes enche o undo.
- teste: test/cor_e_preenchimento_test.dart:150 e :184 ja cobrem objeto+previa; acrescentar um teste de desfazer (tocar amostra, undo, esperar a cor anterior) e um teste de guarda provando que nao existe rota/dialogo modal aberto por EscolhaDeCor.

### `~ ` Abaixo da linha de cor aparecem DUAS FILEIRAS de amostras.

- evidencia: V 00:51.0
- hoje: escolha_de_cor.dart:81-101 monta um Wrap com spacing 7 e amostras de 30 px (escolha_de_cor.dart:212-214) sobre as 12 cores fixas de escolha_de_cor.dart:41-54. Na largura util do painel (tela menos os 46 px do rail e 16 px de folga, controles_da_camada.dart:148-154) isso quebra em duas fileiras.
- divergencia: Praticamente nenhuma na forma. O que difere e a natureza: as 12 do Aurea sao FIXAS e nao editaveis, enquanto no AM a segunda fileira convive com gestao de paleta (que e N). O numero por fileira tambem varia com a largura (8+4 num aparelho largo) em vez de 6+6 como diz o comentario de escolha_de_cor.dart:36-37.
- mudanca: Se a paridade visual importar, fixar seis por fileira em vez de deixar o Wrap decidir. Nao trocar a lista de cores sem referencia.
- risco: Fixar a contagem por fileira quebra em aparelho estreito; usar Wrap resolve isso sozinho hoje.
- teste: Teste de widget com tamanho de tela fixado em 384x832 (a medida do MP4, p.3): contar as amostras por fileira pelas posicoes globais e esperar 6 e 6.

### `ok` O caminho Camada > Cor e preenchimento abre um subpainel de familia dentro do contexto da camada selecionada, sem virar tela nova.

- evidencia: V 00:51.0 (contexto completo de preenchimento) + p.7, estado "Familia de edicao"
- hoje: lib/src/features/editor/presentation/widgets/painel_da_camada.dart:225-228 declara a CategoriaDaCamada id 'cor', rotulo 'Cor e preenchimento'; lib/src/features/editor/presentation/widgets/controles_da_camada.dart:118 roteia 'cor' => PainelDeCor(camada, tempo); painel_da_camada.dart:526-535 troca a grade de categorias pelo conteudo da categoria dentro do MESMO painel.
- divergencia: NENHUMA

### `ok` O nome da familia ocupa o cabecalho superior enquanto o subpainel esta aberto.

- evidencia: V 00:51.0 ("O nome da familia esta no cabecalho superior")
- hoje: lib/src/features/editor/presentation/editor_screen.dart:421-426 troca o cabecalho do projeto por _CabecalhoDaFerramenta(titulo: tituloDaFerramenta(aberta)); painel_da_camada.dart:562 mapeia 'cor' => 'Cor e preenchimento'.
- divergencia: NENHUMA

### `ok` O controle de aparencia permanece SOB a timeline da camada selecionada; a previa e a faixa da camada nao sao substituidas por um modal de cor em tela inteira.

- evidencia: V 00:51.0-00:51.5
- hoje: editor_screen.dart:278-300 monta Column(cabecalho, previa, linha do tempo) e o painel entra como sobreposicao no rodape do Stack; editor_screen.dart:241-276 fixa a altura da previa pelo espaco que sobraria COM a ferramenta aberta, entao ela nao encolhe; painel_da_camada.dart:576-592 (alturaDaFerramentaAberta) mantem o chao da linha do tempo (transporte + regua + uma trilha).
- divergencia: NENHUMA

### `ok` Os fluxos internos dos outros modos de preenchimento, a edicao hexadecimal, o conta-gotas e a gestao da paleta NAO foram demonstrados; seus icones sao visiveis, os fluxos nao.

- evidencia: N (explicito na pagina 13)
- hoje: NAO EXISTE nenhum deles — sem seletor de modo (painel_de_cor.dart:230-318), sem campo hex (escolha_de_cor.dart:160-168 e decimal), sem conta-gotas e sem paleta editavel (escolha_de_cor.dart:41-54 e uma const).
- divergencia: Nao mensuravel: sem referencia AM, nao ha divergencia a declarar.

### Extensoes do Aurea nesta superficie

O PDF manda preservar e dar destino contextual — nunca apagar.

- Cor por TIPO de camada, com ficha diferente em cada um: texto (painel_de_cor.dart:110-118), forma como item de pintura (:119, :187-365), particulas (:120-156) e Elemento 3D (:157-168). O AM da pagina 13 mostra uma superficie so. Destino: manter o switch por tipo dentro da mesma moldura contextual, com o mesmo cabecalho de familia.
- Cor no FIM DA VIDA das particulas, atras de um interruptor que so aparece quando ligada (painel_de_cor.dart:129-155). Nao tem equivalente AM. Destino: continua como segundo seletor de cor da mesma familia, abaixo do primeiro.
- Gradiente com N cores intermediarias, angulo por fita e alternancia radial/linear (painel_de_cor.dart:244-311). Destino natural: e o conteudo do modo 'gradiente' da fileira de tipos que falta — ou seja, esta extensao e o que da corpo ao seletor exigido pelo AM.
- Bloco de CONTORNO completo dentro do painel de cor: criar (ensureShapeStroke), cor, espessura e opacidade animaveis com rail e curva por trecho, e remover (painel_de_cor.dart:319-363). O AM poe isso na familia Borda e sombra / subpainel Traco. Destino: mover para 'borda', preservando todas as capacidades.
- Curva de easing POR TRECHO nas trilhas de item de forma, incluindo aplicar a todos os trechos (painel_de_cor.dart:60-82, via setShapeItemTrackSegmentEase e applyEaseToAllShapeItemTrackSegments). Nao observado no AM. Destino: continua no rail esquerdo, terceiro botao.
- Avisos de contexto escritos em portugues claro quando o modelo e ambiguo: 'Ajustando a primeira pintura desta camada' (painel_de_cor.dart:224-228), 'Esta forma nao tem pintura' (:312-317), 'Esta camada tem mais de um contorno' (:327-331), 'Esta camada nao tem cor propria' (:169). Sao a unica coisa que explica a lista plana de itens de forma. Destino: preservar no topo do painel, acima da fileira de modos.
- PainelDaComposicao: cor de FUNDO da composicao, aberta pelo nome do projeto e nao por camada nenhuma, com o aviso de que ela sai no arquivo exportado e de que PNG em sequencia da fundo transparente (painel_de_cor.dart:374-402). Nao pertence a nenhuma camada, entao nao cabe na familia AM. Destino: permanece no contexto de Projeto (p.7), nunca no de camada.
- Edicao dos tres canais por FITA relativa mais campo digitavel, calibrada para cobrir 0..255 numa passada da largura do painel (escolha_de_cor.dart:102-118), coerente com a regra do app de nao usar deslizante. Destino: convive com a leitura hexadecimal do AM — hex para ler e colar, fitas para ajustar com o dedo.
- Rotulos de acessibilidade com o DONO no nome, para distinguir os tres seletores de um gradiente na mesma ficha (escolha_de_cor.dart:90-98, :199-208) e amostra escolhida marcada por anel em vez de tique, para nao sumir no branco e no amarelo (escolha_de_cor.dart:218-224). Destino: preservar integralmente ao refazer a linha de cor e as amostras.

### Correcoes do conferente (1)

- **Quatro seletores graficos de TIPO DE PREENCHIMENTO no alto do painel, com o modo de cor solida selecionado.**
  - afirmado: "Uma forma criada pelo app so pode ser chapada; gradiente e contorno-como-pintura sao inalcancaveis pela interface."
  - verdade: A metade do gradiente esta certa (nenhum ShapeGradientFill nasce da UI: as unicas construcoes sao project_store.dart:617 e os templates). A metade do CONTORNO esta errada. O proprio painel de cor tem a porta: lib/src/features/editor/presentation/widgets/painel_de_cor.dart:321-325 desenha _Acao(icone: Icons.border_color_rounded, rotulo: 'Adicionar contorno', aoTocar: () => c.ensureShapeStroke(l.id)), e lib/src/features/editor/application/editor_controller.dart:7219-7232 CRIA um ShapeStroke novo (ShapeStroke(color: ..., width: AnimatedDouble(width)) inserido em contents) quando a camada ainda nao tem um. Depois de criado, a UI ainda edita cor (updateShapeStroke, painel_de_cor.dart:333-338), espessura e opacidade (trilha 'width' e 'opacity', painel_de_cor.dart:339-352) e o remove (removeShapeStroke, painel_de_cor.dart:353-361). ShapeStroke conta como pintura no motor pelo mesmo criterio dos outros (editor_controller.dart:6783, 6801, 7265: i is ShapeFill || i is ShapeStroke || i is ShapeGradientFill). Portanto uma forma criada pelo app NAO fica so chapada: ela alcanca chapada + contorno. O que continua sem porta e so o gradiente — e o gradiente como MODO substituto do preenchimento, que e a divergencia real. O veredito da linha (a fileira de quatro modos nao existe; o switch de painel_de_cor.dart:230-318 escolhe o layout pelo item que a camada JA tem, sem estado selecionado e sem troca) permanece correto.

---

## Transformacao: pad de posicao, dial de rotacao, dimensoes vinculadas/independentes, skew (PDF paginas 16-19)

Li as paginas 2, 3, 7 e 16-19 da especificacao (inclusive os quadros p16_0, p16_1, p17_0, p18_0, p18_1 e p19_1) e abri o codigo real em C:/Users/SnyX/Documents/Projetos - Claude/Aurea/lib/src/features/editor/. A arquitetura do painel de transformacao ja corresponde ao AM: quatro submodos num rail direito verde, rail esquerdo com voltar/keyframe/curva, almofada com cantos em L e a frase identica "Deslize aqui para mover a camada", dial acumulando voltas sem zerar em 360, campos "Largura"/"Altura" com corrente, "X Skew"/"Y Skew" com duas reguas e duas casas decimais. Quatro divergencias merecem trabalho: (1) ESTRUTURAL — trocar de submodo descarta a edicao pendente (editor_screen.dart:153-161 lista modoDeTransformacaoProvider entre os focos que chamam descartarPendencia), ou seja, navegacao alterando dado, contra a invariante da p.7 e o P da p.16/17; (2) ESTRUTURAL — o estado desvinculado das dimensoes nao tem a segunda regua e a Altura so muda digitando, porque painel_de_transformacao.dart:307-320 monta sempre uma fita ligada a scaleX; (3) MEDIA — os campos rotulados Largura/Altura mostram porcentagem de escala, que a p.18 proibe expressamente, e o dominio nem tem largura/altura (layer.dart:78-79 so tem scaleX/scaleY); (4) MEDIA — o dial nao tem o arco verde nem o indicador de voltas "1x", e o centro mostra o total bruto (540°) onde o AM mostra "1x" + "180°". Somam-se: nao existe guia de alinhamento no palco durante o arrasto, a fita ativa do par de skew e fixa em X, e o campo z fica sem sublinhado em camada 2D. Nenhum arquivo foi editado.

### `!!` Trocar para rotacao e voltar nao pode reinicializar X/Y/Z; a troca de submodo preserva dimensoes, vinculo, rotacao e posicao, e a troca de painel nao gera alteracao no projeto.

- evidencia: P (p.16 e p.18) + P invariantes da p.7
- hoje: C:/Users/SnyX/Documents/Projetos - Claude/Aurea/lib/src/features/editor/presentation/editor_screen.dart:153-161: modoDeTransformacaoProvider esta na lista de focos que chamam _descartarPendencia; editor_controller.dart:5242-5245 joga fora a EdicaoPendente. Valores nao animados vao para a base e sobrevivem (editor_controller.dart:4859-4871, 4911-4941); o vinculo vive num provider global (painel_de_transformacao.dart:26).
- divergencia: Em propriedade ANIMADA com o cabecote fora de um keyframe, a edicao fica pendente (editor_controller.dart:280-290) e TROCAR DE SUBMODO a descarta: o valor que a pessoa acabou de arrastar some ao ir para rotacao e voltar. Navegacao alterando dado, que e o que a p.7 proibe.
- mudanca: Tirar modoDeTransformacaoProvider da lista de editor_screen.dart:153-161 (o losango do rail continua mirando a propriedade certa via propDoModo) ou, melhor, guardar a pendencia por camada+instante em vez de descarta-la na troca de submodo.
- risco: A pendencia existe para o losango nao mentir (docs/keyframe-explicito.md). Mante-la viva na troca de modo faz o losango de OUTRO modo olhar para uma pendencia que nao e dele — precisa ficar amarrada a propriedade de origem, senao o diamante da rotacao cravaria a posicao.
- teste: Teste de widget: camada com position animada, cabecote entre dois keyframes, arrastar a almofada, trocar para 'Girar', voltar para 'Mover' e exigir que o campo x mostre o valor arrastado (e que o rail continue vazado).

### `!!` Estado DESVINCULADO: aparecem DUAS reguas e cada dimensao se ajusta independentemente — mexer na largura nao sobrescreve a altura.

- evidencia: V 01:08 (p.18, imagem p18_1: duas reguas, 257,3 e 658,7)
- hoje: C:/Users/SnyX/Documents/Projetos - Claude/Aurea/lib/src/features/editor/presentation/widgets/painel_de_transformacao.dart:307-320 mostra SEMPRE uma unica fita, rotulada 'Escala' e alimentada so por l.scaleX; :317 chama _escalar(v/100) sem eixoY, ou seja, destravada ela edita APENAS scaleX (editor_controller.dart:4923-4931). A Altura destravada so muda digitando (:210).
- divergencia: Estrutural: no estado desvinculado falta a segunda regua, e nao ha superficie de arrasto para a Altura. O painel destravado do Aurea nao corresponde ao quadro de 01:08.
- mudanca: No modo escalar, quando escalaTravadaProvider for falso, montar duas FitaDeAjuste empilhadas exatamente como o modo inclinar faz (painel_de_transformacao.dart:321-349): a de cima escrevendo largura (eixoY:false, ativa:true) e a de baixo altura (eixoY:true, ativa:false), com altura 62 cada.
- risco: Duas fitas com dois dedos ao mesmo tempo podem abrir/fechar lotes de desfazer cruzados — a FitaDeAjuste ja se defende com _partida nulavel (fita_de_ajuste.dart:95-124), mas o teste precisa cobrir. O painel tambem perde altura util; conferir que as duas fitas cabem sem estourar (memoria: painel de 372 px que nunca existiu).
- teste: Teste de widget: destravar a corrente, exigir find.bySemanticsLabel('Ajustar Largura') e ('Ajustar Altura'); arrastar a de baixo e exigir scaleY mudado e scaleX intacto.

### `! ` Campos X, Y e Z no topo do subpainel de posicao, com uma casa decimal e valor sublinhado.

- evidencia: V 00:57 (leitura 540,0 / 540,0 / 0,0) e V 00:59 (587,7 / 575,3 / 0,0)
- hoje: C:/Users/SnyX/Documents/Projetos - Claude/Aurea/lib/src/features/editor/presentation/widgets/painel_de_transformacao.dart:115-145 monta x, y, z; campo_de_valor.dart:19-35 formata pt-BR com casas fixas (padrao 1) e :200-203 so sublinha quando ha aoDigitar; a faixa dos campos tem 44 px (painel_de_transformacao.dart:88).
- divergencia: O campo z so e editavel em camada 3D (painel_de_transformacao.dart:140-142 passa aoDigitar nulo quando !l.is3D). Sem callback ele perde o sublinhado, ou seja, em camada 2D o Aurea mostra tres caixas mas so duas se tocam; no quadro do AM as tres aparecem sublinhadas.
- mudanca: Deixar z sempre digitavel: chamar editPositionZ tambem em camada 2D (ligando o 3D da camada ao receber um z != 0, ou aceitando z sem exigir is3D), preservando o sublinhado.
- risco: Escrever z numa camada 2D pode nao ter efeito no motor e criar campo que aceita numero e nao muda nada — o defeito que auditoria_correcoes_test.dart ja pegou no campo Altura. Se o motor 2D ignora z, a alternativa e manter a leitura e nao prometer edicao (e entao anotar como divergencia assumida).
- teste: Teste de widget: montar 'transformar' em camada 2D, digitar 120 em 'Valor de z' e exigir positionZ.valueAt == 120 (ou, na alternativa, exigir que o texto NAO venha sublinhado).

### `! ` Guias de alinhamento aparecem no preview durante a movimentacao.

- evidencia: V 00:57–01:00 ("guias aparecem durante o alinhamento")
- hoje: NAO EXISTE. Varredura em lib/src/features/editor/presentation/widgets/ nao acha guia, snap ou linha de alinhamento; palco_de_previa.dart:6 lista guias apenas num comentario de intencao, sem implementacao.
- divergencia: O Aurea move a camada sem nenhum feedback de alinhamento no palco.
- mudanca: Pintar no palco_de_previa, so enquanto ha arrasto de posicao, linhas de centro horizontal/vertical da composicao (e opcionalmente bordas) quando o centro da camada entra numa tolerancia de poucos pixels.
- risco: Custo de repintura no palco durante o arrasto (memoria 'Aurea GPU por primitiva': nada de saveLayer/MaskFilter por quadro); e o risco de transformar guia em snap magnetico, que o video nao mostra e mudaria o valor escrito.
- teste: Teste do pintor: arrastar a posicao ate o centro e contar as chamadas de drawLine do overlay (2 no centro, 0 fora da tolerancia); guia nunca altera o valor gravado.

### `! ` Arco de destaque verde/ciano acompanhando o angulo no aro do dial.

- evidencia: V 01:01 e V 01:02,5 (p.17, imagem p17_0)
- hoje: NAO EXISTE. C:/Users/SnyX/Documents/Projetos - Claude/Aurea/lib/src/features/editor/presentation/widgets/dial_de_angulo.dart:308-318 desenha um unico circulo inteiro em AmColors.muted com alpha .35 e nada mais; nao ha drawArc em lugar nenhum do arquivo.
- divergencia: O aro do Aurea e cinza uniforme: o angulo so aparece na posicao do botao e no numero. O AM pinta o trecho percorrido em verde/ciano, que e o que da a leitura de relance e mostra onde a volta comecou.
- mudanca: Em _PinturaDoDial, desenhar canvas.drawArc do zero ate graus (mod 360, com sentido correto) em AmColors.accent, largura ~3, por cima do aro cinza, e so depois o botao branco.
- risco: Baixo. Cuidar do sinal (angulo negativo desenha para o outro lado) e do angulo nao finito; um drawArc por quadro nao pesa (nao usa saveLayer).
- teste: Teste do pintor contando as chamadas do canvas: 1 drawCircle do aro, 1 drawArc, 1 drawCircle do botao; e um dump visual em 0, 43, 153 e 259 graus comparado a p17_0.

### `! ` A UI distingue voltas acumuladas do angulo dentro da volta: indicador "1x" acompanhando o angulo.

- evidencia: V 01:02,5 (p.17: sequencia 0, 43, 153, 259 e depois 1x + outro angulo; imagem p17_0 mostra "1x" acima de "35°")
- hoje: NAO EXISTE o indicador. C:/Users/SnyX/Documents/Projetos - Claude/Aurea/lib/src/features/editor/presentation/widgets/dial_de_angulo.dart:189-194 (_texto) escreve o TOTAL acumulado: uma volta e meia sai como "540°", nunca como "1x" + "180°".
- divergencia: O numero central e o total bruto; nao ha separacao entre voltas e angulo dentro da volta.
- mudanca: Acima da caixa do numero, mostrar (graus/360).truncate() como "Nx" quando |graus| >= 360, e passar a escrever no centro graus.remainder(360). O valor mandado por aoMudar continua sendo o total.
- risco: Alto se o texto virar a fonte da verdade: hoje o rotulo de acessibilidade e os testes leem o texto do centro (dial_de_angulo.dart:216 value: texto). Trocar o texto sem trocar o valor pode fazer teste e leitor de tela anunciarem 180 onde ha 540. O campo digitavel do modo 3D tambem precisa continuar mostrando o total.
- teste: Teste de widget: girar 1,5 volta e exigir find.text('1x') e find.text('180°') na tela, e ao mesmo tempo rotation.valueAt == 540 no projeto.

### `! ` Girar continuamente, atravessar uma volta, voltar ao modo posicao e retornar sem salto nem perda de estado.

- evidencia: P, aceite funcional (p.17)
- hoje: C:/Users/SnyX/Documents/Projetos - Claude/Aurea/lib/src/features/editor/presentation/widgets/dial_de_angulo.dart:125-134 recomeca de widget.angulo a cada gesto (sem salto); o modo vive no provider global (painel_de_transformacao.dart:17), entao voltar recupera o mesmo modo e valor.
- divergencia: Mesma ressalva da linha da pendencia: com rotacao animada fora de keyframe, sair do modo girar descarta a edicao.
- mudanca: Coberta pela mudanca da linha da pendencia (editor_screen.dart:153-161).
- risco: Ver aquela linha.
- teste: Girar, ir para 'Mover', voltar para 'Girar' e exigir o mesmo numero no centro e a mesma posicao do botao.

### `! ` Os valores das dimensoes respeitam a unidade real do motor; nao mostrar porcentagem se o controle corresponde a dimensoes.

- evidencia: V 01:04 (200,0 / 200,0) e V 01:08 (257,3 / 658,7) + P explicito na p.18
- hoje: C:/Users/SnyX/Documents/Projetos - Claude/Aurea/lib/src/features/editor/presentation/widgets/painel_de_transformacao.dart:190-211 mostra l.scaleX.valueAt*100 com sufixo '%' sob os rotulos 'Largura' e 'Altura'. No dominio nao existe largura/altura: layer.dart:78-79 so tem scaleX/scaleY, base 1 (layer.dart:57-58).
- divergencia: O Aurea chama de Largura/Altura um numero que e porcentagem de escala — exatamente o que a p.18 proibe. O AM mostra dimensao (257,3 / 658,7), nao 100%.
- mudanca: Duas saidas honestas: (a) converter para dimensao real na leitura e na escrita — largura = tamanho intrinseco da camada * scaleX, com a escrita voltando por scaleX = valor/intrinseco; (b) se o motor nao expuser tamanho intrinseco por tipo de camada, trocar os rotulos para 'Escala X'/'Escala Y' e assumir a divergencia com o AM.
- risco: Alto na saida (a): cada tipo de camada (texto, forma, video, imagem, grupo, nulo) tem um tamanho intrinseco diferente e alguns nao tem nenhum; dividir por zero ou por um tamanho desconhecido escreveria NaN na trilha de escala (a regra de QA manda peneirar NaN antes de salvar). Alem disso a conversao nao pode reescrever keyframes ja gravados.
- teste: Teste por tipo de camada: uma imagem 400x300 com scaleX=2 mostra 'Largura 800,0'; digitar 200 devolve scaleX=0,5; camada sem tamanho intrinseco nao mostra NaN nem quebra o painel.

### `! ` A regua em edicao se distingue da outra (linha central verde na ativa, branca na outra).

- evidencia: V 01:14 (p.19: X Skew em verde, Y Skew apagado; mesma marca no par de dimensoes em p18_1)
- hoje: C:/Users/SnyX/Documents/Projetos - Claude/Aurea/lib/src/features/editor/presentation/widgets/fita_de_ajuste.dart:233-241 pinta accent na ativa e cabecote (branco) na outra — mas painel_de_transformacao.dart:343 fixa ativa:false na fita Y para sempre.
- divergencia: O sinal existe e nunca muda: mexer na inclinacao Y nao acende a fita Y. O comentario do proprio arquivo (:340-342) promete que a marca diz qual o dedo mexeu, e ela nao diz. No AM o valor do eixo inativo tambem sai BRANCO no campo de cima (0,00°), enquanto o Aurea pinta os dois campos em accent (campo_de_valor.dart:195).
- mudanca: Guardar no estado do painel qual eixo foi tocado por ultimo (nasce em X) e passar ativa: eixo==X / eixo==Y; espelhar no CampoDeValor uma cor 'inativa' (AmColors.text) para o eixo que nao esta em edicao.
- risco: Baixo, mas o mesmo estado precisa valer para o par de dimensoes desvinculado, senao ficam duas regras diferentes para o mesmo desenho. Nao deixar o realce virar um segundo conceito de selecao no contrato de estado.
- teste: Teste do pintor/dump: arrastar a fita Y e exigir que a linha central de baixo saia em accent e a de cima em branco.

### `! ` Separacao obrigatoria: skew nao muda o tempo e velocidade nao muda a geometria; sao paineis diferentes na mesma camada e no mesmo contexto de navegacao.

- evidencia: V 01:17,5–01:19 + P (p.19)
- hoje: C:/Users/SnyX/Documents/Projetos - Claude/Aurea/lib/src/features/editor/presentation/widgets/controles_da_camada.dart:111 abre PainelDeVelocidade como categoria 'velocidade', totalmente fora do PainelDeTransformacao; a categoria so existe para VideoLayer/AudioLayer (painel_da_camada.dart:173-178).
- divergencia: A separacao esta correta. Diverge o CAMINHO: no AM a velocidade abre pelo controle com cara de velocimetro na BARRA TEMPORAL; no Aurea e um tile na grade de categorias da camada. Essa entrada pertence a superficie da timeline/grade, nao a este painel.
- mudanca: Fora desta superficie: acrescentar o botao de velocimetro na barra temporal da camada selecionada, apontando para a mesma categoria 'velocidade'. Nao mover nada para dentro do painel de transformacao.
- risco: Duplicar a porta pode criar dois caminhos com estados diferentes; devem apontar para o mesmo categoriaAbertaProvider.
- teste: Da superficie da timeline: tocar o velocimetro abre PainelDeVelocidade com a mesma camada e o mesmo playhead.

### `~ ` Rail direito com quatro seletores verticais na ordem posicao, rotacao, dimensoes, skew; o ativo com destaque verde.

- evidencia: V 00:57 e V 01:01 (PDF p.16, imagens p16_0/p17_0)
- hoje: C:/Users/SnyX/Documents/Projetos - Claude/Aurea/lib/src/features/editor/presentation/widgets/painel_de_transformacao.dart:94-105 (ordem Mover, Girar, Escalar, Inclinar) e rails_do_painel.dart:111-160 (largura 40, quadrado 36, fundo AmColors.chip + icone AmColors.accent #1ED6B1 no vigente).
- divergencia: Ordem, coluna, largura e destaque verde correspondem. So os glifos diferem: AM usa cruz de setas, seta circular sobre quadrado, seta diagonal em quadrado e paralelogramo; o Aurea usa Icons.open_with / rotate_right / aspect_ratio / transform.
- mudanca: Trocar os quatro IconData por icones desenhados iguais aos da referencia (paralelogramo para skew, seta diagonal em moldura para dimensoes).
- risco: Baixo: o rotulo de acessibilidade ('Mover','Girar','Escalar','Inclinar') e o ancoradouro dos testes e nao muda.
- teste: Teste de widget que acha os quatro por find.bySemanticsLabel e um dump visual do painel comparado ao quadro p16_0.

### `~ ` Rail esquerdo com voltar, controle de keyframe e entrada de curva, cujo estado depende da propriedade e do tempo.

- evidencia: V 00:57 (PDF p.16, coluna esquerda de p16_0/p17_0)
- hoje: C:/Users/SnyX/Documents/Projetos - Claude/Aurea/lib/src/features/editor/presentation/widgets/rails_do_painel.dart:56-103 (voltar, keyframe, curva, largura 46); o alvo por modo vem de controles_da_camada.dart:88-96 via propDoModo/nomeDoModo (controles_da_camada.dart:157-169).
- divergencia: Estrutura e estados corretos. O icone de keyframe e Icons.change_history (TRIANGULO) em rails_do_painel.dart:84-86, enquanto o AM e a propria doc interna falam em losango.
- mudanca: Trocar change_history_rounded/outlined por um losango pintado (cheio/vazado) mantendo os tres estados aceso/meioAceso/apagado.
- risco: Baixo; nenhum teste depende do IconData, apenas dos rotulos 'Marcar keyframe aqui' / 'Tirar o keyframe daqui'.
- teste: Dump visual do rail nos tres estados + o teste existente de keyframe explicito.

### `~ ` Dimensoes: campos "Largura" e "Altura" com um botao de vinculo entre eles.

- evidencia: V 01:04 e V 01:08 (p.18, imagens p18_0/p18_1)
- hoje: C:/Users/SnyX/Documents/Projetos - Claude/Aurea/lib/src/features/editor/presentation/widgets/painel_de_transformacao.dart:185-213 usa exatamente os rotulos 'Largura' e 'Altura' com _Corrente (:384-421) entre eles, mesma altura de caixa (24 px).
- divergencia: So o desenho do botao: no AM a corrente e uma caixa arredondada nos DOIS estados, com o glifo mudando (elos ligados / elos partidos); no Aurea a caixa so tem fundo quando travada e vira contorno quando solta (painel_de_transformacao.dart:409-413).
- mudanca: Manter a caixa em ambos os estados, trocando so o glifo e a cor do icone.
- risco: Baixo; o rotulo de acessibilidade ('Soltar largura e altura' / 'Travar largura e altura') e o ancoradouro dos testes e nao muda.
- teste: test/controles_da_camada_test.dart 'escalar tem a corrente' ja cobre o estado; somar um dump visual dos dois estados.

### `ok` Posicao e um SUBMODO dentro de "Movimentacao e transformacao", nao uma janela global de propriedades.

- evidencia: V 00:57–01:00 (PDF p.16)
- hoje: C:/Users/SnyX/Documents/Projetos - Claude/Aurea/lib/src/features/editor/presentation/widgets/controles_da_camada.dart:82 abre PainelDeTransformacao so quando categoriaId=='transformar'; painel_de_transformacao.dart:15 define os quatro modos e :17 o provider do modo vigente. Titulo da barra: painel_da_camada.dart:549 'Movimentacao e transformacao'.
- divergencia: NENHUMA

### `ok` Area ampla com cantos marcados e o texto "Deslize aqui para mover a camada", que aceita arrasto continuo.

- evidencia: V 00:57–01:00 (PDF p.16)
- hoje: C:/Users/SnyX/Documents/Projetos - Claude/Aurea/lib/src/features/editor/presentation/widgets/almofada_de_arrasto.dart:55 usa exatamente a mesma frase; :190-231 pinta os quatro cantos em L; :135-140 arrasto continuo com pan; :146-152 ocupa a area inteira do pai.
- divergencia: NENHUMA

### `ok` O pad nao pode disputar o gesto com o scroll da timeline.

- evidencia: V 00:57–01:00 (P na p.16)
- hoje: C:/Users/SnyX/Documents/Projetos - Claude/Aurea/lib/src/features/editor/presentation/widgets/painel_da_camada.dart:524-537 monta ControlesDaCategoria dentro de um Expanded, sem SingleChildScrollView nem ListView em volta; o painel tem altura fixa (memoria 'Aurea alturas fixas', beta 57).
- divergencia: NENHUMA

### `ok` O preview atualiza continuamente durante o gesto, com a posicao temporal conservada e um historico consistente do gesto.

- evidencia: P (p.16)
- hoje: C:/Users/SnyX/Documents/Projetos - Claude/Aurea/lib/src/features/editor/presentation/widgets/painel_de_transformacao.dart:253-264: aoMover escreve editPosition a cada quadro com widget.tempo; _abrirLote/_fecharLote (:72-74) chamam beginGesture/endGesture, e o undo volta o arrasto inteiro.
- divergencia: NENHUMA

### `ok` Dial circular grande com manipulador branco e leitura numerica central em caixa; nao reduzir a um slider de -180 a 180.

- evidencia: V 01:00,5–01:03,5 (p.17)
- hoje: C:/Users/SnyX/Documents/Projetos - Claude/Aurea/lib/src/features/editor/presentation/widgets/dial_de_angulo.dart:293-325 pinta circulo + botao branco (AmColors.cabecote, raio 15); :251-286 e a caixa central com o numero em AmColors.accent, 20 px, tabular.
- divergencia: NENHUMA na estrutura. (O AM mostra o numero em verde na mesma caixa; o Aurea idem.)

### `ok` O calculo interno nao perde as voltas ao passar por 360; animacao e undo conservam o valor angular completo, nao o texto normalizado.

- evidencia: P (p.17)
- hoje: C:/Users/SnyX/Documents/Projetos - Claude/Aurea/lib/src/features/editor/presentation/widgets/dial_de_angulo.dart:136-159: _total nasce do angulo vigente e ACUMULA passos, com a correcao de +-180 na virada do atan2; :219-222 amarra o gesto a aoComecar/aoTerminar, e painel_de_transformacao.dart:265-272 embrulha em beginGesture/endGesture.
- divergencia: NENHUMA

### `ok` Digitacao direta do angulo e menu contextual da propriedade nao foram filmados: nao inventar janela numerica como se fosse observada.

- evidencia: N (p.17); tambem N para o teclado numerico na p.16
- hoje: O Aurea tem digitacao exata em todo campo: C:/Users/SnyX/Documents/Projetos - Claude/Aurea/lib/src/features/editor/presentation/widgets/campo_de_valor.dart:229-248 abre um CupertinoAlertDialog com CupertinoTextField. No modo girar 2D nao ha campo no topo (painel_de_transformacao.dart:153 devolve SizedBox.shrink), so no 3D (:154-184).
- divergencia: Nao ha divergencia a corrigir: o requisito continua N. O dialogo do Aurea e extensao, nao paridade.

### `ok` Estado VINCULADO: um gesto mantem a proporcao entre largura e altura, e o painel mostra UMA regua.

- evidencia: V 01:04 (p.18, imagem p18_0: uma regua com linha central verde)
- hoje: C:/Users/SnyX/Documents/Projetos - Claude/Aurea/lib/src/features/editor/presentation/widgets/painel_de_transformacao.dart:307-320 mostra uma FitaDeAjuste unica; :370-374 com a corrente travada chama editScaleUniform, que escreve scaleX e scaleY juntos (editor_controller.dart:4911-4921). A linha central sai em AmColors.accent (fita_de_ajuste.dart:233-241).
- divergencia: NENHUMA

### `ok` A troca de submodo preserva o estado do vinculo, e desfazer recupera os valores corretos com o preview correspondente.

- evidencia: V/P (p.18, linha "Retorno / undo")
- hoje: C:/Users/SnyX/Documents/Projetos - Claude/Aurea/lib/src/features/editor/presentation/widgets/painel_de_transformacao.dart:26 escalaTravadaProvider e um StateProvider global (sobrevive a troca de modo e a troca de camada); o undo em lote vem de beginGesture/endGesture (:72-74) sobre _mutate (editor_controller.dart:274+).
- divergencia: NENHUMA para o vinculo e para o undo do gesto. A perda de valor no caso animado esta na linha da pendencia.

### `ok` Skew e o QUARTO submodo de transformacao, com campos "X Skew" e "Y Skew" em graus.

- evidencia: V 01:11,5–01:14,5 (p.19; 34,50° em X com 0,00° em Y; imagem p19_1 mostra 33,60° / 0,00°)
- hoje: C:/Users/SnyX/Documents/Projetos - Claude/Aurea/lib/src/features/editor/presentation/widgets/painel_de_transformacao.dart:214-234 usa os rotulos 'X Skew' e 'Y Skew', casas: 2 e sufixo '°' — a mesma escrita da referencia; e o quarto item do rail (:99).
- divergencia: NENHUMA

### `ok` Duas reguas no painel de skew, com a selecao verde na coluna direita.

- evidencia: V 01:14 (p.19, imagem p19_1: duas reguas empilhadas)
- hoje: C:/Users/SnyX/Documents/Projetos - Claude/Aurea/lib/src/features/editor/presentation/widgets/painel_de_transformacao.dart:321-349 empilha duas FitaDeAjuste (altura 62 cada); o rail direito marca 'Inclinar' com AmColors.accent (rails_do_painel.dart:146-153).
- divergencia: NENHUMA

### `ok` Skew mantem um eixo por controle, com feedback no preview e integracao com keyframes; nao tratar como rotacao, perspectiva livre ou escala.

- evidencia: P (p.19)
- hoje: C:/Users/SnyX/Documents/Projetos - Claude/Aurea/lib/src/features/editor/application/editor_controller.dart:5014-5032 tem editSkewX e editSkewY separados, cada um so na sua trilha (layer.dart:88-89); o rail mira LayerProp.skew (controles_da_camada.dart:161) e o preview repinta a cada quadro do arrasto.
- divergencia: NENHUMA

### Extensoes do Aurea nesta superficie

O PDF manda preservar e dar destino contextual — nunca apagar.

- Terceiro eixo de posicao: campo z e editPositionZ (painel_de_transformacao.dart:134-143, editor_controller.dart:7521). O AM so mostra x/y/z com z sempre 0,0 e nao demonstra edicao — o destino contextual e manter o campo, mas so ele deve ganhar a regra 3D.
- Modo girar em camada 3D com TRES dials lado a lado (X, Y, Z) mais tres campos digitaveis no topo (painel_de_transformacao.dart:154-184 e 274-306; dial_de_angulo.dart:88-102 modo compacto). O AM tem um dial so. Destino: manter atras do interruptor de camada 3D, sem mudar o painel 2D.
- Digitacao exata em qualquer campo por dialogo Cupertino com teclado numerico assinado/decimal e texto ja selecionado (campo_de_valor.dart:229-334). No AM isso e N — preservar como extensao declarada, nao como paridade.
- Ganho de arrasto proporcional a composicao na almofada: outputWidth/360 (painel_de_transformacao.dart:252), para uma passada de dedo cobrir a largura do quadro seja ele 720 ou 4096. O AM nao publica ganho nenhum.
- A FitaDeAjuste relativa e infinita, sem faixa inventada, reusada em escala, inclinacao e parametros de efeito (fita_de_ajuste.dart:23-72). O AM mostra reguas so na transformacao; a generalizacao e do Aurea.
- Keyframe explicito com edicao pendente e losango que nunca mente (editor_controller.dart:78-100 e 5219-5245, docs/keyframe-explicito.md). O AM nao demonstra esse contrato; a extensao precisa sobreviver a correcao da troca de submodo.
- Um gesto = um passo de desfazer (beginGesture/endGesture em painel_de_transformacao.dart:72-74 e a coalescencia de 450 ms em editor_controller.dart:274+).
- editScaleUniform escrevendo os dois eixos de uma vez e a corrente nascendo TRAVADA por padrao (painel_de_transformacao.dart:26 e editor_controller.dart:4911). O video nao mostra qual e o estado inicial do vinculo no AM.
- Rotulos de acessibilidade e semantica em todos os controles ('Mover a camada', 'Girar a camada', 'Ajustar Inclinacao X', 'Soltar largura e altura'), que sao tambem os ancoradouros dos testes de widget. Nenhuma reconstrucao pode remove-los sem quebrar test/controles_da_camada_test.dart, test/auditoria_correcoes_test.dart e test/camada_3d_test.dart.
- Defesas contra valor quebrado: NaN/infinito viram zero na leitura (campo_de_valor.dart:19-35), sao recusados na digitacao (:47-63) e nao contaminam o gesto da fita (fita_de_ajuste.dart:108) nem do dial (dial_de_angulo.dart:132).

### Correcoes do conferente (1)

- **Trocar para rotacao e voltar nao pode reinicializar X/Y/Z; a troca de submodo preserva dimensoes, vinculo, rotacao e posicao, e a troca de painel nao gera alteracao no projeto.**
  - afirmado: Divergencia: em propriedade ANIMADA com o cabecote fora de um keyframe a edicao fica pendente (editor_controller.dart:280-290) e trocar de submodo a descarta (editor_screen.dart:153-161 + descartarPendencia em :5242-5245) — 'o valor que a pessoa acabou de arrastar some ao ir para rotacao e voltar. Navegacao alterando dado, que e o que a p.7 proibe.'
  - verdade: As citacoes de linha estao corretas, mas a conclusao inverte a regra citada. O que a troca de submodo joga fora nao e dado do projeto: em editor_controller.dart:280-291 o _mutate FAZ RETURN antes de tocar em `state` quando ha recusa — a EdicaoPendente e um projeto paralelo guardado num StateProvider (:100), e projetoVisivelProvider (:108-111) existe exatamente para separar 'o que se ve' de 'o que esta gravado' (o comentario diz que timeline, rail, editor de curva e exportacao leem editorControllerProvider). Logo descartarPendencia (:5242-5245) nao escreve no projeto, nao empilha undo e nao apaga keyframe nenhum: a troca de painel gera ZERO alteracao no projeto, que e o que a p.7 exige, e o que a p.22 reforca ('Voltar de painel nao cria nem apaga chaves'). Tambem nao ha reinicializacao: apos o descarte o painel volta a mostrar o valor interpolado da propria animacao no cabecote (l.position.valueAt(_local)), nao 0 nem o default — a p.16 proibe reinicializar X/Y/Z, e eles continuam os mesmos de antes e depois do arrasto. E a segunda clausula a propria matriz ja concede em 'hoje' (base sobrevive em :4859-4871/:4911-4941; vinculo em provider global, painel_de_transformacao.dart:26). Nenhuma das tres clausulas da exigencia foi refutada: o caso construido e a perda de uma PROPOSTA de edicao que, pelo modelo explicito de keyframe (recusa em :135-145 via aceitaEdicaoEm, keyframe.dart:653; cravada por _cravarPendencia em :5220-5235), so entra no projeto quando a pessoa toca no losango — e o losango, apos a troca de submodo, mira outra propriedade.

---

## Velocidade (painel temporal) — PDF "AUREA / UI SOMENTE AM" rev.02, pagina 19 (secao 09 · TRANSFORMACAO E TEMPO), com as regras das paginas 2, 3, 7 e o contexto da pagina 12

A divergencia decisiva e estrutural e de UMA linha: no AM o velocimetro vive na BARRA TEMPORAL da camada selecionada (V 01:17.5, corroborado pela pg.12), e no Aurea Velocidade e um tile da grade de categorias (painel_da_camada.dart:173-178) — a barra temporal do AM simplesmente nao existe no Aurea (linha_do_tempo.dart nao tem nenhuma referencia a velocidade). Do painel para dentro, o que o AM mostra e curto: valor 1.00x, um slider com tartaruga/coelho e quatro opcoes graficas. O Aurea acerta o valor (1,00x, duas casas, sufixo x) e acerta a substituicao da grade com a selecao temporal preservada acima (editor_screen.dart:241-276), mas troca o slider absoluto por uma fita de arrasto relativa sem extremos marcados, troca as quatro opcoes graficas por cinco chips de texto, e depois continua: interruptor de tom, inversao, borrao, secao 'Quadros que faltam' e uma secao 'Rampas' com quatro presets — um mini-workspace de speed ramp que a propria pg.19 proibe neste painel. O motor esta certo e conectado (setClipSpeed guarda o fator, recalcula duracao e empurra o que vem depois), entao nada aqui e trabalho de engine: e ponto de entrada, forma do controle e realocacao das secoes extras. Um defeito de estado real foi encontrado de passagem: `recadoDaVelocidadeProvider` (painel_de_velocidade.dart:12) e global e nunca limpo, entao o recado de uma camada reaparece no painel de outra, quebrando a invariante da pg.7. Duas exigencias ficam N e assim permanecem: o significado das quatro opcoes graficas e a cobertura por tipo de camada.

### `!!` O painel de Velocidade e aberto por um controle com aparencia de velocimetro que fica NA BARRA TEMPORAL da camada selecionada, acima dos tiles — nao por um tile da grade de categorias.

- evidencia: V 01:17.5 (pg.19: "aberto pelo controle com aparencia de velocimetro na barra temporal"); corroborado por V 00:42–00:46 (pg.12: "Barra temporal: Velocidade, controles de corte/limites e audio aparecem acima dos tiles") e pelas grades de pg.11, onde Velocidade nao aparece como tile em nenhum tipo
- hoje: Velocidade e um TILE da grade de categorias: lib/src/features/editor/presentation/widgets/painel_da_camada.dart:173-178 (`if (camada is VideoLayer || camada is AudioLayer) const CategoriaDaCamada(id: 'velocidade', rotulo: 'Velocidade', icone: Icons.speed_rounded)`), despachado em lib/src/features/editor/presentation/widgets/controles_da_camada.dart:111 e titulado em painel_da_camada.dart:556. Barra temporal com velocimetro: NAO EXISTE — lib/src/features/editor/presentation/widgets/linha_do_tempo.dart nao tem nenhuma ocorrencia de speed/velocidade/velocimetro (grep 0 resultados nas 1503 linhas), e o unico Icons.speed_rounded do editor e o do tile.
- divergencia: O ponto de entrada esta em outro lugar da hierarquia. No AM o velocimetro pertence a barra temporal (mesmo nivel dos controles de corte/limites e audio); no Aurea ele so existe dentro da grade de categorias da camada, um nivel abaixo, e a barra temporal do AM nao existe.
- mudanca: Criar a barra de acoes temporais entre a linha do tempo e a grade (a mesma faixa que a pg.12 exige, com corte/limites e audio), e mover para ela o botao de velocimetro que abre `PainelDeVelocidade`. Manter `PainelDeVelocidade` como conteudo; trocar apenas quem o abre. Remover o tile 'velocidade' de `categoriasDaCamada` so depois que a barra existir, para nao deixar o painel sem porta.
- risco: O painel hoje e montado por `ControlesDaCategoria` (controles_da_camada.dart:105-120), que injeta `_ComRail` (rail esquerdo de voltar/keyframe) e `ProvedorDoRelogio`. Abrindo pela barra temporal e preciso continuar entrando no mesmo estado `EstadoDoPainel.categoria` com `categoriaAbertaProvider = 'velocidade'`, senao o `‹` do rail e o titulo da barra de cima (painel_da_camada.dart:556, editor_screen.dart:399) perdem o caminho de volta e a invariante da pg.7 ("nunca perder selecao ao abrir um submenu") cai. Os testes de test/velocidade_e_aparar_test.dart:206-231 dependem de `categoriasDaCamada(...)` conter 'velocidade' e quebram junto.
- teste: Teste de widget: selecionar uma camada, achar `find.bySemanticsLabel('Velocidade')` DENTRO da barra temporal (acima da grade, nao na grade), tocar, e esperar `find.byType(PainelDeVelocidade)` com `estadoDoPainelProvider == EstadoDoPainel.categoria`; e esperar que a grade de categorias nao contenha mais um cartao 'Velocidade'.

### `! ` O ajuste do valor e feito por um SLIDER, com tartaruga em uma ponta e coelho na outra.

- evidencia: V 01:18.0 (pg.19: "valor 1.00x e slider com tartaruga/coelho")
- hoje: lib/src/features/editor/presentation/widgets/painel_de_velocidade.dart:46-60 usa `LinhaDeParametro`, cujo controle de arrasto e a `FitaDeAjuste` (lib/src/features/editor/presentation/widgets/linha_de_parametro.dart:88-100). A propria doc da classe (linha_de_parametro.dart:20-24) diz que ela SUBSTITUIU um `Slider` de proposito: e relativa (`porPixel: .02`), nao absoluta, e nao desenha onde o valor esta no intervalo. Nao ha nenhum icone de tartaruga/coelho nem extremos marcados.
- divergencia: Controle de tipo diferente: fita relativa sem posicao no intervalo e sem marcadores de extremo, contra um slider absoluto com lento/rapido nas pontas. Quem olha nao ve onde 1.00x cai entre o minimo e o maximo.
- mudanca: Nesta superficie especifica, trocar a `FitaDeAjuste` por um slider absoluto sobre a faixa util (o motor limita em 0.1..10.0 — editor_controller.dart:3716), com icone de lento a esquerda e rapido a direita, mantendo o `CampoDeValor` para digitacao exata. Nao trocar a `FitaDeAjuste` nos outros paineis: la a decisao documentada continua valendo.
- risco: O clamp do motor e 0.1..10.0, mas a faixa util e ~0.25..4 (comentario em painel_de_velocidade.dart:51-53); um slider linear de 0.1 a 10 joga quase todo o curso acima de 1x e torna a camera lenta impossivel de ajustar com o dedo. Precisa de escala logaritmica ou de faixa 0.25..4 com o campo cobrindo o resto. Alem disso `setClipSpeed` recalcula duracao e empurra as camadas seguintes a cada quadro do arrasto (editor_controller.dart:3740-3757): sem `beginGesture`/`endGesture` em volta, o desfazer vira centenas de passos.
- teste: Teste de widget: arrastar o slider da esquerda para a direita e conferir que `clipSpeedOf` sobe monotonicamente e que a leitura acompanha; e que os semanticos de lento e rapido existem nas pontas. Teste de historico: um arrasto completo produz UM passo de desfazer.

### `! ` O painel mostra QUATRO opcoes graficas, alem do valor e do slider.

- evidencia: V 01:18.0 (pg.19: "Mostra quatro opcoes graficas, valor 1.00x e slider"). O significado de cada uma e N — o PDF diz explicitamente que "as quatro opcoes graficas precisam de validacao funcional; o video nao demonstra o significado de cada uma nem altera de forma comprovada a leitura 1.00x".
- hoje: lib/src/features/editor/presentation/widgets/painel_de_velocidade.dart:61-67: `_Escolhas(rotulo: 'Atalhos', itens: ['0,25x','0,5x','1x','2x','4x'])` — CINCO chips de TEXTO, nao quatro opcoes graficas. As quatro pecas graficas mais proximas sao as rampas (painel_de_velocidade.dart:138-151, `SpeedRampPreset.values` = impacto/heroi/bala/montagem, lib/src/features/editor/domain/cut.dart:204), que tambem sao botoes de texto e ficam em outra secao, so para video.
- divergencia: Contagem e forma: 5 chips textuais de atalho de fator no lugar de 4 opcoes graficas; e as 4 pecas que existem (rampas) sao de texto, estao em outra secao e nao aparecem para audio.
- mudanca: Reservar no painel a fileira de exatamente quatro opcoes graficas na posicao do AM (abaixo do valor/slider). NAO atribuir significado a elas a partir do video: manter a fileira ligada ao que o Aurea ja sabe fazer so depois de referencia AM adicional, e ate la nao inventar quatro icones decorativos. Os cinco atalhos de fator do Aurea sao extensao — ver `extensoesAurea`.
- risco: Preencher as quatro casas por adivinhacao (por exemplo mapeando-as nas quatro rampas) declara paridade sobre um item que o PDF marca como nao comprovado, e viola a regra da pg.3 ("buscar referencia AM correspondente antes de declarar paridade completa"). Alem disso rampa e coisa de video: em audio as quatro casas ficariam vazias.
- teste: Enquanto for N, o teste e negativo: garantir que o painel nao afirma equivalencia — nenhum widget com semantica de "opcao grafica do AM" existe sem referencia. Quando houver referencia: teste de widget contando exatamente quatro opcoes na fileira, na ordem da captura, com a escolhida em destaque.

### `! ` P · nao introduzir aqui o workspace de speed ramp do documento antigo — o painel de velocidade e local.

- evidencia: V 01:17.5–01:19 + P da pg.19 ("Nao introduzir aqui o workspace de speed ramp do documento antigo")
- hoje: lib/src/features/editor/presentation/widgets/painel_de_velocidade.dart:130-151: titulo '_Titulo("Rampas")', um aviso de duas frases explicando o que e uma rampa, e um `Wrap` com os quatro `SpeedRampPreset` (Impacto/Heroi/Bala/Montagem). Mais painel_de_velocidade.dart:105-129, a secao 'Quadros que faltam' com `InterpolacaoDeQuadros` e outro aviso.
- divergencia: O painel local carrega um mini-workspace de rampa (titulo de secao + texto explicativo + quatro presets) e uma secao de interpolacao de quadros, que o painel do AM nao tem.
- mudanca: Tirar 'Rampas' e 'Quadros que faltam' do corpo do painel de velocidade e dar a elas destino contextual — a rampa pertence ao contexto de keyframes/curva do tempo (o Aurea ja tem `setClipTimeRemapEnabled`, `clipTimeRemapTrack` e `EditorDeCurva`), e a interpolacao de quadros pertence a ficha da midia/exportacao. PRESERVAR: nada aqui pode ser apagado (pg.2, "mudar a interface nao autoriza apagar funcionalidades").
- risco: `applySpeedRamp` zera `speed` e escreve o time remap (editor_controller.dart:3786-3795), enquanto `setClipSpeed` apaga o remap. As duas portas brigam pelo mesmo dado; separa-las em superficies diferentes sem manter o aviso de painel_de_velocidade.dart:131-137 deixa a pessoa sem entender por que o fator voltou a 1. Mover para a curva sem chamador deixa 4 presets orfaos — foi exatamente o que o comentario de painel_de_velocidade.dart:16-20 diz que ja aconteceu uma vez.
- teste: Teste de widget: no painel de velocidade, `find.bySemanticsLabel('Impacto')` = findsNothing e `find.text('Rampas')` = findsNothing; e um teste no destino novo provando que `applySpeedRamp` continua alcancavel por um toque e que o time remap resultante e o mesmo (comparar com test/precomp_test.dart:63).

### `! ` P (pg.7) · voltar do painel recupera o contexto de camada sem perder valores, e nunca reabrir um painel do objeto anterior; a troca de painel nao gera alteracao no projeto.

- evidencia: V 00:40, 00:51 e 01:33 (pg.7, tabela de navegacao e invariantes)
- hoje: O voltar preserva selecao e playhead: controles_da_camada.dart:96-99 passa `aoVoltar` e painel_da_camada.dart:526-532 apenas troca `estadoDoPainelProvider` para `categorias` e limpa `categoriaAbertaProvider` — o projeto nao e tocado. MAS: painel_de_velocidade.dart:12 declara `recadoDaVelocidadeProvider` como `StateProvider<String?>` GLOBAL, escrito em painel_de_velocidade.dart:91-96 e 147, lido em painel_de_velocidade.dart:37 e desenhado em 153, e nunca limpo ao fechar o painel nem ao mudar de camada.
- divergencia: Estado residual entre objetos: o recado "Rampa 'Impacto' aplicada" ou o aviso de video longo demais para inverter sobrevive ao fechar o painel e reaparece no painel de OUTRA camada, falando de uma acao que nao foi feita nela. E a invariante "nunca reabrir um painel do objeto anterior" quebrada pelo lado do conteudo.
- mudanca: Trocar `recadoDaVelocidadeProvider` por estado por camada (chaveado por `camada.id`, via `StateProvider.family`) ou zera-lo em `aoVoltar`/`fecharFerramenta` e sempre que `selectedLayerProvider` mudar.
- risco: Limpar cedo demais engole o aviso legitimo de painel_de_velocidade.dart:91-96, que e a unica resposta visivel quando `setClipReverse` recusa por falta de versao leve — a pessoa toca o interruptor, nada acontece e ninguem explica.
- teste: Teste de widget: em video A, aplicar a rampa 'Impacto' e ver o recado; voltar, selecionar video B, abrir Velocidade e esperar `find.textContaining('Rampa')` = findsNothing. E: com o recado de inversao recusada na tela, ele continua visivel enquanto a camada A estiver selecionada.

### `! ` O painel de velocidade do AM cabe de uma vez: valor, slider e quatro opcoes graficas, sem rolagem.

- evidencia: V 01:18.0 (o quadro mostra o painel inteiro em uma tela)
- hoje: lib/src/features/editor/presentation/widgets/controles_da_camada.dart:184-195 (`_ComRail`) envolve o conteudo num `SingleChildScrollView`, e para video `PainelDeVelocidade` empilha 1 linha de parametro (48 px) + 5 chips + 3 interruptores (~40 px cada) + 2 titulos + 2 avisos + 4 botoes de rampa, dentro dos 300 px de `PainelDaCamada.alturaMaxima` (painel_da_camada.dart:294).
- divergencia: Painel longo e rolavel contra painel curto e chapado do AM; a maior parte do conteudo esta abaixo da dobra.
- mudanca: Depois de tirar rampas e interpolacao (linha 7) e de reduzir os atalhos, o painel cabe: valor + slider + fileira de quatro. Manter o `SingleChildScrollView` do `_ComRail` como rede, mas o conteudo padrao nao deve depender dele.
- risco: O `SingleChildScrollView` do `_ComRail` e compartilhado por todas as categorias; remove-lo quebraria transformacao e efeitos, que sao legitimamente longos. Mexer so no conteudo.
- teste: Teste de widget em 384x832 (a medida da captura, pg.3): abrir Velocidade e conferir que a fileira de quatro opcoes esta visivel sem `tester.scrollUntilVisible`, com `tester.getBottomLeft` dentro da altura do painel.

### `~ ` O painel mostra a leitura numerica do fator, 1.00x na captura.

- evidencia: V 01:18.0 (pg.19: "Velocidade: valor e slider", "valor 1.00x")
- hoje: lib/src/features/editor/presentation/widgets/painel_de_velocidade.dart:46-60: `LinhaDeParametro(rotulo: 'Velocidade', valor: velocidade, casas: 2, sufixo: 'x', ...)`, que desenha `CampoDeValor` (linha_de_parametro.dart:100-113). A formatacao e pt-BR: lib/src/features/editor/presentation/widgets/campo_de_valor.dart:29-34 troca '.' por ',' — a leitura sai "1,00x".
- divergencia: Apenas o separador decimal ("1,00x" vs "1.00x"), que e locale do produto, nao design do AM. Duas casas, sufixo x e posicao no topo do painel batem.
- mudanca: Nenhuma. Manter pt-BR; nao trocar a virgula por ponto so para imitar a captura em ingles.
- risco: Trocar o separador quebraria `numeroDePtBr` (campo_de_valor.dart:47-55), que le de volta o proprio texto que escreveu, e o campo pararia de aceitar digitacao.
- teste: Teste de widget: com velocidade 1.0, `find.text('1,00x')` = findsOneWidget no painel.

### `ok` A area da grade e substituida pelo painel de velocidade, e a selecao temporal permanece visivel acima dele.

- evidencia: V 01:17.5–01:19 (pg.19: "A selecao temporal permanece acima; a area da grade e substituida por esse painel")
- hoje: lib/src/features/editor/presentation/widgets/painel_da_camada.dart:519-533 (`_Aberto`): quando `naCategoria`, o `Expanded` troca `_GradeDeCategorias` por `ControlesDaCategoria` — a grade e de fato substituida, nao empilhada. E lib/src/features/editor/presentation/editor_screen.dart:241-276: com ferramenta aberta o espaco sai da PREVIA e a linha do tempo desce ate `chaoComFerramenta` (transporte + regua + uma trilha), ou seja, a faixa da camada selecionada continua na tela.
- divergencia: NENHUMA

### `ok` P · o painel local precisa estar conectado a duracao/retiming REAIS, e nao ser um controle decorativo.

- evidencia: V 01:17.5–01:19 + P da pg.19 ("reproduzir o painel local e conectar a duracao/retiming reais")
- hoje: lib/src/features/editor/application/editor_controller.dart:3713-3757 (`setClipSpeed`): recalcula `duration` a partir do span de fonte, guarda o FATOR, recusa duracao final abaixo de 50 ms, limpa o time remap (`replaceTimeRemap(l, null)`) e empurra as camadas que comecam depois. Leitura por `clipSpeedOf` (editor_controller.dart:3759-3764). Coberto por test/velocidade_e_aparar_test.dart:233-259.
- divergencia: NENHUMA

### `ok` SEPARACAO OBRIGATORIA · velocidade nao muda a geometria; skew e velocidade sao paineis diferentes e nenhum dos dois abre uma nova arquitetura de editor.

- evidencia: V 01:11.5–01:14.5 (skew) e V 01:17.5–01:19 (velocidade), pg.19
- hoje: Sao paineis distintos e nenhum abre outra tela: skew e o quarto submodo em `PainelDeTransformacao` (controles_da_camada.dart:80-95, `ModoDeTransformacao.inclinar` -> `LayerProp.skew` em controles_da_camada.dart:161-166) e velocidade e `PainelDeVelocidade` (controles_da_camada.dart:111). `setClipSpeed` (editor_controller.dart:3713-3757) so escreve `speed`, `duration`, `effects` e `startTime` de terceiros — nenhum campo de transformacao.
- divergencia: NENHUMA quanto a geometria e a arquitetura. Observacao: `setClipSpeed` desloca o `startTime` de outras camadas (editor_controller.dart:3744-3752) — e efeito temporal, nao geometrico, e nao viola a regra, mas e comportamento que o AM nao demonstra.

### `ok` Para que tipos de camada o velocimetro aparece na barra temporal.

- evidencia: N — a pg.19 nao diz de que tipo era a camada em 01:17.5, e a pg.11 so lista as grades de Forma, Grupo, Camera e Nulo, nenhuma com tile de velocidade (o controle esta na barra temporal, nao na grade). O PDF nao comprova a cobertura por tipo.
- hoje: lib/src/features/editor/presentation/widgets/painel_da_camada.dart:173 restringe a `VideoLayer || AudioLayer`. O motor concorda: `setClipSpeed` so tem ramo para VideoLayer/AudioLayer (editor_controller.dart:3730-3737) e `clipSpeedOf` devolve 1.0 fixo para os demais (editor_controller.dart:3759-3764). Fixado por test/velocidade_e_aparar_test.dart:206-231.
- divergencia: Nao comprovada. A restricao a video/audio e decisao do Aurea, apoiada no motor; o AM nao foi observado neste ponto.

### `ok` Papel do rail esquerdo (voltar, keyframe, entrada de curva) dentro do painel de velocidade.

- evidencia: N — a pg.19 nao descreve a coluna esquerda no trecho de velocidade (so a descreve para posicao, pg.16, e para as familias de aparencia, pgs.13-14)
- hoje: lib/src/features/editor/presentation/widgets/controles_da_camada.dart:129-153: `_alvoDaCategoria` nao tem caso para 'velocidade' e cai em `return const AlvoDoRail()` (linha 152) — o rail aparece com o `‹` funcionando e os botoes de keyframe/curva apagados.
- divergencia: Nao comprovada. A velocidade constante do Aurea nao e propriedade animavel (quem anima o tempo e o time remap), entao o rail apagado e coerente com o motor.

### Extensoes do Aurea nesta superficie

O PDF manda preservar e dar destino contextual — nunca apagar.

- Cinco atalhos de fator em chips (0,25x / 0,5x / 1x / 2x / 4x) — painel_de_velocidade.dart:61-67. Preservar; destino contextual: podem virar valores rapidos ao lado do campo numerico ou um menu do proprio campo, sem ocupar a fileira das quatro opcoes graficas do AM.
- Interruptor de preservacao de tom ("Mantendo o tom da voz" / "Deixar o tom subir e descer") — painel_de_velocidade.dart:71-81, ligado a `setClipPreservePitch`. Vale para video e audio. Destino: pertence ao contexto de audio da barra temporal (a pg.12 registra que a barra temporal do AM tem controles de audio), nao ao painel de velocidade curto.
- Inversao do clipe ("Tocar de tras para a frente") com guarda de proxy e recado quando o video e longo demais — painel_de_velocidade.dart:83-98, `setClipReverse`. Destino: acao temporal da camada, junto com dividir/aparar.
- Borrao de movimento por velocidade — painel_de_velocidade.dart:99-104, `setClipSpeedBlur`. Destino: e aparencia derivada do tempo; cabe no contexto de efeitos da camada ou numa segunda pagina do painel temporal.
- Secao 'Quadros que faltam' com `InterpolacaoDeQuadros` (repetir / mesclar / movimento) e o aviso de que so vale na exportacao — painel_de_velocidade.dart:105-129, `setClipInterpolacao`. Destino: ficha da midia ou ajustes de exportacao, onde a restricao "vale na exportacao" faz sentido.
- Secao 'Rampas' com quatro presets de speed ramp (Impacto, Heroi, Bala, Montagem) e o aviso que explica rampa contra velocidade constante — painel_de_velocidade.dart:130-151, `applySpeedRamp` + `speedRampTrack` (cut.dart:204-244). E exatamente o que a pg.19 manda NAO por neste painel. Destino: contexto de keyframes/curva do tempo, junto de `setClipTimeRemapEnabled` e `EditorDeCurva`. Nunca apagar — o comentario de painel_de_velocidade.dart:16-20 registra que esses comandos ja ficaram sem porta uma vez.
- Ripple temporal: mudar a velocidade empurra o `startTime` de todas as camadas que comecam depois, para nao abrir buraco nem sobreposicao — editor_controller.dart:3744-3752. Comportamento nao demonstrado no AM; preservar e documentar, porque some se o painel for reescrito do zero.
- Digitacao exata do fator pelo `CampoDeValor`, que aceita valores fora da faixa util ate o clamp 0.1..10.0 do motor — painel_de_velocidade.dart:59 e campo_de_valor.dart:47-55. Preservar junto do slider novo.
