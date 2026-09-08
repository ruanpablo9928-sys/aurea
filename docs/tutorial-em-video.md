# Tutoriais em vídeo, gravados pelo próprio app

O primeiro é o da **Cena 3D**: criar o projeto, adicionar a cena, pôr um
cubo, animar com Auto-key, criar uma segunda câmera, cortar entre as
duas, mandar a câmera olhar para o objeto e voltar para o editor.

Ele aparece em dois lugares: na **Início** ("Tutorial em vídeo: sua
primeira cena 3D") e dentro do **Estúdio 3D**, no menu ⋮ ("Tutorial em
vídeo"). A tela mostra o vídeo em cima e os passos embaixo; o passo que
está tocando fica aceso, e tocar num passo pula para ele.

## Por que gravado pelo app, e não filmando um celular

Não abrimos emulador aqui, e uma filmagem de tela envelhece a cada
mudança de UI. O gravador é um teste de widget que **usa o app de
verdade** — os mesmos widgets, a mesma cena 3D, o mesmo pintor — e tira
um PNG por quadro. Se um botão mudar de nome, o gravador falha (ele
procura o botão pela chave), e aí a gravação é refeita junto com a
mudança, em vez de ficar mostrando uma tela que não existe mais.

O que a gravação não tem: a barra de status do sistema e o gesto físico
(o dedo é desenhado na montagem, sobre a posição real do toque).

## Como regravar

Dois passos, na raiz do projeto:

```bash
AUREA_GRAVAR_TUTORIAL=1 flutter test test/tutoriais/gravar_tutorial_cena3d_test.dart
```

```bash
python test/tutoriais/montar_tutorial_cena3d.py
```

O primeiro escreve `build/tutorial/cena3d/`: um PNG por quadro,
`quadros.json` (duração de cada quadro e onde o dedo estava) e
`cenas.json` (o texto de cada passo e em que segundo começa). Sem a
variável de ambiente, o teste não faz nada — a suíte normal não gasta
tempo com ele.

O segundo desenha o dedo e a faixa de legenda, junta tudo com o ffmpeg
embutido do `imageio_ffmpeg` e escreve:

| Arquivo | Para quê |
|---|---|
| `assets/tutoriais/cena3d.mp4` | O que vai dentro do app (480 px de largura). |
| `assets/tutoriais/cena3d.jpg` | O pôster, para quando o vídeo não abre. |
| `assets/tutoriais/cena3d.json` | Os passos com início e fim — é o índice da tela. |
| `Downloads/Aurea-Tutoriais/tutorial-cena3d.mp4` | A versão grande, para mandar no grupo. |
| `Downloads/Aurea-Tutoriais/tutorial-cena3d.srt` | As legendas soltas, para YouTube/Instagram. |

## Como escrever outro tutorial

Copie `test/tutoriais/gravar_tutorial_cena3d_test.dart`. O gravador tem
cinco verbos:

- `g.cena('texto')` — abre um passo novo; o texto vira a legenda daqui
  em diante e uma linha na lista da tela.
- `g.tocar(finder)` — mostra o dedo, toca e some.
- `g.arrastar(finder, Offset)` — arrasto com o dedo acompanhando.
- `g.segurar(segundos)` — segura o quadro (para dar tempo de ler).
- `g.assentar()` — alguns quadros seguidos, para uma folha subindo ou
  uma rota entrando.

Prefira **chaves** (`ValueKey('estudio-camera')`) a textos: elas mudam
menos. E ponha um `expect` nos momentos que provam que o passo
funcionou (o keyframe gravado, a câmera no ar, o `lookAtNodeId`) — é o
que impede o tutorial de mostrar um caminho que já não existe.

Depois, no app: `TutorialScreen(id: 'seu-id')`, e o JSON e o MP4 com
esse nome em `assets/tutoriais/`.
