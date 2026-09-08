/**
 * O SERVIDOR DO MURAL DO AUREA.
 *
 * Um arquivo. Roda no Cloudflare Workers (camada gratuita, sem cartao).
 * Ele existe para uma coisa so: guardar a chave de escrita FORA do
 * aplicativo. Dentro do APK, qualquer chave e publica — um APK e um zip,
 * e achar a chave leva minutos. Aqui, quem tem a chave e o servidor.
 *
 * O QUE ELE FAZ, e por que cada peca esta aqui:
 *
 *   GET  /feed        devolve os posts. Publico, sem conta.
 *   POST /post        aceita um post novo. Passa por quatro portoes.
 *   DELETE /post/:id  apaga um post. So com a senha de moderacao.
 *
 * OS QUATRO PORTOES do POST, na ordem:
 *
 *   1. TAMANHO. Corpo acima de 8 KB nem e lido. Sem isso, um script
 *      enche a base de graca.
 *   2. FILTRO. O mesmo do aplicativo, repetido aqui. O do aplicativo e
 *      cortesia: quem chama este endereco direto nao passa por ele.
 *      Filtro que so existe no cliente nao filtra nada.
 *   3. LIMITE POR APARELHO. Dez posts por hora. Nao impede um
 *      determinado; impede o roteiro que posta mil vezes.
 *   4. FORMATO. O que sai daqui e exatamente o que o aplicativo sabe
 *      ler, e nada mais: campo desconhecido e descartado.
 *
 * O QUE ELE NAO FAZ, de proposito: nao tem senha de usuario, nao tem
 * e-mail, nao tem recuperacao de conta. Um mural de beta nao precisa
 * disso, e cada uma dessas coisas e um vazamento a mais esperando
 * acontecer.
 */

const LIMITE_POR_HORA = 10;
const TAMANHO_MAXIMO = 8 * 1024;
const POSTS_NO_FEED = 200;
const TEXTO_MAXIMO = 1200;

// ---------------------------------------------------------------- filtro

/**
 * As mesmas raizes do aplicativo. Curta de proposito: lista longa vira
 * censura de conversa normal, e "que porcaria de render" nao e o
 * problema que este mural tem. O que se bloqueia e ofensa a alguem.
 */
const RAIZES = [
  'viado', 'bicha', 'traveco', 'macaco preto', 'crioulo', 'preto imundo',
  'retardado', 'mongoloide', 'aleijado de merda',
  'puta que pariu voce', 'vai se foder', 'vai tomar no cu', 'filho da puta',
  'arrombado', 'corno manso', 'vagabunda', 'piranha do caralho',
  'matar voce', 'te matar', 'estupr', 'pedofil', 'nazis', 'hitler tinha razao',
];

const DISFARCES = {
  '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't',
  '@': 'a', '$': 's', '!': 'i',
};

/**
 * Deixa o texto na forma em que a comparacao e justa: minusculas, sem
 * acento, sem disfarce de numero (v1@d0) e com letra repetida tres ou
 * mais vezes reduzida a uma (viiiiado vira viado).
 *
 * Duas letras iguais SOBREVIVEM. Reduzir tudo a uma estragaria "carro" e
 * "nossa", e ai o filtro passaria a acusar portugues normal.
 */
function normalizar(bruto) {
  return bruto
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[0134579@$!]/g, (c) => DISFARCES[c] ?? c)
    .replace(/[^a-z0-9 ]/g, ' ')
    .replace(/(.)\1{2,}/g, '$1')
    .replace(/\s+/g, ' ')
    .trim();
}

const TELEFONE = /(?:\(?\d{2}\)?\s?)?9?\d{4}[\s.-]?\d{4}/;
const EMAIL = /[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}/i;
const CPF = /\d{3}\.?\d{3}\.?\d{3}-?\d{2}/;

/** Devolve o motivo da recusa, ou null se pode publicar. */
function recusar(texto, autor) {
  const t = (texto ?? '').trim();
  if (t.length < 3) return 'Escreva um pouco mais.';
  if (t.length > TEXTO_MAXIMO) return 'Texto longo demais para um mural.';

  const normal = normalizar(t);
  for (const raiz of RAIZES) {
    if (normal.includes(normalizar(raiz))) {
      return 'Ofensa, ameaca e ataque a alguem ficam de fora.';
    }
  }
  // Dado pessoal nao e sobre bom-tom: e para ninguem publicar o proprio
  // numero num mural que qualquer um le.
  if (CPF.test(t)) return 'Tire o CPF: o mural e publico.';
  if (EMAIL.test(t)) return 'Tire o e-mail: o mural e publico.';
  if (TELEFONE.test(t)) return 'Tire o telefone: o mural e publico.';

  const a = normalizar(autor ?? '');
  for (const raiz of RAIZES) {
    if (a.includes(normalizar(raiz))) return 'Esse apelido nao passa.';
  }
  return null;
}

// ------------------------------------------------------------- ajudantes

const json = (corpo, status = 200) =>
  new Response(JSON.stringify(corpo), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      // O aplicativo nao e um navegador, mas um dia alguem abre isto no
      // navegador para conferir. Sai mais barato ja deixar.
      'access-control-allow-origin': '*',
      'cache-control': 'no-store',
    },
  });

/**
 * Quem esta postando. NAO e identidade: e so um numero para contar
 * quantos posts vieram do mesmo lugar na ultima hora. O aplicativo manda
 * o id da conta local; sem ele, vale o endereco de rede.
 */
function quemE(request) {
  return (
    request.headers.get('x-aurea-conta') ||
    request.headers.get('cf-connecting-ip') ||
    'desconhecido'
  );
}

