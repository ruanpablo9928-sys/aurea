# Transcrição na nuvem (Groq Whisper)

As legendas automáticas podem ser transcritas de dois jeitos: **na
nuvem**, pelo Whisper grande da Groq, ou **no aparelho**, pelo
whisper.cpp com o modelo pequeno. A nuvem passa pelo servidor do Aurea —
o mesmo Worker do Cloudflare que serve a comunidade — porque é lá, e só
lá, que a chave da Groq existe.

## A regra que não se negocia

A `GROQ_API_KEY` **não existe no aplicativo**. Não está no código, não
está em asset, não está em configuração, não está em `.so`, não está
"escondida" em base64, partida em pedaços ou cifrada. Um APK é um zip;
qualquer coisa dentro dele é pública em minutos, e nenhum disfarce muda
isso. A segurança vem da arquitetura: o app nunca fala com a Groq.

```text
APP ──(áudio + código da conta)──▶ WORKER ──(áudio + GROQ_API_KEY)──▶ GROQ
APP ◀──(texto, segmentos, palavras)── WORKER ◀──(verbose_json)──────── GROQ
```

A chave entra no Worker como **secret** e nunca no `wrangler.toml`:

```bash
cd servidor/comunidade && npx wrangler secret put GROQ_API_KEY
```

(cole a chave quando ele pedir; ela não aparece no terminal nem no git).
Uma chave que já foi colada em chat, e-mail ou ticket deve ser trocada em
console.groq.com antes de virar secret — o secret é o único lugar onde
ela pode viver.

Há um teste que faz o `grep` por você, antes de qualquer build:
`test/segredo_da_groq_test.dart` varre `lib/`, `android/`, `ios/`,
`assets/`, `servidor/` e `docs/` atrás de `gsk_…`. Apontando
`AUREA_PACOTE` para um APK, AAB ou IPA, ele abre o pacote e varre
também os binários:

```bash
AUREA_PACOTE=C:/Users/SnyX/Downloads/Aurea-APK/app-arm64-v8a-release.apk flutter test test/segredo_da_groq_test.dart
```

## O que o servidor faz

Tudo em `servidor/comunidade/worker.js`, no mesmo Worker do mural — sem
backend novo, sem autenticação nova. Quem transcreve é **a conta da
comunidade**: o código de acesso vai no cabeçalho `Authorization`, como
em qualquer post.

| Endereço | Quem | O que faz |
|---|---|---|
| `POST /transcricao` | com conta | Corpo = o áudio (`content-type: audio/mp4`, `audio/mpeg`, `audio/wav`, `audio/flac`, `audio/ogg`, `audio/webm`). Cabeçalhos opcionais: `x-duracao` (segundos, estimativa) e `x-idioma` (`pt`, `en`…). Devolve `{texto, idioma, duracao, modelo, segmentos[], palavras[]}`, cada item com `inicio`, `fim`, `texto` em segundos. |
| `GET /transcricao/cota` | com conta | `{ligada, modelo, porDia, usadasHoje, segundosPorDia, segundosHoje}`. |
| `GET /transcricao/registro` | senha de moderação | As últimas tentativas (só o técnico). |

Os portões do `POST`, na ordem: **conta** (401), **chave configurada**
(503 se o secret não existe), **tipo** (415), **tamanho** (413 acima de
25 MB — o teto da Groq), **ritmo** por hora (429), **cota da conta** por
dia (429), **cota do servidor** por dia (429). Só depois de todos o áudio
é lido. O `x-duracao` que o app manda serve para barrar *antes* de
gastar; a cota é cobrada pela duração que a Groq mede.

O que a Groq devolve (`verbose_json`) é traduzido para o formato acima
**no servidor**. O app não conhece a Groq: trocar de modelo, ou de
provedor, é mexer só no Worker.

### O que muda sem build novo do app

No `wrangler.toml`, em `[vars]`:

| Variável | Padrão | O que é |
|---|---|---|
| `MODELO_DE_TRANSCRICAO` | `whisper-large-v3-turbo` | O modelo pedido à Groq. |
| `TRANSCRICOES_POR_HORA` | 10 | Por conta. |
| `TRANSCRICOES_POR_DIA` | 30 | Por conta. |
| `SEGUNDOS_DE_AUDIO_POR_DIA` | 1800 | Por conta (30 min). |
| `SEGUNDOS_DE_AUDIO_POR_DIA_TODOS` | 36000 | O servidor inteiro (10 h) — protege a fatura. |

