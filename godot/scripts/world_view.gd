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
	_draw_interiors()
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


# ---------------------------------------------------------------- castle
## Dark back wall of the castle rooms, and torches in the treasure room.
## A room cell is drawn only while there are still bricks above it.
func _draw_interiors() -> void:
	for p in 2:
		if g.castle_style.size() < 2:
			return
		var stone: Color = g.castle_style[p]["color"]
		var dark := stone.darkened(0.58)
		var line := stone.darkened(0.72)
		for cell in g.interiors[p]:
			if not _covered(cell.x + 9, cell.y + 9, p):
				continue
			draw_rect(Rect2(cell.x, cell.y, 18, 18), dark)
			draw_line(Vector2(cell.x, cell.y + 9), Vector2(cell.x + 18, cell.y + 9), line, 1.0)
			var jx: float = cell.x + (9.0 if int(cell.y / 18.0) % 2 == 0 else 0.0)
			draw_line(Vector2(jx, cell.y), Vector2(jx, cell.y + 9), line, 1.0)
			draw_line(Vector2(cell.x + 18 - (jx - cell.x), cell.y + 9), Vector2(cell.x + 18 - (jx - cell.x), cell.y + 18), line, 1.0)
		# torches on the treasure room walls
		var x0: float = g.CASTLE_X[p] - 7 * 18
		var ty: float = g.PLATEAU - 18 - 40
		for tx in [x0 + 4 * 18 + 7, x0 + 10 * 18 - 7]:
			if not _covered(tx, ty, p):
				continue
			var fl := 0.8 + 0.2 * sin(g.t * 13.0 + tx) + 0.1 * sin(g.t * 23.0)
			draw_circle(Vector2(tx, ty), 26 * fl, Color(1.0, 0.7, 0.3, 0.13))
			draw_circle(Vector2(tx, ty), 14 * fl, Color(1.0, 0.75, 0.35, 0.18))
			draw_line(Vector2(tx, ty + 4), Vector2(tx, ty + 15), Color("5a3416"), 3)
			draw_circle(Vector2(tx, ty), 4.5 * fl, Color("ff8a2a"))
			draw_circle(Vector2(tx, ty - 2 * fl), 3.0 * fl, Color("ffe14a"))


func _covered(x: float, y: float, p: int) -> bool:
	for k in range(1, 7):
		var b = g.block_at(x, y - k * 18)
		if b != null and b.owner == p:
			return true
	return false


func _draw_blocks() -> void:
	# soft shadow on the ground under the castles
	for p in 2:
		var cx: float = g.CASTLE_X[p]
		draw_rect(Rect2(cx - 7 * 18 - 10, g.PLATEAU - 2, 14 * 18 + 20, 8), Color(0, 0, 0, 0.16))
	for b in g.blocks:
		if not b.dead:
			_draw_brick(b)
	var snow: bool = g.theme.get("snow", false)
	for b in g.blocks:
		if not b.dead:
			_draw_edges(b, snow)
	for b in g.blocks:
		if b.dead:
			continue
		if b.deco == "banner":
			_draw_banner(b)
		if b.flag:
			_draw_flag(b)
		if b.roof:
			_draw_roof(b)


