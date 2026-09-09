import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../editor/application/registro_de_travadas.dart';

/// O REGISTRO DE TRAVADAS, para ler no aparelho e me mandar.
///
/// A pergunta que tres tentativas de correcao nao conseguiram responder
/// de longe foi simples: no SEU aparelho, com o SEU projeto, o que
/// exatamente esta demorando? Esta tela responde com o que o proprio
/// aplicativo anotou enquanto travava.
///
/// Cada linha e um quadro que passou de 120 ms. Ela diz quanto foi
/// construcao (Dart, o mesmo fio que recebe o toque) e quanto foi
/// desenho (GPU), o que o aplicativo estava fazendo, e — o mais
/// importante — qual renderizador 3D estava em uso.
class TravadasScreen extends StatefulWidget {
  const TravadasScreen({super.key});

  @override
  State<TravadasScreen> createState() => _TravadasScreenState();
}

class _TravadasScreenState extends State<TravadasScreen> {
  @override
  Widget build(BuildContext context) {
    final travadas = RegistroDeTravadas.travadas;
    final causas = RegistroDeTravadas.porCausa();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Travadas'),
        actions: [
          IconButton(
            key: const ValueKey('travadas-copiar'),
            tooltip: 'Copiar tudo',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: RegistroDeTravadas.emTexto()),
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Registro copiado')));
            },
          ),
          IconButton(
            key: const ValueKey('travadas-limpar'),
            tooltip: 'Limpar',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () {
              RegistroDeTravadas.limpar();
              setState(() {});
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            'Quem esta desenhando a cena 3D agora',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          SelectableText(
            descreverMotor3D(),
            key: const ValueKey('travadas-motor'),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 22),
          if (travadas.isEmpty)
            Text(
              'Nenhum quadro passou de ${RegistroDeTravadas.limiteMs} ms '
              'desde que o aplicativo abriu. Use o projeto que trava e '
              'volte aqui.',
              key: const ValueKey('travadas-vazio'),
            )
          else ...[
            Text(
              'Por causa, do que mais pesou',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            for (final c in causas.take(6))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${c.somaMs.toString().padLeft(6)} ms em '
                  '${c.vezes.toString().padLeft(3)}x   ${c.oQue}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            const SizedBox(height: 22),
            Text(
              '${travadas.length} travadas, da mais recente',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            for (final t in travadas)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SelectableText(
                  t.linha,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
