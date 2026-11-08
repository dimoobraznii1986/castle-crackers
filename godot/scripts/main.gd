extends Node2D
## CASTLE CRACKERS
## Two players (or a player and the computer) take turns.
## Each has a castle with a treasure inside. Destroy the enemy treasure to win.
## Modes: "duel" (2 players), "ai" (vs computer), "practice" (only you shoot).
##
## This script holds the game rules and state.
## Drawing is in world_view.gd (battlefield), backdrop.gd (sky, water, weather) and hud.gd (screen UI).

# ---------------------------------------------------------------- constants
const W := 1600
const H := 900
const WATER := 838.0          # water (or lava) line
const G := 540.0              # gravity, px/s^2
const BS := 18.0              # castle brick size
const WIND_ACC := 260.0       # wind push on shots at wind = 1
const WIND_DRIFT := 25.0      # wind push on parachutes, px/s at wind = 1
const PARA_SPEED := 85.0      # falling speed with a parachute
const MIN_SPEED := 160.0
const MAX_SPEED := 960.0
const TURN_TIME := 45.0
const PLATEAU := 612.0        # ground level under the castles
const MAX_INVADERS := 6
const MAX_GUARDS := 4
const MAX_TOWERS := 2
const START_GOLD := 100
const INCOME := 25
const GC := 89                # grid columns (1600 / 18)
const GR := 50                # grid rows (900 / 18)
const CASTLE_X := [230.0, 1370.0]

# kind: shoot = fire from cannon, target = click on map, instant = use at once, menu = open the upgrade shop
# group: each turn you can do ONE attack and ONE build move.
const WEAPONS := [
	{"id": "ball", "name": "Cannonball", "icon": "⚫", "cost": 0, "kind": "shoot", "group": "attack", "secret": false, "desc": "Free. Small blast. The wind barely moves it."},
	{"id": "rocket", "name": "Rocket", "icon": "🚀", "cost": 30, "kind": "shoot", "group": "attack", "secret": false, "desc": "Big blast. The wind pushes it a lot."},
	{"id": "bounce", "name": "Bouncy Bomb", "icon": "💣", "cost": 25, "kind": "shoot", "group": "attack", "secret": false, "desc": "Bounces around. Explodes after 3 seconds."},
	{"id": "cluster", "name": "Cluster", "icon": "🎆", "cost": 45, "kind": "shoot", "group": "attack", "secret": false, "desc": "Explodes into 5 small bombs."},
	{"id": "drill", "name": "Drill Rocket", "icon": "🔩", "cost": 55, "kind": "shoot", "group": "attack", "secret": false, "desc": "Grinds through about 3 bricks, then explodes. Iron stops it."},
	{"id": "mega", "name": "Giant Boulder", "icon": "🪨", "cost": 0, "kind": "shoot", "group": "attack", "secret": true, "desc": "SECRET WEAPON. A huge blast."},
	{"id": "meteor", "name": "Meteor Storm", "icon": "☄️", "cost": 0, "kind": "target", "group": "attack", "secret": true, "desc": "SECRET WEAPON. Click a spot. 5 meteors fall from the sky."},
	{"id": "para", "name": "Paratroopers", "icon": "🪂", "cost": 45, "kind": "instant", "group": "attack", "secret": false, "desc": "3 soldiers jump onto the enemy castle. Each turn they smash bricks and dig to the treasure."},
	{"id": "guards", "name": "Guards", "icon": "💂", "cost": 35, "kind": "instant", "group": "build", "secret": false, "desc": "2 guards land on your castle. They throw spears and fight with swords."},
	{"id": "tower", "name": "Archer Tower", "icon": "🏹", "cost": 60, "kind": "target", "group": "build", "secret": false, "desc": "Click on top of your castle. Archers shoot paratroopers and soldiers."},
	{"id": "wall", "name": "Build Wall", "icon": "🧱", "cost": 35, "kind": "target", "group": "build", "secret": false, "desc": "Click on your side of the map to drop a stone wall."},
	{"id": "upgrade", "name": "Upgrades", "icon": "⬆️", "cost": 0, "kind": "menu", "group": "build", "secret": false, "desc": "Buy upgrades for your cannon, bricks, archers and soldiers."},
]
const KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "Q", "W", "E", "R"]
const NO_WEAPON := {"id": "", "name": "", "icon": "", "cost": 0, "kind": "none", "group": "", "secret": false, "desc": ""}

# Upgrades last for the whole battle. costs[i] = price of level i + 1.
const UPGRADES := [
	{"id": "cannon", "name": "Big Cannon", "icon": "💥", "costs": [60, 90, 130], "desc": "Every shot blasts bigger and hits harder."},
	{"id": "scope", "name": "Aim Scope", "icon": "🔭", "costs": [50, 90], "desc": "Shows the path of your shot while you charge."},
	{"id": "stone", "name": "Strong Stone", "icon": "🏰", "costs": [60, 100], "desc": "All your bricks get tougher. Drills get stuck sooner."},
	{"id": "archers", "name": "Master Archers", "icon": "🏹", "costs": [50, 90], "desc": "Towers shoot faster, farther and hit more often."},
	{"id": "swords", "name": "Sharp Swords", "icon": "⚔️", "costs": [50, 90], "desc": "Your soldiers hit harder and have more health."},
]

const PROJ := {
	"ball": {"wind": 0.25, "blast": 38.0, "dmg": 45.0},
	"rocket": {"wind": 1.0, "blast": 52.0, "dmg": 58.0},
	"bounce": {"wind": 0.4, "blast": 58.0, "dmg": 62.0},
	"cluster": {"wind": 0.4, "blast": 30.0, "dmg": 30.0},
	"bomblet": {"wind": 0.2, "blast": 27.0, "dmg": 28.0},
	"drill": {"wind": 0.6, "blast": 40.0, "dmg": 50.0},
	"mega": {"wind": 0.15, "blast": 92.0, "dmg": 90.0},
	"meteor": {"wind": 0.5, "blast": 46.0, "dmg": 48.0},
	"spear": {"wind": 0.0, "blast": 0.0, "dmg": 0.0},
	"arrow": {"wind": 0.0, "blast": 0.0, "dmg": 0.0},
}

# Castle shapes, drawn for RED (the enemy is on the right). BLUE uses the mirror image.
#   # = brick   F = brick with a flag   ^ = brick with a roof   C = the cannon stands here
#   w = brick with a window   i = brick with an arrow slit   b = brick with a team banner
# Every shape has a 6-wide room in the middle for the treasure, and a full floor row at the bottom.
const LAYOUTS := {
	"Classic": [
		"#F#.........C.",
		"###........###",
		"#i##.#..#.##i#",
		"######bb######",
		"#w##########w#",
		"####......####",
		"####......####",
		"####......####",
		"##############",
	],
	"Keep": [
		".....#^^#.....",
		".....#ww#...C.",
		"F#...####..###",
		"#i...#bb#..#i#",
		"##############",
		"#w##########w#",
		"####......####",
		"####......####",
		"####......####",
		"##############",
	],
	"Fortress": [
		"F^..........C.",
		"##.#.#.#.#.###",
		"#i##bb##bb##i#",
		"##w########w##",
		"####......####",
		"####......####",
		"####......####",
		"##############",
	],
	"Spires": [
		".^............",
		".#..........C.",
		".w.........##F",
		"###...^^...#i#",
		"#i#..#ww#..###",
		"##############",
		"####......####",
		"####......####",
		"####......####",
		"##############",
	],
	"Pyramid": [
		"......FF......",
		".....#ww#...C.",
		"....##bb##.###",
		"...##w##w#####",
		"..####ii######",
		".#############",
		"####......####",
		"####......####",
		"####......####",
		"##############",
	],
	"Twin Towers": [
		"^^..........C.",
		"##.........###",
		"#w.........#i#",
		"##..#b##b#..##",
		"##############",
		"####......####",
		"####......####",
		"####......####",
		"##############",
	],
	"Citadel": [
		"......^^......",
		".....#ww#...C.",
		"F#...####..###",
		"#i#..#bb#..#i#",
		"##############",
		"####......####",
		"####......####",
		"####......####",
		"##############",
	],
}

const LOOT := [
	{"id": "gold", "w": 26, "secret": false},
	{"id": "rocket", "w": 14, "secret": false},
	{"id": "cluster", "w": 10, "secret": false},
	{"id": "drill", "w": 10, "secret": false},
	{"id": "bounce", "w": 10, "secret": false},
	{"id": "repair", "w": 14, "secret": false},
	{"id": "para", "w": 6, "secret": false},
	{"id": "meteor", "w": 1, "secret": true},
	{"id": "mega", "w": 1, "secret": true},
]

# Rare gem crates. They need 3 hits (one hit per shot) and give great rewards.
# Emerald gives 1 prize, diamond gives 2.
const GEM_CHANCE := {"emerald": 0.09, "diamond": 0.04}   # chance per crate drop
const GEM_LOOT := [
	{"id": "gold300", "w": 30},
	{"id": "mega", "w": 18},
	{"id": "meteor", "w": 18},
	{"id": "arsenal", "w": 18},
	{"id": "free_upgrade", "w": 16},
]

const BOOM_WORDS := ["BOOM!", "KABOOM!", "POW!", "BLAM!", "WHAM!", "KRAK!"]

var TEAM := [
	{"name": "RED", "color": Color("e2412f"), "dark": Color("8e1e14"), "light": Color("ff9a7b")},
	{"name": "BLUE", "color": Color("2f7de2"), "dark": Color("173f8a"), "light": Color("8cc4ff")},
]


# ---------------------------------------------------------------- game objects
class Block:
	var x := 0.0
	var y := 0.0
	var w := 18.0
	var h := 18.0
	var hp := 40.0
	var max_hp := 40.0
	var owner := 0
	var vy := 0.0
	var base := Color(0.68, 0.64, 0.56)
	var cracks := []
	var flag := false
	var roof := false
	var deco := ""        # window, slit, banner
	var pat := 0          # brick pattern: 0 or 1 (rows take turns)
	var tones := [0.0, 0.0]
	var moss := false
	var dead := false


## Anything that falls: treasure, cannon, crate, soldier, tower.
class Body:
	var kind := ""        # treasure, cannon, chest, soldier, tower
	var tier := ""        # crates: "" (wood), emerald, diamond
	var role := ""        # soldiers: invader or guard
	var x := 0.0
	var y := 0.0
	var w := 0.0
	var h := 0.0
	var vx := 0.0
	var vy := 0.0
	var owner := -1
	var hp := 100.0
	var max_hp := 100.0
	var hurt := 0.0
	var show_hp := 0.0
	var gone := false
	var recoil := 0.0
	var para := false
	var sway := 0.0
	var opened := false
	var dir := 1
	var anim := 0.0
	var atk := 0.0
	var cool := 0.0
	var dead := false
	var torn := 0.0       # parachute was shot: falls fast
	var land_v := 0.0


class Proj:
	var type := ""
	var x := 0.0
	var y := 0.0
	var vx := 0.0
	var vy := 0.0
	var owner := 0
	var t := 0.0
	var fuse := 0.0
	var drilling := false
	var dx := 0.0
	var dy := 0.0
	var dead := false
	var last_bounce := 0.0
	var target = null     # spears and arrows fly to a target
	var hit := true
	var dmg := 0.0
	var start := Vector2.ZERO   # spears and arrows: start point
	var prog := 0.0             # 0..1 along the arc
	var dur := 0.5
	var arc := 40.0
	var miss := Vector2.ZERO
	var energy := 0.0           # drill: how much drilling is left
	var drill_out := false      # drill already broke through once


