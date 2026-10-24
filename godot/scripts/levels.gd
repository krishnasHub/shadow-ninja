extends RefCounted
## The floors, as data. Units are tiles (T = 32px) unless noted. The HTML version (../index.html)
## carries the same data in its LEVELS array - keep the two in sync.
##
## Every floor gets a 2-tile ceiling (rows 0-1), a 2-tile floor (rows 15-16) and outer walls for free.
##   solids / ducts / holes: [x, y, w, h]  (ducts = solid you can cling under; holes = cut out, e.g. skylights)
##   props:  [type, x, row]  - row is the tile row the prop stands on (15 = the main floor)
##   hints:  [x, y_px, text]  - faint words painted on the back wall
##   lights: lamp (ceiling unless y given), moon (through a skylight gap), sign, camera (sweeps)
##   guards: x start, patrol from/to, walkable bounds min_x/max_x, row they stand on
##   exit:   the door's tile x; reaching it clears the floor

const LEVELS := [
	{
		"name": "FLOOR 1", "subtitle": "the offices",
		"width": 100,
		"solids": [[10, 12, 1, 3], [26, 13, 12, 1], [74, 13, 2, 2], [77, 12, 8, 3], [88, 2, 2, 12]],
		"holes": [[44, 0, 2, 2], [52, 0, 2, 2], [60, 0, 2, 2]],
		"ducts": [[18, 11, 6, 1], [46, 11, 11, 1], [62, 11, 5, 1]],
		"props": [["desk", 4, 15], ["plant", 8, 15], ["desk", 14, 15], ["cooler", 21, 15], ["desk", 40, 15],
			["plant", 48, 15], ["desk", 55, 15], ["chair", 57.5, 15], ["cooler", 66, 15],
			["plant", 80, 12], ["desk", 91, 15], ["plant", 94, 15]],
		"hints": [
			[2.5, 170, "A D / ← →  run (loud)      SHIFT  sneak (silent)      SPACE / W / ↑  jump"],
			[11.0, 210, "light fills the meter.  ↓ behind furniture hides you."],
			[17.5, 300, "jump into the duct to cling.  ← → shimmy,  ↓ drop."],
			[24.0, 170, "↓  crawl - the dark is under the walkway"],
			[33.0, 260, "CTRL: throw mode. aim with the mouse, click to throw. the clack pulls guards to it."],
			[43.0, 170, "moonlight is weaker. it is still light."],
			[38.5, 215, "guards: hide before the torch finds you. if he sees you duck, he knows where."],
			[56.0, 255, "jump on a guard from behind - or drop from a duct - to put him to sleep."],
			[64.0, 170, "some lights blink. count."],
			[85.0, 170, "↓  through the vent"],
		],
		"lights": [
			{"kind": "lamp", "x": 16.5, "spread": 0.5, "radius": 600, "intensity": 0.9},
			{"kind": "lamp", "x": 31.5, "spread": 0.45, "radius": 600},
			{"kind": "moon", "gap": 44}, {"kind": "moon", "gap": 52}, {"kind": "moon", "gap": 60},
			{"kind": "lamp", "x": 69.5, "spread": 0.55, "radius": 600, "flicker": [3.0, 0.55]},
			{"kind": "sign", "x": 97},
		],
		"guards": [
			{"x": 50, "from": 45, "to": 58, "min_x": 38, "max_x": 74, "row": 15},
			{"x": 70, "from": 63, "to": 72, "min_x": 38, "max_x": 74, "row": 15},
		],
		"spawn": [3, 15], "exit": 96,
	},
	{
		"name": "FLOOR 2", "subtitle": "security",
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
			[2.5, 170, "floor 2 - security. tighter, and watched."],
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
		"spawn": [3, 15], "exit": 116,
	},
]
