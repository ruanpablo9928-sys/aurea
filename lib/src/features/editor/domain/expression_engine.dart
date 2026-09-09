/// O MOTOR DE EXPRESSIONS.
///
/// A metade "poder do After Effects" do texto animado. O que ja existia
/// eram os seletores Range e Wiggly — bons, e limitados ao que um par de
/// controles deslizantes consegue dizer. Expression e o que destrava o
/// resto: cada letra decidindo o proprio destino por uma conta.
///
/// TRES DECISOES QUE MOLDAM TUDO AQUI.
///
/// NAO HA LACO. A linguagem nao tem `while` nem `for`. Isso nao e uma
/// falta: e a resposta ao pedido de que `while(true){}` nao congele o
/// aplicativo. Um cronometro que interrompe um laco depois de N
/// milissegundos ainda gasta esses N milissegundos POR CARACTERE, POR
/// QUADRO — com cem letras a 30 quadros por segundo, um travamento de
/// 10 ms vira trinta segundos de espera por segundo de filme. Sem a
/// sintaxe, o laco infinito deixa de existir: vira erro de escrita, na
/// hora de escrever, com linha e coluna. Melhor falhar no editor do que
/// no render.
///
/// O TETO DE PASSOS existe mesmo assim, para chamada aninhada e
/// expressao gigante: nenhuma avaliacao passa de [_tetoDePassos] nos.
///
/// DETERMINISMO. `random` e `wiggle` saem de um gerador proprio semeado
/// por `seedRandom` — nunca do relogio nem do `Random` da plataforma.
/// Abrir o projeto amanha da o mesmo filme, e exportar da o mesmo que o
/// preview mostrou. Sem isso, animacao aleatoria e irreproduzivel e a
/// exportacao nao bate com o que se viu.
///
/// COMPATIBILIDADE, declarada em camadas (o pedido pede isso
/// explicitamente, e pede para nao prometer o impossivel):
///
///   NIVEL 1  time, value, textIndex, textTotal, selectorValue,
///            linear, ease, easeIn, easeOut, clamp, random, seedRandom,
///            wiggle, e a matematica (sin, cos, abs, min, max, floor,
///            ceil, round, sqrt, pow, ...). E o que este arquivo faz.
///   NIVEL 2  thisLayer/thisComp e vinculos entre propriedades — o
///            contexto ja aceita, falta a interface de ligacao.
///   NIVEL 3  o resto do ambiente do After Effects. NAO suportado, e
///            quando aparece o erro DIZ o nome do que faltou, em vez de
///            devolver zero calado.
library;

import 'dart:math' as math;

// ============================================================== ERROS

/// Um erro de expressao com LUGAR. "Expression Error" sozinho nao ajuda
/// ninguem; o que resolve e a linha, a coluna e o trecho.
class ExpressionError implements Exception {
  ExpressionError(
    this.mensagem, {
    this.linha = 1,
    this.coluna = 1,
    this.trecho,
  });

  final String mensagem;
  final int linha;
  final int coluna;

  /// O pedaco do texto que causou o erro, quando da para apontar.
  final String? trecho;

  @override
  String toString() => trecho == null
      ? 'Linha $linha, coluna $coluna: $mensagem'
      : 'Linha $linha, coluna $coluna: $mensagem  ->  "$trecho"';
}

// ============================================================= TOKENS

enum _T { numero, texto, nome, op, fim }

class _Token {
  _Token(this.tipo, this.lexema, this.linha, this.coluna, [this.numero = 0]);
  final _T tipo;
  final String lexema;
  final int linha;
  final int coluna;
  final double numero;
  @override
  String toString() => '$tipo($lexema)';
}

class _Lexer {
  _Lexer(this.fonte);
  final String fonte;
  int _i = 0, _linha = 1, _coluna = 1;

  static const _duplos = ['===', '!==', '==', '!=', '<=', '>=', '&&', '||'];

