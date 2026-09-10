import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';

/// O QUE DA PARA CRIAR, e por qual comando.
///
/// A lista sai dos criadores que EXISTEM no `EditorController` e que nao
/// dependem de escolher arquivo. Midia (imagem, video, audio) precisa do
/// seletor do sistema e de preparar o recurso antes de inserir — outro
/// fluxo, com cancelamento e falha proprios. Anunciar aqui o que ainda
/// nao tem esse caminho seria prometer o que nao entrega.
@immutable
class TipoDeConteudo {
  const TipoDeConteudo({
    required this.id,
    required this.rotulo,
    required this.icone,
    required this.criar,
  });

  final String id;
  final String rotulo;
  final IconData icone;

  /// Cria a camada NO INSTANTE dado e devolve o controle para quem
  /// chamou. Quem decide o instante e o fluxo de adicao, no momento em
  /// que ele abre — nao no momento em que o toque acontece.
  final void Function(EditorController c, Duration em) criar;
}

/// Os tipos que o app sabe criar sem sair da tela.
const tiposDeConteudo = <TipoDeConteudo>[
  TipoDeConteudo(
    id: 'texto',
    rotulo: 'Texto',
    icone: Icons.text_fields_rounded,
    criar: _criarTexto,
  ),
  TipoDeConteudo(
    id: 'forma',
    rotulo: 'Forma',
    icone: Icons.category_rounded,
    criar: _criarForma,
  ),
  TipoDeConteudo(
    id: 'cena3d',
    rotulo: 'Cena 3D',
    icone: Icons.view_in_ar_rounded,
    criar: _criarCena3D,
  ),
  TipoDeConteudo(
    id: 'particulas',
    rotulo: 'Particulas',
    icone: Icons.grain_rounded,
    criar: _criarParticulas,
  ),
];

void _criarTexto(EditorController c, Duration em) => c.addTextLayer(em);
void _criarForma(EditorController c, Duration em) => c.addShapeLayer(em);
void _criarCena3D(EditorController c, Duration em) => c.addScene3DLayer(em);
void _criarParticulas(EditorController c, Duration em) =>
    c.addParticlesLayer(em);

/// O MENU DE ADICAO, na mesma area inferior das ferramentas.
///
/// Ele nao empilha um painel sobre o outro: e um estado do MESMO painel,
/// e por isso nao sobra nenhuma camada invisivel recebendo gesto atras
/// da outra.
///
/// O INSTANTE DE INSERCAO e o capturado quando o menu ABRE, e nao quando
/// o toque acontece. Sao coisas diferentes assim que o relogio anda, e a
/// pessoa escolheu o lugar ao abrir.
class MenuDeAdicao extends ConsumerWidget {
  const MenuDeAdicao({
    super.key,
    required this.instanteDeInsercao,
    required this.aoAdicionar,
  });

  final Duration instanteDeInsercao;

  /// Chamado depois de criar. Quem fecha o menu e quem o abriu — este
  /// widget e um ESTADO do painel, e nao uma rota para empilhar.
  final VoidCallback aoAdicionar;

  @override
  Widget build(BuildContext context, WidgetRef ref) => GridView.builder(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      mainAxisExtent: 56,
    ),
    itemCount: tiposDeConteudo.length,
    itemBuilder: (context, i) {
      final t = tiposDeConteudo[i];
      return Semantics(
        key: ValueKey('adicionar-${t.id}'),
        container: true,
        excludeSemantics: true,
        button: true,
        label: 'Adicionar ${t.rotulo}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            // UMA SO OPERACAO DE DESFAZER por adicao: o criador ja
            // empilha a dele, e o fluxo nao acrescenta outra.
            t.criar(
              ref.read(editorControllerProvider.notifier),
              instanteDeInsercao,
            );
            aoAdicionar();
          },
          child: Container(
            decoration: BoxDecoration(
              color: AmColors.chip,
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(t.icone, size: 19, color: AmColors.action),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t.rotulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      color: AmColors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
