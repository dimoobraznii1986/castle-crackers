class_name WorldView
extends Node2D
## Draws everything on the battlefield: castles, treasures, crates, cannons,
## soldiers, shots, explosions and the aim helpers.
## Later you can swap any of these drawings for sprite images.

const INK := Color(0.11, 0.08, 0.04)

var g   # the main game node


func _draw() -> void:
	if g == null:
		return
	_draw_blocks()
	for tr in g.treasures:
		_draw_treasure(tr)
	for c in g.chests:
		_draw_chest(c)
	for tw in g.towers:
		_draw_tower(tw)
	for i in g.cannons.size():
		_draw_cannon(g.cannons[i], i)
	for s in g.soldiers:
		_draw_soldier(s)
	for p in g.projs:
		_draw_proj(p)
	_draw_parts()
	_draw_aim()


func _reset() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- castle bricks
func _draw_blocks() -> void:
	for b in g.blocks:
		if b.dead:
			continue
		var r: float = b.hp / b.max_hp
		var k := 0.62 + 0.38 * r
		var col: Color = Color8(122, 138, 162) if b.iron else b.base
		col = Color(col.r * k, col.g * k, col.b * k)
		draw_rect(Rect2(b.x, b.y, b.w, b.h), col)
		draw_rect(Rect2(b.x + 2, b.y + 2, b.w - 4, 3), Color(1, 1, 1, 0.28))
		draw_rect(Rect2(b.x + 2, b.y + b.h - 4, b.w - 4, 3), Color(0, 0, 0, 0.22))
		draw_rect(Rect2(b.x + 0.75, b.y + 0.75, b.w - 1.5, b.h - 1.5), Color8(59, 48, 39), false, 1.5)
		if b.iron:
			for o in [Vector2(4, 4), Vector2(b.w - 4, 4), Vector2(4, b.h - 4), Vector2(b.w - 4, b.h - 4)]:
				draw_circle(Vector2(b.x, b.y) + o, 1.6, Color("e4ecf5"))
		var n := 3 if r < 0.3 else (2 if r < 0.6 else (1 if r < 0.92 else 0))
		for i in n:
			var pts: PackedVector2Array = b.cracks[i]
			var moved := PackedVector2Array()
			for pt in pts:
				moved.append(pt + Vector2(b.x, b.y))
			draw_polyline(moved, Color8(30, 24, 19), 1.4)
	for b in g.blocks:
		if b.dead:
			continue
		if b.flag:
			_draw_flag(b)
		if b.roof:
			_draw_roof(b)


func _draw_roof(b) -> void:
	var T: Dictionary = g.TEAM[b.owner]
	var pts := PackedVector2Array([Vector2(b.x - 4, b.y + 1), Vector2(b.x + b.w + 4, b.y + 1), Vector2(b.x + b.w / 2, b.y - 26)])
	Art.outline_poly(self, pts, T["color"], INK, 2)
	draw_line(Vector2(b.x + 2, b.y - 6), Vector2(b.x + b.w - 2, b.y - 6), T["dark"], 2)
	draw_line(Vector2(b.x + b.w / 2, b.y - 26), Vector2(b.x + b.w / 2, b.y - 36), INK, 2)
	draw_circle(Vector2(b.x + b.w / 2, b.y - 37), 2.5, Color("ffd84a"))


func _draw_flag(b) -> void:
	var x: float = b.x + b.w / 2
	var y: float = b.y
	draw_line(Vector2(x, y), Vector2(x, y - 50), Color8(59, 42, 26), 3)
	var dir := 1.0 if g.wind >= 0 else -1.0
	var length: float = 22.0 + absf(g.wind) * 14.0
	var pts := PackedVector2Array()
	for i in range(0, 7):
		pts.append(Vector2(x + dir * length * i / 6.0, y - 50 + sin(g.t * 7 + i) * 2.5 * i / 6.0))
	for i in range(6, -1, -1):
		pts.append(Vector2(x + dir * length * i / 6.0, y - 32 + sin(g.t * 7 + i) * 2.5 * i / 6.0))
	Art.outline_poly(self, pts, g.TEAM[b.owner]["color"], INK, 2)
	draw_circle(Vector2(x + dir * length * 0.45, y - 41), 3.5, Color("ffd84a"))


