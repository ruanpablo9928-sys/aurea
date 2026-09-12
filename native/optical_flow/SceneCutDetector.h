#pragma once

#include <cstdint>
#include <vector>

namespace aurea {

class SceneCutDetector {
public:
    explicit SceneCutDetector(float threshold = 0.38f);
    ~SceneCutDetector() = default;

    void setThreshold(float threshold) { threshold_ = threshold; }
    float getThreshold() const { return threshold_; }

    // Avalia se há um corte brusco de cena entre Frame A e Frame B
    // Retorna true se for detectado corte de cena
    bool isSceneCut(const uint8_t* rgbaA, const uint8_t* rgbaB, int width, int height, int stride = 4);

    // Avalia a métrica de distância contínua [0.0 .. 1.0] entre dois quadros
    float calculateDifferenceScore(const uint8_t* rgbaA, const uint8_t* rgbaB, int width, int height, int stride = 4);

private:
    float threshold_ = 0.38f;
};

} // namespace aurea
