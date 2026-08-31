import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aurea_logo.dart';
import '../../editor/application/editor_controller.dart';
import '../../editor/domain/video_project.dart';
import '../../editor/presentation/editor_screen.dart';
import '../../user/application/user_profile_controller.dart';
import '../application/projects_controller.dart';
import '../domain/project_presets.dart';
import 'whats_new.dart';
import 'new_project_sheet.dart';

/// Aba Inicio: large title, criar projeto, atalhos e recentes.
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

  void _openProject(BuildContext context, WidgetRef ref, VideoProject project) {
    ref.read(editorControllerProvider.notifier).openProject(project);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EditorScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final projects = ref.watch(projectsControllerProvider);
    final theme = Theme.of(context);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ola, ${profile.name}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text('Aurea', style: theme.textTheme.headlineLarge),
                  ],
                ),
              ),
              const AureaLogo(size: 42),
            ],
          ),
          const SizedBox(height: 22),
          _HeroCard(onCreate: () => _createProject(context, ref)),
          const SizedBox(height: 30),
          Text('Comecar com um formato', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final aspect in ProjectPresets.aspects.take(3))
                Expanded(
                  child: _QuickFormat(
                    option: aspect,
                    onTap: () => _createProject(
                      context,
                      ref,
                      presetAspectKey: aspect.key,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 26),
          const WhatsNewCard(),
          const SizedBox(height: 26),
          Text('Recentes', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (projects.isEmpty)
            const _EmptyProjects()
          else
            for (final project in projects)
              _ProjectRow(
                project: project,
                onOpen: () => _openProject(context, ref, project),
                onDelete: () => ref
                    .read(projectsControllerProvider.notifier)
                    .remove(project.id),
              ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.violet.withValues(alpha: 0.26),
            AppColors.surface,
            AppColors.lime.withValues(alpha: 0.10),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Crie algo novo', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Monte sua timeline com videos, audio e efeitos, e exporte direto do celular.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            icon: const Icon(CupertinoIcons.plus, size: 19),
            label: const Text('Novo projeto'),
            onPressed: onCreate,
          ),
        ],
      ),
    );
  }
}

class _QuickFormat extends StatelessWidget {
  const _QuickFormat({required this.option, required this.onTap});

  final AspectOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Icon(option.icon, color: AppColors.lime, size: 24),
            const SizedBox(height: 8),
            Text(
              option.label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                color: AppColors.onDark,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              option.hint,
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({
    required this.project,
    required this.onOpen,
    required this.onDelete,
  });

  final VideoProject project;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  String get _specs {
    final aspect = ProjectPresets.aspects
        .firstWhere(
          (a) => (a.ratio - project.aspectRatio).abs() < 0.01,
          orElse: () => ProjectPresets.aspects.first,
        )
        .label;
    return '$aspect - ${ProjectPresets.resolutionLabel(project.resolutionHeight)} - ${project.fps} fps';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.violet.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(CupertinoIcons.film,
                  color: AppColors.violet, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 1),
                  Text(_specs, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onDelete,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(CupertinoIcons.trash,
                    size: 19, color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(CupertinoIcons.film, color: AppColors.muted, size: 30),
          SizedBox(height: 10),
          Text(
            'Seus projetos aparecerao aqui',
            style: TextStyle(color: AppColors.muted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
