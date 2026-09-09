# QA final — Release Candidate 1.0.0

Auditoria sistemática feita para fechar a versão 1.0.0. O método foi o
pedido: **encontrar → corrigir → testar de novo**, com regressão completa
da suíte depois de cada correção, e nada dado por bom sem prova.

Tudo o que está aqui foi medido, não estimado. Cada bug abaixo tem um
teste que **falhava antes** da correção e **passa depois** — e que fica no
repositório para não deixar o problema voltar.

---

## 1. Resultado

| | |
|---|---|
| Campanhas de auditoria | 7 |
| Testes novos escritos | 54 |
| Bugs encontrados | 9 |
| Bugs corrigidos | 9 |
| P0 abertos | **0** |
| P1 abertos | **0** |
| Suíte completa | **1 860 testes, 0 falhas** (15 pulados, todos por dependencia de aparelho) |

Nenhum bug foi encontrado por leitura de código. Todos apareceram por
execução — varrendo catálogos inteiros, empurrando valores até o extremo
e alimentando o aplicativo com arquivos estragados de propósito.

---

## 2. Os bugs, por severidade

### P0 — perda de trabalho

**1. Projeto com um campo faltando não abria (e derrubava o aplicativo).**
Qualquer campo ausente no arquivo — um projeto de uma versão antiga, um
arquivo cortado pela bateria acabando no meio da gravação, um template
escrito à mão — fazia a leitura estourar com erro de tipo. O projeto
inteiro se perdia.
*Correção:* leitura tolerante em `project_store.dart`. Cada campo tem um
valor razoável de reserva, e uma camada quebrada é pulada sem levar o
resto junto.
*Prova:* `qa_1_0_entrada_hostil_test.dart`.

**2. Um número impossível impedia de salvar.**
`NaN` e infinito são números válidos em Dart e inválidos em JSON. Bastava
uma escala em cima de outra, ou uma expressão com divisão por zero, para
a gravação falhar — e o trabalho da sessão inteira se perdia, sem aviso
útil.
*Correção:* peneira final antes do arquivo troca esses números por zero.
Um valor zerado se conserta na tela; um projeto que não grava, não.
*Prova:* `qa_1_0_entrada_hostil_test.dart`.

**3. Apagar a camada em solo deixava o projeto inteiro invisível.**
A marca de solo ficava órfã no arquivo depois de a camada ser apagada.
Como "havendo solo, só o solo desenha", **todas** as camadas restantes
sumiam — na prévia e no arquivo exportado. Não havia botão para desligar,
porque o botão morava justamente na camada que não existia mais.
*Correção:* solo sem dono não manda em ninguém, e apagar a camada leva
junto a ficha dela (o que também para de engordar o arquivo).
*Prova:* `qa_1_0_timeline_e_camadas_test.dart`.

**4. Um efeito ilegível levava a camada inteira junto.**
Um efeito de uma versão mais nova, ou com um pedaço corrompido, fazia a
camada toda desaparecer na abertura — texto, formas, keyframes, tudo.
*Correção:* a mesma regra já aplicada às camadas passa a valer para
efeitos e máscaras: pula o item, mantém a camada.
*Prova:* `qa_1_0_exportacao_e_sessao_test.dart`.

### P1 — recurso quebrado

**5. Desfazer engolia ações inteiras.**
A janela de 450 ms que junta um arrasto num passo só juntava também
ações deliberadas: adicionar uma forma e mudar a opacidade virava **um**
passo, e um desfazer sumia com a forma inteira. Dois toques rápidos em
"adicionar camada" também viravam um.
*Correção:* toda ação que mexe na lista de camadas é sempre um passo
próprio, e o primeiro ajuste depois de uma ação estrutural também.
*Prova:* `qa_1_0_desfazer_e_ciclo_test.dart`.

**6. Cortar em lote virou trinta passos de desfazer.**
Consequência da correção 5, apanhada pela regressão no mesmo ciclo:
"cortar nas marcações" e "decupar sozinho" deixaram de ser um passo só.
*Correção:* agrupamento explícito, que não depende de tempo nenhum.
*Prova:* `scene_cut_test.dart` (já existia) + `qa_1_0_timeline_e_camadas_test.dart`.

**7. Rastreio de blobs quebrava o quadro nos modos Somar e Tela.**
A sobreposição posicionada virava filha do misturador de mescla. Em
depuração isso levanta erro de árvore; em produção a sobreposição fica
sem tamanho e **some**.
*Correção:* o posicionamento passou para fora da mescla.
*Prova:* `qa_1_0_catalogo_de_efeitos_test.dart`.

**8. Rastreio de blobs em "só sobreposição" derrubava o quadro inteiro.**
Uma pilha com todos os filhos posicionados não tem de onde tirar largura
e altura. Sob restrição livre — que é o caso de qualquer camada com
transformação — isso não quebrava só o efeito: quebrava o quadro.
*Correção:* o conteúdo da camada continua na pilha para dar tamanho, com
opacidade zero (o Flutter não chega a pintá-lo).
*Prova:* `qa_1_0_catalogo_de_efeitos_test.dart`.

