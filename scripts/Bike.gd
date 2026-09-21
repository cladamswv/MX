class_name DirtlineBike
extends CharacterBody3D

signal crashed_event
signal perfect_landing_event
signal finished_event
signal near_miss_event

@export var player_controlled := false
@export var rider_color := Color(0.12, 0.30, 0.56)
@export var max_speed := 34.0
@export var acceleration := 16.5
@export var braking := 25.0
@export var ai_skill := 1.0
@export var side_depth_z := 0.0
var lane_index := 2
var target_lane_index := 2
var touch_lane_step := 0

const GRAVITY := 25.5
const MODEL_SCENE := preload("res://models/dirt_bike_rider_arcade_v4.glb")
const TILT_OFF := 0
const TILT_ASSIST := 1
const TILT_FULL := 2
const TILT_SCALE := 0.26
const WHEELIE_MAX_ANGLE := 1.10
const LOOP_OUT_ANGLE := 1.00
const LANE_POSITIONS := [-5.2, -2.6, 0.0, 2.6, 5.2]
const LANE_RESPONSE := 9.5
const GROUND_OFFSET := -0.10

var speed := 0.0
var heat := 0.0
var boost_meter := 1.0
var race_finished := false
var race_active := false
var crashed := false
var airborne := false
var mud_timer := 0.0
var boost_timer := 0.0
var crash_timer := 0.0
var ai_target_speed := 27.0
var distance_m := 0.0
var current_rpm := 0.0
var traction := 1.0

var touch_throttle := false
var touch_brake := false
var touch_boost := false
# Positive = lean back / front wheel up. Negative = lean forward / nose down.
var touch_lean := 0.0

var tilt_mode := TILT_ASSIST
var tilt_inverted := false
var tilt_sensor_available := false
var tilt_baseline_y := 0.0
var tilt_input := 0.0
var combined_lean_input := 0.0

var _model: Node3D
var _audio: DirtlineAudio
var _rear_wheel: Node3D
var _front_wheel: Node3D
var _last_y_velocity := 0.0
var _visual_pitch := 0.0
var _pitch_velocity := 0.0
var _wheel_spin := 0.0
var _suspension_compression := 0.0
var _throttle_value := 0.0
var _brake_value := 0.0
var _boosting := false
var _was_boosting := false
var _spawn_transform: Transform3D
var _dust: GPUParticles3D
var _mud_spray: GPUParticles3D
var _tilt_filter := 0.0
var _tilt_calibrated := false
var _loopout_timer := 0.0
var _stuck_timer := 0.0
var _last_progress_x := 0.0
var _lane_change_cooldown := 0.0
var _ai_lane_timer := 0.0
var _visual_bank := 0.0
var _track: DirtlineTrack

func _ready() -> void:
    floor_max_angle = deg_to_rad(62.0)
    floor_snap_length = 0.48
    floor_stop_on_slope = false
    collision_layer = 2
    collision_mask = 1
    _spawn_transform = global_transform
    _last_progress_x = global_position.x
    target_lane_index = _nearest_lane_index(side_depth_z)
    lane_index = target_lane_index
    side_depth_z = float(LANE_POSITIONS[target_lane_index])
    _build_collision()
    _model = MODEL_SCENE.instantiate()
    _model.name = "BikeVisual"
    add_child(_model)
    _model.position = Vector3(0.0, 0.29, 0.0)
    _model.scale = Vector3.ONE * 1.22
    _build_wheel_rigs()
    _apply_rider_tint()
    _build_particles()
    if not player_controlled:
        _model.scale *= randf_range(0.97, 1.03)
        ai_target_speed = randf_range(25.0, 31.5) * ai_skill
    _audio = get_tree().get_first_node_in_group("audio") as DirtlineAudio
    _track = get_tree().get_first_node_in_group("race_track") as DirtlineTrack
    _snap_to_surface()
    if player_controlled:
        call_deferred("calibrate_tilt")

