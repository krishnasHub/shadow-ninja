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
const Fight := preload("res://scripts/fight.gd")

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
	"lever_reach": 48.0,                        # a lever this close (px, either side) is pulled; he steps over to it first
	# moving a desk (remembered after Floor 4): hold E / X at its end, move to push or pull. Shift: slow and silent
	"push": 70.0, "push_quiet": 35.0, "push_low": 30.0, "ramp_push": 0.5,
	"desk_gap": 10.0,                           # his middle stands this far off the desk's end, hands on it
	"desk_reach": 22.0,                         # grip a desk from this close to its end (or anywhere along it)
	"scrape_every": 0.45,                       # seconds between scrapes while it moves
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
	"reaction": 0.3,                            # lock-on: seconds before he turns to you once you're behind him
}
# Lock-on: a camera that sees you stops sweeping and follows you (at this rate, within its arc
# plus slack) until you hide, a wall cuts the line, or you leave its reach. Then it eases back.
const CAM_LOCK := {"track": 0.8, "slack": 0.3, "ease_back": 1.5}
# The alarm: a camera that spots you starts the countdown. Leave the floor or put a star through
# the alarm panel in time (once you remember the stars), or it's a lockdown: every guard on alert, hunting where you were seen.
const ALARM := {"countdown": 30.0, "lockdown": 30.0, "regroup": 5.0}
const NOISE := {"run": 150.0, "land": 120.0, "panel": 280.0, "thud": 140.0, "lever": 230.0, "rattle": 90.0,
	"glass": 300.0, "tink": 80.0, "scrape": 110.0, "shout": 320.0}
# Fighting (remembered after Floor 5) - only the watchers: no torch, they see you in the dark up close
# (sight px in front; in any light, lit_sight), can't be dropped on, and find the guards you leave asleep.
# He squares up when he's on you (engage px); or strike when you're by one (reach px). One press: a strike;
# quick presses (3 inside `quick` s): a special. His wind-up: block in it and you counter; miss it and he
# lands it - the meter jumps (`hit`) and he shouts. Worn down (each blow takes some), he's dazed: the next
# press finishes it. Moves and poses: fight.gd.
const FIGHT := {"engage": 46.0, "reach": 62.0, "sight": 64.0, "lit_sight": 300.0, "find": 70.0,
	"hit": 0.35, "quick": 0.55, "attack": [1.3, 2.4], "step": 90.0, "leave": 170.0}
# Throwing stars (remembered after Floor 3; there's nothing to throw before that): straight and fast;
# one through a lamp, a camera's lens or an alarm panel puts it out for good. Not picked up again.
const STAR := {"max": 3, "speed": 950.0, "range": 700.0, "gravity": 1400.0}

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
	var grip := -1           # the desk (index into props) he's gripping, -1 = none
	var grip_on := false     # hands on it (false while he steps over to its end)
	var grip_low := false    # gripping it ducked behind it (↓ + E): it moves, he stays hidden
	var scrape_t := 0.0
	var tuck_to := -1.0      # letting go with ↓: he slides in behind the desk, to this x

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
	var locked := false      # cameras: following you instead of sweeping
	var sweep_t := 0.0       # cameras: sweep clock (stops while locked, so the sweep resumes smoothly)
	var alarm_t := -99.0
	var broken := false      # a star put it out (lamps, cameras); back on a retry
	var broken_t := -99.0
	var shard_y := 0.0       # lamps: the floor the glass fell on
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
	var track_t := -99.0     # lock-on: last time he had you in sight (in a chase)
	var behind_since := -1.0 # lock-on: when you got behind him (-1 = you're in front)
	var last_seen := 0.0
	var knows_hide := -1
	var aim := 0.15
	var invest_x := 0.0
	var intro_to := -1.0     # the opening: where he runs in to (px), or -1
	var gest := ""           # the talk: "point" / "shrug" / "beat" (talking hands), blended in by gest_k
	var gest_k := 0.0
	var gest_x := 0.0        # where a point points (px)
	var nod := 0.0           # the talk: head bob while he speaks (px)
	var hunting_you := false
	var alert := false
	var found := false
	var found_body := false  # alert because he found a sleeping colleague (outlasts a lockdown)
	var lockdown := false    # hunting in a lockdown
	var sleep_t := 0.0
	var torch: Lt
	var kind := "guard"      # or "watcher": no torch, and you fight him
	var hp := 1.0            # a watcher's health: he fades to a dull grey as it goes; 0 = dazed
	var ko := false          # put down in a fight
	var gm := ""             # in a fight: the move his body is playing (fight.gd), and how far in
	var gt := 0.0
	var fall := 0.0          # in a fight: 0 standing .. 1 flat on his back
	var fpose: Dictionary = {}
	var next_attack := 0.0

class Star:
	var x := 0.0
	var y := 0.0
	var vx := 0.0
	var vy := 0.0
	var ang := 0.0
	var dist := 0.0
	var state := "fly"       # fly (straight) -> fall (spent, or off a lamp) -> stuck (in a wall, or on the floor)

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
var hint_a: Array = []          # each hint's fade, 0..1: they surface as you come near, like something half-remembered
const HINT_NEAR := {"x": 5.0 * 32, "y": 12.0 * 32, "in": 1.4, "out": 0.5}   # y: on the wall of the storey you stand in
var guard_defs: Array = []
var spawn := Vector2.ZERO
var exit_x := 0.0
var door_x := 0                 # tiles
var level_t := 0.0              # seconds since this floor started (drives the floor-name banner)
# Memory: what the floors before this one brought back. Abilities ("cling", "takedown", "stars"); how far
# up the scarf the colour has climbed (scarf_reach 0..1, the furthest any earlier floor reached - only
# seen in shadow, see _scarf in draw_node.gd); and at the last step the Evil Co mark ("mark").
var can := {}
var scarf_red := false          # any colour at all (scarf_reach > 0)
var scarf_reach := 0.0
var evil_mark := false
# The opening scene (Floor 1): "hide" (fade in, ~10 s to get out of sight) -> "arrive" (two guards run
# in) -> "talk" (letterbox, no control, their lines over their heads; they shut the alarm off) ->
# "leave" (they run off to search elsewhere, the bars slide away; skipped, they're just gone). Spotted
# before the talk: it's just the game, they hunt you. After the talk the lab has no guards.
var intro := ""
var intro_t := 0.0
var intro_seen := false         # the talk played this run: a retry starts after it (New Game resets it)
# The wake (s into the opening): dark until "black", the room open by "seen" (he can move), the alarm
# light and siren from "alarm", the siren full by "loud", then "footsteps. hide" at "prompt".
const WAKE := {"black": 1.5, "seen": 7.0, "alarm": 9.0, "loud": 13.0, "prompt": 11.0}
var alarm_quiet := false        # the machine's alarm light is off (they shut it off in the talk)
var talk_i := 0
var talk_t := 0.0
const TALK_GAP := 0.7          # s after a line before the next: it lifts away in the last part of this
var bars := 0.0                 # letterbox, 0..1
# The recall: a floor that follows a memory with an ability in it (cling, the stars...) opens on it. The bars come in, the camera closes in on him,
# and he says what's coming back ("in" -> "say"); a new tool flashes in at the top and drops into the
# HUD ("gift", only for one with an icon - the stars); then the camera pulls back and the bars go ("out").
# Skippable, and skipped on a retry.
var recall := ""                # "" | "in" | "say" | "gift" | "out"
var recall_t := 0.0
var recall_i := 0               # the line he's on
var recall_mem: Dictionary = {} # the memory he's recalling (the floor before's `remember`)
var recall_seen := -1           # the floor whose recall played this run: a retry starts after it
var recall_on := true           # dev tools turn it off, so tests start a floor in play
var zoom := 1.0                 # camera zoom: 1 in play, RECALL.zoom in the recall
const RECALL := {"zoom": 1.9, "in": 1.3, "gift": 2.6, "fly": 1.7}   # gift: the flash, then it flies to the HUD from "fly"
# What a remembered ability shows in the recall's flash (only the ones with a HUD icon).
const GIFTS := {"stars": {"name": "THROWING STARS", "keys": "CTRL  to throw", "pad": "hold RT  to throw"}}
var notice := ""                # a line that fades in mid-screen, e.g. "a door unlocks below."
var pad := false                # the last input came from a controller: prompts name its buttons
var pad_aim := Vector2.ZERO     # controller throw mode: where the star goes, relative to the ninja
var pad_rt := false             # right trigger held (throw mode lasts while it is)
var pad_stick := Vector2i.ZERO  # menus: the left stick's direction (one step per push)
var howto_seen := false         # the how-to-play card shows once, before the first New Game
var panels: Array = []          # {x, row, broken, broken_t}: alarm panels
var alarm := ""                 # "" | "alarm" (counting down) | "lockdown"
var alarm_left := 0.0           # seconds left of the countdown / lockdown
var alarm_x := 0.0              # where the camera saw you
var alarm_raised := false       # this run: shown on the end screen
var regroup_t := 0.0            # lockdown: guards are sent hunting again every few seconds
var run_t := 0.0                # this run's time on the floor
var best := {}                  # best clear time per floor index (saved in user://records.cfg)
var new_best := false
var notice_t := 99.0            # seconds since it was set
var static_nodes: Array = []    # drawn once per floor; redrawn when a floor loads
var level_nodes: Array = []     # this floor's lights + occluders, freed when the next one loads
var grid := PackedByteArray()
var seg_a := PackedVector2Array()
var seg_b := PackedVector2Array()
var lights: Array = []          # static lights (lamps, moon, sign)
var torch_pool: Array = []      # one torch light per guard, reused across runs
var guards: Array = []
var noises: Array = []
var stars: Array[Star] = []
var star_count := 0
var star_max := 0               # stars this floor (STAR.max unless the floor says otherwise)
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
# music (tools/make_music.py): a soft base loop always playing, and a tension layer in the same key
# that fades in as danger rises (meter, a guard hunting you, a camera on you). M toggles it.
var music_base: AudioStreamPlayer
var music_tension: AudioStreamPlayer
var music_on := true
var tension := 0.0
const MUSIC_BASE_DB := -7.0
const MUSIC_TENSION_DB := -5.0
# the meter's own sound: a heartbeat that quickens, an uneasy tone that rises, the music pulling
# back - and a sting when you're caught. These are sound effects: M only toggles the music.
const METER_AUDIO := {
	"heart_from": 0.25, "bpm_min": 70.0, "bpm_max": 150.0,   # heartbeat starts at 25% full, 70 -> 150 BPM
	"riser_from": 0.45, "riser_db": -4.0, "riser_pitch": 0.18, # the tone fades in past 45%, rising up to +18%
	"duck": 0.35,                                              # the base music dips by up to 35% at full
}
var sfx_heart: AudioStreamPlayer
var sfx_riser: AudioStreamPlayer
var sfx_caught: AudioStreamPlayer
var sfx_lever: AudioStreamPlayer
var sfx_rattle: AudioStreamPlayer
var sfx_siren: AudioStreamPlayer
var sfx_panel: AudioStreamPlayer
var sfx_whoosh: AudioStreamPlayer
var sfx_glass: AudioStreamPlayer
var sfx_tink: AudioStreamPlayer
var sfx_scrape: AudioStreamPlayer
var sfx_thud: AudioStreamPlayer
var sfx_thud_small: AudioStreamPlayer
var sfx_thud_big: AudioStreamPlayer
var sfx_shout: AudioStreamPlayer
var fight: Guard = null         # the watcher he's fighting
var nm := ""                    # the move he's playing in it ("" = squared up), and how far in
var nt := 0.0
var npose: Dictionary = {}      # his pose this frame
var presses: Array = []         # when strike was pressed: three quick ones are a special
var last_move := ""
var fx: Array = []              # blows landing: {p, t, size} - a white burst
var shake_t := -99.0
var stage_node: Node2D          # the static world layer: redrawn when a desk moves
var rattle_t := -99.0           # when a locked door was last tried
var heart_t := 0.0              # time since the last heartbeat
var last_beat := -99.0          # when it last beat (the screen's red-edge pulse follows it)
var was_caught := false

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
	_setup_music()
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=")
		if kv.size() == 2:
			_capture[kv[0]] = kv[1]
	load_records()
	load_level(0)
	start_run()
	state = "title"
	recall_on = not (_capture.has("capture") or _capture.has("selftest")) or _capture.get("selftest", "") == "recall"
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
		elif _capture.selftest == "lockon":
			_selftest_lockon()
		elif _capture.selftest == "stars":
			_selftest_stars()
		elif _capture.selftest == "alarm":
			_selftest_alarm()
		elif _capture.selftest == "intro":
			_selftest_intro()
		elif _capture.selftest == "music":
			_selftest_music()
		elif _capture.selftest == "recall":
			_selftest_recall()
		elif _capture.selftest == "push":
			_selftest_push()
		elif _capture.selftest == "fight":
			_selftest_fight()
		else:
			_selftest()
		get_tree().quit()

func _setup_music() -> void:
	var players := []
	for which in ["base", "tension"]:
		var st := AudioStreamWAV.load_from_file("res://audio/music_%s.wav" % which)   # raw file: no import step needed
		var p := AudioStreamPlayer.new()
		if st != null:
			st.loop_mode = AudioStreamWAV.LOOP_FORWARD
			st.loop_end = int(st.get_length() * st.mix_rate)
			p.stream = st
		add_child(p)
		players.append(p)
	music_base = players[0]
	music_tension = players[1]
	music_base.volume_db = MUSIC_BASE_DB
	music_tension.volume_db = -80.0
	music_base.play()                        # started together, so the two layers stay in step
	music_tension.play()
	sfx_heart = _sfx_player("heartbeat")
	sfx_riser = _sfx_player("riser", true)
	sfx_caught = _sfx_player("caught")
	sfx_lever = _sfx_player("lever")
	sfx_rattle = _sfx_player("rattle")
	sfx_panel = _sfx_player("panel")
	sfx_whoosh = _sfx_player("whoosh")
	sfx_glass = _sfx_player("glass")
	sfx_tink = _sfx_player("tink")
	sfx_scrape = _sfx_player("scrape")
	sfx_thud = _sfx_player("thud")
	sfx_thud_small = _sfx_player("thud_small")
	sfx_thud_big = _sfx_player("thud_big")
	sfx_shout = _sfx_player("shout")
	for sp in [sfx_thud, sfx_thud_small, sfx_thud_big]:
		sp.max_polyphony = 4                 # a flurry's thuds overlap
	sfx_siren = _sfx_player("siren", true)
	sfx_siren.volume_db = -9.0
	sfx_riser.volume_db = -80.0
	sfx_riser.play()

func _sfx_player(file: String, loop := false) -> AudioStreamPlayer:
	var st := AudioStreamWAV.load_from_file("res://audio/%s.wav" % file)
	var p := AudioStreamPlayer.new()
	if st != null:
		if loop:
			st.loop_mode = AudioStreamWAV.LOOP_FORWARD
			st.loop_end = int(st.get_length() * st.mix_rate)
		p.stream = st
	add_child(p)
	return p

