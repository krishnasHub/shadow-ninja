# Shadow Ninja - hand-off

2D side-scrolling stealth game. A ninja has broken into a high-security office tower and has to get **out**. Stay in shadow; light gets you caught.

Run it: open `index.html` in a browser (single file, no build).

## Pillars
- **The light you see is the light that catches you.** Rendering and detection use the same geometry (visibility polygon + cone + falloff). Never fake one without the other.
- **Light is the puzzle.** Every action (takedown, switch, stone) should change the lighting landscape.
- **Limbo look.** Strict greyscale, black silhouettes, fog, film grain, parallax: far layers drift slowly, near/foreground layers sweep past fast.
- **Caught is a meter, not a moment.** Exposure fills it, shadow drains it. Over the threshold = game over. In between, guards hunt you: hide, then flee.

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
| **Controls (user's call, both versions):** A D / ← → move, SPACE / W / ↑ jump (and grab ducts), S / ↓ crawl + hide + drop, Shift sneak. **Ctrl toggles throw mode**: the ninja holds still and faces the cursor (ducking still works), the mouse aims, a click throws and ends the mode; Ctrl again cancels. Outside throw mode the mouse does nothing. F and E are no longer used | ✅ |
| Stone aimed with the **mouse** (in throw mode). A dotted arc shows the exact path (`predictPath` runs the same `stoneStep` physics as the real stone, verified to match to the pixel). Range is set by `STONE.maxSpeed` (700 ≈ 10 tiles on the flat); past it the cursor becomes a crossed ring saying "too far" and the arc shows where the stone will really fall short. 3 in pouch, picked up again by walking over it. The clack (280px) sends guards to investigate → search → return | ✅ M5 |
| Noise: running footsteps (150px) and hard landings (120px) are loud; Shift-sneak (including landing while holding it) and crawling are silent. Shown as fading rings | ✅ M5 |
| Light switches (guard comes to switch it back on = lure), cameras | ⬜ later |
| Multiple floors (start top, work down), sound pass | ⬜ later |

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
- **Menus (Godot only):** title = New Game / About / Controls / Quit; Esc in play opens the same menu with Resume on top, and the game freezes behind it. ↑↓ or W/S + Enter/Space, or mouse hover + click; Esc goes back or resumes. About = a few lines on the game plus the controls table. Caught/escaped: R retries, Esc goes to the title menu. `run.bat` launches fullscreen; F11 toggles. Self-tests: `--selftest=1`, `--selftest=throwmode`, `--selftest=menu`.
- Differences from HTML: **hard-edged light cones** (user's call: `CONE_SOFT = [1.0]`, 512px light textures with a 1-texel anti-aliased edge, PCF shadows with no smoothing, 4096 shadow atlas). The HTML version still uses the soft 3-cone edge. Also no blur on the foreground silhouettes, and the overlay (eyes/hints) draws above the foreground leaves.

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
