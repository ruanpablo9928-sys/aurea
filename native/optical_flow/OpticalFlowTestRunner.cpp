#include <iostream>
#include <cassert>
#include <vector>
#include <cstring>
#include <cmath>

#include "OpticalFlowTypes.h"
#include "SceneCutDetector.h"
#include "FlowFrameCache.h"
#include "QualityController.h"
#include "VulkanBackend.h"
#include "OpticalFlowEngine.h"
#include "../video/ffmpeg/VideoTimeMapper.h"

using namespace aurea;

void testSceneCutDetector() {
    std::cout << "[TEST] SceneCutDetector... ";
    SceneCutDetector detector(0.38f);

    const int width = 128;
    const int height = 128;
    std::vector<uint8_t> frameA(width * height * 4, 100); // cinza médio
    std::vector<uint8_t> frameASlight(width * height * 4, 105); // cinza muito parecido (sem corte)
    std::vector<uint8_t> frameB(width * height * 4, 250); // quase branco (corte de cena)

    // Frames idênticos não são corte
    assert(!detector.isSceneCut(frameA.data(), frameA.data(), width, height));

    // Frames com pequena variação de movimento não são corte
    assert(!detector.isSceneCut(frameA.data(), frameASlight.data(), width, height));

    // Frames drasticamente diferentes são corte
    assert(detector.isSceneCut(frameA.data(), frameB.data(), width, height));

    std::cout << "PASSED" << std::endl;
}

void testFlowFrameCache() {
    std::cout << "[TEST] FlowFrameCache... ";
    // Cache de 1MB para testar eviction rápida
    FlowFrameCache cache(1024 * 1024);

    FlowCacheKey key1{1000000, 1033333, FlowFrameCache::quantizeTime(0.5f), 128, 128, FlowQuality::High, "4.6"};
    FlowCacheKey key2{2000000, 2033333, FlowFrameCache::quantizeTime(0.5f), 128, 128, FlowQuality::High, "4.6"};

    // 1. Cache Miss inicial
    assert(cache.get(key1) == nullptr);
    assert(cache.getMissCount() == 1);

    // 2. Put
    auto frame1 = std::make_shared<InterpolatedFrame>();
    frame1->width = 128;
    frame1->height = 128;
    frame1->rgbaData.resize(128 * 128 * 4, 128);
    cache.put(key1, frame1);

    // 3. Cache Hit
    auto retrieved = cache.get(key1);
    assert(retrieved != nullptr);
    assert(cache.getHitCount() == 1);
    assert(cache.getHitRate() == 50.0);

    // 4. Limpeza de Cache
    cache.clear();
    assert(cache.get(key1) == nullptr);
    assert(cache.getEntryCount() == 0);

    std::cout << "PASSED" << std::endl;
}

void testQualityController() {
    std::cout << "[TEST] QualityController... ";
    QualityController qc(DeviceTier::High);

    // 1. Export sempre tem escala 1.0
    assert(qc.getRecommendedScale(FlowQuality::Low, false, false) == 1.0f);
    assert(qc.getRecommendedScale(FlowQuality::Ultra, false, false) == 1.0f);

    // 2. Scrubbing rápido reduz escala
    assert(qc.getRecommendedScale(FlowQuality::High, true, true) == 0.75f);

    // 3. Prefetch em scrubbing é 0
    assert(qc.getMaxPrefetchFrames(true) == 0);
    // Prefetch em playback no tier High é 3
    assert(qc.getMaxPrefetchFrames(false) == 3);

    std::cout << "PASSED" << std::endl;
}

void testVulkanBackendTiling() {
    std::cout << "[TEST] VulkanBackend Tiling... ";
    VulkanBackend vk;

    // Resolução 720p cabe em tile único de 1024
    auto tiles720 = vk.computeTiling(1280, 720, 1500, 32);
    assert(tiles720.size() == 1);

    // Resolução 4K (3840x2160) com maxTileSize 1024 gera múltiplos ladrilhos com overlap de 32px
    auto tiles4K = vk.computeTiling(3840, 2160, 1024, 32);
    assert(tiles4K.size() > 1);

    // Verifica que cada tile tem largura e altura dentro do limite
    for (const auto& t : tiles4K) {
        assert(t.width <= 1024);
        assert(t.height <= 1024);
    }

    std::cout << "PASSED" << std::endl;
}

