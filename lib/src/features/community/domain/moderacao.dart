/// O FILTRO DO MURAL.
///
/// Um mural publico sem filtro dura um fim de semana. Mas filtro tambem
/// erra, e errar aqui e pior do que parece: bloquear alguem que escreveu
/// uma frase normal faz a pessoa achar que o app esta quebrado, e ela nao
/// volta. Entao a regra e:
///
///   - o que e claramente ofensa OU claramente dado pessoal, BLOQUEIA e
///     diz por que;
///   - o que so cheira mal (caixa alta, letra repetida, link solto)
///     AVISA e deixa passar depois de arrumado;
///   - na duvida, passa.
///
/// E o filtro roda DUAS VEZES: antes de publicar (a pessoa corrige) e
/// ao mostrar o mural (o que entrou por outro caminho nao aparece). A
/// segunda e a que importa quando o feed vier de fora.
library;

/// O que o filtro decidiu.
enum Veredito {
  /// Pode publicar.
  liberado,

  /// Da para publicar depois de arrumar — o texto diz o que.
  ajustar,

  /// Nao publica.
  bloqueado,
}

class ResultadoDaModeracao {
  const ResultadoDaModeracao(this.veredito, [this.motivo]);

  final Veredito veredito;

  /// Em portugues, dito para a pessoa que escreveu — nao para um log.
  final String? motivo;

  bool get ok => veredito == Veredito.liberado;
  bool get bloqueia => veredito == Veredito.bloqueado;

  static const liberado = ResultadoDaModeracao(Veredito.liberado);
}

/// PALAVRAS QUE NAO ENTRAM.
///
/// A lista e curta de proposito: xingamento pesado e ataque a grupo. Uma
/// lista longa vira censura de conversa normal — "porra" no meio de um
/// elogio nao e o problema que este mural tem.
///
/// Sao guardadas em RAIZ (sem terminacao) porque a comparacao acontece
/// depois de normalizar: sem acento, sem repeticao de letra e com os
/// numeros que imitam letra ja trocados.
const _raizesBloqueadas = <String>[
  'viado', 'bicha', 'traveco', 'macaco preto', 'crioulo', 'preto imundo',
  'retardado', 'mongoloide', 'aleijado de merda',
  'puta que pariu voce', 'vai se foder', 'vai tomar no cu', 'filho da puta',
  'arrombado', 'corno manso', 'vagabunda', 'piranha do caralho',
  'matar voce', 'te matar', 'estupr', 'pedofil', 'nazis', 'hitler tinha razao',
];

/// Trocas que desfazem o disfarce mais comum (l3tr4 por numero).
const _disfarces = {
  '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't', '@': 'a',
  r'$': 's', '!': 'i',
};

const _acentos = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
  'é': 'e', 'ê': 'e', 'è': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i',
  'ó': 'o', 'ô': 'o', 'õ': 'o', 'ò': 'o',
  'ú': 'u', 'ü': 'u', 'ù': 'u',
  'ç': 'c', 'ñ': 'n',
};

/// Deixa o texto na forma em que a comparacao e justa.
///
/// Minusculas, sem acento, sem disfarce de numero e com um espaco so
/// entre palavras. Depois, a parte que importa: uma letra repetida TRES
/// OU MAIS VEZES vira uma so ("viiiiado" -> "viado"), e duas ficam como
/// estao ("carro" continua "carro").
///
/// O corte em tres e escolhido, nao arbitrario: em portugues a letra
/// dobrada e comum (carro, nossa, asse) e reduzir tudo a uma criaria
/// falso positivo; tres iguais seguidas praticamente so aparecem quando
/// alguem esta esticando a palavra — que e exatamente o disfarce.
String normalizarParaFiltro(String bruto) {
  final b = StringBuffer();
  for (final c in bruto.toLowerCase().split('')) {
    final semAcento = _acentos[c] ?? c;
    final semDisfarce = _disfarces[semAcento] ?? semAcento;
    b.write(
      RegExp(r'[a-z0-9 ]').hasMatch(semDisfarce) ? semDisfarce : ' ',
    );
  }
  return b
      .toString()
      .replaceAllMapped(RegExp(r'(.)\1{2,}'), (m) => m[1]!)
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// PADROES DE DADO PESSOAL.
///
/// Bloquear telefone, e-mail e CPF nao e sobre bom-tom: e sobre nao
/// deixar alguem publicar o proprio numero (ou o de outra pessoa) num
/// mural que qualquer um le. Este e o unico bloqueio que existe para
/// proteger quem escreve de si mesmo.
final _telefone = RegExp(r'(?:\(?\d{2}\)?\s?)?9?\d{4}[\s.-]?\d{4}');
final _email = RegExp(r'[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}');
final _cpf = RegExp(r'\d{3}\.?\d{3}\.?\d{3}-?\d{2}');
final _link = RegExp(r'https?://|www\.', caseSensitive: false);

/// Analisa um texto que alguem quer publicar.
ResultadoDaModeracao moderarTexto(String texto) {
  final limpo = texto.trim();
  if (limpo.isEmpty) {
    return const ResultadoDaModeracao(
      Veredito.bloqueado,
      'Escreva alguma coisa antes de publicar.',
    );
  }
  if (limpo.length < 3) {
    return const ResultadoDaModeracao(
      Veredito.bloqueado,
      'Escreva um pouco mais — três letras não contam nada a ninguém.',
    );
  }
  if (limpo.length > 1200) {
    return const ResultadoDaModeracao(
      Veredito.bloqueado,
      'Texto longo demais para um mural. Corte para até 1200 letras.',
    );
  }

  final normal = normalizarParaFiltro(limpo);
  for (final raiz in _raizesBloqueadas) {
    if (normal.contains(normalizarParaFiltro(raiz))) {
      return const ResultadoDaModeracao(
        Veredito.bloqueado,
        'Isso não entra no mural. Ofensa, ameaça e ataque a alguém ficam '
        'de fora — reescreva sem isso.',
      );
    }
  }

  if (_cpf.hasMatch(limpo)) {
    return const ResultadoDaModeracao(
      Veredito.bloqueado,
      'Parece um CPF no texto. O mural é público: tire dados pessoais.',
    );
  }
  if (_email.hasMatch(limpo)) {
    return const ResultadoDaModeracao(
      Veredito.bloqueado,
      'Parece um e-mail no texto. O mural é público: tire dados pessoais.',
    );
  }
  if (_telefone.hasMatch(limpo)) {
    return const ResultadoDaModeracao(
      Veredito.bloqueado,
      'Parece um telefone no texto. O mural é público: tire dados '
      'pessoais.',
    );
  }

  // --- daqui para baixo, so avisa ---

  final letras = limpo.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '');
  if (letras.length >= 12) {
    final maiusculas = letras.split('').where((c) => c == c.toUpperCase()).length;
    if (maiusculas / letras.length > 0.7) {
      return const ResultadoDaModeracao(
        Veredito.ajustar,
        'Está tudo em maiúsculas — no mural isso lê como grito. '
        'Escreva normal.',
      );
    }
  }
  if (RegExp(r'(.)\1{5,}').hasMatch(limpo)) {
    return const ResultadoDaModeracao(
      Veredito.ajustar,
      'Tem letra repetida demais. Tire o exagero e publique.',
    );
  }
  final links = _link.allMatches(limpo).length;
  if (links > 2) {
    return const ResultadoDaModeracao(
      Veredito.ajustar,
      'Muitos links num post só. Deixe um, o que interessa.',
    );
  }

  return ResultadoDaModeracao.liberado;
}

