# Auditoria do Aurea — 8 de setembro de 2026

## Resultado e escopo

A suíte completa disponível terminou com **1.652 testes aprovados, nenhum reprovado e 1 ignorado**, em 3min05s. A análise estática naquele fechamento retornou `No issues found!`. O APK debug foi compilado, instalado e aberto no emulador Android 14 (API 34), em resolução 1080 × 2400. Versão do projeto: 1.5.5+56.

Esses resultados cobrem a auditoria anterior à última simplificação dos efeitos. A validação específica dessa simplificação fica registrada ao final deste relatório. O APK debug da auditoria também antecede essa última mudança.

Foi executada a suíte automatizada inteira e foram percorridos fluxos representativos no Android. Isso não significa que todas as combinações possíveis foram testadas manualmente ou que o app esteja comprovadamente livre de bugs.

## Correções desta auditoria

- **Seleção no preview:** removida a aplicação duplicada da escala no cálculo das alças e da área de toque. A seleção agora usa a transformação 2D com escala por eixo, escala negativa, pivô, rotação e inclinação. As alças têm separação mínima e ficam dentro do palco. Testes verificam posições e seleção por toque com escalas diferentes.
- **Home em celulares estreitos:** ações principais passam a ocupar duas linhas de botões antes que os textos fiquem comprimidos. Ajustados espaçamento e ícone em telas de 320 pontos. A navegação inferior respeita a largura disponível. Verificação em larguras 320, 375, 411 e 768.
- **Adicionar camada:** corrigido o estouro vertical de textos nos atalhos compactos.
- **Conta da comunidade:** publicação e reenvio usam o código de acesso correto. Incluídos copiar código e entrar com código existente. “Apagar conta” passou a “Sair da conta”, de acordo com o comportamento real da ação.
- **Mídia da comunidade:** arquivos locais são enviados antes da publicação; o post recebe a URL remota. Falha no upload impede publicar um post sem o anexo. Corrigida a transição do rascunho para enviado após receber o ID do servidor. Fluxos validados com servidor simulado, sem publicar conteúdo real.
- **Regressões automatizadas:** atualizados caminhos de navegação dos testes para a UI atual, mantendo verificações de resultado. Corrigida a espera pelo carregamento assíncrono do painel de rastreio. Testes de painéis passam a verificar todas as ferramentas esperadas.

As mudanças anteriores de sincronização do primeiro quadro de vídeo foram preservadas e seus testes passaram. As demais alterações históricas estão em `EDITOR-AM-56.md` e `BUGS-BETA-56.md`; não são todas novas desta auditoria.

## Verificação prática

| Área | O que foi verificado | Limite da conclusão |
| --- | --- | --- |
| Projetos | Criar, editar, salvar, fechar e reabrir após reinstalar o APK | Não cobre todos os projetos dos usuários |
| Transformação | Selecionar círculo, mover no painel, preview com tamanho estável | Projeções 3D complexas exigem validação própria |
| Keyframes | Criar, avançar no tempo, editar posição, abrir curva e aplicar easing | Não foram animados todos os parâmetros manualmente |
| Galeria | Permissão, miniaturas de foto e vídeo, importação de foto sintética com quatro cores | Não valida iCloud, todos os formatos HEIC ou importação de todo codec de vídeo |
| Efeitos | Aplicar Gaussian Blur à foto; orientação e cores preservadas no caso testado | Não prova todos os efeitos em todas as GPUs |
| Exportação | MP4 salvo na galeria; arquivo inspecionado com ffprobe | Exportação de cena 2D curta |
| Scene 3D | Abrir flor, avançar no tempo, trocar câmera, abrir hierarquia e adicionar keyframe ao objeto | Emulador estava em recuperação por CPU |
| Comunidade | Conta, credencial, upload, publicação e falhas em testes automatizados | Sem publicação ou teste de rede real |
| Texto, fontes, SVG, Lottie, áudio | Suíte automatizada disponível | Não foram percorridas todas as combinações no aparelho |
| Home e ajustes | Navegação manual e testes responsivos | Usabilidade com pessoas continua necessária |

O vídeo efetivamente exportado tem **H.264, 1280 × 720, 30 fps, 5 segundos e 150 quadros**, conforme `audit-export-probe.json`.

## Limitações e verificações pendentes

1. **GPU e iPhone:** Ajustes informou recuperação por CPU após um encerramento anterior em GPU. A causa desse marcador não foi determinada; reinicializações durante instalação também ocorreram. O teste 3D desta sessão não comprova estabilidade nativa da GPU. É necessário validar em iPhone e Android físicos.
2. **Desempenho:** não foi feito ensaio físico prolongado de aquecimento, memória ou bateria, nem renderização de milhares de camadas com efeitos pesados. Testes de virtualização da timeline não equivalem a esse ensaio.
3. **Testes condicionais:** o benchmark Filament foi ignorado por exigir `AUREA_FILAMENT_BENCH=1`. Há testes de renderização que retornam sem renderizar quando `AUREA_RENDER` não está habilitado; testes de GPU fora do Impeller também não constituem validação de GPU real.
4. **Build:** o APK gerado é debug para verificação no emulador, não uma entrega beta. Nenhum IPA foi gerado nesta auditoria. O build avisa que plugins ainda usam Kotlin Gradle Plugin antigo, exigindo atualização para futuras versões do Flutter.
5. **Facilidade de uso:** comandos em “Mais”, gestos longos e controles densos do Scene 3D ainda precisam de acompanhamento com os beta testers. Uma suíte aprovada não mede sozinha se a interface é intuitiva.

## Evidências

Arquivos preservados em `output/auditoria-2026-09-08/`: logs da suíte, análise e build; MP4 exportado e metadados; capturas da Home, transformação, keyframe, importação, efeito, câmera, keyframe 3D e aviso de recuperação por CPU.

## Simplificação dos efeitos solicitada após a auditoria

Removidas as linhas de intensidade pronta (como Leve/Médio/Forte) e a navegação Ajustar/Avançado do cartão. Todos os parâmetros e cores aparecem diretamente no efeito aberto, nos dois modos de interface. Os dados antigos de profundidade continuam legíveis, sem modificar valores ou animações de projetos existentes. Salvar uma configuração própria continua disponível como recurso separado.

Os testes da galeria foram atualizados para editar diretamente o raio do desfoque e criar seu keyframe. O teste do cartão verifica a exposição de todos os parâmetros de Shake nos dois modos.

**Validação da mudança:** 37 testes aprovados nas suítes de efeitos, compatibilidade, inventário e fluxos de edição; nenhum reprovado. Análise estática dos três arquivos alterados sem problemas. A ajuda interna foi atualizada para o fluxo direto. Logs: `effect-direct-controls-verified.log` e `effect-direct-controls-scoped-analysis.log`, na pasta de evidências. Esta mudança está no código e ainda não foi empacotada em um novo APK/IPA.
