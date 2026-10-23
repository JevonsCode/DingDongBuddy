// Adapted from selection-hook. See LICENSE and README.md in this directory.
#include "engine.h"
#include <algorithm>
#include <cassert>
#include <cmath>
namespace {
void RemoveObjectReplacementChars(std::wstring &text)
{
    if (text.empty())
        return;

    constexpr wchar_t objectReplacementChar = 0xFFFC;
    if (text.find(objectReplacementChar) == std::wstring::npos)
        return;

    std::wstring cleaned;
    cleaned.reserve(text.size());
    for (size_t i = 0; i < text.size(); i++)
    {
        if (text[i] != objectReplacementChar)
        {
            cleaned += text[i];
            continue;
        }

        // Drop one CRLF, LF, or CR immediately before the marker.
        if (!cleaned.empty() && cleaned.back() == L'\n')
        {
            cleaned.pop_back();
            if (!cleaned.empty() && cleaned.back() == L'\r')
                cleaned.pop_back();
        }
        else if (!cleaned.empty() && cleaned.back() == L'\r')
        {
            cleaned.pop_back();
        }

        // Skip one CRLF, LF, or CR immediately after the marker.
        if (i + 1 < text.size() && text[i + 1] == L'\r')
        {
            i++;
            if (i + 1 < text.size() && text[i + 1] == L'\n')
                i++;
        }
        else if (i + 1 < text.size() && text[i + 1] == L'\n')
        {
            i++;
        }
    }

    text.swap(cleaned);
}
}  // namespace

SelectionEngine::SelectionEngine(IUIAutomation* automation) : automation_(automation) {}
bool SelectionEngine::IsStopping() const {
    return cancelled_ && cancelled_->load(std::memory_order_acquire) != sequence_;
}
bool SelectionEngine::IsSafeElement(IUIAutomationElement* element) const {
    BOOL password = TRUE;
    int process = 0;
    return element && SUCCEEDED(element->get_CurrentIsPassword(&password)) && !password &&
        SUCCEEDED(element->get_CurrentProcessId(&process)) &&
        static_cast<DWORD>(process) == process_id_;
}
bool SelectionEngine::GetSelectedText(HWND hwnd, TextSelectionInfo& info,
    const std::atomic<uint64_t>& cancelled, uint64_t sequence) {
    cancelled_ = &cancelled;
    sequence_ = sequence;
    info = {};
    ::GetWindowThreadProcessId(hwnd, &process_id_);
    if (!hwnd || !::IsWindow(hwnd) || process_id_ == ::GetCurrentProcessId() ||
        ::GetForegroundWindow() != hwnd || IsStopping()) return false;
    const auto result = GetTextViaUIAutomation(hwnd, info);
    if (result == TextRetrievalResult::NonTextSelection || IsStopping()) return false;
    // A password/unknown UIA focus must never fall through to a legacy root object.
    // Legacy selection is available only through the validated focused UIA bridge.
    return result == TextRetrievalResult::TextFound && !info.text.empty();
}
TextRetrievalResult SelectionEngine::ClassifyAccessibleRole(IAccessible *accessible, const VARIANT &child)
{
    if (!accessible)
        return TextRetrievalResult::Unavailable;

    TextRetrievalResult result = TextRetrievalResult::Unavailable;
    VARIANT role;
    VariantInit(&role);
    const HRESULT hr = accessible->get_accRole(child, &role);
    if (hr == S_OK && role.vt == VT_I4)
    {
        // ROLE_SYSTEM_TEXT is not proof that text is available; it only permits later
        // fallback. Other concrete UI roles in this range represent object selection.
        if (role.lVal != ROLE_SYSTEM_TEXT && role.lVal >= ROLE_SYSTEM_TITLEBAR &&
            role.lVal <= ROLE_SYSTEM_OUTLINEBUTTON)
            result = TextRetrievalResult::NonTextSelection;
    }
    VariantClear(&role);
    return result;
}

