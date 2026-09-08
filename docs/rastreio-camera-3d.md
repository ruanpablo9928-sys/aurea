# Rastreio de câmera 3D

Descobrir por onde a câmera andou olhando só para o vídeo, e devolver
isso como uma câmera 3D de verdade — para que o que a pessoa puser na
cena fique parado no lugar do mundo real enquanto o vídeo corre.

Não é AR. AR lê os sensores do aparelho no momento da filmagem; aqui o
vídeo pode ter vindo de qualquer lugar (galeria, WhatsApp, uma câmera de
verdade), e a única informação disponível são os pixels.

## O caminho, do vídeo ao texto na calçada

```
vídeo → achar pontos → seguir os pontos → ler que cena é essa →
reconstruir a câmera → ver os pontos em cima do vídeo →
escolher uma superfície → definir o chão → criar a câmera 3D →
pôr texto / forma / nulo em cima
```

Na tela isso são três toques: **Rastrear a câmera** → **Ver os pontos e
montar a cena** → **Criar a câmera 3D**. O resto é opcional e serve para
melhorar o resultado.

## As peças

| Arquivo | O que faz |
| --- | --- |
| `domain/pontos_seguidos.dart` | Acha cantos (Shi-Tomasi) e segue cada um quadro a quadro (NCC com ajuste sub-pixel). |
| `domain/algebra_numerica.dart` | Mat3, autovalores por Jacobi, núcleo, sistema linear, rotação ↔ vetor, mediana. |
| `domain/camera_solver3d.dart` | A reconstrução: essencial por 8 pontos + RANSAC, cheiralidade, triangulação DLT, resecção Gauss-Newton com Huber, refinamento alternado, varredura de focal, portões de degenerescência. |
| `domain/plano_do_rastreio.dart` | Ajusta plano a pontos escolhidos, acha a maior superfície por RANSAC, apaga pontos e recalcula o erro. |
| `domain/cena_do_rastreio.dart` | Converte a solução em `Camera3D`, nuvem, e objetos pousados numa superfície. |
| `application/camera_track_service.dart` | Lê o vídeo, roda tudo fora da thread da interface, grava o resultado, permite resolver de novo. |
| `presentation/am/rastreio3d_screen.dart` | A tela: pontos em cima do vídeo, escolha por toque e laço, alvo do plano, ficha de qualidade, avançado. |

## O que o solver recusa, e por quê

Um rastreador que sempre devolve alguma coisa devolve **mentira** nos
casos difíceis — e a mentira só aparece no dia da entrega, com o objeto
nadando pelo quadro. Estes três casos são recusados de propósito, cada um
com uma frase que diz o que fazer:

- **Tripé / giro no lugar.** Sem deslocamento não existe profundidade a
  medir. Uma panorâmica pura tem solução *perfeita* e falsa: câmeras
  todas no mesmo ponto, pontos a qualquer distância, erro de reprojeção
  zero. Pegamos isso três vezes: pelo resíduo da homografia antes de
  qualquer conta, pelo ângulo de paralaxe do par inicial, e pelo percurso
  da câmera comparado ao tamanho da cena.
- **Cena plana.** Uma parede lisa filmada de lado: uma única homografia
  explica todo o movimento, e a matriz essencial fica indeterminada.
- **Sem textura.** Céu limpo, parede lisa, desfoque forte: menos de doze
  pontos que durem.

## As decisões que custaram caro

**O primeiro quadro não é sagrado.** Enquanto o par inicial era sempre
`(quadro 0, melhor parceiro)`, três filmagens comuns não fechavam: o
chicote (a câmera fica quase parada no começo), a filmagem escura (o
ruído do primeiro quadro define a geometria de tudo) e a que começa
borrada. Hoje a semente escolhe a si mesma: candidatos a base espalhados
pela primeira metade, e o par com mais pontos em comum e mais paralaxe
ganha. As três passaram a fechar.

**O erro é por ponto, e não só da cena.** Uma solução com 0,9 px de média
pode ter dez pontos com 6 px cada — e são esses que fazem o objeto
tremer. Com o erro guardado por ponto, a tela pinta cada um pela
qualidade e deixa apagar os ruins.

**Qualidade é erro + permanência.** Um ponto visto em três quadros quase
sempre fecha, porque há poucas observações para contrariá-lo. Sozinho, o
erro premiaria justamente os pontos frágeis.

**Estrelas são o menor entre erro e quantidade.** Erro baixíssimo com
vinte pontos é uma cena frágil, e uma ficha otimista faria a pessoa
confiar nela.

**O objeto pousa, não afunda.** Um sólido deitado exatamente no plano
briga com ele na hora de decidir qual pixel fica na frente, e pisca. Meio
por cento do tamanho da cena acima resolve.

**X cruz normal, e não normal cruz X.** A ordem trocada devolve um trio
de mão esquerda: a matriz parece uma rotação mas é uma reflexão, e o
objeto nascia de cabeça para baixo. Cento e oitenta graus em X, sem nada
na tela explicando.

**Semente fixa no RANSAC do plano.** O mesmo vídeo tem de dar o mesmo
plano em duas aberturas do projeto, senão o objeto colado nele muda de
lugar sozinho entre uma sessão e outra.

## Modos

