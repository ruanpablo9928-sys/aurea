// A VERSAO QUE O APP MOSTRA TEM DE SER A VERSAO QUE O APP E.
//
// A tela Sobre trazia `1.2.0 (35)` escrito a mao enquanto o pubspec ja
// estava em 1.6.6+67 — trinta e duas entregas de diferenca. Isso nao e
// cosmetico: quando chega um registro de travada, a primeira pergunta e
// "de qual build?", e a unica tela que devia responder respondia errado.
// Uma rodada inteira de diagnostico se perdeu por causa disso.
//
// Este teste faz esquecer de atualizar virar erro, e nao surpresa.
import 'dart:io';

import 'package:aurea/src/core/utils/versao_do_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('versaoDoApp e buildDoApp batem com o pubspec.yaml', () {
    final linha = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    final valor = linha.split(':')[1].trim();
    expect(
      valor,
      '$versaoDoApp+$buildDoApp',
      reason:
          'o pubspec diz "$valor" e o app se apresenta como '
          '"$versaoDoApp+$buildDoApp". Atualize lib/src/core/utils/'
          'versao_do_app.dart junto com o pubspec',
    );
  });

  test('a versao completa e legivel para quem le o registro', () {
    expect(versaoCompleta, '$versaoDoApp ($buildDoApp)');
  });
}
