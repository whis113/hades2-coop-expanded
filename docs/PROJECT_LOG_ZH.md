# 项目日志

> 英文版本：[`PROJECT_LOG.md`](PROJECT_LOG.md)。两份日志按日期对应维护。

## 说明

本日志的英文版本为 [`PROJECT_LOG.md`](PROJECT_LOG.md)。只记录功能开发、问题定位、测试结果和发布；文档同步及路径迁移不记录。历史路径和已废弃方案只在解释技术决策时保留。

## 2026-07-15

### 阿卡那进度保护：已验证

- 实测关闭 `ArcanaFullUnlockRepair` 与 `ArcanaMaxLevelRepair` 后，P1/P2 独立阿卡那预设及运行时效果保持正常。
- 扩展不再改写原版共享的阿卡那解锁、等级、悟性、教程状态或资源。为保持兼容性，仍保留 `GameStateEx` 模块与 Hook 调用链；此前直接移除会导致读取存档报错且 P2 无法创建。

### Co-op 敌人生命倍率：待实机验证

- 已定位本体统一生命值入口：敌人模板位于 `EnemyData`，`RoomLogic.SetupUnit()` 会在完成原版精英与誓约修正后写入 `unit.MaxHealth` 和 `unit.Health`。
- 新增仅在 Co-op 模式加载的 `SetupUnit()` 后置 Hook，默认将敌对单位生命值乘以 `1.5`；中立、魅惑和友方单位不受影响。
- 新增 `Hades2CoopEnemyScaler.exe`，用户选择 `Ship/Hades2.exe` 后可修改已安装 Mod 的 `TN_CoopMod/config.lua`，不会改写游戏本体或存档。

### v0.2.3 外部测试包 / v0.2.3 External Test Package

- 已生成 v0.2.3：包含自包含安装器、完整 Mod、`Hades2CoopEnemyScaler.exe` 和发布包根目录的中英文 `README.md`。
- 安装器会将敌人生命值工具部署到 `<Hades II>\Ship\Hades2CoopEnemyScaler.exe`，卸载时一并移除。
- 发布包根目录新增中英文提醒文件，要求测试者安装前阅读 `README.md`。
- 敌人生命值工具已替换为原生 Win32 EXE，保留英文文件选择界面，体积约为 351 KiB。
- 包 SHA-256：`80632434633D429D83BA48626779D3DAC55850AD341C2B09DA4974F9182F0056`。

## 2026-07-14

### v0.2 测试包、独立阿卡那与锤子候选：已验证并发布 / v0.2 Test Package, Independent Arcana, and Hammer Choices: Verified and Released

归属说明：原项目提供 P1/P2 创建、控制器、角色、镜头、HeroContext、代理和 hook 基础框架；以下均为当前扩展实现，不应归因于原项目。

- 独立阿卡那预设已实机通过：P1/P2 即使选择同一 Set 编号，仍可保存不同装备；重开页面、重启读取、进入 run、死亡后 Boss -> Rest Room 复活和 Trait Tray 均保持各自效果。
- 共享边界已确认：`MetaUpgradeState` 的解锁、等级、悟性和资源保持原版共享；P2 只保存独立 `Equipped` 集合和当前 Layout。
- 审判和水晶雕像已实机通过。P2 临时加卡写入 `CurrentRun.CoopTemporaryMetaUpgrades[2]`，不会污染 P1 或 P2 保存预设。
- 初版按 `EndEncounterEffects` 补偿 P2 会把扎格列欧斯/精英等泛 Boss 路径误判为区域守卫；最终改为复刻本体 `CombatLogic.Kill` 中的 `IsBoss`、`BlockPostBossMetaUpgrades`、组血条拥有者和流程层数条件。
- 同武器双锤子列表复制已修复。根因是本体菜单每次用 `LootTypeHistory[WeaponUpgrade]` 重置相同随机 seed；P2 现在在自身 HeroContext 中预生成独立候选。不同武器继续按各自武器池生成。
- 发布包已更新为 `release/Hades2Coop-v0.2-TestBuild.zip`，包含自包含安装器、完整 `TN_CoopMod`、`LICENSE.txt` 和双语 `TESTER_README.md`。README 明确列出原项目/当前扩展归属、已实现功能、未完成项、安装卸载和实时日志命令。
- v0.2 ZIP SHA-256：`C72626A65B6FA1E1529564F34194918089F66B7284712A9D469CBC41B1ED08BB`。

### 独立阿卡那预设：阶段 1 基线与回撤

- 新增 `arcana_checkpoint.ps1`，创建 `checkpoints/pre-independent-arcana-20260714`。checkpoint 保存阿卡那改动面源码和当前完整 Mod payload；不依赖 Git，因此不会覆盖工作区中无关的未提交改动。
- `arcana_checkpoint.ps1 -Action Restore` 会在游戏关闭时恢复 checkpoint 源码和部署目录 `Content/Mods/TN_CoopMod`。后续独立阿卡那实现可随时回到当前已验证版本。
- 新增 `logic/CoopArcana.lua`。当前只建立 `GameState.CoopArcanaLoadouts.Players[2].Layouts`：P2 各预设槽独立保存 `Equipped` 卡牌集合和当前槽位；首次初始化从 P1 当前共享配置复制一次，之后不覆盖。
- 不复制或代理 `MetaUpgradeState`；解锁、等级、悟性、资源、卡牌布局与教程仍只走原版单份 `GameState`。
- 已接入 P2 编辑页面与运行时装备：P2 打开阿卡那页时使用临时 `MetaUpgradeState`、`SavedMetaUpgradeLayouts`、当前 Layout 和卡牌布局；关闭页面后仅把临时装备结果写回 P2 `Layouts`，随后恢复 P1 的原版全局状态。
- P2 编辑期间拦截本体的存档请求，并在恢复 P1 状态后再保存；同时禁止 P2 在该页执行解锁、卡牌升级和悟性上限购买，永久进度继续完全共享。
- 新增 `[CoopArcanaEditor] open/save-deferred/close`、`[CoopArcanaAudit] editor-closed:P2` 与 `[CoopArcanaRuntime]`。该阶段已部署，等待实机确认 P2 切换 Set 不再改变 P1，以及 P2 新 run 的 trait 实际生效。
- 运行时临时加卡修复已部署：水晶雕像、审判和喀耳刻随机加卡都会经 `AddRandomMetaUpgrades()` 修改本局卡牌；P2 现在使用 `CurrentRun.CoopTemporaryMetaUpgrades[2]`，不会再改写 P1 的共享 Set。Boss 后事件会额外按 P2 自己的审判/水晶雕像 trait 重放本体加卡段；待实机验证。

### 首轮外部测试包

本项是当前扩展的测试交付工具，不属于原项目 `hades2-coop` 的双人系统构造。

- 新增 `tools/TesterInstaller/Hades2CoopInstaller.csproj` 与自包含 WinForms 安装器。
- 安装器要求测试者选择 `<Hades II>\Ship\Hades2.exe`，只会安装、更新或卸载 `<Hades II>\Content\Mods\TN_CoopMod`。
- 安装前检测 `Hades2.exe` 是否仍在运行；更新使用 staging/backup 目录切换，失败时恢复旧 Mod。
- 历史说明（已由 v0.2 替代）：早期脚本曾复制 `TESTER_README_zh-CN.md` 并生成 `release\Hades2Coop-TestBuild.zip`。当前脚本复制双语 `TESTER_README.md` 并生成 `release\Hades2Coop-v0.2-TestBuild.zip`。
- Historical note (superseded by v0.2): the early script copied `TESTER_README_zh-CN.md` and created `release\Hades2Coop-TestBuild.zip`. The current script copies bilingual `TESTER_README.md` and creates `release\Hades2Coop-v0.2-TestBuild.zip`.

### 玩法回归与首测状态

- 普罗米修斯火浪转场期间单名玩家死亡已修复：`RunHooks.lua` 识别 `PrometheusMemoryPresentation`，不再强行唤醒该 Boss 的普通 AI 等待，从而保留本体落地和解除无敌流程。实机通过。
- Boss -> Rest Room 复活已回归通过，死亡玩家保留血量上限、祝福和阿卡那运行时效果。
- 月神 Spell 暂定为正常运作；`TalentDrop` 除哀悼原野外已通过，哀悼原野仍待专项验证。
- 主神 boon 基本覆盖双份，第二份独立生成，不再出现稳定的复制或多刷问题。
- 地下与地表双线目前基本可双人正常游玩。
- 已知限制：run 回 Hub 后 P1/P2 HP/MP HUD 有时不立即刷新，开始下一轮 run 后恢复；独立阿卡那配置尚未开工。

## 2026-07-13

### Chronos 通关流程：三种存活状态验证通过

本项属于当前扩展对 Hades II 特殊 Boss/结算流程的兼容修复，不属于原项目提供的双人系统构造。

问题与根因：

- P1 死亡后，Chronos 的长期本体 AI 协程仍可能读取死亡的 P1 上下文；此前重启 Boss AI 又会从阶段一重新执行，造成 Boss 消失、无敌或转阶段卡住。
- P2 单独存活并关闭结算页后，恢复逻辑曾把镜头锁回死亡 P1，且 P1 的死亡输入锁会干扰原生菜单手柄热切换。

本轮实现：

- `HeroContext.lua`：已死亡的协程上下文会回退到存活的默认英雄，保证长期战斗协程继续读取正确玩家。
- `RunHooks.lua` / `RunEx.lua`：死亡时只释放 Boss 等待、重定向目标并中断当前攻击以重新选目标；不再重启有 `AIStages` 的 Boss。
- `MenuHooks.lua` / `ChronosRecovery.lua`：P2 持有结算页时临时移除 P1 死亡输入锁；关闭后恢复存活者的镜头、移动和战斗状态。

实机结论：

- 仅 P2 存活：通过。
- 仅 P1 存活：通过。
- P1/P2 都存活：通过。
- 三种情况均完成“击败 Chronos -> 关闭结算页 -> 领取沙漏 -> 进入 `I_PostBoss01`”。

### 文档归属边界修正

统一约定：原项目 `hades2-coop` 提供本地双人系统构造，包括 P2 创建、控制器、角色单位、镜头、HeroContext、代理隔离、线程隔离、基础 HUD 和 hook 框架。本项目日志中的“实现/新增”只指当前扩展在此基础上的玩法、兼容修复和调试工具。

当前扩展归属：Boss -> Rest Room 复活、死亡状态修复、信物柜独立使用、阿卡那运行时适配、房间/原野/Chaos/船区/NPC 奖励双发、泉水双人使用、菜单控制修复和地点调试标签。

