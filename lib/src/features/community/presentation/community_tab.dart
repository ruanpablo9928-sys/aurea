import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/snack.dart';
import '../../about/presentation/report_sheet.dart' show AureaAutor;
import '../application/comunidade_service.dart';
import '../application/conta_da_comunidade.dart';
import '../domain/moderacao.dart';
import '../domain/post_da_comunidade.dart';

/// A ABA COMUNIDADE — o mural do beta.
///
/// Tres coisas fazem um mural publico funcionar, e as tres estao aqui:
/// uma CONTA (quem assina), um FILTRO (o que entra) e MIDIA (o que se
/// mostra num app de video). Nada de curtida, seguidor ou notificacao:
/// isso e infraestrutura social, e so faz sentido depois que ha gente
/// postando.
class CommunityTab extends ConsumerStatefulWidget {
  const CommunityTab({super.key});

  @override
  ConsumerState<CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends ConsumerState<CommunityTab> {
  List<PostDaComunidade> _posts = const [];
  bool _carregando = true;

  ComunidadeService get _s => ComunidadeService.instance;

  @override
  void initState() {
    super.initState();
    _atualizar(daRede: true);
  }

  Future<void> _atualizar({required bool daRede}) async {
    if (mounted) setState(() => _carregando = true);
    final posts = await _s.carregar(daRede: daRede);
    if (!mounted) return;
    setState(() {
      _posts = posts;
      _carregando = false;
    });
  }

  /// Sem conta nao se publica — e a conta se cria em um passo, aqui
  /// mesmo, em vez de mandar a pessoa procurar outra aba.
  Future<bool> _garantirConta() async {
    if (ref.read(contaDaComunidadeProvider) != null) return true;
    final criou = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FolhaDaConta(),
    );
    return criou == true && ref.read(contaDaComunidadeProvider) != null;
  }

