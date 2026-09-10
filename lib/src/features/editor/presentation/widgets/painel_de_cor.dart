import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';
import '../../domain/layer.dart';
import '../../domain/shape.dart';
import 'editor_de_curva.dart';
import 'escolha_de_cor.dart';
import 'linha_de_parametro.dart';
import 'rails_do_painel.dart';

/// QUAL TRILHA DO CONTORNO o rail esta mirando.
final itemDaCorProvider = StateProvider<String?>((ref) => null);
final parametroDaCorProvider = StateProvider<String?>((ref) => null);

/// O ALVO DO RAIL quando a ferramenta aberta e a de cor.
///
/// Cor nao e trilha em lugar nenhum deste subsistema — `shapeItemTrack`
/// devolve nulo para preenchimento e gradiente, e o unico dado de cor
/// com keyframe (`colorFrames` do gradiente) nao tem comando que o
/// escreva. Entao so o CONTORNO acende o losango, e so nas duas
/// grandezas que sao numero: espessura e opacidade.
AlvoDoRail alvoDaCorDaForma(
  WidgetRef ref,
  Layer camadaNaTela,
  Duration tempo,
) => alvoDoItemDaForma(
  ref,
  camadaNaTela,
  ref.watch(itemDaCorProvider),
  ref.watch(parametroDaCorProvider),
  tempo,
);

/// O ALVO DO RAIL PARA UM NUMERO DE UM ITEM DA FORMA.
///
/// Serve a Cor e preenchimento e tambem a Borda e sombra: as duas
/// familias mexem em trilhas de `ShapeItem`, e o losango e a curva
/// resolvem-se do mesmo jeito. Recebe item e chave prontos em vez de
/// ler providers, porque quem sabe o que esta em foco e o painel.
AlvoDoRail alvoDoItemDaForma(
  WidgetRef ref,
  Layer camadaNaTela,
  String? itemId,
  String? chave,
  Duration tempo,
) {
  // O rail diz o que ESTA GRAVADO, e nao o que a previa mostra.
  final camada = camadaReal(ref, camadaNaTela);
  if (camada is! ShapeLayer) return const AlvoDoRail();
  if (itemId == null || chave == null) return const AlvoDoRail();
  final item = camada.contents.where((i) => i.id == itemId).firstOrNull;
  if (item == null) return const AlvoDoRail();
  final trilha = EditorController.shapeItemTrack(item, chave);
  if (trilha == null) return const AlvoDoRail();

  final c = ref.read(editorControllerProvider.notifier);
  final local = camada.localTime(tempo);

  // A CURVA PODE ACENDER AQUI, ao contrario de efeito e mascara: o
  // motor tem easing por TRECHO para a trilha de item de forma
  // (`setShapeItemTrackSegmentEase`), e nao so por keyframe.
  Duration? comeca;
  Duration? depois;
  for (final k in trilha.keyframes) {
    if (k.time <= local) comeca = k.time;
    if (k.time > local && depois == null) depois = k.time;
  }
  final temTrecho = comeca != null && depois != null;
  final inicio = comeca ?? Duration.zero;

  return AlvoDoRail(
    temKeyframeAqui: trilha.hasKeyframeAt(local),
    animado: trilha.isAnimated,
    aoAlternarKeyframe: () =>
        c.toggleShapeItemTrackKeyframe(camada.id, itemId, chave, tempo),
    aoAbrirCurva: !temTrecho
        ? null
        : () => ref.read(curvaEmEdicaoProvider.notifier).state = CurvaEmEdicao(
            titulo: switch (chave) {
              'width' => 'Espessura do contorno',
              'opacity' => 'Opacidade do contorno',
              'start' => 'Inicio do traco',
              'end' => 'Fim do traco',
              _ => 'Curva de gradacao',
            },
            atual: trilha.easeAt(inicio),
            aoAplicar: (e) => c.setShapeItemTrackSegmentEase(
              camada.id,
              itemId,
              chave,
              inicio,
              e,
            ),
            aoAplicarEmTodos: trilha.keyframes.length > 2
                ? (e) => c.applyEaseToAllShapeItemTrackSegments(
                    camada.id,
                    itemId,
                    chave,
                    e,
                  )
                : null,
          ),
  );
}

