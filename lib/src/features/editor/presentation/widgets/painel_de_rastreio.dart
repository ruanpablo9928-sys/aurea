import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/camera_track_service.dart';
import '../../application/editor_controller.dart';
import '../../domain/camera_solver3d.dart';
import '../../domain/layer.dart';

/// O que a pessoa escolheu antes de mandar rastrear.
final modoDoSolveProvider = StateProvider<ModoDoSolve>(
  (ref) => ModoDoSolve.equilibrado,
);
final tipoDeTomadaProvider = StateProvider<TipoDeTomada>(
  (ref) => TipoDeTomada.auto,
);

/// O erro da ultima tentativa, por camada.
final erroDoRastreioProvider = StateProvider<String?>((ref) => null);

/// RASTREAR A CAMERA DO VIDEO.
///
/// O solver esta inteiro, vivo e testado — essencial, homografia, SVD,
/// estimativa de foco, nuvem de pontos, qualidade por ponto, e a
/// RECUSA HONESTA de tripe e cena plana — e o unico caminho ate ele,
/// `rastrearCamera3D`, nao tinha um chamador. A tela dedicada morreu
/// com a UI antiga (`rastreio3d_screen.dart`, commit `7fe26b6`) e nunca
/// voltou.
///
/// A ficha depois do solve nao e enfeite: erro em pixels, quadros e
/// pontos sao o que separa "grudou" de "escorrega e da para ver". Sem
/// eles, so se descobre que o rastreio era ruim depois de colar um
/// objeto e exportar.
class PainelDeRastreio extends ConsumerStatefulWidget {
  const PainelDeRastreio({super.key, required this.camada});

  final Layer camada;

  @override
  ConsumerState<PainelDeRastreio> createState() => _PainelDeRastreioState();
}

class _PainelDeRastreioState extends ConsumerState<PainelDeRastreio> {
  final _servico = CameraTrackService.instance;

  @override
  void initState() {
    super.initState();
    _servico.revision.addListener(_mudou);
    _servico.progress.addListener(_mudou);
    _servico.etapa.addListener(_mudou);
  }

  @override
  void dispose() {
    _servico.revision.removeListener(_mudou);
    _servico.progress.removeListener(_mudou);
    _servico.etapa.removeListener(_mudou);
    super.dispose();
  }

  void _mudou() {
    if (mounted) setState(() {});
  }

  Future<void> _rastrear() async {
    ref.read(erroDoRastreioProvider.notifier).state = null;
    setState(() {});
    try {
      await ref
          .read(editorControllerProvider.notifier)
          .rastrearCamera3D(
            widget.camada.id,
            modo: ref.read(modoDoSolveProvider),
            tipoDeTomada: ref.read(tipoDeTomadaProvider),
          );
    } on RastreioException catch (e) {
      // A RECUSA E UM RESULTADO, e nao um defeito. Tripe e cena plana
      // nao TEM solucao 3D — o solver sabe disso e diz; esconder a
      // mensagem faria a pessoa tentar de novo para sempre.
      ref.read(erroDoRastreioProvider.notifier).state = e.mensagem;
    } catch (e) {
      ref.read(erroDoRastreioProvider.notifier).state = '$e';
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.read(editorControllerProvider.notifier);
    final id = widget.camada.id;
    final rodando = _servico.isRunning(id);
    final solucao = _servico.dataFor(id);
    final erro = ref.watch(erroDoRastreioProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Titulo('Como analisar'),
        _Grade<ModoDoSolve>(
          prefixo: 'Modo',
          itens: [for (final m in ModoDoSolve.values) (m.emPalavras, m)],
          atual: ref.watch(modoDoSolveProvider),
          aoTocar: (m) => ref.read(modoDoSolveProvider.notifier).state = m,
        ),
        _Aviso(ref.watch(modoDoSolveProvider).explicacao),
        _Grade<TipoDeTomada>(
          prefixo: 'Tomada',
          itens: [for (final t in TipoDeTomada.values) (t.emPalavras, t)],
          atual: ref.watch(tipoDeTomadaProvider),
          aoTocar: (t) => ref.read(tipoDeTomadaProvider.notifier).state = t,
        ),
        if (rodando) ...[
          const _Titulo('Analisando'),
          _Barra(progresso: _servico.progress.value),
          _Aviso(
            _servico.etapa.value.isEmpty
                ? 'Lendo o video...'
                : _servico.etapa.value,
          ),
        ] else
          _Acao(
            icone: Icons.travel_explore_rounded,
            rotulo: solucao == null
                ? 'Rastrear a camera'
                : 'Rastrear de novo',
            detalhe: 'Leva dezenas de segundos e le o video inteiro',
            aoTocar: _rastrear,
          ),
        if (erro != null) ...[
          const _Titulo('Nao deu'),
          _Aviso(erro),
        ],
        if (solucao != null) ...[
          const _Titulo('O que saiu'),
          // O ERRO EM PIXELS E O NUMERO QUE IMPORTA. Abaixo de ~1 px o
          // objeto colado gruda; acima de ~3 px ele escorrega e da para
          // ver. Guardar isso so no objeto seria descobrir tarde.
          _Ficha('Erro medio', '${solucao.erroPixels.toStringAsFixed(2)} px'),
          _Ficha('Qualidade', _qualidade(solucao.erroPixels)),
          _Ficha('Quadros', '${solucao.quadros} a ${solucao.fps} qps'),
          _Ficha('Pontos seguidos', '${solucao.pontosSeguidos}'),
          _Ficha('Tomada', solucao.tipoDeTomada.emPalavras),
          _Ficha(
            'Lente',
            '${(36 * solucao.focalPx / solucao.largura).round()} mm',
          ),
          _Acao(
            icone: Icons.view_in_ar_rounded,
            rotulo: 'Criar a cena 3D em cima do clipe',
            detalhe: 'Camera com keyframes reais, e a nuvem de pontos junto',
            aoTocar: () => c.criarCenaDoRastreio(id, solucao),
          ),
          _Acao(
            icone: Icons.view_in_ar_outlined,
            rotulo: 'Criar sem a nuvem de pontos',
            detalhe: 'So a camera — mais leve para desenhar',
            aoTocar: () =>
                c.criarCenaDoRastreio(id, solucao, comNuvem: false),
          ),
        ],
      ],
    );
  }