  Future<void> _compor() async {
    if (!await _garantirConta()) return;
    if (!mounted) return;
    final conta = ref.read(contaDaComunidadeProvider)!;
    final post = await showModalBottomSheet<PostDaComunidade>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _Compositor(conta: conta),
    );
    if (post == null) return;
    // GUARDA PRIMEIRO, MANDA DEPOIS.
    //
    // Nesta ordem o post nunca se perde: se a rede cair no meio, ele
    // ficou aqui e da para tentar de novo. Na ordem contraria, uma falha
    // apagaria o que a pessoa escreveu.
    await _s.publicar(post);
    await _atualizar(daRede: false);
    if (!mounted) return;
    AureaSnack.show(context, 'Publicando...');
    final erro = await _s.enviar(post, conta.id);
    if (!mounted) return;
    if (erro != null) {
      // O servidor recusou (ofensa, dado pessoal, limite) ou nao
      // respondeu. Nos dois casos o post continua aqui, marcado, e o
      // motivo e dito com as palavras dele.
      AureaSnack.show(context, erro, duration: const Duration(seconds: 6));
      return;
    }
    await _s.marcarEnviado(post.id);
    await _atualizar(daRede: true);
    if (!mounted) return;
    AureaSnack.show(
      context,
      'No mural. Pode levar um minuto para aparecer para os outros.',
      duration: const Duration(seconds: 5),
    );
  }

  /// TENTAR DE NOVO um post que ficou para tras.
  ///
  /// Serve para os dois casos em que ele fica: a rede caiu na hora de
  /// publicar, ou o servidor recusou e a pessoa corrigiu o texto por
  /// fora. Se falhar outra vez, cai no e-mail — um post escrito e um
  /// trabalho, e trabalho nao se joga fora por falta de sinal.
  Future<void> _reenviar(PostDaComunidade post) async {
    final conta = ref.read(contaDaComunidadeProvider);
    if (conta == null) return;
    AureaSnack.show(context, 'Publicando...');
    final erro = await _s.enviar(post, conta.id);
    if (!mounted) return;
    if (erro == null) {
      await _s.marcarEnviado(post.id);
      await _atualizar(daRede: true);
      if (!mounted) return;
      AureaSnack.show(context, 'No mural.');
      return;
    }
    AureaSnack.show(
      context,
      '$erro Mandando por e-mail.',
      duration: const Duration(seconds: 5),
    );
    await _enviarPorEmail(post);
  }

  Future<void> _enviarPorEmail(PostDaComunidade post) async {
    final corpo = StringBuffer()
      ..writeln('Post para a comunidade do Aurea.')
      ..writeln()
      ..writeln(post.texto)
      ..writeln()
      ..writeln('--- para o feed ---')
      ..writeln(_s.comoJson(post));
    if (post.imagem != null && post.imagemLocal) {
      corpo
        ..writeln()
        ..writeln(
          post.temVideo
              ? 'O vídeo está no aparelho: ${post.imagem}'
              : 'A imagem está no aparelho: ${post.imagem}',
        )
        ..writeln('(anexe o arquivo ao e-mail)');
    }
    final uri = Uri(
      scheme: 'mailto',
      path: AureaAutor.email,
      queryParameters: {
        'subject': 'Comunidade Aurea · ${post.autor}',
        'body': corpo.toString(),
      },
    );
    var abriu = false;
    try {
      abriu = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      abriu = false;
    }
    await _atualizar(daRede: false);
    if (!mounted) return;
    if (!abriu) {
      await Clipboard.setData(ClipboardData(text: corpo.toString()));
      if (!mounted) return;
      AureaSnack.show(
        context,
        'Sem app de e-mail. Copiei o post — mande para ${AureaAutor.email}',
        duration: const Duration(seconds: 6),
      );
      return;
    }
    AureaSnack.show(context, 'Abrindo seu app de e-mail');
  }

  Future<void> _apagar(PostDaComunidade post) async {
    await _s.apagar(post.id);
    await _atualizar(daRede: false);
  }

  @override
  Widget build(BuildContext context) {
    final conta = ref.watch(contaDaComunidadeProvider);
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () => _atualizar(daRede: true),
        color: AppColors.lime,
        backgroundColor: AppColors.surface,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Comunidade',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ),
                _BotaoPublicar(onTap: _compor),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'O mural do beta: mostre o que você fez e veja o que os '
              'outros estão fazendo.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            _LinhaDaConta(
              conta: conta,
              onTocar: () async {
                await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const _FolhaDaConta(),
                );
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(height: 14),

            if (_s.ultimoErro != null) ...[
              _Aviso(
                icone: CupertinoIcons.wifi_slash,
                texto:
                    '${_s.ultimoErro} O que já tinha sido lido continua aqui.',
              ),
              const SizedBox(height: 14),
            ],

            if (_carregando && _posts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CupertinoActivityIndicator()),
              )
            else if (_posts.isEmpty)
              const _Vazio()
            else
              for (final p in _posts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _Cartao(
                    post: p,
                    onEnviar: p.estado == EstadoDoPost.rascunho
                        ? () => _reenviar(p)
                        : null,
                    onApagar: p.meu ? () => _apagar(p) : null,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// A LINHA DA CONTA, no alto: quem voce e neste mural.
class _LinhaDaConta extends StatelessWidget {
  const _LinhaDaConta({required this.conta, required this.onTocar});

  final ContaDaComunidade? conta;
  final VoidCallback onTocar;

  @override
  Widget build(BuildContext context) {
    final c = conta;
    return GestureDetector(
      key: const ValueKey('comunidade-conta'),
      behavior: HitTestBehavior.opaque,
      onTap: onTocar,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _Avatar(nome: c?.apelido ?? '?', arquivo: c?.avatar, raio: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c?.apelido ?? 'Criar minha conta',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c == null
                        ? 'Um apelido e uma foto. É com isso que você assina.'
                        : 'É assim que você assina no mural.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Icon(
              c == null ? CupertinoIcons.plus_circle : CupertinoIcons.pencil,
              size: 18,
              color: AppColors.lime,
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.nome, this.arquivo, this.raio = 15});

  final String nome;
  final String? arquivo;
  final double raio;

  @override
  Widget build(BuildContext context) {
    final f = arquivo;
    if (f != null && File(f).existsSync()) {
      return CircleAvatar(radius: raio, backgroundImage: FileImage(File(f)));
    }
    return CircleAvatar(
      radius: raio,
      backgroundColor: AppColors.violet,
      child: Text(
        nome.trim().isEmpty ? 'A' : nome.trim()[0].toUpperCase(),
        style: TextStyle(
          fontSize: raio * 0.85,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _BotaoPublicar extends StatelessWidget {
  const _BotaoPublicar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const ValueKey('comunidade-publicar'),
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.lime,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.plus, size: 17, color: Color(0xFF0B0E12)),
          SizedBox(width: 6),
          Text(
            'Publicar',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0B0E12),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Cartao extends StatelessWidget {
  const _Cartao({required this.post, this.onEnviar, this.onApagar});

  final PostDaComunidade post;
  final VoidCallback? onEnviar;
  final VoidCallback? onApagar;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('post-${post.id}'),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                _Avatar(nome: post.autor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.autor,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onDark,
                        ),
                      ),
                      Text(
                        post.quandoEmPalavras(),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (post.meu) _Selo(estado: post.estado),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Text(
              post.texto,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.onDark,
              ),
            ),
          ),
          if (post.imagem != null) _Midia(post: post),
          if (post.etiquetas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in post.etiquetas)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentDim,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#$e',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.lime,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (post.link != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: GestureDetector(
                onTap: () => launchUrl(
                  Uri.parse(post.link!),
                  mode: LaunchMode.externalApplication,
                ),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.link, size: 14, color: AppColors.lime),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        post.link!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: AppColors.lime),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (onEnviar != null || onApagar != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Row(
                children: [
                  if (onEnviar != null)
                    Expanded(
                      child: _AcaoDoCartao(
                        chave: 'post-enviar-${post.id}',
                        icone: CupertinoIcons.paperplane,
                        rotulo: 'Tentar publicar de novo',
                        destaque: true,
                        onTap: onEnviar!,
                      ),
                    ),
                  if (onEnviar != null && onApagar != null)
                    const SizedBox(width: 8),
                  if (onApagar != null)
                    _AcaoDoCartao(
                      chave: 'post-apagar-${post.id}',
                      icone: CupertinoIcons.trash,
                      rotulo: 'Apagar',
                      onTap: onApagar!,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A MIDIA DO POST: imagem direto, video com play.
///
/// O video so carrega quando alguem toca. Um mural com dez videos que se
/// inicializam sozinhos ocupa dez decodificadores e trava o aparelho —
/// e ninguem assiste dez videos de uma vez.
class _Midia extends StatefulWidget {
  const _Midia({required this.post});
  final PostDaComunidade post;

  @override
  State<_Midia> createState() => _MidiaState();
}

class _MidiaState extends State<_Midia> {
  VideoPlayerController? _player;
  bool _preparando = false;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _tocar() async {
    final endereco = widget.post.imagem;
    if (endereco == null || _preparando) return;
    if (_player != null) {
      setState(() {
        _player!.value.isPlaying ? _player!.pause() : _player!.play();
      });
      return;
    }
    setState(() => _preparando = true);
    try {
      final c = widget.post.imagemLocal
          ? VideoPlayerController.file(File(endereco))
          : VideoPlayerController.networkUrl(Uri.parse(endereco));
      await c.initialize();
      await c.setLooping(true);
      await c.play();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _player = c;
        _preparando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _preparando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final erro = Container(
      height: 120,
      color: AppColors.surfaceHigh,
      alignment: Alignment.center,
      child: Icon(CupertinoIcons.photo, color: AppColors.muted, size: 28),
    );

    if (!post.temVideo) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: SizedBox(
          width: double.infinity,
          child: post.imagemLocal
              ? Image.file(
                  File(post.imagem!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => erro,
                )
              : Image.network(
                  post.imagem!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => erro,
                  loadingBuilder: (_, filho, progresso) => progresso == null
                      ? filho
                      : SizedBox(
                          height: 120,
                          child: Center(
                            child: CupertinoActivityIndicator(
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                ),
        ),
      );
    }

    final p = _player;
    return GestureDetector(
      key: ValueKey('post-video-${post.id}'),
      onTap: _tocar,
      child: AspectRatio(
        aspectRatio: p != null && p.value.isInitialized
            ? p.value.aspectRatio
            : 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (p != null && p.value.isInitialized)
              VideoPlayer(p)
            else
              ColoredBox(color: AppColors.surfaceHigh),
            if (p == null || !p.value.isPlaying)
              Center(
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .55),
                    shape: BoxShape.circle,
                  ),
                  child: _preparando
                      ? const Center(
                          child: CupertinoActivityIndicator(
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          CupertinoIcons.play_fill,
                          color: Colors.white,
                          size: 26,
                        ),
                ),
              ),
            if (post.duracaoDaMidia != null)
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _emMinutos(post.duracaoDaMidia!),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _emMinutos(Duration d) {
  final m = d.inMinutes;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

class _Selo extends StatelessWidget {
  const _Selo({required this.estado});
  final EstadoDoPost estado;

  @override
  Widget build(BuildContext context) {
    final enviado = estado == EstadoDoPost.enviado;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        // "so voce ve" e literal: enquanto nao entrou no servidor, o post
        // existe so neste aparelho.
        enviado ? 'no mural' : 'só você vê',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppColors.muted,
        ),
      ),
    );
  }
}

class _AcaoDoCartao extends StatelessWidget {
  const _AcaoDoCartao({
    required this.chave,
    required this.icone,
    required this.rotulo,
    required this.onTap,
    this.destaque = false,
  });

  final String chave;
  final IconData icone;
  final String rotulo;
  final VoidCallback onTap;
  final bool destaque;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: ValueKey(chave),
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: destaque ? AppColors.accentDim : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icone,
            size: 15,
            color: destaque ? AppColors.lime : AppColors.muted,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              rotulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: destaque ? AppColors.lime : AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icone, required this.texto, this.alerta = false});
  final IconData icone;
  final String texto;
  final bool alerta;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('comunidade-aviso'),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: alerta
          ? const Color(0xFFFF6B6B).withValues(alpha: .12)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(
          icone,
          size: 17,
          color: alerta ? const Color(0xFFFF6B6B) : AppColors.muted,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: alerta ? const Color(0xFFFF8A8A) : AppColors.muted,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Vazio extends StatelessWidget {
  const _Vazio();

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey('comunidade-vazio'),
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(
      children: [
        Icon(
          CupertinoIcons.person_2,
          size: 42,
          color: AppColors.muted.withValues(alpha: .6),
        ),
        const SizedBox(height: 14),
        Text(
          'O mural ainda está vazio',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.onDark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Seja quem começa. Toque em Publicar e mostre o que você fez '
          'no Aurea.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.muted),
        ),
      ],
    ),
  );
}

// ------------------------------------------------------------- a conta

class _FolhaDaConta extends ConsumerStatefulWidget {
  const _FolhaDaConta();

  @override
  ConsumerState<_FolhaDaConta> createState() => _FolhaDaContaState();
}

class _FolhaDaContaState extends ConsumerState<_FolhaDaConta> {
  late final TextEditingController _apelido;
  String? _avatar;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final c = ref.read(contaDaComunidadeProvider);
    _apelido = TextEditingController(text: c?.apelido ?? '');
    _avatar = c?.avatar;
  }

  @override
  void dispose() {
    _apelido.dispose();
    super.dispose();
  }

  Future<void> _escolherFoto() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
      );
      if (x == null) return;
      setState(() => _avatar = x.path);
    } catch (_) {
      if (!mounted) return;
      AureaSnack.show(context, 'Não consegui abrir a galeria');
    }
  }

  void _salvar() {
    final n = ref.read(contaDaComunidadeProvider.notifier);
    final existe = ref.read(contaDaComunidadeProvider) != null;
    final erro = existe
        ? n.atualizar(apelido: _apelido.text, avatar: _avatar)
        : n.criar(_apelido.text, avatar: _avatar);
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final conta = ref.watch(contaDaComunidadeProvider);
    return _Folha(
      titulo: conta == null ? 'Criar minha conta' : 'Minha conta',
      subtitulo: conta == null
          ? 'É uma conta local: sem senha e sem e-mail. Serve para o '
                'mural saber quem falou.'
          : 'Trocar o apelido não muda os posts que você já publicou.',
      filhos: [
        Row(
          children: [
            GestureDetector(
              key: const ValueKey('conta-foto'),
              onTap: _escolherFoto,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  _Avatar(
                    nome: _apelido.text,
                    arquivo: _avatar,
                    raio: 30,
                  ),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppColors.lime,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.camera_fill,
                      size: 12,
                      color: Color(0xFF0B0E12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextField(
                key: const ValueKey('conta-apelido'),
                controller: _apelido,
                maxLength: 20,
                autofocus: conta == null,
                onChanged: (_) => setState(() => _erro = null),
                style: TextStyle(fontSize: 15, color: AppColors.onDark),
                decoration: InputDecoration(
                  hintText: 'Seu apelido no mural',
                  hintStyle: TextStyle(color: AppColors.muted),
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_erro != null) ...[
          const SizedBox(height: 10),
          _Aviso(
            icone: CupertinoIcons.exclamationmark_triangle,
            texto: _erro!,
            alerta: true,
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            if (conta != null)
              Expanded(
                child: _AcaoDoCartao(
                  chave: 'conta-sair',
                  icone: CupertinoIcons.person_badge_minus,
                  rotulo: 'Apagar conta',
                  onTap: () {
                    ref.read(contaDaComunidadeProvider.notifier).sair();
                    Navigator.of(context).pop(false);
                  },
                ),
              ),
            if (conta != null) const SizedBox(width: 8),
            Expanded(
              child: _AcaoDoCartao(
                chave: 'conta-salvar',
                icone: CupertinoIcons.check_mark,
                rotulo: conta == null ? 'Criar conta' : 'Salvar',
                destaque: true,
                onTap: _salvar,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// -------------------------------------------------------- o compositor

class _Compositor extends StatefulWidget {
  const _Compositor({required this.conta});
  final ContaDaComunidade conta;

  @override
  State<_Compositor> createState() => _CompositorState();
}

class _CompositorState extends State<_Compositor> {
  final _texto = TextEditingController();
  final _etiquetas = TextEditingController();
  String? _midia;
  TipoDeMidia _tipo = TipoDeMidia.imagem;
  Duration? _duracao;
  String? _erro;
  bool _apenasAviso = false;

  @override
  void dispose() {
    _texto.dispose();
    _etiquetas.dispose();
    super.dispose();
  }

  Future<void> _escolherImagem() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
      );
      if (x == null) return;
      setState(() {
        _midia = x.path;
        _tipo = TipoDeMidia.imagem;
        _duracao = null;
      });
    } catch (_) {
      if (!mounted) return;
      AureaSnack.show(context, 'Não consegui abrir a galeria');
    }
  }

  Future<void> _escolherVideo() async {
    try {
      final x = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (x == null) return;
      // A DURACAO SE LE ANTES DE ANEXAR, e nao na hora de mostrar: e ela
      // que decide se o video cabe no mural, e recusar depois de a pessoa
      // ja ter publicado seria pior.
      Duration? duracao;
      try {
        final c = VideoPlayerController.file(File(x.path));
        await c.initialize();
        duracao = c.value.duration;
        await c.dispose();
      } catch (_) {}
      if (duracao != null && duracao.inSeconds > 120) {
        if (!mounted) return;
        setState(
          () => _erro = 'Vídeo de até 2 minutos no mural. '
              'Corte o trecho que interessa e anexe de novo.',
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _midia = x.path;
        _tipo = TipoDeMidia.video;
        _duracao = duracao;
        _erro = null;
      });
    } catch (_) {
      if (!mounted) return;
      AureaSnack.show(context, 'Não consegui abrir a galeria');
    }
  }

  void _pronto() {
    final veredito = moderarTexto(_texto.text);
    // BLOQUEIO E AVISO SAO COISAS DIFERENTES na tela: um impede, o outro
    // so recomenda. Tratar os dois igual faria a pessoa achar que o app
    // travou por causa de uma letra repetida — e insistir num aviso e um
    // direito dela: quem quer escrever em caixa alta, escreve.
    if (veredito.bloqueia) {
      setState(() {
        _erro = veredito.motivo;
        _apenasAviso = false;
      });
      return;
    }
    if (veredito.veredito == Veredito.ajustar && !_apenasAviso) {
      setState(() {
        _erro = veredito.motivo;
        _apenasAviso = true;
      });
      return;
    }
    Navigator.of(context).pop(
      PostDaComunidade(
        id: const Uuid().v4(),
        autor: widget.conta.apelido,
        texto: _texto.text.trim(),
        quando: DateTime.now(),
        imagem: _midia,
        imagemLocal: _midia != null,
        tipoDeMidia: _tipo,
        duracaoDaMidia: _duracao,
        etiquetas: [
          for (final e in _etiquetas.text.split(RegExp(r'[,\s]+')))
            if (e.trim().isNotEmpty) e.trim().replaceAll('#', ''),
        ],
        estado: EstadoDoPost.rascunho,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _Folha(
      titulo: 'Publicar no mural',
      subtitulo: 'Assinado como ${widget.conta.apelido}.',
      filhos: [
        TextField(
          key: const ValueKey('comunidade-texto'),
          controller: _texto,
          maxLines: 5,
          minLines: 3,
          autofocus: true,
          onChanged: (_) => setState(() => _erro = null),
          style: TextStyle(fontSize: 14, color: AppColors.onDark),
          decoration: InputDecoration(
            hintText: 'O que você fez no Aurea?',
            hintStyle: TextStyle(color: AppColors.muted),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('comunidade-etiquetas'),
          controller: _etiquetas,
          style: TextStyle(fontSize: 13, color: AppColors.onDark),
          decoration: InputDecoration(
            hintText: 'etiquetas: motion, 3d, tutorial',
            hintStyle: TextStyle(color: AppColors.muted),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (_erro != null) ...[
          const SizedBox(height: 10),
          _Aviso(
            icone: _apenasAviso
                ? CupertinoIcons.info_circle
                : CupertinoIcons.exclamationmark_triangle,
            texto: _apenasAviso ? '$_erro Toque de novo para publicar assim.'
                : _erro!,
            alerta: !_apenasAviso,
          ),
        ],
        if (_midia != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_tipo == TipoDeMidia.imagem)
                  Image.file(
                    File(_midia!),
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                else
                  Container(
                    height: 140,
                    width: double.infinity,
                    color: AppColors.surfaceHigh,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.play_rectangle_fill,
                          size: 30,
                          color: AppColors.muted,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _duracao == null
                              ? 'Vídeo anexado'
                              : 'Vídeo · ${_emMinutos(_duracao!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _AcaoDoCartao(
                chave: 'comunidade-imagem',
                icone: CupertinoIcons.photo,
                rotulo: 'Imagem',
                onTap: _escolherImagem,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AcaoDoCartao(
                chave: 'comunidade-video',
                icone: CupertinoIcons.videocam,
                rotulo: 'Vídeo',
                onTap: _escolherVideo,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AcaoDoCartao(
                chave: 'comunidade-guardar',
                icone: CupertinoIcons.check_mark,
                rotulo: 'Pronto',
                destaque: true,
                onTap: _pronto,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A casca das folhas desta aba: alca, titulo, subtitulo e o conteudo.
class _Folha extends StatelessWidget {
  const _Folha({
    required this.titulo,
    required this.subtitulo,
    required this.filhos,
  });

  final String titulo;
  final String subtitulo;
  final List<Widget> filhos;

  @override
  Widget build(BuildContext context) {
    final fundo = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: fundo),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.muted.withValues(alpha: .45),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitulo,
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 14),
                ...filhos,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
