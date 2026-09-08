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
 *   SENHA_DE_MODERACAO=... node aviso.mjs "Entre no grupo" --somar --link https://... --popup
 *   SENHA_DE_MODERACAO=... node aviso.mjs --apagar
 *
 * Opcoes:
 *   --nivel info|atencao|problema   a cor do "!" (padrao: atencao)
 *   --link https://...              "Saiba mais" leva para ca
 *   --horas N                       o aviso some sozinho depois de N horas
 *   --somar                         poe MAIS UM embaixo, em vez de trocar
 *   --popup                         abre tambem como janela, uma vez
 *   --servidor https://...          outro servidor (padrao: o do mural)
 *   --apagar                        tira todos os avisos do ar
 *
 * ATENCAO AO APARELHO ANTIGO: quem esta com um app anterior a 1.6.1 le
 * so o PRIMEIRO aviso e nao tem janela. Com o beta espalhado, o recado
 * que todo mundo precisa ver vai no primeiro — ou sozinho.
 *
 * No PowerShell: $env:SENHA_DE_MODERACAO="..."; node aviso.mjs "texto"
 */

const PADRAO = 'https://mural-do-aurea.aureaapp.workers.dev';

const args = process.argv.slice(2);
const opcoes = { nivel: 'atencao', servidor: PADRAO };
const textos = [];
const SOZINHAS = new Set(['apagar', 'somar', 'popup']);
for (let i = 0; i < args.length; i++) {
  const a = args[i];
  if (a.startsWith('--') && SOZINHAS.has(a.slice(2))) opcoes[a.slice(2)] = true;
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
  if (opcoes.popup) corpo.popup = true;
  if (opcoes.horas) {
    corpo.ate = new Date(Date.now() + Number(opcoes.horas) * 3600e3).toISOString();
  }
  resposta = await fetch(endereco, {
    // POST poe mais um embaixo; PUT troca a lista inteira por este.
    method: opcoes.somar ? 'POST' : 'PUT',
    headers: cabecalhos,
    body: JSON.stringify(corpo),
  });
}

const saida = await resposta.json().catch(() => ({}));
if (!resposta.ok) {
  console.error(`Deu errado (${resposta.status}): ${saida.erro ?? ''}`);
  process.exit(1);
}
if (opcoes.apagar) {
  console.log('Avisos apagados. Somem dos aparelhos em ate dez minutos.');
} else {
  const quantos = saida.avisos?.length ?? 1;
  console.log(
    `No ar (id ${saida.aviso.id}); ${quantos} aviso(s) na tela. ` +
      'Aparece em todo aparelho em ate dez minutos.',
  );
  if (quantos > 1) {
    console.log(
      'Lembre: app anterior a 1.6.1 mostra so o primeiro da lista.',
    );
  }
}
