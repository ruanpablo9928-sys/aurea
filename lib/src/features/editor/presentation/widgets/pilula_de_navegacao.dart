import 'package:flutter/material.dart';

import '../../../../core/ui/am_colors.dart';
import 'linha_do_tempo.dart';

/// A PILULA DIZ QUAL CAMADA ESTA ABERTA, e trocar de camada e um gesto
/// dela.
///
/// Antes eram duas setas cinzas soltas nas bordas da faixa. Elas
/// trocavam de camada as cegas: nao havia nome nenhum entre uma e
/// outra, entao so dava para saber onde se tinha parado depois de
/// parar. Juntar o nome e as setas numa peca so poe o gesto e a
/// resposta no mesmo lugar — a especificacao chama isso de "o navegador
/// de camada" (`docs/painel-de-transformacao-alight.md`).
///
/// ELA E BRANCA NUM EDITOR QUASE PRETO de proposito. Flutua por cima
/// das trilhas, que sao coloridas e mudam de cor a cada projeto: nenhum
/// tom da paleta se destacaria de todas elas ao mesmo tempo, e branco
/// puro nao e usado em mais nada aqui alem do cabecote.
class PilulaDeNavegacao extends StatelessWidget {
  const PilulaDeNavegacao({
    super.key,
    required this.nome,
    required this.cor,
    this.aoAnterior,
    this.aoProxima,
    this.largura,
  });

  /// O nome da camada aberta, como ele aparece na trilha.
  final String nome;

  /// A COR VEM DE FORA, e nao de uma tabela daqui: e a mesma cor que a
  /// barra da camada usa na trilha. Duas contas separadas para a mesma
  /// pergunta acabam discordando, e no dia em que discordarem a pilula
  /// para de dizer QUAL camada esta aberta.
  final Color cor;

  /// Nulo apaga a seta em vez de sumir com ela: na primeira camada nao
  /// ha anterior, e uma pilula que muda de largura conforme a posicao
  /// na pilha faria o alvo da outra seta andar debaixo do dedo.
  final VoidCallback? aoAnterior;

  /// Nulo apaga a seta da direita, pela mesma razao de [aoAnterior].
  final VoidCallback? aoProxima;

  /// Nulo = a pilula se ajusta ao conteudo. Flutuando sobre a trilha
  /// ela deve ter o tamanho do nome; largura fixa so serve quando ela
  /// divide uma linha com outra coisa e precisa acompanhar o vizinho.
  final double? largura;

  /// O BRANCO PINTADO TEM 32 PX, e nao cresce com o nome.
  ///
  /// A trilha anda de 30 em 30 px (`docs/linha-do-tempo-alight.md`):
  /// uma peca mais alta que isto ja invade a camada vizinha, e uma que
  /// mudasse de altura a cada troca empurraria a faixa inteira para
  /// baixo — a faixa que o dedo esta usando.
  static const double altura = 32;

  /// O ALVO E MAIOR QUE O DESENHO: a caixa mede 48 px de alto e os 32
  /// brancos ficam centrados nela.
  ///
  /// Quarenta e oito e o piso de alvo tocavel deste aplicativo, o mesmo
  /// motivo pelo qual o transporte mede 48 e nao os 32 da referencia
  /// (ver [LinhaDoTempo.alturaDoTransporte] — ha teste cobrando o
  /// piso). Engordar o branco ate 48 pagaria o dedo e estragaria a
  /// trilha; crescer so o alvo paga o dedo sem pintar nada a mais.
  static const double alturaDoAlvo = 48;

  /// A SETA MEDE 44 PX DE LARGURA pelo mesmo motivo, que e o piso de
  /// largura tocavel. Na horizontal sobra tela — a pilula flutua e nao
  /// disputa a linha com ninguem —, entao aqui o alvo sai de graca.
  static const double larguraDaSeta = 44;

  /// O CHIP PARA EM 140 PX. Nome de camada nao tem limite de tamanho, e
  /// sem teto um "Circulo 1 copia copia" empurraria a seta da direita
  /// para fora da tela. Reticencias mentem menos do que uma seta que
  /// sumiu.
  static const double larguraMaximaDoChip = 140;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: alturaDoAlvo,
    width: largura,
    child: Stack(
      children: [
        // O BRANCO FICA ATRAS E SO NO MEIO DA CAIXA. Ele e desenho; a
        // fila que vem depois e alvo. Separados, a area tocavel cresce
        // para os 48 px do dedo sem que a pilula engorde sobre a
        // trilha. Posicionado, ele nao entra na conta do tamanho da
        // pilha: quem manda na largura continua sendo a fila.
        Positioned(
          left: 0,
          right: 0,
          top: (alturaDoAlvo - altura) / 2,
          height: altura,
          child: const DecoratedBox(
            decoration: ShapeDecoration(
              color: AmColors.cabecote,
              shape: StadiumBorder(),
            ),
          ),
        ),
        Row(
          // COM LARGURA, AS SETAS VAO PARA AS PONTAS; sem ela, a pilula
          // encolhe ate o conteudo e `spaceBetween` nao tem sobra para
          // distribuir, entao as duas configuracoes cabem no mesmo Row.
          mainAxisSize: largura == null
              ? MainAxisSize.min
              : MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Seta(
              icone: Icons.chevron_left_rounded,
              rotulo: 'Camada anterior',
              aoTocar: aoAnterior,
            ),
            // O CHIP SO E FLEXIVEL QUANDO HA LARGURA PARA REPARTIR. Num
            // Row de largura livre a restricao chega infinita, e filho
            // com flex sob largura infinita e erro de layout, nao
            // encolhimento.
            if (largura == null)
              _ChipDoNome(nome: nome, cor: cor)
            else
              Flexible(child: _ChipDoNome(nome: nome, cor: cor)),
            _Seta(
              icone: Icons.chevron_right_rounded,
              rotulo: 'Proxima camada',
              aoTocar: aoProxima,
            ),
          ],
        ),
      ],
    ),
  );
}