class Player:
	var gold := 100
	var inv := {}
	var angle := 0.0
	var dmg := 0.0
	var shots := 0
	var ai := false
	var lvl := {}         # upgrade levels
	var last_power := 0.6


# ---------------------------------------------------------------- state
var state := "title"          # title, units, aim, busy, over
var mode := "duel"            # duel, ai, practice
var theme: Dictionary = {}
var theme_choice := "hills"
var castle_style: Array = []
var turn := 0
var turn_no := 1
var wind := 0.0
var timer := TURN_TIME
var t := 0.0
var players: Array = []
var blocks: Array = []
var treasures: Array = []
var cannons: Array = []
var castles: Array = []
var chests: Array = []
var soldiers: Array = []
var towers: Array = []
var projs: Array = []
var parts: Array = []
var clouds: Array = []
var banner := {}
var msg := {}
var shake := 0.0
var settle := 0.0
var busy_t := 0.0
var power := 0.0
var charging := false
var weapon := "ball"
var mouse := Vector2(800, 400)
var wake := true
var vs_ai := false
var ai := {}
var units_queue: Array = []
var units_t := 0.0
var shot_done := false        # this turn: attack used
var built := false            # this turn: build move used
var turn_end := false
var interiors: Array = [[], []]   # castle rooms (cells) for the dark back wall
var focus := Vector2(800, 450)
var focus_timer := 0.0
var focus_zoom := 1.35
var wmap := {}
var grid: Array = []
var moving: Array = []

# nodes
var terrain: Terrain
var world: WorldView
var hud: Hud
var cam: Camera2D
var sfx: Sfx
var backdrops: Array = []
var autotest: Autotest


# ---------------------------------------------------------------- setup
func _ready() -> void:
	randomize()
	for w in WEAPONS:
		wmap[w["id"]] = w
	grid.resize(GC * GR)
	for i in grid.size():
		grid[i] = []
	for m in ["sky", "mountains", "clouds", "water_back"]:
		_add_backdrop(m)
	terrain = Terrain.new()
	add_child(terrain)
	world = WorldView.new()
	world.g = self
	add_child(world)
	_add_backdrop("water_front")
	_add_backdrop("weather")
	cam = Camera2D.new()
	cam.limit_left = 0
	cam.limit_right = W
	cam.limit_top = -400
	cam.limit_bottom = H
	cam.position = Vector2(800, 450)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 4.0
	add_child(cam)
	cam.make_current()
	sfx = Sfx.new()
	add_child(sfx)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.g = self
	layer.add_child(hud)
	new_game("hills")
	hud.show_title()
	if "--autotest" in OS.get_cmdline_user_args():
		autotest = Autotest.new()   # keep a reference, or the test object is freed
		autotest.run(self)


func _add_backdrop(m: String) -> void:
	var b := Backdrop.new()
	b.g = self
	b.mode = m
	add_child(b)
	backdrops.append(b)


func make_player(i: int) -> Player:
	var p := Player.new()
	p.gold = START_GOLD
	p.inv = {}
	for w in WEAPONS:
		p.inv[w["id"]] = 0
	p.inv["rocket"] = 1
	p.inv["bounce"] = 1
	p.angle = -PI / 4.0 if i == 0 else -PI * 0.75
	p.lvl = {}
	for u in UPGRADES:
		p.lvl[u["id"]] = 0
	return p


## Make a new world. theme_id: hills, snow, desert, lava or random.
func new_game(theme_id: String) -> void:
	var id := theme_id
	if id == "random" or not Themes.LIST.has(id):
		id = Themes.LIST.pick_random()
	theme = Themes.get_theme(id)
	state = "title"
	turn = 0
	turn_no = 1
	wind = 0.0
	timer = TURN_TIME
	players = [make_player(0), make_player(1)]
	blocks = []
	treasures = []
	cannons = []
	castles = [[], []]
	chests = []
	soldiers = []
	towers = []
	projs = []
	parts = []
	banner = {}
	msg = {}
	ai = {}
	units_queue = []
	interiors = [[], []]
	shot_done = false
	built = false
	turn_end = false
	shake = 0.0
	charging = false
	power = 0.0
	weapon = "ball"
	var stones := Themes.STONES.duplicate()
	stones.shuffle()
	castle_style = [stones[0].duplicate(), stones[1].duplicate()]
	terrain.generate(CASTLE_X, PLATEAU, theme)
	build_castle(0)
	build_castle(1)
	rebuild_grid()
	for i in 2:
		var x := randf_range(470.0, 1130.0)
		var c := make_chest(x, 0.0)
		c.para = false
		c.y = surface_y(x + 15.0, 0) - c.h
		chests.append(c)
	clouds = []
	for i in 8:
		clouds.append({"x": randf_range(0, W), "y": randf_range(60, 330), "s": randf_range(0.6, 1.4), "v": randf_range(0.6, 1.3)})
	for b in backdrops:
		b.regen()
	cam.position = Vector2(800, 450)
	cam.zoom = Vector2.ONE
	cam.reset_smoothing()


## Start a battle. game_mode: duel, ai or practice.
func begin_battle(game_mode: String, theme_id: String) -> void:
	theme_choice = theme_id
	new_game(theme_id)
	mode = game_mode
	vs_ai = mode == "ai"
	players[1].ai = vs_ai
	turn = randi() % 2 if mode == "duel" else 0
	if mode == "practice":
		players[0].gold = 99999
		players[0].inv["mega"] = 99
		players[0].inv["meteor"] = 99
	hud.hide_overlays()
	start_turn(true)


# ---------------------------------------------------------------- helpers
func wdef(id: String) -> Dictionary:
	return wmap.get(id, NO_WEAPON)


func lvl(p: int, id: String) -> int:
	return players[p].lvl[id]


func brick_hp(p: int) -> float:
	return 40.0 * (1.0 + 0.5 * lvl(p, "stone"))


func group_used(id: String) -> bool:
	var grp: String = wdef(id)["group"]
	return (grp == "attack" and shot_done) or (grp == "build" and built)


func mark_used(id: String) -> void:
	if wdef(id)["group"] == "attack":
		shot_done = true
	else:
		built = true


func team_name(p: int) -> String:
	if mode == "ai" and p == 1:
		return "COMPUTER"
	if mode == "practice" and p == 1:
		return "TARGET"
	return TEAM[p]["name"]


func in_rect(px: float, py: float, o, pad := 0.0) -> bool:
	return px >= o.x - pad and px < o.x + o.w + pad and py >= o.y - pad and py < o.y + o.h + pad


func rect_dist(px: float, py: float, o) -> float:
	var dx := maxf(maxf(o.x - px, 0.0), px - (o.x + o.w))
	var dy := maxf(maxf(o.y - py, 0.0), py - (o.y + o.h))
	return sqrt(dx * dx + dy * dy)


func rects_overlap(x: float, y: float, w: float, h: float, o) -> bool:
	return x < o.x + o.w and x + w > o.x and y < o.y + o.h and y + h > o.y


func center(o) -> Vector2:
	return Vector2(o.x + o.w / 2.0, o.y + o.h / 2.0)


func count_blocks(p: int) -> int:
	var n := 0
	for b in blocks:
		if b.owner == p and not b.dead:
			n += 1
	return n


func units_of(p: int, role: String) -> Array:
	return soldiers.filter(func(s): return s.owner == p and s.role == role)


func towers_of(p: int) -> Array:
	return towers.filter(func(tw): return tw.owner == p)


## Enemy invaders standing on or near castle p.
func threats_to(p: int) -> Array:
	return soldiers.filter(func(s): return s.owner != p and s.role == "invader" and absf(s.x - CASTLE_X[p]) < 220)


# ---------------------------------------------------------------- castle and blocks
func make_cracks() -> Array:
	var out := []
	for k in 3:
		var x := randf_range(2, BS - 2)
		var y := randf_range(2, BS - 2)
		match randi() % 4:
			0: y = 1.0
			1: y = BS - 1.0
			2: x = 1.0
			_: x = BS - 1.0
		var pts := PackedVector2Array([Vector2(x, y)])
		for i in 3:
			x = clampf(x + (BS / 2.0 - x) * 0.5 + randf_range(-4, 4), 1, BS - 1)
			y = clampf(y + (BS / 2.0 - y) * 0.5 + randf_range(-4, 4), 1, BS - 1)
			pts.append(Vector2(x, y))
		out.append(pts)
	return out


func make_block(x: float, y: float, owner: int) -> Block:
	var b := Block.new()
	b.x = x
	b.y = y
	b.owner = owner
	var base: Color = castle_style[owner]["color"]
	var tint := randf_range(-0.05, 0.05)
	b.base = Color(base.r + tint, base.g + tint, base.b + tint)
	b.tones = [randf_range(-0.04, 0.04), randf_range(-0.04, 0.04)]
	b.pat = int(roundf(y / BS)) % 2
	b.max_hp = brick_hp(owner)
	b.hp = b.max_hp
	b.moss = theme.get("id", "") == "hills" and y > PLATEAU - 3 * BS and randf() < 0.3
	b.cracks = make_cracks()
	return b


func build_castle(p: int) -> void:
	var shape: String = LAYOUTS.keys().pick_random()
	castle_style[p]["shape"] = shape
	var rows: Array = LAYOUTS[shape]
	var cx: float = CASTLE_X[p]
	var x0 := cx - 7.0 * BS
	var top0 := PLATEAU - rows.size() * BS
	var slots := []
	var cannon_cell := Vector2i(12 if p == 0 else 1, 0)
	for r in rows.size():
		var row: String = rows[r]
		for c in row.length():
			var ch := row[c] if p == 0 else row[row.length() - 1 - c]
			if ch == "C":
				cannon_cell = Vector2i(c, r)
				continue
			if not "#F^wib".contains(ch):
				continue
			var b := make_block(x0 + c * BS, top0 + r * BS, p)
			b.flag = ch == "F"
			b.roof = ch == "^"
			b.deco = {"w": "window", "i": "slit", "b": "banner"}.get(ch, "")
			blocks.append(b)
			slots.append(Vector2(b.x, b.y))
	castles[p] = slots
	# room cells: empty, with bricks left, right and above. They get a dark back wall.
	var room := []
	for r in rows.size():
		var row: String = rows[r]
		for c in 14:
			if "#F^wib".contains(row[c]):
				continue
			var left := false
			var right := false
			var above := false
			for k in c:
				left = left or "#F^wib".contains(row[k])
			for k in range(c + 1, 14):
				right = right or "#F^wib".contains(row[k])
			for k in r:
				above = above or "#F^wib".contains(rows[k][c])
			if left and right and above:
				var cc := c if p == 0 else 13 - c
				room.append(Vector2(x0 + cc * BS, top0 + r * BS))
	interiors[p] = room
	var tr := Body.new()
	tr.kind = "treasure"
	tr.x = cx - 22.0
	tr.y = PLATEAU - BS - 36.0
	tr.w = 44.0
	tr.h = 36.0
	tr.hp = 100.0
	tr.owner = p
	treasures.append(tr)
	var cn := Body.new()
	cn.kind = "cannon"
	cn.x = x0 + cannon_cell.x * BS + 9.0 - 17.0
	cn.y = top0 + (cannon_cell.y + 1) * BS - 24.0
	cn.w = 34.0
	cn.h = 24.0
	cn.owner = p
	cannons.append(cn)


func rebuild_grid() -> void:
	for c in grid:
		c.clear()
	moving.clear()
	blocks = blocks.filter(func(b): return not b.dead)
	for b in blocks:
		if b.vy > 0.0:
			moving.append(b)
			continue
		var c0 := maxi(0, floori(b.x / BS))
		var c1 := mini(GC - 1, floori((b.x + b.w - 0.01) / BS))
		var r0 := maxi(0, floori(b.y / BS))
		var r1 := mini(GR - 1, floori((b.y + b.h - 0.01) / BS))
		for r in range(r0, r1 + 1):
			for c in range(c0, c1 + 1):
				grid[r * GC + c].append(b)


