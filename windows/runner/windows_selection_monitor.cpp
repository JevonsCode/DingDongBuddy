#include "windows_selection_monitor.h"
#include "../../third_party/selection-hook/engine.h"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cmath>
#include <mutex>
#include <optional>
#include <string>

namespace {
using Value = flutter::EncodableValue;
using Map = flutter::EncodableMap;

std::string ToUtf8(const std::wstring& text) {
  if (text.empty()) return {};
  const int length = static_cast<int>(text.size());
  const int count = ::WideCharToMultiByte(CP_UTF8, 0, text.data(), length,
      nullptr, 0, nullptr, nullptr);
  if (count <= 0) return {};
  std::string result(static_cast<size_t>(count), '\0');
  ::WideCharToMultiByte(CP_UTF8, 0, text.data(), length,
      result.data(), count, nullptr, nullptr);
  return result;
}
}  // namespace

struct WindowsSelectionMonitor::State {
  struct Request {
    HWND foreground = nullptr;
    POINT point{};
    uint64_t sequence = 0;
    std::chrono::steady_clock::time_point created;
  };
  struct Result {
    Request request;
    TextSelectionInfo selection;
    bool found = false;
  };
  std::mutex mutex;
  std::condition_variable changed;
  std::atomic<uint64_t> sequence{0};
  std::optional<Request> pending;
  std::optional<Result> result;
  HWND destination = nullptr;  // Read/write only under mutex.
  bool stop = false;
  bool initialized = false;
  bool healthy = false;
  bool finished = false;
};

WindowsSelectionMonitor* WindowsSelectionMonitor::active_ = nullptr;

WindowsSelectionMonitor::WindowsSelectionMonitor(
    HWND window, flutter::BinaryMessenger* messenger)
    : window_(window), state_(std::make_shared<State>()) {
  state_->destination = window;
  worker_ = std::thread(&WindowsSelectionMonitor::WorkerMain, state_);
  channel_ = std::make_unique<flutter::MethodChannel<Value>>(
      messenger, "dingdong/windows_selection",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const flutter::MethodCall<Value>& call,
      std::unique_ptr<flutter::MethodResult<Value>> result) {
    if (call.method_name() == "configure") {
      const auto* arguments = call.arguments()
          ? std::get_if<Map>(call.arguments()) : nullptr;
      const auto it = arguments ? arguments->find(Value("enabled")) : Map::const_iterator{};
      const auto* enabled = arguments && it != arguments->end()
          ? std::get_if<bool>(&it->second) : nullptr;
      if (!enabled) {
        result->Error("invalid_arguments", "enabled must be a boolean");
        return;
      }
      Configure(*enabled);
    } else if (call.method_name() != "status") {
      result->NotImplemented();
      return;
    }
    result->Success(Value(Map{{Value("running"), Value(IsRunning())}}));
  });
}

WindowsSelectionMonitor::~WindowsSelectionMonitor() {
  Configure(false);
  channel_->SetMethodCallHandler(nullptr);
  {
    std::lock_guard<std::mutex> lock(state_->mutex);
    state_->stop = true;
    state_->destination = nullptr;
  }
  state_->changed.notify_all();
  // A hostile/hung accessibility provider cannot freeze application shutdown.
  // The detached worker retains only shared State, never this/window/channel/COM
  // from another apartment. This is an EXE, so its code cannot be unloaded.
  std::unique_lock<std::mutex> lock(state_->mutex);
  const bool finished = state_->changed.wait_for(lock,
      std::chrono::milliseconds(100), [this] { return state_->finished; });
  lock.unlock();
  if (finished) worker_.join();
  else worker_.detach();
}

bool WindowsSelectionMonitor::IsOwnWindow(HWND window) {
  DWORD process = 0;
  if (window) ::GetWindowThreadProcessId(window, &process);
  return process == ::GetCurrentProcessId();
}

bool WindowsSelectionMonitor::IsRunning() const {
  std::lock_guard<std::mutex> lock(state_->mutex);
  return enabled_ && mouse_hook_ && keyboard_hook_ && state_->healthy;
}

bool WindowsSelectionMonitor::Configure(bool enabled) {
  if (!enabled) {
    enabled_ = false;
    if (mouse_hook_) ::UnhookWindowsHookEx(mouse_hook_);
    if (keyboard_hook_) ::UnhookWindowsHookEx(keyboard_hook_);
    mouse_hook_ = keyboard_hook_ = nullptr;
    if (active_ == this) active_ = nullptr;
    Invalidate(true);
    mouse_down_ = shift_selection_ = false;
    last_click_time_ = 0;
    return false;
  }
  if (enabled_) return IsRunning();
  {
    // Initialization is normally finished by the time Dart configures the service.
    // Never wait for a provider/retrieval on the window thread.
    std::unique_lock<std::mutex> lock(state_->mutex);
    state_->changed.wait_for(lock, std::chrono::milliseconds(100),
        [this] { return state_->initialized; });
    if (!state_->healthy) return false;
  }
  if (active_ && active_ != this) return false;
  active_ = this;
  mouse_hook_ = ::SetWindowsHookExW(WH_MOUSE_LL, MouseHook,
      ::GetModuleHandleW(nullptr), 0);
  keyboard_hook_ = ::SetWindowsHookExW(WH_KEYBOARD_LL, KeyboardHook,
      ::GetModuleHandleW(nullptr), 0);
  if (!mouse_hook_ || !keyboard_hook_) {
    Configure(false);
    return false;
  }
  enabled_ = true;
  return true;
}

