import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A CHAVE DA GROQ NAO ESTA NO APP. Nem no codigo, nem em asset, nem em
/// configuracao, nem no servidor versionado: so como secret do Worker.
///
/// Um APK e um zip, e `grep gsk_` leva um minuto. Este teste faz esse
/// grep antes de qualquer build — no repositorio inteiro que vira app —
/// e, quando AUREA_PACOTE aponta para um APK, AAB ou IPA, dentro do
/// pacote gerado tambem (inclusive nos binarios nativos).
void main() {
  // O formato de uma chave da Groq: gsk_ e dezenas de letras e numeros.
  final chave = RegExp(r'gsk_[A-Za-z0-9]{20,}');
  final atribuicao = RegExp(r'''GROQ_API_KEY\s*[:=]\s*["']?\s*gsk_''');
  const ignoraPastas = {
    'node_modules',
    '.dart_tool',
    'build',
    '.cxx',
    '.git',
    'tmp',
    'output',
  };
  const ignoraExtensoes = {
    'png', 'jpg', 'jpeg', 'webp', 'gif', 'glb', 'gltf', 'fbx', 'obj', 'bin',
    'ttf', 'otf', 'mp4', 'mp3', 'wav', 'm4a', 'jar', 'zip', 'aar', 'so',
  };

  Iterable<File> arquivosDe(String raiz) sync* {
    final tipo = FileSystemEntity.typeSync(raiz);
    if (tipo == FileSystemEntityType.file) {
      yield File(raiz);
    } else if (tipo == FileSystemEntityType.directory) {
      for (final e in Directory(raiz).listSync(recursive: true, followLinks: false)) {
        if (e is! File) continue;
        final partes = e.path.split(RegExp(r'[\\/]'));
        if (partes.any(ignoraPastas.contains)) continue;
        if (ignoraExtensoes.contains(partes.last.split('.').last.toLowerCase())) {
          continue;
        }
        yield e;
      }
    }
  }

  test('nenhum arquivo do app ou do servidor carrega uma chave da Groq', () {
    final achados = <String>[];
    for (final raiz in const [
      'lib',
      'android/app',
      'android/gradle.properties',
      'android/local.properties',
      'ios/Runner',
      'ios/Flutter',
      'assets',
      'servidor',
      'test',
      'pubspec.yaml',
      '.env',
      'docs',
    ]) {
      for (final f in arquivosDe(raiz)) {
        if (f.lengthSync() > 8 * 1024 * 1024) continue;
        String texto;
        try {
          texto = f.readAsStringSync();
        } catch (_) {
          continue;
        }
        if (chave.hasMatch(texto) || atribuicao.hasMatch(texto)) {
          achados.add(f.path);
        }
      }
    }
    expect(achados, isEmpty, reason: 'chave da Groq em: $achados');
  });

  test('o pacote gerado nao contem a chave (AUREA_PACOTE=caminho do APK/AAB/IPA)', () async {
    final pacote = Platform.environment['AUREA_PACOTE'];
    if (pacote == null || !File(pacote).existsSync()) {
      // Sem pacote apontado, nao ha o que abrir: o teste do repositorio
      // acima e o que roda sempre.
      return;
    }
    final pasta = Directory.systemTemp.createTempSync('aurea_pacote');
    addTearDown(() => pasta.deleteSync(recursive: true));
    // APK, AAB e IPA sao zips: o tar do Windows e do macOS abre os tres.
    final r = await Process.run('tar', ['-xf', pacote, '-C', pasta.path]);
    expect(r.exitCode, 0, reason: 'nao consegui abrir o pacote: ${r.stderr}');

    final agulha = 'gsk_'.codeUnits;
    final achados = <String>[];
    for (final e in pasta.listSync(recursive: true, followLinks: false)) {
      if (e is! File) continue;
      final bytes = e.readAsBytesSync();
      // Procura a sequencia ASCII em qualquer arquivo, binario incluso.
      for (var i = 0; i + agulha.length + 20 <= bytes.length; i++) {
        if (bytes[i] != agulha[0]) continue;
        var bate = true;
        for (var j = 1; j < agulha.length; j++) {
          if (bytes[i + j] != agulha[j]) {
            bate = false;
            break;
          }
        }
        if (!bate) continue;
        // gsk_ seguido de 20 letras/numeros: e uma chave, nao coincidencia.
        var k = 0;
        while (k < 20) {
          final c = bytes[i + agulha.length + k];
          final alfanumerico =
              (c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122);
          if (!alfanumerico) break;
          k++;
        }
        if (k == 20) {
          achados.add(e.path);
          break;
        }
      }
    }
    expect(achados, isEmpty, reason: 'chave da Groq dentro do pacote: $achados');
  });
}
