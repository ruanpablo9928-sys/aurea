/// ONDE A TRANSCRICAO DAS LEGENDAS RODA.
///
/// Na nuvem e o Whisper grande da Groq, passando pelo servidor do Aurea
/// (a chave da Groq mora la, e so la). No aparelho e o whisper.cpp com o
/// modelo pequeno, sem mandar audio a lugar nenhum. O automatico escolhe
/// pela internet: com, nuvem; sem, aparelho.
enum ModoDeTranscricao {
  auto,
  nuvem,
  local;

  static ModoDeTranscricao deNome(String? nome) =>
      values.firstWhere((m) => m.name == nome, orElse: () => auto);

  String get emPalavras => switch (this) {
    auto => 'Automático',
    nuvem => 'Nuvem',
    local => 'No aparelho',
  };

  String get explicacao => switch (this) {
    auto => 'Com internet, na nuvem; sem, no aparelho.',
    nuvem => 'Groq Whisper, pelo servidor do Aurea. Usa sua conta da comunidade.',
    local => 'whisper.cpp no aparelho. O áudio não sai do celular.',
  };
}
