extends Node2D
## All world-space drawing for Shadow Ninja, ported from the HTML canvas code.
## `kind` picks what this node draws; `m` is main.gd (all game state lives there).

var m
var kind := ""

const T := 32

func _draw() -> void:
	match kind:
		"fog": _fog()
		"far": _far()
		"mid": _mid()
		"fg": _fg()
		"stage": _stage()
		"actors_back":
			if m.state != "title" and m.P.hidden:
				_ninja()
		"actors": _actors()
		"overlay": _overlay()
		"aim": _aim()

# ---------- helpers ----------
static func grey(v: int, a := 1.0) -> Color:
	return Color8(v, v, v, int(a * 255))

func _ellipse(c: Vector2, rx: float, ry: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	draw_colored_polygon(pts, col)

func _rrect(x: float, y: float, w: float, h: float, r: float, col: Color) -> void:
	draw_rect(Rect2(x + r, y, w - 2 * r, h), col)
	draw_rect(Rect2(x, y + r, w, h - 2 * r), col)
	for c in [Vector2(x + r, y + r), Vector2(x + w - r, y + r), Vector2(x + r, y + h - r), Vector2(x + w - r, y + h - r)]:
		draw_circle(c, r, col)

func _limb(a: Vector2, b: Vector2, w: float, col: Color) -> void:   # line with round caps
	draw_line(a, b, col, w, true)
	draw_circle(a, w / 2, col)
	draw_circle(b, w / 2, col)

func _text(font: Font, pos: Vector2, s: String, size: int, col: Color, center := false) -> void:
	if center:
		draw_string(font, pos - Vector2(400, 0), s, HORIZONTAL_ALIGNMENT_CENTER, 800, size, col)
	else:
		draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func layer_width(f: float) -> float:
	return ceilf(960 + (m.LW * T - 960) * f) + 60

func layer_height(f: float) -> float:              # tall floors: layers drift vertically at factor f
	return ceilf(540 + (m.LH * T - 540) * f) + 60

# =====================================================================
#  PARALLAX LAYERS - far city, mid office wall, foreground (drawn once)
# =====================================================================
func _fog() -> void:
	var c0 := grey(0xd4)
	var c1 := grey(0xb0)
	var c2 := grey(0x8c)
	draw_polygon(PackedVector2Array([Vector2(-60, -60), Vector2(1020, -60), Vector2(1020, 324), Vector2(-60, 324)]),
		PackedColorArray([c0, c0, c1, c1]))
	draw_polygon(PackedVector2Array([Vector2(-60, 324), Vector2(1020, 324), Vector2(1020, 600), Vector2(-60, 600)]),
		PackedColorArray([c1, c1, c2, c2]))

func _far() -> void:
	var w := layer_width(0.18)
	var hh := layer_height(0.2)
	var r := RandomNumberGenerator.new()
	r.seed = 11
	draw_circle(Vector2(w * 0.62, 120), 34, grey(0xec))
	var x := -20.0
	while x < w:
		var bw := 30 + r.randf() * 70
		var bh := 60 + r.randf() * 120
		draw_rect(Rect2(x, 470 - bh, bw, hh - 470 + bh), grey(0xbd))
		x += bw + r.randf() * 6
	x = -30.0
	while x < w:
		var bw := 40 + r.randf() * 90
		var bh := 120 + r.randf() * 250
		var top := 470 - bh
		draw_rect(Rect2(x, top, bw, hh - top), grey(0x9a))
		if r.randf() < 0.25:
			draw_rect(Rect2(x + bw / 2 - 1, top - 40, 2, 40), grey(0x9a))
		if r.randf() < 0.55:
			var wy := top + 10
			while wy < 460:
				var wx := x + 6
				while wx < x + bw - 6:
					if r.randf() < 0.18:
						draw_rect(Rect2(wx, wy, 4, 6), grey(0xc4))
					wx += 10
				wy += 14
		x += bw + 4 + r.randf() * 20

func _mid() -> void:
	var w := layer_width(0.5)
	var hh := layer_height(0.5)
	var r := RandomNumberGenerator.new()
	r.seed = 23
	var x := 0.0
	while x < w:                                    # glass-wall mullions
		draw_rect(Rect2(x, 0, 7, hh), grey(0x4c))
		x += 150
	var ty := 90.0
	while ty < hh:                                  # transoms, every storey
		draw_rect(Rect2(0, ty, w, 5), grey(0x4c))
		ty += 350
	x = 260.0
	while x < w:                                    # structural columns
		draw_rect(Rect2(x, 0, 44, hh), grey(0x40))
		x += 560 + r.randf() * 120
	x = 80.0
	var col := grey(0x45)
	while x < w:
		var k := r.randf()
		if k < 0.4:                                 # shelving unit
			var sw := 60 + r.randf() * 50
			var sh := 120 + r.randf() * 70
			draw_rect(Rect2(x, 480 - sh, sw, sh), col)
			var y := 480 - sh + 30
			while y < 480:
				draw_rect(Rect2(x + 3, y, sw - 6, 3), grey(0x38))
				y += 34
		elif k < 0.7:                               # pendant light (unlit)
			var ln := 60 + r.randf() * 80
			draw_line(Vector2(x, 60), Vector2(x, 60 + ln), col, 2)
			draw_colored_polygon(PackedVector2Array([Vector2(x - 4, 60 + ln), Vector2(x + 4, 60 + ln),
				Vector2(x + 12, 72 + ln), Vector2(x - 12, 72 + ln)]), col)
		else:                                       # tall plant
			draw_rect(Rect2(x - 9, 455, 18, 25), col)
			for i in 7:
				var a := -1.1 + i * 0.37
				var ln := 40 + r.randf() * 50
				_ellipse(Vector2(x + sin(a) * ln / 2, 455 - cos(a) * ln / 2), 5, ln / 2, a, col)
		x += 180 + r.randf() * 260

func _fg() -> void:
	var w := layer_width(1.35)
	var r := RandomNumberGenerator.new()
	r.seed = 5
	var col := Color(0, 0, 0, 0.95)
	var x := 700.0
	while x < w:
		if r.randf() < 0.5:                         # cables sagging from the ceiling
			var n := 2 + int(r.randf() * 2)
			for k in n:
				var x0 := x + r.randf() * 60
				var x1 := x0 + 120 + r.randf() * 200
				var sag := 50 + r.randf() * 70
				var lw := 4 + r.randf() * 5
				var pts := PackedVector2Array()
				for i in 17:
					var t := i / 16.0
					var a := Vector2(x0, -10).lerp(Vector2((x0 + x1) / 2, sag * 2), t)
					var b := Vector2((x0 + x1) / 2, sag * 2).lerp(Vector2(x1, -10), t)
					pts.append(a.lerp(b, t))
				draw_polyline(pts, col, lw, true)
		else:                                       # big leaves rising from below
			for k in 6:
				var a := -0.9 + r.randf() * 1.8
				var ln := 70 + r.randf() * 80
				_ellipse(Vector2(x + sin(a) * ln / 2, 560 - cos(a) * ln / 2), 14 + r.randf() * 10, ln / 2, a, col)
		x += 900 + r.randf() * 700

# =====================================================================
#  STAGE - tiles, ducts, door, furniture, lamp shades (drawn once, lit by the lights)
# =====================================================================
func _stage() -> void:
	var tile := grey(0x0a)
	for j in m.LH:
		for i in m.LW:
			if m.grid[j * m.LW + i] != 0:
				draw_rect(Rect2(i * T, j * T, T + 0.5, T + 0.5), tile)
	# ducts: hanger rods up to the ceiling and grille seams
	for j in m.LH:
		for i in m.LW:
			if m.grid[j * m.LW + i] == m.GRIP:
				if i % 3 == 0:                      # hanger rod up to whatever is above
					var top: int = j - 1
					while top > 0 and m.grid[top * m.LW + i] == 0:
						top -= 1
					draw_rect(Rect2(i * T + 14, (top + 1) * T, 3, (j - top - 1) * T), tile)
				var k := 4
				while k < T:
					draw_rect(Rect2(i * T + k, j * T + 6, 2, T - 12), grey(0x26))
					k += 8
	# exit door
	var ey: float = (m.exit_row - 3) * T
	draw_rect(Rect2(m.door_x * T + 4, ey + 4, 2 * T - 8, 3 * T - 4), grey(0x2a))
	draw_rect(Rect2(m.door_x * T + 46, ey + 50, 6, 3), tile)
	for d in m.doors:                               # security doors: banded steel while locked, an empty frame once open
		var r := Rect2(d.x * T, d.y * T, d.w * T, d.h * T)
		if not d.open:
			draw_rect(r, grey(0x1e))
			var by := r.position.y + 10
			while by < r.end.y - 6:
				draw_rect(Rect2(r.position.x + 3, by, r.size.x - 6, 3), grey(0x14))
				by += 16
		else:
			draw_rect(Rect2(r.position.x, r.position.y, 4, r.size.y), tile)
			draw_rect(Rect2(r.end.x - 4, r.position.y, 4, r.size.y), tile)
	for p in m.props:
		_prop(p)
	for L in m.lights:                              # lamp shades
		if L.kind == "lamp":
			draw_colored_polygon(PackedVector2Array([Vector2(L.pos.x - 5, L.pos.y - 4), Vector2(L.pos.x + 5, L.pos.y - 4),
				Vector2(L.pos.x + 15, L.pos.y + 7), Vector2(L.pos.x - 15, L.pos.y + 7)]), tile)

func _prop(p: Dictionary) -> void:
	var x: float = p.x * T
	var y: float = p.y
	var c := grey(0x15)
	match p.type:
		"desk":
			draw_rect(Rect2(x, y - 28, 70, 6), c)
			draw_rect(Rect2(x + 4, y - 22, 4, 22), c)
			draw_rect(Rect2(x + 62, y - 22, 4, 22), c)
			draw_rect(Rect2(x + 40, y - 22, 22, 16), c)
			draw_rect(Rect2(x + 14, y - 46, 24, 16), c)
			draw_rect(Rect2(x + 24, y - 30, 4, 2), c)
		"plant":
			draw_colored_polygon(PackedVector2Array([Vector2(x + 4, y - 18), Vector2(x + 22, y - 18), Vector2(x + 19, y), Vector2(x + 7, y)]), c)
			for k in 7:
				var a := -1.2 + k * 0.4
				var ln := 18.0 + (k * 7 % 11)
				_ellipse(Vector2(x + 13 + sin(a) * ln / 2, y - 18 - cos(a) * ln / 2), 3.5, ln / 2, a, c)
		"cooler":
			draw_rect(Rect2(x + 2, y - 40, 22, 40), c)
			draw_rect(Rect2(x + 10, y - 44, 6, 4), c)
			_ellipse(Vector2(x + 13, y - 56), 10, 13, 0, c)
		"rack":                                     # server rack: tall, slotted
			draw_rect(Rect2(x, y - 92, 40, 92), c)
			var sy := y - 84
			while sy < y - 6:
				draw_rect(Rect2(x + 4, sy, 32, 2), grey(0x22))
				sy += 12
		"chair":
			draw_rect(Rect2(x, y - 20, 22, 4), c)
			draw_rect(Rect2(x + 18, y - 40, 4, 22), c)
			draw_rect(Rect2(x + 9, y - 16, 3, 12), c)
			draw_rect(Rect2(x + 1, y - 4, 20, 3), c)

# =====================================================================
#  ACTORS - guards and the ninja (lit by the lights)
# =====================================================================
func _actors() -> void:
	for sw in m.switches:                           # levers: a plate on the wall, the handle swings down when pulled
		var piv := Vector2(sw.x * T, sw.row * T - 35)
		draw_rect(Rect2(piv.x - 6, piv.y - 12, 12, 24), grey(0x1a))
		_limb(piv, m.lever_knob(sw), 3.0, grey(0x10))
		draw_circle(m.lever_knob(sw), 3.5, grey(0x10))
	for L in m.lights:                              # security cameras: housing on the ceiling, lens follows the sweep
		if L.kind == "camera":
			draw_rect(Rect2(L.pos.x - 3, 2 * T, 6, 4), grey(0x12))
			draw_set_transform(L.pos, L.dir)
			draw_rect(Rect2(-8, -6, 20, 12), grey(0x12))
			draw_rect(Rect2(12, -4, 5, 8), grey(0x12))
			draw_set_transform_matrix(Transform2D.IDENTITY)
	for g in m.guards:
		_guard(g)
	if m.state != "title" and not m.P.hidden:
		_ninja()

func _guard(g) -> void:
	var c := grey(0x12)
	var f: float = g.facing
	var x: float = g.x
	var by: float = g.y
	if g.state == "asleep":                         # flat out, torch dark
		_rrect(x - 24, by - 13, 34, 13, 5, c)
		draw_circle(Vector2(x + 17, by - 8), 8, c)
		_limb(Vector2(x - 22, by - 6), Vector2(x - 42, by - 3), 5, c)
		draw_rect(Rect2(x + 30, by - 5, 18, 5), c)   # cap, fallen off
		draw_rect(Rect2(x - 6, by - 6, 14, 6), c)    # torch, off
		return
	var sw: float = sin(g.phase) * clampf(g.cur_v / 50.0, 0.0, 1.0)      # stride grows with speed
	_limb(Vector2(x, by - 20), Vector2(x + sw * 9, by - 1), 5, c)
	_limb(Vector2(x, by - 20), Vector2(x - sw * 9, by - 1), 5, c)
	_rrect(x - 9, by - 46, 18, 28, 5, c)                    # torso
	draw_circle(Vector2(x + f, by - 53), 8, c)              # head
	draw_rect(Rect2(x - 9 + f * 2, by - 62, 18, 5), c)      # cap
	draw_rect(Rect2(x + 6 if f > 0 else x - 16, by - 59, 10, 2.5), c)   # brim
	var L = g.torch
	_limb(Vector2(x + f * 3, by - 41), L.pos, 4.5, c)       # arm
	draw_set_transform(L.pos, L.dir)
	draw_rect(Rect2(-10, -3.5, 12, 7), c)                   # torch
	draw_set_transform_matrix(Transform2D.IDENTITY)

static func lean_tr(cx: float, by: float, lean: float) -> Transform2D:
	return Transform2D(lean, Vector2(cx, by)) * Transform2D(0.0, Vector2(-cx, -by))

func _ninja() -> void:
	var P = m.P
	var g := lerpf(6, 215, P.vis) / 255.0
	var col := Color(g, g, g)
	var f: float = P.facing
	# stride grows with speed, so a slow first step is a small step
	var sw: float = sin(P.walk_phase) * clampf(absf(P.vx) / (50.0 if (P.crawling or P.clinging) else 120.0), 0.0, 1.0)
	draw_polyline(m.scarf_pos, col, 3.0, true)
	var cx: float = P.x + P.w / 2
	var by: float = P.y + P.h
	if P.crawling or P.clinging:
		if P.clinging:                              # crawl pose, upside down
			draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(0, -1), Vector2(0, 2 * P.y + P.h)))
		_limb(Vector2(cx - f * 7, by - 6), Vector2(cx - f * (13 - sw * 3), by - 1), 3.5, col)
		_limb(Vector2(cx - f * 3, by - 6), Vector2(cx - f * (6 + sw * 3), by - 1), 3.5, col)
		_limb(Vector2(cx + f * 7, by - 7), Vector2(cx + f * (11 + sw * 3), by - 1), 3.5, col)
		_ellipse(Vector2(cx, by - 8), 12, 5.5, 0, col)
		draw_circle(Vector2(cx + f * 13, by - 10), 6.5, col)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	draw_set_transform_matrix(lean_tr(cx, by, P.lean))
	if m.at_lever():                                # pulling a lever: one hand on the knob
		var knob: Vector2 = m.lever_knob(m.switches[P.flip_sw])
		_limb(Vector2(cx, by - 15), Vector2(cx + 3, by - 1), 4, col)
		_limb(Vector2(cx, by - 15), Vector2(cx - 4, by - 1), 4, col)
		_limb(Vector2(cx, by - 28), Vector2(cx - f * 4, by - 17), 4, col)
		_limb(Vector2(cx, by - 28), knob, 4, col)
	elif P.on_ground:
		_limb(Vector2(cx, by - 15), Vector2(cx + sw * 8, by - 1), 4, col)
		_limb(Vector2(cx, by - 15), Vector2(cx - sw * 8, by - 1), 4, col)
		_limb(Vector2(cx, by - 28), Vector2(cx - sw * 7, by - 17), 4, col)
		_limb(Vector2(cx, by - 28), Vector2(cx + sw * 7, by - 17), 4, col)
	else:
		_limb(Vector2(cx, by - 15), Vector2(cx + f * 6, by - 6), 4, col)
		_limb(Vector2(cx, by - 15), Vector2(cx - f * 3, by - 3), 4, col)
		_limb(Vector2(cx, by - 28), Vector2(cx + f * 9, by - 36), 4, col)
		_limb(Vector2(cx, by - 28), Vector2(cx - f * 7, by - 34), 4, col)
	_rrect(cx - 6.5, by - 32, 13, 19, 5, col)
	draw_circle(Vector2(cx + f * 1.5, by - 38), 7.5, col)
	draw_set_transform_matrix(Transform2D.IDENTITY)

