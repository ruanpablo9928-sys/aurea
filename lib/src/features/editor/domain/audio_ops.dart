import 'dart:math' as math;
import 'dart:typed_data';

/// OPERACOES DE AUDIO — as contas que fazem o som ficar montavel.
///
/// Todas trabalham sobre o ENVELOPE DE PICO ja calculado para desenhar a
/// forma de onda (100 picos por segundo). Reaproveitar esse envelope em
/// vez de reabrir o arquivo e o que deixa "remover silencio" responder
/// no toque, em vez de rodar o FFmpeg de novo.

/// Picos por segundo do envelope — tem de bater com quem gerou.
const audioPeaksPerSecond = 100;

Duration _atIndex(int i) =>
    Duration(microseconds: (i * 1000000 / audioPeaksPerSecond).round());

/// SILENCIO: trechos abaixo de [threshold] por pelo menos
/// [minSilence].
///
/// O limiar e em AMPLITUDE (0..1), nao em dB, porque e o mesmo numero
/// que a forma de onda desenha — a pessoa ve a linha baixinha e sabe
/// onde o corte vai cair.
///
/// [padding] encolhe cada trecho nas duas pontas: cortar exatamente no
/// limiar decepa o comeco da consoante e o final da vogal, e a fala sai
/// picotada. Uns 120 ms de folga resolvem.
List<(Duration, Duration)> detectSilence(
  Float32List peaks, {
  double threshold = 0.035,
  Duration minSilence = const Duration(milliseconds: 350),
  Duration padding = const Duration(milliseconds: 120),
}) {
  if (peaks.isEmpty) return const [];
  final minLen =
      (minSilence.inMilliseconds * audioPeaksPerSecond / 1000).round();
  final pad = (padding.inMilliseconds * audioPeaksPerSecond / 1000).round();

  final out = <(Duration, Duration)>[];
  var start = -1;
  for (var i = 0; i <= peaks.length; i++) {
    final quieto = i < peaks.length && peaks[i] < threshold;
    if (quieto) {
      if (start < 0) start = i;
      continue;
    }
    if (start >= 0) {
      final len = i - start;
      if (len >= minLen) {
        final a = start + pad;
        final b = i - pad;
        if (b > a) out.add((_atIndex(a), _atIndex(b)));
      }
      start = -1;
    }
  }
  return out;
}

/// O contrario do silencio: onde HA som. E o que sobra depois de
/// remover silencio, e o que a decupagem realmente mantem.
List<(Duration, Duration)> detectSpeech(
  Float32List peaks, {
  double threshold = 0.035,
  Duration minSilence = const Duration(milliseconds: 350),
  Duration padding = const Duration(milliseconds: 120),
}) {
  if (peaks.isEmpty) return const [];
  final silencios = detectSilence(peaks,
      threshold: threshold, minSilence: minSilence, padding: padding);
  final total = _atIndex(peaks.length);

  final out = <(Duration, Duration)>[];
  var cursor = Duration.zero;
  for (final s in silencios) {
    if (s.$1 > cursor) out.add((cursor, s.$1));
    cursor = s.$2;
  }
  if (cursor < total) out.add((cursor, total));
  return out;
}

/// BATIDAS: onde a energia SOBE de repente.
///
/// Nao e detector de tempo musical — e detector de ataque, que e o que
/// serve para encaixar corte no ritmo. Compara cada pico com a media
/// dos anteriores: se estourou [sensitivity] vezes a media, e ataque.
///
/// [minGap] evita marcar a mesma batida duas vezes por causa do
/// sustain.
List<Duration> detectBeats(
  Float32List peaks, {
  double sensitivity = 1.6,
  Duration minGap = const Duration(milliseconds: 200),
  int window = 43,
}) {
  if (peaks.length < window + 2) return const [];
  final gap = (minGap.inMilliseconds * audioPeaksPerSecond / 1000).round();
  final out = <Duration>[];
  var ultimo = -gap;

  for (var i = window; i < peaks.length; i++) {
    var soma = 0.0;
    for (var j = i - window; j < i; j++) {
      soma += peaks[j];
    }
    final media = soma / window;
    if (media < 0.01) continue;
    if (peaks[i] > media * sensitivity && i - ultimo >= gap) {
      out.add(_atIndex(i));
      ultimo = i;
    }
  }
  return out;
}

