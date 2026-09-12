#pragma once

#include "OpticalFlowTypes.h"
#include <vector>
#include <string>
#include <unordered_map>
#include <memory>
#include <mutex>

namespace aurea {

struct ModelManifestEntry {
    std::string modelId;
    std::string displayName;
    std::string version;
    std::string paramFileName;
    std::string binFileName;
    int64_t expectedSizeBytes = 0;
    std::string sha256Hash;
    FlowQuality qualityTier = FlowQuality::High;
    float defaultScale = 1.0f;
    bool supportsArbitraryTimestep = true;
    bool recommendedForPreview = false;
    bool recommendedForExport = false;
    bool isInstalled = false;
};

class RIFEModelManager {
public:
    static RIFEModelManager& instance();

    RIFEModelManager();
    ~RIFEModelManager() = default;

    // Inicializa o manifesto padrão de modelos RIFE compatíveis
    void initializeManifest(const std::string& baseModelsDirectory);

    // Registra um diretório base de busca de modelos
    void setBaseModelsDirectory(const std::string& dir);
    const std::string& getBaseModelsDirectory() const { return baseModelsDir_; }

    // Retorna todos os modelos cadastrados no manifesto
    std::vector<ModelManifestEntry> getAvailableModels() const;

    // Obtém detalhes de um modelo específico
    bool getModelInfo(const std::string& modelId, ModelManifestEntry& outEntry) const;

    // Valida a integridade física dos arquivos do modelo no disco
    bool verifyModel(const std::string& modelId, std::string& outErrorMessage);

    // Seleciona automaticamente o modelo mais adequado para a qualidade e dispositivo
    RIFEModelConfig selectOptimalConfig(FlowQuality quality, bool isPreview, int deviceTier);

    // Registra manualmente um novo modelo
    void registerCustomModel(const ModelManifestEntry& entry);

private:
    std::string baseModelsDir_;
    std::unordered_map<std::string, ModelManifestEntry> registry_;
    mutable std::mutex mutex_;

    void buildDefaultRegistry();
};

} // namespace aurea
