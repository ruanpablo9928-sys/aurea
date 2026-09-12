#pragma once

#include "TimeRemapKeyframe.h"
#include <vector>
#include <mutex>
#include <memory>

namespace aurea {

enum class ExtrapolationMode {
    Hold,           // Mantém o valor do primeiro/último keyframe
    ContinueLinear, // Continua com a inclinação da extremidade
    Loop,           // Repete a curva ciclicamente
    PingPong        // Reflete a curva para frente e para trás
};

class TimeRemapCurve {
public:
    TimeRemapCurve();
    ~TimeRemapCurve() = default;

    // Inicializa curva padrão 1:1 de 0s a durationSeconds
    void resetDefault(double durationSeconds);

    // Adiciona ou atualiza keyframe ordenado por compositionTime
    void addKeyframe(const TimeRemapKeyframe& kf);

    // Remove keyframe por índice
    bool removeKeyframe(size_t index);

    // Remove keyframe pelo tempo com tolerância
    bool removeKeyframeAt(double compositionTime, double tolerance = 0.001);

    // Limpa todos os keyframes
    void clear();

    // Quantidade de keyframes
    size_t getKeyframeCount() const;

    // Retorna cópia de todos os keyframes
    std::vector<TimeRemapKeyframe> getKeyframes() const;

    // Retorna keyframe específico
    bool getKeyframe(size_t index, TimeRemapKeyframe& outKf) const;

    // Atualiza keyframe existente no índice
    bool setKeyframe(size_t index, const TimeRemapKeyframe& kf);

    // Avalia o sourceTime exato correspondente a compositionTime
    double evaluate(double compositionTime) const;

    // Avalia a velocidade instantânea (derivada temporal d(sourceTime)/d(compTime))
    double evaluateSpeed(double compositionTime) const;

    // Configura modo de extrapolação fora do intervalo de keyframes
    void setExtrapolationMode(ExtrapolationMode mode) { extrapolation_ = mode; }
    ExtrapolationMode getExtrapolationMode() const { return extrapolation_; }

private:
    std::vector<TimeRemapKeyframe> keyframes_;
    ExtrapolationMode extrapolation_ = ExtrapolationMode::ContinueLinear;
    mutable std::mutex mutex_;

    // Busca binária pelo segmento ativo
    size_t findSegmentIndex(double compositionTime) const;
};

} // namespace aurea
