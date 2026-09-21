class_name DirtlineTrack
extends Node3D

signal finish_reached(body)

const COURSE_NAMES := ["PINE RIDGE", "RED MESA", "QUARRY RUN"]
const COURSE_SUBTITLES := ["Forest National", "Desert Invitational", "Industrial Open"]
const LANE_Z := [-5.2, -2.6, 0.0, 2.6, 5.2]
const ROAD_HALF_WIDTH := 7.2
const ROAD_WIDTH := ROAD_HALF_WIDTH * 2.0
const SHOULDER_HALF_WIDTH := 12.0
const SURFACE_START_X := -30.0
const SEGMENT_LENGTH := 0.65
const TRACK_THICKNESS := 0.42
const TRACK_SKIRT_BOTTOM_Y := -0.58

const PROP_PINE := preload("res://models/props/pine_tree.glb")
const PROP_PINE_PS2 := preload("res://models/props/pine_tree_ps2.glb")
const PROP_RIDGE_A := preload("res://models/props/mountain_ridge_a.glb")
const PROP_RIDGE_B := preload("res://models/props/mountain_ridge_b.glb")
const PROP_TOWER := preload("res://models/props/marshal_tower.glb")
const PROP_GRANDSTAND := preload("res://models/props/grandstand.glb")
const PROP_TENT := preload("res://models/props/paddock_tent.glb")
const PROP_CACTUS := preload("res://models/props/cactus_cluster.glb")
const PROP_EXCAVATOR := preload("res://models/props/excavator.glb")
const PROP_PIPE_STACK := preload("res://models/props/pipe_stack.glb")
const PROP_ROCK_ARCH := preload("res://models/props/rock_arch.glb")
const PROP_TIRE_BARRIER := preload("res://models/props/tire_barrier.glb")
const PROP_FENCE := preload("res://models/props/wood_fence_6m.glb")
const PROP_BG_PINE := preload("res://models/props/background_pine_ridge_mp.glb")
const PROP_BG_MESA := preload("res://models/props/background_red_mesa_mp.glb")
const PROP_BG_QUARRY := preload("res://models/props/background_quarry_mp.glb")

@export var course_index := 0
@export var side_view_mode := false
@export var arcade_25d_mode := true

var course_name := "PINE RIDGE"
var course_subtitle := "Forest National"
var track_length := 690.0
var finish_x := 660.0
var start_x := -12.0
var jump_features: Array = []
var mud_zones: Array = []
var obstacle_zones: Array = []
var lane_features: Array = []
var surface_sample_count := 0
var surface_triangle_count := 0

var dirt_material: StandardMaterial3D
var shoulder_material: StandardMaterial3D
var mud_material: StandardMaterial3D
var rut_material: StandardMaterial3D
var orange_material: StandardMaterial3D
var dark_material: StandardMaterial3D
var metal_material: StandardMaterial3D
var barrier_material: StandardMaterial3D
var rock_material: StandardMaterial3D
var foliage_material: StandardMaterial3D
var compacted_material: StandardMaterial3D
var chalk_material: StandardMaterial3D
var safety_material: StandardMaterial3D
var distant_rock_material: StandardMaterial3D
var distant_foliage_material: StandardMaterial3D
var banner_material: StandardMaterial3D
var start_banner_material: StandardMaterial3D
var finish_banner_material: StandardMaterial3D
var crowd_material_a: StandardMaterial3D
var crowd_material_b: StandardMaterial3D

func _ready() -> void:
    add_to_group("race_track")
    seed(4100 + course_index * 97)
    _configure_course()
    _make_materials()
    _build_world_floor()
    _build_segmented_track()
    _build_lane_ruts()
    _build_jump_visuals()
    _build_jump_embankments()
    _build_jump_triggers()
    _build_lane_jump_triggers()
    _build_mud_zones()
    _build_obstacles()
    _build_start_complex()
    _build_finish_complex()
    _build_trackside_barriers()
    _build_race_tape()
    _build_race_infrastructure()
    _build_scenery()

func get_course_name() -> String:
    return course_name

func get_course_subtitle() -> String:
    return course_subtitle

func get_finish_x() -> float:
    return finish_x

func get_start_x() -> float:
    return start_x

func get_start_height() -> float:
    return height_at(start_x)

func get_surface_sample_count() -> int:
    return surface_sample_count

func get_surface_triangle_count() -> int:
    return surface_triangle_count