func block_at(px: float, py: float):
	if px < 0 or px >= W or py < 0 or py >= H:
		return null
	var cell: Array = grid[int(py / BS) * GC + int(px / BS)]
	for b in cell:
		if not b.dead and px >= b.x and px < b.x + b.w and py >= b.y and py < b.y + b.h:
			return b
	for b in moving:
		if not b.dead and px >= b.x and px < b.x + b.w and py >= b.y and py < b.y + b.h:
			return b
	return null


func solid_at(px: float, py: float, ignore = null) -> bool:
	var xi := floori(px)
	var yi := floori(py)
	if xi < 0 or xi >= W or yi < 0:
		return false
	if yi >= H:
		return true
	if terrain.data[(yi * W + xi) * 2] != 0:
		return true
	var b = block_at(xi, yi)
	if b != null and b != ignore:
		return true
	for tr in treasures:
		if tr != ignore and not tr.gone and in_rect(xi, yi, tr):
			return true
	return false


func surface_y(px: float, from := 0) -> float:
	for y in range(from, H):
		if solid_at(px, y):
			return y
	return H


func normal_at(px: float, py: float) -> Vector2:
	var n := Vector2.ZERO
	for dy in range(-6, 7, 2):
		for dx in range(-6, 7, 2):
			if dx * dx + dy * dy > 36:
				continue
			if solid_at(px + dx, py + dy):
				n -= Vector2(dx, dy)
	return n.normalized() if n.length() > 0.0 else Vector2(0, -1)


func area_free(x: float, y: float, w: float, h: float) -> bool:
	for pt in [Vector2(x + 2, y + 2), Vector2(x + w - 2, y + 2), Vector2(x + 2, y + h - 2), Vector2(x + w - 2, y + h - 2), Vector2(x + w / 2, y + h / 2)]:
		if solid_at(pt.x, pt.y):
			return false
	for o in cannons + soldiers + treasures + chests + towers:
		if rects_overlap(x, y, w, h, o):
			return false
	return true


# A block stays up if:
#  - something is right under it, or
#  - it is in a short bridge: a standing block is at most 6 blocks away on BOTH sides, or
#  - it sticks out 1 block from a standing block.
func stands_on_something(b) -> bool:
	var by := floorf(b.y + b.h)
	return solid_at(b.x + 3, by, b) or solid_at(b.x + b.w - 3, by, b)


func steps_to_standing(b, dir: int) -> int:
	var cur = b
	for k in range(1, 7):
		var n = block_at(cur.x - 2 if dir < 0 else cur.x + cur.w + 2, cur.y + cur.h / 2)
		if n == null or n == cur or n.vy != 0.0:
			return 99
		if stands_on_something(n):
			return k
		cur = n
	return 99


func block_supported(b) -> bool:
	if stands_on_something(b):
		return true
	var l := steps_to_standing(b, -1)
	var r := steps_to_standing(b, 1)
	if l < 99 and r < 99:
		return true
	return l == 1 or r == 1


func damage_block(b, amt: float, owner: int) -> float:
	if b.dead:
		return 0.0
	var real := minf(b.hp, amt)
	b.hp -= real
	if b.hp <= 0.5:
		destroy_block(b)
	return real if owner >= 0 and b.owner != owner else 0.0


func destroy_block(b) -> void:
	b.dead = true
	wake = true
	var col: Color = b.base
	for i in 5:
		add_p({"type": "debris", "x": b.x + randf_range(2, b.w - 2), "y": b.y + randf_range(2, b.h - 2),
			"vx": randf_range(-170, 170), "vy": randf_range(-320, -60), "size": randf_range(3, 7),
			"rot": randf_range(0, 6), "vr": randf_range(-10, 10), "color": col, "life": randf_range(1, 2), "max": 2.0})
	add_p({"type": "smoke", "x": b.x + 9, "y": b.y + 9, "vx": randf_range(-10, 10), "vy": randf_range(-30, -10),
		"r": 8.0, "life": 0.8, "max": 0.8, "color": Color(0.78, 0.75, 0.67)})


# ---------------------------------------------------------------- particles and text
func add_p(p: Dictionary) -> void:
	if parts.size() < 1800:
		parts.append(p)


func pop_text(text: String, x: float, y: float, size: int, color: Color, life := 1.2) -> void:
	add_p({"type": "text", "text": text, "x": x, "y": y, "vx": 0.0, "vy": -40.0, "size": size, "color": color, "life": life, "max": life})


func dust(x: float, y: float) -> void:
	for i in 4:
		add_p({"type": "smoke", "x": x + randf_range(-8, 8), "y": y, "vx": randf_range(-30, 30), "vy": randf_range(-20, -5),
			"r": 5.0, "life": 0.6, "max": 0.6, "color": Color(0.82, 0.76, 0.67)})


func sparkle(x: float, y: float, n := 6, col := Color("fff6a0")) -> void:
	for i in n:
		add_p({"type": "star", "x": x + randf_range(-10, 10), "y": y + randf_range(-10, 10), "vx": randf_range(-60, 60),
			"vy": randf_range(-120, -30), "life": randf_range(0.6, 1.1), "max": 1.1, "color": col, "size": randf_range(3, 6)})


func splash(x: float, y: float, s := 1.0) -> void:
	var col: Color = theme.get("drop", Color(0.75, 0.9, 1.0))
	for i in int(14 * s):
		add_p({"type": "drop", "x": x + randf_range(-6, 6), "y": y, "vx": randf_range(-90, 90) * s, "vy": randf_range(-320, -120) * s,
			"life": 1.2, "max": 1.2, "size": randf_range(2, 4), "color": col})
	if theme.get("lava", false):
		for i in int(6 * s):
			add_p({"type": "smoke", "x": x + randf_range(-10, 10), "y": y - 4, "vx": randf_range(-15, 15), "vy": randf_range(-60, -30),
				"r": 6.0, "life": 1.2, "max": 1.2, "color": Color(0.3, 0.27, 0.27)})
	sfx.play("splash", 0.1)


func coins(x: float, y: float, n := 8) -> void:
	for i in n:
		add_p({"type": "coin", "x": x, "y": y, "vx": randf_range(-160, 160), "vy": randf_range(-380, -150),
			"life": randf_range(1.2, 2), "max": 2.0, "rot": randf_range(0, 6), "vr": 8.0})


func set_msg(text: String, color := Color.WHITE) -> void:
	msg = {"text": text, "color": color, "life": 2.6}


func set_banner(text: String, sub: String, color: Color, life := 2.0) -> void:
	banner = {"text": text, "sub": sub, "color": color, "life": life, "max": life}


# ---------------------------------------------------------------- explosions
func explode(x: float, y: float, r: float, dmg: float, owner: int) -> void:
	terrain.carve(x, y, r)
	wake = true
	var dealt := 0.0
	for b in blocks:
		if b.dead:
			continue
		var d := rect_dist(x, y, b)
		if d < r:
			dealt += damage_block(b, dmg * (1.0 - 0.6 * d / r), owner)
	for tr in treasures:
		if tr.gone or tr.hp <= 0:
			continue
		var d := rect_dist(x, y, tr)
		if d >= r:
			continue
		var occ := count_occluders(x, y, tr.x + tr.w / 2, tr.y + tr.h / 2)
		var amt := roundi(dmg * 0.9 * (1.0 - 0.5 * d / r) * pow(0.4, occ))
		if amt >= 1:
			tr.hp = maxf(0.0, tr.hp - amt)
			tr.hurt = 1.0
			tr.show_hp = 3.0
			pop_text("-%d" % amt, tr.x + tr.w / 2, tr.y - 14, 34, Color("ff3b30"), 1.6)
			coins(tr.x + tr.w / 2, tr.y + 6, mini(14, 3 + amt / 4))
			if owner >= 0 and tr.owner != owner:
				dealt += amt * 2
	for s in soldiers:
		var d := rect_dist(x, y, s)
		if d < r:
			var f := 1.0 - d / r
			s.hp -= dmg * 1.1 * f
			s.vy = -260.0 * f
			s.y -= 3.0
			s.para = false
			if owner >= 0 and s.owner != owner:
				dealt += 10.0 * f
	for tw in towers:
		var d := rect_dist(x, y, tw)
		if d < r:
			tw.hp -= dmg * 1.2 * (1.0 - d / r)
			tw.hurt = 1.0
			if owner >= 0 and tw.owner != owner:
				dealt += 10.0
	for c in chests.duplicate():
		if rect_dist(x, y, c) < r + 6:
			hit_chest(c, owner)

	# effects
	var k := r / 45.0
	add_p({"type": "flash", "x": x, "y": y, "r": r * 1.5, "life": 0.22, "max": 0.22})
	add_p({"type": "ring", "x": x, "y": y, "r": r, "life": 0.35, "max": 0.35})
	for i in int(12 + r / 3):
		var a := randf() * TAU
		var sp := randf_range(40, 260) * k
		add_p({"type": "fire", "x": x, "y": y, "vx": cos(a) * sp, "vy": sin(a) * sp, "life": randf_range(0.25, 0.6), "max": 0.6, "size": randf_range(4, 9) * k})
	for i in int(6 + r / 6):
		add_p({"type": "smoke", "x": x + randf_range(-r / 2, r / 2), "y": y + randf_range(-r / 2, r / 3), "vx": randf_range(-20, 20),
			"vy": randf_range(-70, -20), "r": randf_range(8, 16) * k, "life": randf_range(1, 2), "max": 2.0, "color": Color(0.27, 0.24, 0.23)})
	var g: Dictionary = theme["ground"]
	for i in int(8 + r / 4):
		add_p({"type": "debris", "x": x, "y": y, "vx": randf_range(-280, 280), "vy": randf_range(-460, -120), "size": randf_range(2, 6),
			"rot": randf_range(0, 6), "vr": randf_range(-12, 12), "life": randf_range(1, 2), "max": 2.0,
			"color": [g["soil_dark"], g["soil_light"], g["grass_col"], g["stone_col"]].pick_random()})
	if r >= 34:
		pop_text(BOOM_WORDS.pick_random(), x + randf_range(-20, 20), y - r * 0.6, int(minf(64, 26 + r * 0.45)),
			[Color("ffe14a"), Color("ff8a2a"), Color.WHITE].pick_random(), 1.0)
	shake = maxf(shake, minf(20.0, r / 3.2))
	if r >= 80:
		sfx.play("boom_big")
	elif r >= 40:
		sfx.play("boom")
	else:
		sfx.play("boom_small", 0.05)

	if owner >= 0 and dealt > 0 and mode != "practice":
		var gold := roundi(dealt / 6.0)
		if gold > 0:
			players[owner].gold += gold
			pop_text("+%d gold" % gold, x, y - r - 30, 20, Color("ffd84a"), 1.4)
	if owner >= 0:
		players[owner].dmg += dealt


func count_occluders(x0: float, y0: float, x1: float, y1: float) -> int:
	var seen := {}
	var n := ceili(Vector2(x1 - x0, y1 - y0).length() / 5.0)
	for i in range(1, n):
		var f := float(i) / n
		var b = block_at(x0 + (x1 - x0) * f, y0 + (y1 - y0) * f)
		if b != null:
			seen[b] = true
	return seen.size()


# ---------------------------------------------------------------- bonus crates
func make_chest(x: float, y: float) -> Body:
	var c := Body.new()
	c.kind = "chest"
	c.x = x
	c.y = y
	c.w = 30.0
	c.h = 26.0
	c.para = true
	c.sway = randf() * 6.0
	return c


