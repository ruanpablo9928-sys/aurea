import 'dart:collection';

import 'package:flutter/scheduler.dart';

/// O QUE TRAVOU O APARELHO, ANOTADO PELO PROPRIO APARELHO.
///
/// Tres tentativas de corrigir "o app congela" falharam porque as
/// medicoes eram feitas num PC, em modo de depuracao, numa bancada de
/// teste. Nada disso e um iPhone 13 com o projeto de verdade. Medir de
/// longe e adivinhar com numero — continua sendo adivinhar.
///
/// Entao o aplicativo passa a medir a si mesmo, onde o problema
/// acontece. Um quadro que passa de [limiteMs] nao e lentidao: e
/// travada, e a pessoa sente. Quando um acontece, fica registrado
/// QUANTO demorou, quanto foi construcao e quanto foi desenho, e
/// sobretudo O QUE o aplicativo estava fazendo na hora.
///
/// O custo disto e uma comparacao de inteiro por quadro. Por isso ele
/// roda tambem na versao entregue, e nao so em depuracao: uma ferramenta
/// de diagnostico que so funciona na bancada nao serve para nada.
class Travada {
  const Travada({
    required this.quando,
    required this.totalMs,
    required this.construcaoMs,
    required this.desenhoMs,
    required this.oQue,
    required this.contexto,
  });

  final DateTime quando;

  /// O quadro inteiro, da construcao ate a tela.
  final int totalMs;

  /// A parte em Dart: construir os widgets e o layout.
  final int construcaoMs;

  /// A parte na GPU: rasterizar.
  final int desenhoMs;

  /// O que o aplicativo estava fazendo. Vem das marcas espalhadas nas
  /// operacoes caras — "gravando o projeto", "pintor 3D em CPU".
  final String oQue;

  /// O estado que ajuda a entender: motor 3D em GPU ou CPU, quantos
  /// triangulos, quantas camadas.
  final String contexto;

  String get linha =>
      '${quando.toIso8601String().substring(11, 19)}  '
      '${totalMs.toString().padLeft(5)} ms  '
      '(constroi ${construcaoMs.toString().padLeft(4)}, '
      'desenha ${desenhoMs.toString().padLeft(4)})  '
      '$oQue  |  $contexto';
}

abstract final class RegistroDeTravadas {
  /// Acima disto a pessoa PERCEBE. Um quadro de 60 fps tem 16,7 ms; um
  /// de 120 ms e um oitavo de segundo de tela parada.
  static const limiteMs = 120;

  /// Quantas travadas guardar. As mais recentes importam mais.
  static const _capacidade = 60;

  static final Queue<Travada> _travadas = Queue<Travada>();

  /// As travadas registradas, da mais recente para a mais antiga.
  static List<Travada> get travadas => _travadas.toList().reversed.toList();

  static bool _ligado = false;

  /// A pilha do que esta acontecendo. E pilha porque as operacoes se
  /// aninham: gravar o projeto acontece dentro de "editar camada".
  static final List<String> _pilha = <String>[];

  /// Contexto do aplicativo no momento da travada. Quem sabe responder
  /// isso e outra camada (o motor 3D, o editor), entao ela se
  /// apresenta aqui em vez de este arquivo importar meio mundo.
  static String Function()? contextoAtual;

  /// Comeca a ouvir os quadros. Chamar uma vez, no inicio do app.
  static void comecar() {
    if (_ligado) return;
    _ligado = true;
    SchedulerBinding.instance.addTimingsCallback(_verQuadros);
  }

  /// Roda [corpo] com uma marca. Se um quadro travar enquanto ela esta
  /// na pilha, e ela que aparece no registro.
  static T marcando<T>(String nome, T Function() corpo) {
    _pilha.add(nome);
    try {
      return corpo();
    } finally {
      if (_pilha.isNotEmpty) _pilha.removeLast();
    }
  }

  /// Versao assincrona: cobre uma gravacao em disco, por exemplo.
  static Future<T> marcandoAsync<T>(
    String nome,
    Future<T> Function() corpo,
  ) async {
    _pilha.add(nome);
    try {
      return await corpo();
    } finally {
      _pilha.remove(nome);
    }
  }

  /// O que estava acontecendo, do mais especifico para o mais geral.
  static String get _oQueEstaAcontecendo =>
      _pilha.isEmpty ? 'nada marcado' : _pilha.reversed.join(' < ');

  static void _verQuadros(List<FrameTiming> quadros) {
    for (final q in quadros) {
      final total = q.totalSpan.inMilliseconds;
      if (total < limiteMs) continue;
      _registrar(
        Travada(
          quando: DateTime.now(),
          totalMs: total,
          construcaoMs: q.buildDuration.inMilliseconds,
          desenhoMs: q.rasterDuration.inMilliseconds,
          oQue: _oQueEstaAcontecendo,
          contexto: contextoAtual?.call() ?? '',
        ),
      );
    }
  }

  static void _registrar(Travada t) {
    _travadas.addLast(t);
    while (_travadas.length > _capacidade) {
      _travadas.removeFirst();
    }
  }

  static void limpar() => _travadas.clear();

  /// Tudo em texto, para colar numa mensagem.
  static String emTexto() {
    if (_travadas.isEmpty) {
      return 'Nenhuma travada acima de ${limiteMs}ms desde que o app abriu.';
    }
    final b = StringBuffer()
      ..writeln('TRAVADAS (quadro acima de ${limiteMs}ms)')
      ..writeln('${_travadas.length} registradas, da mais recente:')
      ..writeln();
    for (final t in travadas) {
      b.writeln(t.linha);
    }
    return b.toString();
  }

  /// O resumo que interessa: qual marca aparece mais, e somando quanto
  /// tempo. Uma travada de 2 s conta mais que dez de 130 ms.
  static List<({String oQue, int vezes, int somaMs})> porCausa() {
    final vezes = <String, int>{};
    final soma = <String, int>{};
    for (final t in _travadas) {
      vezes[t.oQue] = (vezes[t.oQue] ?? 0) + 1;
      soma[t.oQue] = (soma[t.oQue] ?? 0) + t.totalMs;
    }
    final saida = [
      for (final e in vezes.entries)
        (oQue: e.key, vezes: e.value, somaMs: soma[e.key] ?? 0),
    ]..sort((a, b) => b.somaMs.compareTo(a.somaMs));
    return saida;
  }
}
