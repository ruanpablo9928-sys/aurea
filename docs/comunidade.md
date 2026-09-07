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
