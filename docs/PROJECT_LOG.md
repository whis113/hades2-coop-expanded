# Project Log

Chinese version: [`PROJECT_LOG_ZH.md`](PROJECT_LOG_ZH.md).

> This log records gameplay development, investigations, tests, and releases. Documentation-only changes and workspace path migrations are intentionally excluded. Historical file paths and retired approaches are retained only when needed to explain a technical decision.

## 2026-07-15

### Arcana Progression Safeguard

- Disabled `ArcanaFullUnlockRepair` and `ArcanaMaxLevelRepair` after regression testing confirmed that independent P1/P2 Arcana loadouts and runtime effects remain functional.
- The extension now leaves native shared Arcana unlocks, card levels, grasp, tutorial state, and resources unchanged. The compatibility module and hook chain remain loaded because removing them caused save-load failures and prevented P2 creation.

### Co-op Enemy Health Scaling

- Located the native shared health path: enemy templates live in `EnemyData`, while `RoomLogic.SetupUnit()` applies native Elite and Shrine modifiers before assigning `unit.MaxHealth` and `unit.Health`.
- Added a co-op-only post-`SetupUnit()` hook that scales hostile enemy health after native modifiers. Default multiplier: `1.5x`; neutral, charmed, and allied units are excluded.
- Added `Hades2CoopEnemyScaler.exe`, which updates only the installed mod's `TN_CoopMod/config.lua` after the user selects `Ship/Hades2.exe`.

### v0.2.3 External Test Package

- Packaged v0.2.3 with the self-contained installer, full mod payload, `Hades2CoopEnemyScaler.exe`, and a package-root bilingual `README.md`.
- The installer deploys the health-scaling tool to `<Hades II>\Ship\Hades2CoopEnemyScaler.exe` and removes it on uninstall.
- Added bilingual package-root reminder files directing testers to read `README.md` before installation.
- Replaced the self-contained .NET HP tool with a native Win32 executable, preserving the English file-picker UI while reducing the tool to about 351 KiB.
- Package SHA-256: `80632434633D429D83BA48626779D3DAC55850AD341C2B09DA4974F9182F0056`.

## 2026-07-14

### v0.2 Release and Independent Arcana

- Released `Hades2Coop-v0.2-TestBuild.zip` with the self-contained installer, full `TN_CoopMod` payload, license, and bilingual tester guide.
- Verified independent P1/P2 Arcana loadouts. Players can use different configurations in the same layout slot; unlocks, card levels, grasp, resources, and tutorials remain native shared progression.
- Isolated P2 temporary Arcana cards for Judgment and Circe's Crystal Figurine in `CurrentRun.CoopTemporaryMetaUpgrades[2]`.
- Reproduced the native Boss condition from `CombatLogic.Kill` so temporary Arcana effects use actual boss semantics rather than room-name guesses.
- Fixed same-weapon hammer-option duplication by generating P2 candidates in P2 HeroContext with an independent random slot. Different weapons retain separate weapon pools.

### Regression State

- Boss-to-Rest revival, reward duplication, special-boss compatibility, independent keepsakes, fountains, and broad local two-player gameplay remain verified.
- Remaining work: refresh Hub HP/MP immediately after a run, cover `F_PreBoss` Zagreus rewards, and verify Fields `TalentDrop` plus rare NPC/event paths.

## 2026-07-13

### Chronos and Prometheus Compatibility

- Fixed Chronos clear flow for P1-only, P2-only, and two-player survival. Dead-player contexts now fall back to a living hero for long-lived combat coroutines.
- Death handling releases stalled boss waits, retargets living players, and avoids restarting staged boss AI from phase one.
- Run-clear menus suspend and restore dead-player input correctly; post-clear recovery restores the living player's camera, movement, and combat state.
- Prometheus deaths during the fire-wave presentation preserve native landing and invulnerability-release behavior instead of forcing ordinary AI wake-up.

### Rewards, Menus, and Spell HUD

