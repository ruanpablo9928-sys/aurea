import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/community/application/comunidade_service.dart';

/// UM AVISO AO VIVO, escrito de fora e visto em todo aparelho.
///
/// "Estamos resolvendo um bug que trava a exportação" precisa chegar a
/// quem tem o app instalado HOJE, sem esperar build novo. O aviso mora
/// no servidor do mural, na chave `aviso:atual`; o app pergunta ao abrir
/// e de dez em dez minutos. Quem publica é quem tem a senha de moderação
/// — o mesmo canal que apaga post no mural.
///
/// O aviso tem id: dispensar esconde AQUELE aviso, e o próximo aparece
/// de novo. Sem id, a pessoa fecharia o primeiro e nunca veria mais
/// nenhum.
class Aviso {
  const Aviso({
    required this.id,
    required this.texto,
    this.nivel = NivelDoAviso.info,
    this.link,
    this.ate,
  });

  final String id;
  final String texto;
  final NivelDoAviso nivel;

  /// Para onde "saiba mais" leva, quando há.
  final String? link;

  /// Depois deste instante o aviso some sozinho, mesmo sem o servidor
  /// ser atualizado.
  final DateTime? ate;

  bool get vencido => ate != null && DateTime.now().isAfter(ate!);

  static Aviso? deJson(Object? bruto) {
    if (bruto is! Map) return null;
    final m = bruto.cast<String, dynamic>();
    final texto = '${m['texto'] ?? ''}'.trim();
    final id = '${m['id'] ?? ''}'.trim();
    if (texto.isEmpty || id.isEmpty) return null;
    return Aviso(
      id: id,
      texto: texto,
      nivel: NivelDoAviso.values.firstWhere(
        (n) => n.name == m['nivel'],
        orElse: () => NivelDoAviso.info,
      ),
      link: (m['link'] as String?)?.trim().isEmpty ?? true
          ? null
          : m['link'] as String,
      ate: DateTime.tryParse('${m['ate'] ?? ''}'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'texto': texto,
    'nivel': nivel.name,
    if (link != null) 'link': link,
    if (ate != null) 'ate': ate!.toUtc().toIso8601String(),
  };
}

enum NivelDoAviso { info, atencao, problema }

class AvisosService {
  AvisosService({HttpClient? http, this.endereco = ComunidadeService.enderecoPadrao})
    : _http = http ?? (HttpClient()..connectionTimeout = const Duration(seconds: 8));

  static final instance = AvisosService();

  static const _chaveGuardado = 'aviso.atual';
  static const _chaveDispensado = 'aviso.dispensado';
  static const intervalo = Duration(minutes: 10);

  final HttpClient _http;
  final String endereco;

  /// O aviso que a tela deve mostrar agora. Nulo = nada a dizer.
  final ValueNotifier<Aviso?> atual = ValueNotifier(null);

  Timer? _relogio;
  String? _dispensado;

  /// Chamar uma vez, na Início: lê o último guardado (aparece na hora,
  /// mesmo sem rede) e vai buscar o de agora.
  Future<void> iniciar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _dispensado = prefs.getString(_chaveDispensado);
      final guardado = prefs.getString(_chaveGuardado);
      if (guardado != null) _mostrar(Aviso.deJson(jsonDecode(guardado)));
    } catch (_) {}
    unawaited(atualizar());
    _relogio ??= Timer.periodic(intervalo, (_) => atualizar());
  }

  Future<void> atualizar() async {
    try {
      final req = await _http.getUrl(Uri.parse('$endereco/aviso'));
      final res = await req.close().timeout(const Duration(seconds: 8));
      final corpo = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) return;
      final m = (jsonDecode(corpo) as Map).cast<String, dynamic>();
      final aviso = Aviso.deJson(m['aviso']);
      _mostrar(aviso);
      try {
        final prefs = await SharedPreferences.getInstance();
        if (aviso == null) {
          await prefs.remove(_chaveGuardado);
        } else {
          await prefs.setString(_chaveGuardado, jsonEncode(aviso.toJson()));
        }
      } catch (_) {}
    } catch (_) {
      // Sem rede, fica o que já estava na tela. Um aviso velho por dez
      // minutos é melhor do que um aviso que pisca a cada falha.
    }
  }

  void _mostrar(Aviso? aviso) {
    if (aviso == null || aviso.vencido || aviso.id == _dispensado) {
      atual.value = null;
      return;
    }
    atual.value = aviso;
  }

  /// Fecha ESTE aviso. O próximo, com outro id, volta a aparecer.
  Future<void> dispensar() async {
    final a = atual.value;
    if (a == null) return;
    _dispensado = a.id;
    atual.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chaveDispensado, a.id);
    } catch (_) {}
  }

  /// Para o relogio das buscas. Quem chama e a faixa, ao sair da tela.
  void parar() {
    _relogio?.cancel();
    _relogio = null;
  }
}
