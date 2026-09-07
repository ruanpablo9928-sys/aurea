import 'package:flutter/services.dart';

/// O QUE O SISTEMA SABE E O DART NAO: memoria disponivel e estado termico.
///
/// O iOS diz quanto o processo ainda pode alocar antes de ser morto
/// (`os_proc_available_memory`); o Android diz a memoria livre e se o
/// sistema ja esta em "pouca memoria". Os dois dizem se o aparelho esta
/// esquentando. Sao os sinais que chegam ANTES do jetsam e do throttle —
/// e o controlador de qualidade os le a cada dois segundos enquanto uma
/// cena 3D esta na tela.
///
/// Vive no mesmo canal do codificador (`aurea/encoder`), que ja existe
/// nas duas plataformas. Sem resposta (teste, plataforma sem o plugin) o
/// controlador segue so com a estimativa.
class SistemaNativo {
  static const _canal = MethodChannel('aurea/encoder');

  static Future<MemoriaDoSistema?> memoria() async {
    try {
      final m = await _canal.invokeMethod<Map>('memoria');
      if (m == null) return null;
      return MemoriaDoSistema(
        total: (m['total'] as num?)?.toInt() ?? 0,
        disponivel: (m['disponivel'] as num?)?.toInt() ?? -1,
        baixa: m['baixa'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  /// 0 = normal, 1 = morno, 2 = serio, 3 = critico.
  static Future<int> termico() async {
    try {
      return (await _canal.invokeMethod<int>('termico')) ?? 0;
    } catch (_) {
      return 0;
    }
  }
}

class MemoriaDoSistema {
  const MemoriaDoSistema({
    required this.total,
    required this.disponivel,
    required this.baixa,
  });

  /// RAM fisica, em bytes (0 = desconhecida).
  final int total;

  /// Quanto ainda da para alocar, em bytes (-1 = desconhecido). No iOS e
  /// o orcamento do processo; no Android, a memoria livre do sistema.
  final int disponivel;

  /// O sistema ja se declarou em pouca memoria.
  final bool baixa;
}
