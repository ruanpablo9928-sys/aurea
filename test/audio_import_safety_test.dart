import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/media/application/media_import_service.dart';

class _Import extends MediaImportService {
  bool cancelled = false, fail = false, video = false;
  Completer<Duration>? duration;
  @override
  Future<XFile?> pickAudioFile() async => cancelled ? null : XFile('audio.wav');
  @override
  Future<XFile?> pickAudioFromVideo() async {
    video = true;
    return pickAudioFile();
  }

  @override
  Future<Duration> audioDuration(String path) async {
    if (fail) throw const FormatException('Sem audio');
    return duration?.future ?? const Duration(seconds: 12);
  }
}

void main() {
  test(
    'cancelled and unreadable import do not create provisional layers',
    () async {
      final service = _Import();
      final c = ProviderContainer(
        overrides: [mediaImportServiceProvider.overrideWithValue(service)],
      );
      addTearDown(c.dispose);
      final controller = c.read(editorControllerProvider.notifier);
      service.cancelled = true;
      await controller.importAudioFile(Duration.zero);
      expect(c.read(editorControllerProvider).layers, isEmpty);
      service.cancelled = false;
      service.fail = true;
      await expectLater(
        controller.importAudioFile(Duration.zero),
        throwsFormatException,
      );
      expect(c.read(editorControllerProvider).layers, isEmpty);
      service.fail = false;
      await controller.importAudioFile(Duration.zero, fromVideo: true);
      expect(service.video, isTrue);
      expect(
        c.read(editorControllerProvider).layers.single.duration,
        const Duration(seconds: 12),
      );
    },
  );
  test(
    'disposing editor during a metadata probe discards the result',
    () async {
      final service = _Import()..duration = Completer<Duration>();
      final c = ProviderContainer(
        overrides: [mediaImportServiceProvider.overrideWithValue(service)],
      );
      final work = c
          .read(editorControllerProvider.notifier)
          .importAudioFile(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      c.dispose();
      service.duration!.complete(const Duration(seconds: 2));
      await work;
    },
  );
}
