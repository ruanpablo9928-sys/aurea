import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';
import '../../application/playback_controller.dart';
import '../../domain/layer.dart';
import '../contexto_do_editor.dart';
import 'controles_da_camada.dart';
import 'painel_da_camada.dart';

/// A ALTURA DA FAIXA DE CIMA. Uma so, para os tres contextos: projeto,
/// camada e propriedade. Trocar de contexto NAO pode mexer no arranjo
/// vertical — se a faixa mudasse de altura, a previa e a linha do tempo
/// pulariam a cada selecao.
const double alturaDaFaixaDeCima = 52.0;

/// A FAIXA DE CIMA NO CONTEXTO DE CAMADA (V 00:40).
///
/// No Alight Motion, selecionar uma camada TROCA a faixa inteira: sai o
/// nome do projeto e entram as quatro coisas que se faz com uma camada
/// — o nome dela, quem ela segue, apagar, e o `...` que reune o resto.
///
/// No Aurea isso nao existia. As mesmas quatro acoes estavam a dois ou
/// tres toques de distancia, enterradas no cartao "Camada" da grade, e o
/// parent — que a especificacao corrige explicitamente na pagina 7 como
/// sendo Layer Parent, e nao duplicar — nao tinha lugar nenhum no shell.
///
/// O cartao "Camada" continua existindo, com as mesmas acoes: este
/// cabecalho e o CAMINHO CURTO, nao o unico caminho.
class CabecalhoDaCamada extends ConsumerWidget {
  const CabecalhoDaCamada({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projeto = ref.watch(editorControllerProvider);
    final id = ref.watch(selectedLayerProvider);
    final camada = projeto.layers.where((l) => l.id == id).firstOrNull;
    // A CAMADA PODE TER MORRIDO enquanto a barra estava na tela (um
    // desfazer, um apagar de outro caminho). Sem camada nao ha contexto
    // de camada: a barra some e o contexto volta a ser o projeto.
    if (camada == null) return const SizedBox(height: alturaDaFaixaDeCima);
    final vinculo = projeto.linkFor(camada.id, LayerProp.parent);
    final segue = vinculo != null;
    return SizedBox(
      height: alturaDaFaixaDeCima,
      child: Row(
        children: [
          // SAIR DO CONTEXTO DE CAMADA. A selecao continua — sair daqui
          // e fechar o painel, nao desfazer a escolha.
          _Glifo(
            rotulo: 'Voltar ao projeto',
            icone: Icons.arrow_back_ios_new_rounded,
            aoTocar: () => fecharFerramenta(ref),
          ),
          // O NOME DA CAMADA, e o toque nele RENOMEIA.
          //
          // `renameLayer` existia no motor desde sempre e so tinha porta
          // dentro do cartao de acoes em lote. Numa pilha de dez formas
          // chamadas "Forma", o nome e a unica coisa que distingue uma
          // da outra.
          Expanded(
            child: Semantics(
              container: true,
              excludeSemantics: true,
              button: true,
              label: 'Renomear a camada',
              value: camada.name,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => renomearCamada(context, ref, camada),
                child: SizedBox(
                  height: alturaDaFaixaDeCima,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      camada.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AmColors.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // QUEM ESTA CAMADA SEGUE — dois quadrados sobrepostos, como na
          // referencia. Aceso quando ja ha um pai.
          _Glifo(
            rotulo: segue ? 'Trocar quem esta camada segue' : 'Seguir outra camada',
            icone: Icons.filter_none_rounded,
            aceso: segue,
            aoTocar: () => escolherPai(ref),
          ),
          _Glifo(
            rotulo: 'Apagar a camada',
            icone: Icons.delete_outline_rounded,
            aoTocar: () =>
                ref.read(editorControllerProvider.notifier).removeLayer(camada.id),
          ),
          _Glifo(
            rotulo: 'Mais acoes da camada',
            icone: Icons.more_horiz_rounded,
            aoTocar: () =>
                ref.read(menuDaCamadaAbertoProvider.notifier).state = true,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}


/// ABRE A ESCOLHA DE PAI a partir do cabecalho.
///
/// A lista de candidatos mora dentro do cartao "Camada" — abrir o cartao
/// junto e o que faz o overlay ter onde aparecer. Sem isto o interruptor
/// ligaria e nada apareceria na tela.
void escolherPai(WidgetRef ref) {
  ref.read(estadoDoPainelProvider.notifier).state = EstadoDoPainel.categoria;
  ref.read(categoriaAbertaProvider.notifier).state = 'camada';
  ref.read(escolhendoPaiProvider.notifier).state = true;
}

/// RENOMEAR, num modal com escopo claro: fechar nao muda nada.
Future<void> renomearCamada(
  BuildContext context,
  WidgetRef ref,
  Layer camada,
) async {
  final campo = TextEditingController(text: camada.name);
  final novo = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AmColors.panelHigh,
      title: const Text(
        'Nome da camada',
        style: TextStyle(fontSize: 15, color: AmColors.text),
      ),
      content: TextField(
        controller: campo,
        autofocus: true,
        style: const TextStyle(color: AmColors.text),
        decoration: const InputDecoration(hintText: 'Nome'),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(campo.text),
          child: const Text('Renomear'),
        ),
      ],
    ),
  );
  campo.dispose();
  if (novo == null || novo.trim().isEmpty) return;
  ref.read(editorControllerProvider.notifier).renameLayer(camada.id, novo.trim());
}

class _Glifo extends StatelessWidget {
  const _Glifo({
    required this.rotulo,
    required this.icone,
    required this.aoTocar,
    this.aceso = false,
  });

  final String rotulo;
  final IconData icone;
  final VoidCallback aoTocar;
  final bool aceso;

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
      child: SizedBox(
        width: 42,
        height: alturaDaFaixaDeCima,
        child: Icon(
          icone,
          size: 19,
          color: aceso ? AmColors.accent : AmColors.text,
        ),
      ),
    ),
  );
}

/// O `...` DO CABECALHO, aberto.
///
/// Overlay com escopo claro: cobre a tela, fechar devolve exatamente o
/// contexto de camada de antes, e nenhuma das acoes mexe no projeto ate
/// ser tocada.
class MenuDaCamada extends ConsumerWidget {
  const MenuDaCamada({super.key, required this.playback});

  final PlaybackController playback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(menuDaCamadaAbertoProvider)) return const SizedBox.shrink();
    final projeto = ref.watch(editorControllerProvider);
    final id = ref.watch(selectedLayerProvider);
    final camada = projeto.layers.where((l) => l.id == id).firstOrNull;
    if (camada == null) return const SizedBox.shrink();
    final c = ref.read(editorControllerProvider.notifier);
    final ficha = projeto.metaOf(camada.id);
    final agora = playback.time.value - camada.startTime;
    final podeDividir =
        playback.time.value > camada.startTime &&
        playback.time.value < camada.endTime;
    void fechar() =>
        ref.read(menuDaCamadaAbertoProvider.notifier).state = false;
    return Positioned.fill(
      child: Stack(
        children: [
          Semantics(
            container: true,
            excludeSemantics: true,
            button: true,
            label: 'Fechar o menu da camada',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: fechar,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: .5),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: alturaDaFaixaDeCima, right: 8),
              child: Container(
                width: 232,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: AmColors.panelHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AmColors.hairline),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ItemDoMenu(
                      icone: Icons.tune_rounded,
                      rotulo: 'Ferramentas da camada',
                      aoTocar: () {
                        fechar();
                        ref.read(estadoDoPainelProvider.notifier).state =
                            EstadoDoPainel.categoria;
                        ref.read(categoriaAbertaProvider.notifier).state =
                            'camada';
                      },
                    ),
                    _ItemDoMenu(
                      icone: Icons.drive_file_rename_outline_rounded,
                      rotulo: 'Renomear',
                      aoTocar: () {
                        fechar();
                        renomearCamada(context, ref, camada);
                      },
                    ),
                    _ItemDoMenu(
                      icone: Icons.copy_all_rounded,
                      rotulo: 'Duplicar',
                      aoTocar: () {
                        fechar();
                        c.duplicarCamada(camada.id);
                      },
                    ),
                    _ItemDoMenu(
                      icone: Icons.content_cut_rounded,
                      rotulo: 'Dividir no cabecote',
                      porQueNao: podeDividir
                          ? null
                          : 'Leve o cabecote para dentro da camada',
                      aoTocar: () {
                        fechar();
                        c.splitLayer(camada.id, agora);
                      },
                    ),
                    if (camada is GroupLayer)
                      _ItemDoMenu(
                        icone: Icons.login_rounded,
                        rotulo: 'Entrar no grupo',
                        aoTocar: () {
                          fechar();
                          fecharFerramenta(ref);
                          c.enterGroup(camada.id);
                        },
                      )
                    else
                      _ItemDoMenu(
                        icone: Icons.folder_open_rounded,
                        rotulo: 'Agrupar',
                        aoTocar: () {
                          fechar();
                          c.groupLayer(camada.id);
                        },
                      ),
                    _ItemDoMenu(
                      icone: ficha.hidden
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      rotulo: ficha.hidden ? 'Mostrar' : 'Esconder',
                      aoTocar: () {
                        fechar();
                        c.toggleHidden(camada.id);
                      },
                    ),
                    _ItemDoMenu(
                      icone: ficha.locked
                          ? Icons.lock_rounded
                          : Icons.lock_open_rounded,
                      rotulo: ficha.locked ? 'Destravar' : 'Travar',
                      aoTocar: () {
                        fechar();
                        c.toggleLocked(camada.id);
                      },
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
}

class _ItemDoMenu extends StatelessWidget {
  const _ItemDoMenu({
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
          height: 42,
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(
                icone,
                size: 18,
                color: pode ? AmColors.text : AmColors.muted,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    rotulo,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: pode ? AmColors.text : AmColors.muted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }
}