func _build_collision() -> void:
    var collision := CollisionShape3D.new()
    collision.name = "BikeCollision"
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.43
    capsule.height = 1.18
    collision.shape = capsule
    collision.position = Vector3(0.05, 0.70, 0.0)
    add_child(collision)

func _build_wheel_rigs() -> void:
    _rear_wheel = Node3D.new()
    _rear_wheel.name = "RearWheelRig"
    _rear_wheel.position = Vector3(-0.82, 0.46, 0.0)
    _model.add_child(_rear_wheel)

    _front_wheel = Node3D.new()
    _front_wheel.name = "FrontWheelRig"
    _front_wheel.position = Vector3(0.86, 0.49, 0.0)
    _model.add_child(_front_wheel)

    var candidates: Array[Node] = []
    _collect_nodes(_model, candidates)
    for node in candidates:
        if node == _rear_wheel or node == _front_wheel:
            continue
        var node_name := String(node.name)
        if node_name.begins_with("RearTire") or node_name.begins_with("RearRim") or node_name.begins_with("RearHub") or node_name.begins_with("RearBrakeDisc") or node_name.begins_with("RearSpoke") or node_name.begins_with("RearKnob"):
            node.reparent(_rear_wheel, true)
        elif node_name.begins_with("FrontTire") or node_name.begins_with("FrontRim") or node_name.begins_with("FrontHub") or node_name.begins_with("FrontBrakeDisc") or node_name.begins_with("FrontSpoke") or node_name.begins_with("FrontKnob"):
            node.reparent(_front_wheel, true)

func _collect_nodes(root_node: Node, out: Array[Node]) -> void:
    for child in root_node.get_children():
        out.append(child)
        _collect_nodes(child, out)

func _apply_rider_tint() -> void:
    var tint_names := [
        "RiderTorso", "RiderJersey", "HelmetShell", "RearFender", "FrontFender",
        "RightShroud", "LeftShroud", "RiderLUpperArm", "RiderRUpperArm",
        "RiderLShin", "RiderRShin", "RiderLGlove", "RiderRGlove",
        "V4_ChestCenter", "V4_HelmetPeak", "V4_HandGuard_1", "V4_HandGuard_-1",
        "V4_RadiatorGuard_R", "V4_RadiatorGuard_L"
    ]
    for target_name in tint_names:
        var node := _model.find_child(target_name, true, false)
        if node is MeshInstance3D:
            var mat := StandardMaterial3D.new()
            mat.albedo_color = rider_color.lightened(0.04)
            mat.roughness = 0.40 if target_name != "HelmetShell" else 0.24
            mat.metallic = 0.05
            (node as MeshInstance3D).material_override = mat

