# Hades II Co-op Architecture Notes

Last updated: 2026-07-14

Chinese version: [`ARCHITECTURE_ZH.md`](ARCHITECTURE_ZH.md).
Repository root: `hades2-coop-expanded/`

## Project Goal

The current work is focused on extending and stabilizing the original Hades II local co-op project before any remote/network co-op work resumes.

The original project provides the local two-player foundation: player creation, controller binding, unit management, camera, HeroContext, per-player proxies, thread isolation, HUD adaptation, and the hook/load framework. This working copy adds gameplay rules and compatibility fixes on top of that foundation. The original game assumes a single `CurrentRun.Hero`, while the inherited framework makes existing single-player Lua and engine systems operate with multiple heroes.

## Ownership Boundary

| Area | Source | Current-copy responsibility |
|------|--------|-----------------------------|
| P1/P2 creation, controllers, units, camera, HeroContext, proxy isolation, hook framework | Original project | Preserve and avoid attributing as new functionality. |
| Boss -> Rest Room revive and dead-player state recovery | Current extension | Implement and verify without breaking the inherited player lifecycle. |
| Per-player keepsake rack, independent Arcana loadouts and temporary Arcana cards, reward duplication, NPC/Chaos/Fields/ship reward paths | Current extension | Add player-specific native-context handling and room-specific reward rules without changing shared Arcana progression. |
| Debug traces, location tags, P2 menu-control stack and Selene Spell investigation | Current extension | Diagnose interactions between the inherited framework and Hades II native flows. |

## High-Level Load Chain

```text
Hades2.exe
  -> ASI / mod loader
    -> HadesCoopGame.dll
      -> Lua scripts under Content/Mods/TN_CoopMod
        -> init.lua
          -> GamemodeInit.lua
            -> HookStorage
```

## Core Layers

| Layer | Files | Role |
|------|-------|------|
| Native C++ | `game/src/` | Engine hooks, player creation, Lua C API. |
| Lua logic | `game/scripts/logic/` | Co-op lifecycle, hero context, player state, camera, UI, loot. |
| Lua hooks | `game/scripts/hooks/` | Wrap/patch game functions by system. |
| Utility hooks | `game/scripts/utils/` | `SimpleHook`, `HookUtils`, `HookStorage`, table helpers. |

## Core Mechanisms

### Hero Context

`logic/HeroContext.lua` is the central abstraction.

Hades II game code reads `CurrentRun.Hero` everywhere. The mod replaces direct storage with a metatable-backed lookup that returns the hero associated with the current coroutine. This lets existing game functions run as if they were still single-player, while the mod chooses whether they operate on P1 or P2.

Important functions:

- `HeroContext.InitRunHook()`
- `HeroContext.RunWithHeroContext(hero, fun, ...)`
- `HeroContext.RunWithHeroContextAwait(hero, fun, ...)`
- `HeroContext.IsHeroContextExplicit()`

### Native Main Player Swap

Some engine-level functions ignore Lua context and operate on the native main player. `HeroContextNative.lua` and the C++ player-manager extension temporarily swap the active native player so these functions can operate on P2 when required.

### Per-Player Data Isolation

The mod isolates global state that Hades II normally stores once:

- `CurrentRun.Hero.Traits`
- `GameState.MetaUpgradeState`
- selected `MapState` keys
- selected `SessionMapState` keys
- `ScreenAnchors`
- `HUDScreen`
- `LootTypeHistory`

Main files:

- `HeroContextProxy.lua`
- `HeroContextProxySpliter.lua`
- `HeroContextProxyStore.lua`
- `HeroContextProxySpliterStore.lua`

### Hook Framework

Hooks are registered through `GamemodeInit.lua` and `HookStorage`.

Common hook patterns:

- `pre`: run before original function.
- `post`: run after original function.
- `wrap`: receive original function and control invocation.
- `replace`: fully replace original function.

## Level and Room Terminology

Use these terms consistently:

| Term | Meaning |
|------|---------|
| `Run` | One complete attempt. |
| `Layer` | Player-facing biome / major stage segment, usually `RoomSetName`. |
| `Room` | One playable map instance. |
| `Transition` | Moving from one room to another. |
| `Intra-layer Transition` | Same-layer door transition. |
| `Layer Transition` | Transition between major layers. |
| `Boss Room` | Major boss room, usually named like `F_Boss01`. |
| `Rest Room` | Post-boss safe room, usually named like `F_PostBoss01`. |
| `Event Room` | NPC/story/special room. |
| `NPC-assist Event Room` | Event/combat room involving helper NPC participation. |

