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
  editarForma,
  presets,
  efeitos,
}

/// O teto da grade. Nao e decoracao: o teste falha se alguem passar disso.
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
      nullAndClone;

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
      if (shapes && layer is ShapeLayer) AmSecao.editarForma,
      if (layer is! NullLayer &&
          (completo || effects || apple || (text && layer is TextLayer)))
        AmSecao.presets,
      if (effects && layer is! NullLayer) AmSecao.efeitos,
    };
  }
}
