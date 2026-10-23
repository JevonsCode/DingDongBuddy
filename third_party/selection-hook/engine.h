// Adapted from selection-hook (MIT); see README.md.
#pragma once
#include <windows.h>
#include <ole2.h>
#include <UIAutomation.h>
#include <oleacc.h>
#include <atomic>
#include <cstdint>
#include <string>

enum class TextRetrievalResult { TextFound, Unavailable, NonTextSelection };
enum class SelectionPositionLevel { None, Full };
struct TextSelectionInfo {
  std::wstring text;
  POINT startTop{}, startBottom{}, endTop{}, endBottom{};
  SelectionPositionLevel posLevel = SelectionPositionLevel::None;
};
class SelectionEngine {
 public:
  static constexpr int kMaximumTextLength = 16384;
  explicit SelectionEngine(IUIAutomation* automation);
  bool GetSelectedText(HWND hwnd, TextSelectionInfo& info,
      const std::atomic<uint64_t>& cancelled, uint64_t sequence);
 private:
  bool IsStopping() const;
  bool IsSafeElement(IUIAutomationElement* element) const;
  TextRetrievalResult GetTextViaUIAutomation(HWND hwnd, TextSelectionInfo& info);
  bool TryGetTextViaTextPattern(IUIAutomationElement* element, TextSelectionInfo& info);
  TextRetrievalResult ProcessAccessibleSelection(IAccessible* accessible, TextSelectionInfo& info);
  TextRetrievalResult ClassifyAccessibleRole(IAccessible* accessible, const VARIANT& child);
  bool SetTextRangeCoordinates(IUIAutomationTextRange* range, TextSelectionInfo& info);
  IUIAutomation* automation_;
  const std::atomic<uint64_t>* cancelled_ = nullptr;
  uint64_t sequence_ = 0;
  DWORD process_id_ = 0;
#ifdef _DEBUG
  DWORD ownerThreadId_ = ::GetCurrentThreadId();
#endif
};
