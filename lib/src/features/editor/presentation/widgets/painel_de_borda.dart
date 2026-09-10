import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';
import '../../domain/keyframe.dart';
import '../../domain/layer.dart';
import '../../domain/layer_meta.dart';
import '../../domain/shape.dart';
import 'escolha_de_cor.dart';
import 'linha_de_parametro.dart';
import 'rails_do_painel.dart';

/// QUAL SUBMODO DA FAMILIA "BORDA E SOMBRA" esta aberto.
///
/// Tres, como na referencia (V 00:50): Traco, Sombra e Brilho. O
/// primeiro e o unico aberto no video, e e o que nasce escolhido aqui.
enum SubmodoDaBorda { traco, sombra, brilho }

final submodoDaBordaProvider = StateProvider<SubmodoDaBorda>(
  (ref) => SubmodoDaBorda.traco,
);

/// Qual numero do subpainel o rail esquerdo esta mirando.
final parametroDaBordaProvider = StateProvider<String?>((ref) => null);

String rotuloDoSubmodoDaBorda(SubmodoDaBorda m) => switch (m) {
  SubmodoDaBorda.traco => 'Traco',
  SubmodoDaBorda.sombra => 'Sombra',
  SubmodoDaBorda.brilho => 'Brilho',
};

IconData _iconeDoSubmodo(SubmodoDaBorda m) => switch (m) {
  SubmodoDaBorda.traco => Icons.border_color_rounded,
  SubmodoDaBorda.sombra => Icons.dark_mode_rounded,
  SubmodoDaBorda.brilho => Icons.light_mode_rounded,
};

/// BORDA E SOMBRA (V 00:47,5–00:52).
///
/// O tile existia APAGADO, com "Chega numa proxima entrega" escrito
/// nele. E nao era falta de motor: `LayerStyles` ja tinha traco, duas
/// sombras, brilho e duas sobreposicoes, e `_applyLayerStyles` ja
/// desenhava tudo no palco. O que faltava era a porta — `setLayerStyles`
/// e `updateLayerStyles` nao tinham UM chamador na interface inteira.
///
/// A ORGANIZACAO E A DA REFERENCIA: coluna de tres submodos a direita,
/// subpainel com linha de titulo propria (amostra de cor, nome e
/// interruptor), e os numeros abaixo dela.
class PainelDeBorda extends ConsumerWidget {
  const PainelDeBorda({
    super.key,
    required this.camada,
    required this.tempo,
    required this.aoVoltar,
    required this.alvoDoRail,
  });

  final Layer camada;
  final Duration tempo;
  final VoidCallback aoVoltar;

  /// O alvo do rail esquerdo, resolvido pela tela: o subpainel nao sabe
  /// resolver keyframe sozinho.
  final AlvoDoRail Function(SubmodoDaBorda modo) alvoDoRail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modo = ref.watch(submodoDaBordaProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RailEsquerdo(aoVoltar: aoVoltar, alvo: alvoDoRail(modo)),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(4, 6, 8, 12),
            child: switch (modo) {
              SubmodoDaBorda.traco => _Traco(camada: camada, tempo: tempo),
              SubmodoDaBorda.sombra => _Sombra(camada: camada, tempo: tempo),
              SubmodoDaBorda.brilho => _Brilho(camada: camada, tempo: tempo),
            },
          ),
        ),
        // A COLUNA DA DIREITA, com os tres submodos.
        RailDireito(
          modos: [
            for (final m in SubmodoDaBorda.values)
              (_iconeDoSubmodo(m), rotuloDoSubmodoDaBorda(m)),
          ],
          vigente: SubmodoDaBorda.values.indexOf(modo),
          aoEscolher: (i) {
            ref.read(submodoDaBordaProvider.notifier).state =
                SubmodoDaBorda.values[i];
            ref.read(parametroDaBordaProvider.notifier).state = null;
          },
        ),
      ],
    );
  }
}

/// A LINHA DE TITULO DO SUBPAINEL: amostra de cor, nome e interruptor.
///
/// O interruptor a direita LIGA E DESLIGA o estilo sem perder os
/// numeros — que e a diferenca entre "experimentar sem" e "comecar de
/// novo".
class _TituloDoSubpainel extends StatelessWidget {
  const _TituloDoSubpainel({
    required this.nome,
    required this.cor,
    required this.ligado,
    required this.aoAlternar,
  });