  List<_Token> tokens() {
    final out = <_Token>[];
    while (true) {
      _pularBrancos();
      if (_i >= fonte.length) {
        out.add(_Token(_T.fim, '', _linha, _coluna));
        return out;
      }
      final l = _linha, c = _coluna;
      final ch = fonte[_i];

      if (_ehDigito(ch) ||
          (ch == '.' && _i + 1 < fonte.length && _ehDigito(fonte[_i + 1]))) {
        final ini = _i;
        while (_i < fonte.length &&
            (_ehDigito(fonte[_i]) || fonte[_i] == '.')) {
          _avancar();
        }
        final txt = fonte.substring(ini, _i);
        final v = double.tryParse(txt);
        if (v == null) {
          throw ExpressionError(
            'Numero invalido',
            linha: l,
            coluna: c,
            trecho: txt,
          );
        }
        out.add(_Token(_T.numero, txt, l, c, v));
        continue;
      }

      if (ch == '"' || ch == "'") {
        final aspas = ch;
        _avancar();
        final buf = StringBuffer();
        while (_i < fonte.length && fonte[_i] != aspas) {
          if (fonte[_i] == r'\' && _i + 1 < fonte.length) {
            _avancar();
            buf.write(switch (fonte[_i]) {
              'n' => '\n',
              't' => '\t',
              final o => o,
            });
          } else {
            buf.write(fonte[_i]);
          }
          _avancar();
        }
        if (_i >= fonte.length) {
          throw ExpressionError(
            'Texto sem aspas de fechamento',
            linha: l,
            coluna: c,
          );
        }
        _avancar(); // fecha
        out.add(_Token(_T.texto, buf.toString(), l, c));
        continue;
      }

      if (_ehLetra(ch)) {
        final ini = _i;
        while (_i < fonte.length &&
            (_ehLetra(fonte[_i]) || _ehDigito(fonte[_i]))) {
          _avancar();
        }
        out.add(_Token(_T.nome, fonte.substring(ini, _i), l, c));
        continue;
      }

      final resto = fonte.substring(_i);
      final duplo = _duplos.firstWhere(resto.startsWith, orElse: () => '');
      if (duplo.isNotEmpty) {
        for (var k = 0; k < duplo.length; k++) {
          _avancar();
        }
        out.add(_Token(_T.op, duplo, l, c));
        continue;
      }

      // As chaves entram na lista SO para o analisador chegar antes do
      // erro bruto de caractere: e o parser que diz "laco nao existe
      // nesta linguagem", com a explicacao. Um "caractere desconhecido"
      // no lugar disso mandaria a pessoa procurar o problema errado.
      if ('+-*/%()[]{},.;?:<>!='.contains(ch)) {
        _avancar();
        out.add(_Token(_T.op, ch, l, c));
        continue;
      }

      throw ExpressionError(
        'Caractere que a linguagem nao conhece',
        linha: l,
        coluna: c,
        trecho: ch,
      );
    }
  }

  void _pularBrancos() {
    while (_i < fonte.length) {
      final ch = fonte[_i];
      if (ch == '\n') {
        _i++;
        _linha++;
        _coluna = 1;
      } else if (ch == ' ' || ch == '\t' || ch == '\r') {
        _avancar();
      } else if (ch == '/' && _i + 1 < fonte.length && fonte[_i + 1] == '/') {
        while (_i < fonte.length && fonte[_i] != '\n') {
          _avancar();
        }
      } else if (ch == '/' && _i + 1 < fonte.length && fonte[_i + 1] == '*') {
        _avancar();
        _avancar();
        while (_i + 1 < fonte.length &&
            !(fonte[_i] == '*' && fonte[_i + 1] == '/')) {
          if (fonte[_i] == '\n') {
            _i++;
            _linha++;
            _coluna = 1;
          } else {
            _avancar();
          }
        }
        if (_i + 1 < fonte.length) {
          _avancar();
          _avancar();
        } else {
          _i = fonte.length;
        }
      } else {
        return;
      }
    }
  }

  void _avancar() {
    _i++;
    _coluna++;
  }

  static bool _ehDigito(String c) =>
      c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;
  static bool _ehLetra(String c) {
    final u = c.codeUnitAt(0);
    return (u >= 65 && u <= 90) || (u >= 97 && u <= 122) || u == 95 || u == 36;
  }
}

// =============================================================== AST

sealed class _No {
  const _No();
}

class _NumeroNo extends _No {
  const _NumeroNo(this.v);
  final double v;
}

class _TextoNo extends _No {
  const _TextoNo(this.v);
  final String v;
}

class _NomeNo extends _No {
  const _NomeNo(this.nome, this.tok);
  final String nome;
  final _Token tok;
}

