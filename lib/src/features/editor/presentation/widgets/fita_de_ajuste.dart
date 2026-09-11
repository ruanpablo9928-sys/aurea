import 'package:flutter/material.dart';

import '../../../../core/ui/am_colors.dart';

/// A FITA DE AJUSTE — o controle que substituiu o deslizante.
///
/// Um deslizante tem comeco e fim. Escala, inclinacao e a maioria dos
/// parametros de efeito NAO tem, e quando tem o limite e arbitrario:
/// prender "escala" entre 0 e 4 e inventar um teto que o motor nunca
/// pediu. A fita e RELATIVA e INFINITA — cada pixel de dedo vale
/// [porPixel] — e por isso serve igual para 0 a 1 e para 0 a 4000, sem
/// ninguem escolher faixa (`docs/painel-de-transformacao-alight.md`,
/// secao "A fita").
///
/// E o controle mais tocado do painel novo, entao ele faz uma coisa so:
/// converte dedo em valor e avisa quem manda. Formatar, arredondar,
/// prender em faixa e escrever no projeto sao trabalho de quem usa a
/// fita, e nao dela.
///
/// AS LINHAS ROLAM COM O VALOR. Sem isso, arrastar num parametro que vai
/// a milhares nao muda nada visivel na tela — o numero anda no campo,
/// mas a superficie sob o dedo fica parada e o gesto parece morto.
class FitaDeAjuste extends StatefulWidget {
  const FitaDeAjuste({
    required this.valor,
    required this.porPixel,
    required this.aoMudar,
    required this.rotulo,
    this.aoComecar,
    this.aoTerminar,
    this.ativa = true,
    this.altura = 74,
    super.key,
  });

  /// O valor vigente. Serve SO para desenhar a rolagem das linhas: o
  /// gesto nunca le daqui (ver [_FitaDeAjusteState._partida]).
  final double valor;

  /// Quanto o valor muda a cada pixel de dedo. Sai da faixa util do
  /// parametro, para que atravessar a fita de uma ponta a outra cubra o
  /// intervalo que interessa sem exigir dez arrastos.
  final double porPixel;

  /// O NOVO VALOR JA PRONTO, e nao o quanto o dedo andou — ao
  /// contrario da almofada ao lado, que manda deslocamento. Quem sabe
  /// de onde o arrasto partiu e a fita, entao a conta e dela e quem
  /// recebe so escreve. Vem sem arredondar e sem prender em faixa:
  /// decidir a casa decimal e o teto e de quem tem o parametro.
  final void Function(double novoValor) aoMudar;

  /// Um arrasto e UMA edicao. Quem usa liga estes dois em
  /// `beginGesture`/`endGesture` para que o desfazer volte o arrasto
  /// inteiro, e nao os quatrocentos passos que o dedo produziu.
  final VoidCallback? aoComecar;
  final VoidCallback? aoTerminar;

  /// Se esta e a fita em edicao. Num par (inclinacao X e Y), so uma
  /// esta: a outra fica com o centro branco para dizer que existe mas
  /// nao e a que o dedo mexeu por ultimo.
  final bool ativa;

  /// A ALTURA DA FAIXA QUE ACEITA O DEDO. O padrao e folgado porque
  /// este e alvo de polegar, e nao de ponteiro: mais baixo que isto o
  /// dedo encosta nos campos de valor logo acima e o arrasto comeca no
  /// controle errado. Quem empilha duas fitas (inclinacao X e Y) passa
  /// um valor menor, porque as duas dividem a altura do miolo.
  final double altura;

  /// O que o leitor de tela anuncia — e por onde os testes acham a
  /// fita, ja que ela nao tem texto nenhum.
  final String rotulo;

  @override
  State<FitaDeAjuste> createState() => _FitaDeAjusteState();
}

class _FitaDeAjusteState extends State<FitaDeAjuste> {
  /// O VALOR DE ONDE O DEDO PARTIU, congelado no inicio do arrasto.
  ///
  /// Ler `widget.valor` a cada quadro parece mais simples e escorrega:
  /// o motor arredonda (uma casa decimal no campo, quantizacao no
  /// parametro), devolve um numero ligeiramente diferente do que
  /// pedimos, e no quadro seguinte o proximo delta parte desse valor
  /// arredondado. O erro acumula, e o desenho descola do dedo — poucos
  /// pixels por segundo de arrasto, o bastante para parecer defeito.
  ///
  /// NULO QUER DIZER "NAO HA ARRASTO", e e para isso que ele e
  /// anulavel. O Flutter avisa o cancelamento de arrastos que nunca
  /// comecaram: um toque simples, ou um dedo que a area rolavel de cima
  /// roubou, sai pelo `onHorizontalDragCancel` sem ter passado pelo
  /// `Start`. Sem esta marca, esse toque fecharia um lote de desfazer
  /// que ninguem abriu — e, com dois dedos nas duas fitas do par,
  /// fecharia o lote do arrasto que ainda esta acontecendo na outra.
  double? _partida;

  /// A SOMA DOS DELTAS deste arrasto. Somar os deltas e diferente de
  /// olhar a posicao atual: o dedo pode sair da fita e voltar, e o
  /// gesto continua o mesmo.
  double _andado = 0;

  void _comecar(DragStartDetails _) {
    // UM VALOR QUEBRADO NAO CONTAMINA O GESTO: se o parametro chegou
    // NaN ou infinito, partir dele faria o arrasto inteiro escrever
    // NaN, e o parametro nunca mais sairia de la nem arrastando de
    // volta. O pintor ja se defende disso; o gesto tem de se defender
    // igual, porque le o mesmo numero.
    _partida = widget.valor.isFinite ? widget.valor : 0;
    _andado = 0;
    widget.aoComecar?.call();
  }