void testVideoTimeMapperBounding() {
    std::cout << "[TEST] VideoTimeMapper Bounding Frames... ";
    VideoTimeMapper mapper;

    VideoStreamInfo info;
    info.fps = 30.0;
    info.durationUs = 10000000;
    mapper.setStreamInfo(info);

    // Registra alguns frames a cada 33333 us (~30 fps)
    for (int i = 0; i < 10; ++i) {
        mapper.registerFrameTimestamp(i * 33333, 33333, i == 0);
    }

    int64_t ptsA = 0, ptsB = 0;
    float t = 0.0f;

    // 1. Exatamente no frame 2 (66666 us)
    assert(mapper.findBoundingFrames(66666, ptsA, ptsB, t));
    assert(ptsA == 66666);
    assert(t == 0.0f);

    // 2. Exatamente no meio entre frame 1 e frame 2 (~49999 us)
    int64_t midPoint = 33333 + 16666;
    assert(mapper.findBoundingFrames(midPoint, ptsA, ptsB, t));
    assert(ptsA == 33333);
    assert(ptsB == 66666);
    assert(std::abs(t - 0.5f) < 0.05f);

    std::cout << "PASSED" << std::endl;
}

void testOpticalFlowEngine() {
    std::cout << "[TEST] OpticalFlowEngine Integration... ";
    OpticalFlowEngine engine;

    DeviceCapabilities caps;
    caps.tier = DeviceTier::High;
    caps.totalRamMb = 6144;
    engine.initialize(caps);

    assert(engine.isAvailable());

    const int width = 64;
    const int height = 64;

    DecodedVideoFrame frameA;
    frameA.ptsUs = 0;
    frameA.width = width;
    frameA.height = height;
    frameA.rgbaData.resize(width * height * 4, 100);

    DecodedVideoFrame frameB;
    frameB.ptsUs = 33333;
    frameB.width = width;
    frameB.height = height;
    frameB.rgbaData.resize(width * height * 4, 120);

    FlowInterpolationRequest req;
    req.ptsAUs = frameA.ptsUs;
    req.ptsBUs = frameB.ptsUs;
    req.targetPtsUs = 16666;
    req.t = 0.5f;
    req.quality = FlowQuality::High;

    // 1. Interpolação no instante t=0.5
    auto result = engine.interpolate(frameA, frameB, 0.5f, req);
    assert(result != nullptr);
    assert(result->width == width);
    assert(result->height == height);
    assert(result->rgbaData.size() == static_cast<size_t>(width * height * 4));

    // 2. Extremos: t=0.0 retorna frameA
    auto resultZero = engine.interpolate(frameA, frameB, 0.0f, req);
    assert(resultZero != nullptr);
    assert(resultZero->ptsUs == frameA.ptsUs);

    // 3. Extremos: t=1.0 retorna frameB
    auto resultOne = engine.interpolate(frameA, frameB, 1.0f, req);
    assert(resultOne != nullptr);
    assert(resultOne->ptsUs == frameB.ptsUs);

    // 4. Cache hit na segunda chamada com mesmos parâmetros
    auto resultCached = engine.interpolate(frameA, frameB, 0.5f, req);
    assert(resultCached != nullptr);
    assert(resultCached->isCached);

    // 5. Diagnósticos
    auto diag = engine.getDiagnostics();
    assert(diag.enabled);
    assert(diag.cacheHits >= 1);

    std::cout << "PASSED" << std::endl;
}

int main() {
    std::cout << "==========================================" << std::endl;
    std::cout << "  AUREA OPTICAL FLOW & RIFE TEST SUITE    " << std::endl;
    std::cout << "==========================================" << std::endl;

    testSceneCutDetector();
    testFlowFrameCache();
    testQualityController();
    testVulkanBackendTiling();
    testVideoTimeMapperBounding();
    testOpticalFlowEngine();

    std::cout << "==========================================" << std::endl;
    std::cout << "  ALL OPTICAL FLOW TESTS PASSED!          " << std::endl;
    std::cout << "==========================================" << std::endl;
    return 0;
}
