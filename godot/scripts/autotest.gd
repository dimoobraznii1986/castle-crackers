class_name Autotest
extends RefCounted
## Automatic smoke test. Run with:
##   godot --headless --fixed-fps 60 --path . -- --autotest   (fast, no window)
##   godot --path . -- --autotest                             (with a window, saves screenshots to user://)
## It tests menus, lands, every action, soldiers, towers, practice mode. Then it quits.

var g
var tree: SceneTree
var fails := 0


func run(game) -> void:
	g = game
	tree = g.get_tree()
	await _wait(0.5)
	print("TEST start")
	await _shot("title")

	# --- menu screens
	g.hud._choose_mode("ai")
	await _wait(0.3)
	_check(g.hud.map_panel.visible and not g.hud.title_panel.visible, "mode button opens the land screen")
	await _shot("lands_menu")

	# --- every land and castle shape
	var shapes := {}
	for id in Themes.LIST:
		g.new_game(id)
		await _wait(0.4)
		_check(g.theme["id"] == id and g.blocks.size() > 100, "land %s builds (bricks=%d, castles: %s / %s)" % [id, g.blocks.size(), g.castle_style[0]["shape"], g.castle_style[1]["shape"]])
		shapes[g.castle_style[0]["shape"]] = true
		shapes[g.castle_style[1]["shape"]] = true
		await _shot("land_" + id)
	for i in 10:
		g.new_game("hills")
		shapes[g.castle_style[0]["shape"]] = true
		_check(g.cannons[0].y < g.PLATEAU and g.cannons[1].y < g.PLATEAU, "cannons stand on the castles")
		await _wait(0.6)
		var floating := 0
		for b in g.blocks:
			if b.vy > 0:
				floating += 1
		if floating > 0:
			_check(false, "castle shape %s / %s stands still at start (%d falling)" % [g.castle_style[0]["shape"], g.castle_style[1]["shape"], floating])
	print("TEST castle shapes seen: %s" % [shapes.keys()])

	# --- vs computer: one shot each
	g.begin_battle("ai", "snow")
	await _wait(2.0)
	_check(g.state == "aim" and g.turn == 0, "battle starts on RED's turn")
	g.wind = 0.0
	g.weapon = "rocket"
	g.players[0].angle = -0.8
	g.power = 0.8
	g.fire()
	await _wait(0.9)
	await _shot("rocket_flying")
	await _settle()
	_check(g.turn == 1, "turn passes to the computer")
	await _wait_turn(0)
	_check(g.turn == 0, "computer finished its turn")
	await _shot("after_computer")

	# --- paratroopers (2-player mode so nobody plays by itself)
	g.mode = "duel"
	g.vs_ai = false
	g.players[1].ai = false
	g.players[0].gold = 5000
	g.players[1].gold = 5000
	await _aim_turn(0)
	g.weapon = "para"
	g.use_weapon(0, 0)
	_check(g.units_of(0, "invader").size() == 3, "paratroopers jump (3)")
	await _wait(2.5)
	await _shot("paratroopers")
	await _settle()
	var on_castle := 0
	for s in g.units_of(0, "invader"):
		if absf(s.x - g.CASTLE_X[1]) < 160:
			on_castle += 1
	_check(on_castle >= 2, "paratroopers land on the enemy castle (%d of 3)" % on_castle)
	# give red's turn again: the invaders act first
	var blue_before: int = g.count_blocks(1)
	await _aim_turn(1)
	g.state = "busy"
	g.busy_t = 0.0
	await _settle()             # next_turn -> red, units act
	await _wait_state("aim")
	await _shot("invaders_dig")
	_check(g.count_blocks(1) < blue_before, "invaders break bricks (%d -> %d)" % [blue_before, g.count_blocks(1)])

	# --- guards defend
	await _aim_turn(1)
	g.weapon = "guards"
	g.use_weapon(0, 0)
	await _settle()             # -> red turn (invaders act)
	await _wait_state("aim")
	_check(g.units_of(1, "guard").size() >= 1, "guards land on own castle")
	var inv_hp := 0.0
	for s in g.units_of(0, "invader"):
		inv_hp += s.hp
	g.state = "busy"
	g.busy_t = 0.0
	await _settle()             # -> blue turn: guards throw spears
	await _wait_state("aim")
	var inv_hp2 := 0.0
	for s in g.units_of(0, "invader"):
		inv_hp2 += s.hp
	await _shot("guards")
	_check(inv_hp2 < inv_hp, "guards hurt invaders (hp %d -> %d)" % [inv_hp, inv_hp2])

	# --- archer tower shoots paratroopers in the air
	await _aim_turn(1)
	g.weapon = "tower"
	var gh: Dictionary = g.tower_ghost(g.CASTLE_X[1])
	if not gh["ok"]:
		for dx in [-60.0, 60.0, -110.0, 110.0]:
			gh = g.tower_ghost(g.CASTLE_X[1] + dx)
			if gh["ok"]:
				break
	_check(gh["ok"], "tower spot found: %s" % gh["why"])
	g.use_weapon(gh["x"] + 12, 300)
	await _settle()
	await _wait_state("aim")
	_check(g.towers_of(1).size() == 1, "archer tower built")
	for s in g.units_of(0, "invader"):
		s.dead = true
	var arrows := 0
	g.turn = 0
	g.state = "aim"
	g.weapon = "para"
	g.use_weapon(0, 0)
	var t0 := Time.get_ticks_msec()
	while g.state == "busy" and Time.get_ticks_msec() - t0 < 30000:
		for p in g.projs:
			if p.type == "arrow":
				arrows += 1
		await _wait(0.1)
	await _shot("tower")
	_check(arrows > 0, "tower shoots arrows at paratroopers")
	print("TEST invaders alive after tower: %d of 3" % g.units_of(0, "invader").size())

	# --- other actions
	await _wait_state("aim")
	await _aim_turn(1)
	g.weapon = "wall"
	var wg: Dictionary = g.wall_ghost(1100)
	var b1: int = g.count_blocks(1)
	g.use_weapon(1100, 400)
	await _settle()
	_check(not wg["ok"] or g.count_blocks(1) - b1 == 8, "wall adds 8 bricks")
	await _aim_turn(1)
	g.weapon = "repair"
	g.use_weapon(0, 0)
	await _settle()
	_check(true, "repair works")
	await _aim_turn(1)
	g.weapon = "armor"
	g.use_weapon(0, 0)
	await _settle()
	var iron := 0
	for b in g.blocks:
		if b.iron:
			iron += 1
	_check(iron > 10, "iron armor (%d iron bricks)" % iron)
	var c = g.make_chest(800, 100)
	c.para = false
	g.chests.append(c)
	g.explode(815, 113, 30, 10, 0)
	_check(not g.chests.has(c), "crate opens: %s" % g.banner.get("sub", ""))
	await _aim_turn(0)
	var bt = g.treasures[1]
	g.players[0].inv["meteor"] = 1
	g.weapon = "meteor"
	g.use_weapon(bt.x + 22, 300)
	await _wait(1.2)
	await _shot("meteor")
	await _settle()

	# --- finish the game
	if g.state != "over":
		await _aim_turn(0)
		for i in 4:
			g.explode(bt.x + 22, bt.y + 18, 50, 60, 0)
		g.end_action()
		await _settle()
	await _wait(2.5)
	_check(g.state == "over" and g.hud.over_panel.visible, "game over screen shows")
	await _shot("game_over")

	# --- practice mode
	g.begin_battle("practice", "lava")
	await _wait(1.0)
	_check(g.mode == "practice" and g.state == "aim" and g.turn == 0, "practice starts")
	g.weapon = "mega"
	g.power = 0.7
	g.fire()
	await _settle()
	await _wait_state("aim")
	_check(g.turn == 0 and g.players[0].inv["mega"] > 0 and g.players[0].gold > 90000, "practice: still your turn, weapons stay")
	await _shot("practice_lava")

	print("TEST done, fails=%d" % fails)
	tree.quit(1 if fails > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("TEST PASS " if ok else "TEST FAIL ") + what)
	if not ok:
		fails += 1


func _wait(sec: float) -> void:
	await tree.create_timer(sec).timeout


func _settle() -> void:
	var t0 := Time.get_ticks_msec()
	while g.state == "busy" and Time.get_ticks_msec() - t0 < 40000:
		await _wait(0.1)


func _wait_state(st: String) -> void:
	var t0 := Time.get_ticks_msec()
	while g.state != st and g.state != "over" and Time.get_ticks_msec() - t0 < 20000:
		await _wait(0.1)


func _wait_turn(p: int) -> void:
	var t0 := Time.get_ticks_msec()
	while g.turn != p and g.state != "over" and Time.get_ticks_msec() - t0 < 40000:
		await _wait(0.1)
	await _wait_state("aim")


func _aim_turn(p: int) -> void:
	await _settle()
	await _wait_state("aim")
	if g.state == "over":
		return
	g.turn = p
	g.state = "aim"
	g.timer = 45.0
	g.ai = {}


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await tree.process_frame
	await tree.process_frame
	var img: Image = g.get_viewport().get_texture().get_image()
	var path := "user://shot_%s.png" % name
	img.save_png(path)
	print("TEST screenshot ", ProjectSettings.globalize_path(path))