  void _andar(DragUpdateDetails d) {
    final partida = _partida;
    if (partida == null) return;
    _andado += d.delta.dx;
    widget.aoMudar(partida + _andado * widget.porPixel);
  }

  void _terminar() {
    if (_partida == null) return;
    _partida = null;
    widget.aoTerminar?.call();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: true,
    // "AJUSTAR X", e nao so "X": o chip da linha ja leva o nome cru, e
    // dois nos com o mesmo rotulo deixam quem le a tela — e quem escreve
    // teste — sem saber em qual dos dois esta encostando.
    label: 'Ajustar ${widget.rotulo}',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _comecar,
      onHorizontalDragUpdate: _andar,
      onHorizontalDragEnd: (_) => _terminar(),
      onHorizontalDragCancel: _terminar,
      child: SizedBox(
        height: widget.altura.isFinite ? widget.altura : null,
        child: CustomPaint(
          size: Size.infinite,
          painter: _PintorDaFita(
            fase: _faseDe(widget.valor, widget.porPixel),
            ativa: widget.ativa,
          ),
        ),
      ),
    ),
  );
}

/// QUANTO A FITA JA ROLOU DENTRO DE UM PASSO, em pixels.
///
/// `valor / porPixel` e o quanto de dedo aquele valor representa; o
/// resto por [_passo] e o unico pedaco disso que muda o desenho, ja que
/// as linhas sao todas iguais. Com [porPixel] zero ou valor invalido a
/// conta nao tem resposta — a fita entao so nao rola, em vez de sumir.
double _faseDe(double valor, double porPixel) {
  final emPixels = valor / porPixel;
  if (!emPixels.isFinite) return 0;
  // O `%` do Dart devolve resultado nao negativo para divisor positivo,
  // entao valor negativo tambem cai dentro do passo.
  return emPixels % _passo;
}

/// O ESPACO ENTRE DUAS LINHAS DA FITA, medido na referencia: 9 px.
///
/// E o mesmo numero em toda parte porque a fita nao tem escala propria —
/// ela mostra "quanto andou", e nao "onde no intervalo". Se cada
/// parametro espacasse as linhas do seu jeito, o mesmo gesto pareceria
/// mais rapido num campo do que no outro sem que nada tivesse mudado.
const double _passo = 9;

/// A FOLGA EM CIMA E EMBAIXO. As linhas nao encostam nas pontas da
/// faixa: encostadas, a fita vira uma caixa com borda, e a reforma toda
/// e sobre nao ter caixas.
const double _folga = 8;

/// ONDE AS LINHAS COMECAM A SUMIR, contado de cada borda para dentro.
///
/// Na referencia a fita nao termina: ela some. Um corte duro nas pontas
/// contaria a mentira de que existe um comeco e um fim do intervalo — o
/// que e justamente o que a fita nao tem.
const double _bordaSuave = 24;

/// A ESPESSURA DA LINHA CENTRAL. Dois pixels contra um das outras, para
/// o olho achar o centro sem procurar.
const double _linhaCentral = 2;

/// OS RISCOS SAO PINTADOS, E NAO WIDGETS.
///
/// Uma faixa da largura do miolo tem mais de trinta riscos, e cada um
/// viraria um objeto de render a ser refeito a cada quadro do arrasto:
/// trinta nos de layout para desenhar trinta pixels. Aqui e um laco
/// dentro de um `paint` so — no controle que existe justamente para
/// ficar sob o dedo, e por isso o mais repintado do painel.
class _PintorDaFita extends CustomPainter {
  const _PintorDaFita({required this.fase, required this.ativa});

  final double fase;
  final bool ativa;

  @override
  void paint(Canvas canvas, Size size) {
    final topo = _folga;
    final base = size.height - _folga;
    if (base <= topo || size.width <= 0) return;

    final risco = Paint()..strokeWidth = 1;

    // A FITA SEGUE O DEDO: a fase entra somando, e nao subtraindo, para
    // as linhas andarem para o mesmo lado que a mao — como papel
    // deslizando por baixo do dedo. Ao contrario, o gesto briga.
    //
    // Comeca um passo antes de zero para a linha que esta entrando pela
    // esquerda ja aparecer no lugar certo.
    //
    // O DEGRADE DAS BORDAS SAI RISCO A RISCO, e nao de uma mascara.
    // Mascara aqui pediria `saveLayer`, que no Impeller custa um passe
    // de render inteiro por quadro — caro demais para um controle que
    // fica sendo arrastado o tempo todo.
    for (var x = fase - _passo; x <= size.width; x += _passo) {
      final forca = _opacidadeNaBorda(x, size.width);
      if (forca <= 0) continue;
      risco.color = AmColors.muted.withValues(alpha: .25 * forca);
      canvas.drawLine(Offset(x, topo), Offset(x, base), risco);
    }

    final centro = size.width / 2;
    canvas.drawLine(
      Offset(centro, topo),
      Offset(centro, base),
      Paint()
        ..strokeWidth = _linhaCentral
        // Teal na que esta em edicao, branco na outra do par: e o unico
        // sinal de qual das duas fitas o dedo vai mexer.
        ..color = ativa ? AmColors.accent : AmColors.cabecote,
    );
  }

  /// QUANTO DESTA LINHA SOBREVIVE PERTO DA BORDA, de 0 a 1.
  double _opacidadeNaBorda(double x, double largura) {
    final daBorda = x < largura - x ? x : largura - x;
    if (daBorda <= 0) return 0;
    if (daBorda >= _bordaSuave) return 1;
    return daBorda / _bordaSuave;
  }

  @override
  bool shouldRepaint(_PintorDaFita o) => o.fase != fase || o.ativa != ativa;
}