# =====================================================================
#  OVERLAY - drawn after lighting (bulbs, exit sign, hints, eyes, noise, stones, marks)
# =====================================================================
func _overlay() -> void:
	for L in m.lights:                              # bulb glow
		if L.kind == "lamp" and L.level > 0:
			for k in 6:
				draw_circle(L.pos + Vector2(0, 7), 26.0 * (1.0 - k / 6.0), Color(1, 1, 1, 0.12 * L.level))
	for L in m.lights:                              # camera status light: blinks while watching, solid when it sees you
		if L.kind == "camera" and (L.seeing or fmod(m.time, 1.0) < 0.5):
			var led: Vector2 = L.pos + Vector2.from_angle(L.dir) * 2.0
			draw_circle(led, 5.0 if L.seeing else 3.0, Color(1, 1, 1, 0.25))
			draw_circle(led, 2.0, Color(1, 1, 1, 0.95 if L.seeing else 0.6))
	for sw in m.switches:                           # lever light: blinks while armed; flares when pulled, then stays on
		var lp := Vector2(sw.x * T, sw.row * T - 52)
		if sw.on:
			var flare := exp(-(m.time - sw.on_t) * 2.5)
			draw_circle(lp, 5.0 + 26.0 * flare, Color(1, 1, 1, 0.22 + 0.4 * flare))
			draw_circle(lp, 2.5, Color(1, 1, 1, 0.95))
		elif fmod(m.time, 1.2) < 0.6:
			draw_circle(lp, 5.0, Color(1, 1, 1, 0.2))
			draw_circle(lp, 2.0, Color(1, 1, 1, 0.7))
	for d in m.doors:                               # lock light: blinks while locked, dark once open
		if not d.open and fmod(m.time, 1.2) < 0.6:
			var lp := Vector2(d.x * T + d.w * T / 2.0, d.y * T - 8)
			draw_circle(lp, 5.0, Color(1, 1, 1, 0.2))
			draw_circle(lp, 2.0, Color(1, 1, 1, 0.85))
	for p in m.props:                               # server racks: little status lights
		if p.type == "rack":
			for k in 6:
				var on := fmod(m.time * (0.7 + k * 0.23) + p.x * 1.7 + k * 0.37, 1.0) < 0.55
				if on:
					draw_circle(Vector2(p.x * T + 8 + (k % 3) * 11, p.y - 78 + (k / 3) * 36), 1.3, Color(1, 1, 1, 0.55))
	var sign = null                                 # exit sign
	for L in m.lights:
		if L.kind == "sign":
			sign = L
	draw_rect(Rect2(sign.pos.x - 18, sign.pos.y - 7, 36, 14), Color(0.92, 0.92, 0.92, 0.9))
	_text(m.font_bold, sign.pos + Vector2(0, 5), "EXIT", 10, Color.BLACK, true)
	for h in m.hints:
		_text(m.font_italic, Vector2(h[0] * T, h[1]), h[2], 14, Color(1, 1, 1, 0.3))
	var P = m.P
	if m.state != "title":
		if P.cover >= 0 and not P.hidden:           # nudge: you could hide here
			var p: Dictionary = m.props[P.cover]
			_text(m.font_regular, Vector2(p.x * T + m.PROP_W[p.type] / 2, p.y - 66), "↓", 13, Color(1, 1, 1, 0.45), true)
		_eyes()
	_noise_and_stones()
	_guard_marks()
	if m.debug:
		_debug()

