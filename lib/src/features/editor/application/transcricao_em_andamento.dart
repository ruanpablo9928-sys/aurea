import 'package:flutter/foundation.dart';

import '../domain/caption.dart';
import 'transcription_service.dart';

/// O ESTADO DE UMA TRANSCRICAO, para a folha de Legendas ler.
sealed class EstadoDaTranscricao {
  const EstadoDaTranscricao();
}

class TranscricaoParada extends EstadoDaTranscricao {
  const TranscricaoParada();
}

class TranscricaoRodando extends EstadoDaTranscricao {
  const TranscricaoRodando(this.status);
  final String status;
}

class TranscricaoFalhou extends EstadoDaTranscricao {
  const TranscricaoFalhou(
    this.mensagem, {
    this.semInternet = false,
    this.nuvemIndisponivel = false,
    this.precisaDeConta = false,
  });

  final String mensagem;
  final bool semInternet;
  final bool nuvemIndisponivel;
  final bool precisaDeConta;

  /// Vale a pena oferecer o Whisper do aparelho como saida.
  bool get ofereceLocal => semInternet || nuvemIndisponivel || precisaDeConta;
}

class TranscricaoPronta extends EstadoDaTranscricao {
  const TranscricaoPronta(this.falas);
  final int falas;
}

/// A TRANSCRICAO QUE ESTA RODANDO — uma por vez, fora de qualquer tela.
///
/// A folha de Legendas pede e mostra o andamento, mas nao e dona do
/// trabalho: quem fecha a folha no meio ve a camada de legenda aparecer
/// na timeline quando ficar pronta, e quem reabre ve o andamento (ou o
/// erro) de onde parou. E o que deixa a transcricao ser assincrona de
/// verdade — a timeline e o palco continuam respondendo enquanto o audio
/// sobe e a nuvem trabalha.
class TranscricaoEmAndamento {
  TranscricaoEmAndamento();

  static final instance = TranscricaoEmAndamento();

  final ValueNotifier<EstadoDaTranscricao> estado = ValueNotifier(
    const TranscricaoParada(),
  );

  bool get rodando => estado.value is TranscricaoRodando;

  /// Para o servico contar o andamento ("Enviando audio (40%)...").
  void status(String s) {
    if (rodando) estado.value = TranscricaoRodando(s);
  }

  void falhar(String mensagem) => estado.value = TranscricaoFalhou(mensagem);

  void limpar() => estado.value = const TranscricaoParada();

  /// Roda [transcrever] e, quando termina, entrega as falas a
  /// [aoTerminar] — mesmo que quem pediu ja tenha ido embora.
  /// [aoTerminar] devolve um aviso quando nao ha o que fazer com as falas
  /// ("nenhuma fala"), ou null quando deu certo.
  ///
  /// Devolve true quando as legendas entraram no projeto.
  Future<bool> rodar(
    Future<List<Cue>> Function() transcrever, {
    required String? Function(List<Cue> falas) aoTerminar,
  }) async {
    if (rodando) return false;
    estado.value = const TranscricaoRodando('Preparando...');
    try {
      final falas = await transcrever();
      final aviso = aoTerminar(falas);
      estado.value = aviso == null
          ? TranscricaoPronta(falas.length)
          : TranscricaoFalhou(aviso);
      return aviso == null;
    } on TranscricaoSemInternet catch (e) {
      estado.value = TranscricaoFalhou(e.toString(), semInternet: true);
    } on TranscricaoPrecisaDeConta catch (e) {
      estado.value = TranscricaoFalhou(e.toString(), precisaDeConta: true);
    } on TranscricaoNaNuvemIndisponivel catch (e) {
      estado.value = TranscricaoFalhou(e.mensagem, nuvemIndisponivel: true);
    } catch (e) {
      estado.value = TranscricaoFalhou('Erro ao transcrever: $e');
    }
    return false;
  }
}
