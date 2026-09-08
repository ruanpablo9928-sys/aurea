import 'dart:convert';
import 'dart:io';

import 'package:aurea/src/features/editor/application/transcricao_em_andamento.dart';
import 'package:aurea/src/features/editor/application/transcription_service.dart';
import 'package:aurea/src/features/editor/domain/caption.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

/// A TRANSCRICAO NA NUVEM, do lado do app, contra um servidor de mentira.
///
/// O que se prova aqui: so o AUDIO sobe (e com a conta), o que volta
/// vira falas no modo pedido, o audio extraido e apagado, e cada jeito
/// de dar errado vira o erro certo — sem internet, sem conta, nuvem
/// fora, cota — para a folha oferecer "tentar de novo" ou "usar o
/// aparelho" em vez de trocar de motor sozinha.
typedef _Pedido = ({
  String caminho,
  String? autorizacao,
  String? tipo,
  String? duracao,
  String? idioma,
  int bytes,
});

class _Servidor {
  late HttpServer _s;
  int status = 200;
  Map<String, Object?> corpo = const {};
  final pedidos = <_Pedido>[];

  Future<void> abrir() async {
    _s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _s.listen((req) async {
      final bytes = await req.fold<List<int>>([], (a, b) => a..addAll(b));
      pedidos.add((
        caminho: req.uri.path,
        autorizacao: req.headers.value('authorization'),
        tipo: req.headers.contentType?.mimeType,
        duracao: req.headers.value('x-duracao'),
        idioma: req.headers.value('x-idioma'),
        bytes: bytes.length,
      ));
      req.response.statusCode = status;
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode(corpo));
      await req.response.close();
    });
  }

  String get endereco => 'http://127.0.0.1:${_s.port}';

  Future<void> fechar() => _s.close(force: true);
}

Map<String, Object?> _respostaBoa() => {
  'texto': 'Olá mundo',
  'idioma': 'pt',
  'duracao': 2.5,
  'modelo': 'whisper-large-v3-turbo',
  'segmentos': [
    {'inicio': 0, 'fim': 2.5, 'texto': 'Olá mundo'},
  ],
  'palavras': [
    {'inicio': 0, 'fim': 1, 'texto': 'Olá'},
    {'inicio': 1, 'fim': 2.5, 'texto': 'mundo'},
  ],
};

/// Quarenta e oito hexadecimais, como um codigo de acesso de verdade.
const _codigoDeTeste = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

class _Bancada {
  _Bancada({
    required this.servidor,
    required this.pasta,
    this.modo = ModoDeTranscricao.nuvem,
    this.internet = true,
    this.codigo = _codigoDeTeste,
    String? endereco,
  }) {
    servico = TranscriptionService(
      endereco: endereco ?? servidor.endereco,
      modoAtual: () => modo,
      codigoDaConta: () => codigo,
      temInternet: () async => internet,
      extrairAudio: (path, onStatus) async {
        final f = File('${pasta.path}/audio_${extraidos.length}.m4a');
        await f.writeAsBytes(List.filled(4000, 7));
        extraidos.add(f.path);
        return f.path;
      },
      transcreverNoAparelho:
          (
            path, {
            required WhisperModel model,
            required String language,
            required CaptionMode mode,
            void Function(String)? onStatus,
          }) async {
            noAparelho++;
            return [
              Cue(
                start: Duration.zero,
                end: const Duration(seconds: 1),
                text: 'local',
              ),
            ];
          },
    );
  }

  final _Servidor servidor;
  final Directory pasta;
  ModoDeTranscricao modo;
  bool internet;
  String? codigo;
  final extraidos = <String>[];
  var noAparelho = 0;
  late final TranscriptionService servico;
}

