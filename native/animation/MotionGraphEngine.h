#pragma once

#include <cstdint>
#include <vector>
#include <string>

namespace aurea {

enum class InterpolationType {
    Linear = 0,
    Hold = 1,
    Bezier = 2,
    EaseIn = 3,
    EaseOut = 4,
    EaseInOut = 5,
    CustomBezier = 6
};

struct CubicBezierCurve {
    double x1 = 0.0;
    double y1 = 0.0;
    double x2 = 1.0;
    double y2 = 1.0;

    static CubicBezierCurve ease() { return {0.25, 0.1, 0.25, 1.0}; }
    static CubicBezierCurve easeIn() { return {0.42, 0.0, 1.0, 1.0}; }
    static CubicBezierCurve easeOut() { return {0.0, 0.0, 0.58, 1.0}; }
    static CubicBezierCurve easeInOut() { return {0.42, 0.0, 0.58, 1.0}; }
    static CubicBezierCurve linear() { return {0.0, 0.0, 1.0, 1.0}; }
};

class MotionGraphEngine {
public:
    MotionGraphEngine() = default;
    ~MotionGraphEngine() = default;

    // Avalia o valor Y de uma curva Bézier cúbica para um progresso t em [0, 1]
    static double solveCubicBezier(const CubicBezierCurve& curve, double t);

    // Avalia interpolação geral dado o tipo e parâmetros de curva
    static double evaluateProgress(InterpolationType type, const CubicBezierCurve& curve, double linearT);

private:
    static double sampleCurveX(double t, double x1, double x2);
    static double sampleCurveY(double t, double y1, double y2);
    static double sampleCurveDerivativeX(double t, double x1, double x2);
    static double solveCurveX(double x, double x1, double x2);
};

} // namespace aurea
