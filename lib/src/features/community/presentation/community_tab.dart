import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/snack.dart';
import '../../about/presentation/report_sheet.dart' show AureaAutor;
import '../../user/application/user_profile_controller.dart';
import '../application/comunidade_service.dart';
import '../domain/post_da_comunidade.dart';

/// A ABA COMUNIDADE.
///
/// O que ela e: o mural do beta. Quem esta testando mostra o que fez,
/// quem instalou o app ve. Nada de curtida, seguidor ou notificacao —
/// isso e infraestrutura social que so faz sentido depois que ha gente
/// postando.
///
/// O que ela NAO esconde: publicar passa por uma revisao. O app le o
/// feed publico direto do repositorio do projeto (funciona para todo
/// mundo, sem conta e sem segredo embutido), mas escrever nele exigiria
/// uma chave de escrita dentro do APK — que na pratica e uma chave
/// publica. Entao o post fica gravado aqui na hora, marcado, e vai para
/// publicacao pelo mesmo caminho dos relatos de bug. A tela diz isso em
/// vez de fingir que ja esta no ar.
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

  Future<void> _compor() async {
    final perfil = ref.read(userProfileProvider);
    final post = await showModalBottomSheet<PostDaComunidade>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _Compositor(autor: perfil.name),
    );
    if (post == null) return;
    await _s.publicar(post);
    await _atualizar(daRede: false);
    if (!mounted) return;
    AureaSnack.show(
      context,
      'Post guardado. Toque em Enviar para ele entrar no mural.',
      duration: const Duration(seconds: 5),
    );
  }

  Future<void> _enviar(PostDaComunidade post) async {
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
        ..writeln('A imagem esta no aparelho: ${post.imagem}');
      corpo.writeln('(anexe o arquivo ao e-mail)');
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
    await _s.marcarEnviado(post.id);
    await _atualizar(daRede: false);
    if (!mounted) return;
    if (!abriu) {
      await Clipboard.setData(ClipboardData(text: corpo.toString()));
      if (!mounted) return;
      AureaSnack.show(
        context,
        'Sem app de e-mail. Copiei o post — mande para '
        '${AureaAutor.email}',
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
            const SizedBox(height: 18),

            if (_s.ultimoErro != null) ...[
              _Aviso(
                icone: CupertinoIcons.wifi_slash,
                texto: '${_s.ultimoErro} '
                    'O que já tinha sido lido continua aqui.',
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
                        ? () => _enviar(p)
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.plus, size: 17, color: Color(0xFF0B0E12)),
          const SizedBox(width: 6),
          Text(
            'Publicar',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.modoClaro
                  ? const Color(0xFF0B0E12)
                  : const Color(0xFF0B0E12),
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
                CircleAvatar(
                  radius: 15,
                  backgroundColor: AppColors.violet,
                  child: Text(
                    post.autor.trim().isEmpty
                        ? 'A'
                        : post.autor.trim()[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
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
          if (post.imagem != null) _Imagem(post: post),
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
                        rotulo: 'Enviar para o mural',
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

class _Imagem extends StatelessWidget {
  const _Imagem({required this.post});
  final PostDaComunidade post;

  @override
  Widget build(BuildContext context) {
    final erro = Container(
      height: 120,
      color: AppColors.surfaceHigh,
      alignment: Alignment.center,
      child: Icon(
        CupertinoIcons.photo,
        color: AppColors.muted,
        size: 28,
      ),
    );
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
        enviado ? 'enviado' : 'só você vê',
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
  const _Aviso({required this.icone, required this.texto});
  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('comunidade-aviso'),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(icone, size: 17, color: AppColors.muted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: AppColors.muted,
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
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: AppColors.muted,
          ),
        ),
      ],
    ),
  );
}

/// O COMPOSITOR: texto, uma imagem e etiquetas. Nada mais.
class _Compositor extends StatefulWidget {
  const _Compositor({required this.autor});
  final String autor;

  @override
  State<_Compositor> createState() => _CompositorState();
}

class _CompositorState extends State<_Compositor> {
  final _texto = TextEditingController();
  final _etiquetas = TextEditingController();
  String? _imagem;

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
      setState(() => _imagem = x.path);
    } catch (_) {
      if (!mounted) return;
      AureaSnack.show(context, 'Nao consegui abrir a galeria');
    }
  }

  void _pronto() {
    final texto = _texto.text.trim();
    if (texto.isEmpty) {
      AureaSnack.show(context, 'Escreva alguma coisa antes de publicar');
      return;
    }
    Navigator.of(context).pop(
      PostDaComunidade(
        id: const Uuid().v4(),
        autor: widget.autor,
        texto: texto,
        quando: DateTime.now(),
        imagem: _imagem,
        imagemLocal: _imagem != null,
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
                'Publicar no mural',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onDark,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Assinado como ${widget.autor} — troque o nome na aba '
                'Usuário.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('comunidade-texto'),
                controller: _texto,
                maxLines: 5,
                minLines: 3,
                autofocus: true,
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
              const SizedBox(height: 10),
              if (_imagem != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_imagem!),
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              if (_imagem != null) const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _AcaoDoCartao(
                      chave: 'comunidade-imagem',
                      icone: CupertinoIcons.photo,
                      rotulo: _imagem == null ? 'Anexar imagem' : 'Trocar',
                      onTap: _escolherImagem,
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
          ),
        ),
      ),
    );
  }
}
