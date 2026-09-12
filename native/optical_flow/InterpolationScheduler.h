#pragma once

#include "OpticalFlowTypes.h"
#include <functional>
#include <deque>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <atomic>
#include <memory>

namespace aurea {

using InterpolationCompleteCallback = std::function<void(std::shared_ptr<InterpolatedFrame>)>;
using InterpolateTaskFunc = std::function<std::shared_ptr<InterpolatedFrame>(const FlowInterpolationRequest&)>;

struct ScheduledJob {
    FlowInterpolationRequest request;
    InterpolateTaskFunc task;
    InterpolationCompleteCallback callback;
};

class InterpolationScheduler {
public:
    explicit InterpolationScheduler(size_t numWorkers = 2);
    ~InterpolationScheduler();

    void start(size_t numWorkers = 2);
    void stop();
    bool isRunning() const { return running_.load(); }

    // Enfileira um trabalho assíncrono de interpolação
    void enqueueJob(const FlowInterpolationRequest& request,
                    InterpolateTaskFunc task,
                    InterpolationCompleteCallback callback);

    // Atualiza a geração ativa (descarta imediatamente solicitações obsoletas de scrubbing)
    void setGeneration(uint64_t currentGenerationId);
    uint64_t getActiveGeneration() const { return activeGenerationId_.load(); }

    // Limpa a fila pendente
    void clearQueue();

    // Métricas
    size_t getPendingCount();
    uint64_t getDroppedCount() const { return droppedJobs_.load(); }
    uint64_t getCompletedCount() const { return completedJobs_.load(); }

private:
    std::atomic<bool> running_{false};
    std::atomic<uint64_t> activeGenerationId_{0};
    std::atomic<uint64_t> droppedJobs_{0};
    std::atomic<uint64_t> completedJobs_{0};

    std::vector<std::thread> workers_;
    std::deque<ScheduledJob> queue_;
    std::mutex queueMutex_;
    std::condition_variable cv_;

    void workerLoop();
};

} // namespace aurea
