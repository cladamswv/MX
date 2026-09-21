extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
    checks += 1
    if not value: failures += 1; print("FAIL: ", label)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
    var packed := load("res://Main.tscn") as PackedScene; check(packed != null, "main scene loads")
    if packed == null: quit(1); return
    var game := packed.instantiate(); root.add_child(game); await process_frame
    check(game.hud != null, "HUD instantiates"); check(game.audio != null, "audio manager instantiates")
    check(AudioServer.get_bus_index("Music") >= 0, "music bus exists"); check(AudioServer.get_bus_index("Engines") >= 0, "engine bus exists")
    await game._start_course(0); await process_frame
    check(game.racers.size() == 7, "arcade grid has seven riders"); check(game.player.race_active, "race activates")
    var start_x: float = game.player.global_position.x; game.player.set_touch_throttle(true)
    for i in range(120): await physics_frame
    check(game.player.global_position.x > start_x + 1.0, "player advances"); check(game.racers[1].global_position.x > start_x, "AI advances")
    check(game.hud.controls_root.get_node("LeftControlPad").size.y <= 150.0, "compact controls")
    print("BAR SIZES ", game.hud.boost_bar.size, " ", game.hud.heat_bar.size)
    check(game.hud.boost_bar.size.y * game.hud.boost_bar.scale.y <= 12.0, "compact boost bar"); check(game.hud.heat_bar.size.y * game.hud.heat_bar.scale.y <= 12.0, "compact heat bar")
    check(game.camera.camera_back_offset >= 5.0, "camera look-ahead")
    print("DIRTLINE 3.4.0: ", checks, " checks, ", failures, " failures")
    game.queue_free(); await process_frame; quit(0 if failures == 0 else 1)