Known `RoomSetName` values:

| RoomSetName | Layer |
|-------------|-------|
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

Useful fields:

- `CurrentRun.CurrentRoom.Name`
- `CurrentRun.CurrentRoom.RoomSetName`
- `CurrentRun.CurrentRoom.NextRoomSet`
- `CurrentRun.CurrentRoom.BiomeStartRoom`
- `CurrentRun.CurrentRoom.HeroEndPoint`
- `door.Room`

## Current Gameplay Fixes

### Reward Expansion and Diagnostics

Room rewards are no longer handled by a single generic path. The native game uses separate creation flows for ordinary encounters, Fields reward cages, optional Fields mini rewards, ship-wheel rewards, Chaos, NPC events, and shops.

- `logic/loot/LootShared.lua` owns the ordinary/Elite/no-encounter second-reward paths and the dedicated `RoomSetName == "O"` / `GeneratedO` ship-wheel path.
- Mourning Fields (`RoomSetName == "H"`) main rewards are marked before native code destroys `FieldsRewardCage`; consumables use the native respawn-after-use pattern, and optional mini rewards have their own physical duplicate path.
- A second god boon is generated in the receiving player's `HeroContext` through native `SetupRoomReward()` / `GiveLoot()` rules. Fixed rewards remain copies. Same-god results are valid.
- `CoopAppendTraceLog()` in `LuaFunctionDefs.cpp` adds a location tag to every mod trace. The tag maps `F-I` to the four Underworld layers and `N-P` to the three Surface layers, then appends room kind and internal room name.

### P2 Spell HUD Investigation

P2 Selene Spell HUD is intentionally not fixed through the general trait-tray layout. `UIHooks.lua`, `MenuHooks.lua`, and `CoopRun.lua` emit `[CoopSpellUiTrace]` for the menu context, spell anchor creation, and room-presentation snapshots immediately and 0.4 seconds after a transition. The next UI change must be limited to P2's Spell anchor above the right-side health/mana bars, after trace evidence identifies the rebuild point.

### Boss-to-Rest-Room Revive

Current design:

- Ordinary same-layer door transitions do not revive dead players.
- A dead player revives only when the surviving player clears a `Boss Room` and enters the following `Rest Room`.
- The revived hero keeps pre-death max health and acquired boons.

Main files:

- `logic/CoopRun.lua`
- `logic/RunEx.lua`
- `hooks/RunHooks.lua`

`RunEx.ShouldReviveDeadPlayersOnTransition(currentRoom, door)` detects Boss -> Rest Room transitions using room-name helpers.

### Chronos Clear Compatibility

This is a current-extension compatibility layer, not an original-project co-op feature.

- Native staged boss coroutines can retain the hero context that started the room. If that hero dies, `HeroContext` falls back to the living default hero for long-running combat work.
- Player death retargets and releases active boss waits but does not restart an `AIStages` boss from phase one. Restarting a staged Chronos AI corrupts phase-local state.
- `ChronosKillPresentation` is owned by the living player. `MenuHooks` temporarily releases P1's dead-input block while P2 owns the native clear screen, then `ChronosRecovery` restores the survivor's camera and movement after close.
- Verified on 2026-07-13: P1-only alive, P2-only alive, and both-alive Chronos clears all complete the clear screen, collect `MixerIBossDrop`, and enter `I_PostBoss01`.

### Independent Arcana Loadouts and Temporary Cards

This is a current-extension feature, not an original-project co-op feature.

- P1 keeps the native shared `GameState` Arcana view. P2 loadouts are stored at `GameState.CoopArcanaLoadouts.Players[2].Layouts` and contain only equipped-card selections and the selected layout.
- Unlocks, card levels, grasp, resources, and tutorials remain native shared save progression. P2's editor may equip unlocked cards but cannot unlock cards, upgrade cards, or buy grasp.
- P2 editor/tray/runtime operations temporarily install P2's view, invoke native functions, then restore P1's shared view. This permits different P1/P2 layouts even when both select the same numbered set.
- `AddRandomMetaUpgrades()` writes P2 temporary cards to `CurrentRun.CoopTemporaryMetaUpgrades[2]`. Judgment and Circe's Crystal Figurine are replayed for P2 from the native `CombatLogic.Kill` post-Boss gate, so special Bosses and minibosses follow native unit flags rather than room-name assumptions.
- Verified on 2026-07-14: independent editing, persistence, reload, run application, death retention, Judgment, Crystal Figurine, and P2 Trait Tray display.

