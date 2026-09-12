#pragma once

#include <functional>
#include <vector>
#include <queue>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <atomic>
#include <memory>
#include <future>

namespace aurea {

enum class JobPriority {
    High = 0,
    Normal = 1,
    Background = 2
};

class CancellationToken {
public:
    CancellationToken() : cancelled_(false) {}

    void cancel() { cancelled_.store(true, std::memory_order_release); }
    bool isCancelled() const { return cancelled_.load(std::memory_order_acquire); }
    void reset() { cancelled_.store(false, std::memory_order_release); }

private:
    std::atomic<bool> cancelled_;
};

struct Job {
    int64_t id = 0;
    JobPriority priority = JobPriority::Normal;
    std::function<void()> task;
    std::shared_ptr<CancellationToken> token;

    bool operator<(const Job& other) const {
        // Menor valor numérico de JobPriority = maior prioridade
        return static_cast<int>(priority) > static_cast<int>(other.priority);
    }
};

class JobSystem {
public:
    static JobSystem& instance();

    JobSystem(size_t numThreads = 0);
    ~JobSystem();

    void initialize(size_t numThreads = 0);
    void shutdown();
    bool isRunning() const { return running_.load(std::memory_order_acquire); }

    int64_t enqueue(std::function<void()> task,
                    JobPriority priority = JobPriority::Normal,
                    std::shared_ptr<CancellationToken> token = nullptr);

    template<typename F, typename... Args>
    auto enqueueWithResult(JobPriority priority, std::shared_ptr<CancellationToken> token, F&& f, Args&&... args)
        -> std::future<typename std::invoke_result<F, Args...>::type> {
        using ReturnType = typename std::invoke_result<F, Args...>::type;

        auto task = std::make_shared<std::packaged_task<ReturnType()>>(
            std::bind(std::forward<F>(f), std::forward<Args>(args)...)
        );

        std::future<ReturnType> res = task->get_future();
        enqueue([task]() { (*task)(); }, priority, token);
        return res;
    }

    size_t getPendingJobCount();

private:
    std::vector<std::thread> workers_;
    std::priority_queue<Job> jobQueue_;
    std::mutex queueMutex_;
    std::condition_variable cv_;
    std::atomic<bool> running_{false};
    std::atomic<int64_t> nextJobId_{1};

    void workerLoop();
};

} // namespace aurea
