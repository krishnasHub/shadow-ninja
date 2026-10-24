extends Node2D
## SHADOW NINJA - Godot port of the HTML prototype (../index.html). Same level, same rules.
## Core rule kept: the light you SEE is the light that CATCHES you.
## Godot's PointLight2D draws each light; its texture is baked from the same falloff stops and
## soft cone, and its shadows come from occluders built from the same tile rectangles that our
## own detection rays test against.

const DrawNode := preload("res://scripts/draw_node.gd")
const Hud := preload("res://scripts/hud.gd")
const PostShader := preload("res://shaders/post.gdshader")
const Levels := preload("res://scripts/levels.gd")

const VIEW_W := 960.0
const VIEW_H := 540.0
const T := 32
const GRIP := 2
const DOOR := 3                 # a locked door: solid until its switch is pulled

const TUNE := {
	"gravity": 1800.0, "max_fall": 1100.0,
	"walk": 140.0, "run": 260.0, "crawl": 70.0, "cling": 80.0,
	"accel_ground": 1600.0, "accel_air": 900.0,
	# Limbo-style weight: speed builds slowly, then picks up (seconds to full speed), and eases to a stop
	"ramp_run": 0.9, "ramp_walk": 0.6, "ramp_crawl": 0.4, "ramp_cling": 0.5,
	"ramp_floor": 0.08,                         # the first step starts at 8% of full speed
	"decel": 1400.0,                            # stopping / turning: about 0.2s from a full run
	"jump_v": 640.0, "jump_cut": 1.2,           # extra gravity while rising with jump released
	"coyote": 0.08, "jump_buffer": 0.12,
	"width": 18.0, "stand_h": 44.0, "crawl_h": 20.0,
	"ambient": 0.42,                            # how bright "darkness" is (CanvasModulate)
	"fill_rate": 0.38,                          # meter per second at full exposure
	"drain_delay": 1.2, "drain_rate": 0.12,
	"exposed_threshold": 0.03,
	"land_noise_v": 600.0,                      # landings faster than this are loud (drops of up to 3 tiles are quiet)
	"flip_time": 0.65,                          # pulling a lever: the ninja stops, reaches, pulls
}
const METER_SUSPICIOUS := 0.35
const METER_ALERT := 0.65

const GUARD := {
	"walk": 55.0, "chase": 115.0, "investigate": 85.0,
	"ramp": 1.0, "decel": 300.0,                # guards are heavier: slower to get going, ease into stops
	"torch_radius": 330.0, "torch_spread": 0.32, "danger": 1.3,
	"search_time": 4.0, "end_pause": 1.5, "saw_you_hide": 0.4,
	"alert_speed": 1.35, "alert_search": 7.0,
	"wake_after": INF,                          # sleepers never wake. Harder difficulty: seconds
}
const NOISE := {"run": 150.0, "land": 120.0, "stone": 280.0, "thud": 140.0, "lever": 230.0}
const STONE := {"max": 3, "max_speed": 700.0, "gravity": 1400.0, "r": 3.0}

const STOPS_LAMP := [[0.0, 1.0], [0.5, 0.85], [0.8, 0.5], [1.0, 0.0]]
const STOPS_FLAT := [[0.0, 1.0], [1.0, 1.0]]
const CONE_SOFT := [1.0]               # one hard-edged cone, for render AND detection
										# ([0.82, 1.0, 1.15] = the HTML version's soft edge)
const LIGHT_TEX := 512                 # high enough that the cone edge stays crisp when scaled up

const PROP_W := {"desk": 70.0, "plant": 26.0, "cooler": 26.0, "rack": 40.0}
class Player:
	var x := 0.0
	var y := 0.0
	var w := 18.0
	var h := 44.0
	var vx := 0.0
	var vy := 0.0
	var on_ground := false
	var facing := 1
	var crawling := false
	var clinging := false
	var running := false
	var coyote := 0.0
	var jump_buf := 0.0
	var walk_phase := 0.0
	var move_t := 0.0        # how long you've been pushing the same way (drives the speed ramp)
	var lean := 0.0
	var vis := 0.0
	var cover := -1          # index into props, -1 = none
	var hidden := false
	var was_hidden := false
	var flip_sw := -1         # pulling this switch (index), -1 = not
	var flip_t := 0.0

class Lt:
	var kind := "lamp"
	var pos := Vector2.ZERO
	var dir := PI / 2
	var spread := 0.5
	var radius := 420.0
	var intensity := 1.0
	var stops: Array = []
	var flicker_period := 0.0
	var flicker_on := 0.0
	var level := 1.0
	var danger := 1.0
	var sweep_amp := 0.0     # cameras: sweep +-amp radians around base_dir, every sweep_period seconds
	var sweep_period := 1.0
	var base_dir := 0.0
	var seeing := false
	var alarm_t := -99.0
	var node: PointLight2D
	var guard = null

class Guard:
	var x := 0.0
	var y := 0.0
	var facing := 1
	var from_x := 0.0
	var to_x := 0.0
	var min_x := 0.0
	var max_x := 0.0
	var state := "patrol"
	var pause := 0.0
	var phase := 0.0
	var move_t := 0.0
	var cur_v := 0.0         # current speed (drives the stride)
	var moving := false
	var search_start := 0.0
	var search_facing := 1
	var seen_t := -99.0
	var last_seen := 0.0
	var knows_hide := -1
	var aim := 0.15
	var invest_x := 0.0
	var hunting_you := false
	var alert := false
	var found := false
	var sleep_t := 0.0
	var torch: Lt

class Stone:
	var x := 0.0
	var y := 0.0
	var vx := 0.0
	var vy := 0.0
	var resting := false
	var clacked := false
	var taken := false

class NoiseEvent:
	var x := 0.0
	var y := 0.0
	var r := 0.0
	var t := 0.0
	var poly := PackedVector2Array()

# ---------- state ----------
# ---------- the current floor (loaded from levels.gd) ----------
var LW := 100                   # this floor's width in tiles
var LH := 17                    # ...and height (taller floors scroll vertically)
var exit_row := 15              # the tile row the exit door stands on
var switches: Array = []        # {x, row, door, on, anim}: walk up to one and the ninja pulls it
var doors: Array = []           # {x, y, w, h, open}: DOOR tiles until their switch is pulled
var occ_nodes: Array = []       # light occluders (rebuilt when a door opens)
var level_idx := 0
var level: Dictionary = {}
var props: Array = []           # {type, x (tiles), y (px: the surface it stands on)}
var hints: Array = []
var guard_defs: Array = []
var spawn := Vector2.ZERO
var exit_x := 0.0
var door_x := 0                 # tiles
var level_t := 0.0              # seconds since this floor started (drives the floor-name banner)
var static_nodes: Array = []    # drawn once per floor; redrawn when a floor loads
var level_nodes: Array = []     # this floor's lights + occluders, freed when the next one loads
var grid := PackedByteArray()
var seg_a := PackedVector2Array()
var seg_b := PackedVector2Array()
var lights: Array = []          # static lights (lamps, moon, sign)
var torch_pool: Array = []      # one torch light per guard, reused across runs
var guards: Array = []
var noises: Array = []
var stones: Array = []
var stone_count := 0
var P := Player.new()
var scarf_pos := PackedVector2Array()
var scarf_prev := PackedVector2Array()
var state := "title"
var state_t := 0.0
var time := 0.0
var debug := false
var meter := 0.0
var exposure := 0.0
var calm := 0.0
var cam := Vector2(0, maxf(0.0, (LH * T - VIEW_H) / 2.0))
var jump_queued := false
var aiming := false             # throw mode (Ctrl): the mouse aims, a click throws
var mouse_world := Vector2.ZERO
var mouse_seen := false
var mouse_moved_t := -99.0
var fps := 60.0

var camera: Camera2D
var draw_nodes: Array = []      # redrawn every frame
var hud: Control
var post_mat: ShaderMaterial
var font_regular: Font
var font_italic: Font
var font_bold: Font
var _tex_cache := {}

# capture mode (dev tool): godot --path . -- --capture=out.png --setup=chase --frames=40
var _capture := {}
var _frame := 0

# =====================================================================
#  SETUP
# =====================================================================
func _ready() -> void:
	_make_fonts()
	var cm := CanvasModulate.new()
	cm.color = Color(TUNE.ambient, TUNE.ambient, TUNE.ambient)
	add_child(cm)
	build_layers()
	camera = Camera2D.new()
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(camera)
	camera.make_current()
	_build_screen_layers()
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=")
		if kv.size() == 2:
			_capture[kv[0]] = kv[1]
	load_level(0)
	start_run()
	state = "title"
	if _capture.has("capture"):
		_capture_setup(_capture.get("setup", "title"))
	if _capture.has("selftest"):
		if _capture.selftest == "throwmode":
			_selftest_throw_mode()
		elif _capture.selftest == "menu":
			_selftest_menu()
		elif _capture.selftest == "quit":
			_selftest_quit()
		elif _capture.selftest == "floor2":
			_selftest_floor2()
		elif _capture.selftest == "floor3":
			_selftest_floor3()
		else:
			_selftest()
		get_tree().quit()

