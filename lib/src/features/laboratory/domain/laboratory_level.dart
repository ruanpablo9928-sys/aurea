/// Funcionalidades que podem ser ligadas no Laboratorio.
///
/// O panorama continua sendo 8.1: ele aparece separado porque depende da
/// Cena 3D, embora ocupe a mesma linha visual no documento de produto.
enum LaboratoryLevelId {
  core,
  shapes,
  text,
  effects,
  mask,
  cut,
  apple,
  captions,
  scene3d,
  panorama,
  nullAndClone,
  uiFinal,
}

extension LaboratoryLevelIdX on LaboratoryLevelId {
  String get code => switch (this) {
    LaboratoryLevelId.core => '0',
    LaboratoryLevelId.shapes => '1',
    LaboratoryLevelId.text => '2',
    LaboratoryLevelId.effects => '3',
    LaboratoryLevelId.mask => '4',
    LaboratoryLevelId.cut => '5',
    LaboratoryLevelId.apple => '6',
    LaboratoryLevelId.captions => '7',
    LaboratoryLevelId.scene3d => '8',
    LaboratoryLevelId.panorama => '8.1',
    LaboratoryLevelId.nullAndClone => '9',
    LaboratoryLevelId.uiFinal => '10.1',
  };

  int get sortOrder => switch (this) {
    LaboratoryLevelId.core => 0,
    LaboratoryLevelId.shapes => 10,
    LaboratoryLevelId.text => 20,
    LaboratoryLevelId.effects => 30,
    LaboratoryLevelId.mask => 40,
    LaboratoryLevelId.cut => 50,
    LaboratoryLevelId.apple => 60,
    LaboratoryLevelId.captions => 70,
    LaboratoryLevelId.scene3d => 80,
    LaboratoryLevelId.panorama => 81,
    LaboratoryLevelId.nullAndClone => 90,
    LaboratoryLevelId.uiFinal => 101,
  };

  static LaboratoryLevelId? tryParse(String value) {
    for (final level in LaboratoryLevelId.values) {
      if (level.name == value || level.code == value) return level;
    }
    return null;
  }
}

/// Metadados estaveis de um nivel, usados pela tela e pelo motor de testes.
class LaboratoryLevelDefinition {
  const LaboratoryLevelDefinition({
    required this.id,
    required this.title,
    required this.expectedUi,
    this.dependencies = const <LaboratoryLevelId>{LaboratoryLevelId.core},
    this.alwaysEnabled = false,
  });

  final LaboratoryLevelId id;
  final String title;

  /// Descricao curta do ponto da interface que precisa aparecer imediatamente.
  final String expectedUi;
  final Set<LaboratoryLevelId> dependencies;
  final bool alwaysEnabled;
}

/// Catalogo unico dos niveis e de suas dependencias.
abstract final class LaboratoryLevelCatalog {
  static const Map<LaboratoryLevelId, LaboratoryLevelDefinition> byId = {
    LaboratoryLevelId.core: LaboratoryLevelDefinition(
      id: LaboratoryLevelId.core,
      title: 'Nucleo',
      expectedUi: 'Editor base',
      dependencies: <LaboratoryLevelId>{},
      alwaysEnabled: true,
    ),
    LaboratoryLevelId.shapes: LaboratoryLevelDefinition(
      id: LaboratoryLevelId.shapes,
      title: 'Shapes',
      expectedUi: '+ > Shape e Edit Shape',
    ),
    LaboratoryLevelId.text: LaboratoryLevelDefinition(
      id: LaboratoryLevelId.text,
      title: 'Texto',
      expectedUi: '+ > Text e Presets',
    ),
    LaboratoryLevelId.effects: LaboratoryLevelDefinition(
      id: LaboratoryLevelId.effects,
      title: 'Seis efeitos',
      expectedUi: 'Secao Effects',
    ),
    LaboratoryLevelId.mask: LaboratoryLevelDefinition(
      id: LaboratoryLevelId.mask,
      title: 'Mascara',
      expectedUi: 'Mascara em Blending & Opacity',
    ),
    LaboratoryLevelId.cut: LaboratoryLevelDefinition(
      id: LaboratoryLevelId.cut,
      title: 'Corte',
      expectedUi: 'Juncao entre clipes',
    ),
    LaboratoryLevelId.apple: LaboratoryLevelDefinition(
      id: LaboratoryLevelId.apple,
      title: 'Apple',
      expectedUi: 'Presets de curva e estilos Apple',
    ),
    LaboratoryLevelId.captions: LaboratoryLevelDefinition(
      id: LaboratoryLevelId.captions,
      title: 'Legendas',
      expectedUi: 'Botao Legendar na camada de video',
    ),
    LaboratoryLevelId.scene3d: LaboratoryLevelDefinition(
      id: LaboratoryLevelId.scene3d,
      title: 'Cena 3D',
      expectedUi: '+ > Object > Cena 3D',
    ),
    LaboratoryLevelId.panorama: LaboratoryLevelDefinition(
      id: LaboratoryLevelId.panorama,
      title: 'Panorama',
      expectedUi: 'Ambiente dentro da Cena 3D',
      dependencies: <LaboratoryLevelId>{
        LaboratoryLevelId.core,
        LaboratoryLevelId.scene3d,
      },
    ),
    LaboratoryLevelId.nullAndClone: LaboratoryLevelDefinition(
      id: LaboratoryLevelId.nullAndClone,
      title: 'Nulo e Clonar',
      expectedUi: '+ > Object > Nulo e secao Clonar',
      dependencies: <LaboratoryLevelId>{
        LaboratoryLevelId.core,
        LaboratoryLevelId.scene3d,
      },
    ),
    // 10.1 nao acrescenta feature nenhuma: e a prova de que as outras
    // dez cabem na mesma tela. Por isso depende de todas — liga-lo liga
    // o app inteiro, que e o estado em que a contagem vale.
    LaboratoryLevelId.uiFinal: LaboratoryLevelDefinition(
      id: LaboratoryLevelId.uiFinal,
      title: 'UI final',
      expectedUi: 'As cinco zonas com os dez niveis ligados',
      dependencies: <LaboratoryLevelId>{
        LaboratoryLevelId.core,
        LaboratoryLevelId.shapes,
        LaboratoryLevelId.text,
        LaboratoryLevelId.effects,
        LaboratoryLevelId.mask,
        LaboratoryLevelId.cut,
        LaboratoryLevelId.apple,
        LaboratoryLevelId.captions,
        LaboratoryLevelId.scene3d,
        LaboratoryLevelId.panorama,
        LaboratoryLevelId.nullAndClone,
      },
    ),
  };

