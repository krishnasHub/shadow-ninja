extends Node2D
## All world-space drawing for Shadow Ninja, ported from the HTML canvas code.
## `kind` picks what this node draws; `m` is main.gd (all game state lives there).

var m
var kind := ""

const T := 32
const Fight := preload("res://scripts/fight.gd")

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

# Two segments of length seg from a to b, the joint bent out toward `toward` (a knee, an elbow).
func _joint(a: Vector2, b: Vector2, seg: float, toward: Vector2, w: float, col: Color) -> void:
	var d := b - a
	var half := minf(d.length() / 2.0, seg * 0.999)
	var n := Vector2(-d.y, d.x).normalized()
	if n.dot(toward) < 0.0:
		n = -n
	var j := a + d.normalized() * half + n * sqrt(seg * seg - half * half)
	_limb(a, j, w, col)
	_limb(j, b, w, col)

# A leg, the knee toward facing f. The knee rule: standing (bend 0) the segments are exactly half the
# hip-to-floor length L, so the leg is straight; moving, they grow and the knee comes forward.
func _leg(hip: Vector2, foot: Vector2, L: float, bend: float, f: float, w: float, col: Color) -> void:
	_joint(hip, foot, L * (0.5 + 0.1 * bend), Vector2(f, 0), w, col)

# A walking leg: swing s (-1..1) across the stride, the foot lifted while it swings forward.
func _step(hip: Vector2, by: float, s: float, lift: float, stride: float, L: float, bend: float, f: float, w: float, col: Color) -> void:
	_leg(hip, Vector2(hip.x + s * stride, by - 1 - lift), L, bend, f, w, col)

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
	for L in m.lights:                              # lamp shades (a broken one hangs crooked)
		if L.kind == "lamp":
			var sh := PackedVector2Array([Vector2(-5, -4), Vector2(5, -4), Vector2(15, 7), Vector2(-15, 7)])
			var tr := Transform2D(0.35 if L.broken else 0.0, L.pos)
			draw_colored_polygon(tr * sh, tile)

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
		"machine":                                  # the vial machine: a tall cabinet, its door swung open, one vial gone
			draw_rect(Rect2(x - 2, y - 24, 56, 24), c)
			draw_rect(Rect2(x, y - 116, 52, 94), c)
			draw_rect(Rect2(x + 5, y - 110, 42, 82), grey(0x0b))
			for sh in 3:
				var sy := y - 106 + sh * 27
				draw_rect(Rect2(x + 5, sy + 21, 42, 3), c)
				for v in 5:
					if sh == 1 and v == 2:
						continue                    # the empty slot
					draw_rect(Rect2(x + 9 + v * 8, sy + 5, 4, 16), grey(0x26))
					draw_rect(Rect2(x + 9 + v * 8, sy + 3, 4, 3), grey(0x1a))
			draw_colored_polygon(PackedVector2Array([Vector2(x + 52, y - 114), Vector2(x + 68, y - 106),
				Vector2(x + 68, y - 34), Vector2(x + 52, y - 26)]), grey(0x19))
			draw_rect(Rect2(x + 34, y - 18, 12, 8), grey(0x22))
		"chair":
			draw_rect(Rect2(x, y - 20, 22, 4), c)
			draw_rect(Rect2(x + 18, y - 40, 4, 22), c)
			draw_rect(Rect2(x + 9, y - 16, 3, 12), c)
			draw_rect(Rect2(x + 1, y - 4, 20, 3), c)

