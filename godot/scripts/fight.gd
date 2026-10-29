extends RefCounted
## Fighting (Floor 6 on), as data: the poses and the moves, prototyped in tools/characters.html
## (Fighting · Floor 6) - change them there first, then copy the numbers here.
##
## A pose: hip, fA (front foot), fB (back foot), hA (near hand), hB (far hand) - offsets from where he
## stands, x toward his facing - and tilt (the torso, + leans toward his facing). The whole body moves
## with dx (a step in), lift (off the floor), rot (turned about the hip, + pitches forward) and spin
## (0 facing, 1 back turned: drawn squeezed through the turn); face 1: turned round to face him (eyes stay).
## Knees and elbows find themselves.

const POSE0 := {"dx": 0.0, "lift": 0.0, "rot": 0.0, "spin": 0.0, "tilt": 0.0, "face": 0.0}
# Body plans: limb lengths and widths, the shoulder, the torso (a capsule from ta to tb), the head, the neck.
const NB := {"leg": 9.5, "legW": 4.0, "arm": 7.0, "armW": 4.0, "sh": Vector2(0, -13), "ta": Vector2(0, -3.5),
	"tb": Vector2(0, -10.5), "tw": 13.0, "head": Vector2(1.5, -23), "hr": 7.5, "neck": Vector2(-5, -24)}
const GB := {"leg": 10.5, "legW": 5.0, "arm": 10.0, "armW": 4.5, "sh": Vector2(-2, -22), "ta": Vector2(0, -6),
	"tb": Vector2(0, -16), "tw": 18.0, "head": Vector2(1, -33), "hr": 8.0, "neck": Vector2(-3, -27)}
const GAP := 33.0               # his middle to the watcher's, squared up

