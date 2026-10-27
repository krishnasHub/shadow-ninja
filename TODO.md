# Shadow Ninja - hand-off

2D side-scrolling stealth game. A ninja has broken into a high-security office tower and has to get **out**. Stay in shadow; light gets you caught.

Run it: open `index.html` in a browser (single file, no build).

## Pillars
- **The light you see is the light that catches you.** Rendering and detection use the same geometry (visibility polygon + cone + falloff). Never fake one without the other.
- **Light is the puzzle.** Every action (takedown, switch, stone) should change the lighting landscape.
- **Limbo look.** Strict greyscale, black silhouettes, fog, film grain, parallax: far layers drift slowly, near/foreground layers sweep past fast.
- **Caught is a meter, not a moment.** Exposure fills it, shadow drains it. Over the threshold = game over. In between, guards hunt you: hide, then flee.

## Story and progression (user's design, 2026-10-26)
- **Premise:** the ninja broke into the tower and stole "the formula" from a machine full of vials. Its countermeasure sprayed him, and he **lost his memory**. He has to get out, floor by floor, and remembers more as he goes. Remembering brings back abilities, and each memory adds **one dash of colour** somewhere (first: his scarf turns deep red).
- **Art rule:** everything stays greyscale, the vials included. No fog or haze effects. Colour appears only as these memory accents.
- **Opening (start of Floor 1):** fade in on the ninja facing the left wall, by an open machine with vials, its alarm light pulsing. A hint tells you to hide behind the nearest furniture, with about 10 s to do it. Two guards come running. If they see you, it's the normal meter and caught. If you stay hidden, a **cutscene** plays: black letterbox bars, no control, text lines over the guards:
  "What happened?" / "Looks like someone stole the formula!" / "What was it?" / "I don't know, but I heard it has a countermeasure.. it sprays a chemical at anyone trying to steal it." / "Ohh? What does the chemical do?" / "I'm not sure.. but I think the thief loses memory.. maybe temporarily?"
  They leave to search, the bars go, and Floor 1 starts. (Make it skippable, and skip it on a retry.)
- **Floor ladder:**
  | Floor | What's new |
  |---|---|
  | 1 | intro: basic moves, the exit (no ducts, no takedowns) |
  | 2 | remembers clinging to ceilings and putting guards to sleep; a camera to avoid |
  | 3 | everything so far, plus up to the lever and back down (current Floor 3) |
  | 4 | throwing stars: break lights and cameras |
  | 5 | moving objects to make new shadows |
  | 6 | bigger; he can **fight** (karate/judo moves) a new guard type, vigilant and with no torch. A fight only works in shadow: step into light and you're caught anyway |
  | 7-8 | he remembers who he is: he works for **Evil Co**, and the formula is a **vaccine** he was sent to steal |
  | 8-10 | redemption |
- Rework needed: the current Floor 1 uses ducts and takedowns, so it moves to Floor 2's role. Floor 1 becomes the intro.

