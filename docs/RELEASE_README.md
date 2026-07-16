# Hades II Co-op Expansion v0.2.4

Local two-player co-op expansion for Hades II. This package extends the upstream `hades2-coop` local co-op framework with gameplay rules, reward handling, and compatibility fixes for a full roguelike run.

## Install

1. Back up your Hades II save files before installing or testing this mod.
2. Fully exit Hades II.
3. Extract the entire ZIP without separating `Hades2CoopInstaller.exe`, `Hades2CoopEnemyScaler.exe`, `TN_CoopMod`, or `Dependencies`.
4. Run `Hades2CoopInstaller.exe`.
5. Select `<Hades II>\Ship\Hades2.exe` and choose **Install / Update Mod**.
6. Start Hades II and select the Co-op entry from the main menu.

The installer deploys the enemy HP tool to:

```text
<Hades II>\Ship\Hades2CoopEnemyScaler.exe
```

## What This Expansion Adds

The upstream `hades2-coop` project provides the local P1/P2 framework. This expansion adds:

- Boss-to-Rest Room revival. A dead player revives at 30% of their retained maximum HP after the layer boss.
- Independent P1/P2 Keepsakes, one Rest Room keepsake-rack use per player, and one fountain use per player.
- Independent P1/P2 Arcana loadouts, including different card selections in the same layout slot. Native Arcana unlocks, levels, grasp, resources, and tutorials remain shared.
- Per-player temporary Arcana effects from Judgment and Circe's Crystal Figurine.
- Broad dual-reward support for normal rooms, Elite rooms, Chaos, Fields, ship-wheel rewards, and most NPC/event paths. The second god boon is independently generated; hammer choices use each player's weapon pool.
- Death, Boss, menu, spell HUD, and Chronos/Prometheus compatibility fixes.
- Native door-transition base mana refill for both living players, without requiring an Arcana card or item.
- Co-op-only hostile enemy HP scaling. The default is `1.5x`; use `Ship\Hades2CoopEnemyScaler.exe` while the game is closed to change it.

## Changes Since v0.2.3

- Restored the game's normal door-transition mana refill for both living players. The native refill runs once in each living player's context, reaches that player's available mana maximum, and excludes dead players.
- Added one transition-scoped `[CoopDoorManaTrace]` line for before/after mana diagnostics. It is not a passive regeneration trace and is independent of room-progress Arcana handling.

## Important Notes

- Back up your save files before using this mod.
- This mod is still experimental. Errors or crashes may occur; in many cases, exiting the game and loading the save again resolves the immediate problem.
- Please report bugs or unreasonable behavior through the project's GitHub Issues page: <https://github.com/whis113/hades2-coop-expanded/issues>.
- When selecting Co-op with a keyboard/mouse plus controller setup, move the mouse away before confirming with the controller.
- Two-player combat is easier than solo play, so hostile enemy HP defaults to `1.5x` in Co-op. Adjust it with `<Hades II>\Ship\Hades2CoopEnemyScaler.exe` while Hades II is closed.
- Selene rewards: once one player has a Hex, ensure the other player also selects a Hex before taking another Selene reward. Later Selene rewards are upgrades; a player without a Hex may encounter a selection/UI issue or may be unable to claim the reward correctly.
- If a save is currently inside a run, reload it using the same mode used when it was saved. For example, a run saved in solo mode must be resumed through the solo entry; loading it through the Co-op entry can cause an error.

## Still Being Verified

- Hub HP/MP UI may not refresh immediately after a run, although the underlying values are correct.
- `F_PreBoss` Zagreus challenge rewards intentionally remain single-reward.
- Fields of Mourning `TalentDrop` dual-reward behavior still needs dedicated regression testing.
- Rare NPC/event combinations, especially Dionysus, need broader external regression coverage.

## Debug Log and Bug Reports

Keep a PowerShell terminal open during testing:

```powershell
Get-Content "$env:USERPROFILE\Saved Games\Hades II\TN_CoopMod.log" -Wait
```

When reporting a problem, include the route, room label, P1/P2 state, reproduction steps, screenshots or video, and relevant log lines.

## Uninstall

Fully exit Hades II, run `Hades2CoopInstaller.exe`, select the same executable, then choose **Uninstall Co-op Mod**. This removes `TN_CoopMod` and `Ship\Hades2CoopEnemyScaler.exe`; shared loader dependencies remain to avoid breaking other mods.

---

# Hades II Co-op Expansion v0.2.4（中文）

这是一个 Hades II 本地双人扩展包。在原项目 `hades2-coop` 提供的 P1/P2 本地双人框架基础上，本扩展加入了更适合完整肉鸽流程的玩法规则、奖励处理和兼容性修复。

## 安装