  final String nome;
  final Color? cor;
  final bool ligado;
  final VoidCallback aoAlternar;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: Row(
      children: [
        if (cor != null) ...[
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: cor,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: AmColors.hairline),
            ),
          ),
          const SizedBox(width: 9),
        ],
        Expanded(
          child: Text(
            nome,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AmColors.text,
            ),
          ),
        ),
        Semantics(
          container: true,
          excludeSemantics: true,
          toggled: ligado,
          label: ligado ? 'Desligar $nome' : 'Ligar $nome',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: aoAlternar,
            child: Container(
              width: 40,
              height: 24,
              alignment: ligado ? Alignment.centerRight : Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: ligado ? AmColors.actionDim : AmColors.chip,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: ligado ? AmColors.action : AmColors.muted,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// O SUBPAINEL TRACO.
///
/// Numa forma ele edita o `ShapeStroke` de verdade — o mesmo que o
/// render desenha, com ponta, junta e tracejado. Nas outras camadas ele
/// edita o `LayerStyles.stroke`, que e o contorno que acompanha a forma
/// do que a camada desenha.
class _Traco extends ConsumerWidget {
  const _Traco({required this.camada, required this.tempo});

  final Layer camada;
  final Duration tempo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(editorControllerProvider.notifier);
    final projeto = ref.watch(projetoVisivelProvider);
    final l = projeto.layerById(camada.id) ?? camada;
    final local = l.localTime(tempo);
    final escolhido = ref.watch(parametroDaBordaProvider);

    if (l is ShapeLayer) {
      final traco = l.contents.whereType<ShapeStroke>().firstOrNull;
      if (traco == null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // O INTERRUPTOR CRIA O TRACO quando ainda nao ha nenhum: e o
            // mesmo alvo, e nao um botao a mais.
            _TituloDoSubpainel(
              nome: 'Traco',
              cor: null,
              ligado: false,
              aoAlternar: () => c.ensureShapeStroke(camada.id),
            ),
            const _Aviso(
              'Esta forma nao tem contorno. O interruptor acima cria um '
              'branco de doze pixels.',
            ),
          ],
        );
      }
      final trim = l.contents.whereType<TrimOperator>().firstOrNull;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TituloDoSubpainel(
            nome: 'Traco',
            cor: traco.color,
            ligado: true,
            aoAlternar: () => c.removeShapeStroke(camada.id),
          ),
          EscolhaDeCor(
            rotulo: 'Cor do traco',
            cor: traco.color,
            aoComecar: c.beginGesture,
            aoTerminar: c.endGesture,
            aoMudar: (cor) =>
                c.updateShapeStroke(camada.id, (s) => s.copyWith(color: cor)),
          ),
          LinhaDeParametro(
            rotulo: 'Espessura',
            nome: 'Espessura do traco',
            valor: traco.width.valueAt(local),
            casas: 0,
            porPixel: 100 / 300,
            escolhida: escolhido == 'width',
            aoEscolher: () =>
                ref.read(parametroDaBordaProvider.notifier).state = 'width',
            aoComecar: c.beginGesture,
            aoMudar: (v) =>
                c.editShapeItemTrack(camada.id, traco.id, 'width', tempo, v),
            aoTerminar: c.endGesture,
            aoDigitar: (v) =>
                c.editShapeItemTrack(camada.id, traco.id, 'width', tempo, v),
          ),
          LinhaDeParametro(
            rotulo: 'Opacidade',
            nome: 'Opacidade do traco',
            valor: traco.opacity.valueAt(local) * 100,
            casas: 0,
            sufixo: '%',
            porPixel: .4,
            escolhida: escolhido == 'opacity',
            aoEscolher: () =>
                ref.read(parametroDaBordaProvider.notifier).state = 'opacity',
            aoComecar: c.beginGesture,
            aoMudar: (v) => c.editShapeItemTrack(
              camada.id,
              traco.id,
              'opacity',
              tempo,
              v / 100,
            ),
            aoTerminar: c.endGesture,
            aoDigitar: (v) => c.editShapeItemTrack(
              camada.id,
              traco.id,
              'opacity',
              tempo,
              v / 100,
            ),
          ),
          // A FILEIRA DE SEIS OPCOES GRAFICAS.
          //
          // Nao sao decoracao: sao as tres pontas e as tres juntas que o
          // `ShapeStroke` ja tinha (`cap` e `join`) e que nunca tiveram
          // controle nenhum. Uma de cada grupo fica marcada.
          const _Titulo('Ponta e junta'),
          Row(
            children: [
              for (final (cap, rotulo, icone) in const [
                (StrokeCap.butt, 'Ponta reta', Icons.horizontal_rule_rounded),
                (StrokeCap.round, 'Ponta redonda', Icons.circle),
                (StrokeCap.square, 'Ponta quadrada', Icons.square_rounded),
              ])
                _OpcaoGrafica(
                  rotulo: rotulo,
                  icone: icone,
                  aceso: traco.cap == cap,
                  aoTocar: () => c.updateShapeStroke(
                    camada.id,
                    (s) => s.copyWith(cap: cap),
                  ),
                ),
              const SizedBox(width: 8),
              for (final (join, rotulo, icone) in const [
                (StrokeJoin.miter, 'Junta em bico', Icons.change_history_rounded),
                (StrokeJoin.round, 'Junta redonda', Icons.circle_outlined),
                (StrokeJoin.bevel, 'Junta chanfrada', Icons.hexagon_outlined),
              ])
                _OpcaoGrafica(
                  rotulo: rotulo,
                  icone: icone,
                  aceso: traco.join == join,
                  aoTocar: () => c.updateShapeStroke(
                    camada.id,
                    (s) => s.copyWith(join: join),
                  ),
                ),
            ],
          ),
          // "INICIAR" E "FIM": o traco que se desenha sozinho.
          //
          // No motor e o `TrimOperator`, que existia com zero chamadores
          // — o recurso mais pedido de motion e o que faz uma linha se
          // desenhar na tela.
          const _Titulo('Desenhar o traco'),
          if (trim == null)
            _Botao(
              rotulo: 'Iniciar e Fim',
              aoTocar: () => c.ensureShapeTrim(camada.id),
            )
          else ...[
            LinhaDeParametro(
              rotulo: 'Iniciar',
              nome: 'Iniciar o traco',
              valor: trim.start.valueAt(local) * 100,
              casas: 0,
              sufixo: '%',
              porPixel: .4,
              escolhida: escolhido == 'start',
              aoEscolher: () =>
                  ref.read(parametroDaBordaProvider.notifier).state = 'start',
              aoComecar: c.beginGesture,
              aoMudar: (v) => c.editShapeItemTrack(
                camada.id,
                trim.id,
                'start',
                tempo,
                v / 100,
              ),
              aoTerminar: c.endGesture,
              aoDigitar: (v) => c.editShapeItemTrack(
                camada.id,
                trim.id,
                'start',
                tempo,
                v / 100,
              ),
            ),
            LinhaDeParametro(
              rotulo: 'Fim',
              nome: 'Fim do traco',
              valor: trim.end.valueAt(local) * 100,
              casas: 0,
              sufixo: '%',
              porPixel: .4,
              escolhida: escolhido == 'end',
              aoEscolher: () =>
                  ref.read(parametroDaBordaProvider.notifier).state = 'end',
              aoComecar: c.beginGesture,
              aoMudar: (v) => c.editShapeItemTrack(
                camada.id,
                trim.id,
                'end',
                tempo,
                v / 100,
              ),
              aoTerminar: c.endGesture,
              aoDigitar: (v) => c.editShapeItemTrack(
                camada.id,
                trim.id,
                'end',
                tempo,
                v / 100,
              ),
            ),
            _Botao(
              rotulo: 'Tirar o desenho do traco',
              perigo: true,
              aoTocar: () => c.removeShapeTrim(camada.id),
            ),
          ],
        ],
      );
    }

    // AS OUTRAS CAMADAS usam o contorno de ESTILO, que acompanha a forma
    // do que a camada desenha (texto, imagem, video).
    final estilo = projeto.metaOf(camada.id).styles.stroke;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TituloDoSubpainel(
          nome: 'Traco',
          cor: estilo?.color,
          ligado: estilo?.enabled ?? false,
          aoAlternar: () => c.updateLayerStyles(
            camada.id,
            (s) => estilo == null
                ? s.copyWith(stroke: StrokeStyle())
                : s.copyWith(stroke: estilo.copyWith(enabled: !estilo.enabled)),
          ),
        ),
        if (estilo == null)
          const _Aviso(
            'Sem contorno ainda. O interruptor acima cria um branco de '
            'quatro pixels.',
          )
        else ...[
          EscolhaDeCor(
            rotulo: 'Cor do traco',
            cor: estilo.color,
            aoComecar: c.beginGesture,
            aoTerminar: c.endGesture,
            aoMudar: (cor) => c.updateLayerStyles(
              camada.id,
              (s) => s.copyWith(stroke: estilo.copyWith(color: cor)),
            ),
          ),
          LinhaDeParametro(
            rotulo: 'Espessura',
            nome: 'Espessura do traco',
            valor: estilo.width.valueAt(local),
            casas: 0,
            porPixel: 60 / 300,
            aoComecar: c.beginGesture,
            aoMudar: (v) => c.updateLayerStyles(
              camada.id,
              (s) => s.copyWith(
                stroke: estilo.copyWith(width: AnimatedDouble(v)),
              ),
            ),
            aoTerminar: c.endGesture,
            aoDigitar: (v) => c.updateLayerStyles(
              camada.id,
              (s) => s.copyWith(
                stroke: estilo.copyWith(width: AnimatedDouble(v)),
              ),
            ),
          ),
          LinhaDeParametro(
            rotulo: 'Opacidade',
            nome: 'Opacidade do traco',
            valor: estilo.opacity.valueAt(local) * 100,
            casas: 0,
            sufixo: '%',
            porPixel: .4,
            aoComecar: c.beginGesture,
            aoMudar: (v) => c.updateLayerStyles(
              camada.id,
              (s) => s.copyWith(
                stroke: estilo.copyWith(opacity: AnimatedDouble(v / 100)),
              ),
            ),
            aoTerminar: c.endGesture,
            aoDigitar: (v) => c.updateLayerStyles(
              camada.id,
              (s) => s.copyWith(
                stroke: estilo.copyWith(opacity: AnimatedDouble(v / 100)),
              ),
            ),
          ),
          _Botao(
            rotulo: 'Remover o contorno',
            perigo: true,
            aoTocar: () =>
                c.updateLayerStyles(camada.id, (s) => s.copyWith(clearStroke: true)),
          ),
        ],
      ],
    );
  }
}

