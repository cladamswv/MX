# DIRTLINE MX Arcade 3.3.0

## 3.3.0 - Arcade handling + clear-screen rebuild

- Replaced road-dependent `move_and_slide()` racing with deterministic arcade surface-follow movement.
- Player and AI now advance predictably every physics frame while still supporting lane changes, jumps, wheelies, landing pitch, mud, boost, crashes and finish logic.
- Camera now trails the rider instead of sitting ahead of the bike, keeping the player visible and leaving usable look-ahead.
- Removed the 512x512 gameplay logo texture that was expanding to native size on Android and blocking the left half of the screen.
- Added compact text branding and a smaller top HUD.
- Reduced bottom control-pad footprint while retaining large touch targets.
- Front-end TextureRects now set expand mode before assigned size to avoid texture minimum-size regressions.
- Smoke test now requires meaningful player and AI forward displacement, compact HUD dimensions, race-track binding and camera-behind-player staging.

This is a behavior-focused rebuild rather than another visual-only patch.
