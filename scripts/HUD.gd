class_name DirtlineHUD
extends CanvasLayer

signal course_selected(index: int)
signal restart_requested
signal next_track_requested
signal menu_requested

const LOGO_MAIN: Texture2D = preload("res://ui/logo_main.png")
const LOGO_MARK: Texture2D = preload("res://ui/logo_mark.png")
const MENU_BG: Texture2D = preload("res://ui/menu_background.jpg")
const LOADING_BG: Texture2D = preload("res://ui/loading_background.jpg")
const ICON_UP: Texture2D = preload("res://ui/icon_up.png")
const ICON_DOWN: Texture2D = preload("res://ui/icon_down.png")
const ICON_PAUSE: Texture2D = preload("res://ui/icon_pause.png")
const ICON_TILT: Texture2D = preload("res://ui/icon_tilt.png")
const UI_CLICK: AudioStream = preload("res://audio/sfx/ui_click.wav")
const UI_CONFIRM: AudioStream = preload("res://audio/sfx/ui_confirm.wav")

var player: DirtlineBike
var racers: Array[DirtlineBike] = []
var race_time: float = 0.0
var race_running: bool = false
var finish_x: float = 660.0
var course_name: String = "PINE RIDGE"
var course_subtitle: String = "Forest National"
var selected_mode: String = "arcade"
var selected_player_color: Color = Color(0.96, 0.24, 0.04)
var selected_color_name: String = "FACTORY ORANGE"
var default_tilt_mode: int = DirtlineBike.TILT_ASSIST

var speed_label: Label
var place_label: Label
var time_label: Label
var course_label: Label
var heat_bar: ProgressBar
var boost_bar: ProgressBar
var progress_bar: ProgressBar
var event_label: Label
var lane_label: Label
var countdown_label: Label
var finish_panel: Panel
var finish_label: Label
var controls_root: Control
var tilt_button: Button
var tilt_status_label: Label
var pause_panel: Panel
var settings_panel: Panel
var help_panel: Panel
var garage_panel: Panel
var track_panel: Panel
var main_menu_panel: Control
var splash_panel: Control
var loading_panel: Control
var loading_bar: ProgressBar
var loading_status: Label
var mode_badge: Label
var _event_timer: float = 0.0
var _root: Control
var _gameplay_root: Control
var _frontend_root: Control
var frontend_backdrop: TextureRect
var _boot_played: bool = false
var _boot_cancelled: bool = false
var _perfect_landings: int = 0
var _ui_player: AudioStreamPlayer
var _max_speed_kmh: int = 0

var panel_style: StyleBoxFlat
var panel_style_heavy: StyleBoxFlat
var panel_style_soft: StyleBoxFlat
var dark_style: StyleBoxFlat
var orange_style: StyleBoxFlat
var warning_style: StyleBoxFlat
var outline_button_style: StyleBoxFlat

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _make_styles()
    _ui_player = AudioStreamPlayer.new()
    _ui_player.name = "UISound"
    add_child(_ui_player)
    _build_ui()

func _process(delta: float) -> void:
    if player == null or not is_instance_valid(player):
        return
    if race_running and not player.race_finished:
        race_time += delta
    var kmh: int = int(player.speed * 3.6)
    _max_speed_kmh = maxi(_max_speed_kmh, kmh)
    if speed_label != null:
        speed_label.text = "%03d" % kmh
    if time_label != null:
        time_label.text = _format_time(race_time)
    if heat_bar != null:
        heat_bar.value = player.heat * 100.0
        heat_bar.add_theme_stylebox_override("fill", warning_style if player.heat > 0.90 else orange_style)
    if boost_bar != null:
        boost_bar.value = player.boost_meter * 100.0
    if progress_bar != null:
        progress_bar.value = clampf((player.global_position.x + 12.0) / maxf(finish_x + 12.0, 1.0) * 100.0, 0.0, 100.0)
    if place_label != null:
        place_label.text = "%d/%d" % [_get_place(), maxi(racers.size(), 1)]
    if lane_label != null:
        lane_label.text = "LINE %d" % [player.get_lane_index() + 1]
    if tilt_status_label != null:
        tilt_status_label.text = player.get_tilt_status_text()
    if tilt_button != null:
        tilt_button.text = "TILT  %s" % player.get_tilt_mode_label()
    _event_timer -= delta
    if _event_timer <= 0.0 and event_label != null:
        event_label.text = ""

func bind_race(new_player: DirtlineBike, new_racers: Array[DirtlineBike], new_finish_x: float, new_course_name: String, new_subtitle: String) -> void:
    player = new_player
    racers = new_racers
    finish_x = new_finish_x
    course_name = new_course_name
    course_subtitle = new_subtitle
    race_time = 0.0
    race_running = false
    _perfect_landings = 0
    _max_speed_kmh = 0
    _hide_frontend_panels()
    if frontend_backdrop != null:
        frontend_backdrop.visible = false
    finish_panel.visible = false
    pause_panel.visible = false
    _gameplay_root.visible = true
    controls_root.visible = true
    course_label.text = "%s  //  %s" % [course_name, course_subtitle.to_upper()]
    mode_badge.text = "ARCADE RACE" if selected_mode == "arcade" else "TIME TRIAL"
    event_label.text = ""
    if player != null:
        player.tilt_mode = default_tilt_mode
        player.calibrate_tilt()
        if tilt_status_label != null:
            tilt_status_label.text = player.get_tilt_status_text()
        if tilt_button != null:
            tilt_button.text = "TILT  %s" % player.get_tilt_mode_label()