func _make_fonts() -> void:
	var names := PackedStringArray(["Georgia", "Times New Roman", "serif"])
	font_regular = SystemFont.new()
	font_regular.font_names = names
	font_italic = SystemFont.new()
	font_italic.font_names = names
	font_italic.font_italic = true
	font_bold = SystemFont.new()
	font_bold.font_names = names
	font_bold.font_weight = 700

func _add_draw(kind: String, parent: Node, z: int, unshaded := false) -> Node2D:
	var n: Node2D = DrawNode.new()
	n.m = self
	n.kind = kind
	n.z_index = z
	if unshaded:
		var mat := CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		n.material = mat
	parent.add_child(n)
	return n

func build_layers() -> void:
	# back to front: fog (fixed), far city, mid office wall - all lit by the lights like the HTML lightmap
	for spec in [["fog", 0.0, -10, 0.0], ["far", 0.18, -9, 0.2], ["mid", 0.5, -8, 0.5]]:
		var px := Parallax2D.new()
		px.scroll_scale = Vector2(spec[1], spec[3])
		add_child(px)
		static_nodes.append(_add_draw(spec[0], px, spec[2]))
	# main layer
	static_nodes.append(_add_draw("stage", self, 0))
	draw_nodes.append(_add_draw("actors_back", self, -1))     # the ninja while hidden: furniture draws over him
	draw_nodes.append(_add_draw("actors", self, 1))
	# foreground silhouettes sweep past faster than the world
	var fg := Parallax2D.new()
	fg.scroll_scale = Vector2(1.35, 0.0)
	add_child(fg)
	static_nodes.append(_add_draw("fg", fg, 20, true))

func _build_screen_layers() -> void:
	# overlay: world-space things drawn after lighting (eyes, bulbs, hints, noise, aim) - not darkened
	var over := CanvasLayer.new()
	over.layer = 1
	over.follow_viewport_enabled = true
	add_child(over)
	draw_nodes.append(_add_draw("overlay", over, 0))
	draw_nodes.append(_add_draw("aim", over, 1))
	# grain + vignette
	var post := CanvasLayer.new()
	post.layer = 5
	add_child(post)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new()
	post_mat.shader = PostShader
	rect.material = post_mat
	post.add_child(rect)
	# HUD + screens
	var hl := CanvasLayer.new()
	hl.layer = 10
	add_child(hl)
	hud = Hud.new()
	hud.m = self
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hl.add_child(hud)

# =====================================================================
#  LEVEL - one office floor, built from rectangles (tile units)
# =====================================================================
func fill(x: int, y: int, w: int, h: int, v: int = 1) -> void:
	for j in range(y, y + h):
		for i in range(x, x + w):
			grid[j * LW + i] = v

func load_level(idx: int) -> void:
	level_idx = idx
	level = Levels.LEVELS[idx]
	LW = level.width
	LH = level.get("height", 17)
	exit_row = level.get("exit_row", 15)
	for n in level_nodes:
		n.queue_free()
	level_nodes.clear()
	occ_nodes.clear()
	lights.clear()
	grid.resize(LW * LH)
	grid.fill(0)
	fill(0, 0, LW, 2)                   # ceiling
	fill(0, LH - 2, LW, 2)              # floor
	fill(0, 0, 1, LH)                   # outer walls
	fill(LW - 1, 0, 1, LH)
	for r in level.solids:
		fill(r[0], r[1], r[2], r[3])
	for r in level.holes:
		fill(r[0], r[1], r[2], r[3], 0)
	for r in level.ducts:
		fill(r[0], r[1], r[2], r[3], GRIP)
	doors = []
	for r in level.get("doors", []):
		fill(r[0], r[1], r[2], r[3], DOOR)
		doors.append({"x": r[0], "y": r[1], "w": r[2], "h": r[3], "open": false})
	switches = []
	for sw in level.get("switches", []):
		switches.append({"x": sw.x, "row": sw.row, "door": sw.door, "on": false, "anim": 0.0})
	props = []
	for p in level.props:
		props.append({"type": p[0], "x": float(p[1]), "y": float(p[2] * T)})
	hints = level.hints
	guard_defs = level.guards
	spawn = Vector2(level.spawn[0] * T, level.spawn[1] * T - TUNE.stand_h)
	door_x = level.exit
	exit_x = level.exit * T + 8
	build_segments()
	build_occluders()
	build_lights()
	for n in static_nodes:
		n.queue_redraw()

# A door opens: its tiles go, and the light geometry is rebuilt around the gap.
func open_door(i: int) -> void:
	var d: Dictionary = doors[i]
	d.open = true
	fill(d.x, d.y, d.w, d.h, 0)
	build_segments()
	for n in occ_nodes:
		n.queue_free()
	occ_nodes.clear()
	build_occluders()
	for n in static_nodes:
		n.queue_redraw()

# Above the map is open sky (so skylights let moonlight in); sides and below are solid.
func solid_at(i: int, j: int) -> bool:
	if j < 0:
		return false
	if i < 0 or i >= LW or j >= LH:
		return true
	return grid[j * LW + i] != 0

func is_grip(i: int, j: int) -> bool:
	return i >= 0 and i < LW and j >= 0 and j < LH and grid[j * LW + i] == GRIP

func solid_px(x: float, y: float) -> bool:
	return solid_at(floori(x / T), floori(y / T))

func rect_hits(x: float, y: float, w: float, h: float) -> bool:
	for j in range(floori(y / T), floori((y + h - 0.001) / T) + 1):
		for i in range(floori(x / T), floori((x + w - 0.001) / T) + 1):
			if solid_at(i, j):
				return true
	return false

# ---------- occluder segments: merged tile edges ----------
func build_segments() -> void:
	seg_a.clear()
	seg_b.clear()
	for y in range(LH + 1):                 # horizontal edges
		var start := 0
		var run := 0
		for x in range(LW + 1):
			var t := 0
			if x < LW:
				var a := solid_at(x, y - 1)
				var b := solid_at(x, y)
				if a != b:
					t = 1 if b else 2
			if t != run:
				if run != 0:
					seg_a.append(Vector2(start * T, y * T))
					seg_b.append(Vector2(x * T, y * T))
				run = t
				start = x
	for x in range(LW + 1):                 # vertical edges
		var start := 0
		var run := 0
		for y in range(LH + 1):
			var t := 0
			if y < LH:
				var a := solid_at(x - 1, y)
				var b := solid_at(x, y)
				if a != b:
					t = 1 if b else 2
			if t != run:
				if run != 0:
					seg_a.append(Vector2(x * T, start * T))
					seg_b.append(Vector2(x * T, y * T))
				run = t
				start = y

# Godot's light occluders: one rectangle per horizontal run of solid tiles
func build_occluders() -> void:
	for j in LH:
		var i := 0
		while i < LW:
			if grid[j * LW + i] == 0:
				i += 1
				continue
			var s := i
			while i < LW and grid[j * LW + i] != 0:
				i += 1
			var r := Rect2(s * T, j * T, (i - s) * T, T)
			var op := OccluderPolygon2D.new()
			op.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
			var occ := LightOccluder2D.new()
			occ.occluder = op
			add_child(occ)
			level_nodes.append(occ)
			occ_nodes.append(occ)

# Ray (p + t*d) vs segment a-b; returns t (in units of d) or INF.
static func ray_seg(p: Vector2, d: Vector2, a: Vector2, b: Vector2) -> float:
	var e := b - a
	var den := d.x * e.y - d.y * e.x
	if absf(den) < 1e-9:
		return INF
	var s := a - p
	var t := (s.x * e.y - s.y * e.x) / den
	var u := (s.x * d.y - s.y * d.x) / den
	return t if (t > 0.0 and u >= 0.0 and u <= 1.0) else INF

func blocked(a: Vector2, b: Vector2) -> bool:
	var d := b - a
	for k in seg_a.size():
		var t := ray_seg(a, d, seg_a[k], seg_b[k])
		if t > 1e-4 and t < 1.0 - 1e-4:
			return true
	return false

