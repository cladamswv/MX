# DIRTLINE MX Arcade 3.2 Debug Report

A static integrity audit was run on the completed source tree before packaging.

Checked:
- 71 `res://` resource references
- 7 GDScript files
- 23 GLB models (header, length, JSON chunk)
- 50 PNG/JPEG textures/UI images
- 15 WAV files
- 4 OGG files
- Main-to-HUD method references
- presentation asset presence
- project/export/workflow version markers
- bracket/delimiter structure
- parse-safe SmokeTest policy (`:=` disallowed there)

Result at source audit: **0 errors, 0 warnings**.

The environment used to package this build does not include the Godot 4.3 executable or Android export templates, so engine parsing, runtime scene validation, and APK export remain GitHub Actions responsibilities. The included workflow performs those checks before uploading an APK.

The completed fresh-install ZIP was then extracted into a clean directory and the same audit was rerun against the extracted project. Result: **0 errors, 0 warnings**. A recursive source-vs-extracted comparison reported no file differences.