## One block = 2 rows of bricks with mortar lines (running bond).
func _draw_brick(b) -> void:
	var x: float = b.x
	var y: float = b.y
	var r: float = clampf(b.hp / b.max_hp, 0.0, 1.0)
	var k := 0.62 + 0.38 * r
	var base: Color = b.base
	for course in 2:
		var t: float = b.tones[course]
		var c := Color((base.r + t) * k, (base.g + t) * k, (base.b + t) * k)
		draw_rect(Rect2(x, y + course * 9, 18, 9), c)
		draw_rect(Rect2(x, y + course * 9, 18, 2), Color(1, 1, 1, 0.16))
		draw_rect(Rect2(x, y + course * 9 + 7, 18, 2), Color(0, 0, 0, 0.1))
	var mortar := Color(base.r * 0.5 * k, base.g * 0.5 * k, base.b * 0.5 * k)
	draw_line(Vector2(x, y + 9), Vector2(x + 18, y + 9), mortar, 1.2)
	draw_line(Vector2(x, y + 0.5), Vector2(x + 18, y + 0.5), mortar, 1.0)
	var mid: int = b.pat
	draw_line(Vector2(x + 9, y + mid * 9), Vector2(x + 9, y + mid * 9 + 9), mortar, 1.2)
	draw_line(Vector2(x + 0.5, y + (1 - mid) * 9), Vector2(x + 0.5, y + (1 - mid) * 9 + 9), mortar, 1.2)
	if b.moss:
		var mc := Color(0.33, 0.55, 0.2, 0.85)
		draw_circle(Vector2(x + 4, y + 16), 3.0, mc)
		draw_circle(Vector2(x + 8, y + 17), 2.2, mc)
		draw_circle(Vector2(x + 2, y + 12), 1.8, mc)
	# decorations
	match b.deco:
		"window":
			var hole := Color(0.12, 0.09, 0.07)
			draw_rect(Rect2(x + 5, y + 7, 8, 9), hole)
			draw_circle(Vector2(x + 9, y + 7), 4, hole)
			var glow := 0.55 + 0.2 * sin(g.t * 2.5 + x)
			draw_rect(Rect2(x + 6, y + 8, 6, 7), Color(1.0, 0.78, 0.35, glow))
			draw_circle(Vector2(x + 9, y + 7.5), 3, Color(1.0, 0.82, 0.4, glow))
			draw_line(Vector2(x + 9, y + 4), Vector2(x + 9, y + 16), hole, 1.2)
			draw_line(Vector2(x + 5, y + 10), Vector2(x + 13, y + 10), hole, 1.2)
			draw_rect(Rect2(x + 4, y + 15.5, 10, 2), Color(1, 1, 1, 0.35))
		"slit":
			var hole := Color(0.1, 0.07, 0.05)
			draw_rect(Rect2(x + 7.5, y + 3, 3, 12), hole)
			draw_rect(Rect2(x + 5, y + 8, 8, 2.5), hole)
	# cracks
	var n := 3 if r < 0.3 else (2 if r < 0.6 else (1 if r < 0.92 else 0))
	for i in n:
		var pts: PackedVector2Array = b.cracks[i]
		var moved := PackedVector2Array()
		for pt in pts:
			moved.append(pt + Vector2(x, y))
		draw_polyline(moved, Color8(30, 24, 19), 1.4)


## Thick ink line on every open side, so the castle looks like one cartoon shape.
## Open tops get battlements (and snow on the snowy map).
func _draw_edges(b, snow: bool) -> void:
	var x: float = b.x
	var y: float = b.y
	var open_top := _open(x + 9, y - 3)
	if open_top:
		if not b.roof and not b.flag and b.vy == 0.0 and int(roundf(x / 18.0)) % 2 == 0 and _free_above(x, y):
			var mr := Rect2(x + 2, y - 7, 14, 8)
			var mc: Color = b.base
			draw_rect(mr, mc)
			draw_rect(Rect2(mr.position.x, mr.position.y, 14, 2), Color(1, 1, 1, 0.2))
			draw_polyline(PackedVector2Array([Vector2(x + 2, y), Vector2(x + 2, y - 7), Vector2(x + 16, y - 7), Vector2(x + 16, y)]), INK, 2.5)
			if snow:
				Art.fill_rrect(self, Rect2(x + 1, y - 10, 16, 5), 2.5, Color(0.97, 0.98, 1.0))
		draw_line(Vector2(x - 1, y), Vector2(x + 19, y), INK, 2.5)
		if snow:
			Art.fill_rrect(self, Rect2(x - 1, y - 3, 20, 5), 2.5, Color(0.97, 0.98, 1.0))
			draw_circle(Vector2(x + 5, y + 2), 1.8, Color(0.97, 0.98, 1.0))
	if _open(x + 9, y + 21) and not g.solid_at(x + 9, y + 19.5, b):
		draw_line(Vector2(x - 1, y + 18), Vector2(x + 19, y + 18), INK, 2.5)
	if _open(x - 3, y + 9):
		draw_line(Vector2(x, y - 1), Vector2(x, y + 19), INK, 2.5)
	if _open(x + 21, y + 9):
		draw_line(Vector2(x + 18, y - 1), Vector2(x + 18, y + 19), INK, 2.5)


func _open(x: float, y: float) -> bool:
	return g.block_at(x, y) == null


func _free_above(x: float, y: float) -> bool:
	for o in g.cannons + g.towers:
		if g.rects_overlap(x, y - 10, 18, 10, o):
			return false
	return true


