import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/avisos/avisos_service.dart';
import '../../../core/theme/app_theme.dart';

/// A FAIXA DO AVISO AO VIVO, no alto da Início.
///
/// Uma linha, um "!" e o texto que veio do servidor. Sem cartão, sem
/// bolha: é um recado, e um recado se lê e se fecha. O X esconde só este
/// aviso — o próximo, com outro id, aparece de novo.
class AvisoAoVivo extends StatefulWidget {
  const AvisoAoVivo({super.key, this.servico});

  /// Para os testes: um serviço com o aviso já em mãos.
  final AvisosService? servico;

  @override
  State<AvisoAoVivo> createState() => _AvisoAoVivoState();
}

class _AvisoAoVivoState extends State<AvisoAoVivo> {
  AvisosService get _s => widget.servico ?? AvisosService.instance;

  @override
  void initState() {
    super.initState();
    if (widget.servico == null) _s.iniciar();
  }

  @override
  void dispose() {
    // A FAIXA E DONA DO RELOGIO. O servico e um so para o app inteiro,
    // mas quem pede a busca de dez em dez minutos e esta faixa — quando
    // ela sai da tela (ou o teste termina), o relogio para junto.
    if (widget.servico == null) _s.parar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Aviso?>(
    valueListenable: _s.atual,
    builder: (context, aviso, _) {
      if (aviso == null) return const SizedBox.shrink();
      final cor = switch (aviso.nivel) {
        NivelDoAviso.info => AppColors.lime,
        NivelDoAviso.atencao => const Color(0xFFFFC978),
        NivelDoAviso.problema => const Color(0xFFFF7A7A),
      };
      return SafeArea(
        bottom: false,
        child: Container(
          key: ValueKey('aviso-${aviso.id}'),
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
                child: const Text(
                  '!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0B0E12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: aviso.link == null
                      ? null
                      : () => launchUrl(
                          Uri.parse(aviso.link!),
                          mode: LaunchMode.externalApplication,
                        ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      aviso.link == null
                          ? aviso.texto
                          : '${aviso.texto}  Saiba mais ›',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onDark,
                      ),
                    ),
                  ),
                ),
              ),
              // O X TEM 44 PX: um recado que só some acertando um
              // alvo de 16 px vira um recado que não some.
              GestureDetector(
                key: const ValueKey('aviso-fechar'),
                behavior: HitTestBehavior.opaque,
                onTap: _s.dispensar,
                child: SizedBox(
                  width: 40,
                  height: 28,
                  child: Icon(
                    CupertinoIcons.xmark,
                    size: 15,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
