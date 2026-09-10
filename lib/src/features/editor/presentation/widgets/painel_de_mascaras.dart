import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';
import '../../domain/layer.dart';
import '../../domain/mask.dart';
import 'linha_de_parametro.dart';
import 'rails_do_painel.dart';

/// QUAL MASCARA ESTA ABERTA, e qual parametro dela o rail mira.
final mascaraAbertaProvider = StateProvider<String?>((ref) => null);
final parametroDaMascaraProvider = StateProvider<String?>((ref) => null);

/// O ALVO DO RAIL quando a ferramenta aberta e a de mascara.
///
/// Mesma forma de `alvoDoParametroDeEfeito`: o losango marca o
/// parametro escolhido, e a curva fica apagada porque o comando de
/// curva por TRECHO que o motor tem e das propriedades da camada — a
/// trilha da mascara guarda a suavizacao no proprio keyframe, e abrir o
/// editor aqui daria uma curva sem onde escrever.
AlvoDoRail alvoDoParametroDaMascara(
  WidgetRef ref,
  Layer camada,
  Duration tempo,
) {
  final idMascara = ref.watch(mascaraAbertaProvider);
  final chave = ref.watch(parametroDaMascaraProvider);
  if (idMascara == null || chave == null) return const AlvoDoRail();
  final m = camada.masks.where((x) => x.id == idMascara).firstOrNull;
  if (m == null) return const AlvoDoRail();
  final trilha = switch (chave) {
    'feather' => m.feather,
    'featherY' => m.featherVertical,
    'expansion' => m.expansion,
    'opacity' => m.opacity,
    _ => null,
  };
  if (trilha == null) return const AlvoDoRail();

  final c = ref.read(editorControllerProvider.notifier);
  final local = camada.localTime(tempo);
  return AlvoDoRail(
    temKeyframeAqui: trilha.hasKeyframeAt(local),
    animado: trilha.isAnimated,
    aoAlternarKeyframe: () =>
        c.toggleMaskParamKeyframe(camada.id, m.id, chave, tempo),
    aoAbrirCurva: null,
  );
}

/// AS MASCARAS DA CAMADA.
///
/// A categoria inteira estava pronta no motor e trancada: `addMask`,
/// `removeMask`, `reorderMask`, `cycleMaskMode`, `toggleMaskInverted`,
/// `editMaskParam` e sete presets de revelacao (`applyMaskReveal`)
/// existiam, o palco desenhava a mascara e o arquivo a salvava — e
/// NENHUM widget chamava. Recurso pronto sem porta e o mesmo que
/// recurso ausente, com o agravante de ja ter sido pago.
///
/// A ficha segue a forma das outras: chip, fita e campo por parametro
/// (`docs/painel-de-transformacao-alight.md`). Mascara nao ganha
/// linguagem propria — quem aprendeu a mexer em opacidade ja sabe mexer
/// aqui.
class PainelDeMascaras extends ConsumerWidget {
  const PainelDeMascaras({
    super.key,
    required this.camada,
    required this.tempo,
  });

  final Layer camada;
  final Duration tempo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(editorControllerProvider.notifier);
    final aberta = ref.watch(mascaraAbertaProvider);
    final caixa = c.maskBox(camada.id, tempo);
    // NUNCA MENOR QUE UM TOQUE: uma camada de texto curta mede quase
    // nada, e uma mascara desse tamanho faria a camada sumir sem
    // explicacao. O piso deixa a mascara visivel para poder ser mexida.
    final w = caixa.width < 24 ? 240.0 : caixa.width;
    final h = caixa.height < 24 ? 240.0 : caixa.height;