/// COR E PREENCHIMENTO.
///
/// O cartao existia reservado e DESLIGADO desde o comeco da UI nova,
/// dizendo "Chega numa proxima entrega". Enquanto isso todo texto do
/// app era branco e todo retangulo nascia e morria no mesmo azul, com
/// `setShapePrimaryColor`, `updateShapeGradient` e `updateShapeStroke`
/// parados no motor sem um unico chamador. Nao dava para fazer uma
/// peca grafica.
///
/// A ficha muda por tipo de camada, porque "cor" e coisa diferente em
/// cada um: no texto e uma so; na forma e um ITEM DE PINTURA; nas
/// particulas sao duas (comeco e fim da vida).
class PainelDeCor extends ConsumerWidget {
  const PainelDeCor({super.key, required this.camada, required this.tempo});

  final Layer camada;
  final Duration tempo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(editorControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: switch (camada) {
        TextLayer l => [
          EscolhaDeCor(
            rotulo: 'Cor do texto',
            cor: l.color,
            aoComecar: c.beginGesture,
            aoTerminar: c.endGesture,
            aoMudar: (cor) => c.editTextLayer(l.id, color: cor),
          ),
        ],
        ShapeLayer l => _daForma(ref, c, l),
        ParticlesLayer l => [
          EscolhaDeCor(
            rotulo: 'Cor',
            cor: l.color,
            aoComecar: c.beginGesture,
            aoTerminar: c.endGesture,
            aoMudar: (cor) =>
                c.updateParticles(l.id, (p) => p.copyParticles(color: cor)),
          ),
          // A COR DO FIM DA VIDA e o que faz faisca virar brasa. Fica
          // atras de um interruptor porque, desligada, a particula tem
          // uma cor so — e mostrar duas amostras iguais nao diz isso.
          _Interruptor(
            rotulo: l.colorEnd == null
                ? 'Mudar de cor ao apagar'
                : 'Cor no fim da vida ligada',
            icone: Icons.gradient_rounded,
            ligado: l.colorEnd != null,
            aoTocar: () => c.updateParticles(
              l.id,
              (p) => p.colorEnd == null
                  ? p.copyParticles(colorEnd: p.color)
                  : p.copyParticles(clearColorEnd: true),
            ),
          ),
          if (l.colorEnd != null)
            EscolhaDeCor(
              rotulo: 'Cor no fim da vida',
              cor: l.colorEnd!,
              aoComecar: c.beginGesture,
              aoTerminar: c.endGesture,
              aoMudar: (cor) => c.updateParticles(
                l.id,
                (p) => p.copyParticles(colorEnd: cor),
              ),
            ),
        ],
        Element3DLayer l => [
          EscolhaDeCor(
            rotulo: 'Cor',
            cor: l.color,
            aoComecar: c.beginGesture,
            aoTerminar: c.endGesture,
            aoMudar: (cor) => c.updateElement3D(
              l.id,
              (e) => e.copyElement3D(color: cor),
            ),
          ),
        ],
        _ => const [_Aviso('Esta camada nao tem cor propria.')],
      },
    );
  }

  // ------------------------------------------------------------- forma

  /// A CAMADA DE FORMA NAO TEM "COR".
  ///
  /// Ela tem uma LISTA PLANA de itens, avaliada de cima para baixo: as
  /// geometrias acumulam caminhos, e um item de PINTURA consome todos
  /// os caminhos acumulados ate ali. Logo cor nao e propriedade de um
  /// desenho — e propriedade de uma pintura, e uma pintura vale para
  /// tudo que veio antes dela.
  ///
  /// Um seletor de cor por geometria seria mentira. O painel edita a
  /// PRIMEIRA pintura e diz isso quando ha mais de uma — a mesma regra
  /// que a ficha de forma ja usa com a primeira geometria.
  List<Widget> _daForma(WidgetRef ref, EditorController c, ShapeLayer l) {
    final pinturas = l.contents
        .where((i) => i is ShapeFill || i is ShapeGradientFill)
        .toList();

    return [
      if (pinturas.length > 1)
        const _Aviso(
          'Ajustando a primeira pintura desta camada. As outras '
          'continuam como estao.',
        ),
      const _Titulo('Pintura'),
      ...switch (pinturas.firstOrNull) {
        ShapeFill f => [
          EscolhaDeCor(
            rotulo: 'Preenchimento',
            cor: f.color,
            aoComecar: c.beginGesture,
            aoTerminar: c.endGesture,
            aoMudar: (cor) => c.setShapePrimaryColor(l.id, cor),
          ),
        ],
        // O GRADIENTE PRECISA DO PROPRIO CAMINHO: `setShapePrimaryColor`
        // so enxerga preenchimento chapado e contorno. Numa forma cujo
        // unico pintor e gradiente, ele reescreveria a lista identica —
        // zero pixel.
        ShapeGradientFill g => [
          EscolhaDeCor(
            rotulo: 'Cor inicial',
            cor: g.colorA,
            aoComecar: c.beginGesture,
            aoTerminar: c.endGesture,
            aoMudar: (cor) => c.updateShapeGradient(
              l.id,
              g.id,
              (x) => x.copyWith(colorA: cor),
            ),
          ),
          for (var i = 0; i < g.extras.length; i++)
            EscolhaDeCor(
              rotulo: 'Cor do meio ${i + 1}',
              cor: g.extras[i],
              aoComecar: c.beginGesture,
              aoTerminar: c.endGesture,
              aoMudar: (cor) => c.updateShapeGradient(l.id, g.id, (x) {
                final lista = [...x.extras];
                lista[i] = cor;
                return x.copyWith(extras: lista);
              }),
            ),
          EscolhaDeCor(
            rotulo: 'Cor final',
            cor: g.colorB,
            aoComecar: c.beginGesture,
            aoTerminar: c.endGesture,
            aoMudar: (cor) => c.updateShapeGradient(
              l.id,
              g.id,
              (x) => x.copyWith(colorB: cor),
            ),
          ),
          LinhaDeParametro(
            rotulo: 'Angulo',
            nome: 'Angulo do gradiente',
            valor: g.angleDeg,
            casas: 0,
            sufixo: '°',
            porPixel: 360 / 300,
            aoComecar: c.beginGesture,
            aoMudar: (v) => c.updateShapeGradient(
              l.id,
              g.id,
              (x) => x.copyWith(angleDeg: v),
            ),
            aoTerminar: c.endGesture,
            aoDigitar: (v) => c.updateShapeGradient(
              l.id,
              g.id,
              (x) => x.copyWith(angleDeg: v),
            ),
          ),
          _Interruptor(
            rotulo: g.radial ? 'Radial' : 'Em linha reta',
            icone: g.radial
                ? Icons.blur_circular_rounded
                : Icons.gradient_rounded,
            ligado: g.radial,
            aoTocar: () => c.updateShapeGradient(
              l.id,
              g.id,
              (x) => x.copyWith(radial: !x.radial),
            ),
          ),
        ],
        _ => const [
          _Aviso(
            'Esta forma nao tem pintura: os caminhos existem e nada os '
            'pinta. Um contorno resolve.',
          ),
        ],
      },
      // O CONTORNO SAIU DAQUI.
      //
      // A especificacao e explicita (pagina 13): "o painel de Cor e
      // preenchimento contem os controles de COR — nao os do traco.
      // Borda/contorno pertence a familia Borda e sombra, no subpainel
      // Traco". E la que ele mora agora, com ponta, junta e o desenho do
      // traco que este painel nunca teve.
    ];
  }
}

