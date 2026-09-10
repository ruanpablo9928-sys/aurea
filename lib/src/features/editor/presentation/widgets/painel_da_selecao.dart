import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';
import '../../application/playback_controller.dart';
import '../../domain/apple_motion.dart';
import '../../domain/layout_ops.dart';

/// O recado da ultima acao em lote.
final recadoDaSelecaoProvider = StateProvider<String?>((ref) => null);

/// O QUE SE FAZ COM VARIAS CAMADAS DE UMA VEZ.
///
/// `multiSelectProvider` existia desde sempre e era so LIMPO, nunca
/// preenchido: nenhum gesto punha duas camadas no conjunto. Com isso,
/// sete comandos prontos do motor ficavam sem porta — `groupLayers`,
/// `reorderLayers`, `alignSelection`, `distributeSelection`,
/// `spaceSelection`, `cascadeSelection` e as acoes em lote de duplicar
/// e apagar.
///
/// A auditoria chamou isto de "raiz estrutural", e era: sem selecao
/// multipla nao ha grupo de varias, nao ha alinhamento e nao ha
/// escalonamento. Um toque longo na pilha abre as tres coisas.
class PainelDaSelecao extends ConsumerWidget {
  const PainelDaSelecao({super.key, required this.playback});

  final PlaybackController playback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(editorControllerProvider.notifier);
    final projeto = ref.watch(editorControllerProvider);
    // SO OS QUE AINDA EXISTEM. Apagar em lote e desfazer deixam ids
    // mortos no conjunto, e agir sobre eles seria agir sobre nada.
    final ids = [
      for (final l in projeto.layers)
        if (ref.watch(multiSelectProvider).contains(l.id)) l.id,
    ];
    final agora = playback.time.value;
    final recado = ref.watch(recadoDaSelecaoProvider);

    void dizer(String texto) =>
        ref.read(recadoDaSelecaoProvider.notifier).state = texto;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Titulo('Alinhar'),
          _Grade(
            itens: const [
              ('Esquerda', AlignEdge.left),
              ('Centro H', AlignEdge.centerH),
              ('Direita', AlignEdge.right),
              ('Topo', AlignEdge.top),
              ('Centro V', AlignEdge.centerV),
              ('Base', AlignEdge.bottom),
            ],
            aoTocar: (borda) {
              // ENTRE ELAS, e nao na composicao: quem juntou duas
              // camadas quer encostar uma na outra. Alinhar pela
              // composicao continua sendo o certo para UMA camada, e e
              // outra conversa.
              c.alignSelection(ids, borda, agora, to: AlignTo.selection);
              dizer('${ids.length} camadas alinhadas.');
            },
          ),
          _Titulo('Espalhar'),
          _Aviso(
            ids.length < 3
                ? 'Distribuir precisa de tres camadas: as duas pontas ficam '
                      'no lugar e o miolo se ajeita.'
                : 'As duas pontas ficam onde estao; o miolo se ajeita.',
          ),
          _Grade(
            itens: const [
              ('Na horizontal', DistributeAxis.horizontal),
              ('Na vertical', DistributeAxis.vertical),
            ],
            apagado: ids.length < 3,
            aoTocar: (eixo) {
              c.distributeSelection(
                ids,
                eixo,
                DistributeMode.byCenter,
                agora,
              );
              dizer('Espalhadas por centro.');
            },
          ),
          _Titulo('Escalonar no tempo'),
          // CASCATA: as marcas de cada camada saem com um atraso a mais
          // que as da anterior. E o que faz cinco titulos entrarem em
          // sequencia sem animar cinco vezes — e estava no motor sem um
          // unico chamador.
          _Grade(
            itens: const [
              ('Rapido', 60),
              ('Medio', 120),
              ('Lento', 240),
            ],
            aoTocar: (ms) {
              c.cascadeSelection(
                ids,
                interval: Duration(milliseconds: ms),
                order: CascadeOrder.start,
              );
              dizer('Escalonadas de ${ms}ms em ${ms}ms.');
            },
          ),
          _Titulo('A pilha'),
          _Grade(
            itens: const [('Subir', -1), ('Descer', 1)],
            aoTocar: (passo) => c.reorderLayers(ids, passo),
          ),
          _Titulo('Todas juntas'),
          _Acao(
            icone: Icons.folder_open_rounded,
            rotulo: 'Agrupar as ${ids.length}',
            aoTocar: () {
              c.groupLayers(ids);
              ref.read(multiSelectProvider.notifier).state = const {};
            },
          ),
          _Acao(
            icone: Icons.copy_all_rounded,
            rotulo: 'Duplicar as ${ids.length}',
            aoTocar: () {
              // UM DESFAZER SO. Duplicar cinco camadas e uma acao, e
              // nao cinco: sem o lote, voltar atras custaria cinco
              // toques.
              c.runAsOneUndo(() {
                for (final id in ids) {
                  c.duplicarCamada(id);
                }
              });
              dizer('${ids.length} camadas duplicadas.');
            },
          ),
          _Acao(
            icone: Icons.delete_outline_rounded,
            rotulo: 'Apagar as ${ids.length}',
            perigo: true,
            aoTocar: () {
              c.runAsOneUndo(() {
                for (final id in ids) {
                  c.removeLayer(id);
                }
              });
              ref.read(multiSelectProvider.notifier).state = const {};
            },
          ),
          if (recado != null) _Aviso(recado),
        ],
      ),
    );
  }
}

class _Grade<T> extends StatelessWidget {
  const _Grade({
    required this.itens,
    required this.aoTocar,
    this.apagado = false,
  });

  final List<(String, T)> itens;
  final void Function(T) aoTocar;
  final bool apagado;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (nome, valor) in itens)
          Semantics(
            container: true,
            excludeSemantics: true,
            button: !apagado,
            enabled: !apagado,
            label: nome,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: apagado ? null : () => aoTocar(valor),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AmColors.chip,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  nome,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: apagado
                        ? AmColors.muted.withValues(alpha: .4)
                        : AmColors.text,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _Acao extends StatelessWidget {
  const _Acao({
    required this.icone,
    required this.rotulo,
    required this.aoTocar,
    this.perigo = false,
  });

  final IconData icone;
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              icone,
              size: 19,
              color: perigo ? AmColors.pink : AmColors.text,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                rotulo,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: perigo ? AmColors.pink : AmColors.text,
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
    padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
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
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      texto,
      style: const TextStyle(fontSize: 11, color: AmColors.muted, height: 1.4),
    ),
  );
}