# Everything a point can "see" within radius r, as an angle-sorted polygon (used for noise).
func visibility_polygon(o: Vector2, r: float) -> PackedVector2Array:
	var x0 := o.x - r
	var y0 := o.y - r
	var x1 := o.x + r
	var y1 := o.y + r
	var sa := PackedVector2Array()
	var sb := PackedVector2Array()
	for k in seg_a.size():
		var a := seg_a[k]
		var b := seg_b[k]
		if maxf(a.x, b.x) >= x0 and minf(a.x, b.x) <= x1 and maxf(a.y, b.y) >= y0 and minf(a.y, b.y) <= y1:
			sa.append(a)
			sb.append(b)
	var c := [Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]
	for k in 4:
		sa.append(c[k])
		sb.append(c[(k + 1) % 4])
	var angles := PackedFloat64Array()
	for k in sa.size():
		for p in [sa[k], sb[k]]:
			var an: float = (p - o).angle()
			angles.append(an - 1e-4)
			angles.append(an)
			angles.append(an + 1e-4)
	angles.sort()
	var pts := PackedVector2Array()
	for an in angles:
		var d := Vector2(cos(an), sin(an))
		var best := INF
		for k in sa.size():
			best = minf(best, ray_seg(o, d, sa[k], sb[k]))
		if best < INF:
			pts.append(o + d * best)
	return pts

# =====================================================================
#  LIGHTS
# =====================================================================
static func falloff(stops: Array, t: float) -> float:
	for i in range(1, stops.size()):
		if t <= stops[i][0]:
			var t0: float = stops[i - 1][0]
			var v0: float = stops[i - 1][1]
			return lerpf(v0, stops[i][1], (t - t0) / (stops[i][0] - t0))
	return 0.0

# The light's look, baked into a texture: same stops, same three soft cones as light_at().
func light_texture(spread: float, stops: Array) -> ImageTexture:
	var key := "%s|%s" % [spread, stops]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var data := PackedByteArray()
	data.resize(LIGHT_TEX * LIGHT_TEX * 4)
	var c := LIGHT_TEX / 2.0
	var idx := 0
	for j in LIGHT_TEX:
		for i in LIGHT_TEX:
			var v := Vector2(i + 0.5 - c, j + 0.5 - c)
			var d := v.length() / c
			var val := 0.0
			if d < 1.0:
				var ang := absf(v.angle())
				var cone := 0.0
				for k in CONE_SOFT:     # coverage across ~1 texel so the hard edge isn't stair-stepped
					cone += clampf((spread * k - ang) * v.length() + 0.5, 0.0, 1.0)
				val = falloff(stops, d) * cone / CONE_SOFT.size()
			var b := int(val * 255.0)
			data[idx] = b
			data[idx + 1] = b
			data[idx + 2] = b
			data[idx + 3] = 255
			idx += 4
	var tex := ImageTexture.create_from_image(Image.create_from_data(LIGHT_TEX, LIGHT_TEX, false, Image.FORMAT_RGBA8, data))
	_tex_cache[key] = tex
	return tex

func make_light(kind: String, pos: Vector2, dir: float, spread: float, radius: float,
		intensity := 1.0, stops: Array = STOPS_LAMP, danger := 1.0) -> Lt:
	var L := Lt.new()
	L.kind = kind
	L.pos = pos
	L.dir = dir
	L.spread = spread
	L.radius = radius
	L.intensity = intensity
	L.level = intensity
	L.stops = stops
	L.danger = danger
	var pl := PointLight2D.new()
	pl.texture = light_texture(spread, stops)
	pl.texture_scale = radius * 2.0 / LIGHT_TEX
	pl.position = pos
	pl.rotation = dir
	pl.energy = intensity
	pl.shadow_enabled = true
	pl.shadow_filter = Light2D.SHADOW_FILTER_PCF5    # PCF with no extra smoothing: crisp but not jagged
	pl.shadow_filter_smooth = 0.0
	add_child(pl)
	L.node = pl
	return L

func build_lights() -> void:
	var ceil_y := 2 * T + 4
	for d in level.lights:
		var L: Lt
		match d.kind:
			"moon":                     # through a skylight gap, from far above
				var cx: float = (d.gap + 1) * T
				var o := Vector2(cx - 150, -420)
				L = make_light("moon", o, atan2(2 * T - o.y, cx - o.x), 0.3, 1150, 0.45, STOPS_FLAT)
			"sign":
				L = make_light("sign", Vector2(d.x * T, (exit_row - 4) * T + 20), 0.0, PI, 170, 0.35)
			_:                          # lamp / camera: on the ceiling unless a y is given
				var y: float = d.y * T if d.has("y") else ceil_y
				L = make_light(d.kind, Vector2(d.x * T, y), d.get("dir", PI / 2), d.spread, d.radius,
					d.get("intensity", 1.0), STOPS_LAMP, d.get("danger", 1.0))
		if d.has("flicker"):
			L.flicker_period = d.flicker[0]
			L.flicker_on = d.flicker[1]
		if d.has("sweep"):
			L.sweep_amp = d.sweep[0]
			L.sweep_period = d.sweep[1]
			L.base_dir = L.dir
		lights.append(L)
		level_nodes.append(L.node)

func all_lights() -> Array:
	var out := lights.duplicate()
	for g in guards:
		out.append(g.torch)
	return out

func update_light(L: Lt, t: float) -> void:
	if L.sweep_amp > 0.0:
		L.dir = L.base_dir + L.sweep_amp * sin(TAU * t / L.sweep_period)
		L.node.rotation = L.dir
	if L.flicker_period > 0.0:
		var ph := fmod(t, L.flicker_period) / L.flicker_period
		var lit := ph < L.flicker_on
		if ph < 0.07:
			lit = sin(t * 90.0) > 0.2                       # sputters on
		elif ph > L.flicker_on - 0.03 and ph < L.flicker_on:
			lit = sin(t * 70.0) > 0.0
		L.level = L.intensity if lit else 0.0
	L.node.energy = L.level
	L.node.enabled = L.level > 0.0

# How much of light L reaches point p, 0..1. Mirrors the baked texture exactly.
func light_at(L: Lt, p: Vector2) -> float:
	if L.level <= 0.0:
		return 0.0
	var dv := p - L.pos
	var d2 := dv.length_squared()
	if d2 >= L.radius * L.radius:
		return 0.0
	var ang := absf(wrapf(dv.angle() - L.dir, -PI, PI))
	var cone := 0
	for k in CONE_SOFT:
		if ang <= L.spread * k:
			cone += 1
	if cone == 0 or blocked(L.pos, p):
		return 0.0
	return L.level * falloff(L.stops, sqrt(d2) / L.radius) * cone / CONE_SOFT.size()

# =====================================================================
#  RUN STATE
# =====================================================================
func start_run(idx := -1) -> void:
	if idx >= 0:
		load_level(idx)
	P = Player.new()
	P.x = spawn.x
	P.y = spawn.y
	P.w = TUNE.width
	P.h = TUNE.stand_h
	guards.clear()
	for i in guard_defs.size():
		guards.append(make_guard(guard_defs[i], i))
	for i in range(guards.size(), torch_pool.size()):     # torches of guards this floor does not have
		torch_pool[i].level = 0.0
		torch_pool[i].guard = null
	noises.clear()
	stones.clear()
	stone_count = STONE.max
	meter = 0.0
	exposure = 0.0
	calm = 0.0
	jump_queued = false
	aiming = false
	reset_scarf()
	cam.x = clampf(P.x - VIEW_W * 0.4, 0, LW * T - VIEW_W)
	cam.y = clampf(P.y + P.h / 2 - VIEW_H * 0.55, 0, LH * T - VIEW_H)
	state = "play"
	state_t = 0.0
	level_t = 0.0

var test_keys = null    # self-test: a Dictionary of held keys replaces the keyboard

func held(k: String) -> bool:
	if test_keys != null:
		return test_keys.has(k)
	match k:
		"left": return Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A)
		"right": return Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D)
		"jump": return Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
		"down": return Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S)
		"walk": return Input.is_physical_key_pressed(KEY_SHIFT)
	return false

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		var code: int = e.physical_keycode
		if code == KEY_F11:
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
			return
		if in_menu():
			menu_key(code)
			return
		match code:
			KEY_SPACE, KEY_W, KEY_UP:
				jump_queued = true
			KEY_CTRL:                       # throw mode on/off
				if state == "play":
					aiming = not aiming and stone_count > 0
			KEY_R:
				start_run()
			KEY_ESCAPE, KEY_P:
				open_menu("pause" if state == "play" else "title")   # caught / escaped go back to the title
			KEY_ENTER, KEY_KP_ENTER:
				if state == "escaped" and level_idx + 1 < Levels.LEVELS.size():
					start_run(level_idx + 1)        # on to the next floor
				elif state == "caught" or state == "escaped":
					open_menu("title")
			KEY_G:
				debug = not debug
	elif e is InputEventMouseMotion:
		mouse_seen = true
		mouse_moved_t = time
		if in_menu() and menu_page == "":
			var i := menu_item_at(get_viewport().get_mouse_position())
			if i >= 0:
				menu_sel = i
		elif in_menu() and menu_page == "quit":
			var q := quit_item_at(get_viewport().get_mouse_position())
			if q >= 0:
				quit_sel = q
		elif in_menu() and menu_page == "levels":
			var l := level_item_at(get_viewport().get_mouse_position())
			if l >= 0:
				level_sel = l
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if in_menu():
			if menu_page == "quit":
				var q := quit_item_at(get_viewport().get_mouse_position())
				if q >= 0:
					quit_choose(q)
			elif menu_page == "levels":
				var l := level_item_at(get_viewport().get_mouse_position())
				if l >= 0:
					start_run(l)
			elif menu_page != "":
				menu_page = ""
			else:
				var i := menu_item_at(get_viewport().get_mouse_position())
				if i >= 0:
					menu_activate(i)
		elif aiming:                        # outside throw mode the mouse does nothing
			throw_stone()
			aiming = false                  # one throw per Ctrl

