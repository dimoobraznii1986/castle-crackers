class_name Art
extends RefCounted
## Shared drawing helpers: fonts, outlined text, rounded rectangles, stars.

const INK := Color(0.11, 0.08, 0.04)
const CENTER := 0
const LEFT := -1
const RIGHT := 1

static var _font: Font


static func font() -> Font:
	if _font == null:
		var emoji := SystemFont.new()
		emoji.font_names = PackedStringArray(["Apple Color Emoji", "Segoe UI Emoji", "Noto Color Emoji"])
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Trebuchet MS", "Arial Rounded MT Bold", "Verdana", "Arial", "sans-serif"])
		f.font_weight = 800
		f.fallbacks = [emoji]
		_font = f
	return _font


## Cartoon text with a dark outline. `pos` is the baseline point.
static func text(ci: CanvasItem, s: String, pos: Vector2, size: int, color: Color, align := CENTER, outline := -1) -> void:
	var f := font()
	var p := pos
	if align != LEFT:
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		p.x -= w / 2.0 if align == CENTER else w
	var ow := outline if outline >= 0 else maxi(4, size / 4)
	ci.draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ow, Color(INK, color.a))
	ci.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func rrect(r: Rect2, rad: float) -> PackedVector2Array:
	rad = minf(rad, minf(r.size.x, r.size.y) / 2.0)
	var pts := PackedVector2Array()
	var corners := [
		Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.end.x - rad, r.end.y - rad),
		Vector2(r.position.x + rad, r.end.y - rad), Vector2(r.position.x + rad, r.position.y + rad),
	]
	var starts := [-PI / 2.0, 0.0, PI / 2.0, PI]
	for i in 4:
		for k in 5:
			var a: float = starts[i] + k * (PI / 2.0) / 4.0
			pts.append(corners[i] + Vector2(cos(a), sin(a)) * rad)
	return pts


static func fill_rrect(ci: CanvasItem, r: Rect2, rad: float, fill: Color, line := Color(0, 0, 0, 0), width := 2.0) -> void:
	if r.size.x < 1.0 or r.size.y < 1.0:
		return
	var pts := rrect(r, rad)
	ci.draw_colored_polygon(pts, fill)
	if line.a > 0.0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, line, width, true)


static func outline_poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, line: Color, width := 2.0) -> void:
	ci.draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, line, width, true)


static func star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := i * PI / 4.0
		var rr := r * 0.35 if i % 2 == 1 else r
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, col)