func _build_particles() -> void:
    _dust = GPUParticles3D.new()
    _dust.name = "DustTrail"
    _dust.amount = 52
    _dust.lifetime = 0.95
    _dust.randomness = 0.65
    _dust.visibility_aabb = AABB(Vector3(-9,-4,-6), Vector3(18,8,12))
    var dust_process := ParticleProcessMaterial.new()
    dust_process.direction = Vector3(-1.0, 0.28, 0.0)
    dust_process.spread = 28.0
    dust_process.initial_velocity_min = 2.0
    dust_process.initial_velocity_max = 6.0
    dust_process.gravity = Vector3(0.0, -2.6, 0.0)
    dust_process.scale_min = 0.16
    dust_process.scale_max = 0.52
    dust_process.color = Color(0.50, 0.31, 0.16, 0.42)
    dust_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    dust_process.emission_box_extents = Vector3(0.18, 0.08, 0.34)
    _dust.process_material = dust_process
    var quad := QuadMesh.new()
    quad.size = Vector2(0.55, 0.55)
    var dust_mat := StandardMaterial3D.new()
    dust_mat.albedo_color = Color(0.48, 0.31, 0.17, 0.34)
    dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    dust_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    quad.material = dust_mat
    _dust.draw_pass_1 = quad
    _dust.position = Vector3(-1.15, 0.28, 0.0)
    _dust.emitting = false
    add_child(_dust)

    _mud_spray = GPUParticles3D.new()
    _mud_spray.name = "MudSpray"
    _mud_spray.amount = 28
    _mud_spray.lifetime = 0.62
    _mud_spray.randomness = 0.8
    _mud_spray.visibility_aabb = AABB(Vector3(-7,-3,-5), Vector3(14,7,10))
    var mud_process := ParticleProcessMaterial.new()
    mud_process.direction = Vector3(-1.0, 0.55, 0.0)
    mud_process.spread = 34.0
    mud_process.initial_velocity_min = 3.0
    mud_process.initial_velocity_max = 7.0
    mud_process.gravity = Vector3(0.0, -8.0, 0.0)
    mud_process.scale_min = 0.06
    mud_process.scale_max = 0.18
    mud_process.color = Color(0.12, 0.065, 0.03, 0.86)
    _mud_spray.process_material = mud_process
    var mud_quad := QuadMesh.new()
    mud_quad.size = Vector2(0.22, 0.22)
    var mud_mat := StandardMaterial3D.new()
    mud_mat.albedo_color = Color(0.11, 0.055, 0.025, 0.82)
    mud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mud_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    mud_quad.material = mud_mat
    _mud_spray.draw_pass_1 = mud_quad
    _mud_spray.position = Vector3(-1.05, 0.28, 0.0)
    _mud_spray.emitting = false
    add_child(_mud_spray)

func _physics_process(delta: float) -> void:
    # Arcade 3.3 uses deterministic surface-follow movement instead of relying
    # on CharacterBody3D sliding over a dense concave track mesh. This makes
    # forward drive consistent on Android and keeps lane changes/jumps readable.
    if _track == null or not is_instance_valid(_track):
        _track = get_tree().get_first_node_in_group("race_track") as DirtlineTrack

    if not race_active and not race_finished:
        velocity = Vector3.ZERO
        speed = 0.0
        airborne = false
        _snap_to_surface()
        _update_tilt_sensor(delta)
        _update_visuals(delta)
        return

    mud_timer = maxf(0.0, mud_timer - delta)
    boost_timer = maxf(0.0, boost_timer - delta)
    traction = move_toward(traction, 0.62 if mud_timer > 0.0 else 1.0, 2.8 * delta)

    if crashed:
        _update_crash(delta)
        return

    if race_finished:
        _throttle_value = 0.0
        _brake_value = 0.0
        speed = move_toward(speed, 0.0, 5.8 * delta)
        velocity.x = speed
        _advance_lateral(delta)
        global_position.x += speed * delta
        if airborne:
            _advance_airborne(delta, 0.0)
        else:
            _snap_to_surface()
        _update_visuals(delta)
        return

    var lean_input: float = 0.0
    var boost_pressed: bool = false
    if player_controlled:
        _throttle_value = 1.0 if (Input.is_action_pressed("throttle") or touch_throttle) else 0.0
        _brake_value = 1.0 if (Input.is_action_pressed("brake") or touch_brake) else 0.0
        boost_pressed = Input.is_action_pressed("boost") or touch_boost
        lean_input = _read_player_lean(delta)
        _read_player_lane_input()
    else:
        _throttle_value = 1.0
        _brake_value = 0.0
        lean_input = _read_ai_lean()
        _update_ai_speed(delta)
        _update_ai_lane(delta)

    combined_lean_input = lean_input
    _update_engine(delta, boost_pressed)
    _last_y_velocity = velocity.y
    velocity.x = speed

    _advance_lateral(delta)
    var previous_x: float = global_position.x
    global_position.x += speed * delta

    if _track != null and is_instance_valid(_track):
        var jump_power: float = float(_track.get_jump_power_crossing(previous_x, global_position.x, global_position.z))
        if jump_power > 0.0 and not airborne:
            on_ramp(jump_power)
        if _track.crossed_mud_zone(previous_x, global_position.x):
            on_mud()
        if _track.crossed_obstacle(previous_x, global_position.x, global_position.z):
            on_obstacle()

    if airborne:
        _advance_airborne(delta, lean_input)
    else:
        _snap_to_surface()
        _update_ground_pitch(delta, lean_input)

    _update_stuck_guard(delta)
    distance_m = maxf(distance_m, global_position.x)
    if _track != null and is_instance_valid(_track) and global_position.x >= float(_track.get_finish_x()):
        finish_race()
    _update_visuals(delta)

