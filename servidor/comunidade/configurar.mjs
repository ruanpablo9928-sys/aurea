/**
 * CRIA O KV E PREENCHE O wrangler.toml.
 *
 * O passo manual desta montagem era um so, e era justamente o que da
 * errado: rodar `wrangler kv namespace create`, achar o id no meio da
 * saida e cola-lo no lugar certo do arquivo. Um caractere a mais e o
 * deploy sobe apontando para lugar nenhum, sem reclamar.
 *
 * Rodar:  node configurar.mjs
 */
import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';

const NOME = 'MURAL';
const ARQUIVO = new URL('./wrangler.toml', import.meta.url);

function rodar(args) {
  return execFileSync('npx', ['--yes', 'wrangler@latest', ...args], {
    encoding: 'utf8',
    stdio: ['inherit', 'pipe', 'pipe'],
    shell: process.platform === 'win32',
  });
}

console.log(`Criando o KV "${NOME}"...\n`);

let saida;
try {
  saida = rodar(['kv', 'namespace', 'create', NOME]);
} catch (erro) {
  const texto = `${erro.stdout ?? ''}${erro.stderr ?? ''}`;
  console.error(texto || erro.message);
  if (/not logged in|authentication|credentials/i.test(texto)) {
    console.error(
      '\nFalta entrar na sua conta. Rode primeiro:\n' +
        '  npx wrangler login\n',
    );
  }
  process.exit(1);
}

console.log(saida);

// O id e um hexadecimal de 32 caracteres. Procurar por ele e mais
// robusto do que procurar pelo rotulo, que ja mudou de nome antes.
const achado = saida.match(/"id"\s*:\s*"([0-9a-f]{32})"/i)
  ?? saida.match(/\b([0-9a-f]{32})\b/i);

if (!achado) {
  console.error(
    'Nao achei o id na saida acima.\n' +
      'Copie o valor de "id" e cole no wrangler.toml, na linha id = "...".',
  );
  process.exit(1);
}

const id = achado[1];
const toml = readFileSync(ARQUIVO, 'utf8');
const novo = toml.replace(
  /^(\s*id\s*=\s*)"[^"]*"/m,
  (_, prefixo) => `${prefixo}"${id}"`,
);

if (novo === toml) {
  console.error(
    `Nao consegui escrever no wrangler.toml. Ponha a mao: id = "${id}"`,
  );
  process.exit(1);
}

writeFileSync(ARQUIVO, novo);
console.log(`\nPronto. wrangler.toml agora aponta para o KV ${id}.`);
console.log('\nProximos dois comandos:');
console.log('  npx wrangler secret put SENHA_DE_MODERACAO');
console.log('  npx wrangler deploy');
