# Arcade audio pack

This release ships original synthesized audio authored offline by `tools/compose_audio.py` and rendered to WAV/OGG with standard DSP and FFmpeg. It includes menu music, three course loops, idle/mid/high engine loops, countdown/go/finish stingers, UI clicks, boost, jump/landing, crash, mud, and score effects.

Music is routed to `Music`, engines to `Engines`, and effects/UI to `SFX`/`UI` through `default_bus_layout.tres`. All loops have explicit loop metadata or complete OGG pages and can be replaced later using the same filenames.
