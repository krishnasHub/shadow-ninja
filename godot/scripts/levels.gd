extends RefCounted
## The floors, as data. Units are tiles (T = 32px) unless noted. (The HTML prototype, ../index.html, is
## frozen at phase A with its own copy of the first three floors - it no longer needs to match.)
##
## Every floor gets a 2-tile ceiling (rows 0-1), a 2-tile floor (rows 15-16) and outer walls for free.
##   solids / ducts / holes: [x, y, w, h]  (ducts = solid you can cling under; holes = cut out, e.g. skylights)
##   props:  [type, x, row]  - row is the tile row the prop stands on (15 = the main floor)
##   hints:  [x, y_px, text]  - faint words painted on the back wall
##   lights: lamp (ceiling unless y given), moon (through a skylight gap), sign, camera (sweeps)
##   guards: x start, patrol from/to, walkable bounds min_x/max_x, row they stand on;
##           kind "watcher": no torch, but sees as far as a guard (in the dark too), can't be dropped on - you fight
##           him (once "fight" is remembered) - and finds the guards you leave asleep (the alarm goes up)
##   exit:   the door's tile x; reaching it clears the floor (exit_row: the row it stands on, default 15)
##   blackout: true - the guards cut the lights a moment in; sound is the only light (main.gd: BLACKOUT).
##   height: rows (default 17). The floor is always the bottom 2 rows; taller floors scroll vertically.
##   doors:  [x, y, w, h] locked doors (solid);  switches: {x, row, door} - walk up to one and the
##           ninja pulls it, which opens doors[door]. He reaches it from TUNE.lever_reach px either side,
##           so keep a lever within that of any wall (no spot to stand next to it out of reach).
##           Stairs are just 1-tile steps: walking climbs them.
##   panels: [x, row] alarm panels on the wall. A camera that spots you raises the alarm; a star
##           through a panel kills it. Only on floors after the stars come back (before that there's
##           nothing to throw, and an alarm just means: get out, or sit out the lockdown).
##   hints:  an optional 4th string is the controller version.
##   remember: what clearing this floor brings back - {abilities: [...], scarf: 0..1, colors: [...], say: [lines]}.
##           say: what he says in the recall that opens the next floor - only when there are abilities
##           (first person; ~words~ are faint, half-remembered). An ability in main.gd's GIFTS (the stars)
##           also flashes its icon in. With no abilities, the first two lines show on the end screen.
##           scarf: how far up the scarf the dark red has climbed (seen only in shadow). Never named in any
##           text - not in say lines, hints or screens: players should just notice it (user's call). The plan: 0.25 after
##           Floor 3 (the tip), 0.45, 0.65, 0.85, then 1.0 (all of it, a full dark red) with colors: ["mark"],
##           the Evil Co mark on his chest, in grey.
##           A floor's abilities are everything remembered on the floors before it ("cling", "takedown",
##           "stars", "push", "fight").
##   clues:  [id, x, row] something to pick up and read (E): the words are in clues.gd.
##   locks:  {x, row, code, door} a keypad: the right number opens doors[door]. Or {x, row, code, clue, safe: true}:
##           a safe with a clue in it. code: "door" / "safe" - a number made up each new game, shown on a clue.
##   checkpoints: [{x, row}] a retry starts here once he's reached it. At least 6-7 minutes of play apart (user's call).
##   spots:  [{x, row}] quiet checkpoints, off until needed: he's caught a third time since passing one, and a retry
##           starts there from then on (main.gd: update_spots). Place them just before a hard part, somewhere he can
##           stand for 30 s with the guards awake (--selftest=spots checks).
##   searchlight: {spans: [[x0, x1], ...], every: [s, s], warn: s, speed: px/s, linger: [s, s], danger, intensity}
##           a light from outside, through the glass roof (holes): it fills the meter, and never calls a guard. Rotors
##           warn you; when it comes, which span, which way and where it stops are different every time.
##   intro:  the opening scene (Floor 1): {hide: seconds before the guards come, talk: [[guard, line], ...]}.
##           Guards with intro_to wait off to the side, run in to that x, talk, then walk to their rounds.