/// O NOME DE QUEM ASSINA também passa pelo filtro.
///
/// Sem isto, o mural fica limpo e a lista de autores não: quem quer
/// ofender escreve a ofensa no apelido e posta "oi".
ResultadoDaModeracao moderarApelido(String apelido) {
  final limpo = apelido.trim();
  if (limpo.length < 3) {
    return const ResultadoDaModeracao(
      Veredito.bloqueado,
      'O apelido precisa de pelo menos 3 letras.',
    );
  }
  if (limpo.length > 20) {
    return const ResultadoDaModeracao(
      Veredito.bloqueado,
      'Apelido de até 20 letras.',
    );
  }
  if (!RegExp(r'^[A-Za-z0-9._ À-ÿ-]+$').hasMatch(limpo)) {
    return const ResultadoDaModeracao(
      Veredito.bloqueado,
      'Use letras, números, ponto, traço e espaço no apelido.',
    );
  }
  final normal = normalizarParaFiltro(limpo);
  for (final raiz in _raizesBloqueadas) {
    if (normal.contains(normalizarParaFiltro(raiz))) {
      return const ResultadoDaModeracao(
        Veredito.bloqueado,
        'Esse apelido não passa. Escolha outro.',
      );
    }
  }
  // Passar-se pela equipe e o golpe mais barato num mural de beta.
  const reservados = ['aurea', 'admin', 'suporte', 'oficial', 'equipe'];
  for (final r in reservados) {
    if (normal == r || normal.startsWith('$r ')) {
      return const ResultadoDaModeracao(
        Veredito.bloqueado,
        'Esse apelido é reservado — ele passaria por conta oficial.',
      );
    }
  }
  return ResultadoDaModeracao.liberado;
}

/// Ha ofensa NO NOME de quem assina?
///
/// Separado de [moderarApelido] de proposito. Aquele decide quem pode
/// CRIAR uma conta, e por isso tambem recusa nome reservado, tamanho e
/// caractere estranho. Este decide o que APARECE no mural, e ali as
/// regras de criacao nao valem: os avisos oficiais sao assinados
/// "Aurea" — o nome que a criacao recusa justamente para ninguem se
/// passar por eles. Misturar os dois fazia o mural esconder os proprios
/// avisos.
bool _nomeOfensivo(String autor) {
  final normal = normalizarParaFiltro(autor);
  for (final raiz in _raizesBloqueadas) {
    if (normal.contains(normalizarParaFiltro(raiz))) return true;
  }
  return false;
}

/// O FILTRO NA HORA DE MOSTRAR.
///
/// O de cima protege quem escreve daqui. Este protege quem le: o feed
/// vem de fora, e um dia vai vir com coisa que nao passou por este app.
/// Post reprovado nao aparece, e ninguem precisa saber que ele existiu.
/// [permiteVazio] e para o REPOST SEM COMENTARIO: la o texto vazio e o
/// caso normal, e o filtro de "escreva alguma coisa" — que existe para
/// quem esta digitando — sumiria com o cartao.
bool podeMostrar(String texto, String autor, {bool permiteVazio = false}) {
  if (_nomeOfensivo(autor)) return false;
  if (permiteVazio && texto.trim().isEmpty) return true;
  return !moderarTexto(texto).bloqueia;
}