| Modo | Quadros/s | Pontos | Teto de quadros | Refinos |
| --- | --- | --- | --- | --- |
| Rápido | 5 | 70 | 120 | 1 |
| Equilibrado | 8 | 110 | 240 | 2 |
| Preciso | 12 | 220 | 400 | 4 |

O teto de quadros não é capricho: mil quadros em tons de cinza a 240 px
já são setenta megabytes, e num iPhone 13 isso é o app fechado.

## Tipo de tomada

`auto` (padrão), `lenteFixa`, `zoomVariavel`, `tripe`. Quem escolhe
`tripe` recebe a recusa na hora, sem esperar pela conta — não há o que
resolver.

## Onde tudo roda

A leitura do vídeo usa o ffmpeg embutido. O seguimento e a reconstrução
rodam em **isolates** (`Isolate.run`): são segundos de conta pura, e na
thread principal isso é o app congelado. A interface mostra a etapa pelo
nome — *Lendo o vídeo*, *Achando e seguindo os pontos*, *Vendo que tipo
de cena é*, *Reconstruindo o movimento da câmera* — porque uma barra que
fica trinta segundos em "Analisando..." parece travada.

O resultado é gravado em `camera3d/<idDaCamada>.json`. Reabrir o projeto
não pode custar de novo, e — mais importante — a solução tem de ser a
**mesma** de antes, senão o objeto colado no plano muda de lugar entre
uma sessão e outra.

Os rastros 2D ficam na memória enquanto a sessão dura. É isso que faz
"apagar os pontos ruins e resolver de novo" ser um gesto usável em vez de
uma ameaça: refazer a conta não relê o vídeo.

## O que ainda não existe

- **Shadow catcher.** Precisa de suporte no renderizador (um material que
  só recebe sombra); o pintor de CPU não tem sombras, e na GPU isso é um
  passe novo. Está fora até haver a peça.
- **Modelo 3D direto da tela do rastreio.** O caminho é criar um nulo no
  ponto e pendurar o modelo nele pelo estúdio 3D — escolher modelo é
  outra tela inteira.
- **Focal variável (zoom durante a tomada).** O enum existe e o valor é
  guardado, mas a varredura resolve **uma** focal para o clipe inteiro.
  Um zoom real ainda sai com erro maior.

## Os testes

`test/camera_tracker_pro_test.dart` monta quinze filmagens sintéticas —
frente, lateral, órbita, mão, tripé, cena plana, muita profundidade,
poucas features, movimento rápido, borrão, pouca luz, iPhone, Android,
comprimido, longo — projeta uma cena 3D conhecida nos quadros, joga só as
projeções no solver e confere se ele devolve o que se sabe que é a
resposta.

A prova não é o erro de reprojeção (esse fecha até quando a geometria
está errada): é a **variação de escala**. As distâncias entre as posições
da câmera, na solução e na verdade, têm de estar todas na mesma proporção.
Se estão, a solução é a verdade a menos de escala — que é tudo o que se
pode pedir de uma reconstrução feita só com imagens.

`test/rastreio3d_screen_test.dart` cobre a tela; `test/camera_solver3d_test.dart`
e `test/cena_do_rastreio_test.dart` cobrem a álgebra e a ponte para a cena.

## Por que o pipeline é escrito aqui, e não vendorizado

A pergunta é legítima: OpenCV, COLMAP, OpenMVG, Theia, Ceres, ORB-SLAM e
os SDKs de AR resolvem partes disto há anos. As razões de não trazer
nenhum deles inteiro:

- **ARKit e ARCore não servem para o caso principal.** Eles rastreiam o
  movimento do *aparelho* enquanto ele filma, lendo os sensores. O vídeo
  que chega pela galeria não tem sensores nenhum — e é esse o caso de
  uso. Onde os metadados existirem (vídeo gravado pelo próprio aparelho),
  eles poderiam melhorar a estimativa inicial; hoje não são lidos.
- **COLMAP é a referência de qualidade, não de arquitetura.** Ele é
  desenhado para reconstruir cenas a partir de centenas de fotos numa
  máquina de mesa, com bundle adjustment global sobre milhares de
  parâmetros. Os algoritmos servem de guia (a escolha do par inicial por
  qualidade veio daí); o programa inteiro, não.
- **Vendorizar uma biblioteca nativa custa nas duas lojas.** O projeto já
  carrega o whisper com patch, e cada dependência nativa a mais é mais
  peso no APK, mais superfície de build quebrando, e mais tempo entre
  "achei o bug" e "o testador tem o build". O que este solver faz cabe em
  três arquivos de Dart puro, roda em isolate e não muda o tamanho do
  aplicativo.
- **Dart puro roda igual no Android e no iOS**, e é testável sem
  aparelho. As quinze filmagens sintéticas rodam em dois segundos no PC —
  isso é o que permite mexer no solver sem medo.

Nada de proprietário foi copiado. O fluxo é reconhecível para quem usa AE
porque o problema é o mesmo, não porque o código seja.

**O que uma biblioteca nativa traria, se um dia valer o custo:** bundle
adjustment global (hoje o refinamento é alternado, pose por pose),
descritores invariantes a escala e rotação (hoje o seguimento é NCC entre
quadros vizinhos, que perde o ponto num corte ou numa oclusão longa), e
GPU no casamento de features. Nenhum dos três é o gargalo hoje.