func _draw_banner(b) -> void:
	var T: Dictionary = g.TEAM[b.owner]
	var x: float = b.x + 3
	var y: float = b.y + 1
	var sway := sin(g.t * 2.0 + b.x) * 1.0
	var pts := PackedVector2Array([Vector2(x, y), Vector2(x + 12, y), Vector2(x + 12 + sway, y + 21), Vector2(x + 6 + sway, y + 16), Vector2(x + sway, y + 21)])
	Art.outline_poly(self, pts, T["color"], INK, 1.5)
	draw_line(Vector2(x - 1, y), Vector2(x + 13, y), Color("6b4a22"), 2)
	draw_circle(Vector2(x + 6 + sway * 0.5, y + 8), 2.8, Color("ffd84a"))


## Roof cones. Roof bricks side by side share one big cone.
func _draw_roof(b) -> void:
	var left = g.block_at(b.x - 9, b.y + 9)
	if left != null and left.roof and absf(left.y - b.y) < 1.0:
		return
	var n := 1
	var cur = b
	while n < 6:
		var nb = g.block_at(cur.x + 27, cur.y + 9)
		if nb == null or not nb.roof or absf(nb.y - b.y) > 1.0:
			break
		n += 1
		cur = nb
	var T: Dictionary = g.TEAM[b.owner]
	var w := n * 18.0
	var h := 24.0 + w * 0.6
	var x0: float = b.x - 5
	var x1: float = b.x + w + 5
	var top := Vector2(b.x + w / 2, b.y - h)
	Art.outline_poly(self, PackedVector2Array([Vector2(x0, b.y + 1), Vector2(x1, b.y + 1), top]), T["color"], INK, 2.5)
	# shingle rows
	for i in range(1, 4):
		var f := i / 4.0
		var yy: float = b.y + 1 - h * f
		var half := (x1 - x0) / 2.0 * (1.0 - f)
		draw_line(Vector2(top.x - half + 2, yy), Vector2(top.x + half - 2, yy), T["dark"], 2)
	draw_colored_polygon(PackedVector2Array([Vector2(top.x, top.y + 4), Vector2(top.x + 3, b.y - 2), Vector2(x1 - 6, b.y - 2)]), Color(0, 0, 0, 0.15))
	# pole and a small pennant
	draw_line(top, top + Vector2(0, -14), INK, 2)
	var dir := 1.0 if g.wind >= 0 else -1.0
	var wv := sin(g.t * 8.0 + b.x) * 1.5
	draw_colored_polygon(PackedVector2Array([top + Vector2(0, -14), top + Vector2(dir * 12, -11 + wv), top + Vector2(0, -8)]), Color("ffd84a"))
	draw_circle(top + Vector2(0, -15), 2, Color("ffd84a"))


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
			var chute: Color = Color("e8412f") if c.tier == "" else g.gem_color(c.tier)
			draw_colored_polygon(pts, Color.WHITE if i % 2 == 1 else chute)
		draw_arc(pc, 32, PI, TAU, 24, INK, 2.5, true)
	if c.tier != "":
		_draw_gem_chest(c, x, y, w, h)
		_reset()
		return
	draw_rect(Rect2(x, y, w, h), Color("c8873a"))
	draw_line(Vector2(x, y + h / 3), Vector2(x + w, y + h / 3), Color("8a5520"), 1.5)
	draw_line(Vector2(x, y + 2 * h / 3), Vector2(x + w, y + 2 * h / 3), Color("8a5520"), 1.5)
	draw_rect(Rect2(x, y, w, h), Color8(58, 36, 16), false, 2.5)
	for o in [Vector2(0, 0), Vector2(w - 5, 0), Vector2(0, h - 5), Vector2(w - 5, h - 5)]:
		draw_rect(Rect2(Vector2(x, y) + o, Vector2(5, 5)), Color(0.47, 0.47, 0.47))
	Art.text(self, "?", Vector2(0, y + h / 2 + 8), 22, Color.WHITE)
	_reset()