1. 安装或测试前，请先备份 Hades II 存档。
2. 完全退出 Hades II。
3. 解压完整 ZIP，不要拆开 `Hades2CoopInstaller.exe`、`Hades2CoopEnemyScaler.exe`、`TN_CoopMod` 与 `Dependencies`。
4. 运行 `Hades2CoopInstaller.exe`。
5. 选择 `<Hades II>\Ship\Hades2.exe`，点击 **Install / Update Mod**。
6. 启动 Hades II，在主菜单选择 Co-op 入口。

安装器会将敌人生命倍率工具安装到：

```text
<Hades II>\Ship\Hades2CoopEnemyScaler.exe
```

## 本扩展新增内容

原项目 `hades2-coop` 提供本地 P1/P2 双人框架；本扩展新增：

- 区域守卫后进入 Rest Room 的复活：死亡玩家保留原有最大生命，并以最大生命的 30% 复活。
- P1/P2 独立信物、每位玩家各一次 Rest Room 信物柜使用权，以及每位玩家各一次泉水使用权。
- P1/P2 独立阿卡那预设：即使使用同一个 Set 槽位，也可以保存不同的卡牌配置。原版解锁、等级、悟性、资源和教程进度继续共享。
- 审判与喀耳刻水晶雕像的临时阿卡那效果按玩家隔离。
- 普通房、精英房、混沌、哀悼原野、船舵奖励与大多数 NPC/事件房的双奖励支持。第二份主神 boon 独立生成；锤子候选按各自武器池生成。
- 死亡、Boss、菜单、月神 HUD，以及 Chronos/Prometheus 流程的兼容性修复。
- 仅 Co-op 生效的敌对单位生命倍率。默认 `1.5x`；游戏关闭时可使用 `Ship\Hades2CoopEnemyScaler.exe` 调整。

## 相较 v0.2.3 的更新

- 已恢复原版过门基础 MP 回满：任一存活玩家过门时，P1/P2 都会在各自上下文执行一次原版回满，达到各自可用 MP 上限；不依赖阿卡那或道具，死亡玩家不参与。
- 每次 Transition 新增一条 `[CoopDoorManaTrace]` MP 前后诊断。它不是被动回蓝监测，并与房间推进阿卡那逻辑独立。

## 注意事项

- 使用本 Mod 前，请务必备份存档。
- 本 Mod 仍处于测试阶段，可能遇到报错或闪退。多数情况下，退出游戏后重新读档可以恢复当前进度。
- 遇到 Bug，或认为某些行为不合理时，请在 GitHub Issues 反馈：<https://github.com/whis113/hades2-coop-expanded/issues>。
- 使用键鼠加手柄选择 Co-op 时，手柄点击确认前请将鼠标移开。
- 双人战斗会明显降低原版难度，因此 Co-op 中敌对单位生命默认调整为 `1.5x`。如有需要，请在完全退出 Hades II 后使用 `<Hades II>\Ship\Hades2CoopEnemyScaler.exe` 调整。
- 月神奖励：一名玩家已经拥有咒语后，另一名玩家也应先取得一个咒语，再拾取后续月神奖励。后续月神奖励会变为升级；没有咒语的玩家拾取时，可能出现选择/UI 异常，或无法正确领取奖励。
- 如果存档仍在一局 Run 中，读档时必须使用与保存时相同的模式。例如：单人模式保存的 Run 必须从单人入口继续；通过 Co-op 入口读取可能报错。

## 仍在验证

- Run 结束回 Hub 后，HP/MP UI 有时不会立即刷新，但实际数值正确。
- `F_PreBoss` 的扎格列欧斯挑战奖励按设计维持单份。
- 哀悼原野 `TalentDrop` 的双奖励仍需专项回归测试。
- 罕见 NPC/事件组合仍需更广泛的外部回归测试，尤其是 Dionysus。

## 调试日志与问题反馈

测试时请保持一个 PowerShell 日志窗口：

```powershell
Get-Content "$env:USERPROFILE\Saved Games\Hades II\TN_CoopMod.log" -Wait
```

`CoopDoorManaTrace` 只在过门时输出一次。为保持测试日志聚焦，`CoopSpellUiTrace` 与 `CoopArcanaAudit` 当前暂时关闭。

反馈问题时请提供路线、房间标签、P1/P2 状态、复现步骤、截图或视频，以及相关日志行。

## 卸载

完全退出 Hades II 后，运行 `Hades2CoopInstaller.exe`，选择同一个游戏可执行文件，再点击 **Uninstall Co-op Mod**。该操作会移除 `TN_CoopMod` 和 `Ship\Hades2CoopEnemyScaler.exe`；共享加载器依赖会保留，以免影响其他 Mod。
