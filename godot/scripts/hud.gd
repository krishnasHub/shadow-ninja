extends Control
## HUD + screens: title/pause menus (with About and Controls pages), caught, escaped.

var m

# outline: a dark edge (px) so the line reads over a lit wall.
func _text(s: String, pos: Vector2, font: Font, size: int, col: Color, spacing := 0, center := false, outline := 0) -> void:
	var f := font
	if spacing != 0:
		var fv := FontVariation.new()
		fv.base_font = font
		fv.spacing_glyph = spacing
		f = fv
	if outline > 0:
		var oc := Color(0.02, 0.02, 0.02, 0.85 * col.a)
		if center:
			draw_string_outline(f, pos - Vector2(480, 0), s, HORIZONTAL_ALIGNMENT_CENTER, 960, size, outline, oc)
		else:
			draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, oc)
	if center:
		draw_string(f, pos - Vector2(480, 0), s, HORIZONTAL_ALIGNMENT_CENTER, 960, size, col)
	else:
		draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _draw() -> void:
	if m.state != "title":
		_hud()
		_opening()
	_screens()

# The opening scene: black, the room slowly fading in as he comes to, the prompt to hide, then the
# letterbox: the guards' lines sit in the bottom bar under whoever's speaking, word by word.
func _opening() -> void:
	if m.state != "play":
		return
	if m.intro == "hide" and m.intro_t > m.WAKE.prompt:
		var left := maxf(0.0, m.WAKE.prompt + m.level.intro.hide - m.intro_t)
		var a := clampf((m.intro_t - m.WAKE.prompt) / 0.8, 0.0, 1.0)
		_text(_k("footsteps.  hide  -  ↓  behind the bench.", "footsteps.  hide  -  B  behind the bench."), Vector2(480, 140), m.font_italic, 14, Color(1, 1, 1, 0.8 * a), 0, true, 5)
		_text("%d" % ceili(left), Vector2(480, 164), m.font_regular, 12, Color(1, 1, 1, 0.6 * a), 3, true, 5)
	if m.bars > 0.0:
		var h: float = 62.0 * m.bars
		draw_rect(Rect2(0, 0, 960, h), Color(0, 0, 0))
		draw_rect(Rect2(0, 540 - h, 960, h), Color(0, 0, 0))
	if m.intro == "talk":
		_talk_line()
	if m.intro == "talk" or m.recall == "say":
		var top: float = 31.0 * m.bars
		_text(_k("SPACE  next    ·    ESC  skip", "A  next    ·    START  skip"), Vector2(480, top + 4), m.font_regular, 9, Color(1, 1, 1, 0.25), 2, true)
	if m.recall == "say":                       # his own words, under him
		var line: String = m.recall_mem.say[m.recall_i]
		var sx: float = (m.get_viewport().get_canvas_transform() * Vector2(m.P.x + m.P.w / 2, 0)).x
		_say(line, sx, m.recall_t, m.line_dur([0, line]))
	if m.recall == "gift":
		_gift()
	if m.wake_seen() < 1.0:                     # waking: the dark lifts
		draw_rect(Rect2(0, 0, 960, 540), Color(0.035, 0.035, 0.04, 1.0 - m.wake_seen()))

var talk_font: FontVariation
const TALK_SIZE := 13
const TALK_INK := Color(0.6, 0.6, 0.6)
const TALK_FAINT := Color(0.24, 0.24, 0.25)       # the words he half-hears

func _talk_line() -> void:
	var line: Array = m.level.intro.talk[m.talk_i]
	var g = m.intro_guards()[line[0]]
	_say(line[1], g.x - m.cam.x, m.talk_t, m.line_dur(line))