/** Interpret the VARIANT forms returned by IAccessible::get_accSelection. */
TextRetrievalResult SelectionEngine::ProcessAccessibleSelection(IAccessible *accessible,
                                                                TextSelectionInfo &selectionInfo)
{
    if (!accessible)
        return TextRetrievalResult::Unavailable;

    VARIANT self;
    VariantInit(&self);
    self.vt = VT_I4;
    self.lVal = CHILDID_SELF;
    VARIANT state;
    VariantInit(&state);
    const HRESULT stateHr = accessible->get_accState(self, &state);
    const bool protectedControl = FAILED(stateHr) || state.vt != VT_I4 ||
        (state.lVal & STATE_SYSTEM_PROTECTED) != 0;
    VariantClear(&state);
    if (protectedControl) return TextRetrievalResult::NonTextSelection;
    TextRetrievalResult result = TextRetrievalResult::Unavailable;
    VARIANT selection;
    VariantInit(&selection);
    const HRESULT hr = accessible->get_accSelection(&selection);
    if (SUCCEEDED(hr))
    {
        if (selection.vt == VT_BSTR && selection.bstrVal)
        {
            // BSTRs are length-prefixed and may contain embedded NULs. SysStringLen
            // preserves the provider's complete result instead of truncating it.
            selectionInfo.text.assign(selection.bstrVal, std::min<UINT>(SysStringLen(selection.bstrVal), kMaximumTextLength));
            RemoveObjectReplacementChars(selectionInfo.text);
            if (!selectionInfo.text.empty())
                result = TextRetrievalResult::TextFound;
        }
        // Object/enumerated selections are deliberately classified separately so the
        // caller does not fall through to a simulated copy keystroke.
        else if (selection.vt == VT_UNKNOWN || (selection.vt & VT_ARRAY) != 0)
        {
            result = TextRetrievalResult::NonTextSelection;
        }
        else if (selection.vt == VT_I4)
        {
            result = ClassifyAccessibleRole(accessible, selection);
        }
        else if (selection.vt == VT_DISPATCH && selection.pdispVal)
        {
            IAccessible *selectedAccessible = nullptr;
            const HRESULT queryHr =
                selection.pdispVal->QueryInterface(IID_IAccessible, reinterpret_cast<void **>(&selectedAccessible));
            if (queryHr == S_OK && selectedAccessible)
            {
                VARIANT childSelf;
                VariantInit(&childSelf);
                childSelf.vt = VT_I4;
                childSelf.lVal = CHILDID_SELF;
                result = ClassifyAccessibleRole(selectedAccessible, childSelf);
                selectedAccessible->Release();
            }
        }
    }
    VariantClear(&selection);
    return result;
}

/**
 * Read selection through a UIA TextPattern.
 *
 * Only GetSelection is used, for the focused element and for ancestors alike. UIA has
 * no text attribute that marks a range as selected, so a DocumentRange probe can only
 * return the entire document. See issue #25.
 */
bool SelectionEngine::TryGetTextViaTextPattern(IUIAutomationElement *element, TextSelectionInfo &selectionInfo)
{
    if (!element || IsStopping())
        return false;

    if (!IsSafeElement(element))
        return false;
    bool result = false;
    IUIAutomationTextPattern *textPattern = nullptr;
    HRESULT hr = element->GetCurrentPatternAs(UIA_TextPatternId, __uuidof(IUIAutomationTextPattern),
                                              reinterpret_cast<void **>(&textPattern));
    if (SUCCEEDED(hr) && textPattern)
    {
        // First approach: ask the provider for its explicit selection ranges.
        IUIAutomationTextRangeArray *ranges = nullptr;
        hr = textPattern->GetSelection(&ranges);
        if (SUCCEEDED(hr) && ranges)
        {
            int count = 0;
            hr = ranges->get_Length(&count);
            if (SUCCEEDED(hr) && count > 0 && count <= 64)
            {
                // Providers may return multiple ranges; keep the first non-empty range
                // with usable screen coordinates, matching the historical behavior.
                for (int i = 0; i < count && !result && !IsStopping(); i++)
                {
                    IUIAutomationTextRange *range = nullptr;
                    hr = ranges->GetElement(i, &range);
                    if (SUCCEEDED(hr) && range)
                    {
                        BSTR text = nullptr;
                        hr = range->GetText(kMaximumTextLength, &text);
                        if (SUCCEEDED(hr) && text)
                        {
                            // UIA returns BSTR. Preserve its explicit length, including
                            // embedded NULs, instead of relying on null termination.
                            selectionInfo.text.assign(text, std::min<UINT>(SysStringLen(text), kMaximumTextLength));
                            RemoveObjectReplacementChars(selectionInfo.text);
                            if (!selectionInfo.text.empty())
                                result = SetTextRangeCoordinates(range, selectionInfo);
                            SysFreeString(text);
                        }
                        range->Release();
                    }
                }
            }
            ranges->Release();
        }

        // No DocumentRange fallback when GetSelection finds nothing (issue #25). The former
        // probe passed 30034 to GetAttributeValue, but 30034 is
        // UIA_IsScrollPatternAvailablePropertyId, an element property rather than a text
        // attribute, and UIA defines no text attribute that marks a range as selected.
        // Conforming providers therefore answered ReservedNotSupportedValue, and a provider
        // answering TRUE would have produced the whole document as the selection. Chromium
        // evaluates document-range attributes on its browser UI thread by walking the page,
        // which froze every browser window for ~30 s per call on complex pages, twice per
        // gesture that ends without a selection (scrollbar drag, double-click on blank space).
        textPattern->Release();
    }
    return result;
}