### 玩法回归测试进展：2026-07-13

- Chaos 双 boon 已实机通过。
- 过门类阿卡那已实机通过：两个存活玩家会正确获得房间推进效果与 HP/MP 上限变化。
- 阿卡那仍保留一个独立问题：mod 为什么会影响阿卡那系统自身的解锁、等级、布局或存档状态，原因尚未明确；后续目标仍是让 mod 不干预该系统。
- NPC 双奖励除 Dionysus 外均已验证正常；Narcissus 按当前范围维持原版单份奖励，不实现双份。

### 奖励与菜单控制复测后的修复：已部署，待验证

测试结论：

- 哀悼原野奖励已全覆盖；NPC 助战房单人死亡不再卡关。
- 船区 `O_Combat14 / GeneratedO` 的石榴只生成首份，缺少第二份路径日志。
- 喀尔刻 P1 先选可能崩溃；哈迪斯奖励会重复且 P2 无法操作。
- P2 在 boon/reward 选择中打开其他界面后，返回原菜单会失去控制权。
- P2 拾取同神 boon 时可出现重复候选项。

代码改动：

- `UpgradeChoiceHooks.lua`：NPC 第二选择不再固定给 P2；首位选择者完成后，由另一位存活玩家获得第二列表。房间级 `CoopNpcSecondChoiceStarted` 防止第二份菜单递归开启，NPC 收尾回调只在第二次选择后执行。
- `MenuHooks.lua`：改为菜单 owner 栈。子界面关闭后恢复父菜单玩家的手柄控制，全部菜单关闭才还原游戏控制；新增 `[CoopMenuControlTrace]`。
- 主神 boon、锤子和 Chaos 打开前均按当前拾取者清除候选缓存，避免 P2 复用 P1 同神 boon 列表；新增 `CoopChoiceTrace` 的 `god` 标记。
- `InteractLogicHooks.lua`：`UseLoot()` 路径的 `SpellDrop` / `TalentDrop` 也保存实际拾取者并输出 `[CoopSpellTrace] pickup-via-loot`。
- `LootShared.lua`：船区第二奖励未触发时输出 `[CoopShipsRewardTrace] second-skip`，包含奖励类型、开关和房间标记，供下一次确定漏发条件。

### P2 Spell 与船区奖励复测：2026-07-13

测试确认：

- P2 在奖励详情页进入、退出嵌套界面后，手柄控制权会正确恢复给 P2；`CoopMenuControlTrace` 的 owner 栈成对闭合。该菜单控制问题已解决。
- P2 月神 `SpellPotionTrait` 在换房后仍保有 anchor，但被记录为非 active 组件；同时 P1 的 `SpellLeapTrait` 会在 P2 上下文残留期间被错误归因，无法据旧日志判断真实位置。
- 船区 `GeneratedO` 的石榴已出现双份；主神 boon 仍只出现首份。

本轮代码改动：

- `UIHooks.lua`：Spell trace 改为按 trait 实际所属 hero 判定玩家，并同时检查 `ActiveTraitComponents` 和 `SlottedTraitComponents`；不再把 P1 Spell 误记为 P2。
- `UIHooks.lua`：P2 的槽位型 trait 使用镜像后的右侧 tray 坐标，包含月神 Spell，目标位置为 P2 HP/MP 条上方；没有改动通用 boon/trait tray。
- `LootShared.lua`：船区第二份奖励新增 `second-start`、`second-boon-preselect` 两段 trace，可精确区分入口未调用、P2 boon 预选失败与本体未落地三种情况。

已执行 `build_and_deploy.ps1`，部署文件：`hooks/UIHooks.lua`、`logic/loot/LootShared.lua`。

### 原野月神、P2 Spell HUD 与 Chronos 恢复：已部署，待验证

本轮日志确认：

- 原野 cage 中的 `SpellDrop` 会直接打开 `OpenSpellScreen()`，不经过 `UseLoot()` / `UseConsumableItem()`，因此原野第二奖励入口未触发。
- P2 换房后的旧 Spell anchor 可能已被本体复用为 P1 的新组件；此前无条件销毁旧 ID 会误删 P1 图标，并让 `DarkSorceryReady` 满充能边框留在屏幕中央。
- 双人读取克洛诺斯击败后的保留存档时报错于 `HUDLogic.lua:268`：恢复死里逃生图标时 `HUDScreen` 尚未创建。存档本身可由单人入口读取，不是存档损坏。
- 克洛诺斯黑屏发生在 `MixerIBossDrop` 已生成、`EndEarlyAccessPresentation` 尚未开始的阶段，恢复点应放在 Boss 奖励生成和房间读档演出结束处。

代码改动：

- `MenuHooks.lua` / `InteractLogicHooks.lua`：在原野首个月神菜单打开前保留生成点，菜单完成后为另一名存活玩家生成第二份 `SpellDrop` / `TalentDrop`；移除重复的 `OpenTalentScreen` 包装。
- `UIHooks.lua`：P2 Spell 重建按玩家独立 HUD 注册表判断组件，只销毁不属于 P1 的旧对象；同时停止安全旧 anchor 上的满充能动画。
- `UIHooks.lua`：读档期间 `HUDScreen == nil` 时延后 `CreateLifePip()`，避免双人入口把运行时 Lua 错误误报为损坏存档。
- 新增 `logic/ChronosRecovery.lua`：在不修改存档进度的前提下清理 Boss 黑幕、输入锁、计时锁、角色淡出和摄像机锁；`ChronosKillPresentation()` 全程绑定主英雄上下文。

保护措施：已备份 `Profile1.sav.codex-chronos-black-screen-20260713-1430`。构建、部署及全部 Lua 5.2 语法检查通过。

## 2026-07-12

### 调试日志地点标签：已部署

`CoopAppendTraceLog()` 现在会自动从 `CurrentRun.CurrentRoom` 读取区域和房间信息，为所有 mod trace 添加统一前缀：

- 地下：`F/G/H/I` 分别映射为 `Underworld-Layer1-Erebus`、`Layer2-Oceanus`、`Layer3-Fields`、`Layer4-Tartarus`。
- 地表：`N/O/P` 分别映射为 `Surface-Layer1-Ephyra`、`Layer2-Rift`、`Layer3-Olympus`。
- 房间类别：自动识别 `CombatRoom`、`EliteRoom`、`BossRoom`、`ShopRoom`、`RestRoom`、`EventRoom`、`OpeningRoom`；同时保留原始 room 名。

示例：`[Underworld-Layer1-Erebus-CombatRoom-F_Combat12] [CoopRewardTrace] ...`。
无 run 或无房间上下文时分别标记为 `[NoRun]`、`[NoRoom]`，特殊房间使用 `[Special-...]`，以避免错误归类。

### P2 月神 Spell HUD 换房监测：已部署，待定位

已按“先捕捉、后单独固定”的方向处理，尚未调整任何 Trait Tray 或祝福列表坐标。

- 新增 `[CoopSpellUiTrace]`：记录 P2 月神菜单打开/关闭、`TraitUIAdd()`、`CreateSpellHUD()`，包括菜单 owner、当前 HeroContext、Spell 名称、trait、anchor、组件 offset 和附属数字组件 ID。
- `roomPresentationFinished` 在换房演出结束时和 `0.4` 秒后各记录一次 P2 Spell HUD 快照，用于判断图标是否在本体 HUD 重建中丢失、移动或保留了失效锚点。
- `watch_coop_debug.ps1` 已纳入 `CoopSpellUiTrace`。

下一轮只需让 P2 获得一次 `SpellDrop` 或 `TalentDrop`，再通过一个门；提供从 `menu-open` 到下一房 `room-presentation-settled` 的完整 trace。确认 anchor/offset 的变化后，仅为 P2 的 Spell 固定到右侧 HP/MP 双条上方。

### 塞萨利裂谷船舵奖励专用双发：已部署，待实机验证

已根据日志确认正确入口不是普通房间清场奖励，而是点击船舵后才进入的
`RoomSetName == "O" / Encounter == "GeneratedO"`。`GeneratedO_Intro01` 的空奖励仍明确排除。

代码改动：

- `logic/loot/LootShared.lua`：首份船舵奖励生成完成后，立刻在下一位存活玩家的 HeroContext 下再次调用本体奖励生成函数，并在首份旁预留独立落点。
- 主神 boon 在 P2 上下文重新执行 `SetupRoomReward()`，因此按 P2 的信物定向、稀有度效果和本体奖池独立预选；允许与 P1 出现同一神明。
- `TalentDrop`、资源及其他非 boon 奖励生成第二个独立实体，保持首份奖励类型一致。
- 船区拾取监测已不再依赖 `ResourceCosts == nil`，可覆盖 `TalentDrop` 等消耗品。

验证重点：

- 点击船舵后的日志应同时出现 `first-generated` 与 `second-generated`，且 ObjectId 不同。
- 主神 boon：P1/P2 分别领取一份；P2 的定向信物、稀有度效果只影响第二份。
- `TalentDrop`、金币等非 boon：场上应有两个独立可领取实体，领取后正常推进，不影响出口。

### 塞萨利裂谷船区奖励路径定位：待下次实现

本轮日志结论：

- `O_Combat03 / GeneratedO_Intro01` 先走一次空奖励；点击船舵后切换到 `GeneratedO`，实际生成 `TalentDrop`，但没有第二份生成记录。
- `O_Combat01 / GeneratedO` 主神奖励 `ApolloUpgrade` 只生成一份并由 P1 拾取；没有 `[CoopRewardTrace] second-spawn` 或 `[CoopShipsRewardTrace] second-generated`。
- `RoomMoneyDrop` 同样只生成首份。
- `TalentDrop` 输出了 `[CoopSpellTrace]`，但未输出 Ships pickup trace。当前船区监测将 `ResourceCosts == nil` 作为条件，而该消耗品数据不满足该条件，筛选过窄。

下次调整方向：

- 为 `RoomSetName == "O"` 且 `Encounter == GeneratedO` 建立专用第二奖励路径，不再依赖普通 `SpawnSecondNormalRoomReward()` 的条件。
- 主神 boon：P2 HeroContext 下重新调用 `SetupRoomReward()`，保留船区奖励和稀有度规则。
- `TalentDrop` / 其他消耗品：生成独立第二实体，并确保 P2 菜单上下文；固定资源奖励按首份类型复制。
- 扩宽 Ships pickup trace 的识别条件，并记录第二实体的 ObjectId、可用状态和实际拾取者。
- `GeneratedO_Intro01` 的 `Empty` 仍排除，不生成第二份。

