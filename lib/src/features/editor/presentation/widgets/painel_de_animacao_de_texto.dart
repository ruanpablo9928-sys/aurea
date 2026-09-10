import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';
import '../../domain/layer.dart';
import '../../domain/text_anim.dart';
import '../../domain/text_animator.dart';
import '../../domain/text_presets.dart';
import 'controles_da_camada.dart' show casasParaFaixa;
import 'linha_de_parametro.dart';

/// QUAL POSICAO esta sendo ajustada: entrada, enfase ou saida.
final posicaoDaAnimacaoProvider = StateProvider<TextAnimSlot>(
  (ref) => TextAnimSlot.entrada,
);

/// A ANIMACAO DO TEXTO.
///
/// O catalogo tem 35 animacoes, o compilador transforma cada uma num
/// ANIMADOR de verdade (nada de caixa-preta: o resultado continua
/// editavel), o pintor por glifo desenha e o arquivo salva — e nenhum
/// widget chamava `setTextAnim`, `updateTextAnim`, `setTextAnimParam`,
/// `textAnimUnitCount` ou `applyTextPreset`. Sem isto, "tipografia
/// cinetica" era mover a caixa de texto inteira, que e animacao de
/// camada e nao de letra.
///
/// O CASO DE 90% SAO DOIS TOQUES: o cartao, e um chip do catalogo. A
/// posicao ja nasce em Entrada e `setTextAnim` ja traz duracao, atraso,
/// unidade e curva prontos do proprio spec. Nada abaixo da grade
/// aparece antes de existir uma animacao — nem apagado.
class PainelDeAnimacaoDeTexto extends ConsumerWidget {
  const PainelDeAnimacaoDeTexto({super.key, required this.camada});

