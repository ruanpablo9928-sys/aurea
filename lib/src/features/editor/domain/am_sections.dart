import '../../laboratory/domain/laboratory_level.dart';
import 'layer.dart';

/// AS SETE SECOES DA GRADE.
///
/// Regra da UI final: a interface tem tamanho fixo e as features entram
/// DENTRO dela. Sao sete secoes do Nivel 0 ao 9 — precisou de uma oitava,
/// alguma sai ou vira tipo de camada.
///
/// A visibilidade mora aqui, fora do widget, por dois motivos: e a unica
/// forma de CONTAR as secoes num teste (a regra "no maximo sete" so vale
/// se alguem conta), e e a unica forma de provar que nada aparece inerte
/// para um tipo de camada que nao usa aquilo.
enum AmSecao {
  moverTransformar,
  corPreenchimento,
  bordaSombra,
  mesclarOpacidade,
  // As duas do som. Nao sao uma oitava e uma nona secao na grade: sao
  // secoes DE TIPO DE CAMADA, a saida que a propria regra do minimalismo
  // preve. Nenhum tipo passa de sete.
  volume,
  fade,
  editarForma,
  /// O Modulo Grade do nulo. Nao e secao nova na grade de ninguem: e
  /// secao DE TIPO, e o nulo e o unico tipo que a mostra.
  clonar,
  presets,
  efeitos,
}

/// O teto da grade PARA UM TIPO DE CAMADA. Nao e decoracao: o teste falha
/// se alguem passar disso.
const int kAmMaximoSecoes = 7;

/// Quais niveis estao ligados no momento em que o menu abre.
class AmNiveis {
  const AmNiveis({
    this.completo = false,
    this.shapes = false,
    this.text = false,
    this.effects = false,
    this.masks = false,
    this.apple = false,
    this.captions = false,
    this.scene3d = false,
    this.nullAndClone = false,
    this.audio = false,
  });

  /// Modo Nucleo puro: nenhum nivel ligado.
  static const nucleo = AmNiveis();

  /// Os dez niveis ligados — o estado da tarefa de aceite do Nivel 10.1.
  static const tudo = AmNiveis(
    shapes: true,
    text: true,
    effects: true,
    masks: true,
    apple: true,
    captions: true,
    scene3d: true,
    nullAndClone: true,
    audio: true,
  );

  factory AmNiveis.de(
    bool Function(LaboratoryLevelId) liberado, {
    required bool completo,
  }) => AmNiveis(
    completo: completo,
    shapes: liberado(LaboratoryLevelId.shapes),
    text: liberado(LaboratoryLevelId.text),
    effects: liberado(LaboratoryLevelId.effects),
    masks: liberado(LaboratoryLevelId.mask),
    apple: liberado(LaboratoryLevelId.apple),
    captions: liberado(LaboratoryLevelId.captions),
    scene3d: liberado(LaboratoryLevelId.scene3d),
    nullAndClone: liberado(LaboratoryLevelId.nullAndClone),
    audio: liberado(LaboratoryLevelId.audio),
  );

  final bool completo;
  final bool shapes;
  final bool text;
  final bool effects;
  final bool masks;
  final bool apple;
  final bool captions;
  final bool scene3d;
  final bool nullAndClone;
  final bool audio;

  /// No Nucleo puro a grade encolhe para movimentacao e opacidade; qualquer
  /// nivel ligado ja pede a grade inteira.
  bool get gradeCompleta =>
      shapes ||
      text ||
      effects ||
      masks ||
      apple ||
      captions ||
      scene3d ||
      nullAndClone ||
      audio;

  /// AS SECOES QUE APARECEM PARA ESTA CAMADA.
  ///
  /// O que nao se aplica ao tipo nao entra: um Nulo nao tem cor, uma forma
  /// desenhada nao tem legenda. O lugar na grade continua reservado — o que
  /// nao acontece e um botao existir sem fazer nada.
  Set<AmSecao> visiveisPara(Layer layer) {
    if (!gradeCompleta) {
      return {
        AmSecao.moverTransformar,
        if (layer is! NullLayer) AmSecao.mesclarOpacidade,
      };
    }
    // A CAMADA DE AUDIO nao tem posicao, nem opacidade, nem cor: mover um
    // som na tela nao faz nada, e um controle que nao faz nada nao pode
    // aparecer. Ela mostra tres secoes, as do documento.
    if (audio && layer is AudioLayer) {
      return {AmSecao.volume, AmSecao.fade, AmSecao.efeitos};
    }
    // O NULO nao tem aparencia nenhuma: nao tem cor, borda, opacidade nem
    // efeito. Tem o transform (que e para o que ele existe) e a grade de
    // clones que ele controla.
    if (layer is NullLayer) {
      return {
        AmSecao.moverTransformar,
        if (nullAndClone) AmSecao.clonar,
      };
    }
    return {
      AmSecao.moverTransformar,
      if ((shapes && layer is ShapeLayer) ||
          (text && layer is TextLayer) ||
          (scene3d && (layer is Element3DLayer || layer is Scene3DLayer)))
        AmSecao.corPreenchimento,
      if (layer is! NullLayer &&
          (completo ||
              apple ||
              (shapes && layer is ShapeLayer) ||
              (captions && layer is CaptionLayer)))
        AmSecao.bordaSombra,
      if (layer is! NullLayer) AmSecao.mesclarOpacidade,
      // Video com som ganha as duas do audio — e a razao de a grade do
      // video bater exatamente em sete, e nao em oito.
      if (audio && layer is VideoLayer) ...[AmSecao.volume, AmSecao.fade],
      if (shapes && layer is ShapeLayer) AmSecao.editarForma,
      if (layer is! NullLayer &&
          (completo || effects || apple || (text && layer is TextLayer)))
        AmSecao.presets,
      // Efeito visual em camada de som nao desenha nada; a secao de
      // Efeitos do audio e outra, e vem com o nivel 11.
      if (effects && layer is! NullLayer && layer is! AudioLayer)
        AmSecao.efeitos,
    };
  }
}