## Emerald or diamond crate: shiny, glowing, with cracks after each hit.
func _draw_gem_chest(c, x: float, y: float, w: float, h: float) -> void:
	var gem: Color = g.gem_color(c.tier)
	var pulse := 0.5 + 0.5 * sin(g.t * 4.0)
	for i in 4:
		draw_circle(Vector2(0, y + h / 2), 34.0 - i * 6.0, Color(gem, 0.06 + 0.05 * pulse))
	var body := gem.darkened(0.25).lerp(Color.WHITE, c.hurt * 0.7)
	draw_rect(Rect2(x, y, w, h), body)
	# shiny facets
	draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + w * 0.45, y), Vector2(x, y + h * 0.6)]), Color(1, 1, 1, 0.35))
	draw_colored_polygon(PackedVector2Array([Vector2(x + w, y + h), Vector2(x + w * 0.55, y + h), Vector2(x + w, y + h * 0.4)]), Color(0, 0, 0, 0.18))
	# gold frame
	draw_rect(Rect2(x, y, w, h), Color("ffcc1f"), false, 3)
	draw_rect(Rect2(x, y, w, h), INK, false, 1.2)
	draw_line(Vector2(x, y + h / 2), Vector2(x + w, y + h / 2), Color("ffcc1f"), 2)
	# gem on the front
	var gc := Vector2(0, y + h / 2)
	var d := PackedVector2Array([gc + Vector2(0, -7), gc + Vector2(6, 0), gc + Vector2(0, 7), gc + Vector2(-6, 0)])
	Art.outline_poly(self, d, gem.lightened(0.4), INK, 1.5)
	# cracks: one per hit
	var hits: int = int(c.max_hp - c.hp)
	var cracks := [
		[Vector2(x + 3, y + 4), Vector2(x + 9, y + 10), Vector2(x + 7, y + 16)],
		[Vector2(x + w - 3, y + 3), Vector2(x + w - 10, y + 9), Vector2(x + w - 8, y + 20)],
	]
	for i in mini(hits, cracks.size()):
		draw_polyline(PackedVector2Array(cracks[i]), INK, 2)
	# twinkle and hits left
	if sin(g.t * 3.0 + c.x) > 0.6:
		Art.star(self, Vector2(x + w - 4, y + 3), 5, Color.WHITE)
	Art.text(self, "%d" % int(c.hp), Vector2(0, y - 6), 16, Color.WHITE)


