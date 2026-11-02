extends RefCounted
## The clues: what he finds and can't read. Floor 1's pretty much solve the case - he just can't read them yet.
##
## Words are marked word@n: it's scrawl until Floor n, then he can read it (it comes back with his memory).
## A word with no mark is always clear: numbers, mostly - his hands remember numbers first. Never name the
## scarf in any of this. Pick n so the worst word comes last.
##   title: the same markup. art: "chart", "photo", "sticky", "stamp" or "" - drawn by hud.gd.
##   lines: a line starting with ! is drawn big and circled (a code). {door} / {safe} are this game's codes.

const CLUES := {
	"lablog": {
		"title": "batch@3 7",
		"art": "chart",
		"lines": [
			"trial@6 group@3 shows@4 full@5 immunity@9",
			"212 of@2 212 alive@7",
			"this@2 is@2 not@3 a@2 weapon@6",
			"it@2 is@2 the@2 cure@9",
		],
	},
	"memo": {
		"title": "all@2 night@3 staff@3",
		"art": "stamp",
		"lines": [
			"Evil@8 Co@8 tried@4 3 times@3 to@2 buy@5 the@2 formula@5",
			"we@2 said@3 no@2",
			"they@3 will@3 send@4 someone@4",
			"the@2 cabinet@6 sprays@7 anyone@5 who@2 opens@6 it@2",
		],
	},
	"notesafe": {
		"title": "",
		"art": "sticky",
		"lines": [
			"safe@4 upstairs@5",
			"!{safe}",
		],
	},
	"notedoor": {
		"title": "",
		"art": "sticky",
		"lines": [
			"door@3 - stop@4 forgetting@7",
			"!{door}",
		],
	},
	"file": {
		"title": "contractor@6 31",
		"art": "photo",
		"lines": [
			"employer@6  Evil@8 Co@8",
			"task@5  steal@8 batch@3 7",
			"if@2 caught@4  he@3 will@3 know@4 nothing@7",
			"that@2 was@2 his@3 own@5 idea@9",
		],
	},
	"badge": {
		"title": "visitor@3 31",
		"art": "stamp",
		"lines": [
			"signed@4 in@2  03 40",
			"host@5  nobody@7",
			"company@6  Evil@8 Co@8",
		],
	},
}
