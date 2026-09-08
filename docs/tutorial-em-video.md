# Tutoriais em vídeo, gravados pelo próprio app

São três. Todos aparecem na **Início**; os dois de cena 3D também no
menu ⋮ do **Estúdio 3D**, e o do texto dentro do painel **Animação de
texto**:

| id | O que ensina | Duração |
|---|---|---|
| `cena3d` | A primeira cena: criar o projeto, adicionar a Cena 3D, pôr um cubo, mexer no material, animar com Auto-key, criar a segunda câmera, cortar e mandar a câmera olhar para o objeto. | ~1 min |
| `cena-completa` | A cena de verdade: **importar modelos** (o astronauta e a árvore que já vêm no app), posicionar por valor, luz de ponto, animar por keyframe, segunda câmera, **dois cortes no tempo** e a câmera seguindo o personagem. | ~1min24 |
| `texto-bounce` | **Texto que quica, do seu jeito**: escrever, aplicar "Quicar por letra" e mexer no que faz o quique ser seu — amplitude, frequência, decaimento, distância e o atraso entre as letras; e trocar letra ↔ palavra e a ordem. Aparece também dentro do painel Animação de texto. | ~51 s |

A tela mostra o vídeo em cima e os passos embaixo; o passo que está
tocando fica aceso, e tocar num passo pula para ele.

## Por que gravado pelo app, e não filmando um celular

Não abrimos emulador aqui, e uma filmagem de tela envelhece a cada
mudança de UI. O gravador é um teste de widget que **usa o app de
verdade** — os mesmos widgets, a mesma cena, o mesmo pintor — e tira um
PNG por quadro. Se um botão mudar de nome, o gravador falha (ele procura
o botão pela chave), e aí a gravação é refeita junto com a mudança, em
vez de ficar mostrando uma tela que não existe mais.

O que a gravação não tem: a barra de status do sistema e o gesto físico
(o dedo é desenhado na montagem, sobre a posição real do toque).

## Como regravar

Dois passos, na raiz do projeto — o primeiro tutorial:

```bash
AUREA_GRAVAR_TUTORIAL=1 flutter test test/tutoriais/gravar_tutorial_cena3d_test.dart
```

```bash
python test/tutoriais/montar_tutorial.py
```

Para os outros, os mesmos dois comandos trocando o arquivo e o id:

```bash
AUREA_GRAVAR_TUTORIAL=1 flutter test test/tutoriais/gravar_tutorial_cena_completa_test.dart
```

```bash
python test/tutoriais/montar_tutorial.py cena-completa
```

```bash
AUREA_GRAVAR_TUTORIAL=1 flutter test test/tutoriais/gravar_tutorial_texto_bounce_test.dart
```

```bash
python test/tutoriais/montar_tutorial.py texto-bounce
```

O primeiro comando escreve `build/tutorial/<id>/`: um PNG por quadro,
`quadros.json` (duração de cada quadro e onde o dedo estava) e
`cenas.json` (o texto de cada passo e em que segundo começa). Sem a
variável de ambiente, o teste não faz nada — a suíte normal não gasta
tempo com ele.

O segundo desenha o dedo e a faixa de legenda, junta tudo com o ffmpeg
embutido do `imageio_ffmpeg` e escreve:

| Arquivo | Para quê |
|---|---|
| `assets/tutoriais/<id>.mp4` | O que vai dentro do app (480 px de largura). |
| `assets/tutoriais/<id>.jpg` | O pôster, para quando o vídeo não abre. |
| `assets/tutoriais/<id>.json` | Os passos com início e fim — é o índice da tela. |
| `Downloads/Aurea-Tutoriais/tutorial-<id>.mp4` | A versão grande, para mandar no grupo. |
| `Downloads/Aurea-Tutoriais/tutorial-<id>.srt` | As legendas soltas, para YouTube/Instagram. |

## Como escrever outro tutorial

Copie um dos gravadores. A maquinaria mora em `test/tutoriais/gravador.dart`
e tem oito verbos:

- `g.cena('texto')` — abre um passo novo; o texto vira a legenda daqui
  em diante e uma linha na lista da tela.
- `g.tocar(finder)` — mostra o dedo, toca e some.
- `g.arrastar(finder, Offset)` — arrasto com o dedo acompanhando.
- `g.rolarAte(finder)` — rola a folha até o alvo aparecer (as listas são
  preguiçosas: o que está fora da tela nem chega a ser construído).
- `g.valorDoEixo(1, '180')` — digita um número no campo X/Y/Z da
  ferramenta ativa.
- `g.valorDaRegua(finder, de, ate)` — anda um número pela régua, com o
  dedo deslizando junto (funciona mesmo com a régua fora da janela).
- `g.segurar(segundos)` — segura o quadro (para dar tempo de ler).
- `g.assentar()` — alguns quadros seguidos, para uma folha subindo ou
  uma rota entrando.

Prefira **chaves** (`ValueKey('estudio-camera')`) a textos: elas mudam
menos. E ponha um `expect` nos momentos que provam que o passo funcionou
(o keyframe gravado, a câmera no ar, o `lookAtNodeId`) — é o que impede
o tutorial de mostrar um caminho que já não existe.

Cinco armadilhas que custaram tempo, e que já estão resolvidas dentro do
gravador:

1. **Gravar o PNG no meio de um gesto mata o gesto.** `runAsync` sai do
   relógio de mentira do teste e o arrasto morre no caminho; por isso o
   quadro é capturado com `toImageSync` e o disco espera o dedo levantar.
2. **Um arrasto lento perde a arena de gestos.** Cada passo do arrasto é
   um gesto inteiro (desce, anda, sobe); como o efeito é cumulativo, na
   tela dá no mesmo.
3. **Arrastar no palco 3D depende de onde o dedo encosta**: começando
   fora do objeto, o mesmo arrasto orbita a câmera em vez de girar o que
   está selecionado. Para animar, o caminho que sempre funciona é o campo
   de valor (`g.valorDoEixo`) — e é o que se ensina no vídeo.
4. **Um alvo fora da janela recebe o toque mas não o arrasto.** Num
   painel mais alto que a tela, `g.arrastar` rola até ele antes; quando
   nem isso resolve (a régua vive numa lista que só rola por dentro),
   `g.valorDaRegua` anda o número pela própria régua, com o dedo
   deslizando junto — o que se vê é o mesmo.
5. **O texto do palco sai como quadradinhos** se a camada não tiver uma
   fonte que o serviço de fontes conheça: no tutorial do texto, o
   gravador registra a fonte do app (`FontService.registrarSemArquivo`) e
   a aplica à camada antes de gravar.

Um detalhe da montagem: a fonte do app não tem seta nem "⋮". O montador
desenha esses poucos caracteres com a fonte de símbolos do sistema; sem
ela, eles caem para `>`, `<` e `:`.

Para importar um modelo dentro de um tutorial, o seletor de arquivos do
sistema é trocado por um que já sabe o que vai ser escolhido — no
`gravar_tutorial_cena_completa_test.dart`, os próprios modelos do app
(`assets/models/monolito`) escritos numa pasta temporária, que é
exatamente o que a pessoa escolheria na galeria dela.

Depois, no app: `TutorialScreen(id: 'seu-id')`, e o JSON e o MP4 com esse
nome em `assets/tutoriais/`.