func show_course_select() -> void:
    player = null
    racers.clear()
    race_running = false
    _gameplay_root.visible = false
    _hide_frontend_panels()
    if frontend_backdrop != null:
        frontend_backdrop.visible = true
    loading_panel.visible = false
    if not _boot_played:
        _boot_cancelled = false
        call_deferred("_boot_sequence")
    else:
        _show_main_menu()

func show_loading_for_course(index: int) -> void:
    _boot_cancelled = true
    var names: Array[String] = ["PINE RIDGE", "RED MESA", "QUARRY RUN"]
    var subs: Array[String] = ["FOREST NATIONAL", "DESERT CIRCUIT", "INDUSTRIAL RUN"]
    splash_panel.visible = false
    _hide_frontend_panels()
    if frontend_backdrop != null:
        frontend_backdrop.visible = false
    _gameplay_root.visible = false
    loading_panel.visible = true
    loading_panel.modulate = Color.WHITE
    loading_status.text = "BUILDING COURSE"
    loading_bar.value = 12.0
    var title: Label = loading_panel.get_node("CourseTitle") as Label
    var sub: Label = loading_panel.get_node("CourseSubtitle") as Label
    if title != null:
        title.text = names[posmod(index, names.size())]
    if sub != null:
        sub.text = subs[posmod(index, subs.size())]

func set_loading_progress(value: float, text: String) -> void:
    if loading_panel == null:
        return
    loading_bar.value = clampf(value, 0.0, 1.0) * 100.0
    loading_status.text = text.to_upper()

func hide_loading() -> void:
    loading_panel.visible = false

func start_countdown() -> void:
    countdown_label.visible = true
    for value in ["3", "2", "1", "GO!"]:
        countdown_label.text = value
        countdown_label.add_theme_font_size_override("font_size", 82 if value == "GO!" else 112)
        await get_tree().create_timer(0.58, true).timeout
    countdown_label.visible = false
    race_running = true

func show_event(text: String, duration: float = 1.15) -> void:
    event_label.text = text
    _event_timer = duration
    if text.begins_with("PERFECT LANDING"):
        _perfect_landings += 1

func show_finish() -> void:
    race_running = false
    controls_root.visible = false
    finish_panel.visible = true
    finish_label.text = "PLACE  %d / %d\nTIME  %s\nTOP SPEED  %d KM/H\nCLEAN LANDINGS  %d" % [_get_place(), maxi(racers.size(), 1), _format_time(race_time), _max_speed_kmh, _perfect_landings]

func get_race_mode() -> String:
    return selected_mode

func get_player_color() -> Color:
    return selected_player_color

func get_default_tilt_mode() -> int:
    return default_tilt_mode

func _boot_sequence() -> void:
    _boot_played = true
    splash_panel.visible = true
    splash_panel.modulate = Color(1, 1, 1, 0)
    var tween_in: Tween = create_tween()
    tween_in.tween_property(splash_panel, "modulate:a", 1.0, 0.28)
    await tween_in.finished
    if _boot_cancelled:
        splash_panel.visible = false
        return
    await get_tree().create_timer(0.72, true).timeout
    if _boot_cancelled:
        splash_panel.visible = false
        return
    var tween_out: Tween = create_tween()
    tween_out.tween_property(splash_panel, "modulate:a", 0.0, 0.30)
    await tween_out.finished
    splash_panel.visible = false
    splash_panel.modulate = Color.WHITE
    _show_main_menu()

func _show_main_menu() -> void:
    _hide_frontend_panels()
    if frontend_backdrop != null:
        frontend_backdrop.visible = true
    main_menu_panel.visible = true

func _show_track_select(mode: String) -> void:
    selected_mode = mode
    _hide_frontend_panels()
    if frontend_backdrop != null:
        frontend_backdrop.visible = true
    track_panel.visible = true
    var mode_title: Label = track_panel.get_node("ModeTitle") as Label
    if mode_title != null:
        mode_title.text = "ARCADE RACE" if mode == "arcade" else "TIME TRIAL"

func _hide_frontend_panels() -> void:
    if main_menu_panel != null:
        main_menu_panel.visible = false
    if track_panel != null:
        track_panel.visible = false
    if garage_panel != null:
        garage_panel.visible = false
    if help_panel != null:
        help_panel.visible = false
    if settings_panel != null:
        settings_panel.visible = false

func _toggle_pause() -> void:
    if player == null or player.race_finished:
        return
    var now_paused: bool = not get_tree().paused
    get_tree().paused = now_paused
    pause_panel.visible = now_paused
    controls_root.visible = not now_paused
    race_running = not now_paused

func _resume_from_pause() -> void:
    get_tree().paused = false
    pause_panel.visible = false
    controls_root.visible = true
    race_running = true

func _request_restart_from_pause() -> void:
    get_tree().paused = false
    pause_panel.visible = false
    restart_requested.emit()

func _request_menu() -> void:
    get_tree().paused = false
    pause_panel.visible = false
    menu_requested.emit()

func _get_place() -> int:
    if player == null:
        return 1
    var place: int = 1
    for r in racers:
        if r == player or not is_instance_valid(r):
            continue
        if r.global_position.x > player.global_position.x:
            place += 1
    return place