const LEVELS := [
	{
		"name": "FLOOR 1", "subtitle": "the lab",
		"width": 200, "height": 26, "floor_cam": true,
		# Two storeys: the upper floor is row 15 (the slab is rows 15-16), the lower is row 24. About 10 minutes.
		# Upper, left to right: the machine and the lab (the opening), pipes, crates, then the gallery under a
		# ribbed glass roof (the searchlight), and stairs down at 96. Lower: the door at 112 wants a code; the code
		# is back left under the upper floor, in the office past the crawl at 58, by a guard you have to lure away.
		# Through the door: the checkpoint at 116 (about 6-7 minutes in). The crawl at 128, two guards, stairs up at
		# 171-176, back left along the upper floor under more glass to the lever at 114 (and the safe at 123), back
		# down, and the door it opened at 184.
		"solids": [[52, 2, 4, 12], [59, 13, 2, 2], [62, 11, 2, 4],     # the lab: pipes, crates
			[1, 15, 95, 2],                                            # the upper floor
			[1, 17, 21, 7], [22, 17, 1, 7],                            # solid under the machine; the office's back wall
			[96, 16, 1, 1], [97, 17, 1, 1], [98, 18, 1, 1], [99, 19, 1, 1], [100, 20, 1, 1], [101, 21, 1, 1],   # stairs down
			[103, 23, 1, 1],                                           # a crate, to get back up them
			[58, 17, 1, 6],                                            # the office wall: a crawl along the floor
			[112, 2, 1, 19],                                           # the wall over the coded door
			[113, 15, 58, 2],                                          # the second upper floor
			[128, 17, 3, 6],                                           # a crawl
			[171, 16, 1, 1], [172, 17, 1, 1], [173, 18, 1, 1], [174, 19, 1, 1], [175, 20, 1, 1], [176, 21, 1, 1],   # stairs back up, leftward
			[178, 23, 1, 1],                                           # a crate
			[184, 2, 1, 19]],                                          # the wall over the last door
		"holes": [[68, 0, 3, 2], [72, 0, 3, 2], [76, 0, 3, 2], [80, 0, 3, 2], [84, 0, 3, 2], [88, 0, 3, 2], [92, 0, 3, 2],
			[120, 0, 3, 2], [124, 0, 3, 2], [128, 0, 3, 2], [132, 0, 3, 2], [136, 0, 3, 2], [140, 0, 3, 2], [144, 0, 3, 2],
			[148, 0, 3, 2], [152, 0, 3, 2], [156, 0, 3, 2], [160, 0, 3, 2], [164, 0, 3, 2]],
		"ducts": [],
		"doors": [[112, 21, 1, 3], [184, 21, 1, 3]],
		"switches": [{"x": 114.3, "row": 15, "door": 1}],
		"locks": [{"x": 110.5, "row": 24, "door": 0, "code": "door"},
			{"x": 123, "row": 15, "code": "safe", "clue": "file", "safe": true}],
		"clues": [["lablog", 8.2, 15], ["memo", 46.5, 15], ["notesafe", 93.5, 15], ["notedoor", 25.5, 24], ["badge", 188.5, 24]],
		"checkpoints": [{"x": 116, "row": 24}],
		# On the crates before the gallery; the foot of the stairs; inside the office, past the crawl; halfway up the far stairs
		# (passed going up to the lever and coming back from it, so it also answers for the last guard).
		"spots": [{"x": 63, "row": 11}, {"x": 104, "row": 24}, {"x": 50, "row": 24}, {"x": 173.5, "row": 18}],
		"searchlight": {"spans": [[66, 96], [116, 170]], "every": [9.0, 22.0], "warn": 3.5, "speed": 170.0,
			"linger": [0.5, 2.0], "danger": 1.6, "intensity": 0.95},
		"props": [["machine", 1, 15], ["desk", 4.5, 15], ["desk", 12, 15], ["cooler", 18, 15], ["desk", 23, 15],
			["plant", 29, 15], ["desk", 36, 15], ["cooler", 44, 15], ["plant", 49, 15],
			["desk", 67, 15], ["plant", 74, 15], ["cooler", 80, 15], ["desk", 85, 15], ["plant", 91, 15],     # the gallery
			["desk", 88, 24], ["plant", 80, 24], ["cooler", 72, 24], ["desk", 64, 24],                        # below it
			["plant", 53, 24], ["desk", 45, 24], ["cooler", 40, 24], ["desk", 26, 24],                        # the office
			["plant", 106, 24],
			["plant", 134, 24], ["desk", 140, 24], ["cooler", 146, 24], ["desk", 155, 24], ["plant", 161, 24], ["desk", 166, 24],
			["rack", 118, 15], ["desk", 126, 15], ["rack", 134, 15], ["desk", 140, 15], ["rack", 148, 15], ["desk", 154, 15], ["rack", 162, 15],
			["desk", 186, 24], ["plant", 192, 24]],
		"hints": [
			[9.0, 170, "A D / ← →  run (loud)      SHIFT  sneak (silent)      SPACE / W / ↑  jump",
				"stick  run (loud)      hold LT  sneak (silent)      A  jump"],
			[14.0, 220, "light fills the meter.  ↓ behind furniture hides you."],
			[28.0, 190, "a guard sees what his torch sees. stay out of the beam."],
			[50.0, 260, "↓  crawl - under the pipes"],
			[58.0, 200, "up and over."],
			[65.0, 170, "something up there, circling. when you hear it, be behind something."],
			[96.5, 240, "down."],
			[106.0, 620, "four numbers.  someone will have written them down."],
			[60.0, 640, "↓  crawl - through the gap"],
			[47.0, 610, "running is loud. let him hear you - then be somewhere else."],
			[114.0, 640, "a quiet corner."],
			[125.0, 640, "↓  crawl"],
			[176.0, 640, "the crate, a hop to the first step, then just walk."],
			[176.0, 200, "the switch must be back along here."],
		],
		"lights": [
			{"kind": "alarm", "x": 2.1, "y": 11.4, "dir": 0.6, "spread": 1.3, "radius": 170, "intensity": 0.55, "flicker": [1.0, 0.5], "danger": 0.0},
			{"kind": "lamp", "x": 16.5, "spread": 0.5, "radius": 520, "intensity": 0.85},     # the machine's corner stays dark
			{"kind": "lamp", "x": 21.5, "spread": 0.45, "radius": 560},
			{"kind": "lamp", "x": 33.5, "spread": 0.45, "radius": 560, "flicker": [3.0, 0.6]},
			{"kind": "lamp", "x": 42.5, "spread": 0.45, "radius": 560},
			{"kind": "lamp", "x": 57.5, "spread": 0.45, "radius": 420},
			{"kind": "lamp", "x": 79.5, "spread": 0.4, "radius": 480, "flicker": [5.0, 0.55]},  # the gallery
			{"kind": "lamp", "x": 76.5, "y": 17.125, "spread": 0.5, "radius": 400},             # below it
			{"kind": "lamp", "x": 66.5, "y": 17.125, "spread": 0.5, "radius": 400, "flicker": [3.6, 0.6]},
			{"kind": "lamp", "x": 30.5, "y": 17.125, "spread": 0.55, "radius": 420},            # the office: the note is in the light
			{"kind": "lamp", "x": 108.5, "y": 18, "spread": 0.5, "radius": 340, "intensity": 0.8},   # the coded door
			{"kind": "lamp", "x": 137.5, "y": 17.125, "spread": 0.5, "radius": 400, "flicker": [4.0, 0.6]},
			{"kind": "lamp", "x": 150.5, "y": 17.125, "spread": 0.5, "radius": 400},
			{"kind": "lamp", "x": 163.5, "y": 17.125, "spread": 0.5, "radius": 400},
			{"kind": "lamp", "x": 147.5, "spread": 0.4, "radius": 480},                          # the second gallery
			{"kind": "lamp", "x": 117.5, "spread": 0.4, "radius": 420, "intensity": 0.8},        # over the lever
			{"kind": "lamp", "x": 190.5, "y": 17.125, "spread": 0.5, "radius": 420},
			{"kind": "sign", "x": 197},
		],
		"guards": [
			{"x": 31, "from": 10, "to": 27, "min_x": 1, "max_x": 50, "row": 15, "intro_to": 9.5},
			{"x": 33, "from": 32, "to": 47, "min_x": 1, "max_x": 50, "row": 15, "intro_to": 12.5},
			{"x": 40, "from": 30, "to": 48, "min_x": 8, "max_x": 50, "row": 15},        # the lab, after they've gone
			{"x": 82, "from": 72, "to": 90, "min_x": 65, "max_x": 95, "row": 15},       # the gallery
			{"x": 75, "from": 62, "to": 92, "min_x": 59, "max_x": 95, "row": 24},       # below it
			{"x": 32, "from": 30, "to": 35, "min_x": 24, "max_x": 57, "row": 24},       # the office: he stays by the note
			{"x": 140, "from": 132, "to": 150, "min_x": 131, "max_x": 170, "row": 24},
			{"x": 165, "from": 153, "to": 176, "min_x": 131, "max_x": 177, "row": 24},
			{"x": 140, "from": 126, "to": 160, "min_x": 114, "max_x": 170, "row": 15},  # the second gallery
			{"x": 190, "from": 188, "to": 193, "min_x": 185, "max_x": 196, "row": 24},  # by the way out
		],
		"intro": {
			"hide": 10.0,
			# [speaker, line, gesture]. He can't follow what they say: word@n is scrawl until Floor n, as in
			# clues.gd, and only the unmarked key words come through. Gestures: "machine" (points back at it),
			# "ahead" (points the way he went), "shrug"; none = talking hands.
			"talk": [
				[0, "what@2 happened?", "machine"],
				[1, "someone@2 got@2 in@2 and@2 took@3 the@2 formula."],
				[1, "it@2 has@2 a@2 countermeasure...@6 it@2 sprays@7 a@2 chemical."],
				[0, "and?", "shrug"],
				[1, "the@2 thief@4 loses@5 his@2 memory.  maybe@3 for@2 a@2 while.@3"],
				[1, "maybe@3 for@2 good."],
				[0, "then@2 he@2 can't@3 be@2 far.", "ahead"],
			],
		},
		"remember": {"abilities": ["cling", "takedown"], "say": [
			"wait...  my hands know this.",
			"the ceiling holds me.  ~it always did.~",
			"and a guard sleeps  ~if I land on him.~"]},
		"spawn": [3, 15], "exit": 195, "exit_row": 24,
	},
	{
		"name": "FLOOR 2", "subtitle": "the offices",
		"width": 100,
		"solids": [[10, 12, 1, 3], [26, 13, 12, 1], [74, 13, 2, 2], [77, 12, 8, 3], [88, 2, 2, 12]],
		"holes": [[44, 0, 2, 2], [52, 0, 2, 2], [60, 0, 2, 2]],
		"ducts": [[18, 11, 6, 1], [46, 11, 11, 1], [62, 11, 5, 1]],
		"props": [["desk", 4, 15], ["plant", 8, 15], ["desk", 14, 15], ["cooler", 21, 15], ["desk", 40, 15],
			["plant", 48, 15], ["desk", 55, 15], ["chair", 57.5, 15], ["cooler", 66, 15],
			["plant", 80, 12], ["desk", 91, 15], ["plant", 94, 15]],
		"hints": [
			[2.5, 170, "floor 2. the offices. your body remembers more than you do."],
			[17.5, 300, "jump into the duct to cling.  ← → shimmy,  ↓ drop."],
			[24.0, 170, "↓  crawl - the dark is under the walkway"],
			[33.0, 260, "running is loud. let a guard hear you - then be somewhere else."],
			[43.0, 170, "moonlight is weaker. it is still light."],
			[38.5, 215, "guards: hide before the torch finds you. if he sees you duck, he knows where."],
			[56.0, 255, "jump on a guard from behind - or drop from a duct - to put him to sleep."],
			[64.0, 170, "some lights blink. count."],
			[75.0, 200, "a camera. if it sees you, the alarm goes up. be gone before it ends."],
			[85.0, 170, "↓  through the vent"],
		],
		"lights": [
			{"kind": "lamp", "x": 16.5, "spread": 0.5, "radius": 600, "intensity": 0.9},
			{"kind": "lamp", "x": 31.5, "spread": 0.45, "radius": 600},
			{"kind": "moon", "gap": 44}, {"kind": "moon", "gap": 52}, {"kind": "moon", "gap": 60},
			{"kind": "lamp", "x": 69.5, "spread": 0.55, "radius": 600, "flicker": [3.0, 0.55]},
			{"kind": "camera", "x": 81.5, "spread": 0.14, "radius": 420, "sweep": [0.6, 5.0], "danger": 1.5},   # over the raised floor
			{"kind": "sign", "x": 97},
		],
		"guards": [
			{"x": 50, "from": 45, "to": 58, "min_x": 38, "max_x": 74, "row": 15},
			{"x": 70, "from": 63, "to": 72, "min_x": 38, "max_x": 74, "row": 15},
		],
		"remember": {"say": [
			"this corridor...  I've walked it before.",
			"I wasn't lost in this tower.  ~I was sent.~"]},
		"spawn": [3, 15], "exit": 96,
	},
	{
		"name": "FLOOR 3", "subtitle": "the archive",
		"width": 100, "height": 26,
		# two storeys: the upper floor slab is rows 12-13 (top at y 384), the lower floor is row 24 (y 768).
		# Floating stairs climb from the lower storey (bottom step x31, row 21) to the upper one (x40);
		# you can walk underneath them.
		"solids": [[1, 12, 28, 2], [40, 12, 59, 2],
			[29, 23, 1, 1],                                         # a crate to hop from
			[31, 21, 1, 1], [32, 20, 1, 1], [33, 19, 1, 1], [34, 18, 1, 1],
			[35, 17, 1, 1], [36, 16, 1, 1], [37, 15, 1, 1], [38, 14, 1, 1], [39, 13, 1, 1],
			[60, 14, 1, 7]],                                       # the wall above the security door
		"holes": [],
		"ducts": [[74, 8, 9, 1], [44, 19, 8, 1]],
		"doors": [[60, 21, 1, 3]],
		"switches": [{"x": 98.3, "row": 12, "door": 0}],
		"props": [["rack", 5, 24], ["desk", 9, 24], ["rack", 15, 24], ["desk", 20, 24], ["rack", 26, 24],
			["cooler", 33, 24], ["desk", 41, 24], ["rack", 48, 24], ["plant", 55, 24],
			["desk", 64, 24], ["rack", 70, 24], ["cooler", 76, 24], ["desk", 82, 24], ["rack", 88, 24], ["plant", 92, 24],
			["rack", 43, 12], ["rack", 48, 12], ["rack", 56, 12], ["rack", 62, 12], ["desk", 66, 12],
			["rack", 72, 12], ["rack", 78, 12], ["rack", 86, 12], ["rack", 90, 12], ["plant", 93, 12]],
		"hints": [
			[2.5, 580, "floor 3 - the archive. two storeys."],
			[24.0, 640, "the stairs: crate, hop to the first step, then just walk."],
			[50.0, 560, "locked. the switch is upstairs."],
			[44.0, 160, "the server room. racks hide you too."],
			[84.0, 200, "walk up to the lever to pull it. it is loud."],
			[63.0, 560, "through. the way out is at the end."],
		],
		"lights": [
			{"kind": "lamp", "x": 10.5, "y": 14.125, "spread": 0.5, "radius": 420},
			{"kind": "lamp", "x": 22.5, "y": 14.125, "spread": 0.5, "radius": 420, "flicker": [2.8, 0.55]},
			{"kind": "lamp", "x": 35.5, "spread": 0.35, "radius": 760, "intensity": 0.55, "flicker": [4.0, 0.5]},   # down the stairwell: dim, and dark half the time
			{"kind": "lamp", "x": 50.5, "y": 14.125, "spread": 0.5, "radius": 420},
			{"kind": "lamp", "x": 68.5, "y": 14.125, "spread": 0.5, "radius": 420},
			{"kind": "lamp", "x": 84.5, "y": 14.125, "spread": 0.5, "radius": 420, "intensity": 0.9},
			{"kind": "lamp", "x": 52.5, "spread": 0.45, "radius": 420},
			{"kind": "lamp", "x": 64.5, "spread": 0.45, "radius": 420},
			{"kind": "camera", "x": 79.5, "spread": 0.14, "radius": 420, "sweep": [0.6, 5.0], "danger": 1.5},
			{"kind": "lamp", "x": 93.5, "spread": 0.4, "radius": 420},                         # over the lever
			{"kind": "sign", "x": 96},
		],
		"guards": [
			{"x": 14, "from": 7, "to": 28, "min_x": 1, "max_x": 29, "row": 24},
			{"x": 50, "from": 42, "to": 58, "min_x": 32, "max_x": 60, "row": 24},
			{"x": 75, "from": 64, "to": 90, "min_x": 61, "max_x": 95, "row": 24},
			{"x": 60, "from": 44, "to": 88, "min_x": 40, "max_x": 95, "row": 12},      # upstairs, in the server room
		],
		"remember": {"scarf": 0.25, "abilities": ["stars"], "say": [
			"and a weight in my sleeve...  steel.  four points.",
			"it's coming back."]},
		"spawn": [3, 24], "exit": 95, "exit_row": 24,
	},
	{
		"name": "FLOOR 4", "subtitle": "security",
		# the throwing stars: a bright lamp over open floor early (put it out, or wait out the guard who comes
		# to look), a camera over the end you can blind instead of creeping past
		"width": 120,
		# crate steps up to a catwalk (row 10, x 52-74) that runs over a lower floor
		"solids": [[49, 13, 2, 2], [51, 12, 1, 3], [52, 10, 23, 1]],
		"holes": [],
		"ducts": [[26, 11, 8, 1], [79, 11, 7, 1]],
		"props": [["desk", 6, 15], ["desk", 11, 15],
			["desk", 21, 15], ["desk", 26, 15], ["desk", 31, 15], ["desk", 36, 15], ["desk", 41, 15], ["plant", 46, 15],
			["plant", 63, 10], ["cooler", 57, 15], ["desk", 66, 15],
			["cooler", 81, 15], ["plant", 87, 15], ["desk", 93, 15], ["cooler", 99, 15],
			["desk", 108, 15], ["plant", 113, 15]],
		"hints": [
			[2.5, 170, "floor 4 - security. tighter, and watched."],
			[7.5, 205, "CTRL  a star flies straight - through a lamp, a camera's eye, an alarm panel.",
				"hold RT  a star flies straight - through a lamp, a camera's eye, an alarm panel."],
			[7.5, 240, "glass is loud. whoever hears it comes to look."],
			[19.5, 210, "cubicles: desk to desk, low and quiet."],
			[46.5, 170, "up on the catwalk, or down beneath it?"],
			[76.0, 170, "cameras sweep, and can't see behind furniture."],
			[78.0, 210, "a star through the lens, and it's blind."],
			[70.5, 250, "from the end of the catwalk, the camera's in reach."],
		],
		"lights": [
			{"kind": "lamp", "x": 16.5, "spread": 0.6, "radius": 600},                          # over open floor: the first star
			{"kind": "lamp", "x": 26.5, "spread": 0.45, "radius": 600},
			{"kind": "lamp", "x": 33.5, "spread": 0.45, "radius": 600, "flicker": [2.4, 0.6]},
			{"kind": "lamp", "x": 43.5, "spread": 0.45, "radius": 600},
			{"kind": "lamp", "x": 63.5, "spread": 0.4, "radius": 360, "intensity": 0.9},          # over the catwalk
			{"kind": "lamp", "x": 60.5, "y": 11.125, "spread": 0.55, "radius": 220, "intensity": 0.8},   # under it
			{"kind": "camera", "x": 90.5, "spread": 0.14, "radius": 460, "sweep": [0.7, 6.0], "danger": 1.5},
			{"kind": "sign", "x": 117},
		],
		"guards": [
			{"x": 30, "from": 21, "to": 46, "min_x": 1, "max_x": 49, "row": 15},
			{"x": 60, "from": 54, "to": 72, "min_x": 52, "max_x": 75, "row": 10},     # on the catwalk
			{"x": 64, "from": 54, "to": 73, "min_x": 52, "max_x": 105, "row": 15},
			{"x": 102, "from": 97, "to": 108, "min_x": 52, "max_x": 115, "row": 15},
		],
		"panels": [[88.5, 15]],                     # a star from behind the cooler at 81 reaches it
		"remember": {"scarf": 0.45, "abilities": ["push"], "say": [
			"my hands on the edge of a desk...  ~dragging it through the dark.~",
			"cover is only cover where you put it."]},
		"spawn": [3, 15], "exit": 116,
	},
	{
		"name": "FLOOR 5", "subtitle": "the open plan",
		# moving desks, made to matter: cameras can't be put to sleep, and there's one star for four of them.
		# 1: a camera over an empty bay - nothing sees you at the start, but to pass it, bring the desk
		#    (push, duck, push). Running it fills the meter; blind it with the star and you might just make it.
		# 2: a wall too high to jump - push the desk against it and stand on it (and a camera on you while you do).
		# 3: a hall under two cameras with a guard below - two desks, push one, then the other.
		"width": 96,
		"stars": 1,
		"solids": [[52, 11, 2, 4]],                 # the wall: 4 tiles - a jump makes 3.5, a jump off a desk 4.4
		"holes": [],
		"ducts": [],
		"props": [["desk", 5, 15], ["plant", 30, 15],
			["desk", 38, 15],
			["desk", 57, 15], ["desk", 74, 15]],
		"hints": [
			[2.5, 170, "floor 5 - the open plan. nowhere to hide - unless you bring it."],
			[4.5, 210, "E  hold by a desk to grip it. move to push or pull.", "X  hold by a desk to grip it. move to push or pull."],
			[4.5, 245, "it scrapes. SHIFT drags it slow and quiet.", "it scrapes. hold LT to drag it slow and quiet."],
			[12.0, 280, "↓  let go - and you're behind it."],
			[16.0, 210, "behind it, hold E too: it moves with you, hidden.", "behind it, hold X too: it moves with you, hidden."],
			[16.0, 245, "a camera sees a desk move. be still under the lens."],
			[32.0, 190, "one star. four cameras."],
			[45.0, 230, "too high to jump. a desk is a step."],
			[56.0, 190, "a long way under the lenses. there's another desk further on."],
			[86.0, 190, "almost out."],
		],
		"lights": [
			{"kind": "camera", "x": 22.5, "spread": 0.14, "radius": 520, "sweep": [0.55, 5.4], "danger": 1.5},
			{"kind": "camera", "x": 44.5, "spread": 0.14, "radius": 560, "sweep": [0.6, 4.0], "danger": 1.5},
			{"kind": "camera", "x": 66.5, "spread": 0.14, "radius": 580, "sweep": [0.7, 5.0], "danger": 1.5},
			{"kind": "camera", "x": 83.5, "spread": 0.14, "radius": 580, "sweep": [0.7, 4.4], "danger": 1.5},
			{"kind": "sign", "x": 93},
		],
		"guards": [
			{"x": 75, "from": 60, "to": 88, "min_x": 56, "max_x": 90, "row": 15},
		],
		"remember": {"scarf": 0.65, "abilities": ["fight"], "say": [
			"knuckles...  ~a man going down in the dark,~  and me still standing.",
			"up close, in the dark - they should be afraid of me."]},
		"spawn": [3, 15], "exit": 92,
	},
	{
		"name": "FLOOR 6", "subtitle": "the watch",
		# fighting: the watchers carry no torch but see as far as a guard's would reach, even in the dark; spotted,
		# they run at you and hiding is no use. They can't be dropped on, and find the guards you leave asleep. 1: one watcher alone in the dark, to learn on.
		# 2: a torch guard under a duct - the old way still works. 3: a watcher walking near a torch guard:
		# put the guard to sleep and the watcher finds him. 4: a camera, then a last watcher by the exit.
		"width": 130,
		"solids": [],
		"holes": [],
		"ducts": [[42, 11, 12, 1]],
		"props": [["desk", 8, 15], ["plant", 33, 15],
			["desk", 47, 15], ["cooler", 60, 15],
			["desk", 67, 15], ["plant", 80, 15], ["desk", 86, 15],
			["desk", 98, 15], ["cooler", 110, 15], ["plant", 121, 15]],
		"hints": [
			[2.5, 170, "floor 6 - the watch. some of them carry no light."],
			[7.0, 210, "no torch, but he sees as far as the rest. once he has, hiding won't help."],
			[7.0, 245, "by him:  LEFT CLICK / E  strike.   RIGHT CLICK / Q  block.", "by him:  X  strike.   Y  block."],
			[15.0, 280, "three quick strikes: something special.", "three quick X: something special."],
			[24.0, 190, "when he winds up - the ticks over his head - block."],
			[24.0, 225, "jump hops you back. jump toward him and you're over him."],
			[30.0, 260, "fight in the dark. in the light, you're seen anyway."],
			[38.5, 190, "the ones with torches: the old way still works."],
			[63.0, 190, "a watcher finds the ones you leave sleeping. and then everyone knows."],
			[94.0, 190, "almost out."],
		],
		"lights": [
			{"kind": "lamp", "x": 21.5, "spread": 0.4, "radius": 500, "intensity": 0.85},
			{"kind": "lamp", "x": 45.5, "spread": 0.45, "radius": 520},
			{"kind": "lamp", "x": 57.5, "spread": 0.45, "radius": 520},
			{"kind": "lamp", "x": 76.5, "spread": 0.45, "radius": 480, "flicker": [3.2, 0.55]},
			{"kind": "camera", "x": 104.5, "spread": 0.14, "radius": 520, "sweep": [0.65, 5.0], "danger": 1.5},
			{"kind": "lamp", "x": 116.5, "spread": 0.4, "radius": 500, "intensity": 0.8},
			{"kind": "sign", "x": 127},
		],
		"guards": [
			{"x": 18, "from": 12, "to": 30, "min_x": 5, "max_x": 37, "row": 15, "kind": "watcher"},
			{"x": 50, "from": 40, "to": 60, "min_x": 37, "max_x": 63, "row": 15},
			{"x": 70, "from": 65, "to": 80, "min_x": 63, "max_x": 93, "row": 15},
			{"x": 86, "from": 72, "to": 90, "min_x": 63, "max_x": 93, "row": 15, "kind": "watcher"},
			{"x": 115, "from": 108, "to": 123, "min_x": 95, "max_x": 125, "row": 15, "kind": "watcher"},
		],
		"panels": [[100.5, 15]],
		"spawn": [3, 15], "exit": 126,
	},
	{
		"name": "FLOOR 7", "subtitle": "the dark",
		# the blackout: a moment after you arrive the guards cut the lights. Black; sound is the only light -
		# your steps send out ripples that outline what they reach (walls stop them), out to where the guards
		# hear it. Sneak and you're quiet and nearly blind; run and you see, and they hear. The guards see in
		# the dark (night vision): you see only their eyes. 1: a room and one guard, to learn on. 2: through a
		# doorway, two guards and a duct over them. 3: through another, a guard on his rounds and one by the exit.
		"width": 112,
		"blackout": true,
		"solids": [[30, 2, 1, 10], [66, 2, 1, 10]],
		"holes": [],
		"ducts": [[42, 10, 12, 1]],
		"props": [["desk", 8, 15], ["plant", 20, 15],
			["desk", 35, 15], ["cooler", 55, 15], ["desk", 59, 15],
			["desk", 73, 15], ["plant", 84, 15], ["desk", 92, 15], ["cooler", 101, 15]],
		"hints": [
			[2.5, 170, "floor 7. the dark."],
			[6.0, 215, "they still see you. you can only hear them."],
			[11.0, 250, "move, and the dark shows itself. sneak: a little.  run: more - and they hear."],
			[33.0, 190, "eyes in the dark. that's where they're looking."],
			[69.0, 190, "almost out."],
		],
		"lights": [
			{"kind": "lamp", "x": 10.5, "spread": 0.45, "radius": 520, "intensity": 0.9},
			{"kind": "lamp", "x": 24.5, "spread": 0.45, "radius": 520},
			{"kind": "lamp", "x": 47.5, "spread": 0.45, "radius": 520},
			{"kind": "lamp", "x": 80.5, "spread": 0.45, "radius": 520},
			{"kind": "lamp", "x": 98.5, "spread": 0.45, "radius": 520},
			{"kind": "sign", "x": 108},
		],
		"guards": [
			{"x": 24, "from": 15, "to": 28, "min_x": 12, "max_x": 29, "row": 15},
			{"x": 40, "from": 33, "to": 52, "min_x": 31, "max_x": 64, "row": 15},
			{"x": 58, "from": 46, "to": 63, "min_x": 31, "max_x": 64, "row": 15},
			{"x": 80, "from": 70, "to": 94, "min_x": 68, "max_x": 104, "row": 15},
			{"x": 103, "from": 99, "to": 105, "min_x": 96, "max_x": 106, "row": 15},
		],
		"spawn": [3, 15], "exit": 108,
	},
]
