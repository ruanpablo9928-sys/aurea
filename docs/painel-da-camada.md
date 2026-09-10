# O painel de ferramentas da camada

Painel inferior recolhível que muda conforme a camada selecionada.
Entregue em três partes; **esta é a 2A**.

| Entrega | Conteúdo | Estado |
| --- | --- | --- |
| **2A** | estrutura, navegação, seleção — **só leitura** | pronta |
| 2B | ligar os controles aos comandos existentes | a fazer |
| 2C | o botão `+` e os criadores/importadores | a fazer |

## O levantamento que decide o que aparece

A regra é **capacidade real**, não nome do tipo. Uma categoria só entra
quando existe um comando no `EditorController` que a atende.

| Categoria | Comando | Tipos |
| --- | --- | --- |
| Mover e transformar | `editPosition`, `editScaleUniform`, `editRotation` | todos |
| Opacidade | `editOpacity` | todos |
| Texto | `editTextLayer` | `TextLayer` |
| Forma | `editShapeParam` | `ShapeLayer` |
| Volume | `editVideoVolume` | `VideoLayer` |
| Informações da mídia | leitura | imagem, vídeo, áudio |

### Áudio não ganha volume, e isso é de propósito

`AudioLayer` **tem** o campo `volume`. Mas `editVideoVolume` começa com
`if (layer is! VideoLayer) return;` — ele recusa camada de áudio. O
comando é quem manda: anunciar um controle que a operação ignora é pior
do que não ter o cartão.

Quando existir um comando de volume para áudio, a categoria entra sozinha
— basta a linha na tabela de [categoriasDaCamada].

### O nome do cartão diz o que existe

"Opacidade", e não "Mistura e opacidade", porque só há opacidade. O
rótulo é uma promessa; prometer o que não está atrás dele é a forma mais
barata de perder a confiança de quem usa.

### O que ficou fora nesta etapa

Bordas, sombras e modos de mistura. Por decisão, não por esquecimento —
cada um tem etapa própria. Efeitos e **máscara** já entraram.

### Máscara: o recurso que já existia e não tinha porta

O motor sabia fazer máscara desde muito antes desta interface: criar,
apagar, reordenar, trocar o modo, inverter, animar suavidade, expansão e
opacidade, e sete revelações prontas (`applyMaskReveal`). O palco
desenhava. O arquivo salvava. **Nenhum widget chamava.**

Recurso pronto sem porta é o mesmo que recurso ausente, com o agravante
de já ter sido pago. O cartão "Máscara" é a porta, e ele não inventou
nada: cada botão dele é um comando que já estava lá.

A ficha usa a mesma linha das outras — chip, fita e campo. Duas escolhas
merecem registro:

- **O modo cicla num chip só.** São sete modos; sete chips lado a lado
  não cabem nos 300 px do painel, e a lista inteira quase nunca é usada
  (somar e subtrair respondem por quase tudo). O chip mostra o vigente e
  avança ao toque — cabe, e não esconde nenhuma opção.
- **A máscara nasce do tamanho da camada** (`maskBox`), medida com a
  escala neutralizada porque a máscara vive *antes* do transform. Medir
  com a escala ligada aplicaria a escala duas vezes, e toda camada
  aumentada ganharia uma máscara maior que ela.

O cartão não aparece em camada de áudio nem em nulo: nenhum dos dois
desenha um pixel, e recortá-los não mudaria nada na tela.

## Os três estados

São **mutuamente exclusivos**: nunca há dois painéis empilhados, e nenhum
painel invisível continua recebendo gestos atrás do outro.

| Estado | O que mostra |
| --- | --- |
| Recolhido | **nada** — o rodapé inteiro é da linha do tempo |
| Categorias | cabeçalho (nome + tipo) e a grade de cartões |
| Categoria | cabeçalho (Voltar · categoria · camada) e o conteúdo |

### A faixa do rodapé foi removida

Ela existiu: uma barra de 52 px com "Ferramentas da camada" e o `+`,
sempre visível. O problema é o "sempre": 52 px de altura reservados o
tempo inteiro, em toda tela e todo projeto, para oferecer um caminho que
o toque na própria camada já oferece.

**Quem abre as ferramentas hoje é um toque na camada JÁ selecionada**, na
pilha — o primeiro toque escolhe, o segundo abre. É o mesmo gesto do
Alight Motion, onde tocar numa camada mostra o que dá para fazer com ela.
Esses 52 px são da linha do tempo agora.

No modo detalhado não há esse caminho, e é de propósito: lá o toque na
faixa leva o cabeçote, que é o gesto do modo. Quem quer as ferramentas
volta para a pilha — o botão está no cabeçalho, a um toque.

## Duas colunas, e altura pelo conteúdo

Duas colunas no celular: com três, os rótulos começam a truncar, e um
cartão que não se lê não serve de atalho.

O painel **pede só a altura de que precisa**, até um teto de 232 px. Com
altura fixa, três cartões deixavam quase cem pixels de vazio — e cada
pixel ali sai do preview, que é o que a pessoa está olhando. Acima do
teto, o conteúdo rola em vez de empurrar a composição para fora da tela.

