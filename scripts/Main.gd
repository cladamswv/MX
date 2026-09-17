class_name DirtlineGame
extends Node3D

const BikeScript := preload("res://scripts/Bike.gd")
const TrackScript := preload("res://scripts/TrackBuilder.gd")
const CameraScript := preload("res://scripts/CameraRig.gd")
const HUDScript := preload("res://scripts/HUD.gd")
const AudioScript := preload("res://scripts/AudioManager.gd")

var player: DirtlineBike
var racers: Array[DirtlineBike] = []
var camera: DirtlineCamera
var hud: DirtlineHUD
var track: DirtlineTrack
var audio: DirtlineAudio
var current_course := 0
var _starting := false
var _orientation_timer := 0.0

var _environment_node: WorldEnvironment
var _environment: Environment
var _sun: DirectionalLight3D
var _fill: DirectionalLight3D

func _ready() -> void:
    _enforce_landscape()
    _setup_world()
    _spawn_camera()
    _spawn_audio()
    if audio:
        audio.play_menu_music()
    _spawn_hud()
    hud.course_selected.connect(_start_course)
    hud.restart_requested.connect(_restart_course)
    hud.next_track_requested.connect(_next_course)
    hud.menu_requested.connect(_return_to_menu)
    hud.show_course_select()

func _process(delta: float) -> void:
    if Input.is_action_just_pressed("restart") and track != null and not _starting:
        _restart_course()
    if OS.has_feature("mobile"):
        _orientation_timer -= delta
        if _orientation_timer <= 0.0:
            _orientation_timer = 1.0
            _enforce_landscape()

func _enforce_landscape() -> void:
    if OS.has_feature("mobile") and DisplayServer.has_feature(DisplayServer.FEATURE_ORIENTATION):
        DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
        DisplayServer.screen_set_keep_on(true)

func _setup_world() -> void:
    RenderingServer.set_default_clear_color(Color(0.20, 0.46, 0.72, 1.0))
    _environment_node = WorldEnvironment.new()
    _environment_node.name = "RaceEnvironment"
    _environment = Environment.new()
    var sky := Sky.new()
    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color(0.075, 0.25, 0.52)
    sky_material.sky_horizon_color = Color(0.58, 0.75, 0.91)
    sky_material.ground_bottom_color = Color(0.08, 0.07, 0.06)
    sky_material.ground_horizon_color = Color(0.38, 0.40, 0.36)
    sky_material.sun_angle_max = 18.0
    sky_material.sun_curve = 0.11
    sky.sky_material = sky_material
    _environment.sky = sky
    _environment.background_mode = Environment.BG_SKY
    _environment.background_energy_multiplier = 0.92
    _environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    _environment.ambient_light_color = Color(0.64, 0.71, 0.77)
    _environment.ambient_light_energy = 0.92
    _environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
    _environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    _environment.adjustment_enabled = true
    _environment.adjustment_brightness = 1.03
    _environment.adjustment_contrast = 1.10
    _environment.adjustment_saturation = 1.11
    _environment_node.environment = _environment
    add_child(_environment_node)

    _sun = DirectionalLight3D.new()
    _sun.name = "Sun"
    _sun.rotation_degrees = Vector3(-48.0, -30.0, 0.0)
    _sun.light_color = Color(1.0, 0.88, 0.72)
    _sun.light_energy = 1.72
    _sun.shadow_enabled = true
    _sun.directional_shadow_max_distance = 190.0
    add_child(_sun)

    _fill = DirectionalLight3D.new()
    _fill.name = "SkyFill"
    _fill.rotation_degrees = Vector3(-24.0, 150.0, 0.0)
    _fill.light_color = Color(0.52,0.65,0.82)
    _fill.light_energy = 0.38
    _fill.shadow_enabled = false
    add_child(_fill)
    _apply_course_environment(0)

