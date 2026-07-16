# Hades II Co-op 架构说明

英文版本：[`ARCHITECTURE.md`](ARCHITECTURE.md)。

## 项目目标与归属

本工作副本在原项目 `hades2-coop` 的本地双人基础上扩展和稳定玩法。原项目负责 P1/P2 创建、控制器、角色单位、镜头、HeroContext、代理隔离、线程隔离、基础 HUD 与 hook 框架。

当前扩展只负责双人死亡与 Boss -> Rest Room 复活、独立信物、独立阿卡那预设与临时卡、房间奖励双发、特殊 Boss/菜单兼容和调试工具。不要将继承的双人基础设施标记为当前扩展新增功能。

## 加载链与分层

```text
Hades II
  -> ASI / mod-extension loader
    -> HadesCoopGame.dll
      -> game/scripts/init.lua
        -> GamemodeInit.lua and Lua hooks
```

- Lua 层：`game/scripts/`，部署到 `Content/Mods/TN_CoopMod/`。
- C++ 层：原生 DLL 提供引擎 hook 与 Lua bridge API。
- 引擎层：Forge Engine、Lua 5.2 VM、`PlayerManager`、`Player` 与 `PlayerUnit`。
- 原生桥接负责玩家创建、控制器绑定、角色单位生命周期、物品使用和动画切换。`hades2-engine-interface` 提供逆向的引擎头文件。

## 核心机制

- `HeroContext.lua` 通过协程上下文让 `CurrentRun.Hero` 返回对应的 P1 或 P2。
- `HeroContextNative.lua` 在必须调用原生主玩家逻辑时临时交换 `PlayerManager` 的主玩家槽位。
- `HeroContextProxy*.lua` 隔离 `LootTypeHistory`、部分 `MapState`、`SessionMapState`、`GameState.MetaUpgradeState`、`ScreenAnchors` 与 `HUDScreen` 等全局数据。
- `ThreadSplitHooks.lua` 为 timer/event 线程附加玩家后缀，避免 P1/P2 共用线程名称。
- `SimpleHook.lua`、`HookUtils.lua` 与 `HookStorage.lua` 提供 pre/post/wrap/replace hook，并区分 `EngineInit` 和 `GameInit`。

## 独立阿卡那边界

- P2 装备数据位于 `GameState.CoopArcanaLoadouts.Players[2].Layouts`。
- P1/P2 可独立编辑和使用预设，即使选择同一个 Set 编号也不互相覆盖。
- 解锁、卡牌等级、悟性、资源和教程仍是原版共享的 `GameState` 进度。
- 审判与水晶雕像等临时卡位于 `CurrentRun.CoopTemporaryMetaUpgrades[playerId]`；Boss 条件必须复刻 `CombatLogic.Kill` 的原生判断，不能通过房间名推断。

## 奖励和菜单上下文

- 固定资源奖励通常复制同类型实体；主神 boon 的第二份需在另一玩家 HeroContext 下按本体规则重新生成。
- 锤子候选必须按领取玩家的武器池生成；同武器时也必须使用独立候选随机状态。
- Chaos、原野 cage/optional、船舵 `GeneratedO`、NPC 事件等均有独立入口，不能只依赖普通房清场路径。
- 菜单使用 owner 栈；嵌套面板关闭后必须恢复给父菜单所属的 P1 或 P2。

## 房间术语

| 英文术语 | 中文术语 | 含义 |
|---|---|---|
| `Run` | 一局 | 从开始至胜利、死亡或返回的一次尝试。 |
| `Layer` | 层 / 大关 | 玩家视角的生物群系或阶段。 |
| `Room` | 房间 | 一张可游玩的地图实例。 |
| `Transition` | 过门 | 从一个房间进入下一个房间。 |
| `Rest Room` | 层间休息房 | Boss 后、下一层前的安全房间。 |
| `Elite Room` / `Miniboss Room` | 精英 / 小 Boss 房 | 强化遭遇，不一定是层守卫。 |

常见 `RoomSetName`：`F/G/H/I` 为地下四层，`N/O/P/Q` 为地表路线，`Chaos`、`Anomaly`、`Dream` 为特殊分支。

## 调试与风险

- 使用 `TN_CoopMod.log`，所有 trace 应保留地点标签、玩家、房间、遭遇和关键对象 ID。
- 处理死亡时不得在战斗回调中直接删除 P2 原生单位，也不要重启具有阶段状态的 Boss AI。
- P2 Spell HUD 只能修改 P2 自己的组件，避免销毁被本体复用为 P1 HUD 的 anchor。
- 当前主要风险是 Hub HP/MP 延迟刷新、`F_PreBoss` 扎格列欧斯奖励、原野 `TalentDrop` 和罕见 NPC/事件组合。

## 过门基础 MP 回满

原版在 `LeaveRoom` 内通过一次 `RefillMana()` 执行过门回蓝；单人语义下它只作用于当前 hero。

- `RunHooks.pre.LeaveRoom` 只对这一次原版过门调用做单次截获，再在每名存活玩家的 `HeroContext` 中各执行一次原版函数。
- 这会恢复 P1/P2 按各自可用 MP 上限回满的基础行为；不是新增被动回蓝，也不改变其他 `RefillMana()` 调用点。
- 死亡 hero 不参与；`[CoopDoorManaTrace]` 每次 Transition 只记录一条前后 MP 诊断。
- 此行为与 `TraitHooks.CheckChamberTraits()` 的房间推进阿卡那处理相互独立。

## 网络方向

当前优先级是稳定本地双人。网络 co-op 必须等奖励、死亡、过门、UI 与特殊 Boss 流程稳定后再启动。

上述本地 `LeaveRoom` 重放属于同进程 HeroContext 适配，不是跨端同步协议。Network Lab 必须另行定义明确的所有权和可靠的 Transition/状态消息，不能把本地重放直接复用于远程同步。
