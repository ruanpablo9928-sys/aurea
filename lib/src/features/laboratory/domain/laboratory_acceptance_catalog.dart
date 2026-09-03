import 'acceptance_task.dart';
import 'laboratory_level.dart';

AcceptanceStepDefinition _step(
  String id,
  String instruction, {
  List<TestAssetRequirement> assets = const [],
  bool screenshot = false,
}) => AcceptanceStepDefinition(
  id: id,
  instruction: instruction,
  assets: assets,
  screenshotRecommended: screenshot,
);

/// Tarefas guiadas oficiais, transcritas das tarefas de aceite dos niveis.
abstract final class LaboratoryAcceptanceCatalog {
  static final List<AcceptanceTaskDefinition> all = List.unmodifiable([
    AcceptanceTaskDefinition(
      level: LaboratoryLevelId.core,
      title: 'Nucleo',
      steps: [
        _step(
          'n0-import-video',
          'Importar um video com audio.',
          assets: [LaboratoryTestAssets.spokenVideo],
        ),
        _step('n0-cut-three', 'Cortar o video em tres pedacos.'),
        _step(
          'n0-ripple-delete',
          'Apagar o pedaco do meio com ripple; o terceiro deve encostar no primeiro.',
          screenshot: true,
        ),
        _step(
          'n0-mark-beats',
          'Dar play e marcar oito batidas tocando no ritmo.',
          assets: [LaboratoryTestAssets.beatTrack],
        ),
        _step('n0-import-image', 'Importar uma imagem por cima.'),
        _step(
          'n0-position-spring',
          'Animar a posicao da imagem de fora da tela ate o centro, com curva de mola.',
        ),
        _step(
          'n0-scale-beats',
          'Animar a escala com dois keyframes encaixados em duas batidas.',
        ),
        _step('n0-adjust-curve', 'Ajustar a curva da escala no editor.'),
        _step('n0-export', 'Exportar em MP4.'),
      ],
    ),
    AcceptanceTaskDefinition(
      level: LaboratoryLevelId.shapes,
      title: 'Shapes',
      steps: [
        _step(
          'n1-rounded-rectangle',
          'Adicionar um retangulo arredondado da biblioteca.',
        ),
        _step(
          'n1-animate-radius',
          'Animar o raio de canto de 0 a 100% em um segundo, com mola; o quadrado vira circulo.',
        ),
        _step(
          'n1-edit-points',
          'Abrir Edit Points e mover dois pontos com o trackpad, sem tocar no canvas.',
        ),
        _step(
          'n1-morph',
          'Cravar keyframe nos pontos, mover o cabecote e mover os pontos de novo; o morph acontece.',
        ),
        _step('n1-dashed-stroke', 'Ligar o traco e animar o tracejado.'),
        _step(
          'n1-drawing-progress',
          'Aplicar Drawing Progress e animar de 0 a 100; a borda se desenha.',
        ),
        _step('n1-export', 'Exportar.'),
      ],
    ),
    AcceptanceTaskDefinition(
      level: LaboratoryLevelId.text,
      title: 'Texto',
      steps: [
        _step('n2-add-text', 'Adicionar um texto de duas linhas.'),
        _step(
          'n2-extra-font',
          'Trocar a fonte do texto pela fonte extra de teste.',
          assets: [LaboratoryTestAssets.extraFont],
        ),
        _step('n2-apple-recipe', 'Aplicar a receita Apple em Presets.'),
        _step('n2-export', 'Exportar.'),
      ],
    ),
    AcceptanceTaskDefinition(
      level: LaboratoryLevelId.effects,
      title: 'Seis efeitos',
      steps: [
        _step(
          'n3-import-reference',
          'Importar a cartela de referencia.',
          assets: [LaboratoryTestAssets.referenceCard],
        ),
        _step('n3-neon-glow', 'Aplicar Glow pelo preset Neon.'),
        _step('n3-threshold', 'Abrir Montar e baixar o Threshold.'),
        _step(
          'n3-glow-color',
          'Abrir Avancado e trocar a cor do glow.',
          screenshot: true,
        ),
        _step('n3-radius', 'Animar o Radius de 0 a 200 com mola.'),
        _step(
          'n3-rgb-shake',
          'Aplicar RGB Split e Shake, com keyframes de Amount e Amplitude encaixados em duas batidas.',
        ),
        _step('n3-vignette', 'Aplicar Vignette.'),
        _step('n3-export', 'Exportar.'),
      ],
    ),
    AcceptanceTaskDefinition(
      level: LaboratoryLevelId.mask,
      title: 'Mascara',
      steps: [
        _step('n4-text-video', 'Colocar um texto sobre um video.'),
        _step(
          'n4-reveal-left',
          'Tocar Revelar > Esquerda; o texto entra deslizando por tras de uma mascara com feather, em mola.',
        ),
        _step('n4-feather', 'Abrir Montar e aumentar o feather.'),
        _step(
          'n4-track-matte',
          'Adicionar um retangulo acima do video e tocar Recortar pela camada acima; o video fica dentro do retangulo e o retangulo some.',
          screenshot: true,
        ),
        _step('n4-animate-rectangle', 'Animar a escala do retangulo.'),
        _step('n4-add-mask', 'Numa imagem, criar uma mascara externa em Add.'),
        _step(
          'n4-subtract-mask',
          'Criar uma segunda mascara interna em Subtract; deve aparecer um buraco.',
        ),
        _step('n4-export', 'Exportar.'),
      ],
    ),
    AcceptanceTaskDefinition(
      level: LaboratoryLevelId.cut,
      title: 'Corte',
      steps: [
        _step(
          'n5-two-clips',
          'Criar dois clipes cortados do video de teste.',
          assets: [LaboratoryTestAssets.spokenVideo],
        ),
        _step('n5-dissolve', 'Tocar a juncao e escolher Dissolve.'),
        _step('n5-duration', 'Arrastar a alca para 0,5 s.'),
        _step('n5-zoom-warp', 'Trocar a transicao por Zoom warp.'),
        _step('n5-impact', 'No segundo clipe, aplicar a rampa Impacto.'),
        _step(
          'n5-time-remap',
          'Abrir Avancado, ver os keyframes de Time Remap e mover um.',
        ),
        _step('n5-freeze', 'Usar Congelar aqui no meio do primeiro clipe.'),
        _step('n5-reverse', 'Reverter o segundo clipe.'),
        _step('n5-export', 'Exportar.'),
      ],
    ),
    AcceptanceTaskDefinition(
      level: LaboratoryLevelId.apple,
      title: 'Apple',
      steps: [
        _step(
          'n6-load-project',
          'Carregar o projeto Apple de referencia.',
          assets: [
            LaboratoryTestAssets.appleReferenceProject,
            LaboratoryTestAssets.beatTrack,
          ],
        ),
        _step(
          'n6-gradient',
          'Criar fundo com gradiente #000 -> #0A1E3C, sem uma faixa.',
        ),
        _step('n6-card', 'Criar card com retangulo de raio 24 e Sombra suave.'),
        _step(
          'n6-card-entry',
          'Animar escala 92 -> 100% e opacidade com a curva Apple entrada.',
        ),
        _step(
          'n6-title',
          'Criar titulo de duas linhas com a receita Apple do Nivel 2.',
        ),
        _step(
          'n6-icons',
          'Criar tres icones e usar Escalonar selecao em 60 ms com Mola de interface.',
        ),
        _step(
          'n6-glass',
          'Deslizar um painel de Vidro fosco por cima do card.',
        ),
        _step(
          'n6-speed-graph',
          'Abrir o grafico de velocidade da escala do card e verificar o S.',
          screenshot: true,
        ),
        _step('n6-export', 'Exportar.'),
      ],
    ),
    AcceptanceTaskDefinition(
      level: LaboratoryLevelId.captions,
      title: 'Legendas',
      steps: [
        _step(
          'n7-load-spoken',
          'Carregar o video de um minuto com fala.',
          assets: [LaboratoryTestAssets.spokenVideo],
        ),
        _step(
          'n7-caption',
          'Tocar Legendar, ver a estimativa, aceitar e continuar cortando enquanto transcreve.',
        ),
        _step(
          'n7-single-layer',
          'Confirmar que as falas aparecem numa camada so.',
        ),
        _step('n7-box-style', 'Trocar o estilo para Caixa.'),
        _step('n7-correct-word', 'Tocar numa fala e corrigir uma palavra.'),
        _step('n7-merge', 'Unir duas falas.'),
        _step(
          'n7-karaoke',
          'Trocar para palavra por palavra com estilo Karaoke.',
        ),
        _step(
          'n7-delete-sentence',
          'Apagar uma frase pela lista de texto; o trecho some da timeline.',
        ),
        _step(
          'n7-silence',
          'Legendar o video de silencio e confirmar que nenhuma fala foi inventada.',
          assets: [LaboratoryTestAssets.silentVideo],
          screenshot: true,
        ),
        _step('n7-burned-export', 'Exportar com legenda queimada.'),
        _step('n7-srt-export', 'Exportar SRT.'),
      ],
    ),
    AcceptanceTaskDefinition(
      level: LaboratoryLevelId.scene3d,
      title: 'Cena 3D',
      steps: [
        _step('n8-new-scene', 'Criar Nova Cena 3D; ela ja nasce iluminada.'),
        _step(
          'n8-primitives',
          'Adicionar cubo e esfera e aplicar Metal polido na esfera; o ambiente aparece refletido.',
        ),
        _step(
          'n8-import-glb',
          'Importar os GLBs de produto, ver o relatorio e abrir mesmo o grande.',
          assets: [
            LaboratoryTestAssets.smallGlb,
            LaboratoryTestAssets.largeGlb,
          ],
        ),
        _step('n8-environment', 'Trocar o ambiente para Por do sol e girar.'),
        _step(
          'n8-null',
          'Criar Nulo 3D, parentear os tres objetos e girar o nulo.',
        ),
        _step('n8-orbit', 'Aplicar Rig de orbita na camera num toque.'),
        _step(
          'n8-dof',
          'Ligar profundidade de campo e usar Focar no selecionado.',
        ),
        _step(
          'n8-occlusion',
          'Colocar um texto 2D entre a esfera e o cubo e verificar a oclusao.',
          screenshot: true,
        ),
        _step('n8-export', 'Exportar.'),
      ],
    ),
    AcceptanceTaskDefinition(
      level: LaboratoryLevelId.panorama,
      title: 'Panorama',
      steps: [
        _step(
          'n81-scene',
          'Criar cena com esfera Metal polido e dois cubos coloridos.',
        ),
        _step(
          'n81-reflect-scene',
          'Ligar Refletir a cena; os cubos aparecem na esfera.',
        ),
        _step(
          'n81-rotate-null',
          'Girar o nulo dos cubos; o reflexo acompanha.',
        ),
        _step(
          'n81-photo-environment',
          'Fotografar ambiente com o celular e importar; a esfera reflete a sala.',
          assets: [
            LaboratoryTestAssets.equirectangularPanorama,
            LaboratoryTestAssets.phonePanorama,
          ],
          screenshot: true,
        ),
        _step('n81-rotate-environment', 'Girar o ambiente.'),
        _step(
          'n81-high-quality',
          'Subir a qualidade para alta e dar zoom na esfera.',
        ),
        _step('n81-export', 'Exportar.'),
      ],
    ),
    AcceptanceTaskDefinition(
      level: LaboratoryLevelId.nullAndClone,
      title: 'Nulo e Clonar',
      steps: [
        _step('n9-add-null', 'Adicionar um Nulo por + > Object > Nulo.'),
        _step(
          'n9-parent',
          'Parentear duas camadas ao Nulo e mover o Nulo; as duas acompanham.',
        ),
        _step('n9-clone', 'Adicionar uma forma e abrir a secao Clonar.'),
        _step(
          'n9-circle',
          'Distribuir os clones em circulo e ajustar a contagem.',
        ),
        _step('n9-effector', 'Adicionar um Efetor e ajustar raio e queda.'),
        _step(
          'n9-animate-effector',
          'Animar o Efetor atraves dos clones; escala e opacidade acompanham sem saltos.',
          screenshot: true,
        ),
        _step('n9-export', 'Exportar.'),
      ],
    ),
    // 10.1 e a unica tarefa que atravessa o app inteiro numa sessao so:
    // e o teste de que as features couberam na tela, e nao de cada uma.
    AcceptanceTaskDefinition(
      level: LaboratoryLevelId.uiFinal,
      title: 'UI final',
      steps: [
        _step(
          'n101-ligar-tudo',
          'Ligar os dez niveis no Laboratorio. Daqui ate o fim, sem fechar o app.',
        ),
        _step(
          'n101-importar',
          'Importar o video com fala.',
          assets: [LaboratoryTestAssets.spokenVideo],
        ),
        _step('n101-cortar', 'Cortar o video.'),
        _step(
          'n101-batidas',
          'Dar play e marcar as batidas no ritmo.',
          assets: [LaboratoryTestAssets.beatTrack],
        ),
        _step(
          'n101-forma-raio',
          'Adicionar uma forma e animar o raio de canto. '
              'Os toques ate o raio precisam ser no maximo quatro.',
        ),
        _step(
          'n101-texto-apple',
          'Adicionar texto com uma receita Apple.',
          assets: [LaboratoryTestAssets.extraFont],
        ),
        _step(
          'n101-glow',
          'Aplicar Glow e ajustar. '
              'Os toques ate o limiar precisam ser no maximo quatro.',
          assets: [LaboratoryTestAssets.referenceCard],
        ),
        _step(
          'n101-mascara',
          'Revelar a camada por mascara. '
              'Os toques ate o feather precisam ser no maximo quatro.',
        ),
        _step(
          'n101-transicao',
          'Por uma transicao na juncao entre dois clipes. '
              'Os toques ate a duracao precisam ser no maximo quatro.',
        ),
        _step(
          'n101-clonar',
          'Clonar em circulo com efetor. '
              'Os toques ate a contagem precisam ser no maximo quatro.',
        ),
        _step(
          'n101-cena3d',
          'Abrir uma Cena 3D com esfera metalica e panorama. '
              'Os toques ate a rugosidade precisam ser no maximo quatro.',
          assets: [
            LaboratoryTestAssets.smallGlb,
            LaboratoryTestAssets.equirectangularPanorama,
          ],
        ),
        _step(
          'n101-contar-zonas',
          'Contar as zonas da tela: contexto, preview, acoes, tempo e '
              'painel. Precisam ser cinco.',
          screenshot: true,
        ),
        _step(
          'n101-contar-secoes',
          'Abrir o menu da camada e contar as secoes da grade: no maximo '
              'sete, e nenhuma delas sem funcao para o tipo da camada.',
          screenshot: true,
        ),
        _step(
          'n101-diamante',
          'Trocar de sub-aba dez vezes; o losango nao sai do lugar.',
        ),
        _step(
          'n101-nao-cobre',
          'Abrir qualquer painel: preview, regua e barra da camada '
              'continuam visiveis.',
          screenshot: true,
        ),
        _step(
          'n101-profundidades',
          'Subir de Pronto para Montar para Avancado: nada se perde e o '
              'frame nao muda.',
        ),
        _step('n101-export', 'Exportar.'),
      ],
    ),
  ]);

  static AcceptanceTaskDefinition forLevel(LaboratoryLevelId level) =>
      all.firstWhere((task) => task.level == level);
}
