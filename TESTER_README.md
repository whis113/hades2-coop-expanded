# Hades II Co-op v0.2.2 Test Build

## English

### What This Package Includes

This package installs the complete local co-op dependency chain:

- `TN_CoopMod`: the co-op gameplay mod.
- `TN_Core`: the mod framework required to expose the in-game co-op entry point.
- `HadesModNativeExtension.asi`: the native mod-extension plugin.
- `bink2w64.dll`: the ASI Loader, installed only when ReturnOfModding is not already present.

The upstream `hades2-coop` project provides the base local P1/P2 framework. This test build adds revival, independent keepsakes and Arcana loadouts, expanded rewards, and compatibility fixes.

### Install or Update

1. Fully exit Hades II.
2. Extract the entire ZIP. Keep `Hades2CoopInstaller.exe`, `TN_CoopMod`, and `Dependencies` in the same extracted folder.
3. Run `Hades2CoopInstaller.exe`.
4. Select `<Hades II>\Ship\Hades2.exe`.
5. Choose **Install / Update Mod**.
6. Start Hades II. The co-op entry should now be available.

The installer verifies all required files after installation. When it installs the ASI Loader, it backs up the original `Ship\bink2w64.dll` as `bink2w64Hooked.dll`.

### Uninstall

Exit Hades II, run the installer, select the same executable, and choose **Uninstall Co-op Mod**. This removes only `TN_CoopMod`; shared framework and loader files remain to avoid breaking other mods.

### Known Limits

- This is local co-op on one PC, not network multiplayer.
- `F_PreBoss` Zagreus challenge rewards are not yet doubled.
- Fields of Mourning `TalentDrop` still needs targeted verification.
- Some rare NPC/event combinations still need regression testing.
- Hub HP/MP UI may refresh only when the next run starts; gameplay values are unaffected.

### Reporting Problems

Keep a PowerShell log terminal open while testing:

```powershell
Get-Content "$env:USERPROFILE\Saved Games\Hades II\TN_CoopMod.log" -Wait
```

Include the route, room label, P1/P2 state, steps to reproduce, screenshots or video, and related log lines.

## 中文

### 包含内容

本测试包会安装完整的本地双人依赖链：

- `TN_CoopMod`：双人玩法 Mod。
- `TN_Core`：提供游戏内双人模式入口所需的 Mod 框架。
- `HadesModNativeExtension.asi`：原生 Mod 扩展插件。
- `bink2w64.dll`：ASI Loader；仅在未安装 ReturnOfModding 时部署。

原项目 `hades2-coop` 提供 P1/P2 本地双人基础框架。本测试版新增复活、独立信物和阿卡那预设、奖励扩展及兼容修复。

### 安装或更新

1. 完全退出 Hades II。
2. 解压完整 ZIP，确保 `Hades2CoopInstaller.exe`、`TN_CoopMod` 与 `Dependencies` 位于同一解压目录。
3. 运行 `Hades2CoopInstaller.exe`。
4. 选择 `<Hades II>\Ship\Hades2.exe`。
5. 点击 **Install / Update Mod（安装 / 更新 Mod）**。
6. 启动 Hades II，此时应可看到双人模式入口。

安装器会在完成后校验全部必需文件。若安装 ASI Loader，会将原始 `Ship\bink2w64.dll` 备份为 `bink2w64Hooked.dll`。

### 卸载

退出 Hades II 后运行安装器，选择同一个游戏可执行文件，再点击 **Uninstall Co-op Mod（卸载双人 Mod）**。该操作只删除 `TN_CoopMod`；共享框架和加载器会保留，避免影响其他 Mod。

### 已知限制

- 这是单机本地双人，不是联网多人。
- `F_PreBoss` 扎格列欧斯挑战奖励尚未双份。
- 哀悼原野 `TalentDrop` 仍需专项验证。
- 部分罕见 NPC/事件组合仍需回归测试。
- 回到 Hub 后 HP/MP UI 可能要到下一局才刷新，但实际数值不受影响。

### 问题反馈

测试时在 PowerShell 保持日志终端开启：

```powershell
Get-Content "$env:USERPROFILE\Saved Games\Hades II\TN_CoopMod.log" -Wait
```

反馈请包含路线、房间标签、P1/P2 状态、复现步骤、截图或视频，以及相关日志行。