# =====================================================================
#  MENUS - title (New Game / About / Controls / Quit) and pause (Resume + the same).
#  Keyboard: ↑ ↓ (or W S) choose, Enter / Space select, Esc back. Mouse: hover + click.
# =====================================================================
const MENU_Y := 280.0           # first item's baseline; hud.gd draws the items at the same spots
const MENU_DY := 40.0
var menu_sel := 0
var menu_page := ""             # "" = the list, or "levels" / "about" / "controls" / "quit"
var level_sel := 0              # Levels page: which floor is highlighted
const LEVELS_Y := 250.0         # Levels page: first floor's baseline (hud.gd draws at the same spots)
var quit_sel := 0               # "Are you sure?": 0 = No (the default), 1 = Yes
const QUIT_Y := 310.0           # No / Yes baseline; hud.gd draws them at QUIT_X
const QUIT_X := [400.0, 560.0]

func in_menu() -> bool:
	return state == "title" or state == "pause"

func menu_items() -> Array:
	if state == "pause":
		return ["Resume", "New Game", "Levels", "About", "Controls", "Quit"]
	return ["New Game", "Levels", "About", "Controls", "Quit"]

func menu_item_at(p: Vector2) -> int:
	for i in menu_items().size():
		var y := MENU_Y + i * MENU_DY
		if absf(p.x - VIEW_W / 2) < 150 and p.y > y - 28 and p.y < y + 10:
			return i
	return -1

func open_menu(st: String) -> void:
	state = st
	state_t = 0.0
	menu_sel = 0
	menu_page = ""
	aiming = false

func menu_activate(i: int) -> void:
	match menu_items()[i]:
		"Resume":
			state = "play"
		"New Game":
			start_run(0)
		"Levels":                           # pick any floor (a dev convenience for now)
			menu_page = "levels"
			level_sel = level_idx
		"About":
			menu_page = "about"
		"Controls":
			menu_page = "controls"
		"Quit":
			menu_page = "quit"
			quit_sel = 0

func level_item_at(p: Vector2) -> int:
	for i in Levels.LEVELS.size():
		var y := LEVELS_Y + i * MENU_DY
		if absf(p.x - VIEW_W / 2) < 220 and p.y > y - 28 and p.y < y + 10:
			return i
	return -1

func quit_item_at(p: Vector2) -> int:
	for i in 2:
		if absf(p.x - QUIT_X[i]) < 60 and p.y > QUIT_Y - 28 and p.y < QUIT_Y + 10:
			return i
	return -1

func quit_choose(i: int) -> void:
	if i == 1:
		get_tree().quit()
	else:
		menu_page = ""

func menu_key(code: int) -> void:
	if menu_page == "quit":                 # Are you sure?  ← → choose, Enter picks, Y / N shortcuts
		match code:
			KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D, KEY_UP, KEY_DOWN, KEY_W, KEY_S:
				quit_sel = 1 - quit_sel
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				quit_choose(quit_sel)
			KEY_Y:
				quit_choose(1)
			KEY_N, KEY_ESCAPE, KEY_BACKSPACE:
				quit_choose(0)
		return
	if menu_page == "levels":               # ↑ ↓ choose a floor, Enter plays it, Esc back
		var n := Levels.LEVELS.size()
		match code:
			KEY_UP, KEY_W:
				level_sel = (level_sel - 1 + n) % n
			KEY_DOWN, KEY_S:
				level_sel = (level_sel + 1) % n
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				start_run(level_sel)
			KEY_ESCAPE, KEY_BACKSPACE:
				menu_page = ""
		return
	if menu_page != "":                     # About / Controls: any of these goes back
		if code in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_BACKSPACE]:
			menu_page = ""
		return
	var n := menu_items().size()
	match code:
		KEY_UP, KEY_W:
			menu_sel = (menu_sel - 1 + n) % n
		KEY_DOWN, KEY_S:
			menu_sel = (menu_sel + 1) % n
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			menu_activate(menu_sel)
		KEY_ESCAPE:
			if state == "pause":
				state = "play"

# =====================================================================
#  PLAYER
# =====================================================================
# Speed multiplier after pushing for t seconds: starts at ramp_floor, eases up (smoothstep) to 1 at `secs`.
static func ramp(t: float, secs: float) -> float:
	var k := clampf(t / secs, 0.0, 1.0)
	return TUNE.ramp_floor + (1.0 - TUNE.ramp_floor) * k * k * (3.0 - 2.0 * k)

# Pulling a lever: stand still, reach, pull it down (the handle swings), clunk - the door unlocks.
func update_flip(dt: float) -> void:
	var sw: Dictionary = switches[P.flip_sw]
	P.flip_t += dt
	P.vx = 0.0
	P.move_t = 0.0
	jump_queued = false
	var k := clampf((P.flip_t - 0.12) / 0.3, 0.0, 1.0)
	sw.anim = k * k * (3.0 - 2.0 * k)
	if k >= 1.0 and not sw.on:
		sw.on = true
		open_door(sw.door)
		make_noise(sw.x * T, sw.row * T - 30, NOISE.lever)          # the clunk carries
	if P.flip_t >= TUNE.flip_time:
		P.flip_sw = -1

# Where the lever's knob is (handle swings from up to down as anim goes 0 -> 1).
func lever_knob(sw: Dictionary) -> Vector2:
	var a := lerpf(-PI / 2 + 0.55, PI / 2 - 0.55, sw.anim)
	return Vector2(sw.x * T, sw.row * T - 35) + Vector2.from_angle(a) * 16.0

func can_stand() -> bool:
	return not rect_hits(P.x, P.y - (TUNE.stand_h - TUNE.crawl_h), P.w, TUNE.stand_h)

# clinging: hold on while the tile above your middle is a duct
func grip_over(x: float) -> bool:
	return is_grip(floori((x + P.w / 2) / T), floori(P.y / T) - 1)

func start_cling() -> void:
	P.clinging = true
	P.crawling = false
	P.h = TUNE.crawl_h
	P.vx = 0.0
	P.vy = 0.0

func update_cling(dt: float, dir: int) -> bool:
	if held("down"):                    # let go - top stays at the duct, then fall
		P.clinging = false
		P.h = TUNE.stand_h
		P.vy = 0.0
		return false
	if dir != 0:
		P.facing = dir
	jump_queued = false
	P.move_t = P.move_t + dt if dir != 0 and (P.vx == 0 or signf(P.vx) == dir) else 0.0
	var nx := P.x + dir * TUNE.cling * dt
	P.vx = dir * TUNE.cling * ramp(P.move_t, TUNE.ramp_cling) if dir != 0 and grip_over(nx) and not rect_hits(nx, P.y, P.w, P.h) else 0.0
	P.x += P.vx * dt
	P.walk_phase += absf(P.vx) * dt * 0.12
	P.cover = -1
	P.hidden = false
	P.running = false
	P.on_ground = false
	P.lean = 0.0
	return true                         # silent: shimmying makes no noise