func _configure_course() -> void:
    course_index = posmod(course_index, COURSE_NAMES.size())
    course_name = COURSE_NAMES[course_index]
    course_subtitle = COURSE_SUBTITLES[course_index]
    match course_index:
        0:
            track_length = 700.0
            finish_x = 668.0
            jump_features = [
                {"kind":"roller","x":30.0,"width":12.0,"height":0.75},
                {"kind":"table","x":68.0,"width":27.0,"height":3.15,"jump":10.4},
                {"kind":"whoops","x":119.0,"width":34.0,"height":0.62},
                {"kind":"double","x":174.0,"width":34.0,"height":3.35,"jump":11.1},
                {"kind":"table","x":236.0,"width":33.0,"height":3.70,"jump":12.0},
                {"kind":"rollers","x":298.0,"width":40.0,"height":0.90},
                {"kind":"double","x":360.0,"width":37.0,"height":4.05,"jump":12.7},
                {"kind":"step","x":430.0,"width":30.0,"height":2.55,"jump":9.8},
                {"kind":"whoops","x":486.0,"width":41.0,"height":0.78},
                {"kind":"table","x":548.0,"width":38.0,"height":4.30,"jump":13.3},
                {"kind":"double","x":616.0,"width":35.0,"height":2.95,"jump":10.8},
            ]
            mud_zones = [98.0, 282.0, 460.0, 632.0]
            obstacle_zones = [
                {"x":148.0,"lanes":[0,2],"kind":"log"},
                {"x":330.0,"lanes":[1,3],"kind":"tire"},
                {"x":510.0,"lanes":[0,1],"kind":"log"},
            ]
        1:
            track_length = 748.0
            finish_x = 716.0
            jump_features = [
                {"kind":"table","x":44.0,"width":30.0,"height":3.5,"jump":11.0},
                {"kind":"double","x":104.0,"width":39.0,"height":4.1,"jump":12.8},
                {"kind":"rollers","x":170.0,"width":44.0,"height":1.00},
                {"kind":"step","x":240.0,"width":34.0,"height":3.0,"jump":10.8},
                {"kind":"double","x":314.0,"width":43.0,"height":4.7,"jump":14.3},
                {"kind":"table","x":392.0,"width":40.0,"height":4.9,"jump":14.0},
                {"kind":"whoops","x":460.0,"width":46.0,"height":0.86},
                {"kind":"double","x":532.0,"width":44.0,"height":4.9,"jump":14.5},
                {"kind":"table","x":610.0,"width":38.0,"height":3.7,"jump":12.1},
                {"kind":"rollers","x":670.0,"width":35.0,"height":0.82},
            ]
            mud_zones = [196.0]
            obstacle_zones = [
                {"x":140.0,"lanes":[1,3],"kind":"rock"},
                {"x":280.0,"lanes":[0,2],"kind":"rock"},
                {"x":486.0,"lanes":[2,3],"kind":"tire"},
                {"x":646.0,"lanes":[0,1],"kind":"rock"},
            ]
        2:
            track_length = 720.0
            finish_x = 688.0
            jump_features = [
                {"kind":"rollers","x":40.0,"width":35.0,"height":0.76},
                {"kind":"table","x":92.0,"width":30.0,"height":3.2,"jump":10.5},
                {"kind":"whoops","x":144.0,"width":41.0,"height":0.72},
                {"kind":"double","x":210.0,"width":37.0,"height":3.9,"jump":12.2},
                {"kind":"step","x":276.0,"width":31.0,"height":2.55,"jump":9.7},
                {"kind":"rollers","x":342.0,"width":42.0,"height":1.00},
                {"kind":"table","x":410.0,"width":36.0,"height":4.25,"jump":12.9},
                {"kind":"double","x":476.0,"width":40.0,"height":4.45,"jump":13.6},
                {"kind":"whoops","x":540.0,"width":47.0,"height":0.83},
                {"kind":"step","x":610.0,"width":32.0,"height":2.95,"jump":10.3},
                {"kind":"table","x":658.0,"width":32.0,"height":3.9,"jump":12.2},
            ]
            mud_zones = [120.0, 366.0, 566.0]
            obstacle_zones = [
                {"x":175.0,"lanes":[0,4],"kind":"pipe"},
                {"x":305.0,"lanes":[1,3],"kind":"tire"},
                {"x":500.0,"lanes":[0,2,4],"kind":"pipe"},
                {"x":630.0,"lanes":[1,3],"kind":"rock"},
            ]

    # Lane-specific mini ramps create real up/down line choice without making the
    # whole course unreadable. These ride on top of the broad course profile.
    match course_index:
        0:
            lane_features = [
                {"x":88.0,"width":12.0,"height":1.15,"lanes":[0,1],"jump":6.8},
                {"x":205.0,"width":14.0,"height":1.35,"lanes":[3,4],"jump":7.2},
                {"x":392.0,"width":12.0,"height":1.10,"lanes":[1,2],"jump":6.6},
                {"x":585.0,"width":14.0,"height":1.45,"lanes":[2,3],"jump":7.4},
            ]
        1:
            lane_features = [
                {"x":74.0,"width":14.0,"height":1.30,"lanes":[2,3],"jump":7.0},
                {"x":265.0,"width":15.0,"height":1.55,"lanes":[0,1],"jump":7.8},
                {"x":505.0,"width":16.0,"height":1.60,"lanes":[3,4],"jump":8.0},
                {"x":650.0,"width":13.0,"height":1.25,"lanes":[1,2],"jump":7.0},
            ]
        2:
            lane_features = [
                {"x":118.0,"width":12.0,"height":1.10,"lanes":[0,1],"jump":6.6},
                {"x":250.0,"width":13.0,"height":1.25,"lanes":[2,3],"jump":7.0},
                {"x":446.0,"width":15.0,"height":1.45,"lanes":[3,4],"jump":7.4},
                {"x":598.0,"width":13.0,"height":1.20,"lanes":[1,2],"jump":6.8},
            ]

func _make_materials() -> void:
    var dirt_path := "res://textures/forest_dirt.jpg" if course_index == 0 else ("res://textures/red_dirt.jpg" if course_index == 1 else "res://textures/quarry_gravel.jpg")
    var shoulder_path := "res://textures/grass_hd.jpg" if course_index == 0 else ("res://textures/sand_hd.jpg" if course_index == 1 else "res://textures/rock_hd.jpg")

    dirt_material = _make_surface_material(Color(0.42, 0.22, 0.09), dirt_path, 0.94, 3.0)
    shoulder_material = _make_surface_material(
        Color(0.16, 0.31, 0.08) if course_index == 0 else (Color(0.48, 0.30, 0.13) if course_index == 1 else Color(0.25, 0.25, 0.23)),
        shoulder_path, 1.0, 4.2
    )
    mud_material = _make_surface_material(Color(0.09, 0.035, 0.014), "res://textures/mud_hd.jpg", 0.58, 3.0)
    compacted_material = _make_surface_material(
        Color(0.20, 0.09, 0.035) if course_index == 0 else (Color(0.44, 0.18, 0.055) if course_index == 1 else Color(0.18,0.18,0.17)),
        dirt_path, 0.96, 2.4
    )

    rut_material = StandardMaterial3D.new()
    rut_material.albedo_color = Color(0.065, 0.026, 0.012, 0.72)
    rut_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    rut_material.roughness = 1.0
    rut_material.cull_mode = BaseMaterial3D.CULL_DISABLED

    orange_material = StandardMaterial3D.new()
    orange_material.albedo_color = Color(1.0, 0.22, 0.025)
    orange_material.roughness = 0.38

    dark_material = StandardMaterial3D.new()
    dark_material.albedo_color = Color(0.018, 0.020, 0.022)
    dark_material.roughness = 0.72

    metal_material = StandardMaterial3D.new()
    metal_material.albedo_color = Color(0.34, 0.36, 0.38)
    metal_material.metallic = 0.55
    metal_material.roughness = 0.32

    barrier_material = StandardMaterial3D.new()
    barrier_material.albedo_color = Color(0.76, 0.73, 0.66)
    barrier_material.roughness = 0.94

    rock_material = _make_surface_material(Color(0.25,0.24,0.22), "res://textures/rock_hd.jpg", 1.0, 2.6)
    foliage_material = StandardMaterial3D.new()
    foliage_material.albedo_color = Color(0.055, 0.20, 0.06)
    foliage_material.roughness = 1.0

    chalk_material = StandardMaterial3D.new()
    chalk_material.albedo_color = Color(0.96, 0.94, 0.86)
    chalk_material.roughness = 1.0

    safety_material = StandardMaterial3D.new()
    safety_material.albedo_color = Color(1.0, 0.29, 0.025)
    safety_material.roughness = 0.42

    crowd_material_a = StandardMaterial3D.new()
    crowd_material_a.albedo_color = Color(0.94, 0.20, 0.04)
    crowd_material_a.roughness = 0.75

    crowd_material_b = StandardMaterial3D.new()
    crowd_material_b.albedo_color = Color(0.07, 0.13, 0.22)
    crowd_material_b.roughness = 0.78

    distant_rock_material = StandardMaterial3D.new()
    distant_rock_material.albedo_color = Color(0.15,0.20,0.23) if course_index == 0 else (Color(0.38,0.18,0.09) if course_index == 1 else Color(0.19,0.20,0.21))
    distant_rock_material.roughness = 1.0

    distant_foliage_material = StandardMaterial3D.new()
    distant_foliage_material.albedo_color = Color(0.035,0.11,0.045)
    distant_foliage_material.roughness = 1.0

    banner_material = _make_banner_material("res://textures/dirtline_banner.png")
    start_banner_material = _make_banner_material("res://textures/start_banner.png")
    finish_banner_material = _make_banner_material("res://textures/finish_banner.png")

