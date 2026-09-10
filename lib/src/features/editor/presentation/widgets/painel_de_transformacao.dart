import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';
import '../../application/playback_controller.dart';
import '../../domain/layer.dart';
import 'almofada_de_arrasto.dart';
import 'campo_de_valor.dart';
import 'dial_de_angulo.dart';
import 'fita_de_ajuste.dart';
import 'rails_do_painel.dart';

/// OS QUATRO MODOS, na ordem do rail direito da referencia.
enum ModoDeTransformacao { mover, girar, escalar, inclinar }

final modoDeTransformacaoProvider = StateProvider<ModoDeTransformacao>(
  (ref) => ModoDeTransformacao.mover,
);

/// LARGURA E ALTURA ANDAM JUNTAS?
///
/// Travado e o padrao porque e o que quase toda edicao quer: aumentar
/// sem esticar. Destravar e a excecao, e por isso e um botao de corrente
/// entre os dois campos, e nao dois campos sempre soltos.
final escalaTravadaProvider = StateProvider<bool>((ref) => true);

/// O PAINEL DE TRANSFORMACAO.
///
/// Quatro modos, quatro superficies, um rail de cada lado. Nenhum
/// deslizante — ver `docs/painel-de-transformacao-alight.md`, "A regra
/// que muda tudo": posicao e 2D, angulo e circular, e escala nao tem
/// intervalo natural. Um `Slider` mente sobre as tres.
class PainelDeTransformacao extends ConsumerStatefulWidget {
  const PainelDeTransformacao({
    super.key,
    required this.camada,
    required this.tempo,
    required this.playback,
    required this.aoVoltar,
    required this.alvoDoRail,
  });

  final Layer camada;
  final Duration tempo;
  final PlaybackController playback;
  final VoidCallback aoVoltar;

  /// O que o rail esquerdo faz no modo vigente. Vem de fora porque quem
  /// sabe montar keyframe e curva e o painel das ferramentas, que ja tem
  /// a conta pronta para as outras categorias.
  final AlvoDoRail Function(ModoDeTransformacao) alvoDoRail;

  @override
  ConsumerState<PainelDeTransformacao> createState() =>
      _PainelDeTransformacaoState();
}

