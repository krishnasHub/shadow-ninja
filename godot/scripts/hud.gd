extends Control
## HUD + screens: title/pause menus (with About and Controls pages), caught, escaped.

var m

func _text(s: String, pos: Vector2, font: Font, size: int, col: Color, spacing := 0, center := false) -> void:
	var f := font
	if spacing != 0:
		var fv := FontVariation.new()
		fv.base_font = font
		fv.spacing_glyph = spacing
		f = fv
	if center:
		draw_string(f, pos - Vector2(480, 0), s, HORIZONTAL_ALIGNMENT_CENTER, 960, size, col)
	else:
		draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _draw() -> void:
	if m.state != "title":
		_hud()
	_screens()

func _eye(c: Vector2, o: float) -> void:            # opens with exposure
	var hh := 1 + o * 8
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in 17:
		var t := i / 16.0
		var x := lerpf(-16, 16, t)
		var y := hh * 2 * 2 * t * (1 - t)               # quadratic curve peak = hh
		top.append(c + Vector2(x, -y))
		bot.append(c + Vector2(x, y))
	draw_polyline(top, Color(1, 1, 1, 0.75), 1.5, true)
	draw_polyline(bot, Color(1, 1, 1, 0.75), 1.5, true)
	if o > 0.05:
		draw_circle(c, minf(4.5, hh), Color.WHITE)

func _hud() -> void:
	if m.state == "play" and m.level_t < 3.5:       # the floor's name as it starts, fading out
		var a := clampf(minf(m.level_t / 0.6, (3.5 - m.level_t) / 1.0), 0.0, 1.0)
		_text(m.level.name, Vector2(480, 130), m.font_regular, 30, Color(1, 1, 1, 0.85 * a), 12, true)
		_text(m.level.subtitle, Vector2(480, 162), m.font_italic, 16, Color(1, 1, 1, 0.6 * a), 0, true)
	if m.state == "play" and m.notice_t < 3.5:      # a notice (a lever pulled), fading the same way
		var a := clampf(minf(m.notice_t / 0.4, (3.5 - m.notice_t) / 1.0), 0.0, 1.0)
		_text(m.notice, Vector2(480, 150), m.font_italic, 18, Color(1, 1, 1, 0.75 * a), 0, true)
	var x := 28.0
	var y := 30.0
	var w := 230.0
	var h := 8.0
	_text("DETECTION", Vector2(x, y - 9), m.font_regular, 11, Color(1, 1, 1, 0.7), 3)
	draw_rect(Rect2(x - 0.5, y - 0.5, w + 1, h + 1), Color(1, 1, 1, 0.55), false, 1.0)
	draw_rect(Rect2(x, y, w * m.meter, h), Color(1, 1, 1, 0.55 + 0.45 * m.exposure))
	for t in [m.METER_SUSPICIOUS, m.METER_ALERT]:
		draw_rect(Rect2(x + w * t, y - 3, 1, h + 6), Color(1, 1, 1, 0.45))
	_eye(Vector2(x + w + 32, y + 4), m.exposure)
	for i in m.STONE.max:                             # stones in your pouch
		var c := Vector2(x + w + 72 + i * 13, y + 4)
		if i < m.stone_count:
			draw_circle(c, 4, Color(1, 1, 1, 0.7))
		else:
			draw_arc(c, 4, 0, TAU, 16, Color(1, 1, 1, 0.35), 1.0, true)
	if m.aiming:
		_text("THROW MODE  ·  click to throw  ·  CTRL to cancel", Vector2(x + w + 112, y + 8), m.font_regular, 11, Color(1, 1, 1, 0.75), 2)
	elif m.stone_count > 0:
		_text("CTRL", Vector2(x + w + 112, y + 8), m.font_regular, 10, Color(1, 1, 1, 0.3), 2)
	var seen_hide := false
	for g in m.guards:
		if g.knows_hide >= 0:
			seen_hide = true
	var status := "UNSEEN"
	if m.P.hidden and seen_hide:
		status = "HE SAW YOU HIDE - GO"
	elif m.P.hidden:
		status = "HIDDEN"
	elif m.exposure > m.TUNE.exposed_threshold:
		status = "EXPOSED"
	elif m.meter > 0:
		status = "IN SHADOW"
	_text(status, Vector2(x, y + 26), m.font_regular, 11, Color(1, 1, 1, 0.55), 3)
	draw_string(m.font_regular, Vector2(960 - 24 - 500, 540 - 18), "Esc menu  ·  R restart  ·  M music  ·  F11 fullscreen  ·  G debug",
		HORIZONTAL_ALIGNMENT_RIGHT, 500, 11, Color(1, 1, 1, 0.3))

