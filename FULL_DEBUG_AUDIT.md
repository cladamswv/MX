# DIRTLINE MX Arcade 3.3.0 - Full Debug & Regression Audit

This build was rebuilt around the two device failures visible in the Android screenshot rather than treating them as cosmetic issues.

## Screen obstruction fixes

- Removed `logo_mark.png` from the gameplay HUD. The 512x512 texture was able to retain its native minimum size on Android, producing the giant black/orange MX card over the left side of the race.
- Replaced gameplay texture branding with a compact `DIRTLINE MX` text label.
- Reduced telemetry and race-status panel dimensions.
- Rebuilt the bottom left, center, and right touch-control panels to leave the middle of the screen clear.
- Changed front-end TextureRect construction so `EXPAND_IGNORE_SIZE` is applied before an explicit size.
- Disabled the near-side vertical track skirt in 2.5D mode. That geometry could appear as a dark slab across the lower portion of a wide phone display.

## Motorcycle movement fixes

- Removed normal-race reliance on `CharacterBody3D.move_and_slide()`, `is_on_floor()`, and `get_floor_normal()`.
- Forward motion is now deterministic: `x += speed * delta` every physics tick.
- Ground height comes from the same authored `surface_height_at(x,z)` function used to build the visible track.
- Lane movement is explicit and deterministic with separate grounded/airborne lateral rates.
- Jump airtime uses explicit vertical velocity and gravity, with landing detection against the authored surface.
- Ground pitch and landing pitch are derived from sampled track slope, not collision-normal state.
- Jump lips, mud entries, and lane obstacles have deterministic crossing checks in addition to existing Area3D triggers.
- Finish detection has a direct `finish_x` guard so a race cannot depend solely on an Area3D event.
- AI and player share the same movement path; AI retains clutch-launch behavior.

## Camera fixes

- Camera trails the player by 6.6 world units instead of sitting ahead of the bike.
- Increased camera height for a clearer 2.5D / classic arcade motocross angle.
- Preserved look-ahead so upcoming ramps and traffic remain visible.

## Automated audit

`tools/full_audit.py` validates:

- every `res://` reference
- input actions
- GDScript delimiter/merge-marker sanity
- 23 GLB containers
- PNG/JPEG headers
- WAV/OGG containers
- Android version/package metadata
- clear-HUD regression markers
- deterministic-drive code path
- camera-behind-player configuration
- race-track group binding
- absence of old `move_and_slide()` / floor-normal race dependencies

The GitHub smoke test additionally requires meaningful player and AI forward displacement in the real Godot 4.3 runtime before Android export can begin.
