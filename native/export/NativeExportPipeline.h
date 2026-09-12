#pragma once

#include "../core/ProjectCore.h"
#include "../renderer/RenderEngine.h"
#include <memory>
#include <atomic>
#include <functional>
#include <string>

namespace aurea {

using ExportProgressCallback = void(*)(float progress, int currentFrame, int totalFrames);

struct ExportConfig {
    int width = 1920;
    int height = 1080;
    int fps = 30;
    int64_t durationUs = 5000000; // 5 segundos padrão
    int bitrate = 8000000;         // 8 Mbps
    std::string outputPath;
};

class NativeExportPipeline {
public:
    NativeExportPipeline();
    ~NativeExportPipeline();

    // Inicia exportação síncrona ou em thread nativa
    bool exportProject(std::shared_ptr<ProjectCore> project,
                       const ExportConfig& config,
                       ExportProgressCallback progressCallback = nullptr);

    // Renderiza diretamente um quadro específico para um buffer RGBA contíguo de alta velocidade
    bool renderFrameDirect(std::shared_ptr<ProjectCore> project,
                           int frameIndex,
                           int width,
                           int height,
                           int fps,
                           uint8_t* outRgbaBuffer);

    void cancelExport();
    bool isExporting() const { return isExporting_.load(); }
    float getProgress() const { return progress_.load(); }

private:
    std::atomic<bool> isExporting_{false};
    std::atomic<bool> cancelRequested_{false};
    std::atomic<float> progress_{0.0f};

    std::unique_ptr<RenderEngine> exportRenderEngine_;
};

} // namespace aurea