func _make_banner_material(texture_path: String) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.roughness = 0.72
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    if ResourceLoader.exists(texture_path):
        mat.albedo_texture = load(texture_path)
    return mat

func _make_surface_material(color: Color, texture_path: String, roughness: float, uv_scale: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = roughness
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.uv1_triplanar = true
    mat.uv1_world_triplanar = true
    mat.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
    if ResourceLoader.exists(texture_path):
        mat.albedo_texture = load(texture_path)
    return mat

func height_at(x: float) -> float:
    var h := 0.0
    var settle := smoothstep(0.0, 24.0, x - SURFACE_START_X) * (1.0 - smoothstep(finish_x - 18.0, finish_x + 4.0, x))
    h += (sin(x * 0.026) * 0.10 + sin(x * 0.071 + 1.8) * 0.04) * settle
    for feature in jump_features:
        h += _feature_height(x, feature)
    return h

func surface_height_at(x: float, z: float) -> float:
    var base := height_at(x)
    for feature in lane_features:
        var lanes: Array = feature["lanes"]
        var best_weight := 0.0
        for lane_id in lanes:
            var lane_z := float(LANE_Z[int(lane_id)])
            var lateral := absf(z - lane_z)
            var lane_weight := 1.0 - smoothstep(0.72, 1.42, lateral)
            best_weight = maxf(best_weight, lane_weight)
        if best_weight <= 0.0:
            continue
        var cx := float(feature["x"])
        var width := float(feature["width"])
        var h := float(feature["height"])
        base += _table_height(x, cx, width, h) * best_weight
    return base

func get_jump_power_crossing(previous_x: float, current_x: float, z_value: float) -> float:
    if current_x <= previous_x:
        return 0.0
    for feature in jump_features:
        if not feature.has("jump"):
            continue
        var cx: float = float(feature["x"])
        var width: float = float(feature["width"])
        var kind: String = str(feature["kind"])
        var lip_factor: float = 0.18
        if kind == "double":
            lip_factor = 0.24
        elif kind == "step":
            lip_factor = 0.16
        var lip_x: float = cx - width * lip_factor
        if previous_x < lip_x and current_x >= lip_x:
            return float(feature["jump"])
    for feature in lane_features:
        var cx: float = float(feature["x"])
        var width: float = float(feature["width"])
        var lip_x: float = cx - width * 0.26
        if not (previous_x < lip_x and current_x >= lip_x):
            continue
        for lane_id in feature["lanes"]:
            var lane_z: float = float(LANE_Z[int(lane_id)])
            if absf(z_value - lane_z) <= 1.05:
                return float(feature["jump"])
    return 0.0

func crossed_mud_zone(previous_x: float, current_x: float) -> bool:
    if current_x <= previous_x:
        return false
    for mud_value in mud_zones:
        var entry_x: float = float(mud_value) - 5.0
        if previous_x < entry_x and current_x >= entry_x:
            return true
    return false

func crossed_obstacle(previous_x: float, current_x: float, z_value: float) -> bool:
    if current_x <= previous_x:
        return false
    for obstacle in obstacle_zones:
        var obstacle_x: float = float(obstacle["x"])
        if not (previous_x < obstacle_x and current_x >= obstacle_x):
            continue
        for lane_id in obstacle["lanes"]:
            var lane_z: float = float(LANE_Z[int(lane_id)])
            if absf(z_value - lane_z) <= 0.82:
                return true
    return false

func _feature_height(x: float, f: Dictionary) -> float:
    var kind := str(f["kind"])
    var cx := float(f["x"])
    var width := float(f["width"])
    var height := float(f["height"])
    if kind == "table":
        return _table_height(x, cx, width, height)
    if kind == "double":
        return _smooth_hump(x, cx - width * 0.23, width * 0.42, height) + _smooth_hump(x, cx + width * 0.24, width * 0.46, height * 0.91)
    if kind == "step":
        return maxf(_table_height(x, cx - width * 0.14, width * 0.64, height * 0.72), _smooth_hump(x, cx + width * 0.29, width * 0.38, height))
    if kind == "roller":
        return _smooth_hump(x, cx, width, height)
    if kind == "rollers" or kind == "whoops":
        var count := 5 if kind == "rollers" else 7
        var spacing := width / float(count)
        var total := 0.0
        for i in range(count):
            var px := cx - width * 0.5 + spacing * (float(i) + 0.5)
            total += _smooth_hump(x, px, spacing * 1.05, height * (0.84 + 0.16 * sin(float(i) * 1.3 + 0.4)))
        return total
    return 0.0

func _smooth_hump(x: float, center: float, width: float, height: float) -> float:
    var t := absf(x - center) / maxf(width * 0.5, 0.001)
    if t >= 1.0:
        return 0.0
    return height * 0.5 * (1.0 + cos(PI * t))

func _table_height(x: float, center: float, width: float, height: float) -> float:
    var d := absf(x - center)
    var half := width * 0.5
    var plateau := width * 0.15
    if d <= plateau:
        return height
    if d >= half:
        return 0.0
    var t := (d - plateau) / maxf(half - plateau, 0.001)
    var smooth := t * t * (3.0 - 2.0 * t)
    return lerpf(height, 0.0, smooth)

func _build_world_floor() -> void:
    var base_color := shoulder_material
    var world := StaticBody3D.new()
    world.name = "WorldFloor"
    world.position = Vector3(track_length * 0.5, -1.55, 0.0)
    add_child(world)
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(track_length + 120.0, 2.0, 150.0)
    mesh.mesh = box
    mesh.material_override = base_color
    world.add_child(mesh)
    var shape := CollisionShape3D.new()
    var box_shape := BoxShape3D.new()
    box_shape.size = box.size
    shape.shape = box_shape
    world.add_child(shape)

func _build_segmented_track() -> void:
    # Arcade 3.0 keeps one continuous collision surface and samples it densely.
    # This avoids the old segmented-box collision lips while supporting five lanes.
    var x_values: Array[float] = []
    var x := SURFACE_START_X
    while x < track_length:
        x_values.append(x)
        x += SEGMENT_LENGTH
    if x_values.is_empty() or x_values[x_values.size() - 1] < track_length:
        x_values.append(track_length)

    surface_sample_count = x_values.size()
    _build_continuous_road_surface(x_values)
    _build_continuous_shoulders(x_values)
    # The old near-side earth wall was useful for a flat side view, but in the
    # 2.5D camera it filled the lower half of wide phone screens with a dark slab.
    if side_view_mode:
        _build_track_skirt(x_values)

func _build_continuous_road_surface(x_values: Array[float]) -> void:
    # 3.0 uses a true 2.5D grid. Each lane can rise independently for arcade
    # ramps while keeping a single continuous collision mesh across the track.
    var z_values: Array[float] = [-ROAD_HALF_WIDTH, -6.25, -5.2, -3.9, -2.6, -1.3, 0.0, 1.3, 2.6, 3.9, 5.2, 6.25, ROAD_HALF_WIDTH]
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)

    for ix in range(x_values.size() - 1):
        var x0 := float(x_values[ix])
        var x1 := float(x_values[ix + 1])
        for iz in range(z_values.size() - 1):
            var z0 := float(z_values[iz])
            var z1 := float(z_values[iz + 1])
            var p00 := Vector3(x0, surface_height_at(x0, z0), z0)
            var p01 := Vector3(x0, surface_height_at(x0, z1), z1)
            var p10 := Vector3(x1, surface_height_at(x1, z0), z0)
            var p11 := Vector3(x1, surface_height_at(x1, z1), z1)

            st.set_uv(Vector2(x0 * 0.12, (z0 + ROAD_HALF_WIDTH) / ROAD_WIDTH))
            st.add_vertex(p00)
            st.set_uv(Vector2(x0 * 0.12, (z1 + ROAD_HALF_WIDTH) / ROAD_WIDTH))
            st.add_vertex(p01)
            st.set_uv(Vector2(x1 * 0.12, (z0 + ROAD_HALF_WIDTH) / ROAD_WIDTH))
            st.add_vertex(p10)

            st.set_uv(Vector2(x0 * 0.12, (z1 + ROAD_HALF_WIDTH) / ROAD_WIDTH))
            st.add_vertex(p01)
            st.set_uv(Vector2(x1 * 0.12, (z1 + ROAD_HALF_WIDTH) / ROAD_WIDTH))
            st.add_vertex(p11)
            st.set_uv(Vector2(x1 * 0.12, (z0 + ROAD_HALF_WIDTH) / ROAD_WIDTH))
            st.add_vertex(p10)

    st.generate_normals()
    var road_mesh_data := st.commit()
    surface_triangle_count = (x_values.size() - 1) * (z_values.size() - 1) * 2

    var body := StaticBody3D.new()
    body.name = "ContinuousRaceSurface"
    body.add_to_group("race_surface")
    add_child(body)

    var road_mesh := MeshInstance3D.new()
    road_mesh.name = "TrackSurfaceMesh"
    road_mesh.mesh = road_mesh_data
    road_mesh.material_override = dirt_material
    body.add_child(road_mesh)

    var road_collision := CollisionShape3D.new()
    road_collision.name = "ContinuousTrackCollision"
    road_collision.shape = road_mesh_data.create_trimesh_shape()
    body.add_child(road_collision)

