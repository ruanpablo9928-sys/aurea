import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';
import '../../domain/audio_mix.dart';
import '../../domain/layer.dart';
import 'linha_de_parametro.dart';

/// O QUE A ULTIMA ACAO DE SOM RESPONDEU.
///
/// Normalizar e achar batidas sao acoes que podem NAO dar em nada — o
/// arquivo ainda nao foi analisado, a musica nao tem pulso claro. Um
/// botao que aceita o toque e fica igual e indistinguivel de um botao
/// quebrado; esta linha e a resposta.
final recadoDoSomProvider = StateProvider<String?>((ref) => null);

/// O SOM DA CAMADA: volume, entrada, saida, mudo, normalizar e batidas.
///
/// O cartao existia so para video, e chamava-se "Volume" porque so
/// havia volume. Tudo o resto ja estava no motor e sem porta:
/// `updateAudioSpec` (fade de entrada e de saida, mudo, ganho),
/// `normalizeAudio` e a familia de batida (`detectBeatsInto`, `setBpm`,
/// `clearBeats`, `cutAtMarkers`, `distributeAtMarkers`).
///
/// A camada de AUDIO ficava de fora por um `is!`: `editVideoVolume`
/// recusa o que nao for video, e o cartao seguia o comando. Ela tem
/// `volume`, o mixer le e a exportacao respeita — faltava o comando.
class PainelDeSom extends ConsumerWidget {
  const PainelDeSom({super.key, required this.camada});

  final Layer camada;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(editorControllerProvider.notifier);
    final projeto = ref.watch(editorControllerProvider);
    final spec = audioSpecOf(camada) ?? const AudioSpec();
    final volume = c.volumeOf(camada.id) ?? 1;
    final recado = ref.watch(recadoDoSomProvider);

    void dizer(String texto) =>
        ref.read(recadoDoSomProvider.notifier).state = texto;

