# Como subir o servidor do mural

O código está pronto. Você vai criar uma conta e rodar quatro comandos.

Nada de cartão de crédito. Não precisa instalar nada além do que já está
na sua máquina (o Node já está: versão 24).

## Por que isso é necessário

A chave que dá permissão de escrever no mural **não pode morar dentro do
aplicativo**. Um APK é um arquivo zip: qualquer pessoa baixa,
descompacta e acha a chave em minutos. Com a chave na mão, ela reescreve
ou apaga o mural inteiro.

O servidor existe para segurar essa chave. O aplicativo fala com o
servidor; o servidor é quem escreve.

Ele também é o único lugar onde o filtro vale. O filtro que está dentro
do aplicativo é cortesia: quem chama o endereço direto não passa por ele.

---

## Passo 1 · A conta (no navegador)

Vá em **cloudflare.com**, crie uma conta gratuita e confirme o e-mail.

É só isso no site. Todo o resto é no terminal.

## Passo 2 · Entrar pelo terminal

Abra o terminal na pasta do servidor:

```bash
cd "C:\Users\SnyX\Documents\Projetos - Claude\Aurea\servidor\comunidade"
```

E entre na sua conta:

```bash
npx wrangler login
```

Abre o navegador pedindo autorização. Clique em **Allow**. A senha é sua
e fica com você: o terminal recebe só uma autorização, nunca a senha.

## Passo 3 · Criar o armazenamento

```bash
node configurar.mjs
```

Esse comando cria o **Workers KV** com o nome `MURAL` e escreve o id dele
no `wrangler.toml` sozinho. Era o único passo manual da montagem, e o
único onde dá para errar sem perceber: um caractere trocado e o servidor
sobe apontando para lugar nenhum, sem reclamar.

## Passo 4 · A senha de moderação

```bash
npx wrangler secret put SENHA_DE_MODERACAO
```

Ele pergunta o valor. Invente uma senha longa e guarde num lugar seguro.

Ela fica no Cloudflare, nunca no projeto. É com ela que você apaga um
post do mural, e sem ela o endereço de apagar responde "sem permissão"
para todo mundo, inclusive para você.

## Passo 5 · Subir

```bash
npx wrangler deploy
```

### Na primeira vez ele pergunta o subdomínio

> *What would you like your workers.dev subdomain to be?*

É o endereço da **conta**, escolhido uma vez só, e ele vira o miolo da
URL de todos os seus Workers. Como este se chama `mural-do-aurea`, o
endereço final fica:

```
https://mural-do-aurea.SEU-SUBDOMINIO.workers.dev
```

Três coisas para decidir bem:

- **É público.** Quem receber o link vê esse nome. Não use nome
  completo, e-mail nem telefone.
- **É único no mundo todo** da Cloudflare, então nomes óbvios podem já
  estar tomados.
- **Mudar depois quebra** os endereços que já existirem.

Aceita letras minúsculas, números e traço. `aurea` é a escolha natural;
se estiver tomado, `aurea-app` ou `aurea-editor`.

No fim do comando ele imprime o endereço completo. É esse que você me
manda.

---

## Conferir se funcionou

Abra o endereço no navegador com `/feed` no fim:

```
https://mural-do-aurea.SEU-NOME.workers.dev/feed
```

Tem que aparecer `{"posts":[]}`. Mural vazio é o começo certo.

## Apagar um post depois

Trocando o endereço, a senha e o id do post:

```bash
curl -X DELETE -H "Authorization: Bearer SUA_SENHA" https://mural-do-aurea.SEU-NOME.workers.dev/post/ID-DO-POST
```

---

## Avisar todo mundo que tem o app

O aviso ao vivo aparece na Início de todo aparelho, com um "!", em até
dez minutos — sem build novo. Do PC, dentro de `servidor/comunidade`:

```bash
SENHA_DE_MODERACAO=SUA_SENHA node aviso.mjs "Estamos resolvendo um bug na exportação. Não precisa reinstalar."
```

Opções: `--nivel info|atencao|problema` (a cor), `--link https://...`
("Saiba mais"), `--horas 12` (some sozinho). Para tirar do ar:
`node aviso.mjs --apagar`. Em curl, é um `PUT /aviso` com o cabeçalho
`x-moderacao: SUA_SENHA` e o corpo `{"texto": "...", "nivel": "problema"}`.

