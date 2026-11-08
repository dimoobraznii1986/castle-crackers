# CLAUDE.md

Notes for Claude Code when working on this repo.

## Project

**Castle Crackers**: a turn-based 2D castle artillery game, made for a kid (Michael) and his dad.
Each player has a castle with a treasure inside. Destroy the enemy treasure to win.
Modes: 2 players on one computer, vs computer, practice.

- `godot/` is the main version: Godot **4.7**, GDScript, GL Compatibility renderer (so web export works).
- `web/` is the first prototype (plain HTML canvas). Keep it working, but put new features in `godot/`.

## Run and test

```bash
cd godot
godot --path .                                              # play
godot --headless --fixed-fps 60 --path . -- --autotest      # fast test, prints TEST PASS / TEST FAIL
godot --path . -- --autotest                                # same test with a window, saves screenshots to user://
```

Run the autotest after every change. It must end with `TEST done, fails=0`.
Screenshots go to `~/Library/Application Support/Godot/app_userdata/Castle Crackers/shot_*.png`.
After adding a new script with `class_name`, run `godot --headless --path . --import` once.

## Code map (godot/)

| File | What it does |
|---|---|
| `scripts/main.gd` | Rules and state: turns, weapons, physics, soldiers, towers, computer player, camera. Castle shapes are in `LAYOUTS`, weapons in `WEAPONS`. |
| `scripts/world_view.gd` | Draws the battlefield with `_draw()` (no sprites yet). |
| `scripts/hud.gd` | Screen UI: panels, weapon bar, title / land / game-over screens. |
| `scripts/themes.gd` | Lands (sky, ground colors, terrain shape) and castle stone colors. |
| `scripts/backdrop.gd` | Sky, mountains (parallax), clouds, water/lava, snow/embers. |
| `scripts/terrain.gd` + `shaders/terrain.gdshader` | Destructible ground. 2 bytes per pixel (solid, burn). The shader paints it. |
| `scripts/sfx.gd` | Sounds made with code (no sound files). |
| `scripts/autotest.gd` | Automatic test, run with `-- --autotest`. |

Everything is built in code from `scenes/main.tscn` (one node). There are no other scenes yet.

## How to add things

- **New land:** add a block in `Themes.get_theme()` and its id to `Themes.LIST`. Add a short text in `Hud.LAND_INFO`.
- **New castle shape:** add to `LAYOUTS` in `main.gd`. Rules:
  - 14 columns. Drawn for RED; BLUE gets the mirror image.
  - `#` brick, `F` brick with flag, `^` brick with roof, `C` cannon spot (empty cell, bricks under it).
  - Keep the 6-wide treasure room in the middle and a full floor row at the bottom.
  - Rooms or gaps wider than 7 bricks make the ceiling fall (bridge rule in `block_supported`, max 6 steps).
- **New weapon:** add to `WEAPONS` (and `PROJ` if it flies), add a key in `KEYS`, handle it in `use_weapon()` or `impact()`, and draw it in `world_view.gd`.

## GDScript gotchas we hit

- `var x := <Variant expression>` fails ("Cannot infer the type"). Use `var x: float = ...` when the value comes from a Dictionary, an untyped object, or an untyped array.
- Constant arrays and dictionaries are read-only. Call `.duplicate()` before changing them.
- An object running an `await` coroutine must be kept in a variable, or it is freed and the coroutine stops.
- In canvas shaders, `TEXTURE` cannot be passed to a helper function. Sample it inside `fragment()`.
- The `∞` sign is tiny in the system font. Use words like "FREE".
- Headless `print` output is buffered when piped. Write to a file and read it after the process exits.

## Style

- Simple English in comments, docs, commits and PRs: short sentences, simple words.
- Tabs for indentation in GDScript.
- Keep the game kid-friendly: cartoon style, no blood.