    // O FADE E LIMITADO A METADE DO CLIPE.
    //
    // Entrada e saida com metade cada uma se encontram no meio e o
    // clipe nunca chega ao volume cheio; passar disso e um som que
    // some sem nunca ter aparecido.
    final metade = camada.duration.inMilliseconds / 2000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinhaDeParametro(
          rotulo: 'Volume',
          valor: volume * 100,
          casas: 0,
          sufixo: '%',
          porPixel: .6,
          escolhida: true,
          aoComecar: c.beginGesture,
          aoMudar: (v) => c.editVolume(camada.id, v / 100),
          aoTerminar: c.endGesture,
          aoDigitar: (v) => c.editVolume(camada.id, v / 100),
        ),
        LinhaDeParametro(
          rotulo: 'Aparecer',
          valor: spec.fadeIn.inMilliseconds / 1000,
          casas: 2,
          sufixo: 's',
          porPixel: metade <= 0 ? .01 : metade / 200,
          escolhida: true,
          aoComecar: c.beginGesture,
          aoMudar: (v) => _fade(c, camada, entrada: true, segundos: v),
          aoTerminar: c.endGesture,
          aoDigitar: (v) => _fade(c, camada, entrada: true, segundos: v),
        ),
        LinhaDeParametro(
          rotulo: 'Sumir',
          valor: spec.fadeOut.inMilliseconds / 1000,
          casas: 2,
          sufixo: 's',
          porPixel: metade <= 0 ? .01 : metade / 200,
          escolhida: true,
          aoComecar: c.beginGesture,
          aoMudar: (v) => _fade(c, camada, entrada: false, segundos: v),
          aoTerminar: c.endGesture,
          aoDigitar: (v) => _fade(c, camada, entrada: false, segundos: v),
        ),
        // MUDO NAO E O MESMO QUE OLHO FECHADO. O olho tira a camada do
        // preview inteiro; mudo guarda a imagem e larga so o som, que e
        // o caso comum de um video com audio de camera ruim.
        _Interruptor(
          rotulo: spec.muted ? 'Sem som (mudo)' : 'Tirar o som desta camada',
          icone: spec.muted
              ? Icons.volume_off_rounded
              : Icons.volume_up_rounded,
          ligado: spec.muted,
          aoTocar: () => c.updateAudioSpec(
            camada.id,
            (a) => a.copyWith(muted: !a.muted),
          ),
        ),
        _Acao(
          icone: Icons.equalizer_rounded,
          rotulo: 'Emparelhar o volume',
          detalhe: spec.normalizeTargetLufs != null
              ? 'Ja emparelhado; toque para refazer'
              : null,
          aoTocar: () {
            final g = c.normalizeAudio(camada.id);
            dizer(
              g == null
                  ? 'Ainda nao ha analise deste arquivo. Toque de novo em '
                        'alguns segundos.'
                  : 'Ganho ajustado para ${(g * 100).round()}%.',
            );
          },
        ),
        const _Titulo('Batidas'),
        _Aviso(
          projeto.beats.isEmpty
              ? 'Achar as batidas marca o pulso da musica na regua — e '
                    'dai da para cortar tudo no ritmo.'
              : '${projeto.beats.length} batidas'
                    '${projeto.bpm == null ? '' : ' a ${projeto.bpm!.round()} BPM'}'
                    ', marcadas na regua.',
        ),
        _Acao(
          icone: Icons.graphic_eq_rounded,
          rotulo: 'Achar as batidas',
          aoTocar: () async {
            dizer('Procurando...');
            final n = await c.detectBeatsInto(camada.id);
            dizer(
              n == null
                  ? 'Nao deu para achar um pulso claro nesta faixa.'
                  : '$n batidas achadas.',
            );
          },
        ),
        if (projeto.beats.isNotEmpty) ...[
          _Acao(
            icone: Icons.content_cut_rounded,
            rotulo: 'Cortar tudo nas batidas',
            aoTocar: () {
              final n = c.cutAtMarkers(usarBatidas: true);
              dizer('$n cortes.');
            },
          ),
          _Acao(
            icone: Icons.space_bar_rounded,
            rotulo: 'Espalhar as camadas nas batidas',
            aoTocar: () {
              final n = c.distributeAtMarkers(usarBatidas: true);
              dizer('$n camadas realinhadas.');
            },
          ),
          _Acao(
            icone: Icons.clear_rounded,
            rotulo: 'Tirar as batidas',
            aoTocar: () {
              c.clearBeats();
              dizer('Batidas apagadas.');
            },
          ),
        ],
        if (recado != null) _Aviso(recado),
      ],
    );
  }

  void _fade(
    EditorController c,
    Layer camada, {
    required bool entrada,
    required double segundos,
  }) {
    final teto = camada.duration.inMilliseconds ~/ 2;
    final ms = (segundos * 1000).round().clamp(0, teto < 0 ? 0 : teto);
    c.updateAudioSpec(
      camada.id,
      (a) => entrada
          ? a.copyWith(fadeIn: Duration(milliseconds: ms))
          : a.copyWith(fadeOut: Duration(milliseconds: ms)),
    );
  }
}

class _Acao extends StatelessWidget {
  const _Acao({
    required this.icone,
    required this.rotulo,
    required this.aoTocar,
    this.detalhe,
  });

  final IconData icone;
  final String rotulo;
  final VoidCallback aoTocar;
  final String? detalhe;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: true,
    label: rotulo,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aoTocar,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            const SizedBox(width: 6),
            Icon(icone, size: 19, color: AmColors.text),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rotulo,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AmColors.text,
                    ),
                  ),
                  if (detalhe != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        detalhe!,
                        style: TextStyle(
                          fontSize: 10,
                          color: AmColors.muted.withValues(alpha: .7),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
            const SizedBox(width: 6),
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
    padding: const EdgeInsets.fromLTRB(4, 14, 0, 4),
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
