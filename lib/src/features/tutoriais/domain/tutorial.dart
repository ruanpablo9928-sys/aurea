import 'dart:convert';

import 'package:flutter/services.dart';

/// UM TUTORIAL EM VIDEO, gravado pelo proprio app.
///
/// O video (`assets/tutoriais/<id>.mp4`) e uma gravacao de tela feita pelo
/// renderizador do app — os mesmos widgets, a mesma cena — com a faixa
/// de legenda ja desenhada embaixo. O JSON ao lado diz onde cada passo
/// comeca e termina, para a tela do tutorial listar os passos e pular
/// para qualquer um deles.
class Tutorial {
  const Tutorial({
    required this.id,
    required this.titulo,
    required this.duracao,
    required this.largura,
    required this.altura,
    required this.cenas,
  });

  final String id;
  final String titulo;

  /// Em segundos.
  final double duracao;

  /// O tamanho do video, para a proporcao na tela.
  final int largura;
  final int altura;
  final List<CenaDoTutorial> cenas;

  String get video => 'assets/tutoriais/$id.mp4';
  String get poster => 'assets/tutoriais/$id.jpg';

  /// A cena que vale num instante do video.
  CenaDoTutorial? cenaEm(double segundos) {
    CenaDoTutorial? atual;
    for (final c in cenas) {
      if (c.inicio <= segundos + 1e-6) atual = c;
    }
    return atual;
  }

  static Tutorial deJson(String id, Map<String, dynamic> m) {
    final cenas = <CenaDoTutorial>[];
    for (final item in (m['cenas'] as List? ?? const [])) {
      if (item is! Map) continue;
      final c = item.cast<String, dynamic>();
      final texto = '${c['texto'] ?? ''}'.trim();
      if (texto.isEmpty) continue;
      cenas.add(
        CenaDoTutorial(
          n: (c['n'] as num?)?.toInt() ?? cenas.length + 1,
          texto: texto,
          inicio: ((c['inicio'] as num?) ?? 0).toDouble(),
          fim: ((c['fim'] as num?) ?? 0).toDouble(),
        ),
      );
    }
    return Tutorial(
      id: id,
      titulo: '${m['titulo'] ?? id}',
      duracao: ((m['duracao'] as num?) ?? 0).toDouble(),
      largura: (m['largura'] as num?)?.toInt() ?? 780,
      altura: (m['altura'] as num?)?.toInt() ?? 1908,
      cenas: cenas,
    );
  }

  static Future<Tutorial> carregar(String id, {AssetBundle? bundle}) async {
    final texto = await (bundle ?? rootBundle).loadString(
      'assets/tutoriais/$id.json',
    );
    return deJson(id, (jsonDecode(texto) as Map).cast<String, dynamic>());
  }
}

class CenaDoTutorial {
  const CenaDoTutorial({
    required this.n,
    required this.texto,
    required this.inicio,
    required this.fim,
  });

  final int n;
  final String texto;
  final double inicio;
  final double fim;
}