class _UnarioNo extends _No {
  const _UnarioNo(this.op, this.alvo);
  final String op;
  final _No alvo;
}

class _BinarioNo extends _No {
  const _BinarioNo(this.op, this.esq, this.dir, this.tok);
  final String op;
  final _No esq, dir;
  final _Token tok;
}

class _TernarioNo extends _No {
  const _TernarioNo(this.cond, this.sim, this.nao);
  final _No cond, sim, nao;
}

class _ChamadaNo extends _No {
  const _ChamadaNo(this.alvo, this.args, this.tok);
  final _No alvo;
  final List<_No> args;
  final _Token tok;
}

class _MembroNo extends _No {
  const _MembroNo(this.alvo, this.nome, this.tok);
  final _No alvo;
  final String nome;
  final _Token tok;
}

class _IndiceNo extends _No {
  const _IndiceNo(this.alvo, this.indice, this.tok);
  final _No alvo, indice;
  final _Token tok;
}

class _ListaNo extends _No {
  const _ListaNo(this.itens);
  final List<_No> itens;
}

class _AtribuicaoNo extends _No {
  const _AtribuicaoNo(this.nome, this.valor);
  final String nome;
  final _No valor;
}

/// Uma expressao ja compilada. Guardar isto e o que evita reanalisar o
/// texto por caractere e por quadro — com cem letras a 30 quadros, seria
/// tres mil analises por segundo do MESMO texto.
class CompiledExpression {
  CompiledExpression._(this._corpo, this.fonte);

  final List<_No> _corpo;
  final String fonte;

  /// Compila [fonte]. Lanca [ExpressionError] com linha e coluna.
  static CompiledExpression compilar(String fonte) {
    final tokens = _Lexer(fonte).tokens();
    final p = _Parser(tokens);
    return CompiledExpression._(p.programa(), fonte);
  }

  /// Compila sem lancar: devolve o erro em vez do resultado.
  static (CompiledExpression?, ExpressionError?) tentar(String fonte) {
    try {
      return (compilar(fonte), null);
    } on ExpressionError catch (e) {
      return (null, e);
    } catch (e) {
      return (null, ExpressionError('$e'));
    }
  }
}

class _Parser {
  _Parser(this.tokens);
  final List<_Token> tokens;
  int _i = 0;

  _Token get _atual => tokens[_i];
  bool _ehOp(String s) => _atual.tipo == _T.op && _atual.lexema == s;
  bool _ehNome(String s) => _atual.tipo == _T.nome && _atual.lexema == s;

  _Token _consumir(String op) {
    if (!_ehOp(op)) {
      throw ExpressionError(
        'Esperava "$op"',
        linha: _atual.linha,
        coluna: _atual.coluna,
        trecho: _atual.lexema.isEmpty ? null : _atual.lexema,
      );
    }
    return tokens[_i++];
  }

  List<_No> programa() {
    final out = <_No>[];
    while (_atual.tipo != _T.fim) {
      if (_ehOp(';')) {
        _i++;
        continue;
      }
      out.add(_declaracao());
    }
    if (out.isEmpty) {
      throw ExpressionError('Expressao vazia');
    }
    return out;
  }

  _No _declaracao() {
    // LACO NAO EXISTE, e o erro diz por que. Ver a nota no topo.
    if (_ehNome('while') || _ehNome('for') || _ehNome('do')) {
      throw ExpressionError(
        'Laco nao existe nesta linguagem: uma expressao roda por '
        'caractere e por quadro, e um laco ali trava o editor. Use '
        'textIndex, wiggle() ou linear() para variar por letra',
        linha: _atual.linha,
        coluna: _atual.coluna,
        trecho: _atual.lexema,
      );
    }
    if (_ehNome('var') || _ehNome('const') || _ehNome('let')) {
      _i++;
      if (_atual.tipo != _T.nome) {
        throw ExpressionError(
          'Esperava um nome depois de var',
          linha: _atual.linha,
          coluna: _atual.coluna,
        );
      }
      final nome = tokens[_i++].lexema;
      _consumir('=');
      return _AtribuicaoNo(nome, _ternario());
    }
    // Atribuicao simples a um nome ja existente.
    if (_atual.tipo == _T.nome &&
        _i + 1 < tokens.length &&
        tokens[_i + 1].tipo == _T.op &&
        tokens[_i + 1].lexema == '=') {
      final nome = tokens[_i++].lexema;
      _i++; // =
      return _AtribuicaoNo(nome, _ternario());
    }
    return _ternario();
  }

