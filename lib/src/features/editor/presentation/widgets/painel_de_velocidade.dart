import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';
import '../../domain/audio_mix.dart';
import '../../domain/cut.dart';
import '../../domain/layer.dart';
import 'linha_de_parametro.dart';

/// O recado da ultima acao de velocidade.
final recadoDaVelocidadeProvider = StateProvider<String?>((ref) => null);

/// A VELOCIDADE DO CLIPE.
///
/// Tudo aqui ja existia no motor e nao tinha porta: `setClipSpeed`
/// (que ja empurra o que vem depois, para acelerar no meio nao deixar
/// buraco), `setClipReverse` com a guarda do proxy, `setClipSpeedBlur`,
/// `setClipInterpolacao`, `setClipPreservePitch` e as quatro rampas
/// prontas de `applySpeedRamp`.
///
/// A barra na linha do tempo mostra o tempo FINAL: acelerar encurta a
/// barra. O que se guarda e o FATOR, e nao "quanto de fonte cabe" — e
/// e isso que faz voltar para 1x devolver o clipe inteiro.
class PainelDeVelocidade extends ConsumerWidget {
  const PainelDeVelocidade({super.key, required this.camada});

  final Layer camada;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(editorControllerProvider.notifier);
    ref.watch(editorControllerProvider);
    final velocidade = c.clipSpeedOf(camada.id);
    final video = camada is VideoLayer ? camada as VideoLayer : null;
    final spec = audioSpecOf(camada) ?? const AudioSpec();
    final recado = ref.watch(recadoDaVelocidadeProvider);
    final rampa = c.clipHasTimeRemap(camada.id);

    void dizer(String? texto) =>
        ref.read(recadoDaVelocidadeProvider.notifier).state = texto;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinhaDeParametro(
          rotulo: 'Velocidade',
          valor: velocidade,
          casas: 2,
          sufixo: 'x',
          // O DEDO ANDA EM PASSOS PEQUENOS: a faixa util fica entre .25
          // e 4, e um por pixel jogaria o clipe no teto de 10x com meia
          // passada. Passar disso continua possivel pelo campo.
          porPixel: .02,
          escolhida: true,
          aoComecar: c.beginGesture,
          aoMudar: (v) => c.setClipSpeed(camada.id, v),
          aoTerminar: c.endGesture,
          aoDigitar: (v) => c.setClipSpeed(camada.id, v),
        ),
        _Escolhas(
          rotulo: 'Atalhos',
          itens: const ['0,25x', '0,5x', '1x', '2x', '4x'],
          valores: const [.25, .5, 1.0, 2.0, 4.0],
          atual: velocidade,
          aoEscolher: (v) => c.setClipSpeed(camada.id, v),
        ),
        // ACELERAR SOM SOBE O TOM. Manter o tom e o padrao porque e o
        // que quase todo mundo quer; desligar imita fita e disco, e o
        // controle diz isso em vez de fingir que nao acontece.
        _Interruptor(
          rotulo: spec.preservePitch
              ? 'Mantendo o tom da voz'
              : 'Deixar o tom subir e descer',
          icone: spec.preservePitch
              ? Icons.record_voice_over_rounded
              : Icons.album_rounded,
          ligado: spec.preservePitch,
          aoTocar: () =>
              c.setClipPreservePitch(camada.id, !spec.preservePitch),
        ),
        if (video != null) ...[
          _Interruptor(
            rotulo: video.reverse
                ? 'De tras para a frente'
                : 'Tocar de tras para a frente',
            icone: Icons.fast_rewind_rounded,
            ligado: video.reverse,
            aoTocar: () {
              final feito = c.setClipReverse(camada.id, !video.reverse);
              dizer(
                feito
                    ? null
                    : 'Este video e longo demais para inverter sem uma '
                          'versao leve pronta. Tente de novo daqui a pouco.',
              );
            },
          ),
          _Interruptor(
            rotulo: 'Borrao de movimento',
            icone: Icons.motion_photos_on_rounded,
            ligado: video.speedBlur,
            aoTocar: () => c.setClipSpeedBlur(camada.id, !video.speedBlur),
          ),
          // QUADRO QUE A FONTE NAO TEM: a camera lenta pede mais quadros
          // do que o arquivo guarda. Repetir e o que todo editor faz por
          // padrao; mesclar e barato; movimento e caro e e o que da a
          // camera lenta lisa. So vale na exportacao — a previa mostra o
          // quadro mais proximo — e a ficha diz isso.
          _Titulo('Quadros que faltam'),
          _Escolhas(
            rotulo: 'Inventar',
            itens: [
              for (final i in InterpolacaoDeQuadros.values) i.emPalavras,
            ],
            valores: [
              for (var i = 0; i < InterpolacaoDeQuadros.values.length; i++)
                i.toDouble(),
            ],
            atual: video.interpolacao.index.toDouble(),
            aoEscolher: (v) => c.setClipInterpolacao(
              camada.id,
              InterpolacaoDeQuadros.values[v.round()],
            ),
          ),
          const _Aviso(
            'Vale na exportacao. A previa sempre mostra o quadro mais '
            'proximo, que e o que o aparelho consegue na hora.',
          ),
          const _Titulo('Rampas'),
          _Aviso(
            rampa
                ? 'Este clipe esta com uma rampa. A velocidade acima volta '
                      'a mandar quando voce mexer nela.'
                : 'Uma rampa muda a velocidade DENTRO do clipe, sem mudar a '
                      'duracao dele.',
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in SpeedRampPreset.values)
                _Botao(
                  rotulo: p.label,
                  aoTocar: () {
                    c.applySpeedRamp(camada.id, p);
                    dizer('Rampa "${p.label}" aplicada.');
                  },
                ),
            ],
          ),
        ],
        if (recado != null) _Aviso(recado),
      ],
    );
  }
}

/// Uma fileira de valores prontos, com o vigente aceso.
class _Escolhas extends StatelessWidget {
  const _Escolhas({
    required this.rotulo,
    required this.itens,
    required this.valores,
    required this.atual,
    required this.aoEscolher,
  });

  final String rotulo;
  final List<String> itens;
  final List<double> valores;
  final double atual;
  final void Function(double) aoEscolher;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < itens.length; i++)
          _Botao(
            rotulo: itens[i],
            nome: '$rotulo ${itens[i]}',
            aceso: (valores[i] - atual).abs() < .005,
            aoTocar: () => aoEscolher(valores[i]),
          ),
      ],
    ),
  );
}

class _Botao extends StatelessWidget {
  const _Botao({
    required this.rotulo,
    required this.aoTocar,
    this.nome,
    this.aceso = false,
  });

  final String rotulo;
  final String? nome;
  final bool aceso;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: true,
    selected: aceso,
    label: nome ?? rotulo,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aoTocar,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: aceso ? AmColors.chip : null,
          borderRadius: BorderRadius.circular(8),
          border: aceso ? null : Border.all(color: AmColors.hairline),
        ),
        child: Text(
          rotulo,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: aceso ? AmColors.accent : AmColors.text,
          ),
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