  final Layer camada;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = camada;
    if (l is! TextLayer) return const SizedBox.shrink();
    final c = ref.read(editorControllerProvider.notifier);
    final slot = ref.watch(posicaoDaAnimacaoProvider);
    final anim = l.anims.where((a) => a.slot == slot).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Grade<TextAnimSlot>(
          prefixo: 'Posicao',
          itens: [
            for (final s in TextAnimSlot.values)
              (
                textAnimSlotLabel(s),
                s,
                // A BOLINHA DIZ ONDE JA HA COISA. Sem ela, descobrir
                // que a saida esta preenchida exige tocar nas tres.
                l.anims.any((a) => a.slot == s),
              ),
          ],
          atual: slot,
          aoTocar: (s) =>
              ref.read(posicaoDaAnimacaoProvider.notifier).state = s,
        ),
        _Grade<String?>(
          prefixo: 'Animacao',
          itens: [
            ('Nenhuma', null, false),
            for (final spec in textAnimsForSlot(slot))
              (spec.label, spec.id, false),
          ],
          atual: anim?.specId,
          // TOCAR NO CHIP JA ESCOLHIDO DESLIGA, e nunca reaplica:
          // `setTextAnim` RECRIA a instancia com os padroes do spec, e
          // reaplicar apagaria duracao, atraso e unidade que a pessoa
          // acabou de ajustar.
          aoTocar: (id) =>
              c.setTextAnim(l.id, slot, id == anim?.specId ? null : id),
        ),
        if (anim == null)
          const _Aviso(
            'Escolha uma animacao acima. Ela ja comeca com o tempo e a '
            'unidade que combinam com ela.',
          )
        else
          ..._ajustes(ref, c, l, anim, slot),
        const _Titulo('Prontos'),
        // OS PRESETS ANTIGOS ESCREVEM NOUTRO LUGAR (animadores crus), e
        // o motor SOMA os dois — sem limpar o catalogo antes, "Fade por
        // letra" empilharia em cima de "Aparecer" sem nenhum sinal de
        // que ha dois. Por isso a acao troca, e nao acumula.
        const _Aviso(
          'Um pronto substitui o que estiver montado aqui — ele escreve '
          'os animadores direto.',
        ),
        _GradeDeAcoes(
          itens: [
            for (final p in textPresets)
              (
                p.name,
                () {
                  c.runAsOneUndo(() {
                    for (final s in TextAnimSlot.values) {
                      c.setTextAnim(l.id, s, null);
                    }
                    c.applyTextPreset(l.id, p);
                  });
                },
              ),
          ],
        ),
        if (l.animators.isNotEmpty)
          _Acao(
            icone: Icons.clear_rounded,
            rotulo: 'Tirar o pronto (${l.animators.length} animador'
                '${l.animators.length > 1 ? 'es' : ''})',
            aoTocar: () => c.runAsOneUndo(() {
              for (final a in [...l.animators]) {
                c.removeTextAnimator(l.id, a.id);
              }
            }),
          ),
      ],
    );
  }

  // ------------------------------------------------------- os ajustes

  List<Widget> _ajustes(
    WidgetRef ref,
    EditorController c,
    TextLayer l,
    TextAnim anim,
    TextAnimSlot slot,
  ) {
    final spec = anim.spec;
    final quantas = c.textAnimUnitCount(l.id, anim.unit);
    final emLoop = spec?.loop ?? false;

    return [
      // A FICHA E GERADA DA TABELA, como a de efeito: sao 0, 1 ou 2
      // parametros em todo o catalogo, e escrever uma ficha por
      // animacao seriam 35 telas para manter em dia.
      if (spec != null && spec.params.isNotEmpty) ...[
        const _Titulo('Ajustes'),
        for (final p in spec.params)
          LinhaDeParametro(
            rotulo: p.label,
            nome: '${p.label} da animacao',
            valor: anim.params[p.key] ?? p.initial,
            casas: casasParaFaixa((p.max - p.min).abs()),
            sufixo: p.suffix,
            porPixel: (p.max - p.min).abs() / 300,
            aoComecar: c.beginGesture,
            aoMudar: (v) => c.setTextAnimParam(
              l.id,
              anim.id,
              p.key,
              v.clamp(p.min, p.max),
            ),
            aoTerminar: c.endGesture,
            aoDigitar: (v) => c.setTextAnimParam(
              l.id,
              anim.id,
              p.key,
              v.clamp(p.min, p.max),
            ),
          ),
      ],
      const _Titulo('Tempo'),
      _tempo(
        c,
        l,
        anim,
        'Duracao',
        anim.duration,
        4,
        (d) => anim.copyWith(duration: d),
      ),
      // O ATRASO E O QUE FAZ A LETRA SAIR ATRAS DA OUTRA. Com "Tudo
      // junto" o compilador o zera, entao a linha seria inerte — e
      // linha inerte e pior que linha ausente.
      if (anim.unit != TextAnimUnit.all)
        _tempo(
          c,
          l,
          anim,
          'Atraso',
          anim.stagger,
          1,
          (d) => anim.copyWith(stagger: d),
          nome: 'Atraso entre unidades',
        ),
      _tempo(
        c,
        l,
        anim,
        // NA SAIDA O TEMPO CONTA DO FIM DA CAMADA para tras. Chamar
        // isso de "Comecar" mentiria a direcao.
        slot == TextAnimSlot.saida ? 'Antes do fim' : 'Comecar',
        anim.start,
        2,
        (d) => anim.copyWith(start: d),
      ),
      const _Titulo('Como se espalha'),
      _Grade<TextAnimUnit>(
        prefixo: 'Unidade',
        itens: [
          for (final u in TextAnimUnit.values)
            (textAnimUnitLabel(u), u, false),
        ],
        atual: anim.unit,
        aoTocar: (u) =>
            c.updateTextAnim(l.id, anim.id, (a) => a.copyWith(unit: u)),
      ),
      // A CONTAGEM VIVA RESPONDE "por que esta demorando tanto": 40
      // letras a 55 ms de atraso sao mais de dois segundos so de
      // escalonamento.
      _Aviso(
        '$quantas ${textAnimUnitLabel(anim.unit).toLowerCase()}'
        '${anim.unit == TextAnimUnit.all ? '' : ' · '
              '${_emSegundos(anim.totalFor(quantas))} ao todo'}',
      ),
      _Grade<TextAnimOrder>(
        prefixo: 'Ordem',
        itens: [
          for (final o in TextAnimOrder.values)
            (textAnimOrderLabel(o), o, false),
        ],
        atual: anim.order,
        aoTocar: (o) =>
            c.updateTextAnim(l.id, anim.id, (a) => a.copyWith(order: o)),
      ),
      // A CURVA E INERTE NAS ANIMACOES DE LOOP e na maquina de
      // escrever: o compilador sai pelo ramo do loop (ou pelo de
      // duracao zero) antes de aplicar a suavizacao. Um chip ali
      // gravaria no projeto e nao moveria um pixel.
      if (!emLoop && anim.duration > Duration.zero) ...[
        const _Titulo('Curva'),
        _Grade<TextAnimEase>(
          prefixo: 'Curva',
          itens: [
            for (final e in TextAnimEase.values)
              (textAnimEaseLabel(e), e, false),
          ],
          atual: anim.ease,
          aoTocar: (e) =>
              c.updateTextAnim(l.id, anim.id, (a) => a.copyWith(ease: e)),
        ),
      ],
      _Interruptor(
        rotulo: anim.enabled ? 'Desligar a animacao' : 'Ligar a animacao',
        icone: anim.enabled
            ? Icons.toggle_on_rounded
            : Icons.toggle_off_rounded,
        ligado: anim.enabled,
        aoTocar: () => c.updateTextAnim(
          l.id,
          anim.id,
          (a) => a.copyWith(enabled: !a.enabled),
        ),
      ),
      _Acao(
        icone: Icons.delete_outline_rounded,
        rotulo:
            'Tirar a animacao de ${textAnimSlotLabel(slot).toLowerCase()}',
        aoTocar: () => c.setTextAnim(l.id, slot, null),
      ),
    ];
  }

  /// Uma linha de tempo em milissegundos.
  ///
  /// `Duration` de um lado e `double` do outro: a conversao mora aqui
  /// para o piso zero nao ficar espalhado. Atraso negativo inverteria a
  /// fase e duracao zero cairia no ramo de maquina de escrever — um
  /// arrasto para a esquerda transformaria "Subir" em "aparecer de
  /// estalo" sem explicacao.
  Widget _tempo(
    EditorController c,
    TextLayer l,
    TextAnim anim,
    String rotulo,
    Duration valor,
    double porPixel,
    TextAnim Function(Duration) escrever, {
    String? nome,
  }) {
    void aplicar(double ms) => c.updateTextAnim(
      l.id,
      anim.id,
      (_) => escrever(
        Duration(milliseconds: ms.round().clamp(0, 20000)),
      ),
    );
    return LinhaDeParametro(
      rotulo: rotulo,
      nome: nome ?? rotulo,
      valor: valor.inMilliseconds.toDouble(),
      casas: 0,
      sufixo: 'ms',
      porPixel: porPixel,
      aoComecar: c.beginGesture,
      aoMudar: aplicar,
      aoTerminar: c.endGesture,
      aoDigitar: aplicar,
    );
  }

  static String _emSegundos(Duration d) =>
      '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s';
}