# ---------------------------------------------------------------- cannon
func _draw_cannon(c, p: int) -> void:
	var P = g.players[p]
	var px: float = c.x + c.w / 2
	var py: float = c.y + 8
	draw_set_transform(Vector2(px, py), P.angle, Vector2.ONE)
	var rec: float = -c.recoil * 8
	var l: int = g.lvl(p, "cannon")
	var bl := 40.0 + l * 5.0
	var bh := 14.0 + l * 2.0
	Art.fill_rrect(self, Rect2(rec - 8, -bh / 2, bl, bh), 6, Color("3d3d46"), Color("141418"), 2.5)
	draw_rect(Rect2(rec - 4, -bh / 2 + 2, bl - 8, 3), Color(1, 1, 1, 0.28))
	draw_rect(Rect2(rec + 18, -bh / 2 - 1, 5, bh + 2), g.TEAM[p]["color"])
	draw_rect(Rect2(rec + 18, -bh / 2 - 1, 5, bh + 2), Color("141418"), false, 2)
	for i in l:
		draw_rect(Rect2(rec + 4 + i * 6, -bh / 2 - 1, 3, bh + 2), Color("ffcc1f"))
	Art.fill_rrect(self, Rect2(rec + bl - 10, -bh / 2 - 1.5, 6, bh + 3), 2, Color("26262c"), Color("141418"), 2)
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
	elif s.torn > 0:
		# torn parachute flaps above the falling soldier
		var a := clampf(s.torn, 0.0, 1.0)
		for i in 3:
			var ox := (i - 1) * 7.0
			var wv := sin(g.t * 30.0 + i * 2.0) * 5.0
			draw_line(Vector2(fx, by - 22), Vector2(fx + ox + wv, by - 46), Color(0.2, 0.2, 0.2, a), 1.0)
			draw_colored_polygon(PackedVector2Array([Vector2(fx + ox + wv - 4, by - 46), Vector2(fx + ox + wv + 4, by - 46), Vector2(fx + ox - wv * 0.5, by - 34)]),
				Color(T["color"] if i != 1 else Color.WHITE, a))
	var ph := 0.0
	if s.vx != 0.0 or s.vy < 0.0:
		ph = 3.0
	elif s.para:
		ph = sin(s.anim * 5) * 2.0
	draw_line(Vector2(fx - 2, by - 7), Vector2(fx - 2 + ph, by - 1), INK, 3)
	draw_line(Vector2(fx + 2, by - 7), Vector2(fx + 2 - ph, by - 1), INK, 3)
	# weapon: sword (guard) or pickaxe (invader). It swings when attacking.
	var swing := sin(s.atk * 12) * 1.1 if s.atk > 0 else 0.0
	draw_set_transform(Vector2(fx + d * 5, by - 12), d * (0.35 + swing), Vector2.ONE)
	if guard:
		draw_line(Vector2(0, 5), Vector2(0, -2), Color("6b4a22"), 3)
		draw_line(Vector2(-4, -2), Vector2(4, -2), Color("d9a441"), 3)
		draw_colored_polygon(PackedVector2Array([Vector2(-2, -3), Vector2(2, -3), Vector2(1.5, -19), Vector2(0, -22), Vector2(-1.5, -19)]), Color("e8edf3"))
		draw_line(Vector2(0, -4), Vector2(0, -19), Color(0.6, 0.65, 0.72), 1)
	else:
		draw_line(Vector2(0, 6), Vector2(0, -15), Color("8a5a2b"), 2.5)
		draw_polyline(PackedVector2Array([Vector2(-8, -11), Vector2(-3, -15), Vector2(3, -15), Vector2(8, -11)]), Color("9aa3ad"), 3.5)
		draw_polyline(PackedVector2Array([Vector2(-8, -11), Vector2(-3, -15), Vector2(3, -15), Vector2(8, -11)]), INK, 1.0)
	_reset()
	var body_col: Color = T["color"]
	if s.hurt > 0:
		body_col = body_col.lerp(Color.WHITE, s.hurt)
	if not guard:
		# backpack
		Art.fill_rrect(self, Rect2(fx - d * 7 - 3, by - 16, 6, 8), 2, Color("6b5a3a"), INK, 1.5)
	Art.fill_rrect(self, Rect2(fx - 5.5, by - 16, 11, 10), 3, body_col, INK, 2)
	draw_line(Vector2(fx - 5, by - 9), Vector2(fx + 5, by - 9), Color("5a3416"), 2)
	if guard:
		# big round shield in front
		var sc := Vector2(fx + d * 6, by - 11)
		draw_circle(sc, 6.5, T["color"])
		draw_arc(sc, 6.5, 0, TAU, 16, Color("d9a441"), 2, true)
		draw_arc(sc, 7.5, 0, TAU, 16, INK, 1.2, true)
		draw_circle(sc, 2, Color("ffd84a"))
	draw_circle(Vector2(fx, by - 20.5), 5.5, Color("ffcfa6"))
	draw_arc(Vector2(fx, by - 20.5), 5.5, 0, TAU, 16, INK, 2, true)
	if guard:
		var helmet := PackedVector2Array()
		for i in 9:
			var a := PI + i * PI / 8.0
			helmet.append(Vector2(fx, by - 21.5) + Vector2(cos(a), sin(a)) * 6.0)
		Art.outline_poly(self, helmet, Color("c9ced6"), INK, 2)
		draw_line(Vector2(fx, by - 27), Vector2(fx - d * 5, by - 34), T["color"], 3.5)   # plume
	else:
		# bandana with knot
		draw_rect(Rect2(fx - 5.5, by - 26, 11, 4), T["color"])
		draw_rect(Rect2(fx - 5.5, by - 26, 11, 4), INK, false, 1.2)
		draw_line(Vector2(fx - d * 5, by - 24), Vector2(fx - d * 10, by - 22 + sin(g.t * 9 + s.x) * 2), T["color"], 2)
	draw_circle(Vector2(fx + d * 2.5, by - 19.5), 2.2, Color.WHITE)
	draw_circle(Vector2(fx + d * 3.2, by - 19.5), 1.1, Color.BLACK)
	if s.atk > 0:
		draw_line(Vector2(fx + d * 0.5, by - 23.5), Vector2(fx + d * 4.5, by - 22.5), INK, 1.5)   # angry brow
	if s.hp < s.max_hp:
		draw_rect(Rect2(fx - 8, by - 38, 16, 4), INK)
		draw_rect(Rect2(fx - 7, by - 37, 14 * maxf(0.0, s.hp) / s.max_hp, 2), Color("6be04a"))