/** Retrieve selection through UI Automation and its legacy compatibility pattern. */
TextRetrievalResult SelectionEngine::GetTextViaUIAutomation(HWND hwnd, TextSelectionInfo &selectionInfo)
{
#ifdef _DEBUG
    assert(ownerThreadId_ == GetCurrentThreadId());
#endif
    if (!automation_ || !hwnd || IsStopping())
        return TextRetrievalResult::Unavailable;

    TextRetrievalResult result = TextRetrievalResult::Unavailable;
    TextRetrievalResult legacyResult = TextRetrievalResult::Unavailable;

    // Preserve the original ElementFromHandle probe before querying the focused element.
    // Some providers do not expose usable accessibility data for an invalid target HWND.
    IUIAutomationElement *windowElement = nullptr;
    HRESULT hr = automation_->ElementFromHandle(hwnd, &windowElement);
    if (FAILED(hr) || !windowElement)
        return TextRetrievalResult::Unavailable;

    // Selection is normally owned by the focused element, not necessarily by the HWND
    // passed to ElementFromHandle.
    IUIAutomationElement *focusedElement = nullptr;
    hr = automation_->GetFocusedElement(&focusedElement);
    windowElement->Release();
    if (FAILED(hr) || !focusedElement || IsStopping())
    {
        if (focusedElement)
            focusedElement->Release();
        return TextRetrievalResult::Unavailable;
    }


    if (!IsSafeElement(focusedElement)) {
        focusedElement->Release();
        return TextRetrievalResult::NonTextSelection;
    }

    // Approach 1: native UIA TextPattern on the focused element.
    if (TryGetTextViaTextPattern(focusedElement, selectionInfo))
        result = TextRetrievalResult::TextFound;

    // Approach 2: UIA's LegacyIAccessible bridge.
    if (result != TextRetrievalResult::TextFound && !IsStopping())
    {
        IUIAutomationLegacyIAccessiblePattern *legacyPattern = nullptr;
        hr = focusedElement->GetCurrentPatternAs(UIA_LegacyIAccessiblePatternId,
                                                 __uuidof(IUIAutomationLegacyIAccessiblePattern),
                                                 reinterpret_cast<void **>(&legacyPattern));
        if (SUCCEEDED(hr) && legacyPattern)
        {
            IAccessible *accessible = nullptr;
            hr = legacyPattern->GetIAccessible(&accessible);
            if (SUCCEEDED(hr) && accessible)
            {
                legacyResult = ProcessAccessibleSelection(accessible, selectionInfo);
                if (legacyResult == TextRetrievalResult::TextFound)
                    result = TextRetrievalResult::TextFound;
                accessible->Release();
            }
            legacyPattern->Release();
        }
    }

    // Approach 3: walk ancestors and retry TextPattern. In Chromium/Edge a tabindex
    // container can receive focus while an ancestor Document owns the selection.
    // See issue #18 and PR #14.
    if (result != TextRetrievalResult::TextFound && !IsStopping())
    {
        IUIAutomationTreeWalker *treeWalker = nullptr;
        hr = automation_->get_ControlViewWalker(&treeWalker);
        if (SUCCEEDED(hr) && treeWalker)
        {
            // The Document element is normally only a few levels above the focus owner.
            constexpr int maxWalkUpLevels = 10;
            IUIAutomationElement *current = focusedElement;
            current->AddRef();
            for (int level = 0; level < maxWalkUpLevels && result != TextRetrievalResult::TextFound && !IsStopping();
                 level++)
            {
                IUIAutomationElement *parent = nullptr;
                hr = treeWalker->GetParentElement(current, &parent);
                current->Release();
                current = nullptr;
                if (FAILED(hr) || !parent)
                    break;
                current = parent;
                if (!IsSafeElement(current)) break;
                // Ancestors are read through GetSelection only, like the focused element.
                if (TryGetTextViaTextPattern(current, selectionInfo))
                    result = TextRetrievalResult::TextFound;
            }
            if (current)
                current->Release();
            treeWalker->Release();
        }
    }

    if (result != TextRetrievalResult::TextFound && legacyResult == TextRetrievalResult::NonTextSelection)
        result = TextRetrievalResult::NonTextSelection;
    focusedElement->Release();
    return result;
}

