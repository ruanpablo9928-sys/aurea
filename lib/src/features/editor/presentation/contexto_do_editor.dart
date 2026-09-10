import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/editor_controller.dart';
import '../domain/layer.dart';
import 'widgets/controles_da_camada.dart';
import 'widgets/editor_de_curva.dart';
import 'widgets/painel_da_camada.dart';
import 'widgets/painel_de_cor.dart';
import 'widgets/painel_de_mascaras.dart';
import 'widgets/painel_de_transformacao.dart';
import 'widgets/visao_geral_das_camadas.dart';

/// ONDE EU ESTOU — uma resposta, num lugar so.
///
/// A especificacao `Aurea_UI_Somente_Alight_Motion_Video.pdf` (pagina 7)
/// exige "uma fonte de verdade para selecao e painel ativo". Antes deste
/// arquivo a resposta estava espalhada por onze `StateProvider`
/// independentes, e a CADEIA DE PRIORIDADE entre eles estava copiada em
/// tres lugares: no cabecalho da tela (`editor_screen.dart`), na conta de
/// altura (`alturaDaFerramentaAberta`) e no painel sobreposto. Tres
/// copias da mesma regra sempre acabam discordando — e discordavam: com
/// uma familia aberta, trocar de camada deixava o titulo da familia
/// ANTIGA no cabecalho enquanto o painel ja desenhava a grade da camada
/// nova.
///
/// Os `StateProvider` continuam sendo os donos do dado. O que este
/// arquivo acrescenta e a LEITURA: um valor derivado que diz em que
/// contexto a tela esta, e um `FocoDoEditor` que diz sobre o que o
/// proximo gesto age.
enum ContextoDoEditor {
  /// Nada aberto. A area inferior e a timeline geral e o `+` esta no
  /// canto. E o estado 00:00 da referencia.
  projeto,

  /// Uma camada selecionada, com a grade de acoes DO TIPO dela. A faixa
  /// de cima passa a ser da camada: nome, parent, apagar e o `...`.
  /// E o estado 00:40 da referencia.
  camada,

  /// Uma familia aberta dentro da camada (cor, transformacao, efeitos,
  /// opacidade...). A faixa de cima vira `‹` mais o nome da familia.
  familia,

  /// A curva de gradacao de um intervalo. Abre POR DENTRO de uma
  /// familia, e por isso vem antes dela na cadeia: quem esta na frente
  /// e quem nomeia a barra.
  curva,

  /// Varias camadas juntas. O conjunto muda o que todo gesto faz, entao
  /// ele tem contexto proprio.
  selecao,

  /// Os ajustes da composicao — o que nao pertence a camada nenhuma.
  composicao,
}

/// A CADEIA DE PRIORIDADE, escrita UMA vez.
///
/// A ordem nao e arbitraria: e a ordem de quem esta na frente na tela.
/// A curva cobre a familia, a familia cobre a camada, a camada cobre o
/// projeto. Quem cobre, nomeia.
ContextoDoEditor _contexto(Ref ref) {
  if (ref.watch(curvaEmEdicaoProvider) != null) return ContextoDoEditor.curva;
  final estado = ref.watch(estadoDoPainelProvider);
  if (estado == EstadoDoPainel.composicao) return ContextoDoEditor.composicao;
  if (estado == EstadoDoPainel.selecao &&
      ref.watch(multiSelectProvider).length >= 2) {
    return ContextoDoEditor.selecao;
  }
  if (estado == EstadoDoPainel.categoria &&
      ref.watch(categoriaAbertaProvider) != null) {
    return ContextoDoEditor.familia;
  }
  if (estado == EstadoDoPainel.categorias &&
      ref.watch(selectedLayerProvider) != null) {
    return ContextoDoEditor.camada;
  }
  return ContextoDoEditor.projeto;
}

/// Em que contexto a tela esta. Leia por aqui; nao refaca a cadeia.
final contextoDoEditorProvider = Provider<ContextoDoEditor>(_contexto);

/// A SOBREPOSICAO ABERTA, se houver.
///
/// Menu, modal e ajustes sao OVERLAY: eles nao trocam o contexto de
/// baixo, ficam por cima dele, e fechar tem de devolver exatamente o
/// estado anterior (PDF, pagina 7). Por isso vivem num provider
/// separado, e nao como mais um caso de [ContextoDoEditor].
enum SobreposicaoDoEditor { nenhuma, adicao, escolhaDePai, menuDaCamada }