func gem_color(tier: String) -> Color:
	return Color("2ecc71") if tier == "emerald" else Color("8ee8ff")


## A blast hits a crate. Wood crates open at once.
## Gem crates need 3 hits, and only 1 hit counts per turn (so one shot = one hit).
func hit_chest(c: Body, who: int) -> void:
	if c.tier == "" or who < 0:
		open_chest(c, who)
		return
	if int(c.cool) == turn_no:
		return
	c.cool = turn_no
	c.hp -= 1
	c.hurt = 1.0
	if c.hp <= 0:
		open_chest(c, who)
		return
	sparkle(c.x + 15, c.y + 13, 8, gem_color(c.tier))
	pop_text("CRACK! %d more" % int(c.hp), c.x + 15, c.y - 22, 22, gem_color(c.tier), 1.4)
	sfx.play("clang")


func open_chest(c: Body, who: int) -> void:
	if c.opened:
		return
	c.opened = true
	chests.erase(c)
	var col := Color("c8873a") if c.tier == "" else gem_color(c.tier)
	sparkle(c.x + 15, c.y + 13, 16 if c.tier == "" else 40, Color("fff6a0") if c.tier == "" else col)
	for i in (6 if c.tier == "" else 14):
		add_p({"type": "debris", "x": c.x + 15, "y": c.y + 13, "vx": randf_range(-200, 200), "vy": randf_range(-350, -100),
			"size": randf_range(4, 8), "rot": randf_range(0, 6), "vr": randf_range(-10, 10), "color": col, "life": 1.5, "max": 1.5})
	if who < 0:
		return
	if c.tier != "":
		open_gem(c, who)
		return
	var total := 0
	for l in LOOT:
		total += l["w"]
	var roll := randf() * total
	var loot: Dictionary = LOOT[0]
	for l in LOOT:
		roll -= l["w"]
		if roll <= 0:
			loot = l
			break
	var text := give_loot(who, loot["id"])
	set_banner("%s FOUND" % team_name(who), text, TEAM[who]["color"], 2.8)
	sfx.play("secret" if loot["secret"] else "chest")


func give_loot(p: int, id: String) -> String:
	var P: Player = players[p]
	match id:
		"gold":
			var gold := 40 + randi_range(0, 4) * 15
			P.gold += gold
			return "💰 %d gold" % gold
		"rocket":
			P.inv["rocket"] += 2
			return "🚀 2 Rockets"
		"cluster":
			P.inv["cluster"] += 1
			return "🎆 a Cluster Bomb"
		"drill":
			P.inv["drill"] += 1
			return "🔩 a Drill Rocket"
		"bounce":
			P.inv["bounce"] += 2
			return "💣 2 Bouncy Bombs"
		"repair":
			var n := repair(p)
			return "🔧 Free repair! Castle fixed" if n > 0 else "🔧 A repair kit (nothing to fix)"
		"para":
			P.inv["para"] += 1
			return "🪂 Free paratroopers"
		"meteor":
			P.inv["meteor"] += 1
			return "☄️ SECRET WEAPON: Meteor Storm!"
		"mega":
			P.inv["mega"] += 1
			return "🪨 SECRET WEAPON: Giant Boulder!"
	return ""


func open_gem(c: Body, who: int) -> void:
	var texts := []
	for k in (2 if c.tier == "diamond" else 1):
		var total := 0
		for l in GEM_LOOT:
			total += l["w"]
		var roll := randf() * total
		var id: String = GEM_LOOT[0]["id"]
		for l in GEM_LOOT:
			roll -= l["w"]
			if roll <= 0:
				id = l["id"]
				break
		texts.append(give_gem_loot(who, id))
	coins(c.x + 15, c.y + 10, 24)
	var title := "💎 DIAMOND CRATE!" if c.tier == "diamond" else "💚 EMERALD CRATE!"
	set_banner(title, "%s got %s" % [team_name(who), " + ".join(texts)], gem_color(c.tier), 3.5)
	shake = maxf(shake, 8.0)
	sfx.play("secret")


func give_gem_loot(p: int, id: String) -> String:
	var P: Player = players[p]
	match id:
		"gold300":
			P.gold += 300
			return "💰 300 gold"
		"arsenal":
			P.inv["rocket"] += 2
			P.inv["drill"] += 2
			P.inv["cluster"] += 2
			return "🚀🔩🎆 2 Rockets, 2 Drills, 2 Clusters"
		"free_upgrade":
			var ids := []
			for u in UPGRADES:
				if upgrade_cost(p, u["id"]) >= 0:
					ids.append(u["id"])
			if ids.is_empty():
				P.gold += 300
				return "💰 300 gold"
			var uid: String = ids.pick_random()
			grant_upgrade(p, uid)
			for u in UPGRADES:
				if u["id"] == uid:
					return "⬆️ FREE %s %s" % [u["icon"], u["name"]]
	return give_loot(p, id)


func drop_chest() -> void:
	if chests.size() >= 3:
		return
	var c := make_chest(randf_range(470, 1130), -40)
	var has_gem := chests.any(func(o): return o.tier != "")
	var roll := randf()
	if not has_gem and roll < GEM_CHANCE["diamond"]:
		c.tier = "diamond"
	elif not has_gem and roll < GEM_CHANCE["diamond"] + GEM_CHANCE["emerald"]:
		c.tier = "emerald"
	if c.tier != "":
		c.hp = 3.0
		c.max_hp = 3.0
		c.cool = -1.0
		var gem := "💎 A DIAMOND" if c.tier == "diamond" else "💚 An EMERALD"
		set_msg("%s crate is falling! Hit it 3 times for a big prize!" % gem, gem_color(c.tier))
		sfx.play("secret")
	else:
		set_msg("📦 A bonus crate is falling! Shoot it to open it.", Color("ffe9a0"))
	chests.append(c)


# ---------------------------------------------------------------- actions
func can_use(p: int, id: String, quiet := true) -> bool:
	var P: Player = players[p]
	var w := wdef(id)
	if w["kind"] == "none":
		return false
	if p == turn and group_used(id):
		if w["group"] == "attack":
			return _deny("You already attacked this turn. Build something, or press END TURN.", quiet)
		return _deny("You already built this turn. Now shoot!", quiet)
	if id == "upgrade":
		for u in UPGRADES:
			if upgrade_cost(p, u["id"]) >= 0 and (mode == "practice" or P.gold >= upgrade_cost(p, u["id"])):
				return true
		return _deny("Not enough gold for an upgrade.", quiet)
	if id == "para" and units_of(p, "invader").size() >= MAX_INVADERS:
		return _deny("You already have %d soldiers out there." % MAX_INVADERS, quiet)
	if id == "guards" and units_of(p, "guard").size() >= MAX_GUARDS:
		return _deny("You already have %d guards." % MAX_GUARDS, quiet)
	if id == "tower" and towers_of(p).size() >= MAX_TOWERS:
		return _deny("You can have only %d towers." % MAX_TOWERS, quiet)
	if P.inv[id] > 0:
		return true
	if w["secret"]:
		return _deny("Secret weapon! Find it in a bonus crate.", quiet)
	if P.gold < w["cost"]:
		return _deny("Not enough gold. %s costs %d." % [w["name"], w["cost"]], quiet)
	return true


func _deny(text: String, quiet: bool) -> bool:
	if not quiet:
		set_msg(text, Color("ffb0a0"))
		sfx.play("error")
	return false


func pay(p: int, id: String) -> void:
	var P: Player = players[p]
	if P.inv[id] > 0:
		if not (mode == "practice" and wdef(id)["secret"]):
			P.inv[id] -= 1
	elif mode != "practice":
		P.gold -= wdef(id)["cost"]


func select_weapon(id: String) -> void:
	if state != "aim" or players[turn].ai:
		return
	var w := wdef(id)
	if w["secret"] and players[turn].inv[id] <= 0:
		can_use(turn, id, false)
		return
	if group_used(id):
		can_use(turn, id, false)
		return
	if id == "upgrade":
		if can_use(turn, id, false):
			sfx.play("click")
			hud.show_shop()
		return
	weapon = id
	charging = false
	power = 0.0
	sfx.play("click")
	hud.refresh_bar()


func use_weapon(mx: float, my: float) -> void:
	if state != "aim":
		return
	var p := turn
	var w := wdef(weapon)
	var id: String = w["id"]
	match w["kind"]:
		"none", "menu":
			return
		"shoot":
			if not can_use(p, id, false):
				return
			charging = true
			power = 0.0
			return
		"target":
			if id == "wall" or id == "tower":
				var g := wall_ghost(mx) if id == "wall" else tower_ghost(mx)
				if not g["ok"]:
					set_msg(g["why"], Color("ffb0a0"))
					sfx.play("error")
					return
				if not can_use(p, id, false):
					return
				pay(p, id)
				if id == "wall":
					build_wall(p, g)
				else:
					build_tower(p, g)
			elif id == "meteor":
				if not can_use(p, id, false):
					return
				pay(p, id)
				meteor_storm(p, mx)
			mark_used(id)
			end_action()
			return
	# instant
	if not can_use(p, id, false):
		return
	pay(p, id)
	match id:
		"para":
			drop_troops(p, 1 - p, 3, "invader")
			set_msg("🪂 Paratroopers away! Watch the wind.")
			sfx.play("march")
		"guards":
			drop_troops(p, p, 2, "guard")
			set_msg("💂 Guards are coming to protect your castle.")
			sfx.play("march")
	mark_used(id)
	end_action()


func fire() -> void:
	var p := turn
	var P: Player = players[p]
	var id := weapon
	charging = false
	if not can_use(p, id, false):
		power = 0.0
		return
	pay(p, id)
	var c: Body = cannons[p]
	var px := c.x + c.w / 2.0
	var py := c.y + 8.0
	var a := P.angle
	var sp := MIN_SPEED + power * (MAX_SPEED - MIN_SPEED)
	var ox := px + cos(a) * 32.0
	var oy := py + sin(a) * 32.0
	projs.append(make_proj(id, ox, oy, cos(a) * sp, sin(a) * sp, p))
	for i in 8:
		add_p({"type": "smoke", "x": ox, "y": oy, "vx": cos(a) * randf_range(20, 90) + randf_range(-20, 20),
			"vy": sin(a) * randf_range(20, 90) + randf_range(-20, 20), "r": randf_range(5, 10), "life": 0.9, "max": 0.9, "color": Color(0.9, 0.9, 0.9)})
	add_p({"type": "flash", "x": ox, "y": oy, "r": 22.0, "life": 0.12, "max": 0.12})
	c.recoil = 1.0
	shake = maxf(shake, 4.0)
	P.shots += 1
	P.last_power = power
	power = 0.0
	sfx.play("shoot")
	mark_used(id)
	end_action()


func end_action() -> void:
	state = "busy"
	busy_t = 0.0
	settle = 0.0
	charging = false
	hud.refresh_bar()


## Upgrade shop. Returns the price of the next level, or -1 at max level.
func upgrade_cost(p: int, id: String) -> int:
	for u in UPGRADES:
		if u["id"] == id:
			var l := lvl(p, id)
			return -1 if l >= u["costs"].size() else u["costs"][l]
	return -1