# ---------------------------------------------------------------- treasure
func _draw_treasure(tr) -> void:
	if tr.gone:
		return
	var x: float = tr.x
	var y: float = tr.y
	var w: float = tr.w
	var h: float = tr.h
	var c := Vector2(x + w / 2, y + h / 2)
	var pulse := 0.06 + 0.025 * sin(g.t * 3 + tr.owner)
	for i in 6:
		draw_circle(c, 50.0 - i * 7.0, Color(1.0, 0.88, 0.43, pulse))
	for coin in [[9.0, 0.52, 7.0], [17.0, 0.4, 8.0], [27.0, 0.42, 8.0], [35.0, 0.52, 7.0], [22.0, 0.3, 6.0]]:
		var cp := Vector2(x + coin[0], y + h * coin[1])
		draw_circle(cp, coin[2], Color("ffd23f"))
		draw_arc(cp, coin[2], 0, TAU, 16, Color("8a5a00"), 1.5, true)
	var box := Rect2(x + 2, y + h * 0.48, w - 4, h * 0.52)
	Art.fill_rrect(self, box, 4, Color("8a4b1f"), Color8(43, 23, 9), 2.5)
	draw_rect(Rect2(x + 8, box.position.y + 1, 4, box.size.y - 2), Color("e8b33a"))
	draw_rect(Rect2(x + w - 12, box.position.y + 1, 4, box.size.y - 2), Color("e8b33a"))
	draw_rect(Rect2(x + w / 2 - 4, y + h * 0.62, 8, 8), Color("e8b33a"))
	var cx := x + w / 2
	var cy := y + h * 0.3
	var crown := PackedVector2Array([Vector2(cx - 12, cy), Vector2(cx - 13, cy - 13), Vector2(cx - 6, cy - 6), Vector2(cx, cy - 17),
		Vector2(cx + 6, cy - 6), Vector2(cx + 13, cy - 13), Vector2(cx + 12, cy)])
	Art.outline_poly(self, crown, Color("ffcc1f"), Color("6b4300"), 2)
	draw_circle(Vector2(cx, cy - 5), 3.5, g.TEAM[tr.owner]["color"])
	if sin(g.t * 2.3 + tr.owner * 2) > 0.85:
		Art.star(self, Vector2(cx + 10, cy - 14), 5, Color.WHITE)
	if tr.hurt > 0:
		draw_rect(Rect2(x, y - 16, w, h + 16), Color(1, 1, 1, tr.hurt * 0.7))
	if tr.show_hp > 0:
		var a := minf(1.0, tr.show_hp)
		Art.fill_rrect(self, Rect2(x - 4, y - 32, w + 8, 10), 4, Color(INK, a))
		var hc := Color("6be04a") if tr.hp > 50 else (Color("ffc62a") if tr.hp > 25 else Color("ff4a3a"))
		hc.a = a
		draw_rect(Rect2(x - 2, y - 30, (w + 4) * tr.hp / 100.0, 6), hc)


# ---------------------------------------------------------------- bonus crate
func _draw_chest(c) -> void:
	var w: float = c.w
	var h: float = c.h
	# draw around a pivot at the top middle, so the crate can swing under the parachute
	var rot: float = sin(c.sway) * 0.12 if c.para else 0.0
	draw_set_transform(Vector2(c.x + w / 2, c.y), rot, Vector2.ONE)
	var x := -w / 2
	var y := 0.0
	if c.para:
		var pc := Vector2(0, -40)
		draw_line(Vector2(x + 2, y), pc + Vector2(-30, 0), Color(0.2, 0.2, 0.2), 1.2)
		draw_line(Vector2(x + w - 2, y), pc + Vector2(30, 0), Color(0.2, 0.2, 0.2), 1.2)
		draw_line(Vector2(0, y), pc + Vector2(0, -2), Color(0.2, 0.2, 0.2), 1.2)
		for i in 5:
			var pts := PackedVector2Array([pc])
			for k in 5:
				var a := PI + (i + k / 4.0) * PI / 5.0
				pts.append(pc + Vector2(cos(a), sin(a)) * 32)
			draw_colored_polygon(pts, Color.WHITE if i % 2 == 1 else Color("e8412f"))
		draw_arc(pc, 32, PI, TAU, 24, INK, 2.5, true)
	draw_rect(Rect2(x, y, w, h), Color("c8873a"))
	draw_line(Vector2(x, y + h / 3), Vector2(x + w, y + h / 3), Color("8a5520"), 1.5)
	draw_line(Vector2(x, y + 2 * h / 3), Vector2(x + w, y + 2 * h / 3), Color("8a5520"), 1.5)
	draw_rect(Rect2(x, y, w, h), Color8(58, 36, 16), false, 2.5)
	for o in [Vector2(0, 0), Vector2(w - 5, 0), Vector2(0, h - 5), Vector2(w - 5, h - 5)]:
		draw_rect(Rect2(Vector2(x, y) + o, Vector2(5, 5)), Color(0.47, 0.47, 0.47))
	Art.text(self, "?", Vector2(0, y + h / 2 + 8), 22, Color.WHITE)
	_reset()