# =====================================================================
#  ACTORS - guards and the ninja (lit by the lights)
# =====================================================================
func _actors() -> void:
	for pn in m.panels:                             # alarm panels: a box on the wall; cracked open once a star goes through
		var c := Vector2(pn.x * T, pn.row * T - 48)
		draw_rect(Rect2(c.x - 8, c.y - 10, 16, 20), grey(0x1c))
		draw_rect(Rect2(c.x - 5, c.y - 3, 10, 9), grey(0x12))
		if pn.broken:
			draw_line(c + Vector2(-6, -8), c + Vector2(2, 1), grey(0x40), 1.0)
			draw_line(c + Vector2(2, 1), c + Vector2(-1, 8), grey(0x40), 1.0)
	for sw in m.switches:                           # levers: a plate on the wall, the handle swings down when pulled
		var piv := Vector2(sw.x * T, sw.row * T - 35)
		draw_rect(Rect2(piv.x - 6, piv.y - 12, 12, 24), grey(0x1a))
		_limb(piv, m.lever_knob(sw), 3.0, grey(0x10))
		draw_circle(m.lever_knob(sw), 3.5, grey(0x10))
	for st in m.stars:                              # a star stuck in a wall (or lying where it fell)
		if st.state == "stuck":
			_star(Vector2(st.x, st.y), st.ang, 4.5, grey(0x30))
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