func update_player(dt: float) -> void:
	var dir := (1 if held("right") else 0) - (1 if held("left") else 0)
	if aiming:                              # throw mode: hold still and face the cursor (ducking still works)
		dir = 0
		jump_queued = false
		P.facing = 1 if aim_target().x >= P.x + P.w / 2 else -1
	if P.clinging and update_cling(dt, dir):
		return
	if P.flip_sw >= 0:
		update_flip(dt)
		return
	var want_crawl := held("down")
	if want_crawl and P.on_ground and not P.crawling:
		P.y += TUNE.stand_h - TUNE.crawl_h
		P.h = TUNE.crawl_h
		P.crawling = true
	elif not want_crawl and P.crawling and can_stand():
		P.y -= TUNE.stand_h - TUNE.crawl_h
		P.h = TUNE.stand_h
		P.crawling = false
	P.running = not held("walk") and not P.crawling       # running is the default; Shift sneaks
	if dir != 0:
		P.facing = dir
	var max_v: float = TUNE.crawl if P.crawling else (TUNE.run if P.running else TUNE.walk)
	# pushing the same way (or starting from still) builds the ramp; letting go or turning resets it
	P.move_t = P.move_t + dt if dir != 0 and (P.vx == 0 or signf(P.vx) == dir) else 0.0
	if not P.on_ground:
		P.vx = move_toward(P.vx, dir * max_v, TUNE.accel_air * dt)        # air control unchanged
	elif dir == 0 or signf(P.vx) == -dir:
		P.vx = move_toward(P.vx, 0.0, TUNE.decel * dt)                    # ease to a stop / slow before turning
	else:
		var ramp_s: float = TUNE.ramp_crawl if P.crawling else (TUNE.ramp_run if P.running else TUNE.ramp_walk)
		P.vx = move_toward(P.vx, dir * max_v * ramp(P.move_t, ramp_s), TUNE.accel_ground * dt)

	P.coyote = TUNE.coyote if P.on_ground else P.coyote - dt
	P.jump_buf = TUNE.jump_buffer if jump_queued else P.jump_buf - dt
	jump_queued = false
	if P.jump_buf > 0 and P.coyote > 0 and not P.crawling:
		P.vy = -TUNE.jump_v
		P.jump_buf = 0.0
		P.coyote = 0.0
	if not held("jump") and P.vy < 0:
		P.vy += TUNE.gravity * TUNE.jump_cut * dt
	P.vy = minf(P.vy + TUNE.gravity * dt, TUNE.max_fall)

	# move X, then Y, resolving against tiles
	P.x += P.vx * dt
	if rect_hits(P.x, P.y, P.w, P.h):
		# stairs: a one-tile step at your feet is walked up, not bumped into
		var up := floorf((P.y + P.h - 0.001) / T) * T - P.h
		if P.on_ground and not P.crawling and P.y - up <= T + 0.5 and not rect_hits(P.x, up, P.w, P.h):
			P.y = up
		else:
			P.x = floorf((P.x + P.w - 0.001) / T) * T - P.w if P.vx > 0 else (floorf(P.x / T) + 1) * T
			P.vx = 0.0
	var was_on_ground := P.on_ground
	var impact_v := P.vy
	P.on_ground = false
	P.y += P.vy * dt
	if rect_hits(P.x, P.y, P.w, P.h):
		if P.vy > 0:
			P.y = floorf((P.y + P.h - 0.001) / T) * T - P.h
			P.on_ground = true
			P.vy = 0.0
		else:
			P.y = (floorf(P.y / T) + 1) * T
			P.vy = 0.0
			if grip_over(P.x) and not held("down"):   # head hits a duct: grab on
				start_cling()
				return
	# a hard landing is loud unless you're sneaking (Shift)
	if P.on_ground and not was_on_ground and impact_v > TUNE.land_noise_v and not held("walk"):
		make_noise(P.x + P.w / 2, P.y + P.h, NOISE.land)

	# hiding: ducked behind furniture with your middle inside its footprint
	var mid := P.x + P.w / 2
	P.cover = -1
	if P.on_ground:
		for i in props.size():
			var p: Dictionary = props[i]
			if PROP_W.has(p.type) and absf(p.y - (P.y + P.h)) < 2 and mid > p.x * T + 4 and mid < p.x * T + PROP_W[p.type] - 4:
				P.cover = i
				break
	P.hidden = P.cover >= 0 and P.crawling
	# walk up to a lever and the ninja pulls it himself
	if P.on_ground and not P.crawling:
		for i in switches.size():
			var sw: Dictionary = switches[i]
			if not sw.on and absf(mid - (sw.x * T)) < 14 and absf(P.y + P.h - sw.row * T) < 4:
				P.flip_sw = i
				P.flip_t = 0.0
				P.vx = 0.0
				P.lean = 0.0
				break

	var moving := absf(P.vx) > 8
	var prev_phase := P.walk_phase
	P.walk_phase += absf(P.vx) * dt * (0.12 if P.crawling else 0.075)
	# running footsteps are loud; sneaking and crawling are silent
	if P.running and P.on_ground and absf(P.vx) > 150 and floori(P.walk_phase / TAU) != floori(prev_phase / TAU):
		make_noise(mid, P.y + P.h, NOISE.run)
	var lean_to := 0.0 if (P.crawling or not moving) else P.facing * (0.18 if P.running else 0.06)
	P.lean = move_toward(P.lean, lean_to, dt * 1.5)

# headband tails - a little verlet chain
func neck() -> Vector2:
	var cx := P.x + P.w / 2
	var by := P.y + P.h
	if P.clinging:
		return Vector2(cx + P.facing * 9, P.y + 11)
	if P.crawling:
		return Vector2(cx + P.facing * 9, by - 11)
	return Vector2(cx - P.facing * 5, by - 39)

func reset_scarf() -> void:
	scarf_pos.clear()
	scarf_prev.clear()
	var n := neck()
	for i in 7:
		var p := Vector2(n.x - P.facing * i * 5, n.y)
		scarf_pos.append(p)
		scarf_prev.append(p)

func update_scarf() -> void:
	scarf_pos[0] = neck()
	for i in range(1, scarf_pos.size()):
		var v := (scarf_pos[i] - scarf_prev[i]) * 0.92
		scarf_prev[i] = scarf_pos[i]
		scarf_pos[i] += v + Vector2(-P.facing * 0.15, 0.12 + sin(time * 7 + i) * 0.06)
	for k in 3:
		for i in range(1, scarf_pos.size()):
			var dv := scarf_pos[i] - scarf_pos[i - 1]
			var d := maxf(dv.length(), 0.0001)
			scarf_pos[i] -= dv * ((d - 5) / d)

# =====================================================================
#  DETECTION
# =====================================================================
func sample_points() -> Array:
	var cx := P.x + P.w / 2
	return [Vector2(cx, P.y + 5), Vector2(cx, P.y + P.h * 0.5), Vector2(cx, P.y + P.h - 4)]

# Behind furniture no light reaches you - except the torch of a guard who saw you duck there.
func light_reaches_hidden(L: Lt) -> bool:
	return L.guard != null and L.guard.knows_hide == P.cover

func update_detection(dt: float) -> void:
	var pts := sample_points()
	var e := 0.0
	var fill_amt := 0.0
	for L in all_lights():
		if P.hidden and not light_reaches_hidden(L):
			continue
		var s := 0.0
		for p in pts:
			s += light_at(L, p)
		s /= pts.size()
		e += s
		fill_amt += s * L.danger
	exposure = minf(1.0, e)
	var hunted := false
	for g in guards:
		if g.state == "chase" or (g.state == "search" and g.hunting_you):
			hunted = true
	if exposure > TUNE.exposed_threshold:
		meter += fill_amt * TUNE.fill_rate * dt
		calm = 0.0
	elif not hunted:
		calm += dt
		if calm > TUNE.drain_delay:
			meter = maxf(0.0, meter - TUNE.drain_rate * dt)
	P.vis = move_toward(P.vis, exposure, dt * 6)
	if meter >= 1.0:
		meter = 1.0
		state = "caught"
		state_t = 0.0

# Cameras: their sweeping beam fills the meter like any light (hiding beats it). Seeing you also
# calls the nearest awake guard over to where you were standing.
func update_cameras() -> void:
	var px := P.x + P.w / 2
	for L in lights:
		if L.kind != "camera":
			continue
		var s := 0.0
		if not P.hidden:
			for p in sample_points():
				s += light_at(L, p)
		L.seeing = s > 0.05
		if L.seeing and time - L.alarm_t > 1.5:
			L.alarm_t = time
			var best = null
			var best_d := INF
			for g in guards:
				var d: float = absf(g.x - px) + absf(g.y - (P.y + P.h)) * 2
				if g.state != "asleep" and d < best_d:
					best_d = d
					best = g
			if best != null:
				hear(best, px)

# =====================================================================
#  NOISE + STONES - noise is a circle; any awake guard inside it (with a clear line) goes to look
# =====================================================================
func make_noise(x: float, y: float, r: float) -> void:
	y -= 6                                   # lift off the floor so the floor doesn't swallow it
	var n := NoiseEvent.new()
	n.x = x
	n.y = y
	n.r = r
	n.poly = visibility_polygon(Vector2(x, y), r)
	noises.append(n)
	for g in guards:
		if g.state != "asleep" and Vector2(g.x - x, g.y - 30 - y).length() < r and not blocked(Vector2(x, y), Vector2(g.x, g.y - 30)):
			hear(g, x)

func hear(g: Guard, x: float) -> void:
	if g.state == "chase" and time - g.seen_t < 0.1:
		return                               # he's looking right at you already
	g.state = "investigate"
	g.invest_x = x

# Aim at the mouse. Pick the throw that lands on it; if that needs more than max_speed it's
# out of range, and you throw as hard as you can toward it (the arc shows where that lands).
func aim_target() -> Vector2:
	if mouse_seen:
		return mouse_world
	return Vector2(P.x + P.w / 2 + P.facing * 8 * T, P.y + P.h)