## Phase B (done, Godot, 2026-10-26)
- **The opening** (`intro` in the lab's data; `update_intro` in main.gd): "hide" (the wake, `WAKE` in main.gd: the music carries on from the title over 1.5 s of near-black, the room fades in by 7 s and he can move; at 9 s the machine's alarm light and siren come up, full by 13 s; at 11 s "footsteps. hide - ↓ behind the bench." with a 10 s count) → "arrive" (the two guards with `intro_to` run in at 1.6x chase speed) → "talk" (letterbox bars, no control, nobody detects, they turn to face each other, torches lowered; one line at a time in the bottom letterbox bar under the speaker, small spaced grey caps, each word drifting up into place, the line lifting away at the end; ~half-heard~ words are faint; the speaker nods and his free hand points, shrugs or moves with the words (`talk_body`), and in the cutscene the guards get elbows; they shut the alarm light off, so he's in the dark when it ends; SPACE/A next, ESC/START/B skip) → "leave" (they run off the right edge and are removed, or vanish at once on a skip; the bars slide away, the floor's name shows). After the talk the lab has no guards. If they see or hear you before the talk, the scene just ends and they hunt you. A retry (R) after the talk starts with no guards and the alarm off; New Game or a pick from Levels always plays the opening. Self-test: `--selftest=intro` (also checks the lab's route).
- **Memory:** each floor's `remember` (abilities, colours, two lines) applies to the floors after it, including when you pick a floor from the Levels menu. The lab gives back **cling** and **takedowns** (gated in code: no duct grab, no takedown before that); the archive gives back the **red scarf** (deep red, darker in shadow; the only colour in the game). The end screen shows the memory's two lines in place of "down the stairs"; a colour memory's line is in that red.
- **Hints are muted during the talk.** Lights with `danger: 0` (the machine's alarm) don't count as exposure at all.

## Phase A (done, both versions, 2026-10-26)
- Only a **camera** spotting you raises the alarm: a 30 s countdown. Leave the floor in time, or hit the **alarm panel** with a stone, to cancel it.
- If it runs out: **lockdown.** Every guard goes on alert and hunts for you for about 30 s, then they go back to normal. Stay hidden.
- The end screen shows clear time, best time per floor, and "alarm raised" if it went off.
- How it's built: `panels: [[x, row]]` in the level data (Floor 2 at 88.5, reachable from behind the cooler at 81; Floor 3 at 83.5 upstairs, from behind the rack at 78). The panel light pulses slowly, blinks fast during an alarm, and sparks out when broken. Sounds: siren.wav (loop) and panel.wav. `ALARM` = countdown 30, lockdown 30, and a regroup every 5 s (guards in lockdown are sent searching near where you were seen). "ALARM 0:24" / "LOCKDOWN" shows top centre. Best times: Godot `user://records.cfg` (self-tests never touch it), HTML localStorage `shadowNinja.best`. Self-test: `--selftest=alarm`.
- **Lock-on:** a chasing guard keeps you in sight while you're within his torch's reach with a clear line, even outside the beam. He turns to you after `GUARD.reaction` (0.3 s) once you're behind him, and his torch tracks faster. He loses you only if you hide, a wall cuts the line, or you get out of reach. A camera that sees you stops sweeping and follows you (`CAM_LOCK`: 0.8 rad/s, within its arc + 0.3), lets go when you hide or break the line, then eases back into its sweep. Standing still under a camera now gets you caught. Self-test: `--selftest=lockon`.
- **Locked doors:** walking into one rattles it (rattle.wav, a small noise) and says "locked. the switch is upstairs." (or downstairs, from where its lever is).
- **Floor 3 stairs lamp:** dimmed to 0.55 and flickering (4 s cycle, on half of it), so there's a dark window to climb in.
- **Hints are his memory:** each fades in when he's within 5 tiles of it on the same storey (it's on the wall above his feet, less than 12 tiles up), and fades away as he moves on. They also drift into place and breathe gently. Hidden on the title screen.
- **Controller (Xbox layout, both versions):** stick/d-pad move, A jump, B crawl (and cancel a throw), hold LT (or LB) sneak, hold RT (or RB) to aim with the right stick and let go to throw (how far you push sets the range), Start pause, View restart, Y music. In menus: stick/d-pad, A select, B back. Every prompt (footers, end screens, the throw-mode line, the HUD's key line, Floor 1's hints via an optional 4th hint field) switches to button names when the pad was the last thing used. Godot uses `Input` joypads (any connected pad); HTML uses the Gamepad API (polled each step).
- **How to play:** the first New Game shows a card with both columns (keyboard | controller), with the active device brighter. Any key or button starts. The Controls page uses the same 3-column table.

## Platform decision
- Prototype in **HTML5 Canvas** (here) to find the fun fast.
- If it grows: **Godot 4** for pure 2D (built-in 2D lights/occluders, HTML export).
  **Unreal** only if we go 2.5D (3D world, side camera, like *Inside*). Paper2D is neglected.

## Mechanics (target)
| Mechanic | Status |
|---|---|
| Run by default / hold Shift to sneak / jump (coyote + buffer, variable height) | ✅ M1 |
| Hide: ↓ while over a desk, plant or water cooler → drawn behind it, lights can't reach you (exposure 0). A "↓" nudge shows when you're in front of one | ✅ M4a |
| Crawl (↓) - low hitbox, fits under 1-tile gaps, can't stand if blocked | ✅ M1 |
| Lights: ceiling lamps, moonlight skylights, flickering fluorescent, exit sign | ✅ M2 |
| Detection meter (3 sample points: head/torso/feet) + eye indicator + heartbeat vignette | ✅ M2 |
| Ninja is a black silhouette in shadow, turns light grey when lit | ✅ M2 |
| Guards with torches: Patrol → Chase (torch on you, "!") → Search (sweeps, "?") → Return. Torch = a moving `light()`, polygon recomputed each frame. 2 guards share the moonlight/flicker floor | ✅ M3 |
| Ceiling cling: jump into a duct (tile value `GRIP` = 2) and you grab it automatically; ← → shimmy (80, silent), ↓ drop. Ducts are solid occluders, so they cast shadows. 3 ducts: tutorial (18-23), over each guard's patrol | ✅ M4 |
| **Hiding rule (user's call):** hiding beats every light, *unless* a guard had you in his torch when you ducked (within `GUARD.sawYouHide` = 0.4s). Then he knows that spot and his torch finds you there. If his back was turned or his beam never touched you, he walks right past. HUD says "HE SAW YOU HIDE - GO" | ✅ M3 |
| Takedown: come down on a guard (jump onto him) while he can't see you → asleep for good, torch off, thud noise. A guard whose torch finds a sleeping colleague goes on alert (35% faster, searches 7s, "!!"/"??") | ✅ M5 |
| Takedown by dropping from a duct onto a guard (same rule: he mustn't be seeing you) | ✅ M4 |
| Sleeping guards never wake (user's call). `GUARD.wakeAfter` (now `Infinity`) is the knob for a harder difficulty; when it runs out the guard wakes alert and searches | ✅ |
| Walls block sound: each noise gets a visibility polygon (same as lights). Guards only hear it with a clear line, and the bubble is drawn clipped to that polygon so it stops at walls | ✅ |
| **Limbo-style weight (user's call, both versions, every actor):** speed starts at 8% and eases up (smoothstep) to full over `ramp*` seconds (run 0.9, sneak 0.6, crawl 0.4, duct 0.5; guards 1.0). Leg and arm swing grow with speed, so a slow first step is a small step. Stopping and turning ease down at `decel` (ninja: about 0.2s and a 22px slide from a run). Guards also slow as they reach their target. Air control is unchanged. Measured: run 29→50→82→120→160→197 px/s at 0.1s steps (full 260 at 0.9s). Second pass after the user found the first one too abrupt | ✅ |
| **Controls (user's call, both versions):** A D / ← → move, SPACE / W / ↑ jump (and grab ducts), S / ↓ crawl + hide + drop, Shift sneak. **Ctrl toggles throw mode**: the ninja holds still and faces the cursor (ducking still works), the mouse aims, a click throws and ends the mode; Ctrl again cancels. Outside throw mode the mouse does nothing. F and E are no longer used | ✅ |
| Stone aimed with the **mouse** (in throw mode). A dotted arc shows the exact path (`predictPath` runs the same `stoneStep` physics as the real stone, verified to match to the pixel). Range is set by `STONE.maxSpeed` (700 ≈ 10 tiles on the flat); past it the cursor becomes a crossed ring saying "too far" and the arc shows where the stone will really fall short. 3 in pouch, picked up again by walking over it. The clack (280px) sends guards to investigate → search → return | ✅ M5 |
| Noise: running footsteps (150px) and hard landings (120px) are loud; Shift-sneak (including landing while holding it) and crawling are silent. Shown as fading rings | ✅ M5 |
| Light switches (guard comes to switch it back on = lure), cameras | ⬜ later |
| Multiple floors (start top, work down), sound pass | ⬜ later |

## Floors
- **Godot is the game from phase B on (user's call, 2026-10-26).** `index.html` is frozen at phase A: it keeps its old three floors (offices, security, archive) and gets no new features. Floors are data in `godot/scripts/levels.gd` (the format is documented at the top).
- **The order now:** 1 the lab (new: the opening scene, then the basics) · 2 the offices · 3 the archive · 4 security (the old Floor 2, kept as the base for the throwing-stars floor).
- **Floor 1, the lab** (80 tiles): the vial machine against the left wall (open, one vial gone, its alarm light flashing; that light can't fill the meter), a bench a step away to hide behind, then lamps and cover with the two guards from the opening (one lamp flickers), a stone lure, pipes to crawl under (x52-55), crates to climb (x59, x62), and the exit at 77. No ducts, no takedowns: you don't remember them yet.
- **Floor 2, the offices:** the old Floor 1, plus a **camera** over the raised floor (81.5) and its **panel** (84.5, a throw from behind the plant at 80).
- Clearing a floor shows "FLOOR n CLEARED", where Enter goes to the next floor, R replays it, and Esc goes to the menu. Each floor opens with its name fading in. Clearing the last floor shows "OUT".
- **Floor 4, security** (120 tiles, the old Floor 2): a cubicle row of desks under a strip of lights (one flickers), a crate climb to a **catwalk** with its own guard and lamp over a lower floor with a second guard and a small lamp, then a corridor watched by a **security camera**, a guard posted near the exit, and coolers/plants/desks to hide behind. 4 guards.
- **Floor 3, the archive** (100x26 tiles, two storeys): start on the lower storey, where a **locked security door** blocks the way out. Climb the **stairs** (a crate, a hop to the first step, then just walk) to the upper storey's server room (racks, a sweeping camera, a guard, a lit lever at the far end). **Walk up to the lever and the ninja pulls it himself** (he stops, reaches, the handle swings down, and there's a clunk that guards can hear). He reaches it from `lever_reach` (48px, 1.5 tiles) either side and steps over to it first. Playtest bug fixed: the reach used to be 14px, so jumping past the lever landed you between it and the wall with nothing happening (1 in 3 runs got stuck). The lever is now at 98.3, against the wall: nowhere beside it is out of reach, and he pulls it in shadow, just past the lamp's cone (exposure 0 for the whole pull). You still have to cross the light to get there. **The pull is made obvious** (playtest: a pull in the dark went unnoticed, so it looked like the bug was still there). It has three cues: a clunk, then a distant bolt (**lever.wav**); the lever's light (blinks while armed, flares on the pull, then stays on); and "a door unlocks below." fading in mid-screen like the floor name ("above"/"" is picked from where the door is). That opens the door. Then back down the stairs, under them, through the door, and out. 4 guards, one upstairs.
- **Verticality** (both versions): floors can be taller (`height`); the camera follows vertically; the far and mid parallax layers drift vertically (0.2 / 0.5) and the foreground stays put vertically. The exit is on `exitRow`, and you must be on that row to leave.
- **Stairs:** any 1-tile step at your feet is walked up automatically (`P.y` steps up when the tile above is free). The floating steps leave room to walk underneath. Landings up to 3 tiles are now quiet (`land_noise_v` 600).
- **Doors and switches:** `doors: [x, y, w, h]` are solid DOOR tiles (3), and `switches: {x, row, door}`. Opening a door clears its tiles and rebuilds the light geometry (segments + Godot occluders / HTML light polygons). The lock light blinks until it opens. A retry (R) resets every lever and locks its door again. **Keep a lever within `lever_reach` of any wall**, or there's a spot beside it that can't pull it.
- **Server rack** prop (hide behind it, 40px wide, tall) with blinking status lights.
- **Levels menu** (both versions, user's call; may be removed later): title and pause menus list every floor; pick one to play it.
- **Cameras** (new on Floor 2): a narrow beam that sweeps (`sweep: [amplitude, period]`), fills the meter (danger 1.5), can't be put to sleep, and is beaten by hiding. When it sees you it calls the nearest awake guard to where you stood (at most every 1.5s). Its status light blinks while watching and goes solid when it sees you.
- Guards now have a `row` (the tile row they stand on), so they can patrol catwalks.

## Music (both versions)
- `tools/make_music.py` composes and renders it with numpy (original, reproducible: edit, then `python tools/make_music.py`). Two seamless 60 s loops in D minor at 64 BPM, 22 kHz mono WAV (2.6 MB each) in `godot/audio/`. The HTML version plays the same files.
  - **base**: warm detuned pad (Dm(add9) - Bbmaj7 - Gm9 - A7sus4, 4 bars each), a low D drone, sparse pentatonic plucks with a dotted-eighth echo, and a soft low pulse on beats 1 and 3. Always on.
  - **tension**: a muted bass ostinato on the chord roots, a dry 16th tick, and a thin high shimmer. Same chords and length, started together with the base.
- The tension layer's volume follows danger: meter x 1.3, a chasing guard 0.9, a searching/investigating guard 0.45, a camera on you 0.7. It rises quickly (0.6/s), settles slowly (0.2/s), and holds while paused. Levels: base -7 dB, tension -5 dB at full.
- **The meter, heard** (`METER_AUDIO` in both versions): past 25% a muffled **heartbeat** starts and quickens from 70 to 150 BPM as the meter fills, getting louder. The screen's red-edge pulse now throbs once per beat. Past 45% an uneasy high **tone** (riser.wav: minor seconds plus a tritone, looping) fades in and rises up to +18% in pitch. The base music dips by up to 35%. Being caught plays **caught.wav** (a deep impact and a dissonant stab). Pulling a lever plays **lever.wav** (a clunk, then a bolt sliding back). It's rendered last in `make_music.py`. Note: re-running the script no longer reproduces the committed caught.wav/riser.wav byte for byte, so check `git status` after a render. Measured: meter 0.5 -> about 100 BPM, 0.8 -> 130, 0.98 -> about 145.
- **M** toggles the music (the heartbeat, tone and sting are sound effects and keep playing). In the browser it starts on the first key press or click (browsers block sound before that).
- Godot loads the WAVs at runtime (`AudioStreamWAV.load_from_file`), so a fresh clone needs no import step. Self-test: `--selftest=music`.

## Meter rules (current)
- `exposure` = sum over lights of avg light at 3 body points, capped at 1.
- Fills at `exposure × fillRate` (0.38/s). After `drainDelay` (1.2s) in full shadow, drains at 0.12/s.
- Each light has a `danger` multiplier on fill: lamps 1, guard torch 1.3 (standing in a beam ≈ 2.5s to caught).
- While any guard is chasing or searching, the meter does **not** drain. Shake them first.
- Moonlight is weaker (0.45) but flat; lamps fall off with distance.
- The `METER_SUSPICIOUS`/`METER_ALERT` tick marks on the HUD are unused so far. Either use them (e.g. guards hear you when the meter is high) or remove them.

## Godot port (`godot/`)
A full port of the HTML version (same level, mechanics and numbers) in Godot 4.7, GL Compatibility renderer.
- Play: `godot --path godot`. Edit: `godot -e --path godot` (or import `godot/project.godot` in the Project Manager).
- `scripts/main.gd` = all game logic (a line-by-line translation of index.html). `scripts/draw_node.gd` = all world drawing, picked by `kind`. `scripts/hud.gd` = HUD and screens. `shaders/post.gdshader` = grain + vignette + heartbeat.
- Lights are Godot `PointLight2D`s with shadows. Their textures are baked from the same `stops` + `CONE_SOFT`, and the occluders are the same tile runs. Detection still uses our own rays (`light_at`), so the rule holds.
- Everything is built in code (no TileMap or hand-made scenes yet). Moving the level to a TileMap is the step that unlocks editing levels in the Godot editor.
- Dev tools: `godot_console --headless --path godot -- --selftest=1` replays the scenarios verified in the HTML version (all pass). `godot_console --path godot -- --capture=out.png --setup=chase --frames=45` saves a screenshot (setups: title, lamp, chase, cling, moon).
- **Menus (both versions):** title = New Game / About / Controls / Quit; Esc in play opens the same menu with Resume on top, and the game freezes behind it. ↑↓ or W/S + Enter/Space, or mouse hover + click; Esc goes back or resumes. About = a few lines on the game plus the controls table. Caught/escaped: R retries, Esc goes to the title menu. Quit asks "Are you sure?" (No is the default; ← → choose, Y/N shortcuts, Esc = No). `run.bat` launches fullscreen; F11 toggles. Self-tests: `--selftest=1`, `--selftest=throwmode`, `--selftest=menu`, `--selftest=quit`, `--selftest=floor2` (transition, the catwalk climb, cameras), `--selftest=floor3` (the whole route: stairs, lever, door, out). Screenshot setups also include floor2, catwalk, camera, floor3, stairs and lever.
- **Hard-edged light cones** in both versions (user's call: `CONE_SOFT = [1]`; Godot also uses 512px light textures with a 1-texel anti-aliased edge, PCF shadows with no smoothing, and a 4096 shadow atlas). HTML Quit can't close a browser tab it didn't open, so it shows a goodbye screen instead. Differences from HTML: no blur on the foreground silhouettes, and the overlay (eyes/hints) draws above the foreground leaves.

## Code map (`index.html`)
- `TUNE` - every gameplay number in one place.
- Level is built with `fill(x,y,w,h)` calls (tile units, T=32), 100×17 tiles, 5 sections with in-world hint text.
- `buildSegments` merges tile edges → `visibilityPolygon` (cached per light) → `drawLight` / `lightAt` share `CONE_SOFT` + `stops`.
- Render order: fog → far city (0.18) → mid office wall (0.5) → tiles/props/ninja → **multiply lightmap** → **screen haze** (light shafts) → eyes/hints → foreground (1.35, blurred) → grain + vignette → HUD.
- `G` toggles debug: occluder segments, light polygons, body sample points, fps.

## Next
1. **Playtest by hand** (not done yet): tune jump, crawl speed, meter fill/drain, lamp radius, guard speeds (`GUARD`).
2. All the core mechanics from the original idea are in. Next: a real designed floor (top of the tower, working down), then a sound pass.
3. Difficulty settings: wakeAfter, guard speeds, torch reach, meter fill rate.
4. Known simplification: sound travels in straight lines only (no bending around corners), though it does pass through openings like the vent gap.

Verified by script (M4): jump into a duct → cling at its underside, shimmy stops at the duct's end, ↓ drops; a guard patrolling right under a clinging ninja doesn't see him; dropping onto him puts him to sleep. Sound: open floor 256px → heard; behind the raised floor 304px → not heard.

Verified by script (M5): running behind a guard draws him over and sneaking doesn't; a stone thrown from behind a desk lands past a guard and he walks away to check it (meter stays 0); jumping on a guard from behind puts him to sleep; the other guard finds the body and goes on alert.

Verified by script (not by hand): ducking in a beam → guard walks over and catches you; hiding before he looks → he patrols right over you with the meter at 0; spotted then out of sight → chase > search > return > patrol.
- **Characters:** `tools/characters.html` is the character sheet (stand, sneak, the anime run, jump, crawl, cling; the guards' gaits; the speech mock-ups). Knee rule: standing, the leg's segments are exactly half the hip-to-floor length, so it's straight; moving, they grow and the knee comes forward. Running flat out (`dashing()`) is the anime run: body pitched 0.62 rad from the hip, arms streaming back. Elbows only in cutscenes; in play the arms stay as they were.
- **Throwing stars (phase C, Floor 4):** remembered on clearing Floor 3 (with the scarf). Throw mode throws whatever's in hand; Q / Tab (controller X) switches stone and star, and an empty hand switches by itself. `STAR`: 3 a floor, 950 px/s in a straight line, 700 px reach, not picked up again. One through a lamp's bulb or a camera's housing puts it out until a retry (`break_light`): a lamp's shade hangs crooked and glass glints on the floor, and the glass is loud (`NOISE.glass` 300 px - guards come to look); a camera's lens droops, it sparks, and it never sees you again. A miss bites into the wall (a tink). The aim shows a dotted line and rings the light it would hit. Floor 4: a bright lamp over open floor at 16.5 to learn on; the camera at 90.5 can be blinded from the end of the catwalk (the duct blocks a throw from behind the cooler). Sounds: whoosh, glass, tink. Self-test: `--selftest=stars`.
- **Memory colour (the rule):** one colour on one thing - the scarf - and only in shadow. Lit, he's the grey he always was. Each floor's `remember.scarf` (0..1) sets how far up the scarf the colour has climbed from the tip; it deepens from maroon to a full dark red as it climbs (`_scarf` in draw_node.gd, fading out by half-lit). Plan: 0.25 after Floor 3 (in now), then 0.45, 0.65, 0.85, and 1.0 at the last step, together with `colors: ["mark"]` - the Evil Co mark on his chest, a grey diamond a shade off his body, seen lit or not (`_mark`). No hands. Mocked up in `tools/characters.html` (Memory · colour over time).
