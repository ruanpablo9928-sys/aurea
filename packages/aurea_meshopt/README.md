# meshoptimizer integration

Upstream: https://github.com/zeux/meshoptimizer/tree/v1.1
Version: v1.1. License: MIT (LICENSE). Upstream source files are unmodified.
The wrapper exports one checked C ABI operation. Dart build hooks compile it
for the target platform, including Android and iOS. Vertex-cache optimization
runs in a worker isolate, once for a new static opaque GPU primitive; it does
not simplify geometry, change winding, or reorder transparent triangles.