const CONTROLS := [
	["A  D   /   ←  →", "run  (loud)"],
	["hold  SHIFT", "sneak  (silent)"],
	["SPACE  /  W  /  ↑", "jump  ·  grab a duct  ·  land on a guard to put him to sleep"],
	["S  /  ↓", "crawl  ·  hide behind furniture  ·  drop from a duct"],
	["CTRL", "throw mode  -  aim with the mouse, click to throw a stone"],
	["ESC", "pause menu"],
	["R    ·    F11", "restart    ·    fullscreen"],
	["M", "music on / off"],
]
const ABOUT := [
	"You slipped into a high-security office tower. Now you have to get out.",
	"Light is the enemy. Lamps, moonlight and every guard's torch fill your detection meter;",
	"shadow drains it. Fill it and you're caught.",
	"Hide behind furniture, cling to ducts, throw stones to pull guards away,",
	"or drop on one to put him to sleep - his torch goes dark with him.",
	"A guard who sees you duck knows where you went. One who doesn't walks right past.",
]

func _screens() -> void:
	var st: String = m.state
	var t: float = m.state_t
	if st == "title" or st == "pause":
		_menu(st == "pause")
	elif st == "caught":
		draw_rect(Rect2(0, 0, 960, 540), Color(1, 1, 1, maxf(0, 1 - t * 3)))
		draw_rect(Rect2(0, 0, 960, 540), Color(0, 0, 0, minf(0.78, t * 1.2)))
		if t > 0.4:
			_text("CAUGHT", Vector2(480, 260), m.font_regular, 56, Color(1, 1, 1, 0.92), 16, true)
			_text("the meter filled.", Vector2(480, 305), m.font_italic, 16, Color(1, 1, 1, 0.6), 0, true)
			_text("R  try again    ·    ESC  menu", Vector2(480, 345), m.font_regular, 13, Color(1, 1, 1, 0.5), 2, true)
	elif st == "escaped":
		draw_rect(Rect2(0, 0, 960, 540), Color(0, 0, 0, minf(0.8, t)))
		if t > 0.5:
			var last: bool = m.level_idx + 1 >= m.Levels.LEVELS.size()
			if last:
				_text("OUT", Vector2(480, 260), m.font_regular, 56, Color(1, 1, 1, 0.92), 16, true)
				_text("you made it out of the tower.", Vector2(480, 305), m.font_italic, 16, Color(1, 1, 1, 0.6), 0, true)
				_text("ENTER  menu    ·    R  replay this floor", Vector2(480, 345), m.font_regular, 13, Color(1, 1, 1, 0.5), 2, true)
			else:
				_text(m.level.name + "  CLEARED", Vector2(480, 260), m.font_regular, 40, Color(1, 1, 1, 0.92), 12, true)
				_text("down the stairs, into the dark.", Vector2(480, 300), m.font_italic, 16, Color(1, 1, 1, 0.6), 0, true)
				_text("ENTER  next floor    ·    R  replay this floor    ·    ESC  menu", Vector2(480, 345), m.font_regular, 13, Color(1, 1, 1, 0.5), 2, true)

