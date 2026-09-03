import 'laboratory_level.dart';

enum LaboratoryAssetId {
  referenceCard,
  spokenVideo,
  silentVideo,
  beatTrack,
  smallGlb,
  largeGlb,
  equirectangularPanorama,
  phonePanorama,
  extraFont,
  appleReferenceProject,
}

/// Um ativo reproduzivel usado por uma tarefa de aceite.
///
/// [location] pode ser um caminho de asset empacotado ou o caminho local do
/// arquivo baixado uma vez. O dominio nao executa IO.
class TestAssetRequirement {
  const TestAssetRequirement({
    required this.id,
    required this.label,
    this.location,
    this.bundled = true,
    this.approximateBytes,
  });

  final LaboratoryAssetId id;
  final String label;
  final String? location;
  final bool bundled;
  final int? approximateBytes;

  Map<String, Object?> toJson() => {
    'id': id.name,
    'label': label,
    if (location != null) 'location': location,
    'bundled': bundled,
    if (approximateBytes != null) 'approximateBytes': approximateBytes,
  };

  factory TestAssetRequirement.fromJson(Map<String, Object?> json) {
    return TestAssetRequirement(
      id: LaboratoryAssetId.values.firstWhere(
        (value) => value.name == json['id'],
        orElse: () => LaboratoryAssetId.referenceCard,
      ),
      label: json['label']?.toString() ?? 'Ativo de teste',
      location: json['location']?.toString(),
      bundled: json['bundled'] as bool? ?? true,
      approximateBytes: (json['approximateBytes'] as num?)?.toInt(),
    );
  }
}

class AcceptanceStepDefinition {
  AcceptanceStepDefinition({
    required this.id,
    required String instruction,
    this.assets = const <TestAssetRequirement>[],
    this.screenshotRecommended = false,
  }) : instruction = instruction.trim(),
       assert(id != ''),
       assert(instruction.trim() != '');

  final String id;
  final String instruction;
  final List<TestAssetRequirement> assets;
  final bool screenshotRecommended;

  Map<String, Object?> toJson() => {
    'id': id,
    'instruction': instruction,
    if (assets.isNotEmpty)
      'assets': [for (final asset in assets) asset.toJson()],
    if (screenshotRecommended) 'screenshotRecommended': true,
  };

  factory AcceptanceStepDefinition.fromJson(Map<String, Object?> json) {
    final rawAssets = json['assets'];
    return AcceptanceStepDefinition(
      id: json['id']?.toString() ?? 'step',
      instruction: json['instruction']?.toString() ?? 'Executar passo',
      assets: [
        if (rawAssets is Iterable)
          for (final asset in rawAssets)
            if (asset is Map)
              TestAssetRequirement.fromJson(
                asset.map((key, value) => MapEntry(key.toString(), value)),
              ),
      ],
      screenshotRecommended: json['screenshotRecommended'] as bool? ?? false,
    );
  }
}

class AcceptanceTaskDefinition {
  AcceptanceTaskDefinition({
    required this.level,
    required String title,
    required Iterable<AcceptanceStepDefinition> steps,
  }) : title = title.trim(),
       steps = List.unmodifiable(steps) {
    if (this.title.isEmpty) throw ArgumentError.value(title, 'title');
    if (this.steps.isEmpty) throw ArgumentError('A tarefa precisa de passos.');
    final ids = <String>{};
    for (final step in this.steps) {
      if (!ids.add(step.id)) {
        throw ArgumentError('Passo duplicado: ${step.id}');
      }
    }
  }

  final LaboratoryLevelId level;
  final String title;
  final List<AcceptanceStepDefinition> steps;

  AcceptanceStepDefinition stepById(String id) =>
      steps.firstWhere((step) => step.id == id);

  Map<String, Object?> toJson() => {
    'level': level.name,
    'title': title,
    'steps': [for (final step in steps) step.toJson()],
  };

  factory AcceptanceTaskDefinition.fromJson(Map<String, Object?> json) {
    final rawSteps = json['steps'];
    return AcceptanceTaskDefinition(
      level:
          LaboratoryLevelIdX.tryParse(json['level']?.toString() ?? '') ??
          LaboratoryLevelId.core,
      title: json['title']?.toString() ?? 'Tarefa de aceite',
      steps: [
        if (rawSteps is Iterable)
          for (final step in rawSteps)
            if (step is Map)
              AcceptanceStepDefinition.fromJson(
                step.map((key, value) => MapEntry(key.toString(), value)),
              ),
      ],
    );
  }
}

/// Catalogo dos ativos exigidos pela especificacao do Laboratorio.
abstract final class LaboratoryTestAssets {
  static const referenceCard = TestAssetRequirement(
    id: LaboratoryAssetId.referenceCard,
    label: 'Cartela de referencia',
  );
  static const spokenVideo = TestAssetRequirement(
    id: LaboratoryAssetId.spokenVideo,
    label: 'Video de 60 s com fala em PT-BR',
  );
  static const silentVideo = TestAssetRequirement(
    id: LaboratoryAssetId.silentVideo,
    label: 'Video de 60 s de silencio puro',
  );
  static const beatTrack = TestAssetRequirement(
    id: LaboratoryAssetId.beatTrack,
    label: 'Trilha com batidas marcadas',
  );
  static const smallGlb = TestAssetRequirement(
    id: LaboratoryAssetId.smallGlb,
    label: 'Produto 3D pequeno',
    approximateBytes: 3000000,
  );
  static const largeGlb = TestAssetRequirement(
    id: LaboratoryAssetId.largeGlb,
    label: 'Produto 3D grande',
    approximateBytes: 40000000,
  );
  static const equirectangularPanorama = TestAssetRequirement(
    id: LaboratoryAssetId.equirectangularPanorama,
    label: 'Panorama equiretangular',
  );
  static const phonePanorama = TestAssetRequirement(
    id: LaboratoryAssetId.phonePanorama,
    label: 'Panorama de celular de 150 graus',
  );
  static const extraFont = TestAssetRequirement(
    id: LaboratoryAssetId.extraFont,
    label: 'Fonte extra TTF',
  );
  static const appleReferenceProject = TestAssetRequirement(
    id: LaboratoryAssetId.appleReferenceProject,
    label: 'Projeto Apple de referencia',
  );

  static const all = <TestAssetRequirement>[
    referenceCard,
    spokenVideo,
    silentVideo,
    beatTrack,
    smallGlb,
    largeGlb,
    equirectangularPanorama,
    phonePanorama,
    extraFont,
    appleReferenceProject,
  ];
}