/// O SUBPAINEL SOMBRA: a que cai fora e a que cai dentro.
class _Sombra extends ConsumerWidget {
  const _Sombra({required this.camada, required this.tempo});

  final Layer camada;
  final Duration tempo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(editorControllerProvider.notifier);
    final projeto = ref.watch(projetoVisivelProvider);
    final estilos = projeto.metaOf(camada.id).styles;
    final local = camada.localTime(tempo);

    Widget bloco({
      required String nome,
      required ShadowStyle? estilo,
      required LayerStyles Function(LayerStyles, ShadowStyle?) escrever,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TituloDoSubpainel(
          nome: nome,
          cor: estilo?.color,
          ligado: estilo?.enabled ?? false,
          aoAlternar: () => c.updateLayerStyles(
            camada.id,
            (s) => escrever(
              s,
              estilo == null
                  ? ShadowStyle()
                  : estilo.copyWith(enabled: !estilo.enabled),
            ),
          ),
        ),
        if (estilo != null) ...[
          EscolhaDeCor(
            rotulo: 'Cor de $nome',
            cor: estilo.color,
            aoComecar: c.beginGesture,
            aoTerminar: c.endGesture,
            aoMudar: (cor) => c.updateLayerStyles(
              camada.id,
              (s) => escrever(s, estilo.copyWith(color: cor)),
            ),
          ),
          for (final (rotulo, valor, escala, sufixo, aplicar)
              in <(String, double, double, String, ShadowStyle Function(double))>[
            (
              'Distancia',
              estilo.distance.valueAt(local),
              1,
              ' px',
              (v) => estilo.copyWith(distance: AnimatedDouble(v)),
            ),
            (
              'Angulo',
              estilo.angleDeg.valueAt(local),
              1,
              '°',
              (v) => estilo.copyWith(angleDeg: AnimatedDouble(v)),
            ),
            (
              'Desfoque',
              estilo.size.valueAt(local),
              1,
              ' px',
              (v) => estilo.copyWith(size: AnimatedDouble(v)),
            ),
            (
              'Opacidade',
              estilo.opacity.valueAt(local) * 100,
              100,
              '%',
              (v) => estilo.copyWith(opacity: AnimatedDouble(v / 100)),
            ),
          ])
            LinhaDeParametro(
              rotulo: rotulo,
              nome: '$rotulo de $nome',
              valor: valor,
              casas: 0,
              sufixo: sufixo,
              porPixel: escala == 100 ? .4 : 100 / 300,
              aoComecar: c.beginGesture,
              aoMudar: (v) =>
                  c.updateLayerStyles(camada.id, (s) => escrever(s, aplicar(v))),
              aoTerminar: c.endGesture,
              aoDigitar: (v) =>
                  c.updateLayerStyles(camada.id, (s) => escrever(s, aplicar(v))),
            ),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        bloco(
          nome: 'Sombra projetada',
          estilo: estilos.dropShadow,
          escrever: (s, novo) => novo == null
              ? s.copyWith(clearDropShadow: true)
              : s.copyWith(dropShadow: novo),
        ),
        const SizedBox(height: 8),
        bloco(
          nome: 'Sombra interna',
          estilo: estilos.innerShadow,
          escrever: (s, novo) => novo == null
              ? s.copyWith(clearInnerShadow: true)
              : s.copyWith(innerShadow: novo),
        ),
      ],
    );
  }
}

