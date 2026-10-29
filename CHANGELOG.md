# 0.1.1

- Load on engine 0.3.97: the supported engine range is now `>=0.3.96 <0.4.0`.
- The logic now ships as a library bundled inside the mod; behaviour is unchanged.

# 0.1.0

- Reveal text a whole page or segment at a time across Gen 1 (`red`, `blue`, `yellow`), Gen 2 (`gold`, `silver`, `crystal`), and Gen 3 (`firered`, `leafgreen`, `ruby`, `sapphire`, `emerald`) on gen1recomp 0.3.96 (`"games": ["all"]`).
- Support overworld dialogue, signposts, yes/no menus, battle messages (`BattleState:updateQueue`), Gen 2 `Typer` menus, RSE `SceneKit` cutscenes, and FRLG intro speeches (`OakSpeech`).
- Preserve page advance prompts, confirmation buttons (`A`/`B`), yes/no choices, auto-scroll wait timers, and scripted pause markers.
- No settings menu, keybindings, or save mutations. Restores vanilla typewriter speeds cleanly on mod unload/reset.
- Verified across 240 headless assertions and standalone installed game checks on `firered`, `emerald`, `red`, and `crystal`.
