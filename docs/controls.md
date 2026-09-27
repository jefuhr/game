# First-person controls

Click or tap the scene to start. A gamepad's bottom face button also starts play.

## Level One: The East River Hop

The default scene is a beginner crossing from Lower Manhattan to DUMBO.
Follow the gold roof arrows and jump at the gold edges. Every ferry roof reached
in order saves a checkpoint. Falling in the water, pressing R / Back, or using
the pause screen's CHECKPOINT button returns you to that safe roof.
Finish at the DUMBO pier after all seven ferries. Click, tap, press gamepad A,
or use PLAY AGAIN to restart after completion. The clock is informational;
there is no time limit or penalty for falling. Pausing also pauses the clock.

The movement laboratory described below remains in `scenes/playground.tscn`.

| Input | Move | Look | Jump | Pause | Respawn | Music |
| --- | --- | --- | --- | --- | --- | --- |
| Keyboard/mouse | WASD or arrows | Captured mouse | Space | Escape | R | M or MUSIC button |
| Gamepad | Left stick | Right stick | A / Cross (bottom face button) | Start / Options | Back / Select | — |
| Touch | Drag left side | Drag right side | Hold JUMP | Top pause button | Pause, then RESPAWN | MUSIC button |

Touch movement uses a floating stick anchored where the finger lands. Separate
pointer IDs allow movement, look, and jump at the same time. Rotate the device
freely; resizing clears active touches so fingers cannot get stuck. Gamepad
sticks use a radial deadzone and preserve analog movement strength.

Browsers cannot reliably enumerate keyboards or mice. On a touch-capable device,
the touch overlay appears by default unless a gamepad is connected. Meaningful
keyboard/mouse or gamepad activity switches the active controls; touching the
screen brings touch controls back. Press a gamepad button if the browser has not
yet exposed it. Click the scene to capture the mouse when switching back to it.
The **TOUCH: AUTO / ON** button, or **T**, can pin touch controls on. A disconnected
active gamepad pauses the game and restores the available fallback. Leaving the
window or losing pointer lock pauses and clears held input.

## Background music

The `Music` autoload (`scripts/music.gd`) generates a short looping chiptune-style
pad in code, so no audio assets are required. The **MUSIC: ON / OFF** button below
the TOUCH button, or **M**, mutes and unmutes it. The choice is saved in
`user://settings.cfg` and restored on the next launch. Browsers only start audio
after the first click or tap.

## Movement

`scenes/player.tscn` is a reusable capsule-based `CharacterBody3D` with a camera.
Tune exported values on the player or in `scripts/player.gd`:

- Ground speed: 7 m/s; ground acceleration: 10; friction: 6; stop speed: 2.5 m/s.
- Gravity: 20 m/s²; jump speed: 7 m/s.
- Air acceleration: 12; projected air wish-speed cap: 0.8 m/s.
- Auto bunny hop: enabled. Holding jump skips ground friction on each takeoff.

Acceleration is limited along the desired direction, preserving perpendicular
momentum for air strafing. This is Source-inspired movement, not a frame-exact
Source engine port. Crouching and stair stepping are not implemented. Ramps use
Godot's floor snapping and sliding; surf ramps (below) use Source-style clipping.

Input is centralized in the `Controls` autoload. Mouse look accumulates
screen-relative deltas. Touch look tracks its own finger positions and converts
the difference to screen pixels to avoid spurious browser multitouch deltas.
Stick look uses angular speed multiplied by elapsed time.
Sensitivity values live in `scripts/controls.gd`. The test arena has ramps,
jump blocks, pillars, walls, a surf ramp, a speed readout, and a fall-triggered respawn.

## Surf ramp

Counter-Strike style surfing lives along the left side of the arena. Climb the
**SURF STAIRS** on the back wall to the start deck (7.5 m up), then drop onto
the floating teal wedge. Its faces are 55° — steeper than the 45° floor limit —
so you cannot stand on them. Hold strafe **toward** the ramp face to stay on it
and steer with the mouse/stick like an air strafe; gravity builds speed as you
surf down and across. You can also reach the ramp by bouncing on the pink floor
tiles beside it and strafing onto a face. Fall off and you land on the floor.