    void criar(String nome, BezierPath caminho) {
      c.addMask(camada.id, LayerMask(name: nome, path: AnimatedPath(caminho)));
      _abrirUltima(ref);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (camada.masks.isEmpty)
          const _Aviso(
            'Sem mascara. Uma mascara recorta esta camada: o que fica '
            'dentro dela aparece, e o resto some.',
          ),
        for (var i = 0; i < camada.masks.length; i++) ...[
          _TituloDaMascara(
            mascara: camada.masks[i],
            aberta: camada.masks[i].id == aberta,
            podeSubir: i > 0,
            podeDescer: i < camada.masks.length - 1,
            aoAbrir: () => ref.read(mascaraAbertaProvider.notifier).state =
                camada.masks[i].id == aberta ? null : camada.masks[i].id,
            aoMover: (d) => c.reorderMask(camada.id, camada.masks[i].id, d),
            aoInverter: () =>
                c.toggleMaskInverted(camada.id, camada.masks[i].id),
            aoRemover: () {
              ref.read(mascaraAbertaProvider.notifier).state = null;
              c.removeMask(camada.id, camada.masks[i].id);
            },
          ),
          if (camada.masks[i].id == aberta)
            _FichaDaMascara(
              camada: camada,
              mascara: camada.masks[i],
              tempo: tempo,
            ),
        ],
        const _Titulo('Criar'),
        _GradeDeAcoes(
          itens: [
            ('Retangulo', () => criar('Retangulo', BezierPath.rect(w, h))),
            ('Elipse', () => criar('Elipse', BezierPath.ellipse(w, h))),
            (
              'Estrela',
              () => criar('Estrela', BezierPath.star(5, w / 2, w / 4)),
            ),
            ('Coracao', () => criar('Coracao', BezierPath.heart(w, h))),
          ],
        ),
        const _Titulo('Revelar'),
        // OS SETE PRESETS JA GRAVAM OS KEYFRAMES: cada um e uma mascara
        // comum com duas geometrias e a animacao entre elas pronta. Sao
        // o caminho mais curto que este app tem de uma camada parada
        // para uma camada que entra em cena — e seguem editaveis
        // depois, porque o preset nao cria nada especial.
        _GradeDeAcoes(
          itens: [
            for (final p in MaskRevealPreset.values)
              (
                p.label,
                () {
                  c.applyMaskReveal(camada.id, p, tempo);
                  _abrirUltima(ref);
                },
              ),
          ],
        ),
      ],
    );
  }

  /// Abre a ficha da mascara recem-criada.
  ///
  /// Quem acabou de escolher quer ajustar, e nao procurar de novo o que
  /// acabou de criar — a mesma regra do catalogo de efeitos.
  void _abrirUltima(WidgetRef ref) {
    final nova = ref
        .read(editorControllerProvider)
        .layers
        .where((l) => l.id == camada.id)
        .firstOrNull
        ?.masks
        .lastOrNull;
    if (nova == null) return;
    ref.read(mascaraAbertaProvider.notifier).state = nova.id;
    ref.read(parametroDaMascaraProvider.notifier).state = 'feather';
  }
}

class _TituloDaMascara extends StatelessWidget {
  const _TituloDaMascara({
    required this.mascara,
    required this.aberta,
    required this.podeSubir,
    required this.podeDescer,
    required this.aoAbrir,
    required this.aoMover,
    required this.aoInverter,
    required this.aoRemover,
  });

  final LayerMask mascara;
  final bool aberta;
  final bool podeSubir;
  final bool podeDescer;
  final VoidCallback aoAbrir;
  final void Function(int) aoMover;
  final VoidCallback aoInverter;
  final VoidCallback aoRemover;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            container: true,
            excludeSemantics: true,
            button: true,
            selected: aberta,
            label: mascara.name,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: aoAbrir,
              child: Row(
                children: [
                  Icon(
                    aberta
                        ? Icons.arrow_drop_down_rounded
                        : Icons.arrow_right_rounded,
                    size: 22,
                    color: AmColors.text,
                  ),
                  Flexible(
                    child: Text(
                      mascara.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AmColors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // A ORDEM DECIDE O DESENHO: subtrair depois de somar tira o que
        // a de cima poe. Sem estes dois, criar as duas na ordem errada
        // obrigaria a apagar e refazer.
        if (podeSubir)
          _IconeDaMascara(
            icone: Icons.keyboard_arrow_up_rounded,
            rotulo: 'Subir ${mascara.name}',
            aoTocar: () => aoMover(-1),
          ),
        if (podeDescer)
          _IconeDaMascara(
            icone: Icons.keyboard_arrow_down_rounded,
            rotulo: 'Descer ${mascara.name}',
            aoTocar: () => aoMover(1),
          ),
        _IconeDaMascara(
          icone: mascara.inverted
              ? Icons.flip_rounded
              : Icons.flip_to_front_rounded,
          rotulo: 'Inverter ${mascara.name}',
          aceso: mascara.inverted,
          aoTocar: aoInverter,
        ),
        _IconeDaMascara(
          icone: Icons.delete_outline_rounded,
          rotulo: 'Tirar ${mascara.name}',
          aoTocar: aoRemover,
        ),
      ],
    ),
  );
}

class _IconeDaMascara extends StatelessWidget {
  const _IconeDaMascara({
    required this.icone,
    required this.rotulo,
    required this.aoTocar,
    this.aceso = false,
  });

  final IconData icone;
  final String rotulo;
  final VoidCallback aoTocar;
  final bool aceso;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: true,
    toggled: aceso,
    label: rotulo,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aoTocar,
      child: SizedBox(
        width: 32,
        height: 40,
        child: Icon(
          icone,
          size: 17,
          color: aceso ? AmColors.accent : AmColors.muted,
        ),
      ),
    ),
  );
}

class _FichaDaMascara extends ConsumerWidget {
  const _FichaDaMascara({
    required this.camada,
    required this.mascara,
    required this.tempo,
  });

  final Layer camada;
  final LayerMask mascara;
  final Duration tempo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(editorControllerProvider.notifier);
    final local = camada.localTime(tempo);
    final escolhida = ref.watch(parametroDaMascaraProvider);

