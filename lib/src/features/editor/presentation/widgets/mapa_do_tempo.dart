import 'package:flutter_riverpod/flutter_riverpod.dart';

/// O MAPA ENTRE TEMPO E PIXEL — e a peca que decide como a linha do
/// tempo se comporta.
///
/// A versao anterior espremia a composicao INTEIRA na largura da tela:
/// `x = largura * t / duracao`. Parece simples, e e o erro que faz um
/// editor de celular ficar inutil no primeiro projeto de verdade:
///
///   - num projeto de tres minutos, um clipe de dois segundos vira um
///     risco de quatro pixels — invisivel, e impossivel de pegar;
///   - a mesma camada muda de tamanho na tela so porque OUTRA camada
///     esticou a duracao do projeto;
///   - nao ha como aproximar para trabalhar num trecho.
///
/// O modelo daqui e o do Alight Motion, medido quadro a quadro numa
/// gravacao do editor real (`docs/linha-do-tempo-alight.md`):
///
///   - a ESCALA e constante e vive em [pxPorSegundo]. Um segundo ocupa
///     sempre o mesmo tanto de tela, seja qual for a duracao;
///   - o CABECOTE fica preso no meio da largura e nao anda. Quem anda e
///     o conteudo, que desliza por baixo dele;
///   - arrastar o conteudo para o lado E navegar no tempo.
///
/// Todo mundo que desenha ou toca na linha do tempo passa por aqui: os
/// dois modos, a regua e as trilhas. Ter uma conta so e o que garante
/// que o cabecote da regua cai exatamente sobre o keyframe da trilha.
class MapaDoTempo {
  const MapaDoTempo({
    required this.largura,
    required this.pxPorSegundo,
    required this.tempo,
  });

  /// A largura util em pixels.
  final double largura;

  /// A escala. Um segundo de composicao ocupa este tanto de pixels.
  final double pxPorSegundo;

  /// Onde o cabecote esta. E ele que define o trecho visivel: o mapa
  /// nao guarda rolagem propria, porque duas fontes de verdade para
  /// "onde estamos" sempre acabam discordando.
  final Duration tempo;

  /// O CABECOTE FICA NO MEIO. Medido na gravacao: 287 px de 576, ou
  /// seja, o centro exato da largura da tela.
  ///
  /// No meio, e nao na esquerda, porque editar e olhar para os dois
  /// lados do instante atual — o que ja passou explica o que vem, e o
  /// que vem e o que se esta ajustando.
  static const fracaoDoCabecote = .5;

  double get ancora => largura * fracaoDoCabecote;

  /// Onde este instante cai na tela. Pode dar negativo ou passar da
  /// largura: quem desenha recorta.
  double xDe(Duration t) =>
      ancora + (t - tempo).inMicroseconds / 1000000 * pxPorSegundo;

  /// O instante sob este pixel.
  Duration tempoEm(double x) =>
      tempo +
      Duration(
        microseconds: ((x - ancora) / pxPorSegundo * 1000000).round(),
      );

  /// Quantos pixels uma duracao ocupa.
  double larguraDe(Duration d) =>
      d.inMicroseconds / 1000000 * pxPorSegundo;

  /// Quanto tempo um deslocamento em pixels representa. Negativo anda
  /// para tras — arrastar o conteudo para a direita volta no tempo.
  Duration tempoDe(double px) =>
      Duration(microseconds: (px / pxPorSegundo * 1000000).round());

  Duration get inicioVisivel => tempoEm(0);
  Duration get fimVisivel => tempoEm(largura);

  /// A ESCALA QUE FAZ A COMPOSICAO INTEIRA CABER.
  ///
  /// Com o cabecote no meio, a composicao aparece por inteiro quando o
  /// cabecote esta no meio dela — que e onde a conta abaixo mira. E o
  /// ponto de partida de todo projeto e o destino do botao "enquadrar".
  static double zoomQueCabe(double largura, Duration duracao) {
    final segundos = duracao.inMicroseconds / 1000000;
    if (largura <= 0 || segundos <= 0) return zoomPadrao;
    return prender(largura / segundos);
  }

  /// O chao e o teto do zoom.
  ///
  /// O CHAO existe para a composicao nao virar um risco: abaixo de
  /// quatro pixels por segundo, um clipe de um segundo some. O TETO
  /// existe porque abaixo de um quadro nao ha o que ver — a 60 fps, 480
  /// px/s ja da oito pixels por quadro.
  static const zoomMinimo = 4.0;
  static const zoomMaximo = 480.0;
  static const zoomPadrao = 60.0;

  static double prender(double v) {
    if (v.isNaN) return zoomPadrao;
    if (v < zoomMinimo) return zoomMinimo;
    if (v > zoomMaximo) return zoomMaximo;
    return v;
  }
}

/// A ESCALA VIGENTE, em pixels por segundo.
///
/// Nula ate alguem escolher. Enquanto for nula, cada tela calcula
/// [MapaDoTempo.zoomQueCabe] com a largura que ela tem — e assim um
/// projeto recem-aberto ja aparece inteiro, sem ninguem precisar
/// enquadrar. No instante em que o dedo belisca ou o botao enquadra,
/// o valor passa a ser explicito e para de seguir a duracao.
///
/// Vive so na sessao. Guardar zoom em disco seria gravar preferencia de
/// vista dentro do arquivo do projeto — migracao de dados, e isso esta
/// fora deste pacote.
final zoomDaLinhaDoTempoProvider = StateProvider<double?>((ref) => null);
