/// XML PEQUENO E PERMISSIVO.
///
/// O app le dois formatos de XML de fora — projetos de cena e arquivos
/// SVG — e nenhum dos dois precisa de validacao, espacos de nome ou
/// DTD: precisa de tag, atributos, filhos e texto, sem cair com arquivo
/// estranho. Isso cabe em duzentas linhas e evita mais uma dependencia.
library;

/// Elemento de XML minimo: tag, atributos, filhos e texto.
class XmlNode {
  XmlNode(this.tag, this.attrs, [this.parent]);

  /// Sempre em minusculas (o SVG mistura `linearGradient` e `path`).
  final String tag;
  final Map<String, String> attrs;
  final XmlNode? parent;
  final List<XmlNode> children = [];
  final StringBuffer text = StringBuffer();

  /// O primeiro atributo que existir, entre varios nomes possiveis.
  String? attr(List<String> names) {
    for (final n in names) {
      for (final e in attrs.entries) {
        if (e.key.toLowerCase() == n.toLowerCase()) return e.value;
      }
    }
    return null;
  }

  /// O texto do elemento com as entidades ja resolvidas (`&amp;` -> `&`).
  String get innerText => desescapaXml(text.toString());

  /// O primeiro filho com esta tag (ou nulo).
  XmlNode? child(String tag) {
    for (final c in children) {
      if (c.tag == tag) return c;
    }
    return null;
  }

  /// Todos os filhos diretos com esta tag.
  Iterable<XmlNode> childrenNamed(String tag) sync* {
    for (final c in children) {
      if (c.tag == tag) yield c;
    }
  }

  Iterable<XmlNode> descendants() sync* {
    for (final c in children) {
      yield c;
      yield* c.descendants();
    }
  }

  @override
  String toString() => '<$tag ${attrs.keys.join(' ')}>';
}

/// Parser de XML pequeno e permissivo: elementos, atributos (com aspas
/// simples ou duplas), texto, comentarios, CDATA e declaracoes. Nao
/// valida nada — o que importa e nao cair com arquivo estranho.
XmlNode parseXml(String src) {
  final root = XmlNode('#root', const {});
  var cur = root;
  var i = 0;
  final n = src.length;
  final attrRe = RegExp(
    r'''([A-Za-z_:][\w:.\-]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s/>]+))''',
  );
  while (i < n) {
    final lt = src.indexOf('<', i);
    if (lt < 0) {
      cur.text.write(src.substring(i));
      break;
    }
    if (lt > i) cur.text.write(src.substring(i, lt));
    if (src.startsWith('<!--', lt)) {
      final fim = src.indexOf('-->', lt);
      i = fim < 0 ? n : fim + 3;
      continue;
    }
    if (src.startsWith('<![CDATA[', lt)) {
      final fim = src.indexOf(']]>', lt);
      cur.text.write(src.substring(lt + 9, fim < 0 ? n : fim));
      i = fim < 0 ? n : fim + 3;
      continue;
    }
    if (src.startsWith('<?', lt) || src.startsWith('<!', lt)) {
      final fim = src.indexOf('>', lt);
      i = fim < 0 ? n : fim + 1;
      continue;
    }
    final gt = _fimDaTag(src, lt);
    if (gt < 0) break;
    final corpo = src.substring(lt + 1, gt).trim();
    i = gt + 1;
    if (corpo.startsWith('/')) {
      final nome = corpo.substring(1).trim().toLowerCase();
      // Fecha ate achar a tag (tolerante a fechamento fora de ordem).
      var p = cur;
      while (p.parent != null && p.tag != nome) {
        p = p.parent!;
      }
      cur = p.parent ?? root;
      continue;
    }
    final autoFecha = corpo.endsWith('/');
    final semBarra = autoFecha ? corpo.substring(0, corpo.length - 1) : corpo;
    final espaco = semBarra.indexOf(RegExp(r'\s'));
    final nome = (espaco < 0 ? semBarra : semBarra.substring(0, espaco))
        .toLowerCase();
    final attrs = <String, String>{};
    if (espaco >= 0) {
      for (final m in attrRe.allMatches(semBarra.substring(espaco))) {
        attrs[m.group(1)!] = desescapaXml(
          m.group(2) ?? m.group(3) ?? m.group(4) ?? '',
        );
      }
    }
    final el = XmlNode(nome, attrs, cur);
    cur.children.add(el);
    if (!autoFecha) cur = el;
  }
  return root;
}

int _fimDaTag(String s, int lt) {
  var aspas = '';
  for (var i = lt + 1; i < s.length; i++) {
    final c = s[i];
    if (aspas.isNotEmpty) {
      if (c == aspas) aspas = '';
      continue;
    }
    if (c == '"' || c == "'") {
      aspas = c;
    } else if (c == '>') {
      return i;
    }
  }
  return -1;
}

String desescapaXml(String s) {
  var out = s
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&#39;', "'");
  // Entidades numericas (&#10; nas quebras de linha do texto).
  out = out.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
    final code = int.tryParse(m.group(1)!);
    return code == null ? m.group(0)! : String.fromCharCode(code);
  });
  return out.replaceAll('&amp;', '&');
}
