# First-person controls

Click or tap the scene to start. A gamepad's bottom face button also starts play.

| Input | Move | Look | Jump | Pause | Respawn |
| --- | --- | --- | --- | --- | --- |
| Keyboard/mouse | WASD or arrows | Captured mouse | Space | Escape | R |
| Gamepad | Left stick | Right stick | A / Cross (bottom face button) | Start / Options | Back / Select |
| Touch | Drag left side | Drag right side | Hold JUMP | Top pause button | Pause, then RESPAWN |

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

## Movement

`scenes/player.tscn` is a reusable capsule-based `CharacterBody3D` with a camera.
Tune exported values on the player or in `scripts/player.gd`:

- Ground speed: 7 m/s; ground acceleration: 10; friction: 6; stop speed: 2.5 m/s.
- Gravity: 20 m/s²; jump speed: 7 m/s.
- Air acceleration: 12; projected air wish-speed cap: 0.8 m/s.
- Auto bunny hop: enabled. Holding jump skips ground friction on each takeoff.

Acceleration is limited along the desired direction, preserving perpendicular
momentum for air strafing. This is Source-inspired movement, not a frame-exact
Source engine port. Crouching, stair stepping, and Source-specific surf collision
behavior are not implemented. Ramps use Godot's floor snapping and sliding.

Input is centralized in the `Controls` autoload. Mouse look accumulates
screen-relative deltas. Touch look tracks its own finger positions and converts
the difference to screen pixels to avoid spurious browser multitouch deltas.
Stick look uses angular speed multiplied by elapsed time.
Sensitivity values live in `scripts/controls.gd`. The test arena has ramps,
jump blocks, pillars, walls, a speed readout, and a fall-triggered respawn.

## iOS fullscreen

iPhone Safari does not reliably support requesting fullscreen for an arbitrary
game canvas. Use **Share → Add to Home Screen**, then launch the icon to remove
Safari's address and navigation bars. The Web export includes Apple's standalone
metadata and a touch icon. A service worker/offline PWA is not required for this
standalone launch. System status/home-indicator visibility remains iOS-controlled.
The page keeps the default safe viewport rather than drawing controls into notches.

iPad Safari supports element fullscreen after a user gesture. See
[WebKit's iPhone fullscreen issue](https://bugs.webkit.org/show_bug.cgi?id=206854)
and [Apple's standalone web-app documentation](https://developer.apple.com/library/archive/documentation/AppleApplications/Reference/SafariWebContent/ConfiguringWebApplications/ConfiguringWebApplications.html).

## Regression checks

Run `godot --headless --path . tests/controller_test.tscn`. It exits nonzero on
failure and covers real floor/wall/ramp collisions, movement speed, friction,
jumping, air momentum, respawn, pause, stick deadzones, multitouch, and fallback.
CI runs these checks before exporting. Physical Safari and gamepad testing is
still needed to validate hardware-specific mappings and browser behavior.