Mudou, `npx wrangler deploy`, e todo aparelho passa a usar o novo.

### Privacidade e registro

O áudio vive só na memória da requisição: chega, vai para a Groq, e a
resposta volta. Nada dele é gravado. O que fica no KV, por trinta dias,
é um registro **técnico** por tentativa — `conta`, `duracao`, `quando`,
`modelo`, `status` (`ok`, `groq-500`, `ocupado`, `sem-resposta`…), `ms` —
e os contadores de cota do dia. Nunca o áudio, nunca o texto.

## O que o app faz

`lib/src/features/editor/application/transcription_service.dart`:

- `TranscriptionService.transcribeMedia(mídia, mode, modo)` é a única
  porta. Quem chama (a folha de Legendas, o AutoEdit) recebe `List<Cue>`
  e não sabe de onde veio.
- **Só o áudio sobe**: o FFmpeg tira do vídeo um AAC mono a 32 kbit/s e
  16 kHz (dez minutos ≈ 2,4 MB). O arquivo é apagado logo depois de
  subir, deu certo ou não.
- **Modo** (`ModoDeTranscricao`, nos Ajustes e na própria folha):
  `auto` — com internet, nuvem; sem, aparelho. `nuvem` — só nuvem.
  `local` — só aparelho, nada sai do celular.
- **Erros com saída**: sem internet → `TranscricaoSemInternet`; sem
  conta → `TranscricaoPrecisaDeConta`; nuvem fora, cota, servidor mudo →
  `TranscricaoNaNuvemIndisponivel` (com `tenteEm` quando o servidor diz).
  A folha mostra a mensagem e oferece **Tentar de novo** e **Usar o
  Whisper do aparelho**. No modo automático, com internet, uma falha da
  nuvem NÃO troca de motor sozinha — baixar 70 MB de modelo sem avisar
  seria pior do que perguntar.
- **Não trava o editor**: a transcrição roda em
  `TranscricaoEmAndamento`, fora da folha. "Continuar em segundo plano"
  fecha a folha; a camada de legenda entra na timeline quando ficar
  pronta, e reabrir a folha mostra o andamento ou o erro.
- O áudio só sai do aparelho quando a pessoa toca em **Transcrever** com
  a nuvem escolhida. Nunca sozinho.

O que volta alimenta o que já existia: `Cue` → `CaptionLayer`, nos três
modos (frases, curtas, palavra por palavra). As palavras com tempo são o
que a animação palavra a palavra e o karaokê vão usar.

## Testes

Sem nuvem, sem aparelho:

- `node servidor/comunidade/teste.mjs` — a Groq de brinquedo: sem conta
  (401), sem chave (503), tipo errado (415), 26 MB (413), transcrição
  boa (texto, palavras, segmentos, a chave no cabeçalho e só nele, o
  modelo e o idioma no formulário), modelo trocado por configuração,
  silêncio (200 vazio), Groq 500 (502), Groq 429 (503 com `tenteEm`),
  rede caída até a Groq (502), cota de segundos, cota de transcrições,
  cota do servidor, ritmo por hora, registro só com o técnico, nada do
  áudio guardado.
- `flutter test test/transcricao_na_nuvem_test.dart` — o app contra um
  servidor de mentira: só o áudio sobe (com a conta), os três modos de
  legenda, auto sem internet cai para o aparelho, nuvem sem internet
  avisa, sem conta pede a conta, 502/429/401 viram os erros certos, o
  servidor mudo não derruba o app, alucinação em laço descartada, e o
  trabalho em andamento com cada falha e a sua saída.
- `flutter test test/segredo_da_groq_test.dart` — a chave não está em
  lugar nenhum.

O que só se prova num aparelho, com a chave no ar: áudio curto e longo
de verdade, português e inglês, várias vozes, ruído de fundo, e a rede
caindo no meio do envio (o app mostra "indisponível" e oferece o
aparelho). Roteiro: um clipe de 10 s em português; um de 8 min em
inglês; um com duas pessoas; um com música alta; um mudo (deve dar
"nenhuma fala"); e um com o Wi-Fi desligado no meio do "Enviando áudio".
