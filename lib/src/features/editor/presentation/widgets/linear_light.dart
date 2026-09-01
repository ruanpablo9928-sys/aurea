import 'dart:ui' as ui;

/// A FAMILIA DE LUZ, EM ESPACO LINEAR.
///
/// Borrar, somar e misturar sao contas de LUZ, e luz soma em espaco
/// linear. O valor guardado numa imagem nao e luz: e um numero corrigido
/// para o olho. Borrar esse numero direto e o que faz o glow sair
/// acinzentado e o desfoque deixar halo escuro na borda.
///
/// Aqui o filtro pedido e embrulhado entre desfazer e refazer a curva do
/// sRGB — tres passes na GPU, encadeados pelo proprio motor:
///
///     sRGB -> linear   →   o filtro   →   linear -> sRGB
///
/// Sem suporte (aparelho sem Impeller, ou o shader nao carregou), o
/// filtro volta EXATAMENTE como veio. Um efeito com a matematica antiga
/// e melhor do que nenhum efeito.
class LinearLight {
  LinearLight._();

  static ui.FragmentProgram? _program;
  static bool _tried = false;

  static Future<void> warmUp() async {
    if (_tried) return;
    _tried = true;
    try {
      _program = await ui.FragmentProgram.fromAsset('shaders/gamma.frag');
    } catch (_) {
      _program = null;
    }
  }

  /// Se da para trabalhar em linear neste aparelho.
  static bool get ready =>
      _program != null && ui.ImageFilter.isShaderFilterSupported;

  static ui.ImageFilter? _curva(double mode, ui.Size size) {
    final p = _program;
    if (p == null) return null;
    try {
      final shader = p.fragmentShader()
        ..setFloat(0, size.width <= 0 ? 1 : size.width)
        ..setFloat(1, size.height <= 0 ? 1 : size.height)
        ..setFloat(2, mode);
      return ui.ImageFilter.shader(shader);
    } catch (_) {
      // Aparelho sem suporte a shader como filtro.
      return null;
    }
  }

  /// Embrulha [inner] para que ele aconteca em espaco LINEAR.
  ///
  /// [size] e o tamanho em que o filtro vai rodar — o shader precisa
  /// dele para achar o pixel.
  static ui.ImageFilter wrap(ui.ImageFilter inner, ui.Size size) {
    if (!ready) return inner;
    final paraLinear = _curva(0, size);
    final paraSrgb = _curva(1, size);
    if (paraLinear == null || paraSrgb == null) return inner;

    // compose(outer, inner) = outer(inner(x)). Lendo de dentro para
    // fora: primeiro tira a curva, depois filtra, depois devolve a curva.
    return ui.ImageFilter.compose(
      outer: paraSrgb,
      inner: ui.ImageFilter.compose(outer: inner, inner: paraLinear),
    );
  }

  /// Desfoque gaussiano feito em espaco linear.
  ///
  /// O kernel e o do motor (normalizado por construcao — a soma dos
  /// pesos e 1, entao o desfoque nao clareia nem escurece). O que
  /// faltava era o espaco.
  static ui.ImageFilter blur({
    required double sigmaX,
    required double sigmaY,
    required ui.Size size,
    ui.TileMode tileMode = ui.TileMode.decal,
  }) =>
      wrap(
        ui.ImageFilter.blur(
            sigmaX: sigmaX, sigmaY: sigmaY, tileMode: tileMode),
        size,
      );
}
