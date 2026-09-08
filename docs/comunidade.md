# Comunidade

Aba **Comunidade**, segunda na barra de baixo. O mural do beta: quem está
testando mostra o que fez, quem instalou o app vê, responde e reposta.

## O que existe

- **Conta de verdade**, no servidor. Um apelido único e um **código de
  acesso** de 48 caracteres. Sem senha e sem e-mail.
- **Publicar** texto, **imagem**, **vídeo** e **projeto do Aurea**.
- **Responder** a um post (uma conversa por post) e **repostar**, com ou
  sem comentário.
- **Apagar** o próprio post, aqui e no mural.
- **Abrir um projeto publicado** como projeto novo deste aparelho.
- **Filtro de conteúdo** dos dois lados.

## A conta, e por que ela é assim

Quem assina um post é o **código de acesso**, e não um nome no corpo da
requisição. O aplicativo manda o código no cabeçalho; o servidor olha de
quem ele é e escreve o autor. Enquanto o autor vinha no corpo, qualquer
um que montasse a chamada à mão postava com o nome de outra pessoa.

Não há senha nem e-mail **de propósito**. Senha pede recuperação,
recuperação pede e-mail, e-mail pede caixa de saída: três peças novas
para um mural de beta. O código faz o mesmo papel, cabe num bloco de
notas e serve para entrar noutro aparelho.

**O código é o que não pode se perder.** Ele fica gravado no aparelho, e
a tela da conta mostra para copiar. Perder o código é perder o apelido:
sem e-mail, não há para onde mandar um "esqueci".

Sair do aparelho não apaga a conta — o código faz voltar. Apagar a conta
de verdade é outra conversa, e não cabe atrás de um botão que qualquer
toque errado alcança.

## O filtro, dos dois lados

O do aplicativo é **cortesia**: diz à pessoa o que está errado enquanto
ela escreve, sem esperar a viagem até o servidor. O do servidor é o que
**vale**, porque quem chama o endereço direto não passa pelo primeiro.

O filtro é curto de propósito: lista longa vira censura de conversa
normal, e "que porcaria de render" não é o problema que este mural tem. O
que se bloqueia é ofensa a alguém, ameaça, e dado pessoal (telefone,
e-mail, endereço) que a pessoa publicaria sem pensar.

Bloqueio e aviso são coisas diferentes na tela: um impede, o outro só
recomenda. Insistir num aviso é um direito de quem escreve — quem quer
escrever em caixa alta, escreve.

Há ainda um filtro **na hora de mostrar**: o feed vem de fora, e um dia
vem com coisa que não passou por este app. Post reprovado não aparece, e
ninguém precisa saber que ele existiu. No repost, o filtro olha o texto
do original também — filtrar só o comentário deixaria passar exatamente
o que se quer barrar.

## Resposta e repost

- A resposta **não aparece no mural de cima**: ela vive na conversa do
  post que respondeu. Um mural em que toda resposta vira post é um mural
  ilegível depois de uma semana.
- As respostas são buscadas **só quando a conversa abre**. Trazê-las com
  o feed seria baixar as respostas de duzentos posts para ler as de um.
- O repost guarda uma **cópia** do original, e não só o id. O feed
  devolve duzentos posts; o original pode ser mais antigo que isso, e aí
  o cartão apareceria vazio. Com a cópia, o repost continua legível para
  sempre — inclusive se o original for apagado depois, que é o que se
  espera de uma citação.
- **Não se reposta um repost.** O botão aponta para o original.
- Repostar **sem escrever nada** é o uso normal: obrigar a escrever faria
  todo mundo digitar um ponto.

## Imagem, vídeo e projeto

Os três sobem pelo mesmo caminho (`POST /midia`), porque para o servidor
são a mesma coisa: bytes com um tipo declarado. É ele quem decide onde
cada um mora.

- **Imagem**: comprimida no aparelho antes de sair (1600 px, qualidade
  82). Uma foto de celular sai com oito megabytes; o mural aceita dois.
  Reduzir antes poupa a internet de quem publica e faz caber.
- **Projeto**: vira um `TemplatePack` (JSON) e sobe. Quem abre recebe as
  camadas, as animações e a cena 3D — **os vídeos e as fotos importadas
  ficam no aparelho de quem fez**, e isso é dito na tela antes de anexar.
- **Vídeo**: precisa do R2 ligado no painel da Cloudflare. Sem ele, o
  servidor responde 501 explicando o que falta. Trinta megabytes num KV
  que cobra leitura de valor inteiro seria a ferramenta errada.

O arquivo sobe **antes** do post, e não junto: o post é um JSON de alguns
kilobytes e a foto tem megabytes; mandar os dois na mesma requisição faria
o mural recusar o post inteiro por tamanho.

Se o arquivo não sobe, o post **continua guardado como rascunho**.
Publicar só o texto entregaria um post que fala de uma imagem que ninguém
vai ver.

## Guarda primeiro, manda depois

O post é gravado no aparelho antes de sair. Nesta ordem ele nunca se
perde: se a rede cair no meio, ficou aqui e dá para tentar de novo. Na
ordem contrária, uma falha apagaria o que a pessoa escreveu.

O **id quem dá é o servidor**. Ao publicar, a cópia local recebe o id da
publicada — sem isso o mural mostraria o post repetido durante o minuto
que o armazenamento leva para propagar, e quem escreveu acharia que
publicou duas vezes sem querer.

## O servidor

Código, endpoints e como subir: [`docs/servidor-da-comunidade.md`](servidor-da-comunidade.md).
Fonte em `servidor/comunidade/`, testes em `servidor/comunidade/teste.mjs`
(rodam sem nuvem: `node servidor/comunidade/teste.mjs`).

## Quando o servidor muda

Trocar o servidor **quebra os aplicativos antigos**. O beta 56 mandava o
autor no corpo e sem código de acesso; com o servidor de contas no ar,
esses aparelhos passaram a receber 401 ao publicar. Ler continuou
funcionando. Quem for atualizar o servidor: avise os testadores de que
precisam do build novo, antes de publicar a mudança.