  _No _ternario() {
    final cond = _ou();
    if (_ehOp('?')) {
      _i++;
      final sim = _ternario();
      _consumir(':');
      final nao = _ternario();
      return _TernarioNo(cond, sim, nao);
    }
    return cond;
  }

  _No _ou() {
    var e = _e();
    while (_ehOp('||')) {
      final t = tokens[_i++];
      e = _BinarioNo('||', e, _e(), t);
    }
    return e;
  }

  _No _e() {
    var e = _igualdade();
    while (_ehOp('&&')) {
      final t = tokens[_i++];
      e = _BinarioNo('&&', e, _igualdade(), t);
    }
    return e;
  }

  _No _igualdade() {
    var e = _comparacao();
    while (_ehOp('==') || _ehOp('!=') || _ehOp('===') || _ehOp('!==')) {
      final t = tokens[_i++];
      final op = t.lexema == '==='
          ? '=='
          : (t.lexema == '!==' ? '!=' : t.lexema);
      e = _BinarioNo(op, e, _comparacao(), t);
    }
    return e;
  }

  _No _comparacao() {
    var e = _soma();
    while (_ehOp('<') || _ehOp('>') || _ehOp('<=') || _ehOp('>=')) {
      final t = tokens[_i++];
      e = _BinarioNo(t.lexema, e, _soma(), t);
    }
    return e;
  }

  _No _soma() {
    var e = _produto();
    while (_ehOp('+') || _ehOp('-')) {
      final t = tokens[_i++];
      e = _BinarioNo(t.lexema, e, _produto(), t);
    }
    return e;
  }

  _No _produto() {
    var e = _unario();
    while (_ehOp('*') || _ehOp('/') || _ehOp('%')) {
      final t = tokens[_i++];
      e = _BinarioNo(t.lexema, e, _unario(), t);
    }
    return e;
  }

  _No _unario() {
    if (_ehOp('-') || _ehOp('+') || _ehOp('!')) {
      final t = tokens[_i++];
      return _UnarioNo(t.lexema, _unario());
    }
    return _posfixo();
  }

  _No _posfixo() {
    var e = _primario();
    while (true) {
      if (_ehOp('(')) {
        final t = tokens[_i++];
        final args = <_No>[];
        if (!_ehOp(')')) {
          args.add(_ternario());
          while (_ehOp(',')) {
            _i++;
            args.add(_ternario());
          }
        }
        _consumir(')');
        e = _ChamadaNo(e, args, t);
      } else if (_ehOp('.')) {
        final t = tokens[_i++];
        if (_atual.tipo != _T.nome) {
          throw ExpressionError(
            'Esperava um nome depois do ponto',
            linha: _atual.linha,
            coluna: _atual.coluna,
          );
        }
        e = _MembroNo(e, tokens[_i++].lexema, t);
      } else if (_ehOp('[')) {
        final t = tokens[_i++];
        final idx = _ternario();
        _consumir(']');
        e = _IndiceNo(e, idx, t);
      } else {
        return e;
      }
    }
  }

  _No _primario() {
    final t = _atual;
    switch (t.tipo) {
      case _T.numero:
        _i++;
        return _NumeroNo(t.numero);
      case _T.texto:
        _i++;
        return _TextoNo(t.lexema);
      case _T.nome:
        _i++;
        return _NomeNo(t.lexema, t);
      case _T.op:
        if (t.lexema == '(') {
          _i++;
          final e = _ternario();
          _consumir(')');
          return e;
        }
        if (t.lexema == '[') {
          _i++;
          final itens = <_No>[];
          if (!_ehOp(']')) {
            itens.add(_ternario());
            while (_ehOp(',')) {
              _i++;
              itens.add(_ternario());
            }
          }
          _consumir(']');
          return _ListaNo(itens);
        }
        throw ExpressionError(
          'Nao esperava "${t.lexema}" aqui',
          linha: t.linha,
          coluna: t.coluna,
          trecho: t.lexema,
        );
      case _T.fim:
        throw ExpressionError(
          'A expressao termina antes do esperado',
          linha: t.linha,
          coluna: t.coluna,
        );
    }
  }
}