/** Extract first/last usable UIA bounding rectangles in physical screen coordinates. */
bool SelectionEngine::SetTextRangeCoordinates(IUIAutomationTextRange *range, TextSelectionInfo &selectionInfo)
{
    if (!range || IsStopping())
        return false;

    SAFEARRAY *rectArray = nullptr;
    const HRESULT hr = range->GetBoundingRectangles(&rectArray);
    if (FAILED(hr) || !rectArray)
        return false;

    if (SafeArrayGetDim(rectArray) != 1 || SafeArrayGetElemsize(rectArray) != sizeof(double))
    {
        SafeArrayDestroy(rectArray);
        return false;
    }

    // Access the SAFEARRAY directly; it stores repeating left/top/width/height values.
    double *rects = nullptr;
    const HRESULT accessHr = SafeArrayAccessData(rectArray, reinterpret_cast<void **>(&rects));
    if (FAILED(accessHr) || !rects)
    {
        SafeArrayDestroy(rectArray);
        return false;
    }

    LONG lowerBound = 0;
    LONG upperBound = -1;
    const HRESULT lowerHr = SafeArrayGetLBound(rectArray, 1, &lowerBound);
    const HRESULT upperHr = SafeArrayGetUBound(rectArray, 1, &upperBound);
    const int64_t elementCount = static_cast<int64_t>(upperBound) - lowerBound + 1;
    if (FAILED(lowerHr) || FAILED(upperHr) || elementCount <= 0 ||
        elementCount > 65536 || elementCount % 4 != 0)
    {
        SafeArrayUnaccessData(rectArray);
        SafeArrayDestroy(rectArray);
        return false;
    }
    const int rectCount = static_cast<int>(elementCount / 4);
    int firstValid = -1;
    int lastValid = -1;
    // Ignore near-zero-width artifacts and implausibly tall provider rectangles. These
    // thresholds are historical compatibility behavior, not general layout validation.
    for (int i = 0; i < rectCount; i++)
    {
        const int index = i * 4;
        if (std::isfinite(rects[index]) && std::isfinite(rects[index + 1]) &&
            std::abs(rects[index]) < 1000000.0 && std::abs(rects[index + 1]) < 1000000.0 &&
            rects[index + 2] > 1.0 && rects[index + 2] < 100000.0 &&
            rects[index + 3] > 0.0 && rects[index + 3] < 10000.0)
        {
            firstValid = index;
            break;
        }
    }
    for (int i = rectCount - 1; i >= 0; i--)
    {
        const int index = i * 4;
        if (std::isfinite(rects[index]) && std::isfinite(rects[index + 1]) &&
            std::abs(rects[index]) < 1000000.0 && std::abs(rects[index + 1]) < 1000000.0 &&
            rects[index + 2] > 1.0 && rects[index + 2] < 100000.0 &&
            rects[index + 3] > 0.0 && rects[index + 3] < 10000.0)
        {
            lastValid = index;
            break;
        }
    }

    bool found = false;
    // The first valid rectangle supplies the left edge of the first line; the last
    // supplies the right edge of the last line.
    if (firstValid >= 0 && lastValid >= 0)
    {
        selectionInfo.startTop.x = static_cast<LONG>(rects[firstValid]);
        selectionInfo.startTop.y = static_cast<LONG>(rects[firstValid + 1]);
        selectionInfo.startBottom.x = static_cast<LONG>(rects[firstValid]);
        selectionInfo.startBottom.y = static_cast<LONG>(rects[firstValid + 1] + rects[firstValid + 3]);
        selectionInfo.endBottom.x = static_cast<LONG>(rects[lastValid] + rects[lastValid + 2]);
        selectionInfo.endBottom.y = static_cast<LONG>(rects[lastValid + 1] + rects[lastValid + 3]);
        selectionInfo.endTop.x = static_cast<LONG>(rects[lastValid] + rects[lastValid + 2]);
        selectionInfo.endTop.y = static_cast<LONG>(rects[lastValid + 1]);
        selectionInfo.posLevel = SelectionPositionLevel::Full;
        found = true;
    }
    // Always unlock before destroying the SAFEARRAY, including the no-valid-rect case.
    SafeArrayUnaccessData(rectArray);
    SafeArrayDestroy(rectArray);
    return found;
}
