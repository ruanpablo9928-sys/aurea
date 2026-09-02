import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../editor/application/proxy_service.dart';
import '../../editor/application/media_preview_service.dart';
import '../../../core/ui/snack.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/app_mode.dart';
import '../../../core/theme/app_theme.dart';
import '../../projects/domain/project_presets.dart';
import '../application/settings_controller.dart';

/// Aba Ajustes: listas agrupadas estilo iOS.
class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  Future<void> _clearCache(BuildContext context) async {
    var removedBytes = 0;
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        for (final entity in tempDir.listSync()) {
          try {
            if (entity is File) {
              removedBytes += entity.lengthSync();
              entity.deleteSync();
            } else if (entity is Directory) {
              entity.deleteSync(recursive: true);
            }
          } catch (_) {
            // Arquivo em uso; ignora e segue.
          }
        }
      }
    } catch (_) {}
    if (!context.mounted) return;
    final mb = (removedBytes / (1024 * 1024)).toStringAsFixed(1);
    await ProxyService.instance.clearCache();
    MediaPreviewService.instance.clearMemory();
    if (!context.mounted) return;
    AureaSnack.show(context, 'Cache limpo ($mb MB liberados)');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final modo = ref.watch(appModeProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          Text('Ajustes', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 24),
          const _GroupHeader('Padroes de novos projetos'),
          _Group(
            children: [
              _SegmentedRow<String>(
                label: 'Proporcao',
                values: [for (final a in ProjectPresets.aspects) a.key],
                selected: settings.defaultAspectKey,
                labelOf: (k) => k,
                onChanged: controller.setDefaultAspect,
              ),
              const _GroupDivider(),
              _SegmentedRow<int>(
                label: 'Resolucao',
                values: ProjectPresets.resolutions,
                selected: settings.defaultResolution,
                labelOf: (r) => switch (r) {
                  720 => '720p',
                  1080 => '1080p',
                  2160 => '4K',
                  _ => '${r}p',
                },
                onChanged: controller.setDefaultResolution,
              ),
              const _GroupDivider(),
              _SegmentedRow<int>(
                label: 'Quadros por segundo',
                values: ProjectPresets.fpsOptions,
                selected: settings.defaultFps,
                labelOf: (f) => '$f',
                onChanged: controller.setDefaultFps,
              ),
            ],
          ),
          const SizedBox(height: 26),
          const _GroupHeader('Exportacao'),
          _Group(
            children: [
              _SwitchRow(
                title: 'Salvar na galeria',
                subtitle: 'Copia o video exportado para a galeria',
                value: settings.saveToGallery,
                onChanged: controller.setSaveToGallery,
              ),
            ],
          ),
          const SizedBox(height: 26),
          // O INTERRUPTOR (AUREA-reset-ao-nucleo.md): o nucleo e o
          // padrao; o estudio inteiro continua no codigo e liga aqui.
          const _GroupHeader('Modo'),
          _Group(
            children: [
              _SwitchRow(
                title: 'Estudio completo',
                subtitle: modo.isFull
                    ? 'Efeitos, texto, formas, 3D, particulas e o resto ligados'
                    : 'Desligado: so o nucleo (video, imagem, audio, cortes, marcadores, keyframes, exportar)',
                value: modo.isFull,
                onChanged: (v) => ref
                    .read(appModeProvider.notifier)
                    .set(v ? AppMode.full : AppMode.core),
              ),
            ],
          ),
          const SizedBox(height: 26),
          const _GroupHeader('Geral'),
          _Group(
            children: [
              _SwitchRow(
                title: 'Vibracao ao interagir',
                value: settings.hapticFeedback,
                onChanged: controller.setHapticFeedback,
              ),
              const _GroupDivider(),
              _TapRow(
                title: 'Limpar cache',
                subtitle: 'Remove arquivos temporarios de preview e render',
                onTap: () => _clearCache(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w500,
          color: AppColors.muted,
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(children: children),
    );
  }
}

class _GroupDivider extends StatelessWidget {
  const _GroupDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Divider(color: AppColors.hairline),
    );
  }
}

class _SegmentedRow<T extends Object> extends StatelessWidget {
  const _SegmentedRow({
    required this.label,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<T>(
              groupValue: selected,
              backgroundColor: AppColors.background,
              thumbColor: AppColors.surfaceHigh,
              onValueChanged: (v) {
                if (v != null) onChanged(v);
              },
              children: {
                for (final v in values)
                  v: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      labelOf(v),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                        color: v == selected
                            ? AppColors.lime
                            : AppColors.onDark,
                      ),
                    ),
                  ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyLarge),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: AppColors.lime,
            thumbColor: value ? const Color(0xFF0B0E12) : null,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _TapRow extends StatelessWidget {
  const _TapRow({required this.title, this.subtitle, required this.onTap});

  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodyLarge),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(subtitle!,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_right,
                size: 16, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
