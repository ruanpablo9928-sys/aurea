/// IMANTACAO NA LINHA DO TEMPO.
///
/// Sem ima, alinhar um clipe com outro e mira: o dedo entrega tempo
/// continuo, e "encostar" vira um erro de dezenas de milissegundos que
/// ninguem enxerga na tela e todo mundo ouve no corte. Editar musica
/// neste app era impossivel por causa disto.
///
/// A regra e uma so: quando o alvo passa perto de uma ancora, ele COLA
/// nela. Perto e medido em PIXELS e traduzido para tempo por quem
/// chama — uma tolerancia fixa em milissegundos seria generosa demais
/// com o zoom fechado e inutil com ele aberto.
library;

/// A ancora mais proxima de [alvo] dentro de [tolerancia], ou nulo.
///
/// Devolve a ANCORA, e nao o tempo colado, porque quem chama muitas
/// vezes precisa saber QUAL delas pegou — para desenhar a linha do ima,
/// por exemplo.
Duration? ancoraMaisProxima(
  Duration alvo,
  Iterable<Duration> ancoras,
  Duration tolerancia,
) {
  if (tolerancia <= Duration.zero) return null;
  Duration? melhor;
  var menor = tolerancia.inMicroseconds + 1;
  for (final a in ancoras) {
    final d = (a - alvo).inMicroseconds.abs();
    if (d < menor) {
      menor = d;
      melhor = a;
    }
  }
  return melhor;
}

/// COLA [alvo] na ancora mais proxima, se houver uma perto.
Duration imantar(
  Duration alvo,
  Iterable<Duration> ancoras,
  Duration tolerancia,
) => ancoraMaisProxima(alvo, ancoras, tolerancia) ?? alvo;

/// COLA UM CLIPE INTEIRO, olhando as DUAS pontas.
///
/// Um clipe encosta no vizinho tanto pelo comeco quanto pelo fim, e a
/// que ganha e a que estiver mais perto. Imantar so o comeco faria o
/// caso mais comum de todos — arrastar um clipe para encostar o FIM
/// dele no comeco do proximo — nao funcionar.
///
/// Devolve o novo INICIO do clipe.
Duration imantarClipe(
  Duration inicio,
  Duration duracao,
  Iterable<Duration> ancoras,
  Duration tolerancia,
) {
  final lista = ancoras.toList(growable: false);
  final peloInicio = ancoraMaisProxima(inicio, lista, tolerancia);
  final peloFim = ancoraMaisProxima(inicio + duracao, lista, tolerancia);
  if (peloInicio == null && peloFim == null) return inicio;
  if (peloFim == null) return peloInicio!;
  if (peloInicio == null) return peloFim - duracao;
  final distInicio = (peloInicio - inicio).inMicroseconds.abs();
  final distFim = (peloFim - (inicio + duracao)).inMicroseconds.abs();
  return distFim < distInicio ? peloFim - duracao : peloInicio;
}
