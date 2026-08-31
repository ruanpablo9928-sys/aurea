import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../editor/domain/video_project.dart';

/// Renderizacao do projeto para um arquivo final via FFmpeg.
///
/// Versao inicial: exporta apenas o primeiro clip de video (remux/transcode
/// simples). A composicao completa da timeline (concat, overlays, audio mix)
/// sera construida sobre esta base.
class ExportService {
  Future<String?> exportProject(VideoProject project) async {
    final clip = project.firstVideoLayer;
    if (clip == null) return null;

    final outputDir = await getApplicationDocumentsDirectory();
    final outputPath =
        '${outputDir.path}${Platform.pathSeparator}aurea_export_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final session = await FFmpegKit.execute(
      '-y -i "${clip.sourcePath}" -c copy "$outputPath"',
    );
    final returnCode = await session.getReturnCode();
    return ReturnCode.isSuccess(returnCode) ? outputPath : null;
  }
}

final exportServiceProvider = Provider<ExportService>((ref) => ExportService());
