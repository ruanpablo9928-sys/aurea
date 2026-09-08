import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
// Tests replace the native player underneath our video_player dependency.
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:aurea/src/features/editor/application/video_layer_manager.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';

class _NativePlayer extends VideoPlayerPlatform {
  final events = StreamController<VideoEvent>();
  final calls = <String>[];
  Duration position = Duration.zero;
  Completer<void>? seekGate;
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    events.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        size: const Size(128, 72),
        duration: const Duration(seconds: 20),
      ),
    );
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events.stream;
  @override
  Future<void> dispose(int playerId) async {}
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> pause(int playerId) async {
    calls.add('pause');
  }

  @override
  Future<void> play(int playerId) async {
    calls.add('play@${position.inMilliseconds}');
  }

  @override
  Future<Duration> getPosition(int playerId) async => position;
  @override
  Future<void> seekTo(int playerId, Duration target) async {
    calls.add('seek@${target.inMilliseconds}');
    final gate = seekGate;
    if (gate != null) await gate.future;
    position = target;
    calls.add('ready@${target.inMilliseconds}');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native play waits for the requested first frame after rewind', (
    tester,
  ) async {
    final native = _NativePlayer();
    VideoPlayerPlatform.instance = native;
    final manager = VideoLayerManager();
    final layers = [
      VideoLayer(
        id: 'clip',
        name: 'clip',
        startTime: Duration.zero,
        duration: const Duration(seconds: 10),
        sourcePath: 'fixture.mp4',
      ),
    ];
    manager.sync(layers, const Duration(seconds: 4), false);
    await tester.pumpAndSettle();
    expect(manager.controllerFor('clip'), isNotNull);
    expect(native.position, const Duration(seconds: 4));
    native.calls.clear();
    native.seekGate = Completer<void>();
    manager.sync(layers, Duration.zero, true);
    await tester.pump();
    manager.sync(layers, const Duration(milliseconds: 33), true);
    manager.sync(layers, const Duration(milliseconds: 66), true);
    expect(
      native.calls.where((c) => c.startsWith('play@')),
      isEmpty,
      reason: 'the decoder still holds the frame from the middle of the clip',
    );
    native.seekGate!.complete();
    await tester.pump();
    await tester.pump();
    expect(native.calls, contains('play@0'));
    manager.dispose();
    await tester.pumpAndSettle();
    unawaited(native.events.close());
  });

  for (final offset in [Duration.zero, const Duration(seconds: 2)]) {
    testWidgets('rewind while playing honors trimmed source offset $offset', (
      tester,
    ) async {
      final native = _NativePlayer();
      VideoPlayerPlatform.instance = native;
      final manager = VideoLayerManager();
      final layers = [
        VideoLayer(
          id: 'clip',
          name: 'clip',
          startTime: Duration.zero,
          duration: const Duration(seconds: 10),
          sourcePath: 'fixture.mp4',
          sourceOffset: offset,
        ),
      ];
      manager.sync(layers, const Duration(seconds: 4), true);
      await tester.pumpAndSettle();
      native.calls.clear();
      native.seekGate = Completer<void>();
      expect(
        manager.sync(layers, Duration.zero, true, seekRevision: 1),
        isNull,
      );
      await tester.pump();
      expect(native.calls, contains('pause'));
      expect(native.calls, contains('seek@${offset.inMilliseconds}'));
      expect(native.calls.where((c) => c.startsWith('play@')), isEmpty);
      native.seekGate!.complete();
      await tester.pumpAndSettle();
      expect(native.calls.last, 'play@${offset.inMilliseconds}');
      manager.dispose();
      await tester.pumpAndSettle();
      unawaited(native.events.close());
    });
  }

  testWidgets(
    'pause cancels a pending start and scrub expiry does not pause playback',
    (tester) async {
      final native = _NativePlayer();
      VideoPlayerPlatform.instance = native;
      final manager = VideoLayerManager();
      final layers = [
        VideoLayer(
          id: 'clip',
          name: 'clip',
          startTime: Duration.zero,
          duration: const Duration(seconds: 10),
          sourcePath: 'fixture.mp4',
        ),
      ];
      manager.sync(layers, Duration.zero, false);
      await tester.pumpAndSettle();
      native.calls.clear();
      native.seekGate = Completer<void>();
      manager.sync(layers, const Duration(seconds: 1), true);
      await tester.pump();
      manager.sync(layers, const Duration(seconds: 1), false);
      native.seekGate!.complete();
      await tester.pumpAndSettle();
      expect(native.calls.where((c) => c.startsWith('play@')), isEmpty);
      native.seekGate = null;
      manager.scrub();
      manager.sync(layers, const Duration(seconds: 1), true);
      await tester.pumpAndSettle();
      native.calls.clear();
      await tester.pump(const Duration(milliseconds: 200));
      expect(native.calls, isNot(contains('pause')));
      manager.dispose();
      await tester.pumpAndSettle();
      unawaited(native.events.close());
    },
  );
}