func buy_upgrade(id: String) -> bool:
	var p := turn
	var cost := upgrade_cost(p, id)
	if state != "aim" or built or cost < 0:
		return false
	if mode != "practice":
		if players[p].gold < cost:
			_deny("Not enough gold. It costs %d." % cost, false)
			return false
		players[p].gold -= cost
	grant_upgrade(p, id)
	var up_name := ""
	for u in UPGRADES:
		if u["id"] == id:
			up_name = "%s %s" % [u["icon"], u["name"]]
	var c: Body = cannons[p]
	sparkle(c.x + c.w / 2, c.y, 14, Color("ffe14a"))
	set_banner("UPGRADE!", "%s level %d" % [up_name, lvl(p, id)], TEAM[p]["color"], 2.0)
	sfx.play("upgrade")
	built = true
	end_action()
	return true


## Add one upgrade level (bought, or from a gem crate).
func grant_upgrade(p: int, id: String) -> void:
	players[p].lvl[id] += 1
	if id == "stone":
		# make the bricks you have now tougher too
		for b in blocks:
			if b.owner == p and not b.dead:
				var new_max := brick_hp(p)
				b.hp += new_max - b.max_hp
				b.max_hp = new_max


## Finish the turn now (END TURN button, Enter key, or time is up).
func end_turn() -> void:
	if state != "aim":
		return
	turn_end = true
	end_action()


func start_turn(first := false) -> void:
	timer = TURN_TIME
	wind = roundf(randf_range(-1, 1) * 10.0) / 10.0
	weapon = "ball"
	power = 0.0
	charging = false
	shot_done = false
	built = false
	turn_end = false
	ai = {}
	if not first:
		if mode != "practice":
			players[turn].gold += INCOME
		turn_no += 1
		if randf() < 0.5:
			drop_chest()
	if mode == "practice":
		set_banner("PRACTICE", "Shot %d. Try any weapon!" % turn_no, TEAM[0]["color"], 1.4)
	else:
		var sub := "1 attack + 1 build each turn" if first else "+%d gold" % INCOME
		set_banner("%s'S TURN" % team_name(turn), sub, TEAM[turn]["color"], 1.8)
	sfx.play("turn")
	# your soldiers and towers act first
	units_queue = [] if first else unit_actors(turn)
	units_t = 0.9
	state = "units" if not units_queue.is_empty() else "aim"
	hud.refresh_bar()


## Called when everything is quiet after an action.
## The turn goes on until the player has attacked AND built (or pressed END TURN).
func after_action() -> void:
	var dead := treasures.filter(func(tr): return tr.hp <= 0)
	if not dead.is_empty():
		game_over(dead)
		return
	if turn_end or (shot_done and built) or timer <= 0 or (shot_done and (players[turn].ai or mode == "practice")):
		next_turn()
		return
	state = "aim"
	ai = {}
	charging = false
	power = 0.0
	weapon = "" if shot_done else "ball"
	hud.refresh_bar()


func next_turn() -> void:
	var dead := treasures.filter(func(tr): return tr.hp <= 0)
	if not dead.is_empty():
		game_over(dead)
		return
	if mode != "practice":
		turn = 1 - turn
	start_turn()


func game_over(dead: Array) -> void:
	state = "over"
	hud.refresh_bar()
	for tr in dead:
		coins(tr.x + tr.w / 2, tr.y + 10, 40)
		explode(tr.x + tr.w / 2, tr.y + tr.h / 2, 60, 0, -1)
		tr.gone = true
	var winner: int = -1 if dead.size() == 2 else 1 - dead[0].owner
	sfx.play("win")
	await get_tree().create_timer(1.8).timeout
	if state != "over":
		return
	if mode == "practice":
		hud.show_game_over("WELL DONE!", "You destroyed the treasure in %d shots." % players[0].shots, Color("ffd84a"))
	elif winner < 0:
		hud.show_game_over("IT'S A DRAW!", "Both treasures are gone!", Color("ffd84a"))
	else:
		var loser_name: String = team_name(1 - winner).to_lower()
		hud.show_game_over("%s WINS!" % team_name(winner), "The %s treasure is destroyed in %d turns!" % [loser_name, turn_no], TEAM[winner]["light"])


## Build wall: 2 bricks wide, 4 bricks tall. It drops from above.
func wall_ghost(mx: float) -> Dictionary:
	var p := turn
	var bx := roundf(mx / BS) * BS - BS
	var g := {"x": bx, "y": 0.0, "w": BS * 2, "h": BS * 4, "ok": true, "why": ""}
	var top := minf(minf(surface_y(bx + 3), surface_y(bx + BS)), surface_y(bx + 2 * BS - 3))
	g["y"] = top - g["h"]
	var mid := W / 2.0
	if (p == 0 and bx + g["w"] > mid - 80) or (p == 1 and bx < mid + 80):
		g["ok"] = false
		g["why"] = "Build on your own side of the map."
	elif bx < 0 or bx + g["w"] > W:
		g["ok"] = false
		g["why"] = "Too close to the edge."
	elif top >= WATER or g["y"] < 20:
		g["ok"] = false
		g["why"] = "You cannot build there."
	else:
		for o in cannons + treasures + soldiers + towers:
			if rects_overlap(g["x"], g["y"] - 30, g["w"], g["h"] + 30, o):
				g["ok"] = false
				g["why"] = "Something is in the way."
	return g


func build_wall(p: int, g: Dictionary) -> void:
	for r in 4:
		for c in 2:
			blocks.append(make_block(g["x"] + c * BS, g["y"] - 30 + r * BS, p))
	rebuild_grid()
	wake = true
	sparkle(g["x"] + BS, g["y"] + 20, 10, Color.WHITE)
	sfx.play("build")


## Archer tower: must stand on top of your own castle bricks.
func tower_ghost(mx: float) -> Dictionary:
	var p := turn
	var x := roundf(mx) - 15.0
	var g := {"x": x, "y": 0.0, "w": 30.0, "h": 46.0, "ok": true, "why": ""}
	var top := minf(surface_y(x + 5), surface_y(x + 25))
	g["y"] = top - g["h"]
	var b1 = block_at(x + 5, top + 2)
	var b2 = block_at(x + 25, top + 2)
	if absf(mx - CASTLE_X[p]) > 7 * BS + 6 or b1 == null or b2 == null or b1.owner != p or b2.owner != p:
		g["ok"] = false
		g["why"] = "Put the tower on top of your castle."
	elif g["y"] < 20:
		g["ok"] = false
		g["why"] = "Too high. Build lower."
	else:
		for o in cannons:
			if rects_overlap(g["x"] - 14, g["y"], g["w"] + 28, g["h"], o):
				g["ok"] = false
				g["why"] = "Too close to the cannon."
		for o in towers + soldiers + treasures:
			if rects_overlap(g["x"], g["y"], g["w"], g["h"], o):
				g["ok"] = false
				g["why"] = "Something is in the way."
	return g


func build_tower(p: int, g: Dictionary) -> void:
	var tw := Body.new()
	tw.kind = "tower"
	tw.owner = p
	tw.x = g["x"]
	tw.y = g["y"] - 20
	tw.w = g["w"]
	tw.h = g["h"]
	tw.hp = 80.0
	tw.max_hp = 80.0
	tw.dir = 1 if p == 0 else -1
	towers.append(tw)
	sparkle(tw.x + 15, tw.y + 20, 10, Color.WHITE)
	set_msg("🏹 Archer tower built! It shoots enemy paratroopers.")
	sfx.play("build")


## Best spot for a tower on castle p (for the computer). Returns -1 if there is none.
func tower_spot(p: int) -> float:
	var dx := -7.0 * BS
	while dx <= 7.0 * BS:
		var x: float = CASTLE_X[p] + dx
		if tower_ghost(x)["ok"]:
			return x
		dx += BS / 2.0
	return -1.0


func meteor_storm(p: int, tx: float) -> void:
	for i in 5:
		var x := tx + (i - 2) * 42.0 + randf_range(-10, 10)
		var pr := make_proj("meteor", x - 190, -60.0 - i * 90.0, 170, 260, p)
		pr.t = 1.0
		projs.append(pr)
	pop_text("METEOR STORM!", tx, 200, 50, Color("ff8a2a"), 2.0)
	sfx.play("secret")


## Soldiers jump from the sky with parachutes. They aim for the castle of `target`.
## The wind pushes parachutes, so they start a bit upwind.
func drop_troops(p: int, target: int, n: int, role: String) -> void:
	var have := units_of(p, role).size()
	n = mini(n, (MAX_INVADERS if role == "invader" else MAX_GUARDS) - have)
	var x0: float = CASTLE_X[target] - 7.0 * BS
	var fall_time := (PLATEAU - 100.0) / PARA_SPEED
	var drift := wind * WIND_DRIFT * fall_time
	for i in n:
		var tx := x0 + 30.0 + 192.0 * i / maxf(1.0, n - 1.0) + randf_range(-14, 14)
		var s := Body.new()
		s.kind = "soldier"
		s.role = role
		s.owner = p
		s.w = 12.0
		s.h = 22.0
		s.hp = (30.0 if role == "invader" else 40.0) * (1.0 + 0.3 * lvl(p, "swords"))
		s.max_hp = s.hp
		s.x = tx - drift - 6.0
		s.y = -60.0 - i * 45.0
		s.para = true
		s.sway = randf() * 6.0
		s.anim = randf() * 6.0
		s.dir = 1 if CASTLE_X[1 - p] > s.x else -1
		soldiers.append(s)


func repair(p: int) -> int:
	var n := 0
	for b in blocks:
		if b.owner == p and not b.dead and b.hp < b.max_hp:
			b.hp = b.max_hp
			n += 1
			sparkle(b.x + 9, b.y + 9, 2, Color("9fffa0"))
	var tr: Body = treasures[p]
	var tc := center(tr)
	var slots: Array = castles[p].duplicate()
	slots.sort_custom(func(a, b): return (a + Vector2(9, 9)).distance_to(tc) < (b + Vector2(9, 9)).distance_to(tc))
	var built := 0
	for sl in slots:
		if built >= 8:
			break
		if not area_free(sl.x, sl.y, BS, BS):
			continue
		blocks.append(make_block(sl.x, sl.y, p))
		rebuild_grid()
		built += 1
		sparkle(sl.x + 9, sl.y + 9, 4, Color("9fffa0"))
	wake = true
	return n + built


# ---------------------------------------------------------------- soldiers and towers (unit turn)
## Soldiers and towers of player p act at the start of p's turn.
func unit_actors(p: int) -> Array:
	var out := []
	for s in soldiers:
		if s.owner == p and not s.para:
			out.append(s)
	for tw in towers:
		if tw.owner == p:
			out.append(tw)
	return out


## Returns true if the unit did something (so we wait a moment for the animation).
func unit_act(a) -> bool:
	if a.dead:
		return false
	if a.kind == "tower":
		var al := lvl(a.owner, "archers")
		var tg = nearest_enemy_soldier(a, 320.0 + 60.0 * al, false)
		if tg == null:
			return false
		a.atk = 0.6
		shoot_missile("arrow", a, tg, 0.6 + 0.12 * al, 18.0 + 6.0 * al)
		if al >= 2:
			shoot_missile("arrow", a, tg, 0.6 + 0.12 * al, 18.0 + 6.0 * al, 0.25)
		return true
	if a.role == "guard":
		return guard_act(a)
	return invader_act(a)


func sword_dmg(p: int, base: float) -> float:
	return base * (1.0 + 0.4 * lvl(p, "swords"))


## A guard fights an invader next to it. If the invader is farther, the guard
## throws a spear and jumps closer, so next turn it can use the sword.
func guard_act(a: Body) -> bool:
	var tg = nearest_enemy_soldier(a, 300.0, false)
	if tg == null:
		return false
	var dx: float = center(tg).x - center(a).x
	a.dir = 1 if dx >= 0 else -1
	if absf(dx) < 34 and absf(center(tg).y - center(a).y) < 30:
		melee(a, tg)
		return true
	a.atk = 0.5
	shoot_missile("spear", a, tg, 0.75, sword_dmg(a.owner, 16.0))
	if absf(dx) < 220:
		leap(a, center(tg).x - signf(dx) * 22.0)
		pop_text("CHARGE!", a.x + 6, a.y - 10, 16, TEAM[a.owner]["light"], 0.9)
	return true