# ---------------------------------------------------------------- archer tower
## A stone turret on the castle with an archer on top.
func _draw_tower(tw) -> void:
	var T: Dictionary = g.TEAM[tw.owner]
	var x: float = tw.x
	var y: float = tw.y
	var w: float = tw.w
	var h: float = tw.h
	var d: float = tw.dir
	var stone: Color = g.castle_style[tw.owner]["color"]
	stone = stone.lerp(Color.WHITE, tw.hurt * 0.6)
	var mortar := stone.darkened(0.45)
	# body
	var body := Rect2(x + 3, y + 16, w - 6, h - 16)
	draw_rect(body, stone)
	var row := 0
	var yy := y + 16.0
	while yy < y + h:
		draw_line(Vector2(x + 3, yy), Vector2(x + w - 3, yy), mortar, 1.0)
		var jx := x + 3 + (8.0 if row % 2 == 0 else 15.0)
		draw_line(Vector2(jx, yy), Vector2(jx, minf(yy + 8, y + h)), mortar, 1.0)
		yy += 8.0
		row += 1
	draw_rect(Rect2(x + w / 2 - 1.5, y + 24, 3, 10), Color(0.1, 0.07, 0.05))
	draw_rect(body, INK, false, 2.5)
	# archer (behind the battlements)
	var ax := x + w / 2
	var ay := y + 5
	draw_rect(Rect2(ax - 4, ay + 2, 8, 8), T["color"])
	draw_circle(Vector2(ax, ay), 4.2, Color("ffcfa6"))
	draw_arc(Vector2(ax, ay), 4.2, 0, TAU, 12, INK, 1.5, true)
	draw_rect(Rect2(ax - 4.5, ay - 5, 9, 3), T["dark"])
	draw_circle(Vector2(ax + d * 2, ay), 1.0, Color.BLACK)
	# bow: pulled back while shooting
	var pull := 4.0 if tw.atk > 0 else 0.0
	var bc := Vector2(ax + d * 5, ay + 2)
	draw_arc(bc, 8, -PI / 2 if d > 0 else PI / 2, PI / 2 if d > 0 else PI * 1.5, 10, Color("8a5a2b"), 2, true)
	var top := bc + Vector2(0, -8)
	var bot := bc + Vector2(0, 8)
	var mid := bc + Vector2(-d * pull, 0)
	draw_polyline(PackedVector2Array([top, mid, bot]), Color(1, 1, 1, 0.8), 1)
	if tw.atk > 0:
		draw_line(mid, mid + Vector2(d * 14, 0), Color("6b4a22"), 1.5)
	# platform and battlements
	var plat := Rect2(x, y + 10, w, 7)
	draw_rect(plat, stone)
	draw_rect(plat, INK, false, 2.5)
	for mx in [x, x + w - 8]:
		draw_rect(Rect2(mx, y + 2, 8, 9), stone)
		draw_rect(Rect2(mx, y + 2, 8, 9), INK, false, 2)
	# pennant on a pole at the back
	var px := x + (2.0 if d > 0 else w - 2.0)
	draw_line(Vector2(px, y + 2), Vector2(px, y - 18), INK, 2)
	var dir := 1.0 if g.wind >= 0 else -1.0
	var wv := sin(g.t * 8.0 + x) * 1.5
	draw_colored_polygon(PackedVector2Array([Vector2(px, y - 18), Vector2(px + dir * 14, y - 14 + wv), Vector2(px, y - 10)]), T["color"])
	var al: int = g.lvl(tw.owner, "archers")
	for i in al:
		Art.star(self, Vector2(x + w / 2 - (al - 1) * 5 + i * 10, y + 40), 4, Color("ffd84a"))
	if tw.hp < tw.max_hp:
		draw_rect(Rect2(x, y - 26, w, 4), INK)
		draw_rect(Rect2(x + 1, y - 25, (w - 2) * maxf(0.0, tw.hp) / tw.max_hp, 2), Color("6be04a"))


# ---------------------------------------------------------------- projectiles
func _draw_proj(p) -> void:
	var pos := Vector2(p.x, p.y)
	var a := atan2(p.vy, p.vx)
	match p.type:
		"spear", "arrow":
			if p.prog < 0.0:
				return
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
		var sl: int = g.lvl(p, "scope")
		if sl > 0 and not g.players[p].ai:
			var pw: float = g.power if g.charging else g.players[p].last_power
			var path: PackedVector2Array = g.trajectory(p, g.weapon, ang, pw, 0.7 if sl == 1 else 2.0)
			for i in range(2, path.size(), 3):
				var f := 1.0 - float(i) / path.size() * 0.6
				draw_circle(path[i], 3.2, Color(INK, 0.5 * f))
				draw_circle(path[i], 2.2, Color(1, 1, 1, 0.9 * f))
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