func _build_continuous_shoulders(x_values: Array[float]) -> void:
    _build_visual_ribbon(x_values, -SHOULDER_HALF_WIDTH, -ROAD_HALF_WIDTH, -0.06, shoulder_material, "FarShoulder")
    _build_visual_ribbon(x_values, ROAD_HALF_WIDTH, SHOULDER_HALF_WIDTH, -0.06, shoulder_material, "NearShoulder")

func _build_visual_ribbon(x_values: Array[float], z0: float, z1: float, y_offset: float, material: Material, node_name: String) -> void:
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var indices := PackedInt32Array()
    for sx in x_values:
        var sy: float = height_at(float(sx)) + y_offset
        vertices.append(Vector3(float(sx), sy, z0))
        vertices.append(Vector3(float(sx), sy, z1))
        normals.append(Vector3.UP)
        normals.append(Vector3.UP)
    for i in range(x_values.size() - 1):
        var a := i * 2
        var b := a + 1
        var c := a + 2
        var d := a + 3
        indices.append_array(PackedInt32Array([a, b, c, b, d, c]))
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_INDEX] = indices
    var ribbon_mesh := ArrayMesh.new()
    ribbon_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var mi := MeshInstance3D.new()
    mi.name = node_name
    mi.mesh = ribbon_mesh
    mi.material_override = material
    add_child(mi)