func aim_throw() -> Dictionary:
	var tgt := aim_target()
	var side := 1 if tgt.x >= P.x + P.w / 2 else -1
	var o := Vector2(P.x + P.w / 2 + side * 8, P.y + (8.0 if P.crawling else (12.0 if P.clinging else 14.0)))
	var dv := tgt - o
	var t := clampf(dv.length() / 450.0, 0.25, 0.8)
	var v := Vector2(dv.x / t, dv.y / t - 0.5 * STONE.gravity * t)
	var in_range := v.length() <= STONE.max_speed
	if not in_range:
		v = v.normalized() * STONE.max_speed
	return {"side": side, "o": o, "v": v, "in_range": in_range, "tgt": tgt}

func throw_stone() -> void:
	if state != "play" or stone_count <= 0:
		return
	var a := aim_throw()
	stone_count -= 1
	P.facing = a.side
	var s := Stone.new()
	s.x = a.o.x
	s.y = a.o.y
	s.vx = a.v.x
	s.vy = a.v.y
	stones.append(s)

# One physics step for a flying stone (used by the real stone AND the aim preview). True on impact.
func stone_step(s: Stone, dt: float) -> bool:
	var hit := false
	s.vy += STONE.gravity * dt
	s.x += s.vx * dt
	if solid_px(s.x, s.y):
		s.x -= s.vx * dt
		s.vx *= -0.35
		hit = true
	s.y += s.vy * dt
	if solid_px(s.x, s.y):
		s.y -= s.vy * dt
		hit = true
		if s.vy > 0:
			if s.vy < 160:
				s.resting = true
				s.vx = 0.0
				s.vy = 0.0
				s.y = (floorf(s.y / T) + 1) * T - STONE.r
			else:
				s.vy *= -0.3
				s.vx *= 0.6
		else:
			s.vy = 0.0
	return hit

func predict_path(a: Dictionary) -> Dictionary:
	var s := Stone.new()
	s.x = a.o.x
	s.y = a.o.y
	s.vx = a.v.x
	s.vy = a.v.y
	var pts := PackedVector2Array()
	for i in 120:
		if stone_step(s, 1.0 / 60.0):
			break
		if i % 2 == 1:
			pts.append(Vector2(s.x, s.y))
	return {"pts": pts, "end": Vector2(s.x, s.y)}

func clack(s: Stone) -> void:
	if not s.clacked:
		s.clacked = true
		make_noise(s.x, s.y, NOISE.stone)

func update_stones(dt: float) -> void:
	var px := P.x + P.w / 2
	var feet := P.y + P.h
	for s in stones:
		if s.resting:
			if stone_count < STONE.max and absf(s.x - px) < 14 and absf(s.y - feet) < 12:
				s.taken = true
				stone_count += 1
			continue
		if stone_step(s, dt):
			clack(s)
	stones = stones.filter(func(s): return not s.taken)
	for n in noises:
		n.t += dt
	noises = noises.filter(func(n): return n.t < 0.6)

# =====================================================================
#  GUARDS - a guard's torch is just a moving light
#  Patrol → (torch finds you) Chase → (lost you) Search → Return → Patrol
#  Patrol → (hears a noise / finds a sleeping guard) Investigate → Search
#  Land on one who can't see you → Asleep, torch off, for good.
# =====================================================================
func make_guard(d: Dictionary, idx: int) -> Guard:
	var g := Guard.new()
	g.x = d.x * T
	g.y = d.row * T
	g.from_x = d["from"] * T
	g.to_x = d["to"] * T
	g.min_x = d.min_x * T + 12
	g.max_x = d.max_x * T - 12
	if torch_pool.size() <= idx:
		torch_pool.append(make_light("torch", Vector2(g.x, g.y - 32), 0.0, GUARD.torch_spread,
			GUARD.torch_radius, 1.0, STOPS_LAMP, GUARD.danger))
	g.torch = torch_pool[idx]
	g.torch.level = 1.0
	g.torch.guard = g
	g.torch.pos = Vector2(g.x + 14, g.y - 32)            # the torch is reused: aim it fresh for this run
	g.torch.dir = g.aim
	g.torch.node.position = g.torch.pos
	g.torch.node.rotation = g.torch.dir
	return g

func guard_sees(g: Guard) -> bool:
	if g.state == "asleep" or (P.hidden and g.knows_hide != P.cover):
		return false
	var s := 0.0
	for p in sample_points():
		s += light_at(g.torch, p)
	return s > 0.05

func update_guard(g: Guard, dt: float) -> void:
	if g.state == "asleep":
		if time - g.sleep_t < GUARD.wake_after:
			return
		g.alert = true                                    # wakes up angry
		g.torch.level = g.torch.intensity
		g.state = "search"
		g.hunting_you = false
		g.search_start = time
		g.search_facing = g.facing
	var px := P.x + P.w / 2
	if guard_sees(g):
		g.seen_t = time
		g.last_seen = px
		g.state = "chase"
	var seeing := time - g.seen_t < 0.1
	# a sleeping colleague in his torch puts him on alert
	if not seeing:
		for o in guards:
			if o.state == "asleep" and not o.found and light_at(g.torch, Vector2(o.x, o.y - 8)) > 0.05:
				o.found = true
				g.alert = true
				hear(g, o.x)
	var boost: float = GUARD.alert_speed if g.alert else 1.0
	var target = null
	var speed: float = GUARD.walk * boost
	if g.state == "patrol":
		if g.pause > 0:
			g.pause -= dt
		else:
			target = g.to_x if g.facing > 0 else g.from_x
			if absf(target - g.x) < 2:
				g.facing *= -1
				g.pause = GUARD.end_pause
				target = null
	elif g.state == "chase" or g.state == "investigate":
		var chasing := g.state == "chase"
		speed = (GUARD.chase if chasing else GUARD.investigate) * boost
		target = clampf(g.last_seen if chasing else g.invest_x, g.min_x, g.max_x)
		if seeing and absf(px - g.x) < 30:
			target = null                                 # standing over you
		elif not seeing and absf(target - g.x) < 6:
			g.state = "search"
			g.hunting_you = chasing
			g.search_start = time
			g.search_facing = g.facing
			target = null
	elif g.state == "search":
		g.facing = g.search_facing * (-1 if floori((time - g.search_start) / 1.3) % 2 == 1 else 1)
		if time - g.search_start > (GUARD.alert_search if g.alert else GUARD.search_time):
			g.state = "return"
	elif g.state == "return":
		target = clampf(g.x, g.from_x, g.to_x)
		if absf(target - g.x) < 2:
			g.state = "patrol"
	g.moving = false
	var dx: float = clampf(target, g.min_x, g.max_x) - g.x if target != null else 0.0
	if absf(dx) > 1:
		var d := 1 if dx > 0 else -1
		g.move_t = g.move_t + dt if d == g.facing else 0.0              # turning around restarts the ramp
		g.facing = d
		var v := speed * ramp(g.move_t, GUARD.ramp)
		v = minf(v, sqrt(2.0 * GUARD.decel * absf(dx)) + 5.0)          # ease into the stop
		g.x += d * minf(absf(dx), v * dt)
		g.phase += v * dt * 0.08
		g.moving = true
		g.cur_v = v
	else:
		g.move_t = 0.0
		g.cur_v = 0.0
	# torch: level-ish on patrol, on you in a chase, sweeping in a search
	var tp := Vector2(g.x + g.facing * 14, g.y - 32)
	var aim := 0.15
	if g.state == "chase" and seeing:
		aim = clampf(atan2(P.y + P.h / 2 - tp.y, absf(px - tp.x)), -0.6, 0.7)
	elif g.state == "search":
		aim = 0.1 + sin(time * 2.2) * 0.35
	g.aim = lerpf(g.aim, aim, 1 - exp(-dt * 6))
	var L := g.torch
	L.pos = tp
	L.dir = g.aim if g.facing > 0 else PI - g.aim
	L.node.position = L.pos
	L.node.rotation = L.dir

func update_guards(dt: float) -> void:
	# The hiding rule: duck while a guard has you in his torch (or just did) and he knows the spot.
	if P.hidden and not P.was_hidden:
		for g in guards:
			if time - g.seen_t < GUARD.saw_you_hide:
				g.knows_hide = P.cover
	if not P.hidden:
		for g in guards:
			g.knows_hide = -1
	P.was_hidden = P.hidden
	# takedown: come down on a guard who can't see you
	if not P.on_ground and P.vy > 0:
		for g in guards:
			if g.state == "asleep" or time - g.seen_t < 0.15:
				continue
			if P.x < g.x + 11 and P.x + P.w > g.x - 11 and P.y < g.y and P.y + P.h > g.y - 62:
				takedown(g)
	for g in guards:
		update_guard(g, dt)

func takedown(g: Guard) -> void:
	g.state = "asleep"
	g.sleep_t = time
	g.torch.level = 0.0
	g.moving = false
	P.vy = -320.0                                         # spring off him
	make_noise(g.x, g.y - 10, NOISE.thud)                 # the thud can bring the other guard