/// O SUBPAINEL BRILHO.
class _Brilho extends ConsumerWidget {
  const _Brilho({required this.camada, required this.tempo});

  final Layer camada;
  final Duration tempo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(editorControllerProvider.notifier);
    final projeto = ref.watch(projetoVisivelProvider);
    final brilho = projeto.metaOf(camada.id).styles.outerGlow;
    final local = camada.localTime(tempo);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TituloDoSubpainel(
          nome: 'Brilho externo',
          cor: brilho?.color,
          ligado: brilho?.enabled ?? false,
          aoAlternar: () => c.updateLayerStyles(
            camada.id,
            (s) => s.copyWith(
              outerGlow: brilho == null
                  ? GlowStyle()
                  : brilho.copyWith(enabled: !brilho.enabled),
            ),
          ),
        ),
        if (brilho == null)
          const _Aviso(
            'Sem brilho ainda. O interruptor acima cria um branco suave.',
          )
        else ...[
          EscolhaDeCor(
            rotulo: 'Cor do brilho',
            cor: brilho.color,
            aoComecar: c.beginGesture,
            aoTerminar: c.endGesture,
            aoMudar: (cor) => c.updateLayerStyles(
              camada.id,
              (s) => s.copyWith(outerGlow: brilho.copyWith(color: cor)),
            ),
          ),
          LinhaDeParametro(
            rotulo: 'Tamanho',
            nome: 'Tamanho do brilho',
            valor: brilho.size.valueAt(local),
            casas: 0,
            sufixo: ' px',
            porPixel: 100 / 300,
            aoComecar: c.beginGesture,
            aoMudar: (v) => c.updateLayerStyles(
              camada.id,
              (s) => s.copyWith(
                outerGlow: brilho.copyWith(size: AnimatedDouble(v)),
              ),
            ),
            aoTerminar: c.endGesture,
            aoDigitar: (v) => c.updateLayerStyles(
              camada.id,
              (s) => s.copyWith(
                outerGlow: brilho.copyWith(size: AnimatedDouble(v)),
              ),
            ),
          ),
          LinhaDeParametro(
            rotulo: 'Opacidade',
            nome: 'Opacidade do brilho',
            valor: brilho.opacity.valueAt(local) * 100,
            casas: 0,
            sufixo: '%',
            porPixel: .4,
            aoComecar: c.beginGesture,
            aoMudar: (v) => c.updateLayerStyles(
              camada.id,
              (s) => s.copyWith(
                outerGlow: brilho.copyWith(opacity: AnimatedDouble(v / 100)),
              ),
            ),
            aoTerminar: c.endGesture,
            aoDigitar: (v) => c.updateLayerStyles(
              camada.id,
              (s) => s.copyWith(
                outerGlow: brilho.copyWith(opacity: AnimatedDouble(v / 100)),
              ),
            ),
          ),
          _Botao(
            rotulo: 'Remover o brilho',
            perigo: true,
            aoTocar: () => c.updateLayerStyles(
              camada.id,
              (s) => s.copyWith(clearOuterGlow: true),
            ),
          ),
        ],
      ],
    );
  }
}