  /// O erro em palavras. O numero e exato e nao diz nada sozinho para
  /// quem nunca viu um solve.
  static String _qualidade(double px) {
    if (px <= 1) return 'Gruda (abaixo de 1 px)';
    if (px <= 2) return 'Boa';
    if (px <= 3) return 'Aceitavel';
    return 'Escorrega — da para ver o objeto deslizar';
  }
}

class _Barra extends StatelessWidget {
  const _Barra({required this.progresso});

  final double progresso;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    label: 'Progresso do rastreio',
    value: '${(progresso * 100).round()}%',
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: LayoutBuilder(
        builder: (context, limites) => Stack(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: AmColors.chip,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Container(
              height: 6,
              width: limites.maxWidth * progresso.clamp(0.0, 1.0),
              decoration: BoxDecoration(
                color: AmColors.accent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Ficha extends StatelessWidget {
  const _Ficha(this.rotulo, this.valor);

  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    label: rotulo,
    value: valor,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              rotulo,
              style: const TextStyle(fontSize: 12, color: AmColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AmColors.text,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Grade<T> extends StatelessWidget {
  const _Grade({
    required this.prefixo,
    required this.itens,
    required this.atual,
    required this.aoTocar,
  });

  final String prefixo;
  final List<(String, T)> itens;
  final T atual;
  final void Function(T) aoTocar;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (nome, valor) in itens)
          Semantics(
            container: true,
            excludeSemantics: true,
            button: true,
            selected: valor == atual,
            label: '$prefixo $nome',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => aoTocar(valor),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: valor == atual ? AmColors.chip : null,
                  borderRadius: BorderRadius.circular(8),
                  border: valor == atual
                      ? null
                      : Border.all(color: AmColors.hairline),
                ),
                child: Text(
                  nome,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: valor == atual ? AmColors.accent : AmColors.text,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _Acao extends StatelessWidget {
  const _Acao({
    required this.icone,
    required this.rotulo,
    required this.aoTocar,
    this.detalhe,
  });

  final IconData icone;
  final String rotulo;
  final VoidCallback aoTocar;
  final String? detalhe;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: true,
    label: rotulo,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aoTocar,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icone, size: 19, color: AmColors.text),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rotulo,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AmColors.text,
                    ),
                  ),
                  if (detalhe != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        detalhe!,
                        style: TextStyle(
                          fontSize: 10,
                          color: AmColors.muted.withValues(alpha: .7),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 12, 0, 6),
    child: Text(
      texto,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AmColors.muted,
      ),
    ),
  );
}

class _Aviso extends StatelessWidget {
  const _Aviso(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 2, 0, 6),
    child: Text(
      texto,
      style: const TextStyle(fontSize: 11, color: AmColors.muted, height: 1.4),
    ),
  );
}