func _format_time(t: float) -> String:
    var minutes: int = int(t) / 60
    var seconds: float = fmod(t, 60.0)
    return "%d:%05.2f" % [minutes, seconds]

func _make_styles() -> void:
    panel_style = StyleBoxFlat.new()
    panel_style.bg_color = Color(0.025, 0.029, 0.034, 0.84)
    panel_style.border_color = Color(0.28, 0.30, 0.32, 0.88)
    panel_style.set_border_width_all(1)
    panel_style.set_corner_radius_all(12)
    panel_style.shadow_color = Color(0, 0, 0, 0.36)
    panel_style.shadow_size = 10

    panel_style_heavy = StyleBoxFlat.new()
    panel_style_heavy.bg_color = Color(0.012, 0.014, 0.017, 0.95)
    panel_style_heavy.border_color = Color(1.0, 0.27, 0.04, 0.78)
    panel_style_heavy.set_border_width_all(2)
    panel_style_heavy.set_corner_radius_all(14)
    panel_style_heavy.shadow_color = Color(0, 0, 0, 0.55)
    panel_style_heavy.shadow_size = 18

    panel_style_soft = StyleBoxFlat.new()
    panel_style_soft.bg_color = Color(0.06, 0.068, 0.077, 0.76)
    panel_style_soft.border_color = Color(0.31, 0.33, 0.35, 0.62)
    panel_style_soft.set_border_width_all(1)
    panel_style_soft.set_corner_radius_all(9)

    dark_style = StyleBoxFlat.new()
    dark_style.bg_color = Color(0.075, 0.082, 0.09, 0.95)
    dark_style.set_corner_radius_all(5)

    orange_style = StyleBoxFlat.new()
    orange_style.bg_color = Color(1.0, 0.255, 0.025, 1.0)
    orange_style.set_corner_radius_all(5)

    warning_style = StyleBoxFlat.new()
    warning_style.bg_color = Color(0.95, 0.055, 0.025, 1.0)
    warning_style.set_corner_radius_all(5)

    outline_button_style = StyleBoxFlat.new()
    outline_button_style.bg_color = Color(0.04, 0.045, 0.052, 0.96)
    outline_button_style.border_color = Color(0.52, 0.54, 0.56, 0.70)
    outline_button_style.set_border_width_all(1)
    outline_button_style.set_corner_radius_all(8)

func _build_ui() -> void:
    _root = Control.new()
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(_root)

    _frontend_root = Control.new()
    _frontend_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _frontend_root.z_index = 50
    _root.add_child(_frontend_root)

    frontend_backdrop = TextureRect.new()
    frontend_backdrop.name = "FrontendBackdrop"
    frontend_backdrop.texture = MENU_BG
    frontend_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    frontend_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    frontend_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    frontend_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _frontend_root.add_child(frontend_backdrop)

    _gameplay_root = Control.new()
    _gameplay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _gameplay_root.z_index = 10
    _root.add_child(_gameplay_root)

    _build_splash()
    _build_loading()
    _build_main_menu()
    _build_track_select()
    _build_garage()
    _build_help()
    _build_settings()
    _build_top_hud()
    _build_events()
    _build_controls()
    _build_pause_panel()
    _build_finish_panel()

    _gameplay_root.visible = false
    _hide_frontend_panels()
    if frontend_backdrop != null:
        frontend_backdrop.visible = true
    loading_panel.visible = false
    splash_panel.visible = false

func _build_splash() -> void:
    splash_panel = Control.new()
    splash_panel.name = "SplashScreen"
    splash_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _frontend_root.add_child(splash_panel)
    _add_fullscreen_background(splash_panel, LOADING_BG, Color(0.02, 0.025, 0.03, 0.36))

    var logo := TextureRect.new()
    logo.texture = LOGO_MAIN
    logo.position = Vector2(188, 188)
    logo.size = Vector2(904, 230)
    logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    splash_panel.add_child(logo)

    var caption: Label = _make_label("A DIRTLINE RACING PRODUCTION", Vector2(0, 458), 18, Color(0.73, 0.76, 0.79))
    caption.size = Vector2(1280, 28)
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    splash_panel.add_child(caption)

func _build_loading() -> void:
    loading_panel = Control.new()
    loading_panel.name = "LoadingScreen"
    loading_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _frontend_root.add_child(loading_panel)
    _add_fullscreen_background(loading_panel, LOADING_BG, Color(0.0, 0.0, 0.0, 0.48))

    var logo := TextureRect.new()
    logo.texture = LOGO_MAIN
    logo.position = Vector2(42, 34)
    logo.size = Vector2(430, 112)
    logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    loading_panel.add_child(logo)

    var course_title: Label = _make_label("PINE RIDGE", Vector2(68, 338), 54, Color(0.98, 0.985, 0.99))
    course_title.name = "CourseTitle"
    course_title.size = Vector2(760, 70)
    loading_panel.add_child(course_title)
    var course_sub: Label = _make_label("FOREST NATIONAL", Vector2(72, 407), 20, Color(1.0, 0.32, 0.05))
    course_sub.name = "CourseSubtitle"
    course_sub.size = Vector2(680, 30)
    loading_panel.add_child(course_sub)

    loading_bar = _make_bar(Vector2(72, 586), Vector2(880, 14))
    loading_panel.add_child(loading_bar)
    loading_status = _make_label("BUILDING COURSE", Vector2(72, 614), 15, Color(0.82, 0.84, 0.86))
    loading_status.size = Vector2(880, 24)
    loading_panel.add_child(loading_status)
    var tip: Label = _make_label("TIP  //  MATCH YOUR BIKE ANGLE TO THE LANDING FOR MORE SPEED", Vector2(72, 656), 14, Color(0.60, 0.63, 0.66))
    tip.size = Vector2(1030, 24)
    loading_panel.add_child(tip)

