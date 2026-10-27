extends RefCounted
## The floors, as data. Units are tiles (T = 32px) unless noted. (The HTML prototype, ../index.html, is
## frozen at phase A with its own copy of the first three floors - it no longer needs to match.)
##
## Every floor gets a 2-tile ceiling (rows 0-1), a 2-tile floor (rows 15-16) and outer walls for free.
##   solids / ducts / holes: [x, y, w, h]  (ducts = solid you can cling under; holes = cut out, e.g. skylights)
##   props:  [type, x, row]  - row is the tile row the prop stands on (15 = the main floor)
##   hints:  [x, y_px, text]  - faint words painted on the back wall
##   lights: lamp (ceiling unless y given), moon (through a skylight gap), sign, camera (sweeps)
##   guards: x start, patrol from/to, walkable bounds min_x/max_x, row they stand on
##   exit:   the door's tile x; reaching it clears the floor (exit_row: the row it stands on, default 15)
##   height: rows (default 17). The floor is always the bottom 2 rows; taller floors scroll vertically.
##   doors:  [x, y, w, h] locked doors (solid);  switches: {x, row, door} - walk up to one and the
##           ninja pulls it, which opens doors[door]. He reaches it from TUNE.lever_reach px either side,
##           so keep a lever within that of any wall (no spot to stand next to it out of reach).
##           Stairs are just 1-tile steps: walking climbs them.
##   panels: [x, row] alarm panels on the wall. A camera that spots you raises the alarm; a stone
##           through a panel kills it (floors with a camera should have one).
##   hints:  an optional 4th string is the controller version.
##   remember: what clearing this floor brings back - {abilities: [...], colors: [...], lines: [2 lines]}.
##           A floor's abilities are everything remembered on the floors before it ("cling", "takedown").
##   intro:  the opening scene (Floor 1): {hide: seconds before the guards come, talk: [[guard, line], ...]}.
##           Guards with intro_to wait off to the side, run in to that x, talk, then walk to their rounds.

const LEVELS := [
	{
		"name": "FLOOR 1", "subtitle": "the lab",
		"width": 80,
		# the vial machine against the left wall, a bench right beside it to hide behind; then the basics:
		# lamps and cover, two guards (the ones from the opening), a stone lure, pipes to crawl under, crates
		"solids": [[52, 2, 4, 12], [59, 13, 2, 2], [62, 11, 2, 4]],
		"holes": [],
		"ducts": [],
		"props": [["machine", 1, 15], ["desk", 4.5, 15], ["desk", 12, 15], ["cooler", 18, 15], ["desk", 23, 15],
			["plant", 29, 15], ["desk", 36, 15], ["cooler", 44, 15], ["plant", 49, 15], ["desk", 68, 15], ["plant", 74, 15]],
		"hints": [
			[9.0, 170, "A D / ← →  run (loud)      SHIFT  sneak (silent)      SPACE / W / ↑  jump",
				"stick  run (loud)      hold LT  sneak (silent)      A  jump"],
			[14.0, 220, "light fills the meter.  ↓ behind furniture hides you."],
			[28.0, 190, "a guard sees what his torch sees. stay out of the beam."],
			[35.0, 255, "CTRL: throw mode. aim with the mouse, click to throw. the clack pulls guards to it.",
				"hold RT, aim with the right stick, let go to throw. the clack pulls guards to it."],
			[50.0, 260, "↓  crawl - under the pipes"],
			[58.0, 200, "up and over."],
			[70.0, 190, "the way down. keep going."],
		],
		"lights": [
			{"kind": "alarm", "x": 2.1, "y": 11.4, "dir": 0.6, "spread": 1.3, "radius": 170, "intensity": 0.55, "flicker": [1.0, 0.5], "danger": 0.0},
			{"kind": "lamp", "x": 16.5, "spread": 0.5, "radius": 520, "intensity": 0.85},     # the machine's corner stays dark
			{"kind": "lamp", "x": 21.5, "spread": 0.45, "radius": 560},
			{"kind": "lamp", "x": 33.5, "spread": 0.45, "radius": 560, "flicker": [3.0, 0.6]},
			{"kind": "lamp", "x": 42.5, "spread": 0.45, "radius": 560},
			{"kind": "lamp", "x": 57.5, "spread": 0.45, "radius": 420},
			{"kind": "lamp", "x": 70.5, "spread": 0.5, "radius": 560, "intensity": 0.9},
			{"kind": "sign", "x": 78},
		],
		"guards": [
			{"x": 31, "from": 10, "to": 27, "min_x": 1, "max_x": 50, "row": 15, "intro_to": 9.5},
			{"x": 33, "from": 32, "to": 47, "min_x": 1, "max_x": 50, "row": 15, "intro_to": 12.5},
		],
		"intro": {
			"hide": 10.0,
			# [speaker, line, gesture]. ~words~ are the ones he half-hears (drawn faint). Gestures: "machine"
			# (points back at it), "ahead" (points the way he went), "shrug"; none = talking hands.
			"talk": [
				[0, "what happened?", "machine"],
				[1, "someone ~got in and~ took the formula."],
				[1, "it has a countermeasure... ~it~ sprays a chemical."],
				[0, "and?", "shrug"],
				[1, "the thief loses his memory. ~maybe for a while.~"],
				[1, "maybe for good."],
				[0, "then he can't be far.", "ahead"],
			],
		},
		"remember": {"abilities": ["cling", "takedown"], "lines": [
			"you remember...  the ceiling holds you.  and a guard sleeps if you land on him.",
			"jump into a duct to cling.   land on a guard from behind to put him to sleep."]},
		"spawn": [3, 15], "exit": 77,
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
			[33.0, 260, "CTRL: throw mode. aim with the mouse, click to throw. the clack pulls guards to it.",
				"hold RT, aim with the right stick, let go to throw. the clack pulls guards to it."],
			[43.0, 170, "moonlight is weaker. it is still light."],
			[38.5, 215, "guards: hide before the torch finds you. if he sees you duck, he knows where."],
			[56.0, 255, "jump on a guard from behind - or drop from a duct - to put him to sleep."],
			[64.0, 170, "some lights blink. count."],
			[75.0, 200, "a camera. it can't be put to sleep - but a stone through its alarm panel kills the alarm."],
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
		"panels": [[84.5, 12]],                     # on the raised floor, a throw from behind the plant at 80
		"remember": {"lines": [
			"a corridor like this one...  you have walked it before.",
			"you weren't lost in this tower. you were sent."]},
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
		"panels": [[83.5, 12]],                     # upstairs, in reach from behind the rack at 78
		"remember": {"colors": ["scarf"], "lines": [
			"your scarf.  red.  it was always red.",
			"you remember your name...  almost."]},
		"spawn": [3, 24], "exit": 95, "exit_row": 24,
	},
	{
		"name": "FLOOR 4", "subtitle": "security",
		# for now: the old Floor 2, kept as the base for the throwing-stars floor
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
			[19.5, 210, "cubicles: desk to desk, low and quiet."],
			[46.5, 170, "up on the catwalk, or down beneath it?"],
			[76.0, 170, "cameras sweep. they can't be put to sleep - and can't see behind furniture."],
			[78.0, 210, "if a camera sees you, the nearest guard comes running."],
		],
		"lights": [
			{"kind": "lamp", "x": 12.5, "spread": 0.5, "radius": 600, "intensity": 0.9},
			{"kind": "lamp", "x": 23.5, "spread": 0.45, "radius": 600},
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
		"panels": [[88.5, 15]],                     # a stone from behind the cooler at 81 reaches it
		"spawn": [3, 15], "exit": 116,
	},
]
