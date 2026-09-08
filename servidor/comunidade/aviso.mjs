/**
 * MANDA UM AVISO PARA TODO APARELHO COM O APP INSTALADO.
 *
 * O aviso aparece na Inicio, com um "!", em ate dez minutos (e na hora
 * em quem abrir o app). Quem escreve e quem tem a senha de moderacao —
 * a mesma que apaga post no mural. Ela entra pela variavel de ambiente,
 * nunca por argumento: argumento fica no historico do terminal.
 *
 * Rodar, a partir de servidor/comunidade:
 *
 *   SENHA_DE_MODERACAO=... node aviso.mjs "Estamos resolvendo um bug na exportação."
 *   SENHA_DE_MODERACAO=... node aviso.mjs "Resolvido! Atualize o app." --nivel info --horas 12
 *   SENHA_DE_MODERACAO=... node aviso.mjs --apagar
 *
 * Opcoes:
 *   --nivel info|atencao|problema   a cor do "!" (padrao: atencao)
 *   --link https://...              "Saiba mais" leva para ca
 *   --horas N                       o aviso some sozinho depois de N horas
 *   --servidor https://...          outro servidor (padrao: o do mural)
 *   --apagar                        tira o aviso do ar
 *
 * No PowerShell: $env:SENHA_DE_MODERACAO="..."; node aviso.mjs "texto"
 */

const PADRAO = 'https://mural-do-aurea.aureaapp.workers.dev';

const args = process.argv.slice(2);
const opcoes = { nivel: 'atencao', servidor: PADRAO };
const textos = [];
for (let i = 0; i < args.length; i++) {
  const a = args[i];
  if (a === '--apagar') opcoes.apagar = true;
  else if (a.startsWith('--')) opcoes[a.slice(2)] = args[++i];
  else textos.push(a);
}

const senha = process.env.SENHA_DE_MODERACAO;
if (!senha) {
  console.error('Falta a senha: SENHA_DE_MODERACAO=... node aviso.mjs "texto"');
  process.exit(2);
}

const endereco = `${opcoes.servidor.replace(/\/+$/, '')}/aviso`;
const cabecalhos = {
  'x-moderacao': senha,
  'content-type': 'application/json',
};

let resposta;
if (opcoes.apagar) {
  resposta = await fetch(endereco, { method: 'DELETE', headers: cabecalhos });
} else {
  const texto = textos.join(' ').trim();
  if (texto.length < 3) {
    console.error('Escreva o aviso: node aviso.mjs "Estamos resolvendo..."');
    process.exit(2);
  }
  const corpo = { texto, nivel: opcoes.nivel };
  if (opcoes.link) corpo.link = opcoes.link;
  if (opcoes.horas) {
    corpo.ate = new Date(Date.now() + Number(opcoes.horas) * 3600e3).toISOString();
  }
  resposta = await fetch(endereco, {
    method: 'PUT',
    headers: cabecalhos,
    body: JSON.stringify(corpo),
  });
}

const saida = await resposta.json().catch(() => ({}));
if (!resposta.ok) {
  console.error(`Deu errado (${resposta.status}): ${saida.erro ?? ''}`);
  process.exit(1);
}
console.log(
  opcoes.apagar
    ? 'Aviso apagado. Some dos aparelhos em ate dez minutos.'
    : `No ar (id ${saida.aviso.id}). Aparece em todo aparelho em ate dez minutos.`,
);