func _build_main_menu() -> void:
    main_menu_panel = Control.new()
    main_menu_panel.name = "MainMenu"
    main_menu_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _frontend_root.add_child(main_menu_panel)
    _add_fullscreen_background(main_menu_panel, MENU_BG, Color(0.0, 0.0, 0.0, 0.42))

    var logo := TextureRect.new()
    logo.texture = LOGO_MAIN
    logo.position = Vector2(52, 46)
    logo.size = Vector2(610, 158)
    logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    main_menu_panel.add_child(logo)

    var tag: Label = _make_label("FIVE LINES. BIG AIR. ONE FINISH.", Vector2(78, 202), 17, Color(0.76, 0.79, 0.82))
    tag.size = Vector2(580, 30)
    main_menu_panel.add_child(tag)

    var menu_card := Panel.new()
    menu_card.position = Vector2(72, 278)
    menu_card.size = Vector2(394, 370)
    menu_card.add_theme_stylebox_override("panel", panel_style_heavy)
    main_menu_panel.add_child(menu_card)

    var race := _make_button("ARCADE RACE", Vector2(22, 22), Vector2(350, 66), true)
    menu_card.add_child(race)
    race.pressed.connect(func(): _show_track_select("arcade"))
    var time_trial := _make_button("TIME TRIAL", Vector2(22, 98), Vector2(350, 58), false)
    menu_card.add_child(time_trial)
    time_trial.pressed.connect(func(): _show_track_select("time_trial"))
    var garage := _make_button("GARAGE", Vector2(22, 166), Vector2(350, 52), false)
    menu_card.add_child(garage)
    garage.pressed.connect(func():
        _hide_frontend_panels()
        garage_panel.visible = true
    )
    var howto := _make_button("HOW TO PLAY", Vector2(22, 228), Vector2(350, 52), false)
    menu_card.add_child(howto)
    howto.pressed.connect(func():
        _hide_frontend_panels()
        help_panel.visible = true
    )
    var settings := _make_button("SETTINGS", Vector2(22, 290), Vector2(350, 52), false)
    menu_card.add_child(settings)
    settings.pressed.connect(func():
        _hide_frontend_panels()
        settings_panel.visible = true
    )

    var build_label: Label = _make_label("ARCADE 3.2  //  PRESENTATION BUILD", Vector2(918, 674), 13, Color(0.56, 0.59, 0.62))
    build_label.size = Vector2(330, 24)
    build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    main_menu_panel.add_child(build_label)

func _build_track_select() -> void:
    track_panel = Panel.new()
    track_panel.name = "TrackSelect"
    track_panel.position = Vector2(118, 72)
    track_panel.size = Vector2(1044, 576)
    track_panel.add_theme_stylebox_override("panel", panel_style_heavy)
    _frontend_root.add_child(track_panel)

    var mode_title: Label = _make_label("ARCADE RACE", Vector2(34, 24), 22, Color(1.0, 0.30, 0.04))
    mode_title.name = "ModeTitle"
    mode_title.size = Vector2(450, 32)
    track_panel.add_child(mode_title)
    var title: Label = _make_label("SELECT COURSE", Vector2(32, 58), 42, Color(0.98, 0.985, 0.99))
    title.size = Vector2(600, 54)
    track_panel.add_child(title)

    var names: Array[String] = ["PINE RIDGE", "RED MESA", "QUARRY RUN"]
    var subs: Array[String] = ["FOREST NATIONAL", "DESERT CIRCUIT", "INDUSTRIAL RUN"]
    var details: Array[String] = ["TECHNICAL  //  RHYTHM + MUD", "FAST  //  TABLETOPS + AIRTIME", "ROUGH  //  WHOOPS + GRAVEL"]
    for i in range(3):
        var x: float = 34.0 + float(i) * 326.0
        var card := Panel.new()
        card.position = Vector2(x, 142)
        card.size = Vector2(302, 306)
        card.add_theme_stylebox_override("panel", panel_style_soft)
        track_panel.add_child(card)
        var num: Label = _make_label("0%d" % [i + 1], Vector2(18, 12), 18, Color(1.0, 0.30, 0.04))
        card.add_child(num)
        var nm: Label = _make_label(names[i], Vector2(18, 54), 29, Color(0.98, 0.985, 0.99))
        nm.size = Vector2(270, 44)
        card.add_child(nm)
        var sb: Label = _make_label(subs[i], Vector2(18, 101), 14, Color(0.66, 0.69, 0.72))
        sb.size = Vector2(270, 28)
        card.add_child(sb)
        var det: Label = _make_label(details[i], Vector2(18, 162), 13, Color(0.78, 0.80, 0.82))
        det.size = Vector2(270, 26)
        card.add_child(det)
        var choose := _make_button("RACE THIS COURSE", Vector2(18, 226), Vector2(266, 58), i == 0)
        card.add_child(choose)
        choose.pressed.connect(_on_course_button.bind(i))

    var back := _make_button("BACK", Vector2(34, 496), Vector2(140, 48), false)
    track_panel.add_child(back)
    back.pressed.connect(_show_main_menu)
    var hint: Label = _make_label("UP/DOWN CHANGES RACING LINE  //  LEAN OR TILT CONTROLS BIKE PITCH", Vector2(224, 506), 13, Color(0.61, 0.64, 0.67))
    hint.size = Vector2(784, 24)
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    track_panel.add_child(hint)

