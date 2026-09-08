# Auditoria do motor 3D — a bancada do pior caso

Gerado por `test/motor3d_auditoria_test.dart`. Cada linha é
um GLB fabricado no próprio teste e levado pelo caminho
real do aplicativo: importador → formato interno → ponte
GLB → (Filament).

Memória é a estimativa do próprio `ModelAsset3D`, que conta
o custo no heap do Dart — não a memória de GPU. FPS, memória
de GPU e iPhone 13 **não estão aqui**: precisam de aparelho.

| Asset | Arquivo | Abriu | Import | Ponte | Triângulos | Prims | Mats | Esq. | Anim. | Heap estimado | Textura no heap | GLB da ponte | Esq. na ponte | Anim. na ponte |
| --- | ---: | :--: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | :--: | :--: |
| Simples | 0.0 MB | sim | 11 ms | 21 ms | 8 | 1 | 1 | 0 | 0 | 0.0 MB | 0.0 MB | 0.0 MB | **não** | **não** |
| Médio (50k tri) | 1.4 MB | sim | 88 ms | 188 ms | 51200 | 1 | 1 | 0 | 0 | 9.1 MB | 0.0 MB | 1.1 MB | **não** | **não** |
| Complexo (60 materiais) | 0.1 MB | sim | 64 ms | 392 ms | 192000 | 60 | 60 | 0 | 0 | 35.2 MB | 0.0 MB | 4.2 MB | **não** | **não** |
| Muitos objetos (500) | 0.0 MB | sim | 15 ms | 147 ms | 64000 | 500 | 1 | 0 | 0 | 13.8 MB | 0.0 MB | 1.6 MB | **não** | **não** |
| Pesado (250k tri) | 6.9 MB | sim | 89 ms | 428 ms | 259200 | 1 | 1 | 0 | 0 | 45.7 MB | 0.0 MB | 6.9 MB | **não** | **não** |
| Personagem (skin) | 0.1 MB | sim | 39 ms | 11 ms | 3200 | 1 | 1 | 1 | 1 | 0.6 MB | 0.0 MB | 0.1 MB | **não** | **não** |
| Morph targets | 0.1 MB | sim | 1 ms | 23 ms | 1800 | 1 | 1 | 0 | 0 | 0.4 MB | 0.0 MB | 0.0 MB | **não** | **não** |
| Transparência | 0.1 MB | sim | 1 ms | 3 ms | 1800 | 1 | 1 | 0 | 0 | 0.3 MB | 0.0 MB | 0.0 MB | **não** | **não** |
| Textura 2048² | 4.0 MB | sim | 18 ms | 79 ms | 800 | 1 | 1 | 0 | 0 | 10.8 MB | 10.7 MB | 4.0 MB | **não** | **não** |
| Textura 4096² | 16.0 MB | sim | 73 ms | 268 ms | 800 | 1 | 1 | 0 | 0 | 42.8 MB | 42.7 MB | 16.0 MB | **não** | **não** |
| GLB com cauda | 0.0 MB | **NÃO** | 0 ms | 0 ms | 0 | 0 | 0 | 0 | 0 | 0.0 MB | 0.0 MB | 0.0 MB | **não** | **não** |
| Draco (comprimido) | 0.0 MB | **NÃO** | 0 ms | 0 ms | 0 | 0 | 0 | 0 | 0 | 0.0 MB | 0.0 MB | 0.0 MB | **não** | **não** |
| KTX2 / BasisU | 0.0 MB | **NÃO** | 1 ms | 0 ms | 0 | 0 | 0 | 0 | 0 | 0.0 MB | 0.0 MB | 0.0 MB | **não** | **não** |
| Meshopt | 0.0 MB | **NÃO** | 0 ms | 0 ms | 0 | 0 | 0 | 0 | 0 | 0.0 MB | 0.0 MB | 0.0 MB | **não** | **não** |

- **GLB com cauda** recusado: Tamanho do GLB invalido ou arquivo incompleto.
- **Draco (comprimido)** recusado: Extensao obrigatoria nao suportada: KHR_draco_mesh_compression. Exporte GLB sem compressao Draco/Meshopt e com texturas PNG/JPEG.
- **KTX2 / BasisU** recusado: Extensao obrigatoria nao suportada: KHR_texture_basisu. Exporte GLB sem compressao Draco/Meshopt e com texturas PNG/JPEG.
- **Meshopt** recusado: Extensao obrigatoria nao suportada: EXT_meshopt_compression. Exporte GLB sem compressao Draco/Meshopt e com texturas PNG/JPEG.

