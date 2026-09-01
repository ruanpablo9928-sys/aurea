import 'layer.dart';

/// OPERACOES DE MONTAGEM — o que separa "mover retangulos" de editar.
///
/// Todas sao funcoes PURAS sobre a lista de camadas: entram camadas,
/// saem camadas. Isso mantem desfazer trivial e deixa cada regra
/// testavel sem interface.
///
/// A ideia que atravessa todas: uma trilha e uma FILA no tempo. Quando
/// se tira algo do meio, o que vem depois anda para tras; quando se
/// enfia algo no meio, o que vem depois anda para frente. Sem isso, o
/// buraco fica na tela e a pessoa arruma na mao.

/// Uma trilha e o conjunto de camadas que dividem a mesma faixa. Aqui a
/// trilha e identificada pela posicao na pilha, entao "mesma trilha" =
/// "mesmo indice de profundidade".
typedef TrackKey = int;

/// Camadas ordenadas por inicio.
List<Layer> _porTempo(Iterable<Layer> layers) =>
    [...layers]..sort((a, b) => a.startTime.compareTo(b.startTime));

/// EXCLUSAO COM ARRASTO: tira a camada e puxa para tras tudo que vinha
/// depois DELA, fechando o buraco.
///
/// E a diferenca entre "apaguei um trecho" e "apaguei um trecho e agora
/// tenho um silencio de tres segundos no meio".
List<Layer> rippleDelete(List<Layer> layers, String id) {
  final alvo = layers.where((l) => l.id == id).firstOrNull;
  if (alvo == null) return layers;
  final vao = alvo.duration;

  return [
    for (final l in layers)
      if (l.id != id)
        if (l.startTime >= alvo.endTime)
          l.copyLayer(startTime: l.startTime - vao)
        else
          l,
  ];
}

/// FECHAR BURACOS: empurra tudo para tras ate encostar no anterior.
///
/// Nao muda a ordem nem a duracao de ninguem — so tira o vazio. E o
/// comando que se usa depois de apagar varios trechos soltos.
List<Layer> closeGaps(List<Layer> layers, {Duration from = Duration.zero}) {
  final ordenadas = _porTempo(layers);
  final movidas = <String, Duration>{};
  var cursor = from;

  for (final l in ordenadas) {
    if (l.endTime <= from) continue;
    final novo = l.startTime < cursor ? l.startTime : cursor;
    movidas[l.id] = novo;
    cursor = novo + l.duration;
  }

  return [
    for (final l in layers)
      movidas.containsKey(l.id) && movidas[l.id] != l.startTime
          ? l.copyLayer(startTime: movidas[l.id])
          : l,
  ];
}

/// INSERIR: abre espaco em [at] do tamanho de [novo] e empurra para
/// frente tudo que comeca dali em diante. O que esta ATRAVESSADO no
/// ponto e dividido.
///
/// E o "insert edit" do NLE: enfiar um plano no meio sem atropelar o
/// que ja estava montado.
({List<Layer> layers, Layer inserted}) insertAt(
  List<Layer> layers,
  Layer novo,
  Duration at,
) {
  final vao = novo.duration;
  final out = <Layer>[];

  for (final l in layers) {
    if (l.startTime >= at) {
      out.add(l.copyLayer(startTime: l.startTime + vao));
      continue;
    }
    if (l.endTime > at) {
      // Atravessa o ponto: a parte de tras vai para depois do inserido.
      final antes = l.copyLayer(duration: at - l.startTime);
      final depois = l.duplicated().copyLayer(
            startTime: at + vao,
            duration: l.endTime - at,
          );
      out..add(antes)..add(depois);
      continue;
    }
    out.add(l);
  }

  final colocado = novo.copyLayer(startTime: at);
  out.add(colocado);
  return (layers: out, inserted: colocado);
}

