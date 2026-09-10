import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';
import '../../application/font_service.dart';
import '../../domain/layer.dart';

/// A LISTA DE FONTES ESTA ABERTA?
///
/// Uma vista dentro da categoria de texto, e nao uma folha por cima — o
/// mesmo caminho do catalogo de efeitos. Uma folha taparia a previa, que
/// e onde se ve se a fonte serve.
final escolhaDeFonteProvider = StateProvider<bool>((ref) => false);

/// O filtro, quando a lista fica grande.
final filtroDeFonteProvider = StateProvider<String>((ref) => '');

/// DE ONDE VEM OS ARQUIVOS DE FONTE.
///
/// Provider e nao chamada direta: o seletor de arquivos e um canal de
/// plataforma, e um teste que tocasse em "Importar fontes" bateria nele.
/// Trocar esta funcao e o que deixa o caminho inteiro — importar,
/// aplicar, ver na lista — ser exercitado sem arquivo de verdade.
final escolherFontesProvider = Provider<Future<List<String>> Function()>(
  (ref) => _escolherDoSistema,
);

Future<List<String>> _escolherDoSistema() async {
  final r = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['ttf', 'otf'],
    allowMultiple: true,
  );
  return [
    for (final f in r?.files ?? const <PlatformFile>[])
      if (f.path != null) f.path!,
  ];
}

/// A LINHA DE FONTE, fechada: diz qual esta valendo e abre a lista.
class LinhaDaFonte extends ConsumerWidget {
  const LinhaDaFonte({super.key, required this.camada});

