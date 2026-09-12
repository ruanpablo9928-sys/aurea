#pragma once

#include "FFmpegTypes.h"
#include "VideoTimeMapper.h"
#include <string>
#include <memory>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <atomic>
#include <functional>
#include <deque>

namespace aurea {

struct DecodeRequest {
    int64_t targetTimeUs = 0;
    uint64_t generationId = 0;
    SeekAccuracy accuracy = SeekAccuracy::ExactFrame;
};

class FFmpegVideoDecoder {
public:
    using FrameDecodedCallback = std::function<void(std::shared_ptr<DecodedVideoFrame>)>;

    FFmpegVideoDecoder();
    ~FFmpegVideoDecoder();

    bool open(const std::string& filePath);
    void close();
    bool isOpen() const { return isOpen_; }

    const VideoStreamInfo& getStreamInfo() const { return streamInfo_; }
    VideoTimeMapper& getTimeMapper() { return timeMapper_; }

    // Enfileira requisição assíncrona para decodificação (não bloqueia UI)
    void requestFrame(int64_t targetTimeUs, uint64_t generationId, SeekAccuracy accuracy = SeekAccuracy::ExactFrame);

    // Decodificação determinística e síncrona para modo de EXPORTAÇÃO
    bool decodeExactFrameSync(int64_t targetTimeUs, DecodedVideoFrame& outFrame);

    // Registra callback acionado quando um novo quadro é decodificado
    void setFrameCallback(FrameDecodedCallback callback);

    // Obtém o quadro decodificado mais recente
    std::shared_ptr<DecodedVideoFrame> getLatestFrame() const;

    // Cancela requisições com geração anterior
    void cancelPriorGenerations(uint64_t currentGenerationId);

private:
    std::string filePath_;
    std::atomic<bool> isOpen_{false};
    std::atomic<bool> isRunning_{false};

    VideoStreamInfo streamInfo_;
    VideoTimeMapper timeMapper_;

    std::thread workerThread_;
    std::mutex queueMutex_;
    std::condition_variable queueCv_;
    std::deque<DecodeRequest> requestQueue_;

    mutable std::mutex frameMutex_;
    std::shared_ptr<DecodedVideoFrame> latestFrame_;
    FrameDecodedCallback frameCallback_;

    std::atomic<uint64_t> activeGenerationId_{0};
    int64_t currentDecoderPtsUs_ = -1;

    void workerLoop();
    bool internalDecodeTo(int64_t targetPtsUs, DecodedVideoFrame& outFrame, uint64_t genId);
    void generatePlaceholderFrame(int64_t ptsUs, DecodedVideoFrame& outFrame);
};

} // namespace aurea