Cada aviso tem um id: quem fechar um aviso não vê aquele de novo, mas vê
o próximo. Publicar o mesmo texto duas vezes gera dois ids — e quem já
tinha fechado o primeiro vê o segundo.

## O que foi criado, com os nomes certos

| Nome | O que é | Para quê |
|---|---|---|
| **Worker** `mural-do-aurea` | o servidor | recebe e devolve os posts |
| **Workers KV** `MURAL` | armazenamento de chave e valor | guarda cada post numa chave |
| **Secret** `SENHA_DE_MODERACAO` | variável secreta do Worker | autoriza apagar |

### Por que KV, e não R2, D1 ou Durable Objects

| Produto | Para quê | Aqui |
|---|---|---|
| **Workers KV** | chave e valor, leitura rápida | **é este** |
| **R2** | arquivos (imagem, vídeo) | vai ser preciso **depois**, para a mídia |
| **D1** | banco SQL relacional | um mural não tem relação para consultar |
| **Durable Objects** | consistência forte | cada post já tem chave própria, não há corrida |

Um mural se lê muito e se escreve pouco, guardando texto debaixo de um
nome. É o que KV faz melhor: 100 mil leituras por dia na camada gratuita.

---

## O que o servidor faz

| Endereço | Quem pode | O que faz |
|---|---|---|
| `POST /conta`, `POST /conta/entrar`, `PATCH /conta` | qualquer um | Cria a conta, entra com o código, troca o apelido. |
| `GET /feed`, `GET /respostas/:id` | qualquer um | Devolve os posts, do mais novo para o mais antigo. |
| `POST /post` | com conta, com limite | Aceita um post depois dos portões. |
| `DELETE /post/:id` | o dono, ou a senha | Tira um post do mural. |
| `POST /midia`, `GET /midia/:id` | com conta | Sobe e serve imagem, vídeo e projeto. |
| `GET /aviso` | qualquer um | O aviso ao vivo que a Início mostra (ou `null`). |
| `PUT /aviso`, `DELETE /aviso` | só com a senha | Escreve e apaga o aviso ao vivo. |
| `POST /transcricao` | com conta, com cota | Transcreve um áudio na nuvem (Groq Whisper). Ver [`transcricao-na-nuvem.md`](transcricao-na-nuvem.md). |
| `GET /transcricao/cota` | com conta | Quanto da cota de transcrição do dia ainda resta. |

Os quatro portões do `POST`, na ordem:

1. **Tamanho.** Corpo acima de 8 KB nem é lido.
2. **Filtro.** O mesmo do aplicativo, repetido aqui — é aqui que ele vale.
3. **Limite.** Dez posts por hora por aparelho. Não impede um
   determinado; impede o roteiro que posta mil vezes.
4. **Formato.** Só sai o que o aplicativo sabe ler. Campo inventado é
   descartado em silêncio.

## Testar sem subir nada

O filtro e o formato dão para exercitar na sua máquina, antes de tudo:

```bash
node teste.mjs
```

Quinze verificações, entre elas ofensa disfarçada (`v1@d0`), telefone,
apelido ofensivo, o limite por hora, e que "carro" e "nossa" continuam
passando.

## Se der errado

| O que aparece | O que fazer |
|---|---|
| `not logged in` | `npx wrangler login` |
| `KV namespace ... is not valid` | faltou o Passo 3: `node configurar.mjs` |
| `Sem permissao` ao apagar | faltou o Passo 4, ou a senha está diferente |
| `{"posts":[]}` | está certo. O mural começa vazio. |
| pergunta o subdomínio | é o endereço da conta, escolhido uma vez. Veja o Passo 5. |

---

## Quando estiver no ar

Me mande o endereço. No aplicativo muda uma linha, em
`ComunidadeService.enderecoPadrao`, e o mural passa a publicar direto:
sem e-mail, sem você no meio, sem nada de novo para os testadores
aprenderem. A conta, o filtro e a mídia já estão prontos do lado de cá.

## O que ainda vai faltar

**Imagem e vídeo continuam no aparelho.** Publicar o arquivo exige
guardar arquivo, que é outra peça (o R2 da própria Cloudflare, com 10 GB
grátis). Vale fazer depois que o texto estiver rodando: é o passo com
mais consequência, porque arquivo que sobe fica no seu nome.
