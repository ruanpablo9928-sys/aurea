import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/snack.dart';
import '../domain/laboratory_session.dart';

typedef LaboratoryReportShare = Future<void> Function(
  String plainText,
  List<LaboratoryAttachment> attachments,
);

/// Abre o relatorio como folha deslizante, nunca como dialogo central.
Future<void> showLaboratoryReportSheet(
  BuildContext context, {
  required String reportText,
  required Iterable<LaboratoryAttachment> attachments,
  LaboratoryReportShare? onShare,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (context) => LaboratoryReportSheet(
      reportText: reportText,
      attachments: attachments.toList(growable: false),
      onShare: onShare,
    ),
  );
}

/// Folha de texto simples com os prints registrados na sessao.
class LaboratoryReportSheet extends StatefulWidget {
  const LaboratoryReportSheet({
    super.key,
    required this.reportText,
    required this.attachments,
    this.onShare,
  });

  final String reportText;
  final List<LaboratoryAttachment> attachments;
  final LaboratoryReportShare? onShare;

  @override
  State<LaboratoryReportSheet> createState() => _LaboratoryReportSheetState();
}

class _LaboratoryReportSheetState extends State<LaboratoryReportSheet> {
  bool _sharing = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.reportText));
    if (!mounted) return;
    AureaSnack.show(context, 'Relatorio copiado');
  }

  Future<void> _share() async {
    if (_sharing) return;
    final share = widget.onShare;
    if (share == null) {
      await _copy();
      if (!mounted) return;
      AureaSnack.show(
        context,
        'Compartilhamento indisponivel; o texto foi copiado',
      );
      return;
    }
    setState(() => _sharing = true);
    try {
      await share(widget.reportText, widget.attachments);
    } catch (_) {
      if (!mounted) return;
      AureaSnack.show(context, 'Nao foi possivel abrir o compartilhamento');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.48,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) => Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            const _Grabber(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 10, 10),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.doc_plaintext,
                    color: AppColors.lime,
                    size: 21,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Relatorio do Laboratorio',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Fechar relatorio',
                    child: CupertinoButton(
                      padding: const EdgeInsets.all(10),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Icon(
                        CupertinoIcons.xmark_circle_fill,
                        color: AppColors.muted,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: AppColors.hairline),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Semantics(
                    label: 'Relatorio em texto simples',
                    textField: true,
                    readOnly: true,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        border: Border.all(color: AppColors.hairline),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: SelectableText(
                        widget.reportText,
                        style: const TextStyle(
                          color: AppColors.onDark,
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.48,
                        ),
                      ),
                    ),
                  ),
                  if (widget.attachments.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'PRINTS E ANEXOS',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 9),
                    SizedBox(
                      height: 94,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.attachments.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) =>
                            _AttachmentTile(widget.attachments[index]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Copiar relatorio',
                    child: OutlinedButton.icon(
                      onPressed: _copy,
                      icon: const Icon(CupertinoIcons.doc_on_doc, size: 18),
                      label: const Text('Copiar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _sharing ? null : _share,
                      icon: _sharing
                          ? const SizedBox.square(
                              dimension: 17,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(CupertinoIcons.share, size: 19),
                      label: Text(_sharing ? 'Abrindo…' : 'Enviar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile(this.attachment);

  final LaboratoryAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final file = _fileFor(attachment.uri);
    final label =
        attachment.label ?? (attachment.isScreenshot ? 'Print' : 'Anexo');
    return Semantics(
      image: attachment.isScreenshot,
      label: label,
      child: Container(
        width: 116,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (attachment.isScreenshot && file != null)
              Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _AttachmentFallback(),
              )
            else
              const _AttachmentFallback(),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black.withValues(alpha: 0.72),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  File? _fileFor(String rawUri) {
    if (rawUri.trim().isEmpty) return null;
    final uri = Uri.tryParse(rawUri);
    if (uri == null) return null;
    if (uri.scheme == 'file') return File.fromUri(uri);
    if (uri.scheme.isEmpty) return File(rawUri);
    return null;
  }
}

class _AttachmentFallback extends StatelessWidget {
  const _AttachmentFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(CupertinoIcons.paperclip, size: 24, color: AppColors.muted),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 5,
        margin: const EdgeInsets.only(top: 8, bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.outline,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}
