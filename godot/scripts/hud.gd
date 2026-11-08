class_name Hud
extends Control
## Screen UI: player panels, wind, timer, messages, weapon buttons,
## title screen, map ("land") screen and game-over screen.

const INK := Color(0.11, 0.08, 0.04)
const CREAM := Color(1.0, 0.97, 0.9, 0.95)

const LAND_INFO := {
	"hills": "Grass and hills",
	"snow": "Ice and snow",
	"desert": "Sand and an oasis",
	"lava": "Night and hot lava",
	"random": "A surprise!",
}

var g
var bar: HBoxContainer
var buttons: Array = []
var title_panel: Control
var map_panel: Control
var over_panel: Control
var over_title: Label
var over_sub: Label
var mute_btn: Button
var pending_mode := "duel"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_bar()
	_build_mute()
	_build_title()
	_build_map()
	_build_over()


# ---------------------------------------------------------------- styles
func _box(bg: Color, border: Color, bw := 3, radius := 13, shadow := true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	if shadow:
		s.shadow_color = INK
		s.shadow_size = 1
		s.shadow_offset = Vector2(0, 5)
	s.content_margin_left = 6
	s.content_margin_right = 6
	return s


func _label(text: String, size: int, color: Color, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font = Art.font()
	ls.font_size = size
	ls.font_color = color
	if outline > 0:
		ls.outline_size = outline
		ls.outline_color = INK
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _big_button(text: String, color: Color, width := 330) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(width, 84)
	b.add_theme_font_override("font", Art.font())
	b.add_theme_font_size_override("font_size", 32)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_color_override("font_outline_color", INK)
	b.add_theme_constant_override("outline_size", 8)
	b.add_theme_stylebox_override("normal", _box(color, INK, 5, 22))
	b.add_theme_stylebox_override("hover", _box(color.lightened(0.15), INK, 5, 22))
	b.add_theme_stylebox_override("pressed", _box(color.darkened(0.15), INK, 5, 22))
	return b


# ---------------------------------------------------------------- weapon bar
func _build_bar() -> void:
	bar = HBoxContainer.new()
	bar.position = Vector2(0, 900 - 90)
	bar.size = Vector2(1600, 80)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)
	for i in g.WEAPONS.size():
		var w: Dictionary = g.WEAPONS[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(106, 72)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): g.select_weapon(w["id"]))
		var icon := _label(w["icon"], 26, Color.WHITE)
		icon.position = Vector2(0, 4)
		icon.size = Vector2(106, 34)
		b.add_child(icon)
		var nm := _label(w["name"], 13, INK)
		nm.position = Vector2(0, 42)
		nm.size = Vector2(106, 20)
		b.add_child(nm)
		var key := _label(g.KEYS[i], 11, Color(INK, 0.55))
		key.position = Vector2(6, 3)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_child(key)
		var tag := _label("", 12, Color("ffd84a"))
		tag.position = Vector2(62, -12)
		tag.size = Vector2(52, 20)
		var tag_bg := StyleBoxFlat.new()
		tag_bg.bg_color = INK
		tag_bg.set_corner_radius_all(9)
		tag.add_theme_stylebox_override("normal", tag_bg)
		b.add_child(tag)
		bar.add_child(b)
		buttons.append({"btn": b, "icon": icon, "name": nm, "tag": tag, "w": w})
	bar.visible = false


func refresh_bar() -> void:
	var show: bool = g.state == "aim" or g.state == "busy" or g.state == "units"
	bar.visible = show
	if not show:
		return
	var p: int = g.turn
	var P = g.players[p]
	var active: bool = g.state == "aim" and not P.ai
	var practice: bool = g.mode == "practice"
	bar.modulate = Color(1, 1, 1, 1.0 if active else 0.45)
	var team: Color = g.TEAM[p]["color"]
	for item in buttons:
		var w: Dictionary = item["w"]
		var b: Button = item["btn"]
		var inv: int = P.inv[w["id"]]
		var locked: bool = w["secret"] and inv <= 0
		var usable: bool = g.can_use(p, w["id"])
		var selected: bool = g.weapon == w["id"]
		var bg := Color("ffe9a8")
		if locked:
			bg = Color("b3a8d6")
		elif selected:
			bg = Color("fff8d6")
		var border := team if selected else INK
		var sb := _box(bg, border, 5 if selected else 3)
		for st in ["normal", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, sb)
		b.add_theme_stylebox_override("hover", _box(bg.lightened(0.3), border, 5 if selected else 3))
		b.disabled = not active
		b.modulate = Color(1, 1, 1, 1) if (usable or locked) else Color(0.75, 0.75, 0.75, 0.6)
		b.position.y = -6 if selected else 0
		item["icon"].text = "🔒" if locked else w["icon"]
		item["name"].text = "Secret" if locked else w["name"]
		b.tooltip_text = "Secret weapon. Find it in a bonus crate!" if locked else w["desc"]
		var tag: Label = item["tag"]
		tag.visible = true
		if practice and (w["cost"] > 0 or w["secret"]):
			tag.text = "FREE"
			tag.label_settings.font_color = Color("8dff7a")
		elif inv > 0:
			tag.text = "x%d" % inv
			tag.label_settings.font_color = Color("8dff7a")
		elif w["secret"]:
			tag.visible = false
		elif w["cost"] > 0:
			tag.text = "%d g" % w["cost"]
			tag.label_settings.font_color = Color("ffd84a")
		else:
			tag.text = "FREE"
			tag.label_settings.font_color = Color("8dff7a")


