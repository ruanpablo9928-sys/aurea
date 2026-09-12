#include "MotionGraphEngine.h"
#include <cmath>
#include <algorithm>

namespace aurea {

double MotionGraphEngine::sampleCurveX(double t, double x1, double x2) {
    // ((1 - 3*x2 + 3*x1)*t + (3*x2 - 6*x1))*t + 3*x1)*t
    return (((1.0 - 3.0 * x2 + 3.0 * x1) * t + (3.0 * x2 - 6.0 * x1)) * t + 3.0 * x1) * t;
}

double MotionGraphEngine::sampleCurveY(double t, double y1, double y2) {
    return (((1.0 - 3.0 * y2 + 3.0 * y1) * t + (3.0 * y2 - 6.0 * y1)) * t + 3.0 * y1) * t;
}

double MotionGraphEngine::sampleCurveDerivativeX(double t, double x1, double x2) {
    return ((3.0 - 9.0 * x2 + 9.0 * x1) * t + (6.0 * x2 - 12.0 * x1)) * t + 3.0 * x1;
}

double MotionGraphEngine::solveCurveX(double x, double x1, double x2) {
    // 1. Tentar Newton-Raphson
    double t = x;
    for (int i = 0; i < 8; ++i) {
        double currentX = sampleCurveX(t, x1, x2) - x;
        if (std::abs(currentX) < 1e-6) {
            return t;
        }
        double dX = sampleCurveDerivativeX(t, x1, x2);
        if (std::abs(dX) < 1e-6) {
            break;
        }
        t = t - currentX / dX;
    }

    // 2. Fallback por Bissecção
    double t0 = 0.0;
    double t1 = 1.0;
    t = x;

    if (t < t0) return t0;
    if (t > t1) return t1;

    while (t0 < t1) {
        double currentX = sampleCurveX(t, x1, x2);
        if (std::abs(currentX - x) < 1e-6) {
            return t;
        }
        if (x > currentX) {
            t0 = t;
        } else {
            t1 = t;
        }
        t = (t1 - t0) * 0.5 + t0;
    }

    return t;
}

double MotionGraphEngine::solveCubicBezier(const CubicBezierCurve& curve, double t) {
    if (t <= 0.0) return 0.0;
    if (t >= 1.0) return 1.0;
    double solvedT = solveCurveX(t, curve.x1, curve.x2);
    return sampleCurveY(solvedT, curve.y1, curve.y2);
}

double MotionGraphEngine::evaluateProgress(InterpolationType type, const CubicBezierCurve& curve, double linearT) {
    double t = std::clamp(linearT, 0.0, 1.0);

    switch (type) {
        case InterpolationType::Hold:
            return t >= 1.0 ? 1.0 : 0.0;

        case InterpolationType::EaseIn:
            return solveCubicBezier(CubicBezierCurve::easeIn(), t);

        case InterpolationType::EaseOut:
            return solveCubicBezier(CubicBezierCurve::easeOut(), t);

        case InterpolationType::EaseInOut:
            return solveCubicBezier(CubicBezierCurve::easeInOut(), t);

        case InterpolationType::Bezier:
            return solveCubicBezier(CubicBezierCurve::ease(), t);

        case InterpolationType::CustomBezier:
            return solveCubicBezier(curve, t);

        case InterpolationType::Linear:
        default:
            return t;
    }
}

} // namespace aurea
