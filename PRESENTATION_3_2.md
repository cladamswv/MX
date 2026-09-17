# DIRTLINE MX Arcade 3.2 — Turnkey Presentation Pass

This build converts the working Arcade 3.x prototype into a coherent game front-end and race presentation.

## New presentation layer
- New DIRTLINE MX logo and launcher mark.
- Branded Godot boot splash.
- Animated splash-to-menu sequence.
- Full-screen main menu with Arcade Race, Time Trial, Garage, How to Play, and Settings.
- Course-selection cards for Pine Ridge, Red Mesa, and Quarry Run.
- Real loading screen with course title, status text, progress meter, and control tip.
- Garage color selection for the player's rider/bike.
- Functional Time Trial mode that launches a solo rider instead of the seven-rider grid.
- Pause menu with Resume, Restart Race, and Main Menu.
- Results screen with place, time, top speed, and clean-landing count.

## Gameplay HUD redesign
- Compact DIRTLINE logo in the race HUD.
- Separated telemetry and race-status clusters.
- Smaller, cleaner bottom control pods.
- Dedicated five-line track controls.
- Lean, tilt, brake, boost, and throttle grouped by function.
- Polished color hierarchy and translucent arcade panels.

## Branding integration
- Updated track banner, START banner, and FINISH banner textures.
- New app icon.
- New UI click and confirmation sounds.

## Validation
The GitHub workflow imports the project with Godot 4.3, launches the runtime smoke test, validates the 2.5D race scene and presentation APIs, exports the Android APK, verifies its signature, and inspects its Android manifest.
