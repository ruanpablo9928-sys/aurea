#include "BezierEvaluator.h"
#include <algorithm>

namespace aurea {

static constexpr double kEpsilon = 1e-7;
static constexpr int kMaxNewtonIterations = 8;
static constexpr int kMaxBisectionIterations = 16;

double BezierEvaluator::sampleX(double u, double x0, double cx0, double cx1, double x1) {
    double inv = 1.0 - u;
    return inv * inv * inv * x0 +
           3.0 * inv * inv * u * cx0 +
           3.0 * inv * u * u * cx1 +
           u * u * u * x1;
}

double BezierEvaluator::sampleY(double u, double y0, double cy0, double cy1, double y1) {
    double inv = 1.0 - u;
    return inv * inv * inv * y0 +
           3.0 * inv * inv * u * cy0 +
           3.0 * inv * u * u * cy1 +
           u * u * u * y1;
}

double BezierEvaluator::sampleDerivativeX(double u, double x0, double cx0, double cx1, double x1) {
    double inv = 1.0 - u;
    return 3.0 * inv * inv * (cx0 - x0) +
           6.0 * inv * u * (cx1 - cx0) +
           3.0 * u * u * (x1 - cx1);
}

double BezierEvaluator::sampleDerivativeY(double u, double y0, double cy0, double cy1, double y1) {
    double inv = 1.0 - u;
    return 3.0 * inv * inv * (cy0 - y0) +
           6.0 * inv * u * (cy1 - cy0) +
           3.0 * u * u * (y1 - cy1);
}

double BezierEvaluator::solveUForX(double targetX, double x0, double cx0, double cx1, double x1) {
    if (std::abs(x1 - x0) < kEpsilon) return 0.0;

    // Estimativa inicial linear
    double u = (targetX - x0) / (x1 - x0);
    u = std::clamp(u, 0.0, 1.0);

    // Tentativa Newton-Raphson
    for (int i = 0; i < kMaxNewtonIterations; ++i) {
        double currentX = sampleX(u, x0, cx0, cx1, x1) - targetX;
        if (std::abs(currentX) < kEpsilon) {
            return u;
        }
        double dX = sampleDerivativeX(u, x0, cx0, cx1, x1);
        if (std::abs(dX) < 1e-6) {
            break;
        }
        u -= currentX / dX;
        if (u < 0.0 || u > 1.0) {
            break;
        }
    }

    // Fallback garantido: Bisseção
    double low = 0.0;
    double high = 1.0;
    u = (low + high) * 0.5;

    for (int i = 0; i < kMaxBisectionIterations; ++i) {
        double currentX = sampleX(u, x0, cx0, cx1, x1);
        if (std::abs(currentX - targetX) < kEpsilon) {
            return u;
        }
        if (currentX < targetX) {
            low = u;
        } else {
            high = u;
        }
        u = (low + high) * 0.5;
    }

    return u;
}

bool BezierEvaluator::solveCubicBezier(double x0, double y0,
                                      double cx0, double cy0,
                                      double cx1, double cy1,
                                      double x1, double y1,
                                      double targetX,
                                      double& outY,
                                      double& outDerivative) {
    double u = solveUForX(targetX, x0, cx0, cx1, x1);
    outY = sampleY(u, y0, cy0, cy1, y1);

    double dx = sampleDerivativeX(u, x0, cx0, cx1, x1);
    double dy = sampleDerivativeY(u, y0, cy0, cy1, y1);

    if (std::abs(dx) > 1e-7) {
        outDerivative = dy / dx;
    } else {
        outDerivative = 0.0;
    }

    return true;
}

void BezierEvaluator::evaluateSegment(const TimeRemapKeyframe& k0,
                                     const TimeRemapKeyframe& k1,
                                     double compositionTime,
                                     double& outSourceTime,
                                     double& outSpeed) {
    double dt = k1.compositionTime - k0.compositionTime;
    if (dt <= kEpsilon) {
        outSourceTime = k0.sourceTime;
        outSpeed = 0.0;
        return;
    }

    switch (k0.interpolation) {
        case TimeRemapInterpolation::Hold: {
            outSourceTime = k0.sourceTime;
            outSpeed = 0.0;
            break;
        }
        case TimeRemapInterpolation::Linear: {
            double u = (compositionTime - k0.compositionTime) / dt;
            outSourceTime = k0.sourceTime + u * (k1.sourceTime - k0.sourceTime);
            outSpeed = (k1.sourceTime - k0.sourceTime) / dt;
            break;
        }
        case TimeRemapInterpolation::EaseIn: {
            // Preset Ease In: P0(0,0), C0(0.42, 0), C1(1, 1), P1(1, 1)
            double x0 = k0.compositionTime;
            double y0 = k0.sourceTime;
            double x1 = k1.compositionTime;
            double y1 = k1.sourceTime;
            double cx0 = x0 + dt * 0.42;
            double cy0 = y0;
            double cx1 = x1;
            double cy1 = y1;
            solveCubicBezier(x0, y0, cx0, cy0, cx1, cy1, x1, y1, compositionTime, outSourceTime, outSpeed);
            break;
        }
        case TimeRemapInterpolation::EaseOut: {
            // Preset Ease Out: P0(0,0), C0(0, 0), C1(0.58, 1), P1(1, 1)
            double x0 = k0.compositionTime;
            double y0 = k0.sourceTime;
            double x1 = k1.compositionTime;
            double y1 = k1.sourceTime;
            double cx0 = x0;
            double cy0 = y0;
            double cx1 = x0 + dt * 0.58;
            double cy1 = y1;
            solveCubicBezier(x0, y0, cx0, cy0, cx1, cy1, x1, y1, compositionTime, outSourceTime, outSpeed);
            break;
        }
        case TimeRemapInterpolation::EaseInOut: {
            // Preset Ease In Out: P0(0,0), C0(0.42, 0), C1(0.58, 1), P1(1, 1)
            double x0 = k0.compositionTime;
            double y0 = k0.sourceTime;
            double x1 = k1.compositionTime;
            double y1 = k1.sourceTime;
            double cx0 = x0 + dt * 0.42;
            double cy0 = y0;
            double cx1 = x0 + dt * 0.58;
            double cy1 = y1;
            solveCubicBezier(x0, y0, cx0, cy0, cx1, cy1, x1, y1, compositionTime, outSourceTime, outSpeed);
            break;
        }
        case TimeRemapInterpolation::Bezier:
        case TimeRemapInterpolation::CustomBezier:
        default: {
            double x0 = k0.compositionTime;
            double y0 = k0.sourceTime;
            double x1 = k1.compositionTime;
            double y1 = k1.sourceTime;

            double cx0 = x0 + k0.outHandle.dx;
            double cy0 = y0 + k0.outHandle.dy;
            double cx1 = x1 + k1.inHandle.dx;
            double cy1 = y1 + k1.inHandle.dy;

            // Garantir que as alças em X estejam no intervalo ordenado
            cx0 = std::clamp(cx0, x0, x1);
            cx1 = std::clamp(cx1, x0, x1);

            solveCubicBezier(x0, y0, cx0, cy0, cx1, cy1, x1, y1, compositionTime, outSourceTime, outSpeed);
            break;
        }
    }
}

} // namespace aurea
