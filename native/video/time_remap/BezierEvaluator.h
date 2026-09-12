#pragma once

#include "TimeRemapKeyframe.h"
#include <cmath>

namespace aurea {

class BezierEvaluator {
public:
    // Avalia o segmento entre dois keyframes k0 e k1 para compositionTime no intervalo [k0.compositionTime, k1.compositionTime]
    static void evaluateSegment(const TimeRemapKeyframe& k0,
                                const TimeRemapKeyframe& k1,
                                double compositionTime,
                                double& outSourceTime,
                                double& outSpeed);

    // Avalia curva Bézier cúbica paramétrica dada pelos pontos (P0, C0, C1, P1)
    static bool solveCubicBezier(double x0, double y0,
                                 double cx0, double cy0,
                                 double cx1, double cy1,
                                 double x1, double y1,
                                 double targetX,
                                 double& outY,
                                 double& outDerivative);

private:
    static double sampleX(double u, double x0, double cx0, double cx1, double x1);
    static double sampleY(double u, double y0, double cy0, double cy1, double y1);
    static double sampleDerivativeX(double u, double x0, double cx0, double cx1, double x1);
    static double sampleDerivativeY(double u, double y0, double cy0, double cy1, double y1);
    static double solveUForX(double targetX, double x0, double cx0, double cx1, double x1);
};

} // namespace aurea