# ---------------------------------------------------------------- cannon
func _draw_cannon(c, p: int) -> void:
	var P = g.players[p]
	var px: float = c.x + c.w / 2
	var py: float = c.y + 8
	draw_set_transform(Vector2(px, py), P.angle, Vector2.ONE)
	var rec: float = -c.recoil * 8
	Art.fill_rrect(self, Rect2(rec - 8, -7, 40, 14), 6, Color("3d3d46"), Color("141418"), 2.5)
	draw_rect(Rect2(rec - 4, -5, 32, 3), Color(1, 1, 1, 0.28))
	draw_rect(Rect2(rec + 18, -8, 5, 16), g.TEAM[p]["color"])
	draw_rect(Rect2(rec + 18, -8, 5, 16), Color("141418"), false, 2)
	Art.fill_rrect(self, Rect2(rec + 30, -8.5, 6, 17), 2, Color("26262c"), Color("141418"), 2)
	_reset()
	var carriage := PackedVector2Array([Vector2(c.x + 3, c.y + c.h - 5), Vector2(c.x + c.w - 3, c.y + c.h - 5), Vector2(px + 9, py + 1), Vector2(px - 9, py + 1)])
	Art.outline_poly(self, carriage, Color("7a4a22"), Color8(43, 23, 9), 2.5)
	for wx in [c.x + 9, c.x + c.w - 9]:
		var wc := Vector2(wx, c.y + c.h - 8)
		draw_circle(wc, 8, Color("5a3416"))
		draw_arc(wc, 8, 0, TAU, 20, Color8(43, 23, 9), 2.5, true)
		for i in 3:
			var a: float = i * PI / 3 + wx
			draw_line(wc + Vector2(cos(a), sin(a)) * 7, wc - Vector2(cos(a), sin(a)) * 7, Color8(43, 23, 9), 1.5)
		draw_circle(wc, 2.5, Color("d9a441"))


# ---------------------------------------------------------------- soldier
func _draw_soldier(s) -> void:
	var T: Dictionary = g.TEAM[s.owner]
	var guard: bool = s.role == "guard"
	var fx: float = s.x + s.w / 2
	var by: float = s.y + s.h
	var d: float = s.dir
	if s.para:
		# parachute in team colors, swinging a bit
		var sw: float = sin(s.sway) * 0.15
		draw_set_transform(Vector2(fx, by - 22), sw, Vector2.ONE)
		var pc := Vector2(0, -30)
		for side in [-1.0, 1.0]:
			draw_line(Vector2(side * 4, 0), pc + Vector2(side * 22, 0), Color(0.2, 0.2, 0.2), 1.0)
		for i in 4:
			var pts := PackedVector2Array([pc])
			for k in 5:
				var a := PI + (i + k / 4.0) * PI / 4.0
				pts.append(pc + Vector2(cos(a), sin(a)) * 24)
			draw_colored_polygon(pts, T["color"] if i % 2 == 0 else Color.WHITE)
		draw_arc(pc, 24, PI, TAU, 20, INK, 2, true)
		_reset()
	var ph := 0.0
	if s.vx != 0.0:
		ph = sin(s.anim * 14) * 3.5
	elif s.para:
		ph = sin(s.anim * 5) * 2.0
	draw_line(Vector2(fx - 2, by - 7), Vector2(fx - 2 + ph, by - 1), INK, 3)
	draw_line(Vector2(fx + 2, by - 7), Vector2(fx + 2 - ph, by - 1), INK, 3)
	# spear (invader) or tall spear with flag (guard)
	var swing := sin(s.atk * 12) * 0.8 if s.atk > 0 else 0.0
	draw_set_transform(Vector2(fx + d * 5, by - 12), d * (0.35 + swing), Vector2.ONE)
	draw_line(Vector2(0, 6), Vector2(0, -20 if guard else -16), Color("6b4a22"), 2)
	var tip := -20.0 if guard else -16.0
	draw_colored_polygon(PackedVector2Array([Vector2(-3, tip + 1), Vector2(0, tip - 6), Vector2(3, tip + 1)]), Color("d8dde5"))
	_reset()
	var body_col: Color = T["color"]
	if s.hurt > 0:
		body_col = body_col.lerp(Color.WHITE, s.hurt)
	Art.fill_rrect(self, Rect2(fx - 5.5, by - 16, 11, 10), 3, body_col, INK, 2)
	if guard:
		# round shield in front
		var sc := Vector2(fx + d * 6, by - 11)
		draw_circle(sc, 5, Color("d9a441"))
		draw_arc(sc, 5, 0, TAU, 14, INK, 1.5, true)
		draw_circle(sc, 1.6, T["dark"])
	draw_circle(Vector2(fx, by - 20.5), 5.5, Color("ffcfa6"))
	draw_arc(Vector2(fx, by - 20.5), 5.5, 0, TAU, 16, INK, 2, true)
	var helmet := PackedVector2Array()
	for i in 9:
		var a := PI + i * PI / 8.0
		helmet.append(Vector2(fx, by - 21.5) + Vector2(cos(a), sin(a)) * 6.0)
	Art.outline_poly(self, helmet, Color("c9ced6") if guard else T["dark"], INK, 2)
	if guard:
		draw_line(Vector2(fx, by - 27), Vector2(fx - d * 4, by - 33), T["color"], 3)   # plume
	draw_circle(Vector2(fx + d * 2.5, by - 19.5), 2.2, Color.WHITE)
	draw_circle(Vector2(fx + d * 3.2, by - 19.5), 1.1, Color.BLACK)
	if s.hp < s.max_hp:
		draw_rect(Rect2(fx - 8, by - 34, 16, 4), INK)
		draw_rect(Rect2(fx - 7, by - 33, 14 * s.hp / s.max_hp, 2), Color("6be04a"))