func _menu(paused: bool) -> void:
	draw_rect(Rect2(0, 0, 960, 540), Color(0, 0, 0, 0.62 if paused else 0.55))
	if m.menu_page != "":                            # text pages: darker so they read easily
		draw_rect(Rect2(0, 0, 960, 540), Color(0, 0, 0, 0.45))
	if m.menu_page == "quit":
		_text("Are you sure?", Vector2(480, 240), m.font_italic, 28, Color(1, 1, 1, 0.9), 0, true)
		for i in 2:
			var label := "NO" if i == 0 else "YES"
			var x: float = m.QUIT_X[i]
			var sel: bool = i == m.quit_sel
			draw_string(m.font_regular, Vector2(x - 60, m.QUIT_Y), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 20, Color(1, 1, 1, 0.95 if sel else 0.42))
			if sel:
				draw_line(Vector2(x - 22, m.QUIT_Y + 10), Vector2(x + 22, m.QUIT_Y + 10), Color(1, 1, 1, 0.7), 1.0)
		_footer("← →  choose    ·    ENTER  select    ·    ESC  back")
		return
	if m.menu_page == "levels":
		_text("LEVELS", Vector2(480, 150), m.font_regular, 30, Color(1, 1, 1, 0.9), 10, true)
		for i in m.Levels.LEVELS.size():
			var L: Dictionary = m.Levels.LEVELS[i]
			var y: float = m.LEVELS_Y + i * m.MENU_DY
			var sel: bool = i == m.level_sel
			var label := "%s   ·   %s" % [L.name, L.subtitle]
			_text(label, Vector2(480, y), m.font_regular, 18, Color(1, 1, 1, 0.95 if sel else 0.42), 3, true)
			if sel:
				var half: float = (m.font_regular.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + label.length() * 3) / 2
				draw_line(Vector2(480 - half - 44, y - 6), Vector2(480 - half - 16, y - 6), Color(1, 1, 1, 0.7), 1.0)
				draw_line(Vector2(480 + half + 16, y - 6), Vector2(480 + half + 44, y - 6), Color(1, 1, 1, 0.7), 1.0)
		_footer("↑ ↓  choose    ·    ENTER  play    ·    ESC  back")
		return
	if m.menu_page == "about":
		_about()
		return
	if m.menu_page == "controls":
		_text("CONTROLS", Vector2(480, 120), m.font_regular, 30, Color(1, 1, 1, 0.9), 10, true)
		_table(190)
		_footer("ESC  back")
		return
	_text("SHADOW NINJA", Vector2(480, 165), m.font_regular, 54, Color(1, 1, 1, 0.92), 14, true)
	_text("paused" if paused else "stay out of the light", Vector2(480, 205), m.font_italic, 18, Color(1, 1, 1, 0.6), 0, true)
	var items: Array = m.menu_items()
	for i in items.size():
		var y: float = m.MENU_Y + i * m.MENU_DY
		var sel: bool = i == m.menu_sel
		var label: String = items[i].to_upper()
		_text(label, Vector2(480, y), m.font_regular, 20, Color(1, 1, 1, 0.95 if sel else 0.42), 5, true)
		if sel:                                      # short rules either side of the chosen item
			var half: float = (m.font_regular.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + label.length() * 5) / 2
			draw_line(Vector2(480 - half - 44, y - 7), Vector2(480 - half - 16, y - 7), Color(1, 1, 1, 0.7), 1.0)
			draw_line(Vector2(480 + half + 16, y - 7), Vector2(480 + half + 44, y - 7), Color(1, 1, 1, 0.7), 1.0)
	_footer("↑ ↓  choose    ·    ENTER  select" + ("    ·    ESC  resume" if paused else ""))

func _about() -> void:
	_text("ABOUT", Vector2(480, 80), m.font_regular, 30, Color(1, 1, 1, 0.9), 10, true)
	for i in ABOUT.size():
		_text(ABOUT[i], Vector2(480, 125 + i * 22), m.font_italic, 15, Color(1, 1, 1, 0.75), 0, true)
	_text("CONTROLS", Vector2(480, 275), m.font_regular, 13, Color(1, 1, 1, 0.55), 6, true)
	_table(305)
	_text("a greyscale stealth prototype, after Limbo and Mark of the Ninja", Vector2(480, 482), m.font_italic, 12, Color(1, 1, 1, 0.4), 0, true)
	_footer("ESC  back")

func _table(y0: float) -> void:                      # keys right-aligned, actions left-aligned
	for i in CONTROLS.size():
		var y := y0 + i * 24
		draw_string(m.font_regular, Vector2(100, y), CONTROLS[i][0], HORIZONTAL_ALIGNMENT_RIGHT, 300, 14, Color(1, 1, 1, 0.85))
		draw_string(m.font_italic, Vector2(425, y), CONTROLS[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.6))

func _footer(s: String) -> void:
	_text(s, Vector2(480, 515), m.font_regular, 11, Color(1, 1, 1, 0.35), 2, true)
