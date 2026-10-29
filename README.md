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

The repository holds the mod's source and its headless test suites. Releases are built and verified with the project's build tooling: the suites run on the packaged zip in an external engine copy, then against a staged copy of the installed game and its imported data. Install the release zip.
