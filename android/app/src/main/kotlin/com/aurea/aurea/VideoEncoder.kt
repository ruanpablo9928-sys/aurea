package com.aurea.aurea

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Build
import java.io.File
import java.nio.ByteBuffer

/**
 * CODIFICADOR DE VIDEO DA PLATAFORMA.
 *
 * Substitui o x264 do FFmpeg por MediaCodec + MediaMuxer. Tres motivos,
 * na ordem em que importam:
 *
 *  1. LICENCA — x264 e GPL. Num app comercial isso obriga a abrir o
 *     codigo inteiro. O codificador do sistema nao tem esse problema, e
 *     a exposicao de patente passa a ser do fabricante do aparelho.
 *  2. VELOCIDADE — e hardware. x264 e software.
 *  3. MANUTENCAO — vem com o Android; nao e dependencia aposentada.
 *
 * Os quadros chegam como arquivos PNG ja desenhados pelo Flutter. A
 * conversao RGBA -> YUV420 acontece aqui, porque e o formato que o
 * codificador aceita em modo de buffer (o modo de Surface exigiria EGL,
 * e complicaria sem ganhar nada nesse fluxo).
 */
class VideoEncoder {

    private var codec: MediaCodec? = null
    private var muxer: MediaMuxer? = null
    private var trackIndex = -1
    private var muxerStarted = false
    private var frameIndex = 0L

    private var width = 0
    private var height = 0
    private var fps = 30
    private var yuv: ByteArray? = null

    /** Buffer de bitmap reaproveitado: alocar por quadro derruba a taxa. */
    private var argb: IntArray? = null

    /** Se o aparelho sabe codificar este formato. */
    private fun hasEncoder(mime: String): Boolean = try {
        MediaCodecList(MediaCodecList.REGULAR_CODECS)
            .codecInfos
            .any { it.isEncoder && it.supportedTypes.any { t -> t.equals(mime, true) } }
    } catch (e: Exception) {
        false
    }