func _advance_lateral(delta: float) -> void:
    _lane_change_cooldown = maxf(0.0, _lane_change_cooldown - delta)
    side_depth_z = float(LANE_POSITIONS[target_lane_index])
    var previous_z: float = global_position.z
    var max_lateral: float = 8.5 if not airborne else 5.5
    global_position.z = move_toward(global_position.z, side_depth_z, max_lateral * delta)
    velocity.z = (global_position.z - previous_z) / maxf(delta, 0.0001)

func _advance_airborne(delta: float, lean_input: float) -> void:
    velocity.y -= GRAVITY * delta
    global_position.y += velocity.y * delta
    _update_air_pitch(delta, lean_input)
    var ground_y: float = _surface_y(global_position.x, global_position.z)
    if velocity.y <= 0.0 and global_position.y <= ground_y:
        global_position.y = ground_y
        airborne = false
        _handle_landing()
        velocity.y = 0.0

func _surface_y(x_value: float, z_value: float) -> float:
    if _track != null and is_instance_valid(_track):
        return float(_track.surface_height_at(x_value, z_value)) + GROUND_OFFSET
    return GROUND_OFFSET

func _snap_to_surface() -> void:
    global_position.y = _surface_y(global_position.x, global_position.z)
    velocity.y = 0.0

func _ground_pitch_at(x_value: float, z_value: float) -> float:
    if _track == null or not is_instance_valid(_track):
        return 0.0
    var sample: float = 0.45
    var y0: float = float(_track.surface_height_at(x_value - sample, z_value))
    var y1: float = float(_track.surface_height_at(x_value + sample, z_value))
    return atan2(y1 - y0, sample * 2.0)

func _nearest_lane_index(z_value: float) -> int:
    var best_index := 0
    var best_distance := INF
    for i in range(LANE_POSITIONS.size()):
        var distance := absf(z_value - float(LANE_POSITIONS[i]))
        if distance < best_distance:
            best_distance = distance
            best_index = i
    return best_index

func set_lane_index(new_index: int, snap_now: bool = false) -> void:
    target_lane_index = clampi(new_index, 0, LANE_POSITIONS.size() - 1)
    lane_index = target_lane_index
    side_depth_z = float(LANE_POSITIONS[target_lane_index])
    if snap_now:
        global_position.z = side_depth_z

func nudge_lane(direction: int) -> void:
    if direction == 0:
        return
    target_lane_index = clampi(target_lane_index + direction, 0, LANE_POSITIONS.size() - 1)
    lane_index = target_lane_index
    side_depth_z = float(LANE_POSITIONS[target_lane_index])
    _lane_change_cooldown = 0.11

func get_lane_index() -> int:
    return target_lane_index

func _read_player_lane_input() -> void:
    if _lane_change_cooldown > 0.0:
        return
    if Input.is_action_just_pressed("lane_far"):
        nudge_lane(-1)
    elif Input.is_action_just_pressed("lane_near"):
        nudge_lane(1)
    if touch_lane_step != 0:
        nudge_lane(touch_lane_step)
        touch_lane_step = 0

func _update_ai_lane(delta: float) -> void:
    _ai_lane_timer -= delta
    if _ai_lane_timer > 0.0:
        return
    _ai_lane_timer = randf_range(1.2, 2.8)
    var change := randi_range(-1, 1)
    if change != 0:
        nudge_lane(change)

func _update_lane_control(delta: float) -> void:
    _advance_lateral(delta)