func _eyes() -> void:
	if fmod(m.time, 4.3) < 0.12:                    # blink
		return
	var P = m.P
	var f: float = P.facing
	var cx: float = P.x + P.w / 2
	var by: float = P.y + P.h
	var h: Vector2
	if P.clinging:
		h = Vector2(cx + f * 13, P.y + 10)
	elif P.crawling:
		h = Vector2(cx + f * 13, by - 10)
	else:
		draw_set_transform_matrix(lean_tr(cx, by, P.lean))
		h = Vector2(cx + f * 1.5, by - 38)
	for e in [[Vector2(f * 2.5, -1.5), 1.7], [Vector2(f * 5.8, -1.8), 1.5]]:
		draw_circle(h + e[0], e[1] + 2.5, Color(1, 1, 1, 0.25))
		draw_circle(h + e[0], e[1], Color.WHITE)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _noise_and_stones() -> void:
	for n in m.noises:                              # a bubble that spreads to the noise's reach, cut off by walls
		var k: float = n.t / 0.6
		var rr: float = maxf(1.0, n.r * minf(1.0, k * 1.6))
		var circle := PackedVector2Array()
		for i in 40:
			circle.append(Vector2(n.x, n.y) + Vector2.from_angle(TAU * i / 40.0) * rr)
		for part in Geometry2D.intersect_polygons(n.poly, circle):
			draw_colored_polygon(part, Color(1, 1, 1, 0.08 * (1 - k)))
			var outline: PackedVector2Array = part.duplicate()
			outline.append(part[0])
			draw_polyline(outline, Color(1, 1, 1, 0.3 * (1 - k)), 1.5, true)
	for s in m.stones:
		draw_circle(Vector2(s.x, s.y), m.STONE.r, grey(0xb4))

