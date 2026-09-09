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

Efeitos, bordas, sombras, máscaras e modos de mistura. Por decisão, não
por esquecimento — cada um tem etapa própria.

## Os três estados

São **mutuamente exclusivos**: nunca há dois painéis empilhados, e nenhum
painel invisível continua recebendo gestos atrás do outro.

| Estado | O que mostra |
| --- | --- |
| Recolhido | faixa com "Ferramentas da camada" e o `+` |
| Categorias | cabeçalho (nome + tipo) e a grade de cartões |
| Categoria | cabeçalho (Voltar · categoria · camada) e o conteúdo |

Sem seleção, a faixa diz **"Selecione uma camada"** e não abre.

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

## O `+` nesta etapa

Ele **existe, ocupa o lugar dele e está desligado**, com explicação. Não
some para reaparecer na 2C: mudar o layout debaixo da mão de quem está
validando é pior que um botão inerte.

O lugar é reservado no layout, ao lado da faixa. Ele **não flutua sobre a
linha do tempo** — sobrepor um keyframe, o olho, uma barra de camada ou a
cápsula de tempo tornaria esses alvos intocáveis justamente na região
mais disputada da tela.

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