func _build_garage() -> void:
    garage_panel = Panel.new()
    garage_panel.name = "Garage"
    garage_panel.position = Vector2(250, 112)
    garage_panel.size = Vector2(780, 500)
    garage_panel.add_theme_stylebox_override("panel", panel_style_heavy)
    _frontend_root.add_child(garage_panel)

    var title: Label = _make_label("GARAGE", Vector2(36, 26), 42, Color(0.98, 0.985, 0.99))
    garage_panel.add_child(title)
    var sub: Label = _make_label("CHOOSE YOUR FACTORY COLOR", Vector2(39, 82), 15, Color(0.66, 0.69, 0.72))
    garage_panel.add_child(sub)

    var colors: Array[Color] = [Color(0.96, 0.24, 0.04), Color(0.10, 0.32, 0.72), Color(0.82, 0.08, 0.10)]
    var names: Array[String] = ["FACTORY ORANGE", "FACTORY BLUE", "RACE RED"]
    for i in range(3):
        var x: float = 44.0 + float(i) * 232.0
        var swatch := ColorRect.new()
        swatch.position = Vector2(x, 148)
        swatch.size = Vector2(204, 120)
        swatch.color = colors[i]
        garage_panel.add_child(swatch)
        var b := _make_button(names[i], Vector2(x, 286), Vector2(204, 58), i == 0)
        garage_panel.add_child(b)
        b.pressed.connect(_select_rider_color.bind(colors[i], names[i]))
    var current: Label = _make_label("SELECTED  //  " + selected_color_name, Vector2(44, 376), 16, Color(1.0, 0.31, 0.05))
    current.name = "SelectedColor"
    current.size = Vector2(570, 28)
    garage_panel.add_child(current)
    var back := _make_button("BACK", Vector2(590, 420), Vector2(150, 48), false)
    garage_panel.add_child(back)
    back.pressed.connect(_show_main_menu)

func _select_rider_color(color: Color, label_text: String) -> void:
    selected_player_color = color
    selected_color_name = label_text
    var label: Label = garage_panel.get_node("SelectedColor") as Label
    if label != null:
        label.text = "SELECTED  //  " + selected_color_name

func _build_help() -> void:
    help_panel = Panel.new()
    help_panel.name = "HowToPlay"
    help_panel.position = Vector2(194, 84)
    help_panel.size = Vector2(892, 552)
    help_panel.add_theme_stylebox_override("panel", panel_style_heavy)
    _frontend_root.add_child(help_panel)

    var title: Label = _make_label("HOW TO PLAY", Vector2(38, 28), 40, Color(0.98, 0.985, 0.99))
    help_panel.add_child(title)
    _add_help_block(help_panel, Vector2(40, 112), "01  CHOOSE A LINE", "MOVE UP / DOWN THE TRACK TO PASS RIDERS, AVOID ROUGH SECTIONS AND SET UP JUMPS.")
    _add_help_block(help_panel, Vector2(40, 214), "02  CONTROL THE BIKE", "THROTTLE BUILDS SPEED. BRAKE SETS UP CORNERS. LEAN BACK FOR WHEELIES, LEAN FORWARD FOR NOSE-DOWN ROTATION.")
    _add_help_block(help_panel, Vector2(40, 332), "03  STICK THE LANDING", "MATCH YOUR BIKE ANGLE TO THE LANDING SLOPE. CLEAN LANDINGS KEEP SPEED AND CAN REWARD BOOST.")
    var back := _make_button("BACK", Vector2(702, 478), Vector2(150, 48), false)
    help_panel.add_child(back)
    back.pressed.connect(_show_main_menu)

func _add_help_block(parent: Control, pos: Vector2, header: String, body: String) -> void:
    var h: Label = _make_label(header, pos, 20, Color(1.0, 0.31, 0.05))
    h.size = Vector2(800, 30)
    parent.add_child(h)
    var b: Label = _make_label(body, pos + Vector2(0, 34), 15, Color(0.78, 0.80, 0.82))
    b.size = Vector2(800, 56)
    b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    parent.add_child(b)