/// A TINTA DAS SETAS E A MESMA QUE A TRILHA USA sobre uma barra clara:
/// `#0B0E12`, o que [sobreACorDaCamada] devolve para fundo claro. Preto
/// puro nao aparece em nenhuma outra peca do editor, e ter dois pretos
/// parecidos e ter um deles errado sem ninguem saber qual.
const Color _tintaDaSeta = AmColors.onAction;

/// QUANTO SOBRA DA SETA APAGADA: um quarto. Menos que isso e some, e
/// sumir e justamente o que nao se quer — apagada, a seta ainda diz
/// "acabou a pilha" sem tirar nada do lugar.
const double _setaApagada = .25;

/// O ICONE E PEQUENO DENTRO DE UM ALVO GRANDE. O alvo mede 44x48 por
/// causa do dedo; o desenho fica em 18 px porque quem le a pilula esta
/// lendo o NOME — duas setas gordas nas pontas disputariam com ele.
const double _tamanhoDaSeta = 18;

/// UMA SETA APAGADA CONTINUA OCUPANDO O LUGAR DELA.
///
/// Sumir com a seta na ponta da pilha mudaria a largura da pilula e
/// moveria a outra seta debaixo do dedo de quem esta percorrendo as
/// camadas. Apagada, ela ainda diz "acabou" sem trocar nada de lugar.
class _Seta extends StatelessWidget {
  const _Seta({
    required this.icone,
    required this.rotulo,
    required this.aoTocar,
  });

  final IconData icone;
  final String rotulo;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: true,
    enabled: aoTocar != null,
    label: rotulo,
    child: GestureDetector(
      // OPACO ATE APAGADA: a pilula flutua sobre a trilha, e um toque
      // que a atravessasse moveria o tempo ou trocaria a selecao sem
      // que ninguem tivesse mirado la embaixo.
      behavior: HitTestBehavior.opaque,
      onTap: aoTocar,
      child: SizedBox(
        width: PilulaDeNavegacao.larguraDaSeta,
        height: PilulaDeNavegacao.alturaDoAlvo,
        child: Center(
          child: Icon(
            icone,
            size: _tamanhoDaSeta,
            color: aoTocar == null
                ? _tintaDaSeta.withValues(alpha: _setaApagada)
                : _tintaDaSeta,
          ),
        ),
      ),
    ),
  );
}

/// O RAIO DO CHIP: 6. Arredondado por inteiro ele viraria capsula, e
/// capsula aqui e a forma de quem se toca — o chip nao se toca, so as
/// setas. Quadrado, ele encostaria nas quinas do branco. Os 8 da caixa
/// de valor do painel sao de outra peca, essa sim tocavel.
const double _raioDoChip = 6;

/// O RESPIRO DE DENTRO: 10 na horizontal, 4 na vertical. Na horizontal
/// e maior porque o texto encosta no canto arredondado antes de encostar
/// na borda reta; na vertical e curto para o chip inteiro caber, com ar
/// em cima e embaixo, dentro dos 32 px de branco.
const EdgeInsets _respiroDoChip = EdgeInsets.symmetric(
  horizontal: 10,
  vertical: 4,
);

/// O CORPO DO NOME: 12. Quem decide e o teto de 140 px do chip — maior
/// que isso e um nome comum ja sai cortado; menor, o nome deixa de se
/// ler de relance por cima de uma trilha colorida.
const double _corpoDoNome = 12;

/// O NOME MORA NUM CHIP DA COR DA CAMADA, e nao solto sobre o branco.
///
/// A cor e a unica coisa que liga esta pilula a barra la embaixo na
/// trilha: sem o chip, o nome seria texto preto igual ao de qualquer
/// outra camada, e a pilula diria o nome sem dizer de quem ele e.
class _ChipDoNome extends StatelessWidget {
  const _ChipDoNome({required this.nome, required this.cor});

  final String nome;
  final Color cor;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    label: nome,
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: PilulaDeNavegacao.larguraMaximaDoChip,
      ),
      child: Container(
        padding: _respiroDoChip,
        decoration: BoxDecoration(
          color: cor,
          borderRadius: BorderRadius.circular(_raioDoChip),
        ),
        child: Text(
          nome,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            // A COR DO TEXTO SAI DA LUMINANCIA DA CAMADA, pela conta da
            // trilha e nao por uma copia dela: preto fixo so funcionava
            // enquanto todas as cores eram claras, e duas contas para a
            // mesma pergunta acabam discordando no dia em que alguem
            // mexer numa so.
            color: sobreACorDaCamada(cor),
            fontSize: _corpoDoNome,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}
