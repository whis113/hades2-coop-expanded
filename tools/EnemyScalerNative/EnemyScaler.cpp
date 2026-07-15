#include <windows.h>
#include <commdlg.h>
#include <tlhelp32.h>

#include <algorithm>
#include <filesystem>
#include <fstream>
#include <regex>
#include <sstream>
#include <string>

namespace {
constexpr int PathEditId = 1001;
constexpr int MultiplierEditId = 1002;
constexpr int EnabledCheckId = 1003;
constexpr int BrowseButtonId = 1004;
constexpr int LoadButtonId = 1005;
constexpr int ApplyButtonId = 1006;
constexpr int StatusLabelId = 1007;

HWND pathEdit = nullptr;
HWND multiplierEdit = nullptr;
HWND enabledCheck = nullptr;
HWND statusLabel = nullptr;

void SetStatus(const std::wstring& message, COLORREF color) {
    SetWindowTextW(statusLabel, message.c_str());
    SendMessageW(statusLabel, WM_SETFONT, reinterpret_cast<WPARAM>(GetStockObject(DEFAULT_GUI_FONT)), TRUE);
    SetWindowLongPtrW(statusLabel, GWLP_USERDATA, static_cast<LONG_PTR>(color));
    InvalidateRect(statusLabel, nullptr, TRUE);
}

std::wstring GetControlText(HWND control) {
    const auto length = GetWindowTextLengthW(control);
    std::wstring value(length + 1, L'\0');
    GetWindowTextW(control, value.data(), length + 1);
    value.resize(length);
    return value;
}

bool IsGameRunning() {
    const HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snapshot == INVALID_HANDLE_VALUE) {
        return false;
    }

    PROCESSENTRY32W process{};
    process.dwSize = sizeof(process);
    bool running = false;
    if (Process32FirstW(snapshot, &process)) {
        do {
            if (_wcsicmp(process.szExeFile, L"Hades2.exe") == 0) {
                running = true;
                break;
            }
        } while (Process32NextW(snapshot, &process));
    }
    CloseHandle(snapshot);
    return running;
}

bool TryGetConfigPath(std::filesystem::path& configPath, std::wstring& error) {
    const std::filesystem::path executablePath(GetControlText(pathEdit));
    if (!std::filesystem::is_regular_file(executablePath) || _wcsicmp(executablePath.filename().c_str(), L"Hades2.exe") != 0) {
        error = L"Select Hades II's Ship\\Hades2.exe.";
        return false;
    }

    const auto shipDirectory = executablePath.parent_path();
    const auto gameDirectory = shipDirectory.parent_path();
    configPath = gameDirectory / L"Content" / L"Mods" / L"TN_CoopMod" / L"config.lua";
    if (!std::filesystem::is_regular_file(configPath)) {
        error = L"TN_CoopMod is not installed or config.lua is missing. Install the co-op mod first.";
        return false;
    }
    return true;
}

bool ReadFile(const std::filesystem::path& path, std::string& contents) {
    std::ifstream input(path, std::ios::binary);
    if (!input) {
        return false;
    }
    std::ostringstream buffer;
    buffer << input.rdbuf();
    contents = buffer.str();
    return true;
}

bool WriteFile(const std::filesystem::path& path, const std::string& contents) {
    std::ofstream output(path, std::ios::binary | std::ios::trunc);
    if (!output) {
        return false;
    }
    output.write(contents.data(), static_cast<std::streamsize>(contents.size()));
    return output.good();
}

bool FindEnemyScalingBlock(const std::string& config, size_t& blockStart, size_t& blockLength) {
    const auto section = config.find("EnemyScaling");
    if (section == std::string::npos) {
        return false;
    }
    const auto openBrace = config.find('{', section);
    const auto closeBrace = config.find('}', openBrace);
    if (openBrace == std::string::npos || closeBrace == std::string::npos) {
        return false;
    }
    blockStart = openBrace;
    blockLength = closeBrace - openBrace + 1;
    return true;
}

bool ReadBoolean(const std::string& config, bool& enabled) {
    size_t start = 0;
    size_t length = 0;
    if (!FindEnemyScalingBlock(config, start, length)) {
        return false;
    }
    const std::string block = config.substr(start, length);
    const std::regex pattern(R"(Enabled\s*=\s*(true|false))");
    std::smatch match;
    if (!std::regex_search(block, match, pattern)) {
        return false;
    }
    enabled = match[1] == "true";
    return true;
}

bool ReadMultiplier(const std::string& config, double& multiplier) {
    size_t start = 0;
    size_t length = 0;
    if (!FindEnemyScalingBlock(config, start, length)) {
        return false;
    }
    const std::string block = config.substr(start, length);
    const std::regex pattern(R"(HealthMultiplier\s*=\s*([0-9]+(?:\.[0-9]+)?))");
    std::smatch match;
    if (!std::regex_search(block, match, pattern)) {
        return false;
    }
    multiplier = std::clamp(std::stod(match[1]), 0.10, 10.00);
    return true;
}