func _build_settings() -> void:
    settings_panel = Panel.new()
    settings_panel.name = "Settings"
    settings_panel.position = Vector2(310, 146)
    settings_panel.size = Vector2(660, 430)
    settings_panel.add_theme_stylebox_override("panel", panel_style_heavy)
    _frontend_root.add_child(settings_panel)

    var title: Label = _make_label("SETTINGS", Vector2(36, 28), 40, Color(0.98, 0.985, 0.99))
    settings_panel.add_child(title)
    var tilt_title: Label = _make_label("DEFAULT TILT CONTROL", Vector2(38, 122), 15, Color(0.66, 0.69, 0.72))
    settings_panel.add_child(tilt_title)
    var tilt_setting := _make_button("ASSIST", Vector2(38, 158), Vector2(260, 62), true)
    tilt_setting.name = "TiltSetting"
    settings_panel.add_child(tilt_setting)
    tilt_setting.pressed.connect(_cycle_default_tilt)
    var note: Label = _make_label("ASSIST IS RECOMMENDED. TOUCH LEAN BUTTONS ALWAYS REMAIN AVAILABLE.", Vector2(38, 240), 14, Color(0.72, 0.74, 0.76))
    note.size = Vector2(560, 54)
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    settings_panel.add_child(note)
    var back := _make_button("BACK", Vector2(468, 348), Vector2(150, 48), false)
    settings_panel.add_child(back)
    back.pressed.connect(_show_main_menu)

func _cycle_default_tilt() -> void:
    default_tilt_mode = (default_tilt_mode + 1) % 3
    var button: Button = settings_panel.get_node("TiltSetting") as Button
    if button != null:
        if default_tilt_mode == DirtlineBike.TILT_OFF:
            button.text = "OFF"
        elif default_tilt_mode == DirtlineBike.TILT_FULL:
            button.text = "FULL TILT"
        else:
            button.text = "ASSIST"

func _build_top_hud() -> void:
    var logo := TextureRect.new()
    logo.texture = LOGO_MAIN
    logo.position = Vector2(18, 14)
    logo.size = Vector2(252, 64)
    logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _gameplay_root.add_child(logo)

    var telemetry := Panel.new()
    telemetry.position = Vector2(18, 78)
    telemetry.size = Vector2(446, 76)
    telemetry.add_theme_stylebox_override("panel", panel_style)
    _gameplay_root.add_child(telemetry)

    speed_label = _make_label("000", Vector2(16, -1), 44, Color(0.98, 0.985, 0.99))
    speed_label.size = Vector2(108, 54)
    telemetry.add_child(speed_label)
    telemetry.add_child(_make_label("KM/H", Vector2(20, 49), 11, Color(0.63, 0.66, 0.69)))

    place_label = _make_label("1/7", Vector2(142, 9), 25, Color(1.0, 0.30, 0.04))
    place_label.size = Vector2(76, 34)
    telemetry.add_child(place_label)
    telemetry.add_child(_make_label("POSITION", Vector2(143, 45), 10, Color(0.63, 0.66, 0.69)))

    time_label = _make_label("0:00.00", Vector2(256, 10), 23, Color(0.98, 0.985, 0.99))
    time_label.size = Vector2(166, 32)
    telemetry.add_child(time_label)
    telemetry.add_child(_make_label("RACE TIME", Vector2(258, 45), 10, Color(0.63, 0.66, 0.69)))

    course_label = _make_label("PINE RIDGE  //  FOREST NATIONAL", Vector2(286, 20), 15, Color(0.84, 0.86, 0.88))
    course_label.size = Vector2(500, 24)
    _gameplay_root.add_child(course_label)
    mode_badge = _make_label("ARCADE RACE", Vector2(286, 48), 13, Color(1.0, 0.31, 0.05))
    mode_badge.size = Vector2(260, 22)
    _gameplay_root.add_child(mode_badge)

    var status := Panel.new()
    status.position = Vector2(608, 18)
    status.size = Vector2(574, 92)
    status.add_theme_stylebox_override("panel", panel_style)
    _gameplay_root.add_child(status)

    heat_bar = _make_bar(Vector2(18, 18), Vector2(160, 12))
    status.add_child(heat_bar)
    status.add_child(_make_label("ENGINE HEAT", Vector2(18, 38), 10, Color(0.65, 0.68, 0.71)))
    boost_bar = _make_bar(Vector2(202, 18), Vector2(160, 12))
    boost_bar.value = 100
    status.add_child(boost_bar)
    status.add_child(_make_label("BOOST", Vector2(202, 38), 10, Color(0.65, 0.68, 0.71)))
    progress_bar = _make_bar(Vector2(386, 18), Vector2(168, 12))
    status.add_child(progress_bar)
    status.add_child(_make_label("PROGRESS", Vector2(386, 38), 10, Color(0.65, 0.68, 0.71)))
    lane_label = _make_label("LINE 3", Vector2(386, 61), 13, Color(1.0, 0.31, 0.05))
    lane_label.size = Vector2(168, 22)
    lane_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    status.add_child(lane_label)

    var pause := TextureButton.new()
    pause.texture_normal = ICON_PAUSE
    pause.ignore_texture_size = true
    pause.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
    pause.position = Vector2(1198, 20)
    pause.size = Vector2(56, 56)
    _gameplay_root.add_child(pause)
    pause.pressed.connect(_toggle_pause)

func _build_events() -> void:
    event_label = Label.new()
    event_label.position = Vector2(0, 142)
    event_label.size = Vector2(1280, 58)
    event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    event_label.add_theme_font_size_override("font_size", 26)
    event_label.add_theme_color_override("font_color", Color(1.0, 0.34, 0.055))
    event_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.82))
    event_label.add_theme_constant_override("shadow_offset_x", 2)
    event_label.add_theme_constant_override("shadow_offset_y", 3)
    _gameplay_root.add_child(event_label)

    countdown_label = Label.new()
    countdown_label.position = Vector2(0, 210)
    countdown_label.size = Vector2(1280, 160)
    countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    countdown_label.add_theme_font_size_override("font_size", 112)
    countdown_label.add_theme_color_override("font_color", Color(1.0, 0.26, 0.035))
    countdown_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.88))
    countdown_label.add_theme_constant_override("shadow_offset_x", 4)
    countdown_label.add_theme_constant_override("shadow_offset_y", 5)
    countdown_label.visible = false
    _gameplay_root.add_child(countdown_label)