func _build_track_skirt(x_values: Array[float]) -> void:
    # A continuous near-side earth face makes the side-view course look sculpted
    # without introducing another collision body.
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var indices := PackedInt32Array()
    var z := ROAD_HALF_WIDTH + 0.01
    for sx in x_values:
        var top_y: float = height_at(float(sx)) - 0.02
        vertices.append(Vector3(float(sx), top_y, z))
        vertices.append(Vector3(float(sx), TRACK_SKIRT_BOTTOM_Y, z))
        normals.append(Vector3(0.0, 0.0, 1.0))
        normals.append(Vector3(0.0, 0.0, 1.0))
    for i in range(x_values.size() - 1):
        var a := i * 2
        var b := a + 1
        var c := a + 2
        var d := a + 3
        indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_INDEX] = indices
    var skirt_mesh := ArrayMesh.new()
    skirt_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var mi := MeshInstance3D.new()
    mi.name = "TrackEarthSkirt"
    mi.mesh = skirt_mesh
    mi.material_override = compacted_material
    add_child(mi)

func _build_lane_ruts() -> void:
    var x := start_x + 8.0
    while x < finish_x - 8.0:
        for lane_z in LANE_Z:
            _add_visual_box(Vector3(4.6, 0.025, 0.10), Vector3(x, surface_height_at(x, lane_z) + 0.055, lane_z - 0.30), rut_material)
            _add_visual_box(Vector3(4.6, 0.025, 0.10), Vector3(x, surface_height_at(x, lane_z) + 0.055, lane_z + 0.30), rut_material)
        x += 5.0

func _build_jump_visuals() -> void:
    for feature in jump_features:
        var cx := float(feature["x"])
        var width := float(feature["width"])
        var kind := str(feature["kind"])
        if feature.has("jump"):
            _add_jump_marker_pair(cx - width * 0.34, "JUMP")
            _add_jump_marker_pair(cx + width * 0.32, "LAND")
        if kind == "whoops" or kind == "rollers":
            _add_section_sign(cx - width * 0.55, "WHOOPS")

func _add_jump_marker_pair(x: float, label: String) -> void:
    var y := height_at(x)
    var marker_zs: Array = [-7.25] if side_view_mode else [-7.25, 7.25]
    for z in marker_zs:
        _add_visual_box(Vector3(0.16, 1.55, 0.16), Vector3(x, y + 0.78, float(z)), safety_material)
        _add_visual_box(Vector3(0.36, 0.16, 0.36), Vector3(x, y + 1.58, float(z)), chalk_material)
    _add_section_sign(x, label)

func _add_section_sign(x: float, _label: String) -> void:
    var y := height_at(x)
    _add_visual_box(Vector3(0.12, 1.55, 2.4), Vector3(x, y + 2.25, -8.5), dark_material)
    _add_visual_box(Vector3(0.14, 0.46, 2.1), Vector3(x - 0.08, y + 2.35, -8.5), orange_material)

func _build_jump_embankments() -> void:
    for feature in jump_features:
        if not feature.has("jump"):
            continue
        var cx: float = float(feature["x"])
        var width: float = float(feature["width"])
        var h: float = float(feature["height"])
        # Visual earth masses beneath the jump shoulders make the course read as sculpted dirt, not floating boxes.
        var embankment_sides: Array = [-1.0] if side_view_mode else [-1.0, 1.0]
        for side_value in embankment_sides:
            var side: float = float(side_value)
            var z: float = side * (ROAD_HALF_WIDTH + 1.8)
            var mound := MeshInstance3D.new()
            var mound_mesh := BoxMesh.new()
            mound_mesh.size = Vector3(width * 0.72, maxf(0.45, h * 0.58), 3.4)
            mound.mesh = mound_mesh
            mound.material_override = compacted_material
            mound.position = Vector3(cx, height_at(cx) - maxf(0.35, h * 0.30), z)
            mound.rotation_degrees = Vector3(0.0, randf_range(-2.5, 2.5), 0.0)
            add_child(mound)

func _build_race_tape() -> void:
    var x: float = start_x + 6.0
    while x < finish_x:
        var x2: float = minf(x + 12.0, finish_x)
        var mid: float = (x + x2) * 0.5
        var y: float = height_at(mid)
        var tape_sides: Array = [-1.0] if side_view_mode else [-1.0, 1.0]
        for side_value in tape_sides:
            var side: float = float(side_value)
            var z: float = side * 8.45
            _add_visual_box(Vector3(x2 - x, 0.055, 0.055), Vector3(mid, y + 1.25, z), orange_material)
            _add_visual_box(Vector3(0.10, 1.25, 0.10), Vector3(x, height_at(x) + 0.62, z), dark_material)
        x += 12.0

func _add_spectator_cluster(x: float, z: float) -> void:
    var base_y: float = height_at(clampf(x, start_x, finish_x))
    for i in range(8):
        var person := MeshInstance3D.new()
        var body := CapsuleMesh.new()
        body.radius = 0.18
        body.height = 1.15
        body.radial_segments = 6
        body.rings = 3
        person.mesh = body
        person.material_override = crowd_material_a if i % 2 == 0 else crowd_material_b
        person.position = Vector3(x + float(i % 4) * 0.55 - 0.8, base_y + 0.58, z + float(i / 4) * 0.60 - 0.3)
        person.rotation.y = PI * 0.5 + randf_range(-0.25, 0.25)
        add_child(person)

func _build_jump_triggers() -> void:
    for feature in jump_features:
        if not feature.has("jump"):
            continue
        var cx := float(feature["x"])
        var width := float(feature["width"])
        var kind := str(feature["kind"])
        var lip_factor := 0.18
        if kind == "double":
            lip_factor = 0.24
        elif kind == "step":
            lip_factor = 0.16
        var lip_x := cx - width * lip_factor
        var area := Area3D.new()
        area.collision_layer = 0
        area.collision_mask = 2
        area.name = "JumpTrigger_%d" % int(cx)
        area.position = Vector3(lip_x, height_at(lip_x) + 0.55, 0.0)
        area.monitoring = true
        var cs := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = Vector3(1.25, 1.8, ROAD_WIDTH)
        cs.shape = shape
        area.add_child(cs)
        add_child(area)
        var power := float(feature["jump"])
        area.body_entered.connect(func(body):
            if body.has_method("on_ramp"):
                body.on_ramp(power)
        )

