#include "JobSystem.h"
#include <algorithm>

namespace aurea {

JobSystem& JobSystem::instance() {
    static JobSystem sInstance;
    return sInstance;
}

JobSystem::JobSystem(size_t numThreads) {
    initialize(numThreads);
}

JobSystem::~JobSystem() {
    shutdown();
}

void JobSystem::initialize(size_t numThreads) {
    if (running_.load(std::memory_order_acquire)) return;

    if (numThreads == 0) {
        unsigned int hw = std::thread::hardware_concurrency();
        // Reserva pelo menos 1 thread para a UI/main loop, mantendo entre 2 e 8 workers em mobile
        numThreads = std::clamp(hw > 1 ? hw - 1 : 1, 2u, 8u);
    }

    running_.store(true, std::memory_order_release);
    workers_.reserve(numThreads);

    for (size_t i = 0; i < numThreads; ++i) {
        workers_.emplace_back(&JobSystem::workerLoop, this);
    }
}

void JobSystem::shutdown() {
    if (!running_.load(std::memory_order_acquire)) return;

    running_.store(false, std::memory_order_release);
    cv_.notify_all();

    for (std::thread& worker : workers_) {
        if (worker.joinable()) {
            worker.join();
        }
    }
    workers_.clear();

    std::lock_guard<std::mutex> lock(queueMutex_);
    while (!jobQueue_.empty()) {
        jobQueue_.pop();
    }
}

int64_t JobSystem::enqueue(std::function<void()> task,
                          JobPriority priority,
                          std::shared_ptr<CancellationToken> token) {
    if (!running_.load(std::memory_order_acquire) || !task) {
        return -1;
    }

    int64_t jobId = nextJobId_.fetch_add(1, std::memory_order_relaxed);
    Job job;
    job.id = jobId;
    job.priority = priority;
    job.task = std::move(task);
    job.token = token;

    {
        std::lock_guard<std::mutex> lock(queueMutex_);
        jobQueue_.push(std::move(job));
    }

    cv_.notify_one();
    return jobId;
}

size_t JobSystem::getPendingJobCount() {
    std::lock_guard<std::mutex> lock(queueMutex_);
    return jobQueue_.size();
}

void JobSystem::workerLoop() {
    while (running_.load(std::memory_order_acquire)) {
        Job currentJob;
        {
            std::unique_lock<std::mutex> lock(queueMutex_);
            cv_.wait(lock, [this]() {
                return !running_.load(std::memory_order_acquire) || !jobQueue_.empty();
            });

            if (!running_.load(std::memory_order_acquire) && jobQueue_.empty()) {
                return;
            }

            if (!jobQueue_.empty()) {
                currentJob = std::move(const_cast<Job&>(jobQueue_.top()));
                jobQueue_.pop();
            }
        }

        // Se o job foi cancelado antes de iniciar, descarta
        if (currentJob.token && currentJob.token->isCancelled()) {
            continue;
        }

        if (currentJob.task) {
            try {
                currentJob.task();
            } catch (...) {
                // Previne que exceções em jobs background derrubem o worker loop
            }
        }
    }
}

} // namespace aurea