bool ReplaceSetting(std::string& config, const std::string& name, const std::string& value) {
    size_t start = 0;
    size_t length = 0;
    if (!FindEnemyScalingBlock(config, start, length)) {
        return false;
    }
    std::string block = config.substr(start, length);
    const std::regex pattern("(" + name + R"(\s*=\s*)(?:true|false|[0-9]+(?:\.[0-9]+)?))");
    const std::string updated = std::regex_replace(block, pattern, "$1" + value, std::regex_constants::format_first_only);
    if (updated == block) {
        return false;
    }
    config.replace(start, length, updated);
    return true;
}

void ShowError(HWND window, const std::wstring& message) {
    SetStatus(message, RGB(178, 34, 34));
    MessageBoxW(window, message.c_str(), L"Hades II Co-op Enemy HP Settings", MB_OK | MB_ICONERROR);
}

void BrowseForGame(HWND window) {
    wchar_t fileName[MAX_PATH]{};
    OPENFILENAMEW dialog{};
    dialog.lStructSize = sizeof(dialog);
    dialog.hwndOwner = window;
    dialog.lpstrFilter = L"Hades II executable (Hades2.exe)\0Hades2.exe\0Executable files (*.exe)\0*.exe\0";
    dialog.lpstrFile = fileName;
    dialog.nMaxFile = MAX_PATH;
    dialog.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST;
    dialog.lpstrTitle = L"Select Hades2.exe";
    if (GetOpenFileNameW(&dialog)) {
        SetWindowTextW(pathEdit, fileName);
        SetStatus(L"Game path selected. Click Load Current Setting or Apply Setting.", RGB(0, 100, 0));
    }
}

void LoadCurrentSetting(HWND window) {
    std::filesystem::path configPath;
    std::wstring error;
    if (!TryGetConfigPath(configPath, error)) {
        ShowError(window, error);
        return;
    }

    std::string config;
    bool enabled = true;
    double multiplier = 1.50;
    if (!ReadFile(configPath, config) || !ReadBoolean(config, enabled) || !ReadMultiplier(config, multiplier)) {
        ShowError(window, L"Unable to read EnemyScaling settings from config.lua.");
        return;
    }

    SendMessageW(enabledCheck, BM_SETCHECK, enabled ? BST_CHECKED : BST_UNCHECKED, 0);
    wchar_t multiplierText[32]{};
    swprintf_s(multiplierText, L"%.2f", multiplier);
    SetWindowTextW(multiplierEdit, multiplierText);
    SetStatus(L"Current enemy HP setting loaded.", RGB(0, 100, 0));
}

void ApplySetting(HWND window) {
    if (IsGameRunning()) {
        ShowError(window, L"Fully exit Hades II before applying a setting.");
        return;
    }

    std::filesystem::path configPath;
    std::wstring error;
    if (!TryGetConfigPath(configPath, error)) {
        ShowError(window, error);
        return;
    }

    const std::wstring multiplierText = GetControlText(multiplierEdit);
    wchar_t* end = nullptr;
    const double multiplier = wcstod(multiplierText.c_str(), &end);
    if (end == multiplierText.c_str() || *end != L'\0' || multiplier < 0.10 || multiplier > 10.00) {
        ShowError(window, L"Enter an enemy HP multiplier from 0.10 to 10.00.");
        return;
    }

    std::string config;
    if (!ReadFile(configPath, config)) {
        ShowError(window, L"Unable to read config.lua.");
        return;
    }

    char multiplierValue[32]{};
    sprintf_s(multiplierValue, "%.2f", multiplier);
    const bool enabled = SendMessageW(enabledCheck, BM_GETCHECK, 0, 0) == BST_CHECKED;
    if (!ReplaceSetting(config, "Enabled", enabled ? "true" : "false") || !ReplaceSetting(config, "HealthMultiplier", multiplierValue)) {
        ShowError(window, L"EnemyScaling settings were not found in config.lua.");
        return;
    }

    const auto temporaryPath = configPath.wstring() + L".tmp";
    if (!WriteFile(temporaryPath, config)) {
        ShowError(window, L"Unable to write temporary config.lua file.");
        return;
    }
    std::error_code moveError;
    std::filesystem::rename(temporaryPath, configPath, moveError);
    if (moveError) {
        std::filesystem::remove(configPath, moveError);
        moveError.clear();
        std::filesystem::rename(temporaryPath, configPath, moveError);
    }
    if (moveError) {
        ShowError(window, L"Unable to replace config.lua.");
        return;
    }

    SetStatus(L"Applied. Restart Hades II to load the new enemy HP setting.", RGB(0, 100, 0));
}