func _build_controls() -> void:
    controls_root = Control.new()
    controls_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _gameplay_root.add_child(controls_root)

    var left_pad := Panel.new()
    left_pad.position = Vector2(18, 548)
    left_pad.size = Vector2(424, 154)
    left_pad.add_theme_stylebox_override("panel", panel_style)
    controls_root.add_child(left_pad)

    var lane_title: Label = _make_label("TRACK LINE", Vector2(12, 8), 10, Color(0.62, 0.65, 0.68))
    left_pad.add_child(lane_title)
    var lane_up := _make_icon_button(ICON_UP, "UP", Vector2(12, 30), Vector2(84, 108), true)
    left_pad.add_child(lane_up)
    lane_up.pressed.connect(func():
        if player:
            player.set_touch_lane_step(-1)
    )
    var lane_down := _make_icon_button(ICON_DOWN, "DOWN", Vector2(104, 30), Vector2(84, 108), false)
    left_pad.add_child(lane_down)
    lane_down.pressed.connect(func():
        if player:
            player.set_touch_lane_step(1)
    )

    var lean_back := _make_button("LEAN BACK\nWHEELIE", Vector2(202, 20), Vector2(98, 118), false)
    lean_back.add_theme_font_size_override("font_size", 12)
    left_pad.add_child(lean_back)
    lean_back.button_down.connect(func():
        if player:
            player.set_touch_lean(1.0)
    )
    lean_back.button_up.connect(func():
        if player:
            player.set_touch_lean(0.0)
    )

    var lean_fwd := _make_button("LEAN FORWARD\nNOSE DOWN", Vector2(310, 20), Vector2(102, 118), false)
    lean_fwd.add_theme_font_size_override("font_size", 11)
    left_pad.add_child(lean_fwd)
    lean_fwd.button_down.connect(func():
        if player:
            player.set_touch_lean(-1.0)
    )
    lean_fwd.button_up.connect(func():
        if player:
            player.set_touch_lean(0.0)
    )

    var sensor_pad := Panel.new()
    sensor_pad.position = Vector2(462, 626)
    sensor_pad.size = Vector2(332, 76)
    sensor_pad.add_theme_stylebox_override("panel", panel_style)
    controls_root.add_child(sensor_pad)
    var tilt_icon := TextureRect.new()
    tilt_icon.texture = ICON_TILT
    tilt_icon.position = Vector2(8, 11)
    tilt_icon.size = Vector2(50, 50)
    tilt_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    tilt_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    sensor_pad.add_child(tilt_icon)
    tilt_button = _make_button("TILT  ASSIST", Vector2(62, 10), Vector2(132, 54), true)
    tilt_button.add_theme_font_size_override("font_size", 12)
    sensor_pad.add_child(tilt_button)
    tilt_button.pressed.connect(func():
        if player:
            player.cycle_tilt_mode()
            tilt_button.text = "TILT  %s" % player.get_tilt_mode_label()
    )
    var calibrate := _make_button("CAL", Vector2(202, 10), Vector2(54, 54), false)
    calibrate.add_theme_font_size_override("font_size", 12)
    sensor_pad.add_child(calibrate)
    calibrate.pressed.connect(func():
        if player:
            player.calibrate_tilt()
            show_event("TILT CALIBRATED", 0.8)
    )
    var invert := _make_button("INV", Vector2(264, 10), Vector2(56, 54), false)
    invert.add_theme_font_size_override("font_size", 12)
    sensor_pad.add_child(invert)
    invert.pressed.connect(func():
        if player:
            player.toggle_tilt_invert()
            show_event("TILT INVERTED", 0.8)
    )
    tilt_status_label = _make_label("", Vector2(70, 56), 9, Color(0.60, 0.63, 0.66))
    tilt_status_label.size = Vector2(250, 16)
    sensor_pad.add_child(tilt_status_label)

    var right_pad := Panel.new()
    right_pad.position = Vector2(814, 548)
    right_pad.size = Vector2(448, 154)
    right_pad.add_theme_stylebox_override("panel", panel_style)
    controls_root.add_child(right_pad)

    var brake := _make_button("BRAKE", Vector2(12, 32), Vector2(112, 108), false)
    right_pad.add_child(brake)
    brake.button_down.connect(func():
        if player:
            player.set_touch_brake(true)
    )
    brake.button_up.connect(func():
        if player:
            player.set_touch_brake(false)
    )

    var boost := _make_button("BOOST", Vector2(134, 54), Vector2(100, 86), true)
    boost.add_theme_font_size_override("font_size", 15)
    right_pad.add_child(boost)
    boost.button_down.connect(func():
        if player:
            player.set_touch_boost(true)
    )
    boost.button_up.connect(func():
        if player:
            player.set_touch_boost(false)
    )

    var throttle := _make_button("THROTTLE", Vector2(244, 14), Vector2(192, 126), true)
    throttle.add_theme_font_size_override("font_size", 18)
    right_pad.add_child(throttle)
    throttle.button_down.connect(func():
        if player:
            player.set_touch_throttle(true)
    )
    throttle.button_up.connect(func():
        if player:
            player.set_touch_throttle(false)
    )

