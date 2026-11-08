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
- **Choose an action:** click a button at the bottom. Attack keys: `1`-`8`. Build keys: `Q` `W` `E` `R`.
- **End turn:** press **END TURN** or `Enter`.
- **Sound:** press `M` to turn sound on or off.

Each turn you get **1 attack** (shoot or paratroopers) **and 1 build move** (guards, tower, wall or an upgrade).
Do them in any order. You have 45 seconds.

## Actions

| Action | Cost | What it does |
|---|---|---|
| Cannonball | free | Small blast. Wind barely moves it. |
| Rocket | 30 | Big blast. Wind pushes it a lot. |
| Bouncy Bomb | 25 | Bounces. Explodes after 3 seconds. |
| Cluster | 45 | Splits into 5 small bombs. |
| Drill Rocket | 55 | Grinds through about 3 bricks, then explodes. Strong Stone stops it sooner. If it breaks into a room, it flies on. |
| Giant Boulder | secret | Huge blast. Only from crates. |
| Meteor Storm | secret | 5 meteors fall where you click. Only from crates. |
| Paratroopers | 45 | 3 soldiers float down onto the enemy castle. Each turn they break a brick or steal treasure. The wind pushes them. |
| Guards | 35 | 2 guards land on your castle. They throw spears, jump to enemy soldiers and fight with swords. A hit can knock a soldier off the castle. |
| Archer Tower | 60 | A stone tower on top of your castle. Its arrows tear enemy parachutes, so the soldiers fall hard. It also shoots soldiers on your castle. |
| Build Wall | 35 | Drops a stone wall on your side of the map. |
| Upgrades | varies | Opens the upgrade shop (see below). |

## Upgrades

Upgrades last for the whole battle. Buying one uses your build move.

| Upgrade | Levels | Cost | What it does |
|---|---|---|---|
| Big Cannon | 3 | 60 / 90 / 130 | Bigger blasts and more damage for every shot. |
| Aim Scope | 2 | 50 / 90 | Shows the path of your shot while you charge. |
| Strong Stone | 2 | 60 / 100 | All your bricks get +50% health per level. |
| Master Archers | 2 | 50 / 90 | Towers shoot faster, farther and better. Level 2 shoots 2 arrows. |
| Sharp Swords | 2 | 50 / 90 | Your soldiers hit harder and have more health. |

You get 25 gold each turn, plus gold for damage to the enemy.
`?` crates fall from the sky. Shoot them to get gold, weapons, a repair (the only way to fix your castle), or a secret weapon.

**Gem crates (rare):** sometimes an 💚 emerald or 💎 diamond crate falls. It needs 3 hits (only 1 hit counts per turn).

| Crate | Prizes |
|---|---|
| Emerald | 1 big prize: 300 gold, Giant Boulder, Meteor Storm, an arsenal (2 rockets, 2 drills, 2 clusters), or a free upgrade. |
| Diamond | 2 big prizes from the same list. |

Giant Boulder and Meteor Storm are very rare in normal crates. Gem crates are the best way to get them.

**Soldiers:** at the start of your turn, your soldiers and towers act first. Then you attack and build.
Paratroopers smash bricks, steal treasure and bash towers. Soldiers that fall from high up get hurt.

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