final sobreposicaoDoEditorProvider = Provider<SobreposicaoDoEditor>((ref) {
  if (ref.watch(barraDeAdicaoAbertaProvider)) {
    return SobreposicaoDoEditor.adicao;
  }
  if (ref.watch(escolhendoPaiProvider)) {
    return SobreposicaoDoEditor.escolhaDePai;
  }
  if (ref.watch(menuDaCamadaAbertoProvider)) {
    return SobreposicaoDoEditor.menuDaCamada;
  }
  return SobreposicaoDoEditor.nenhuma;
});

/// O MENU DE TRES PONTOS DO CABECALHO DA CAMADA esta aberto?
///
/// Overlay, como os outros: fechar devolve o contexto de camada intacto.
final menuDaCamadaAbertoProvider = StateProvider<bool>((ref) => false);

/// SOBRE O QUE O PROXIMO GESTO AGE.
///
/// A edicao pendente (`docs/keyframe-explicito.md`) vale para UM
/// controle, num instante. Trocar de camada, de familia, de submodo, de
/// efeito, de mascara ou de parametro muda o que o losango mira — e um
/// losango nunca pode cravar o valor de outra coisa.
///
/// Isto era uma lista de dez providers escrita a mao em
/// `editor_screen.dart`, e uma lista escrita a mao esquece. Virou um
/// VALOR: se o foco mudou, mudou; nao ha o que esquecer.
@immutable
class FocoDoEditor {
  const FocoDoEditor({
    required this.contexto,
    required this.camadaId,
    required this.categoriaId,
    required this.submodo,
    required this.efeitoId,
    required this.parametroId,
    required this.mascaraId,
    required this.parametroDaMascara,
    required this.itemDaCor,
    required this.parametroDaCor,
  });

  final ContextoDoEditor contexto;
  final String? camadaId;
  final String? categoriaId;
  final ModoDeTransformacao submodo;
  final String? efeitoId;
  final String? parametroId;
  final String? mascaraId;
  final String? parametroDaMascara;
  final String? itemDaCor;
  final String? parametroDaCor;

  @override
  bool operator ==(Object other) =>
      other is FocoDoEditor &&
      other.contexto == contexto &&
      other.camadaId == camadaId &&
      other.categoriaId == categoriaId &&
      other.submodo == submodo &&
      other.efeitoId == efeitoId &&
      other.parametroId == parametroId &&
      other.mascaraId == mascaraId &&
      other.parametroDaMascara == parametroDaMascara &&
      other.itemDaCor == itemDaCor &&
      other.parametroDaCor == parametroDaCor;

  @override
  int get hashCode => Object.hash(
    contexto,
    camadaId,
    categoriaId,
    submodo,
    efeitoId,
    parametroId,
    mascaraId,
    parametroDaMascara,
    itemDaCor,
    parametroDaCor,
  );
}

final focoDoEditorProvider = Provider<FocoDoEditor>(
  (ref) => FocoDoEditor(
    contexto: ref.watch(contextoDoEditorProvider),
    camadaId: ref.watch(selectedLayerProvider),
    categoriaId: ref.watch(categoriaAbertaProvider),
    submodo: ref.watch(modoDeTransformacaoProvider),
    efeitoId: ref.watch(efeitoAbertoProvider),
    parametroId: ref.watch(parametroAbertoProvider),
    mascaraId: ref.watch(mascaraAbertaProvider),
    parametroDaMascara: ref.watch(parametroDaMascaraProvider),
    itemDaCor: ref.watch(itemDaCorProvider),
    parametroDaCor: ref.watch(parametroDaCorProvider),
  ),
);

/// A VISTA DA PREVIA. Campo do contrato minimo de estado (PDF, pagina
/// 7) que nao tinha nome no Aurea.
///
/// `composicao` e o quadro do projeto. `camada` isola a camada
/// selecionada — util para ver o que uma mascara esta fazendo sem o
/// resto por cima. E extensao do Aurea; nasce sempre em `composicao`.
enum VistaDaPrevia { composicao, camada }

final vistaDaPreviaProvider = StateProvider<VistaDaPrevia>(
  (ref) => VistaDaPrevia.composicao,
);