LRESULT CALLBACK WindowProcedure(HWND window, UINT message, WPARAM wParam, LPARAM lParam) {
    switch (message) {
    case WM_CREATE: {
        const HFONT font = static_cast<HFONT>(GetStockObject(DEFAULT_GUI_FONT));
        CreateWindowW(L"STATIC", L"Adjust the installed co-op mod's enemy HP multiplier. The game must be closed. This tool changes only TN_CoopMod\\config.lua.", WS_CHILD | WS_VISIBLE, 18, 18, 650, 42, window, nullptr, nullptr, nullptr);
        pathEdit = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", L"", WS_CHILD | WS_VISIBLE | WS_TABSTOP | ES_AUTOHSCROLL, 18, 72, 490, 24, window, reinterpret_cast<HMENU>(static_cast<INT_PTR>(PathEditId)), nullptr, nullptr);
        CreateWindowW(L"BUTTON", L"Browse for Hades2.exe...", WS_CHILD | WS_VISIBLE | WS_TABSTOP, 520, 72, 160, 24, window, reinterpret_cast<HMENU>(static_cast<INT_PTR>(BrowseButtonId)), nullptr, nullptr);
        CreateWindowW(L"STATIC", L"Enemy HP multiplier", WS_CHILD | WS_VISIBLE, 18, 115, 180, 24, window, nullptr, nullptr, nullptr);
        multiplierEdit = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", L"1.50", WS_CHILD | WS_VISIBLE | WS_TABSTOP | ES_AUTOHSCROLL, 205, 112, 100, 24, window, reinterpret_cast<HMENU>(static_cast<INT_PTR>(MultiplierEditId)), nullptr, nullptr);
        enabledCheck = CreateWindowW(L"BUTTON", L"Enable enemy HP scaling", WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_AUTOCHECKBOX, 18, 151, 220, 24, window, reinterpret_cast<HMENU>(static_cast<INT_PTR>(EnabledCheckId)), nullptr, nullptr);
        SendMessageW(enabledCheck, BM_SETCHECK, BST_CHECKED, 0);
        CreateWindowW(L"BUTTON", L"Load Current Setting", WS_CHILD | WS_VISIBLE | WS_TABSTOP, 18, 190, 150, 28, window, reinterpret_cast<HMENU>(static_cast<INT_PTR>(LoadButtonId)), nullptr, nullptr);
        CreateWindowW(L"BUTTON", L"Apply Setting", WS_CHILD | WS_VISIBLE | WS_TABSTOP, 178, 190, 120, 28, window, reinterpret_cast<HMENU>(static_cast<INT_PTR>(ApplyButtonId)), nullptr, nullptr);
        statusLabel = CreateWindowW(L"STATIC", L"Default is 1.50x enemy HP. Select Hades2.exe, then load or apply the setting.", WS_CHILD | WS_VISIBLE, 18, 235, 650, 40, window, reinterpret_cast<HMENU>(static_cast<INT_PTR>(StatusLabelId)), nullptr, nullptr);
        EnumChildWindows(window, [](HWND child, LPARAM value) -> BOOL { SendMessageW(child, WM_SETFONT, value, TRUE); return TRUE; }, reinterpret_cast<LPARAM>(font));
        return 0;
    }
    case WM_COMMAND:
        switch (LOWORD(wParam)) {
        case BrowseButtonId: BrowseForGame(window); return 0;
        case LoadButtonId: LoadCurrentSetting(window); return 0;
        case ApplyButtonId: ApplySetting(window); return 0;
        }
        break;
    case WM_CTLCOLORSTATIC: {
        const HWND control = reinterpret_cast<HWND>(lParam);
        if (control == statusLabel) {
            SetTextColor(reinterpret_cast<HDC>(wParam), static_cast<COLORREF>(GetWindowLongPtrW(statusLabel, GWLP_USERDATA)));
            SetBkMode(reinterpret_cast<HDC>(wParam), TRANSPARENT);
            return reinterpret_cast<LRESULT>(GetSysColorBrush(COLOR_BTNFACE));
        }
        break;
    }
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProcW(window, message, wParam, lParam);
}
}

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR, int commandShow) {
    const wchar_t className[] = L"Hades2CoopEnemyScalerWindow";
    WNDCLASSW windowClass{};
    windowClass.hInstance = instance;
    windowClass.lpszClassName = className;
    windowClass.lpfnWndProc = WindowProcedure;
    windowClass.hCursor = LoadCursor(nullptr, IDC_ARROW);
    windowClass.hbrBackground = GetSysColorBrush(COLOR_BTNFACE);
    RegisterClassW(&windowClass);

    const HWND window = CreateWindowExW(0, className, L"Hades II Co-op Enemy HP Settings", WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX, CW_USEDEFAULT, CW_USEDEFAULT, 720, 330, nullptr, nullptr, instance, nullptr);
    ShowWindow(window, commandShow);

    MSG message{};
    while (GetMessageW(&message, nullptr, 0, 0)) {
        TranslateMessage(&message);
        DispatchMessageW(&message);
    }
    return static_cast<int>(message.wParam);
}
