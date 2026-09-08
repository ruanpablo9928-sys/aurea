import 'package:flutter/foundation.dart';

/// O CRONOMETRO DO PIPELINE 3D.
///
/// A regra da missao era essa: medir antes de otimizar. Este arquivo e a
/// regua — ele nao decide nada, so conta quanto tempo cada fase levou e
/// quantas vezes cada trabalho caro aconteceu.
///
/// DESLIGADO ELE CUSTA UM `if`. As fases sao chamadas no caminho quente
/// (uma vez por no, por quadro); com [ligado] falso, `fase` executa o
/// corpo e volta, sem relogio nem mapa.
///
/// O que se mede:
///
///   - FASES (tempo): sincronia de nos, transform, malha do no,
///     avaliacao de modelo, upload, render de CPU, ordenacao.
///   - CONTAS (quantidade): nos vistos, malhas reconstruidas, modelos
///     avaliados, listas de material alocadas, texturas subidas.
///
/// A diferenca entre "no visto" e "malha reconstruida" e o que separa um
/// quadro barato de um caro — e e exatamente isso que a otimizacao
/// precisa mostrar antes e depois.
abstract final class Perfil3D {
  /// Ligado so quando alguem esta medindo: o HUD do Estudio, a bancada
  /// ou um teste. Em producao fica desligado.
  static bool ligado = false;

  static final Map<String, _Fase> _fases = {};
  static final Map<String, int> _contas = {};

  /// Roda [corpo] cronometrado sob [nome]. Devolve o que o corpo devolver.
  static T fase<T>(String nome, T Function() corpo) {
    if (!ligado) return corpo();
    final relogio = Stopwatch()..start();
    try {
      return corpo();
    } finally {
      relogio.stop();
      (_fases[nome] ??= _Fase()).somar(relogio.elapsedMicroseconds);
    }
  }

  /// Soma [n] a um contador (nos vistos, malhas refeitas, alocacoes).
  static void contar(String nome, [int n = 1]) {
    if (!ligado) return;
    _contas[nome] = (_contas[nome] ?? 0) + n;
  }

  /// Marca o fim de um quadro: e o que divide os totais por quadro.
  static void quadro() {
    if (!ligado) return;
    _quadros++;
  }

  static int _quadros = 0;

  static void zerar() {
    _fases.clear();
    _contas.clear();
    _quadros = 0;
  }

  static Relatorio3D relatorio() => Relatorio3D(
    quadros: _quadros,
    fases: {
      for (final e in _fases.entries)
        e.key: (
          ms: e.value.microssegundos / 1000.0,
          chamadas: e.value.chamadas,
        ),
    },
    contas: Map.of(_contas),
  );

  /// Uma linha por fase, do mais caro para o mais barato — o formato que
  /// o HUD e a bancada mostram.
  static String emTexto() => relatorio().emTexto();
}

class _Fase {
  int microssegundos = 0;
  int chamadas = 0;

  void somar(int us) {
    microssegundos += us;
    chamadas++;
  }
}

@immutable
class Relatorio3D {
  const Relatorio3D({
    required this.quadros,
    required this.fases,
    required this.contas,
  });

  final int quadros;
  final Map<String, ({double ms, int chamadas})> fases;
  final Map<String, int> contas;

  double msPorQuadroDe(String fase) {
    final f = fases[fase];
    if (f == null || quadros == 0) return 0;
    return f.ms / quadros;
  }

  double porQuadroDe(String conta) =>
      quadros == 0 ? 0 : (contas[conta] ?? 0) / quadros;

  double get msTotalPorQuadro => quadros == 0
      ? 0
      : fases.values.fold<double>(0, (s, f) => s + f.ms) / quadros;

  String emTexto() {
    final linhas = <String>['quadros: $quadros'];
    final ordenadas = fases.entries.toList()
      ..sort((a, b) => b.value.ms.compareTo(a.value.ms));
    for (final e in ordenadas) {
      final porQuadro = quadros == 0 ? e.value.ms : e.value.ms / quadros;
      linhas.add(
        '  ${e.key.padRight(26)} ${porQuadro.toStringAsFixed(3)} ms/quadro '
        '(${e.value.chamadas} chamadas)',
      );
    }
    final contasOrdenadas = contas.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in contasOrdenadas) {
      final porQuadro = quadros == 0 ? e.value : e.value / quadros;
      linhas.add(
        '  ${e.key.padRight(26)} ${porQuadro.toStringAsFixed(1)} /quadro '
        '(${e.value} no total)',
      );
    }
    return linhas.join('\n');
  }
}