func _update_stuck_guard(delta: float) -> void:
    # Physics failsafe: a valid rider applying throttle must make forward
    # progress. This guard also works while airborne because a rider that was
    # spawned a few centimeters off the surface must not remain frozen forever.
    if crashed or race_finished or not race_active:
        _stuck_timer = 0.0
        _last_progress_x = global_position.x
        return

    var progress: float = global_position.x - _last_progress_x
    var min_drive_speed: float = 2.0 if not player_controlled else 4.5
    var trying_to_move: bool = _throttle_value > 0.55 and speed > min_drive_speed
    var expected_floor: float = maxf(0.012, speed * delta * 0.045)

    if trying_to_move and progress < expected_floor:
        _stuck_timer += delta
    else:
        _stuck_timer = maxf(0.0, _stuck_timer - delta * 3.0)

    var recovery_delay: float = 0.38 if not player_controlled else 0.70
    if _stuck_timer > recovery_delay:
        var recovery_speed: float = maxf(speed, 8.0 if not player_controlled else 7.0)
        # Nudge forward only when ordinary CharacterBody motion has genuinely
        # stalled. This is intentionally small enough to preserve jumps and
        # obstacle gameplay while preventing a deadlocked starting grid.
        global_position.x += maxf(0.85, recovery_speed * 0.085)
        global_position.y += 0.38
        global_position.z = side_depth_z
        speed = recovery_speed
        velocity = Vector3(recovery_speed, 0.8, 0.0)
        airborne = true
        _stuck_timer = 0.0

    _last_progress_x = global_position.x

func _read_player_lean(delta: float) -> float:
    var manual: float = 0.0
    manual += Input.get_action_strength("lean_back")
    manual -= Input.get_action_strength("lean_forward")
    manual += touch_lean
    manual = clampf(manual, -1.0, 1.0)

    _update_tilt_sensor(delta)
    var sensor_weight := 0.0
    if tilt_mode == TILT_ASSIST:
        sensor_weight = 0.42
    elif tilt_mode == TILT_FULL:
        sensor_weight = 1.0
    return clampf(manual + tilt_input * sensor_weight, -1.0, 1.0)

func _update_tilt_sensor(delta: float) -> void:
    if not player_controlled or tilt_mode == TILT_OFF:
        tilt_input = move_toward(tilt_input, 0.0, delta * 5.0)
        return
    var accel: Vector3 = Input.get_accelerometer()
    tilt_sensor_available = accel.length() > 0.5
    if not tilt_sensor_available:
        tilt_input = move_toward(tilt_input, 0.0, delta * 5.0)
        return
    if not _tilt_calibrated:
        tilt_baseline_y = accel.y
        _tilt_calibrated = true
    var raw: float = (accel.y - tilt_baseline_y) * TILT_SCALE
    if tilt_inverted:
        raw *= -1.0
    raw = clampf(raw, -1.0, 1.0)
    if absf(raw) < 0.07:
        raw = 0.0
    _tilt_filter = lerpf(_tilt_filter, raw, 1.0 - exp(-10.0 * delta))
    tilt_input = _tilt_filter

func calibrate_tilt() -> void:
    var accel: Vector3 = Input.get_accelerometer()
    tilt_sensor_available = accel.length() > 0.5
    tilt_baseline_y = accel.y
    _tilt_filter = 0.0
    tilt_input = 0.0
    _tilt_calibrated = tilt_sensor_available

func cycle_tilt_mode() -> void:
    tilt_mode = (tilt_mode + 1) % 3
    calibrate_tilt()

func toggle_tilt_invert() -> void:
    tilt_inverted = not tilt_inverted
    calibrate_tilt()

func get_tilt_mode_label() -> String:
    if tilt_mode == TILT_OFF:
        return "OFF"
    if tilt_mode == TILT_FULL:
        return "FULL"
    return "ASSIST"

func get_tilt_status_text() -> String:
    if tilt_mode == TILT_OFF:
        return "TILT OFF"
    if tilt_sensor_available:
        return "TILT %s  %.2f" % [get_tilt_mode_label(), tilt_input]
    return "TILT %s  TOUCH BACKUP" % get_tilt_mode_label()

