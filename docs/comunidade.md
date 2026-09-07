# Comunidade

Beta 54 (2026-09-07). Aba **Comunidade**, segunda na barra de baixo.

## O que é

O mural do beta: quem está testando mostra o que fez, quem instalou o app
vê. Sem curtida, sem seguidor, sem notificação — isso é infraestrutura
social que só faz sentido depois que existe gente postando.

## Como funciona hoje, sem meias palavras

**Ler é automático e vale para todo mundo.** O app busca um feed JSON
público e mostra. Funciona sem conta, sem login e sem nada embutido no
APK. O que chegou fica gravado no aparelho, então o mural continua
legível sem internet.

**Escrever passa por uma revisão.** O post é gravado no aparelho na hora
e aparece no topo com o selo "só você vê". O botão **Enviar para o mural**
abre o e-mail já com o texto e o JSON prontos.

Por que não publica direto: publicar exigiria uma credencial de escrita
dentro do aplicativo. Uma credencial dentro de um APK é uma credencial
pública — qualquer pessoa que abra o arquivo pode escrever no mural de
todo mundo. Enquanto não houver um servidor com contas de verdade, a
revisão humana é a única forma honesta.

## Onde mora o feed

Um **gist público** na conta `ueeruan`:

```
https://gist.github.com/ueeruan/6d8c4adf3d31d6061a54fcfc13e55487
```

O app lê a versão crua:

```
https://gist.githubusercontent.com/ueeruan/6d8c4adf3d31d6061a54fcfc13e55487/raw/feed.json
```

Gist e não um arquivo do repositório porque o repositório do app é
privado: de lá, o aparelho de ninguém conseguiria ler.

## Publicar um post que chegou

Cole o bloco JSON do e-mail dentro de `posts` e salve o gist:

```bash
gh gist edit 6d8c4adf3d31d6061a54fcfc13e55487
```

O post aparece para todo mundo no próximo puxão para atualizar.

## O formato

```json
{
  "posts": [
    {
      "id": "único",
      "autor": "Nome",
      "texto": "O que a pessoa escreveu.",
      "quando": "2026-09-07T18:00:00Z",
      "imagem": "https://…  (opcional)",
      "link": "https://…  (opcional)",
      "etiquetas": ["3d", "motion"]
    }
  ]
}
```

Um item quebrado não derruba o mural: o leitor descarta o item e mostra o
resto. Só `texto` é obrigatório; o que faltar ganha um padrão.

## Trocar de servidor depois

`ComunidadeService.enderecoPadrao` é o único lugar que sabe onde o feed
está. Quando existir um serviço com contas, a aba não precisa mudar: ela
já lê uma lista de posts e escreve através do serviço.

---

## Conta, filtro e mídia (beta 55)

### A mini conta

Local, sem senha e sem e-mail. Guarda um **id**, um **apelido** e uma
**foto** opcional. Existe por três motivos, e nenhum é burocracia:

1. **Quem assina aparece antes de publicar.** Sem conta, a pessoa
   escrevia e só descobria como tinha assinado depois.
2. **O apelido passa pelo filtro uma vez**, na criação, e não a cada
   post. Sem isso o mural fica limpo e a lista de autores não: quem quer
   ofender escreve a ofensa no apelido e posta "oi".
3. **O id sobrevive à troca de apelido.** Quando houver servidor, os
   posts já sabem de quem são.

Apagar a conta some com a identidade neste aparelho. **Não** apaga o que
a pessoa já publicou: o mural é dos outros também.

Apelidos reservados (`aurea`, `admin`, `suporte`, `oficial`, `equipe`)
são recusados — passar-se pela equipe é o golpe mais barato num mural de
beta.

### O filtro

Roda **duas vezes**: antes de publicar, e ao ler o feed. A segunda é a
que importa, porque o feed vem de fora e um dia vem com coisa que não
passou por este app.

| Veredito | O que acontece |
|---|---|
| **Bloqueado** | Ofensa, ameaça, ataque a grupo. Dado pessoal (telefone, e-mail, CPF). Texto vazio, com menos de 3 letras ou mais de 1200. |
| **Ajustar** | Caixa alta, letra repetida demais, mais de dois links. Avisa uma vez; tocar de novo publica assim. |
| **Liberado** | O resto. Na dúvida, passa. |

A comparação é feita depois de **normalizar**: minúsculas, sem acento,
sem disfarce de número (`v1@d0`) e com letra repetida três ou mais vezes
reduzida a uma (`viiiiado` → `viado`). Duas letras iguais sobrevivem,
senão "carro" e "nossa" virariam outra coisa.

A lista de palavras é **curta de propósito**. Lista longa vira censura de
conversa normal, e "que porcaria de render" não é o problema que este
mural tem. O que se bloqueia é ofensa a alguém, não palavrão.

Bloquear telefone, e-mail e CPF não é bom-tom: é impedir que alguém
publique o próprio número num mural que qualquer um lê.

### Imagem e vídeo

Um post carrega **no máximo uma mídia**. Não é limitação técnica: um
mural de trabalho é sobre mostrar uma coisa bem feita, e uma galeria
dentro do cartão rouba a leitura do que a pessoa escreveu.

- **Imagem**: até 1600 px de largura, reduzida na hora de escolher.
- **Vídeo**: até **2 minutos**. A duração é lida **antes** de anexar —
  recusar depois de a pessoa já ter publicado seria pior.

No mural, o vídeo **só carrega quando alguém toca**. Dez vídeos que se
inicializam sozinhos ocupam dez decodificadores e travam o aparelho, e
ninguém assiste dez vídeos de uma vez.

O campo do endereço continua sendo `imagem` no JSON, com `midia:
"video"` ao lado. Assim um feed escrito antes disto continua valendo.
