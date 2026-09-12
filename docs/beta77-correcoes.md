# Aurea beta 77 — novidades e correções

- **Melhorar qualidade:** uma área própria na tela inicial para ampliar fotos e vídeos em 2x ou 4x com IA local, ajustar detalhes, reduzir ruído e comparar antes e depois.
- **15 estilos de cor:** inclui oito novos visuais inspirados nas referências enviadas: Cobre dramático, Retrato limpo, Cinema lilás, Azul fosco, Esporte nítido, Azul elétrico, Flash e Verde e ouro. A intensidade pode ser ajustada.
- **Scene 3D renovado:** controles adaptados ao celular, abas claras, dicas, troca de câmera e vínculo com nulos visível.
- **Reflexos do ambiente:** objetos metálicos podem refletir outros objetos da cena. É possível atualizar a captura do reflexo e ajustar sua intensidade.
- **Modelos 3D:** otimização em C++ reorganiza os triângulos de malhas elegíveis sem eliminar detalhes; a preparação acontece fora da interface.
- **Rotação e nulos:** correções na edição entre keyframes, composição de rotações e conservação da posição ao vincular ou desvincular objetos.
- **Profundidade Z:** correção do cálculo usado para tocar e arrastar camadas com perspectiva.
- **AutoKey:** ligado por padrão. Depois que uma propriedade recebe seu primeiro keyframe, as próximas alterações podem ser gravadas automaticamente.
- **Time Remap:** controle do tempo em Efeitos, com curvas e restauração do movimento linear.
- **Optical Flow:** interpolação de movimento em Efeitos. O vídeo original continua disponível enquanto a prévia suavizada é preparada.
- **Exportação:** os efeitos não escapam mais do quadro da composição para a interface.
- **Aviso de novidades:** resumo simples ao abrir esta versão.

## Verificação realizada

82 testes direcionados passaram, cobrindo transformação, nulos, seleção com Z, efeitos temporais, telas pequenas, cores e otimização nativa. No Android também foram executados o render 3D com reflexos, a troca de geometria otimizada, a interpolação de vídeo, a inferência ESRGAN e a exportação de vídeo com cor.

O vídeo de teste do Optical Flow manteve os 2 segundos originais e passou de 15 para 60 quadros por segundo. A exportação de melhoria gerou H.264 de 2 segundos a 30 quadros por segundo.

## Limites importantes

A melhoria usa um modelo ESRGAN compacto; não é o motor do Topaz. Os estilos de cor são receitas próprias inspiradas nas imagens, não presets proprietários da Adobe. O Optical Flow usa compensação de movimento do FFmpeg. O resultado e a velocidade variam conforme a mídia e o aparelho. A exportação da área Melhorar qualidade usa 30 quadros por segundo. A otimização não garante ausência de travamentos com qualquer modelo 3D. Os testes direcionados não equivalem a uma certificação de todo o app.
