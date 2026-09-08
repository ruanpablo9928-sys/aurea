/**
 * O TESTE DO SERVIDOR, sem servidor.
 *
 * O Worker inteiro depende de coisas que dao para exercitar aqui mesmo:
 * o filtro, a conta, quem pode apagar o que, e o formato do que sai.
 * Subir para a nuvem so para descobrir que uma frase normal esta sendo
 * recusada e o jeito caro de testar.
 *
 * Rodar:  node servidor/comunidade/teste.mjs
 */
import worker from './worker.js';

// Uma base de brinquedo com a mesma cara da KV do Cloudflare.
function kvFalsa() {
  const dados = new Map();
  return {
    dados,
    async get(k, tipo) {
      if (!dados.has(k)) return null;
      const valor = dados.get(k);
      // A KV de verdade devolve texto por padrao e bytes quando pedidos.
      if (tipo === 'arrayBuffer' && typeof valor === 'string') {
        return new TextEncoder().encode(valor).buffer;
      }
      return valor;
    },
    async put(k, v) {
      dados.set(k, v);
    },
    async delete(k) {
      dados.delete(k);
    },
    async list({ prefix = '', limit = 1000 } = {}) {
      return {
        keys: [...dados.keys()]
          .filter((k) => k.startsWith(prefix))
          .sort()
          .slice(0, limit)
          .map((name) => ({ name })),
      };
    },
  };
}

// E um R2 de brinquedo.
function r2Falso() {
  const dados = new Map();
  return {
    dados,
    async put(nome, corpo, opcoes) {
      dados.set(nome, { corpo, ...opcoes });
    },
    async get(nome) {
      const achado = dados.get(nome);
      return achado
        ? { body: achado.corpo, httpMetadata: achado.httpMetadata }
        : null;
    },
  };
}

let falhas = 0;
function confere(nome, real, esperado) {
  const ok = JSON.stringify(real) === JSON.stringify(esperado);
  if (!ok) {
    falhas++;
    console.log(
      `FALHOU  ${nome}\n  esperado: ${JSON.stringify(esperado)}\n  veio:     ${JSON.stringify(real)}`,
    );
  } else {
    console.log(`ok      ${nome}`);
  }
}

const env = {
  MURAL: kvFalsa(),
  ARQUIVOS: r2Falso(),
  SENHA_DE_MODERACAO: 'senha-de-teste',
};

const BASE = 'https://exemplo.workers.dev';
const chamar = (metodo, caminho, { corpo, codigo, cabecalhos } = {}) =>
  worker.fetch(
    new Request(`${BASE}${caminho}`, {
      method: metodo,
      headers: {
        ...(corpo !== undefined ? { 'content-type': 'application/json' } : {}),
        ...(codigo ? { authorization: `Bearer ${codigo}` } : {}),
        ...cabecalhos,
      },
      ...(corpo !== undefined ? { body: JSON.stringify(corpo) } : {}),
    }),
    env,
  );

// ======================================================== conta

let r = await chamar('POST', '/conta', { corpo: { apelido: 'Ana Motion' } });
const ana = await r.json();
confere('cria conta', r.status, 201);
confere('devolve o codigo de acesso', /^[0-9a-f]{48}$/.test(ana.codigo), true);

r = await chamar('POST', '/conta', { corpo: { apelido: 'ana motion' } });
confere('apelido repetido e recusado', r.status, 409);

r = await chamar('POST', '/conta', { corpo: { apelido: 'Aurea' } });
confere('apelido reservado e recusado', r.status, 422);

r = await chamar('POST', '/conta', { corpo: { apelido: 'vai se foder' } });
confere('apelido ofensivo e recusado', r.status, 422);

r = await chamar('POST', '/conta', { corpo: { apelido: 'Bruno 3D' } });
const bruno = await r.json();
confere('segunda conta', r.status, 201);

r = await chamar('POST', '/conta/entrar', { codigo: ana.codigo });
confere('entrar com o codigo', (await r.json()).apelido, 'Ana Motion');

r = await chamar('POST', '/conta/entrar', { codigo: 'f'.repeat(48) });
confere('codigo inventado nao entra', r.status, 401);

// ======================================================== publicar

r = await chamar('POST', '/post', { corpo: { texto: 'oi' } });
confere('sem conta nao publica', r.status, 401);

r = await chamar('POST', '/post', {
  codigo: ana.codigo,
  corpo: {
    texto: 'Terminei minha primeira animacao com o rastreio 3D!',
    autor: 'Bruno 3D',
  },
});
const post = (await r.json()).post;
confere('publica', r.status, 201);
confere(
  'o autor vem da conta, nao do corpo',
  post.autor,
  'Ana Motion',
);

r = await chamar('POST', '/post', {
  codigo: ana.codigo,
  corpo: { texto: 'vai tomar no cu' },
});
confere('ofensa e recusada', r.status, 422);

r = await chamar('POST', '/post', {
  codigo: ana.codigo,
  corpo: { texto: 'me chama no 11 98765-4321' },
});
confere('telefone e recusado', r.status, 422);

// ======================================================== resposta

r = await chamar('POST', '/post', {
  codigo: bruno.codigo,
  corpo: { texto: 'Ficou muito bom! Como voce fez a camera?', respondeA: post.id },
});
const resposta = (await r.json()).post;
confere('responde', r.status, 201);
confere('a resposta aponta para o pai', resposta.respondeA, post.id);

