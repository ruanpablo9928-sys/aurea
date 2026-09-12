#include "GPUUploadQueue.h"

namespace aurea {

GPUUploadQueue::GPUUploadQueue() = default;

GPUUploadQueue::~GPUUploadQueue() {
    clear();
}

void GPUUploadQueue::enqueueUpload(const std::string& name,
                                  size_t sizeBytes,
                                  std::function<bool()> action,
                                  std::shared_ptr<CancellationToken> token) {
    if (!action) return;

    std::lock_guard<std::mutex> lock(mutex_);
    UploadItem item;
    item.id = nextItemId_++;
    item.name = name;
    item.sizeBytes = sizeBytes;
    item.uploadAction = std::move(action);
    item.token = token;

    queue_.push_back(std::move(item));
    totalBytesPending_.fetch_add(sizeBytes, std::memory_order_relaxed);
}

void GPUUploadQueue::processFrame(float budgetMs) {
    if (budgetMs <= 0.0f) return;

    auto startTime = std::chrono::steady_clock::now();
    double budgetUs = budgetMs * 1000.0;

    while (true) {
        UploadItem item;
        {
            std::lock_guard<std::mutex> lock(mutex_);
            if (queue_.empty()) {
                break;
            }
            item = std::move(queue_.front());
            queue_.pop_front();
        }

        // Verifica cancelamento
        if (item.token && item.token->isCancelled()) {
            totalBytesPending_.fetch_sub(item.sizeBytes, std::memory_order_relaxed);
            continue;
        }

        // Executa o upload na GPU
        bool finished = false;
        try {
            if (item.uploadAction) {
                finished = item.uploadAction();
            } else {
                finished = true;
            }
        } catch (...) {
            finished = true; // Em caso de erro, não entra em loop infinito
        }

        if (finished) {
            totalBytesPending_.fetch_sub(item.sizeBytes, std::memory_order_relaxed);
        } else {
            // Se não finalizou (fatiamento multi-frame), recoloca no início da fila
            std::lock_guard<std::mutex> lock(mutex_);
            queue_.push_front(std::move(item));
        }

        // Checa se estourou o frame budget
        auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(
            std::chrono::steady_clock::now() - startTime
        ).count();

        if (elapsed >= budgetUs) {
            // Devolve o controle imediatamente para o render loop
            break;
        }
    }
}

void GPUUploadQueue::clear() {
    std::lock_guard<std::mutex> lock(mutex_);
    queue_.clear();
    totalBytesPending_.store(0, std::memory_order_release);
}

bool GPUUploadQueue::isIdle() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return queue_.empty();
}

size_t GPUUploadQueue::getPendingCount() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return queue_.size();
}

size_t GPUUploadQueue::getTotalBytesPending() const {
    return totalBytesPending_.load(std::memory_order_relaxed);
}

} // namespace aurea