const NP := {	# the ninja: low, quick, on the balls of his feet
	"stance": { "hip": Vector2(-1, -14), "fA": Vector2(6, -1), "fB": Vector2(-8, -1), "hA": Vector2(9, -27), "hB": Vector2(4, -23), "tilt": 0.12 },
	"jab": { "dx": 5, "hip": Vector2(1, -14), "fA": Vector2(8, -1), "fB": Vector2(-7, -1), "hA": Vector2(18, -28), "hB": Vector2(4, -25), "tilt": 0.2 },
	"cross": { "dx": 6, "rot": 0.05, "hip": Vector2(2, -14), "fA": Vector2(8, -1), "fB": Vector2(-4, -2), "hA": Vector2(7, -26), "hB": Vector2(18, -28), "tilt": 0.32 },
	"rhChamber": { "dx": 3, "hip": Vector2(0, -15), "fA": Vector2(2, -1), "fB": Vector2(7, -12), "hA": Vector2(8, -30), "hB": Vector2(-5, -22), "tilt": -0.15 },
	"rhKick": { "dx": 9, "hip": Vector2(0, -16), "fA": Vector2(-1, -1), "fB": Vector2(15, -28), "hA": Vector2(6, -31), "hB": Vector2(-12, -21), "tilt": -0.5 },
	"rhBack": { "dx": 5, "hip": Vector2(0, -15), "fA": Vector2(1, -1), "fB": Vector2(5, -9), "hA": Vector2(8, -29), "hB": Vector2(-3, -22), "tilt": -0.1 },
	"lkKick": { "dx": 8, "hip": Vector2(0, -14), "fA": Vector2(0, -1), "fB": Vector2(17, -8), "hA": Vector2(8, -30), "hB": Vector2(-9, -22), "tilt": -0.3 },
	"tpChamber": { "dx": 2, "hip": Vector2(-2, -15), "fA": Vector2(7, -12), "fB": Vector2(-6, -1), "hA": Vector2(8, -29), "hB": Vector2(2, -25), "tilt": -0.15 },
	"tpKick": { "dx": 7, "hip": Vector2(-2, -15), "fA": Vector2(15, -23), "fB": Vector2(-5, -1), "hA": Vector2(6, -30), "hB": Vector2(-4, -25), "tilt": -0.42 },
	"sbLoad": { "dx": 3, "spin": 0.4, "hip": Vector2(0, -14), "fA": Vector2(4, -1), "fB": Vector2(-5, -1), "hA": Vector2(5, -28), "hB": Vector2(2, -25), "tilt": 0.15 },
	"sbKick": { "dx": 10, "spin": 1, "hip": Vector2(0, -16), "fA": Vector2(1, -1), "fB": Vector2(-17, -24), "hA": Vector2(5, -27), "hB": Vector2(9, -21), "tilt": 0.45 },
	"fkStep": { "dx": 6, "hip": Vector2(0, -12), "fA": Vector2(7, -1), "fB": Vector2(-6, -1), "hA": Vector2(10, -27), "hB": Vector2(6, -24), "tilt": 0.2 },
	"fkAir": { "dx": 13, "lift": 15, "hip": Vector2(0, -15), "fA": Vector2(2, -14), "fB": Vector2(-11, -6), "hA": Vector2(14, -36), "hB": Vector2(12, -31), "tilt": 0.1 },
	"fkLand": { "dx": 10, "hip": Vector2(0, -12), "fA": Vector2(6, -1), "fB": Vector2(-6, -1), "hA": Vector2(9, -27), "hB": Vector2(4, -23), "tilt": 0.2 },
	"ksLoad": { "dx": 7, "hip": Vector2(0, -11), "fA": Vector2(6, -1), "fB": Vector2(-6, -1), "hA": Vector2(8, -25), "hB": Vector2(3, -22), "tilt": 0.25 },
	"ksFly": { "dx": 14, "lift": 12, "rot": -1.5, "hip": Vector2(0, -14), "fA": Vector2(9, 1), "fB": Vector2(-8, 1), "hA": Vector2(-10, -20), "hB": Vector2(-14, -16) },
	"ksDown": { "dx": 13, "lift": -7, "rot": -1.5, "hip": Vector2(0, -14), "fA": Vector2(7, 0), "fB": Vector2(-7, 2), "hA": Vector2(-10, -20), "hB": Vector2(-14, -17) },
	"ksUp": { "dx": 12, "hip": Vector2(0, -11), "fA": Vector2(5, -1), "fB": Vector2(-6, -1), "hA": Vector2(8, -25), "hB": Vector2(3, -22), "tilt": 0.2 },
	"smChamber": { "dx": 2, "hip": Vector2(0, -15), "fA": Vector2(3, -1), "fB": Vector2(6, -11), "hA": Vector2(8, -28), "hB": Vector2(3, -25), "tilt": 0 },
	"smFly": { "dx": 12, "lift": 6, "hip": Vector2(1, -15), "fA": Vector2(4, -5), "fB": Vector2(-14, -10), "hA": Vector2(3, -26), "hB": Vector2(19, -30), "tilt": 0.35 },
	"smLand": { "dx": 10, "hip": Vector2(1, -13), "fA": Vector2(8, -1), "fB": Vector2(-5, -1), "hA": Vector2(6, -27), "hB": Vector2(14, -27), "tilt": 0.25 },
	"swDrop": { "dx": 4, "spin": 0.4, "hip": Vector2(0, -7), "fA": Vector2(4, -1), "fB": Vector2(-6, -1), "hA": Vector2(6, -1), "hB": Vector2(2, -2), "tilt": 0.6 },
	"swSweep": { "dx": 6, "spin": 1, "hip": Vector2(0, -7), "fA": Vector2(2, -1), "fB": Vector2(-19, -2), "hA": Vector2(-2, -1), "hB": Vector2(3, -1), "tilt": 0.7 },
	"swRise": { "dx": 4, "hip": Vector2(0, -11), "fA": Vector2(5, -1), "fB": Vector2(-6, -1), "hA": Vector2(8, -25), "hB": Vector2(3, -22), "tilt": 0.2 },
	"flCrouch": { "dx": 7, "hip": Vector2(0, -10), "fA": Vector2(5, -1), "fB": Vector2(-6, -1), "hA": Vector2(6, -22), "hB": Vector2(1, -19), "tilt": 0.1 },
	"flKick": { "dx": 10, "lift": 14, "rot": -2.4, "hip": Vector2(0, -15), "fA": Vector2(2, 3), "fB": Vector2(-4, -2), "hA": Vector2(-6, -20), "hB": Vector2(-9, -16) },
	"flOver": { "dx": 6, "lift": 18, "rot": -4.0, "hip": Vector2(0, -15), "fA": Vector2(4, -7), "fB": Vector2(-1, -6), "hA": Vector2(3, -22), "hB": Vector2(-2, -20) },
	"flLand": { "dx": 2, "rot": -2 * PI, "hip": Vector2(0, -10), "fA": Vector2(5, -1), "fB": Vector2(-6, -1), "hA": Vector2(6, -22), "hB": Vector2(1, -19), "tilt": 0.15 },
	"vtCrouch": { "dx": 8, "hip": Vector2(0, -10), "fA": Vector2(6, -1), "fB": Vector2(-6, -1), "hA": Vector2(8, -22), "hB": Vector2(3, -19), "tilt": 0.3 },
	"vtPlant": { "dx": 18, "lift": 34, "rot": 1.6, "hip": Vector2(0, -14), "fA": Vector2(2, -1), "fB": Vector2(-3, -1), "hA": Vector2(4, -27), "hB": Vector2(2, -26) },
	"vtOver": { "dx": 33, "lift": 52, "rot": PI, "hip": Vector2(0, -14), "fA": Vector2(1, -2), "fB": Vector2(-2, -1), "hA": Vector2(1, -25), "hB": Vector2(-1, -25) },
	"vtDown": { "dx": 46, "lift": 24, "rot": 4.4, "spin": 0.6, "hip": Vector2(0, -14), "fA": Vector2(4, -4), "fB": Vector2(-2, -3), "hA": Vector2(6, -24), "hB": Vector2(2, -22) },
	"vtLand": { "face": 1, "dx": 54, "rot": 2 * PI, "spin": 1, "hip": Vector2(0, -11), "fA": Vector2(5, -1), "fB": Vector2(-6, -1), "hA": Vector2(8, -25), "hB": Vector2(3, -22), "tilt": 0.2 },
	"vtKick": { "face": 1, "dx": 50, "spin": 1, "hip": Vector2(-2, -15), "fA": Vector2(15, -23), "fB": Vector2(-5, -1), "hA": Vector2(6, -30), "hB": Vector2(-4, -25), "tilt": -0.42 },
	"vtSet": { "face": 1, "dx": 52, "spin": 1, "hip": Vector2(-1, -14), "fA": Vector2(6, -1), "fB": Vector2(-8, -1), "hA": Vector2(9, -27), "hB": Vector2(4, -23), "tilt": 0.12 },
	"overSet": { "face": 1, "dx": 64, "spin": 1, "hip": Vector2(-1, -14), "fA": Vector2(6, -1), "fB": Vector2(-8, -1), "hA": Vector2(9, -27), "hB": Vector2(4, -23), "tilt": 0.12 },
	"hopCrouch": { "hip": Vector2(-1, -11), "fA": Vector2(6, -1), "fB": Vector2(-7, -1), "hA": Vector2(9, -25), "hB": Vector2(4, -22), "tilt": 0.15 },
	"hopAir": { "dx": -18, "lift": 9, "hip": Vector2(-1, -14), "fA": Vector2(4, -5), "fB": Vector2(-6, -4), "hA": Vector2(9, -28), "hB": Vector2(4, -24), "tilt": -0.05 },
	"hopLand": { "dx": -36, "hip": Vector2(-1, -12), "fA": Vector2(6, -1), "fB": Vector2(-7, -1), "hA": Vector2(9, -27), "hB": Vector2(4, -23), "tilt": 0.12 },
	"hit": { "dx": -3, "hip": Vector2(-4, -14), "fA": Vector2(3, -1), "fB": Vector2(-9, -1), "hA": Vector2(3, -22), "hB": Vector2(-3, -19), "tilt": -0.38 },
	"block": { "hip": Vector2(-2, -13), "fA": Vector2(5, -1), "fB": Vector2(-8, -1), "hA": Vector2(8, -33), "hB": Vector2(9, -28), "tilt": -0.05 },
	"parry": { "dx": 2, "hip": Vector2(0, -13), "fA": Vector2(6, -1), "fB": Vector2(-8, -1), "hA": Vector2(15, -36), "hB": Vector2(7, -25), "tilt": 0.05 },
	"palm": { "dx": 7, "hip": Vector2(3, -13), "fA": Vector2(10, -1), "fB": Vector2(-5, -1), "hA": Vector2(9, -33), "hB": Vector2(19, -28), "tilt": 0.3 },
	"fnGrab": { "dx": 9, "hip": Vector2(1, -14), "fA": Vector2(8, -1), "fB": Vector2(-5, -1), "hA": Vector2(17, -34), "hB": Vector2(15, -29), "tilt": 0.25 },
	"fnKnee": { "dx": 10, "hip": Vector2(1, -15), "fA": Vector2(0, -1), "fB": Vector2(5, -13), "hA": Vector2(14, -30), "hB": Vector2(12, -26), "tilt": 0.3 },
	"fnSweep": { "dx": 11, "rot": 0.05, "hip": Vector2(3, -12), "fA": Vector2(17, -3), "fB": Vector2(0, -1), "hA": Vector2(16, -33), "hB": Vector2(13, -27), "tilt": 0.3 },
	"fnUp": { "dx": 22, "hip": Vector2(0, -9), "fA": Vector2(7, -1), "fB": Vector2(-7, -1), "hA": Vector2(8, -31), "hB": Vector2(2, -18), "tilt": 0.2 },
	"fnDown": { "dx": 22, "hip": Vector2(0, -8), "fA": Vector2(7, -1), "fB": Vector2(-7, -1), "hA": Vector2(18, -6), "hB": Vector2(2, -16), "tilt": 0.55 },
	"rise": { "dx": 20, "hip": Vector2(0, -15), "fA": Vector2(5, -1), "fB": Vector2(-5, -1), "hA": Vector2(4, -18), "hB": Vector2(-2, -17), "tilt": 0.02 },
}
const GP := {	# the watcher: a brawler - big, square, fists up
	"stance": { "hip": Vector2(0, -19), "fA": Vector2(8, -1), "fB": Vector2(-9, -1), "hA": Vector2(13, -41), "hB": Vector2(8, -36), "tilt": 0.06 },
	"windup": { "rot": -0.05, "hip": Vector2(-3, -19), "fA": Vector2(7, -1), "fB": Vector2(-10, -1), "hA": Vector2(10, -40), "hB": Vector2(-13, -43), "tilt": -0.2 },
	"punch": { "dx": 4, "hip": Vector2(3, -19), "fA": Vector2(11, -1), "fB": Vector2(-8, -1), "hA": Vector2(6, -36), "hB": Vector2(24, -41), "tilt": 0.25 },
	"stumble": { "dx": 3, "hip": Vector2(1, -18), "fA": Vector2(10, -1), "fB": Vector2(-6, -1), "hA": Vector2(10, -27), "hB": Vector2(-6, -25), "tilt": 0.3 },
	"hitHead": { "dx": -2, "hip": Vector2(-3, -19), "fA": Vector2(6, -1), "fB": Vector2(-10, -1), "hA": Vector2(5, -36), "hB": Vector2(-2, -33), "tilt": -0.32 },
	"hitHead2": { "dx": -3, "rot": -0.03, "hip": Vector2(-3, -19), "fA": Vector2(6, -1), "fB": Vector2(-10, -1), "hA": Vector2(2, -34), "hB": Vector2(-4, -31), "tilt": -0.22 },
	"lookUp": { "hip": Vector2(-1, -19), "fA": Vector2(7, -1), "fB": Vector2(-8, -1), "hA": Vector2(10, -44), "hB": Vector2(6, -40), "tilt": -0.25 },
	"shoved": { "dx": 12, "hip": Vector2(3, -18), "fA": Vector2(12, -1), "fB": Vector2(-4, -1), "hA": Vector2(16, -30), "hB": Vector2(10, -28), "tilt": 0.45 },
	"turned": { "spin": 1, "hip": Vector2(0, -19), "fA": Vector2(8, -1), "fB": Vector2(-9, -1), "hA": Vector2(13, -41), "hB": Vector2(8, -36), "tilt": 0.06 },
	"fold": { "dx": -1, "hip": Vector2(-2, -18), "fA": Vector2(7, -1), "fB": Vector2(-8, -1), "hA": Vector2(6, -26), "hB": Vector2(3, -24), "tilt": 0.55 },
	"buckle": { "rot": 0.05, "hip": Vector2(-1, -15), "fA": Vector2(6, -1), "fB": Vector2(-9, -1), "hA": Vector2(10, -34), "hB": Vector2(4, -30), "tilt": 0.15 },
	"flung": { "dx": -10, "hip": Vector2(-5, -19), "fA": Vector2(2, -1), "fB": Vector2(-12, -1), "hA": Vector2(-4, -46), "hB": Vector2(-10, -40), "tilt": -0.5 },
	"flung2": { "dx": -20, "hip": Vector2(-5, -19), "fA": Vector2(2, -1), "fB": Vector2(-12, -1), "hA": Vector2(-6, -47), "hB": Vector2(-12, -41), "tilt": -0.55 },
	"dazed": { "hip": Vector2(-2, -18), "fA": Vector2(6, -1), "fB": Vector2(-8, -1), "hA": Vector2(6, -25), "hB": Vector2(-4, -24), "tilt": -0.1 },
	"out": { "hip": Vector2(-1, -19), "fA": Vector2(6, -1), "fB": Vector2(-6, -1), "hA": Vector2(-10, -38), "hB": Vector2(-14, -32) },
}


