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
    private const string GameExecutableName = "Hades2.exe";
    private readonly TextBox gameExePathTextBox = new() { Dock = DockStyle.Fill };
    private readonly Label statusLabel = new() { AutoSize = true, MaximumSize = new Size(600, 0) };
    private readonly Button installButton = new() { Text = "安装 / 更新 Mod", AutoSize = true };
    private readonly Button uninstallButton = new() { Text = "卸载 Mod", AutoSize = true };

    public InstallerForm()
    {
        Text = "Hades II Co-op 首测安装器";
        StartPosition = FormStartPosition.CenterScreen;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        MinimizeBox = false;
        ClientSize = new Size(680, 250);

        var browseButton = new Button { Text = "选择 Hades2.exe...", AutoSize = true };
        browseButton.Click += (_, _) => BrowseForGameExecutable();
        installButton.Click += (_, _) => InstallOrUpdate();
        uninstallButton.Click += (_, _) => Uninstall();

        var openModsButton = new Button { Text = "打开 Mods 文件夹", AutoSize = true };
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
            Text = "选择 Hades II 的 Ship\\Hades2.exe。安装器只会写入 Content\\Mods\\TN_CoopMod。",
            AutoSize = true,
            MaximumSize = new Size(620, 0),
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
        SetStatus("请选择游戏可执行文件，然后安装。安装前请完全退出 Hades II。", Color.DimGray);
    }

    private void BrowseForGameExecutable()
    {
        using var dialog = new OpenFileDialog
        {
            Title = "选择 Hades2.exe",
            Filter = "Hades II executable (Hades2.exe)|Hades2.exe|Executable files (*.exe)|*.exe",
            FileName = GameExecutableName,
        };

        if (dialog.ShowDialog(this) == DialogResult.OK)
        {
            gameExePathTextBox.Text = dialog.FileName;
            SaveGamePath(dialog.FileName);
            SetStatus("已选择游戏路径。", Color.DarkGreen);
        }
    }

    private void InstallOrUpdate()
    {
        if (!TryGetTargetModDirectory(out var targetModDirectory))
        {
            return;
        }

        if (!EnsureGameIsClosed())
        {
            return;
        }

        var payloadDirectory = Path.Combine(AppContext.BaseDirectory, ModFolderName);
        if (!File.Exists(Path.Combine(payloadDirectory, "HadesCoopGame.dll")))
        {
            ShowError("发布包不完整：找不到 TN_CoopMod\\HadesCoopGame.dll。请重新下载完整测试包。");
            return;
        }

        var modsDirectory = Directory.GetParent(targetModDirectory)?.FullName;
        if (modsDirectory is null)
        {
            ShowError("无法确定游戏 Mods 目录。");
            return;
        }

        var stagingDirectory = targetModDirectory + ".installing";
        var backupDirectory = targetModDirectory + ".backup";
        try
        {
            SetBusy(true, "正在复制 Mod 文件...");
            DeleteDirectoryIfExists(stagingDirectory);
            DeleteDirectoryIfExists(backupDirectory);
            Directory.CreateDirectory(modsDirectory);
            CopyDirectory(payloadDirectory, stagingDirectory);

            if (Directory.Exists(targetModDirectory))
            {
                Directory.Move(targetModDirectory, backupDirectory);
            }

            Directory.Move(stagingDirectory, targetModDirectory);
            DeleteDirectoryIfExists(backupDirectory);
            SetStatus("安装完成。请启动 Hades II，并从 co-op 入口开始游戏。", Color.DarkGreen);
        }
        catch (Exception exception)
        {
            // Restore the prior installation if the swap did not finish.
            // 若目录替换未完成，则恢复旧安装，避免留下半成品 Mod。
            DeleteDirectoryIfExists(stagingDirectory);
            if (!Directory.Exists(targetModDirectory) && Directory.Exists(backupDirectory))
            {
                Directory.Move(backupDirectory, targetModDirectory);
            }

            ShowError($"安装失败：{exception.Message}");
        }
        finally
        {
            SetBusy(false);
        }
    }

    private void Uninstall()
    {
        if (!TryGetTargetModDirectory(out var targetModDirectory))
        {
            return;
        }

        if (!EnsureGameIsClosed())
        {
            return;
        }

        if (!Directory.Exists(targetModDirectory))
        {
            SetStatus("未找到已安装的 TN_CoopMod，无需卸载。", Color.DimGray);
            return;
        }

        var confirmation = MessageBox.Show(
            this,
            "将删除 Content\\Mods\\TN_CoopMod。不会删除存档或游戏本体文件。是否继续？",
            "确认卸载",
            MessageBoxButtons.YesNo,
            MessageBoxIcon.Warning);
        if (confirmation != DialogResult.Yes)
        {
            return;
        }

        try
        {
            SetBusy(true, "正在卸载 Mod...");
            Directory.Delete(targetModDirectory, true);
            SetStatus("卸载完成。", Color.DarkGreen);
        }
        catch (Exception exception)
        {
            ShowError($"卸载失败：{exception.Message}");
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
            ShowError("请选择 Hades II 安装目录下 Ship\\Hades2.exe。");
            return false;
        }

        var shipDirectory = Path.GetDirectoryName(executablePath);
        var gameDirectory = shipDirectory is null ? null : Directory.GetParent(shipDirectory)?.FullName;
        if (gameDirectory is null)
        {
            ShowError("无法从 Hades2.exe 推导游戏根目录。");
            return false;
        }

        SaveGamePath(executablePath);
        targetModDirectory = Path.Combine(gameDirectory, "Content", "Mods", ModFolderName);
        return true;
    }

    private bool EnsureGameIsClosed()
    {
        if (Process.GetProcessesByName("Hades2").Length == 0)
        {
            return true;
        }

        ShowError("请先完全退出 Hades II，再安装、更新或卸载 Mod。");
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

    private static string SettingsPath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "Hades2CoopInstaller",
        "settings.json");

    private static string? LoadSavedGamePath()
    {
        try
        {
            if (!File.Exists(SettingsPath))
            {
                return null;
            }

            return JsonSerializer.Deserialize<InstallerSettings>(File.ReadAllText(SettingsPath))?.GameExecutablePath;
        }
        catch
        {
            return null;
        }
    }

    private static void SaveGamePath(string gameExecutablePath)
    {
        var directory = Path.GetDirectoryName(SettingsPath)!;
        Directory.CreateDirectory(directory);
        File.WriteAllText(SettingsPath, JsonSerializer.Serialize(new InstallerSettings(gameExecutablePath)));
    }

    private sealed record InstallerSettings(string GameExecutablePath);
}