# =====================================================================
#  STEP / FRAME
# =====================================================================
func _physics_process(dt: float) -> void:
	time += dt
	state_t += dt
	for L in lights:
		update_light(L, time)
	for L in torch_pool:
		update_light(L, time)
	if state == "title":
		cam.x = (0.5 - 0.5 * cos(time * 0.04)) * (LW * T - VIEW_W)
		return
	if state != "play":
		return
	update_player(dt)
	update_stones(dt)
	update_scarf()
	update_guards(dt)
	update_detection(dt)
	update_cameras()
	level_t += dt
	var target := clampf(P.x + P.w / 2 - VIEW_W * 0.45 + P.facing * 70, 0, LW * T - VIEW_W)
	cam.x = lerpf(cam.x, target, 1 - exp(-dt * 4))
	var target_y := clampf(P.y + P.h / 2 - VIEW_H * 0.55, 0, LH * T - VIEW_H)   # tall floors scroll vertically
	cam.y = lerpf(cam.y, target_y, 1 - exp(-dt * 3))
	if state == "play" and P.x + P.w > exit_x and absf(P.y + P.h - exit_row * T) < T:
		state = "escaped"
		state_t = 0.0

func _process(dt: float) -> void:
	fps = lerpf(fps, 1.0 / maxf(dt, 0.001), 0.05)
	camera.position = cam.round()
	mouse_world = get_global_mouse_position()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if state == "play" else Input.MOUSE_MODE_VISIBLE
	var hb := 0.0
	if state != "title" and meter > 0.5:
		hb = (meter - 0.5) * 2 * (0.5 + 0.5 * sin(time * (6 + meter * 6)))
	post_mat.set_shader_parameter("heartbeat", hb)
	post_mat.set_shader_parameter("seed", randf() * 100.0)
	for n in draw_nodes:
		n.queue_redraw()
	hud.queue_redraw()
	if _capture.has("capture"):
		_frame += 1
		if _frame == int(_capture.get("frames", "30")):
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(_capture.capture)
			get_tree().quit()

# Dev tool: put the game in a known spot for a screenshot.
func _capture_setup(setup: String) -> void:
	match setup:
		"title":
			open_menu("title")
		"about", "controls", "quit":
			open_menu("title")
			menu_page = setup
		"pause":
			start_run()
			P.x = 13.2 * T
			open_menu("pause")
			menu_sel = 2
		"floor2":
			start_run(1)
			P.x = 3 * T
			level_t = 1.0
		"catwalk":
			start_run(1)
			P.x = 56 * T
			P.y = 10 * T - P.h
		"camera":
			start_run(1)
			P.x = 84 * T
			guards[3].x = 104 * T
		"floor3":
			start_run(2)
			P.x = 24 * T
			level_t = 9.0
		"stairs":
			start_run(2)
			P.x = 35 * T
			P.y = 17 * T - P.h
			level_t = 9.0
		"lever":
			start_run(2)
			P.x = 96.5 * T - 9                  # right at the lever: the pull starts on the first frame
			P.y = 12 * T - P.h
			P.facing = 1
			level_t = 9.0
		"lamp":
			start_run()
			P.x = 13.2 * T
		"chase":
			start_run()
			P.x = 54 * T
			guards[0].x = 49 * T
		"cling":
			start_run()
			P.x = 63.5 * T
			P.y = 12 * T
			start_cling()
			guards[1].x = 64 * T
		"moon":
			start_run()
			P.x = 49 * T
			guards[0].x = 57 * T
			guards[0].facing = -1
	if state == "play":
		reset_scarf()
		cam.x = clampf(P.x + P.w / 2 - VIEW_W * 0.45 + P.facing * 70, 0, LW * T - VIEW_W)

# Dev tool: replays the scenarios verified in the HTML version and prints what happened.
#   godot_console --headless --path . -- --selftest=1
func _run(frames: int) -> void:
	for i in frames:
		_physics_process(1.0 / 60.0)

func _selftest() -> void:
	var out := {}
	test_keys = {}
	# hiding under the first lamp
	start_run()
	P.x = 14 * T + 26
	_run(10)
	out["lamp: standing exposure"] = snappedf(exposure, 0.01)
	test_keys = {"down": true}
	_run(30)
	out["lamp: ducked behind desk"] = "hidden=%s exposure=%.2f" % [P.hidden, exposure]
	# cling: jump into the tutorial duct
	start_run()
	test_keys = {}
	P.x = 20 * T
	_run(5)
	jump_queued = true
	test_keys = {"jump": true}
	_run(30)
	out["duct: jumped in"] = "clinging=%s y=%d" % [P.clinging, P.y]
	# a patrolling guard walks under a clinging ninja; then drop on him
	start_run()
	test_keys = {}
	guards[0].x = 47 * T
	guards[1].x = 72 * T
	P.x = 53 * T
	P.y = 12 * T
	start_cling()
	var seen := false
	for i in 60 * 8:
		_run(1)
		if guards[0].state == "chase":
			seen = true
		if absf(guards[0].x - (P.x + P.w / 2)) < 6:
			break
	test_keys = {"down": true}
	_run(2)
	test_keys = {}
	_run(30)
	out["duct: guard walked under, seen?"] = seen
	out["duct: drop takedown"] = "%s, torch level %.0f" % [guards[0].state, guards[0].torch.level]
	# stone lure: thrown from behind a desk past a guard
	start_run()
	guards[0].x = 47 * T
	guards[0].facing = -1
	P.x = 40 * T + 26
	P.y = 15 * T - TUNE.crawl_h
	P.h = TUNE.crawl_h
	P.crawling = true
	P.facing = 1
	test_keys = {"down": true}
	_run(2)
	mouse_seen = true
	mouse_world = Vector2(52 * T, 15 * T - 2)
	throw_stone()
	var seq := [guards[0].state]
	var max_m := 0.0
	for i in 60 * 16:
		_run(1)
		max_m = maxf(max_m, meter)
		if seq[-1] != guards[0].state:
			seq.append(guards[0].state)
	out["stone: guard"] = " > ".join(seq)
	out["stone: max meter / state"] = "%.2f / %s" % [max_m, state]
	# noise: running behind a guard vs sneaking
	for keys in [{"right": true}, {"right": true, "walk": true}]:
		start_run()
		test_keys = keys
		guards[0].x = 50 * T
		guards[0].facing = 1
		P.x = guards[0].x - 180
		_run(45)
		out["noise: " + ("sneak" if keys.has("walk") else "run") + " behind guard"] = guards[0].state
	# walls block sound
	test_keys = {}
	start_run()
	guards[1].x = 64 * T
	guards[1].pause = 99
	make_noise(72 * T, 15 * T, 400)
	out["sound: open floor 256px"] = guards[1].state
	start_run()
	guards[1].x = 86 * T
	guards[1].pause = 99
	make_noise(76.5 * T, 15 * T, 400)
	out["sound: behind raised floor 304px"] = guards[1].state
	# aim preview matches the real stone
	start_run()
	P.x = 41 * T
	mouse_world = Vector2(49 * T, 15 * T - 2)
	var a := aim_throw()
	var pred: Vector2 = predict_path(a).end
	throw_stone()
	var s: Stone = stones[0]
	while not stone_step(s, 1.0 / 60.0):
		pass
	out["aim: predicted vs actual landing x"] = "%.1f vs %.1f" % [pred.x, s.x]
	# the speed ramp: run from a standstill, then let go
	start_run()
	P.x = 39 * T
	test_keys = {"right": true}
	var curve := []
	for i in 36:
		_run(1)
		if i % 6 == 5:
			curve.append(int(P.vx))
	out["ramp: run speed every 0.1s"] = curve
	test_keys = {}
	var x_stop := P.x
	var frames := 0
	while P.vx > 0 and frames < 120:
		_run(1)
		frames += 1
	out["ramp: stop from a run"] = "%.2fs, slid %dpx" % [frames / 60.0, P.x - x_stop]
	guards[0].x = 45 * T
	guards[0].facing = 1
	guards[0].pause = 0.0
	guards[0].move_t = 0.0
	var gcurve := []
	var gx: float = guards[0].x
	for i in 60:
		_run(1)
		if i % 15 == 14:
			gcurve.append(int((guards[0].x - gx) * 4))
			gx = guards[0].x
	out["ramp: guard speed every 0.25s"] = gcurve
	test_keys = null
	for k in out:
		print("  ", k, ": ", out[k])

