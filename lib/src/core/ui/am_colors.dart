import 'dart:ui';

/// A PALETA DO EDITOR.
///
/// Os tons neutros foram MEDIDOS numa gravacao do Alight Motion em uso,
/// e nao escolhidos no olho (`docs/linha-do-tempo-alight.md`): fundo da
/// previa #121218, cromo #18181E, pilula de camada #242436, capsula do
/// tempo #242430. A diferenca entre eles e pequena de proposito — o
/// editor inteiro e quase preto para que a composicao, que e o unico
/// conteudo colorido da tela, seja a coisa mais brilhante que se ve.
///
/// AS CORES DE MARCA SAO AS DA AUREA, e nao as da referencia. Copiar
/// estrutura, medida e comportamento e aprender; copiar o verde da
/// concorrencia seria copiar identidade. O lima da logo ocupa o mesmo
/// lugar que o verde ocupa la: o botao de exportar.
abstract final class AmColors {
  /// O FUNDO ATRAS DA COMPOSICAO. Mais escuro que o cromo, para o quadro
  /// do projeto se destacar do que e ferramenta.
  static const Color bg = Color(0xFF121218);

  /// O CROMO: cabecalho, transporte, linha do tempo. Tudo que e
  /// ferramenta usa este tom, e por isso os tres blocos parecem uma peca
  /// so, que e o que eles sao.
  static const Color topBar = Color(0xFF18181E);
  static const Color panel = Color(0xFF18181E);
  static const Color panelHigh = Color(0xFF1E1E28);

  /// A CAPSULA DO TEMPO e os chips em geral.
  static const Color chip = Color(0xFF242430);

  /// A PILULA DA CAMADA: o olho e a cor, flutuando sobre a trilha.
  static const Color pilula = Color(0xFF242436);

  /// Keyframe, curva e realce de contexto (teal).
  static const Color accent = Color(0xFF1ED6B1);
  static const Color accentDim = Color(0xFF183F3C);

  /// ACAO (o lima da logo): Exportar, o "+", chips de acao. O teal fica
  /// com keyframe e curva; a acao e outra cor para nao se confundir com
  /// "esta animado".
  static const Color action = Color(0xFFB8FF3D);
  static const Color onAction = Color(0xFF0B0E12);
  static const Color actionDim = Color(0xFF2A3A16);

  /// Selecao e grupos (violeta da logo).
  static const Color selection = Color(0xFF7C62FF);

  /// Barras de camada com contraste para texto e keyframes.
  static const Color teal = Color(0xFF43B7C6);
  static const Color tealBright = Color(0xFF81D8E0);

  /// Marca de keyframe na regua.
  static const Color pink = Color(0xFFFF6B6B);

  /// O CABECOTE E BRANCO, como na referencia. Ele cruza trilhas de todas
  /// as cores: qualquer cor propria brigaria com alguma delas, e branco
  /// puro nao e usado em mais nada grande na tela.
  static const Color cabecote = Color(0xFFFFFFFF);

  static const Color text = Color(0xFFE9EDF2);
  static const Color muted = Color(0xFF8B94A3);
  static const Color hairline = Color(0x14FFFFFF);
}