# ---------------------------------------------------------------- archer tower
func _draw_tower(tw) -> void:
	var T: Dictionary = g.TEAM[tw.owner]
	var x: float = tw.x
	var y: float = tw.y
	var w: float = tw.w
	var h: float = tw.h
	var wood := Color("9a6a3a").lerp(Color.WHITE, tw.hurt * 0.6)
	# legs
	draw_line(Vector2(x + 3, y + h), Vector2(x + 7, y + 18), Color("6b4a22"), 3)
	draw_line(Vector2(x + w - 3, y + h), Vector2(x + w - 7, y + 18), Color("6b4a22"), 3)
	draw_line(Vector2(x + 5, y + h - 8), Vector2(x + w - 5, y + 24), Color("6b4a22"), 2)
	draw_line(Vector2(x + w - 5, y + h - 8), Vector2(x + 5, y + 24), Color("6b4a22"), 2)
	# cabin
	Art.fill_rrect(self, Rect2(x, y + 8, w, 12), 2, wood, INK, 2)
	draw_rect(Rect2(x + w / 2 - 4, y + 10, 8, 6), Color(0.1, 0.07, 0.05))
	# archer head in the window
	draw_circle(Vector2(x + w / 2, y + 12), 3.0, Color("ffcfa6"))
	# roof
	Art.outline_poly(self, PackedVector2Array([Vector2(x - 4, y + 9), Vector2(x + w + 4, y + 9), Vector2(x + w / 2, y - 8)]), T["color"], INK, 2)
	if tw.hp < tw.max_hp:
		draw_rect(Rect2(x, y - 16, w, 4), INK)
		draw_rect(Rect2(x + 1, y - 15, (w - 2) * maxf(0.0, tw.hp) / tw.max_hp, 2), Color("6be04a"))