void WindowsSelectionMonitor::Invalidate(bool dismiss) {
  state_->sequence.fetch_add(1, std::memory_order_acq_rel);
  {
    std::lock_guard<std::mutex> lock(state_->mutex);
    state_->pending.reset();
    state_->result.reset();
  }
  if (dismiss && channel_) channel_->InvokeMethod("dismiss", nullptr);
}

void WindowsSelectionMonitor::Request(POINT point, HWND foreground) {
  if (!enabled_ || !foreground || IsOwnWindow(foreground) ||
      foreground != ::GetForegroundWindow()) return;
  const auto sequence = state_->sequence.fetch_add(1,
      std::memory_order_acq_rel) + 1;
  {
    std::lock_guard<std::mutex> lock(state_->mutex);
    state_->pending = State::Request{foreground, point, sequence,
        std::chrono::steady_clock::now()};
  }
  state_->changed.notify_all();
}

LRESULT CALLBACK WindowsSelectionMonitor::MouseHook(
    int code, WPARAM message, LPARAM data) {
  if (code == HC_ACTION && active_ && active_->enabled_) {
    const auto& event = *reinterpret_cast<const MSLLHOOKSTRUCT*>(data);
    if ((event.flags & LLMHF_INJECTED) == 0) active_->OnMouse(message, event);
  }
  return ::CallNextHookEx(nullptr, code, message, data);
}

LRESULT CALLBACK WindowsSelectionMonitor::KeyboardHook(
    int code, WPARAM message, LPARAM data) {
  if (code == HC_ACTION && active_ && active_->enabled_) {
    const auto& event = *reinterpret_cast<const KBDLLHOOKSTRUCT*>(data);
    if ((event.flags & LLKHF_INJECTED) == 0) active_->OnKeyboard(message, event);
  }
  return ::CallNextHookEx(nullptr, code, message, data);
}

void WindowsSelectionMonitor::OnMouse(WPARAM message, const MSLLHOOKSTRUCT& event) {
  if (message == WM_LBUTTONDOWN || message == WM_RBUTTONDOWN ||
      message == WM_MBUTTONDOWN || message == WM_MOUSEWHEEL) {
    const bool own = IsOwnWindow(::WindowFromPoint(event.pt));
    Invalidate(!own);
    mouse_down_ = message == WM_LBUTTONDOWN && !own;
    down_point_ = event.pt;
    // Low-level hooks run before activation. Capture the clicked root so the
    // first drag into a previously inactive application can still be retrieved.
    down_foreground_ = ::GetAncestor(::WindowFromPoint(event.pt), GA_ROOT);
    return;
  }
  if (message != WM_LBUTTONUP || !mouse_down_) return;
  mouse_down_ = false;
  const bool drag = std::abs(event.pt.x - down_point_.x) >= ::GetSystemMetrics(SM_CXDRAG) ||
      std::abs(event.pt.y - down_point_.y) >= ::GetSystemMetrics(SM_CYDRAG);
  const bool twice = last_click_time_ != 0 &&
      event.time - last_click_time_ <= ::GetDoubleClickTime() &&
      std::abs(event.pt.x - last_click_point_.x) <= ::GetSystemMetrics(SM_CXDOUBLECLK) &&
      std::abs(event.pt.y - last_click_point_.y) <= ::GetSystemMetrics(SM_CYDOUBLECLK);
  last_click_time_ = drag ? 0 : event.time;
  last_click_point_ = event.pt;
  if (drag || twice || (::GetAsyncKeyState(VK_SHIFT) & 0x8000) != 0)
    Request(event.pt, down_foreground_);
}

void WindowsSelectionMonitor::OnKeyboard(WPARAM message, const KBDLLHOOKSTRUCT& event) {
  const bool down = message == WM_KEYDOWN || message == WM_SYSKEYDOWN;
  if (event.vkCode == VK_ESCAPE && down) {
    Invalidate(true);
    return;
  }
  if (IsOwnWindow(::GetForegroundWindow())) {
    shift_selection_ = false;
    return;
  }
  const bool shift = event.vkCode == VK_LSHIFT || event.vkCode == VK_RSHIFT || event.vkCode == VK_SHIFT;
  const bool navigation = event.vkCode == VK_LEFT || event.vkCode == VK_RIGHT ||
      event.vkCode == VK_UP || event.vkCode == VK_DOWN || event.vkCode == VK_HOME ||
      event.vkCode == VK_END || event.vkCode == VK_PRIOR || event.vkCode == VK_NEXT;
  if (down) {
    Invalidate(true);
    if (navigation && (::GetAsyncKeyState(VK_SHIFT) & 0x8000) != 0)
      shift_selection_ = true;
  } else if (shift && shift_selection_) {
    shift_selection_ = false;
    POINT point{};
    ::GetCursorPos(&point);
    Request(point, ::GetForegroundWindow());
  }
}