/// Uma fileira de chips com o vigente aceso; o terceiro campo de cada
/// item acende uma bolinha (usado para dizer que a posicao ja tem
/// animacao).
class _Grade<T> extends StatelessWidget {
  const _Grade({
    required this.prefixo,
    required this.itens,
    required this.atual,
    required this.aoTocar,
  });

  final String prefixo;
  final List<(String, T, bool)> itens;
  final T? atual;
  final void Function(T) aoTocar;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (nome, valor, marcado) in itens)
          Semantics(
            container: true,
            excludeSemantics: true,
            button: true,
            selected: valor == atual,
            label: '$prefixo $nome',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => aoTocar(valor),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: valor == atual ? AmColors.chip : null,
                  borderRadius: BorderRadius.circular(8),
                  border: valor == atual
                      ? null
                      : Border.all(color: AmColors.hairline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (marcado) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AmColors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      nome,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: valor == atual
                            ? AmColors.accent
                            : AmColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
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
          label: 'Pronto $nome',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: acao,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
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

class _Acao extends StatelessWidget {
  const _Acao({
    required this.icone,
    required this.rotulo,
    required this.aoTocar,
  });

  final IconData icone;
  final String rotulo;
  final VoidCallback aoTocar;

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
            const SizedBox(width: 4),
            Icon(icone, size: 19, color: AmColors.text),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                rotulo,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AmColors.text,
                ),
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