/// GANHO DE NORMALIZACAO: quanto multiplicar para o pico mais alto
/// chegar em [target].
///
/// Usa o percentil 99, nao o maximo absoluto: um estalo isolado nao
/// pode decidir o volume da faixa inteira.
double normalizeGain(Float32List peaks, {double target = 0.89}) {
  if (peaks.isEmpty) return 1;
  final ordenados = Float32List.fromList(peaks)..sort();
  final idx = ((ordenados.length - 1) * 0.99).floor();
  final pico = ordenados[idx];
  if (pico <= 0.0001) return 1;
  return (target / pico).clamp(0.1, 12.0);
}

/// Ganho -> decibeis, para mostrar na interface. Silencio vira -inf, que
/// a UI escreve como "mudo".
double gainToDb(double gain) =>
    gain <= 0 ? double.negativeInfinity : 20 * (math.log(gain) / math.ln10);

double dbToGain(double db) =>
    db.isFinite ? math.pow(10, db / 20).toDouble() : 0;

/// ENVELOPE DE FADE em [t], dentro de um clipe de [duration].
///
/// A curva e igual-potencia (seno), nao linear: fade linear de volume
/// soa como um buraco no meio, porque o ouvido responde a potencia.
double fadeGainAt(
  Duration t,
  Duration duration, {
  Duration fadeIn = Duration.zero,
  Duration fadeOut = Duration.zero,
}) {
  final us = t.inMicroseconds;
  final total = duration.inMicroseconds;
  if (total <= 0) return 1;
  if (us < 0 || us > total) return 0;

  var g = 1.0;
  final inUs = fadeIn.inMicroseconds;
  if (inUs > 0 && us < inUs) {
    g *= math.sin((us / inUs) * math.pi / 2);
  }
  final outUs = fadeOut.inMicroseconds;
  if (outUs > 0 && us > total - outUs) {
    final f = (total - us) / outUs;
    g *= math.sin(f.clamp(0.0, 1.0) * math.pi / 2);
  }
  return g.clamp(0.0, 1.0);
}

/// DUCKING: quanto a trilha tem de abaixar por causa da voz.
///
/// Devolve 1 quando nao ha voz e (1 - amount) no meio dela, com subida
/// e descida suaves — o corte seco chama mais atencao que a musica alta.
///
/// [attack] e curto porque a musica precisa sair da frente ANTES da
/// silaba; [release] e longo porque voltar rapido soa como bombeamento.
Float32List duckEnvelope(
  Float32List voicePeaks, {
  double amount = 0.7,
  double threshold = 0.05,
  Duration attack = const Duration(milliseconds: 120),
  Duration release = const Duration(milliseconds: 450),
}) {
  final n = voicePeaks.length;
  final out = Float32List(n);
  if (n == 0) return out;

  final piso = (1 - amount).clamp(0.0, 1.0);
  final aPassos =
      math.max(1, (attack.inMilliseconds * audioPeaksPerSecond / 1000).round());
  final rPassos = math.max(
      1, (release.inMilliseconds * audioPeaksPerSecond / 1000).round());

  var g = 1.0;
  for (var i = 0; i < n; i++) {
    final alvo = voicePeaks[i] >= threshold ? piso : 1.0;
    if (alvo < g) {
      g = math.max(alvo, g - (1 - piso) / aPassos);
    } else if (alvo > g) {
      g = math.min(alvo, g + (1 - piso) / rPassos);
    }
    out[i] = g;
  }
  return out;
}

/// Junta trechos que ficaram perto demais um do outro.
///
/// Depois de remover silencio, dois pedacos separados por 80 ms viram
/// dois cortes que ninguem percebe — e duas camadas a mais para
/// gerenciar. Colar e mais honesto.
List<(Duration, Duration)> mergeClose(
  List<(Duration, Duration)> ranges, {
  Duration maxGap = const Duration(milliseconds: 200),
}) {
  if (ranges.length < 2) return ranges;
  final ordenados = [...ranges]..sort((a, b) => a.$1.compareTo(b.$1));
  final out = <(Duration, Duration)>[ordenados.first];
  for (final r in ordenados.skip(1)) {
    final ultimo = out.last;
    if (r.$1 - ultimo.$2 <= maxGap) {
      out[out.length - 1] = (ultimo.$1, r.$2 > ultimo.$2 ? r.$2 : ultimo.$2);
    } else {
      out.add(r);
    }
  }
  return out;
}
