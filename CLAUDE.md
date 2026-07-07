# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

This is a **local co-op mod for Hades II** (Supergiant Games, 2024) that lets two players play on the same PC with two controllers. It does NOT use networking — users who want online play are directed to use Parsec.

- **Version**: 0.1.8
- **License**: MIT
- **Author**: Uladzislau "TheNormalnij" Nikalayevich
- **Distribution**: GitHub Releases + Thunderstore

## Build

```powershell
# From the hades2-coop directory:
cmake -A x64 . -B build_msvc
cmake --build build_msvc --config Release
```

Output lands in `build_msvc/bin/TN_CoopMod/` (DLL + Lua scripts). The built DLL is `HadesCoopGame.dll`.

Alternatively, open in Visual Studio with CMake tools installed, then Build → Install HadesCoop.

**Requirements**: CMake 3.20+, MSVC (Windows x64), git submodules (`hades2-engine-interface`).

## Tech stack

| Layer | Tech |
|-------|------|
| Native mod DLL | C++20, CMake |
| Game logic scripting | Lua 5.2 (the game's embedded runtime) |
| Target engine | Supergiant's proprietary AQUARIUS engine |
| Libraries | EASTL, Lua 5.2.2, hades2-engine-interface (reverse-engineered engine headers) |
| Injection | Ultra-ASI-Loader (bink2w64.dll proxy) |
| CI/CD | GitHub Actions (`build.yml` on push/PR, `release.yml` on `v*` tags) |

## Architecture

### Loading chain

```
Hades II (AQUARIUS engine)
  └─ ASI Loader (bink2w64.dll proxy)
      └─ HadesModNativeExtension.asi (mod loader)
          └─ HadesCoopGame.dll (this mod)
```

### C++ layer (`game/src/`)

The DLL exports three lifecycle functions called by the mod loader:

1. **`HadesModInit`** — Installs memory hooks (animation swap, magnetism fix, ally-model-limit assert suppression) and initializes the hook table.
2. **`HadesModStart`** — No-op, always returns true.
3. **`HadesModLuaCreated`** — Called when the Lua runtime is ready. Registers 14 C functions into Lua via `LuaFunctionDefs::Load`.

**`CoopContext`** (singleton) manages player creation, unit creation, item use, and player removal. It owns a `PlayerManager` that tracks up to `MAX_PLAYERS`. Key methods: `CreatePlayer`, `CreatePlayerUnit` (clones the base player's `MapThing` and spawns via `World::CreateThing`), `RemovePlayer`, `UseItem`.

**Memory hooks** (C++):
- **AnimSwapHook**: Hooks `Thing::SetAnimation`, `Unit::PlayMoveAnimation`, `AnimationManager::GetNameSwap` — enables per-player weapon animation swaps.
- **MagnetismHook**: Hooks `MagnetismSystem::UpdateThing` — fixes magnetism for Lob-type weapons in co-op.
- **AllyModelLimitsAssertHooh**: NOPs out debug assertions about exceeding max ally bone/triangle counts when two players' pets/allies are active.

### Lua layer (`game/scripts/`)

**Entry point**: `init.lua` loads the co-op menu, checks the "Coop" gamemode flag from temp runtime data, creates Player 2 if needed, then calls `GamemodeInit.lua`.

**Gamemode initialization** (`GamemodeInit.lua`):
1. Registers 25 Lua hook files (one per game system) via `HookStorage`
2. Sets up engine event handlers (`OnPreThingCreation`, `OnAnyLoad`, `OnMenuOpened`)
3. Fires `Events.engine:hooksPreInicialized` → inits HeroContext, HeroEx, HookStorage, CoopCamera, LootInterface, CoopGame → fires `hooksInicialized`

**HeroContext** (`logic/HeroContext.lua`) — The central architectural pattern:

Hades II is single-player by design: `CurrentRun.Hero` is a single hero reference. The mod makes it multi-player by:
- Replacing `CurrentRun.Hero` with a metatable-based getter that returns the **current thread's** hero.
- Each player's logic runs in its own Lua coroutine (created via `RunWithHeroContext`), bound to that player's hero.
- The mapping `CorontinueToHero` (weak-keyed table: coroutine → hero) tracks which hero each coroutine belongs to.
- Hooks `thread()` and `coroutine.yield()` to propagate hero context into spawned threads and clean up on task completion.

**HeroContextProxy** (`logic/HeroContextProxy.lua`) — Splits game data tables (e.g., Traits) into per-player sub-tables. When `CurrentRun.Hero.Traits` is accessed, it returns only the traits belonging to the currently active hero context.

**Event system** (`logic/Events.lua`) — Three observable event buses built on `utils/Observable.lua`:
- `Events.engine` — `hooksPreInicialized`, `hooksInicialized`, `presave`, `postsave`, `tick`
- `Events.run` — `newRunStarted`, `mapLoaded`, `roomPreStart`, `roomPresentationFinished`, `roomPreLeave`, `allEnemiesDead`
- `Events.game` — `comsumeAmmoItem`

**C++ bridge functions** registered in Lua (14 functions):
`CoopSetPlayerGamepad`, `CoopGetPlayerGamepad`, `CoopGetGamepadName`, `CoopGetPlayersCount`, `CoopCreatePlayer`, `CoopRemovePlayer`, `CoopHasPlayer`, `CoopCreatePlayerUnit`, `CoopRemovePlayerUnit`, `CoopUseItem`, `CoopSetCurrentMainPlayer`, `CoopResetCurrentMainPlayer`, `CoopSetAnimationSwap`, `CoopRemoveAnimationSwap`

### Key Lua source files

| Path | Purpose |
|------|---------|
| `scripts/init.lua` | Entry point, creates P2, loads gamemode |
| `scripts/config.lua` | User config (loot delivery mode, outlines, debug) |
| `scripts/GamemodeInit.lua` | Registers all hooks and engine handlers |
| `scripts/types.lua` | Lua type annotations for C++ bridge functions |
| `scripts/hooks/*.lua` | 25 hook files, each wrapping one game system |
| `scripts/logic/CoopGame.lua` | Game lifecycle, save/load orchestration |
| `scripts/logic/CoopRun.lua` | Run/room lifecycle, player spawning, death handling |
| `scripts/logic/CoopPlayers.lua` | Player management, hero-to-player binding |
| `scripts/logic/CoopCamera.lua` | Two-player camera |
| `scripts/logic/CoopControl.lua` | Input/controller binding |
| `scripts/logic/HeroContext.lua` | Thread-local hero context switching |
| `scripts/logic/HeroContextProxy.lua` | Per-player data table splitting |
| `scripts/logic/Events.lua` | Observable event system |
| `scripts/logic/loot/LootInterface.lua` | Reward distribution subsystem |
| `scripts/logic/saveHandlers/` | Save/load state management |
| `scripts/mainmenu/CoopMenu.lua` | Controller selection menu |
| `scripts/utils/` | Observable, HookStorage, HookUtils, SimpleHook, TableUtils |

## Level and room terminology

Use these terms consistently in code comments, docs, issues, and debugging notes:

| Term | Chinese shorthand | Meaning |
|------|-------------------|---------|
| `Run` | 一局 | One complete attempt from start until win/death/return. |
| `Layer` | 层 / 大关 | A player-facing biome or major stage segment. In code this usually maps to `RoomSetName`. |
| `Room` | 房间 / 小房间 | One playable map instance inside a layer. |
| `Transition` | 过门 | Moving from one room to another. |
| `Intra-layer Transition` | 同层过门 | Door transition where the next room stays in the same layer. |
| `Layer Transition` | 跨层 | Transition from one layer to another, usually after boss/rest progression. |
| `Combat Room` | 战斗房 | Normal enemy encounter room. |
| `Event Room` | 事件房 | NPC/story/special event room. |
| `Shop Room` | 商店房 | Charon/shop room. |
| `Recovery Room` | 回复房 | Healing or recovery-focused room. |
| `Boss Room` | Boss 房 | Major boss encounter room at the end of a layer segment. |
| `Miniboss Room` | 小 Boss 房 | Elite/miniboss encounter room. |
| `Rest Room` | 层间休息房 | Safe inter-layer room after a boss and before the next layer. |
| `Reward Room` | 奖励房 | Room primarily used to grant or resolve rewards. |
| `Door` | 门 | The exit object selected to enter the next room. |
| `Spawn Point` | 出生点 / 入口点 | The point where a hero should be created or moved after loading a room. |

Known `RoomSetName` values from the local Hades II scripts:

| `RoomSetName` | Player-facing layer |
|---------------|---------------------|
| `F` | Erebus |
| `G` | Oceanus |
| `H` | Mourning Fields |
| `I` | Tartarus |
| `N` | Ephyra |
| `O` | Rift of Thessaly |
| `P` | Olympus |
| `Q` | Summit |
| `Chaos` | Chaos branch |
| `Anomaly` | Anomaly branch |
| `Dream` | Dream branch |

Useful game fields when reasoning about room flow:

- `CurrentRun.CurrentRoom.Name`
- `CurrentRun.CurrentRoom.RoomSetName`
- `CurrentRun.CurrentRoom.NextRoomSet`
- `CurrentRun.CurrentRoom.BiomeStartRoom`
- `CurrentRun.CurrentRoom.HeroEndPoint`
- `door.Room`

## Revive feature target

The revive mod feature is intentionally scoped to a boss-to-rest-room recovery flow:

- If either player dies during a layer, that player should remain dead during ordinary `Intra-layer Transition`s.
- A dead player should revive when the surviving player clears a `Boss Room` and enters the following `Rest Room`.
- The revive path should restore the dead hero state, recreate or bind the player unit if needed, move the revived player to the rest room spawn point, refresh UI, and keep player-to-hero mappings valid.
- Do not treat every door transition as a revive trigger. Combat, event, shop, recovery, reward, and same-layer transitions should preserve the dead state unless the design is explicitly changed.

Minimum manual tests for this feature:

- P1 dies, P2 clears boss, enter rest room, P1 revives.
- P2 dies, P1 clears boss, enter rest room, P2 revives.
- Dead player does not revive after ordinary same-layer door transitions.
- Revived player has a valid unit, health, input, camera participation, HUD state, and spawn position.

Verified behavior as of local testing:

- Boss-to-rest-room revive works.
- Revived players preserve their pre-death state, including max health and acquired boons.
- P2 receives Arcana effects at run start and preserves them after death.

Recent implementation awaiting verification:

- `hooks/TraitHooks.lua` wraps `CheckChamberTraits()` so room-progress Arcana effects such as `ChamberHealthMetaUpgrade` run once for every alive player when one alive player uses the door.
- Intended behavior: if both players are alive, both players gain room-progress effects; if one player is dead, the dead player does not gain room-progress effects until revived.

Known issue to investigate:

- In NPC-assist `Event Room`s, if one player dies the room can possibly softlock. The trigger is not confirmed yet; collect room name, NPC helper, current encounter, alive/dead player, and exit unlock state before changing logic.

## Testing

There is no automated test suite. Testing is done manually by launching Hades II with two controllers.

## Code style

C++ formatting is LLVM-based (`.clang-format`): 4-space indent, 120 column limit. Lua files use `---@type` and `---@param` annotations for LuaLS type checking.

## Related subprojects in this workspace

- `jj-repository_HadesMP/` — Hades I networked co-op (C DLL proxies + Python bridge + TCP/UDP). Has its own `CLAUDE.md` and extensive `.claude/` docs.
- `hades-mp/` — Hades I/II C++ DLL loader + ASIO networking (WIP).
- `HadesMP/` — Hades I C++ DLL injection (stalled).