r = await chamar('GET', `/respostas/${post.id}`);
const respostas = (await r.json()).posts;
confere('as respostas vem pelo pai', respostas.length, 1);
confere('e sao de quem respondeu', respostas[0].autor, 'Bruno 3D');

r = await chamar('POST', '/post', {
  codigo: bruno.codigo,
  // Texto valido de proposito: com "oi" o filtro recusaria antes, por
  // ser curto, e o teste passaria pelo motivo errado.
  corpo: {
    texto: 'respondendo um post que ja foi apagado',
    respondeA: 'post-que-nao-existe',
  },
});
confere('responder a post inexistente e recusado', r.status, 404);

// A resposta NAO aparece no mural de cima.
r = await chamar('GET', '/feed');
let feed = (await r.json()).posts;
confere('o feed nao mistura resposta', feed.length, 1);

// ========================================================== repost

r = await chamar('POST', '/post', {
  codigo: bruno.codigo,
  corpo: { texto: '', repostaDe: post.id },
});
const repost = (await r.json()).post;
confere('reposta sem comentar', r.status, 201);
confere('guarda copia do original', repost.original.autor, 'Ana Motion');
confere('e o texto do original', repost.original.texto, post.texto);

r = await chamar('POST', '/post', {
  codigo: ana.codigo,
  corpo: { texto: 'olhem isso', repostaDe: repost.id },
});
confere('nao reposta um repost', r.status, 422);

// ========================================================== apagar

r = await chamar('DELETE', `/post/${post.id}`, { codigo: bruno.codigo });
confere('nao apaga post dos outros', r.status, 401);

r = await chamar('DELETE', `/post/${post.id}`, { codigo: ana.codigo });
confere('o dono apaga o proprio post', r.status, 200);

r = await chamar('DELETE', `/post/${repost.id}`, {
  cabecalhos: { 'x-moderacao': 'senha-de-teste' },
});
confere('a moderacao apaga qualquer um', r.status, 200);

r = await chamar('DELETE', '/post/nao-existe', { codigo: ana.codigo });
confere('apagar o que nao existe', r.status, 404);

// =========================================================== midia

async function subir(tipo, bytes) {
  return worker.fetch(
    new Request(`${BASE}/midia`, {
      method: 'POST',
      headers: {
        'content-type': tipo,
        'content-length': String(bytes),
        authorization: `Bearer ${ana.codigo}`,
      },
      body: new Uint8Array(bytes),
    }),
    env,
  );
}

r = await subir('image/png', 1024);
const midia = await r.json();
confere('sobe imagem', r.status, 201);
confere('devolve endereco no proprio servidor', midia.url.startsWith(`${BASE}/midia/`), true);

r = await subir('application/x-msdownload', 1024);
confere('tipo de fora da lista e recusado', r.status, 415);

r = await subir('video/mp4', 60 * 1024 * 1024);
confere('arquivo grande demais e recusado', r.status, 413);

r = await chamar('GET', new URL(midia.url).pathname);
confere('serve o arquivo', r.status, 200);
confere('com o tipo certo', r.headers.get('content-type'), 'image/png');

r = await chamar('GET', '/midia/..%2F..%2Fetc%2Fpasswd');
confere('nome com caminho e recusado', r.status, 400);

// --- sem R2: projeto ainda funciona, foto e video nao
const semR2 = { MURAL: env.MURAL, SENHA_DE_MODERACAO: 'senha-de-teste' };
const subirSemR2 = (tipo, bytes) =>
  worker.fetch(
    new Request(`${BASE}/midia`, {
      method: 'POST',
      headers: {
        'content-type': tipo,
        'content-length': String(bytes),
        authorization: `Bearer ${ana.codigo}`,
      },
      body: tipo === 'application/json' ? '{"nome":"meu projeto"}' : new Uint8Array(bytes),
    }),
    semR2,
  );

r = await subirSemR2('application/json', 22);
const projeto = await r.json();
confere('projeto sobe sem R2 (vai para o KV)', r.status, 201);

r = await worker.fetch(new Request(projeto.url), semR2);
confere('e o projeto volta inteiro', await r.text(), '{"nome":"meu projeto"}');

r = await subirSemR2('image/png', 1024);
const fotoSemR2 = await r.json();
confere('foto sobe sem R2 (vai para o KV)', r.status, 201);

r = await worker.fetch(new Request(fotoSemR2.url), semR2);
confere('e a foto volta com o tipo certo', r.headers.get('content-type'), 'image/png');

r = await subirSemR2('video/mp4', 1024);
confere('video sem R2 explica o que falta', r.status, 501);

r = await subirSemR2('image/png', 5 * 1024 * 1024);
confere('foto grande demais para o KV e recusada', r.status, 413);

// =========================================================== limite

let ultimo = 0;
for (let i = 0; i < 25; i++) {
  const resposta = await chamar('POST', '/post', {
    codigo: bruno.codigo,
    corpo: { texto: `post numero ${i} do roteiro automatico` },
  });
  ultimo = resposta.status;
}
confere('o limite por hora barra o roteiro', ultimo, 429);

console.log(falhas === 0 ? '\nTudo certo.' : `\n${falhas} falha(s).`);
process.exit(falhas === 0 ? 0 : 1);
