#include "meshoptimizer.h"
#include <cstdint>
#include <cstring>
#include <vector>
#if defined(_WIN32)
#define API __declspec(dllexport)
#else
#define API __attribute__((visibility("default"))) __attribute__((used))
#endif
// Separate output guarantees failure never changes the caller's mesh.
extern "C" API int aurea_meshopt_cache(uint32_t* indices, uint32_t count, uint32_t vertices) {
  if (!indices || !count || count % 3 || !vertices) return 0;
  for (uint32_t i = 0; i < count; ++i) if (indices[i] >= vertices) return 0;
  try {
    std::vector<uint32_t> result(count);
    meshopt_optimizeVertexCache(result.data(), indices, count, vertices);
    std::memcpy(indices, result.data(), size_t(count) * sizeof(uint32_t));
    return 1;
  } catch (...) { return 0; }
}
