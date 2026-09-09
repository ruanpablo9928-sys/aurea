# O travamento com modelo 3D — o que foi medido, e o que era engano

Registro do que aconteceu entre os builds 63 e 68, escrito porque três
entregas seguidas "corrigiram" o problema sem corrigir nada, e o motivo
disso é aproveitável.

## O relato

iPhone 13. Projeto com cena 3D e modelo importado. Tocar em algo só
responde depois de uns dois segundos; arrastar trava tudo. Só acontece
com modelo importado.

## O que o aparelho dizia

O build 67 já trazia um registro de travadas na tela
Ajustes → Cena 3D → Travadas. Ele dizia, em toda entrada:

```
1533 ms  (constroi 1533, desenha 0)  nada marcado  |  motor=GPU pronto=true ...
```

Duas leituras minhas, e as duas erradas:

1. **"`desenha 0` inocenta o motor 3D."** Não inocenta. O Flutter conta
   como `constroi` tudo que roda em Dart no quadro — construir, posicionar
   e **pintar**. `CustomPainter.paint` e a chamada de desenho da GPU
   partem daí. `desenha` é só a rasterização.

2. **"`nada marcado` prova que a causa está fora das marcas."** Não
   provava nada. Era o instrumento quebrado.

## O defeito do instrumento

As marcas eram empilhadas e desempilhadas dentro de `marcando`, e quem
lia a pilha era o retorno de `addTimingsCallback`. Esse retorno **não
acontece durante o quadro**: o Flutter junta os tempos em lote e os
entrega "dentro de mais ou menos um segundo", para o custo de medir não
pesar na versão entregue. Quando ele chegava, o `finally` de toda marca
já havia rodado e a pilha estava vazia.

`nada marcado` era, portanto, **a única saída possível** — inclusive
numa travada de 1.800 ms cuja causa estava marcada. Eu li isso como
resultado e fui procurar no lugar errado, duas vezes.

Agora cada marca se cronometra a si mesma e soma o que gastou, e o corte
do quadro vem de `LigacaoQueMedeOQuadro`, que marca o início no primeiro
código Dart do quadro (`handleBeginFrame`) e fecha a conta num retorno
persistente, logo depois de pintar. Nada depende de retorno atrasado, e
o ócio entre quadros não conta mais como travada.

## Os dois defeitos reais que apareceram no caminho

### 1. A estimativa de triângulos era cega para o modelo importado

`trianglesEstimados` só olhava `node.mesh`. Um nó de modelo importado tem
`mesh` **nulo** — a geometria mora em `modelAsset`. A conta caía no valor
de primitiva e devolvia **32**, para um modelo de **73.187 faces**
(medido em `test/pintor_cpu_modelo_pesado_test.dart`).

Consequências:

- o teto do pintor de CPU, entregue no build 66 exatamente para proteger
  contra modelo importado, **nunca disparava para modelo importado**;
- o registro do aparelho vinha com `PINTOU-EM-CPU=32tri` com o modelo
  inteiro na cena, e eu li aquilo como "o pintor de CPU está fora disto".

### 2. O teto e o orçamento eram dois números que não se falavam

O pintor cortava o modelo em 40.000 faces (12.000 em rascunho); o
orçamento recusava qualquer cena acima de 3.000. Corrigida a estimativa,
**todo** modelo importado passaria a cair no substituto — inclusive na
tela de Animação de modelo, que existe para mostrar o modelo.

Agora o teto **é** o orçamento: um modelo de 73 mil faces vira um de 3
mil e aparece. O substituto ficou para o que a decimação não resolve
(muitos objetos, muitas cópias), que é o caso para o qual foi escrito. A
exportação continua sem teto e leva o modelo inteiro.

### 3. A assinatura do nó usava identidade onde precisava de valor

Em `CacheDeMalhas`, a assinatura que decide se o nó é **destruído e
refeito na GPU** usava `identityHashCode(motion)`. Como o nó é imutável,
toda reconstrução traz um `ModelMotion3D` novo com o mesmo conteúdo:
objeto novo, hash novo, assinatura nova, modelo inteiro derrubado e
resubido a cada edição.

É o mesmo defeito já encontrado no cache de `ModelAsset3D.evaluate` e
corrigido lá com igualdade por valor. Aqui ele tinha sobrado, um andar
acima — e um andar acima custa mais caro.

## A versão que o app dizia ter

A tela Sobre mostrava `1.2.0 (35)` escrito à mão enquanto o `pubspec` já
estava em `1.6.6+67`. Trinta e duas entregas de diferença. Isso não é
cosmético: quando chega um registro de travada, a primeira pergunta é "de
qual build?", e a única tela que devia responder respondia errado — uma
rodada inteira de diagnóstico se perdeu nisso. Agora é uma constante só,
e `test/versao_bate_com_pubspec_test.dart` falha se ela sair de sincronia
com o `pubspec`. O registro também passou a trazer `app=` na primeira
linha.

## O que fica

Nenhuma das três correções está provada como **a** causa dos 1.500 ms no
iPhone 13 — só o registro do aparelho pode dizer isso, e é para isso que
o build 68 existe. O que está provado é que as três eram defeitos reais
no caminho exato do relato, e que a medição anterior não podia responder
à pergunta que eu estava fazendo a ela.

As marcas agora cobrem: a sincronia da cena 3D inteira (nós, luzes,
ambiente, névoa e pós), o desenho na GPU, o pintor de CPU, a avaliação do
modelo importado, a construção da linha do tempo, do palco e da
composição, a gravação do projeto, e — por cima de tudo — `drawFrame`.
Com isso, um `nada marcado` deixou de ser ambíguo: ou o custo está num
tique de animação, ou está em construção/posicionamento de algo que
ninguém cronometrou. São duas hipóteses, não infinitas.