func _guard_marks() -> void:
	for g in m.guards:
		if g.state == "asleep":
			for k in 3:
				var p := fmod(m.time * 0.5 + k / 3.0, 1.0)
				_text(m.font_italic, Vector2(g.x + 18 + p * 14, g.y - 22 - p * 30), "z", 13, Color(1, 1, 1, 0.5 * (1 - p)))
			continue
		var mk := ""
		if g.state == "chase":
			mk = "!"
		elif g.state == "search" or g.state == "investigate":
			mk = "?"
		if mk != "":
			_text(m.font_bold, Vector2(g.x, g.y - 72), mk + mk if g.alert else mk, 20, Color(1, 1, 1, 0.85), true)

func _debug() -> void:
	for k in m.seg_a.size():
		draw_line(m.seg_a[k], m.seg_b[k], Color(1, 1, 1, 0.25), 1)
	if m.state != "title":
		for p in m.sample_points():
			var lit := false
			for L in m.all_lights():
				if m.light_at(L, p) > 0:
					lit = true
			draw_circle(p, 3, Color.WHITE if lit else Color.BLACK)
	_text(m.font_regular, Vector2(m.cam.x + 28, m.cam.y + 522), "fps %d  exposure %.2f  meter %.2f" % [m.fps, m.exposure, m.meter], 11, Color(1, 1, 1, 0.7))

# =====================================================================
#  AIM - the stone's arc and the cursor (on top of everything)
# =====================================================================
func _aim() -> void:
	if m.state != "play" or not m.aiming:          # only in throw mode (Ctrl)
		return
	var a: Dictionary = m.aim_throw()
	var can: bool = m.stone_count > 0
	if can:
		var path: Dictionary = m.predict_path(a)
		for p in path.pts:
			draw_circle(p, 1.6, Color(1, 1, 1, 0.55))
		draw_arc(path.end, 6, 0, TAU, 24, Color(1, 1, 1, 0.7), 1.5, true)
	var t: Vector2 = a.tgt
	var ok: bool = a.in_range and can
	var col := Color(1, 1, 1, 0.9 if ok else 0.45)
	draw_arc(t, 8, 0, TAU, 28, col, 1.5, true)
	if ok:
		draw_circle(t, 1.8, col)
	else:
		draw_line(t + Vector2(-6, -6), t + Vector2(6, 6), col, 1.5, true)
		draw_line(t + Vector2(6, -6), t + Vector2(-6, 6), col, 1.5, true)
		_text(m.font_italic, t + Vector2(0, 24), "too far" if can else "no stones", 11, col, true)
