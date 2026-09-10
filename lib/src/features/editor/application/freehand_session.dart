import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ferramenta temporária da sessão do editor; nunca pertence ao projeto salvo.
final freehandRequestProvider = StateProvider.autoDispose<bool>((ref) => false);

/// Quadros fantasma para desenhar/animar à mão: 0 desliga a comparação.
final onionSkinProvider = StateProvider.autoDispose<int>((ref) => 0);

/// DESENHO VETORIAL: a caneta que coloca vertice a vertice.
///
/// Irma do desenho a mao livre e diferente dele: o traco livre segue o
/// dedo e depois e simplificado; a caneta coloca CANTOS exatos, um
/// toque por vertice, e a pessoa decide quando fechar a forma. Sao as
/// duas entradas que a referencia poe lado a lado no seletor.
final desenhoVetorialProvider = StateProvider.autoDispose<bool>((ref) => false);
