# Instant Text

All dialogue, battle messages, and menus type out instantly across **Gen 1, Gen 2, and Gen 3** in **gen1recomp**. Both lines of each text page reveal immediately without waiting for individual character typewriter delays, regardless of your in-game TEXT SPEED setting.

Supports all games on **gen1recomp 0.3.96** (`"games": ["all"]`):
- **Gen 1 (`red`, `blue`, `yellow`):** Instant dialogue and signs (`TextBox`), plus instant battle message text (`BattleState:updateQueue`).
- **Gen 2 (`gold`, `silver`, `crystal`):** Instant dialogue and signs (`TextBox`), plus instant menu and battle text (`Typer`).
- **Gen 3 (`firered`, `leafgreen`, `ruby`, `sapphire`, `emerald`):** Instant dialogue and battle message boxes (`Message`), cutscene printers (`SceneKit`), and intro speeches (`OakSpeech`).

Page prompts, confirmation button waits (`A`/`B`), yes/no choices, auto-scroll timers, and intentional scripted pause markers remain 100% functional. No settings menu, save mutations, or key bindings.

## Installation

Download the ZIP from [Releases](https://github.com/hugo-cacciatori/instant_text/releases), extract its `instant_text` folder into your game's `mods/` directory, enable it in the mod manager, and launch any supported game. To disable, turn it off in the mod manager and restart.

## Development

Run the headless integration suite:

```powershell
python tools/test.py --engine C:/path/to/gen1recomp-0.3.96
```

Build the release archive and checksums:

```powershell
python tools/package.py
```

Verify the packaged ZIP against the engine and against the installed game data:

```powershell
python tools/test_package.py --engine C:/path/to/gen1recomp-0.3.96 --archive dist/v0.1.0/instant_text-0.1.0.zip
python tools/test_installed.py --installation C:/Users/<you>/AppData/Roaming/pokemon-love2d --archive dist/v0.1.0/instant_text-0.1.0.zip
```