func _build_lane_jump_triggers() -> void:
    for feature in lane_features:
        var cx := float(feature["x"])
        var width := float(feature["width"])
        var power := float(feature["jump"])
        var lip_x := cx - width * 0.26
        for lane_id in feature["lanes"]:
            var lane_z := float(LANE_Z[int(lane_id)])
            var area := Area3D.new()
            area.collision_layer = 0
            area.collision_mask = 2
            area.name = "LaneJump_%d_%d" % [int(cx), int(lane_id)]
            area.position = Vector3(lip_x, surface_height_at(lip_x, lane_z) + 0.48, lane_z)
            var cs := CollisionShape3D.new()
            var shape := BoxShape3D.new()
            shape.size = Vector3(1.3, 1.6, 2.0)
            cs.shape = shape
            area.add_child(cs)
            add_child(area)
            area.body_entered.connect(func(body):
                if body.has_method("on_ramp"):
                    body.on_ramp(power)
            )

func _build_mud_zones() -> void:
    for mud_x in mud_zones:
        var x := float(mud_x)
        var y := height_at(x)
        _add_visual_box(Vector3(10.0, 0.035, ROAD_WIDTH - 0.4), Vector3(x, y + 0.08, 0.0), mud_material)
        var area := Area3D.new()
        area.collision_layer = 0
        area.collision_mask = 2
        area.name = "Mud_%d" % int(x)
        area.position = Vector3(x, y + 0.65, 0.0)
        var cs := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = Vector3(10.0, 1.4, ROAD_WIDTH)
        cs.shape = shape
        area.add_child(cs)
        add_child(area)
        area.body_entered.connect(func(body):
            if body.has_method("on_mud"):
                body.on_mud()
        )

func _build_obstacles() -> void:
    for obstacle in obstacle_zones:
        var x := float(obstacle["x"])
        var kind := str(obstacle["kind"])
        for lane_index in obstacle["lanes"]:
            var z := float(LANE_Z[int(lane_index)])
            var y := surface_height_at(x, z)
            if kind == "tire":
                _spawn_prop(PROP_TIRE_BARRIER, Vector3(x, y + 0.03, z), Vector3(0.75,0.75,0.75), PI * 0.5)
            elif kind == "pipe":
                _add_visual_cylinder(Vector3(x, y + 0.45, z), 0.42, 1.7, metal_material, Vector3(0.0,0.0,90.0))
            elif kind == "rock":
                _add_visual_rock(Vector3(x, y + 0.46, z), 0.78)
            else:
                _add_visual_cylinder(Vector3(x, y + 0.35, z), 0.26, 1.9, barrier_material, Vector3(0.0,0.0,90.0))
            var area := Area3D.new()
            area.collision_layer = 0
            area.collision_mask = 2
            area.position = Vector3(x, y + 0.7, z)
            var cs := CollisionShape3D.new()
            var shape := BoxShape3D.new()
            shape.size = Vector3(1.5, 1.35, 1.25)
            cs.shape = shape
            area.add_child(cs)
            add_child(area)
            area.body_entered.connect(func(body):
                if body.has_method("on_obstacle"):
                    body.on_obstacle()
            )

func _build_start_complex() -> void:
    var y := height_at(start_x)
    _build_arch(start_x - 5.5, y, "START")
    for lane_z in LANE_Z:
        _add_visual_box(Vector3(0.18, 0.035, 1.7), Vector3(start_x + 4.8, y + 0.06, lane_z), chalk_material)
        _add_visual_box(Vector3(2.2, 0.035, 0.08), Vector3(start_x + 3.8, y + 0.06, lane_z - 0.85), chalk_material)
        _add_visual_box(Vector3(2.2, 0.035, 0.08), Vector3(start_x + 3.8, y + 0.06, lane_z + 0.85), chalk_material)
    _build_grandstand(start_x + 12.0, -13.0)
    _add_paddock_tent(start_x + 19.0, -14.5, Color(1.0,0.23,0.04))
    _add_paddock_tent(start_x + 27.0, -15.5, Color(0.09,0.18,0.52))

func _build_finish_complex() -> void:
    var y := height_at(finish_x)
    _build_arch(finish_x, y, "FINISH")
    var area := Area3D.new()
    area.collision_layer = 0
    area.collision_mask = 2
    area.name = "FinishTrigger"
    area.position = Vector3(finish_x + 0.8, y + 1.8, 0.0)
    var cs := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(1.6, 4.5, ROAD_WIDTH + 1.0)
    cs.shape = shape
    area.add_child(cs)
    add_child(area)
    area.body_entered.connect(func(body):
        if body.has_method("finish_race"):
            body.finish_race()
            finish_reached.emit(body)
    )
    _build_grandstand(finish_x - 14.0, -13.0)
    if not side_view_mode:
        _build_grandstand(finish_x - 22.0, 13.0)

func _build_arch(x: float, y: float, _label: String) -> void:
    var arch_zs: Array = [-7.4] if side_view_mode else [-7.4, 7.4]
    for z_value in arch_zs:
        var z: float = float(z_value)
        _add_visual_box(Vector3(0.50, 6.4, 0.50), Vector3(x, y + 3.2, z), dark_material)
        _add_visual_box(Vector3(0.82, 0.18, 0.82), Vector3(x, y + 0.10, z), metal_material)
    if not side_view_mode:
        _add_visual_box(Vector3(0.52, 1.35, 15.1), Vector3(x, y + 5.65, 0.0), dark_material)
    _add_banner_quad(Vector3(x, y + 5.65, -6.9 if side_view_mode else 0.0), Vector2(12.5, 1.05), finish_banner_material if _label == "FINISH" else start_banner_material)
    var lamp_zs: Array = [-6.8] if side_view_mode else [-5.0, 0.0, 5.0]
    for z_value in lamp_zs:
        var z: float = float(z_value)
        var lamp := OmniLight3D.new()
        lamp.position = Vector3(x - 0.45, y + 5.45, z)
        lamp.light_color = Color(1.0, 0.72, 0.40)
        lamp.light_energy = 1.2
        lamp.omni_range = 10.0
        add_child(lamp)