  static List<LaboratoryLevelDefinition> get ordered {
    final result = byId.values.toList()
      ..sort((a, b) => a.id.sortOrder.compareTo(b.id.sortOrder));
    return List.unmodifiable(result);
  }

  static LaboratoryLevelDefinition definition(LaboratoryLevelId id) =>
      byId[id]!;

  /// Dependencias transitivas, incluindo o proprio nivel.
  static Set<LaboratoryLevelId> closureOf(LaboratoryLevelId id) {
    final result = <LaboratoryLevelId>{};

    void visit(LaboratoryLevelId current) {
      if (!result.add(current)) return;
      for (final dependency in definition(current).dependencies) {
        visit(dependency);
      }
    }

    visit(id);
    return Set.unmodifiable(result);
  }

  static Set<LaboratoryLevelId> dependentsOf(LaboratoryLevelId id) {
    final result = <LaboratoryLevelId>{};
    for (final candidate in byId.keys) {
      if (candidate != id && closureOf(candidate).contains(id)) {
        result.add(candidate);
      }
    }
    return Set.unmodifiable(result);
  }
}

/// Selecao normalizada: o Nucleo e as dependencias sempre permanecem ligados.
class LaboratoryLevelSelection {
  LaboratoryLevelSelection([Iterable<LaboratoryLevelId> enabled = const []])
    : enabled = Set.unmodifiable(_normalize(enabled));

  factory LaboratoryLevelSelection.fromJson(Object? json) {
    if (json is! Iterable) return LaboratoryLevelSelection();
    return LaboratoryLevelSelection(
      json
          .map((value) => LaboratoryLevelIdX.tryParse(value.toString()))
          .whereType<LaboratoryLevelId>(),
    );
  }

  final Set<LaboratoryLevelId> enabled;

  bool isEnabled(LaboratoryLevelId id) => enabled.contains(id);

  LaboratoryLevelSelection enable(LaboratoryLevelId id) =>
      LaboratoryLevelSelection(<LaboratoryLevelId>{
        ...enabled,
        ...LaboratoryLevelCatalog.closureOf(id),
      });

  /// Desligar uma dependencia tambem desliga tudo que deixaria de ser valido.
  /// O Nucleo nunca pode ser desligado.
  LaboratoryLevelSelection disable(LaboratoryLevelId id) {
    if (LaboratoryLevelCatalog.definition(id).alwaysEnabled) return this;
    final removed = <LaboratoryLevelId>{
      id,
      ...LaboratoryLevelCatalog.dependentsOf(id),
    };
    return LaboratoryLevelSelection(enabled.difference(removed));
  }

  List<String> toJson() {
    final values = enabled.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return [for (final value in values) value.name];
  }

  static Set<LaboratoryLevelId> _normalize(Iterable<LaboratoryLevelId> values) {
    final result = <LaboratoryLevelId>{LaboratoryLevelId.core};
    for (final value in values) {
      result.addAll(LaboratoryLevelCatalog.closureOf(value));
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      other is LaboratoryLevelSelection &&
      enabled.length == other.enabled.length &&
      enabled.containsAll(other.enabled);

  @override
  int get hashCode => Object.hashAll(
    (enabled.toList()..sort((a, b) => a.index.compareTo(b.index))),
  );
}