### 原野次要奖励（mini）双发：已部署，待实机验证

原因与代码改动：

- `FieldsOptionalRewards` 在进房时使用 `SpawnRoomReward(... NotRequiredPickup = true)` 生成，不属于 cage 主奖励，因此此前未覆盖。
- `logic/loot/LootShared.lua` 现为每份 `RoomSetName == "H"` 的 optional reward 在原奖励旁生成一份同类型副本，使用 P2 HeroContext；不影响主 cage 和 Miniboss。
- 新增 `[CoopFieldsOptionalTrace] second-spawn`，记录两份奖励名称与 ObjectId。

验证重点：

- 原野 mini HP/MP、金币、回复、护甲、礼物、Meta 资源等应各出现两份。
- 不应影响主 cage 奖励数量、Miniboss boon 数量或出口。

### 原野普通消耗品双奖励与 Miniboss 第三份修复：已部署，待实机验证

日志结论：

- `H_Combat12` 的 `RoomMoneyDrop` / `MaxHealthDrop` 确实完成了首份消耗品拾取，但此前没有第二份逻辑。
- `H_MiniBoss01` 已在进房时由通用 Elite 路径生成 Hera + Ares；之后 `UseLoot()` 又补发 Ares，形成第三份。
- `H_Combat03` 的锤子和石榴使用 `UseLoot()` 拾取后补发，已正常双份。

代码改动：

- 普通原野 cage 消耗品在首份 `UseConsumableItem()` 前临时设置 `RespawnAfterUse`，利用本体波塞冬同类逻辑保留同一实体一次；首份结束后清除该标记，第二次拾取正常销毁。新增 `[CoopFieldsRewardTrace] second-rearmed`。
- `H_MiniBoss*` 在拾取后跳过 `SpawnSecondFieldsCageReward()`，保留已有的通用 Elite 双奖励，不再产生第三份；日志为 `second-skip ... miniboss-native-double`。

验证重点：

- 金币、人马心、护甲、MP 等普通 cage 消耗品应可领取两次，第二次后消失。
- 原野 Miniboss boon 总数应为两份，不应在首次领取后出现第三份。

### 原野消耗品奖励拾取监测补全：已部署

测试反馈：

- `H_Combat12 / GeneratedH_Passive` 已记录主要/次要奖励生成，以及主要奖励 cage 解锁；拾取 `RoomMoneyDrop` 后没有拾取日志。

原因与改动：

- `RoomMoneyDrop`、`MaxHealthDrop`、`ArmorBoost` 等原野奖励是 `ConsumableItem`，不经过 `UseLoot()`。
- `hooks/InteractLogicHooks.lua` 现同时监测 `UseConsumableItem()`，Fields 和船区均记录 `pickup-start` / `pickup-finished`，并标记 `kind=consumable`。

### 原野与船区奖励全链路监测：已部署

新增监测：

- 哀悼原野：`[CoopFieldsRewardTrace]` 记录 cage 标记、普通 cage encounter 开始、Miniboss cage 解锁、奖励拾取开始/完成、第二份生成；涵盖 boon 与非 boon。
- 塞萨利裂谷船区：`[CoopShipsRewardTrace]` 记录首份/第二份的生成玩家、奖励名、实体 ID、奖励类型，以及非商店奖励的拾取开始/完成。
- `watch_coop_debug.ps1` 已纳入上述日志和 `[CoopHubUiRefresh]`。

用途：

- 用实际 reward 名称与 ObjectId 对照预选结果，定位第二份在“预选、CreateLoot、落地、交互”哪个阶段丢失或不可见。

### 奖励归属限制回撤：已部署

- 随后确认实际场上可能只有首份 Demeter、未出现可见的第二份 Aphrodite。若保留 owner 限制，P2 会被拒绝交互且可能导致奖励必需物无法完成。
- 已立即撤回 `CoopModOwnerPlayerId` 与 `pickup-blocked` 逻辑，恢复此前不会因拾取限制卡关的行为。
- 后续先定位“P2 预选/生成日志存在但地面实体不可见或未生成”的根因，确认两个可领取实体稳定存在后再考虑归属限制。

### 房间奖励玩家归属绑定：已部署，待实机验证

测试反馈：

- `B_Combat01` 日志显示首份为 Demeter、P2 独立生成 Aphrodite；但实际 P1 领取后 P2 仍可拾取地上的 Demeter，说明奖励对象没有限制拾取者。

代码改动：

- `logic/loot/LootShared.lua`：首份、普通第二份和 direct fallback 第二份 loot 均写入 `CoopModOwnerPlayerId`。
- `hooks/InteractLogicHooks.lua`：`UseLoot()` 拒绝非 owner 交互，输出 `[CoopRewardTrace] pickup-blocked`；哀悼原野拾取后第二份也绑定 P2。

验证重点：

- P1/P2 各只能领取自己的一份地面奖励；P2 尝试领取 P1 的奖励应无菜单，并输出 `pickup-blocked`。
- P2 仍能正常领取自己的第二份 boon/锤子等，不应阻塞出口。

### 原野奖励笼标记修复与塞勒涅 HUD 回撤：已部署，待实机验证

测试反馈：

- P2 塞勒涅 HUD 修复无效，且影响 P2 祝福查看列表；按要求先撤回固定槽位容器分离/右侧定位改动。
- 哀悼原野奖励仍为单份。
- Hub UI 延迟刷新仍未恢复，推测回 Hub 后本体已清空 `RunResult`，导致刷新 guard 提前退出。

根因与代码改动：

- 原野奖励笼在 `StartFieldsEncounter()` 中于战斗开始时被销毁；前版在玩家拾取时反查 `FieldsRewardCage`，必然无法识别。现于笼销毁前把 `RewardId` 标记到 loot；Miniboss 的 `UnlockRewardCagesMiniboss()` 也使用相同标记。日志先输出 `[CoopFieldsRewardTrace] marked`，拾取完成后输出 `second-spawn`。
- 撤回 `UIHooks.lua` 中 P2 `SlottedTraitComponents/ActiveTraitComponents` 分离和固定槽位右移，恢复之前稳定的祝福列表 UI。
- Hub HUD 延迟刷新移除 `RunEx.IsRunEnded()` guard；调用点本身已限定为 run 结束流程。

验证重点：

- 原野奖励：必须依次看到 `marked` 与 `second-spawn`，并确认第二份可领取且不生成第三份。
- Hub：回到 Hub 后立即检查双方 UI，无须再次进入 run。

### Run 结束后 Hub HUD 延迟刷新：已部署，待实机验证

测试反馈：

- Run 结束回到 Hub 后，UI 仍显示上一趟 run 的状态；进入下一次 run 后才恢复，数值本体不受影响。

代码改动：

- `logic/CoopPlayers.lua`：`ResetAfterRunEnd()` 不再只刷新 MP，改为在数值重置后延迟刷新 HP/MP HUD。
- `logic/CoopRun.lua`：Hub 房间演出结束后再调用一次相同刷新，防止本体 `StartRoom`/演出覆盖先前 UI 更新。新增 `[CoopHubUiRefresh]`。

验证重点：

- 任意 run 结束回 Hub 后，不进入新 run 也应立即显示双方正常 HP/MP 面板与角色状态。

### 船区与原野 Elite/无 Encounter boon 独立预选：已部署，待实机验证

测试反馈：

- 塞萨利裂谷船区的 Elite 奖励已双发，但 boon 的第二份仍复制 P1。
- 哀悼原野 Elite 与无 Encounter 房也已双发，但主神 boon 同样复制。

根因与代码改动：

- 原先 `GetRoomRewardType()` 主要依赖已创建 loot 的 `GodLoot` 字段；部分特殊奖励路径未可靠携带该字段，结果把 `ZeusUpgrade` 等当成固定名称复制。
- `logic/loot/LootShared.lua` 现按本体 `SpawnRoomReward()` 的优先级解析类型：`EncounterRoomRewardOverride`、`ChangeReward/ChosenRewardType`、房间 `Reward`，最后才读取 `LootData` 的 `GodLoot` 兜底。船区转舵存储的 `EncounterRoomRewardOverride = "Boon"` 因此可正确进入独立生成。

验证重点：

- 船区、哀悼原野 Elite、哀悼原野无 Encounter 房的第二份主神 boon 应有独立神明；P2 信物的定向与稀有度效果应作用于第二份。
- 非主神奖励仍为同类复制，不应产生第三份。

### 哀悼原野拾取后二次生成与 P2 塞勒涅 HUD：已部署，待实机验证

测试反馈：

- 哀悼原野（`RoomSetName == "H"`）的笼中奖励在进房时已存在，锤子、赫尔墨斯 boon、石榴和主神 boon 均未可靠双发；此前房间结算/`GiveLoot()` fallback 无法覆盖该入口。
- P2 取得塞勒涅法术后，法术 HUD 仍可能显示为居中半透明黑框。

代码改动：

- `hooks/InteractLogicHooks.lua`：新增 `UseLoot()` 钩子，仅识别 `FieldsRewardCage` 持有的奖励。首份菜单关闭后，在原位置按 P2 HeroContext 调用 `GiveLoot()` 生成第二份；该时序参照波塞冬 `DoubleRewardBoon` 的“选择完成后再生成”实现。主神 boon 用 `SetupRoomReward()` 重新按 P2 信物和原版奖池预选，其他奖励复制首份类型。新增 `[CoopFieldsRewardTrace]`。
- `logic/loot/LootShared.lua`：在原野拾取后二次生成期间阻止直接奖励 fallback，避免额外生成第三份。
- `hooks/UIHooks.lua`：`HUDScreen.SlottedTraitComponents` / `ActiveTraitComponents` 改为按玩家分离；P2 的固定槽位（包括 `Spell`）改为右侧坐标，避免覆盖 P1 法术图标和丢失锚点。
- `watch_coop_debug.ps1`：加入 Fields、Chaos、Spell 与结局 trace 过滤。

验证重点：

- 哀悼原野第一次领取笼中奖励后，应出现 `[CoopFieldsRewardTrace] second-spawn ...`，并在原位置出现 P2 的第二份；主神 boon 的 `first` / `second` 可以不同。
- P2 领取 `SpellDrop` 后，法术图标应在右侧固定槽位正常显示，P2 可打开、选择和施放。

### 菜单 HeroContext、锤子/Chaos 缓存与 Hub MP 复位：已部署，待实机验证

测试反馈：

