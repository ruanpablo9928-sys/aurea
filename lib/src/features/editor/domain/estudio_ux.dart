/// A UX DO ESTUDIO 3D, NA PARTE QUE NAO PRECISA DE TELA.
///
/// Encaixe na grade, trava de eixo, a hierarquia da cena em ordem de
/// arvore, a busca por nome e as dicas de boas-vindas. Tudo o que o
/// Estudio mostra vem daqui — e tudo o que esta aqui se testa sem
/// widget.
library;

import 'camera3d.dart';
import 'scene3d.dart';

// ------------------------------------------------------------ grade

/// ENCAIXAR NA GRADE: o multiplo do passo mais perto do valor.
double encaixar(double v, double passo) =>
    passo <= 0 ? v : (v / passo).round() * passo;

/// Os passos da grade, por ferramenta. Em unidades da cena (o cubo
/// padrao mede 100), graus e fator de escala.
const passoDeMover = 10.0;
const passoDeGirar = 15.0;
const passoDeEscalar = 0.25;

Vec3 encaixarVec3(Vec3 v, double passo) =>
    Vec3(encaixar(v.x, passo), encaixar(v.y, passo), encaixar(v.z, passo));

// ------------------------------------------------------------ eixo

/// EIXO TRAVADO no arrasto: o deslocamento so anda nele.
enum EixoTravado { livre, x, y, z }

String eixoLabel(EixoTravado e) => switch (e) {
  EixoTravado.livre => 'Livre',
  EixoTravado.x => 'X',
  EixoTravado.y => 'Y',
  EixoTravado.z => 'Z',
};

Vec3 travarEixo(Vec3 v, EixoTravado eixo) => switch (eixo) {
  EixoTravado.livre => v,
  EixoTravado.x => Vec3(v.x, 0, 0),
  EixoTravado.y => Vec3(0, v.y, 0),
  EixoTravado.z => Vec3(0, 0, v.z),
};

// ------------------------------------------------------------ ferramentas

/// As quatro ferramentas da barra de baixo. SELECIONAR e a de
/// navegacao: um dedo sempre gira a camera, e o toque escolhe.
enum FerramentaDoEstudio { selecionar, mover, girar, escalar }

String ferramentaLabel(FerramentaDoEstudio f) => switch (f) {
  FerramentaDoEstudio.selecionar => 'Selecionar',
  FerramentaDoEstudio.mover => 'Mover',
  FerramentaDoEstudio.girar => 'Girar',
  FerramentaDoEstudio.escalar => 'Escalar',
};

// ------------------------------------------------------------ hierarquia

enum TipoDeItem { no, luz, camera }

/// Uma linha do painel da cena.
class ItemDaCena {
  const ItemDaCena({
    required this.id,
    required this.nome,
    required this.tipo,
    this.nivel = 0,
    this.visivel = true,
    this.travado = false,
    this.grupo = false,
    this.ativo = false,
  });

  final String id;
  final String nome;
  final TipoDeItem tipo;

  /// Profundidade na arvore (filho de filho = 2).
  final int nivel;
  final bool visivel;
  final bool travado;

  /// Um nulo 3D: o pivo de um grupo.
  final bool grupo;

  /// A camera no ar / o no selecionado.
  final bool ativo;
}

/// A HIERARQUIA em ordem de arvore: cada pai seguido dos filhos, com o
/// nivel. Um no cujo pai nao existe mais aparece na raiz — nao some.
/// Depois dos nos vem as luzes e as cameras.
List<ItemDaCena> hierarquiaDaCena(
  Scene3D cena, {
  List<Light3D> luzes = const [],
  List<Camera3D> cameras = const [],
  String? cameraAtiva,
  String? selecionado,
}) {
  final ids = {for (final n in cena.nodes) n.id};
  final saida = <ItemDaCena>[];
  final vistos = <String>{};

  void desce(String? pai, int nivel) {
    for (final n in cena.nodes) {
      final paiDele = n.parentId != null && ids.contains(n.parentId)
          ? n.parentId
          : null;
      if (paiDele != pai || !vistos.add(n.id)) continue;
      saida.add(
        ItemDaCena(
          id: n.id,
          nome: n.name,
          tipo: TipoDeItem.no,
          nivel: nivel,
          visivel: n.visible,
          travado: n.locked,
          grupo: n.isNull,
          ativo: n.id == selecionado,
        ),
      );
      if (nivel < 32) desce(n.id, nivel + 1);
    }
  }

  desce(null, 0);
  for (final l in luzes) {
    saida.add(
      ItemDaCena(
        id: l.id,
        nome: luzLabel(l.kind),
        tipo: TipoDeItem.luz,
        ativo: l.id == selecionado,
      ),
    );
  }
  for (final c in cameras) {
    saida.add(
      ItemDaCena(
        id: c.id,
        nome: c.name,
        tipo: TipoDeItem.camera,
        ativo: c.id == cameraAtiva,
      ),
    );
  }
  return saida;
}

String luzLabel(Light3DKind k) => switch (k) {
  Light3DKind.directional => 'Luz direcional',
  Light3DKind.point => 'Luz de ponto',
  Light3DKind.ambient => 'Luz ambiente',
  Light3DKind.spot => 'Luz spot',
};

/// BUSCAR pelo nome: sem caixa, sem acento, por pedaco.
List<ItemDaCena> buscarNaCena(List<ItemDaCena> itens, String termo) {
  final t = _semAcento(termo.trim().toLowerCase());
  if (t.isEmpty) return itens;
  return [
    for (final i in itens)
      if (_semAcento(i.nome.toLowerCase()).contains(t)) i,
  ];
}

String _semAcento(String s) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const para = 'aaaaaeeeeiiiiooooouuuucn';
  final b = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    final i = de.indexOf(ch);
    b.write(i < 0 ? ch : para[i]);
  }
  return b.toString();
}

// ------------------------------------------------------------ vistas

/// As vistas predefinidas do menu da camera, na ordem em que aparecem.
const vistasPredefinidas = [
  SceneView.front,
  SceneView.back,
  SceneView.left,
  SceneView.right,
  SceneView.top,
  SceneView.bottom,
];

// ------------------------------------------------------------ dicas

/// AS DICAS DE BOAS-VINDAS: quatro, curtas, uma vez.
const dicasDoEstudio = [
  'Toque num objeto para selecionar. Toque duas vezes nele para a '
      'camera enquadrar.',
  'Um dedo gira a camera. Dois dedos deslizam. A pinca aproxima.',
  'Mover, Girar e Escalar ficam embaixo: escolha um e arraste o objeto.',
  'O botao de tres pontos guarda o resto: cena, cameras, vistas e o modo '
      'avancado.',
];