void WindowsSelectionMonitor::WorkerMain(const std::shared_ptr<State>& state) {
  const HRESULT initialized = ::CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  IUIAutomation* automation = nullptr;
  if (SUCCEEDED(initialized))
    ::CoCreateInstance(CLSID_CUIAutomation, nullptr, CLSCTX_INPROC_SERVER,
        IID_PPV_ARGS(&automation));
  {
    std::lock_guard<std::mutex> lock(state->mutex);
    state->healthy = automation != nullptr;
    state->initialized = true;
  }
  state->changed.notify_all();
  if (automation) {
    SelectionEngine engine(automation);
    for (;;) {
      State::Request request;
      {
        std::unique_lock<std::mutex> lock(state->mutex);
        state->changed.wait(lock, [&state] { return state->stop || state->pending.has_value(); });
        if (state->stop) break;
        request = *state->pending;
        state->pending.reset();
        // Hooks precede the target's mouse/key dispatch. Let its selection settle.
        state->changed.wait_for(lock, std::chrono::milliseconds(70), [&state, &request] {
          return state->stop || state->sequence.load() != request.sequence;
        });
        if (state->stop) break;
      }
      if (state->sequence.load() != request.sequence) continue;
      State::Result result;
      result.request = request;
      result.found = engine.GetSelectedText(request.foreground, result.selection,
          state->sequence, request.sequence);
      std::lock_guard<std::mutex> lock(state->mutex);
      if (state->stop) break;
      if (state->sequence.load() != request.sequence ||
          ::GetForegroundWindow() != request.foreground ||
          std::chrono::steady_clock::now() - request.created > std::chrono::seconds(2)) continue;
      state->result = std::move(result);
      if (state->destination) ::PostMessageW(state->destination, kResultMessage, 0, 0);
    }
    automation->Release();
  }
  if (SUCCEEDED(initialized)) ::CoUninitialize();
  {
    std::lock_guard<std::mutex> lock(state->mutex);
    state->healthy = false;
    state->finished = true;
  }
  state->changed.notify_all();
}

bool WindowsSelectionMonitor::HandleMessage(UINT message) {
  if (message != kResultMessage) return false;
  std::optional<State::Result> result;
  {
    std::lock_guard<std::mutex> lock(state_->mutex);
    result.swap(state_->result);
  }
  if (!enabled_ || !result || result->request.sequence != state_->sequence.load() ||
      ::GetForegroundWindow() != result->request.foreground ||
      std::chrono::steady_clock::now() - result->request.created > std::chrono::seconds(2)) return true;
  if (!result->found) {
    channel_->InvokeMethod("dismiss", nullptr);
    return true;
  }
  const auto& info = result->selection;
  const double dpi = static_cast<double>(::GetDpiForWindow(window_));
  const double scale = dpi > 0 ? dpi / 96.0 : 1.0;
  RECT rect{result->request.point.x, result->request.point.y,
      result->request.point.x + 1, result->request.point.y + 1};
  if (info.posLevel == SelectionPositionLevel::Full) {
    rect.left = std::min(info.startTop.x, info.endTop.x);
    rect.top = std::min(info.startTop.y, info.endTop.y);
    rect.right = std::max(info.startBottom.x, info.endBottom.x);
    rect.bottom = std::max(info.startBottom.y, info.endBottom.y);
  }
  MONITORINFO monitor{};
  monitor.cbSize = sizeof(monitor);
  ::GetMonitorInfoW(::MonitorFromRect(&rect, MONITOR_DEFAULTTONEAREST), &monitor);
  channel_->InvokeMethod("selected", std::make_unique<Value>(Map{
      {Value("text"), Value(ToUtf8(info.text))},
      {Value("x"), Value(rect.left / scale)}, {Value("y"), Value(rect.top / scale)},
      {Value("width"), Value((rect.right - rect.left) / scale)},
      {Value("height"), Value((rect.bottom - rect.top) / scale)},
      {Value("coordinateScale"), Value(scale)},
      {Value("workAreaX"), Value(monitor.rcWork.left / scale)},
      {Value("workAreaY"), Value(monitor.rcWork.top / scale)},
      {Value("workAreaWidth"), Value((monitor.rcWork.right - monitor.rcWork.left) / scale)},
      {Value("workAreaHeight"), Value((monitor.rcWork.bottom - monitor.rcWork.top) / scale)}}));
  return true;
}