- P2 拾取塞勒涅 `SpellDrop` 后，法术选择列表只能由 P1 协助控制；进入下一房间时 P2 的法术 HUD 变成居中的半透明黑框。
- P2 先拿锤子后，P1 再拿锤子会看到 P2 武器的选项。
- Chaos Room 的两份 `TrialUpgrade` 初始列表相同，只能依赖单独 reroll 道具改变第二份。
- 全员死亡回到 Hub 后，P2 可能保留未充满的 MP，例如 `65/90`。

根因与代码改动：

- `hooks/MenuHooks.lua`：通用菜单 wrapper 之前只切换手柄映射，未让本体菜单完整运行在打开者的 HeroContext。现按当前玩家在 `RunWithHeroContextAwait()` 中执行，并补注册 `OpenTalentScreen()`；这覆盖塞勒涅法术选择后的天赋页面。
- `hooks/UpgradeChoiceHooks.lua`：`WeaponUpgrade` 与 `TrialUpgrade` 都会在 loot 创建时缓存 `UpgradeOptions`。现每名玩家打开前均清空缓存，让本体按该拾取者当前武器/traits 重新生成。日志改为 `[CoopChoiceTrace] refresh-options player=... loot=...`。
- `logic/CoopPlayers.lua`：Hub 结束清理在移除 run 内 MP trait 后，对每名玩家补满 MP、调用 `ValidateMaxMana()` 并刷新双方 MP HUD；P2 不再依赖原版单人 reset 路径。

验证重点：

- P2 拾取 `SpellDrop` 时由 P2 控制法术选择；后续打开 `TalentDrop` 也是 P2 控制。若 HUD 黑框仍在，记录是否仅为 HUD 显示问题、法术本体能否施放。
- 无论 P1/P2 谁先拿锤子，双方锤子列表均匹配各自武器。
- Chaos 两份 `TrialUpgrade` 初始选项独立，且每人只可领取一次，不产生第三份。
- 全员死亡回 Hub 后，双方 MP 均为各自 `MaxMana`，并有 `[CoopHubManaReset]`。

### 塞勒涅拾取者归属、Chaos 随机槽位与克洛诺斯结局协程：已部署，待实机验证

追加测试反馈：

- 前一版后，P2 塞勒涅法术菜单和 Chaos 两份列表仍未改变。
- 哀悼原野存在未双发的普通房奖励；未提供对应 room name / `[CoopRewardTrace]`，尚不能判断是 `SpawnRoomReward()` 还是该区域的特殊奖励函数。
- 击败克洛诺斯后偶发黑屏，run 无法结束并回到三岔路口。

代码改动：

- `hooks/InteractLogicHooks.lua`：P1/P2 拾取 `SpellDrop` 或 `TalentDrop` 时，将玩家编号写入 consumable，并输出 `[CoopSpellTrace]`。
- `hooks/MenuHooks.lua`：`OpenSpellScreen` / `OpenTalentScreen` 优先读取 consumable 的玩家编号，而不是依赖可能已回到 P1 的 `CurrentRun.Hero`；随后在该玩家 HeroContext 中打开并切换菜单手柄。
- `hooks/UpgradeChoiceHooks.lua`：P2 打开 `TrialUpgrade` 前，除重建选项外额外调用 `RandomSynchronize(102)`，避免原版为相同 Chaos loot 重用同步随机序列而固定生成与 P1 相同的列表。
- `hooks/RunHooks.lua`：`EndEarlyAccessPresentation()` 原 wrapper 使用非等待版 HeroContext，但本体结局演出含多个 `wait`。现改为 `RunWithHeroContextAwait()`，使整个结局协程保持 P1 上下文；新增 `[CoopEndRunTrace] early-access-outro-start/finished`。

下一轮验证：

- P2 拾取塞勒涅后应出现 `[CoopSpellTrace] pickup player=P2`，并由 P2 控制法术/天赋选择。
- Chaos P2 列表应不同于 P1；每人仍只领取一次。
- 克洛诺斯击败后应依次出现 `early-access-outro-start` 与 `early-access-outro-finished`。若仍黑屏，截取这两行附近全部日志。
- 哀悼原野遗漏房请提供该房间前后完整 `[CoopRewardTrace]`，至少包括 room、encounter、native/tracked/reward/type 行。

### Chaos 选项去重与纳西索斯崩溃回退：已部署，待实机验证

测试反馈：

- `Chaos_05` 中 P1/P2 的 `TrialUpgrade` 都已进入各自 HeroContext，但初始三项仍相同。
- `NPC_Narcissus_01` 在 P1 选择后打开 P2 列表，P2 选择流程导致游戏崩溃。

根因与处理：

- Chaos：仅清空 `UpgradeOptions` 或切换一次随机槽位不足以保证不同结果。现记录 P1 的完整选项签名，P2 在显示前以槽位 `102..110` 调用本体 `SetTraitsOnLoot()` 预生成，直到签名不同才显示；输出 `[CoopChaosTrace]`。若所有尝试都相同，会明确记录 `no-distinct-options`，表示当前可用池无法组成第二套不同列表。
- 纳西索斯：本体在 `NarcissusBenefitChoice()` 从 boon 菜单返回后，才将 `NarcissusPostChoicePresentation` 写入外层对话 screen；boon screen 本身 `handler=nil`。通用双选流程在返回前插入 P2 菜单，破坏该状态机并导致崩溃。
- 安全回退：从 `NpcBoonChoiceSources` 移除 `NPC_Narcissus_01`。纳西索斯暂时只提供原版单份奖励，不再崩溃；后续须为该事件单独实现“原对话流程完成后再发 P2 奖励”的方案。

验证重点：

- Chaos 日志应包含 P1/P2 的 `[CoopChaosTrace]`，并比较两个 `options=` 内容。
- 纳西索斯完成一次选择并离开事件房，确认不再崩溃；此版本不应出现 P2 第二列表。

### 哀悼原野直接奖励 fallback 扩展：已部署，待实机验证

测试反馈：

- 哀悼原野普通房中，锤子、赫尔墨斯 boon、石榴均只出现一份。
- 提供的日志只有 `[CoopRarityTrace]`，它记录的是 P1 打开奖励菜单，不包含奖励生成入口；未出现对应 `[CoopRewardTrace]`，表明该路径可能绕过 `SpawnRoomReward()`。

代码改动：

- `logic/loot/LootShared.lua`：直接 `GiveLoot()` 的第二份奖励 fallback 原先仅覆盖 Chaos、NonCombat Event 和 NPC-assist；现加入 `EncounterType == Default` 与 `Miniboss`。
- 现有 `CoopModSpawnRoomRewardActive`、`CoopSpawningSecondNormalRoomReward`、`CoopSecondDirectRewardSpawned` guard 保持不变，因此已经通过 `SpawnRoomReward()` 生成两份的房间不会再变为三份。

验证重点：

- 在哀悼原野普通房验证锤子、赫尔墨斯 boon、石榴各出现两份。
- 确认每种奖励只能领取两次，且不会出现第三份。

### 哀悼原野主神 boon 独立生成：已部署，待实机验证

- 初版 direct `GiveLoot()` fallback 会复制首份 loot 名称；若哀悼原野出现主神 boon，P2 会错误继承 P1 神明，不能应用 P2 神明信物。
- `logic/loot/LootShared.lua` 已调整：普通/Elite combat 的 direct `GodLoot` 第二份在 P2 HeroContext 调用本体 `SetupRoomReward()` 预选，再以该结果调用 `GiveLoot()`。
- Chaos、NonCombat Event，以及赫尔墨斯/塞勒涅、锤子、石榴等固定非主神奖励仍复制首份，避免改写其原有事件或特殊选择逻辑。
- 验证：P1/P2 携带不同主神信物进入哀悼原野，出现主神 boon 时确认两份分别读取各自信物与稀有度。

## 2026-07-11

### 双奖励验证通过与 Hub MP 残留清理：已部署，待复测

本轮实机结果：

- 开局双 boon 正常生成：P1 宙斯、P2 战神的定向信物均按各自 HeroContext 生效，P2 稀有度菜单也正常出现。
- Elite boon 双发成功；P2 锤子列表已按 P2 当前武器生成。
- Medea、Artemis NPC boon 事件中，P1 选择后 P2 会得到一份独立列表，事件流程正常。
- 仍发现失败返回 Hub 后可能残留 run 内 MP trait；日志中 P2 有 `RoomRewardMaxManaTrait{value=5}`，使 MP 从应有值额外增加 5。

原版数值结论：

- `BaseStaffAspect` 是原版法杖形态 trait，而非 co-op 或阿卡那残留。其满级为 `+40 MaxMana`，同时还携带法杖伤害效果。
- 因此，装备法杖形态且装备 `HealthManaBonusMetaUpgrade(+40)` 时，`50 基础 + 40 阿卡那 + 40 法杖形态 = 130 MP` 是原版计算结果；不能通过删除该 trait 将数值强行压到 90，否则会破坏武器形态效果。

代码改动：

- `logic/CoopPlayers.lua`：`ResetAfterRunEnd()` 现在对 P1/P2 都调用 `RemoveRunScopedManaTraits()`。
- 该清理仅在 Hub/Ready Room 边界运行，移除单次 run 的 `RoomRewardMaxManaTrait`（包括门牌 `+5 MP`）以及未装备 MP 信物时遗留的信物补偿 trait；随后在各自 HeroContext 调用原版 `ValidateMaxMana()`。
- 清理后调用已 hook 的 `UpdateManaMeterUI()` 刷新双方 HUD，并写入 `[CoopHubManaReset] removed=P1:n,P2:n` 日志。
- 不移除 `BaseStaffAspect`，确保 run 内原版武器形态和伤害效果保持正确。

验证重点：

- 失败返回 Hub 后，日志应出现 `[CoopHubManaReset]`；不应再保留 `RoomRewardMaxManaTrait{source=nil,value=5}`。
- 装备满级基础法杖形态且有双上限阿卡那时，130 MP 是预期值；不装备该形态时才应为 90 MP。
- 观察 P1/P2 MP 条是否在返回 Hub 后立即同步，而不是等待下一次状态变化。

### 奖励覆盖第二轮修复、P2 锤子与泉水：已部署，待实机验证

测试反馈：

- 地上第二层船区房间的奖励未双发，Elite 房也未出现第二个 boon。
- P2 拾取代达罗斯之锤时，选项来自 P1 的武器池。
- 所有恢复泉水只能使用一次，且第一次显示的恢复量异常为双倍。
- NPC boon 事件不能第二次对话，因此无法通过重复交互给 P2 第二份奖励。

代码改动：

