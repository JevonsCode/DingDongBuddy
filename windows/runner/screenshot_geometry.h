#ifndef RUNNER_SCREENSHOT_GEOMETRY_H_
#define RUNNER_SCREENSHOT_GEOMETRY_H_

#include <algorithm>

namespace screenshot {
struct Point { int x; int y; };
struct Rect {
  int left; int top; int right; int bottom;
  int width() const { return right - left; }
  int height() const { return bottom - top; }
  bool usable() const { return width() >= 2 && height() >= 2; }
};
inline Rect Region(Point a, Point b, int width, int height) {
  return {std::clamp(std::min(a.x, b.x), 0, width),
          std::clamp(std::min(a.y, b.y), 0, height),
          std::clamp(std::max(a.x, b.x), 0, width),
          std::clamp(std::max(a.y, b.y), 0, height)};
}
inline Point Clip(Point p, const Rect& r) {
  return {std::clamp(p.x, r.left, r.right),
          std::clamp(p.y, r.top, r.bottom)};
}
}  // namespace screenshot
#endif