## Sword or pickaxe hit. Pushes the enemy back. It can fall off the castle!
func melee(a: Body, tg: Body) -> void:
	a.atk = 0.5
	var dm := sword_dmg(a.owner, 16.0)
	tg.hp -= dm
	tg.hurt = 1.0
	var push := signf(center(tg).x - center(a).x)
	if push == 0:
		push = float(a.dir)
	tg.vx = push * 120.0
	tg.vy = -170.0
	tg.y -= 2.0
	pop_text("CLASH!", (a.x + tg.x) / 2 + 6, a.y - 10, 20, Color.WHITE, 0.9)
	for i in 8:
		add_p({"type": "spark", "x": (a.x + tg.x) / 2 + 6, "y": a.y + 6, "vx": randf_range(-180, 180), "vy": randf_range(-200, 40), "life": 0.35, "max": 0.35})
	sfx.play("sword")


## Jump toward x (soldiers do not walk, they leap).
func leap(s: Body, tx: float) -> void:
	s.vy = -300.0
	var air := 2.0 * 300.0 / G
	s.vx = clampf((tx - center(s).x) / air, -180.0, 180.0)
	s.y -= 2.0


func nearest_enemy_soldier(from, max_d: float, in_air: bool):
	var best = null
	var best_d := max_d
	for s in soldiers:
		if s.owner == from.owner or s.dead or s.para != in_air:
			continue
		var d := center(s).distance_to(center(from))
		if d < best_d:
			best_d = d
			best = s
	return best


## Spears and arrows fly in an arc to the target. `delay` waits before the shot.
func shoot_missile(type: String, from, tg, chance: float, dmg: float, delay := 0.0) -> void:
	var c := center(from) + Vector2(0, -8 if type == "spear" else -18)
	var p := make_proj(type, c.x, c.y, 0, 0, from.owner)
	p.start = c
	p.target = tg
	p.hit = randf() < chance
	p.dmg = dmg
	var d := c.distance_to(center(tg))
	p.dur = clampf(d / 520.0, 0.25, 1.2)
	p.arc = clampf(d * 0.22, 8.0, 80.0)
	p.prog = -delay / p.dur
	if not p.hit:
		p.miss = Vector2(randf_range(16, 28) * (1 if randf() < 0.5 else -1), randf_range(-24, 6))
	projs.append(p)
	if delay <= 0.0:
		sfx.play("swoosh", 0.05)


## An invader fights a guard next to it, or steals treasure, or breaks a brick.
## If there is nothing to hit, it hops toward the enemy treasure.
func invader_act(s: Body) -> bool:
	var e := 1 - s.owner
	var fx := s.x + s.w / 2
	var feet := s.y + s.h
	for o in soldiers:
		if o.owner != s.owner and o.role == "guard" and not o.para and absf(o.x + o.w / 2 - fx) < 34 and absf(o.y + o.h - feet) < 30:
			s.dir = 1 if o.x > s.x else -1
			melee(s, o)
			return true
	for tw in towers:
		if tw.owner != s.owner and rect_dist(fx, feet - 10, tw) < 16:
			s.atk = 0.5
			tw.hp -= sword_dmg(s.owner, 20.0)
			tw.hurt = 1.0
			pop_text("BASH!", tw.x + 15, tw.y - 8, 20, Color.WHITE, 0.9)
			sfx.play("clang")
			return true
	var tr: Body = treasures[e]
	if not tr.gone and tr.hp > 0 and rect_dist(fx, feet - 8, tr) < 14:
		s.atk = 0.5
		tr.hp = maxf(0.0, tr.hp - 8)
		tr.hurt = 1.0
		tr.show_hp = 3.0
		if mode != "practice":
			players[s.owner].gold += 5
		pop_text("STEAL! -8", tr.x + tr.w / 2, tr.y - 12, 22, Color("ffd84a"))
		coins(tr.x + tr.w / 2, tr.y + 8, 5)
		sfx.play("clang")
		return true
	var dir := 1.0 if tr.x + tr.w / 2 > fx else -1.0
	s.dir = int(dir)
	# brick under the feet, then bricks in front
	for pt in [Vector2(fx, feet + 3), Vector2(fx - 5, feet + 3), Vector2(fx + 5, feet + 3), Vector2(fx + dir * 10, feet - 6), Vector2(fx + dir * 10, feet - 15)]:
		var b = block_at(pt.x, pt.y)
		if b != null and b.owner == e:
			s.atk = 0.5
			damage_block(b, sword_dmg(s.owner, 40.0), s.owner)
			pop_text("CLANG!", fx, s.y - 6, 16, Color.WHITE, 0.8)
			for i in 5:
				add_p({"type": "spark", "x": pt.x, "y": pt.y, "vx": randf_range(-120, 120), "vy": randf_range(-160, 20), "life": 0.3, "max": 0.3})
			sfx.play("clang")
			return true
	# nothing to hit: jump toward the treasure
	leap(s, fx + dir * 60.0)
	pop_text("Hop!", fx, s.y - 6, 14, Color.WHITE, 0.7)
	return true


func update_units(dt: float) -> void:
	units_t -= dt
	if units_t > 0:
		return
	while not units_queue.is_empty():
		var a = units_queue.pop_front()
		if a.dead or not (a in soldiers or a in towers):
			continue
		focus = center(a)
		focus_timer = 0.9
		focus_zoom = 1.3
		if unit_act(a):
			units_t = 0.65
			return
	# all done: wait for spears, arrows, jumps and falling bricks
	var jumping := soldiers.any(func(s): return s.vy != 0.0 or s.vx != 0.0)
	if projs.is_empty() and not wake and not jumping:
		var dead := treasures.filter(func(tr): return tr.hp <= 0)
		if not dead.is_empty():
			game_over(dead)
			return
		state = "aim"
		hud.refresh_bar()


# ---------------------------------------------------------------- projectiles
func make_proj(type: String, x: float, y: float, vx: float, vy: float, owner: int) -> Proj:
	var p := Proj.new()
	p.type = type
	p.x = x
	p.y = y
	p.vx = vx
	p.vy = vy
	p.owner = owner
	p.fuse = 3.0 if type == "bounce" else 0.0
	return p


func proj_hit(p: Proj) -> String:
	var x := floori(p.x)
	var y := floori(p.y)
	if y < 0:
		return ""
	if terrain.is_solid(x, y):
		return "terrain"
	if block_at(x, y) != null:
		return "block"
	for tr in treasures:
		if not tr.gone and in_rect(x, y, tr, 2):
			return "treasure"
	for c in chests:
		if in_rect(x, y, c, 3):
			return "chest"
	for s in soldiers:
		if in_rect(x, y, s, 2):
			return "soldier"
	for tw in towers:
		if tw.owner != p.owner and in_rect(x, y, tw, 2):
			return "tower"
	return ""


func impact(p: Proj) -> void:
	var d: Dictionary = PROJ[p.type]
	var l := lvl(p.owner, "cannon") if p.owner >= 0 else 0
	explode(p.x, p.y, d["blast"] * (1.0 + 0.15 * l), d["dmg"] * (1.0 + 0.2 * l), p.owner)
	if p.type == "cluster":
		for i in 5:
			var b := make_proj("bomblet", p.x, p.y - 8, randf_range(-230, 230), randf_range(-400, -220), p.owner)
			b.t = 0.02
			projs.append(b)
	p.dead = true


## Spears and arrows follow an arc to their (moving) target.
func update_missile(p: Proj, dt: float) -> void:
	var tg = p.target
	if tg == null or tg.dead:
		p.dead = true
		return
	p.prog += dt / p.dur
	if p.prog < 0.0:
		return
	var s := minf(p.prog, 1.0)
	var end := center(tg) + p.miss
	var pos := p.start.lerp(end, s) + Vector2(0, -sin(PI * s) * p.arc)
	if dt > 0:
		p.vx = (pos.x - p.x) / dt
		p.vy = (pos.y - p.y) / dt
	p.x = pos.x
	p.y = pos.y
	if p.prog < 1.0:
		return
	p.dead = true
	if not p.hit:
		pop_text("Miss!", tg.x + 6, tg.y - 10, 16, Color.WHITE, 0.8)
		return
	if tg.para:
		# the arrow tears the parachute: the soldier falls fast
		tg.para = false
		tg.torn = 1.2
		tg.hp -= 8.0
		tg.hurt = 1.0
		tg.vy = 80.0
		pop_text("RIIIP!", tg.x + 6, tg.y - 34, 24, Color("ffe14a"))
		for i in 8:
			add_p({"type": "debris", "x": tg.x + 6, "y": tg.y - 30, "vx": randf_range(-120, 120), "vy": randf_range(-160, 20), "size": randf_range(3, 6),
				"rot": randf_range(0, 6), "vr": randf_range(-10, 10), "color": [TEAM[tg.owner]["color"], Color.WHITE].pick_random(), "life": 1.2, "max": 1.2})
		sfx.play("rip")
	else:
		tg.hp -= p.dmg
		tg.hurt = 1.0
		pop_text("-%d" % int(p.dmg), tg.x + 6, tg.y - 10, 18, Color("ff6a5a"))
		sfx.play("clang", 0.05)


func update_proj(p: Proj, dt: float) -> void:
	if p.type == "spear" or p.type == "arrow":
		update_missile(p, dt)
		return
	p.t += dt
	var def: Dictionary = PROJ[p.type]
	if p.drilling:
		update_drill(p, dt)
		return
	if p.type == "bounce":
		p.fuse -= dt
		if p.fuse <= 0:
			impact(p)
			return
	var sp := Vector2(p.vx, p.vy).length()
	var n := maxi(1, ceili(sp * dt / 3.0))
	var sdt := dt / n
	for i in n:
		p.vx += wind * WIND_ACC * def["wind"] * sdt
		p.vy += G * sdt
		var ox := p.x
		var oy := p.y
		p.x += p.vx * sdt
		p.y += p.vy * sdt
		if p.x < -300 or p.x > W + 300 or p.y > H:
			p.dead = true
			return
		if p.y >= WATER:
			splash(p.x, WATER)
			p.dead = true
			return
		if p.t < 0.04:
			continue
		var hit := proj_hit(p)
		if hit == "":
			continue
		if p.type == "bounce":
			p.x = ox
			p.y = oy
			var nn := normal_at(p.x, p.y)
			var dot := p.vx * nn.x + p.vy * nn.y
			if dot < 0:
				p.vx -= 2 * dot * nn.x
				p.vy -= 2 * dot * nn.y
			p.vx *= 0.55
			p.vy *= 0.55
			if absf(dot) > 60 and t - p.last_bounce > 0.1:
				sfx.play("bounce")
				p.last_bounce = t
			break
		if p.type == "drill" and not p.drill_out and (hit == "block" or hit == "terrain"):
			var l := maxf(0.001, Vector2(p.vx, p.vy).length())
			p.drilling = true
			p.energy = 1.0
			p.dx = p.vx / l
			p.dy = p.vy / l
			return
		impact(p)
		return
	# trails
	if p.type == "rocket" or p.type == "drill":
		add_p({"type": "smoke", "x": p.x - p.vx * 0.02, "y": p.y - p.vy * 0.02, "vx": randf_range(-10, 10), "vy": randf_range(-20, 0),
			"r": 4.0, "life": 0.8, "max": 0.8, "color": Color(0.92, 0.92, 0.92)})
		add_p({"type": "fire", "x": p.x - p.vx * 0.015, "y": p.y - p.vy * 0.015, "vx": -p.vx * 0.1, "vy": -p.vy * 0.1, "life": 0.15, "max": 0.15, "size": 4.0})
	elif p.type == "meteor":
		for k in 2:
			add_p({"type": "fire", "x": p.x + randf_range(-4, 4), "y": p.y + randf_range(-4, 4), "vx": -p.vx * 0.2, "vy": -p.vy * 0.2,
				"life": 0.35, "max": 0.35, "size": randf_range(5, 9)})
		add_p({"type": "smoke", "x": p.x, "y": p.y, "vx": 0.0, "vy": -10.0, "r": 7.0, "life": 1.0, "max": 1.0, "color": Color(0.35, 0.27, 0.23)})
	elif randf() < 0.5:
		add_p({"type": "smoke", "x": p.x, "y": p.y, "vx": 0.0, "vy": -8.0, "r": 2.5, "life": 0.5, "max": 0.5, "color": Color.WHITE})


