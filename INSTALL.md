# DIRTLINE MX Arcade 3.4.0 installation

Extract the fresh-install ZIP, open the folder in Godot 4.3, and run the Android preset. For an update ZIP, extract it over the existing 3.3 project and overwrite files.

Android export requires official Godot 4.3 templates, Android SDK, Java 17, and a debug keystore. `.github/workflows/android.yml` configures these on GitHub Actions and uploads a signed debug APK.

```bash
python3 tools/full_audit.py
godot --headless --path . --import
godot --headless --path . --script res://scripts/SmokeTest.gd
godot --headless --path . --script res://tests/Regression.gd
```
