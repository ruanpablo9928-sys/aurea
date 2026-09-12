#pragma once

#include "OpticalFlowTypes.h"
#include "VulkanBackend.h"
#include <memory>
#include <string>
#include <mutex>

namespace aurea {

class NCNNBackend {
public:
    NCNNBackend();
    ~NCNNBackend();

    bool initialize(std::shared_ptr<VulkanBackend> vulkan);
    void shutdown();

    bool loadModel(const RIFEModelConfig& config);
    bool isModelLoaded() const { return modelLoaded_; }
    const std::string& getLoadedModelName() const { return currentModelName_; }

    // Executa a inferência de interpolação entre Frame A e Frame B no instante t (0.0 .. 1.0)
    bool process(const uint8_t* rgbaA,
                 const uint8_t* rgbaB,
                 int width,
                 int height,
                 float t,
                 uint8_t* outRgba,
                 const RIFEModelConfig& config);

    // Motor de Optical Flow nativo com Warping bidirecional e fusão adaptativa de fluxo
    static void computeOpticalFlowWarp(const uint8_t* rgbaA,
                                       const uint8_t* rgbaB,
                                       int width,
                                       int height,
                                       float t,
                                       uint8_t* outRgba,
                                       float scale = 1.0f);

private:
    bool initialized_ = false;
    bool modelLoaded_ = false;
    std::string currentModelName_;
    std::shared_ptr<VulkanBackend> vulkan_;
    mutable std::mutex mutex_;

    // Estrutura opaca para isolamento de headers ncnn
    struct NetImpl;
    std::unique_ptr<NetImpl> impl_;
};

} // namespace aurea