# How much danger the music should carry, 0..1.
func music_danger() -> float:
	var d := meter * 1.3
	for g in guards:
		if g.state == "chase":
			d = maxf(d, 0.9)
		elif g.state == "search" or g.state == "investigate":
			d = maxf(d, 0.45)
	for L in lights:
		if L.kind == "camera" and L.seeing:
			d = maxf(d, 0.7)
	if alarm != "":
		d = maxf(d, 0.6)
	return clampf(d, 0.0, 1.0)

func update_music(dt: float) -> void:
	var siren_on := (alarm != "" or intro == "hide" or intro == "arrive") and state == "play"
	if siren_on != sfx_siren.playing and sfx_siren.stream != null:
		if siren_on:
			sfx_siren.play()
		else:
			sfx_siren.stop()
	if state == "pause":
		return                               # hold the mood while paused
	var target := music_danger() if state == "play" else 0.0
	tension = move_toward(tension, target, dt * (0.6 if target > tension else 0.2))   # rises quickly, settles slowly
	music_tension.volume_db = linear_to_db(maxf(tension, 0.0001)) + MUSIC_TENSION_DB
	update_meter_audio(dt)

# The meter, heard: a heartbeat that quickens and grows, a tone that rises, the music pulling back.
func update_meter_audio(dt: float) -> void:
	var playing := state == "play"
	var m := meter if playing else 0.0
	var k := clampf((m - METER_AUDIO.heart_from) / (1.0 - METER_AUDIO.heart_from), 0.0, 1.0)
	if playing and m > METER_AUDIO.heart_from:
		heart_t += dt
		if heart_t >= 60.0 / lerpf(METER_AUDIO.bpm_min, METER_AUDIO.bpm_max, k):
			heart_t = 0.0
			last_beat = time
			sfx_heart.volume_db = linear_to_db(lerpf(0.3, 1.0, k)) - 2.0
			sfx_heart.play()
	else:
		heart_t = 0.6                       # so the first beat comes soon after the meter crosses in
	var r := clampf((m - METER_AUDIO.riser_from) / (1.0 - METER_AUDIO.riser_from), 0.0, 1.0)
	sfx_riser.volume_db = linear_to_db(maxf(pow(r, 1.5), 0.0001)) + METER_AUDIO.riser_db
	sfx_riser.pitch_scale = 1.0 + METER_AUDIO.riser_pitch * r * r
	music_base.volume_db = MUSIC_BASE_DB + linear_to_db(1.0 - METER_AUDIO.duck * m)
	sfx_siren.volume_db = -9.0 + linear_to_db(maxf(wake_alarm(), 0.0001))
	if state == "caught" and not was_caught:
		sfx_caught.play()
	was_caught = state == "caught"

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
	stage_node = _add_draw("stage", self, 0)
	static_nodes.append(stage_node)
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
		switches.append({"x": sw.x, "row": sw.row, "door": sw.door, "on": false, "anim": 0.0, "on_t": -99.0})
	panels = []
	for pn in level.get("panels", []):
		panels.append({"x": pn[0], "row": pn[1], "broken": false, "broken_t": -99.0})
	props = []
	for p in level.props:
		props.append({"type": p[0], "x": float(p[1]), "y": float(p[2] * T)})
	hints = level.hints
	hint_a = []
	hint_a.resize(hints.size())
	hint_a.fill(0.0)
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
	rebuild_geometry()

# Hints are his own memory talking: each fades in while he's near it and fades away as he moves on.
func update_hints(dt: float) -> void:
	var mid := P.x + P.w / 2
	for i in hints.size():
		var h: Array = hints[i]
		var w := font_italic.get_string_size(h[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var x0: float = h[0] * T
		var dx := maxf(0.0, maxf(x0 - mid, mid - (x0 + w)))
		var up: float = P.y + P.h - h[1]
		var near: bool = dx < HINT_NEAR.x and up >= 0.0 and up < HINT_NEAR.y and not cutscene()
		hint_a[i] = move_toward(hint_a[i], 1.0 if near else 0.0, dt * (HINT_NEAR["in"] if near else HINT_NEAR.out))

# The opening scene. See `intro` above.
func intro_guards() -> Array:
	return guards.filter(func(g): return g.intro_to >= 0.0)

func update_intro(dt: float) -> void:
	bars = move_toward(bars, 1.0 if intro == "talk" or recall in ["in", "say", "gift"] else 0.0, dt * 1.6)
	if intro == "":
		return
	intro_t += dt
	var ig := intro_guards()
	var waiting := ["intro", "intro_run", "intro_talk"]
	if intro != "talk" and intro != "leave" and ig.any(func(g): return not g.state in waiting):
		intro = ""                          # they saw or heard you: no scene, just the hunt
		level_t = 0.0
		return
	match intro:
		"hide":
			if intro_t >= WAKE.prompt + level.intro.hide:
				intro = "arrive"
				for g in ig:
					g.state = "intro_run"
		"arrive":
			if ig.all(func(g): return absf(g.x - g.intro_to) < 3.0):
				intro = "talk"
				talk_i = 0
				talk_t = 0.0
				aiming = false
				P.vx = 0.0
				face_each_other(ig)
				alarm_quiet = true              # "someone turn that thing off"
		"talk":
			talk_t += dt
			var line: Array = level.intro.talk[talk_i]
			talk_body(ig, line, dt)
			if talk_t > line_dur(line) + TALK_GAP:
				next_line()
		"leave":
			if bars <= 0.0:
				intro = ""

# How long a line is up, by its length (the ~ marks don't count).
func line_dur(line: Array) -> float:
	return 1.4 + 0.05 * String(line[1]).replace("~", "").length()

# Who's talking shows in the body: the speaker nods and his free hand moves (a point, a shrug, or
# just talking hands); the other one stands and listens.
func talk_body(ig: Array, line: Array, dt: float) -> void:
	var g_line: String = line[2] if line.size() > 2 else ""
	for i in ig.size():
		var g: Guard = ig[i]
		var speaking: bool = i == line[0] and talk_t < line_dur(line)
		if speaking:
			match g_line:
				"machine", "ahead":
					g.gest = "point"
					g.gest_x = 0.0 if g_line == "machine" else LW * T
				"shrug":
					g.gest = "shrug"
				_:
					g.gest = "beat"
		g.gest_k = move_toward(g.gest_k, 1.0 if speaking else 0.0, dt * (5.0 if speaking else 3.0))
		g.nod = maxf(0.0, sin(talk_t * 11.0)) * 0.8 if speaking else 0.0

func next_line() -> void:
	talk_i += 1
	talk_t = 0.0
	if talk_i >= level.intro.talk.size():
		end_talk()

# The talk: they stop and turn to each other, torches down.
func face_each_other(ig: Array) -> void:
	var mid := 0.0
	for g in ig:
		mid += g.x / ig.size()
	for g in ig:
		g.state = "intro_talk"
		g.facing = 1 if g.x < mid else -1
		g.moving = false
		g.cur_v = 0.0
		g.aim = 0.9
		g.torch.pos = Vector2(g.x + g.facing * 14, g.y - 32)
		g.torch.dir = g.aim if g.facing > 0 else PI - g.aim
		g.torch.node.position = g.torch.pos
		g.torch.node.rotation = g.torch.dir

# skip: they're gone at once; otherwise they run off to search elsewhere.
func end_talk(skip := false) -> void:
	intro = "leave"
	intro_seen = true
	level_t = 0.0                           # now the floor's name
	for g in intro_guards():
		g.gest_k = 0.0
		g.nod = 0.0
		if skip:
			drop_guard(g)
		elif g.state == "intro_talk":
			g.state = "intro_exit"

# No control and nobody looks: the opening's talk, or a recall.
func cutscene() -> bool:
	return intro == "talk" or recall != ""

# The recall. See `recall` above.
func start_recall(mem: Dictionary) -> void:
	recall = "in"
	recall_t = 0.0
	recall_i = 0
	recall_mem = mem
	recall_seen = level_idx
	level_t = 99.0                          # the floor's name waits for it
	aiming = false

func recall_gift() -> Dictionary:           # the new tool he gets back, if it has an icon to flash
	for a in recall_mem.get("abilities", []):
		if GIFTS.has(a):
			return GIFTS[a]
	return {}

func update_recall(dt: float) -> void:
	if recall == "":
		return
	recall_t += dt
	var k := 1.0 - exp(-dt * 2.6)
	zoom = lerpf(zoom, 1.0 if recall == "out" else RECALL.zoom, k)
	match recall:
		"in":
			if recall_t >= RECALL["in"]:
				recall = "say"
				recall_t = 0.0
		"say":
			if recall_t > line_dur([0, recall_mem.say[recall_i]]) + TALK_GAP:
				next_recall_line()
		"gift":
			if recall_t >= RECALL.gift:
				end_recall()
		"out":
			if absf(zoom - 1.0) < 0.01 and bars <= 0.0:
				zoom = 1.0
				recall = ""
				level_t = 0.0                   # now the floor's name

func next_recall_line() -> void:
	recall_i += 1
	recall_t = 0.0
	if recall_i >= recall_mem.say.size():
		recall = "gift" if not recall_gift().is_empty() else "out"

func end_recall() -> void:                  # skip, or done: pull back out
	recall = "out"
	recall_t = 0.0

# A guard leaves the floor for good (the opening's two, once they've gone).
func drop_guard(g: Guard) -> void:
	g.torch.level = 0.0
	g.torch.node.enabled = false
	g.torch.guard = null
	guards.erase(g)

# The opening's wake, 0..1: how much of the room he sees, and of the sound he hears.
func wake_seen() -> float:
	if intro != "hide":
		return 1.0
	return smoothstep(WAKE.black, WAKE.seen, intro_t)

func wake_alarm() -> float:                  # the machine's alarm, light and siren, coming up
	if intro != "hide":
		return 1.0
	return smoothstep(WAKE.alarm, WAKE.loud, intro_t)

func waking() -> bool:
	return intro == "hide" and intro_t < WAKE.seen

# A camera saw you: start the countdown (unless one's running, or every panel is already dead).
func raise_alarm(x: float) -> void:
	alarm_x = x
	if alarm != "" or (not panels.is_empty() and panels.all(func(pn): return pn.broken)):
		return
	alarm = "alarm"
	alarm_left = ALARM.countdown
	alarm_raised = true
	notice = "the alarm is up. get out." if panels.is_empty() or not can.has("stars") else "the alarm is up. get out - or kill the panel."
	notice_t = 0.0

func update_alarm(dt: float) -> void:
	if alarm == "":
		return
	alarm_left -= dt
	if alarm == "alarm" and alarm_left <= 0.0:
		alarm = "lockdown"                  # too slow: every guard hunts for you
		alarm_left = ALARM.lockdown
		regroup_t = 0.0
		notice = "lockdown. stay hidden."
		notice_t = 0.0
		for g in guards:
			if g.state != "asleep":
				g.lockdown = true
				g.alert = true
	if alarm == "lockdown":
		regroup_t -= dt
		if regroup_t <= 0.0:                # keep them searching around where you were seen
			regroup_t = ALARM.regroup
			for g in guards:
				if g.lockdown and (g.state == "patrol" or g.state == "return"):
					hear(g, alarm_x + randf_range(-4.0, 4.0) * T)
		if alarm_left <= 0.0:               # it's over: they calm down and go back to their rounds
			alarm = ""
			for g in guards:
				if g.lockdown:
					g.lockdown = false
					g.alert = g.found_body

func break_panel(pn: Dictionary) -> void:
	pn.broken = true
	pn.broken_t = time
	sfx_panel.play()
	make_noise(pn.x * T, pn.row * T - 48, NOISE.panel)
	if alarm == "alarm":
		alarm = ""
		notice = "alarm off."
	else:
		notice = "the alarm panel is dead."
	notice_t = 0.0

func record_time() -> void:
	var prev: float = best.get(level_idx, INF)
	new_best = run_t < prev
	if new_best:
		best[level_idx] = run_t
		if _capture.has("selftest"):
			return                           # tests teleport to the exit: keep them out of the real records
		var cf := ConfigFile.new()
		for k in best:
			cf.set_value("best", str(k), best[k])
		cf.save("user://records.cfg")

func load_records() -> void:
	if _capture.has("selftest"):
		return
	var cf := ConfigFile.new()
	if cf.load("user://records.cfg") == OK and cf.has_section("best"):
		for k in cf.get_section_keys("best"):
			best[int(k)] = float(cf.get_value("best", k))

static func clock(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]

# Walking into a locked door: the handle rattles and you're told where its switch is.
func try_door(x: float) -> void:
	var i := floori(x / T)
	for j in range(floori(P.y / T), floori((P.y + P.h - 0.001) / T) + 1):
		if i >= 0 and i < LW and j >= 0 and j < LH and grid[j * LW + i] == DOOR:
			if time - rattle_t > 1.2:
				rattle_t = time
				sfx_rattle.play()
				make_noise(x, P.y + P.h / 2, NOISE.rattle)
			if notice_t > 2.0:
				notice = "locked."
				for sw in switches:
					var d: Dictionary = doors[sw.door]
					if not sw.on and i >= d.x and i < d.x + d.w:
						notice = "locked. the switch is upstairs." if sw.row < d.y else ("locked. the switch is downstairs." if sw.row > d.y + d.h else "locked. find its switch.")
				notice_t = 0.0
			return

# A retry starts the floor over: every lever up, every door it opened locked again.
func reset_doors() -> void:
	for sw in switches:
		sw.on = false
		sw.anim = 0.0
		sw.on_t = -99.0
	var changed := false
	for d in doors:
		if d.open:
			d.open = false
			fill(d.x, d.y, d.w, d.h, DOOR)
			changed = true
	if changed:
		rebuild_geometry()

func rebuild_geometry() -> void:
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

func update_light(L: Lt, t: float, dt: float) -> void:
	if L.sweep_amp > 0.0 and not L.locked and not L.broken:
		L.sweep_t += dt
		var to := L.base_dir + L.sweep_amp * sin(TAU * L.sweep_t / L.sweep_period)
		L.dir = move_toward(L.dir, to, CAM_LOCK.ease_back * dt)     # after a lock it eases back into the sweep
		L.node.rotation = L.dir
	if L.flicker_period > 0.0:
		var ph := fmod(t, L.flicker_period) / L.flicker_period
		var lit := ph < L.flicker_on
		if ph < 0.07:
			lit = sin(t * 90.0) > 0.2                       # sputters on
		elif ph > L.flicker_on - 0.03 and ph < L.flicker_on:
			lit = sin(t * 70.0) > 0.0
		L.level = L.intensity if lit else 0.0
	if L.kind == "alarm":
		L.level = 0.0 if alarm_quiet else L.level * minf(1.0, wake_alarm() * 3.0)
	if L.broken:
		L.level = 0.0
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
	reset_doors()
	for L in lights:
		L.locked = false
		if L.broken:                         # a retry: the lamps and cameras are back
			L.broken = false
			L.level = L.intensity
	for pn in panels:
		pn.broken = false
	alarm = ""
	alarm_raised = false
	run_t = 0.0
	new_best = false
	props = []                              # a retry: the desks are back where they were
	for p in level.props:
		props.append({"type": p[0], "x": float(p[1]), "y": float(p[2] * T)})
	stage_node.queue_redraw()
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
	stars.clear()
	fight = null
	nm = ""
	presses.clear()
	fx.clear()
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
	notice_t = 99.0
	can = {}
	scarf_reach = 0.0
	evil_mark = false
	for i in level_idx:                     # everything the floors before this one brought back
		var mem: Dictionary = Levels.LEVELS[i].get("remember", {})
		for a in mem.get("abilities", []):
			can[a] = true
		scarf_reach = maxf(scarf_reach, mem.get("scarf", 0.0))
		if "mark" in mem.get("colors", []):
			evil_mark = true
	scarf_red = scarf_reach > 0.0
	star_max = level.get("stars", STAR.max) if can.has("stars") else 0
	star_count = star_max
	intro = ""
	bars = 0.0
	alarm_quiet = false
	if level.has("intro") and intro_seen:      # a retry: the scene's over, they've gone
		alarm_quiet = true
		for g in intro_guards():
			drop_guard(g)
	elif level.has("intro"):
		intro = "hide"
		intro_t = 0.0
		level_t = 99.0                      # the floor's name waits for the scene to end
		P.facing = -1                       # facing the machine
		for g in guards:
			if g.intro_to >= 0.0:
				g.state = "intro"
				g.facing = -1
	recall = ""
	zoom = 1.0
	var prev: Dictionary = Levels.LEVELS[level_idx - 1].get("remember", {}) if level_idx > 0 else {}
	if recall_on and not prev.get("abilities", []).is_empty() and recall_seen != level_idx:   # only for something he can do
		start_recall(prev)

var test_keys = null    # self-test: a Dictionary of held keys replaces the keyboard

func held(k: String) -> bool:
	if recall != "":                        # in the recall he just stands there
		return false
	if test_keys != null:
		return test_keys.has(k)
	match k:
		"left": return Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A) \
			or joy_axis(JOY_AXIS_LEFT_X) < -0.4 or joy_btn(JOY_BUTTON_DPAD_LEFT)
		"right": return Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D) \
			or joy_axis(JOY_AXIS_LEFT_X) > 0.4 or joy_btn(JOY_BUTTON_DPAD_RIGHT)
		"jump": return Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) \
			or joy_btn(JOY_BUTTON_A)
		"down": return Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S) \
			or joy_btn(JOY_BUTTON_B) or joy_btn(JOY_BUTTON_DPAD_DOWN) or joy_axis(JOY_AXIS_LEFT_Y) > 0.7
		"grip": return Input.is_physical_key_pressed(KEY_E) or joy_btn(JOY_BUTTON_X)
		"walk": return Input.is_physical_key_pressed(KEY_SHIFT) \
			or joy_axis(JOY_AXIS_TRIGGER_LEFT) > 0.4 or joy_btn(JOY_BUTTON_LEFT_SHOULDER)
	return false

