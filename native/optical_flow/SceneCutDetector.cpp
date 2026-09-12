#include "SceneCutDetector.h"
#include <cmath>
#include <algorithm>

namespace aurea {

SceneCutDetector::SceneCutDetector(float threshold)
    : threshold_(threshold) {}

float SceneCutDetector::calculateDifferenceScore(const uint8_t* rgbaA, const uint8_t* rgbaB, int width, int height, int stride) {
    if (!rgbaA || !rgbaB || width <= 0 || height <= 0) {
        return 0.0f;
    }

    // Amostragem em grade com salto adaptativo para garantir execução em sub-milissegundo
    const int stepX = std::max(4, width / 64);
    const int stepY = std::max(4, height / 64);

    double totalDiff = 0.0;
    int sampleCount = 0;

    // Histograma simplificado de luminância de 16 bins para comparar distribuição de iluminação/cor
    int histA[16] = {0};
    int histB[16] = {0};

    for (int y = 0; y < height; y += stepY) {
        const int rowOffset = y * width * stride;
        for (int x = 0; x < width; x += stepX) {
            const int idx = rowOffset + x * stride;

            // Coeficientes ITU-R BT.601 para Luminância
            const double lumA = 0.299 * rgbaA[idx] + 0.587 * rgbaA[idx + 1] + 0.114 * rgbaA[idx + 2];
            const double lumB = 0.299 * rgbaB[idx] + 0.587 * rgbaB[idx + 1] + 0.114 * rgbaB[idx + 2];

            totalDiff += std::abs(lumA - lumB);

            int binA = std::clamp(static_cast<int>(lumA / 16.0), 0, 15);
            int binB = std::clamp(static_cast<int>(lumB / 16.0), 0, 15);
            histA[binA]++;
            histB[binB]++;

            sampleCount++;
        }
    }

    if (sampleCount == 0) return 0.0f;

    // 1. Média absoluta de diferença normalizada [0..1]
    double meanDiffNorm = (totalDiff / sampleCount) / 255.0;

    // 2. Distância de histograma (Bhattacharyya simplificado / soma de diferenças absolutas)
    double histDiff = 0.0;
    for (int b = 0; b < 16; ++b) {
        double probA = static_cast<double>(histA[b]) / sampleCount;
        double probB = static_cast<double>(histB[b]) / sampleCount;
        histDiff += std::abs(probA - probB);
    }
    double histScore = histDiff * 0.5; // normalizado [0..1]

    // Pontuação combinada ponderada
    float finalScore = static_cast<float>(0.6 * meanDiffNorm + 0.4 * histScore);
    return std::clamp(finalScore, 0.0f, 1.0f);
}

bool SceneCutDetector::isSceneCut(const uint8_t* rgbaA, const uint8_t* rgbaB, int width, int height, int stride) {
    float score = calculateDifferenceScore(rgbaA, rgbaB, width, height, stride);
    return score >= threshold_;
}

} // namespace aurea
