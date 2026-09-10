import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';
import '../../application/layer_preset_store.dart';
import '../../domain/layer.dart';
import '../../domain/project_store.dart';
import 'painel_da_camada.dart';

/// PRESETS DA CAMADA (V, pagina 20).
///
/// O tile existia na grade dos quatro tipos da referencia e nao existia
/// aqui. Sem nenhum preset salvo, a superficie abre um VAZIO UTIL — com
/// os dois caminhos reais que a especificacao exige: salvar o que esta
/// nesta camada, e trazer o que veio de fora. Nada de botao que nao faz
/// nada.
class PresetsDaCamada extends ConsumerStatefulWidget {
  const PresetsDaCamada({super.key, required this.camada});

  final Layer camada;

  @override
  ConsumerState<PresetsDaCamada> createState() => _PresetsDaCamadaState();
}

class _PresetsDaCamadaState extends ConsumerState<PresetsDaCamada> {
  @override
  void initState() {
    super.initState();
    LayerPresetStore.instance.load();
  }

  Future<void> _salvar() async {
    final campo = TextEditingController(text: widget.camada.name);
    final nome = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AmColors.panelHigh,
        title: const Text(
          'Nome do preset',
          style: TextStyle(fontSize: 15, color: AmColors.text),
        ),
        content: TextField(
          controller: campo,
          autofocus: true,
          style: const TextStyle(color: AmColors.text),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(campo.text),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    campo.dispose();
    if (nome == null || nome.trim().isEmpty) return;
    await LayerPresetStore.instance.salvar(
      widget.camada,
      nome.trim(),
      tipoDaCamadaEmPalavras(widget.camada),
    );
  }

  Future<void> _importar() async {
    final dados = await Clipboard.getData(Clipboard.kTextPlain);
    final texto = dados?.text;
    if (!mounted) return;
    if (texto == null || texto.trim().isEmpty) {
      _recado('Nao ha nada copiado para importar.');
      return;
    }
    final preset = await LayerPresetStore.instance.importar(texto);
    if (!mounted) return;
    _recado(
      preset == null
          ? 'O que esta copiado nao e um preset de camada.'
          : 'Preset "${preset.nome}" importado.',
    );
  }

  void _recado(String texto) => ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(texto)));

  /// APLICA O PRESET NESTA CAMADA.
  ///
  /// O que entra e a TRANSFORMACAO, a opacidade e os efeitos, com todos
  /// os keyframes. O tempo e o conteudo da camada NAO sao tocados: um
  /// preset que trocasse o texto ou a duracao seria trocar a camada, e
  /// nao aplicar uma receita nela.
  void _aplicar(LayerPreset p) {
    final fonte = layerFromJson(p.dados);
    ref
        .read(editorControllerProvider.notifier)
        .aplicarPresetDeCamada(widget.camada.id, fonte);
    _recado('Preset "${p.nome}" aplicado.');
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: LayerPresetStore.instance.revision,
    builder: (context, _, _) {
      final lista = LayerPresetStore.instance.presets;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (lista.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 10, 4, 12),
              child: Text(
                'Nenhum preset salvo ainda.\n\n'
                'Um preset guarda a transformacao, a opacidade e os '
                'efeitos desta camada — com os keyframes — para reusar '
                'noutra camada ou noutro projeto.',
                key: ValueKey('presets-vazio'),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: AmColors.muted,
                ),
              ),
            )
          else
            for (final p in lista)
              _Linha(
                nome: p.nome,
                tipo: p.tipo,
                aoAplicar: () => _aplicar(p),
                aoCopiar: () async {
                  await Clipboard.setData(
                    ClipboardData(text: LayerPresetStore.instance.exportar(p)),
                  );
                  if (mounted) _recado('Preset copiado.');
                },
                aoRemover: () => LayerPresetStore.instance.remover(p.id),
              ),
          const Divider(height: 20, color: AmColors.hairline),
          _Acao(
            icone: Icons.bookmark_add_outlined,
            rotulo: 'Salvar esta camada como preset',
            aoTocar: _salvar,
          ),
          _Acao(
            icone: Icons.download_rounded,
            rotulo: 'Importar preset copiado',
            aoTocar: _importar,
          ),
        ],
      );
    },
  );
}

class _Linha extends StatelessWidget {
  const _Linha({
    required this.nome,
    required this.tipo,
    required this.aoAplicar,
    required this.aoCopiar,
    required this.aoRemover,
  });

  final String nome;
  final String tipo;
  final VoidCallback aoAplicar;
  final VoidCallback aoCopiar;
  final VoidCallback aoRemover;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 46,
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            container: true,
            excludeSemantics: true,
            button: true,
            label: 'Aplicar preset $nome',
            value: tipo,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: aoAplicar,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    nome,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AmColors.text,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        _Glifo(
          icone: Icons.copy_rounded,
          rotulo: 'Copiar preset $nome',
          aoTocar: aoCopiar,
        ),
        _Glifo(
          icone: Icons.delete_outline_rounded,
          rotulo: 'Apagar preset $nome',
          aoTocar: aoRemover,
        ),
      ],
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
        height: 44,
        child: Icon(icone, size: 17, color: AmColors.muted),
      ),
    ),
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
      child: SizedBox(
        height: 46,
        child: Row(
          children: [
            Icon(icone, size: 18, color: AmColors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  rotulo,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AmColors.accent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
