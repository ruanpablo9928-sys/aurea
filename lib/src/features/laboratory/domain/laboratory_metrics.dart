enum ThermalState { unknown, nominal, fair, serious, critical }

extension ThermalStateLabel on ThermalState {
  String get reportLabel => switch (this) {
    ThermalState.unknown => 'desconhecida',
    ThermalState.nominal => 'normal',
    ThermalState.fair => 'morna',
    ThermalState.serious => 'quente',
    ThermalState.critical => 'critica',
  };
}

/// Amostra produzida pelo overlay de desempenho.
class PerformanceSample {
  const PerformanceSample({
    required this.fps,
    this.gear,
    this.drawCalls = 0,
    this.renderPasses = 0,
    this.liveDecoders = 0,
    this.audioUnderruns = 0,
    this.allocationsPerFrame = 0,
    this.thermalState = ThermalState.unknown,
    this.temperatureCelsius,
  }) : assert(fps >= 0),
       assert(drawCalls >= 0),
       assert(renderPasses >= 0),
       assert(liveDecoders >= 0),
       assert(audioUnderruns >= 0),
       assert(allocationsPerFrame >= 0);

  final double fps;
  final String? gear;
  final int drawCalls;
  final int renderPasses;
  final int liveDecoders;
  final int audioUnderruns;
  final int allocationsPerFrame;
  final ThermalState thermalState;
  final double? temperatureCelsius;
}

/// Metricas acumuladas automaticamente durante um passo.
class LaboratoryMetrics {
  const LaboratoryMetrics({
    this.touchCount = 0,
    this.elapsed = Duration.zero,
    this.currentFps = 0,
    this.averageFps = 0,
    this.minimumFps = 0,
    this.fpsSampleCount = 0,
    this.gear,
    this.drawCalls = 0,
    this.renderPasses = 0,
    this.liveDecoders = 0,
    this.audioUnderruns = 0,
    this.allocationsPerFrame = 0,
    this.thermalState = ThermalState.unknown,
    this.temperatureCelsius,
  }) : assert(touchCount >= 0),
       assert(fpsSampleCount >= 0);

  final int touchCount;
  final Duration elapsed;
  final double currentFps;
  final double averageFps;
  final double minimumFps;
  final int fpsSampleCount;
  final String? gear;
  final int drawCalls;
  final int renderPasses;
  final int liveDecoders;
  final int audioUnderruns;
  final int allocationsPerFrame;
  final ThermalState thermalState;
  final double? temperatureCelsius;

  LaboratoryMetrics recordTouch([int count = 1]) {
    if (count < 0) throw ArgumentError.value(count, 'count');
    return copyWith(touchCount: touchCount + count);
  }

  LaboratoryMetrics recordPerformance(PerformanceSample sample) {
    final count = fpsSampleCount + 1;
    final average = ((averageFps * fpsSampleCount) + sample.fps) / count;
    final minimum = fpsSampleCount == 0
        ? sample.fps
        : (sample.fps < minimumFps ? sample.fps : minimumFps);
    return copyWith(
      currentFps: sample.fps,
      averageFps: average,
      minimumFps: minimum,
      fpsSampleCount: count,
      gear: sample.gear,
      clearGear: sample.gear == null,
      drawCalls: sample.drawCalls,
      renderPasses: sample.renderPasses,
      liveDecoders: sample.liveDecoders,
      // Underruns sao contador acumulado: nunca pode regredir por uma amostra
      // atrasada do overlay.
      audioUnderruns: sample.audioUnderruns > audioUnderruns
          ? sample.audioUnderruns
          : audioUnderruns,
      allocationsPerFrame: sample.allocationsPerFrame,
      thermalState: sample.thermalState,
      temperatureCelsius: sample.temperatureCelsius,
      clearTemperature: sample.temperatureCelsius == null,
    );
  }

  LaboratoryMetrics copyWith({
    int? touchCount,
    Duration? elapsed,
    double? currentFps,
    double? averageFps,
    double? minimumFps,
    int? fpsSampleCount,
    String? gear,
    bool clearGear = false,
    int? drawCalls,
    int? renderPasses,
    int? liveDecoders,
    int? audioUnderruns,
    int? allocationsPerFrame,
    ThermalState? thermalState,
    double? temperatureCelsius,
    bool clearTemperature = false,
  }) => LaboratoryMetrics(
    touchCount: touchCount ?? this.touchCount,
    elapsed: elapsed ?? this.elapsed,
    currentFps: currentFps ?? this.currentFps,
    averageFps: averageFps ?? this.averageFps,
    minimumFps: minimumFps ?? this.minimumFps,
    fpsSampleCount: fpsSampleCount ?? this.fpsSampleCount,
    gear: clearGear ? null : gear ?? this.gear,
    drawCalls: drawCalls ?? this.drawCalls,
    renderPasses: renderPasses ?? this.renderPasses,
    liveDecoders: liveDecoders ?? this.liveDecoders,
    audioUnderruns: audioUnderruns ?? this.audioUnderruns,
    allocationsPerFrame: allocationsPerFrame ?? this.allocationsPerFrame,
    thermalState: thermalState ?? this.thermalState,
    temperatureCelsius: clearTemperature
        ? null
        : temperatureCelsius ?? this.temperatureCelsius,
  );

  Map<String, Object?> toJson() => {
    'touchCount': touchCount,
    'elapsedUs': elapsed.inMicroseconds,
    'currentFps': currentFps,
    'averageFps': averageFps,
    'minimumFps': minimumFps,
    'fpsSampleCount': fpsSampleCount,
    if (gear != null) 'gear': gear,
    'drawCalls': drawCalls,
    'renderPasses': renderPasses,
    'liveDecoders': liveDecoders,
    'audioUnderruns': audioUnderruns,
    'allocationsPerFrame': allocationsPerFrame,
    'thermalState': thermalState.name,
    if (temperatureCelsius != null) 'temperatureCelsius': temperatureCelsius,
  };

  factory LaboratoryMetrics.fromJson(Map<String, Object?> json) {
    int nonNegativeInt(String key) {
      final value = (json[key] as num?)?.toInt() ?? 0;
      return value < 0 ? 0 : value;
    }

    double nonNegativeDouble(String key) {
      final value = (json[key] as num?)?.toDouble() ?? 0;
      return value < 0 || !value.isFinite ? 0 : value;
    }

    return LaboratoryMetrics(
      touchCount: nonNegativeInt('touchCount'),
      elapsed: Duration(microseconds: nonNegativeInt('elapsedUs')),
      currentFps: nonNegativeDouble('currentFps'),
      averageFps: nonNegativeDouble('averageFps'),
      minimumFps: nonNegativeDouble('minimumFps'),
      fpsSampleCount: nonNegativeInt('fpsSampleCount'),
      gear: json['gear']?.toString(),
      drawCalls: nonNegativeInt('drawCalls'),
      renderPasses: nonNegativeInt('renderPasses'),
      liveDecoders: nonNegativeInt('liveDecoders'),
      audioUnderruns: nonNegativeInt('audioUnderruns'),
      allocationsPerFrame: nonNegativeInt('allocationsPerFrame'),
      thermalState: ThermalState.values.firstWhere(
        (value) => value.name == json['thermalState'],
        orElse: () => ThermalState.unknown,
      ),
      temperatureCelsius: (json['temperatureCelsius'] as num?)?.toDouble(),
    );
  }
}