# ---------------------------------------------------------------- mute
func _build_mute() -> void:
	mute_btn = Button.new()
	mute_btn.focus_mode = Control.FOCUS_NONE
	mute_btn.position = Vector2(1600 - 62, 900 - 150)
	mute_btn.custom_minimum_size = Vector2(48, 48)
	mute_btn.add_theme_font_override("font", Art.font())
	mute_btn.add_theme_font_size_override("font_size", 22)
	for st in ["normal", "hover", "pressed"]:
		mute_btn.add_theme_stylebox_override(st, _box(Color("fff3cf"), INK, 3, 24, false))
	mute_btn.tooltip_text = "Sound on/off (M)"
	mute_btn.pressed.connect(func(): g.toggle_mute())
	add_child(mute_btn)
	refresh_mute()


func refresh_mute() -> void:
	mute_btn.text = "🔇" if g.sfx.muted else "🔊"


# ---------------------------------------------------------------- overlays
func _overlay(dim_alpha := 0.62) -> Control:
	var root := Control.new()
	root.position = Vector2.ZERO
	root.size = Vector2(1600, 900)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.07, 0.16, dim_alpha)
	dim.size = Vector2(1600, 900)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	add_child(root)
	return root


func _centered_column(parent: Control, sep := 18) -> VBoxContainer:
	var center := CenterContainer.new()
	center.size = Vector2(1600, 900)
	parent.add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", sep)
	center.add_child(col)
	return col


func _title_label(text: String, size := 110) -> Label:
	var title := _label(text, size, Color("ffd84a"), 30)
	title.label_settings.shadow_color = INK
	title.label_settings.shadow_size = 1
	title.label_settings.shadow_offset = Vector2(0, 10)
	return title


func _build_title() -> void:
	title_panel = _overlay()
	var col := _centered_column(title_panel)
	col.add_child(_title_label("CASTLE CRACKERS"))
	col.add_child(_label("Two kingdoms. Two treasures. Only one winner.", 30, Color.WHITE, 12))
	var rules := PanelContainer.new()
	var rb := _box(CREAM, INK, 4, 20)
	rb.content_margin_left = 30
	rb.content_margin_right = 30
	rb.content_margin_top = 16
	rb.content_margin_bottom = 16
	rules.add_theme_stylebox_override("panel", rb)
	var rv := VBoxContainer.new()
	rules.add_child(rv)
	for line in [
		"🎯 Move the mouse to aim. Hold the mouse button (or SPACE) to charge. Let go to fire.",
		"👑 Break the enemy castle. Destroy the treasure inside to win.",
		"📦 Shoot the ? crates to win gold, weapons, armor and secret weapons.",
		"🪂 Drop paratroopers on the enemy castle. Defend yours with guards and archer towers.",
		"💨 Watch the wind. Rockets and parachutes feel it the most.",
	]:
		var l := _label(line, 21, INK)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		rv.add_child(l)
	col.add_child(rules)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	for m in [["2 PLAYERS", "duel", Color("e2412f")], ["VS COMPUTER", "ai", Color("2f7de2")], ["PRACTICE", "practice", Color("3fa34d")]]:
		var b := _big_button(m[0], m[2], 300)
		var game_mode: String = m[1]
		b.pressed.connect(func(): _choose_mode(game_mode))
		row.add_child(b)
	col.add_child(row)


func _build_map() -> void:
	map_panel = _overlay(0.35)
	var col := _centered_column(map_panel, 26)
	col.add_child(_title_label("CHOOSE YOUR LAND", 72))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	col.add_child(row)
	for id in Themes.LIST + ["random"]:
		row.add_child(_land_card(id))
	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var back := _big_button("BACK", Color("6a7a96"), 220)
	back.pressed.connect(func(): show_title())
	back_row.add_child(back)
	col.add_child(back_row)
	map_panel.visible = false


