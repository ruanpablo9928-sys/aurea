import 'package:aurea/src/features/community/domain/moderacao.dart';
import 'package:flutter_test/flutter_test.dart';

/// O FILTRO DO MURAL, dos dois lados.
///
/// Um filtro se julga por duas listas: o que ele PEGA e o que ele DEIXA
/// PASSAR. A segunda importa mais. Bloquear uma frase normal faz a pessoa
/// achar que o app quebrou, e ela nao volta — enquanto um xingamento que
/// escapou some com um toque de quem modera.
void main() {
  group('normalizar', () {
    test('tira acento, disfarce de numero e letra repetida', () {
      expect(normalizarParaFiltro('VIÁDO'), 'viado');
      expect(normalizarParaFiltro('v1@d0'), 'viado');
      expect(normalizarParaFiltro('viiiiiado'), 'viado');
      expect(normalizarParaFiltro('a   b'), 'a b');
    });

    test('duas letras iguais sobrevivem — senao quebra o portugues', () {
      // "carro", "asse", "nossa": reduzir tudo a uma letra estragaria a
      // comparacao de palavras normais.
      expect(normalizarParaFiltro('carro'), 'carro');
      expect(normalizarParaFiltro('nossa'), 'nossa');
    });
  });

  group('o que nao entra', () {
    test('ofensa, mesmo disfarcada', () {
      for (final texto in [
        'vai se foder',
        'V41 S3 FOD3R',
        'seu viiiiado',
        'vou te matar',
      ]) {
        expect(
          moderarTexto(texto).veredito,
          Veredito.bloqueado,
          reason: texto,
        );
      }
    });

    test('dado pessoal — protege quem escreve de si mesmo', () {
      expect(moderarTexto('me chama no 11 98765-4321').bloqueia, isTrue);
      expect(moderarTexto('meu email e joao@exemplo.com').bloqueia, isTrue);
      expect(moderarTexto('cpf 123.456.789-00 para o pix').bloqueia, isTrue);
    });

    test('vazio, curto demais e longo demais', () {
      expect(moderarTexto('').bloqueia, isTrue);
      expect(moderarTexto('   ').bloqueia, isTrue);
      expect(moderarTexto('ok').bloqueia, isTrue);
      expect(moderarTexto('a' * 1300).bloqueia, isTrue);
    });

    test('o motivo e escrito para quem publicou, nao para um log', () {
      final r = moderarTexto('vai tomar no cu');
      expect(r.motivo, isNotNull);
      expect(r.motivo, contains('mural'));
      expect(r.motivo!.length, greaterThan(20));
    });
  });

  group('o que so ganha um aviso', () {
    test('caixa alta, letra repetida e link demais', () {
      for (final texto in [
        'OLHA ISSO QUE EU FIZ AGORA NO APP',
        'ficou lindooooooooo demais',
        'veja https://a.com e https://b.com e https://c.com',
      ]) {
        expect(moderarTexto(texto).veredito, Veredito.ajustar, reason: texto);
      }
    });
  });

  group('o que passa', () {
    test('conversa normal de quem edita video', () {
      for (final texto in [
        'Terminei minha primeira animação com o rastreio 3D, ficou ótimo!',
        'Alguém sabe como faço a máscara acompanhar a mão? Tô apanhando.',
        'O modelo MÃO ENTERRADA é muito bom, usei como base pro meu.',
        'Achei um bug: a timeline trava quando arrasto rápido. Vou reportar.',
        'Que porcaria de render, mas a culpa foi minha kkkk',
        'Fiz em 4K 60fps e exportou em 2 minutos',
      ]) {
        expect(moderarTexto(texto).ok, isTrue, reason: texto);
      }
    });

    test('numero que nao e telefone passa', () {
      expect(moderarTexto('renderizei em 1920x1080 a 30 fps').ok, isTrue);
      expect(moderarTexto('durou 12 segundos e deu 240 quadros').ok, isTrue);
    });
  });

  group('apelido', () {
    test('tamanho e caracteres', () {
      expect(moderarApelido('ab').bloqueia, isTrue);
      expect(moderarApelido('a' * 25).bloqueia, isTrue);
      expect(moderarApelido('joão_silva!!!').bloqueia, isTrue);
      expect(moderarApelido('João Silva').ok, isTrue);
      expect(moderarApelido('maria.motion').ok, isTrue);
      expect(moderarApelido('dnyx-01').ok, isTrue);
    });

    test('ofensa no apelido tambem nao entra', () {
      expect(moderarApelido('vai se foder').bloqueia, isTrue);
    });

    test('nome que se passa pela equipe e reservado', () {
      // O golpe mais barato num mural de beta: postar como se fosse o app.
      expect(moderarApelido('Aurea').bloqueia, isTrue);
      expect(moderarApelido('aurea oficial').bloqueia, isTrue);
      expect(moderarApelido('suporte').bloqueia, isTrue);
      // Mas um nome que so COMECA parecido continua valendo.
      expect(moderarApelido('aureliano').ok, isTrue);
    });
  });

  group('filtro na hora de mostrar', () {
    test('o que veio de fora e nao passa, nao aparece', () {
      expect(podeMostrar('post normal do mural', 'Ana'), isTrue);
      expect(podeMostrar('vai tomar no cu', 'Ana'), isFalse);
      expect(podeMostrar('post normal', 'vai se foder'), isFalse);
      // MAS NOME RESERVADO CONTINUA APARECENDO. "Aurea" e recusado na
      // CRIACAO de conta, para ninguem se passar pela equipe — e e
      // exatamente com esse nome que os avisos oficiais chegam. Misturar
      // as duas regras fazia o mural esconder os proprios avisos.
      expect(moderarApelido('Aurea').bloqueia, isTrue);
      expect(podeMostrar('Beta 55 no ar', 'Aurea'), isTrue);
    });
  });
}