# ---------------------------------------------------------------- projectiles
func _draw_proj(p) -> void:
	var pos := Vector2(p.x, p.y)
	var a := atan2(p.vy, p.vx)
	match p.type:
		"spear", "arrow":
			draw_set_transform(pos, a, Vector2.ONE)
			var length := 16.0 if p.type == "spear" else 12.0
			draw_line(Vector2(-length, 0), Vector2(length - 4, 0), Color("6b4a22"), 2)
			draw_colored_polygon(PackedVector2Array([Vector2(length - 5, -3), Vector2(length + 2, 0), Vector2(length - 5, 3)]), Color("d8dde5"))
			if p.type == "arrow":
				draw_line(Vector2(-length, 0), Vector2(-length - 4, -3), Color.WHITE, 2)
				draw_line(Vector2(-length, 0), Vector2(-length - 4, 3), Color.WHITE, 2)
			_reset()
		"ball", "bomblet":
			var r := 6.0 if p.type == "ball" else 4.0
			draw_circle(pos, r, Color("26262c"))
			draw_arc(pos, r, 0, TAU, 16, Color.BLACK, 2, true)
			draw_circle(pos - Vector2(r, r) / 3.0, r / 3.0, Color(1, 1, 1, 0.5))
		"cluster":
			draw_circle(pos, 7, Color("d8322a"))
			draw_arc(pos, 7, 0, TAU, 16, Color.BLACK, 2, true)
			for i in 4:
				var aa: float = i * 1.57 + g.t * 8
				draw_circle(pos + Vector2(cos(aa), sin(aa)) * 3.5, 1.6, Color("ffd84a"))
		"bounce":
			draw_circle(pos, 7, Color("3f8f2b"))
			draw_arc(pos, 7, 0, TAU, 16, Color.BLACK, 2, true)
			draw_rect(Rect2(pos.x - 2, pos.y - 11, 4, 4), Color(0.67, 0.67, 0.67))
			Art.text(self, str(ceili(p.fuse)), pos + Vector2(0, -16), 16, Color.WHITE)
		"mega":
			draw_circle(pos, 13, Color("7d756c"))
			draw_arc(pos, 13, 0, TAU, 24, Color.BLACK, 3, true)
			draw_circle(pos + Vector2(-4, 3), 3, Color("5d564f"))
			draw_circle(pos + Vector2(5, -4), 2.5, Color("5d564f"))
		"meteor":
			for i in 4:
				draw_circle(pos, 22.0 - i * 4.0, Color(1.0, 0.55 + i * 0.1, 0.2, 0.15))
			draw_circle(pos, 9, Color("6b3a24"))
			draw_arc(pos, 9, 0, TAU, 16, Color.BLACK, 2, true)
		"rocket", "drill":
			var rot := atan2(p.dy, p.dx) if p.drilling else a
			draw_set_transform(pos, rot, Vector2.ONE)
			if p.type == "rocket":
				Art.fill_rrect(self, Rect2(-12, -4.5, 20, 9), 3, Color("e9e9ee"), Color.BLACK, 2)
				Art.outline_poly(self, PackedVector2Array([Vector2(8, -4.5), Vector2(15, 0), Vector2(8, 4.5)]), Color("e2412f"), Color.BLACK, 2)
				draw_colored_polygon(PackedVector2Array([Vector2(-12, -4), Vector2(-16, -9), Vector2(-8, -4)]), Color("e2412f"))
				draw_colored_polygon(PackedVector2Array([Vector2(-12, 4), Vector2(-16, 9), Vector2(-8, 4)]), Color("e2412f"))
			else:
				Art.fill_rrect(self, Rect2(-12, -5, 14, 10), 2, Color("d6a420"), Color.BLACK, 2)
				Art.outline_poly(self, PackedVector2Array([Vector2(2, -5), Vector2(16, 0), Vector2(2, 5)]), Color("c9d0d8"), Color.BLACK, 2)
				var o := fmod(g.t * 60.0, 4.0)
				for i in 3:
					draw_line(Vector2(4 + i * 4 + o, -4 + i), Vector2(6 + i * 4 + o, 4 - i), Color(0.4, 0.4, 0.4), 1)
			_reset()