# Controllers (Xbox layout): any connected pad counts. The strongest push wins.
func joy_axis(a: int) -> float:
	var v := 0.0
	for d in Input.get_connected_joypads():
		var x := Input.get_joy_axis(d, a)
		if absf(x) > absf(v):
			v = x
	return v

func joy_btn(b: int) -> bool:
	for d in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(d, b):
			return true
	return false

func toggle_music() -> void:
	music_on = not music_on
	music_base.stream_paused = not music_on
	music_tension.stream_paused = not music_on

# A controller button, pressed. In menus the buttons stand in for keys; in play they're the controls.
func pad_button(b: int) -> void:
	if b == JOY_BUTTON_Y and in_menu():         # music: Y in a menu (in play, Y blocks in a fight)
		toggle_music()
		return
	if in_menu():
		var code: int = {JOY_BUTTON_A: KEY_ENTER, JOY_BUTTON_B: KEY_ESCAPE, JOY_BUTTON_START: KEY_ESCAPE,
			JOY_BUTTON_DPAD_UP: KEY_UP, JOY_BUTTON_DPAD_DOWN: KEY_DOWN,
			JOY_BUTTON_DPAD_LEFT: KEY_LEFT, JOY_BUTTON_DPAD_RIGHT: KEY_RIGHT}.get(b, 0)
		if code != 0 or menu_page == "howto":
			menu_key(code)
		return
	if intro == "talk" and state == "play":
		if b == JOY_BUTTON_A:
			next_line()
		elif b == JOY_BUTTON_START or b == JOY_BUTTON_B:
			end_talk(true)
		return
	if recall != "" and state == "play" and b != JOY_BUTTON_BACK:
		if b == JOY_BUTTON_A and recall == "say":
			next_recall_line()
		elif (b == JOY_BUTTON_START or b == JOY_BUTTON_B) and recall != "out":
			end_recall()
		return
	match b:
		JOY_BUTTON_X:
			if fight_ready():
				fight_strike()
		JOY_BUTTON_Y:
			if fight != null:
				fight_block()
		JOY_BUTTON_A:
			if state == "play":
				jump_queued = true
			elif state == "caught":
				start_run()
			elif state == "escaped":
				if level_idx + 1 < Levels.LEVELS.size():
					start_run(level_idx + 1)
				else:
					open_menu("title")
		JOY_BUTTON_B:
			aiming = false                  # cancels a throw
		JOY_BUTTON_BACK:
			start_run()
		JOY_BUTTON_START:
			open_menu("pause" if state == "play" else "title")

# Hold RT (or RB) to aim with the right stick; let go to throw.
func pad_throw(down: bool) -> void:
	if state != "play" or recall != "":
		return
	if down and not aiming and can_throw():
		aiming = true
		pad_aim = Vector2(P.facing * 5 * T, -T)
	elif not down and aiming:
		throw_star()
		aiming = false

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventJoypadButton:
		pad = true
		if e.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			pad_throw(e.pressed)
		elif e.pressed:
			pad_button(e.button_index)
		return
	if e is InputEventJoypadMotion:
		if absf(e.axis_value) > 0.5:
			pad = true
		if e.axis == JOY_AXIS_TRIGGER_RIGHT and (e.axis_value > 0.5) != pad_rt:
			pad_rt = e.axis_value > 0.5
			pad_throw(pad_rt)
		var sx := joy_axis(JOY_AXIS_LEFT_X)          # menus: one step per push of the stick
		var sy := joy_axis(JOY_AXIS_LEFT_Y)
		var d := Vector2i.ZERO
		if absf(sy) > 0.6:
			d.y = signi(int(signf(sy)))
		elif absf(sx) > 0.6:
			d.x = signi(int(signf(sx)))
		if d != pad_stick:
			pad_stick = d
			if in_menu() and d != Vector2i.ZERO:
				menu_key(KEY_UP if d.y < 0 else (KEY_DOWN if d.y > 0 else (KEY_LEFT if d.x < 0 else KEY_RIGHT)))
		return
	if e is InputEventKey and e.pressed and not e.echo:
		pad = false
		var code: int = e.physical_keycode
		if code == KEY_M:                   # music on / off, anywhere
			toggle_music()
			return
		if code == KEY_F11:
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
			return
		if in_menu():
			menu_key(code)
			return
		if intro == "talk" and state == "play":
			if code in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_W, KEY_UP]:
				next_line()
			elif code in [KEY_ESCAPE, KEY_P]:
				end_talk(true)
			return
		if recall != "" and state == "play" and code != KEY_R:
			if code in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_W, KEY_UP] and recall == "say":
				next_recall_line()
			elif code in [KEY_ESCAPE, KEY_P] and recall != "out":
				end_recall()
			return
		match code:
			KEY_SPACE, KEY_W, KEY_UP:
				jump_queued = true
			KEY_E, KEY_F:                   # a fight: strike (E is the grip otherwise)
				if fight_ready():
					fight_strike()
			KEY_Q:
				if fight != null:
					fight_block()
			KEY_CTRL:                       # throw mode on/off
				if state == "play":
					aiming = not aiming and can_throw()
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
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
		pad = false
		if fight != null and state == "play":
			fight_block()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		pad = false
		if in_menu():
			if menu_page == "howto":
				menu_key(KEY_ENTER)
			elif menu_page == "quit":
				var q := quit_item_at(get_viewport().get_mouse_position())
				if q >= 0:
					quit_choose(q)
			elif menu_page == "levels":
				var l := level_item_at(get_viewport().get_mouse_position())
				if l >= 0:
					intro_seen = false
					recall_seen = -1
					start_run(l)
			elif menu_page != "":
				menu_page = ""
			else:
				var i := menu_item_at(get_viewport().get_mouse_position())
				if i >= 0:
					menu_activate(i)
		elif aiming:                        # throw mode: a click throws
			throw_star()
			aiming = false                  # one throw per Ctrl
		elif state == "play" and fight_ready():   # otherwise, by a watcher: strike
			fight_strike()

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
			intro_seen = false
			recall_seen = -1
			if howto_seen:
				start_run(0)
			else:
				howto_seen = true           # the first time: how to play, then any key starts
				menu_page = "howto"
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
	if menu_page == "howto":                # any key or button: play
		menu_page = ""
		intro_seen = false
		recall_seen = -1
		start_run(0)
		return
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
				intro_seen = false
				recall_seen = -1
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

# Pulling a lever: step up to it, stand still, reach, pull it down (the handle swings), clunk - the door unlocks.
func update_flip(dt: float) -> void:
	var sw: Dictionary = switches[P.flip_sw]
	var mid := P.x + P.w / 2
	var to := clampf(mid, sw.x * T - 12, sw.x * T + 12)      # close enough for the hand to reach the knob
	if absf(to - mid) > 0.01:
		var step := move_toward(mid, to, TUNE.walk * dt) - mid
		P.x += step
		P.vx = step / dt                                      # so the legs walk
		P.facing = 1 if step > 0 else -1
		P.walk_phase += absf(P.vx) * dt * 0.075
		jump_queued = false
		return
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
		# and the player is told: a clunk you hear, the lever's light flares, a line on screen
		sw.on_t = time
		sfx_lever.play()
		var d: Dictionary = doors[sw.door]
		notice = "a door unlocks below." if d.y > sw.row else ("a door unlocks above." if d.y + d.h < sw.row else "a door unlocks.")
		notice_t = 0.0
	if P.flip_t >= TUNE.flip_time:
		P.flip_sw = -1

# Pulling, and close enough that the hand is on the knob (not still stepping over to it).
func at_lever() -> bool:
	return P.flip_sw >= 0 and absf(P.x + P.w / 2 - switches[P.flip_sw].x * T) <= 12.5

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
	if fight != null:                        # squared up: update_fight has him
		P.vx = 0.0
		P.running = false
		return
	var dir := (1 if held("right") else 0) - (1 if held("left") else 0)
	if aiming:                              # throw mode: hold still and face the cursor (ducking still works)
		dir = 0
		if pad and test_keys == null:       # controller: the right stick (or the left) aims; the push sets the range
			var st := Vector2(joy_axis(JOY_AXIS_RIGHT_X), joy_axis(JOY_AXIS_RIGHT_Y))
			if st.length() < 0.25:
				st = Vector2(joy_axis(JOY_AXIS_LEFT_X), joy_axis(JOY_AXIS_LEFT_Y))
			if st.length() > 0.25:
				pad_aim = st.normalized() * lerpf(1.5 * T, 11.0 * T, clampf((st.length() - 0.25) / 0.7, 0.0, 1.0))
		jump_queued = false
		P.facing = 1 if aim_target().x >= P.x + P.w / 2 else -1
	if P.clinging and update_cling(dt, dir):
		return
	if P.flip_sw >= 0:
		update_flip(dt)
		return
	if P.grip >= 0 and update_grip(dt, dir):
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
	if P.tuck_to >= 0.0:                    # let go of a desk with ↓: slide in behind it
		if P.crawling and absf(P.x - P.tuck_to) > 0.5 and not rect_hits(move_toward(P.x, P.tuck_to, 220.0 * dt), P.y, P.w, P.h):
			P.x = move_toward(P.x, P.tuck_to, 220.0 * dt)
			dir = 0
		else:
			P.tuck_to = -1.0
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
			try_door(P.x + P.w + 1 if P.vx > 0 else P.x - 1)
			P.vx = 0.0
	var was_on_ground := P.on_ground
	var impact_v := P.vy
	P.on_ground = false
	var feet_was := P.y + P.h
	P.y += P.vy * dt
	var desk_top := on_desk(feet_was) if P.vy >= 0.0 else -1.0
	if desk_top >= 0.0:                     # landed on (or still standing on) a desk
		P.y = desk_top - P.h
		P.on_ground = true
		P.vy = 0.0
	elif rect_hits(P.x, P.y, P.w, P.h):
		if P.vy > 0:
			P.y = floorf((P.y + P.h - 0.001) / T) * T - P.h
			P.on_ground = true
			P.vy = 0.0
		else:
			P.y = (floorf(P.y / T) + 1) * T
			P.vy = 0.0
			if can.has("cling") and grip_over(P.x) and not held("down"):   # head hits a duct: grab on (once remembered)
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
	# ducked behind a desk, hold E / X as well and he grips it low: it moves with him, and he stays hidden
	if can.has("push") and held("grip") and P.hidden and props[P.cover].type == "desk" and P.tuck_to < 0.0 and not aiming:
		P.grip = P.cover
		P.grip_on = true
		P.grip_low = true
		P.vx = 0.0
		P.move_t = 0.0
		return
	# walk up to a lever and the ninja pulls it himself
	if P.on_ground and not P.crawling:
		for i in switches.size():
			var sw: Dictionary = switches[i]
			if not sw.on and absf(mid - (sw.x * T)) < TUNE.lever_reach and absf(P.y + P.h - sw.row * T) < 4:
				P.flip_sw = i
				P.flip_t = 0.0
				P.vx = 0.0
				P.lean = 0.0
				break
	# hold E / X by a desk and he grips it (once remembered)
	if can.has("push") and held("grip") and P.on_ground and not P.crawling and not aiming and P.flip_sw < 0:
		var d := desk_near()
		if d >= 0:
			# the nearer end, unless there's no room to stand there (a desk against a wall): then the other
			var x0: float = props[d].x * T
			var near_side := 1 if mid < x0 + PROP_W.desk / 2 else -1
			for side in [near_side, -near_side]:
				var stand: float = (x0 if side > 0 else x0 + PROP_W.desk) - side * TUNE.desk_gap - P.w / 2
				if not rect_hits(stand, P.y, P.w, P.h):
					P.grip = d
					P.grip_on = false
					P.facing = side                 # he faces the desk
					P.vx = 0.0
					P.move_t = 0.0
					return

	var moving := absf(P.vx) > 8
	var prev_phase := P.walk_phase
	P.walk_phase += absf(P.vx) * dt * (0.12 if P.crawling else 0.075)
	# running footsteps are loud; sneaking and crawling are silent
	if P.running and P.on_ground and absf(P.vx) > 150 and floori(P.walk_phase / TAU) != floori(prev_phase / TAU):
		make_noise(mid, P.y + P.h, NOISE.run)
	# running: the anime lean, pitched from the hip (see dashing()); sneaking: a touch forward
	var lean_to := 0.0 if (P.crawling or not moving) else P.facing * (0.62 if dashing() else 0.06)
	P.lean = move_toward(P.lean, lean_to, dt * 2.5)