- Verified Chaos dual boons and transition Arcana effects for both living players.
- NPC second-choice flow now assigns the second list to the other living player, avoiding recursive menus.
- Introduced a menu-owner stack so nested detail/tray screens restore the correct P1/P2 controller owner.
- Added P2 Selene Spell HUD diagnostics and per-player component ownership checks. Ship-wheel boon and optional reward paths were further instrumented and corrected.

## 2026-07-12

### Reward-Path Investigation and Coverage

- Added location-tagged trace output based on room set, layer, room type, and room name.
- Located the Thessaly ship-wheel reward entry at `RoomSetName == "O"` with `GeneratedO`; excluded its preliminary empty generation path.
- Added dedicated second-reward logic for ship-wheel boons and fixed rewards, with independent P2 boon selection and keepsake/rarity context.
- Added Mourning Fields optional-reward coverage and prevented miniboss rewards from receiving an unintended third boon.
- Added Fields reward pickup traces for cage rewards, miniboss rewards, and optional rewards to distinguish generation from collection failures.
- Began isolated P2 Selene Spell HUD tracing before changing layout behavior.

## 2026-07-11

### Death Stability and Dual Rewards

- Reworked P2 death handling after native unit deletion caused familiar-context crashes. Dead heroes are now marked, input-locked, and hidden without unsafe weapon/familiar teardown.
- Enemy targeting skips dead heroes; Boss-to-Rest revival restores visibility and input.
- Stopped rebuilding boss AI during player death after traces showed that it left boss state flags stuck and could block phase progression.
- Implemented broad second-reward spawning: ordinary rooms, Elite paths, no-encounter paths, Chaos, NPC/event flows, fountains, and initial run rewards.
- Added boon traces for force-boon keepsakes and rarity effects, then corrected the P2 reward-context routing.

## 2026-07-10

### Boss Death Investigation

- Added `CoopBossTrace` and `CoopDeathTrace` after a dead P2 could leave Polyphemus and other bosses inactive or invulnerable.
- Traces showed that the surviving player remained alive while boss required-kill state continued changing, excluding an ordinary full-party death path.
- Identified AI restart and native player-unit deletion as shared risk factors across normal and boss rooms.
- Iteratively narrowed death handling to duplicate-call protection, safe dead-state marking, living-target selection, and later revival restoration.

## 2026-07-09

### Keepsake Rack and Arcana Recovery Work

- Implemented one Rest Room keepsake-rack use for each player, including per-player blocked-keepsake state and final native lock after both players use the rack.
- Confirmed P2 uses its own trait panel and keepsake selection context.
- Established the intended roadmap: independent keepsakes, dual fixed-room rewards, player-specific boon-influencing keepsakes, then independent Arcana loadouts.
- Investigated Arcana UI/progression corruption. Temporary full-unlock and max-level recovery switches were used to restore test saves, with explicit intent to remove them after a runtime-only solution existed.

## 2026-07-08

### Arcana and Repository Baseline

- Rolled back an Arcana UI repair that reset configuration state and retained only the room-transition Arcana implementation in `TraitHooks.lua`.
- Continued investigating `ChamberHealthMetaUpgrade` value propagation and delayed P1 UI refresh.
- Established the active development and deployment scripts, including CMake fallback behavior when `cmake` is not available on `PATH`.

## 2026-07-07

### Initial Gameplay Extensions

- Implemented and verified Boss-to-Rest revival. A dead player does not revive during ordinary same-layer transitions and retains maximum health and boons after revival.
- Fixed P2 disappearing after ordinary room transitions by restoring alive-P2 initialization/rebinding during room presentation.
- Fixed P2 missing pre-run Arcana effects by waiting for native meta-upgrade equipment and respecting explicit hero context.
- Added room-transition Arcana processing for every living hero so shared door progress applies to both living players.
- Identified NPC-assist room softlock risk when one player dies; later death-flow fixes addressed this class of issue.
