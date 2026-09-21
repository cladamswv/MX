# DIRTLINE MX Arcade 3.4.0

An arcade motocross racer for Android landscape, built with Godot 4.3 and the GL Compatibility renderer.

3.4.0 adds a new logo and launcher icon, optimized low-poly bikes and props, three original synthesized race loops, engine/SFX mixing, compact touch controls, safe-area handling, pause/countdown fixes, deterministic finish scoring, saved settings/high scores, and a showroom garage.

Open this folder in Godot 4.3. Run `python3 tools/full_audit.py`, then press Play or export Android. The repository workflow performs the audit, Godot import, runtime smoke test, Android debug export, APK signature verification, and manifest checks.

```bash
python3 tools/full_audit.py
godot --headless --path . --import
godot --headless --path . --script res://tests/Regression.gd
```

Generated audio is original synthesis authored by `tools/compose_audio.py`; no third-party recordings are included. The included DejaVu Sans Bold font license is in `ui/fonts/LICENSE.txt`.