  final TextLayer camada;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A LISTA MUDA POR FORA. Importar uma fonte so mexe no servico, e
    // sem escutar a revisao a linha continuaria mostrando o nome velho
    // ate um rebuild por outro motivo.
    return ValueListenableBuilder<int>(
      valueListenable: FontService.instance.revision,
      builder: (context, _, _) {
        final familia = camada.fontFamily;
        // O ROTULO DIZ A VERDADE QUANDO A FONTE SUMIU. Um projeto que
        // veio de outro aparelho referencia uma familia que nao esta
        // instalada aqui: o texto ja desenha com a do app, e mostrar o
        // nome como se estivesse aplicada seria mentir.
        final nome = familia == null
            ? 'Do aplicativo'
            : FontService.instance.has(familia)
            ? familia
            : '$familia (faltando)';
        return Semantics(
          container: true,
          excludeSemantics: true,
          button: true,
          label: 'Fonte: $nome',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                ref.read(escolhaDeFonteProvider.notifier).state = true,
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.font_download_rounded,
                    size: 18,
                    color: AmColors.muted,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Fonte',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AmColors.muted,
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      // DESENHADA NA PROPRIA FAMILIA: o nome de uma
                      // fonte diz pouco; o desenho dela diz tudo.
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AmColors.text,
                        fontFamily: resolveFontFamily(familia),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AmColors.muted,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A LISTA DE FONTES, aberta.
///
/// `FontService` tinha a lista, o importador de .ttf, a remocao e o
/// aviso de revisao — e o unico chamador em todo o app era o boot
/// (`loadAll`). Nenhuma tela listava, importava ou escolhia familia: o
/// painel de texto tinha exatamente tres controles (texto, tamanho,
/// negrito), e todo texto do app saia na fonte padrao.
class ListaDeFontes extends ConsumerStatefulWidget {
  const ListaDeFontes({super.key, required this.camada});

  final TextLayer camada;

  @override
  ConsumerState<ListaDeFontes> createState() => _ListaDeFontesState();
}

class _ListaDeFontesState extends ConsumerState<ListaDeFontes> {
  String? _recado;
  bool _importando = false;

  /// Acima disto, procurar rolando fica pior que digitar.
  static const _minimoParaFiltrar = 12;

  Future<void> _importar() async {
    setState(() {
      _importando = true;
      _recado = null;
    });
    try {
      final caminhos = await ref.read(escolherFontesProvider)();
      if (caminhos.isEmpty) {
        if (mounted) setState(() => _importando = false);
        return;
      }
      final r = await FontService.instance.importMany(caminhos);
      if (!mounted) return;
      // QUEM ACABOU DE IMPORTAR QUER VER O TEXTO MUDAR, e nao procurar
      // na lista o que acabou de trazer — a mesma regra do efeito
      // recem-adicionado e da mascara recem-criada.
      if (r.imported.isNotEmpty) {
        ref
            .read(editorControllerProvider.notifier)
            .editTextLayer(widget.camada.id, fontFamily: r.imported.first);
      }
      setState(() {
        _importando = false;
        _recado = r.imported.isEmpty
            ? 'Nenhuma fonte deu certo. Sao aceitos arquivos .ttf e .otf.'
            : '${r.imported.length} fonte(s) importada(s)'
                  '${r.failed > 0 ? ', ${r.failed} nao deram' : ''}.';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _importando = false;
          _recado = 'Nao deu para importar: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.read(editorControllerProvider.notifier);
    final l = widget.camada;

    return ValueListenableBuilder<int>(
      valueListenable: FontService.instance.revision,
      builder: (context, _, _) {
        final todas = FontService.instance.families;
        final filtro = ref.watch(filtroDeFonteProvider).toLowerCase();
        final lista = filtro.isEmpty
            ? todas
            : [
                for (final f in todas)
                  if (f.toLowerCase().contains(filtro)) f,
              ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Acao(
              icone: Icons.arrow_back_ios_new_rounded,
              rotulo: 'Voltar ao texto',
              aoTocar: () {
                ref.read(filtroDeFonteProvider.notifier).state = '';
                ref.read(escolhaDeFonteProvider.notifier).state = false;
              },
            ),
            _Acao(
              icone: Icons.add_rounded,
              rotulo: _importando ? 'Importando...' : 'Importar fontes',
              aoTocar: _importando ? () {} : _importar,
            ),
            if (_recado != null) _Aviso(_recado!),
            if (todas.length >= _minimoParaFiltrar)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Semantics(
                  container: true,
                  textField: true,
                  label: 'Filtrar fontes',
                  child: TextField(
                    onChanged: (t) =>
                        ref.read(filtroDeFonteProvider.notifier).state = t,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AmColors.text,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: AmColors.chip,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      hintText: 'Filtrar',
                      hintStyle: const TextStyle(color: AmColors.muted),
                    ),
                  ),
                ),
              ),
            // A DO APLICATIVO E SEMPRE A PRIMEIRA OPCAO. Voltar ao
            // padrao exige `clearFont`: passar `fontFamily: null` nao
            // limpa nada, porque nulo quer dizer "nao mexa".
            _LinhaDeFamilia(
              familia: null,
              nome: 'Do aplicativo',
              escolhida: l.fontFamily == null,
              aoTocar: () => c.editTextLayer(l.id, clearFont: true),
            ),
            for (final f in lista)
              _LinhaDeFamilia(
                familia: f,
                nome: f,
                escolhida: f == l.fontFamily,
                aoTocar: () => c.editTextLayer(l.id, fontFamily: f),
                aoRemover: FontService.instance.isBundled(f)
                    ? null
                    : () async {
                        await FontService.instance.remove(f);
                        if (!context.mounted) return;
                        // A CAMADA NAO PODE FICAR APONTANDO PARA O QUE
                        // NAO EXISTE MAIS: o desenho ja cai na fonte do
                        // app, e o rotulo diria "(faltando)" para
                        // sempre.
                        if (l.fontFamily == f) {
                          c.editTextLayer(l.id, clearFont: true);
                        }
                      },
              ),
          ],
        );
      },
    );
  }
}

class _LinhaDeFamilia extends StatelessWidget {
  const _LinhaDeFamilia({
    required this.familia,
    required this.nome,
    required this.escolhida,
    required this.aoTocar,
    this.aoRemover,
  });

  final String? familia;
  final String nome;
  final bool escolhida;
  final VoidCallback aoTocar;
  final VoidCallback? aoRemover;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            container: true,
            excludeSemantics: true,
            button: true,
            selected: escolhida,
            label: familia == null ? 'Fonte do aplicativo' : 'Fonte $nome',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: aoTocar,
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: escolhida
                        ? const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: AmColors.accent,
                          )
                        : null,
                  ),
                  Flexible(
                    child: Text(
                      // A AMOSTRA VAI JUNTO DO NOME: uma lista de
                      // fontes se le pelo desenho, e nao pelo nome.
                      '$nome  Aa Bb 123',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: escolhida ? AmColors.accent : AmColors.text,
                        fontFamily: resolveFontFamily(familia),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (aoRemover != null)
          Semantics(
            container: true,
            excludeSemantics: true,
            button: true,
            label: 'Tirar $nome',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: aoRemover,
              child: const SizedBox(
                width: 34,
                height: 44,
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: 17,
                  color: AmColors.muted,
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
            Icon(icone, size: 18, color: AmColors.text),
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

class _Aviso extends StatelessWidget {
  const _Aviso(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 2, 0, 8),
    child: Text(
      texto,
      style: const TextStyle(fontSize: 11, color: AmColors.muted, height: 1.4),
    ),
  );
}