func _read_ai_lean() -> float:
    if airborne:
        return clampf(-_visual_pitch * 0.75, -0.65, 0.65)
    return 0.0

func _update_ground_pitch(delta: float, lean_input: float) -> void:
    var ground_pitch: float = _ground_pitch_at(global_position.x, global_position.z)
    var speed_ratio: float = clampf(speed / maxf(max_speed, 1.0), 0.0, 1.1)
    var wheelie_gate: float = clampf((speed - 4.0) / 12.0, 0.0, 1.0)
    var wheelie_amount: float = maxf(lean_input, 0.0) * wheelie_gate * (0.32 + _throttle_value * 0.68)
    var nose_down: float = maxf(-lean_input, 0.0) * 0.20
    var target_pitch: float = ground_pitch + wheelie_amount * WHEELIE_MAX_ANGLE - nose_down

    _pitch_velocity = move_toward(_pitch_velocity, 0.0, 6.0 * delta)
    _visual_pitch = lerp_angle(_visual_pitch, target_pitch, 1.0 - exp(-8.5 * delta))

    if _visual_pitch > LOOP_OUT_ANGLE and speed > 5.5:
        _loopout_timer += delta
        if _loopout_timer > 0.25:
            crash()
    else:
        _loopout_timer = maxf(0.0, _loopout_timer - delta * 2.0)

func _update_air_pitch(delta: float, lean_input: float) -> void:
    var air_accel := 3.5
    _pitch_velocity += lean_input * air_accel * delta
    if _throttle_value > 0.0:
        _pitch_velocity += 0.16 * delta
    if _brake_value > 0.0:
        _pitch_velocity -= 0.13 * delta
    _pitch_velocity *= exp(-1.15 * delta)
    _pitch_velocity = clampf(_pitch_velocity, -2.25, 2.25)
    _visual_pitch = clampf(_visual_pitch + _pitch_velocity * delta, -1.35, 1.35)

func _update_engine(delta: float, boost_pressed: bool) -> void:
    var normalized_speed := clampf(speed / max_speed, 0.0, 1.15)
    var heat_limiter := 1.0
    if heat > 0.88:
        heat_limiter = lerpf(1.0, 0.70, inverse_lerp(0.88, 1.0, heat))
    var mud_limiter := 0.73 if mud_timer > 0.0 else 1.0
    var effective_max := max_speed * heat_limiter * mud_limiter
    _was_boosting = _boosting
    _boosting = boost_pressed and boost_meter > 0.015 and heat < 0.985 and _throttle_value > 0.0
    if _boosting:
        effective_max *= 1.15
        boost_meter = maxf(0.0, boost_meter - 0.29 * delta)
        heat = minf(1.0, heat + 0.17 * delta)
        boost_timer = 0.12
        if not _was_boosting and _audio:
            _audio.play_sfx("boost", -5.0, randf_range(0.98, 1.03))
    else:
        boost_meter = minf(1.0, boost_meter + (0.052 if _throttle_value < 0.4 else 0.032) * delta)

    if _throttle_value > 0.0:
        var accel_curve := lerpf(1.15, 0.42, clampf(normalized_speed, 0.0, 1.0))
        var slope_penalty: float = 1.0
        if not airborne and _track != null and is_instance_valid(_track):
            var slope_pitch: float = _ground_pitch_at(global_position.x, global_position.z)
            slope_penalty = clampf(1.0 - sin(slope_pitch) * 0.55, 0.64, 1.18)
        speed = move_toward(speed, effective_max, acceleration * accel_curve * slope_penalty * traction * delta)
        heat = minf(1.0, heat + lerpf(0.020, 0.052, normalized_speed) * delta)
    else:
        speed = move_toward(speed, 0.0, (3.1 + normalized_speed * 2.0) * delta)
        heat = maxf(0.0, heat - 0.115 * delta)

    if _brake_value > 0.0:
        speed = move_toward(speed, 0.0, braking * _brake_value * delta)
        heat = maxf(0.0, heat - 0.060 * delta)

    if not player_controlled:
        speed = minf(speed, ai_target_speed)
        heat = maxf(0.0, heat - 0.045 * delta)

    current_rpm = clampf(0.18 + normalized_speed * 0.68 + _throttle_value * 0.22, 0.0, 1.0)

