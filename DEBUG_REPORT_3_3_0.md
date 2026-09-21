# DIRTLINE MX Arcade 3.3.0 Debug Report

Primary device issues addressed:

1. **Gameplay view blocked by logo**
   - Root cause: 512x512 `logo_mark.png` could retain texture minimum size on Android.
   - Fix: no texture logo is used during gameplay; compact text branding replaces it.

2. **Rider pushed against the left edge**
   - Root cause: the camera was positioned ahead of the target while also looking ahead.
   - Fix: camera now trails the bike by 6.6 world units and keeps forward look-ahead.

3. **Motorcycles not driving consistently**
   - Root cause: CharacterBody3D `move_and_slide()` was being asked to traverse a dense concave 2.5D track mesh while also receiving direct recovery teleports.
   - Fix: arcade movement now follows the authored `surface_height_at()` function deterministically, with explicit airborne physics for jumps and landings.

4. **Controls consume too much screen**
   - Fix: control pads were reduced and re-anchored to the bottom corners/center.

The GitHub smoke test for this build rejects weak player/AI displacement and oversized control-pad regressions.