# =====================================================================
#  MOVING A DESK - grip its end (E / X), then push or pull. The light rules don't change: gripping,
#  he's standing, so a light on him fills the meter. ↓ lets go and tucks him in behind it.
#  Ducked behind it, ↓ + E grips it low: slow and silent, and no light finds him - but a camera
#  that sees a desk move raises the alarm (see update_cameras). Held still under the lens, it's furniture.
# =====================================================================
func desk_near() -> int:                    # the desk he's standing over, else one within reach of its end
	var mid := P.x + P.w / 2
	for reach in [0.0, TUNE.desk_reach]:
		for i in props.size():
			var p: Dictionary = props[i]
			if p.type == "desk" and absf(p.y - (P.y + P.h)) < 2 \
					and mid > p.x * T - reach and mid < p.x * T + PROP_W.desk + reach:
				return i
	return -1

# Once he remembers furniture moves, he uses it: a desk's top is a step to stand on (one way: walk
# through it, land on it from above). Returns the top's y if his feet crossed it this frame, else -1.
const DESK_TOP := 28.0
func on_desk(feet_was: float) -> float:
	if not can.has("push"):
		return -1.0
	for p in props:
		var top: float = p.y - DESK_TOP
		if p.type == "desk" and feet_was <= top + 0.5 and P.y + P.h >= top \
				and P.x + P.w > p.x * T + 4 and P.x < p.x * T + PROP_W.desk - 4:
			return top
	return -1.0

# Where the desk would be after moving dx: not into a wall, not off an edge, not into other furniture.
func desk_can_move(i: int, dx: float) -> bool:
	var d: Dictionary = props[i]
	var x0: float = d.x * T + dx
	var w: float = PROP_W.desk
	if rect_hits(x0, d.y - 28, w, 27) or not solid_px(x0 + 2, d.y + 1) or not solid_px(x0 + w - 2, d.y + 1):
		return false
	for j in props.size():
		var o: Dictionary = props[j]
		if j != i and PROP_W.has(o.type) and absf(o.y - d.y) < 2 and x0 < o.x * T + PROP_W[o.type] and x0 + w > o.x * T:
			return false
	return true

# The end of the desk his hands are on (he faces the desk: it's on his facing side).
func grip_end() -> float:
	var d: Dictionary = props[P.grip]
	return d.x * T if P.facing > 0 else d.x * T + PROP_W.desk

func release_grip() -> void:
	P.grip = -1
	P.grip_on = false
	P.grip_low = false
	P.move_t = 0.0

func update_grip(dt: float, dir: int) -> bool:
	if P.grip_low:
		return update_grip_low(dt, dir)
	var d: Dictionary = props[P.grip]
	var side := P.facing
	var mid := P.x + P.w / 2
	if held("down"):                        # let go and tuck in behind it
		P.tuck_to = grip_end() + side * 16 - P.w / 2
		release_grip()
		return false
	if not held("grip") or not P.on_ground or aiming:
		release_grip()
		return false
	jump_queued = false
	P.running = false
	P.cover = -1
	P.hidden = false
	if not P.grip_on:                       # step over to its end first
		var to := grip_end() - side * TUNE.desk_gap
		if absf(to - mid) > 0.5:
			var step := move_toward(mid, to, TUNE.walk * dt) - mid
			if rect_hits(P.x + step, P.y, P.w, P.h):
				release_grip()
				return false
			P.x += step
			P.vx = step / dt                # so the legs walk
			P.walk_phase += absf(P.vx) * dt * 0.075
			return true
		P.grip_on = true
		P.vx = 0.0
		P.scrape_t = TUNE.scrape_every * 0.6   # the first scrape comes soon after it starts moving
	var quiet := held("walk")
	var max_v: float = TUNE.push_quiet if quiet else TUNE.push
	P.move_t = P.move_t + dt if dir != 0 and (P.vx == 0 or signf(P.vx) == dir) else 0.0
	var v: float = dir * max_v * ramp(P.move_t, TUNE.ramp_push) if dir != 0 else 0.0
	var dx := v * dt
	if dx != 0.0 and (not desk_can_move(P.grip, dx) or rect_hits(P.x + dx, P.y, P.w, P.h)):
		dx = 0.0
		v = 0.0
	P.x += dx
	d.x += dx / T
	P.vx = v
	if dx != 0.0:
		stage_node.queue_redraw()
	P.walk_phase += absf(P.vx) * dt * 0.1
	if absf(P.vx) > 20.0 and not quiet:     # the legs scrape: guards nearby hear it
		P.scrape_t += dt
		if P.scrape_t >= TUNE.scrape_every:
			P.scrape_t = 0.0
			make_noise(d.x * T + PROP_W.desk / 2, d.y, NOISE.scrape)
			sfx_scrape.play()
	# leaning into it pushing, back from it pulling, a little in holding still
	var lean_to: float = side * 0.1
	if absf(P.vx) > 8.0:
		lean_to = side * (0.3 if signf(P.vx) == side else -0.16)
	P.lean = move_toward(P.lean, lean_to, dt * 2.5)
	return true

# Gripping it low, from behind: he crawls with it, hidden. Let go of E (or ↓) and he lets go.
func update_grip_low(dt: float, dir: int) -> bool:
	if not held("grip") or not held("down") or aiming:
		release_grip()
		return false
	var d: Dictionary = props[P.grip]
	jump_queued = false
	P.running = false
	if dir != 0:
		P.facing = dir
	P.move_t = P.move_t + dt if dir != 0 and (P.vx == 0 or signf(P.vx) == dir) else 0.0
	var v: float = dir * TUNE.push_low * ramp(P.move_t, TUNE.ramp_push) if dir != 0 else 0.0
	var dx := v * dt
	if dx != 0.0 and (not desk_can_move(P.grip, dx) or rect_hits(P.x + dx, P.y, P.w, P.h)):
		dx = 0.0
		v = 0.0
	P.x += dx
	d.x += dx / T
	P.vx = v
	if dx != 0.0:
		stage_node.queue_redraw()
	var under: float = d.x * T + PROP_W.desk / 2 - P.w / 2      # he settles in under its middle
	if absf(P.x - under) > 0.5 and not rect_hits(move_toward(P.x, under, 60.0 * dt), P.y, P.w, P.h):
		P.walk_phase += 60.0 * dt * 0.12
		P.x = move_toward(P.x, under, 60.0 * dt)
	P.walk_phase += absf(P.vx) * dt * 0.12
	P.lean = move_toward(P.lean, 0.0, dt * 2.5)
	P.cover = P.grip
	P.hidden = true
	return true

func gripping() -> bool:                     # standing at its end, hands on it
	return P.grip >= 0 and P.grip_on and not P.grip_low

func gripping_low() -> bool:                 # ducked behind it, hands up on its top
	return P.grip >= 0 and P.grip_low

func low_bob() -> float:                     # gripping low and moving it, he bobs with the shuffle
	return -absf(sin(P.walk_phase)) * 1.2 if absf(P.vx) > 1.0 else 0.0

func pushing_low() -> bool:                  # moving it from behind, hidden
	return P.grip >= 0 and P.grip_low and absf(P.vx) > 1.0

func desk_points() -> Array:                 # where a camera looks for a moving desk: its top, end to end
	var d: Dictionary = props[P.grip]
	var x0: float = d.x * T
	return [Vector2(x0 + 6, d.y - 14), Vector2(x0 + PROP_W.desk / 2, d.y - 14), Vector2(x0 + PROP_W.desk - 6, d.y - 14)]

# The anime run: flat out on the ground - legs under him, the body pitched forward from the hip.
func dashing() -> bool:
	return P.on_ground and P.running and absf(P.vx) > 200.0 and not P.crawling and not P.clinging

# headband tails - a little verlet chain
func neck() -> Vector2:
	var cx := P.x + P.w / 2
	var by := P.y + P.h
	if fight != null and not npose.is_empty():
		return Fight.rig(cx, by, P.facing, npose, Fight.NB).neck
	if P.clinging:
		return Vector2(cx + P.facing * 9, P.y + 11)
	if gripping_low():
		return Vector2(cx + P.facing * 5, by - 18 + low_bob())
	if P.crawling:
		return Vector2(cx + P.facing * 9, by - 11)
	var n := Vector2(cx - P.facing * 5, by - 39)
	if dashing():                            # the neck goes with the pitched body
		var hip := Vector2(cx, by - 15)
		n = hip + (n - hip).rotated(P.lean)
	elif gripping():                         # leaning into (or back from) a desk, from the feet
		n = Vector2(cx, by) + (n - Vector2(cx, by)).rotated(P.lean)
	return n

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
		if L.danger <= 0.0 or (P.hidden and not light_reaches_hidden(L)):
			continue                         # (danger 0: lights that can't catch you, like the vial machine's alarm)
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

# Cameras: their sweeping beam fills the meter like any light (hiding beats it). Seeing you locks
# them on (they follow you) and calls the nearest awake guard over to where you were standing.
func update_cameras(dt: float) -> void:
	var px := P.x + P.w / 2
	var torso: Vector2 = sample_points()[1]
	for L in lights:
		if L.kind != "camera":
			continue
		if L.broken:
			L.seeing = false
			continue
		if L.locked:
			var target: Vector2 = desk_points()[1] if P.hidden and pushing_low() else torso
			var a: float = (target - L.pos).angle()
			var keep: bool = (not P.hidden or pushing_low()) and L.pos.distance_to(target) < L.radius and not blocked(L.pos, target) \
				and absf(wrapf(a - L.base_dir, -PI, PI)) <= L.sweep_amp + CAM_LOCK.slack
			if keep:
				L.dir += clampf(wrapf(a - L.dir, -PI, PI), -CAM_LOCK.track * dt, CAM_LOCK.track * dt)
				L.node.rotation = L.dir
			else:
				L.locked = false
		var s := 0.0
		if not P.hidden:
			for p in sample_points():
				s += light_at(L, p)
		elif pushing_low():                    # hidden, but a desk on the move: the camera sees that
			for p in desk_points():
				s += light_at(L, p)
		L.seeing = s > 0.05
		if L.seeing and L.sweep_amp > 0.0:
			L.locked = true
		if L.seeing:
			raise_alarm(px)
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
#  NOISE + STARS - noise is a circle; any awake guard inside it (with a clear line) goes to look
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

# Aim at the mouse (or, in controller throw mode, the right stick). The star leaves his hand on
# whichever side the target is.
func aim_target() -> Vector2:
	if pad and aiming:
		return Vector2(P.x + P.w / 2, P.y + P.h / 2) + pad_aim
	if mouse_seen:
		return mouse_world
	return Vector2(P.x + P.w / 2 + P.facing * 8 * T, P.y + P.h)

func aim_throw() -> Dictionary:
	var tgt := aim_target()
	var side := 1 if tgt.x >= P.x + P.w / 2 else -1
	var o := Vector2(P.x + P.w / 2 + side * 8, P.y + (8.0 if P.crawling else (12.0 if P.clinging else 14.0)))
	return {"side": side, "o": o, "tgt": tgt}

# Throw mode needs something to throw: nothing until the stars come back, nothing once they're gone.
func can_throw() -> bool:
	return can.has("stars") and star_count > 0

func breakable(L: Lt) -> bool:
	return (L.kind == "lamp" or L.kind == "camera") and not L.broken

# Does a star at p go through L? Lamps: the bulb under the shade. Cameras: the housing.
func star_hits(L: Lt, p: Vector2) -> bool:
	var c: Vector2 = L.pos + (Vector2(0, 4) if L.kind == "lamp" else Vector2.ZERO)
	return p.distance_to(c) < (12.0 if L.kind == "lamp" else 13.0)

# Where a star thrown along dir from o goes: the light it would put out, the alarm panel it would kill,
# or where it bites into a wall, or where it's spent. Used for the aim line and checked again in flight.
func star_trace(o: Vector2, dir: Vector2, max_d: float) -> Dictionary:
	var d := 0.0
	while d < max_d:
		var p := o + dir * d
		if solid_px(p.x, p.y):
			return {"end": p - dir * 4.0, "light": null, "panel": null, "wall": true}
		for L in lights:
			if breakable(L) and star_hits(L, p):
				return {"end": p, "light": L, "panel": null, "wall": false}
		var pn = panel_at(p)
		if pn != null:
			return {"end": p, "light": null, "panel": pn, "wall": false}
		d += 4.0
	return {"end": o + dir * max_d, "light": null, "panel": null, "wall": false}

# A live alarm panel at p (it sits on the wall at chest height), or null.
func panel_at(p: Vector2):
	for pn in panels:
		if not pn.broken and absf(p.x - pn.x * T) < 9 and absf(p.y - (pn.row * T - 48)) < 11:
			return pn
	return null

func star_aim() -> Dictionary:
	var a := aim_throw()
	var dir: Vector2 = (a.tgt - a.o).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(P.facing, 0)
	a["dir"] = dir
	a["trace"] = star_trace(a.o, dir, STAR.range)
	return a

func throw_star() -> void:
	if state != "play" or star_count <= 0:
		return
	var a := star_aim()
	star_count -= 1
	P.facing = a.side
	var st := Star.new()
	st.x = a.o.x
	st.y = a.o.y
	st.vx = a.dir.x * STAR.speed
	st.vy = a.dir.y * STAR.speed
	stars.append(st)
	sfx_whoosh.play()

# A star through a lamp or a camera: out for good (this run). Glass is loud - whoever hears it comes
# to look where it fell.
func break_light(L: Lt) -> void:
	L.broken = true
	L.broken_t = time
	L.locked = false
	L.seeing = false
	L.level = 0.0
	var y: float = L.pos.y + 8
	while y < LH * T and not solid_px(L.pos.x, y):
		y += 4.0
	L.shard_y = y
	if L.kind == "lamp":
		sfx_glass.play()
		make_noise(L.pos.x, y, NOISE.glass)
		notice = "glass. someone will come to look."
	else:
		L.dir = PI / 2 + 0.5 * (1 if L.base_dir < PI / 2 else -1)   # the lens droops
		L.node.rotation = L.dir
		sfx_panel.play()
		make_noise(L.pos.x, y, NOISE.thud)
		notice = "the camera's blind."
	notice_t = 0.0

