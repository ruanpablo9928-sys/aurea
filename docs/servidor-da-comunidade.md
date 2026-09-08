# Como subir o servidor do mural

Você não precisa saber programar servidor. O código está pronto em
`servidor/comunidade/worker.js`; o que falta é criar uma conta e colar.

São uns dez minutos de cliques. Nada de cartão de crédito, nada de
instalar programa.

## Por que isso é necessário

A chave que dá permissão de escrever no mural **não pode morar dentro do
aplicativo**. Um APK é um arquivo zip: qualquer pessoa baixa,
descompacta e acha a chave em minutos. Com a chave na mão, ela reescreve
ou apaga o mural inteiro.

O servidor existe para segurar essa chave. O aplicativo fala com o
servidor; o servidor é quem escreve. É a única peça que falta.

Ele também é o único lugar onde o filtro vale de verdade. O filtro que
está dentro do aplicativo é cortesia: quem chama o endereço direto não
passa por ele.

---

## Parte 1 · Criar a conta

1. Vá em **cloudflare.com** e crie uma conta gratuita.
2. Confirme o e-mail que eles mandam.

É a mesma empresa que a maioria dos sites usa para não cair. A camada
gratuita dá 100 mil requisições por dia. Um mural de beta usa uns
milhares por mês.

## Parte 2 · Criar o KV

O produto chama-se **Workers KV**. É um armazenamento de chave e valor:
você guarda um texto debaixo de um nome e busca por esse nome. Nada de
tabelas nem de consultas.

No painel da Cloudflare:

1. Menu da esquerda: **Storage & Databases** › **KV**.
2. **Create instance** (ou *Create a namespace*, conforme a versão do
   painel).
3. Nome: `mural`.
4. **Add**.

### Por que KV e não os outros

A Cloudflare oferece quatro armazenamentos, e a escolha aqui não é gosto:

| Produto | Para quê | Por que não |
|---|---|---|
| **KV** | chave e valor, leitura rápida e distribuída | **é este** |
| **R2** | arquivos (imagem, vídeo, backup) | vai ser preciso **depois**, para a mídia |
| **D1** | banco SQL relacional | um mural não tem relação nenhuma para consultar |
| **Durable Objects** | estado com consistência forte | resolve corrida de escrita, e aqui cada post já tem chave própria |

Um mural é uma lista de textos que se lê muito e se escreve pouco. Isso é
exatamente o que KV faz melhor, e é o mais barato de operar: na camada
gratuita são 100 mil leituras por dia.

Cada post fica numa chave própria, e é por isso que dois aparelhos
publicando no mesmo segundo não apagam um ao outro.

## Parte 3 · Criar o servidor

1. Menu da esquerda: **Compute (Workers)** › **Workers & Pages**.
2. **Create** › **Start with Hello World!** › **Deploy**.
3. Depois de subir, **Edit code** (ou *Continue to project* › *Edit
   code*).
4. Apague tudo o que estiver no editor.
5. Abra `servidor/comunidade/worker.js` deste projeto, copie o arquivo
   inteiro e cole lá.
6. **Deploy**.

Anote o endereço que aparece. É algo como:

```
https://mural-do-aurea.SEU-NOME.workers.dev
```

## Parte 4 · Ligar a gaveta no servidor

O código procura a gaveta pelo nome `MURAL`. Falta dizer qual é:

1. Na página do Worker: **Settings** › **Bindings** › **Add binding**.
2. Tipo: **KV namespace**.
3. Variable name: `MURAL` (em maiúsculas, exatamente assim).
4. KV namespace: `mural`, o que você criou na Parte 2.
5. **Deploy**.

## Parte 5 · A senha de moderação

É com ela que você apaga um post do mural.

1. **Settings** › **Variables and Secrets** › **Add**.
2. Type: **Secret**.
3. Name: `SENHA_DE_MODERACAO`.
4. Value: invente uma senha longa e guarde num lugar seguro.
5. **Deploy**.

Sem esse segredo, o endereço de apagar responde "sem permissão" para
todo mundo, inclusive para você.

---

## Conferir se funcionou

Abra no navegador:

```
https://SEU-ENDERECO.workers.dev/feed
```

Tem que aparecer `{"posts":[]}`. Mural vazio é o começo certo.

## Apagar um post depois

Pelo terminal, trocando o endereço, a senha e o id do post:

```bash
curl -X DELETE -H "Authorization: Bearer SUA_SENHA" https://SEU-ENDERECO.workers.dev/post/ID-DO-POST
```

---

## O que o servidor faz, em três endereços

| Endereço | Quem pode | O que faz |
|---|---|---|
| `GET /feed` | qualquer um | Devolve os posts, do mais novo para o mais antigo. |
| `POST /post` | qualquer um, com limite | Aceita um post depois de quatro portões. |
| `DELETE /post/:id` | só com a senha | Tira um post do mural. |

Os quatro portões do `POST`, na ordem:

1. **Tamanho.** Corpo acima de 8 KB nem é lido.
2. **Filtro.** O mesmo do aplicativo, repetido aqui — é aqui que ele vale.
3. **Limite.** Dez posts por hora por aparelho. Não impede um
   determinado; impede o roteiro que posta mil vezes.
4. **Formato.** Só sai o que o aplicativo sabe ler. Campo inventado é
   descartado em silêncio.

## Testar sem subir nada

O filtro e o formato dão para exercitar na sua máquina:

```bash
node servidor/comunidade/teste.mjs
```

Quinze verificações, entre elas ofensa disfarçada (`v1@d0`), telefone,
apelido ofensivo, o limite por hora, e que "carro" e "nossa" continuam
passando.

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