Abrir o painel reduz o espaço do preview, mas **não muda** proporção,
resolução nem coordenadas do projeto. O enquadramento é o mesmo, menor.

## O que a 2A garante não fazer

A condição para avançar é severa e está coberta por teste: abrir,
navegar e fechar **não altera** conteúdo, histórico nem o renderizado.

- Entrar em "Opacidade" não inicializa a camada em 100% nem insere
  keyframe.
- Navegar no tempo com o painel aberto não escreve no projeto.
- Recolher mantém a seleção e o tempo — fechar uma gaveta não desfaz o
  que se escolheu.
- O olho continua usando a operação de visibilidade existente, sem abrir
  ferramentas nem deslocar o tempo.

## Seleção por identidade

O painel acompanha o **id** da camada, não a posição na lista. Se ela
deixa de existir (exclusão, desfazer), o painel se recolhe sozinho em vez
de segurar uma referência morta.

## O `+`: um botão redondo e dois níveis

O `+` é o **círculo colorido que flutua no canto inferior direito da
linha do tempo** — o mesmo lugar que o Alight Motion usa, e pelo mesmo
motivo: é o canto que o polegar alcança sem a mão sair de posição, e
acrescentar mais uma camada é a ação mais repetida de quem monta uma
composição.

Ele custa sobrepor uma faixa de trilha, e o custo foi aceito depois de
medido: a região que ele tapa é o fim do último trilho, não a régua nem o
cabeçote. Aberto, ele vira um `x` — o mesmo alvo que chamou o menu o
dispensa.

### Nível 1: a barra de famílias

Abre **em cima do `+`**, presa a ele. Só ícones, com um rótulo minúsculo
embaixo: quem já sabe lê o ícone, quem não sabe lê a palavra, e nenhum
dos dois paga o preço do outro. Ela rola na horizontal — são sete
famílias hoje e vão ser mais, e uma barra que aperta os ícones até
ninguém acertar o dedo é pior que uma que rola.

| Família | O que tem dentro |
| --- | --- |
| 3D | Cena 3D · Nulo 3D · Objetos 3D · Partículas |
| Texto | Texto |
| Formas | Retângulo · Elipse · Polígono · Estrela · Setor · Anel |
| Imagens | Da galeria |
| Vídeos | Da galeria |
| Áudio | Arquivo · De um vídeo |
| Ferramentas | Camada de ajuste |

### Nível 2: o painel do meio

A família abre um painel **no centro da tela, com o resto desfocado**.
Escolher o que criar é uma decisão, e enquanto ela está aberta não há o
que fazer atrás. O desfoque diz isso sem apagar o contexto — dá para ver
qual projeto está embaixo.

O desfoque custa **um passe de GPU**, e por isso a reprodução para antes
de ele aparecer: desfocar sessenta quadros por segundo de composição
seria pagar caro por um fundo que ninguém está olhando.

Um item pode ter **filhos** em vez de criar: é o caso de "Objetos 3D",
que são dezessete primitivas. Ele abre mais um nível dentro do mesmo
painel, com um Voltar no cabeçalho. Dois níveis e o teto — um terceiro
precisa de decisão, não de acidente.

### Tudo aqui é comando que existe

Cada item chama um método do `EditorController` que já está lá:
`addScene3DLayer`, `addNullLayer`, `addElement3DLayer`,
`addParticlesLayer`, `addTextLayer`, `addShapeLayer`,
`importImageFromGallery`, `importVideoFromGallery`, `importAudioFile`,
`addAdjustmentLayer`. Nada de item aceso que abre o nada — o que ainda
não tiver caminho aparece apagado e diz por quê.

O **instante de inserção** é o capturado quando o menu ABRE, e não quando
o toque no item acontece. Assim que o relógio anda os dois deixam de ser
a mesma coisa, e o lugar que a pessoa escolheu foi o de quando abriu.

## O interruptor de validação

`painelDaCamadaLigadoProvider`, ligado por padrão. Desligar devolve a
interface anterior — preview e linha do tempo, sem painel — **sem
converter projeto nenhum**.

## O que 2B precisa resolver

Nada disso está implementado, e nenhum controle deve ser ligado antes:

- **Slider**: um gesto confirmado gera **uma** operação de desfazer;
  cancelar restaura; gesto sem mudança não polui o histórico.
- **Campo numérico**: estados intermediários de digitação (vazio, só o
  sinal) não chegam ao modelo; validar contra os limites reais da
  propriedade, não um limite genérico.
- **Propriedade animada**: sem contrato de edição disponível, mostrar
  "Animado" e bloquear com explicação. Nunca transformar animada em
  estática por causa de um slider.
- **Rascunho pendente**: ao trocar de camada, oferecer Aplicar,
  Descartar ou Continuar editando.
- **Durante reprodução**: pausar ao começar a modificar, sem deslocar o
  cabeçote; não retomar sozinho depois.
