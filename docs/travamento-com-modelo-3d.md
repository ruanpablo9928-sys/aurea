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

---

# O que o build 68 respondeu

O registro voltou do iPhone 13 com a resposta, e ela não era nada do que
eu vinha perseguindo:

```
POR MARCA, desde que o app abriu:
  21984 ms  758x  pior 3662 ms   quadro: construir, posicionar e pintar
  21006 ms  122x  pior 3616 ms   cena 3D: sincronizar
  20234 ms  122x  pior 3445 ms   cena 3D: sincronizar > ambiente
    763 ms  122x  pior  175 ms   cena 3D: sincronizar > nos
    399 ms  143x  pior   71 ms   cena 3D: desenhar na GPU
     64 ms  122x  pior   64 ms   avaliando o modelo importado
```

**O ambiente é 92% do quadro travado.** O modelo importado, que foi a
minha hipótese por três entregas, custou **64 ms no total** — meio
milissegundo por chamada.

Dois números fecham a leitura:

- as seis travadas registradas somam ~20,4 s em `ambiente`, que é o total
  da marca: são **seis eventos discretos de ~3,4 s**, e não um custo
  difuso;
- fora essas seis, os outros 752 quadros somaram 1,5 s — **2 ms por
  quadro**. O aplicativo está fluido; ele tem seis picos.

## O que foi corrigido com isso

O cálculo da radiância não é o culpado: medido em
`test/bancada_ambiente_test.dart`, custa **13–26 ms** num desktop, e a
parte síncrona de abrir o isolate custa **2 ms**. O custo está numa
chamada nativa, e duas coisas erradas no caminho foram corrigidas:

1. **Cada troca de ambiente subia um `EnvironmentMap` novo.** O mapa
   depende só do tipo — são sete no catálogo — e o flutter_scene **não
   libera memória de GPU** (bdero/flutter_scene#285). Seis trocas
   deixavam seis atlas de radiância retidos, além do que o modelo de 73
   mil faces já ocupa. Agora cada tipo sobe uma vez só — e o mesmo vale
   para panoramas de arquivo, guardados pelo caminho, porque o desfoque
   do fundo vive no `Skybox` e não no mapa: mexer no controle de desfoque
   subia um atlas novo a cada passo. É a mesma política de "sobe uma vez"
   que as texturas já seguem, pelo mesmo motivo.

2. **Cada mudança de cor do céu criava um `SkyEnvironment` novo.** O
   pacote fatia o bake do céu em um passe de GPU por quadro — mas só a
   partir do **segundo** bake daquele objeto; o primeiro roda inteiro
   numa chamada só, de propósito, para a cena nascer iluminada. Objeto
   novo a cada mudança fazia todo bake ser o primeiro. Agora o objeto é
   reaproveitado e recebe `invalidate()`.

## O que ainda não está provado

Se a pessoa estiver no céu procedural, nenhum dos dois caminhos acima
roda, e o bloco do céu é síncrono e curto. Por isso as três saídas de
`_sincronizarAmbiente` foram marcadas separadamente — panorama do disco,
mapa HDR na GPU, abrir o isolate e céu procedural. O próximo registro
aponta a linha, sem mais leitura de código.

---

# A causa, provada: abrir isolate custava mais que o trabalho

O registro do build 69, no iPhone 13:

```
17761 ms  1922x  pior 2171 ms   quadro: construir, posicionar e pintar
14223 ms   309x  pior 2154 ms   cena 3D: sincronizar
12471 ms   309x  pior 1960 ms   cena 3D: sincronizar > ambiente
12470 ms     9x  pior 1960 ms   cena 3D: ambiente > abrir isolate
```

**Os dois últimos totais são o mesmo número.** Abrir o isolate era 100%
do custo do ambiente: 1.400–1.960 ms **síncronos**, no fio que recebe o
toque. E não é só o primeiro spawn que custa — a média das nove chamadas
foi 1.385 ms.

O mesmo `Isolate.run` custa **2 ms** num desktop
(`test/bancada_ambiente_test.dart`), então o preço é do spawn em AOT no
iOS, e não do cálculo. E o cálculo que ele evitava custa **13–26 ms**.

> Abrir o isolate saía vinte vezes mais caro do que simplesmente fazer a
> conta.

Isso também explica o relato ao pé da letra: *"a timeline roda lisa até
chegar na camada da cena 3D; se eu vou até o fim e volto pra cima da
camada, ele dá uma travada e volta"*. Entrar na camada remonta a cena,
a sincronia dispara o ambiente, e o spawn congela a tela por dois
segundos. A timeline nunca foi o problema.

A radiância passou a ser calculada no próprio fio, uma vez por tipo, com
os pedidos concorrentes compartilhando o mesmo trabalho. O custo vira um
engasgo de dezenas de milissegundos na primeira vez que cada ambiente
aparece. `test/sem_isolate_na_cena3d_test.dart` impede a volta, porque a
intuição aqui está errada e a tentação de "jogar para um isolate" é
grande.

## O que sobrou, e é dez vezes menor

```
1731 ms  309x  pior 423 ms   cena 3D: sincronizar > nos
 287 ms  305x  pior 245 ms   avaliando o modelo importado
```

O pico de 423 ms em `nos` (dos quais 245 ms avaliando o modelo) continua
sendo uma travada perceptível, e é o próximo alvo — mas é uma ordem de
grandeza abaixo do que acabou de sair.