## The drill grinds bricks one by one. Each brick uses up some of its energy.
## Iron is very hard. When the energy is gone, the drill is stuck and explodes.
## If it breaks out into open air, it flies on and explodes at the next hit.
func update_drill(p: Proj, dt: float) -> void:
	var nose := Vector2(p.x + p.dx * 6.0, p.y + p.dy * 6.0)
	var b = block_at(nose.x, nose.y)
	if b == null:
		b = block_at(p.x, p.y)
	var speed: float
	if b != null:
		speed = 55.0
		damage_block(b, 150.0 * dt, p.owner)
		p.energy -= 1.2 * dt
		shake = maxf(shake, 1.5)
		for i in 2:
			add_p({"type": "spark", "x": nose.x, "y": nose.y, "vx": randf_range(-150, 150) - p.dx * 120, "vy": randf_range(-180, 40) - p.dy * 120, "life": 0.3, "max": 0.3})
		if randf() < dt * 10.0:
			add_p({"type": "debris", "x": nose.x, "y": nose.y, "vx": randf_range(-90, 90) - p.dx * 80, "vy": randf_range(-200, -60), "size": randf_range(2, 4),
				"rot": 0.0, "vr": 6.0, "color": b.base, "life": 0.8, "max": 0.8})
		sfx.play("drill", 0.09)
	elif terrain.is_solid(int(nose.x), int(nose.y)) or terrain.is_solid(int(p.x), int(p.y)):
		speed = 110.0
		p.energy -= 0.6 * dt
		terrain.carve(p.x, p.y, 8, false)
		sfx.play("drill", 0.07)
	else:
		# broke out into open air
		p.drilling = false
		p.drill_out = true
		p.vx = p.dx * 240.0
		p.vy = p.dy * 240.0
		pop_text("CRUNCH!", p.x, p.y - 14, 18, Color.WHITE, 0.8)
		return
	wake = true
	p.x += p.dx * speed * dt
	p.y += p.dy * speed * dt
	for tr in treasures:
		if not tr.gone and in_rect(p.x, p.y, tr, 2):
			impact(p)
			return
	if p.y >= WATER or p.x < 0 or p.x > W:
		splash(p.x, WATER)
		p.dead = true
		return
	if p.energy <= 0:
		pop_text("STUCK!", p.x, p.y - 20, 20, Color("ffe14a"), 0.9)
		impact(p)


# ---------------------------------------------------------------- falling things
func body_supported(o) -> bool:
	var by := floorf(o.y + o.h)
	return solid_at(o.x + 3, by, o) or solid_at(o.x + o.w / 2, by, o) or solid_at(o.x + o.w - 3, by, o)


## Returns "rest", "land" (just hit the ground hard) or "fall".
func fall_body(o, dt: float, max_v := 750.0) -> String:
	if o.vy < 0.0:
		# moving up (a hop or a blast)
		o.vy += G * dt
		var ny: float = o.y + o.vy * dt
		if solid_at(o.x + o.w / 2, ny, o):
			o.vy = 0.0
		else:
			o.y = ny
		return "fall"
	if body_supported(o):
		var hard: bool = o.vy > 150
		o.vy = 0.0
		return "land" if hard else "rest"
	o.vy = minf(o.vy + G * dt, max_v)
	var steps := maxi(1, roundi(o.vy * dt))
	for i in steps:
		o.y += 1.0
		if body_supported(o):
			break
	return "fall"


func update_blocks(dt: float) -> void:
	if not wake:
		return
	var any := false
	var arr := blocks.filter(func(b): return not b.dead)
	arr.sort_custom(func(a, b): return a.y > b.y)
	for b in arr:
		if block_supported(b):
			if b.vy > 150:
				dust(b.x + b.w / 2, b.y + b.h)
			if b.vy > 0:
				any = true
			b.vy = 0.0
			continue
		any = true
		b.vy = minf(b.vy + G * dt, 800.0)
		var steps := maxi(1, roundi(b.vy * dt))
		for i in steps:
			b.y += 1.0
			if b.y > WATER:
				b.dead = true
				splash(b.x + b.w / 2, WATER, 0.6)
				break
			if block_supported(b):
				break
	wake = any


func update_bodies(dt: float) -> void:
	for tr in treasures:
		if tr.gone:
			continue
		if fall_body(tr, dt) == "land":
			dust(tr.x + tr.w / 2, tr.y + tr.h)
		if tr.y + tr.h > WATER + 6 and tr.hp > 0:
			tr.hp = 0.0
			splash(tr.x + tr.w / 2, WATER, 1.5)
			set_banner("SPLASH!", "The %s treasure sank!" % team_name(tr.owner).to_lower(), TEAM[tr.owner]["color"], 2.5)
		tr.hurt = maxf(0.0, tr.hurt - dt * 3)
		tr.show_hp = maxf(0.0, tr.show_hp - dt)
	for c in cannons:
		if fall_body(c, dt) == "land":
			dust(c.x + c.w / 2, c.y + c.h)
		c.recoil = maxf(0.0, c.recoil - dt * 4)
		if c.y + c.h > WATER + 4:
			respawn_cannon(c)
	for c in chests:
		c.sway += dt * 2
		c.hurt = maxf(0.0, c.hurt - dt * 3)
		var r := fall_body(c, dt, 95.0 if c.para else 750.0)
		if r != "fall":
			if c.para:
				dust(c.x + 15, c.y + c.h)
			c.para = false
	for c in chests.duplicate():
		if c.y + c.h > WATER + 4:
			splash(c.x + 15, WATER, 0.7)
			chests.erase(c)
	for tw in towers:
		if fall_body(tw, dt) == "land":
			dust(tw.x + tw.w / 2, tw.y + tw.h)
		tw.hurt = maxf(0.0, tw.hurt - dt * 3)
		tw.atk = maxf(0.0, tw.atk - dt)
		# shoot enemy paratroopers in the air
		tw.cool -= dt
		if tw.cool <= 0 and tw.y + tw.h < WATER:
			var al := lvl(tw.owner, "archers")
			var tg = nearest_enemy_soldier(tw, 360.0 + 80.0 * al, true)
			if tg != null:
				shoot_missile("arrow", tw, tg, 0.6 + 0.12 * al, 20.0)
				tw.atk = 0.6
				tw.cool = 2.0 / (1.0 + 0.5 * al)
		if tw.hp <= 0 or tw.y + tw.h > WATER + 4:
			tw.dead = true
			for i in 8:
				add_p({"type": "debris", "x": tw.x + 12, "y": tw.y + 20, "vx": randf_range(-200, 200), "vy": randf_range(-350, -100),
					"size": randf_range(4, 8), "rot": randf_range(0, 6), "vr": randf_range(-10, 10), "color": castle_style[tw.owner]["color"], "life": 1.5, "max": 1.5})
			pop_text("Tower down!", tw.x + 15, tw.y - 10, 20, Color.WHITE)
	towers = towers.filter(func(tw): return not tw.dead)


func respawn_cannon(c: Body) -> void:
	splash(c.x + c.w / 2, WATER)
	var x: float = CASTLE_X[c.owner]
	var top = null
	for b in blocks:
		if b.owner == c.owner and not b.dead and (top == null or b.y < top.y):
			top = b
	if top != null:
		x = top.x + top.w / 2
	c.x = x - c.w / 2
	c.y = 40.0
	c.vy = 0.0
	set_msg("The %s cannon fell in. A new one drops in!" % team_name(c.owner).to_lower())


func update_soldiers(dt: float) -> void:
	for s in soldiers:
		s.anim += dt
		s.atk = maxf(0.0, s.atk - dt)
		s.hurt = maxf(0.0, s.hurt - dt * 3)
		s.torn = maxf(0.0, s.torn - dt)
		var r: String
		var v_before: float = s.vy
		if s.para:
			s.sway += dt * 2.0
			s.x += wind * WIND_DRIFT * dt
			r = fall_body(s, dt, PARA_SPEED)
			if r != "fall":
				s.para = false
				dust(s.x + 6, s.y + s.h)
		else:
			if s.vx != 0.0:
				var nx: float = s.x + s.vx * dt
				var front: float = nx + (s.w if s.vx > 0 else 0.0)
				if solid_at(front, s.y + s.h - 8, s) or solid_at(front, s.y + 4, s):
					s.vx = 0.0
				else:
					s.x = nx
			r = fall_body(s, dt)
			if r != "fall":
				s.vx = 0.0
			if r == "land":
				dust(s.x + 6, s.y + s.h)
				if v_before > 300.0:
					var fall_dmg := (v_before - 300.0) * 0.12
					s.hp -= fall_dmg
					s.hurt = 1.0
					pop_text("THUD!", s.x + 6, s.y - 8, 18, Color.WHITE, 0.8)
					sfx.play("thud", 0.1)
		if s.x < -30 or s.x > W + 30:
			s.hp = 0.0
		if s.y + s.h > WATER + 4:
			s.hp = 0.0
			splash(s.x + 6, WATER, 0.6)
		if s.hp <= 0:
			s.dead = true
			add_p({"type": "smoke", "x": s.x + 6, "y": s.y + 10, "vx": 0.0, "vy": -30.0, "r": 12.0, "life": 1.0, "max": 1.0, "color": Color(0.94, 0.94, 0.94)})
			pop_text("Ouch!", s.x + 6, s.y - 4, 16, TEAM[s.owner]["light"])
			continue
		for c in chests.duplicate():
			if c.tier == "" and rects_overlap(s.x, s.y, s.w, s.h, c):
				open_chest(c, s.owner)
	soldiers = soldiers.filter(func(s): return not s.dead)


# ---------------------------------------------------------------- particles update
func update_parts(dt: float) -> void:
	for p in parts:
		p["life"] -= dt
		match p["type"]:
			"smoke":
				p["x"] += p["vx"] * dt
				p["y"] += p["vy"] * dt
				p["r"] += dt * 14
			"fire":
				p["x"] += p["vx"] * dt
				p["y"] += p["vy"] * dt
				p["vx"] *= 0.92
				p["vy"] = p["vy"] * 0.92 - 30 * dt
			"debris", "coin", "drop":
				p["vy"] += G * dt
				p["x"] += p["vx"] * dt
				p["y"] += p["vy"] * dt
				if p.has("rot"):
					p["rot"] += p.get("vr", 8.0) * dt
				if p["vy"] > 0 and solid_at(p["x"], p["y"]):
					p["vy"] *= -0.35
					p["vx"] *= 0.6
					p["y"] -= 2
				if p["y"] > WATER:
					p["life"] = minf(p["life"], 0.05)
			"spark":
				p["x"] += p["vx"] * dt
				p["y"] += p["vy"] * dt
				p["vy"] += 300 * dt
			"star":
				p["x"] += p["vx"] * dt
				p["y"] += p["vy"] * dt
				p["vy"] += 80 * dt
			"text":
				p["y"] += p["vy"] * dt
				p["vy"] *= 0.96
	parts = parts.filter(func(p): return p["life"] > 0)