# Dev tool: throw mode - Ctrl toggles it, the mouse only throws inside it, and it ends after one throw.
#   godot_console --headless --path . -- --selftest=throwmode
func _selftest_throw_mode() -> void:
	var press := func(code):
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.pressed = true
		_unhandled_input(ev)
	var click := func():
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		_unhandled_input(ev)
	start_run()
	test_keys = {}
	P.x = 41 * T
	mouse_seen = true
	mouse_world = Vector2(47 * T, 15 * T - 2)
	click.call()
	print("  click outside throw mode -> stones left: ", stone_count)
	press.call(KEY_CTRL)
	print("  ctrl -> aiming: ", aiming)
	test_keys = {"right": true}
	var x0 := P.x
	_run(20)
	print("  holding D while aiming -> moved px: ", P.x - x0)
	click.call()
	print("  click in throw mode -> stones left: ", stone_count, ", still aiming: ", aiming)
	press.call(KEY_CTRL)
	press.call(KEY_CTRL)
	print("  ctrl twice -> aiming: ", aiming)
	test_keys = {"jump": true}
	press.call(KEY_W)
	_run(5)
	print("  W jumps -> on ground: ", P.on_ground)
	test_keys = null

# Dev tool: menus - keyboard navigation, Esc pause/resume, About/Controls pages.
#   godot_console --headless --path . -- --selftest=menu
func _selftest_menu() -> void:
	var press := func(code):
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.pressed = true
		_unhandled_input(ev)
	open_menu("title")
	print("  title items: ", menu_items())
	press.call(KEY_DOWN)
	press.call(KEY_ENTER)
	print("  ↓ + Enter -> page: ", menu_page)
	press.call(KEY_ESCAPE)
	print("  Esc -> page: '", menu_page, "', state: ", state)
	press.call(KEY_UP)
	press.call(KEY_UP)
	print("  ↑ ↑ wraps -> selected: ", menu_items()[menu_sel])
	press.call(KEY_DOWN)
	press.call(KEY_SPACE)
	print("  New Game -> state: ", state, ", ninja shown: ", state == "play")
	_run(10)
	var x0 := P.x
	press.call(KEY_ESCAPE)
	print("  Esc in play -> state: ", state, ", items: ", menu_items())
	test_keys = {"right": true}
	_run(30)
	print("  paused: holding D moved px: ", P.x - x0)
	test_keys = null
	press.call(KEY_ESCAPE)
	print("  Esc again -> state: ", state)
	press.call(KEY_ESCAPE)
	press.call(KEY_ENTER)
	print("  Esc, Enter on Resume -> state: ", state)
	state = "caught"
	press.call(KEY_ESCAPE)
	print("  caught + Esc -> state: ", state)
	menu_sel = menu_items().find("Levels")
	press.call(KEY_ENTER)
	print("  Levels -> page: ", menu_page, ", floors listed: ", Levels.LEVELS.size())
	press.call(KEY_DOWN)
	press.call(KEY_DOWN)
	press.call(KEY_ENTER)
	print("  ↓ ↓ Enter -> ", state, " on ", level.name, " (", level.subtitle, ")")

# Dev tool: the "Are you sure?" quit page.  godot_console --headless --path . -- --selftest=quit
func _selftest_quit() -> void:
	var press := func(code):
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.pressed = true
		_unhandled_input(ev)
	open_menu("title")
	menu_sel = menu_items().find("Quit")
	press.call(KEY_ENTER)
	print("  Quit -> page: ", menu_page, ", default: ", "No" if quit_sel == 0 else "Yes")
	press.call(KEY_ENTER)
	print("  Enter on No -> page: '", menu_page, "', still running: ", not get_tree().is_queued_for_deletion())
	menu_sel = menu_items().find("Quit")
	press.call(KEY_ENTER)
	press.call(KEY_RIGHT)
	print("  → -> selected: ", "No" if quit_sel == 0 else "Yes")
	press.call(KEY_ESCAPE)
	print("  Esc -> page: '", menu_page, "'")


# Dev tool: floor 2 - transition, the route up to the catwalk, cameras.
#   godot_console --headless --path . -- --selftest=floor2
func _selftest_floor2() -> void:
	var press := func(code):
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.pressed = true
		_unhandled_input(ev)
	test_keys = {}
	start_run(0)
	P.x = exit_x
	_run(2)
	print("  floor 1 exit -> state: ", state)
	press.call(KEY_ENTER)
	print("  Enter -> ", level.name, " (", level.subtitle, "), width ", LW, ", guards ", guards.size(), ", lights ", lights.size())
	# the climb: floor -> crate -> crate -> catwalk, one held jump each
	var tops := []
	for step in [[47.6, 15], [49.6, 13], [51.1, 12]]:
		P.x = step[0] * T
		P.y = step[1] * T - P.h
		P.vx = 0.0
		P.vy = 0.0
		P.move_t = 0.0
		test_keys = {"right": true, "jump": true}
		jump_queued = true
		for i in 50:
			_run(1)
			if P.on_ground and i > 5:
				break
		test_keys = {}
		tops.append("x%.1f row %.0f" % [(P.x + P.w / 2) / T, (P.y + P.h) / T])
	print("  climb landings: ", tops)
	print("  catwalk guard stands on row: ", guards[1].y / T)
	# camera: standing in its sweep vs hidden behind the cooler under it
	var cam_l: Lt = null
	for L in lights:
		if L.kind == "camera":
			cam_l = L
	start_run(1)
	for L in lights:                       # the floor was reloaded: find its camera again
		if L.kind == "camera":
			cam_l = L
	guards[3].x = 108 * T
	P.x = 90 * T
	var seen_t := -1.0
	for i in 60 * 7:
		_run(1)
		if cam_l.seeing and seen_t < 0:
			seen_t = i / 60.0
	var called := []
	for g in guards:
		if g.state == "investigate" or g.state == "search" or g.state == "chase":
			called.append(guards.find(g))
	print("  standing under the camera: seen after %.1fs, guards called: %s, meter %.2f" % [seen_t, called, meter])
	start_run(1)
	for L in lights:
		if L.kind == "camera":
			cam_l = L
	P.x = 81 * T + 4
	P.y = 15 * T - TUNE.crawl_h
	P.h = TUNE.crawl_h
	P.crawling = true
	test_keys = {"down": true}
	var ever := false
	for i in 60 * 7:
		_run(1)
		ever = ever or cam_l.seeing
	print("  hidden behind the cooler for a full sweep: seen? ", ever, ", meter %.2f" % meter)
	test_keys = null


# Dev tool: floor 3 - the whole route with the guards asleep: stairs up, the lever (pulled
# automatically), back down, under the stairs, through the door, out.
#   godot_console --headless --path . -- --selftest=floor3
func _walk(keys: Dictionary, until: Callable, max_frames := 900) -> int:
	test_keys = keys
	for i in max_frames:
		if keys.has("jump"):
			jump_queued = true
		_run(1)
		meter = 0.0                          # route test: getting there, not getting caught
		if until.call():
			test_keys = {}
			return i
	test_keys = {}
	return -1

func _sleep_all() -> void:
	for g in guards:
		g.state = "asleep"
		g.torch.level = 0.0

func _selftest_floor3() -> void:
	start_run(2)
	_sleep_all()
	print("  ", level.name, " (", level.subtitle, "): ", LW, "x", LH, " tiles, door locked: ", not doors[0].open)
	P.x = 45 * T
	_walk({"right": true}, func(): return false, 240)
	print("  walk right on the lower floor: stopped at x%.1f (the door is at 60)" % ((P.x + P.w) / T))
	start_run(2)
	_sleep_all()
	P.x = 27 * T
	_walk({"right": true}, func(): return P.on_ground and P.x > 29 * T and P.y + P.h < 24 * T - 1, 120)
	print("  onto the crate: row %.0f" % ((P.y + P.h) / T))
	_walk({"right": true, "jump": true}, func(): return P.on_ground and P.x > 31 * T and P.y + P.h <= 21 * T + 1, 60)
	print("  hop to the first step: row %.0f" % ((P.y + P.h) / T))
	var up := _walk({"right": true}, func(): return P.on_ground and P.y + P.h <= 12 * T + 1 and P.x > 41 * T)
	print("  walk up the stairs: reached row %.0f in %.1fs, camera y %.0f" % [(P.y + P.h) / T, up / 60.0, cam.y])
	var pulled := _walk({"right": true}, func(): return P.flip_sw >= 0)
	print("  walk to the lever: he starts pulling it by himself: ", pulled >= 0, ", stopped: ", absf(P.vx) < 0.01)
	var mid_anim := 0.0
	_walk({}, func():
		mid_anim = maxf(mid_anim, switches[0].anim) if switches[0].anim < 1.0 else mid_anim
		return P.flip_sw < 0, 120)
	print("  after the pull: lever on: ", switches[0].on, ", door open: ", doors[0].open, ", door tiles gone: ", grid[22 * LW + 60] == 0, ", clunk heard: ", noises.size() > 0)
	var down := _walk({"left": true}, func(): return P.on_ground and P.y + P.h >= 24 * T - 1 and P.x < 31 * T, 1500)
	print("  back down the stairs: lower floor at x%.1f after %.1fs" % [P.x / T, down / 60.0])
	var out := _walk({"right": true}, func(): return state == "escaped", 1500)
	print("  under the stairs, through the door, out: ", state, " after %.1fs" % (out / 60.0))
	test_keys = null