// ========================================================== CONTEXTO

/// O que a expressao enxerga quando roda.
///
/// Um objeto por AVALIACAO, barato de criar: e o que muda por caractere
/// (textIndex) e por quadro (time).
class ExpressionContext {
  ExpressionContext({
    required this.time,
    this.value = 0,
    this.textIndex = 0,
    this.textTotal = 1,
    this.selectorValue = 0,
    this.index = 0,
    this.name = '',
    this.extras = const {},
  });

  /// Segundos desde o inicio da camada.
  final double time;

  /// O valor que a propriedade teria sem a expressao.
  final Object value;

  /// Indice da unidade (0 na primeira letra) e quantas ha.
  final int textIndex;
  final int textTotal;

  /// A cobertura que os seletores anteriores produziram para esta
  /// unidade, em 0..100 — e o `selectorValue` do After Effects.
  final double selectorValue;

  final int index;
  final String name;

  /// Ponte para o resto: controles deslizantes, propriedades ligadas.
  /// E por aqui que o nivel 2 entra sem mexer no motor.
  final Map<String, Object> extras;
}

// ========================================================= AVALIADOR

/// Resultado de uma avaliacao: valor OU erro, nunca os dois.
class ExpressionResult {
  const ExpressionResult.ok(this.valor) : erro = null;
  const ExpressionResult.falha(this.erro) : valor = null;

  final Object? valor;
  final ExpressionError? erro;

  bool get deuCerto => erro == null;

  /// O numero, quando for numero; [padrao] quando nao for.
  double comoNumero([double padrao = 0]) {
    final v = valor;
    if (v is double) return v.isFinite ? v : padrao;
    if (v is int) return v.toDouble();
    if (v is List && v.isNotEmpty && v.first is double) {
      final f = v.first as double;
      return f.isFinite ? f : padrao;
    }
    return padrao;
  }
}

const int _tetoDePassos = 20000;

class ExpressionEvaluator {
  ExpressionEvaluator(this.programa, this.ctx);

  final CompiledExpression programa;
  final ExpressionContext ctx;

  final Map<String, Object> _locais = {};
  int _passos = 0;
  int _semente = 0;
  bool _sementeDefinida = false;

  /// Avalia. NUNCA lanca: erro vira [ExpressionResult.falha], porque uma
  /// expressao errada nao pode derrubar o quadro — ela tem de aparecer
  /// como aviso e a propriedade continuar no valor de base.
  ExpressionResult avaliar() {
    try {
      Object ultimo = 0.0;
      for (final no in programa._corpo) {
        ultimo = _no(no);
      }
      return ExpressionResult.ok(ultimo);
    } on ExpressionError catch (e) {
      return ExpressionResult.falha(e);
    } catch (e) {
      return ExpressionResult.falha(ExpressionError('$e'));
    }
  }

  void _passo(_Token? t) {
    if (++_passos > _tetoDePassos) {
      throw ExpressionError(
        'A expressao e grande demais para rodar por caractere e por '
        'quadro (teto de $_tetoDePassos passos)',
        linha: t?.linha ?? 1,
        coluna: t?.coluna ?? 1,
      );
    }
  }

  Object _no(_No no) {
    switch (no) {
      case _NumeroNo(:final v):
        return v;
      case _TextoNo(:final v):
        return v;
      case _ListaNo(:final itens):
        _passo(null);
        return [for (final i in itens) _no(i)];
      case _AtribuicaoNo(:final nome, :final valor):
        _passo(null);
        final v = _no(valor);
        _locais[nome] = v;
        return v;
      case _NomeNo(:final nome, :final tok):
        _passo(tok);
        return _variavel(nome, tok);
      case _UnarioNo(:final op, :final alvo):
        _passo(null);
        final v = _no(alvo);
        return switch (op) {
          '-' => -_num(v, null),
          '+' => _num(v, null),
          _ => _verdade(v) ? 0.0 : 1.0,
        };
      case _TernarioNo(:final cond, :final sim, :final nao):
        _passo(null);
        return _verdade(_no(cond)) ? _no(sim) : _no(nao);
      case _BinarioNo(:final op, :final esq, :final dir, :final tok):
        _passo(tok);
        return _binario(op, esq, dir, tok);
      case _IndiceNo(:final alvo, :final indice, :final tok):
        _passo(tok);
        final a = _no(alvo);
        final i = _num(_no(indice), tok).round();
        if (a is List) {
          if (i < 0 || i >= a.length) {
            throw ExpressionError(
              'Indice $i fora da lista de ${a.length}',
              linha: tok.linha,
              coluna: tok.coluna,
            );
          }
          return a[i];
        }
        throw ExpressionError(
          'Isto nao e uma lista',
          linha: tok.linha,
          coluna: tok.coluna,
        );
      case _MembroNo(:final alvo, :final nome, :final tok):
        _passo(tok);
        return _membro(alvo, nome, tok);
      case _ChamadaNo(:final alvo, :final args, :final tok):
        _passo(tok);
        return _chamada(alvo, args, tok);
    }
  }