# ---------------------------------------------------------------- computer player
func ai_update(dt: float) -> void:
	if ai.is_empty():
		ai = {"phase": "think", "t": 0.0}
	ai["t"] += dt
	var P: Player = players[turn]
	match ai["phase"]:
		"think":
			if ai["t"] >= 1.0:
				_ai_decide()
		"aim":
			var target: float = ai["angle"]
			var diff := wrapf(target - P.angle, -PI, PI)
			var step := 1.4 * dt
			if absf(diff) <= step:
				P.angle = target
				ai["phase"] = "charge"
				charging = true
				power = 0.0
			else:
				P.angle += signf(diff) * step
		"charge":
			if charging and power >= ai["power"]:
				power = ai["power"]
				fire()


func _ai_decide() -> void:
	var p := turn
	var P: Player = players[p]
	var e := 1 - p
	if not built:
		_ai_build()
		if state == "aim":
			built = true   # nothing to build: go on to the attack
			ai["t"] = 0.4
		return
	var choice := "ball"
	if P.inv["meteor"] > 0:
		choice = "meteor"
	elif P.inv["mega"] > 0:
		choice = "mega"
	elif turn_no > 1 and can_use(p, "para") and units_of(p, "invader").size() < 3 and randf() < 0.25:
		choice = "para"
	elif can_use(p, "drill") and randf() < 0.3:
		choice = "drill"
	elif can_use(p, "rocket") and absf(wind) < 0.6 and randf() < 0.5:
		choice = "rocket"
	elif can_use(p, "cluster") and randf() < 0.3:
		choice = "cluster"
	weapon = choice
	hud.refresh_bar()
	var w := wdef(choice)
	var et: Body = treasures[e]
	if w["kind"] == "instant":
		use_weapon(0, 0)
		return
	if choice == "meteor":
		use_weapon(et.x + et.w / 2, 300)
		return
	var shot := ai_find_shot(p, choice, center(et))
	ai["angle"] = shot.x + randf_range(-0.04, 0.04)
	ai["power"] = clampf(shot.y + randf_range(-0.035, 0.035), 0.05, 1.0)
	ai["phase"] = "aim"


## The computer's build move: defend, repair, build or upgrade. Sometimes it skips.
func _ai_build() -> void:
	var p := turn
	var P: Player = players[p]
	var choice := ""
	if not threats_to(p).is_empty() and units_of(p, "guard").size() < 2 and can_use(p, "guards") and randf() < 0.8:
		choice = "guards"
	elif towers_of(p).is_empty() and turn_no > 3 and can_use(p, "tower") and randf() < 0.35:
		choice = "tower"
	elif P.gold >= 110 and randf() < 0.5:
		var ups := ["cannon", "stone", "swords"]
		if not towers_of(p).is_empty():
			ups.append("archers")
		ups.shuffle()
		for id in ups:
			var cost := upgrade_cost(p, id)
			if cost >= 0 and P.gold - cost >= 40:
				buy_upgrade(id)
				return
	if choice == "":
		return
	weapon = choice
	hud.refresh_bar()
	if choice == "tower":
		var spot := tower_spot(p)
		if spot >= 0:
			use_weapon(spot, 300)
		return
	use_weapon(0, 0)


## Try many angles and powers. Return the best Vector2(angle, power).
func ai_find_shot(p: int, type: String, target: Vector2) -> Vector2:
	var best := Vector2(-PI / 4.0 if p == 0 else -PI * 0.75, 0.75)
	var best_d := INF
	var elev := 0.2
	while elev <= 1.4:
		var pw := 0.3
		while pw <= 1.0:
			var ang := -elev if p == 0 else -PI + elev
			var d := sim_shot(p, type, ang, pw, target)
			if d < best_d:
				best_d = d
				best = Vector2(ang, pw)
			pw += 0.05
		elev += 0.087
	var base := best
	for da in [-0.06, -0.03, 0.0, 0.03, 0.06]:
		for k in range(-5, 6):
			var ang2: float = base.x + da
			var pw2 := clampf(base.y + k * 0.01, 0.05, 1.0)
			var d2 := sim_shot(p, type, ang2, pw2, target)
			if d2 < best_d:
				best_d = d2
				best = Vector2(ang2, pw2)
	return best


## Fly a pretend shot. Return how far from the target it lands.
func sim_shot(p: int, type: String, ang: float, pw: float, target: Vector2) -> float:
	var c: Body = cannons[p]
	var sp := MIN_SPEED + pw * (MAX_SPEED - MIN_SPEED)
	var x := c.x + c.w / 2.0 + cos(ang) * 32.0
	var y := c.y + 8.0 + sin(ang) * 32.0
	var vx := cos(ang) * sp
	var vy := sin(ang) * sp
	var wk: float = PROJ[type]["wind"]
	var dt := 1.0 / 60.0
	var tt := 0.0
	for frame in 700:
		var n := maxi(1, ceili(Vector2(vx, vy).length() * dt / 4.0))
		var sdt := dt / n
		for i in n:
			vx += wind * WIND_ACC * wk * sdt
			vy += G * sdt
			x += vx * sdt
			y += vy * sdt
			tt += sdt
			if x < -300 or x > W + 300 or y >= WATER:
				return 1e9
			if tt < 0.04 or y < 0:
				continue
			if solid_at(x, y):
				if absf(x - CASTLE_X[p]) < 170:
					return 1e9   # would hit our own castle
				return Vector2(x, y).distance_to(target)
	return 1e9


## Points along the path of a shot (for the Aim Scope upgrade). Stops at the first hit.
func trajectory(p: int, type: String, ang: float, pw: float, max_t: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var c: Body = cannons[p]
	var sp := MIN_SPEED + pw * (MAX_SPEED - MIN_SPEED)
	var pos := Vector2(c.x + c.w / 2.0 + cos(ang) * 32.0, c.y + 8.0 + sin(ang) * 32.0)
	var v := Vector2(cos(ang), sin(ang)) * sp
	var wk: float = PROJ[type]["wind"]
	var dt := 1.0 / 60.0
	var tt := 0.0
	while tt < max_t:
		for i in 4:
			v.x += wind * WIND_ACC * wk * dt / 4.0
			v.y += G * dt / 4.0
			pos += v * dt / 4.0
		tt += dt
		pts.append(pos)
		if pos.y >= WATER or pos.x < 0 or pos.x > W or (tt > 0.05 and pos.y > 0 and solid_at(pos.x, pos.y)):
			break
	return pts


# ---------------------------------------------------------------- input
func aim_at(m: Vector2) -> void:
	var c: Body = cannons[turn]
	players[turn].angle = atan2(m.y - (c.y + 8), m.x - (c.x + c.w / 2))


func human_turn() -> bool:
	return state == "aim" and not players[turn].ai


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = get_global_mouse_position()
		if human_turn() and wdef(weapon)["kind"] == "shoot":
			aim_at(mouse)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and human_turn():
			mouse = get_global_mouse_position()
			if wdef(weapon)["kind"] == "shoot":
				aim_at(mouse)
			use_weapon(mouse.x, mouse.y)
		elif not event.pressed and charging and human_turn():
			fire()
	elif event is InputEventKey:
		var k: InputEventKey = event
		if k.keycode == KEY_M and k.pressed and not k.echo:
			toggle_mute()
			return
		if not human_turn():
			return
		if (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER) and k.pressed and not k.echo:
			if shot_done or built:
				end_turn()
			return
		var P: Player = players[turn]
		if k.keycode == KEY_SPACE:
			if k.pressed and not k.echo:
				use_weapon(mouse.x, mouse.y)
			elif not k.pressed and charging:
				fire()
			return
		if not k.pressed:
			return
		match k.keycode:
			KEY_LEFT:
				P.angle -= 0.025
			KEY_RIGHT:
				P.angle += 0.025
			KEY_UP, KEY_DOWN:
				var up := 1.0 if k.keycode == KEY_UP else -1.0
				P.angle += (-0.025 if cos(P.angle) >= 0 else 0.025) * up
		var key_name := OS.get_keycode_string(k.keycode).to_upper()
		var idx := KEYS.find(key_name)
		if idx >= 0 and not k.echo:
			select_weapon(WEAPONS[idx]["id"])


func toggle_mute() -> void:
	sfx.muted = not sfx.muted
	hud.refresh_mute()


# ---------------------------------------------------------------- main loop
func _process(delta: float) -> void:
	var dt := minf(delta, 1.0 / 30.0)
	update(dt)
	update_camera(dt)
	terrain.flush()
	world.queue_redraw()
	hud.queue_redraw()


func update(dt: float) -> void:
	t += dt
	rebuild_grid()
	for c in clouds:
		c["x"] += (10.0 + wind * 45.0) * c["v"] * dt
		if c["x"] > W + 150:
			c["x"] = -150.0
		elif c["x"] < -150:
			c["x"] = W + 150.0

	if state == "units":
		update_units(dt)
	elif state == "aim":
		if mode != "practice":
			timer -= dt
		if charging:
			power += dt / 2.0
			if power >= 1.0:
				power = 1.0
				fire()
		if state == "aim" and players[turn].ai:
			ai_update(dt)
		if state == "aim" and timer <= 0:
			set_msg("Time is up!", Color("ffb0a0"))
			end_turn()

	for p in projs:
		update_proj(p, dt)
	projs = projs.filter(func(p): return not p.dead)
	update_blocks(dt)
	update_bodies(dt)
	update_soldiers(dt)
	update_parts(dt)

	if state == "busy":
		busy_t += dt
		var quiet := projs.is_empty() and not wake
		for o in treasures + cannons + towers:
			if o.vy != 0.0:
				quiet = false
		for s in soldiers:
			if s.para or s.vy != 0.0 or s.vx != 0.0:
				quiet = false
		if quiet and busy_t > 0.5:
			settle += dt
		else:
			settle = 0.0
		if settle > 0.8 or busy_t > 25:
			after_action()

	shake = maxf(0.0, shake - dt * 30)
	if not banner.is_empty():
		banner["life"] -= dt
		if banner["life"] <= 0:
			banner = {}
	if not msg.is_empty():
		msg["life"] -= dt
		if msg["life"] <= 0:
			msg = {}


## The camera follows shots, parachutes and fighting soldiers, then shows the whole map again.
func update_camera(dt: float) -> void:
	var target := Vector2(800, 450)
	var z := 1.0
	if state == "busy" or state == "over" or state == "units":
		var follow = null
		for p in projs:
			if p.type == "spear" or p.type == "arrow":
				continue
			if follow == null or p.type != "bomblet":
				follow = p
		var flying := soldiers.filter(func(s): return s.para)
		if follow != null:
			focus = Vector2(follow.x, follow.y)
			focus_timer = 1.1
			focus_zoom = 1.35
		elif not flying.is_empty():
			var sum := Vector2.ZERO
			for s in flying:
				sum += center(s)
			focus = sum / flying.size()
			focus_timer = 0.8
			focus_zoom = 1.2
		focus_timer -= dt
		if focus_timer > 0:
			target = focus
			z = focus_zoom
	cam.position = target
	cam.zoom = cam.zoom.lerp(Vector2(z, z), 1.0 - exp(-3.0 * dt))
	cam.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake)) if shake > 0 else Vector2.ZERO