/// A ROLAGEM DA LINHA DO TEMPO, em segundos do projeto.
///
/// Tambem era um campo sem nome: o cabecote fica preso em
/// `MapaDoTempo.fracaoDoCabecote` e o conteudo desliza por baixo dele,
/// entao a rolagem era DERIVADA do tempo e nao existia como estado. Ela
/// precisa existir para "voltar de um subpainel nao pode perder o
/// playhead nem a posicao da timeline" ser testavel.
final rolagemDaLinhaDoTempoProvider = StateProvider<Duration>(
  (ref) => Duration.zero,
);

/// O MODO DA LINHA DO TEMPO QUE VALE AGORA.
///
/// No AM a troca e CONSEQUENCIA da selecao: no contexto de projeto a
/// area inferior e a pilha; no contexto de camada e a faixa daquela
/// camada. No Aurea a troca era um interruptor manual no cabecalho, que
/// ficava ligado mesmo sem camada selecionada.
///
/// PRECEDENCIA, explicita: o contexto manda. O interruptor manual
/// (`modoDaLinhaDoTempoProvider`, extensao do Aurea) so decide no
/// contexto de projeto, onde o AM nao tem opiniao porque nao tem o
/// recurso.
final modoEfetivoProvider = Provider<ModoDaLinhaDoTempo>((ref) {
  switch (ref.watch(contextoDoEditorProvider)) {
    case ContextoDoEditor.camada:
    case ContextoDoEditor.familia:
    case ContextoDoEditor.curva:
      return ModoDaLinhaDoTempo.detalhado;
    case ContextoDoEditor.projeto:
    case ContextoDoEditor.selecao:
    case ContextoDoEditor.composicao:
      return ref.watch(modoDaLinhaDoTempoProvider);
  }
});

/// SELECIONAR UMA CAMADA — um gesto, um estado novo, de uma vez.
///
/// No AM (V 00:40) tocar numa camada da timeline troca o cabecalho, a
/// area inferior e o painel ao mesmo tempo. No Aurea eram DOIS toques:
/// o primeiro so escrevia `selectedLayerProvider` e a tela nao mudava
/// nada; o segundo abria o painel. Entre um e outro nao havia sinal de
/// que existia um contexto para entrar.
///
/// A INVARIANTE que esta funcao protege: NUNCA REABRIR UM PAINEL DO
/// OBJETO ANTERIOR. Trocar de camada com "Opacidade" aberta e um fluxo
/// real — fechar a familia a cada troca obrigaria a reabrir toda vez. A
/// regra e por EXISTENCIA DA CATEGORIA, e nao por identidade da camada:
/// se a camada nova tambem tem aquela familia, ela segue aberta; se nao
/// tem, cai na grade dela. O que nao pode acontecer e o cabecalho dizer
/// "Cor e preenchimento" enquanto o painel mostra a grade de um audio.
void selecionarCamada(WidgetRef ref, String id) {
  final anterior = ref.read(selectedLayerProvider);
  ref.read(selectedLayerProvider.notifier).state = id;
  // A CURVA MORRE NA TROCA: ela e de um intervalo de uma propriedade de
  // UMA camada. Mante-la aberta apontaria para keyframes que sairam da
  // tela.
  if (anterior != id) {
    ref.read(curvaEmEdicaoProvider.notifier).state = null;
  }
  final aberta = ref.read(categoriaAbertaProvider);
  final estado = ref.read(estadoDoPainelProvider);
  if (estado == EstadoDoPainel.categoria && aberta != null) {
    final camada = ref
        .read(editorControllerProvider)
        .layers
        .where((l) => l.id == id)
        .firstOrNull;
    if (camada != null && _temCategoria(camada, aberta)) {
      // A familia continua aberta, agora sobre a camada nova. E o caso
      // bom: comparar a opacidade de duas camadas sem sair do controle.
      return;
    }
  }
  abrirFerramentasDaCamada(ref);
}

bool _temCategoria(Layer camada, String id) =>
    categoriasDaCamada(camada).any((c) => c.id == id);

/// DESSELECIONAR: volta ao contexto de projeto sem mexer no projeto.
void limparContextoDeCamada(WidgetRef ref) {
  ref.read(selectedLayerProvider.notifier).state = null;
  ref.read(curvaEmEdicaoProvider.notifier).state = null;
  ref.read(menuDaCamadaAbertoProvider.notifier).state = false;
  fecharFerramenta(ref);
}