    fun start(
        path: String,
        w: Int,
        h: Int,
        frameRate: Int,
        bitRate: Int,
        hevc: Boolean = false
    ) {
        stop(discard = true)

        // O H.264 exige dimensao par.
        width = if (w % 2 == 0) w else w + 1
        height = if (h % 2 == 0) h else h + 1
        fps = if (frameRate < 1) 30 else frameRate

        // HEVC quando pedido E quando o aparelho tem: sem codificador de
        // H.265 a exportacao nao pode simplesmente falhar — cai no H.264,
        // que todo aparelho tem.
        val mime = if (hevc && hasEncoder(MediaFormat.MIMETYPE_VIDEO_HEVC)) {
            MediaFormat.MIMETYPE_VIDEO_HEVC
        } else {
            MediaFormat.MIMETYPE_VIDEO_AVC
        }

        val format = MediaFormat.createVideoFormat(mime, width, height).apply {
            setInteger(
                MediaFormat.KEY_COLOR_FORMAT,
                MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible
            )
            setInteger(MediaFormat.KEY_BIT_RATE, bitRate)
            setInteger(MediaFormat.KEY_FRAME_RATE, fps)
            // Um quadro-chave por segundo: sem isso, buscar no video
            // exportado fica lento.
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
            // AS ETIQUETAS DE COR. Sem elas o arquivo nao diz em que
            // espaco foi escrito, e cada player supoe o seu. Tem de
            // casar exatamente com a conversao de argbToNv12.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                setInteger(
                    MediaFormat.KEY_COLOR_STANDARD,
                    MediaFormat.COLOR_STANDARD_BT709
                )
                setInteger(
                    MediaFormat.KEY_COLOR_RANGE,
                    MediaFormat.COLOR_RANGE_LIMITED
                )
                setInteger(
                    MediaFormat.KEY_COLOR_TRANSFER,
                    MediaFormat.COLOR_TRANSFER_SDR_VIDEO
                )
            }
        }

        val c = MediaCodec.createEncoderByType(mime)
        c.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        c.start()
        codec = c

        File(path).parentFile?.mkdirs()
        muxer = MediaMuxer(path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        trackIndex = -1
        muxerStarted = false
        frameIndex = 0
        yuv = ByteArray(width * height * 3 / 2)
        argb = IntArray(width * height)
    }

    /**
     * CODIFICA UM QUADRO VINDO DA MEMORIA — o caminho normal.
     *
     * Os bytes chegam como RGBA de 8 bits, na ordem que o Flutter
     * entrega. Antes eles vinham por PNG no disco: comprimir com zlib
     * de um lado da ponte para descomprimir do outro, e guardar o filme
     * inteiro em disco no meio do caminho. Nao havia motivo de imagem
     * para isso — so era o jeito de os pixels chegarem aqui.
     */
    fun encodeFrameRgba(bytes: ByteArray, w: Int, h: Int) {
        if (w == width && h == height) {
            // UMA PASSADA, e nao duas. A versao anterior copiava RGBA
            // para um IntArray de ARGB (dois milhoes de iteracoes num
            // quadro 1080x1920) so para o passo seguinte percorrer o
            // mesmo array de novo. Isso e trabalho por quadro, na CPU,
            // no aparelho — e o array intermediario ainda custava oito
            // megabytes vivos o tempo todo.
            rgbaToNv12(bytes, yuv!!, width, height)
            queueYuv()
            return
        }
        // TAMANHO DIFERENTE DO CONFIGURADO. Acontece so na sobra: a
        // captura ja sai na resolucao de saida (o Flutter reduz na GPU,
        // de graca), mas um arredondamento de um pixel ainda e possivel.
        // Aqui vale pagar um Bitmap para escalar corretamente, em vez de
        // recusar o quadro.
        val quadro = IntArray(w * h)
        var p = 0
        for (i in quadro.indices) {
            val r = bytes[p].toInt() and 0xff
            val g = bytes[p + 1].toInt() and 0xff
            val b = bytes[p + 2].toInt() and 0xff
            quadro[i] = (0xff shl 24) or (r shl 16) or (g shl 8) or b
            p += 4
        }
        val bmp = Bitmap.createBitmap(quadro, w, h, Bitmap.Config.ARGB_8888)
        try {
            encodeBitmap(bmp)
        } finally {
            bmp.recycle()
        }
    }

    /** Codifica um quadro vindo de um PNG no disco. Caminho de reserva. */
    fun encodeFrameFile(framePath: String) {
        val opts = BitmapFactory.Options().apply {
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val bmp = BitmapFactory.decodeFile(framePath, opts)
            ?: throw IllegalStateException("Quadro ilegivel: $framePath")
        try {
            encodeBitmap(bmp)
        } finally {
            bmp.recycle()
        }
    }

    private fun encodeBitmap(source: Bitmap) {
        val c = codec ?: throw IllegalStateException("Codificador nao iniciado")

        val bmp = if (source.width == width && source.height == height) {
            source
        } else {
            Bitmap.createScaledBitmap(source, width, height, true)
        }

        val pixels = argb!!
        bmp.getPixels(pixels, 0, width, 0, 0, width, height)
        if (bmp !== source) bmp.recycle()

        encodeYuvFromArgb()
    }

    /** Converte o quadro que esta em [argb] e o entrega ao codificador. */
    private fun encodeYuvFromArgb() {
        argbToNv12(argb!!, yuv!!, width, height)
        queueYuv()
    }

    /** Entrega ao codificador o quadro que ja esta em [yuv]. */
    private fun queueYuv() {
        val c = codec ?: throw IllegalStateException("Codificador nao iniciado")

        // Enfileira o quadro.
        var queued = false
        while (!queued) {
            val inIndex = c.dequeueInputBuffer(10_000)
            if (inIndex >= 0) {
                val buf: ByteBuffer = c.getInputBuffer(inIndex)!!
                buf.clear()
                buf.put(yuv!!)
                val ptsUs = frameIndex * 1_000_000L / fps
                c.queueInputBuffer(inIndex, 0, yuv!!.size, ptsUs, 0)
                frameIndex++
                queued = true
            }
            drain(false)
        }
    }

    /** Fecha o fluxo e devolve o caminho do arquivo escrito. */
    fun finish(): Boolean {
        val c = codec ?: return false
        val inIndex = c.dequeueInputBuffer(10_000)
        if (inIndex >= 0) {
            c.queueInputBuffer(
                inIndex, 0, 0,
                frameIndex * 1_000_000L / fps,
                MediaCodec.BUFFER_FLAG_END_OF_STREAM
            )
        }
        drain(true)
        stop(discard = false)
        return true
    }

    private fun drain(endOfStream: Boolean) {
        val c = codec ?: return
        val info = MediaCodec.BufferInfo()
        while (true) {
            val outIndex = c.dequeueOutputBuffer(info, if (endOfStream) 10_000 else 0)
            when {
                outIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (!endOfStream) return
                }

                outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    if (muxerStarted) throw IllegalStateException("formato mudou duas vezes")
                    trackIndex = muxer!!.addTrack(c.outputFormat)
                    muxer!!.start()
                    muxerStarted = true
                }

                outIndex >= 0 -> {
                    val buf = c.getOutputBuffer(outIndex)!!
                    // Config do codec vai no formato, nao como amostra.
                    if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                        info.size = 0
                    }
                    if (info.size > 0 && muxerStarted) {
                        buf.position(info.offset)
                        buf.limit(info.offset + info.size)
                        muxer!!.writeSampleData(trackIndex, buf, info)
                    }
                    c.releaseOutputBuffer(outIndex, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
                }
            }
        }
    }

    fun stop(discard: Boolean) {
        try {
            codec?.stop()
        } catch (_: Exception) {
        }
        try {
            codec?.release()
        } catch (_: Exception) {
        }
        codec = null
        try {
            if (muxerStarted) muxer?.stop()
        } catch (_: Exception) {
        }
        try {
            muxer?.release()
        } catch (_: Exception) {
        }
        muxer = null
        muxerStarted = false
        yuv = null
        argb = null
        if (discard) frameIndex = 0
    }

    companion object {
        /**
         * ARGB -> NV12 (Y plano, depois UV intercalado), em BT.709 de
         * faixa limitada.
         *
         * AQUI ESTAVA O BUG DE COR. Os coeficientes eram os do BT.601
         * (66/129/25) e o arquivo saia sem etiqueta nenhuma. Player
         * nenhum adivinha: diante de um H.264 de alta definicao sem
         * etiqueta, todos assumem BT.709. O quadro era escrito com uma
         * matriz e lido com outra — e matriz trocada nao escurece a
         * imagem, ela GIRA o matiz: o verde puxa para amarelo, a pele
         * avermelha. Era esse o "as cores do video nao batem com o
         * preview".
         *
         * Agora sao os coeficientes do BT.709, e o formato leva as
         * etiquetas que dizem exatamente isso (ver start()). Os numeros
         * vem de ExportColor, no Dart, que e onde a politica de cor do
         * app esta escrita — e de onde o teste os cobra.
         *
         * A conversao roda por quadro, entao e escrita para nao alocar
         * nada e percorrer a imagem uma vez so.
         */
        /**
         * RGBA (como o Flutter entrega) -> NV12, direto.
         *
         * Mesma matriz e mesma faixa de [argbToNv12] — o que muda e nao
         * precisar de um IntArray no meio do caminho.
         */
        fun rgbaToNv12(rgba: ByteArray, out: ByteArray, w: Int, h: Int) {
            val frameSize = w * h
            var yIndex = 0
            var uvIndex = frameSize
            var p = 0
            for (j in 0 until h) {
                for (i in 0 until w) {
                    val r = rgba[p].toInt() and 0xff
                    val g = rgba[p + 1].toInt() and 0xff
                    val b = rgba[p + 2].toInt() and 0xff
                    p += 4

                    val y = ((47 * r + 157 * g + 16 * b + 128) shr 8) + 16
                    out[yIndex++] = clamp(y)

                    if (j and 1 == 0 && i and 1 == 0) {
                        val u = ((-26 * r - 87 * g + 113 * b + 128) shr 8) + 128
                        val v = ((113 * r - 102 * g - 11 * b + 128) shr 8) + 128
                        out[uvIndex++] = clamp(u)
                        out[uvIndex++] = clamp(v)
                    }
                }
            }
        }

        fun argbToNv12(argb: IntArray, out: ByteArray, w: Int, h: Int) {
            val frameSize = w * h
            var yIndex = 0
            var uvIndex = frameSize

            var index = 0
            for (j in 0 until h) {
                for (i in 0 until w) {
                    val c = argb[index]
                    val r = (c shr 16) and 0xff
                    val g = (c shr 8) and 0xff
                    val b = c and 0xff

                    val y = ((47 * r + 157 * g + 16 * b + 128) shr 8) + 16
                    out[yIndex++] = clamp(y)

                    // Croma em 2x2: so nas linhas e colunas pares. Os
                    // tres coeficientes de cada linha somam ZERO — se
                    // nao somassem, cinza deixaria de ser cinza e a
                    // imagem inteira ganharia uma dominante.
                    if (j and 1 == 0 && i and 1 == 0) {
                        val u = ((-26 * r - 87 * g + 113 * b + 128) shr 8) + 128
                        val v = ((113 * r - 102 * g - 11 * b + 128) shr 8) + 128
                        out[uvIndex++] = clamp(u)
                        out[uvIndex++] = clamp(v)
                    }
                    index++
                }
            }
        }

        private fun clamp(v: Int): Byte =
            when {
                v < 0 -> 0
                v > 255 -> 255.toByte()
                else -> v.toByte()
            }
    }
}
