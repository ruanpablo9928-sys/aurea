import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';
import '../../application/playback_controller.dart';
import '../../domain/layer.dart';
import 'painel_da_camada.dart';

/// A BARRA TEMPORAL DA CAMADA (V 00:40, acima da grade de acoes).
///
/// As tres coisas que mais se fazem com o TEMPO de uma camada — aparar,
/// dividir, mudar a velocidade — ficavam espalhadas: velocidade e som
/// eram tiles condicionais da grade, e dividir estava enterrado a tres
/// toques dentro do cartao "Camada". No AM elas moram numa faixa propria
/// logo acima da grade, e valem para qualquer tipo de camada.
///
/// OS SIMBOLOS RESPONDEM AO CABECOTE. Com o cabecote dentro do segmento,
/// dividir acende e as duas alcas aparam ate ele. Fora do segmento nao
/// ha o que dividir nem ate onde aparar, e a alca vira "levar o cabecote
/// ate a camada" — que e a acao que destrava as outras.
class BarraTemporalDaCamada extends ConsumerWidget {
  const BarraTemporalDaCamada({
    super.key,
    required this.camada,
    required this.playback,
  });

  final Layer camada;
  final PlaybackController playback;

  static const double altura = 40;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ValueListenableBuilder<Duration>(
        valueListenable: playback.time,
        builder: (context, agora, _) {
          final c = ref.read(editorControllerProvider.notifier);
          final dentro =
              agora > camada.startTime + const Duration(milliseconds: 100) &&
              agora < camada.endTime - const Duration(milliseconds: 100);
          final temSom = camada is VideoLayer || camada is AudioLayer;
          return SizedBox(
            height: altura,
            child: Row(
              children: [
                _Alvo(
                  icone: dentro
                      ? Icons.first_page_rounded
                      : Icons.keyboard_tab_rounded,
                  rotulo: dentro
                      ? 'Aparar o comeco ate o cabecote'
                      : 'Levar o cabecote ate o comeco da camada',
                  aoTocar: () => dentro
                      ? c.trimLayerStart(camada.id, agora)
                      : playback.seek(camada.startTime),
                ),
                _Alvo(
                  icone: Icons.content_cut_rounded,
                  rotulo: 'Dividir no cabecote',
                  porQueNao: dentro
                      ? null
                      : 'Leve o cabecote para dentro da camada',
                  aoTocar: () => c.splitLayer(camada.id, agora),
                ),
                _Alvo(
                  icone: dentro
                      ? Icons.last_page_rounded
                      : Icons.keyboard_tab_rounded,
                  rotulo: dentro
                      ? 'Aparar o fim ate o cabecote'
                      : 'Levar o cabecote ate o fim da camada',
                  aoTocar: () => dentro
                      ? c.trimLayerEnd(camada.id, agora)
                      : playback.seek(
                          camada.endTime - const Duration(milliseconds: 1),
                        ),
                ),
                const _Risco(),
                _Alvo(
                  icone: Icons.speed_rounded,
                  rotulo: 'Velocidade',
                  porQueNao: temSom
                      ? null
                      : 'So midia com duracao propria muda de velocidade',
                  aoTocar: () => abrirCategoria(ref, 'velocidade'),
                ),
                _Alvo(
                  icone: Icons.volume_up_rounded,
                  rotulo: 'Som',
                  porQueNao: temSom ? null : 'Esta camada nao tem som',
                  aoTocar: () => abrirCategoria(ref, 'som'),
                ),
                const Spacer(),
                // A DURACAO EM NUMERO, que e o que a barra toda mexe.
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Semantics(
                    container: true,
                    excludeSemantics: true,
                    label: 'Duracao da camada',
                    value: _emSegundos(camada.duration),
                    child: Text(
                      _emSegundos(camada.duration),
                      style: const TextStyle(
                        fontSize: 11,
                        fontFeatures: [FontFeature.tabularFigures()],
                        color: AmColors.muted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
}

String _emSegundos(Duration d) =>
    '${(d.inMilliseconds / 1000).toStringAsFixed(1)} s';

/// ABRE UMA FAMILIA pelo id, do jeito que a grade abre.
void abrirCategoria(WidgetRef ref, String id) {
  ref.read(estadoDoPainelProvider.notifier).state = EstadoDoPainel.categoria;
  ref.read(categoriaAbertaProvider.notifier).state = id;
}

class _Alvo extends StatelessWidget {
  const _Alvo({
    required this.icone,
    required this.rotulo,
    required this.aoTocar,
    this.porQueNao,
  });

  final IconData icone;
  final String rotulo;
  final VoidCallback aoTocar;
  final String? porQueNao;

  @override
  Widget build(BuildContext context) {
    final pode = porQueNao == null;
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: pode,
      label: rotulo,
      hint: porQueNao,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: pode ? aoTocar : null,
        child: SizedBox(
          width: 44,
          height: BarraTemporalDaCamada.altura,
          child: Icon(
            icone,
            size: 18,
            color: pode ? AmColors.text : AmColors.muted.withValues(alpha: .45),
          ),
        ),
      ),
    );
  }
}

class _Risco extends StatelessWidget {
  const _Risco();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 18,
    margin: const EdgeInsets.symmetric(horizontal: 5),
    color: AmColors.hairline,
  );
}