# One line, in the bottom bar under the speaker (sx: his x on screen): small spaced caps. Each word
# drifts up into place a beat after the last; when the line's done, it lifts away. ~faint~ words are
# the half-heard (or half-remembered) ones.
func _say(text: String, sx: float, t: float, dur: float) -> void:
	if talk_font == null:
		talk_font = FontVariation.new()
		talk_font.base_font = m.font_regular
		talk_font.spacing_glyph = 3
	var words := []                                  # [word, faint]
	var faint := false
	for w in text.split(" "):
		if w.begins_with("~"):
			faint = true
		words.append([w.replace("~", "").to_upper(), faint])
		if w.ends_with("~"):
			faint = false
	var sp := talk_font.get_string_size("  ", HORIZONTAL_ALIGNMENT_LEFT, -1, TALK_SIZE).x
	var total := -sp
	for w in words:
		total += talk_font.get_string_size(w[0], HORIZONTAL_ALIGNMENT_LEFT, -1, TALK_SIZE).x + sp
	var cx := clampf(sx, total / 2 + 24, 960 - total / 2 - 24)
	var y: float = 540 - 31.0 * m.bars + TALK_SIZE * 0.35
	var out := smoothstep(dur + m.TALK_GAP * 0.6 - 0.45, dur + m.TALK_GAP * 0.6, t)
	var x := cx - total / 2
	for i in words.size():
		var k := smoothstep(i * 0.11, i * 0.11 + 0.5, t)
		var col: Color = TALK_FAINT if words[i][1] else TALK_INK
		col.a = k * (1.0 - out)
		draw_string(talk_font, Vector2(x, y + (1.0 - k) * 9.0 - out * 8.0), words[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, TALK_SIZE, col)
		x += talk_font.get_string_size(words[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, TALK_SIZE).x + sp

func _star_icon(c: Vector2, col: Color, r := 5.0, rot := 0.4) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		pts.append(c + Vector2.from_angle(rot + i * TAU / 8.0) * (r if i % 2 == 0 else r * 0.32))
	draw_colored_polygon(pts, col)

# Where the HUD's star icons sit (the recall's star flies to the middle one).
func _star_slot(i: int) -> Vector2:
	return Vector2(28.0 + 230.0 + 76.0 + i * 15.0, 34.0)

# The recall's gift: the star flashes in at the top, turns, its name under it - then it shrinks and
# flies down into its place in the HUD.
func _gift() -> void:
	var g: Dictionary = m.recall_gift()
	var t: float = m.recall_t
	var fly: float = m.RECALL.fly
	var top := Vector2(480, 128)
	var f := smoothstep(fly, m.RECALL.gift - 0.15, t)          # 0 at the top -> 1 in the HUD
	var pop := smoothstep(0.0, 0.25, t)
	var c := top.lerp(_star_slot(1), f)
	var r := lerpf(24.0 * (1.0 + 0.35 * (1.0 - smoothstep(0.25, 0.6, t))) * pop, 5.0, f)
	var flash := 0.5 + 0.5 * cos(minf(t, fly) * TAU * 1.6)     # pulses while it hangs there
	if f < 1.0:
		var ring := smoothstep(0.0, 0.9, t)                      # one bright ring going out
		draw_arc(top, 20.0 + ring * 70.0, 0, TAU, 48, Color(1, 1, 1, 0.5 * (1.0 - ring)), 2.0, true)
		for k in 3:                                              # a soft glow behind it
			draw_circle(c, r * (1.6 + k * 0.5), Color(1, 1, 1, (0.05 + 0.07 * flash) * (1.0 - f) / (k + 1)))
	_star_icon(c, Color(1, 1, 1, lerpf(0.75 + 0.25 * flash, 0.75, f)), r, 0.4 + t * 1.2 * (1.0 - f))
	var la := smoothstep(0.35, 0.8, t) * (1.0 - smoothstep(fly - 0.4, fly, t))
	_text(g.name, Vector2(480, top.y + 52), m.font_regular, 15, Color(1, 1, 1, 0.85 * la), 8, true, 4)
	_text(_k(g["keys"], g.pad), Vector2(480, top.y + 74), m.font_italic, 12, Color(1, 1, 1, 0.55 * la), 1, true, 4)

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
	if m.state == "play" and m.alarm != "":         # the alarm's clock, top centre
		var label: String = "ALARM" if m.alarm == "alarm" else "LOCKDOWN"
		var on: bool = m.alarm == "lockdown" or fmod(m.time, 0.8) < 0.55
		_text(label + "   " + m.clock(maxf(m.alarm_left, 0.0) + 0.99), Vector2(480, 34), m.font_regular, 15, Color(1, 1, 1, 0.9 if on else 0.35), 4, true)
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
	# the stars, once he remembers them - hidden until the recall's flash has dropped them into place
	if m.can.has("stars") and not m.recall in ["in", "say", "gift"]:
		for i in m.star_max:
			_star_icon(_star_slot(i), Color(1, 1, 1, 0.75 if i < m.star_count else 0.15))
		var tx := _star_slot(m.star_max).x + 2
		if m.aiming:
			_text(_k("THROW MODE  ·  click to throw  ·  CTRL to cancel", "THROW  ·  right stick aims  ·  let go of RT  ·  B cancels"),
				Vector2(tx, y + 8), m.font_regular, 11, Color(1, 1, 1, 0.75), 2)
		elif m.can_throw():
			_text(_k("CTRL", "RT"), Vector2(tx, y + 8), m.font_regular, 10, Color(1, 1, 1, 0.3), 2)
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
	draw_string(m.font_regular, Vector2(960 - 24 - 500, 540 - 18), _k("Esc menu  ·  R restart  ·  M music  ·  F11 fullscreen  ·  G debug", "Start menu  ·  View restart  ·  Y music"),
		HORIZONTAL_ALIGNMENT_RIGHT, 500, 11, Color(1, 1, 1, 0.3))

const CONTROLS := [                                   # keyboard, controller (Xbox), what it does
	["A  D   /   ←  →", "stick  /  d-pad", "run  (loud)"],
	["hold  SHIFT", "hold  LT", "sneak  (silent)"],
	["SPACE  /  W  /  ↑", "A", "jump  ·  grab a duct  ·  land on a guard to put him to sleep"],
	["S  /  ↓", "B  /  ↓", "crawl  ·  hide behind furniture  ·  drop from a duct"],
	["CTRL", "hold  RT", "throw a star  -  aim, click / let go  (once you remember them)"],
	["hold  E", "hold  X", "grip a desk  -  move to push or pull it  (once you remember)"],
	["↓  +  hold  E", "↓  +  hold  X", "behind a desk: move it, hidden  -  a camera sees a desk move"],
	["LEFT CLICK  /  E  /  F", "X", "fight a watcher:  strike  -  3 quick for a special  (once you remember)"],
	["RIGHT CLICK  /  Q", "Y", "fight:  block his swing, as he winds up   ·   jump: hop back, or over him"],
	["ESC", "START", "pause menu"],
	["R    ·    F11", "VIEW", "restart    ·    fullscreen"],
	["M", "Y  (in a menu)", "music on / off"],
]

# The prompt for whichever device you last touched.
func _k(keys: String, pad: String) -> String:
	return pad if m.pad else keys
const ABOUT := [
	"You slipped into a high-security office tower. Now you have to get out.",
	"Light is the enemy. Lamps, moonlight and every guard's torch fill your detection meter;",
	"shadow drains it. Fill it and you're caught.",
	"Hide behind furniture, cling to ducts, let a guard hear you to pull him away,",
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
			_text(_k("R  try again    ·    ESC  menu", "A  try again    ·    START  menu"), Vector2(480, 345), m.font_regular, 13, Color(1, 1, 1, 0.5), 2, true)
	elif st == "escaped":
		draw_rect(Rect2(0, 0, 960, 540), Color(0, 0, 0, minf(0.8, t)))
		if t > 0.5:
			var last: bool = m.level_idx + 1 >= m.Levels.LEVELS.size()
			if last:
				_text("OUT", Vector2(480, 260), m.font_regular, 56, Color(1, 1, 1, 0.92), 16, true)
				_text("you made it out of the tower.", Vector2(480, 305), m.font_italic, 16, Color(1, 1, 1, 0.6), 0, true)
				_times(t)
				_text(_k("ENTER  menu    ·    R  replay this floor", "A  menu    ·    VIEW  replay this floor"), Vector2(480, 375), m.font_regular, 13, Color(1, 1, 1, 0.5), 2, true)
			else:
				_text(m.level.name + "  CLEARED", Vector2(480, 260), m.font_regular, 40, Color(1, 1, 1, 0.92), 12, true)
				# a memory with no ability in it shows here; one with an ability he says himself as the next
				# floor opens (the recall)
				var mem: Dictionary = m.level.get("remember", {})
				if mem.has("say") and mem.get("abilities", []).is_empty():
					_text(mem.say[0].replace("~", ""), Vector2(480, 290), m.font_italic, 16, Color(1, 1, 1, 0.75), 0, true)
					_text(mem.say[1].replace("~", ""), Vector2(480, 312), m.font_italic, 14, Color(1, 1, 1, 0.5), 0, true)
				else:
					_text("down the stairs, into the dark.", Vector2(480, 300), m.font_italic, 16, Color(1, 1, 1, 0.6), 0, true)
				_times(t)
				_text(_k("ENTER  next floor    ·    R  replay this floor    ·    ESC  menu", "A  next floor    ·    VIEW  replay this floor    ·    START  menu"), Vector2(480, 375), m.font_regular, 13, Color(1, 1, 1, 0.5), 2, true)

# The end screen's numbers: this run's time, the best, and whether the alarm went up.
func _times(t: float) -> void:
	var a := clampf((t - 0.8) / 0.5, 0.0, 1.0)
	var line: String = "time  " + m.clock(m.run_t)
	if m.new_best:
		line += "    ·    new best"
	elif m.best.has(m.level_idx):
		line += "    ·    best  " + m.clock(m.best[m.level_idx])
	_text(line, Vector2(480, 340), m.font_regular, 14, Color(1, 1, 1, 0.75 * a), 3, true)
	if m.alarm_raised:
		_text("alarm raised", Vector2(480, 357), m.font_italic, 13, Color(1, 1, 1, 0.5 * a), 0, true)

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
		_footer(_k("← →  choose    ·    ENTER  select    ·    ESC  back", "← →  choose    ·    A  select    ·    B  back"))
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
		_footer(_k("↑ ↓  choose    ·    ENTER  play    ·    ESC  back", "↑ ↓  choose    ·    A  play    ·    B  back"))
		return
	if m.menu_page == "about":
		_about()
		return
	if m.menu_page == "controls":
		_text("CONTROLS", Vector2(480, 120), m.font_regular, 30, Color(1, 1, 1, 0.9), 10, true)
		_table(200, true)
		_footer(_k("ESC  back", "B  back"))
		return
	if m.menu_page == "howto":                       # before the first New Game
		_text("HOW TO PLAY", Vector2(480, 105), m.font_regular, 30, Color(1, 1, 1, 0.9), 10, true)
		_text("stay in the dark. the light you see is the light that catches you.", Vector2(480, 140), m.font_italic, 16, Color(1, 1, 1, 0.65), 0, true)
		_table(200, true, 22.0)
		var a := 0.45 + 0.35 * sin(m.time * 3.0)
		_text(_k("press any key", "press any button"), Vector2(480, 470), m.font_regular, 14, Color(1, 1, 1, a), 4, true)
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
	_footer(_k("↑ ↓  choose    ·    ENTER  select" + ("    ·    ESC  resume" if paused else ""),
		"↑ ↓  choose    ·    A  select" + ("    ·    B  resume" if paused else "")))

func _about() -> void:
	_text("ABOUT", Vector2(480, 80), m.font_regular, 30, Color(1, 1, 1, 0.9), 10, true)
	for i in ABOUT.size():
		_text(ABOUT[i], Vector2(480, 125 + i * 22), m.font_italic, 15, Color(1, 1, 1, 0.75), 0, true)
	_text("CONTROLS", Vector2(480, 275), m.font_regular, 13, Color(1, 1, 1, 0.55), 6, true)
	_table(294, false, 15.0, 12)
	_text("a greyscale stealth prototype, after Limbo and Mark of the Ninja", Vector2(480, 482), m.font_italic, 12, Color(1, 1, 1, 0.4), 0, true)
	_footer(_k("ESC  back", "B  back"))

func _table(y0: float, heads := false, dy := 24.0, size := 14) -> void:     # keyboard | controller | what it does; your device is brighter
	var kb := 0.85 if not m.pad else 0.45
	var jp := 0.85 if m.pad else 0.45
	if heads:
		draw_string(m.font_regular, Vector2(40, y0 - 30), "KEYBOARD", HORIZONTAL_ALIGNMENT_RIGHT, 230, 10, Color(1, 1, 1, kb * 0.6))
		draw_string(m.font_regular, Vector2(290, y0 - 30), "CONTROLLER", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, jp * 0.6))
	for i in CONTROLS.size():
		var y := y0 + i * dy
		draw_string(m.font_regular, Vector2(40, y), CONTROLS[i][0], HORIZONTAL_ALIGNMENT_RIGHT, 230, size, Color(1, 1, 1, kb))
		draw_string(m.font_regular, Vector2(290, y), CONTROLS[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, jp))
		draw_string(m.font_italic, Vector2(420, y), CONTROLS[i][2], HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, 0.6))

func _footer(s: String) -> void:
	_text(s, Vector2(480, 515), m.font_regular, 11, Color(1, 1, 1, 0.35), 2, true)
