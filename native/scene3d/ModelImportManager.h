#pragma once

#include "JobSystem.h"
#include "ModelAnalyzer.h"
#include "GPUUploadQueue.h"
#include "LODManager.h"
#include "AssetCache.h"
#include <string>
#include <memory>
#include <unordered_map>
#include <mutex>
#include <functional>

namespace aurea {

enum class ImportStage {
    Idle,
    Analyzing,
    ProxyReady,
    Decoding,
    Optimizing,
    UploadingGPU,
    Completed,
    Cancelled,
    Failed
};

struct ImportProgress {
    int64_t jobId = 0;
    ImportStage stage = ImportStage::Idle;
    float progress = 0.0f; // 0.0 a 1.0
    std::string stageDescription;
    std::string errorMessage;
    bool isDone = false;
};

struct ImportOptions {
    bool generateLODs = true;
    bool streamTextures = true;
    int maxTextureDim = 2048;
    bool useCache = true;
};

using ImportProgressCallback = std::function<void(const ImportProgress&)>;

class ModelImportManager {
public:
    static ModelImportManager& instance();

    ModelImportManager();
    ~ModelImportManager();

    // Inicia importação assíncrona em background
    int64_t startImportAsync(const std::string& filePath,
                             const ImportOptions& options,
                             std::shared_ptr<GPUUploadQueue> uploadQueue,
                             std::function<void(std::shared_ptr<Mesh3D> proxyMesh, std::shared_ptr<Mesh3D> finalMesh)> onMeshReady,
                             ImportProgressCallback progressCallback = nullptr);

    // Cancela uma importação em andamento
    void cancelImport(int64_t jobId);

    // Consulta o progresso atual
    ImportProgress getProgress(int64_t jobId) const;

    // Remove registros concluídos
    void cleanupJob(int64_t jobId);

private:
    struct ActiveImport {
        int64_t jobId = 0;
        std::string filePath;
        ImportProgress progress;
        std::shared_ptr<CancellationToken> cancelToken;
        ImportProgressCallback callback;
    };

    std::unordered_map<int64_t, std::shared_ptr<ActiveImport>> activeJobs_;
    mutable std::mutex mutex_;
    std::atomic<int64_t> nextJobId_{1};

    void updateProgress(int64_t jobId, ImportStage stage, float progress, const std::string& desc);
};

} // namespace aurea