- `logic/loot/LootShared.lua`：本体 `SpawnRoomReward()` 的 `Room.Reward.FunctionName` 分支会创建 loot 后返回 `nil`。现在在该调用期间记录首个 `GiveLoot()` 结果，使用它继续第二份奖励判断；同时允许 `ChangeReward` 的 Elite/Miniboss 奖励进入双发流程。新增 `[CoopRewardTrace]`。
- `hooks/UpgradeChoiceHooks.lua`：`OpenUpgradeChoiceMenu()` 现完整运行在掉落所属 HeroContext，修复锤子选项读取错误的 `CurrentRun.Hero` 武器。对于带本体 NPC 收尾回调的 boon 选择，P1 选后自动打开 P2 的新列表，并在 P2 选后执行事件收尾；新增 `[CoopNpcRewardTrace]`。
- `logic/loot/LootShared.lua`：补充 `ArtemisCombat*`、`AthenaCombat*`、`DionysusCombat*`、`HadesCombat*` NPC 助战奖励识别。这些房间本体在战斗结束后调用 `SpawnRoomReward()`，直接 `GiveLoot()` 的变体也会进入双奖励路径。
- `hooks/InteractLogicHooks.lua`：新增 `UseHealthFountain()` wrapper。P1/P2 对同一泉水各使用一次；首次使用后恢复可交互与房间必需物，第二次才维持本体耗尽状态；新增 `[CoopFountainTrace]`。
- `watch_coop_debug.ps1` 已更新，可在独立终端显示上述三类日志。

部署与检查：

- `build_and_deploy.ps1` 构建、安装和部署成功。
- `git diff --check` 仅保留已有的 `game/src/extensions/LuaFunctionDefs.cpp:283` 文件末尾空行提示，未改动该文件。

下一轮测试：

- 在船区、Elite、无 Encounter 关键奖励房分别验证两份奖励，并保留对应 `[CoopRewardTrace]`。
- 让 P2 拾取锤子，确认选项属于 P2 当前武器。
- 对任意 Rest/道中泉水按 P1 -> P2 和 P2 -> P1 各测一次，确认每人一次、出口状态正常。
- 验证 NPC boon 事件中 P1 选择后 P2 是否自动出现新列表，且事件不会提前离场或卡住。

### 奖励覆盖范围扩展：已部署，等待宽范围实机测试

开发目标：

- 将双奖励从普通 `EncounterType == "Default"` 战斗房扩展到 Elite、无 Encounter 的关键奖励、Chaos、Event 与 NPC-assist Event Room。
- 无 Encounter 的主神 boon 继续独立生成；Chaos/Event/NPC-assist 的固定奖励采用复制策略。

代码改动：

- 修改 `game/scripts/config.lua`：新增 `ExpandedRoomDoubleRewards = true`。
- 修改 `game/scripts/logic/loot/LootShared.lua`：
  - `SpawnRoomReward()` 路径取消仅限 Default Encounter 的限制，覆盖 Elite 与无 Encounter 固定奖励；Boss、商店、cage、bonus、显式 spawn 和特殊奖励路径仍排除。
  - 普通/Elite/无 Encounter 的主神 `Boon` 第二份继续在另一位玩家 HeroContext 按本体 `SetupRoomReward()` 独立预选。
  - Chaos 与 `NonCombat` Event/NPC-assist 的 boon 改为复制第一份，符合既定规则。
- 新增直接 `GiveLoot()` 的房间级复制守卫：Chaos 和 `NonCombat` 事件绕过 `SpawnRoomReward()` 时，只为另一名存活玩家额外生成一次同内容奖励，并输出 `[CoopDebug] label=direct-reward-copy`。

Elite 稀有度继承确认：

- 本体的高难/Elite/Miniboss 房间可在 `RoomData*.lua` 配置 `BoonRaritiesOverride`，例如 Rare、Epic、Legendary、Duo 的概率覆盖。
- 原版 `GetRarityChances()` 先读取 `CurrentRun.CurrentRoom.BoonRaritiesOverride`，再叠加当前 Hero 的 `RarityBonus` 与 `MultiplicativeRarityBonus`。
- 当前第二份独立 boon 仍在相同 `CurrentRun.CurrentRoom` 内调用本体 `GiveLoot()`，未设置 `IgnoreRoomRarityBonus`；因此无需复制或手动修改概率，已自动继承 Elite 房覆盖，同时保留 P2 自己的信物/trait 稀有度加成。

部署：

- 已运行 `build_and_deploy.ps1` 成功，已部署 `config.lua` 与 `logic/loot/LootShared.lua`。
- 测试时记录 room name、encounter name/type、奖励类型、是否看到第二份奖励、是否出现 `direct-reward-copy`、两份奖励拾取和出口解锁状态。

### 新增实时 co-op 调试面板：已部署

开发目标：

- 让测试时可以直接观察 mod 维护的双人状态，而不是只依赖错误发生后的日志。
- 优先覆盖近期高风险状态：P1/P2 HP/MP、死亡标记、信物、熟灵、神明信物的 `ForceBoonName`、稀有度信物次数，以及第二份 boon 的预选结果。

代码改动：

- 新增 `game/scripts/logic/CoopDebugMonitor.lua`。
  - 以独立 `CreateScreenObstacle()` 创建左上 `CO-OP DEBUG` HUD，不写入 Hero、Room 或奖励对象。
  - 每 0.25 秒刷新 P1/P2 的 HP/MP、存活状态、信物、熟灵、强制 boon trait 和稀有度 trait 使用次数。
  - `RecordReward()` 为关键奖励事件写入 `[CoopDebug]`，使用已有 DLL 日志函数，因此每行附本地时间。
- 修改 `GamemodeInit.lua`：游戏 hook 初始化后启动监测模块。
- 修改 `LootHooks.lua` 与 `LootShared.lua`：记录开局与普通房第二份 boon 的预选/生成结果及当时 P2 信物 trait。
- 修改 `config.lua`：新增 `Debug.RuntimeMonitor = true` 和 `Debug.RuntimeMonitorInterval = 0.25`。

部署与测试方式：

- 已运行 `build_and_deploy.ps1` 成功，已部署 `config.lua`、`GamemodeInit.lua`、`logic/CoopDebugMonitor.lua`、`hooks/LootHooks.lua`、`logic/loot/LootShared.lua`。
- 进入 run 后观察左上 `CO-OP DEBUG`；日志路径为 `%USERPROFILE%\Saved Games\Hades II\TN_CoopMod.log`。
- 针对 P2 `ForceBoon`，测试时记录 P2 面板的 `K`/`Force` 字段和对应 `[CoopDebug]` 的 `traitForce`、`result`、`forced`。

后续调整：

- 游戏内 HUD 在进入 run 后会被房间 UI 生命周期清除，不能作为稳定的实时调试载体。
- 新增根目录脚本 `watch_coop_debug.ps1`，已启动独立可见 PowerShell 窗口，实时筛选 `[CoopDebug]`、`[CoopDeathTrace]` 与 `[CoopBossTrace]`。
- `CoopDebug` 额外输出 `forceUses`。原版 `SetupRoomReward()` 的强制 boon 条件是 `trait.ForceBoonName ~= nil and trait.Uses > 0`，所以必须同时观察 trait 名与次数。
- 本次日志显示 `ForceZeusBoonKeepsake` 的 `traitForce=ZeusUpgrade` 存在，但预选结果是 `HephaestusUpgrade`；待下一轮确认该时刻 `forceUses` 是否已被前一份奖励消耗。

### P2 定向 boon 已确认，稀有度菜单诊断已部署

- 2026-07-11 测试：P2 携带 `ForceHestiaBoonKeepsake` 时，第二份 boon 的日志为 `result=HestiaUpgrade`、`forceUses=1`；生成后为 `forceUses=0`，确认 P2 定向 boon 与其消耗已正常工作。
- 同次测试中 P2 拾取赫斯提亚 boon 时没有显示稀有度升级选项；`rarityUses=1` 在掉落生成后仍存在，问题发生在 boon 选择菜单阶段，而不是掉落生成阶段。
- 原版 `UpgradeChoiceScreenCheckRarifyButton()` 会直接读取 `CurrentRun.Hero.Traits`。新增 `hooks/UpgradeChoiceHooks.lua`，在菜单创建时标记来源玩家，并在每次悬停 boon 选项时输出 `[CoopRarityTrace]`：来源玩家、实际 HeroContext 玩家、boon 类型、匹配信物、稀有度次数与按钮可见状态。
- 已构建部署 `GamemodeInit.lua` 和 `UpgradeChoiceHooks.lua`；需完全重启游戏后读取新 hook。

根因与修复：

- 后续日志：P2 波塞冬 boon 的菜单标记为 `sourcePlayer=P2`，但原版 `UpgradeChoiceScreenCheckRarifyButton()` 实际读取的是 `contextPlayer=P1`；因此 P2 的 `ForcePoseidonBoonKeepsake` 未进入 trait 遍历，`visible=false`。
- 修改 `hooks/UpgradeChoiceHooks.lua`：该函数现按 `screen.Source.CoopModUpgradeChoicePlayerId` 在拾取者 HeroContext 内调用本体逻辑。P1 和非玩家来源菜单保留原始路径。
- 已重新构建并部署 `UpgradeChoiceHooks.lua`，等待实机验证 P2 稀有度按钮出现、消耗 P2 `RarityUpgradeData.Uses`，且不影响 P1。

### 全员死亡返回 Hub 后输入锁残留：修复已部署

测试现象：

- P1 先死亡、P2 后死亡时，回到三岔路口后两名玩家都无法操作，活跃模型有时仍是 P2。
- P2 先死亡、P1 后死亡时，P1 可以移动；进入 Ready Room 后 P2 模型刷新出来但不能移动。
- 两种情况都需要返回主菜单重新加载存档才能恢复。

根因与修复：

- 战斗死亡时 `RunHooks.KillHero()` 为死亡玩家添加 `CoopDeadPlayerX` 输入锁并设为透明；原有代码只在 Boss -> Rest Room 复活时移除。
- 原有 `CoopPlayers.OnAllPlayersDead()` 只重置默认 Hero、血量和控制配置，未清除 `IsDead`、输入锁或透明状态；`CoopRun.OnMapLoaded()` 在 Hub 也只治疗 P2。
- 新增 `CoopPlayers.ResetAfterRunEnd(reason)`：清除 P1/P2 的 `IsDead`、`CoopDeadPlayerX`、死亡效果和透明状态，恢复 HP、控制方案及 P1 活跃单位，并输出 `[CoopRunReset]`。
- `CoopRun.OnMapLoaded()` 在 `Hub_Main` 或 `Hub_PreRun` 调用该清理，作为原版死亡 outro 完成后的稳定边界。
- 经过复核，全员死亡时不立即清除 `IsDead`，以避免与原版 `KillHero()` / `EndRun()` 结算线程竞争；该阶段仅恢复默认 Hero 和控制配置，完整状态清理延后到 Hub。
- 已构建并部署 `logic/CoopPlayers.lua` 与 `logic/CoopRun.lua`。
- 后续实机确认：该问题已解决，P1 -> P2 与 P2 -> P1 死亡顺序均不再要求退出主菜单恢复控制。