func _build_pause_panel() -> void:
    pause_panel = Panel.new()
    pause_panel.name = "PauseMenu"
    pause_panel.position = Vector2(422, 162)
    pause_panel.size = Vector2(436, 390)
    pause_panel.visible = false
    pause_panel.add_theme_stylebox_override("panel", panel_style_heavy)
    _gameplay_root.add_child(pause_panel)

    var title: Label = _make_label("PAUSED", Vector2(0, 30), 42, Color(0.98, 0.985, 0.99))
    title.size = Vector2(436, 52)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pause_panel.add_child(title)
    var resume := _make_button("RESUME", Vector2(58, 112), Vector2(320, 58), true)
    pause_panel.add_child(resume)
    resume.pressed.connect(_resume_from_pause)
    var restart := _make_button("RESTART RACE", Vector2(58, 184), Vector2(320, 52), false)
    pause_panel.add_child(restart)
    restart.pressed.connect(_request_restart_from_pause)
    var menu := _make_button("MAIN MENU", Vector2(58, 248), Vector2(320, 52), false)
    pause_panel.add_child(menu)
    menu.pressed.connect(_request_menu)

func _build_finish_panel() -> void:
    finish_panel = Panel.new()
    finish_panel.position = Vector2(386, 152)
    finish_panel.size = Vector2(508, 410)
    finish_panel.visible = false
    finish_panel.add_theme_stylebox_override("panel", panel_style_heavy)
    _gameplay_root.add_child(finish_panel)

    var title: Label = _make_label("RACE COMPLETE", Vector2(0, 24), 20, Color(1.0, 0.30, 0.04))
    title.size = Vector2(508, 30)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    finish_panel.add_child(title)
    finish_label = _make_label("PLACE  1 / 7", Vector2(28, 78), 24, Color(0.98, 0.985, 0.99))
    finish_label.size = Vector2(452, 168)
    finish_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    finish_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    finish_panel.add_child(finish_label)
    var again := _make_button("RACE AGAIN", Vector2(36, 278), Vector2(204, 56), false)
    finish_panel.add_child(again)
    again.pressed.connect(func(): restart_requested.emit())
    var next := _make_button("NEXT TRACK", Vector2(268, 278), Vector2(204, 56), true)
    finish_panel.add_child(next)
    next.pressed.connect(func(): next_track_requested.emit())
    var menu := _make_button("MAIN MENU", Vector2(152, 350), Vector2(204, 42), false)
    finish_panel.add_child(menu)
    menu.pressed.connect(_request_menu)

func _add_fullscreen_background(parent: Control, texture: Texture2D, tint: Color) -> void:
    var bg := TextureRect.new()
    bg.texture = texture
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    parent.add_child(bg)
    var overlay := ColorRect.new()
    overlay.color = tint
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    parent.add_child(overlay)

func _make_bar(pos: Vector2, size_value: Vector2) -> ProgressBar:
    var bar := ProgressBar.new()
    bar.position = pos
    bar.size = size_value
    bar.max_value = 100.0
    bar.show_percentage = false
    bar.add_theme_stylebox_override("background", dark_style)
    bar.add_theme_stylebox_override("fill", orange_style)
    return bar

func _make_label(text_value: String, pos: Vector2, font_size: int, color: Color) -> Label:
    var lbl := Label.new()
    lbl.text = text_value
    lbl.position = pos
    lbl.add_theme_font_size_override("font_size", font_size)
    lbl.add_theme_color_override("font_color", color)
    return lbl

func _play_ui_sound(confirm: bool = false) -> void:
    if _ui_player == null:
        return
    _ui_player.stop()
    _ui_player.stream = UI_CONFIRM if confirm else UI_CLICK
    _ui_player.volume_db = -10.0 if confirm else -14.0
    _ui_player.play()

func _make_button(text_value: String, pos: Vector2, size_value: Vector2, orange: bool) -> Button:
    var button := Button.new()
    button.text = text_value
    button.position = pos
    button.size = size_value
    button.add_theme_font_size_override("font_size", 17)
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.92, 0.22, 0.025, 0.98) if orange else Color(0.09, 0.098, 0.108, 0.97)
    normal.border_color = Color(1.0, 0.36, 0.08, 0.95) if orange else Color(0.34, 0.36, 0.38, 0.90)
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(8)
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color(1.0, 0.29, 0.04, 1.0) if orange else Color(0.14, 0.15, 0.16, 1.0)
    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = Color(0.72, 0.12, 0.02, 1.0) if orange else Color(0.20, 0.21, 0.22, 1.0)
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_color_override("font_color", Color(0.98, 0.985, 0.99))
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.button_down.connect(_play_ui_sound.bind(orange))
    return button

func _make_icon_button(icon: Texture2D, text_value: String, pos: Vector2, size_value: Vector2, orange: bool) -> Button:
    var b: Button = _make_button(text_value, pos, size_value, orange)
    b.icon = icon
    b.icon_max_width = 34
    return b

func _on_course_button(index: int) -> void:
    _hide_frontend_panels()
    course_selected.emit(index)
