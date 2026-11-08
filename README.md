# Castle Crackers

A turn-based castle battle game. Each player has a castle with a treasure inside.
Destroy the enemy treasure to win.

**Modes:** 2 Players (one computer), VS Computer, Practice (only you shoot, no timer, all weapons free).
**Lands:** Green Hills, Snowy Peaks, Desert Dunes, Lava Night, or Random.
Every battle has new castle shapes and colors.

There are two versions:

| Folder | What it is |
|---|---|
| `godot/` | **Main version.** Godot 4 project. Camera follows shots, computer opponent, nicer ground. |
| `web/` | First prototype. Plain HTML page. Open `web/index.html` in a browser. |

## Run the Godot version

1. Download Godot 4.7 (or newer) from https://godotengine.org/download. It is free.
2. Open Godot. Click **Import**. Choose the file `godot/project.godot`.
3. Press **Play** (F5).

## How to play

- **Aim:** move the mouse (or use the arrow keys).
- **Shoot:** hold the mouse button (or SPACE) to charge power. Let go to fire.
- **Choose an action:** click a button at the bottom, or press `1`-`9`, `0`, `Q`, `E`.
- **Sound:** press `M` to turn sound on or off.

One action per turn. You have 45 seconds.

## Actions

| Action | Cost | What it does |
|---|---|---|
| Cannonball | free | Small blast. Wind barely moves it. |
| Rocket | 30 | Big blast. Wind pushes it a lot. |
| Bouncy Bomb | 25 | Bounces. Explodes after 3 seconds. |
| Cluster | 45 | Splits into 5 small bombs. |
| Drill Rocket | 55 | Digs through walls, then explodes. |
| Giant Boulder | secret | Huge blast. Only from crates. |
| Meteor Storm | secret | 5 meteors fall where you click. Only from crates. |
| Paratroopers | 45 | 3 soldiers float down onto the enemy castle. Each turn they break a brick or steal treasure. The wind pushes them. |
| Guards | 35 | 2 guards land on your castle. Each turn they throw spears at enemy soldiers. |
| Archer Tower | 60 | Build it on your castle. It shoots enemy paratroopers in the air, and soldiers on your castle. |
| Build Wall | 35 | Drops a stone wall on your side of the map. |
| Repair | 50 | Fixes cracks and rebuilds up to 8 bricks. |
| Iron Armor | 110 | Bricks around your treasure become iron (half damage). |

You get 25 gold each turn, plus gold for damage to the enemy.
`?` crates fall from the sky. Shoot them to get gold, weapons, armor, repairs, or a secret weapon.

**Soldiers:** at the start of your turn, your soldiers and towers act first. Then you choose your action.

## Godot project files

| File | What it does |
|---|---|
| `scripts/main.gd` | Game rules, physics, turns, soldiers, computer player, camera. Castle shapes are in `LAYOUTS`. |
| `scripts/world_view.gd` | Draws castles, cannons, soldiers, towers, shots, explosions. |
| `scripts/hud.gd` | Screen UI: panels, buttons, title, land and game-over screens. |
| `scripts/themes.gd` | The lands (colors, terrain shape) and castle stone colors. Add new lands here. |
| `scripts/backdrop.gd` | Sky, mountains, clouds, water or lava, snow and embers. |
| `scripts/terrain.gd` | Ground that can be destroyed. |
| `shaders/terrain.gdshader` | Paints the ground: grass, soil, stones. |
| `scripts/sfx.gd` | Sound effects made with code. |
| `scripts/art.gd` | Drawing helpers and fonts. |
| `scripts/autotest.gd` | Automatic test. |

## Automatic test

```
cd godot
godot --headless --fixed-fps 60 --path . -- --autotest
```

It plays some turns, tests every action, and prints `TEST PASS` / `TEST FAIL` lines.