### P2 信物错误写入 P1：根因修复并部署

根因：

- 本体 `KeepsakeScreenClose()` 会直接执行 `UnequipKeepsake(CurrentRun.Hero, ...)` 与 `EquipKeepsake(CurrentRun.Hero, ...)`。
- 旧的 P2 信物柜适配只隔离了 `GameState.LastAwardTrait` 和 UI 状态，没有在关闭菜单时切换 HeroContext。
- 结果是 P2 选择的信物 trait 实际卸载/装备在 P1：神明信物不会在 P2 boon 上提供定向与稀有度；MP 信物会给 P1 添加 `RoomRewardMaxManaTrait`，造成 P1 MP 上限异常残留。

代码改动：

- 修改 `game/scripts/hooks/MenuHooks.lua`：`KeepsakeScreenClose()` 现在在实际选择该信物的 HeroContext 内运行本体关闭逻辑。
- 修改 `game/scripts/logic/CoopPlayers.lua`：增加 P1 MP 残留清理；仅当 P1 没有 `ManaOverTimeRefundKeepsake` 时，移除来源为该信物的 `RoomRewardMaxManaTrait` 并调用 `ValidateMaxMana()`。
- 修改 `game/scripts/hooks/RunHooks.lua`：每个新 run 开始前再次执行该残留清理，帮助修复旧版本已经写入的 P1 MP 状态。
- 已通过 `build_and_deploy.ps1` 构建并部署 `MenuHooks.lua`、`CoopPlayers.lua`、`RunHooks.lua`。

待实机验证：

- P2 神明信物能定向第二份 boon，并显示/消耗 P2 自己的稀有度效果。
- P2 MP 信物只影响 P2；P1 未装备该信物时，MP 上限恢复为当前阿卡那与自身 traits 应有数值（本次目标为 90）。
- 失败回大厅与下一局 run 时，两位玩家 HP/MP 均正常复位。

### MP 150 根因修正为 P2 熟灵串写：已部署

- 运行时日志显示，进入 run 时 P1 的 MP 相关 traits 只有 `HealthManaBonusMetaUpgrade{value=40}` 和 `DigFamiliar{value=60}`；因此 P1 MP 为 `50 + 40 + 60 = 150`。
- `DigFamiliar` 来自 P2 的熟灵状态，而 P2 自身没有该 trait，证明熟灵和此前信物一样只切换了存档字段、没有切换实际 HeroContext。
- 修改 `game/scripts/hooks/FamilliarHooks.lua`：P2 调用 `UseFamiliar()` 时，原版 `UnequipFamiliar()` / `EquipFamiliar()` 改在 P2 HeroContext 内执行。
- 修改 `game/scripts/logic/CoopPlayers.lua`：新 run 时移除错误附着在 P1、且不属于 P1 自己熟灵的 P2 familiar traits，并重算 HP/MP。
- 修改 `game/src/extensions/LuaFunctionDefs.cpp`：`TN_CoopMod.log` 的诊断行现在附带本地日期时间；trace 同时输出 P1/P2 的信物和熟灵名称。
- 已完整构建并部署 DLL 与 `FamilliarHooks.lua`、`CoopPlayers.lua`、`RunHooks.lua`。
- 后续实机确认：P1 MP 已恢复正常；P2 的 `ForceBoon` 仍未生效，因此问题范围已从 MP/熟灵串写收敛到 boon 奖励选择路径。

## 2026-07-10

### 双 boon 改为 P2 独立走本体奖励规则：已部署，待实机验证

开发背景：

- 普通战斗房双奖励已经验证可生成，但第二份 boon 之前复制了 P1 的神明，无法支持 P1/P2 各自信物。
- 确认本体神明信物采用 `ForceBoonName`：下一份符合条件的普通 `Boon` 会定向为该神明并消耗一次，同时应用对应稀有度效果。
- 本体非普通 boon 奖励（如赫尔墨斯、塞勒涅、代达罗斯之锤）不应被合作逻辑改写。

代码改动：

- 修改 `game/scripts/logic/loot/LootShared.lua`：
  - 普通战斗房的第二份非 boon 奖励继续复制 P1 的奖励类型与 loot。
  - 当第一份为普通 `Boon` 时，为 P2 创建临时奖励记录，并在 P2 HeroContext 调用本体 `SetupRoomReward()`。
  - 不传 `previouslyChosenRewards`，因此 P1/P2 获得同一神明仍是合法的本体随机结果。
  - 使用独立预选出的 `ForceLootName` 生成 P2 boon，使 P2 的神明信物、稀有度和 `Uses` 在 P2 上下文生效。
- 修改 `game/scripts/hooks/LootHooks.lua`：开局免费 boon 的第二份也使用 P2 的本体 `SetupRoomReward()` 预选，不再复制 P1 的神明。
- 已运行 `build_and_deploy.ps1`；`LootShared.lua` 与 `LootHooks.lua` 已部署到游戏 Mods 目录。

待实机验证：

- P1/P2 都无神明信物时，第二份 boon 独立随机且允许同神。
- P1/P2 分别携带不同神明信物时，两份普通 boon 分别消耗各自信物并应用各自稀有度。
- 开局免费 boon 的第一份菜单正常自动打开，第二份留在场上且归 P2。
- 非 boon 固定奖励仍复制且两份均可拾取、出口正常解锁。

后续测试结论：

- 开局 boon 已成功生成两份，第二份不再复制 P1 神明；但 P2 神明信物的定向 boon 效果未生效。
- P2 拾取对应神明 boon 时，预期的稀有度提升未出现；推测 P2 keepsake 的实际 trait 未在 P2 HeroContext 中生效，待单独排查。
- Elite 遭遇战房的 boon 奖励未双发，原因是当前实现仅允许 `EncounterType == "Default"`。
- 无遭遇战但会给关键奖励（boon、锤子等）的房间未双发，需要按奖励来源扩展而非简单放宽普通房判断。
- 发现一次 P2 的 MP 上限提升**信物效果**错误作用到 P1，且更换阿卡那、退出重进游戏后 P1 MP 上限仍异常为 150；该问题按信物串写记录，非阿卡那牌效果本身。
- 失败返回大厅时，P1/P2 的 HP/MP 有时仍显示上一趟 run 状态；进入下一趟 run 通常恢复，但 P1 MP 异常仍可能保留。
- 后续修复优先级：P2 信物 trait 归属与状态清理 -> Elite / 无遭遇战关键奖励双发 -> Chaos / Event / NPC-assist / Rest Room 专项规则。

### 普通战斗房双固定奖励：实现并部署

开发目标：

- 当前先实现普通 `Combat Room` / `Normal Room` 的双固定奖励。
- Chaos Room、Event Room、NPC-assist Event Room、Rest Room / Fountain Room 泉水双使用先记录为后续目标。

代码改动：

- 修改 `game/scripts/config.lua`，新增 `NormalRoomDoubleRewards = true`。
- 修改 `game/scripts/logic/loot/LootShared.lua`：
  - 保留原有房间奖励 Hero context 选择逻辑。
  - 在第一份 `SpawnRoomReward()` 成功生成后，判断当前房间是否为普通战斗房。
  - 限定触发条件：`EncounterType == "Default"`、两名玩家都存活、不是商店 / 事件 / Boss / 特殊奖励 / cage reward / bonus reward 路径。
  - 为下一名存活玩家选择并生成第二份固定 room reward。
  - 第二份奖励使用独立 `ChooseRoomReward()` / `SetupRoomReward()`，并排除第一份奖励，避免直接复制同一个奖励对象。

部署：

- 运行 `.\build_and_deploy.ps1` 成功。
- 部署到游戏目录的文件：
  - `config.lua`
  - `logic\loot\LootShared.lua`

待实机测试：

- 普通战斗房清房后是否出现第二份固定奖励。
- boon 奖励和普通资源奖励是否都能正常拾取。
- 两份奖励都拾取后出口是否正常解锁。
- 一名玩家死亡时是否不会生成第二份奖励。

后续修正：

- 第一版普通房双奖励未生效，原因是本体普通清房奖励调用是 `SpawnRoomReward(encounter)`，而不是 `SpawnRoomReward(room)`；旧判断 `eventSource == room` 误排除了正常路径。
- 已移除该限制。
- 第二份奖励策略改为复制第一份 `RewardOverride` / `LootName`，非 boon 资源奖励不再重新抽取不同奖励。
- 新增开局免费 boon 双发：`LootHooks.UnwrapRandomLoot()` 会在第一份免费 boon 生成后，为另一名存活玩家生成同神 loot；第一份仍自动打开，第二份留在场上。
- 新增配置：`StartingBoonDoubleRewards = true`。

实机测试结论：

- 普通战斗房双奖励已达成。
- 当前问题：boon 也会被复制为同神 loot，第二份缺少随机性。
- 设计调整：普通 boon 奖励后续应拆分为独立生成，给 P1/P2 信物分别影响第一/第二份 boon 留出入口。
- 保留 copy 策略的范围：非 boon 普通奖励、Chaos Room、Event Room、NPC-assist Event Room 可以优先沿用复制逻辑。

### Boss 转阶段后玩家死亡卡关：加入运行时监测

本轮实测：

- 过门增加 HP/MP 上限的阿卡那已对两位玩家生效，HUD 也即时更新。
- P2 在 Boss 未转阶段时死亡，战斗可继续；Boss 转阶段后死亡曾出现 Boss 无敌、战斗卡住。
- NPC 助战房可正常通过，进一步支持其卡关是死亡战斗状态的连带问题，而非房间独立逻辑。

本次开发：

- 在 `game/scripts/hooks/RunHooks.lua` 增加 `[CoopBossTrace]`。
- 仅在 Boss 房记录：玩家死亡标记后、死亡处理后、死亡后 0.5/2/5 秒，以及 `ChronosPhaseTransition()` 后。
- 每条日志记录 Boss 阶段、目标、AI 标识、无敌标记、存活玩家数、默认 Hero、房间出口状态、必杀敌人数量与 `MapState.BlockSpawns`。
- 在 `game/scripts/config.lua` 启用 `SoftlockTrace`。
- 发现 `DebugPrint` 不写入 `Hades II.log` 或 `Hades II-F10.log`，因此在 `game/src/extensions/LuaFunctionDefs.cpp` 增加 `CoopAppendTraceLog()`，由 DLL 直接追加写入用户存档目录。