async function passouDoLimite(env, quem) {
  const hora = new Date().toISOString().slice(0, 13); // 2026-09-07T19
  const chave = `limite:${quem}:${hora}`;
  const atual = Number((await env.MURAL.get(chave)) ?? 0);
  if (atual >= LIMITE_POR_HORA) return true;
  // Expira sozinho: contador de hora que nao expira vira lixo eterno.
  await env.MURAL.put(chave, String(atual + 1), { expirationTtl: 7200 });
  return false;
}

/**
 * O feed inteiro, montado a partir dos posts guardados um a um.
 *
 * Guardar um arquivo so com tudo dentro seria mais simples e perderia
 * post: dois aparelhos publicando no mesmo segundo leem a mesma versao e
 * um sobrescreve o outro. Um post por chave nao tem esse problema.
 */
async function montarFeed(env) {
  const lista = await env.MURAL.list({ prefix: 'post:', limit: POSTS_NO_FEED });
  const posts = [];
  for (const chave of lista.keys) {
    const bruto = await env.MURAL.get(chave.name);
    if (bruto) {
      try {
        posts.push(JSON.parse(bruto));
      } catch {
        // Um post estragado nao pode derrubar o mural inteiro.
      }
    }
  }
  posts.sort((a, b) => String(b.quando).localeCompare(String(a.quando)));
  return posts;
}

// ------------------------------------------------------------------ rotas

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const caminho = url.pathname.replace(/\/+$/, '') || '/';

    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'access-control-allow-origin': '*',
          'access-control-allow-methods': 'GET,POST,DELETE,OPTIONS',
          'access-control-allow-headers': 'content-type,authorization,x-aurea-conta',
        },
      });
    }

    // ---- LER: publico, sem conta, sem chave.
    if (request.method === 'GET' && (caminho === '/feed' || caminho === '/')) {
      const cache = await env.MURAL.get('feed');
      if (cache) {
        return new Response(cache, {
          headers: {
            'content-type': 'application/json; charset=utf-8',
            'access-control-allow-origin': '*',
            // Meio minuto de cache: o mural nao muda a cada segundo, e
            // isso corta quase todas as leituras da base.
            'cache-control': 'public, max-age=30',
          },
        });
      }
      const corpo = JSON.stringify({ posts: await montarFeed(env) });
      await env.MURAL.put('feed', corpo, { expirationTtl: 60 });
      return new Response(corpo, {
        headers: {
          'content-type': 'application/json; charset=utf-8',
          'access-control-allow-origin': '*',
          'cache-control': 'public, max-age=30',
        },
      });
    }

    // ---- PUBLICAR.
    if (request.method === 'POST' && caminho === '/post') {
      const tamanho = Number(request.headers.get('content-length') ?? 0);
      if (tamanho > TAMANHO_MAXIMO) {
        return json({ erro: 'Post grande demais.' }, 413);
      }

      let corpo;
      try {
        corpo = await request.json();
      } catch {
        return json({ erro: 'Corpo invalido.' }, 400);
      }

      const motivo = recusar(corpo.texto, corpo.autor);
      if (motivo) return json({ erro: motivo }, 422);

      const quem = quemE(request);
      if (await passouDoLimite(env, quem)) {
        return json(
          { erro: `Limite de ${LIMITE_POR_HORA} posts por hora.` },
          429,
        );
      }

      // SO O QUE O APLICATIVO SABE LER sai daqui. Campo desconhecido no
      // corpo e descartado em silencio: e o que impede alguem de
      // inventar um campo e ver o que acontece do outro lado.
      const quando = new Date().toISOString();
      const id = String(corpo.id ?? crypto.randomUUID()).slice(0, 64);
      const post = {
        id,
        autor: String(corpo.autor ?? 'Anonimo').slice(0, 20),
        texto: String(corpo.texto).trim().slice(0, TEXTO_MAXIMO),
        quando,
        etiquetas: Array.isArray(corpo.etiquetas)
          ? corpo.etiquetas.slice(0, 5).map((e) => String(e).slice(0, 20))
          : [],
      };
      if (typeof corpo.imagem === 'string' && corpo.imagem.startsWith('https://')) {
        post.imagem = corpo.imagem.slice(0, 500);
        if (corpo.midia === 'video') post.midia = 'video';
        if (Number.isFinite(corpo.duracao)) post.duracao = corpo.duracao;
      }

      // A chave comeca pelo instante ao contrario para o `list` ja vir
      // com o mais novo na frente.
      const ordem = String(1e13 - Date.parse(quando)).padStart(14, '0');
      await env.MURAL.put(`post:${ordem}:${id}`, JSON.stringify(post));
      await env.MURAL.delete('feed');
      return json({ ok: true, post }, 201);
    }

    // ---- APAGAR: so quem tem a senha de moderacao.
    if (request.method === 'DELETE' && caminho.startsWith('/post/')) {
      const senha = (request.headers.get('authorization') ?? '').replace(
        'Bearer ',
        '',
      );
      if (!env.SENHA_DE_MODERACAO || senha !== env.SENHA_DE_MODERACAO) {
        return json({ erro: 'Sem permissao.' }, 401);
      }
      const alvo = decodeURIComponent(caminho.slice('/post/'.length));
      const lista = await env.MURAL.list({ prefix: 'post:' });
      for (const chave of lista.keys) {
        if (chave.name.endsWith(`:${alvo}`)) {
          await env.MURAL.delete(chave.name);
          await env.MURAL.delete('feed');
          return json({ ok: true });
        }
      }
      return json({ erro: 'Nao achei esse post.' }, 404);
    }

    return json({ erro: 'Endereco desconhecido.' }, 404);
  },
};