func _apply_course_environment(index: int) -> void:
    match index:
        0:
            _set_sky_colors(Color(0.075,0.25,0.52), Color(0.58,0.75,0.91), Color(0.38,0.40,0.36))
            _environment.ambient_light_color = Color(0.66,0.73,0.78)
            _sun.rotation_degrees = Vector3(-47.0, -29.0, 0.0)
            _sun.light_color = Color(1.0,0.87,0.70)
            _sun.light_energy = 1.78
        1:
            _set_sky_colors(Color(0.08,0.31,0.66), Color(0.94,0.69,0.43), Color(0.48,0.25,0.11))
            _environment.ambient_light_color = Color(0.78,0.68,0.56)
            _sun.rotation_degrees = Vector3(-40.0, -37.0, 0.0)
            _sun.light_color = Color(1.0,0.76,0.54)
            _sun.light_energy = 1.95
        2:
            _set_sky_colors(Color(0.10,0.18,0.28), Color(0.59,0.67,0.72), Color(0.27,0.28,0.27))
            _environment.ambient_light_color = Color(0.66,0.68,0.69)
            _sun.rotation_degrees = Vector3(-52.0, -20.0, 0.0)
            _sun.light_color = Color(0.96,0.91,0.82)
            _sun.light_energy = 1.62


func _set_sky_colors(top: Color, horizon: Color, ground_horizon: Color) -> void:
    if _environment == null or _environment.sky == null:
        return
    var sky_material := _environment.sky.sky_material as ProceduralSkyMaterial
    if sky_material == null:
        return
    sky_material.sky_top_color = top
    sky_material.sky_horizon_color = horizon
    sky_material.ground_horizon_color = ground_horizon

func _spawn_audio() -> void:
    audio = AudioScript.new()
    audio.name = "Audio"
    audio.add_to_group("audio")
    add_child(audio)

func _spawn_hud() -> void:
    hud = HUDScript.new()
    hud.name = "HUD"
    add_child(hud)

func _spawn_camera() -> void:
    if camera != null and is_instance_valid(camera):
        camera.make_current()
        return
    camera = CameraScript.new()
    camera.name = "RaceCamera"
    camera.position = Vector3(0.0, 4.5, 22.0)
    add_child(camera)
    camera.make_current()

func _start_course(index: int) -> void:
    if _starting:
        return
    _starting = true
    _enforce_landscape()
    current_course = posmod(index, 3)
    hud.show_loading_for_course(current_course)
    hud.set_loading_progress(0.18, "Clearing previous race")
    await get_tree().process_frame
    await _clear_race()
    _apply_course_environment(current_course)
    hud.set_loading_progress(0.42, "Building terrain and scenery")

    track = TrackScript.new()
    track.name = "Track_%d" % current_course
    track.course_index = current_course
    add_child(track)
    await get_tree().process_frame
    hud.set_loading_progress(0.68, "Staging riders")

    _spawn_racers()
    _spawn_camera()
    camera.set_target(player, true)
    if audio:
        audio.bind_player_bike(player)
        audio.play_race_music(current_course)

    hud.set_loading_progress(0.90, "Final checks")
    hud.bind_race(player, racers, track.get_finish_x(), track.get_course_name(), track.get_course_subtitle())
    if player:
        player.tilt_mode = hud.get_default_tilt_mode()
        player.calibrate_tilt()
    await get_tree().process_frame
    _runtime_visual_guard()
    hud.set_loading_progress(1.0, "Ready")
    await get_tree().create_timer(0.15).timeout
    hud.hide_loading()
    await hud.start_countdown()
    for bike in racers:
        if is_instance_valid(bike):
            bike.race_active = true
    if audio:
        audio.play_sfx("go", -2.0, 1.0)
    _starting = false

func _restart_course() -> void:
    if not _starting:
        _start_course(current_course)

func _next_course() -> void:
    if not _starting:
        _start_course((current_course + 1) % 3)