func update_stars(dt: float) -> void:
	for st in stars:
		match st.state:
			"fly":
				st.ang += dt * 30.0
				var step := Vector2(st.vx, st.vy) * dt
				var n := ceili(step.length() / 4.0)
				for i in n:
					var p := Vector2(st.x, st.y) + step * ((i + 1.0) / n)
					if solid_px(p.x, p.y):
						st.state = "stuck"             # bites into the wall
						sfx_tink.play()
						make_noise(st.x, st.y, NOISE.tink)
						break
					var hit = null
					for L in lights:
						if breakable(L) and star_hits(L, p):
							hit = L
					var pn = panel_at(p)
					st.x = p.x
					st.y = p.y
					if hit != null or pn != null:
						if hit != null:
							break_light(hit)
						else:
							break_panel(pn)            # a star through the alarm panel kills it
						st.state = "fall"              # through the glass, and down
						st.vx *= 0.15
						st.vy = -80.0
						break
				st.dist += step.length()
				if st.state == "fly" and st.dist > STAR.range:
					st.state = "fall"                  # spent
					st.vx *= 0.3
					st.vy *= 0.3
			"fall":
				st.ang += dt * 18.0
				st.vy += STAR.gravity * dt
				var nx: float = st.x + st.vx * dt
				var ny: float = st.y + st.vy * dt
				if solid_px(nx, ny):
					st.state = "stuck"
					sfx_tink.play()
				else:
					st.x = nx
					st.y = ny

func update_noises(dt: float) -> void:
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
	g.intro_to = d.get("intro_to", -1.0) * T if d.has("intro_to") else -1.0
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
	g.kind = d.get("kind", "guard")
	if g.kind == "watcher":
		g.torch.level = 0.0                  # no torch: he sees with his eyes
	return g

# Lock-on: in a chase he keeps you in sight while you're in his torch's reach with a clear line
# (and not hidden where he didn't see you go), even when you slip out of the beam for a moment.
func guard_tracks(g: Guard) -> bool:
	if g.state != "chase" or (P.hidden and g.knows_hide != P.cover):
		return false
	var torso: Vector2 = sample_points()[1]
	var eye := Vector2(g.x, g.y - 34)
	return eye.distance_to(torso) < GUARD.torch_radius and not blocked(eye, torso)

func guard_sees(g: Guard) -> bool:
	if g.kind == "watcher":
		return watcher_sees(g)
	if g.state == "asleep" or g.state == "intro_exit" or (P.hidden and g.knows_hide != P.cover):
		return false
	var s := 0.0
	for p in sample_points():
		s += light_at(g.torch, p)
	return s > 0.05

func update_guard(g: Guard, dt: float) -> void:
	if g.state == "fight":                           # update_fight has him
		return
	if g.state == "asleep" and g.ko:
		return
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
	var lit := guard_sees(g)
	if lit:
		g.seen_t = time
		g.state = "chase"
	if lit or guard_tracks(g):
		g.track_t = time
		# you got behind him: he turns after a beat (a quick hop over him buys you that beat)
		if signf(px - g.x) == g.facing or absf(px - g.x) < 4:
			g.behind_since = -1.0
		elif g.behind_since < 0:
			g.behind_since = time
		if g.behind_since < 0 or time - g.behind_since > GUARD.reaction:
			g.last_seen = px
	var seeing := time - g.track_t < 0.1 and g.state == "chase"
	# a watcher on you, up close: he squares up
	if g.kind == "watcher" and seeing and fight == null and can.has("fight") and P.on_ground and not P.clinging \
			and absf(px - g.x) < FIGHT.engage and absf(g.y - (P.y + P.h)) < 8:
		start_fight(g)
		return
	# a sleeping colleague in his torch puts him on alert
	if not seeing:
		for o in guards:
			if o.state == "asleep" and not o.found and light_at(g.torch, Vector2(o.x, o.y - 8)) > 0.05:
				o.found = true
				g.alert = true
				g.found_body = true
				hear(g, o.x)
			elif g.kind == "watcher" and o.state == "asleep" and not o.found and absf(o.y - g.y) < 8 \
					and absf(o.x - g.x) < FIGHT.find and signf(o.x - g.x) == g.facing:
				o.found = true                       # a watcher finds him: wakes him, and the alarm goes up
				g.alert = true
				g.found_body = true
				raise_alarm(o.x)
				if not o.ko:
					o.state = "search"
					o.alert = true
					o.hunting_you = false
					o.search_start = time
					o.search_facing = o.facing
					o.torch.level = o.torch.intensity
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
		if seeing and absf(px - g.x) < (70.0 if g.kind == "watcher" and fight != null else 30.0):
			target = null                                 # standing over you (a watcher waits his turn)
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
	elif g.state == "intro_run":                    # the opening: running in to the machine
		speed = GUARD.chase * 1.6                    # running: something's been stolen
		target = g.intro_to
	elif g.state == "intro_exit":                   # gone to search elsewhere: off the floor
		speed = GUARD.chase * 1.6
		target = g.max_x
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
		aim = clampf(atan2(P.y + P.h / 2 - tp.y, absf(px - tp.x)), -1.0, 1.1)
	elif g.state == "search":
		aim = 0.1 + sin(time * 2.2) * 0.35
	g.aim = lerpf(g.aim, aim, 1 - exp(-dt * (10.0 if g.state == "chase" and seeing else 6.0)))
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
	if not P.on_ground and P.vy > 0 and can.has("takedown"):
		for g in guards:
			if g.state == "asleep" or g.kind == "watcher" or time - g.seen_t < 0.15:
				continue                                      # (a watcher looks up: no dropping on him)
			if P.x < g.x + 11 and P.x + P.w > g.x - 11 and P.y < g.y and P.y + P.h > g.y - 62:
				takedown(g)
	for g in guards:
		update_guard(g, dt)
	for g in guards.filter(func(g): return g.state == "intro_exit" and (g.x > cam.x + VIEW_W + 40 or g.x >= g.max_x - 2)):
		drop_guard(g)

func takedown(g: Guard) -> void:
	g.state = "asleep"
	g.sleep_t = time
	g.torch.level = 0.0
	g.moving = false
	P.vy = -320.0                                         # spring off him
	make_noise(g.x, g.y - 10, NOISE.thud)                 # the thud can bring the other guard

# =====================================================================
#  FIGHTING - the watchers (Floor 6 on). Two tracks play fight.gd's moves: his (nm, nt) and the watcher's
#  (g.gm, g.gt). A strike sets both - he strikes, the watcher reels. His wind-up sets both too; a block in
#  it turns both into the counter. A hop back is his alone: the watcher's punch lands on air.
# =====================================================================
# No torch: in the dark he sees you up close in front of him; in any light, further. Not behind him.
func watcher_sees(g: Guard) -> bool:
	if g.state in ["asleep", "intro_exit", "fight"] or (P.hidden and g.knows_hide != P.cover):
		return false
	var torso: Vector2 = sample_points()[1]
	var eye := Vector2(g.x, g.y - 52)
	var dx := torso.x - eye.x
	if (signf(dx) != g.facing and absf(dx) > 6.0) or absf(g.y - (P.y + P.h)) > 40.0 or blocked(eye, torso):
		return false
	return absf(dx) < FIGHT.sight or (exposure > TUNE.exposed_threshold and absf(dx) < FIGHT.lit_sight)

func watcher_near() -> Guard:                 # a watcher you could strike from where you stand
	if not P.on_ground or P.clinging:
		return null
	var px := P.x + P.w / 2
	for g in guards:
		if g.kind == "watcher" and g.state != "asleep" and absf(g.x - px) < FIGHT.reach and absf(g.y - (P.y + P.h)) < 8:
			return g
	return null

func fight_ready() -> bool:
	return state == "play" and recall == "" and can.has("fight") and (fight != null or watcher_near() != null)

func start_fight(g: Guard) -> void:
	if P.crawling:
		if not can_stand():
			return
		P.y -= TUNE.stand_h - TUNE.crawl_h
		P.h = TUNE.stand_h
		P.crawling = false
	release_grip()
	P.tuck_to = -1.0
	fight = g
	g.state = "fight"
	g.seen_t = time
	g.moving = false
	g.cur_v = 0.0
	g.gm = ""
	g.next_attack = randf_range(0.7, 1.2)
	g.facing = 1 if P.x + P.w / 2 > g.x else -1
	P.facing = -g.facing
	P.vx = 0.0
	P.lean = 0.0
	aiming = false
	nm = ""
	presses.clear()

func end_fight() -> void:
	if fight != null and fight.state == "fight":
		fight.state = "chase"                    # you got away from him: after you
		fight.last_seen = P.x + P.w / 2
		fight.track_t = time
	fight = null
	nm = ""

func start_move(name: String) -> void:
	nm = name
	nt = 0.0
	if not Fight.MOVES[name].g.is_empty():
		fight.gm = name
		fight.gt = 0.0
	if name in Fight.STRIKES or name in Fight.SPECIALS:
		last_move = name

# Where his feet would be after a move that carries him dx px (toward the watcher) - if he can stand there.
func lands_ok(dx: float) -> bool:
	var x := P.x + P.facing * dx
	return not rect_hits(x, P.y, P.w, P.h) and solid_px(x + P.w / 2, P.y + P.h + 2)

func fight_strike() -> void:
	if fight == null:
		var w := watcher_near()
		if w == null:
			return
		start_fight(w)
		if fight == null:
			return
	var g := fight
	if g.gm in ["late", "counter", "getup"] or nm in ["late", "counter", "finish", "hop", "over"] or nm in Fight.SPECIALS:
		return                                   # his swing, his fall, or a move of yours that isn't done
	presses = presses.filter(func(t): return time - t < FIGHT.quick)
	presses.append(time)
	if g.hp <= 0.0:                              # dazed: finish it
		if nm == "":
			start_move("finish")
		return
	if presses.size() >= 3:                      # quick: a special, cutting the strike short
		presses.clear()
		var pool: Array = Fight.SPECIALS.filter(func(m): return m != last_move and (m != "vault" or lands_ok(52.0)))
		start_move(pool[randi() % pool.size()])
		return
	if nm == "":
		var pool: Array = Fight.STRIKES.filter(func(m): return m != last_move)
		start_move(pool[randi() % pool.size()])

func fight_block() -> void:                    # in his wind-up: the counter
	var g := fight
	var tell: Array = Fight.MOVES.late.tell
	if g != null and g.gm == "late" and nm == "late" and g.gt >= tell[0] and g.gt <= tell[1]:
		g.gm = "counter"
		nm = "counter"

func fight_jump(dir: int) -> void:             # a short hop back; toward him, over him
	if nm != "" and not (nm == "late" and nt < 1.0):
		return
	if dir == P.facing and lands_ok(64.0):
		start_move("over")
	elif lands_ok(36.0 * -1.0) or lands_ok(-20.0):
		nm = "hop"                               # his alone: whatever the watcher's doing goes on
		nt = 0.0

func hit_fx(p: Vector2, size: float) -> void:
	fx.append({"p": p, "t": time, "size": size})
	(sfx_thud_big if size >= 1.5 else (sfx_thud_small if size < 1.0 else sfx_thud)).play()
	if size >= 1.5:
		shake_t = time

func knock_out(g: Guard) -> void:
	g.state = "asleep"
	g.ko = true
	g.sleep_t = time
	g.gm = ""
	g.fall = 1.0
	g.moving = false
	make_noise(g.x, g.y - 10, NOISE.thud)        # he hits the floor: it carries a little
	if fight == g:
		fight = null
		nm = ""

func update_fight(dt: float) -> void:
	var g := fight
	if g == null:
		return
	var px := P.x + P.w / 2
	if absf(g.x - px) > FIGHT.leave or absf(g.y - (P.y + P.h)) > 16:
		end_fight()
		return
	if jump_queued:
		jump_queued = false
		fight_jump((1 if held("right") else 0) - (1 if held("left") else 0))
	# the blows land as their moment comes: on him from his track, on you from his (if you're still there)
	if g.gm != "":
		var M: Dictionary = Fight.MOVES[g.gm]
		var was := g.gt
		g.gt += dt
		for sp in M.get("sparks", []):
			if sp[1] != "g" and sp[0] > was and sp[0] <= g.gt and nm == g.gm:
				hit_fx(Vector2(px + P.facing * sp[2], P.y + P.h + sp[3]), sp[4])
				if sp[1] == "n":                 # he lands it: the meter jumps, and he shouts
					meter = minf(1.0, meter + FIGHT.hit)
					calm = 0.0
					sfx_shout.play()
					make_noise(g.x, g.y - 40, NOISE.shout)
	if nm != "":
		var M: Dictionary = Fight.MOVES[nm]
		var was := nt
		nt += dt
		for sp in M.get("sparks", []):
			if sp[1] == "g" and sp[0] > was and sp[0] <= nt and g.gm == nm:
				g.hp = maxf(0.0, g.hp - Fight.damage(sp[4]))
				hit_fx(Vector2(g.x - g.facing * sp[2], g.y + sp[3]), sp[4])
		if nt >= Fight.track_end(M.n):           # done: he stays where it left him (a hop, over the watcher)
			var last := Fight.pose(Fight.NP, M.n[-1][1])
			if last.dx != 0.0 and lands_ok(last.dx):
				P.x += P.facing * last.dx
			if last.spin > 0.5:
				P.facing = -P.facing
			nm = ""
	if g.gm != "":
		var M: Dictionary = Fight.MOVES[g.gm]
		var falls: Array = M.get("fall", [])
		if g.gt >= maxf(Fight.track_end(M.g), Fight.track_end(falls)):
			var down := Fight.num_at(falls, g.gt) > 0.5
			if Fight.pose(Fight.GP, M.g[-1][1]).spin > 0.5:
				g.facing = -g.facing             # he turned round to face you
			if down and g.hp <= 0.0:
				knock_out(g)
				return
			g.gm = "getup" if down and g.gm != "getup" else ""
			g.gt = 0.0
			g.next_attack = randf_range(FIGHT.attack[0], FIGHT.attack[1])
	px = P.x + P.w / 2
	# between moves: face each other, he keeps his distance, and now and then he swings
	if g.gm == "" and nm == "":
		g.facing = 1 if px > g.x else -1
		P.facing = -g.facing
		var want := clampf(px + P.facing * Fight.GAP, g.min_x, g.max_x)
		g.x = move_toward(g.x, want, FIGHT.step * dt)
		if g.hp > 0.0 and absf(g.x - want) < 4.0:
			g.next_attack -= dt
			if g.next_attack <= 0.0:
				start_move("late")
	# the poses, for drawing
	var stand := "dazed" if g.hp <= 0.0 else "stance"
	npose = Fight.pose_at(Fight.MOVES[nm].n, Fight.NP, nt, "stance") if nm != "" else Fight.pose(Fight.NP, "stance")
	if npose.name == "stance" or npose.name == "block":
		npose.lift += sin(time * 7.0) * 0.7      # light on his feet
	var GM: Dictionary = Fight.MOVES[g.gm] if g.gm != "" else {}
	g.fpose = Fight.pose_at(GM.g, Fight.GP, g.gt, stand) if g.gm != "" else Fight.pose(Fight.GP, stand)
	g.fall = Fight.num_at(GM.get("fall", []), g.gt) if g.gm != "" else 0.0
	if g.fpose.name == "dazed":
		g.fpose.tilt += sin(time * 3.1) * 0.09   # swaying
	fx = fx.filter(func(e): return time - e.t < 0.3)

# His pose a moment ago (speed lines), or now.
func npose_at(t: float) -> Dictionary:
	if nm == "":
		return Fight.pose(Fight.NP, "stance")
	return Fight.pose_at(Fight.MOVES[nm].n, Fight.NP, maxf(t, 0.0), "stance")

