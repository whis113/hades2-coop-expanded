# Hades II Co-op v0.2 Test Build / Hades II 双人 Mod v0.2 测试版

> Test build. Back up saves before use. / 测试版本。使用前请备份存档。

## Scope and Attribution / 功能来源与归属

This package is based on the upstream **Hades II coop mod** by Hades2-coop-project.

本测试包基于 Hades2-coop-project 的 **Hades II coop mod** 原项目。

### Provided by the upstream project / 原项目提供

- The local two-player foundation: co-op entry point, two controllable heroes, controller-based local play, and the base local co-op architecture.
- 本地双人基础框架：合作入口、两个可控制角色、手柄本地游玩，以及基础合作架构。
- This is local co-op on one PC. Online play is not included; use a streaming solution such as Parsec if needed.
- 本 Mod 是单机本地合作，不包含联网功能；如需远程游玩，请自行使用 Parsec 等串流工具。

### Added or substantially changed in this project / 本项目新增或重点修改

- Per-player death handling: one surviving player can continue; the dead player returns at the following layer-transition Rest Room while retaining their run state.
- 独立死亡处理：一名玩家存活时可继续；死亡玩家会在下一层间 Rest Room 回归，并保留本局状态。
- Boss death/phase/transition handling for co-op, including Chronos end-run recovery.
- 合作模式下的 Boss 死亡、转阶段与过场处理，包括 Chronos 通关流程恢复。
- Independent P1/P2 keepsake selection and separate use of Rest Room keepsake cabinets and fountains.
- P1/P2 独立选择信物；Rest Room 信物柜和泉水可分别使用。
- Independent P1/P2 Arcana loadouts, including separate layouts even when both players use the same set number. Arcana unlocks, card levels, and grasp progression remain shared save progress.
- P1/P2 独立阿卡那配置；即使使用相同 set 编号也可装备不同卡牌。解锁、卡牌等级和悟性仍是共享存档进度。
- P2 support for temporary Arcana-card effects such as Judgment and Circe's Crystal Figurine, following native Boss-kill conditions.
- P2 支持审判、水晶雕像等临时阿卡那加卡效果，并跟随本体 Boss 击杀条件。
- Expanded two-player rewards across standard combat, Elite, Chaos, many event/NPC rewards, Fields of Mourning, and Thessaly Rift ship rewards.
- 扩展普通战斗、精英、Chaos、多个事件/NPC、哀悼原野和塞萨利裂谷船区的双人奖励。
- Independent second boon generation where supported, individual weapon hammer pools, and a distinct P2 hammer list when both players use the same weapon.
- 在支持的场景独立生成第二份主神祝福；锤子按玩家武器生成，且同武器时 P2 列表不会直接复制 P1。
- Debug traces with route/room labels for reporting issues.
- 带路线和房间标签的调试日志，便于反馈问题。

## Included and Verified in v0.2 / v0.2 已实现并验证

- P1/P2 can configure, save, reload, and run different Arcana loadouts.
- P1/P2 可配置、保存、重新读取并运行不同的阿卡那配置。
- P2 Arcana effects, Rest Room revival retention, Judgment, and Crystal Figurine work independently.
- P2 的阿卡那效果、Rest Room 复活保留、审判和水晶雕像可独立生效。
- P1/P2 can independently change keepsakes in Rest Rooms.
- P1/P2 可以在 Rest Room 独立更换信物。
- One-player death no longer blocks normal rooms or tested Boss encounters; tested underground and surface routes are playable as co-op runs.
- 单人死亡不再阻塞普通房和已测试 Boss；地下与地表路线均已具备双人可玩流程。
- Common rewards, most boon rewards, Elite rewards, Chaos rewards, Fields rewards, ship rewards, fountains, and weapon hammers have co-op coverage.
- 普通奖励、多数祝福、精英、Chaos、原野、船区、泉水和锤子均已有双人覆盖。

## Not Completed or Needs More Coverage / 未完成或仍需更多测试