func _build_trackside_barriers() -> void:
    var x := start_x + 4.0
    var fence_zs: Array = [-7.8] if side_view_mode else [-7.8, 7.8]
    while x <= finish_x + 4.0:
        var y := height_at(clampf(x, start_x, finish_x))
        for z_value in fence_zs:
            var z: float = float(z_value)
            _spawn_prop(PROP_FENCE, Vector3(x, y - 0.05, z), Vector3.ONE, 0.0 if z < 0.0 else PI)
        x += 6.0

    var tire_x := start_x + 9.0
    while tire_x < finish_x:
        if int(tire_x / 18.0) % 3 == 0:
            var side := -1.0 if side_view_mode else (-1.0 if int(tire_x) % 2 == 0 else 1.0)
            _spawn_prop(PROP_TIRE_BARRIER, Vector3(tire_x, height_at(tire_x), side * 8.6), Vector3(0.9,0.9,0.9), PI * 0.5)
        tire_x += 18.0

func _build_race_infrastructure() -> void:
    for x in [82.0, 222.0, 382.0, 542.0]:
        if x < finish_x - 20.0:
            _build_timing_gate(x)
    for x in [104.0, 292.0, 468.0]:
        if x < finish_x - 20.0:
            _build_grandstand(x, -13.2)
    for x in [70.0, 210.0, 350.0, 490.0, 630.0]:
        if x < finish_x - 10.0:
            _add_light_pole(x, -11.2)
            if not side_view_mode:
                _add_light_pole(x + 7.0, 11.2)
    for x in [48.0, 156.0, 258.0, 372.0, 486.0, 596.0]:
        if x < finish_x - 10.0:
            _add_track_billboard(x, -9.1)
    for x in [34.0, 126.0, 248.0, 418.0, 566.0]:
        if x < finish_x - 12.0:
            _add_spectator_cluster(x, -12.0)

func _build_timing_gate(x: float) -> void:
    var y := height_at(x)
    var gate_zs: Array = [-7.2] if side_view_mode else [-7.2, 7.2]
    for z_value in gate_zs:
        var z: float = float(z_value)
        _add_visual_box(Vector3(0.24, 4.8, 0.24), Vector3(x, y + 2.4, z), metal_material)
    if not side_view_mode:
        _add_visual_box(Vector3(0.28, 0.68, 14.6), Vector3(x, y + 4.75, 0.0), dark_material)
    _add_banner_quad(Vector3(x, y + 4.76, -6.8 if side_view_mode else 0.0), Vector2(9.6, 0.58), banner_material)

func _build_scenery() -> void:
    _build_background_mountains()
    match course_index:
        0:
            _build_pine_scenery()
        1:
            _build_desert_scenery()
        2:
            _build_quarry_scenery()

func _build_background_mountains() -> void:
    # Arcade 3.1 medium-poly textured environment clusters. Each GLB contains
    # real UV-mapped PBR materials rather than flat-color primitive silhouettes.
    # The large clusters are spaced so the 2.5D camera sees an authored backdrop
    # without stacking several expensive copies in the same frame.
    var bg_scene: PackedScene = PROP_BG_PINE if course_index == 0 else (PROP_BG_MESA if course_index == 1 else PROP_BG_QUARRY)
    var spacing := 78.0 if course_index == 0 else 82.0
    var x := -18.0
    var layer := 0
    while x < finish_x + 95.0:
        var z := -60.0 - float(layer % 2) * 8.0
        var y := -3.2 if course_index == 0 else -2.4
        var scale_amount := 1.02 + float(layer % 3) * 0.035
        var bg := _spawn_prop(bg_scene, Vector3(x, y, z), Vector3.ONE * scale_amount, 0.0)
        if bg != null:
            bg.name = "ArcadeBackgroundMP_%d" % layer
            bg.add_to_group("medium_poly_background")
        x += spacing
        layer += 1

func _build_pine_scenery() -> void:
    var x := -4.0
    while x < finish_x:
        var scenery_sides: Array = [-1.0] if arcade_25d_mode else [-1.0, 1.0]
        for side_value in scenery_sides:
            var side: float = float(side_value)
            if randf() < 0.95:
                _add_pine_tree(x + randf_range(-3.5,3.5), side * randf_range(11.5,19.0), randf_range(0.85,1.45))
            if randf() < 0.58:
                _add_pine_tree(x + randf_range(-5.0,5.0), side * randf_range(19.0,28.0), randf_range(1.15,1.85))
        x += randf_range(8.0,13.0)
    _add_marshal_tower(252.0, 10.5)
    _add_marshal_tower(555.0, -10.5)
    _add_paddock_tent(138.0, -12.5, Color(1.0,0.24,0.04))
    _add_paddock_tent(418.0, 12.5, Color(0.12,0.25,0.72))

func _build_desert_scenery() -> void:
    var x := 8.0
    while x < finish_x:
        var scenery_sides: Array = [-1.0] if arcade_25d_mode else [-1.0, 1.0]
        for side_value in scenery_sides:
            var side: float = float(side_value)
            if randf() < 0.78:
                _add_boulder_cluster(x + randf_range(-4.0,4.0), side * randf_range(12.0,25.0), randf_range(0.8,1.6))
            if randf() < 0.60:
                _add_cactus_cluster(x + randf_range(-3.0,3.0), side * randf_range(14.0,28.0), randf_range(0.85,1.35))
        x += randf_range(12.0,19.0)
    for px in [120.0, 336.0, 575.0]:
        _spawn_prop(PROP_ROCK_ARCH, Vector3(px, height_at(px) - 0.2, 16.0 if int(px) % 2 == 0 else -16.0), Vector3.ONE * 0.9, PI * 0.5)

