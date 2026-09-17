# DIRTLINE_SMOKETEST_V32_PRESENTATION_PARSESAFE
extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _fail(code: int, message: String) -> void:
    push_error("SMOKE_V32: " + message)
    quit(code)

func _run() -> void:
    print("SMOKE_V32: starting 2.5D five-lane + turnkey presentation test")

    var packed = load("res://Main.tscn")
    if packed == null or not (packed is PackedScene):
        _fail(10, "Main.tscn failed to load as PackedScene")
        return

    var game = (packed as PackedScene).instantiate()
    if game == null:
        _fail(11, "Main scene did not instantiate")
        return

    root.add_child(game)
    await process_frame
    await process_frame

    var hud = game.get("hud")
    if hud == null:
        _fail(12, "presentation HUD did not spawn")
        return
    if not ResourceLoader.exists("res://ui/logo_main.png"):
        _fail(41, "professional logo asset is missing")
        return
    if not ResourceLoader.exists("res://ui/menu_background.jpg"):
        _fail(42, "menu background asset is missing")
        return
    if not ResourceLoader.exists("res://ui/loading_background.jpg"):
        _fail(43, "loading background asset is missing")
        return
    if not hud.has_method("show_loading_for_course"):
        _fail(44, "loading-screen API is missing")
        return
    if not hud.has_method("get_race_mode"):
        _fail(45, "race mode API is missing")
        return
    if not hud.has_method("get_player_color"):
        _fail(46, "garage rider-color API is missing")
        return

    if not game.has_method("_start_course"):
        _fail(47, "Main scene does not expose _start_course")
        return

    await game.call("_start_course", 0)
    await process_frame
    await process_frame

    var player = game.get("player")
    var cam = game.get("camera")
    var track = game.get("track")
    var surface_nodes = get_nodes_in_group("race_surface")
    var sample_count = 0
    var triangle_count = 0
    if track != null:
        sample_count = int(track.call("get_surface_sample_count"))
        triangle_count = int(track.call("get_surface_triangle_count"))

    var renderer = str(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))
    var orientation = int(ProjectSettings.get_setting("display/window/handheld/orientation", -1))

    print("SMOKE_V32: renderer=", renderer)
    print("SMOKE_V32: orientation=", orientation)
    print("SMOKE_V32: player=", player != null)
    print("SMOKE_V32: track=", track != null)
    print("SMOKE_V32: camera=", cam != null)
    print("SMOKE_V32: race_surface_bodies=", surface_nodes.size())
    print("SMOKE_V32: samples=", sample_count)
    print("SMOKE_V32: triangles=", triangle_count)

    if renderer != "gl_compatibility":
        _fail(13, "GL Compatibility renderer is not enabled")
        return
    if orientation != DisplayServer.SCREEN_LANDSCAPE:
        _fail(14, "project is not locked to landscape")
        return
    if player == null:
        _fail(15, "player did not spawn")
        return
    if track == null:
        _fail(16, "track did not spawn")
        return
    if cam == null or not (cam is Camera3D):
        _fail(17, "2.5D camera did not spawn")
        return
    if not (cam as Camera3D).current:
        _fail(18, "2.5D camera is not current")
        return
    if (cam as Camera3D).projection != Camera3D.PROJECTION_PERSPECTIVE:
        _fail(19, "camera is not perspective 2.5D projection")
        return
    if surface_nodes.size() < 1:
        _fail(20, "continuous race surface body did not build")
        return
    if sample_count < 900:
        _fail(21, "continuous race surface has too few X samples")
        return
    if triangle_count < 20000:
        _fail(22, "five-lane surface has too few triangles")
        return

    if not player.has_method("nudge_lane"):
        _fail(23, "lane-change method is missing")
        return
    if not player.has_method("get_lane_index"):
        _fail(24, "lane-index method is missing")
        return
    if not player.has_method("set_touch_lane_step"):
        _fail(25, "touch lane method is missing")
        return

    var starting_lane = int(player.call("get_lane_index"))
    print("SMOKE_V32: starting_lane=", starting_lane)
    if starting_lane != 2:
        _fail(26, "player did not start in center lane")
        return

    player.call("nudge_lane", -1)
    var far_lane = int(player.call("get_lane_index"))
    if far_lane != 1:
        _fail(27, "lane change toward far side failed")
        return
    player.call("nudge_lane", 1)
    var restored_lane = int(player.call("get_lane_index"))
    if restored_lane != 2:
        _fail(28, "lane change back to center failed")
        return

    if not player.has_method("calibrate_tilt"):
        _fail(29, "tilt calibration method is missing")
        return
    if not player.has_method("cycle_tilt_mode"):
        _fail(30, "tilt mode method is missing")
        return

    var visual = (player as Node3D).get_node_or_null("BikeVisual")
    if visual == null:
        _fail(31, "Arcade V4 bike visual did not instantiate")
        return
    var armor = visual.find_child("V4_ChestProtector", true, false)
    if armor == null:
        _fail(32, "V4 rider armor upgrade is missing")
        return

    var front_rig = visual.get_node_or_null("FrontWheelRig")
    var rear_rig = visual.get_node_or_null("RearWheelRig")
    if front_rig == null or rear_rig == null:
        _fail(33, "wheel rigs were not created")
        return

    var arcade_mode = bool(track.get("arcade_25d_mode"))
    var side_mode = bool(track.get("side_view_mode"))
    print("SMOKE_V32: arcade_25d=", arcade_mode, " side_view=", side_mode)
    if not arcade_mode or side_mode:
        _fail(34, "track presentation mode is not 2.5D arcade")
        return

    var center_height = float(track.call("surface_height_at", 88.0, 0.0))
    var far_height = float(track.call("surface_height_at", 88.0, -5.2))
    print("SMOKE_V32: lane_surface_delta=", far_height - center_height)
    if far_height <= center_height + 0.15:
        _fail(35, "lane-specific ramp geometry did not build")
        return

    var surface_body = surface_nodes[0]
    var road_mesh = surface_body.get_node_or_null("TrackSurfaceMesh") if surface_body != null else null
    var road_collision = surface_body.get_node_or_null("ContinuousTrackCollision") if surface_body != null else null
    if road_mesh == null:
        _fail(36, "race surface visible mesh is missing")
        return
    if road_collision == null:
        _fail(37, "race surface collision is missing")
        return

    var active_camera = root.get_viewport().get_camera_3d()
    if active_camera == null:
        _fail(38, "viewport has no active Camera3D")
        return

    var background_nodes = get_nodes_in_group("medium_poly_background")
    print("SMOKE_V32: medium_poly_backgrounds=", background_nodes.size())
    if background_nodes.size() < 4:
        _fail(39, "medium-poly textured background clusters did not spawn")
        return

    var bg_mesh_count = 0
    var first_bg = background_nodes[0]
    if first_bg != null:
        bg_mesh_count = _count_mesh_instances(first_bg)
    print("SMOKE_V32: first_background_meshes=", bg_mesh_count)
    if bg_mesh_count < 10:
        _fail(40, "medium-poly background imported with too few mesh parts")
        return

    var gameplay_root = hud.get("_gameplay_root")
    var controls_root = hud.get("controls_root")
    var finish_panel = hud.get("finish_panel")
    if gameplay_root == null or controls_root == null:
        _fail(48, "turnkey gameplay HUD roots are missing")
        return
    if finish_panel == null:
        _fail(49, "results screen is missing")
        return
    if not hud.has_method("_toggle_pause"):
        _fail(50, "pause menu control is missing")
        return

    print("SMOKE_V32: PASS")
    quit(0)

func _count_mesh_instances(node) -> int:
    var count = 0
    if node is MeshInstance3D:
        count += 1
    for child in node.get_children():
        count += _count_mesh_instances(child)
    return count