class _OpcaoGrafica extends StatelessWidget {
  const _OpcaoGrafica({
    required this.rotulo,
    required this.icone,
    required this.aceso,
    required this.aoTocar,
  });

  final String rotulo;
  final IconData icone;
  final bool aceso;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: true,
    selected: aceso,
    label: rotulo,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aoTocar,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: aceso ? AmColors.chip : null,
          borderRadius: BorderRadius.circular(8),
          border: aceso ? null : Border.all(color: AmColors.hairline),
        ),
        child: Icon(
          icone,
          size: 16,
          color: aceso ? AmColors.accent : AmColors.muted,
        ),
      ),
    ),
  );
}

class _Botao extends StatelessWidget {
  const _Botao({
    required this.rotulo,
    required this.aoTocar,
    this.perigo = false,
  });

  final String rotulo;
  final VoidCallback aoTocar;
  final bool perigo;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: true,
    label: rotulo,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aoTocar,
      child: SizedBox(
        height: 44,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            rotulo,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
              decorationColor: perigo ? AmColors.pink : AmColors.accent,
              color: perigo ? AmColors.pink : AmColors.accent,
            ),
          ),
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
    padding: const EdgeInsets.fromLTRB(2, 12, 0, 6),
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
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
    child: Text(
      texto,
      style: const TextStyle(fontSize: 11, height: 1.4, color: AmColors.muted),
    ),
  );
}