# The moves. Each has a track for him (n) and one for the watcher (g): [[time, pose, ease]] - "snap" is a
# strike (fast out, settling in), else smooth - and maybe fall (his fall, 0..1, from his feet), tell (his
# wind-up: the white ticks), wob (dazed) and sparks: [time, on whom ("g" him, "n" the ninja, "p" a parry:
# no harm), dx, dy (from the one hit's feet, x toward the other), size (< 1 one of several, 1.5+ heavy)].
# At the end of his track the ninja stays where the last pose left him (a hop back, over the watcher).
const STRIKES := ["jab", "cross", "body", "leg", "teep"]             # one press: one of these, at random
const SPECIALS := ["spin", "knee", "scissor", "superman", "flurry", "sweep", "flash", "vault"]   # three quick presses
const MOVES := {
	"jab": {
		"n": [[0.0, "stance"], [0.05, "stance"], [0.11, "jab", "snap"], [0.2, "jab"], [0.38, "stance"]],
		"g": [[0.0, "stance"], [0.11, "stance"], [0.15, "hitHead", "snap"], [0.3, "hitHead"], [0.6, "stance"]],
		"sparks": [[0.12, "g", -9, -42, 1.0]]},
	"cross": {
		"n": [[0.0, "stance"], [0.06, "stance"], [0.13, "cross", "snap"], [0.22, "cross"], [0.4, "stance"]],
		"g": [[0.0, "stance"], [0.13, "stance"], [0.17, "hitHead", "snap"], [0.34, "hitHead"], [0.65, "stance"]],
		"sparks": [[0.14, "g", -9, -40, 1.0]]},
	"body": {
		"n": [[0.0, "stance"], [0.05, "stance"], [0.14, "rhChamber"], [0.22, "rhKick", "snap"], [0.32, "rhKick"], [0.42, "rhBack"], [0.6, "stance"]],
		"g": [[0.0, "stance"], [0.22, "stance"], [0.27, "fold", "snap"], [0.55, "fold"], [0.9, "stance"]],
		"sparks": [[0.23, "g", -9, -28, 1.2]]},
	"leg": {
		"n": [[0.0, "stance"], [0.05, "stance"], [0.12, "rhChamber"], [0.2, "lkKick", "snap"], [0.28, "lkKick"], [0.38, "rhBack"], [0.55, "stance"]],
		"g": [[0.0, "stance"], [0.2, "stance"], [0.25, "buckle", "snap"], [0.5, "buckle"], [0.85, "stance"]],
		"sparks": [[0.21, "g", -7, -9, 1.0]]},
	"teep": {
		"n": [[0.0, "stance"], [0.06, "stance"], [0.16, "tpChamber"], [0.24, "tpKick", "snap"], [0.34, "tpKick"], [0.5, "stance"]],
		"g": [[0.0, "stance"], [0.24, "stance"], [0.3, "flung", "snap"], [0.55, "flung"], [1.05, "stance"]],
		"sparks": [[0.25, "g", -9, -24, 1.2]]},
	"spin": {
		"n": [[0.0, "stance"], [0.1, "stance"], [0.22, "sbLoad"], [0.32, "sbKick", "snap"], [0.44, "sbKick"], [0.62, "stance"]],
		"g": [[0.0, "stance"], [0.32, "stance"], [0.38, "flung2", "snap"], [0.8, "flung2"], [1.5, "stance"]],
		"sparks": [[0.33, "g", -9, -26, 2.0]]},
	"knee": {
		"n": [[0.0, "stance"], [0.1, "stance"], [0.2, "fkStep"], [0.33, "fkAir", "snap"], [0.45, "fkAir"], [0.62, "fkLand"], [0.85, "stance"]],
		"g": [[0.0, "stance"], [0.33, "stance"], [0.38, "hitHead", "snap"], [0.46, "flung2"], [0.9, "flung2"], [1.6, "stance"]],
		"sparks": [[0.35, "g", -9, -40, 2.0]]},
	"scissor": {
		"n": [[0.0, "stance"], [0.1, "stance"], [0.22, "ksLoad"], [0.38, "ksFly", "snap"], [0.58, "ksDown"], [0.9, "ksDown"], [1.15, "ksUp"], [1.6, "stance"]],
		"g": [[0.0, "stance"], [0.4, "stance"], [0.48, "stumble"], [0.75, "out"], [1.6, "out"]],
		"fall": [[0.0, 0.0], [0.45, 0.0], [0.72, 1.0]],
		"sparks": [[0.73, "g", 30, -3, 2.0]]},
	"superman": {
		"n": [[0.0, "stance"], [0.08, "stance"], [0.2, "smChamber"], [0.32, "smFly", "snap"], [0.42, "smFly"], [0.55, "smLand"], [0.8, "stance"]],
		"g": [[0.0, "stance"], [0.32, "stance"], [0.36, "hitHead", "snap"], [0.44, "flung"], [0.8, "flung"], [1.4, "stance"]],
		"sparks": [[0.33, "g", -9, -42, 1.6]]},
	"flurry": {
		"n": [[0.0, "stance"], [0.06, "jab", "snap"], [0.12, "cross", "snap"], [0.18, "jab", "snap"], [0.24, "cross", "snap"], [0.3, "jab", "snap"], [0.38, "palm", "snap"], [0.5, "palm"], [0.75, "stance"]],
		"g": [[0.0, "stance"], [0.07, "hitHead", "snap"], [0.13, "hitHead2", "snap"], [0.19, "hitHead", "snap"], [0.25, "hitHead2", "snap"], [0.31, "hitHead", "snap"], [0.4, "flung2", "snap"], [0.8, "flung2"], [1.5, "stance"]],
		"sparks": [[0.07, "g", -9, -42, 0.7], [0.13, "g", -9, -38, 0.7], [0.19, "g", -9, -43, 0.7], [0.25, "g", -9, -39, 0.7], [0.31, "g", -9, -42, 0.7], [0.39, "g", -9, -36, 1.6]]},
	"sweep": {
		"n": [[0.0, "stance"], [0.08, "stance"], [0.2, "swDrop"], [0.32, "swSweep", "snap"], [0.45, "swSweep"], [0.7, "swRise"], [1.0, "stance"]],
		"g": [[0.0, "stance"], [0.32, "stance"], [0.38, "hitHead"], [0.6, "out"], [1.0, "out"]],
		"fall": [[0.0, 0.0], [0.33, 0.0], [0.62, 1.0]],
		"sparks": [[0.33, "g", -6, -4, 0.8], [0.63, "g", 30, -3, 1.8]]},
	"flash": {
		"n": [[0.0, "stance"], [0.08, "stance"], [0.2, "flCrouch"], [0.32, "flKick", "snap"], [0.44, "flOver"], [0.6, "flLand"], [0.85, "stance"]],
		"g": [[0.0, "stance"], [0.31, "stance"], [0.35, "hitHead", "snap"], [0.45, "flung2"], [0.9, "flung2"], [1.6, "stance"]],
		"sparks": [[0.33, "g", -10, -44, 1.8]]},
	"vault": {                                  # over his head, a kick in the back; he staggers, then turns
		"n": [[0.0, "stance"], [0.08, "stance"], [0.2, "vtCrouch"], [0.36, "vtPlant"], [0.5, "vtOver"], [0.62, "vtDown"], [0.74, "vtLand"], [0.86, "vtLand"], [0.96, "vtKick", "snap"], [1.08, "vtKick"], [1.25, "vtSet"]],
		"g": [[0.0, "stance"], [0.3, "stance"], [0.42, "lookUp"], [0.75, "lookUp"], [0.96, "lookUp"], [1.0, "shoved", "snap"], [1.35, "shoved"], [1.7, "stumble"], [1.85, "turned", "snap"]],
		"sparks": [[0.97, "g", 10, -30, 1.8]]},
	# moving: jump (or jump + away) hops back - short, in a fight; jump + toward him goes over him
	"hop": {
		"n": [[0.0, "stance"], [0.1, "hopCrouch"], [0.22, "hopAir", "snap"], [0.36, "hopLand"], [0.5, "hopLand"]],
		"g": []},
	"over": {
		"n": [[0.0, "stance"], [0.08, "stance"], [0.2, "vtCrouch"], [0.36, "vtPlant"], [0.5, "vtOver"], [0.62, "vtDown"], [0.74, "vtLand"], [1.0, "overSet"]],
		"g": [[0.0, "stance"], [0.3, "stance"], [0.42, "lookUp"], [0.8, "lookUp"], [0.92, "turned", "snap"]]},
	# his attack: the tell, then the haymaker. Block in the tell and it turns into "counter" (same clock).
	"late": {
		"n": [[0.0, "stance"], [1.03, "stance"], [1.09, "hit", "snap"], [1.4, "hit"], [1.8, "stance"]],
		"g": [[0.0, "stance"], [0.3, "windup"], [0.95, "windup"], [1.04, "punch", "snap"], [1.25, "punch"], [1.6, "stance"]],
		"tell": [0.3, 1.02], "sparks": [[1.06, "n", 4, -38, 1.3]]},
	"counter": {
		"n": [[0.0, "stance"], [0.45, "stance"], [0.52, "block", "snap"], [0.98, "block"], [1.04, "parry", "snap"], [1.1, "parry"], [1.15, "palm", "snap"], [1.3, "palm"], [1.6, "stance"]],
		"g": [[0.0, "stance"], [0.3, "windup"], [0.95, "windup"], [1.03, "punch", "snap"], [1.08, "stumble"], [1.14, "stumble"], [1.18, "flung", "snap"], [1.5, "flung"], [2.0, "stance"]],
		"tell": [0.3, 1.0], "sparks": [[1.05, "p", 14, -37, 0.8], [1.16, "g", -9, -36, 1.3]]},
	# dazed: the next press is the finisher - clinch, a knee, the sweep, one more on the floor
	"finish": {
		"n": [[0.0, "stance"], [0.12, "fnGrab"], [0.3, "fnGrab"], [0.38, "fnKnee", "snap"], [0.5, "fnKnee"], [0.62, "fnGrab"], [0.74, "fnSweep", "snap"], [1.0, "fnSweep"], [1.3, "fnUp"], [1.42, "fnDown", "snap"], [1.65, "fnDown"], [2.2, "rise"]],
		"g": [[0.0, "dazed"], [0.32, "dazed"], [0.4, "fold", "snap"], [0.65, "fold"], [0.75, "hitHead"], [1.0, "out"], [2.2, "out"]],
		"fall": [[0.0, 0.0], [0.74, 0.0], [1.12, 1.0]],
		"sparks": [[0.4, "g", -9, -30, 1.0], [1.13, "g", 30, -3, 1.5], [1.43, "g", 17, -5, 1.2]]},
	# he got up again (a takedown that didn't finish him)
	"getup": {
		"n": [],
		"g": [[0.0, "out"], [0.45, "dazed"], [0.8, "stance"]],
		"fall": [[0.0, 1.0], [0.45, 0.0]]},
}