- Online networking is not planned in this package; it is local co-op only.
- 不含联网功能，仅支持本地合作。
- Zagreus challenge rewards that appear in `F_PreBoss` are not yet doubled.
- 扎格列欧斯挑战后在 `F_PreBoss` 出现的奖励尚未实现双份。
- Fields of Mourning `TalentDrop` double-reward flow needs dedicated verification.
- 哀悼原野的 `TalentDrop` 双份流程仍需专项验证。
- Some rare NPC/event combinations still need broad regression testing, especially Dionysus.
- 少数 NPC/事件组合仍需广泛回归测试，尤其是狄奥尼索斯。
- The legacy Arcana full-unlock/max-level recovery compatibility path has not yet been removed. Non-full-progression saves need careful testing.
- 旧版“阿卡那全解锁/满级恢复”兼容路径尚未移除；非全解锁或非满级存档需要谨慎测试。
- After a run ends, HP/MP HUD values may not refresh immediately in the Hub. Starting the next run restores the HUD; underlying gameplay values are unaffected.
- Run 结束回到 Hub 后，HP/MP HUD 有时不会立即刷新；开始下一局会恢复，不影响实际数值。

## Installation / 安装

1. Fully exit Hades II. / 完全退出 Hades II。
2. Extract the entire archive. Keep `Hades2CoopInstaller.exe` and `TN_CoopMod` together. / 解压完整压缩包，保持 `Hades2CoopInstaller.exe` 与 `TN_CoopMod` 位于同一目录。
3. Run `Hades2CoopInstaller.exe`. / 运行 `Hades2CoopInstaller.exe`。
4. Select `Ship\Hades2.exe`, then choose **Install / Update Mod**. / 选择 `Ship\Hades2.exe`，点击“安装 / 更新 Mod”。
5. Start the game and use the co-op entry point. / 启动游戏，从合作入口开始双人 run。

The installer writes only to `<Hades II>\Content\Mods\TN_CoopMod`; it does not modify game files or delete saves.

安装器只写入 `<Hades II>\Content\Mods\TN_CoopMod`，不会修改游戏本体文件或删除存档。

## Uninstall / 卸载

Exit the game, run the installer again, select the same `Hades2.exe`, and choose **Uninstall Mod**.

退出游戏后再次运行安装器，选择同一个 `Hades2.exe`，点击“卸载 Mod”。

## Test Checklist / 建议测试项目

- Keep a debug-log terminal open while testing. In PowerShell, run the following command before launching the game; it will continuously print new Mod log lines. / 测试时请保持调试日志终端开启。启动游戏前在 PowerShell 运行以下命令，它会持续输出新增的 Mod 日志。

```powershell
Get-Content "$env:USERPROFILE\Saved Games\Hades II\TN_CoopMod.log" -Wait
```

- If the log file does not exist yet, start the game once with the Mod enabled, then run the command again. / 若日志文件尚不存在，请先启用 Mod 启动一次游戏，再重新运行该命令。
- Test a run on both underground and surface routes. / 地下与地表路线各测试一局。
- Test one player dying in a normal room and during a Boss fight. / 分别测试普通房和 Boss 战中的单人死亡。
- Test different and identical weapons with a double hammer reward. / 用不同武器和相同武器分别测试双锤子。
- Test different Arcana layouts, Judgment, and Crystal Figurine. / 测试不同阿卡那配置、审判和水晶雕像。
- Test a Rest Room keepsake swap and fountain with both players. / 测试两人使用 Rest Room 信物柜和泉水。

## Bug Reports / 问题反馈

Please include the route, room label, P1/P2 state, reward/trait involved, reproduction steps, screenshot/video, and relevant log excerpt.

反馈请附上路线、房间标签、P1/P2 状态、涉及的奖励或效果、复现步骤、截图/录像及相关日志片段。

```text
C:\Users\<USER>\Saved Games\Hades II\TN_CoopMod.log
```

## License and Credits / 许可证与致谢

The upstream project is licensed under MIT; see `LICENSE.txt` in this package. This test build retains upstream copyright notices.

原项目采用 MIT 许可证；请参阅包内 `LICENSE.txt`。本测试版保留原项目版权声明。
