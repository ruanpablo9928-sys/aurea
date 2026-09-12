import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ficha_do_selecionado.dart';
import 'folhas_do_estudio.dart';

Future<void> abrirFolhaDePropriedadesNova(
  BuildContext context,
  WidgetRef ref, {
  required String layerId,
  required Duration tempo,
  AbaDaFicha aba = AbaDaFicha.transformar,
}) => mostrarFolhaScene3D<void>(
  context,
  title: 'Propriedades',
  body: FolhaDePropriedades(layerId: layerId, tempo: tempo, aba: aba),
);

/// Uses the actual animated tracks, materials and texture controls.
class FolhaDePropriedades extends StatelessWidget {
  const FolhaDePropriedades({
    super.key,
    required this.layerId,
    required this.tempo,
    this.aba = AbaDaFicha.transformar,
  });
  final String layerId;
  final Duration tempo;
  final AbaDaFicha aba;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .60,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: FichaDoSelecionado(
        layerId: layerId,
        tempo: tempo,
        abaInicial: aba,
      ),
    ),
  );
}
