# Hades II Co-op

![Status](https://img.shields.io/badge/status-in%20development-orange)
![Platform](https://img.shields.io/badge/platform-Windows-blue)
![Game](https://img.shields.io/badge/game-Hades%20II-red)
![License](https://img.shields.io/badge/license-MIT-green)

Hades II local two-player co-op mod workspace, extending the upstream co-op foundation with stable roguelike gameplay rules and compatibility fixes.

Chinese version: [`README_ZH.md`](README_ZH.md).

## Scope and Attribution

The upstream `hades2-coop` project provides the local P1/P2 framework: player creation, controller binding, units, cameras, HeroContext, proxy and thread isolation, base HUD adaptation, and hook infrastructure.

This workspace owns gameplay extensions: boss-to-rest revival, death handling, independent keepsakes and Arcana loadouts, duplicated rewards, special-boss/menu compatibility, and diagnostics. Do not attribute the inherited framework to this extension.

## v0.2 Status

Verified:

- P1/P2 independent Arcana loadouts, including separate configurations in the same layout slot. Native unlocks, card levels, and grasp progression remain shared.
- Per-player temporary Arcana cards from Judgment and Circe's Crystal Figurine.
- Independent keepsake changes, one Rest Room rack use per player, and two fountain uses.
- A surviving player can continue after the other dies; the dead player revives after the layer boss and the following Rest Room.
- Chronos clear recovery for P1-only, P2-only, and two-player survival; Prometheus phase-transition deaths preserve the native landing sequence.
- Broad dual reward coverage for ordinary, Elite, Chaos, Fields, ship-wheel, and most NPC/event paths. The second god boon is independently generated; hammer choices use each player's weapon pool.

Still under test:

- Hub HP/MP HUD does not always refresh immediately after a run.
- Zagreus challenge rewards generated in `F_PreBoss` are not yet duplicated.
- Fields `TalentDrop` and rare NPC/event combinations need external regression coverage.
- Legacy Arcana unlock/max-level recovery switches must be removed without affecting partial-progress saves.

## Installation

For external testing, use `release/Hades2Coop-v0.2-TestBuild.zip`.

1. Extract the archive without separating `Hades2CoopInstaller.exe` from `TN_CoopMod`.
2. Run `Hades2CoopInstaller.exe`.
3. Select `<Hades II>\Ship\Hades2.exe`.
4. Choose Install or Update. The installer only manages `<Hades II>\Content\Mods\TN_CoopMod`.
5. Use Uninstall in the same installer to remove the mod payload.

For development:

```powershell
Set-Location E:\hades2coop\workplace\hades2-coop-expanded
.\install_all.ps1
.\build_and_deploy.ps1
```

Use `install_all.ps1` for initial setup and `build_and_deploy.ps1` after every development change, including Lua-only changes.

## Tester Quick Start

Run the game in co-op mode and keep the mod log open in a separate PowerShell terminal:

```powershell
Get-Content "$env:USERPROFILE\Saved Games\Hades II\TN_CoopMod.log" -Wait
```

Defect reports should include the route, room label, P1/P2 state, reproduction steps, and relevant trace lines.

## Project Layout

```text
workplace/hades2-coop-expanded/   Active C++ and Lua working copy
reference project/                Upstream/reference projects; do not edit by default
ARCHITECTURE.md                   English technical architecture
ARCHITECTURE_ZH.md                Chinese technical architecture
PROJECT_LOG.md                    English chronological project history
PROJECT_LOG_ZH.md                 Chinese chronological project history
TODO.md                           Current work and validation list
SESSION_NOTES.md                  Session handoff notes
```

## Terminology

- `Run`: one full attempt, from start to win, death, or return.
- `Layer`: a major biome or stage segment, usually a `RoomSetName`.
- `Room`: one playable map instance.
- `Transition`: moving through a door to another room.
- `Rest Room`: the safe inter-layer room after a boss.
- `Elite Room` / `Miniboss Room`: a stronger encounter, not necessarily a layer boss.

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the full room naming table and architecture boundaries.

## Contribution

Read [`AGENTS.md`](AGENTS.md), [`TODO.md`](TODO.md), and the architecture document before changing gameplay behavior. Keep code comments in Chinese and English, preserve upstream attribution, and update both language versions of affected documentation.

## License

See [`LICENSE`](workplace/hades2-coop-expanded/LICENSE).