# A throwing star: four points.
func _star(p: Vector2, ang: float, r: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		pts.append(p + Vector2.from_angle(ang + i * TAU / 8.0) * (r if i % 2 == 0 else r * 0.32))
	draw_colored_polygon(pts, c)

func _guard(g) -> void:
	if g.kind == "watcher":
		_watcher(g)
		return
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
	var amp := clampf(g.cur_v / 50.0, 0.0, 1.0)                          # stride grows with speed
	var bend := clampf(g.cur_v / 115.0, 0.0, 1.0)                        # and the knee with it; standing, straight
	var hip := Vector2(x, by - 20)
	var up: float = cos(g.phase) * f * amp * (3.0 + 4.0 * bend)           # the forward-swinging foot lifts
	var stride := 9.0 * (1.0 + 0.3 * clampf((g.cur_v - 55.0) / 60.0, 0.0, 1.0))
	_step(hip, by, sin(g.phase) * amp, maxf(up, 0.0), stride, 19, bend, f, 5, c)
	_step(hip, by, -sin(g.phase) * amp, maxf(-up, 0.0), stride, 19, bend, f, 5, c)
	var cut: bool = g.state == "intro_talk"                 # a cutscene: the free arm, elbows, the speaking nod
	if cut:
		_talk_arm(g, x, by, f, c)
	_rrect(x - 9, by - 46, 18, 28, 5, c)                    # torso
	var ny: float = g.nod - (g.gest_k if g.gest == "shrug" else 0.0)
	draw_circle(Vector2(x + f, by - 53 + ny), 8, c)         # head
	draw_rect(Rect2(x - 9 + f * 2, by - 62 + ny, 18, 5), c) # cap
	draw_rect(Rect2(x + 6 if f > 0 else x - 16, by - 59 + ny, 10, 2.5), c)   # brim
	var L = g.torch
	if cut:                                                 # the torch arm, bent at the elbow
		_joint(Vector2(x + f * 3, by - 41), L.pos, 7.5, Vector2(-f * 0.3, 1), 4.5, c)
	else:
		_limb(Vector2(x + f * 3, by - 41), L.pos, 4.5, c)   # arm
	draw_set_transform(L.pos, L.dir)
	draw_rect(Rect2(-10, -3.5, 12, 7), c)                   # torch
	draw_set_transform_matrix(Transform2D.IDENTITY)

# The watcher: a guard without the cap or the torch - a bare head, an earpiece, both hands free (fists up
# in a fight). His colour is his health: near black, fading to a dull grey as he's worn down.
func _watcher(g) -> void:
	var c := grey(int(lerpf(0x58, 0x12, clampf(g.hp, 0.0, 1.0))))
	var f: float = g.facing
	var x: float = g.x
	var by: float = g.y
	if g.state == "fight" or g.state == "asleep":
		var p: Dictionary = g.fpose if g.state == "fight" and not g.fpose.is_empty() else Fight.pose(Fight.GP, "out")
		var fall: float = g.fall if g.state == "fight" else 1.0
		if fall > 0.0:                              # over backwards from his feet, flat on his back
			draw_set_transform_matrix(Transform2D(-f * fall * PI / 2, Vector2(x, by - fall * 9)) * Transform2D(0.0, Vector2(-x, -by)))
		var R := Fight.rig(x, by, f, p, Fight.GB)
		_rig(R, Fight.GB, c)
		draw_polyline(PackedVector2Array([R.ear, R.ear.lerp(R.collar, 0.5) + Vector2(-R.fe * 3, 0), R.collar]), c, 1.0, true)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	var amp := clampf(g.cur_v / 50.0, 0.0, 1.0)            # his rounds: the guard's walk
	var bend := clampf(g.cur_v / 115.0, 0.0, 1.0)
	var hip := Vector2(x, by - 20)
	var up: float = cos(g.phase) * f * amp * (3.0 + 4.0 * bend)
	var stride := 9.0 * (1.0 + 0.3 * clampf((g.cur_v - 55.0) / 60.0, 0.0, 1.0))
	var sw: float = sin(g.phase) * amp
	_step(hip, by, sw, maxf(up, 0.0), stride, 19, bend, f, 5, c)
	_step(hip, by, -sw, maxf(-up, 0.0), stride, 19, bend, f, 5, c)
	_joint(Vector2(x - f * 2, by - 42), Vector2(x - f * 2 - sw * 7, by - 23), 10.0, Vector2(-f * 0.3, 1), 4.5, c)   # far arm
	_rrect(x - 9, by - 46, 18, 28, 5, c)
	draw_circle(Vector2(x + f, by - 53), 8, c)                                   # bare head
	draw_polyline(PackedVector2Array([Vector2(x - f * 2, by - 53), Vector2(x - f * 7, by - 50), Vector2(x - f * 4, by - 46)]), c, 1.0, true)   # earpiece
	_joint(Vector2(x + f * 3, by - 41), Vector2(x + f * 3 + sw * 7, by - 23), 10.0, Vector2(f * 0.3, 1), 4.5, c)    # near arm

# A fighter from fight.gd's rig: legs (knees toward his facing), the far arm, the torso, the head, the near arm.
func _rig(R: Dictionary, B: Dictionary, c: Color) -> void:
	_joint(R.hip, R.fB, B.leg, Vector2(R.fe, 0), B.legW, c)
	_joint(R.hip, R.fA, B.leg, Vector2(R.fe, 0), B.legW, c)
	_joint(R.sh, R.hB, B.arm, Vector2(0, 1), B.armW, c)          # elbows hang below
	_limb(R.ta, R.tb, B.tw, c)
	draw_circle(R.head, B.hr, c)
	_joint(R.sh, R.hA, B.arm, Vector2(0, 1), B.armW, c)

# The talk: his free arm (the far one, behind the torso). Hangs at his side; while he speaks it
# points (at gest_x), shrugs, or moves with the words ("beat"), blended in by gest_k.
func _talk_arm(g, x: float, by: float, f: float, c: Color) -> void:
	var sh := Vector2(x - f * 2, by - 42)
	var elbow := Vector2(x - f * 2.5, by - 32.5)
	var hand := Vector2(x - f * 1, by - 23)
	var e2 := elbow
	var h2 := hand
	match g.gest:
		"point":                                    # straight out toward gest_x, a touch above level
			var d: float = signf(g.gest_x - x) if g.gest_x != x else -f
			e2 = sh + Vector2(d * 9, -1)
			h2 = sh + Vector2(d * 19, -3)
		"shrug":                                    # forearm up, palm out
			e2 = Vector2(x - f * 8, by - 33)
			h2 = Vector2(x - f * 12, by - 42)
		"beat":                                     # talking hands: in front of the chest, moving with the words
			e2 = Vector2(x + f * 1, by - 31)
			h2 = Vector2(x + f * 9, by - 36 + sin(m.talk_t * 9.0) * 2.0)
	elbow = elbow.lerp(e2, g.gest_k)
	hand = hand.lerp(h2, g.gest_k)
	_limb(sh, elbow, 4.5, c)
	_limb(elbow, hand, 4.5, c)

# Remembered (Floor 3 on), the scarf has colour - but only in the dark. The colour sits at the tail and
# climbs toward his neck floor by floor (m.scarf_reach), deepening from maroon to a full dark red. As light
# finds him it fades out: lit, he's the grey he always was.
const MAROON := Color(0.15, 0.018, 0.03)
const DEEP_RED := Color(0.25, 0.018, 0.024)

func _scarf(P, col: Color) -> void:
	var pts: PackedVector2Array = m.scarf_pos
	if not m.scarf_red:
		draw_polyline(pts, col, 3.0, true)
		return
	var shade := 1.0 - smoothstep(0.0, 0.5, P.vis)  # colour only in shadow: gone by half-lit
	var r: float = m.scarf_reach
	var hue := MAROON.lerp(DEEP_RED, r)
	var cols := PackedColorArray()
	for i in pts.size():
		var t := float(i) / (pts.size() - 1)          # 0 at the neck, 1 at the tip
		var u := smoothstep(1.0 - r - 0.35, 1.0 - r + 0.05, t)
		cols.append(col.lerp(col.lerp(hue, u), shade))
	draw_polyline_colors(pts, cols, 3.0, true)

static func lean_tr(cx: float, by: float, lean: float) -> Transform2D:
	return Transform2D(lean, Vector2(cx, by)) * Transform2D(0.0, Vector2(-cx, -by))

# The ninja's upper body: in the anime run it pitches from the hip; otherwise the small lean from the feet.
static func body_tr(mm) -> Transform2D:
	var P = mm.P
	var cx: float = P.x + P.w / 2
	var by: float = P.y + P.h
	if mm.dashing():
		return lean_tr(cx, by - 15, P.lean)
	if mm.gripping():                               # into or back from a desk: the full lean, from the feet
		return lean_tr(cx, by, P.lean)
	return lean_tr(cx, by, clampf(P.lean, -0.2, 0.2))

func _ninja() -> void:
	var P = m.P
	var g := lerpf(6, 215, P.vis) / 255.0
	var col := Color(g, g, g)
	var f: float = P.facing
	# stride grows with speed, so a slow first step is a small step
	var sw: float = sin(P.walk_phase) * clampf(absf(P.vx) / (50.0 if (P.crawling or P.clinging) else 120.0), 0.0, 1.0)
	_scarf(P, col)
	var cx: float = P.x + P.w / 2
	var by: float = P.y + P.h
	if m.fight != null and not m.npose.is_empty():        # squared up: the fight's poses (fight.gd)
		_rig(Fight.rig(cx, by, f, m.npose, Fight.NB), Fight.NB, col)
		return
	if m.gripping_low():
		_low_pose(P, cx, by, f, col)
		return
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
	var hip := Vector2(cx, by - 15)
	if m.gripping():
		_grip_pose(P, cx, by, f, col)
		return
	if m.dashing():                                 # the anime run: legs under him, body pitched from the hip, arms streaming back
		var s := sin(P.walk_phase)
		var u := cos(P.walk_phase) * f
		_leg(hip, Vector2(cx + s * 12, by - 1 - maxf(u, 0.0) * 8 - maxf(-u, 0.0) * 3), 14, 1, f, 4, col)
		_leg(hip, Vector2(cx - s * 12, by - 1 - maxf(-u, 0.0) * 8 - maxf(u, 0.0) * 3), 14, 1, f, 4, col)
		draw_set_transform_matrix(body_tr(m))
		var wob := sin(P.walk_phase * 2) * 1.2
		_limb(Vector2(cx, by - 28), Vector2(cx - f * 15, by - 24 + wob), 4, col)
		_limb(Vector2(cx, by - 27), Vector2(cx - f * 14, by - 20 - wob), 4, col)
		_rrect(cx - 6.5, by - 32, 13, 19, 5, col)
		_mark(cx + f * 2, by - 25, col, P.vis)
		draw_circle(Vector2(cx + f * 1.5, by - 38), 7.5, col)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	draw_set_transform_matrix(body_tr(m))
	if m.at_lever():                                # pulling a lever: one hand on the knob
		var knob: Vector2 = m.lever_knob(m.switches[P.flip_sw])
		_leg(hip, Vector2(cx + 3, by - 1), 14, 0, f, 4, col)
		_leg(hip, Vector2(cx - 4, by - 1), 14, 0, f, 4, col)
		_limb(Vector2(cx, by - 28), Vector2(cx - f * 4, by - 17), 4, col)
		_limb(Vector2(cx, by - 28), knob, 4, col)
	elif P.on_ground:
		var amp: float = clampf(absf(P.vx) / 120.0, 0.0, 1.0)
		var bend: float = clampf(absf(P.vx) / 260.0, 0.0, 1.0)         # standing still: straight legs
		var up: float = cos(P.walk_phase) * f * amp * (2.0 + 4.0 * bend)   # the forward-swinging foot lifts
		var stride: float = 8.0 * (1.0 + 0.25 * bend)
		_step(hip, by, sw, maxf(up, 0.0), stride, 14, bend, f, 4, col)
		_step(hip, by, -sw, maxf(-up, 0.0), stride, 14, bend, f, 4, col)
		_limb(Vector2(cx, by - 28), Vector2(cx - sw * 7, by - 17), 4, col)
		_limb(Vector2(cx, by - 28), Vector2(cx + sw * 7, by - 17), 4, col)
	else:
		_leg(hip, Vector2(cx + f * 6, by - 4), 14, 1, f, 4, col)       # tucked: knees up
		_leg(hip, Vector2(cx - f * 3, by - 2), 14, 1, f, 4, col)
		_limb(Vector2(cx, by - 28), Vector2(cx + f * 9, by - 36), 4, col)
		_limb(Vector2(cx, by - 28), Vector2(cx - f * 7, by - 34), 4, col)
	_rrect(cx - 6.5, by - 32, 13, 19, 5, col)
	_mark(cx + f * 2, by - 25, col, P.vis)
	draw_circle(Vector2(cx + f * 1.5, by - 38), 7.5, col)
	draw_set_transform_matrix(Transform2D.IDENTITY)

# Moving a desk (prototyped in tools/characters.html): he faces it, hands on its end. Pushing he leans in
# with his feet braced behind; pulling he leans back and steps backwards. The hands stay on the desk.
func _grip_pose(P, cx: float, by: float, f: float, col: Color) -> void:
	var feet := Vector2(cx, by)
	var moving: bool = absf(P.vx) > 8.0
	var pulling: bool = moving and signf(P.vx) != f
	var s: float = sin(P.walk_phase) if moving else 0.0
	var up: float = cos(P.walk_phase) * signf(P.vx) if moving else 0.0
	var hip: Vector2 = feet + (Vector2(cx, by - 15) - feet).rotated(P.lean * 0.4)
	var base: float = cx - f * (-2.0 if pulling else 5.0)
	if moving:
		_leg(hip, Vector2(base + s * 7, by - 1 - maxf(up, 0.0) * 3), 14, 0.7, f, 4, col)
		_leg(hip, Vector2(base - s * 7, by - 1 - maxf(-up, 0.0) * 3), 14, 0.7, f, 4, col)
	else:                                           # braced: back foot out, front knee soft
		_leg(hip, Vector2(cx + f * 3, by - 1), 14, 0.3, f, 4, col)
		_leg(hip, Vector2(cx - f * 6, by - 1), 14, 0.3, f, 4, col)
	var edge: float = m.grip_end()
	_limb(feet + (Vector2(cx, by - 28) - feet).rotated(P.lean), Vector2(edge, by - 27), 4, col)           # top hand on the corner
	_limb(feet + (Vector2(cx - f, by - 27) - feet).rotated(P.lean), Vector2(edge + f * 0.5, by - 21), 4, col)   # the other lower on the end
	draw_set_transform_matrix(body_tr(m))
	_rrect(cx - 6.5, by - 32, 13, 19, 5, col)
	_mark(cx + f * 2, by - 25, col, P.vis)
	draw_circle(Vector2(cx + f * 1.5, by - 38), 7.5, col)
	draw_set_transform_matrix(Transform2D.IDENTITY)

# Gripping a desk low (↓ + E, prototyped in tools/characters.html): crouched under its top, back knee
# down, both hands up on the desktop. Moving it he shuffles - the knees trade a little and he bobs.
func _low_pose(P, cx: float, by: float, f: float, col: Color) -> void:
	var s: float = sin(P.walk_phase) if absf(P.vx) > 1.0 else 0.0
	var b: float = m.low_bob()
	var hip := Vector2(cx - f * 3, by - 9 + b)
	var knee := Vector2(cx + f * (1 + s * 2), by - 2)
	_limb(hip, knee, 3.5, col)                      # the back leg: knee down, shin along the floor
	_limb(knee, Vector2(cx - f * (10 - s * 2), by - 1.5), 3.5, col)
	var knee2 := Vector2(cx + f * (6 - s * 2), by - 11 + b)
	_limb(hip, knee2, 3.5, col)                     # the front leg: up, foot planted
	_limb(knee2, Vector2(cx + f * (5 - s * 2), by - 1), 3.5, col)
	_limb(hip, Vector2(cx + f * 4, by - 17 + b), 10, col)                     # the back, hunched
	var d: Dictionary = m.props[P.grip]             # hands up on the desktop (on it, near its end too)
	var x0: float = d.x * T + 3
	var x1: float = d.x * T + m.PROP_W.desk - 3
	_limb(Vector2(cx + f * 4, by - 18 + b), Vector2(clampf(cx + f * 11, x0, x1), by - 24), 4, col)
	_limb(Vector2(cx + f * 3, by - 17 + b), Vector2(clampf(cx + f * 17, x0, x1), by - 24), 4, col)
	draw_circle(Vector2(cx + f * 9, by - 19 + b), 6.5, col)

# The Evil Co mark (the last memory): a small diamond over his heart, a shade of grey off his body, lit or not.
func _mark(x: float, y: float, col: Color, vis: float) -> void:
	if not m.evil_mark:
		return
	var g := lerpf(44, 140, vis) / 255.0
	draw_colored_polygon(PackedVector2Array([Vector2(x, y - 2.8), Vector2(x + 2.4, y), Vector2(x, y + 2.8), Vector2(x - 2.4, y)]), Color(g, g, g))
	draw_circle(Vector2(x, y), 0.8, col)

# =====================================================================
#  OVERLAY - drawn after lighting (bulbs, exit sign, hints, eyes, noise, stars, marks)
# =====================================================================
func _overlay() -> void:
	for L in m.lights:                              # bulb glow
		if L.kind == "lamp" and L.level > 0:
			for k in 6:
				draw_circle(L.pos + Vector2(0, 7), 26.0 * (1.0 - k / 6.0), Color(1, 1, 1, 0.12 * L.level))
	for L in m.lights:                              # a broken light: glass glinting on the floor; a camera spits sparks
		if not L.broken:
			continue
		var age: float = m.time - L.broken_t
		if L.kind == "lamp":
			for k in 7:
				var gx: float = L.pos.x + (fmod(k * 37.0, 30.0) - 15.0)
				var a: float = 0.12 + 0.25 * maxf(0.0, sin(m.time * 3.0 + k * 1.7))
				draw_circle(Vector2(gx, L.shard_y - 1.5), 1.0, Color(1, 1, 1, a))
		elif age < 1.6:
			for k in 6:
				var sp: Vector2 = L.pos + Vector2(randf_range(-8, 8), randf_range(-2, 10) + age * 30.0)
				draw_circle(sp, 1.2, Color(1, 1, 1, (1.0 - age / 1.6) * 0.9))
	for L in m.lights:                              # camera status light: blinks while watching, solid when it sees you
		if L.kind == "camera" and not L.broken and (L.seeing or fmod(m.time, 1.0) < 0.5):
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
	for L in m.lights:                              # the vial machine's alarm light: a bulb that flashes with it
		if L.kind == "alarm" and L.level > 0.0:
			draw_circle(L.pos, 9.0, Color(1, 1, 1, 0.25))
			draw_circle(L.pos, 3.0, Color(1, 1, 1, 0.95))
	for pn in m.panels:                             # panel light: a slow pulse; fast in an alarm; sparks, then dark, once broken
		var lp := Vector2(pn.x * T, pn.row * T - 54)
		if pn.broken:
			var k: float = m.time - pn.broken_t
			if k < 1.2 and fmod(m.time * 17.0, 1.0) < 0.4:
				draw_circle(lp + Vector2(randf_range(-6, 6), randf_range(0, 10)), 1.5, Color(1, 1, 1, 0.9 * (1.2 - k)))
		elif fmod(m.time, 0.3 if m.alarm != "" else 2.0) < (0.15 if m.alarm != "" else 0.25):
			draw_circle(lp, 6.0 if m.alarm != "" else 4.0, Color(1, 1, 1, 0.22))
			draw_circle(lp, 2.0, Color(1, 1, 1, 0.9))
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
	for i in m.hints.size():                        # [x, y, text, controller text (optional)]; they surface as you near them
		var h: Array = m.hints[i]
		var a: float = m.hint_a[i] if m.state != "title" else 0.0
		if a > 0.01:
			a = a * a * (3.0 - 2.0 * a)
			var breathe := 0.88 + 0.12 * sin(m.time * 1.3 + i * 1.7)
			_text(m.font_italic, Vector2(h[0] * T, h[1] + (1.0 - a) * 5.0), h[3] if m.pad and h.size() > 3 else h[2], 14, Color(1, 1, 1, 0.34 * a * breathe))
	var P = m.P
	if m.state != "title":
		if P.cover >= 0 and not P.hidden:           # nudge: you could hide here
			var p: Dictionary = m.props[P.cover]
			_text(m.font_regular, Vector2(p.x * T + m.PROP_W[p.type] / 2, p.y - 66), "↓", 13, Color(1, 1, 1, 0.45), true)
		_eyes()
		_fight_fx()
	_noise_and_stars()
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
	if m.fight != null and not m.npose.is_empty():
		var R := Fight.rig(cx, by, f, m.npose, Fight.NB)
		if R.sx < 0.0 and m.npose.face < 0.5:           # back turned in a spin: no eyes
			return
		h = R.head
		f = R.fe
	elif P.clinging:
		h = Vector2(cx + f * 13, P.y + 10)
	elif m.gripping_low():
		h = Vector2(cx + f * 9, by - 19 + m.low_bob())
	elif P.crawling:
		h = Vector2(cx + f * 13, by - 10)
	else:
		draw_set_transform_matrix(body_tr(m))
		h = Vector2(cx + f * 1.5, by - 38)
	for e in [[Vector2(f * 2.5, -1.5), 1.7], [Vector2(f * 5.8, -1.8), 1.5]]:
		draw_circle(h + e[0], e[1] + 2.5, Color(1, 1, 1, 0.25))
		draw_circle(h + e[0], e[1], Color.WHITE)
	draw_set_transform_matrix(Transform2D.IDENTITY)

# A fight: the watcher's tell (three white ticks over his head), speed lines where his hands and feet
# just were, and a white burst where a blow lands.
func _fight_fx() -> void:
	var g = m.fight
	if g != null:
		var k: float = m.tell_k()
		if k > 0.0:
			var o := Vector2(g.x + g.facing, g.y - 66)
			var col := Color(1, 1, 1, (0.6 + 0.4 * sin(m.time * 38.0)) * k)
			for a in [-0.55, 0.0, 0.55]:
				var d := Vector2(sin(a), -cos(a))
				draw_line(o + d * 7.0, o + d * 15.0, col, 2.0, true)
		var P = m.P
		var cx: float = P.x + P.w / 2
		var by: float = P.y + P.h
		var ext := func(p: Dictionary) -> Array:
			var R := Fight.rig(cx, by, P.facing, p, Fight.NB)
			return [R.fA, R.fB, R.hA, R.hB]
		var prev: Array = ext.call(m.npose_at(m.nt))
		for j in range(1, 7):
			var cur: Array = ext.call(m.npose_at(m.nt - j * 0.014))
			for i in 4:
				if (prev[i] as Vector2).distance_to(cur[i]) > 2.2:
					draw_line(prev[i], cur[i], Color(0.82, 0.82, 0.82, 0.32 * (1.0 - j / 7.0)), 2.2, true)
			prev = cur
	for e in m.fx:
		var k: float = (m.time - e.t) / 0.25
		if k >= 0.0 and k < 1.0:
			var r: float = (3.0 + k * 9.0) * e.size
			for i in 6:
				var d := Vector2.from_angle(i * TAU / 6.0 + 0.3)
				draw_line(e.p + d * r * 0.4, e.p + d * r, Color(1, 1, 1, 0.9 * (1.0 - k)), 1.2, true)

func _noise_and_stars() -> void:
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
	for st in m.stars:                              # in flight: a spinning glint
		if st.state != "stuck":
			_star(Vector2(st.x, st.y), st.ang, 5.0, grey(0xc8))

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
#  AIM - the star's line and the cursor (on top of everything)
# =====================================================================
func _aim() -> void:
	if m.state != "play" or not m.aiming:          # only in throw mode (Ctrl)
		return
	_aim_star()

# A star's aim: a straight dotted line to where it goes; a ring on the light or panel it would put out.
func _aim_star() -> void:
	var a: Dictionary = m.star_aim()
	var can: bool = m.star_count > 0
	var tr: Dictionary = a.trace
	var end: Vector2 = tr.end
	if can:
		var d: float = a.o.distance_to(end)
		var i := 10.0
		while i < d:
			draw_circle(a.o + a.dir * i, 1.3, Color(1, 1, 1, 0.5))
			i += 10.0
		if tr.light != null:
			var L = tr.light
			draw_arc(L.pos + (Vector2(0, 4) if L.kind == "lamp" else Vector2.ZERO), 12, 0, TAU, 28, Color(1, 1, 1, 0.9), 1.5, true)
		elif tr.panel != null:
			draw_arc(Vector2(tr.panel.x * m.T, tr.panel.row * m.T - 48), 12, 0, TAU, 28, Color(1, 1, 1, 0.9), 1.5, true)
		elif tr.wall:
			draw_line(end + Vector2(-4, -4), end + Vector2(4, 4), Color(1, 1, 1, 0.6), 1.5, true)
			draw_line(end + Vector2(4, -4), end + Vector2(-4, 4), Color(1, 1, 1, 0.6), 1.5, true)
	var t: Vector2 = a.tgt
	var col := Color(1, 1, 1, 0.9 if can else 0.45)
	draw_arc(t, 8, 0, TAU, 28, col, 1.5, true)
	draw_circle(t, 1.8, col)
	if not can:
		_text(m.font_italic, t + Vector2(0, 24), "no stars", 11, col, true)