func _update_ai_speed(delta: float) -> void:
    ai_target_speed = move_toward(ai_target_speed, (27.0 + ai_skill * 3.2), delta * 0.30)

func activate_from_grid() -> void:
    race_finished = false
    crashed = false
    race_active = true
    crash_timer = 0.0
    _stuck_timer = 0.0
    _last_progress_x = global_position.x
    velocity.y = 0.0
    velocity.z = 0.0
    airborne = false
    if _track == null or not is_instance_valid(_track):
        _track = get_tree().get_first_node_in_group("race_track") as DirtlineTrack
    _snap_to_surface()
    if player_controlled:
        speed = maxf(speed, 0.0)
        velocity.x = speed
    else:
        # Small clutch launch prevents AI riders from remaining at an exact
        # zero-velocity equilibrium on the grid. Normal AI acceleration takes
        # over immediately on the following physics tick.
        speed = maxf(speed, 3.4)
        _throttle_value = 1.0
        velocity.x = speed

func set_touch_throttle(value: bool) -> void:
    touch_throttle = value

func set_touch_brake(value: bool) -> void:
    touch_brake = value

func set_touch_boost(value: bool) -> void:
    touch_boost = value

func set_touch_lean(value: float) -> void:
    touch_lean = clampf(value, -1.0, 1.0)

func set_touch_lane_step(direction: int) -> void:
    touch_lane_step = clampi(direction, -1, 1)

func on_ramp(power: float) -> void:
    if crashed or race_finished or speed < 6.0:
        return
    if not airborne:
        var speed_factor: float = clampf(speed / max_speed, 0.45, 1.12)
        velocity.y = power * (0.70 + speed_factor * 0.34)
        airborne = true
        _pitch_velocity += 0.18
        _suspension_compression = 0.10
        if _audio:
            _audio.play_sfx("jump", -4.0, randf_range(0.96, 1.04))

func on_mud() -> void:
    mud_timer = maxf(mud_timer, 1.15)
    speed *= 0.94
    _mud_spray.emitting = true
    if _audio:
        _audio.play_sfx("mud", -5.0, randf_range(0.92, 1.06))

func on_obstacle() -> void:
    if speed > 8.0:
        crash()
    else:
        speed *= 0.72

func give_boost(amount: float = 0.22) -> void:
    boost_meter = minf(1.0, boost_meter + amount)
    speed = minf(max_speed * 1.15, speed + 2.8)

func crash() -> void:
    if crashed:
        return
    crashed = true
    crash_timer = 1.25
    velocity.y = 4.6
    speed *= 0.40
    _pitch_velocity = 2.0 if randf() > 0.5 else -2.0
    crashed_event.emit()
    if _audio:
        _audio.play_sfx("crash_1" if randf() > 0.5 else "crash_2", -2.0, randf_range(0.94, 1.05))

func _update_crash(delta: float) -> void:
    crash_timer -= delta
    speed = move_toward(speed, 0.0, 15.0 * delta)
    velocity.x = speed
    velocity.y -= GRAVITY * delta
    _advance_lateral(delta)
    global_position.x += speed * delta
    global_position.y += velocity.y * delta
    var ground_y: float = _surface_y(global_position.x, global_position.z)
    if global_position.y < ground_y:
        global_position.y = ground_y
        velocity.y = 0.0
    _visual_pitch += _pitch_velocity * delta
    _pitch_velocity += 1.2 * delta
    _update_visuals(delta)
    if crash_timer <= 0.0:
        crashed = false
        airborne = false
        speed = 7.5
        heat *= 0.70
        _visual_pitch = 0.0
        _pitch_velocity = 0.0
        global_position.z = side_depth_z
        _snap_to_surface()
        velocity = Vector3(speed, 0.0, 0.0)

