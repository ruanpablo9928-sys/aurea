# ESRGAN compacto

Modelo: compressed_esrgan.tflite, release 2.0.0 do projeto GSOC de Adrish Dey.
Fonte: https://github.com/captain-pool/GSOC/tree/master/E3_Distill_ESRGAN
Download: https://github.com/captain-pool/GSOC/releases/download/2.0.0/compressed_esrgan.tflite
Licença MIT: ESRGAN-LICENSE.txt (licença original preservada).
SHA-256: 27ed316318cac65fe350ccdb3c1e19ac08c512f4aa2fc23b1a351ce334809c3f

Entrada float32 RGB [1,180,320,3], valores 0–255.
Saída float32 RGB [1,720,1280,3]. Recortar valores ao intervalo 0–255.
O app usa tiles com margem de 16 pixels, preserva alfa separadamente e
reduz a saída neural de 4x para 2x quando solicitado.

Runtime: tflite_flutter 0.12.1, projeto mantido no repositório TensorFlow:
https://github.com/tensorflow/flutter-tflite
Android usa LiteRT 1.4.0; iOS usa TensorFlow Lite 2.12.0 conforme o plugin.

Este é um modelo destilado para super-resolução local. Não contém modelos,
marcas, SDKs ou presets proprietários da Topaz ou da Adobe. Os presets de cor
do Aurea são receitas próprias; os oito adicionais seguem o estilo visual
das referências enviadas, sem incorporar as fotografias no aplicativo.
