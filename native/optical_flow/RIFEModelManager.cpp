#include "RIFEModelManager.h"
#include <fstream>
#include <sys/stat.h>

namespace aurea {

static bool fileExistsAndNonEmpty(const std::string& path, int64_t* outSize = nullptr) {
    struct stat buffer;
    if (stat(path.c_str(), &buffer) == 0 && buffer.st_size > 0) {
        if (outSize) *outSize = static_cast<int64_t>(buffer.st_size);
        return true;
    }
    return false;
}

RIFEModelManager& RIFEModelManager::instance() {
    static RIFEModelManager mgr;
    return mgr;
}

RIFEModelManager::RIFEModelManager() {
    buildDefaultRegistry();
}

void RIFEModelManager::buildDefaultRegistry() {
    // 1. RIFE v4.6 (O estado da arte para alta fidelidade e timestep arbitrário)
    ModelManifestEntry rife46;
    rife46.modelId = "rife-v4.6";
    rife46.displayName = "RIFE v4.6 (Fidelidade Máxima)";
    rife46.version = "4.6";
    rife46.paramFileName = "flownet.param";
    rife46.binFileName = "flownet.bin";
    rife46.expectedSizeBytes = 18 * 1024 * 1024; // ~18MB
    rife46.qualityTier = FlowQuality::Ultra;
    rife46.defaultScale = 1.0f;
    rife46.supportsArbitraryTimestep = true;
    rife46.recommendedForExport = true;
    rife46.recommendedForPreview = false;
    registry_[rife46.modelId] = rife46;

    // 2. RIFE v4 (Equilibrado para timeline e speed ramps)
    ModelManifestEntry rife40;
    rife40.modelId = "rife-v4";
    rife40.displayName = "RIFE v4 (Padrão Equilibrado)";
    rife40.version = "4.0";
    rife40.paramFileName = "flownet_v4.param";
    rife40.binFileName = "flownet_v4.bin";
    rife40.expectedSizeBytes = 14 * 1024 * 1024; // ~14MB
    rife40.qualityTier = FlowQuality::High;
    rife40.defaultScale = 1.0f;
    rife40.supportsArbitraryTimestep = true;
    rife40.recommendedForExport = true;
    rife40.recommendedForPreview = true;
    registry_[rife40.modelId] = rife40;

    // 3. RIFE Fast (Modelo quantizado / escala 0.5 para preview instantâneo móvel)
    ModelManifestEntry rifeFast;
    rifeFast.modelId = "rife-fast";
    rifeFast.displayName = "RIFE Fast (Baixa Latência Preview)";
    rifeFast.version = "4.0-fast";
    rifeFast.paramFileName = "flownet_fast.param";
    rifeFast.binFileName = "flownet_fast.bin";
    rifeFast.expectedSizeBytes = 8 * 1024 * 1024; // ~8MB
    rifeFast.qualityTier = FlowQuality::Low;
    rifeFast.defaultScale = 0.5f;
    rifeFast.supportsArbitraryTimestep = true;
    rifeFast.recommendedForPreview = true;
    rifeFast.recommendedForExport = false;
    registry_[rifeFast.modelId] = rifeFast;
}

void RIFEModelManager::initializeManifest(const std::string& baseModelsDirectory) {
    std::lock_guard<std::mutex> lock(mutex_);
    baseModelsDir_ = baseModelsDirectory;

    for (auto& pair : registry_) {
        std::string param = baseModelsDir_ + "/" + pair.second.modelId + "/" + pair.second.paramFileName;
        std::string bin = baseModelsDir_ + "/" + pair.second.modelId + "/" + pair.second.binFileName;
        pair.second.isInstalled = fileExistsAndNonEmpty(param) && fileExistsAndNonEmpty(bin);
    }
}

void RIFEModelManager::setBaseModelsDirectory(const std::string& dir) {
    initializeManifest(dir);
}

std::vector<ModelManifestEntry> RIFEModelManager::getAvailableModels() const {
    std::lock_guard<std::mutex> lock(mutex_);
    std::vector<ModelManifestEntry> list;
    for (const auto& pair : registry_) {
        list.push_back(pair.second);
    }
    return list;
}

bool RIFEModelManager::getModelInfo(const std::string& modelId, ModelManifestEntry& outEntry) const {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = registry_.find(modelId);
    if (it != registry_.end()) {
        outEntry = it->second;
        return true;
    }
    return false;
}

bool RIFEModelManager::verifyModel(const std::string& modelId, std::string& outErrorMessage) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = registry_.find(modelId);
    if (it == registry_.end()) {
        outErrorMessage = "Modelo '" + modelId + "' não cadastrado no manifesto.";
        return false;
    }

    std::string dir = baseModelsDir_.empty() ? modelId : baseModelsDir_ + "/" + modelId;
    std::string paramPath = dir + "/" + it->second.paramFileName;
    std::string binPath = dir + "/" + it->second.binFileName;

    int64_t paramSize = 0, binSize = 0;
    if (!fileExistsAndNonEmpty(paramPath, &paramSize)) {
        outErrorMessage = "Arquivo de parâmetros ausente ou vazio: " + paramPath;
        it->second.isInstalled = false;
        return false;
    }

    if (!fileExistsAndNonEmpty(binPath, &binSize)) {
        outErrorMessage = "Arquivo binário de pesos ausente ou vazio: " + binPath;
        it->second.isInstalled = false;
        return false;
    }

    it->second.isInstalled = true;
    return true;
}

RIFEModelConfig RIFEModelManager::selectOptimalConfig(FlowQuality quality, bool isPreview, int deviceTier) {
    std::lock_guard<std::mutex> lock(mutex_);
    RIFEModelConfig config;

    // Dispositivo com baixo poder de processamento (Tier 0 / Low) ou Preview ágil
    if (isPreview && (quality == FlowQuality::Low || deviceTier <= 1)) {
        config.modelName = "rife-fast";
        config.modelVersion = "4.0-fast";
        config.scale = 0.5f;
        config.useFp16 = true;
        config.numThreads = 2;
    } else if (quality == FlowQuality::Medium) {
        config.modelName = "rife-v4";
        config.modelVersion = "4.0";
        config.scale = 0.75f;
        config.useFp16 = true;
        config.numThreads = 4;
    } else if (quality == FlowQuality::Ultra || (!isPreview && deviceTier >= 2)) {
        config.modelName = "rife-v4.6";
        config.modelVersion = "4.6";
        config.scale = 1.0f;
        config.useFp16 = true;
        config.numThreads = 4;
    } else {
        config.modelName = "rife-v4";
        config.modelVersion = "4.0";
        config.scale = 1.0f;
        config.useFp16 = true;
        config.numThreads = 4;
    }

    auto it = registry_.find(config.modelName);
    if (it != registry_.end()) {
        std::string dir = baseModelsDir_.empty() ? config.modelName : baseModelsDir_ + "/" + config.modelName;
        config.modelPath = dir;
        config.paramFile = dir + "/" + it->second.paramFileName;
        config.binFile = dir + "/" + it->second.binFileName;
    }

    return config;
}

void RIFEModelManager::registerCustomModel(const ModelManifestEntry& entry) {
    std::lock_guard<std::mutex> lock(mutex_);
    registry_[entry.modelId] = entry;
}

} // namespace aurea
