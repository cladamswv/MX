# DIRTLINE_SMOKETEST_V330_ARCADE_DRIVE_CLEARHUD_PARSESAFE
extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
    var packed: PackedScene = load("res://Main.tscn") as PackedScene
    if packed == null: quit(10); return
    var game = packed.instantiate(); root.add_child(game); await process_frame
    await game._start_course(0); await process_frame
    var player = game.player; var start_x: float = player.global_position.x
    player.set_touch_throttle(true)
    for i in range(120): await physics_frame
    var player_forward_delta: float = player.global_position.x - start_x
    var ai_forward_delta: float = game.racers[1].global_position.x - start_x
    var camera_back_offset: float = game.camera.camera_back_offset
    print("SMOKE_V330: player_forward_delta=", player_forward_delta)
    print("SMOKE_V330: ai_forward_delta=", ai_forward_delta)
    print("SMOKE_V330: camera_back_offset=", camera_back_offset)
    if player_forward_delta <= 1.0 or ai_forward_delta <= 0.1 or camera_back_offset < 5.0: quit(11); return
    if game.hud.find_child("GameplayLogo", true, false) != null: quit(12); return
    print("SMOKE_V330: PASS"); game.queue_free(); await process_frame; quit(0)
