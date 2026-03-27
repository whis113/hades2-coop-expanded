# Hades II coop mod

Play Hades 2 with a friend!
This mod adds local cooperative multiplayer to Hades 2, allowing two players to fight through the Underworld together on the same PC.

For online play: Use a streaming tool like [Parsec](https://parsec.app/) to share your game session with a remote friend.

The mod supports the **Steam** and **Epic Games Store** versions of the gamme

**Warning**

You need a gameplay to play this mod.

# Intalling

1. Download the latest release of this mod from the [releases page](https://github.com/Hades2-coop-project/hades2-coop/releases)
2. Unpack the archive
3. Run `install.ps1` with powershell

# Build

## Using CMake for Windows x64

```powershell
cmake -A x64 . -B build_msvc
cmake --build build_msvc --config Release
```

Copy files from `build_msvc/bin` to the `Hades II/Mods/TN_CoopMod` folder.

## Using [Visual Studio](https://visualstudio.microsoft.com/) GUI

You need to install cmake in the Visual Studio Installer to build the project.
Open the project in VS and click Build -> Install HadesCoop in the top menu.

Copy files from `build_msvc/bin` to the `Hades II/Mods/TN_CoopMod` folder.