/// O FUNDO DA COMPOSICAO.
///
/// Nao pertence a camada nenhuma, entao nao pode morar no cartao de cor
/// de nenhuma delas: repetiria em quatro tipos e cada controle teria de
/// explicar sobre quem age. Ele e da COMPOSICAO, e por isso abre pelo
/// nome do projeto — o unico ponto da tela que ja fala em nome dela.
class PainelDaComposicao extends ConsumerWidget {
  const PainelDaComposicao({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(editorControllerProvider.notifier);
    final projeto = ref.watch(editorControllerProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Titulo('Fundo'),
          EscolhaDeCor(
            rotulo: 'Fundo da composicao',
            cor: projeto.backgroundColor,
            aoComecar: c.beginGesture,
            aoTerminar: c.endGesture,
            aoMudar: c.setBackgroundColor,
          ),
          const _Aviso(
            'A cor do fundo sai no arquivo exportado. Para um fundo '
            'transparente, exporte em sequencia PNG.',
          ),
        ],
      ),
    );
  }
}

class _Interruptor extends StatelessWidget {
  const _Interruptor({
    required this.rotulo,
    required this.icone,
    required this.ligado,
    required this.aoTocar,
  });

  final String rotulo;
  final IconData icone;
  final bool ligado;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: true,
    toggled: ligado,
    label: rotulo,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aoTocar,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            const SizedBox(width: 4),
            Icon(
              icone,
              size: 19,
              color: ligado ? AmColors.accent : AmColors.text,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                rotulo,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ligado ? AmColors.accent : AmColors.text,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 12, 0, 6),
    child: Text(
      texto,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AmColors.muted,
      ),
    ),
  );
}

class _Aviso extends StatelessWidget {
  const _Aviso(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 2, 0, 6),
    child: Text(
      texto,
      style: const TextStyle(fontSize: 11, color: AmColors.muted, height: 1.4),
    ),
  );
}
