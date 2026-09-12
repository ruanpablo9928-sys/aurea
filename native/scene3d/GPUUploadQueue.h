#pragma once

#include "JobSystem.h"
#include <functional>
#include <deque>
#include <mutex>
#include <atomic>
#include <chrono>

namespace aurea {

struct UploadItem {
    int64_t id = 0;
    std::string name;
    size_t sizeBytes = 0;
    std::function<bool()> uploadAction; // Retorna true se finalizado, false se precisa continuar
    std::shared_ptr<CancellationToken> token;
};

class GPUUploadQueue {
public:
    GPUUploadQueue();
    ~GPUUploadQueue();

    // Adiciona item para upload incremental
    void enqueueUpload(const std::string& name,
                       size_t sizeBytes,
                       std::function<bool()> action,
                       std::shared_ptr<CancellationToken> token = nullptr);

    // Executado dentro da thread de renderização da GPU respeitando o frame budget
    void processFrame(float budgetMs);

    void clear();
    bool isIdle() const;
    size_t getPendingCount() const;
    size_t getTotalBytesPending() const;

private:
    std::deque<UploadItem> queue_;
    mutable std::mutex mutex_;
    std::atomic<size_t> totalBytesPending_{0};
    int64_t nextItemId_ = 1;
};

} // namespace aurea
