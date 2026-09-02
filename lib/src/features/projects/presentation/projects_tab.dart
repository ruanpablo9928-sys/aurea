import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aurea_logo.dart';
import '../../about/presentation/report_sheet.dart';
import '../../editor/application/editor_controller.dart';
import '../../editor/domain/template_pack.dart';
import '../../editor/domain/video_project.dart';
import '../../editor/presentation/editor_screen.dart';
import '../application/projects_controller.dart';
import '../application/thumbnail_service.dart';
import '../domain/alight_xml_import.dart';
import '../domain/notes_motion_template.dart';
import '../domain/project_presets.dart';
import 'new_project_sheet.dart';
import 'whats_new.dart';

/// Aba Inicio, do jeito de um app de video: o titulo, um botao de
/// criar, os formatos como pilulas, os projetos recentes como cartoes
/// com a miniatura DE VERDADE do projeto, os modelos com um quadro
/// renderizado — e nada de cartao-vitrine com degrade e texto de
/// marketing.
class ProjectsTab extends ConsumerWidget {
  const ProjectsTab({super.key});

  Future<void> _createProject(
    BuildContext context,
    WidgetRef ref, {
    String? presetAspectKey,
  }) async {
    final project =
        await showNewProjectSheet(context, presetAspectKey: presetAspectKey);
    if (project == null || !context.mounted) return;

    ref.read(projectsControllerProvider.notifier).add(project);
    ref.read(editorControllerProvider.notifier).openProject(project);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EditorScreen()),
    );
  }

  /// MODELO PRONTO: um projeto montado por codigo, com id novo a cada
  /// abertura — o mesmo cuidado do template em arquivo.
  Future<void> _abrirModelo(
      BuildContext context, WidgetRef ref, VideoProject modelo) async {
    final project = modelo.comIdNovo();
    ref.read(projectsControllerProvider.notifier).add(project);
    ref.read(editorControllerProvider.notifier).openProject(project);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EditorScreen()),
    );
  }

  /// ABRIR TEMPLATE: o arquivo vira um projeto NOVO, com id novo.
  ///
  /// Sem id novo, abrir o mesmo template duas vezes sobrescreveria o
  /// trabalho da primeira vez — e a pessoa perderia o que fez sem
  /// entender por que.
  Future<void> _openTemplate(BuildContext context, WidgetRef ref) async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    final caminho = r?.files.single.path;
    if (caminho == null || !context.mounted) return;

    TemplatePack? pack;
    try {
      pack = TemplatePack.decode(await File(caminho).readAsString());
    } catch (_) {
      pack = null;
    }
    if (!context.mounted) return;
    if (pack == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nao consegui ler esse template')));
      return;
    }

    final novo = pack.project.copyWith(name: pack.name).comIdNovo();
    ref.read(projectsControllerProvider.notifier).add(novo);
    ref.read(editorControllerProvider.notifier).openProject(novo);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EditorScreen()),
    );
  }

  /// PRESET DO ALIGHT MOTION (XML): le o que reconhece, mostra o balanco
  /// (camadas, keyframes, o que ficou de fora) e abre como projeto novo.
  Future<void> _importarAlight(BuildContext context, WidgetRef ref) async {
    final r = await FilePicker.platform.pickFiles(type: FileType.any);
    final caminho = r?.files.single.path;
    if (caminho == null || !context.mounted) return;
    final nomeArquivo = caminho.split(RegExp(r'[\\/]')).last;
    AlightImportResult resultado;
    try {
      final texto = await File(caminho).readAsString();
      resultado = importAlightXml(texto,
          nome: nomeArquivo.replaceAll(
              RegExp(r'\.xml$', caseSensitive: false), ''));
    } on AlightImportException catch (e) {
      if (!context.mounted) return;
      await _aviso(context, 'Nao deu para importar', e.message);
      return;
    } catch (e) {
      if (!context.mounted) return;
      await _aviso(context, 'Nao deu para importar', 'Arquivo ilegivel: $e');
      return;
    }
    if (!context.mounted) return;
    final abrir = await showCupertinoDialog<bool>(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: const Text('Preset do Alight'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            _resumoDaImportacao(resultado),
            textAlign: TextAlign.left,
          ),
        ),
        actions: [
          CupertinoDialogAction(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Cancelar')),
          CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Abrir')),
        ],
      ),
    );
    if (abrir != true || !context.mounted) return;
    final novo = resultado.project;
    ref.read(projectsControllerProvider.notifier).add(novo);
    ref.read(editorControllerProvider.notifier).openProject(novo);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EditorScreen()),
    );
  }

  static String _resumoDaImportacao(AlightImportResult r) {
    final b = StringBuffer()
      ..write('${r.layersImported} camadas e ')
      ..write('${r.keyframesImported} keyframes reconhecidos.');
    if (r.ignored.isNotEmpty) {
      b.write('\n\nFicou de fora:');
      for (final item in r.ignored.take(6)) {
        b.write('\n- $item');
      }
      if (r.ignored.length > 6) {
        b.write('\n- e mais ${r.ignored.length - 6}');
      }
    }
    return b.toString();
  }

  Future<void> _aviso(BuildContext context, String titulo, String texto) =>
      showCupertinoDialog<void>(
        context: context,
        builder: (c) => CupertinoAlertDialog(
          title: Text(titulo),
          content: Padding(
              padding: const EdgeInsets.only(top: 8), child: Text(texto)),
          actions: [
            CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.of(c).pop(),
                child: const Text('OK')),
          ],
        ),
      );

  void _openProject(BuildContext context, WidgetRef ref, VideoProject project) {
    ref.read(editorControllerProvider.notifier).openProject(project);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EditorScreen()),
    );
  }

  Future<void> _confirmarExclusao(
      BuildContext context, WidgetRef ref, VideoProject project) async {
    final apaga = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (c) => CupertinoActionSheet(
        title: Text(project.name),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Excluir projeto'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(c).pop(false),
          child: const Text('Cancelar'),
        ),
      ),
    );
    if (apaga != true) return;
    ref.read(projectsControllerProvider.notifier).remove(project.id);
    ThumbnailService.instance.delete(project.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsControllerProvider);
    final theme = Theme.of(context);
    ThumbnailService.instance.init();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 120),
        children: [
          // TITULO GRANDE, como toda tela raiz do app.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text('Aurea', style: theme.textTheme.headlineLarge),
                ),
                const AureaLogo(size: 38),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // CRIAR: um botao so, e o template ao lado como icone.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      icon: const Icon(CupertinoIcons.plus, size: 19),
                      label: const Text('Novo projeto'),
                      onPressed: () => _createProject(context, ref),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _IconeQuadrado(
                  icon: CupertinoIcons.doc_on_doc,
                  tooltip: 'Abrir template',
                  onTap: () => _openTemplate(context, ref),
                ),
                const SizedBox(width: 10),
                _IconeQuadrado(
                  icon: CupertinoIcons.arrow_down_doc,
                  tooltip: 'Importar preset do Alight (XML)',
                  onTap: () => _importarAlight(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // FORMATOS como pilulas, numa fila que rola.
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final aspect in ProjectPresets.aspects)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _Pilula(
                      icon: aspect.icon,
                      label: '${aspect.label}  ${aspect.hint}',
                      onTap: () => _createProject(context, ref,
                          presetAspectKey: aspect.key),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          _TituloSecao(
            'Recentes',
            detalhe: projects.isEmpty
                ? null
                : '${projects.length} ${projects.length == 1 ? 'projeto' : 'projetos'}',
          ),
          const SizedBox(height: 10),
          if (projects.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 6, 20, 6),
              child: Text(
                'Seus projetos aparecem aqui, com a miniatura do que voce fez.',
                style: TextStyle(color: AppColors.muted, fontSize: 13.5),
              ),
            )
          else
            ValueListenableBuilder<int>(
              valueListenable: ThumbnailService.instance.revision,
              builder: (_, rev, _) => SizedBox(
                height: 176,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    for (final project in projects)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _CartaoProjeto(
                          project: project,
                          thumb: ThumbnailService.instance.fileFor(project.id),
                          revision: rev,
                          onOpen: () => _openProject(context, ref, project),
                          onLongPress: () =>
                              _confirmarExclusao(context, ref, project),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 28),
          // MODELOS: motions inteiros montados camada por camada — abrir
          // um e ver como cada coisa foi feita.
          const _TituloSecao('Modelos'),
          const SizedBox(height: 10),
          SizedBox(
            height: 176,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _CartaoModelo(
                  imagem: 'assets/templates/notes.jpg',
                  titulo: 'Notes',
                  detalhe: 'Icone, botao, listas, whip e glow',
                  onTap: () =>
                      _abrirModelo(context, ref, buildNotesMotionTemplate()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          _Linha(
            icon: CupertinoIcons.sparkles,
            texto: 'O que ha de novo nesta versao',
            onTap: () => showWhatsNewSheet(context),
          ),
          _Linha(
            icon: CupertinoIcons.exclamationmark_bubble,
            texto: 'Versao beta: achou um problema? Conte pra gente',
            onTap: () => showReportSheet(context),
          ),
        ],
      ),
    );
  }
}

class _TituloSecao extends StatelessWidget {
  const _TituloSecao(this.titulo, {this.detalhe});

  final String titulo;
  final String? detalhe;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(titulo, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (detalhe != null)
            Text(detalhe!,
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _IconeQuadrado extends StatelessWidget {
  const _IconeQuadrado(
      {required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 20, color: AppColors.onDark),
        ),
      ),
    );
  }
}

class _Pilula extends StatelessWidget {
  const _Pilula({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.lime),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
                color: AppColors.onDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cartao de projeto: miniatura real (quando o projeto ja foi aberto e
/// fechado uma vez), nome e ficha tecnica. Segurar apaga.
class _CartaoProjeto extends StatelessWidget {
  const _CartaoProjeto({
    required this.project,
    required this.thumb,
    required this.revision,
    required this.onOpen,
    required this.onLongPress,
  });

  final VideoProject project;
  final File? thumb;
  final int revision;
  final VoidCallback onOpen;
  final VoidCallback onLongPress;

  String get _specs {
    final aspect = ProjectPresets.aspects
        .firstWhere(
          (a) => (a.ratio - project.aspectRatio).abs() < 0.01,
          orElse: () => ProjectPresets.aspects.first,
        )
        .label;
    return '$aspect · ${ProjectPresets.resolutionLabel(project.resolutionHeight)} · ${project.fps} fps';
  }

  @override
  Widget build(BuildContext context) {
    final t = thumb;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      onLongPress: onLongPress,
      child: SizedBox(
        width: 156,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 156,
                height: 118,
                child: t == null
                    ? const ColoredBox(
                        color: AppColors.surfaceHigh,
                        child: Center(
                          child: Icon(CupertinoIcons.film,
                              color: AppColors.muted, size: 24),
                        ),
                      )
                    : Image.file(
                        t,
                        key: ValueKey('${project.id}-$revision'),
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              project.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
                color: AppColors.onDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _specs,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cartao de modelo pronto: um quadro renderizado do proprio motion.
class _CartaoModelo extends StatelessWidget {
  const _CartaoModelo({
    required this.imagem,
    required this.titulo,
    required this.detalhe,
    required this.onTap,
  });

  final String imagem;
  final String titulo;
  final String detalhe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 156,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 156,
                height: 118,
                child: Image.asset(imagem, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
                color: AppColors.onDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              detalhe,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Linha simples com icone e seta: sem caixa, sem borda.
class _Linha extends StatelessWidget {
  const _Linha({required this.icon, required this.texto, required this.onTap});

  final IconData icon;
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.lime),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                texto,
                style: const TextStyle(fontSize: 14, color: AppColors.onDark),
              ),
            ),
            const Icon(CupertinoIcons.chevron_right,
                size: 15, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