func _handle_landing() -> void:
    var impact: float = absf(_last_y_velocity)
    var ground_pitch: float = _ground_pitch_at(global_position.x, global_position.z)
    var landing_error: float = absf(wrapf(_visual_pitch - ground_pitch, -PI, PI))
    _suspension_compression = clampf(impact * 0.025, 0.05, 0.30)

    if landing_error > 0.78 or (impact > 9.0 and landing_error > 0.52):
        crash()
        return

    if impact > 2.8 and landing_error < 0.17:
        give_boost(0.20)
        perfect_landing_event.emit()
        if _audio:
            _audio.play_sfx("perfect", -1.5, randf_range(0.98, 1.03))
    elif impact > 6.5 or landing_error > 0.34:
        speed *= 0.86
        if _audio:
            _audio.play_sfx("landing_hard", -4.0, randf_range(0.95, 1.05))
    elif _audio:
        _audio.play_sfx("landing_soft", -8.0, randf_range(0.96, 1.04))

    _pitch_velocity *= 0.25
    _visual_pitch = lerp_angle(_visual_pitch, ground_pitch, 0.45)

func _update_visuals(delta: float) -> void:
    if _model == null:
        return

    _wheel_spin -= speed * delta / 0.48
    if _rear_wheel:
        _rear_wheel.rotation.z = _wheel_spin
    if _front_wheel:
        _front_wheel.rotation.z = _wheel_spin
        _front_wheel.rotation.y = 0.0

    _suspension_compression = move_toward(_suspension_compression, 0.0, 1.55 * delta)
    var base_position := Vector3(0.0, 0.29 - _suspension_compression, 0.0)

    # Keep the rear axle visually planted during a wheelie instead of rotating around the bike center.
    if not airborne and not crashed and _visual_pitch > 0.02:
        var rear_pivot := Vector2(-0.82, 0.17)
        var rotated_pivot := rear_pivot.rotated(_visual_pitch)
        var correction := rear_pivot - rotated_pivot
        base_position.x += correction.x
        base_position.y += correction.y

    _model.position = base_position
    _model.rotation.z = _visual_pitch
    var target_bank := clampf(-velocity.z * 0.055, -0.34, 0.34)
    _visual_bank = lerpf(_visual_bank, target_bank, 1.0 - exp(-8.0 * delta))
    _model.rotation.x = _visual_bank

    var rider_bob := sin(Time.get_ticks_msec() * 0.025) * minf(speed / max_speed, 1.0) * 0.008
    _model.position.y += rider_bob

    var moving_on_ground: bool = not airborne and speed > 4.0 and not crashed
    _dust.emitting = moving_on_ground and mud_timer <= 0.0
    if moving_on_ground:
        _dust.amount_ratio = clampf((speed - 4.0) / 21.0, 0.15, 1.0)
    if mud_timer <= 0.0:
        _mud_spray.emitting = false

func finish_race() -> void:
    if race_finished:
        return
    race_finished = true
    finished_event.emit()
    if _audio:
        _audio.play_sfx("finish", -1.0, 1.0)

func reset_bike(start_transform: Transform3D = _spawn_transform) -> void:
    global_transform = start_transform
    velocity = Vector3.ZERO
    speed = 0.0
    heat = 0.0
    boost_meter = 1.0
    crashed = false
    race_finished = false
    race_active = false
    airborne = false
    _visual_pitch = 0.0
    _pitch_velocity = 0.0
    _loopout_timer = 0.0
    combined_lean_input = 0.0
    lane_index = target_lane_index
    side_depth_z = float(LANE_POSITIONS[target_lane_index])
    global_position.z = side_depth_z
    if _track == null or not is_instance_valid(_track):
        _track = get_tree().get_first_node_in_group("race_track") as DirtlineTrack
    _snap_to_surface()