# ---------------------------------------------------------------- particles
func _draw_parts() -> void:
	for p in g.parts:
		var f := clampf(p["life"] / p["max"], 0.0, 1.0)
		var pos := Vector2(p["x"], p["y"])
		match p["type"]:
			"smoke":
				var c: Color = p["color"]
				draw_circle(pos, p["r"], Color(c, 0.55 * f))
			"fire":
				var c := Color("fff3a0") if f > 0.6 else (Color("ffb22a") if f > 0.3 else Color("e8461f"))
				draw_circle(pos, p["size"] * (0.5 + f * 0.6), c)
			"debris":
				var c: Color = p["color"]
				var s: float = p["size"]
				draw_set_transform(pos, p["rot"], Vector2.ONE)
				draw_rect(Rect2(-s / 2, -s / 2, s, s), Color(c, minf(1.0, f * 2)))
				draw_rect(Rect2(-s / 2, -s / 2, s, s), Color(0, 0, 0, 0.5 * minf(1.0, f * 2)), false, 1)
				_reset()
			"coin":
				draw_set_transform(pos, 0.0, Vector2(absf(cos(p["rot"])) + 0.15, 1.0))
				draw_circle(Vector2.ZERO, 4.5, Color(1.0, 0.82, 0.25, minf(1.0, f * 2)))
				draw_arc(Vector2.ZERO, 4.5, 0, TAU, 12, Color("8a5a00"), 1.5)
				_reset()
			"drop":
				var c: Color = p.get("color", Color(0.75, 0.9, 1.0))
				draw_circle(pos, p["size"], Color(c, f))
			"spark":
				draw_line(pos, pos - Vector2(p["vx"], p["vy"]) * 0.03, Color(1.0, 0.9, 0.47, f), 2)
			"star":
				var c: Color = p["color"]
				Art.star(self, pos, p["size"], Color(c, f))
			"flash":
				var r: float = p["r"]
				draw_circle(pos, r, Color(1.0, 0.55, 0.16, f * 0.25))
				draw_circle(pos, r * 0.75, Color(1.0, 0.82, 0.35, f * 0.45))
				draw_circle(pos, r * 0.45, Color(1.0, 1.0, 0.9, f * 0.8))
			"ring":
				draw_arc(pos, p["r"] * (1.6 - f * 0.8), 0, TAU, 32, Color(1, 1, 1, f * 0.8), 4 * f + 1, true)
	# comic text on top
	for p in g.parts:
		if p["type"] != "text":
			continue
		var f := clampf(p["life"] / p["max"], 0.0, 1.0)
		var age := 1.0 - f
		var sc := 0.4 + age / 0.12 * 0.8 if age < 0.12 else 1.2 - minf(0.2, age - 0.12)
		var c: Color = p["color"]
		draw_set_transform(Vector2(p["x"], p["y"]), 0.0, Vector2(sc, sc))
		Art.text(self, p["text"], Vector2.ZERO, p["size"], Color(c, minf(1.0, f * 3)))
		_reset()


# ---------------------------------------------------------------- aim helpers
func _draw_aim() -> void:
	if g.state != "aim":
		return
	var p: int = g.turn
	var c = g.cannons[p]
	var T: Dictionary = g.TEAM[p]
	var w: Dictionary = g.wdef(g.weapon)
	var px: float = c.x + c.w / 2
	var py: float = c.y + 8
	var by: float = c.y - 30 + sin(g.t * 6) * 5
	Art.outline_poly(self, PackedVector2Array([Vector2(px - 10, by - 12), Vector2(px + 10, by - 12), Vector2(px, by)]), T["color"], INK, 2.5)
	if w["kind"] == "shoot":
		var ang: float = g.players[p].angle
		var dir := Vector2(cos(ang), sin(ang))
		var hc := Vector2(px, py) + dir * 110
		draw_arc(hc, 10, 0, TAU, 20, T["color"], 3, true)
		for o in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			draw_line(hc + o * 5, hc + o * 15, T["color"], 3)
		if g.charging:
			var n := int(g.power * 18)
			for i in n + 1:
				var f := i / 18.0
				draw_circle(Vector2(px, py) + dir * (38 + i * 6.5), 2.5 + f * 6, Color.from_hsv((120.0 - f * 120.0) / 360.0, 0.9, 0.95))
			Art.text(self, "%d%%" % roundi(g.power * 100), Vector2(px, c.y - 50), 18, Color.WHITE)
	elif g.weapon == "wall" and not g.players[p].ai:
		var gh: Dictionary = g.wall_ghost(g.mouse.x)
		var rc := Rect2(gh["x"], gh["y"], gh["w"], gh["h"])
		draw_rect(rc, Color(0.75, 0.91, 0.69, 0.55) if gh["ok"] else Color(1.0, 0.54, 0.48, 0.55))
		draw_rect(rc, Color("2f7a1f") if gh["ok"] else Color("a01e10"), false, 3)
	elif g.weapon == "tower" and not g.players[p].ai:
		var gh: Dictionary = g.tower_ghost(g.mouse.x)
		var rc := Rect2(gh["x"], gh["y"], gh["w"], gh["h"])
		draw_rect(rc, Color(0.75, 0.91, 0.69, 0.55) if gh["ok"] else Color(1.0, 0.54, 0.48, 0.55))
		draw_rect(rc, Color("2f7a1f") if gh["ok"] else Color("a01e10"), false, 3)
	elif g.weapon == "meteor" and not g.players[p].ai:
		var x: float = g.mouse.x
		draw_dashed_line(Vector2(x, 30), Vector2(x, g.WATER), Color(1.0, 0.35, 0.16, 0.8), 3, 10)
		draw_arc(Vector2(x, g.surface_y(x, 30)), 30, 0, TAU, 32, Color("ff5a28"), 3, true)