  // ------------------------------------------------------- variaveis

  Object _variavel(String nome, _Token tok) {
    final local = _locais[nome];
    if (local != null) return local;
    switch (nome) {
      case 'time':
        return ctx.time;
      case 'value':
        return ctx.value;
      case 'textIndex':
        // O After Effects conta a partir de 1.
        return (ctx.textIndex + 1).toDouble();
      case 'textTotal':
        return ctx.textTotal.toDouble();
      case 'selectorValue':
        return ctx.selectorValue;
      case 'index':
        return ctx.index.toDouble();
      case 'name':
        return ctx.name;
      case 'Math':
        return 'Math';
      case 'true':
        return 1.0;
      case 'false':
        return 0.0;
      case 'PI':
        return math.pi;
    }
    final extra = ctx.extras[nome];
    if (extra != null) return extra;
    throw ExpressionError(
      'Nao existe "$nome" nesta versao. Ver a lista de funcoes em '
      'Ajuda > Expressions',
      linha: tok.linha,
      coluna: tok.coluna,
      trecho: nome,
    );
  }

  Object _membro(_No alvo, String nome, _Token tok) {
    final a = _no(alvo);
    if (a == 'Math') return 'Math.$nome';
    if (a is List) {
      final i = switch (nome) {
        'x' => 0,
        'y' => 1,
        'z' => 2,
        'length' => -1,
        _ => -2,
      };
      if (i == -1) return a.length.toDouble();
      if (i >= 0 && i < a.length) return a[i];
    }
    if (a is Map<String, Object>) {
      final v = a[nome];
      if (v != null) return v;
    }
    throw ExpressionError(
      '"$nome" nao existe aqui',
      linha: tok.linha,
      coluna: tok.coluna,
      trecho: nome,
    );
  }

  // -------------------------------------------------------- funcoes