class _PainelDeTransformacaoState
    extends ConsumerState<PainelDeTransformacao> {
  /// A FOTO DO VALOR NO INICIO DO ARRASTO.
  ///
  /// As superficies entregam o deslocamento ACUMULADO, e nao o do
  /// quadro. Somar quadro a quadro arredondaria em cada soma e a camada
  /// terminaria alguns pixels longe de onde o dedo parou.
  Offset _posicaoAoComecar = Offset.zero;

  EditorController get _c => ref.read(editorControllerProvider.notifier);

  Duration get _local => widget.camada.localTime(widget.tempo);

  void _abrirLote() => _c.beginGesture();

  void _fecharLote() => _c.endGesture();

  @override
  Widget build(BuildContext context) {
    final modo = ref.watch(modoDeTransformacaoProvider);
    return Row(
      children: [
        RailEsquerdo(
          aoVoltar: widget.aoVoltar,
          alvo: widget.alvoDoRail(modo),
        ),
        Expanded(
          child: Column(
            children: [
              SizedBox(height: 44, child: Center(child: _campos(modo))),
              Expanded(child: _superficie(modo)),
              const SizedBox(height: 10),
            ],
          ),
        ),
        RailDireito(
          modos: const [
            (Icons.open_with_rounded, 'Mover'),
            (Icons.rotate_right_rounded, 'Girar'),
            (Icons.aspect_ratio_rounded, 'Escalar'),
            (Icons.transform_rounded, 'Inclinar'),
          ],
          vigente: modo.index,
          aoEscolher: (i) => ref
              .read(modoDeTransformacaoProvider.notifier)
              .state = ModoDeTransformacao.values[i],
        ),
      ],
    );
  }

  // ------------------------------------------------------- os campos

  Widget _campos(ModoDeTransformacao modo) {
    final l = widget.camada;
    switch (modo) {
      case ModoDeTransformacao.mover:
        final p = l.position.valueAt(_local);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CampoDeValor(
              rotulo: 'x',
              valor: p.dx,
              aoDigitar: (v) =>
                  _c.editPosition(l.id, widget.tempo, Offset(v, p.dy)),
            ),
            const SizedBox(width: 6),
            CampoDeValor(
              rotulo: 'y',
              valor: p.dy,
              aoDigitar: (v) =>
                  _c.editPosition(l.id, widget.tempo, Offset(p.dx, v)),
            ),
            const SizedBox(width: 14),
            CampoDeValor(
              rotulo: 'z',
              valor: l.positionZ.valueAt(_local),
              // Z SO EDITA EM CAMADA 3D. O campo continua a vista, e
              // apagado, porque some-lo mudaria a largura da fileira
              // toda vez que alguem ligasse o 3D.
              aoDigitar: l.is3D
                  ? (v) => _c.editPositionZ(l.id, widget.tempo, v)
                  : null,
            ),
          ],
        );
      case ModoDeTransformacao.girar:
        // O ANGULO MORA NO CENTRO DO DIAL, e nao aqui em cima: e para la
        // que o olho vai enquanto o dedo gira.
        return const SizedBox.shrink();
      case ModoDeTransformacao.escalar:
        final travada = ref.watch(escalaTravadaProvider);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CampoDeValor(
              rotulo: 'Largura',
              valor: l.scaleX.valueAt(_local) * 100,
              sufixo: '%',
              aoDigitar: (v) => _escalar(v / 100, l.scaleY.valueAt(_local)),
            ),
            _Corrente(
              travada: travada,
              aoTocar: () => ref.read(escalaTravadaProvider.notifier).state =
                  !travada,
            ),
            CampoDeValor(
              rotulo: 'Altura',
              valor: l.scaleY.valueAt(_local) * 100,
              sufixo: '%',
              aoDigitar: (v) => _escalar(l.scaleX.valueAt(_local), v / 100),
            ),
          ],
        );
      case ModoDeTransformacao.inclinar:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CampoDeValor(
              rotulo: 'X Skew',
              valor: l.skewX.valueAt(_local),
              casas: 2,
              sufixo: '°',
              aoDigitar: (v) => _c.editSkewX(l.id, widget.tempo, v),
            ),
            const SizedBox(width: 8),
            CampoDeValor(
              rotulo: 'Y Skew',
              valor: l.skewY.valueAt(_local),
              casas: 2,
              sufixo: '°',
              aoDigitar: (v) => _c.editSkewY(l.id, widget.tempo, v),
            ),
          ],
        );
    }
  }

  // --------------------------------------------------- as superficies

  Widget _superficie(ModoDeTransformacao modo) {
    final l = widget.camada;
    switch (modo) {
      case ModoDeTransformacao.mover:
        final projeto = ref.watch(editorControllerProvider);
        // O GANHO TRADUZ DEDO EM COMPOSICAO.
        //
        // Um a um seria fiel e inutil: numa composicao de 1080 px vista
        // num painel de 300, atravessar a almofada inteira andaria menos
        // de um terco do quadro. Com este ganho, uma passada de dedo na
        // almofada percorre quase a largura da composicao, seja ela de
        // 720 ou de 4096.
        final ganho = projeto.outputWidth / 360;
        return AlmofadaDeArrasto(
          aoComecar: () {
            _posicaoAoComecar = l.position.valueAt(_local);
            _abrirLote();
          },
          aoMover: (d) => _c.editPosition(
            l.id,
            widget.tempo,
            _posicaoAoComecar + d * ganho,
          ),
          aoTerminar: _fecharLote,
        );
      case ModoDeTransformacao.girar:
        return DialDeAngulo(
          angulo: l.rotation.valueAt(_local),
          aoComecar: _abrirLote,
          aoMudar: (g) => _c.editRotation(l.id, widget.tempo, g),
          aoTerminar: _fecharLote,
        );
      case ModoDeTransformacao.escalar:
        final travada = ref.watch(escalaTravadaProvider);
        return Center(
          child: FitaDeAjuste(
            rotulo: 'Escala',
            valor: l.scaleX.valueAt(_local) * 100,
            // MEIO PONTO PERCENTUAL POR PIXEL: uma passada de dedo na
            // largura do painel cobre de 100% a 250%, que e a faixa em
            // que quase todo ajuste acontece.
            porPixel: .5,
            aoComecar: _abrirLote,
            aoMudar: (v) => _escalar(
              v / 100,
              travada ? v / 100 : l.scaleY.valueAt(_local),
            ),
            aoTerminar: _fecharLote,
          ),
        );
      case ModoDeTransformacao.inclinar:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FitaDeAjuste(
              rotulo: 'Inclinacao X',
              valor: l.skewX.valueAt(_local),
              porPixel: .25,
              altura: 62,
              aoComecar: _abrirLote,
              aoMudar: (v) => _c.editSkewX(l.id, widget.tempo, v),
              aoTerminar: _fecharLote,
            ),
            const SizedBox(height: 8),
            FitaDeAjuste(
              rotulo: 'Inclinacao Y',
              valor: l.skewY.valueAt(_local),
              porPixel: .25,
              altura: 62,
              // A SEGUNDA FITA NAO E A ATIVA: a linha central dela sai
              // branca, e e assim que se sabe qual das duas o dedo
              // estava mexendo na referencia.
              ativa: false,
              aoComecar: _abrirLote,
              aoMudar: (v) => _c.editSkewY(l.id, widget.tempo, v),
              aoTerminar: _fecharLote,
            ),
          ],
        );
    }
  }

  void _escalar(double x, double y) {
    if (ref.read(escalaTravadaProvider)) {
      _c.editScaleUniform(widget.camada.id, widget.tempo, x);
      return;
    }
    _c.editScaleX(widget.camada.id, widget.tempo, x);
    _c.editScaleY(widget.camada.id, widget.tempo, y);
  }
}

/// A CORRENTE entre Largura e Altura.
class _Corrente extends StatelessWidget {
  const _Corrente({required this.travada, required this.aoTocar});

  final bool travada;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: true,
    toggled: travada,
    label: travada
        ? 'Soltar largura e altura'
        : 'Travar largura e altura',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aoTocar,
      child: Container(
        width: 34,
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        // O CAMPO E A CORRENTE TEM A MESMA ALTURA de proposito: na
        // referencia os tres formam uma fileira so, e um botao mais
        // baixo quebraria a linha de base do numero.
        decoration: BoxDecoration(
          color: travada ? AmColors.chip : null,
          borderRadius: BorderRadius.circular(8),
          border: travada ? null : Border.all(color: AmColors.hairline),
        ),
        child: Icon(
          travada ? Icons.link_rounded : Icons.link_off_rounded,
          size: 15,
          color: travada ? AmColors.text : AmColors.muted,
        ),
      ),
    ),
  );
}
