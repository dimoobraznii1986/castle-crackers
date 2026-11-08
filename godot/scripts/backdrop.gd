class_name Backdrop
extends Node2D
## Background, water and weather layers. Colors come from the map theme.
## mode: "sky", "mountains", "clouds", "water_back", "water_front", "weather".

var g
var mode := "sky"
var sun := Vector2(1100, 170)
var layers: Array = []   # mountain layers: [points, color]
var stars: Array = []    # night sky
var flakes: Array = []   # snow or embers


func regen() -> void:
	var th: Dictionary = g.theme
	if mode == "sky":
		sun = Vector2(randf_range(1000, 1250), randf_range(140, 190))
		stars = []
		if th["stars"]:
			for i in 140:
				stars.append([Vector2(randf_range(-300, 1900), randf_range(-500, 520)), randf_range(0.8, 2.2), randf() * TAU])
	elif mode == "mountains":
		layers = []
		var cols: Array = th["mountains"]
		var specs := [[560.0, 90.0, cols[0], 0.006], [640.0, 70.0, cols[1], 0.009]]
		for L in specs:
			var ph := randf() * 6.0
			var ph2 := randf() * 6.0
			var pts := PackedVector2Array()
			var x := -400.0
			while x <= 2000.0:
				var y: float
				if th["id"] == "desert":
					# flat-topped mesas
					y = L[0] - L[1] * clampf(1.6 * sin(x * L[3] + ph), 0.0, 1.0)
				else:
					y = L[0] - L[1] * (0.5 + 0.5 * sin(x * L[3] + ph)) - L[1] * 0.4 * absf(sin(x * L[3] * 2.7 + ph2))
				pts.append(Vector2(x, y))
				x += 8.0
			layers.append([pts, L[2]])
	elif mode == "weather":
		flakes = []
		if th["snow"] or th["lava"]:
			for i in 110:
				flakes.append([randf_range(0, 1600), randf_range(-400, 900), randf_range(25, 70), randf_range(1.2, 3.0), randf() * TAU])
	queue_redraw()


func _process(_delta: float) -> void:
	if g == null:
		return
	if mode == "mountains":
		# parallax: far mountains move slower than the ground
		position = (g.cam.get_screen_center_position() - Vector2(800, 450)) * 0.35
	elif mode != "sky" or not stars.is_empty():
		queue_redraw()


func _draw() -> void:
	if g == null or g.theme.is_empty():
		return
	var th: Dictionary = g.theme
	match mode:
		"sky":
			var stops: Array = th["sky"].duplicate()
			stops.append([1300.0, stops[-1][1]])
			for i in stops.size() - 1:
				var y0: float = stops[i][0]
				var y1: float = stops[i + 1][0]
				var c0: Color = stops[i][1]
				var c1: Color = stops[i + 1][1]
				draw_polygon(PackedVector2Array([Vector2(-400, y0), Vector2(2000, y0), Vector2(2000, y1), Vector2(-400, y1)]),
					PackedColorArray([c0, c0, c1, c1]))
			for st in stars:
				var tw := 0.6 + 0.4 * sin(g.t * 2.0 + st[2])
				draw_circle(st[0], st[1], Color(1, 1, 0.9, tw))
			var sun_col: Color = th["sun"]
			var size: float = th["sun_size"]
			for i in 8:
				draw_circle(sun, size * 4.1 - i * size * 0.4, Color(sun_col, 0.07))
			draw_circle(sun, size, sun_col)
			draw_arc(sun, size, 0, TAU, 48, th["sun_edge"], 4, true)
			if th["stars"]:
				# moon craters
				draw_circle(sun + Vector2(-8, -6), size * 0.22, Color(0.85, 0.8, 0.7))
				draw_circle(sun + Vector2(9, 8), size * 0.15, Color(0.85, 0.8, 0.7))
		"mountains":
			for L in layers:
				var top: PackedVector2Array = L[0]
				var poly := top.duplicate()
				poly.append(Vector2(2000, 1300))
				poly.append(Vector2(-400, 1300))
				draw_colored_polygon(poly, L[1])
				draw_polyline(top, th["mountain_line"], 3, true)
		"clouds":
			for c in g.clouds:
				var s: float = c["s"]
				var base := Vector2(c["x"], c["y"])
				for b in [[0.0, 6.0, 26.0], [30.0, 10.0, 22.0], [-28.0, 12.0, 20.0], [14.0, -8.0, 22.0]]:
					draw_circle(base + Vector2(b[0], b[1] + 6) * s, b[2] * s, th["cloud_shadow"])
				for b in [[0.0, 6.0, 26.0], [30.0, 10.0, 22.0], [-28.0, 12.0, 20.0], [14.0, -8.0, 22.0]]:
					draw_circle(base + Vector2(b[0], b[1]) * s, b[2] * s, th["cloud"])
		"water_back":
			draw_colored_polygon(_wave(-5.0, 1.3, 2.0, true), th["water_back"])
		"water_front":
			draw_colored_polygon(_wave(4.0, 2.0, 0.0, true), th["water_front"])
			draw_polyline(_wave(4.0, 2.0, 0.0, false), th["water_line"], 3, true)
			if th["lava"]:
				# bubbles on the lava
				for i in 10:
					var bx := fmod(i * 173.0 + g.t * 20.0, 1600.0)
					var r := 3.0 + 2.0 * sin(g.t * 3.0 + i)
					draw_circle(Vector2(bx, g.WATER + 14 + (i % 3) * 12), r, Color(1.0, 0.85, 0.3, 0.8))
		"weather":
			for f in flakes:
				var p: Vector2
				if th["snow"]:
					# snow falls and drifts with the wind
					var y := fmod(f[1] + g.t * f[2], 1300.0) - 400.0
					var x := fposmod(f[0] + g.t * g.wind * 40.0 + sin(g.t + f[4]) * 12.0, 1600.0)
					p = Vector2(x, y)
					draw_circle(p, f[3], Color(1, 1, 1, 0.85))
				else:
					# embers rise from the lava
					var y := 900.0 - fmod(f[1] + 400.0 + g.t * f[2], 1300.0)
					var x := fposmod(f[0] + sin(g.t * 1.5 + f[4]) * 15.0 + g.t * g.wind * 20.0, 1600.0)
					p = Vector2(x, y)
					draw_circle(p, f[3] * 0.8, Color(1.0, 0.6, 0.15, 0.7))


func _wave(off: float, speed: float, phase: float, closed: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var x := -200.0
	while x <= 1800.0:
		var y: float = g.WATER + off + sin(x * 0.02 + g.t * speed + phase) * 4.0 + sin(x * 0.05 - g.t * 1.1) * 2.0
		pts.append(Vector2(x, y))
		x += 16.0
	if closed:
		pts.append(Vector2(1800, 1000))
		pts.append(Vector2(-200, 1000))
	return pts