func _land_card(id: String) -> Button:
	var land_name := "Random"
	var icon := "🎲"
	var bg := Color("5b4b8a")
	if id != "random":
		var th := Themes.get_theme(id)
		land_name = th["name"]
		icon = th["icon"]
		bg = th["sky"][2][1]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(250, 270)
	b.add_theme_stylebox_override("normal", _box(bg, INK, 5, 22))
	b.add_theme_stylebox_override("hover", _box(bg.lightened(0.2), Color("ffd84a"), 7, 22))
	b.add_theme_stylebox_override("pressed", _box(bg.darkened(0.15), INK, 5, 22))
	var ic := _label(icon, 80, Color.WHITE)
	ic.position = Vector2(0, 26)
	ic.size = Vector2(250, 100)
	b.add_child(ic)
	var nm := _label(land_name, 28, Color.WHITE, 10)
	nm.position = Vector2(0, 140)
	nm.size = Vector2(250, 40)
	b.add_child(nm)
	var info := _label(LAND_INFO[id], 17, Color.WHITE, 6)
	info.position = Vector2(14, 190)
	info.size = Vector2(222, 60)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(info)
	b.mouse_entered.connect(func():
		if id != "random":
			g.new_game(id))
	b.pressed.connect(func(): g.begin_battle(pending_mode, id))
	return b


func _build_over() -> void:
	over_panel = _overlay()
	var col := _centered_column(over_panel, 24)
	over_title = _title_label("RED WINS!")
	col.add_child(over_title)
	over_sub = _label("", 30, Color.WHITE, 12)
	col.add_child(over_sub)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	var again := _big_button("PLAY AGAIN", Color("e2412f"))
	again.pressed.connect(func(): g.begin_battle(g.mode, g.theme_choice))
	var menu := _big_button("MENU", Color("6a7a96"))
	menu.pressed.connect(func():
		g.new_game(g.theme_choice)
		show_title())
	row.add_child(again)
	row.add_child(menu)
	col.add_child(row)
	over_panel.visible = false


func _choose_mode(game_mode: String) -> void:
	pending_mode = game_mode
	g.sfx.play("click")
	title_panel.visible = false
	map_panel.visible = true


func show_title() -> void:
	title_panel.visible = true
	map_panel.visible = false
	over_panel.visible = false
	refresh_bar()


func hide_overlays() -> void:
	title_panel.visible = false
	map_panel.visible = false
	over_panel.visible = false


func show_game_over(title: String, sub: String, color: Color) -> void:
	over_title.text = title
	over_title.label_settings.font_color = color
	over_sub.text = sub
	over_panel.visible = true


# ---------------------------------------------------------------- drawn HUD
func _draw() -> void:
	if g == null or g.state == "title":
		return
	for p in 2:
		_draw_panel(p)
	_draw_wind()
	_draw_texts()


func _draw_panel(p: int) -> void:
	var P = g.players[p]
	var T: Dictionary = g.TEAM[p]
	var tr = g.treasures[p]
	var w := 360.0
	var x := 16.0 if p == 0 else 1600.0 - 16.0 - w
	var y := 12.0
	var active: bool = g.turn == p and (g.state == "aim" or g.state == "busy" or g.state == "units")
	if active:
		var c: Color = T["color"]
		Art.fill_rrect(self, Rect2(x - 5, y - 5, w + 10, 102), 20, Color(c, 0.55 + 0.3 * sin(g.t * 5)))
	Art.fill_rrect(self, Rect2(x, y, w, 92), 16, CREAM, INK, 4)
	var named: String = g.team_name(p)
	var title: String = named if named.length() > 4 else "%s KINGDOM" % named
	Art.text(self, title, Vector2(x + 16, y + 32), 24, T["color"], Art.LEFT)
	Art.text(self, "👑", Vector2(x + 14, y + 74), 22, Color.WHITE, Art.LEFT, 0)
	Art.fill_rrect(self, Rect2(x + 48, y + 52, 190, 24), 10, Color("3a2a1a"))
	var hp := maxf(0.0, tr.hp)
	if hp > 0:
		Art.fill_rrect(self, Rect2(x + 51, y + 55, 184 * hp / 100.0, 18), 8, Color("f0a81e") if hp > 30 else Color("e0401e"))
		Art.fill_rrect(self, Rect2(x + 53, y + 56, maxf(0.0, 180 * hp / 100.0), 6), 3, Color(1, 1, 1, 0.35))
	Art.text(self, "%d / 100" % ceili(hp), Vector2(x + 143, y + 70), 15, Color.WHITE)
	var practice: bool = g.mode == "practice"
	if not (practice and p == 1):
		Art.text(self, "💰", Vector2(x + 250, y + 36), 20, Color.WHITE, Art.LEFT, 0)
		Art.text(self, "FREE" if practice else str(P.gold), Vector2(x + 282, y + 36), 22, Color("ffd84a"), Art.LEFT)
	var troops: int = g.units_of(p, "invader").size() + g.units_of(p, "guard").size()
	Art.text(self, "🪖", Vector2(x + 250, y + 74), 20, Color.WHITE, Art.LEFT, 0)
	Art.text(self, "x%d" % troops, Vector2(x + 282, y + 74), 22, Color.WHITE, Art.LEFT)


