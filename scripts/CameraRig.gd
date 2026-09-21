class_name DirtlineCamera
extends Camera3D

# DIRTLINE MX 3.0 arcade 2.5D camera.
# The race still reads left-to-right, but an oblique perspective reveals lane depth
# so the player can move up/down the course like classic arcade motocross games.

var target: DirtlineBike
var shake_strength := 0.0
var impact_zoom := 0.0
var base_fov := 49.0
var camera_distance := 21.5
var camera_height := 9.0
var camera_back_offset := 6.6
var forward_screen_bias := 5.0
var _snapped := false

func _ready() -> void:
    projection = Camera3D.PROJECTION_PERSPECTIVE
    fov = base_fov
    near = 0.12
    far = 1400.0
    make_current()

func set_target(new_target: DirtlineBike, snap_now: bool = true) -> void:
    target = new_target
    _snapped = false
    if target != null and snap_now:
        snap_to_target()

func snap_to_target() -> void:
    if target == null or not is_instance_valid(target):
        return
    global_position = _desired_camera_position()
    _look_arcade_angle()
    make_current()
    _snapped = true

func _process(delta: float) -> void:
    if not current:
        make_current()
    if target == null or not is_instance_valid(target):
        return
    if not _snapped:
        snap_to_target()
        return

    shake_strength = move_toward(shake_strength, 0.0, delta * 3.2)
    impact_zoom = move_toward(impact_zoom, 0.0, delta * 1.9)

    var desired := _desired_camera_position()
    global_position = global_position.lerp(desired, 1.0 - exp(-5.8 * delta))

    if shake_strength > 0.001:
        global_position += Vector3(
            randf_range(-1.0, 1.0),
            randf_range(-0.65, 0.65),
            randf_range(-0.35, 0.35)
        ) * shake_strength

    var speed_ratio := clampf(target.speed / maxf(target.max_speed, 1.0), 0.0, 1.25)
    var target_fov := base_fov + speed_ratio * 3.4 + impact_zoom * 1.8
    fov = lerpf(fov, target_fov, 1.0 - exp(-4.2 * delta))
    _look_arcade_angle()

func _desired_camera_position() -> Vector3:
    if target == null:
        return global_position
    var speed_ratio := clampf(target.speed / maxf(target.max_speed, 1.0), 0.0, 1.25)
    var air_height := clampf(maxf(target.global_position.y - 0.5, 0.0), 0.0, 8.0)
    var lane_follow := target.global_position.z * 0.38
    return Vector3(
        target.global_position.x - camera_back_offset + speed_ratio * 0.45,
        target.global_position.y + camera_height + air_height * 0.12,
        lane_follow + camera_distance
    )

func _look_arcade_angle() -> void:
    if target == null or not is_instance_valid(target):
        return
    var focus := Vector3(
        target.global_position.x + forward_screen_bias,
        target.global_position.y + 1.05,
        target.global_position.z * 0.52
    )
    look_at(focus, Vector3.UP)

func punch(amount: float = 0.16) -> void:
    shake_strength = maxf(shake_strength, amount)
    impact_zoom = maxf(impact_zoom, amount * 1.45)