### Prometheus Memory-Presentation Death Compatibility

This is a current-extension boss compatibility fix, not an original-project co-op feature.

- During `PrometheusMemoryPresentation`, native scripts run a separate `PrometheusNotify` sequence that returns the boss from the elevated fire-wave state, restores scale/collision/targeting, and clears invulnerability.
- `RunHooks.WakeBossAiAfterPlayerDeath()` now defers normal boss wake/retarget work for that specific presentation flag. Releasing `WaitForRotation` during the presentation skips the native outro and leaves an oversized, unreachable boss.
- Verified on 2026-07-14: one player can die during the fire-wave transition; Prometheus lands and resumes normal combat.

### First External Test Delivery

- `tools/TesterInstaller` contains the self-contained Windows installer source.
- `build_tester_package.ps1` publishes `Hades2CoopInstaller.exe`, packages the current `TN_CoopMod` payload, and creates `release/Hades2Coop-v0.2-TestBuild.zip`.
- The installer receives a selected `Ship/Hades2.exe` path and only manages `Content/Mods/TN_CoopMod`; it does not modify native game scripts or save data.

Issue fixed:

- P2 previously started a run without Arcana effects, visible as P1 having 70 max HP while P2 had base 30 max HP.

Fix:

- `logic/HeroEx.lua` now waits for `EquipPreRunMetaUpgrades()` during fresh hero creation.
- `hooks/GameStateHooks.lua` now respects explicit hero context in `EquipMetaUpgrades` instead of blindly broadcasting through stale hero lists.

Verified:

- P2 receives Arcana effects at run start.
- P2 keeps Arcana effects after death.

### Room-Progress Arcana

Issue:

- Arcana effects such as `ChamberHealthMetaUpgrade` (`+5 HP/+5 MP` after room progress) were not applying correctly for both players.

Implementation:

- Added `hooks/TraitHooks.lua`.
- Registered it in `GamemodeInit.lua`.
- `TraitHooks.wrap.CheckChamberTraits()` runs the original `CheckChamberTraits()` once per alive hero using `HeroContext.RunWithHeroContextAwait()`.

Awaiting verification:

- Both alive players should gain room-progress effects when one alive player uses a door.
- Dead players should not gain these effects until revived.

## Known Risks

### NPC-Assist Event Room Softlock

Observed risk:

- In event rooms with NPC assistance, if one player dies, the room may softlock.

Trigger is unknown. Next repro should capture:

- Room name
- NPC/helper name
- Encounter name/type
- Which player died
- Which player remained alive
- Enemy state
- Exit unlock state
- Whether `OnAllEnemiesDead`, `CheckRoomExitsReady`, or `RestoreUnlockRoomExits` fired

Likely files to inspect:

- `hooks/RunHooks.lua`
- `hooks/EnemyAiHooks.lua`
- `hooks/DamageHooks.lua`
- `logic/CoopRun.lua`
- original game `EncounterLogic.lua` / `RoomLogic.lua`

## Key Modified Files

| File | Purpose |
|------|---------|
| `game/scripts/logic/CoopRun.lua` | Run/room lifecycle, revive gating, room presentation handling. |
| `game/scripts/logic/RunEx.lua` | Room helpers and Boss -> Rest Room transition detection. |
| `game/scripts/logic/HeroEx.lua` | Fresh hero creation and pre-run upgrade setup. |
| `game/scripts/hooks/GameStateHooks.lua` | Per-player `GameState.MetaUpgradeState`, Arcana equip behavior. |
| `game/scripts/hooks/TraitHooks.lua` | Room-progress trait handling for all alive players. |
| `game/scripts/GamemodeInit.lua` | Hook registration. |
| `game/scripts/hooks/RunHooks.lua` | StartRoom/LeaveRoom/exits/restore handling. |

## Network Direction

Network co-op remains a later-stage goal. Do not start network architecture changes until local two-player behavior is stable.

When returning to networking, prefer:

- ENet/UDP for frequent input and movement state.
- Reliable events for room transition, enemy creation/death, damage, boon selection, and revive.
- Existing references: `HadesMP/Core/Network/packets.h`, `client.h`, `server.h`, plus `hades-mp` ASIO code.