void main() {
  late _Servidor servidor;
  late Directory pasta;

  setUp(() async {
    servidor = _Servidor();
    await servidor.abrir();
    servidor.corpo = _respostaBoa();
    pasta = Directory.systemTemp.createTempSync('aurea_transcricao');
  });

  tearDown(() async {
    await servidor.fechar();
    pasta.deleteSync(recursive: true);
  });

  test('na nuvem: so o audio sobe, com a conta; vira falas; o audio some', () async {
    final b = _Bancada(servidor: servidor, pasta: pasta);
    final status = <String>[];
    final falas = await b.servico.transcribeMedia(
      '/video.mp4',
      onStatus: status.add,
    );
    expect(falas, hasLength(1));
    expect(falas.single.text, 'Olá mundo');
    expect(falas.single.start, Duration.zero);
    expect(falas.single.end, const Duration(milliseconds: 2500));

    final pedido = servidor.pedidos.single;
    expect(pedido.caminho, '/transcricao');
    expect(pedido.autorizacao, 'Bearer $_codigoDeTeste');
    expect(pedido.tipo, 'audio/mp4', reason: 'sobe o audio, nao o video');
    expect(pedido.bytes, 4000, reason: 'o arquivo extraido, inteiro');
    expect(pedido.idioma, 'pt');
    expect(double.parse(pedido.duracao!), greaterThan(0));
    expect(b.noAparelho, 0);
    expect(
      File(b.extraidos.single).existsSync(),
      isFalse,
      reason: 'o audio extraido e apagado depois de subir',
    );
    expect(status.any((s) => s.contains('Enviando')), isTrue);
    expect(status.last, contains('nuvem'));
  });

  test('palavra usa as palavras; curtas agrupa; frases usa os segmentos', () async {
    final b = _Bancada(servidor: servidor, pasta: pasta);
    final palavras = await b.servico.transcribeMedia(
      '/v.mp4',
      mode: CaptionMode.palavra,
    );
    expect(palavras.map((c) => c.text), ['Olá', 'mundo']);
    expect(palavras.first.end, const Duration(seconds: 1));

    final curtas = await b.servico.transcribeMedia(
      '/v.mp4',
      mode: CaptionMode.curtas,
    );
    expect(curtas.map((c) => c.text).join(' '), contains('Olá'));
    expect(curtas.map((c) => c.text).join(' '), contains('mundo'));

    final frases = await b.servico.transcribeMedia(
      '/v.mp4',
      mode: CaptionMode.frases,
    );
    expect(frases.single.text, 'Olá mundo');
  });

  test('automatico sem internet cai para o aparelho, sem tocar na rede', () async {
    final b = _Bancada(
      servidor: servidor,
      pasta: pasta,
      modo: ModoDeTranscricao.auto,
      internet: false,
    );
    final status = <String>[];
    final falas = await b.servico.transcribeMedia('/v.mp4', onStatus: status.add);
    expect(falas.single.text, 'local');
    expect(b.noAparelho, 1);
    expect(servidor.pedidos, isEmpty);
    expect(status.first, contains('Sem internet'));
  });

  test('nuvem sem internet avisa — e nao troca de motor sozinha', () async {
    final b = _Bancada(
      servidor: servidor,
      pasta: pasta,
      modo: ModoDeTranscricao.nuvem,
      internet: false,
    );
    await expectLater(
      b.servico.transcribeMedia('/v.mp4'),
      throwsA(isA<TranscricaoSemInternet>()),
    );
    expect(b.noAparelho, 0);
    expect(servidor.pedidos, isEmpty);
  });

  test('sem conta da comunidade a nuvem pede a conta', () async {
    for (final modo in [ModoDeTranscricao.nuvem, ModoDeTranscricao.auto]) {
      final b = _Bancada(servidor: servidor, pasta: pasta, modo: modo, codigo: null);
      await expectLater(
        b.servico.transcribeMedia('/v.mp4'),
        throwsA(isA<TranscricaoPrecisaDeConta>()),
      );
    }
    expect(servidor.pedidos, isEmpty);
  });

  test('o aparelho, quando escolhido, nunca sobe nada', () async {
    final b = _Bancada(
      servidor: servidor,
      pasta: pasta,
      modo: ModoDeTranscricao.local,
    );
    final falas = await b.servico.transcribeMedia('/v.mp4');
    expect(falas.single.text, 'local');
    expect(servidor.pedidos, isEmpty);
    expect(b.extraidos, isEmpty, reason: 'nem extrai o m4a');
  });

  test('nuvem fora (502) e cota (429) viram "indisponivel", com o motivo', () async {
    final b = _Bancada(servidor: servidor, pasta: pasta);
    servidor.status = 502;
    servidor.corpo = {'erro': 'A transcricao na nuvem esta indisponivel.'};
    await expectLater(
      b.servico.transcribeMedia('/v.mp4'),
      throwsA(
        isA<TranscricaoNaNuvemIndisponivel>()
            .having((e) => e.cota, 'cota', isFalse)
            .having((e) => e.mensagem, 'mensagem', contains('indisponivel')),
      ),
    );

    servidor.status = 429;
    servidor.corpo = {'erro': 'Sua cota de hoje acabou.', 'tenteEm': 3600};
    await expectLater(
      b.servico.transcribeMedia('/v.mp4'),
      throwsA(
        isA<TranscricaoNaNuvemIndisponivel>()
            .having((e) => e.cota, 'cota', isTrue)
            .having((e) => e.tenteEm, 'tenteEm', const Duration(hours: 1)),
      ),
    );

    // Um 401 e a conta que nao vale mais no servidor.
    servidor.status = 401;
    servidor.corpo = {'erro': 'Crie sua conta antes de transcrever.'};
    await expectLater(
      b.servico.transcribeMedia('/v.mp4'),
      throwsA(isA<TranscricaoPrecisaDeConta>()),
    );
    expect(b.noAparelho, 0, reason: 'nada disso troca de motor sozinho');
    // E o audio extraido nao fica para tras em nenhum dos casos.
    expect(b.extraidos.where((p) => File(p).existsSync()), isEmpty);
  });

  test('servidor que nao responde vira "indisponivel" (e nao um crash)', () async {
    final b = _Bancada(
      servidor: servidor,
      pasta: pasta,
      endereco: 'http://127.0.0.1:1',
    );
    await expectLater(
      b.servico.transcribeMedia('/v.mp4'),
      throwsA(isA<TranscricaoNaNuvemIndisponivel>()),
    );
  });

  test('a repeticao em laco (alucinacao no silencio) e descartada', () {
    Cue oi(int s) => Cue(
      start: Duration(seconds: s),
      end: Duration(seconds: s + 1),
      text: 'oi',
    );
    final bruta = TranscricaoBruta(
      texto: 'oi oi oi oi',
      duracao: 4,
      segmentos: [oi(0), oi(1), oi(2), oi(3)],
      palavras: const [],
    );
    expect(
      TranscriptionService.cuesDe(bruta, CaptionMode.frases),
      hasLength(2),
    );
    // Sem palavras, o modo palavra usa os segmentos.
    expect(
      TranscriptionService.cuesDe(bruta, CaptionMode.palavra),
      hasLength(2),
    );
  });

  test('uma palavra sem duracao ganha 80 ms; texto vazio some', () {
    final bruta = TranscricaoBruta.deJson({
      'texto': 'a',
      'duracao': 1,
      'segmentos': [],
      'palavras': [
        {'inicio': 0.5, 'fim': 0.5, 'texto': 'a'},
        {'inicio': 0.6, 'fim': 0.9, 'texto': '   '},
      ],
    });
    expect(bruta.palavras, hasLength(1));
    expect(bruta.palavras.single.end - bruta.palavras.single.start,
        const Duration(milliseconds: 80));
  });

  test('o trabalho em andamento: rodando, pronta, e cada falha com a sua saida', () async {
    final job = TranscricaoEmAndamento();
    final vistos = <String>[];
    job.estado.addListener(() => vistos.add(job.estado.value.runtimeType.toString()));

    final entrou = await job.rodar(
      () async {
        job.status('Enviando áudio (50%)...');
        return [
          Cue(start: Duration.zero, end: const Duration(seconds: 1), text: 'x'),
        ];
      },
      aoTerminar: (falas) => null,
    );
    expect(entrou, isTrue);
    expect(job.estado.value, isA<TranscricaoPronta>());
    expect(vistos.first, 'TranscricaoRodando');

    expect(
      await job.rodar(
        () async => throw const TranscricaoNaNuvemIndisponivel('fora'),
        aoTerminar: (_) => null,
      ),
      isFalse,
    );
    final falha = job.estado.value as TranscricaoFalhou;
    expect(falha.nuvemIndisponivel, isTrue);
    expect(falha.ofereceLocal, isTrue);
    expect(falha.mensagem, 'fora');

    await job.rodar(
      () async => throw const TranscricaoSemInternet(),
      aoTerminar: (_) => null,
    );
    expect((job.estado.value as TranscricaoFalhou).semInternet, isTrue);

    await job.rodar(
      () async => throw const TranscricaoPrecisaDeConta(),
      aoTerminar: (_) => null,
    );
    expect((job.estado.value as TranscricaoFalhou).precisaDeConta, isTrue);

    // Nenhuma fala: e uma falha com aviso, sem oferecer o aparelho.
    await job.rodar(() async => [], aoTerminar: (_) => 'Nenhuma fala.');
    final vazia = job.estado.value as TranscricaoFalhou;
    expect(vazia.ofereceLocal, isFalse);
    expect(vazia.mensagem, 'Nenhuma fala.');
  });
}