日志结论与修复：

- `N_Boss01 / BossPolyphemus01` 中，P2 死亡时 P1 始终存活，`requiredKills` 仍在减少，排除“全员死亡”或房间失败路径。
- `death-marked` 快照中 Polyphemus 没有无敌标记；紧接 `death-handled` 快照出现 `flags=Generic`，且 5 秒后未清除。
- 原因是 `RunEx.RefreshEnemyAI()` 杀掉并重新创建了 Boss AI，打断了 Boss 阶段状态/无敌标记的正常回收。
- 已修改 `game/scripts/logic/RunEx.lua`：只重启普通敌人 AI；Boss 保持原 AI，目标选择继续由 `EnemyAiHooks` 指向最近存活玩家。
- 后续 `N_Boss02` 测试出现重复死亡回调，并在首次处理完成前报错；普通 room 也会复现。原生 `CoopRemovePlayerUnit()` 会在战斗伤害回调内直接执行 `unit->Delete()`，这是共同风险点。
- `RunHooks.KillHero()` 现会忽略已死亡 Hero 的重复回调，且不再删除 P2 原生单位，改为 `HeroEx.HideHero()`；敌方选目标会跳过 `IsDead` Hero。新增 `[CoopDeathTrace]`，普通房和 Boss 房都可记录死亡处理的前后状态。
- `CoopRun.ReviveHeroForNextRoom()` 改为重新显示保留的隐藏 Hero；新房入场流程仍负责最终传送位置。
- 错误窗口的本体日志最终定位为 `FamiliarLogic.lua:1092`：`PolecatFamiliarAI()` 在错误 Hero 上下文中取得空的 `traitData`。该调用由 P2 死亡后的 `HeroEx.HideHero()` 内部 `UnequipWeapon` 路径触发。P2 死亡处理进一步收敛为只标记 `IsDead`，不删除、不隐藏、不卸武器；敌人目标查询已自行跳过死亡 Hero。
- 后续普通房追踪显示 P2 已移除隐藏/删除操作后仍在 `death-marked` 后中断，剩余共享动作只有 `RunEx.RefreshEnemyAI()` 的敌人线程重建。已从死亡路径移除该重启；`EnemyAiHooks.GetTargetId()` 本来就会将目标查询导向最近存活玩家。
- 死亡状态原先只设置 `IsDead`，导致 P2 仍可移动和攻击。现在死亡处理为每位玩家添加 `CoopDeadPlayerX` 输入锁并将其单位透明，不调用会触发信物兽错误的 `UnequipWeapon`；Boss -> Rest Room 复活时移除输入锁并显示单位。

下一次测试：

- 在可转阶段 Boss 战中，等待转阶段完成后让 P2 死亡。
- 无论卡住与否，退出后读取 `%USERPROFILE%\Saved Games\Hades II\TN_CoopMod.log` 中的 `[CoopBossTrace]` 行，用该快照选择下一步修复。

最终测试结论：

- P2 在普通房或 Boss 房死亡均不再弹出错误窗口。
- 死亡玩家透明且输入锁定，无法继续移动或攻击；存活玩家可继续战斗。
- Boss 转阶段后 P2 死亡不再令 Boss 进入永久无敌。
- Boss -> Rest Room 后死亡玩家恢复可见和输入，复活流程通过实测。

## 2026-07-09

### Rest Room 信物柜开发与实测

开发目标：

- 原版 `Rest Room` 信物柜在玩家换一次信物后，会通过 `CurrentRun.CurrentRoom.BlockKeepsakeMenu = true` 锁住。
- co-op 目标是 P1/P2 在同一个 `Rest Room` 中各自可以换一次信物。
- 已知当前 mod 已有 `LastAwardTraitCoopPlayerX`，P2 可以独立选择信物；本次只补“信物柜使用次数/锁柜状态按玩家拆分”。

代码改动：

- 修改 `game/scripts/hooks/MenuHooks.lua`。
- 引入 `RunEx`，用于判断当前房间是否是 `Rest Room`。
- 新增 `MenuHooks.ActiveKeepsakeRackPlayerId`，在 `OpenKeepsakeRackScreen` 打开期间记录当前使用信物柜的玩家。
- 扩展 `MenuHooks.wrap.OpenKeepsakeRackScreen()`：
  - 默认无法识别玩家时回退到 P1。
  - P2 打开信物柜时继续临时交换 `GameState.LastAwardTrait` 和 `GameState.LastAwardTraitCoopPlayerX`。
  - P2 打开期间临时把 `CurrentRun.BlockedKeepsakes` 替换为 `CurrentRun.BlockedKeepsakesCoopPlayerX`，避免 P1/P2 的“本 run 已换下信物禁用列表”互相污染。
- 新增 `MenuHooks.wrap.UseKeepsakeRack()`：
  - 仅在 co-op 且当前房间为 `Rest Room` 时改变原版行为。
  - 如果当前玩家本房间已经使用过信物柜，则走原版锁柜提示。
  - 如果房间级 `BlockKeepsakeMenu` 已经因为另一个玩家换过信物而变成 true，会临时放开，让尚未使用过的玩家可以打开柜子。
- 新增 `MenuHooks.wrap.KeepsakeScreenClose()`：
  - 只有实际更换信物时，才记录本玩家已使用本房间信物柜。
  - 记录字段：`CurrentRun.CurrentRoom.CoopKeepsakeRackUsedByPlayer[playerId]`。
  - 两名玩家都使用后，才恢复原版锁柜表现：`UseLockedGiftRack` + `GiftRackClosed`。
  - 如果只是一名玩家使用完，保持 `UseAwardMenu`，让另一名玩家仍可使用。

部署：

- 已部署到游戏 mod 目录：

```text
<Hades II>\Content\Mods\TN_CoopMod\hooks\MenuHooks.lua
```

- 源文件和部署文件 SHA256 已确认一致。
- `git diff --check` 已通过。
- 本机没有 `lua` 命令，未能做 Lua 语法检查。

测试结论：

- `Rest Room` 中 P1/P2 都可以各自换一次信物，当前信物柜双人使用方案验证通过。
- P2 打开祝福/trait 面板时看到的是自己的面板，不是 P1 的面板；此前怀疑的 P2 祝福面板串到 P1 的问题不存在。
- 过门类阿卡那牌效果仍有不确定性：有时生效，有时不生效，需要后续单独复测和定位。

当前处理判断：

- 信物柜功能可以进入下一阶段观察，不再作为阻塞项。
- 暂时不要继续改 P2 祝福面板 UI。
- 下一步应优先调查房间推进类阿卡那的不稳定触发，再继续做固定 room 奖励双发放。

### 后续 co-op 功能方向

新增需求：

- P1/P2 阿卡那牌配置独立。
- P1/P2 信物选择独立。
- 在层与层之间的 `Rest Room`，两个玩家都能各自选择一次信物；原版单人中玩家选完新信物后，信物柜会锁起来。
- 拾取一个 room 固定奖励后，自动再刷一个奖励。
- 在双奖励基础上，影响祝福掉率/类型的信物按玩家分别生效：
  - P1 信物影响第一个祝福奖励。
  - P2 信物影响第二个祝福奖励。
  - 示例：P1 携带宙斯信物，P2 携带赫拉信物。进入 run 后，第一个初始祝福仍为宙斯，且稀有度提升正常生效；选择完后，再掉落赫拉祝福，赫拉信物的稀有度提升也正常生效。

实现判断：

- 当前阿卡那修复是强制解锁/强制满级的救援方案，不是最终方向。
- 最终方向应是：mod 不影响阿卡那系统本身的解锁、等级、layout 和配置，只在 co-op 运行时为每个玩家选择正确的配置上下文。
- 新功能建议从“信物独立 + Rest Room 双人换信物”起手，而不是先做阿卡那独立配置。

建议起手点：

1. 先做 P1/P2 信物独立和 Rest Room 双人换信物。
2. 再做固定 room 奖励双发放。
3. 再把影响祝福池/稀有度的信物接到双奖励上。
4. 最后做 P1/P2 阿卡那配置独立，并同时移除当前阿卡那强制修复逻辑。

理由：

- 信物系统当前已有 `LastAwardTraitCoopPlayerX` 存储路径，改动面比阿卡那小。
- 双奖励和信物影响祝福池强相关，适合在信物独立之后做。
- 阿卡那系统刚经历存档污染问题，必须等救援逻辑关闭并确认稳定后再做独立配置，否则容易再次破坏存档。

### 阿卡那等级临时恢复

测试结果：

- 阿卡那配置界面已确认恢复。
- 新问题：阿卡那牌等级全部变成最低等级。

处理前备份：

```text
%USERPROFILE%\Saved Games\Hades II\Profile1.sav.codex-before-arcana-level-repair-<timestamp>
```

本次处理：

- 新增临时开关 `Config.Debug.ArcanaMaxLevelRepair = true`。
- 在 `GameStateEx.RepairArcanaFullUnlockState()` 中，如果该开关开启，则把每张非 debug 阿卡那牌的等级设置为该卡最大等级。
- 不修改悟性上限、不修改装备配置、不修改资源。
- `[CoopArcanaRepair]` 日志新增 `maxed` 数量，便于确认有多少已解锁卡达到最大等级。
- 注意：这是救援/恢复用的临时方案，不是最终实现方向；最终目标仍然是 mod 不影响阿卡那系统的解锁、等级、layout 和配置。

已部署：

- `config.lua`
- `logic\GameStateEx.lua`

下一次测试：

- 先进 co-op 模式触发修复。
- 打开阿卡那界面，确认卡牌等级是否恢复到预期。
- 如果等级恢复正确，下一步应关闭 `ArcanaFullUnlockRepair` 和 `ArcanaMaxLevelRepair` 两个临时开关并重新部署。
- 如果不符合预期，可回到代码 tag：

```text
checkpoint-arcana-ui-repaired-levels-low-20260709
```

等级恢复成功后，已保留当前版本为新的检查点：

```text
checkpoint-arcana-ui-and-levels-repaired-20260709
```

### 阿卡那配置界面恢复

测试结果：

- 直接从单人入口进入时，阿卡那界面仍显示错误。
- 从 co-op 模式进入后，阿卡那界面恢复正常。
- 之后重新进入单人入口，阿卡那界面也恢复正常。

结论：