# A pose by name, with the defaults filled in.
static func pose(table: Dictionary, name: String) -> Dictionary:
	var p := POSE0.duplicate()
	p.merge(table[name], true)
	p.name = name
	return p

# The pose at time t along keys [[time, name, ease], ...], eased between; rot takes the short way round.
static func pose_at(keys: Array, table: Dictionary, t: float, idle: String) -> Dictionary:
	if keys.is_empty():
		return pose(table, idle)
	var i := 0
	while i < keys.size() - 1 and keys[i + 1][0] <= t:
		i += 1
	var A: Array = keys[i]
	var B: Array = keys[mini(i + 1, keys.size() - 1)]
	var u := clampf((t - A[0]) / (B[0] - A[0]), 0.0, 1.0) if B[0] > A[0] else 0.0
	u = 1.0 - pow(1.0 - u, 3.0) if B.size() > 2 and B[2] == "snap" else u * u * (3.0 - 2.0 * u)
	var pa := pose(table, A[1])
	var pb := pose(table, B[1])
	var o := {}
	for k in pa:
		if pa[k] is Vector2:
			o[k] = (pa[k] as Vector2).lerp(pb[k], u)
		elif k == "rot":
			var d: float = pb.rot - pa.rot
			d -= TAU * roundf(d / TAU)
			o.rot = pa.rot + d * u
		else:
			o[k] = lerpf(float(pa[k]), float(pb[k]), u)
	o.name = A[1] if u < 0.5 else B[1]
	return o

