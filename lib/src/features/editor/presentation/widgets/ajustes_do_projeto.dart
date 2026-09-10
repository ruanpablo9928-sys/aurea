import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';
import 'escolha_de_cor.dart';
import 'painel_da_camada.dart';

/// AS CONFIGURACOES DO PROJETO, num sheet inferior (V 01:47).
///
/// A entrada e a ENGRENAGEM do cabecalho, ao lado do exportar — nao o
/// toque no nome do projeto, que era o unico caminho e nao tem
/// correspondencia na referencia. O sheet abre SEM sair do editor: a
/// faixa de cima continua visivel e a timeline volta como estava.
///
/// A ORDEM E NORMATIVA (pagina 25): presets de proporcao, Resolucao,
/// Quadros por segundo, Plano de fundo.
class AjustesDoProjeto extends ConsumerWidget {
  const AjustesDoProjeto({super.key});

  /// Os cinco presets da referencia, nesta ordem, mais o lapis.
  static const proporcoes = <(String, double)>[
    ('16:9', 16 / 9),
    ('9:16', 9 / 16),
    ('4:5', 4 / 5),
    ('1:1', 1),
    ('4:3', 4 / 3),
  ];

  static const resolucoes = <int>[480, 720, 1080, 1440, 2160];
  static const taxas = <int>[24, 25, 30, 50, 60];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(editorControllerProvider);
    final c = ref.read(editorControllerProvider.notifier);
    final atual = p.outputWidth / p.outputHeight;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            container: true,
            excludeSemantics: true,
            button: true,
            label: 'Fechar ajustes',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => fecharAjustesDoProjeto(ref),
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: AmColors.text,
                ),
              ),
            ),
          ),
        ),
        const _Titulo('Proporcao'),
        Row(
          children: [
            for (final (rotulo, valor) in proporcoes)
              Expanded(
                child: _Chip(
                  rotulo: rotulo,
                  aceso: (atual - valor).abs() < 0.01,
                  aoTocar: () => c.setComposition(aspectRatio: valor),
                ),
              ),
            // O LAPIS: proporcao que nao esta na fileira.
            _Glifo(
              icone: Icons.edit_rounded,
              rotulo: 'Proporcao personalizada',
              aoTocar: () => _proporcaoPersonalizada(context, ref),
            ),
          ],
        ),
        _LinhaDeEscolha(
          rotulo: 'Resolucao',
          valor: '${p.outputHeight}p',
          opcoes: [for (final r in resolucoes) ('${r}p', r)],
          escolhido: p.outputHeight,
          aoEscolher: (v) => c.setComposition(resolutionHeight: v),
        ),
        _LinhaDeEscolha(
          rotulo: 'Quadros por segundo',
          valor: '${p.fps} fps',
          opcoes: [for (final f in taxas) ('$f fps', f)],
          escolhido: p.fps,
          aoEscolher: (v) => c.setComposition(fps: v),
        ),
        const _Titulo('Plano de fundo'),
        EscolhaDeCor(
          rotulo: 'Plano de fundo',
          cor: p.backgroundColor,
          aoComecar: c.beginGesture,
          aoTerminar: c.endGesture,
          aoMudar: c.setBackgroundColor,
        ),
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text(
            'Mudar a proporcao ou a resolucao nao mexe em keyframe nenhum: '
            'as camadas continuam nas coordenadas do projeto.',
            style: TextStyle(fontSize: 11, height: 1.35, color: AmColors.muted),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Tempo Total de Edição: '
            '${p.duration.inMinutes.toString().padLeft(2, '0')}:'
            '${(p.duration.inSeconds % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AmColors.muted,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _proporcaoPersonalizada(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final campo = TextEditingController();
    final texto = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AmColors.panelHigh,
        title: const Text(
          'Proporcao (largura:altura)',
          style: TextStyle(fontSize: 15, color: AmColors.text),
        ),
        content: TextField(
          controller: campo,
          autofocus: true,
          style: const TextStyle(color: AmColors.text),
          decoration: const InputDecoration(hintText: '21:9'),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(campo.text),
            child: const Text('Usar'),
          ),
        ],
      ),
    );
    campo.dispose();
    if (texto == null) return;
    final partes = texto.split(RegExp(r'[:\sx/]+'));
    if (partes.length != 2) return;
    final w = double.tryParse(partes[0]);
    final h = double.tryParse(partes[1]);
    if (w == null || h == null || w <= 0 || h <= 0) return;
    ref
        .read(editorControllerProvider.notifier)
        .setComposition(aspectRatio: w / h);
  }
}

/// UMA LINHA "rotulo a esquerda, valor a direita" que ABRE as opcoes no
/// proprio lugar — o dropdown da referencia.
class _LinhaDeEscolha extends StatefulWidget {
  const _LinhaDeEscolha({
    required this.rotulo,
    required this.valor,
    required this.opcoes,
    required this.escolhido,
    required this.aoEscolher,
  });

  final String rotulo;
  final String valor;
  final List<(String, int)> opcoes;
  final int escolhido;
  final void Function(int) aoEscolher;

  @override
  State<_LinhaDeEscolha> createState() => _LinhaDeEscolhaState();
}

class _LinhaDeEscolhaState extends State<_LinhaDeEscolha> {
  bool _aberta = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        container: true,
        excludeSemantics: true,
        button: true,
        expanded: _aberta,
        label: widget.rotulo,
        value: widget.valor,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _aberta = !_aberta),
          child: SizedBox(
            height: 46,
            child: Row(
              children: [
                Text(
                  widget.rotulo,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AmColors.text,
                  ),
                ),
                const Spacer(),
                Text(
                  widget.valor,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AmColors.accent,
                  ),
                ),
                Icon(
                  _aberta
                      ? Icons.arrow_drop_up_rounded
                      : Icons.arrow_drop_down_rounded,
                  size: 22,
                  color: AmColors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
      if (_aberta)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (rotulo, valor) in widget.opcoes)
                _Chip(
                  rotulo: rotulo,
                  aceso: valor == widget.escolhido,
                  aoTocar: () {
                    widget.aoEscolher(valor);
                    setState(() => _aberta = false);
                  },
                ),
            ],
          ),
        ),
    ],
  );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.rotulo,
    required this.aceso,
    required this.aoTocar,
  });

  final String rotulo;
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
        height: 38,
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: aceso ? AmColors.chip : null,
          borderRadius: BorderRadius.circular(9),
          border: aceso ? null : Border.all(color: AmColors.hairline),
        ),
        child: FittedBox(
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
    ),
  );
}

class _Glifo extends StatelessWidget {
  const _Glifo({
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
      child: SizedBox(
        width: 40,
        height: 38,
        child: Icon(icone, size: 17, color: AmColors.text),
      ),
    ),
  );
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
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

/// ABRE OS AJUSTES DO PROJETO pela engrenagem do cabecalho.
void abrirAjustesDoProjeto(WidgetRef ref) {
  ref.read(estadoDoPainelProvider.notifier).state = EstadoDoPainel.composicao;
  ref.read(categoriaAbertaProvider.notifier).state = null;
}

/// FECHA OS AJUSTES DO PROJETO.
void fecharAjustesDoProjeto(WidgetRef ref) {
  ref.read(estadoDoPainelProvider.notifier).state = EstadoDoPainel.recolhido;
}