- 修复逻辑需要经过 co-op 模式初始化路径才会执行并写回存档。
- 一旦 co-op 路径写回了修复后的 `MetaUpgradeCardLayout` / `MetaUpgradeState.Unlocked`，后续单人入口也能正常显示。

当前处理策略：

- 暂时保留 `Config.Debug.ArcanaFullUnlockRepair = true`，再观察一轮，确认不会反复破坏配置。
- 确认稳定后，应关闭该临时修复开关，避免长期在每次打开阿卡那界面时强制改写解锁状态。

### 阿卡那状态识别错误排查

测试结果：

- 上一版仍未恢复，表现和之前一样。
- 当前判断：可能是游戏把 `MetaUpgradeLimitLevel` / `GetMaxMetaUpgradeCost()` / `ScreensViewed.MetaUpgradeCardLayout` 识别成初始状态，导致修复条件没有通过，或打开界面时又走回首次解锁路径。

本次处理：

- 将阿卡那恢复逻辑移动到 `GameStateEx.RepairArcanaFullUnlockState()`。
- 在两个时间点执行：
  - `GameStateHooks.post.InitializeMetaUpgradeState()`
  - `MenuHooks.HookUiControl("OpenMetaUpgradeCardScreen")` wrapper 内，调用原版界面函数前
- 临时开启 `Config.Debug.ArcanaFullUnlockRepair = true`，不再依赖游戏识别出来的悟性上限。
- 增加 `[CoopArcanaRepair]` 日志，记录：
  - `MetaUpgradeLimitLevel`
  - `GetMaxMetaUpgradeCost()` 识别结果
  - `MetaUpgradeCardLayout` 格子数
  - 已解锁阿卡那数量
  - `ScreensViewed.MetaUpgradeCardLayout`

已部署：

- `config.lua`
- `hooks\GameStateHooks.lua`
- `hooks\MenuHooks.lua`
- `logic\GameStateEx.lua`

下一次测试：

- 完全重启游戏后进入准备房打开阿卡那界面。
- 如果仍未恢复，读取 `%USERPROFILE%\Saved Games\Hades II\Hades II.log` 中的 `[CoopArcanaRepair]` 行，判断是状态识别错误还是界面逻辑覆盖。

### 阿卡那悟性恢复但牌面仍是初始 9 张

测试结果：

- 使用 `Profile1.sav.bak6` 后，阿卡那悟性上限恢复到 30。
- 进入准备房后，阿卡那牌面仍只显示初始 9 张。
- 结论：存档里的资源/悟性进度可恢复，但阿卡那 layout / unlocked 标记仍不完整。

本次处理：

- `MenuHooks.pre.OpenMetaUpgradeCardScreen()` 不再调用 `GameStateEx.CopyTraitsToMetaUpgrades(CurrentRun.Hero)`，避免打开阿卡那界面前把 hero traits 回写到 `GameState.MetaUpgradeState`。
- `GameStateHooks.post.InitializeMetaUpgradeState()` 增加保守修复：
  - 仅在当前悟性上限至少 30 时启用。
  - 补全 `GameState.MetaUpgradeCardLayout` 为原版 5x5 layout。
  - 将非 debug 阿卡那卡的 `Unlocked` 设为 true。
  - 不修改卡牌等级、不修改装备配置、不修改资源。
  - 标记 `GameState.ScreensViewed.MetaUpgradeCardLayout = true`，避免重复触发首次解锁提示。

已部署：

- `game/scripts/hooks/GameStateHooks.lua`
- `game/scripts/hooks/MenuHooks.lua`

下一次测试重点：

- 使用当前 `Profile1.sav`，完全重启游戏。
- 进入准备房打开阿卡那配置界面，确认是否显示完整 5x5 卡牌页。
- 检查是否仍弹出首次解锁阿卡那系统的提示。

### 阿卡那存档进度被重置

测试结果：

- 阿卡那配置界面仍未恢复。
- 读取存档页面显示阿卡那悟性只剩 10，说明 `MetaUpgradeState` 存档数据已经被写坏，不只是 UI 问题。

本次处理：

- `game/scripts/hooks/GameStateHooks.lua` 改为不再分离 `GameState.MetaUpgradeState`。
- 当前策略回到原版单份阿卡那存档：P1/P2 暂时共享 P1 的阿卡那配置，P2 开 run 时继续通过 `HeroEx.CreateFreshHero()` 装配同一份阿卡那效果。
- 已运行 `build_and_deploy.ps1`，部署目标只更新了 `hooks\GameStateHooks.lua`。

存档处理：

- 已备份当前损坏存档：

```text
%USERPROFILE%\Saved Games\Hades II\Profile1.sav.codex-before-arcana-restore-<timestamp>
```

- 已用最新可用备份恢复当前存档：

```text
%USERPROFILE%\Saved Games\Hades II\Profile1.sav.bak3
```

后续 `bak3` 实测仍不对，已继续恢复到：

```text
%USERPROFILE%\Saved Games\Hades II\Profile1.sav.bak6
```

恢复后的当前存档：

```text
%USERPROFILE%\Saved Games\Hades II\Profile1.sav
```

下一次测试重点：

- 完全重启游戏。
- 在读取存档页面确认阿卡那悟性是否恢复。
- 进入准备房打开阿卡那配置界面，确认 P1 是否显示完整卡牌页。
- 如果 `bak3` 仍然不对，再尝试更早且更大的备份，例如 `Profile1.sav.bak5`、`Profile1.sav.bak6` 或 `Profile1.sav.bak4`。

### 阿卡那配置界面仍未恢复

测试结果：

- 阿卡那配置界面仍然没有恢复到完整解锁状态。

本次处理：

- 继续保留已删除的 `ArcanaStateRepair.lua`，不再写入阿卡那解锁/等级状态。
- 修正 `HeroContextProxySpliterStore.Destroy()` / `Recreate()`：解除 proxy 前先把 P1 的分离数据写回目标表。
- `GameStateHooks.post.InitializeMetaUpgradeState()` 改为使用 `Destroy("GameState")` 后再重建，避免 `GameState.MetaUpgradeState` 被旧 proxy 链或空 raw 表污染。

已部署：

- `game/scripts/hooks/GameStateHooks.lua`
- `game/scripts/logic/HeroContextProxySpliterStore.lua`

下一次测试重点：

- 在准备房打开阿卡那配置界面，确认 P1 是否恢复完整卡牌页。
- 退出并重新打开界面，确认是否还会提示“可以解锁阿卡那牌”。
- 如果仍不恢复，下一步检查 `MenuHooks.pre.OpenMetaUpgradeCardScreen()` 和 `GameStateEx.CopyTraitsToMetaUpgrades()` 是否在打开界面前破坏 `MetaUpgradeState`。

## 2026-07-08

### GitHub 仓库状态

`https://github.com/whis113/hades2-coop.git` 已重新创建为 private 仓库。

本地工作副本：

```text
<previous local working copy>
```

已推送到远端：

```text
whis113/master
```

当前远端 HEAD：

```text
e5508a003baa29409a6a5a7b4b36e9106fe7e13f
```

额外创建了一个验证 clone：

```text
<temporary verification clone>
```

该 clone 已包含子模块 `libs/hades2-engine-interface`。

## 2026-07-07

### Session 上下文

当前工作副本：

```text
<previous local working copy>
```

原版/参考项目：

```text
<upstream/reference project>
```

### 构建 / 部署脚本

本轮之前已经修复当前工作副本中的开发脚本：

- `install_all.ps1`
- `dev_deploy.ps1`
- `build_and_deploy.ps1`
- `build_and_deploy.bat`

CMake 自动检测会在 `PATH` 中没有普通 `cmake` 时使用 Visual Studio 自带 CMake。

本机已知 CMake 路径：

```text
<Visual Studio installation>\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe
```

### 复活功能

已实现并验证 Boss -> Rest Room 复活逻辑。

行为：

- 死亡玩家不会在普通同层过门时复活。
- 死亡玩家只会在存活玩家清完 `Boss Room` 并进入后续 `Rest Room` 时复活。
- 复活玩家保留死亡前状态，包括血量上限和已获得祝福。

主要文件：

- `game/scripts/logic/CoopRun.lua`
- `game/scripts/logic/RunEx.lua`
- `game/scripts/hooks/RunHooks.lua`

### P2 普通过门后消失

修复了两个玩家都存活时，普通门 transition 后 P2 消失的问题。

关键变化：

- 恢复 `CoopRun.OnRoomPresentationFinished()` 中对存活 P2 的初始化/重新绑定逻辑。

### P2 run 开始时丢失阿卡那效果

问题：

- P2 在 run 开始时没有获得阿卡那效果。
- 可见症状：P1 因阿卡那有 70 血量上限，P2 只有基础 30 血量上限。

修复：

- `HeroEx.CreateFreshHero()` 现在会等待 `EquipPreRunMetaUpgrades()` 完成。
- `GameStateHooks.wrap.EquipMetaUpgrades()` 现在尊重显式 hero context。

已验证：

- P2 在 run 开始时获得阿卡那效果。
- P2 死亡后仍保留阿卡那效果。

主要文件：

- `game/scripts/logic/HeroEx.lua`
- `game/scripts/hooks/GameStateHooks.lua`

### 房间推进类阿卡那

问题：

- `ChamberHealthMetaUpgrade` 这类房间推进效果没有按 co-op 预期同时作用于两个玩家。

设计决定：

- 两个玩家都存活时，一个玩家过门应视为两个存活玩家一起通过房间。
- 死亡玩家在复活前不获得房间推进类效果。

实现：

- 新增 `game/scripts/hooks/TraitHooks.lua`。
- 在 `game/scripts/GamemodeInit.lua` 中注册。
- `CheckChamberTraits()` 现在会对每个存活 hero 各执行一次。

状态：

- 已实现并部署。
- 等待实机验证。

### 已知问题：NPC 助战事件房 softlock

观察：

- 在 NPC 助战事件房中，如果其中一个玩家死亡，可能出现 softlock。
- 触发原因未确认。

下一次复现时需要收集：

- Room name
- NPC/helper name
- Encounter name/type
- 哪个玩家死亡
- 哪个玩家存活
- 敌人 / all-enemies-dead 状态
- 出口解锁状态

### 最近成功部署

`build_and_deploy.ps1` 成功将修改后的 Lua 文件部署到：

```text
<Hades II>\Content\Mods\TN_CoopMod
```

最近复制过的文件包括：

- `logic\CoopRun.lua`
- `logic\RunEx.lua`
- `hooks\GameStateHooks.lua`
- `logic\HeroEx.lua`
- `GamemodeInit.lua`
- `hooks\TraitHooks.lua`