func _return_to_menu() -> void:
    if _starting:
        return
    _starting = true
    await _clear_race()
    if audio:
        audio.play_menu_music()
    if hud:
        hud.show_course_select()
    _starting = false

func _clear_race() -> void:
    if camera != null and is_instance_valid(camera):
        camera.set_target(null, false)
    for bike in racers:
        if is_instance_valid(bike):
            bike.queue_free()
    racers.clear()
    player = null
    if track != null and is_instance_valid(track):
        track.queue_free()
    track = null
    if audio:
        audio.bind_player_bike(null)
    await get_tree().process_frame

func _spawn_racers() -> void:
    # Arcade 3.2 supports a full 7-rider arcade race or a solo time trial.
    var start_lanes := [2, 1, 3, 0, 4, 1, 3]
    var start_offsets := [0.0, -2.3, -2.3, -4.7, -4.7, -7.0, -7.0]
    var colors := [
        hud.get_player_color(), Color(0.10,0.32,0.72), Color(0.82,0.08,0.10),
        Color(0.12,0.52,0.28), Color(0.58,0.24,0.67), Color(0.84,0.68,0.08), Color(0.12,0.58,0.66)
    ]
    var rider_count: int = 1 if hud.get_race_mode() == "time_trial" else 7
    var start_pos_x := track.get_start_x()
    for i in range(rider_count):
        var lane_id: int = start_lanes[i]
        var lane_z: float = float(DirtlineBike.LANE_POSITIONS[lane_id])
        var bike: DirtlineBike = BikeScript.new()
        bike.name = "Player" if i == 0 else "AI_%02d" % i
        bike.player_controlled = i == 0
        bike.rider_color = colors[i]
        bike.ai_skill = 0.955 + float(i) * 0.011
        bike.max_speed = 34.0 if i == 0 else 32.7 + float(i % 3) * 0.48
        bike.side_depth_z = lane_z
        bike.target_lane_index = lane_id
        bike.lane_index = lane_id
        var bx := start_pos_x + start_offsets[i]
        var by := track.surface_height_at(bx, lane_z) - 0.10
        bike.position = Vector3(bx, by, lane_z)
        add_child(bike)
        bike.set_lane_index(lane_id, true)
        racers.append(bike)
        if i == 0:
            player = bike
            bike.tilt_mode = hud.get_default_tilt_mode()
            bike.perfect_landing_event.connect(_on_perfect_landing)
            bike.crashed_event.connect(_on_player_crash)
            bike.finished_event.connect(_on_player_finish)

func _runtime_visual_guard() -> void:
    if camera == null or not is_instance_valid(camera):
        _spawn_camera()
    if camera != null:
        camera.set_target(player, true)
        camera.make_current()
    var surface_count := get_tree().get_nodes_in_group("race_surface").size()
    if surface_count == 0:
        push_error("DIRTLINE runtime guard: no race surface segments found")
        _add_emergency_road()
    if get_viewport().get_camera_3d() == null and camera != null:
        camera.make_current()

func _add_emergency_road() -> void:
    var body := StaticBody3D.new()
    body.name = "EmergencyRoad"
    body.position = Vector3(320.0, -0.30, 0.0)
    add_child(body)
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(760.0, 0.50, 15.0)
    mesh.mesh = box
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.38,0.18,0.07)
    mat.roughness = 1.0
    mesh.material_override = mat
    body.add_child(mesh)
    var cs := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = box.size
    cs.shape = shape
    body.add_child(cs)

func _on_perfect_landing() -> void:
    if hud:
        hud.show_event("PERFECT LANDING   +BOOST", 1.05)
    if camera:
        camera.punch(0.075)

func _on_player_crash() -> void:
    if hud:
        hud.show_event("CRASH!", 0.85)
    if camera:
        camera.punch(0.32)

func _on_player_finish() -> void:
    if hud:
        hud.show_finish()
    if camera:
        camera.punch(0.12)
    if audio:
        audio.play_finish_stinger()