# Where the watcher's tell is, if he's winding up (0..1 how strong), else 0.
func tell_k() -> float:
	if fight == null or not (fight.gm in ["late", "counter"]):
		return 0.0
	var tell: Array = Fight.MOVES[fight.gm].tell
	return clampf((fight.gt - tell[0]) / 0.08, 0.0, 1.0) if fight.gt >= tell[0] and fight.gt < tell[1] else 0.0

# =====================================================================
#  STEP / FRAME
# =====================================================================
func _physics_process(dt: float) -> void:
	time += dt
	state_t += dt
	for L in lights:
		update_light(L, time, dt)
	for L in torch_pool:
		update_light(L, time, dt)
	if state == "title":
		cam.x = (0.5 - 0.5 * cos(time * 0.04)) * (LW * T - VIEW_W)
		return
	if state != "play":
		return
	update_intro(dt)
	update_recall(dt)
	if recall != "":                         # the recall: he stands there (held() is all false), nothing else moves
		update_player(dt)
	elif intro != "talk":                    # the talk is a cutscene: no control, nobody looks
		if not waking():                     # coming to: he can't move yet
			update_player(dt)
		update_noises(dt)
		update_stars(dt)
		update_guards(dt)
		update_fight(dt)
		update_detection(dt)
		update_cameras(dt)
		update_alarm(dt)
	update_scarf()
	update_hints(dt)
	if recall == "":
		run_t += dt                          # the floor's clock starts once he's back in control
	level_t += dt
	notice_t += dt
	var target := clampf(P.x + P.w / 2 - VIEW_W * 0.45 + P.facing * 70, 0, LW * T - VIEW_W)
	cam.x = lerpf(cam.x, target, 1 - exp(-dt * 4))
	var target_y := clampf(P.y + P.h / 2 - VIEW_H * 0.55, 0, LH * T - VIEW_H)   # tall floors scroll vertically
	cam.y = lerpf(cam.y, target_y, 1 - exp(-dt * 3))
	if state == "play" and P.x + P.w > exit_x and absf(P.y + P.h - exit_row * T) < T:
		state = "escaped"
		state_t = 0.0
		alarm = ""                           # out in time: the alarm stays on the floor you left
		record_time()

func _process(dt: float) -> void:
	fps = lerpf(fps, 1.0 / maxf(dt, 0.001), 0.05)
	camera.zoom = Vector2(zoom, zoom)
	if zoom > 1.001:                         # the recall: close in on him (his chest a little above centre)
		var view := Vector2(VIEW_W, VIEW_H) / zoom
		var f := Vector2(P.x + P.w / 2, P.y + P.h / 2)
		var zp := (f - view * Vector2(0.5, 0.56)).clamp(Vector2.ZERO, Vector2(LW * T, LH * T) - view)
		camera.position = cam.lerp(zp, (zoom - 1.0) / (RECALL.zoom - 1.0)).round()
	else:
		camera.position = cam.round()
	var sk := (time - shake_t) / 0.16              # a heavy blow shakes the view for a moment
	if sk >= 0.0 and sk < 1.0:
		camera.position.x += sin(time * 160.0) * 2.0 * (1.0 - sk)
	mouse_world = get_global_mouse_position()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if state == "play" else Input.MOUSE_MODE_VISIBLE
	var hb := 0.0                            # the red-edge pulse: one throb per heartbeat
	if state != "title" and meter > METER_AUDIO.heart_from:
		var k := clampf((meter - METER_AUDIO.heart_from) / (1.0 - METER_AUDIO.heart_from), 0.0, 1.0)
		hb = (0.35 + 0.65 * k) * exp(-(time - last_beat) * 5.0)
	post_mat.set_shader_parameter("heartbeat", hb)
	update_music(dt)
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
	load_level(1)                           # default setups are on the offices
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
			start_run(3)
			P.x = 3 * T
			level_t = 1.0
		"catwalk":
			start_run(3)
			P.x = 56 * T
			P.y = 10 * T - P.h
		"camera":
			start_run(3)
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
			P.x = switches[0].x * T - 9         # right at the lever: the pull starts on the first frame
			P.y = 12 * T - P.h
			P.facing = 1
			level_t = 9.0
		"dash":                                 # floor 2: running flat out (the anime run)
			start_run(1)
			test_keys = {"right": true}
		"starthrow":                            # floor 4: stars in hand, aiming at the first lamp
			start_run(3)
			P.x = 13 * T
			aiming = true
			pad = true                          # aim with the stick: the real mouse would override a set target
			for L in lights:
				if L.kind == "lamp" and absf(L.pos.x - 16.5 * T) < 4:
					pad_aim = L.pos + Vector2(0, 4) - Vector2(P.x + P.w / 2, 15 * T - TUNE.stand_h / 2)
		"push", "pull":                         # floor 5: pushing the first desk (or pulling it back)
			start_run(4)
			P.x = 7 * T
			level_t = 9.0
			test_keys = {"grip": true}
			_run(30)
			test_keys = {"grip": true, "right" if setup == "push" else "left": true}
		"creep":                                # floor 5: ducked behind the desk, moving it (↓ + E)
			start_run(4)
			props[0].x = 8.0
			P.x = 9 * T
			level_t = 9.0
			test_keys = {"down": true, "grip": true, "right": true}
		"camdesk":                              # floor 5: ducked behind a desk between bay 1's cameras
			start_run(4)
			props[0].x = 16.0
			P.x = 17 * T
			level_t = 9.0
			test_keys = {"down": true}
		"fight":                                # floor 6: a fight, a move part way (--move=jab --at=20 frames)
			_capture_fight(_capture.get("move", "jab"))
		"fighttell":                            # floor 6: his wind-up, the ticks over his head
			_capture_fight("tell")
		"climb":                                # floor 5: up on the desk pushed against the wall
			start_run(4)
			props[2].x = 52.0 - PROP_W.desk / T
			P.x = 50.5 * T
			P.y = 15 * T - DESK_TOP - P.h
			P.on_ground = true
			level_t = 9.0
		"hall":                                 # floor 5: the hall, the first desk on its way
			start_run(4)
			props[3].x = 64.0
			P.x = 63.4 * T
			level_t = 9.0
			test_keys = {"grip": true}
		"starbroken":                           # floor 4: the first lamp out, glass on the floor
			start_run(3)
			P.x = 13 * T
			for L in lights:
				if L.kind == "lamp" and absf(L.pos.x - 16.5 * T) < 4:
					break_light(L)
			star_count = 2
		"waking":                               # floor 1: the room half out of the dark
			start_run(0)
			intro_t = 4.5
		"opening":                              # floor 1: waking by the machine, told to hide
			start_run(0)
			intro_t = WAKE.prompt + 2.0
		"talk":                                 # floor 1: hidden behind the bench, the guards talking
			start_run(0)
			P.x = 5.6 * T - P.w / 2
			P.y = 15 * T - TUNE.crawl_h
			P.h = TUNE.crawl_h
			P.crawling = true
			for g in guards:
				g.x = g.intro_to
			face_each_other(intro_guards())
			alarm_quiet = true
			intro = "talk"
			talk_i = 1
			bars = 1.0
		"remember":                             # floor 2 cleared: a memory with no ability shows on the end screen
			start_run(1)
			run_t = 151.0
			state = "escaped"
			state_t = 3.0
		"scarf":                                # floor 4, under a lamp: the scarf is plain grey here
			start_run(3)
			P.x = 16.2 * T
			level_t = 9.0
		"scarfdark":                            # floor 4, in shadow, running: the scarf's tail turns maroon
			start_run(3)
			P.x = 4 * T
			level_t = 9.0
			test_keys = {"right": true, "walk": true}
		"recall", "gift":                       # floor 4 opens: he remembers the stars (mid-line / the flash)
			recall_on = true
			start_run(3)
			recall = "say" if setup == "recall" else "gift"
			recall_i = 1
			recall_t = 1.6 if setup == "recall" else 0.9
			zoom = RECALL.zoom
			bars = 1.0
		"howto":                                # the how-to-play card before the first New Game
			open_menu("title")
			menu_page = "howto"
		"alarm":                                # floor 2: the camera has you, the alarm clock runs
			start_run(3)
			P.x = 87 * T
			level_t = 9.0
		"cleared":                              # floor 2's end screen, with the alarm raised
			start_run(3)
			run_t = 83.0
			alarm_raised = true
			best[1] = 71.0
			state = "escaped"
			state_t = 3.0
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
	load_level(1)                           # these scenarios were built on the offices
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

# Dev tool: throw mode - nothing to throw before the stars; then Ctrl toggles it, the mouse only throws
# inside it, and it ends after one throw.
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
	start_run(1)
	test_keys = {}
	press.call(KEY_CTRL)
	print("  %s (no stars yet): ctrl -> aiming: %s" % [level.name, aiming])
	start_run(3)
	P.x = 9 * T
	mouse_seen = true
	mouse_world = Vector2(14 * T, 12 * T)
	click.call()
	print("  %s: click outside throw mode -> stars left: %d" % [level.name, star_count])
	press.call(KEY_CTRL)
	print("  ctrl -> aiming: ", aiming)
	test_keys = {"right": true}
	var x0 := P.x
	_run(20)
	print("  holding D while aiming -> moved px: ", P.x - x0)
	click.call()
	print("  click in throw mode -> stars left: ", star_count, ", still aiming: ", aiming)
	press.call(KEY_CTRL)
	press.call(KEY_CTRL)
	print("  ctrl twice -> aiming: ", aiming)
	test_keys = {"jump": true}
	press.call(KEY_W)
	_run(5)
	print("  W jumps -> on ground: ", P.on_ground)
	star_count = 0
	press.call(KEY_CTRL)
	print("  out of stars: ctrl -> aiming: ", aiming)
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
	print("  New Game (first time) -> page: ", menu_page, " (how to play)")
	press.call(KEY_SPACE)
	print("  any key -> state: ", state, ", ninja shown: ", state == "play")
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
	start_run(2)
	P.x = exit_x
	_run(2)
	print("  floor 3 exit -> state: ", state)
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
	start_run(3)
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
	start_run(3)
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
	print("  walk right on the lower floor: stopped at x%.1f (the door is at 60), told: '%s', rattled: %s" % [(P.x + P.w) / T, notice, rattle_t > 0])
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


# Dev tool: lock-on - a guard keeps you in sight once he's chasing; a camera follows you.
#   godot_console --headless --path . -- --selftest=lockon
# Throwing stars on Floor 4: switching, a lamp out (and heard), a camera blinded, a miss in the wall.
#   godot_console --headless --path . -- --selftest=stars
func _selftest_stars() -> void:
	test_keys = {}
	start_run(2)
	print("  %s: stars %d, can throw: %s (not remembered yet)" % [level.name, star_count, can_throw()])
	start_run(3)
	print("  %s: remembers %s, stars %d, can throw: %s" % [level.name, can.keys(), star_count, can_throw()])
	var lamp: Lt = null
	var cam_l: Lt = null
	for L in lights:
		if L.kind == "lamp" and absf(L.pos.x - 16.5 * T) < 4:
			lamp = L
		if L.kind == "camera" and absf(L.pos.x - 90.5 * T) < 4:
			cam_l = L
	P.x = 14 * T
	_run(5)
	mouse_seen = true
	mouse_world = lamp.pos + Vector2(0, 4)
	aiming = true
	var aim := star_aim()
	print("  aim line at the lamp over x16.5: would put it out: %s" % (aim.trace.light == lamp))
	throw_star()
	aiming = false
	var seen := {"noise": false}                  # (a dictionary: lambdas capture it by reference)
	var t := _walk({}, func():
		seen.noise = seen.noise or noises.size() > 0
		return lamp.broken, 60)
	print("  thrown: lamp out after %d frames, level %.1f, glass heard: %s, notice '%s', stars left %d" % [t, lamp.level, seen.noise, notice, star_count])
	_run(30)
	print("  the star fell: %s" % stars.map(func(s): return s.state))
	var g0: Guard = guards[0]
	g0.x = 23 * T
	g0.facing = 1                                 # looking away, toward his rounds
	g0.pause = 99.0
	g0.state = "patrol"
	lamp.broken = false
	lamp.level = lamp.intensity
	stars.clear()
	star_count = 2
	mouse_world = lamp.pos + Vector2(0, 4)
	aiming = true
	throw_star()
	aiming = false
	_run(20)
	print("  a guard 6 tiles off hears the glass: %s, going to x%.1f" % [g0.state, g0.invest_x / T])
	# the camera over the end of the floor: blind it from the end of the catwalk, then walk under it
	P.x = 73 * T
	P.y = 10 * T - P.h
	for g in guards:
		g.state = "asleep"
		g.sleep_t = time
		g.torch.level = 0.0
	mouse_world = cam_l.pos
	aiming = true
	var ca := star_aim()
	print("  aim line at the camera: would blind it: %s" % (ca.trace.light == cam_l))
	throw_star()
	aiming = false
	_walk({}, func(): return cam_l.broken, 60)
	P.x = 90 * T
	P.y = 15 * T - P.h
	_run(120)
	print("  camera blind: %s, sees you standing under it: %s, alarm '%s'" % [cam_l.broken, cam_l.seeing, alarm])
	star_count = 1
	mouse_world = Vector2(P.x + 300, P.y - 200)
	aiming = true
	var miss := star_aim()
	throw_star()
	aiming = false
	_run(60)
	print("  a miss: aimed at the wall (%s), the star %s at x%.1f" % [miss.trace.wall, stars[-1].state, stars[-1].x / T])
	star_count = 0
	print("  out of stars: can throw: %s" % can_throw())
	start_run()                                   # R: the same floor again
	_run(2)
	print("  retry: lamp lit again %s, camera back %s, stars %d" % [not lamp.broken and lamp.level > 0, not cam_l.broken, star_count])
	test_keys = null


func _selftest_lockon() -> void:
	test_keys = {}
	start_run(1)
	var g: Guard = guards[0]
	for o in guards:
		if o != g:
			o.state = "asleep"
			o.torch.level = 0.0
	g.facing = 1
	g.pause = 0.0
	P.y = g.y - P.h
	P.x = g.x + 110
	var spotted := _walk({}, func(): return g.state == "chase", 60)
	print("  in his torch: chasing after %d frames" % spotted)
	P.x = g.x - 70                               # hop over him: now behind his back
	_run(10)
	print("  behind him for 0.17s: still facing %+d (reaction), state %s" % [g.facing, g.state])
	_run(40)
	print("  behind him for 0.83s: facing %+d, state %s (old rule: lost you)" % [g.facing, g.state])
	P.x = g.x + 450                              # behind him again and far out of his reach (open floor)
	meter = 0.0
	var lost := _walk({}, func(): return g.state == "search", 400)
	print("  out of reach (x%.0f, he's at x%.0f): gives up and searches after %.1fs" % [P.x / T, g.x / T, lost / 60.0])
	# camera: locks on and follows; hiding breaks it; it eases back into the sweep
	start_run(3)
	_sleep_all()
	var cam_l: Lt = null
	for L in lights:
		if L.kind == "camera":
			cam_l = L
	P.x = 90 * T
	var seen := _walk({}, func(): return cam_l.locked, 60 * 7)
	var d0 := cam_l.dir
	var lit := 0
	for i in 60:                                 # walk away at sneak speed for a second
		P.x += 140.0 / 60.0
		_run(1)
		meter = 0.0
		lit += 1 if cam_l.seeing else 0
	print("  camera: locked on after %.1fs; sneaking away for 1s it followed (%.2f rad), on you %d/60 frames" % [seen / 60.0, cam_l.dir - d0, lit])
	P.x = 81 * T + 4                             # behind the cooler
	P.y = 15 * T - TUNE.crawl_h
	P.h = TUNE.crawl_h
	P.crawling = true
	test_keys = {"down": true}
	_run(2)
	print("  hidden behind the cooler: locked ", cam_l.locked)
	var max_step := 0.0
	var prev := cam_l.dir
	for i in 180:
		_run(1)
		max_step = maxf(max_step, absf(cam_l.dir - prev))
		prev = cam_l.dir
	print("  back to sweeping, smoothly: biggest step per frame %.3f rad" % max_step)
	test_keys = null


