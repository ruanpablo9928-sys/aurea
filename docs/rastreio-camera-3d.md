# Rastreio de câmera 3D e rastreio de objetos

Beta 53 (2026-09-07).

Duas ferramentas novas na mesma porta: **⌖ Rastrear**, nas ações rápidas
de qualquer camada de vídeo.

## Por que existem

O app já sabia seguir um ponto (`tracker2d.dart`, usado por estabilizar e
reenquadrar) e já sabia detectar regiões em movimento
(`blob_track.dart`). Nenhuma das duas servia para o que as pessoas pedem:

- o **Blob Tracker** só **desenhava caixas**. Via-se o rastreio e não
  dava para pendurar nada nele. Além disso vivia escondido dentro de um
  efeito, atrás de quatro passos.
- **rastreio de câmera 3D não existia**. Sem ele, cena 3D em cima de
  vídeo é sempre um adesivo: o vídeo se move e o objeto fica parado.

## Seguir um objeto (2D)

Um toque em **Procurar objetos** faz tudo: cria o efeito de rastreio na
camada se ainda não existir, extrai os quadros e roda a detecção. O
resultado vira uma lista de objetos, do que atravessa o plano inteiro
para o que passou de relance (os de menos de 4 quadros nem aparecem —
são ruído).

Escolhido o objeto, a folha pergunta **qual camada gruda nele**. Daí o
caminho do blob vira keyframes de posição na camada escolhida, com
**Crescer e encolher junto** opcional (a escala segue a largura da
caixa).

A conversão passa pela **caixa da camada de vídeo**, não pela composição:
o vídeo pode estar deslocado, ampliado ou girado, e nesse caso o objeto
tem de acompanhar o que se vê, não o arquivo.

## Rastrear a câmera em 3D

Descobre por onde a câmera passou e monta uma **camada de cena 3D** por
cima do clipe, com fundo transparente, a câmera rastreada e a nuvem de
pontos. O que entrar nessa cena fica parado no lugar do mundo real.

### O caminho da conta

| Passo | Onde | O que faz |
|---|---|---|
| 1 | `pontos_seguidos.dart` | Acha **cantos** (Shi‑Tomasi: menor autovalor da matriz de estrutura) e segue cada um por correlação normalizada, com refino subpixel e reposição quando o time encolhe. |
| 2 | `camera_solver3d.dart` | **Par inicial** com paralaxe suficiente → **matriz essencial** (8 pontos + RANSAC) → 4 poses possíveis → **cheiralidade** escolhe a única que põe a cena na frente das duas câmeras. |
| 3 | idem | **Ressecção** de cada quadro (Gauss‑Newton amortecido com peso de Huber) e **interseção** (retriangulação com todas as vistas). Repetido três vezes — um ajuste de feixes pobre, que converge. |
| 4 | idem | **Distância focal por varredura**: resolve uma versão curta com 14 focais candidatas e fica com a que explica melhor as observações. Duas vistas não decidem a focal; sete decidem. |
| 5 | `cena_do_rastreio.dart` | Converte para `Camera3D` (posição, alvo, **giro** e focal em mm) e monta a camada. |

A álgebra necessária está em `algebra_numerica.dart` (Jacobi para
simétricas, núcleo de sistema homogêneo, eliminação com pivô, Rodrigues).
Não há pacote de álgebra no projeto e não valia trazer um.

### O que ele recusa, e por quê

Antes de qualquer conta, o solver mede o **resíduo de uma homografia**
entre pares de quadros espalhados. Se uma transformação plana já explica
todo o movimento, ou a câmera girou no lugar (tripé) ou o que aparece
está todo na mesma distância — e nos dois casos a profundidade não está
na imagem.

Isso importa porque a solução degenerada **parece certa**: sem
translação a conta fecha com as câmeras todas no mesmo ponto e erro de
reprojeção zero. Quem confiasse nela veria o objeto colado nadar assim
que a câmera mexesse. Medido nos testes: cena 3D com translação dá
resíduo de 6 a 15 px; rotação pura dá 0 a 0,5 px. O corte fica em
0,8 px (0,33 % da largura analisada).

Também recusa com explicação quando há **poucos pontos** (plano liso,
céu limpo, desfoque forte).

### O que não dá para saber

A **escala**. Duas fotos de uma maquete e de um prédio são idênticas.
Por convenção a nuvem sai num raio de 350 unidades, que é a ordem de
grandeza do resto da cena 3D do app.

A **orientação** vem de "a câmera estava em pé": o topo médio das
imagens vira +Y. Ajustar por um plano de chão seria mais preciso quando
há chão, e desastroso quando o que domina o quadro é uma parede — por
isso `definirChao(solucao, ids)` existe à parte, para quando a pessoa
escolhe os pontos.

## Como isso é testado

Um solver de câmera não se testa olhando: quando erra, o sintoma é a cena
escorregando no vídeo, e aí já é tarde. Os testes fazem o caminho
inverso — montam uma cena 3D conhecida, projetam nos quadros e conferem
se o solver devolve o que se sabe ser a resposta.

- `camera_solver3d_test.dart`: recupera o caminho da câmera com menos de
  2 % de erro de forma; aguenta 1 px de ruído de rastreio; descobre a
  focal dentro de 25 %; recusa rotação pura.
- `cena_do_rastreio_test.dart`: **fecha o círculo** — monta a câmera do
  app a partir da solução e reprojeta a nuvem usando a projeção do
  motor. Mediana de erro abaixo de 0,5 px, com 14 graus de câmera
  inclinada. É este teste que pega o erro clássico de câmera rastreada:
  enquadramento certo, cena inteira tombada.
- `pontos_seguidos_test.dart`: cantos espalhados, deslocamento conhecido
  com precisão subpixel, reposição em travelling longo.
- `rastreio_ui_test.dart`: a porta de entrada existe e grudar move mesmo
  a camada.

## Custo

O rastreio roda em 240 px de largura, a 8 quadros por segundo, até 240
quadros. Seguir os pontos e resolver a câmera saem da thread da interface
(`Isolate.run`) — na thread principal isso é o app congelado.

A solução é **gravada em disco** por camada. Resolver de novo a cada
abertura custaria segundos e, pior, moveria o objeto que a pessoa colou
no plano.

## Uma limitação que vale saber

A cena 3D é desenhada no tamanho da **composição**, e o ângulo de visão
resolvido vale para a largura do **quadro analisado**. Os dois só
coincidem quando o clipe rastreado preenche a composição — que é o caso
normal.

Com o vídeo encaixotado numa composição de outra proporção, o 3D fica
certo na horizontal e desencontrado na vertical. A folha avisa quando as
proporções diferem em mais de 3 %.
