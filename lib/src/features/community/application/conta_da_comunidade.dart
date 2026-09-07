import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/prefs.dart';
import '../domain/moderacao.dart';

/// A MINI CONTA DO MURAL.
///
/// Mini porque nao tem senha, nao tem servidor e nao tem recuperacao: e
/// uma identidade LOCAL, criada uma vez, que assina os posts. Isso e o
/// que um mural de beta precisa — saber quem falou — e nada do que ele
/// nao precisa.
///
/// O que ela resolve, e por isso existe em vez de so um campo de nome:
///
///   1. QUEM ASSINA APARECE ANTES DE PUBLICAR. Sem conta, a pessoa
///      escrevia e so descobria como tinha assinado depois.
///   2. O APELIDO PASSA PELO FILTRO uma vez, na criacao, e nao a cada
///      post. Sem isso, o mural fica limpo e a lista de autores nao.
///   3. O ID SOBREVIVE A TROCA DE APELIDO. Um dia o mural vai ter
///      servidor; quando tiver, os posts ja sabem de quem sao.
class ContaDaComunidade {
  const ContaDaComunidade({
    required this.id,
    required this.apelido,
    required this.criadaEm,
    this.avatar,
  });

  final String id;
  final String apelido;
  final DateTime criadaEm;

  /// Caminho de um arquivo no aparelho. Nulo = usa a inicial do apelido.
  final String? avatar;

  String get inicial =>
      apelido.trim().isEmpty ? 'A' : apelido.trim()[0].toUpperCase();

  Map<String, dynamic> toJson() => {
    'id': id,
    'apelido': apelido,
    'criadaEm': criadaEm.toUtc().toIso8601String(),
    if (avatar != null) 'avatar': avatar,
  };

  static ContaDaComunidade? deJson(String fonte) {
    try {
      final m = (jsonDecode(fonte) as Map).cast<String, dynamic>();
      final apelido = '${m['apelido'] ?? ''}';
      if (apelido.trim().isEmpty) return null;
      return ContaDaComunidade(
        id: '${m['id'] ?? const Uuid().v4()}',
        apelido: apelido,
        criadaEm: DateTime.tryParse('${m['criadaEm']}')?.toLocal() ??
            DateTime.now(),
        avatar: m['avatar'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  ContaDaComunidade copyWith({String? apelido, String? avatar}) =>
      ContaDaComunidade(
        id: id,
        apelido: apelido ?? this.apelido,
        criadaEm: criadaEm,
        avatar: avatar ?? this.avatar,
      );
}

class ContaDaComunidadeController extends Notifier<ContaDaComunidade?> {
  static const _chave = 'comunidade.conta';

  @override
  ContaDaComunidade? build() {
    try {
      final bruto = ref.read(sharedPreferencesProvider).getString(_chave);
      return bruto == null ? null : ContaDaComunidade.deJson(bruto);
    } catch (_) {
      // Sem prefs (teste, primeira execucao): simplesmente nao ha conta.
      return null;
    }
  }

  /// Cria a conta. Devolve o motivo da recusa, ou null se deu certo.
  String? criar(String apelido, {String? avatar}) {
    final veredito = moderarApelido(apelido);
    if (veredito.bloqueia) return veredito.motivo;
    _gravar(
      ContaDaComunidade(
        id: const Uuid().v4(),
        apelido: apelido.trim(),
        criadaEm: DateTime.now(),
        avatar: avatar,
      ),
    );
    return null;
  }

  /// Troca apelido e/ou foto. Devolve o motivo da recusa, ou null.
  String? atualizar({String? apelido, String? avatar}) {
    final atual = state;
    if (atual == null) return 'Crie a conta primeiro.';
    if (apelido != null) {
      final veredito = moderarApelido(apelido);
      if (veredito.bloqueia) return veredito.motivo;
    }
    _gravar(atual.copyWith(apelido: apelido?.trim(), avatar: avatar));
    return null;
  }

  /// Apaga a conta DESTE APARELHO. Os posts ja publicados continuam no
  /// mural — o mural e de todos, e apagar a conta nao apaga o que a
  /// pessoa disse aos outros.
  void sair() {
    state = null;
    try {
      ref.read(sharedPreferencesProvider).remove(_chave);
    } catch (_) {}
  }

  void _gravar(ContaDaComunidade conta) {
    state = conta;
    try {
      ref
          .read(sharedPreferencesProvider)
          .setString(_chave, jsonEncode(conta.toJson()));
    } catch (_) {
      // Sem prefs a conta vale para esta sessao; melhor que travar.
    }
  }
}

final contaDaComunidadeProvider =
    NotifierProvider<ContaDaComunidadeController, ContaDaComunidade?>(
      ContaDaComunidadeController.new,
    );
