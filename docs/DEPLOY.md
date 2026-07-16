# 开发部署指南

最后更新：2026-07-12

## 当前工作流

从仓库根目录运行以下命令。

无论修改 Lua 还是 C++，均使用同一条命令：

```powershell
Set-Location 'C:\path\to\hades2-coop-expanded'
.\scripts\build_and_deploy.ps1
```

该脚本会配置 CMake、构建 Release、安装到 `bin\TN_CoopMod`，并把变更复制到：

```text
<Hades II>\Content\Mods\TN_CoopMod
```

首次安装或环境检查使用：

```powershell
.\scripts\install_all.ps1
```

## 验证部署

构建输出应显示 `Deploy complete`。若改动涉及 C++，还应显示新的 `HadesCoopGame.dll` 写入时间。

```powershell
Get-Item '<Hades II>\Content\Mods\TN_CoopMod\HadesCoopGame.dll'
```

不要直接使用旧的 `dev_deploy.ps1` 或 `build_and_deploy.bat` 作为日常工作流；它们保留仅供历史兼容，未经当前流程验证。

## 调试日志

打开独立终端：

```powershell
Set-Location 'C:\path\to\hades2-coop-expanded'
.\scripts\watch_coop_debug.ps1
```

完整日志文件：

```text
%USERPROFILE%\Saved Games\Hades II\TN_CoopMod.log
```

日志会带地点前缀，例如：

```text
[Underworld-Layer1-Erebus-CombatRoom-F_Combat12] [CoopRewardTrace] ...
```

常用 trace：`CoopRewardTrace`、`CoopFieldsRewardTrace`、`CoopShipsRewardTrace`、`CoopDoorManaTrace`、`CoopDeathTrace`、`CoopBossTrace`。

`CoopDoorManaTrace` 只在过门时记录一次 P1/P2 的 MP 前后值，用于确认原版基础回满是否在两名存活玩家各自上下文中执行。`CoopSpellUiTrace` 与 `CoopArcanaAudit` 当前暂时关闭。

## 排障

- PowerShell 运行当前目录脚本时必须使用 `./` 或 `.\` 前缀。
- `cmake` 找不到时，脚本会尝试 Visual Studio 2022 内置 CMake；确认已安装 C++ 与 CMake 组件。
- Lua 改动未生效时，重新执行 `./build_and_deploy.ps1`，并检查目标 Mod 目录的文件时间。
- 游戏运行期间不要替换 DLL；先退出游戏再部署 C++ 改动。
