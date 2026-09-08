/**
 * O TESTE DO SERVIDOR, sem servidor.
 *
 * O Worker inteiro depende de duas coisas que dao para exercitar aqui
 * mesmo: o filtro e o formato do que sai. Subir para a nuvem so para
 * descobrir que uma frase normal esta sendo recusada e o jeito caro de
 * testar.
 *
 * Rodar:  node servidor/comunidade/teste.mjs
 */
import worker from './worker.js';

// Uma base de dados de brinquedo com a mesma cara da KV do Cloudflare.
function baseFalsa() {
  const dados = new Map();
  return {
    dados,
    async get(k) {
      return dados.has(k) ? dados.get(k) : null;
    },
    async put(k, v) {
      dados.set(k, v);
    },
    async delete(k) {
      dados.delete(k);
    },
    async list({ prefix = '', limit = 1000 } = {}) {
      const keys = [...dados.keys()]
        .filter((k) => k.startsWith(prefix))
        .sort()
        .slice(0, limit)
        .map((name) => ({ name }));
      return { keys };
    },
  };
}

let falhas = 0;
function confere(nome, real, esperado) {
  const ok = JSON.stringify(real) === JSON.stringify(esperado);
  if (!ok) {
    falhas++;
    console.log(`FALHOU  ${nome}\n  esperado: ${JSON.stringify(esperado)}\n  veio:     ${JSON.stringify(real)}`);
  } else {
    console.log(`ok      ${nome}`);
  }
}

const env = { MURAL: baseFalsa(), SENHA_DE_MODERACAO: 'senha-de-teste' };

const postar = (corpo, conta = 'aparelho-1') =>
  worker.fetch(
    new Request('https://exemplo.workers.dev/post', {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-aurea-conta': conta },
      body: JSON.stringify(corpo),
    }),
    env,
  );

const ler = () =>
  worker.fetch(new Request('https://exemplo.workers.dev/feed'), env);

// --- o que passa
let r = await postar({
  autor: 'Ana',
  texto: 'Terminei minha primeira animacao com o rastreio 3D, ficou otimo!',
});
confere('post normal e aceito', r.status, 201);

// --- o que nao passa
r = await postar({ autor: 'Ana', texto: 'vai tomar no cu' });
confere('ofensa e recusada', r.status, 422);

r = await postar({ autor: 'Ana', texto: 'me chama no 11 98765-4321' });
confere('telefone e recusado', r.status, 422);

r = await postar({ autor: 'Ana', texto: 'v41 s3 f0d3r seu v1@d0' });
confere('ofensa disfarcada e recusada', r.status, 422);

r = await postar({ autor: 'vai se foder', texto: 'oi pessoal do mural' });
confere('apelido ofensivo e recusado', r.status, 422);

r = await postar({ autor: 'Ana', texto: 'oi' });
confere('texto curto demais e recusado', r.status, 422);

// --- portugues normal nao pode ser confundido com disfarce
r = await postar({
  autor: 'Ana',
  texto: 'o carro passou e a nossa cena ficou boa demais',
});
confere('carro e nossa continuam passando', r.status, 201);

// --- limite por aparelho
let ultimo = 0;
for (let i = 0; i < 12; i++) {
  const resposta = await postar(
    { autor: 'Spam', texto: `post numero ${i} do roteiro automatico` },
    'aparelho-spam',
  );
  ultimo = resposta.status;
}
confere('o decimo primeiro post da mesma hora e barrado', ultimo, 429);

// --- o feed devolve o que entrou, mais novo primeiro
const feed = await (await ler()).json();
confere('o feed tem os posts aceitos', feed.posts.length >= 3, true);
confere(
  'o mais novo vem primeiro',
  feed.posts[0].quando >= feed.posts[feed.posts.length - 1].quando,
  true,
);
confere(
  'so os campos conhecidos saem',
  Object.keys(feed.posts[0]).every((k) =>
    ['id', 'autor', 'texto', 'quando', 'etiquetas', 'imagem', 'midia', 'duracao'].includes(k),
  ),
  true,
);

// --- campo inventado e descartado
r = await postar({
  autor: 'Ana',
  texto: 'este post tenta mandar um campo que nao existe',
  admin: true,
  imagem: 'javascript:alert(1)',
});
const feed2 = await (await ler()).json();
const recente = feed2.posts[0];
confere('campo inventado nao entra', recente.admin, undefined);
confere('imagem que nao e https e descartada', recente.imagem, undefined);

// --- apagar exige senha
r = await worker.fetch(
  new Request(`https://exemplo.workers.dev/post/${recente.id}`, {
    method: 'DELETE',
  }),
  env,
);
confere('apagar sem senha e negado', r.status, 401);

r = await worker.fetch(
  new Request(`https://exemplo.workers.dev/post/${recente.id}`, {
    method: 'DELETE',
    headers: { authorization: 'Bearer senha-de-teste' },
  }),
  env,
);
confere('apagar com senha funciona', r.status, 200);

console.log(falhas === 0 ? '\nTudo certo.' : `\n${falhas} falha(s).`);
process.exit(falhas === 0 ? 0 : 1);
