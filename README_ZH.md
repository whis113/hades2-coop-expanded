# Hades II Co-op

![Status](https://img.shields.io/badge/status-in%20development-orange)
![Platform](https://img.shields.io/badge/platform-Windows-blue)
![Game](https://img.shields.io/badge/game-Hades%20II-red)
![License](https://img.shields.io/badge/license-MIT-green)

文档状态：2026-07-15 已同步 v0.2.3 外部测试包、独立阿卡那、锤子候选修复和敌人生命值工具状态。

英文文档：[`README.md`](README.md)。

Hades II 本地双人 co-op mod 开发工作区，目标是在原版 roguelike 流程中稳定支持 P1/P2 同场战斗、死亡、复活与双人奖励。

> 本文为中文版本；后续新增内容必须同步更新英文 `README.md`。

## 目录

- [项目状态](#项目状态)
- [特性](#特性)
- [安装](#安装)
- [快速开始](#快速开始)
- [配置](#配置)
- [项目结构](#项目结构)
- [术语与注意事项](#术语与注意事项)
- [常见问题](#常见问题)
- [贡献](#贡献)
- [许可证](#许可证)
- [更新记录](#更新记录)

## 项目边界与来源

本项目不是从零实现双人系统，而是基于原项目 `hades2-coop` 的本地双人框架进行玩法扩展和问题修复。除非特别标注，以下能力属于原项目基础设施：P2 创建与控制器绑定、双人角色单位、镜头、输入、HeroContext、线程隔离、全局数据代理、基础 HUD 适配、Lua/C++ hook 框架以及基础奖励分发框架。

当前项目新增或修改的范围主要是：Boss -> Rest Room 复活、双人死亡状态处理、P1/P2 信物柜独立使用、P1/P2 独立阿卡那预设与临时加卡、房间奖励双发、P2 boon/锤子/Chaos 选项上下文、NPC 奖励流程、泉水双人使用、调试监测和地点标签。

| 来源 | 文档含义 |
|------|----------|
| 原项目 | 提供双人系统构造和底层运行框架，不应在本项目日志中重复归功于当前扩展。 |
| 当前扩展 | 在原项目基础上新增的玩法功能、兼容修复、调试工具和针对本体特殊流程的适配。 |

## 项目状态

当前仓库即为开发副本。需要对比原版行为时，请单独克隆上游项目；不要直接在参考副本中开发或部署。

## 特性

- 本地双人 co-op：P1/P2 独立控制、镜头、HUD 和战斗参与。
- 双人死亡流程：单名玩家死亡后不结束 run，存活玩家可继续清房。
- Boss -> Rest Room 复活：死亡玩家在关底 Boss 后进入 Rest Room 时复活，并保留血量上限、祝福和阿卡那效果。
- 独立信物选择：P1/P2 可分别选择信物，Rest Room 信物柜两人各可使用一次。
- 独立阿卡那：P1/P2 可独立保存和使用各自的预设，即使使用相同 Set 编号也不会互相改写；解锁、等级和悟性继续共享原版存档进度。
- 阿卡那运行时适配：P2 run 开始时能获得自身阿卡那效果；过门类 HP/MP 上限增长、审判和水晶雕像临时加卡已验证双人生效且按玩家隔离。
- Chronos 通关兼容：已验证 P1 存活、P2 存活和双人存活三种状态均可完成结算、领取沙漏并进入 `I_PostBoss01`。
- 普罗米修斯转场兼容：火浪演出期间单名玩家死亡不会再打断 Boss 的落地流程。
- 双奖励：地下、地表主线的普通房、Elite、无 Encounter、哀悼原野 cage/mini、Chaos 与船区船舵奖励已基本验证为双份；主神 boon 的第二份独立按本体规则生成，不复制且不多刷；锤子按玩家武器池生成，同武器时 P2 不再复制 P1 列表。
- 双人互动开发中：P1/P2 可各使用一次恢复泉水；NPC boon 事件会在 P1 选择后为 P2 打开第二份列表。
- NPC 助战奖励覆盖：Echo、Arachne、Narcissus、Medea、Circe、Icarus，以及 Artemis、Athena、Dionysus、Hades 的助战奖励路径。

## 安装

### 测试者快速安装

首轮测试请使用发布包中的 `Hades2CoopInstaller.exe`，无需安装开发工具或运行 PowerShell：

1. 完全退出 Hades II。
2. 先阅读压缩包根目录的 `README.md`，再解压 `Hades2Coop-v0.2.3-TestBuild.zip`，保持 `Hades2CoopInstaller.exe`、`TN_CoopMod` 与 `Dependencies` 在同一目录。
3. 运行安装器，选择 `<Hades II>\Ship\Hades2.exe`。
4. 点击“安装 / 更新 Mod”。

安装器会写入 `<Hades II>\Content\Mods\TN_CoopMod`，并将敌人生命值工具安装到 `<Hades II>\Ship\Hades2CoopEnemyScaler.exe`；可在同一界面卸载，不会修改游戏本体或删除存档。详细中英文测试说明见发布包根目录的 `README.md`。

### 前置依赖

- Windows
- Steam 版 Hades II
- Visual Studio 2022 Build Tools 或 Visual Studio 2022 Community
- CMake
- PowerShell

mod 部署目标：

```text
<Hades II>\Content\Mods\TN_CoopMod
```

### 构建与部署

从当前工作副本运行：

```powershell
Set-Location 'C:\path\to\hades2-coop-expanded'
.\scripts\build_and_deploy.ps1
```

首次安装或完整环境检查可运行：

```powershell
.\scripts\install_all.ps1
```

## 快速开始

1. 构建并部署 mod：

```powershell
Set-Location 'C:\path\to\hades2-coop-expanded'
.\scripts\build_and_deploy.ps1
```

2. 启动 Hades II。
3. 从 co-op 入口开始 run。
4. 用两名玩家进入普通战斗房，清房后验证是否出现双份固定奖励。
5. 若一名玩家死亡，验证存活玩家能继续战斗，并在 Boss 后 Rest Room 复活死亡玩家。

## 配置

主要配置文件：

```text
game/scripts/config.lua
```

常用开关：

| 配置 | 说明 |
|------|------|
| `LootDelivery = "Shared"` | 当前奖励分配模式，房间奖励在玩家间轮换 Hero context。 |
| `NormalRoomDoubleRewards = true` | 普通战斗房双固定奖励开关；非 boon 复制，普通 boon 第二份按 P2 的原版奖励规则独立生成，待实机验证。 |
| `ExpandedRoomDoubleRewards = true` | 扩展 Elite、无 Encounter 关键奖励、Chaos 与 Event/NPC-assist 奖励的双发逻辑。 |
| `EnemyScaling.HealthMultiplier = 1.5` | 仅在 Co-op 模式下对敌对单位生命值应用倍率；可用 `Hades2CoopEnemyScaler.exe` 修改。 |
| `Debug.SoftlockTrace = true` | 输出死亡 / Boss softlock 调试信息。 |
| `Debug.RuntimeMonitor = false` | 游戏内实时面板；当前默认关闭，改用独立终端日志观察。 |
| `Debug.ArcanaFullUnlockRepair = false` | 已停用的临时阿卡那界面救援开关；保留模块与调用链以维持兼容性。 |
| `Debug.ArcanaMaxLevelRepair = false` | 已停用的临时阿卡那等级救援开关；不会再改写原版存档等级。 |

## 项目结构

| 路径 | 用途 |
|------|------|
| `game/` | Hades II 本地双人 mod 的 C++ 与 Lua 源码。 |
| `scripts/` | 构建、部署、打包、回滚与日志工具。 |
| `tools/` | 测试者安装器源码。 |
| `docs/` | 架构、部署、测试和项目日志。 |
| `docs/ARCHITECTURE.md` | 中英文架构说明 / Bilingual architecture notes. |
| `docs/PROJECT_LOG.md` | 按日期记录的详细开发日志。 |

## 术语与注意事项

| 术语 | 中文用法 | 说明 |
|------|----------|------|
| `Run` | 一轮 / 一局 | 从进入路线到胜利、死亡或退出的一次完整尝试。 |
| `Layer` | 层 / 大关 | 玩家视角下的一大段区域。 |
| `Room` / `Chamber` | 房间 / 小关卡 | 一次加载的可游玩空间。 |
| `Combat Room` / `Normal Room` | 普通战斗房 | 标准敌人房，当前双奖励优先支持对象。 |
| `Event Room` | 事件房 | NPC、剧情、互动或特殊选择房。 |
| `NPC-assist Event Room` | NPC 助战事件房 | 带 NPC 参与战斗或协助的事件房。 |
| `Chaos Room` | 混沌房 | Chaos 分支或混沌祝福相关房间。 |
| `Shop Room` | 商店房 | Charon / 商店房间。 |
| `Recovery Room` / `Fountain Room` | 回复房 / 泉水房 | 可恢复血量的房间或泉水点。 |
| `Boss Room` | Boss 房 | 关底 Boss 或主要 Boss 战。 |
| `Rest Room` | 层间休息房 | Boss 后进入下一层前的安全房，不等同于普通回复房。 |
| `Door` / `Exit` | 门 / 出口 | 进入下一房间的交互对象。 |
| `Room Reward` | 房间固定奖励 | 清房后出现的主要奖励。 |
| `Boon` | 祝福 | 神明祝福奖励。 |
| `Keepsake` | 信物 | 玩家装备的信物。 |
| `Arcana` | 阿卡那牌 | 原版阿卡那系统。 |

注意：

- 双奖励正在覆盖普通战斗房、Elite、无 Encounter 关键奖励，以及 Chaos/Event/NPC-assist；等待宽范围实机测试。
- 普通战斗房的第二份 boon 已改为 P2 独立走原版 `SetupRoomReward` 规则；需要实机验证神明信物、稀有度和重复神明行为。
- 当前已知：P2 ForceBoon 与稀有度提升已验证生效；Elite、船区、无遭遇战关键奖励和 P2 Spell HUD 仍需要复测。
- 塞萨利裂谷船区只处理点击船舵后的 `GeneratedO`；`GeneratedO_Intro01` 的空奖励不会生成第二份。
- 所有 mod trace 现自动带地点标签，例如 `[Underworld-Layer1-Erebus-CombatRoom-F_Combat12]`；详见 `docs/PROJECT_LOG.md`。
- P2 月神 Spell 的菜单、HUD 创建和换房后状态已增加 `[CoopSpellUiTrace]`，当前仅监测，尚未修改通用 Trait Tray 坐标。
- 2026-07-11：P1 的异常 150 MP 已确认由误附着的 P2 `DigFamiliar +60` 导致；熟灵 HeroContext 修复经实机确认后已恢复正常。
- 2026-07-11：新增游戏内 `CO-OP DEBUG` 面板和带时间戳的 `[CoopDebug]` 奖励日志，用于确认 P1/P2 的 HP/MP、信物、熟灵和 boon 定向 trait。
- 非 boon 奖励、Chaos Room、Event Room、NPC-assist Event Room 可以优先沿用 copy 逻辑。
- 恢复泉水已实现每位存活玩家各一次，等待 P1/P2 顺序与出口状态复测。
- `ArcanaFullUnlockRepair` 和 `ArcanaMaxLevelRepair` 是已停用的临时存档/界面救援方案。验证确认关闭后不会影响独立阿卡那配置或原版共享进度；保留模块与调用链以维持加载兼容性。
- 详细开发过程不要堆在 README，写入 `docs/PROJECT_LOG.md`。
- 当前已知限制：run 结束回到 Hub 后，P1/P2 的 HP/MP HUD 有时不会立即刷新；开始下一轮 run 后会恢复，实际数值与继续游玩不受影响。

## 常见问题

### PowerShell 提示脚本不存在

在当前目录执行脚本时需要加 `.\`：

```powershell
.\scripts\build_and_deploy.ps1
```

### `cmake` 无法识别

安装 Visual Studio 2022 后，可使用脚本自动查找 VS 内置 CMake；若仍失败，检查 Visual Studio 的 C++ 和 CMake 组件是否安装。

### 改了 Lua 后游戏里没变化

重新运行：

```powershell
.\scripts\build_and_deploy.ps1
```

并确认目标目录中 `Content\Mods\TN_CoopMod` 的文件时间已更新。

### 如何读取 co-op 调试状态

默认使用独立 PowerShell 终端观察，运行：

```powershell
Set-Location 'C:\path\to\hades2-coop-expanded'
.\scripts\watch_coop_debug.ps1
```

终端会实时筛选奖励、原野/船区、月神 UI、泉水、NPC、死亡和 Boss 相关行；每行均带可读地点标签。`Ctrl+C` 停止。若需要游戏内面板，可把 `Debug.RuntimeMonitor` 改为 `true`。详细事件日志位于：

```text
%USERPROFILE%\Saved Games\Hades II\TN_CoopMod.log
```

## 贡献

- 当前优先使用 issue/日志描述可复现问题：room name、encounter name/type、死亡玩家、存活玩家、是否 Boss 转阶段、奖励类型。
- 提交代码前先运行 `.\scripts\build_and_deploy.ps1`。
- 不要直接修改参考项目；所有开发改动应进入当前仓库。

## 许可证

当前工作副本继承原项目许可证，详见：

```text
LICENSE.txt
```

## 更新记录

### 2026-07-14

- 首轮测试包已生成：自包含 `Hades2CoopInstaller.exe`、完整 `TN_CoopMod` 和中文测试说明可通过 `build_tester_package.ps1` 打包为 zip。
- 普罗米修斯火浪转场期间单名玩家死亡已实机修复；Boss 会正常落地、恢复模型与可攻击状态。
- Boss -> Rest Room 复活已回归通过；地下和地表两条主线目前基本可双人正常游玩。
- 主神 boon 已基本验证双份、独立生成、不复制且不多刷；月神 Spell 暂按正常运作处理，哀悼原野 `TalentDrop` 仍待专项测试。
- 已知未修复：run 回 Hub 后的 HP/MP HUD 延迟刷新；`F_PreBoss` 中扎格列欧斯挑战奖励尚未双份；哀悼原野 `TalentDrop` 双份仍待专项验证。

### 2026-07-14：v0.2 测试包与阿卡那独立预设

- 已验证 P1/P2 独立阿卡那编辑、持久化、重新读取、run 生效、死亡后保留和 Trait Tray 显示；共享的仅是原版解锁、等级和悟性进度。
- 已验证审判与水晶雕像的 P2 临时加卡。实现复刻本体 `CombatLogic.Kill` 的单位条件，避免以房间名错误识别扎格列欧斯或精英遭遇。
- 已修复同武器双锤子列表复制：P2 在自身 HeroContext 中使用独立同步随机槽生成候选；不同武器路径保持按各自武器池生成。
- 已生成 `Hades2Coop-v0.2.3-TestBuild.zip`，内含自包含安装器、完整 Mod、敌人生命值工具、MIT 许可证和发布包根目录的中英文 `README.md`；测试说明要求保持 `TN_CoopMod.log` 的实时终端开启。

### 2026-07-13

- 修复 Chronos 分阶段 AI 在单名玩家死亡后错误重启的问题；保留本体阶段协程，仅重定向存活玩家目标。
- 修复 Chronos 结算关闭后 P2 输入和镜头残留在死亡 P1 的问题。
- 实机验证 Chronos 的 P1 单独存活、P2 单独存活、双人存活通关流程均可完成：关闭结算页、领取沙漏、进入 `I_PostBoss01`。
- 修复 P2 月神 HUD 换房时误删 P1 组件的问题，并补充满充能边框清理。
- 为哀悼原野直接打开菜单的月神奖励补充第二份生成路径。
- 修复克洛诺斯保留存档的双人读取时序错误，并增加 Boss 黑屏/摄像机恢复点。

### 2026-07-12

- 为哀悼原野的 cage 主奖励、mini 奖励和消耗品补齐专用双奖励路径，并避免 Miniboss 第三份奖励。
- 为塞萨利裂谷船舵后的 `GeneratedO` 建立独立第二奖励生成入口；boon 使用 P2 的本体预选，其他奖励生成独立实体，待实机验证。
- 新增 `[CoopSpellUiTrace]`，追踪 P2 月神菜单、Spell HUD 创建及换房后状态。
- 原生日志出口自动添加区域、层级、房间类型和内部 room 名地点标签。

### 2026-07-11

- 修复自定义奖励函数返回空值导致的船区 / 特殊奖励双发漏判，并扩大 Elite/Miniboss 覆盖。
- 修复 P2 代达罗斯之锤菜单错误读取 P1 武器池。
- 实现恢复泉水每名存活玩家各使用一次。
- 为 NPC boon 事件增加 P1 选择后自动打开的 P2 第二份选择列表。
- 新增外部终端可见的奖励、泉水和 NPC 事件追踪日志。

### 2026-07-10

- 修复 P2 死亡导致普通房 / Boss 房错误窗口和卡关的问题。
- 验证 Boss -> Rest Room 复活、死亡输入锁、Boss 转阶段后继续战斗。
- 验证过门 HP/MP 上限阿卡那双人生效。
- 新增并验证普通战斗房双固定奖励；非 boon 奖励复制第一份。
- 普通房与开局免费 boon 的第二份 boon 改为 P2 独立走原版奖励规则，待实机验证。

### 2026-07-09

- 验证 P1/P2 信物选择独立。
- 实现 Rest Room 信物柜 P1/P2 各使用一次。
- 修复并验证阿卡那界面与等级救援方案。

### 2026-07-08

- 更新开发工作副本路径。
- 修复并整理开发部署脚本。

### 2026-07-07

- 建立顶层文档：`README.md`、`TODO.md`、`PROJECT_LOG.md`、`SESSION_NOTES.md`。
- 记录房间术语、复活目标和当前架构。
