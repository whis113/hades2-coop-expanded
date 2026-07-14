using System.Diagnostics;
using System.Text.Json;

namespace Hades2CoopInstaller;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        ApplicationConfiguration.Initialize();
        Application.Run(new InstallerForm());
    }
}

internal sealed class InstallerForm : Form
{
    private const string ModFolderName = "TN_CoopMod";
    private const string CoreFolderName = "TN_Core";
    private const string DependenciesFolderName = "Dependencies";
    private const string NativeExtensionName = "HadesModNativeExtension.asi";
    private const string AsiLoaderName = "bink2w64.dll";
    private const string GameExecutableName = "Hades2.exe";

    private readonly TextBox gameExePathTextBox = new() { Dock = DockStyle.Fill };
    private readonly Label statusLabel = new() { AutoSize = true, MaximumSize = new Size(620, 0) };
    private readonly Button installButton = new() { Text = "Install / Update Mod\n安装 / 更新 Mod", AutoSize = true };
    private readonly Button uninstallButton = new() { Text = "Uninstall Co-op Mod\n卸载双人 Mod", AutoSize = true };

    public InstallerForm()
    {
        Text = "Hades II Co-op Test Installer / Hades II 双人 Mod 测试安装器";
        StartPosition = FormStartPosition.CenterScreen;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        MinimizeBox = false;
        ClientSize = new Size(720, 290);

        var browseButton = new Button { Text = "Browse for Hades2.exe...\n选择 Hades2.exe...", AutoSize = true };
        var openModsButton = new Button { Text = "Open Mods Folder\n打开 Mods 文件夹", AutoSize = true };
        browseButton.Click += (_, _) => BrowseForGameExecutable();
        installButton.Click += (_, _) => InstallOrUpdate();
        uninstallButton.Click += (_, _) => Uninstall();
        openModsButton.Click += (_, _) => OpenModsFolder();

        var layout = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            Padding = new Padding(18),
            ColumnCount = 2,
            RowCount = 5,
        };
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));

        layout.Controls.Add(new Label
        {
            Text = Bilingual(
                "Select Hades II's Ship\\Hades2.exe. This installer deploys TN_CoopMod, TN_Core, the native extension, and the ASI loader when required.",
                "请选择 Hades II 的 Ship\\Hades2.exe。安装器会部署 TN_CoopMod、TN_Core、原生扩展及所需的 ASI 加载器。"),
            AutoSize = true,
            MaximumSize = new Size(660, 0),
        }, 0, 0);
        layout.SetColumnSpan(layout.GetControlFromPosition(0, 0)!, 2);
        layout.Controls.Add(gameExePathTextBox, 0, 1);
        layout.Controls.Add(browseButton, 1, 1);

        var buttons = new FlowLayoutPanel { AutoSize = true, FlowDirection = FlowDirection.LeftToRight };
        buttons.Controls.Add(installButton);
        buttons.Controls.Add(uninstallButton);
        buttons.Controls.Add(openModsButton);
        layout.Controls.Add(buttons, 0, 2);
        layout.SetColumnSpan(buttons, 2);
        layout.Controls.Add(statusLabel, 0, 4);
        layout.SetColumnSpan(statusLabel, 2);
        Controls.Add(layout);

        gameExePathTextBox.Text = LoadSavedGamePath() ?? string.Empty;
        SetStatus(Bilingual(
            "Select the game executable, then install. Fully exit Hades II before installing, updating, or uninstalling.",
            "请选择游戏可执行文件后安装。安装、更新或卸载前请完全退出 Hades II。"), Color.DimGray);
    }

    private static string Bilingual(string english, string chinese) => $"{english}\r\n{chinese}";

    private void BrowseForGameExecutable()
    {
        using var dialog = new OpenFileDialog
        {
            Title = "Select Hades2.exe / 选择 Hades2.exe",
            Filter = "Hades II executable (Hades2.exe)|Hades2.exe|Executable files (*.exe)|*.exe",
            FileName = GameExecutableName,
        };

        if (dialog.ShowDialog(this) == DialogResult.OK)
        {
            gameExePathTextBox.Text = dialog.FileName;
            SaveGamePath(dialog.FileName);
            SetStatus(Bilingual("Game path selected.", "已选择游戏路径。"), Color.DarkGreen);
        }
    }

    private void InstallOrUpdate()
    {
        if (!TryGetTargetModDirectory(out var targetModDirectory) || !EnsureGameIsClosed())
        {
            return;
        }

        var payloadDirectory = Path.Combine(AppContext.BaseDirectory, ModFolderName);
        var dependenciesDirectory = Path.Combine(AppContext.BaseDirectory, DependenciesFolderName);
        if (!File.Exists(Path.Combine(payloadDirectory, "HadesCoopGame.dll")))
        {
            ShowError(Bilingual(
                "Incomplete package: TN_CoopMod\\HadesCoopGame.dll is missing. Download the full test package again.",
                "测试包不完整：缺少 TN_CoopMod\\HadesCoopGame.dll。请重新下载完整测试包。"));
            return;
        }
        if (!Directory.Exists(Path.Combine(dependenciesDirectory, CoreFolderName))
            || !File.Exists(Path.Combine(dependenciesDirectory, NativeExtensionName))
            || !File.Exists(Path.Combine(dependenciesDirectory, AsiLoaderName)))
        {
            ShowError(Bilingual(
                "Incomplete package: required co-op dependencies are missing. Download the full test package again.",
                "测试包不完整：缺少双人模式所需依赖。请重新下载完整测试包。"));
            return;
        }

        var modsDirectory = Directory.GetParent(targetModDirectory)?.FullName;
        if (modsDirectory is null)
        {
            ShowError(Bilingual("Unable to determine the game's Mods directory.", "无法确定游戏 Mods 目录。"));
            return;
        }

        var stagingDirectory = targetModDirectory + ".installing";
        var backupDirectory = targetModDirectory + ".backup";
        try
        {
            SetBusy(true, Bilingual("Installing co-op files...", "正在安装双人 Mod 文件..."));
            DeleteDirectoryIfExists(stagingDirectory);
            DeleteDirectoryIfExists(backupDirectory);
            Directory.CreateDirectory(modsDirectory);
            InstallSharedDependencies(dependenciesDirectory, modsDirectory);
            CopyDirectory(payloadDirectory, stagingDirectory);

            if (Directory.Exists(targetModDirectory))
            {
                Directory.Move(targetModDirectory, backupDirectory);
            }

            Directory.Move(stagingDirectory, targetModDirectory);
            DeleteDirectoryIfExists(backupDirectory);
            VerifyInstallation(targetModDirectory, modsDirectory);
            SetStatus(Bilingual(
                "Install complete. The Co-op entry should be available after starting Hades II.",
                "安装完成。启动 Hades II 后应可看到双人模式入口。"), Color.DarkGreen);
        }
        catch (Exception exception)
        {
            DeleteDirectoryIfExists(stagingDirectory);
            if (!Directory.Exists(targetModDirectory) && Directory.Exists(backupDirectory))
            {
                Directory.Move(backupDirectory, targetModDirectory);
            }

            ShowError(Bilingual($"Installation failed: {exception.Message}", $"安装失败：{exception.Message}"));
        }
        finally
        {
            SetBusy(false);
        }
    }

    private void Uninstall()
    {
        if (!TryGetTargetModDirectory(out var targetModDirectory) || !EnsureGameIsClosed())
        {
            return;
        }

        if (!Directory.Exists(targetModDirectory))
        {
            SetStatus(Bilingual("TN_CoopMod is not installed.", "未找到已安装的 TN_CoopMod。"), Color.DimGray);
            return;
        }

        var confirmation = MessageBox.Show(
            this,
            Bilingual(
                "This removes Content\\Mods\\TN_CoopMod only. It does not delete saves. Shared TN_Core and loader files are kept to avoid breaking other mods. Continue?",
                "此操作只删除 Content\\Mods\\TN_CoopMod，不会删除存档。为避免影响其他 Mod，会保留共享的 TN_Core 和加载器。是否继续？"),
            "Confirm Uninstall / 确认卸载",
            MessageBoxButtons.YesNo,
            MessageBoxIcon.Warning);
        if (confirmation != DialogResult.Yes)
        {
            return;
        }

        try
        {
            SetBusy(true, Bilingual("Uninstalling TN_CoopMod...", "正在卸载 TN_CoopMod..."));
            Directory.Delete(targetModDirectory, true);
            SetStatus(Bilingual(
                "TN_CoopMod was removed. Shared TN_Core and loader files were kept.",
                "TN_CoopMod 已卸载。共享 TN_Core 和加载器已保留。"), Color.DarkGreen);
        }
        catch (Exception exception)
        {
            ShowError(Bilingual($"Uninstall failed: {exception.Message}", $"卸载失败：{exception.Message}"));
        }
        finally
        {
            SetBusy(false);
        }
    }

    private void OpenModsFolder()
    {
        if (!TryGetTargetModDirectory(out var targetModDirectory))
        {
            return;
        }

        var modsDirectory = Directory.GetParent(targetModDirectory)?.FullName;
        if (modsDirectory is not null)
        {
            Directory.CreateDirectory(modsDirectory);
            Process.Start(new ProcessStartInfo { FileName = modsDirectory, UseShellExecute = true });
        }
    }

    private bool TryGetTargetModDirectory(out string targetModDirectory)
    {
        targetModDirectory = string.Empty;
        var executablePath = gameExePathTextBox.Text.Trim();
        if (!File.Exists(executablePath) || !string.Equals(Path.GetFileName(executablePath), GameExecutableName, StringComparison.OrdinalIgnoreCase))
        {
            ShowError(Bilingual(
                "Select Hades II's Ship\\Hades2.exe.",
                "请选择 Hades II 安装目录中的 Ship\\Hades2.exe。"));
            return false;
        }

        var shipDirectory = Path.GetDirectoryName(executablePath);
        var gameDirectory = shipDirectory is null ? null : Directory.GetParent(shipDirectory)?.FullName;
        if (gameDirectory is null)
        {
            ShowError(Bilingual("Unable to determine the Hades II game directory.", "无法确定 Hades II 游戏根目录。"));
            return false;
        }

        SaveGamePath(executablePath);
        targetModDirectory = Path.Combine(gameDirectory, "Content", "Mods", ModFolderName);
        return true;
    }

    private static bool EnsureGameIsClosed()
    {
        if (Process.GetProcessesByName("Hades2").Length == 0)
        {
            return true;
        }

        MessageBox.Show(
            Bilingual(
                "Fully exit Hades II before installing, updating, or uninstalling.",
                "安装、更新或卸载前请完全退出 Hades II。"),
            "Hades II Co-op",
            MessageBoxButtons.OK,
            MessageBoxIcon.Error);
        return false;
    }

    private void SetBusy(bool isBusy, string? status = null)
    {
        UseWaitCursor = isBusy;
        installButton.Enabled = !isBusy;
        uninstallButton.Enabled = !isBusy;
        if (status is not null)
        {
            SetStatus(status, Color.DimGray);
        }

        Application.DoEvents();
    }

    private void SetStatus(string message, Color color)
    {
        statusLabel.Text = message;
        statusLabel.ForeColor = color;
    }

    private void ShowError(string message)
    {
        SetStatus(message, Color.Firebrick);
        MessageBox.Show(this, message, "Hades II Co-op", MessageBoxButtons.OK, MessageBoxIcon.Error);
    }

    private static void CopyDirectory(string sourceDirectory, string destinationDirectory)
    {
        Directory.CreateDirectory(destinationDirectory);
        foreach (var directory in Directory.GetDirectories(sourceDirectory, "*", SearchOption.AllDirectories))
        {
            Directory.CreateDirectory(directory.Replace(sourceDirectory, destinationDirectory, StringComparison.OrdinalIgnoreCase));
        }

        foreach (var sourceFile in Directory.GetFiles(sourceDirectory, "*", SearchOption.AllDirectories))
        {
            var destinationFile = sourceFile.Replace(sourceDirectory, destinationDirectory, StringComparison.OrdinalIgnoreCase);
            File.Copy(sourceFile, destinationFile, true);
        }
    }

    private static void DeleteDirectoryIfExists(string directory)
    {
        if (Directory.Exists(directory))
        {
            Directory.Delete(directory, true);
        }
    }

    private static void InstallSharedDependencies(string dependenciesDirectory, string modsDirectory)
    {
        CopyDirectory(Path.Combine(dependenciesDirectory, CoreFolderName), Path.Combine(modsDirectory, CoreFolderName));

        var gameDirectory = Directory.GetParent(modsDirectory)?.Parent?.FullName
            ?? throw new InvalidOperationException("Unable to determine the game directory / 无法确定游戏根目录。");
        var shipDirectory = Path.Combine(gameDirectory, "Ship");
        var pluginsDirectory = Path.Combine(shipDirectory, "plugins");
        Directory.CreateDirectory(pluginsDirectory);
        File.Copy(Path.Combine(dependenciesDirectory, NativeExtensionName), Path.Combine(pluginsDirectory, NativeExtensionName), true);

        if (Directory.Exists(Path.Combine(shipDirectory, "ReturnOfModding")))
        {
            return;
        }

        var loaderDestination = Path.Combine(shipDirectory, AsiLoaderName);
        var originalBinkBackup = Path.Combine(shipDirectory, "bink2w64Hooked.dll");
        if (!File.Exists(originalBinkBackup))
        {
            if (!File.Exists(loaderDestination))
            {
                throw new FileNotFoundException("Original bink2w64.dll is missing / 找不到原始 bink2w64.dll。", loaderDestination);
            }

            // Preserve the original game DLL before installing the ASI loader.
            // 安装 ASI 加载器前保留原始游戏 DLL。
            File.Move(loaderDestination, originalBinkBackup);
        }

        File.Copy(Path.Combine(dependenciesDirectory, AsiLoaderName), loaderDestination, true);
    }

    private static void VerifyInstallation(string targetModDirectory, string modsDirectory)
    {
        var gameDirectory = Directory.GetParent(modsDirectory)?.Parent?.FullName
            ?? throw new InvalidOperationException("Unable to determine the game directory / 无法确定游戏根目录。");
        var shipDirectory = Path.Combine(gameDirectory, "Ship");
        var requiredPaths = new List<string>
        {
            Path.Combine(targetModDirectory, "HadesCoopGame.dll"),
            Path.Combine(modsDirectory, CoreFolderName, "init.lua"),
            Path.Combine(shipDirectory, "plugins", NativeExtensionName),
        };
        if (!Directory.Exists(Path.Combine(shipDirectory, "ReturnOfModding")))
        {
            requiredPaths.Add(Path.Combine(shipDirectory, AsiLoaderName));
        }

        var missing = requiredPaths.Where(path => !File.Exists(path)).ToArray();
        if (missing.Length > 0)
        {
            throw new InvalidOperationException($"Installation verification failed / 安装校验失败：{string.Join("; ", missing)}");
        }
    }

    private static string SettingsPath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "Hades2CoopInstaller",
        "settings.json");

    private static string? LoadSavedGamePath()
    {
        try
        {
            return File.Exists(SettingsPath)
                ? JsonSerializer.Deserialize<InstallerSettings>(File.ReadAllText(SettingsPath))?.GameExecutablePath
                : null;
        }
        catch
        {
            return null;
        }
    }

    private static void SaveGamePath(string gameExecutablePath)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(SettingsPath)!);
        File.WriteAllText(SettingsPath, JsonSerializer.Serialize(new InstallerSettings(gameExecutablePath)));
    }

    private sealed record InstallerSettings(string GameExecutablePath);
}
