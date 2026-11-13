#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

void FlutterWindow::SetFullScreen(bool full_screen) {
  HWND hwnd = GetHandle();
  if (!hwnd) return;
  if (is_full_screen_ == full_screen) return;

  if (full_screen) {
    prev_placement_.length = sizeof(prev_placement_);
    GetWindowPlacement(hwnd, &prev_placement_);

    HMONITOR hmon = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
    MONITORINFO mi = { sizeof(mi) };
    if (GetMonitorInfo(hmon, &mi)) {
      SetWindowLong(hwnd, GWL_STYLE,
                    GetWindowLong(hwnd, GWL_STYLE) & ~WS_OVERLAPPEDWINDOW);
      SetWindowPos(hwnd, HWND_TOP,
                   mi.rcMonitor.left, mi.rcMonitor.top,
                   mi.rcMonitor.right - mi.rcMonitor.left,
                   mi.rcMonitor.bottom - mi.rcMonitor.top,
                   SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
      is_full_screen_ = true;
    }
  } else {
    SetWindowLong(hwnd, GWL_STYLE,
                  GetWindowLong(hwnd, GWL_STYLE) | WS_OVERLAPPEDWINDOW);
    SetWindowPlacement(hwnd, &prev_placement_);
    SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                 SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
    is_full_screen_ = false;
  }
}

void FlutterWindow::ToggleFullScreen() {
  SetFullScreen(!is_full_screen_);
}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Registrar MethodChannel nativo para control de ventana y pantalla completa
  window_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "com.cajaya.pos/window",
      &flutter::StandardMethodCodec::GetInstance());

  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "toggleFullScreen") {
          ToggleFullScreen();
          result->Success(flutter::EncodableValue(is_full_screen_));
        } else if (call.method_name() == "setFullScreen") {
          const auto* args = std::get_if<bool>(call.arguments());
          if (args) {
            SetFullScreen(*args);
            result->Success(flutter::EncodableValue(is_full_screen_));
          } else {
            result->Error("BAD_ARGS", "Expected boolean argument");
          }
        } else if (call.method_name() == "isFullScreen") {
          result->Success(flutter::EncodableValue(is_full_screen_));
        } else {
          result->NotImplemented();
        }
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (window_channel_) {
    window_channel_ = nullptr;
  }
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Manejo nativo de F11 en caso de que la ventana Win32 reciba el mensaje directamente
  if (message == WM_KEYDOWN && wparam == VK_F11) {
    ToggleFullScreen();
    if (window_channel_) {
      window_channel_->InvokeMethod("onFullScreenChanged",
                                    std::make_unique<flutter::EncodableValue>(is_full_screen_));
    }
    return 0;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