/// SOBRESCREVER: poe [novo] em [at] apagando o que estava embaixo, sem
/// mexer no que esta fora do trecho.
///
/// A diferenca para inserir: aqui a linha do tempo NAO estica. E o que
/// se usa para trocar um plano por outro mantendo a sincronia do resto.
({List<Layer> layers, Layer inserted}) overwriteAt(
  List<Layer> layers,
  Layer novo,
  Duration at,
) {
  final fim = at + novo.duration;
  final out = <Layer>[];

  for (final l in layers) {
    // Fora do trecho: intacta.
    if (l.endTime <= at || l.startTime >= fim) {
      out.add(l);
      continue;
    }
    // Coberta por inteiro: some.
    if (l.startTime >= at && l.endTime <= fim) continue;

    // Sobra so a ponta da esquerda.
    if (l.startTime < at && l.endTime <= fim) {
      out.add(l.copyLayer(duration: at - l.startTime));
      continue;
    }
    // Sobra so a ponta da direita.
    if (l.startTime >= at && l.endTime > fim) {
      out.add(l.copyLayer(
        startTime: fim,
        duration: l.endTime - fim,
      ));
      continue;
    }
    // O novo cai no MEIO dela: sobram as duas pontas.
    out.add(l.copyLayer(duration: at - l.startTime));
    out.add(l.duplicated().copyLayer(
          startTime: fim,
          duration: l.endTime - fim,
        ));
  }

  final colocado = novo.copyLayer(startTime: at);
  out.add(colocado);
  return (layers: out, inserted: colocado);
}

/// Avanca o PONTO DE ENTRADA na midia quando um pedaco vira o "depois"
/// de um corte. Sem isso, tirar um trecho do meio faz o pedaco de tras
/// repetir o audio (ou o video) que ja tinha passado.
Layer _avancarFonte(Layer l, Duration quanto) => switch (l) {
      VideoLayer v => v.copyLayer(sourceOffset: v.sourceOffset + quanto),
      AudioLayer a => a.copyLayer(sourceOffset: a.sourceOffset + quanto),
      _ => l,
    };

/// LEVANTAR (lift): tira o trecho e DEIXA o buraco. O oposto de
/// [rippleDelete] — usado quando a sincronia com outra trilha importa
/// mais do que fechar o vazio.
List<Layer> liftRange(
  List<Layer> layers,
  Duration from,
  Duration to, {
  Set<String>? only,
}) {
  if (to <= from) return layers;
  final out = <Layer>[];

  for (final l in layers) {
    if (only != null && !only.contains(l.id)) {
      out.add(l);
      continue;
    }
    if (l.endTime <= from || l.startTime >= to) {
      out.add(l);
      continue;
    }
    if (l.startTime >= from && l.endTime <= to) continue;

    if (l.startTime < from && l.endTime <= to) {
      out.add(l.copyLayer(duration: from - l.startTime));
      continue;
    }
    if (l.startTime >= from && l.endTime > to) {
      out.add(_avancarFonte(l, to - l.startTime)
          .copyLayer(startTime: to, duration: l.endTime - to));
      continue;
    }
    out.add(l.copyLayer(duration: from - l.startTime));
    out.add(_avancarFonte(l.duplicated(), to - l.startTime).copyLayer(
      startTime: to,
      duration: l.endTime - to,
    ));
  }
  return out;
}

/// EXTRAIR (extract): tira o trecho E fecha o buraco.
List<Layer> extractRange(
  List<Layer> layers,
  Duration from,
  Duration to, {
  Set<String>? only,
}) {
  if (to <= from) return layers;
  final vao = to - from;
  final levantadas = liftRange(layers, from, to, only: only);

  return [
    for (final l in levantadas)
      if (l.startTime >= to && (only == null || only.contains(l.id)))
        l.copyLayer(startTime: l.startTime - vao)
      else
        l,
  ];
}

/// Onde ha VAZIO na linha do tempo, entre [from] e o fim.
///
/// Serve para o comando de fechar buracos avisar quantos existem — e
/// para o teste provar que fechou.
List<(Duration, Duration)> gapsIn(List<Layer> layers,
    {Duration from = Duration.zero}) {
  final ordenadas = _porTempo(layers.where((l) => l.endTime > from));
  final out = <(Duration, Duration)>[];
  var cursor = from;
  for (final l in ordenadas) {
    if (l.startTime > cursor) out.add((cursor, l.startTime));
    if (l.endTime > cursor) cursor = l.endTime;
  }
  return out;
}