# Dev tool: the alarm - a camera raises it, a star through the panel kills it, letting it run
# out means a lockdown that ends after a while; the floor time and best time are recorded.
#   godot_console --headless --path . -- --selftest=alarm
func _selftest_alarm() -> void:
	test_keys = {}
	start_run(3)
	_sleep_all()
	P.x = 90 * T
	_walk({}, func(): return alarm != "", 60 * 7)
	print("  spotted by the camera -> alarm: '%s', %.0fs on the clock, told: '%s'" % [alarm, alarm_left, notice])
	P.x = 81 * T + 4                             # duck behind the cooler, then throw at the panel
	P.y = 15 * T - TUNE.crawl_h
	P.h = TUNE.crawl_h
	P.crawling = true
	test_keys = {"down": true}
	_run(2)
	mouse_seen = true
	mouse_world = Vector2(panels[0].x * T, panels[0].row * T - 48)
	aiming = true
	var a := star_aim()
	throw_star()
	aiming = false
	var hit := _walk({"down": true}, func(): return panels[0].broken, 120)
	print("  star from behind the cooler (aim rings the panel: %s): panel broken after %.2fs, alarm: '%s', told: '%s'" % [a.trace.panel == panels[0], hit / 60.0, alarm, notice])
	_run(60)
	print("  camera sees you again with the panel dead -> alarm: '%s'" % alarm)
	start_run(3)
	print("  retry: panel whole again: ", not panels[0].broken, ", alarm '", alarm, "'")
	# the countdown runs out: lockdown
	for g in guards:
		g.state = "patrol"
	P.x = 90 * T
	_walk({}, func(): return alarm != "", 60 * 7)
	P.x = 3 * T                                  # far away at the start, out of sight
	P.y = 15 * T - P.h
	_walk({}, func(): return alarm == "lockdown", 60 * 31)
	var hunting := []
	for g in guards:
		hunting.append("%s%s" % [g.state, "*" if g.lockdown else ""])
	print("  30s later -> '%s', told '%s'; guards: %s (* = in lockdown, alert)" % [alarm, notice, hunting])
	_walk({}, func(): return alarm == "", 60 * 31)
	_run(60 * 12)
	var after := []
	for g in guards:
		after.append("%s%s" % [g.state, "!" if g.alert else ""])
	print("  lockdown over -> alarm '%s'; 12s later guards: %s (! = still alert)" % [alarm, after])
	# floor time and best
	start_run(1)
	_run(90)
	P.x = exit_x
	_run(2)
	var t1 := run_t
	print("  offices cleared in %s, new best: %s, saved best: %s" % [clock(run_t), new_best, clock(best.get(1, -1.0))])
	start_run(1)
	_run(200)
	P.x = exit_x
	_run(2)
	print("  slower run %s -> new best: %s (best still %s)" % [clock(run_t), new_best, clock(best[1])])
	test_keys = null


# Dev tool: the recall - a floor after a memory opens on him remembering it; skippable, skipped on a retry.
#   godot_console --headless --path . -- --selftest=recall
func _selftest_recall() -> void:
	var press := func(code):
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.pressed = true
		_unhandled_input(ev)
	test_keys = {}
	start_run(0)
	print("  %s (nothing before it): recall '%s'" % [level.name, recall])
	for from in [0, 1, 2]:                         # clear Floors 1, 2, 3: Enter goes on to the next (2 has no ability)
		start_run(from)
		state = "escaped"
		press.call(KEY_ENTER)
		var x0 := P.x
		var seen := {"phases": [recall], "zoom": 1.0, "lines": 0, "stars_hidden": false}
		var t := _walk({"right": true}, func():
			if seen.phases[-1] != recall:
				seen.phases.append(recall)
			seen.zoom = maxf(seen.zoom, zoom)
			if recall == "say":
				seen.lines = maxi(seen.lines, recall_i + 1)
			return recall == "", 60 * 30)
		print("  %s: %s over %.1fs, zoom up to %.2f, %d lines, moved %dpx, meter %.2f, clock %.1fs" % [level.name,
			" > ".join(seen.phases), t / 60.0, seen.zoom, seen.lines, P.x - x0, meter, run_t])
		print("    then: zoom %.2f, bars %.2f, floor name at %.1fs, remembers %s, can throw %s" % [zoom, bars, level_t, can.keys(), can_throw()])
	press.call(KEY_R)
	print("  R (retry): recall '%s'" % recall)
	recall_seen = -1                               # as a pick from Levels does
	start_run(3)
	_run(90)
	press.call(KEY_SPACE)
	print("  space -> line %d" % recall_i)
	press.call(KEY_ESCAPE)
	var out := _walk({}, func(): return recall == "", 60 * 5)
	print("  esc -> '%s'%s, back in play %.1fs later, state %s" % ["out" if out > 0 else recall, "", out / 60.0, state])
	test_keys = null


# Dev tool: the opening scene, memory, and the lab's route.
#   godot_console --headless --path . -- --selftest=intro
func _selftest_intro() -> void:
	test_keys = {}
	start_run(0)
	print("  %s (%s): scene '%s', facing %+d, remembers %s" % [level.name, level.subtitle, intro, P.facing, can.keys()])
	P.x = 5.6 * T - P.w / 2                      # behind the bench, ducked
	_run(60)
	var dark := wake_seen()
	_run(60 * 3)
	print("  waking: 1s in, room seen %.2f; 4s in, seen %.2f, alarm %.2f; moved %s" % [dark, wake_seen(), wake_alarm(), P.x != 5.6 * T - P.w / 2])
	var talk := 240 + _walk({"down": true}, func(): return intro == "talk", 60 * 30)
	print("  hidden behind the bench: the guards arrive, the talk starts at %.1fs; hidden %s, meter %.2f" % [talk / 60.0, P.hidden, meter])
	_run(30)
	print("  in the talk: the alarm light is off: %s; facing each other: %s" % [lights.filter(func(L): return L.kind == "alarm").all(func(L): return L.level == 0.0), intro_guards().map(func(g): return g.facing)])
	var seen_lines := {}                          # (a dictionary: lambdas capture it by reference)
	var leave := _walk({"down": true}, func():
		seen_lines[talk_i] = true
		return intro != "talk", 60 * 60)
	print("  the talk: %d lines over %.1fs, bars %.2f, meter %.2f, now '%s'" % [seen_lines.size(), leave / 60.0, bars, meter, intro])
	_walk({"down": true}, func(): return intro == "", 120)
	_run(60 * 6)
	print("  after: scene over, they ran off: guards left %d, floor name showing: %s" % [guards.size(), level_t < 3.5])
	start_run(0)                                  # a retry: the scene's over, no guards, alarm off
	_run(30)
	print("  retry: scene '%s', guards %d, alarm light %.2f" % [intro, guards.size(), lights.filter(func(L): return L.kind == "alarm")[0].level])
	howto_seen = true                             # finished the talk, then New Game from the menu
	menu_activate(menu_items().find("New Game"))
	print("  New Game after the talk: scene '%s', guards %d" % [intro, guards.size()])
	intro_seen = false                            # skipped: they're gone at once
	start_run(0)
	P.x = 5.6 * T - P.w / 2
	_walk({"down": true}, func(): return intro == "talk", 60 * 30)
	end_talk(true)
	_run(1)
	print("  skipped: guards %d, alarm light %.2f" % [guards.size(), lights.filter(func(L): return L.kind == "alarm")[0].level])
	intro_seen = false
	recall_seen = -1
	start_run(0)                                  # standing in the open by the machine
	var hunt := _walk({}, func(): return intro == "", 60 * 30)
	for i in 60 * 8:
		if state != "play":
			break
		_run(1)
	print("  not hidden: the scene drops after %.1fs (%s), then: %s" % [hunt / 60.0, guards.map(func(g): return g.state), state])
	for i in Levels.LEVELS.size():
		start_run(i)
		print("  %s remembers: %s%s" % [level.name, can.keys(), "  + scarf colour to %.2f" % scarf_reach if scarf_red else ""])
	# the lab's route, guards asleep: the pipes (crawl), the crates (jump), out
	start_run(0)
	intro = ""
	_sleep_all()
	P.x = 45 * T
	_walk({"right": true}, func(): return false, 150)
	var at_pipes := (P.x + P.w) / T
	_walk({"right": true, "down": true}, func(): return P.x > 56.5 * T, 400)
	var through := P.x / T
	var out := _walk({"right": true, "jump": true}, func(): return state == "escaped", 900)
	print("  lab route: stopped at the pipes x%.1f, crawled through to x%.1f, out after %.1fs: %s" % [at_pipes, through, out / 60.0, state])
	test_keys = null


# Dev tool: music - both loops load and play; the tension layer follows danger; M toggles.
#   godot_console --headless --path . -- --selftest=music
func _selftest_music() -> void:
	print("  loops: base %.0fs, tension %.0fs, playing: %s" % [music_base.stream.get_length(), music_tension.stream.get_length(), music_base.playing and music_tension.playing])
	start_run(1)
	test_keys = {}
	for i in 120:
		_run(1)
		update_music(1.0 / 60.0)
	print("  calm: tension %.2f (%.0f dB)" % [tension, music_tension.volume_db])
	guards[0].state = "chase"
	guards[0].seen_t = time
	for i in 120:
		guards[0].seen_t = time
		guards[0].state = "chase"
		update_music(1.0 / 60.0)
	print("  a guard chasing for 2s: tension %.2f (%.0f dB)" % [tension, music_tension.volume_db])
	guards[0].state = "patrol"
	for i in 300:
		update_music(1.0 / 60.0)
	print("  safe again for 5s: tension %.2f" % tension)
	for level_m in [0.2, 0.5, 0.8, 0.98]:            # the meter, heard: beats per minute and the rising tone
		start_run(1)
		var beats := 0
		var prev := last_beat
		for i in 60 * 6:
			meter = level_m
			update_music(1.0 / 60.0)
			time += 1.0 / 60.0
			if last_beat != prev:
				beats += 1
				prev = last_beat
		print("  meter %.2f: heartbeat %d BPM, tone %.0f dB at pitch x%.2f, base music %.1f dB" % [level_m, beats * 10, sfx_riser.volume_db, sfx_riser.pitch_scale, music_base.volume_db])
	meter = 1.0
	state = "caught"
	update_music(1.0 / 60.0)
	print("  caught -> sting playing: ", sfx_caught.playing)
	start_run(1)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_M
	ev.pressed = true
	_unhandled_input(ev)
	print("  M -> music paused: ", music_base.stream_paused and music_tension.stream_paused)
	_unhandled_input(ev)
	print("  M again -> playing: ", not music_base.stream_paused)
	test_keys = null