Any `StaticBody3D` in the `surf` group works. While airborne, hitting one of its
upward-facing faces that is steeper than `floor_max_angle` removes only the
velocity going into the face (Source's clip velocity); all speed along the face
is kept. Vertical ends and walkable tops behave like normal geometry. Tune the
wedge with the `SURF_*` constants in `scripts/arena.gd`. It is one prism mesh and
one convex collider to stay cheap on mobile.

## Trampolines

The pink cuboids in the **TRAMPOLINES** court (right side of the arena) launch
the player. There is a floor pad under a ceiling pad, a slope facing the right
wall, and a pad mounted on that wall. Any `StaticBody3D` in the `trampoline`
group works at any orientation: its local +Y face is the bouncy side, and its
other faces are solid. Add more with `_trampoline()` in `scripts/arena.gd`.

On contact, the player's velocity into the face is replaced by a launch along the
face normal; speed along the surface is kept. Launch speed is
`trampoline_min_launch + impact × trampoline_restitution` (6 m/s + 0.6 × impact),
capped at `trampoline_max_launch` (24 m/s), so harder impacts launch harder.
Bouncing between the floor and ceiling pads escalates up to the cap; air-strafe
out or press respawn. Court floor pads are raised, so jump onto them.

### Bounce floor

40% of the arena floor is trampoline: 56 of the 140 4 × 4 m floor cells are
flush pink checker tiles (`BOUNCE_FLOOR_MAP` in `scripts/arena.gd`, `#` = tile).
They leave the spawn area, props, and the court clear. Walking onto a tile does
not launch you; jump on it to start bouncing. Repeated bounces settle around
15 m/s (about 5.6 m high). Steer off a tile to stop. All tiles share one static
body and are drawn with a single MultiMesh to stay cheap on mobile.

Invisible colliders extend the perimeter walls up to 30 m so big bounces cannot
carry anyone out of the arena.

Citizens join in too: whenever one lands on an upward-facing trampoline it hops
at `trampoline_hop_speed` (5 m/s, `scripts/citizen.gd`). Citizens' obstacle
probes start 6 cm above their feet so the thin tile edge does not stop them.

## iOS fullscreen

iPhone Safari does not reliably support requesting fullscreen for an arbitrary
game canvas. Use **Share → Add to Home Screen**, then launch the icon to remove
Safari's address and navigation bars. The Web export includes Apple's standalone
metadata and a touch icon. A service worker/offline PWA is not required for this
standalone launch. System status/home-indicator visibility remains iOS-controlled.
The page uses `viewport-fit=cover` and a translucent status bar so the 3D view
extends to the screen edges, including the rounded corners and notch area.
Only HUD controls and the watermark use the device's safe-area insets; the game
canvas is never padded or letterboxed. Insets update when the device rotates.
After a deployment that changes these Home Screen settings, fully close and
reopen the app. If iOS retains the old launch layout, remove its Home Screen icon
and add it again from the updated Safari page.

`web/shell.html` is based on Godot 4.7.2's standard Web shell. Keep its engine
placeholders and startup handling when upgrading Godot. Its small safe-area
bridge reports CSS pixels to the HUD without changing the renderer's dimensions.

iPad Safari supports element fullscreen after a user gesture. See
[WebKit's iPhone fullscreen issue](https://bugs.webkit.org/show_bug.cgi?id=206854)
and [Apple's standalone web-app documentation](https://developer.apple.com/library/archive/documentation/AppleApplications/Reference/SafariWebContent/ConfiguringWebApplications/ConfiguringWebApplications.html).

## Regression checks

Run `godot --headless --path . tests/controller_test.tscn`. It exits nonzero on
failure and covers real floor/wall/ramp collisions, movement speed, friction,
jumping, air momentum, respawn, pause, stick deadzones, multitouch, and fallback.
CI runs these checks before exporting. Physical Safari and gamepad testing is
still needed to validate hardware-specific mappings and browser behavior.