static func num_at(keys: Array, t: float) -> float:   # [[time, value], ...], eased between
	if keys.is_empty():
		return 0.0
	var i := 0
	while i < keys.size() - 1 and keys[i + 1][0] <= t:
		i += 1
	var A: Array = keys[i]
	var B: Array = keys[mini(i + 1, keys.size() - 1)]
	var u := clampf((t - A[0]) / (B[0] - A[0]), 0.0, 1.0) if B[0] > A[0] else 0.0
	return lerpf(A[1], B[1], u * u * (3.0 - 2.0 * u))

static func track_end(keys: Array) -> float:
	return keys[-1][0] if not keys.is_empty() else 0.0

static func spin_scale(s: float) -> float:          # the turn, as a squeeze: never quite flat
	var k := cos(PI * s)
	if absf(k) >= 0.3:
		return k
	var m := fposmod(s, 2.0)
	return 0.3 if m < 0.5 or m > 1.5 else -0.3

# A pose's points on screen, for a fighter standing at x (his feet at by), facing f.
static func rig(x: float, by: float, f: float, p: Dictionary, B: Dictionary) -> Dictionary:
	var sx := spin_scale(p.spin)
	var hip := Vector2(p.hip.x + p.dx, p.hip.y - p.lift)
	var r: float = p.rot
	var map := func(q: Vector2) -> Vector2:
		var l := (q - hip).rotated(r)
		return Vector2(x + f * (hip.x + l.x * sx), by + hip.y + l.y)
	var L := func(q: Vector2) -> Vector2: return Vector2(q.x + p.dx, q.y - p.lift)   # a hand or foot, moved with him
	var Tt := func(q: Vector2) -> Vector2: return hip + q.rotated(p.tilt)              # a body point, tilted
	return {"sx": sx, "fe": f * signf(sx), "hip": map.call(hip),
		"fA": map.call(L.call(p.fA)), "fB": map.call(L.call(p.fB)), "hA": map.call(L.call(p.hA)), "hB": map.call(L.call(p.hB)),
		"sh": map.call(Tt.call(B.sh)), "ta": map.call(Tt.call(B.ta)), "tb": map.call(Tt.call(B.tb)),
		"head": map.call(Tt.call(B.head)), "neck": map.call(Tt.call(B.neck)),
		"ear": map.call(Tt.call(Vector2(-3, -31))), "collar": map.call(Tt.call(Vector2(-5, -24)))}

# How much a blow takes off him: a strike 0.2, a special 0.4, one of a flurry a little.
static func damage(size: float) -> float:
	return 0.4 if size >= 1.5 else (0.04 if size < 1.0 else 0.2)