  Object _chamada(_No alvo, List<_No> argsNo, _Token tok) {
    final args = [for (final a in argsNo) _no(a)];
    double n(int i, [double p = 0]) => i < args.length ? _num(args[i], tok) : p;

    var nome = '';
    if (alvo is _NomeNo) {
      nome = alvo.nome;
    } else if (alvo is _MembroNo) {
      final base = _no(alvo.alvo);
      nome = base == 'Math' ? 'Math.${alvo.nome}' : alvo.nome;
    }

    switch (nome) {
      // ---- matematica
      case 'Math.sin' || 'sin':
        return math.sin(n(0));
      case 'Math.cos' || 'cos':
        return math.cos(n(0));
      case 'Math.tan' || 'tan':
        return math.tan(n(0));
      case 'Math.abs' || 'abs':
        return n(0).abs();
      case 'Math.floor' || 'floor':
        return n(0).floorToDouble();
      case 'Math.ceil' || 'ceil':
        return n(0).ceilToDouble();
      case 'Math.round' || 'round':
        return n(0).roundToDouble();
      case 'Math.sqrt' || 'sqrt':
        return math.sqrt(math.max(0, n(0)));
      case 'Math.pow' || 'pow':
        return math.pow(n(0), n(1)).toDouble();
      case 'Math.min' || 'min':
        return math.min(n(0), n(1));
      case 'Math.max' || 'max':
        return math.max(n(0), n(1));
      case 'Math.atan2':
        return math.atan2(n(0), n(1));
      case 'Math.exp':
        return math.exp(n(0));
      case 'Math.log':
        return math.log(math.max(1e-12, n(0)));
      case 'degreesToRadians':
        return n(0) * math.pi / 180;
      case 'radiansToDegrees':
        return n(0) * 180 / math.pi;

      // ---- animacao
      case 'clamp':
        return n(0).clamp(n(1), n(2)).toDouble();
      case 'linear':
        return _linear(n(0), n(1, 0), n(2, 1), n(3, 0), n(4, 1));
      case 'ease':
        return _comCurva(n(0), n(1, 0), n(2, 1), n(3, 0), n(4, 1), _suave);
      case 'easeIn':
        return _comCurva(n(0), n(1, 0), n(2, 1), n(3, 0), n(4, 1), _entra);
      case 'easeOut':
        return _comCurva(n(0), n(1, 0), n(2, 1), n(3, 0), n(4, 1), _sai);
      case 'seedRandom':
        _semente = n(0).round();
        _sementeDefinida = true;
        return 0.0;
      case 'random':
        if (args.isEmpty) return _aleatorio();
        if (args.length == 1) return _aleatorio() * n(0);
        return n(0) + _aleatorio() * (n(1) - n(0));
      case 'gaussRandom':
        // Soma de tres uniformes: perto o bastante de uma normal, e
        // deterministica como todo o resto.
        return (_aleatorio() + _aleatorio() + _aleatorio()) / 3;
      case 'wiggle':
        return _wiggle(n(0, 2), n(1, 1), n(2, 1), n(3, .5));
      case 'noise':
        return _ruido(n(0), 0) * 2 - 1;

      // ---- texto
      case 'length':
        final a = args.isEmpty ? '' : args.first;
        if (a is String) return a.length.toDouble();
        if (a is List) return a.length.toDouble();
        return 0.0;
    }

    throw ExpressionError(
      'A funcao "$nome" nao existe nesta versao. Se ela veio do After '
      'Effects, e um recurso ainda nao suportado',
      linha: tok.linha,
      coluna: tok.coluna,
      trecho: nome,
    );
  }

  // ------------------------------------------------------ aleatorio

  /// Gerador proprio (xorshift32) semeado por `seedRandom`. Nunca o
  /// `Random` da plataforma: o mesmo projeto tem de dar o mesmo filme
  /// no preview e na exportacao, hoje e amanha.
  int _estado = 0;
  bool _iniciado = false;

  double _aleatorio() {
    if (!_iniciado) {
      final base = _sementeDefinida ? _semente : ctx.textIndex;
      _estado = (base * 2654435761 + 12345) & 0x7fffffff;
      if (_estado == 0) _estado = 1;
      _iniciado = true;
    }
    var x = _estado;
    x ^= (x << 13) & 0x7fffffff;
    x ^= x >> 17;
    x ^= (x << 5) & 0x7fffffff;
    _estado = x == 0 ? 1 : x;
    return _estado / 0x7fffffff;
  }

  double _ruido(double t, int canal) {
    final base = _sementeDefinida ? _semente : ctx.textIndex;
    final i = t.floor();
    final f = _suave(t - i);
    double h(int k) {
      var x =
          (k * 374761393 + base * 668265263 + canal * 2246822519) & 0x7fffffff;
      x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff;
      return (x ^ (x >> 16)) / 0x7fffffff;
    }

    final a = h(i), b = h(i + 1);
    return a + (b - a) * f;
  }

  /// `wiggle(freq, amp)` no espirito do After Effects: ruido suave em
  /// volta do valor de base.
  double _wiggle(double freq, double amp, double oitavas, double mult) {
    final base = _num(ctx.value, null, 0);
    var soma = 0.0, peso = 1.0, total = 0.0;
    final n = oitavas.clamp(1, 4).round();
    for (var o = 0; o < n; o++) {
      final f = freq * math.pow(2, o);
      soma += (_ruido(ctx.time * f, o) * 2 - 1) * peso;
      total += peso;
      peso *= mult.clamp(0.0, 1.0);
    }
    return base + (total <= 0 ? 0 : soma / total) * amp;
  }

  // ------------------------------------------------------ utilidades

  static double _suave(double t) => t * t * (3 - 2 * t);
  static double _entra(double t) => t * t;
  static double _sai(double t) => 1 - (1 - t) * (1 - t);