func _build_quarry_scenery() -> void:
    var x := 10.0
    while x < finish_x:
        var scenery_sides: Array = [-1.0] if arcade_25d_mode else [-1.0, 1.0]
        for side_value in scenery_sides:
            var side: float = float(side_value)
            if randf() < 0.80:
                _add_boulder_cluster(x + randf_range(-4.0,4.0), side * randf_range(13.0,25.0), randf_range(0.75,1.55))
        x += randf_range(11.0,18.0)
    _spawn_prop(PROP_EXCAVATOR, Vector3(225.0, height_at(225.0), -15.0), Vector3.ONE * 1.08, 0.0)
    _spawn_prop(PROP_EXCAVATOR, Vector3(480.0, height_at(480.0), -16.0), Vector3.ONE * 1.08, 0.0)
    _spawn_prop(PROP_PIPE_STACK, Vector3(102.0, height_at(102.0), -14.0), Vector3.ONE, 0.0)
    _spawn_prop(PROP_PIPE_STACK, Vector3(570.0, height_at(570.0), -14.0), Vector3.ONE, 0.0)
    _add_paddock_tent(320.0, -13.0, Color(0.96,0.36,0.05))

func _add_pine_tree(x: float, z: float, scale_value: float) -> void:
    var tree_scene: PackedScene = PROP_PINE_PS2 if side_view_mode else PROP_PINE
    _spawn_prop(tree_scene, Vector3(x, height_at(clampf(x,start_x,finish_x)) - 0.20, z), Vector3.ONE * scale_value, randf_range(-0.12,0.12))

func _add_cactus_cluster(x: float, z: float, scale_value: float) -> void:
    _spawn_prop(PROP_CACTUS, Vector3(x, height_at(clampf(x,start_x,finish_x)) - 0.10, z), Vector3.ONE * scale_value, randf_range(-0.20,0.20))

func _add_boulder_cluster(x: float, z: float, scale_value: float) -> void:
    for i in range(3):
        var p := Vector3(x + randf_range(-1.2,1.2), height_at(clampf(x,start_x,finish_x)) + randf_range(0.25,0.65), z + randf_range(-1.4,1.4))
        _add_visual_rock(p, scale_value * randf_range(0.55,1.0))

func _add_visual_rock(pos: Vector3, scale_value: float) -> void:
    var mesh := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.7
    sphere.height = 1.25
    sphere.radial_segments = 8
    sphere.rings = 5
    mesh.mesh = sphere
    mesh.material_override = rock_material
    mesh.position = pos
    mesh.scale = Vector3(randf_range(0.8,1.4), randf_range(0.65,1.15), randf_range(0.8,1.4)) * scale_value
    mesh.rotation_degrees = Vector3(randf_range(-10,10), randf_range(0,180), randf_range(-10,10))
    add_child(mesh)

func _add_marshal_tower(x: float, z: float) -> void:
    _spawn_prop(PROP_TOWER, Vector3(x, height_at(x), z), Vector3.ONE, 0.0)

func _build_grandstand(x: float, z: float) -> void:
    _spawn_prop(PROP_GRANDSTAND, Vector3(x, height_at(clampf(x,start_x,finish_x)), z), Vector3.ONE, 0.0 if z < 0.0 else PI)

func _add_paddock_tent(x: float, z: float, color: Color) -> void:
    var inst := _spawn_prop(PROP_TENT, Vector3(x, height_at(clampf(x,start_x,finish_x)), z), Vector3.ONE, 0.0)
    _tint_prop(inst, ["Canopy"], color)

func _add_track_billboard(x: float, z: float) -> void:
    var y := height_at(x)
    for dz in [-2.2, 2.2]:
        _add_visual_box(Vector3(0.15, 2.7, 0.15), Vector3(x, y + 1.35, z + dz), dark_material)
    _add_visual_box(Vector3(0.20, 1.55, 4.7), Vector3(x, y + 2.35, z), dark_material)
    var billboard_size: Vector2 = Vector2(3.25, 0.90) if arcade_25d_mode else Vector2(4.15, 1.15)
    _add_banner_quad(Vector3(x - 0.12, y + 2.20, z), billboard_size, banner_material)

func _add_light_pole(x: float, z: float) -> void:
    var y := height_at(clampf(x,start_x,finish_x))
    _add_visual_box(Vector3(0.16, 6.5, 0.16), Vector3(x, y + 3.25, z), dark_material)
    _add_visual_box(Vector3(1.55, 0.13, 0.20), Vector3(x + 0.62, y + 6.18, z), metal_material)
    var lamp := OmniLight3D.new()
    lamp.position = Vector3(x + 1.25, y + 6.0, z)
    lamp.light_color = Color(1.0, 0.79, 0.52)
    lamp.light_energy = 1.45
    lamp.omni_range = 14.0
    add_child(lamp)

func _spawn_prop(scene_resource: PackedScene, pos: Vector3, scale_value: Vector3 = Vector3.ONE, yaw: float = 0.0) -> Node3D:
    var inst := scene_resource.instantiate() as Node3D
    if inst == null:
        return null
    inst.position = pos
    inst.scale = scale_value
    inst.rotation.y = yaw
    add_child(inst)
    return inst

func _tint_prop(root: Node, node_names: Array[String], color: Color) -> void:
    if root == null:
        return
    for target_name in node_names:
        var node := root.find_child(target_name, true, false)
        if node is MeshInstance3D:
            var m := StandardMaterial3D.new()
            m.albedo_color = color
            m.roughness = 0.48
            (node as MeshInstance3D).material_override = m

func _add_banner_quad(pos: Vector3, size_value: Vector2, material: Material) -> MeshInstance3D:
    var mesh := MeshInstance3D.new()
    var quad := QuadMesh.new()
    quad.size = size_value
    mesh.mesh = quad
    mesh.material_override = material
    mesh.position = pos
    mesh.rotation.y = 0.0 if side_view_mode else PI * 0.5
    add_child(mesh)
    return mesh

func _add_visual_box(size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    mesh.mesh = box
    mesh.material_override = material
    mesh.position = pos
    add_child(mesh)
    return mesh

func _add_visual_cylinder(pos: Vector3, radius: float, height: float, material: Material, rotation_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mesh := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = radius
    cylinder.bottom_radius = radius
    cylinder.height = height
    cylinder.radial_segments = 10
    mesh.mesh = cylinder
    mesh.material_override = material
    mesh.position = pos
    mesh.rotation_degrees = rotation_deg
    add_child(mesh)
    return mesh
