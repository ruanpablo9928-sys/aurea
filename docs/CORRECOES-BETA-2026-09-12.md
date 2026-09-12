# Correções dos relatos beta — 12/09/2026

Alterações feitas sobre a revisão local `1c226f8`, preservando as correções da auditoria anterior desta rodada. Ainda não publicadas.

| Captura | Resultado |
| --- | --- |
| 1 — mesclagem | Testes por pixels confirmam Clarear, Escurecer, Color Burn, Exclusão, Multiplicar, Tela e opacidade. Branco em Clarear cobre o fundo; em Escurecer revela a imagem abaixo. A explicação do painel foi corrigida. Não foi comprovada uma falha geral desses modos nas imagens fornecidas. |
| 2 — eixo Z | Campo liberado para imagens e outras camadas visuais. Editar Z ativa a profundidade e mantém a regra existente de keyframes e desfazer. |
| 3 — linha vermelha | O painel de movimento agora alinha ao centro e acompanha o eixo inicial de gestos quase retos, mostrando as guias durante o gesto. As guias desaparecem ao soltar. |
| 4 — painel pequeno | Mais espaço reservado aos controles, com uma timeline compacta de uma camada. A prévia mantém o enquadramento ao selecionar e trocar ferramentas. Testado em 375×667 e 390×844, além dos testes responsivos existentes. |
| 5 — reverso | Ativação imediata usando o caminho de reprodução por tempo da mídia. A cópia auxiliar é preparada em segundo plano e sua indisponibilidade não impede o reverso. Fluidez ainda depende da decodificação do aparelho. |
| 6 — galeria | Confirmado o navegador real de álbuns da versão atual. Corrigida exceção ao pedir miniatura cuja referência expirou após atualização. Testados acesso limitado, paginação, troca de álbum, cancelamento e falha de importação. |
| 7 — erro vermelho no 3D | Luz direcional criada com direção explícita, eliminando a asserção de `DirectionalLightComponent`. Cena aberta no emulador na auditoria. |
| 8 — resolução da prévia | Seletor Full / 1/2 / 1/4 / 1/8 no canto da prévia. Reduz as imagens intermediárias dos efeitos e a resolução de renderização da GPU 3D. Não muda dimensões do projeto nem resolução de exportação. Full mantém o orçamento adaptativo existente. Não reduz a resolução de decodificação do vídeo original. |
| 9 — cantos individuais | Restaurado o painel completo de formas, que havia sido substituído por um painel com menos ferramentas. Os números dos cantos agora abrem entrada numérica e alteram o canto escolhido. Traço, desenho e pontos voltam a ficar acessíveis. |
| 10 e 11 — controles circulados | Removidos da régua os botões de ímã, busca, entrada e saída. |

O aviso inicial foi atualizado com uma descrição curta para os testadores.

## Validação e limites

- Novas regressões: `test/beta_screenshots_regressions_test.dart` e `test/beta_blend_composited_test.dart`.
- Comparação por pixels ampliada em `test/mescla_no_palco_test.dart`.
- Fluxo de galeria atualizado para o nome atual “Mídia”; mantém as verificações de importação e acesso.
- Galeria nativa confirmada no emulador Android após conceder acesso: álbuns e miniaturas carregaram. Captura: `tmp/am-audit/beta-gallery-access.png`.
- Build Android x64 debug compilado e instalado; análise estática sem problemas. Validação direcionada final: 47 aprovados, uma falha preexistente de navegação de grupos fora dos novos testes das capturas.
- O teste de movimento usa gestos no painel; o de cantos abre o teclado e confirma o número; o de resolução verifica a razão efetiva de rasterização e a preservação do projeto.
- A captura isolada de um beta não permite provar o comportamento de todos os arquivos, efeitos ou dispositivos. A reprodução em iPhone físico e arquivos específicos dos relatos continua necessária antes de afirmar que o app está sem bugs.
- O inventário amplo de falhas da suíte fica na auditoria do projeto; testes não foram desativados para ocultar falhas.