# Moving desks (Floor 5):  godot_console --headless --path . -- --selftest=push
func _selftest_push() -> void:
	start_run(3)
	test_keys = {"grip": true}
	P.x = 7 * T
	_run(30)
	print("  %s: E by a desk grips it: %s (not remembered yet)" % [level.name, P.grip >= 0])
	start_run(4)
	print("  %s: remembers %s" % [level.name, can.keys()])
	_sleep_all()
	_break_cameras()                              # the mechanics first, with nothing watching
	var d: Dictionary = props[0]
	var x0: float = d.x
	P.x = 6 * T                                   # standing over the desk's left part
	test_keys = {"grip": true}
	_run(30)
	print("  grip: desk %d, hands on: %s, facing %d, his middle %.1f px off its end" % [P.grip, P.grip_on, P.facing, grip_end() - (P.x + P.w / 2)])
	var scrapes := func(keys: Dictionary, frames: int) -> Array:   # [desk moved px, scrapes heard]
		test_keys = keys
		var from: float = d.x
		var n := 0
		var before := noises.size()
		for i in frames:
			_run(1)
			if noises.size() > before:
				n += 1
			before = noises.size()
		return [(d.x - from) * T, n]
	var r: Array = scrapes.call({"grip": true, "right": true}, 120)
	print("  push right 2s: desk moved %.0f px, scrapes %d, lean %.2f" % [r[0], r[1], P.lean])
	r = scrapes.call({"grip": true, "right": true, "walk": true}, 120)
	print("  with SHIFT 2s: desk moved %.0f px, scrapes %d" % [r[0], r[1]])
	r = scrapes.call({"grip": true, "left": true}, 60)
	print("  pull left 1s: desk moved %.0f px, lean %.2f, still facing %d" % [r[0], P.lean, P.facing])
	var off := grip_end() - (P.x + P.w / 2)
	test_keys = {"grip": true, "down": true}
	_run(1)
	test_keys = {"down": true}
	_run(19)
	print("  ↓: let go %s, crawling %s, hidden %s behind desk %d (his hands were %.1f px off)" % [P.grip < 0, P.crawling, P.hidden, P.cover, off])
	test_keys = {}
	_run(10)
	print("  up again: standing %s, gripping %s" % [not P.crawling, P.grip >= 0])
	# ducked behind it, ↓ + E: he grips it low and moves it, hidden the whole way
	P.x = d.x * T + PROP_W.desk / 2 - P.w / 2
	test_keys = {"down": true}
	_run(10)
	test_keys = {"down": true, "grip": true}
	_run(5)
	var low := P.grip_low
	var hid := true
	var n0 := noises.size()
	var from: float = d.x
	test_keys = {"down": true, "grip": true, "right": true}
	for i in 120:
		_run(1)
		hid = hid and P.hidden
	print("  ↓ + E behind it: grips low %s, 2s moved it %.0f px, hidden all along %s, noises %d" % [low, (d.x - from) * T, hid, noises.size() - n0])
	test_keys = {"down": true}
	_run(5)
	print("  let go of E: gripping %s, still hidden %s" % [P.grip >= 0, P.hidden])
	# under a live camera: still, it's furniture; moving, it's the alarm
	for move in [false, true]:
		start_run(4)
		_sleep_all()
		props[0].x = 21.0
		P.x = 22 * T - P.w / 2
		test_keys = {"down": true}
		_run(10)
		alarm = ""                                # (he stood up in the beam for a moment, placed there)
		alarm_raised = false
		meter = 0.0
		for L in lights:
			L.locked = false
		test_keys = {"down": true, "grip": true, "right": true} if move else {"down": true, "grip": true}
		_run(600)
		print("  10s under the camera behind a desk, %s: alarm %s, meter %.2f" % ["moving it" if move else "still", alarm_raised, meter])
	# into furniture: push the second desk left until it meets the plant at x30
	var d1: Dictionary = props[2]
	release_grip()
	P.x = 39 * T
	P.y = 15 * T - P.h
	test_keys = {"grip": true, "left": true}
	_run(700)
	print("  pushed into the plant: desk's left end at x%.2f (plant's right end x%.2f)" % [d1.x, 30 + PROP_W.plant / T])
	# the wall: too high to jump, but not from a desk pushed against it
	start_run(4)
	_sleep_all()
	_break_cameras()
	var wall_top := 11.0 * T
	P.x = 50 * T
	var made := _walk({"right": true, "jump": true}, func(): return P.on_ground and P.y + P.h <= wall_top + 0.5, 240)
	print("  the wall from the floor: on top %s" % (made >= 0))
	P.x = 37 * T
	P.y = 15 * T - P.h
	test_keys = {"grip": true}
	_run(30)
	test_keys = {"grip": true, "right": true}
	_run(600)
	print("  desk pushed to the wall: its right end at x%.2f (wall at x52)" % (props[2].x + PROP_W.desk / T))
	release_grip()
	test_keys = {}
	_run(5)
	P.x = 48 * T
	made = _walk({"right": true, "jump": true}, func(): return P.on_ground and P.y + P.h <= wall_top + 0.5, 240)
	print("  onto the desk, then the wall: on top %s, at x%.1f" % [made >= 0, (P.x + P.w / 2) / T])
	# a guard who hears it comes to look
	start_run(4)
	_break_cameras()
	var g0: Guard = guards[0]
	P.x = 6 * T
	test_keys = {"grip": true}
	_run(30)
	g0.x = props[0].x * T + 35 + 90
	g0.facing = 1                                 # his back to it
	g0.state = "patrol"
	g0.pause = 99.0
	test_keys = {"grip": true, "right": true}
	var states := [g0.state]
	for i in 60:
		_run(1)
		if g0.state != states[-1]:
			states.append(g0.state)
	print("  a guard 90 px off, back turned, hears the scrape: %s" % " > ".join(states))
	# the point of it all: a desk in his beat, ducked behind - he walks right over you
	start_run(4)
	_break_cameras()
	g0 = guards[0]
	g0.min_x = 8 * T                              # (he's the hall's guard, borrowed for bay 1)
	g0.from_x = 10 * T
	props[0].x = 17.0
	P.x = 18 * T - P.w / 2
	test_keys = {"down": true}
	_run(10)
	g0.x = 27 * T
	g0.facing = -1
	g0.state = "patrol"
	g0.to_x = 14 * T
	g0.pause = 0.0
	var top := 0.0
	var passed := false
	for i in 500:
		_run(1)
		top = maxf(top, meter)
		passed = passed or g0.x < 15 * T
	print("  hidden behind a pushed desk: guard walked past %s, meter peak %.2f, his state %s" % [passed, top, g0.state])
	# is the desk needed? the lazy way through each camera bay: just run (or sneak), whatever the sweep
	var tries := {"bay 1 (run)": [3.0, 30.5, false], "bay 1 (sneak)": [3.0, 30.5, true], "the hall (run)": [55.0, 92.5, false],
		"the hall (run, guard awake)": [55.0, 92.5, false]}
	for name in tries:
		var tr: Array = tries[name]
		var outcomes := []
		for k in 8:
			start_run(4)
			if not "awake" in name:
				_sleep_all()
			P.x = tr[0] * T
			_run(k * 20)                            # a different moment in the sweeps
			meter = 0.0
			test_keys = {"right": true, "walk": true} if tr[2] else {"right": true}
			var f := 0
			while state == "play" and P.x + P.w / 2 < tr[1] * T and f < 1800:
				_run(1)
				f += 1
			outcomes.append("caught" if state == "caught" else ("%.2f%s" % [meter, " alarm" if alarm_raised else ""]))
		print("  %s without a desk: %s" % [name, outcomes])
	# the start is dark: standing about at the spawn (or by the desk) never fills the meter
	var idle := []
	for x in [3.0, 7.0, 11.0]:
		start_run(4)
		P.x = x * T
		test_keys = {}
		var peak := 0.0
		for i in 1200:
			_run(1)
			peak = maxf(peak, meter)
		idle.append("x%d %.2f" % [x, peak])
	print("  standing still for 20 s, meter peak: %s" % [idle])
	# and with one: bay 1 leapfrogged (push while the beam's away, duck when it comes near)
	var r1 := _leapfrog(0, 27.5)
	print("  bay 1 behind the desk: to x%.1f in %.1fs, ducked %d times, meter peak %.2f, caught %s" % r1)
	# the hall: two desks - push the first, then the second the rest of the way
	var r2 := _leapfrog(3, 92.5, 55.5)
	print("  the hall behind two desks: to x%.1f in %.1fs, ducked %d times, meter peak %.2f, caught %s" % r2)
	# bay 1 from behind the desk (↓ + E): crawled straight through, then stopping while a lens is on it
	for careful in [false, true]:
		var r3 := _creep(0, 27.5, careful)
		print("  bay 1 crept behind the desk%s: to x%.1f in %.1fs, alarm %s, meter peak %.2f" % [" (still under the lens)" if careful else "", r3[0], r3[1], r3[2], r3[3]])
	start_run(4)
	print("  retry: desks back at %s" % [props.filter(func(p): return p.type == "desk").map(func(p): return p.x)])
	test_keys = null

func _creep(desk: int, to_x: float, careful: bool) -> Array:
	start_run(4)
	_sleep_all()
	P.x = props[desk].x * T + PROP_W.desk / 2 - P.w / 2
	test_keys = {"down": true}
	_run(10)
	var frames := 0
	var top := 0.0
	while state == "play" and props[desk].x * T + PROP_W.desk < to_x * T and frames < 120 * 60:
		var near := false
		for L in lights:
			if L.kind == "camera" and not L.broken:
				var beam: Vector2 = L.pos + Vector2.from_angle(L.dir) * ((15 * T - L.pos.y) / sin(L.dir))
				near = near or absf(beam.x - (props[desk].x * T + PROP_W.desk / 2)) < 140.0
		test_keys = {"down": true, "grip": true} if careful and near else {"down": true, "grip": true, "right": true}
		_run(1)
		top = maxf(top, meter)
		frames += 1
	return [props[desk].x + PROP_W.desk / T, frames / 60.0, alarm_raised, top]

func _break_cameras() -> void:
	for L in lights:
		if L.kind == "camera":
			L.broken = true

# A careful player on Floor 5: grip the desk he's at and push right; duck whenever a camera's beam comes
# within reach; when the desk won't go further, walk on to the next one. Returns [x reached, s, ducks, peak, caught].
func _leapfrog(desk: int, to_x: float, from_x := -1.0) -> Array:
	start_run(4)
	_sleep_all()
	P.x = (props[desk].x if from_x < 0.0 else from_x) * T
	var ducks := 0
	var frames := 0
	var top := 0.0
	var stalled := 0
	var walk_on := 0
	while state == "play" and P.x + P.w / 2 < to_x * T and frames < 120 * 60:
		var near := false
		for L in lights:
			if L.kind == "camera" and not L.broken:
				var beam: Vector2 = L.pos + Vector2.from_angle(L.dir) * ((15 * T - L.pos.y) / sin(L.dir))
				near = near or absf(beam.x - (P.x + P.w / 2)) < 140.0
		if near:
			if not P.crawling:
				ducks += 1
			test_keys = {"down": true}
			walk_on = 0
		elif walk_on > 0:                       # on to the next desk (or the exit), quietly
			test_keys = {"right": true, "walk": true}
			walk_on -= 1
		else:
			test_keys = {"grip": true, "right": true}
		var x_was := P.x
		_run(1)
		stalled = stalled + 1 if gripping() and absf(P.x - x_was) < 0.01 and not near else 0
		if stalled > 20:                        # this desk's done: let go and move on
			stalled = 0
			walk_on = 40
		top = maxf(top, meter)
		frames += 1
	return [(P.x + P.w / 2) / T, frames / 60.0, ducks, top, state == "caught"]

# Floor 6: the watchers and the fight.
func _selftest_fight() -> void:
	start_run(5)
	print("  %s: remembers %s" % [level.name, can.keys()])
	var w: Guard
	# sight: no torch - in the dark, only up close and in front
	var seen := []
	for d in [3.0, 1.5, -1.2]:
		w = _fight_setup(10.0, 10.0 + d, 1)
		seen.append("%+.1f tiles: %s" % [d, watcher_sees(w)])
	print("  a watcher in the dark sees you at %s  (exposure %.2f)" % [seen, exposure])
	# walk up to him: he squares up
	w = _fight_setup(10.0, 14.0, 1)
	w.pause = 0.0
	test_keys = {"left": true, "walk": true}
	var f := 0
	while fight == null and f < 600:
		_run(1)
		f += 1
	test_keys = {}
	print("  sneak up to him: a fight %s after %.1fs, %.0f px apart, facing each other %s" % [fight == w, f / 60.0, absf(w.x - (P.x + P.w / 2)), P.facing == -w.facing])
	_run(30)
	print("  squared up: %.0f px apart (gap %.0f)" % [absf(w.x - (P.x + P.w / 2)), Fight.GAP])
	# one press: a strike at random
	w.next_attack = 99.0
	var moves := []
	for i in 5:
		fight_strike()
		moves.append(nm)
		var thuds := fx.size()
		_run(70)
	print("  five single presses: %s, his health now %.2f" % [moves, w.hp])
	# three quick presses: a special
	w.hp = 1.0
	for i in 3:
		fight_strike()
		_run(6)
	var special := nm
	var fr := 0
	while nm != "" and fr < 300:
		_run(1)
		fr += 1
	_run(60)
	print("  three quick presses: %s (a special: %s), his health %.2f, his move now '%s', fight on %s" % [special, special in Fight.SPECIALS, w.hp, w.gm, fight == w])
	# his swing, not blocked: the meter jumps, he shouts
	w = _fight_setup(10.0, 10.0 + Fight.GAP / T, -1, true)
	var heard := false
	var n0 := noises.size()
	for i in 150:
		_run(1)
		heard = heard or noises.size() > n0
	print("  his swing, no block: meter %.2f, the shout heard %s" % [meter, heard])
	# blocked in the tell: the counter
	w = _fight_setup(10.0, 10.0 + Fight.GAP / T, -1, true)
	while w.gm != "late":
		_run(1)
	while w.gt < 0.6:
		_run(1)
	var k := tell_k()
	fight_block()
	var countered := nm == "counter"
	_run(150)
	print("  block in his tell (ticks showing %s): counter %s, meter %.2f, his health %.2f" % [k > 0.0, countered, meter, w.hp])
	# blocked too early (no tell yet): nothing
	w = _fight_setup(10.0, 10.0 + Fight.GAP / T, -1, true)
	_run(5)
	fight_block()
	print("  block with no swing coming: %s" % ["counter" if nm == "counter" else "nothing"])
	# a hop back in his tell: he swings at air
	w = _fight_setup(10.0, 10.0 + Fight.GAP / T, -1, true)
	while w.gt < 0.5 or w.gm != "late":
		_run(1)
	var x0 := P.x
	jump_queued = true
	_run(130)
	print("  hop back in his tell: moved %.0f px back, meter %.2f (the punch missed)" % [(x0 - P.x) * P.facing, meter])
	# jump toward him: over him; he turns round
	w = _fight_setup(10.0, 10.0 + Fight.GAP / T, -1, true)
	w.next_attack = 99.0
	_run(30)
	var side0 := signf(P.x + P.w / 2 - w.x)
	test_keys = {"right" if P.facing > 0 else "left": true}
	jump_queued = true
	_run(1)
	test_keys = {}
	_run(120)
	print("  jump toward him: over him %s, facing each other again %s, %.0f px apart" % [signf(P.x + P.w / 2 - w.x) == -side0, P.facing == -w.facing, absf(w.x - (P.x + P.w / 2))])
	# worn down: dazed, then the finisher puts him out
	w = _fight_setup(10.0, 10.0 + Fight.GAP / T, -1, true)
	w.next_attack = 99.0
	w.hp = 0.15
	fight_strike()
	_run(80)
	var dazed := w.hp <= 0.0
	var tries := 0
	while fight != null and tries < 10:
		fight_strike()
		_run(60)
		tries += 1
	_run(200)
	print("  worn down: dazed %s; then the finisher: out %s (asleep %s, ko %s), the fight over %s" % [dazed, w.ko, w.state == "asleep", w.ko, fight == null])
	# no dropping on him
	w = _fight_setup(10.0, 10.0, 1)
	P.y = 9 * T
	P.on_ground = false
	_run(60)
	print("  dropped onto from above: he's %s" % w.state)
	# in the light, a fight is seen anyway
	w = _fight_setup(21.0, 21.0 + Fight.GAP / T, -1)
	start_fight(w)
	w.next_attack = 99.0
	_run(90)
	print("  a fight under the lamp: meter %.2f after 1.5s" % meter)
	# a watcher finds a sleeping guard: the alarm goes up
	start_run(5)
	var gd: Guard = guards[2]
	var wt: Guard = guards[3]
	for o in guards:
		if o != gd and o != wt:
			o.state = "asleep"
			o.found = true
	P.x = 4 * T
	gd.state = "asleep"
	gd.x = 76 * T
	wt.x = 84 * T
	wt.facing = -1
	wt.to_x = 66 * T
	wt.from_x = 66 * T
	wt.pause = 0.0
	test_keys = {}
	_run(400)
	print("  a watcher walks up to a sleeping guard: found %s, alarm '%s', the guard %s" % [gd.found, alarm, gd.state])
	test_keys = null

# Floor 6 with only the first watcher awake, at gx (tiles), standing still facing face; him at px. fight: squared up.
func _fight_setup(gx: float, px: float, face: int, fight_now := false) -> Guard:
	start_run(5)
	var w: Guard = guards[0]
	for o in guards:
		if o != w:
			o.state = "asleep"
			o.torch.level = 0.0
			o.found = true
	w.x = gx * T
	w.facing = face
	w.state = "patrol"
	w.pause = 99.0                              # standing still
	P.x = px * T - P.w / 2
	test_keys = {}
	_run(2)
	if fight_now:
		start_fight(w)
		w.next_attack = 0.0
		meter = 0.0
	return w

func _capture_fight(setup: String) -> void:
	start_run(5)
	var w: Guard = guards[0]
	w.x = 12 * T
	P.x = 12 * T - Fight.GAP - P.w / 2
	start_fight(w)
	w.next_attack = 99.0
	level_t = 9.0
	if setup == "tell":
		w.next_attack = 0.0
		_run(65)
	else:
		w.hp = 0.5
		start_move(setup)
		_run(int(_capture.get("at", "20")))