  static double _linear(double t, double t0, double t1, double v0, double v1) {
    if (t1 == t0) return t <= t0 ? v0 : v1;
    final k = ((t - t0) / (t1 - t0)).clamp(0.0, 1.0);
    return v0 + (v1 - v0) * k;
  }

  static double _comCurva(
    double t,
    double t0,
    double t1,
    double v0,
    double v1,
    double Function(double) curva,
  ) {
    if (t1 == t0) return t <= t0 ? v0 : v1;
    final k = ((t - t0) / (t1 - t0)).clamp(0.0, 1.0);
    return v0 + (v1 - v0) * curva(k);
  }

  Object _binario(String op, _No esqNo, _No dirNo, _Token tok) {
    // Curto-circuito antes de avaliar o lado direito.
    if (op == '&&') {
      return _verdade(_no(esqNo)) ? (_verdade(_no(dirNo)) ? 1.0 : 0.0) : 0.0;
    }
    if (op == '||') {
      return _verdade(_no(esqNo)) ? 1.0 : (_verdade(_no(dirNo)) ? 1.0 : 0.0);
    }
    final e = _no(esqNo);
    final d = _no(dirNo);
    if (op == '+' && (e is String || d is String)) {
      return '${_texto(e)}${_texto(d)}';
    }
    if (op == '==') return _iguais(e, d) ? 1.0 : 0.0;
    if (op == '!=') return _iguais(e, d) ? 0.0 : 1.0;

    // Vetor com vetor, e vetor com numero: e o que faz `position + [10,0]`
    // funcionar como no After Effects.
    if (e is List || d is List) {
      final a = e is List ? e : null;
      final b = d is List ? d : null;
      final n = math.max(a?.length ?? 0, b?.length ?? 0);
      return [
        for (var i = 0; i < n; i++)
          _conta(
            op,
            a == null ? _num(e, tok) : _num(a[i], tok),
            b == null ? _num(d, tok) : _num(b[i], tok),
            tok,
          ),
      ];
    }
    return _conta(op, _num(e, tok), _num(d, tok), tok);
  }

  double _conta(String op, double a, double b, _Token tok) => switch (op) {
    '+' => a + b,
    '-' => a - b,
    '*' => a * b,
    '/' => b == 0 ? 0 : a / b,
    '%' => b == 0 ? 0 : a % b,
    '<' => a < b ? 1 : 0,
    '>' => a > b ? 1 : 0,
    '<=' => a <= b ? 1 : 0,
    '>=' => a >= b ? 1 : 0,
    _ => throw ExpressionError(
      'Operador "$op" desconhecido',
      linha: tok.linha,
      coluna: tok.coluna,
    ),
  };

  static bool _iguais(Object a, Object b) {
    if (a is String || b is String) return _texto(a) == _texto(b);
    if (a is double && b is double) return a == b;
    return a == b;
  }

  static bool _verdade(Object v) {
    if (v is double) return v != 0;
    if (v is String) return v.isNotEmpty;
    if (v is List) return v.isNotEmpty;
    return false;
  }

  static String _texto(Object v) {
    if (v is String) return v;
    if (v is double) {
      return v == v.roundToDouble() && v.abs() < 1e15
          ? v.toInt().toString()
          : v.toString();
    }
    if (v is List) return v.map((e) => _texto(e as Object)).join(',');
    return '$v';
  }

  double _num(Object v, _Token? tok, [double padrao = double.nan]) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is List && v.isNotEmpty) return _num(v.first, tok, padrao);
    if (v is String) {
      final p = double.tryParse(v);
      if (p != null) return p;
    }
    if (!padrao.isNaN) return padrao;
    throw ExpressionError(
      'Esperava um numero aqui',
      linha: tok?.linha ?? 1,
      coluna: tok?.coluna ?? 1,
    );
  }
}

/// Compila e avalia numa chamada. Para o caminho quente — por caractere,
/// por quadro — compile UMA vez e reuse o [CompiledExpression].
ExpressionResult avaliarExpressao(String fonte, ExpressionContext ctx) {
  final (prog, erro) = CompiledExpression.tentar(fonte);
  if (prog == null) return ExpressionResult.falha(erro!);
  return ExpressionEvaluator(prog, ctx).avaliar();
}