### P2 — comportamento errado sem perda

**9. Legenda com fim antes do começo entrava na lista.**
Um SRT assim existe (exportador torto, edição à mão). A legenda nunca
aparecia e ainda bagunçava a ordenação de quem desenha.
*Correção:* essas entradas ficam de fora na leitura.
*Prova:* `qa_1_0_entrada_hostil_test.dart`.

---

## 3. O que foi testado, campanha por campanha

### Campanha 1 — nada se perde ao salvar e reabrir
Varredura de **catálogo**, não de exemplos escolhidos a dedo: os 56
efeitos (com parâmetros animados), os 36 presets de animação de texto em
todos os seus slots, todas as primitivas de forma, todos os tipos de
objeto 3D e todas as curvas de keyframe. Cada um grava e volta idêntico.
Um catálogo cresce; varrendo o catálogo, o efeito novo de amanhã entra na
conta sozinho.

### Campanha 2 — entrada hostil
JSON corrompido, arquivo cortado no meio, expressão inválida, valores
extremos (`NaN`, infinito, 10^300), texto vazio, texto de 20 mil
caracteres, emoji, escrita da direita para a esquerda, duração zero,
mídia que não existe, SRT quebrado, cinco efeitos empilhados.
**Encontrou os bugs 1, 2 e 9.**

### Campanha 3 — desfazer, refazer e o ciclo completo
Granularidade do histórico ação a ação, arrasto de valor como passo
único, desfazer além do início, refazer além do fim, refazer cortado por
uma operação nova, e o ciclo inteiro: criar de tudo, salvar, fechar,
reabrir e conferir propriedade por propriedade. Mais cem idas e voltas
seguidas provando que o arquivo não incha.
**Encontrou o bug 5** (e a regressão 6 apareceu na verificação).

### Campanha 4 — todo efeito, em todo extremo
A ficha de cada parâmetro (mínimo < máximo, inicial dentro da faixa,
escolhas com opções suficientes), os extremos sobrevivendo ao arquivo,
valores mil vezes além do limite, e **o desenho de verdade**: cada um dos
56 efeitos renderizado com todos os parâmetros no mínimo e depois no
máximo, mais pilhas de cinco efeitos no máximo.
**Encontrou os bugs 7 e 8.**

### Campanha 5 — linha do tempo sob carga
Projetos de 10, 50 e 100 camadas: criar, salvar, reabrir e conferir uma a
uma; reordenar sem embaralhar as vizinhas; apagar trinta de uma vez;
cortar uma camada em vinte pedaços sem sobreposição. Duplicação de todos
os tipos de camada com prova de **independência** (mexer na cópia não
mexe no original). Agrupar e desagrupar devolvendo tudo no lugar.
Travada, escondida e solo sobrevivendo ao arquivo. E a prova em pixel de
que o olho fechado não aparece no vídeo exportado.
**Encontrou o bug 3.**

### Campanha 6 — o que sai no arquivo, e o texto que anima
Prova em pixel de que a prévia e o arquivo exportado são **o mesmo
quadro**, e de que as ajudas de edição só existem na prévia. Cada um dos
36 presets de texto medido em oito instantes para provar que anima de
verdade (com cor saturada, porque metade deles mexe em matiz e branco não
muda de cor). Nomes de arquivo com espaço, acento, emoji, aspas e
japonês.

### Campanha 7 — exportação e sessão longa
Todas as combinações de tamanho, codec, formato, qualidade e fps sobre
seis formatos de projeto — 1 080 combinações — provando que nenhuma
produz dimensão ímpar, dimensão degenerada ou taxa de bits que o ffmpeg
recuse no fim de dez minutos de render. Quinhentas edições seguidas com o
histórico parando de crescer. Vinte projetos abertos em sequência sem
arrastar nada do anterior. Cinquenta gestos abertos e cancelados. E
arquivos de uma versão mais nova: campo desconhecido, camada
desconhecida, efeito desconhecido.
**Encontrou o bug 4.**

---

## 4. O que ficou de fora, e por quê

Coisas que **não** dá para provar em teste de widget nesta máquina, e que
precisam de aparelho:

- **Exportação de verdade pelo ffmpeg** (arquivo `.mp4` no disco). A
  suíte cobre os parâmetros e o quadro; a codificação em si depende do
  aparelho.
- **Uso de memória e temperatura em sessão longa de verdade** no iPhone.
- **Transcrição na nuvem**: o servidor devolve 503 até a chave da Groq ser
  posta como secret do Worker — isso é um comando que só você pode rodar.

## 5. Ponto conhecido, não corrigido

A rolagem automática da linha do tempo custa **5,8 ms por quadro** durante
a reprodução (6,3 ms com ela, 0,5 ms sem). Foi medido, está documentado em
`docs/desempenho-3d-e-editor.md`, e **não** é um bug de correção: é uma
troca de projeto entre "a linha do tempo segue o cabeçote" e o custo de
layout disso. Fica registrado para decisão, não como pendência de QA.
