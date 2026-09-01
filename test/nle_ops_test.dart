import 'package:flutter_test/flutter_test.dart';

import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/nle_ops.dart';

Duration _s(num v) => Duration(milliseconds: (v * 1000).round());

TextLayer _clip(String nome, num inicio, num dur) => TextLayer(
      name: nome,
      startTime: _s(inicio),
      duration: _s(dur),
      text: nome,
    );

/// Devolve (nome, inicio, fim) em segundos, ordenado por inicio.
List<(String, double, double)> _linha(List<Layer> layers) {
  final out = [
    for (final l in layers)
      (
        l.name,
        l.startTime.inMilliseconds / 1000,
        l.endTime.inMilliseconds / 1000
      ),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  return out;
}

void main() {
  group('Exclusao com arrasto', () {
    test('tira o trecho e puxa o que vinha depois', () {
      final t = [_clip('A', 0, 2), _clip('B', 2, 3), _clip('C', 5, 1)];
      final r = rippleDelete(t, t[1].id);
      expect(_linha(r), [
        ('A', 0.0, 2.0),
        ('C', 2.0, 3.0), // andou 3 s para tras
      ]);
    });

    test('o que vem ANTES nao se mexe', () {
      final t = [_clip('A', 0, 2), _clip('B', 4, 1)];
      final r = rippleDelete(t, t[1].id);
      expect(_linha(r), [('A', 0.0, 2.0)]);
    });

    test('id que nao existe nao muda nada', () {
      final t = [_clip('A', 0, 2)];
      expect(rippleDelete(t, 'nada'), same(t));
    });
  });

  group('Fechar buracos', () {
    test('encosta tudo, sem mudar ordem nem duracao', () {
      final t = [_clip('A', 0, 2), _clip('B', 5, 1), _clip('C', 9, 3)];
      final r = closeGaps(t);
      expect(_linha(r), [
        ('A', 0.0, 2.0),
        ('B', 2.0, 3.0),
        ('C', 3.0, 6.0),
      ]);
    });

    test('depois de fechar nao sobra buraco nenhum', () {
      final t = [_clip('A', 1, 2), _clip('B', 6, 1), _clip('C', 10, 2)];
      expect(gapsIn(t).length, 3); // inclui o vazio do inicio
      expect(gapsIn(closeGaps(t)), isEmpty);
    });

    test('fecha so do ponto pedido para frente', () {
      final t = [_clip('A', 0, 2), _clip('B', 6, 1), _clip('C', 10, 1)];
      final r = closeGaps(t, from: _s(6));
      expect(_linha(r), [
        ('A', 0.0, 2.0), // intacta: acaba antes do ponto
        ('B', 6.0, 7.0),
        ('C', 7.0, 8.0),
      ]);
    });

    test('linha ja encostada nao muda', () {
      final t = [_clip('A', 0, 2), _clip('B', 2, 2)];
      expect(_linha(closeGaps(t)), _linha(t));
    });
  });

  group('Inserir', () {
    test('empurra para frente o que comeca dali', () {
      final t = [_clip('A', 0, 2), _clip('B', 2, 2)];
      final r = insertAt(t, _clip('NOVO', 0, 1), _s(2));
      expect(_linha(r.layers), [
        ('A', 0.0, 2.0),
        ('NOVO', 2.0, 3.0),
        ('B', 3.0, 5.0),
      ]);
    });

    test('divide quem estava atravessado no ponto', () {
      final t = [_clip('A', 0, 4)];
      final r = insertAt(t, _clip('NOVO', 0, 1), _s(1));
      expect(_linha(r.layers), [
        ('A', 0.0, 1.0),
        ('NOVO', 1.0, 2.0),
        ('A', 2.0, 5.0), // o resto de A, depois do inserido
      ]);
    });

    test('a linha do tempo ESTICA pelo tamanho do inserido', () {
      final t = [_clip('A', 0, 2), _clip('B', 2, 2)];
      final antes = t.map((l) => l.endTime).reduce((a, b) => a > b ? a : b);
      final r = insertAt(t, _clip('N', 0, 3), _s(1));
      final depois =
          r.layers.map((l) => l.endTime).reduce((a, b) => a > b ? a : b);
      expect(depois - antes, _s(3));
    });

    test('o inserido volta com o inicio ja no lugar', () {
      final r = insertAt([], _clip('N', 99, 1), _s(4));
      expect(r.inserted.startTime, _s(4));
    });
  });

  group('Sobrescrever', () {
    test('apaga o que estava embaixo sem esticar a linha', () {
      final t = [_clip('A', 0, 2), _clip('B', 2, 2), _clip('C', 4, 2)];
      final r = overwriteAt(t, _clip('N', 0, 2), _s(2));
      expect(_linha(r.layers), [
        ('A', 0.0, 2.0),
        ('N', 2.0, 4.0), // B sumiu inteira
        ('C', 4.0, 6.0), // C nao andou
      ]);
    });

    test('sobra a ponta de quem so foi coberta em parte', () {
      final t = [_clip('A', 0, 4)];
      final r = overwriteAt(t, _clip('N', 0, 2), _s(3));
      expect(_linha(r.layers), [
        ('A', 0.0, 3.0),
        ('N', 3.0, 5.0),
      ]);
    });

    test('caindo no meio, sobram as DUAS pontas', () {
      final t = [_clip('A', 0, 6)];
      final r = overwriteAt(t, _clip('N', 0, 2), _s(2));
      expect(_linha(r.layers), [
        ('A', 0.0, 2.0),
        ('N', 2.0, 4.0),
        ('A', 4.0, 6.0),
      ]);
    });

    test('quem esta fora do trecho fica intacto', () {
      final t = [_clip('A', 0, 1), _clip('B', 8, 1)];
      final r = overwriteAt(t, _clip('N', 0, 2), _s(3));
      expect(_linha(r.layers), [
        ('A', 0.0, 1.0),
        ('N', 3.0, 5.0),
        ('B', 8.0, 9.0),
      ]);
    });
  });

  group('Levantar e extrair', () {
    test('levantar tira o trecho e DEIXA o buraco', () {
      final t = [_clip('A', 0, 6)];
      final r = liftRange(t, _s(2), _s(4));
      expect(_linha(r), [
        ('A', 0.0, 2.0),
        ('A', 4.0, 6.0),
      ]);
      expect(gapsIn(r).length, 1);
    });

    test('extrair tira o trecho E fecha o buraco', () {
      final t = [_clip('A', 0, 2), _clip('B', 2, 2), _clip('C', 4, 2)];
      final r = extractRange(t, _s(2), _s(4));
      expect(_linha(r), [
        ('A', 0.0, 2.0),
        ('C', 2.0, 4.0), // andou 2 s para tras
      ]);
    });

    test('faixa invertida ou vazia nao faz nada', () {
      final t = [_clip('A', 0, 4)];
      expect(liftRange(t, _s(3), _s(1)), same(t));
      expect(extractRange(t, _s(2), _s(2)), same(t));
    });

    test('so as camadas escolhidas sao afetadas', () {
      final t = [_clip('A', 0, 6), _clip('B', 0, 6)];
      final r = liftRange(t, _s(2), _s(4), only: {t[0].id});
      final b = r.where((l) => l.name == 'B').toList();
      expect(b.length, 1);
      expect(b.first.duration, _s(6));
    });
  });

  group('Buracos', () {
    test('acha o vazio do inicio e o do meio', () {
      final t = [_clip('A', 1, 1), _clip('B', 5, 1)];
      final g = gapsIn(t);
      expect(g.length, 2);
      expect(g[0].$1, Duration.zero);
      expect(g[0].$2, _s(1));
      expect(g[1].$1, _s(2));
      expect(g[1].$2, _s(5));
    });

    test('camadas sobrepostas nao inventam buraco', () {
      final t = [_clip('A', 0, 5), _clip('B', 2, 5)];
      expect(gapsIn(t), isEmpty);
    });

    test('linha vazia nao tem buraco', () {
      expect(gapsIn(const []), isEmpty);
    });
  });

  group('Ponto de entrada na midia', () {
    AudioLayer fala(num inicio, num dur, {Duration? off}) => AudioLayer(
          name: 'fala',
          startTime: _s(inicio),
          duration: _s(dur),
          sourcePath: 'fala.wav',
          sourceOffset: off ?? Duration.zero,
        );

    // Tirar um pedaco do MEIO de uma locucao: o rabo tem que continuar
    // de onde parou. Sem avancar a fonte, ele repetia o audio que ja
    // tinha tocado — a frase saia gaguejando.
    test('o rabo do corte continua de onde parou', () {
      final r = liftRange([fala(0, 10)], _s(3), _s(5));
      final rabo = r.whereType<AudioLayer>().reduce(
          (a, b) => a.startTime > b.startTime ? a : b);
      expect(rabo.startTime, _s(5));
      expect(rabo.sourceOffset, _s(5));
    });

    test('a cabeca do corte nao mexe na fonte', () {
      final r = liftRange([fala(0, 10)], _s(3), _s(5));
      final cabeca = r.whereType<AudioLayer>().reduce(
          (a, b) => a.startTime < b.startTime ? a : b);
      expect(cabeca.sourceOffset, Duration.zero);
      expect(cabeca.duration, _s(3));
    });

    test('soma ao ponto de entrada que ja existia', () {
      final r = liftRange([fala(0, 10, off: _s(4))], _s(2), _s(6));
      final rabo = r.whereType<AudioLayer>().reduce(
          (a, b) => a.startTime > b.startTime ? a : b);
      expect(rabo.sourceOffset, _s(10));
    });

    test('clipe que so comeca dentro do trecho tambem avanca', () {
      final r = liftRange([fala(2, 8)], _s(0), _s(5));
      final unico = r.whereType<AudioLayer>().single;
      expect(unico.startTime, _s(5));
      expect(unico.sourceOffset, _s(3));
    });

    test('video mantem o mesmo comportamento', () {
      final v = VideoLayer(
        name: 'tomada',
        startTime: Duration.zero,
        duration: _s(10),
        sourcePath: 'a.mp4',
        sourceOffset: _s(1),
      );
      final r = extractRange([v], _s(4), _s(6));
      final rabo = r.whereType<VideoLayer>().reduce(
          (a, b) => a.sourceOffset > b.sourceOffset ? a : b);
      expect(rabo.sourceOffset, _s(7));
      // Extrair fecha o buraco: o rabo encosta na cabeca.
      expect(rabo.startTime, _s(4));
    });

    test('clipe fora do trecho nao e tocado', () {
      final r = liftRange([fala(8, 2, off: _s(3))], _s(0), _s(5));
      expect(r.whereType<AudioLayer>().single.sourceOffset, _s(3));
    });
  });
}
