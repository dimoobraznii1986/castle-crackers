class_name Terrain
extends Sprite2D
## The ground. It can be destroyed.
## `data` has 2 bytes per pixel: [ground 0/255, burn 0..255].
## The shader in shaders/terrain.gdshader turns this into grass, soil and stones.

const W := 1600
const H := 900

var data := PackedByteArray()
var img: Image
var tex: ImageTexture
var dirty := false


func _ready() -> void:
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/terrain.gdshader")
	material = mat


func generate(castle_x: Array, plateau: float, theme: Dictionary) -> void:
	var tp: Dictionary = theme["terrain"]
	var mat := material as ShaderMaterial
	for key in theme["ground"]:
		var c: Color = theme["ground"][key]
		mat.set_shader_parameter(key, Vector3(c.r, c.g, c.b))
	data.resize(W * H * 2)
	data.fill(0)
	var p1 := randf() * TAU
	var p2 := randf() * TAU
	var p3 := randf() * TAU
	var mount: float = randf_range(tp["mount_min"], tp["mount_max"])
	var mx := 800.0 + randf_range(-70.0, 70.0)
	var mw: float = tp["mount_w"] * randf_range(0.8, 1.2)
	var v1: float = randf_range(0.2, 1.0) * tp["valley"]
	var v2: float = randf_range(0.2, 1.0) * tp["valley"]
	for x in W:
		var y: float = tp["base"] + tp["hill"] * sin(x * 0.0047 + p1) + tp["hill2"] * sin(x * 0.013 + p2) + 7.0 * sin(x * 0.041 + p3)
		y -= mount * exp(-pow((x - mx) / mw, 2.0))
		y += v1 * exp(-pow((x - 530.0) / 75.0, 2.0))
		y += v2 * exp(-pow((x - 1070.0) / 75.0, 2.0))
		y = minf(y, 815.0)
		for cx in castle_x:
			var t := smoothstep(165.0, 265.0, absf(x - cx))
			y = plateau * (1.0 - t) + y * t
		for yy in range(maxi(0, ceili(y)), H):
			data[(yy * W + x) * 2] = 255
	# floating islands
	var n_isl: int = tp["islands"]
	if n_isl < 0:
		n_isl = 1 if randf() < 0.5 else 2
	for k in n_isl:
		var cx: float
		if n_isl == 1:
			cx = randf_range(720.0, 880.0)
		elif k == 0:
			cx = randf_range(560.0, 680.0)
		else:
			cx = randf_range(920.0, 1040.0)
		var cy := randf_range(220.0, 310.0)
		var rw := randf_range(55.0, 95.0)
		var rh := randf_range(26.0, 42.0)
		for x in range(floori(cx - rw), ceili(cx + rw) + 1):
			var t := (x - cx) / rw
			var s := 1.0 - t * t
			if s <= 0.0:
				continue
			var top := cy - 9.0 * sqrt(s) + 3.0 * sin(x * 0.2)
			var bot := cy + rh * s * (0.8 + 0.2 * sin(x * 0.13 + k * 3.0))
			for yy in range(floori(top), ceili(bot)):
				if yy >= 0 and yy < H:
					data[(yy * W + x) * 2] = 255
	img = Image.create_from_data(W, H, false, Image.FORMAT_RG8, data)
	tex = ImageTexture.create_from_image(img)
	texture = tex
	dirty = false


func is_solid(x: int, y: int) -> bool:
	if x < 0 or x >= W or y < 0:
		return false
	if y >= H:
		return true
	return data[(y * W + x) * 2] != 0


## Remove ground in a circle. Darken the ground around the hole.
func carve(cx: float, cy: float, r: float, burn := true) -> void:
	var r2 := r * r
	var rb := r + 6.0
	var rb2 := rb * rb
	var x0 := maxi(0, floori(cx - rb))
	var x1 := mini(W - 1, ceili(cx + rb))
	var y0 := maxi(0, floori(cy - rb))
	var y1 := mini(H - 1, ceili(cy + rb))
	for yy in range(y0, y1 + 1):
		var dy := yy - cy
		var row := yy * W
		for xx in range(x0, x1 + 1):
			var dx := xx - cx
			var d2 := dx * dx + dy * dy
			if d2 > rb2:
				continue
			var i := (row + xx) * 2
			if d2 <= r2:
				data[i] = 0
				data[i + 1] = 0
			elif burn and data[i] != 0:
				data[i + 1] = mini(255, data[i + 1] + 140)
	dirty = true


## Send changes to the GPU (once per frame at most).
func flush() -> void:
	if not dirty:
		return
	img.set_data(W, H, false, Image.FORMAT_RG8, data)
	tex.update(img)
	dirty = false
