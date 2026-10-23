#include "../../third_party/selection-hook/engine.h"
#include <cassert>
#include <iostream>
#include <string>

namespace {
constexpr wchar_t kFixtureClass[] = L"DingDongSelectionFixture";
constexpr wchar_t kFixtureText[] = L"alpha selected text omega";
LRESULT CALLBACK FixtureProc(HWND window, UINT message, WPARAM wparam, LPARAM lparam) {
  if (message == WM_DESTROY) { ::PostQuitMessage(0); return 0; }
  return ::DefWindowProcW(window, message, wparam, lparam);
}
int Fixture() {
  WNDCLASSW type{};
  type.lpfnWndProc = FixtureProc;
  type.hInstance = ::GetModuleHandleW(nullptr);
  type.lpszClassName = kFixtureClass;
  ::RegisterClassW(&type);
  HWND window = ::CreateWindowW(kFixtureClass, kFixtureClass, WS_OVERLAPPEDWINDOW,
      40, 40, 500, 180, nullptr, nullptr, type.hInstance, nullptr);
  HWND edit = ::CreateWindowW(L"EDIT", kFixtureText,
      WS_CHILD | WS_VISIBLE | WS_TABSTOP | ES_AUTOHSCROLL,
      10, 10, 440, 90, window, reinterpret_cast<HMENU>(100), type.hInstance, nullptr);
  ::ShowWindow(window, SW_SHOW);
  ::SetForegroundWindow(window);
  ::SetFocus(edit);
  ::SendMessageW(edit, EM_SETSEL, 6, 19);
  MSG message{};
  while (::GetMessageW(&message, nullptr, 0, 0) > 0) {
    ::TranslateMessage(&message);
    ::DispatchMessageW(&message);
  }
  return 0;
}
}

int wmain(int argc, wchar_t** argv) {
  if (argc == 2 && std::wstring(argv[1]) == L"--fixture") return Fixture();
  if (FAILED(::CoInitializeEx(nullptr, COINIT_MULTITHREADED))) return 1;
  IUIAutomation* automation = nullptr;
  if (FAILED(::CoCreateInstance(CLSID_CUIAutomation, nullptr, CLSCTX_INPROC_SERVER,
      IID_PPV_ARGS(&automation)))) return 2;
  SelectionEngine engine(automation);
  std::atomic<uint64_t> sequence{1};
  TextSelectionInfo info;
  assert(!engine.GetSelectedText(nullptr, info, sequence, 1));
  assert(info.text.empty());

  wchar_t executable[MAX_PATH]{};
  ::GetModuleFileNameW(nullptr, executable, MAX_PATH);
  std::wstring command = L"\"" + std::wstring(executable) + L"\" --fixture";
  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  PROCESS_INFORMATION process{};
  assert(::CreateProcessW(nullptr, command.data(), nullptr, nullptr, FALSE,
      0, nullptr, nullptr, &startup, &process));
  ::AllowSetForegroundWindow(process.dwProcessId);
  HWND window = nullptr;
  for (int attempt = 0; attempt < 100 && !window; ++attempt) {
    ::Sleep(30);
    window = ::FindWindowW(kFixtureClass, kFixtureClass);
  }
  assert(window);
  ::SetForegroundWindow(window);
  ::Sleep(120);
  if (::GetForegroundWindow() != window) {
    // Windows background sessions cannot grant themselves foreground permission.
    // The guard itself must still be verified instead of reading another app.
    assert(!engine.GetSelectedText(window, info, sequence, 1));
    assert(info.text.empty());
    sequence.store(2);
    assert(!engine.GetSelectedText(window, info, sequence, 1));
    ::PostMessageW(window, WM_CLOSE, 0, 0);
    ::WaitForSingleObject(process.hProcess, 2000);
    ::CloseHandle(process.hProcess);
    ::CloseHandle(process.hThread);
    automation->Release();
    ::CoUninitialize();
    std::cout << "PASS: null/stale-foreground/cancelled rejection. SKIP: live UIA fixture (Windows foreground permission denied).\n";
    return 0;
  }
  const DWORD before = ::GetClipboardSequenceNumber();
  const bool found = engine.GetSelectedText(window, info, sequence, 1);
  if (!found || info.text != L"selected text") {
    std::cerr << "UIA fixture selection unavailable or incorrect\n";
    IUIAutomationElement* focused = nullptr;
    automation->GetFocusedElement(&focused);
    if (focused) {
      int pid = 0;
      BOOL password = TRUE;
      CONTROLTYPEID type = 0;
      focused->get_CurrentProcessId(&pid);
      focused->get_CurrentIsPassword(&password);
      focused->get_CurrentControlType(&type);
      std::cerr << "pid=" << pid << " expected=" << process.dwProcessId
          << " password=" << password << " type=" << type
          << " foreground=" << (::GetForegroundWindow() == window) << '\n';
      focused->Release();
    }
    std::wcerr << L"text=" << info.text << L'\n';
    ::PostMessageW(window, WM_CLOSE, 0, 0);
    return 3;
  }
  assert(info.posLevel == SelectionPositionLevel::Full);
  assert(info.endBottom.y > info.startTop.y);
  assert(::GetClipboardSequenceNumber() == before);

  // Cancelled work must not return a previously populated selection.
  sequence.store(2);
  assert(!engine.GetSelectedText(window, info, sequence, 1));
  assert(info.text.empty());
  HWND edit = ::GetDlgItem(window, 100);
  ::SendMessageW(edit, EM_SETPASSWORDCHAR, L'*', 0);
  ::Sleep(40);
  assert(!engine.GetSelectedText(window, info, sequence, 2));
  assert(info.text.empty());
  ::SendMessageW(edit, EM_SETPASSWORDCHAR, 0, 0);
  ::SendMessageW(edit, EM_SETSEL, 0, 0);
  ::Sleep(40);
  assert(!engine.GetSelectedText(window, info, sequence, 2));
  assert(::GetClipboardSequenceNumber() == before);
  ::PostMessageW(window, WM_CLOSE, 0, 0);
  ::WaitForSingleObject(process.hProcess, 2000);
  ::CloseHandle(process.hProcess);
  ::CloseHandle(process.hThread);
  automation->Release();
  ::CoUninitialize();
  std::cout << "PASS: real UIA selection, coordinates, password rejection, empty selection, cancellation, clipboard unchanged\n";
  return 0;
}
