// QUANTO CUSTA O AMBIENTE — a pergunta que o registro do aparelho abriu.
//
// O registro do build 68, no iPhone 13, apontou `cena 3D: sincronizar >
// ambiente` como 92% do quadro travado: 20.234 ms em 122 chamadas, com
// pico de 3.445 ms. Antes de mexer, era preciso saber se o custo era o
// CALCULO da radiancia ou uma chamada nativa.
//
// Esta bancada responde a primeira metade: o calculo e barato. Se ele
// engordar, este teste falha e a conta do aparelho muda de dono.
import 'dart:isolate';

import 'package:aurea/src/features/editor/domain/element3d.dart';
import 'package:aurea/src/features/editor/domain/environment_radiance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gerar a radiancia de um ambiente e barato', () {
    for (final kind in EnvironmentKind.values) {
      final r = Stopwatch()..start();
      final px = environmentRadiance(kind);
      r.stop();
      expect(px.length, 512 * 256 * 4);
      // Medido: 13-26 ms num desktop. Duas a tres vezes isso num iPhone
      // — longe dos 3.445 ms que o aparelho registrou.
      expect(
        r.elapsedMilliseconds,
        lessThan(200),
        reason:
            '${kind.name} levou ${r.elapsedMilliseconds} ms: se o calculo '
            'ficou caro, o teto do quadro tem de ser revisto',
      );
    }
  });

  test('abrir o isolate nao segura o fio da interface', () async {
    final r = Stopwatch()..start();
    final futuro = Isolate.run(
      () => environmentRadiance(EnvironmentKind.estudio),
    );
    final sincrono = r.elapsedMilliseconds;
    await futuro;
    // A parte que importa e a SINCRONA: e ela que roda no fio que recebe
    // o toque. Medida em 2 ms aqui.
    expect(
      sincrono,
      lessThan(200),
      reason:
          'abrir o isolate custou $sincrono ms no fio principal; se isso '
          'cresce, o calculo em segundo plano deixa de compensar',
    );
  });
}
