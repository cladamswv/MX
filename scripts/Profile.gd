class_name DirtlineProfile
extends Node

const SAVE_PATH := "user://arcade_profile.cfg"
const COLORS := [Color("ff6a18"), Color("17bcec"), Color("f33858")]
const COLOR_NAMES := ["FACTORY ORANGE", "ELECTRIC BLUE", "RACE RED"]
var music_volume: float = 0.72
var engine_volume: float = 0.65
var sfx_volume: float = 0.85
var tilt_mode: int = 0
var color_index: int = 0
var high_scores: Dictionary = {}
var best_times: Dictionary = {}
var save_enabled: bool = true

func _ready() -> void:
    add_to_group("profile")
    var config := ConfigFile.new()
    if config.load(SAVE_PATH) != OK:
        return
    music_volume = clampf(float(config.get_value("audio", "music", 0.72)), 0.0, 1.0)
    engine_volume = clampf(float(config.get_value("audio", "engine", 0.65)), 0.0, 1.0)
    sfx_volume = clampf(float(config.get_value("audio", "sfx", 0.85)), 0.0, 1.0)
    tilt_mode = clampi(int(config.get_value("controls", "tilt", 0)), 0, 2)
    color_index = clampi(int(config.get_value("rider", "color", 0)), 0, 2)
    high_scores = config.get_value("records", "scores", {})
    best_times = config.get_value("records", "times", {})

func save() -> void:
    if not save_enabled:
        return
    var config := ConfigFile.new()
    config.set_value("audio", "music", music_volume)
    config.set_value("audio", "engine", engine_volume)
    config.set_value("audio", "sfx", sfx_volume)
    config.set_value("controls", "tilt", tilt_mode)
    config.set_value("rider", "color", color_index)
    config.set_value("records", "scores", high_scores)
    config.set_value("records", "times", best_times)
    var result := config.save(SAVE_PATH)
    if result != OK:
        push_warning("Could not save local race records: %s" % error_string(result))

func record_race(course: String, mode: String, score: int, elapsed: float) -> bool:
    var key := course + ":" + mode
    var improved := score > int(high_scores.get(key, 0))
    high_scores[key] = maxi(score, int(high_scores.get(key, 0)))
    if elapsed > 0.0 and (not best_times.has(key) or elapsed < float(best_times[key])):
        best_times[key] = elapsed
    save()
    return improved