    /// [escala] traduz o que se MOSTRA no que se GRAVA.
    ///
    /// A opacidade da mascara e um fator de 0 a 1 no motor e uma
    /// porcentagem na tela. Sem esta divisao, a linha lia 100 e
    /// escrevia 100: o dedo saia de "100%" e chegava em "86%" gravando
    /// opacidade 86 — oitenta e seis vezes opaca, que e o mesmo que
    /// nada ter mudado. A linha mostrava um numero e gravava outro.
    LinhaDeParametro linha(
      String chave,
      String rotulo,
      double bruto,
      double teto, {
      int casas = 0,
      String sufixo = '',
      double escala = 1,
    }) {
      void escrever(double mostrado) => c.editMaskParam(
        camada.id,
        mascara.id,
        chave,
        tempo,
        mostrado / escala,
      );
      return LinhaDeParametro(
        rotulo: rotulo,
        valor: bruto * escala,
        casas: casas,
        sufixo: sufixo,
        // A FITA E RELATIVA: o teto so decide quanto o valor anda por
        // pixel de dedo. Uma passada na largura do painel cobre a faixa
        // util inteira, e passar dela continua possivel pelo campo.
        porPixel: teto / 300,
        escolhida: escolhida == chave,
        aoEscolher: () =>
            ref.read(parametroDaMascaraProvider.notifier).state = chave,
        aoComecar: c.beginGesture,
        aoMudar: escrever,
        aoTerminar: c.endGesture,
        aoDigitar: escrever,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Modos(
            atual: mascara.mode,
            aoTrocar: () => c.cycleMaskMode(camada.id, mascara.id),
          ),
          linha(
            'feather',
            mascara.featherLinked ? 'Suavidade' : 'Suavidade X',
            mascara.feather.valueAt(local),
            400,
          ),
          if (!mascara.featherLinked)
            linha(
              'featherY',
              'Suavidade Y',
              mascara.featherVertical.valueAt(local),
              400,
            ),
          // SOLTAR OS EIXOS da a borda dura dos lados e macia em cima —
          // que e como se faz um degrade de horizonte. Fica atras de um
          // interruptor porque e a excecao, e ligado nao gasta linha.
          _Interruptor(
            rotulo: mascara.featherLinked
                ? 'Soltar suavidade X e Y'
                : 'Ligar suavidade X e Y',
            ligado: !mascara.featherLinked,
            aoTocar: () => c.toggleMaskFeatherAxes(camada.id, mascara.id),
          ),
          linha('expansion', 'Expansao', mascara.expansion.valueAt(local), 400),
          linha(
            'opacity',
            'Opacidade',
            mascara.opacity.valueAt(local),
            100,
            sufixo: '%',
            escala: 100,
          ),
        ],
      ),
    );
  }
}

/// O MODO DA MASCARA, num chip que cicla.
///
/// Sete modos em chips lado a lado nao cabem nos 300 px do painel, e a
/// lista inteira raramente e usada: somar e subtrair respondem por
/// quase tudo. Um chip que mostra o vigente e avanca ao toque cabe, e
/// diz o estado sem esconder nenhuma opcao.
class _Modos extends StatelessWidget {
  const _Modos({required this.atual, required this.aoTrocar});

  final MaskMode atual;
  final VoidCallback aoTrocar;

  static String nomeDe(MaskMode m) => switch (m) {
    MaskMode.none => 'Nenhum',
    MaskMode.add => 'Somar',
    MaskMode.subtract => 'Subtrair',
    MaskMode.intersect => 'Interseccao',
    MaskMode.lighten => 'Clarear',
    MaskMode.darken => 'Escurecer',
    MaskMode.difference => 'Diferenca',
  };

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: true,
    label: 'Modo da mascara: ${nomeDe(atual)}',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aoTrocar,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const SizedBox(width: 6),
            const Text(
              'Modo',
              style: TextStyle(fontSize: 12, color: AmColors.muted),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AmColors.chip,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                nomeDe(atual),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AmColors.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GradeDeAcoes extends StatelessWidget {
  const _GradeDeAcoes({required this.itens});

  final List<(String, VoidCallback)> itens;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final (nome, acao) in itens)
        Semantics(
          container: true,
          excludeSemantics: true,
          button: true,
          label: nome,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: acao,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AmColors.chip,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                nome,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AmColors.text,
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class _Interruptor extends StatelessWidget {
  const _Interruptor({
    required this.rotulo,
    required this.ligado,
    required this.aoTocar,
  });

  final String rotulo;
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
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            const SizedBox(width: 6),
            Icon(
              ligado ? Icons.link_off_rounded : Icons.link_rounded,
              size: 17,
              color: ligado ? AmColors.accent : AmColors.muted,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                rotulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ligado ? AmColors.text : AmColors.muted,
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
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      texto,
      style: const TextStyle(fontSize: 11, color: AmColors.muted, height: 1.4),
    ),
  );
}
