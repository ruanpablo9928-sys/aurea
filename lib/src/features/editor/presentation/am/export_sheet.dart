import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../application/editor_controller.dart';
import '../../domain/lottie_export.dart';
import 'am_colors.dart';
import 'am_widgets.dart';

/// EXPORTAR (spec motion-graphics-pro, PR-X23/X25): Lottie com validador
/// e SVG animado. Motion designer que trabalha para produto entrega
/// Lottie, nao MP4.
Future<void> showExportSheet(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(editorControllerProvider.notifier);
  String? status;
  var busy = false;

  await showParamSheet(
    context,
    heightFactor: 0.55,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final project = ref.read(editorControllerProvider);
        final issues = validateForLottie(project);
        final blocking = issues.where((i) => i.blocking).toList();
        final warnings = issues.where((i) => !i.blocking).toList();

        Future<void> writeFile(
            String name, String content, String label) async {
          setSheetState(() => busy = true);
          try {
            final dir = await getApplicationDocumentsDirectory();
            final out = Directory('${dir.path}/exports');
            if (!out.existsSync()) out.createSync(recursive: true);
            final file = File('${out.path}/$name');
            await file.writeAsString(content);
            await Clipboard.setData(ClipboardData(text: file.path));
            setSheetState(() {
              busy = false;
              status = '$label salvo em ${file.path}\n'
                  '(caminho copiado para a area de transferencia)';
            });
          } catch (e) {
            setSheetState(() {
              busy = false;
              status = 'Falhou: $e';
            });
          }
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Exportar',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AmColors.text)),
                const SizedBox(height: 4),
                // Modo compativel: avisa desde o comeco, em vez de
                // surpreender no fim.
                Row(
                  children: [
                    Transform.scale(
                      scale: 0.72,
                      child: CupertinoSwitch(
                        value: project.lottieMode,
                        activeTrackColor: AmColors.accent,
                        onChanged: (v) {
                          controller.setLottieMode(v);
                          setSheetState(() {});
                        },
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Modo compativel com Lottie: avisa sobre o que '
                        'nao sobrevive enquanto voce monta.',
                        style: TextStyle(
                            fontSize: 11, color: AmColors.muted),
                      ),
                    ),
                  ],
                ),
                const Divider(color: AmColors.hairline, height: 18),

                // VALIDADOR: o que nao sobrevive, camada por camada.
                Text(
                  blocking.isEmpty
                      ? 'Tudo sobrevive ao Lottie.'
                      : '${blocking.length} camada(s) NAO sobrevivem:',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: blocking.isEmpty
                          ? AmColors.accent
                          : const Color(0xFFE85B81)),
                ),
                const SizedBox(height: 4),
                for (final i in blocking)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(CupertinoIcons.exclamationmark_triangle,
                            size: 14, color: Color(0xFFE85B81)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('${i.layerName}: ${i.message}',
                              style: const TextStyle(
                                  fontSize: 11, color: AmColors.muted)),
                        ),
                      ],
                    ),
                  ),
                for (final i in warnings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(CupertinoIcons.info_circle,
                            size: 14, color: AmColors.muted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('${i.layerName}: ${i.message}',
                              style: const TextStyle(
                                  fontSize: 11, color: AmColors.muted)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: AmColors.accent,
                    borderRadius: BorderRadius.circular(12),
                    onPressed: busy
                        ? null
                        : () {
                            final out = exportLottie(project);
                            writeFile(
                              '${project.name}.json',
                              const JsonEncoder.withIndent('  ')
                                  .convert(out.json),
                              'Lottie (${out.exported} camadas'
                              '${out.skipped > 0 ? ', ${out.skipped} puladas' : ''})',
                            );
                          },
                    child: const Text('Exportar Lottie (.json)',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0B0E12))),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: AmColors.chip,
                    borderRadius: BorderRadius.circular(12),
                    onPressed: busy
                        ? null
                        : () => writeFile(
                              '${project.name}.svg',
                              exportAnimatedSvg(project),
                              'SVG animado',
                            ),
                    child: const Text('Exportar SVG animado',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AmColors.accent)),
                  ),
                ),
                if (status != null) ...[
                  const SizedBox(height: 10),
                  Text(status!,
                      style: const TextStyle(
                          fontSize: 11, color: AmColors.accent)),
                ],
                const SizedBox(height: 8),
                const Text(
                  'Video (MP4) continua em desenvolvimento.',
                  style: TextStyle(fontSize: 11, color: AmColors.muted),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