func _draw_wind() -> void:
	var cx := 800.0
	var y := 14.0
	Art.fill_rrect(self, Rect2(cx - 160, y, 320, 58), 14, CREAM, INK, 4)
	Art.text(self, "WIND", Vector2(cx, y + 22), 18, Color("9fdcff"))
	Art.fill_rrect(self, Rect2(cx - 130, y + 32, 260, 16), 8, INK)
	var wl: float = g.wind * 124.0
	if absf(wl) > 1:
		draw_rect(Rect2(minf(cx, cx + wl), y + 35, absf(wl), 10), Color("5fc4ff"))
		var s := signf(wl)
		var off := fmod(g.t * 40.0 * absf(g.wind), 14.0)
		var k := off
		while k < absf(wl) - 4:
			var ax := cx + s * k
			draw_colored_polygon(PackedVector2Array([Vector2(ax, y + 36), Vector2(ax + s * 5, y + 40), Vector2(ax, y + 44)]), Color(1, 1, 1, 0.8))
			k += 14.0
	else:
		Art.text(self, "calm", Vector2(cx, y + 46), 13, Color.WHITE)
	draw_rect(Rect2(cx - 1, y + 30, 2, 20), Color.WHITE)
	if g.state == "aim" or g.state == "busy" or g.state == "units":
		var tt := maxi(0, ceili(g.timer))
		draw_circle(Vector2(cx, 106), 28, g.TEAM[g.turn]["color"])
		draw_arc(Vector2(cx, 106), 28, 0, TAU, 32, INK, 4, true)
		var label := "..."
		if g.state == "aim":
			label = "--" if g.mode == "practice" else str(tt)
		Art.text(self, label, Vector2(cx, 115), 26, Color("ffe14a") if (tt <= 10 and g.state == "aim") else Color.WHITE)


func _draw_texts() -> void:
	if not g.banner.is_empty():
		var b: Dictionary = g.banner
		var age: float = b["max"] - b["life"]
		var f := clampf(b["life"] / 0.4, 0.0, 1.0)
		var sc := 0.5 + age / 0.2 * 0.5 if age < 0.2 else 1.0
		draw_set_transform(Vector2(800, 250), 0.0, Vector2(sc, sc))
		var c: Color = b["color"]
		Art.text(self, b["text"], Vector2.ZERO, 68, Color(c, f))
		if b["sub"] != "":
			Art.text(self, b["sub"], Vector2(0, 52), 32, Color(1, 1, 1, f))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not g.msg.is_empty():
		var c: Color = g.msg["color"]
		Art.text(self, g.msg["text"], Vector2(800, 770), 24, Color(c, clampf(g.msg["life"] / 0.4, 0.0, 1.0)))
	if g.state == "units":
		Art.text(self, "⚔️ Your soldiers and towers attack!", Vector2(800, 735), 24, Color("ffe9a0"))
		return
	if g.state == "aim":
		var w: Dictionary = g.wdef(g.weapon)
		if g.players[g.turn].ai:
			Art.text(self, "%s is thinking..." % g.team_name(g.turn), Vector2(800, 735), 24, Color("ffe9a0"))
			return
		var hint: String
		if w["kind"] == "shoot":
			hint = "Move the mouse to aim. Hold the mouse (or SPACE) to charge. Let go to fire."
		elif w["id"] == "wall":
			hint = "Click on your side of the map to build a wall."
		elif w["id"] == "tower":
			hint = "Click on your castle to build the tower."
		elif w["id"] == "meteor":
			hint = "Click where the meteors should fall."
		else:
			hint = "Click on the map (or press SPACE) to use %s." % w["name"]
		Art.text(self, "%s  %s: %s" % [w["icon"], w["name"], w["desc"]], Vector2(800, 712), 20, Color.WHITE)
		Art.text(self, hint, Vector2(800, 740), 17, Color("ffe9a0"))
