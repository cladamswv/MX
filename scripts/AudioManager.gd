class_name DirtlineAudio
extends Node

const SFX_FILES := {
    "jump": "res://audio/sfx/jump_takeoff.wav",
    "landing_soft": "res://audio/sfx/landing_soft.wav",
    "landing_hard": "res://audio/sfx/landing_hard.wav",
    "perfect": "res://audio/sfx/perfect_landing.wav",
    "crash_1": "res://audio/sfx/crash_01.wav",
    "crash_2": "res://audio/sfx/crash_02.wav",
    "mud": "res://audio/sfx/mud_splash.wav",
    "boost": "res://audio/sfx/boost.wav",
    "go": "res://audio/sfx/go.wav",
    "finish": "res://audio/sfx/finish.wav",
}

const MUSIC_FILES := {
    "menu": "res://audio/music/menu_theme.ogg",
    "race_0": "res://audio/music/race_loop_1.ogg",
    "race_1": "res://audio/music/race_loop_2.ogg",
    "race_2": "res://audio/music/race_loop_3.ogg",
}

const ENGINE_FILES := {
    "idle": "res://audio/engine/engine_idle.wav",
    "mid": "res://audio/engine/engine_mid.wav",
    "high": "res://audio/engine/engine_high.wav",
}

var player_bike: DirtlineBike
var _sfx_players: Dictionary = {}
var _music_player: AudioStreamPlayer
var _stinger_player: AudioStreamPlayer
var _engine_idle_player: AudioStreamPlayer
var _engine_mid_player: AudioStreamPlayer
var _engine_high_player: AudioStreamPlayer
var _current_music_key := ""

func _ready() -> void:
    _setup_sfx_players()
    _setup_music_players()
    _setup_engine_players()

func _process(delta: float) -> void:
    _update_engine_mix(delta)

func bind_player_bike(bike: DirtlineBike) -> void:
    player_bike = bike
    if player_bike == null:
        _stop_engine_players()

func play_sfx(key: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
    if not _sfx_players.has(key):
        return
    var p: AudioStreamPlayer = _sfx_players[key]
    if p.stream == null:
        return
    p.volume_db = volume_db
    p.pitch_scale = pitch
    p.play()

func play_menu_music() -> void:
    _play_music_key("menu", -13.0)

func play_race_music(course_index: int) -> void:
    var key := "race_%d" % posmod(course_index, 3)
    _play_music_key(key, -15.0)

func play_finish_stinger() -> void:
    if _stinger_player.stream == null:
        return
    _stinger_player.volume_db = -6.0
    _stinger_player.play()

func _setup_sfx_players() -> void:
    for key in SFX_FILES:
        var p := AudioStreamPlayer.new()
        p.name = "SFX_" + str(key)
        add_child(p)
        if ResourceLoader.exists(SFX_FILES[key]):
            p.stream = load(SFX_FILES[key])
        _sfx_players[key] = p

func _setup_music_players() -> void:
    _music_player = AudioStreamPlayer.new()
    _music_player.name = "MusicLoop"
    add_child(_music_player)

    _stinger_player = AudioStreamPlayer.new()
    _stinger_player.name = "MusicStinger"
    add_child(_stinger_player)
    if ResourceLoader.exists(SFX_FILES["finish"]):
        _stinger_player.stream = load(SFX_FILES["finish"])

func _setup_engine_players() -> void:
    _engine_idle_player = _new_engine_player("EngineIdle", ENGINE_FILES["idle"])
    _engine_mid_player = _new_engine_player("EngineMid", ENGINE_FILES["mid"])
    _engine_high_player = _new_engine_player("EngineHigh", ENGINE_FILES["high"])

func _new_engine_player(node_name: String, path: String) -> AudioStreamPlayer:
    var p := AudioStreamPlayer.new()
    p.name = node_name
    p.volume_db = -40.0
    add_child(p)
    if ResourceLoader.exists(path):
        p.stream = load(path)
        _set_loop(p.stream)
    return p

func _set_loop(stream: AudioStream) -> void:
    if stream is AudioStreamWAV:
        var wav := stream as AudioStreamWAV
        wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
    elif stream is AudioStreamOggVorbis:
        var ogg := stream as AudioStreamOggVorbis
        ogg.loop = true

func _play_music_key(key: String, volume_db: float) -> void:
    if _current_music_key == key and _music_player.playing:
        _music_player.volume_db = volume_db
        return
    if not MUSIC_FILES.has(key):
        return
    var path: String = MUSIC_FILES[key]
    if not ResourceLoader.exists(path):
        return
    var stream: AudioStream = load(path) as AudioStream
    _set_loop(stream)
    _music_player.stop()
    _music_player.stream = stream
    _music_player.volume_db = volume_db
    _music_player.play()
    _current_music_key = key

func _update_engine_mix(delta: float) -> void:
    if player_bike == null or not is_instance_valid(player_bike):
        _fade_engine_to_silence(delta)
        return

    var should_run := player_bike.race_active or (not player_bike.race_finished and player_bike.speed > 0.5)
    if should_run:
        _ensure_engine_players_running()
    else:
        _fade_engine_to_silence(delta)
        return

    var rpm := clampf(player_bike.current_rpm, 0.0, 1.0)
    var speed_ratio := clampf(player_bike.speed / maxf(player_bike.max_speed, 1.0), 0.0, 1.2)
    var idle_gain := clampf(1.15 - rpm * 2.1, 0.0, 1.0)
    var mid_gain := clampf(1.0 - absf(rpm - 0.46) * 2.5, 0.0, 1.0)
    var high_gain := clampf((rpm - 0.42) * 1.9, 0.0, 1.0)

    if player_bike.boost_timer > 0.0:
        high_gain = minf(1.0, high_gain + 0.18)
        mid_gain = minf(1.0, mid_gain + 0.07)

    _set_player_mix(_engine_idle_player, idle_gain, -8.0 + rpm * 5.0, 0.84 + rpm * 0.18, delta)
    _set_player_mix(_engine_mid_player, mid_gain, -9.5 + speed_ratio * 5.0, 0.84 + rpm * 0.33, delta)
    _set_player_mix(_engine_high_player, high_gain, -11.0 + speed_ratio * 6.0, 0.88 + rpm * 0.42, delta)

func _set_player_mix(player: AudioStreamPlayer, gain: float, target_db: float, target_pitch: float, delta: float) -> void:
    if player == null:
        return
    if gain <= 0.001:
        player.volume_db = move_toward(player.volume_db, -40.0, 55.0 * delta)
    else:
        var mixed_db := target_db + linear_to_db(gain)
        player.volume_db = lerpf(player.volume_db, mixed_db, 1.0 - exp(-8.0 * delta))
    player.pitch_scale = lerpf(player.pitch_scale, target_pitch, 1.0 - exp(-7.0 * delta))

func _ensure_engine_players_running() -> void:
    for p in [_engine_idle_player, _engine_mid_player, _engine_high_player]:
        if p and p.stream != null and not p.playing:
            p.play()

func _fade_engine_to_silence(delta: float) -> void:
    for p in [_engine_idle_player, _engine_mid_player, _engine_high_player]:
        if p:
            p.volume_db = move_toward(p.volume_db, -40.0, 40.0 * delta)
            if p.playing and p.volume_db <= -39.0:
                p.stop()

func _stop_engine_players() -> void:
    for p in [_engine_idle_player, _engine_mid_player, _engine_high_player]:
        if p:
            p.stop()
            p.volume_db = -40.0
