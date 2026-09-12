#include "InterpolationScheduler.h"

namespace aurea {

InterpolationScheduler::InterpolationScheduler(size_t numWorkers) {
    start(numWorkers);
}

InterpolationScheduler::~InterpolationScheduler() {
    stop();
}

void InterpolationScheduler::start(size_t numWorkers) {
    if (running_.load()) return;
    running_.store(true);

    size_t count = (numWorkers == 0) ? 2 : numWorkers;
    workers_.reserve(count);
    for (size_t i = 0; i < count; ++i) {
        workers_.emplace_back(&InterpolationScheduler::workerLoop, this);
    }
}

void InterpolationScheduler::stop() {
    if (!running_.load()) return;
    running_.store(false);
    cv_.notify_all();

    for (auto& t : workers_) {
        if (t.joinable()) {
            t.join();
        }
    }
    workers_.clear();

    clearQueue();
}

void InterpolationScheduler::enqueueJob(const FlowInterpolationRequest& request,
                                       InterpolateTaskFunc task,
                                       InterpolationCompleteCallback callback) {
    if (!running_.load()) return;

    // Se já chegou com geração defasada, ignora de imediato
    if (request.generationId < activeGenerationId_.load() && !request.exportMode) {
        droppedJobs_++;
        return;
    }

    std::lock_guard<std::mutex> lock(queueMutex_);
    if (request.preview) {
        // Modo Preview: coloca no início da fila para priorizar o quadro mais recente da agulha
        queue_.push_front({request, std::move(task), std::move(callback)});
    } else {
        // Modo Export: ordem sequencial determinística FIFO
        queue_.push_back({request, std::move(task), std::move(callback)});
    }
    cv_.notify_one();
}

void InterpolationScheduler::setGeneration(uint64_t currentGenerationId) {
    activeGenerationId_.store(currentGenerationId);

    // Remove imediatamente jobs antigos da fila pendente
    std::lock_guard<std::mutex> lock(queueMutex_);
    auto it = queue_.begin();
    while (it != queue_.end()) {
        if (!it->request.exportMode && it->request.generationId < currentGenerationId) {
            droppedJobs_++;
            it = queue_.erase(it);
        } else {
            ++it;
        }
    }
}

void InterpolationScheduler::clearQueue() {
    std::lock_guard<std::mutex> lock(queueMutex_);
    droppedJobs_ += queue_.size();
    queue_.clear();
}

size_t InterpolationScheduler::getPendingCount() {
    std::lock_guard<std::mutex> lock(queueMutex_);
    return queue_.size();
}

void InterpolationScheduler::workerLoop() {
    while (running_.load()) {
        ScheduledJob job;
        {
            std::unique_lock<std::mutex> lock(queueMutex_);
            cv_.wait(lock, [this] {
                return !running_.load() || !queue_.empty();
            });

            if (!running_.load()) break;

            job = std::move(queue_.front());
            queue_.pop_front();
        }

        // Verificação de stale job antes de executar o RIFE
        uint64_t currentGen = activeGenerationId_.load();
        if (!job.request.exportMode && job.request.generationId < currentGen) {
            droppedJobs_++;
            continue;
        }

        std::shared_ptr<InterpolatedFrame> result;
        if (job.task) {
            result = job.task(job.request);
        }

        // Verificação de stale job pós-execução
        if (!job.request.exportMode && job.request.generationId < activeGenerationId_.load()) {
            droppedJobs_++;
            continue;
        }

        completedJobs_++;

        if (job.callback && result) {
            job.callback(result);
        }
    }
}

} // namespace aurea
