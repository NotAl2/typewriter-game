extends Node2D
## Builds the desk, routes every input, and runs the flow between letters.
##
##   menu → type a letter → results → the reply arrives → read it
##        → next letter, or the dismissal card
##
## The scene graph is assembled in code rather than laid out in the editor,
## because every position in it comes from Layout.gd - which is generated from
## the same file the art generator draws with. Placing sprites by hand in a
## .tscn would fork those numbers, and the first time somebody moved the platen
## the paper would stop lining up with the strike point.
##
## Draw order is the whole trick with the machine: the sheet has to be behind
## the platen, the typebars in front of the platen, and the body in front of the
## typebars, or nothing reads as a physical object.

const ART := "res://assets/art/"

enum Phase { MENU, PLAYING, RESULTS, READING, GAME_OVER }

var typewriter
var ritual
var overlay
var candle
var source_letter
var tutorial
var envelope
var kit

var phase: int = Phase.MENU

var _camera: Camera2D
var _world: Node2D
var _ui: CanvasLayer
var _sheet_layer: Node2D
var _font: BitmapText

var _menu
var _reader
var _result_card
var _game_over

var _shake := 0.0
var _shake_seed := 0.0
var _parallax := Vector2.ZERO
var _mouse_down := false
var _breathe := 0.0
var _dust: GPUParticles2D
var _bin: Sprite2D
var _stack: Sprite2D
var prop_labels
var _hands: Sprite2D
var _hand_timer := 0.0
var _headless_test := false


func _ready() -> void:
	randomize()
	_font = BitmapText.load_face("type_5x7")

	_camera = Camera2D.new()
	_camera.position = Vector2(Layout.VIEW_W, Layout.VIEW_H) * 0.5
	_camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	add_child(_camera)

	_world = Node2D.new()
	add_child(_world)

	_build_world()
	_build_overlay()

	GameEvents.shake_requested.connect(_on_shake)
	GameEvents.glyph_struck.connect(_on_glyph_struck)
	GameEvents.carriage_returned.connect(func(_r: int) -> void: _sync_source_row())
	GameEvents.paper_loaded.connect(func() -> void: _sync_source_row())

	Audio.start_ambience()
	set_process_input(true)

	var args := OS.get_cmdline_user_args()
	_headless_test = "--test-ritual" in args
	if _headless_test:
		# tests drive the ritual directly; skip the menu entirely
		RunState.reset(RunState.Difficulty.STANDARD)
		RunState.tutorial_enabled = false
		_begin_letter()
		_run_harness()
	elif "--capture-ui" in args:
		_capture_ui()
	else:
		_open_menu()


## Walk every full-screen layer in turn and photograph it. Used to eyeball the
## menu, guide, reply and dismissal screens without playing to each of them.
func _capture_ui() -> void:
	await _shoot_ui("menu", func() -> void: _open_menu())

	await _shoot_ui("tutorial", func() -> void:
		if is_instance_valid(_menu):
			_menu.queue_free()
		_menu = null
		RunState.reset(RunState.Difficulty.STANDARD)
		_begin_letter()
		_start_tutorial())

	await _shoot_ui("props", func() -> void:
		if is_instance_valid(tutorial):
			tutorial.queue_free()
		tutorial = null
		# park the cursor on the inkwell so its caption is up
		prop_labels.update_hover(
			Vector2(Layout.INKWELL_X + 15, Layout.INKWELL_Y + 15), false))

	await _shoot_ui("results", func() -> void:
		if is_instance_valid(tutorial):
			tutorial.queue_free()
		var r := RitualResult.new()
		r.document_title = "To Eleanor Ashe"
		r.accuracy = 0.71
		r.chars_expected = 100
		r.chars_correct = 71
		r.wpm = 22.0
		r.smudges = 3
		r.overstrikes = 6
		r.sheets_spoiled = 2
		r.seal_grade = RitualResult.Grade.POOR
		r.evaluate()
		phase = Phase.RESULTS
		var lines := r.summary_lines()
		lines.append("")
		lines.append(RunState.standing())
		_result_card = preload("res://scripts/desk/ResultCard.gd").new()
		_ui.add_child(_result_card)
		_result_card.setup(_font, lines)
		RunState.submit(r))

	await _shoot_ui("reply_rage", func() -> void:
		if is_instance_valid(_result_card):
			_result_card.queue_free()
		_result_card = null
		RunState.reset(RunState.Difficulty.UNFORGIVING)
		var bad := RitualResult.new()
		bad.chars_expected = 100
		bad.chars_correct = 61
		bad.accuracy = 0.61
		bad.smudges = 4
		bad.overstrikes = 9
		bad.seal_grade = RitualResult.Grade.POOR
		bad.evaluate()
		var tone: int = RunState.submit(bad)
		_show_reply(tone))

	await _shoot_ui("game_over", func() -> void:
		if is_instance_valid(_reader):
			_reader.queue_free()
		_reader = null
		_show_game_over())

	get_tree().quit(0)


func _shoot_ui(name: String, setup_fn: Callable) -> void:
	setup_fn.call()
	for i in 130:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var dir := "user://shots/"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := "%sui_%s.png" % [dir, name]
	img.save_png(path)
	print("ui shot -> %s" % ProjectSettings.globalize_path(path))


func _run_harness() -> void:
	var harness: Node = preload("res://tests/RitualHarness.gd").new()
	add_child(harness)
	harness.finished.connect(func(ok: bool) -> void:
		get_tree().quit(0 if ok else 1))
	harness.run(self)


# --------------------------------------------------------------------------
# construction
# --------------------------------------------------------------------------

func _sprite(tex_name: String, pos: Vector2, parent: Node) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(ART + tex_name + ".png")
	s.centered = false
	s.position = pos
	parent.add_child(s)
	return s


func _build_world() -> void:
	_sprite("bg_room", Vector2.ZERO, _world)
	_sprite("desk", Vector2(0, Layout.DESK_TOP_Y), _world)

	# --- back dressing ---
	_sprite("photo_frame", Vector2(Layout.PHOTO_X, Layout.PHOTO_Y), _world)
	_sprite("journal", Vector2(Layout.JOURNAL_X, Layout.JOURNAL_Y), _world)
	_stack = _sprite("paper_stack",
		Vector2(Layout.PAPER_STACK_X, Layout.PAPER_STACK_Y), _world)

	candle = preload("res://scripts/desk/CandleLight.gd").new()
	_world.add_child(candle)
	candle.build()

	# --- the machine ---
	typewriter = preload("res://scripts/typewriter/Typewriter.gd").new()
	_world.add_child(typewriter)
	typewriter.build(_font)

	# the candle glow rides above the machine so it actually lights it
	var glow: Sprite2D = candle.glow_sprite()
	candle.remove_child(glow)
	_world.add_child(glow)

	# --- front dressing and the props the player uses ---
	source_letter = preload("res://scripts/desk/SourceLetter.gd").new()
	_world.add_child(source_letter)

	_sprite("inkwell", Vector2(Layout.INKWELL_X, Layout.INKWELL_Y), _world)
	_sprite("quill", Vector2(Layout.QUILL_X, Layout.QUILL_Y), _world)
	_sprite("wax_box", Vector2(Layout.WAX_BOX_X, Layout.WAX_BOX_Y), _world)

	# NOTE: hands are deliberately NOT placed. assets/art/hands.png is generated
	# and ready, but the procedural version reads as brown lumps at this scale
	# and merges with the brass die. The cursor already IS the player's hand.

	envelope = preload("res://scripts/letter/Envelope.gd").new()
	_world.add_child(envelope)
	envelope.build(_font)

	kit = preload("res://scripts/letter/SealingKit.gd").new()
	_world.add_child(kit)
	kit.build(envelope.seal_point())

	# the freed sheet and any waste are carried by the player, so they sit above
	# everything else on the desk
	_sheet_layer = Node2D.new()
	_world.add_child(_sheet_layer)

	_build_dust()

	# The basket goes in LAST of the desk furniture so a ball dropping into it
	# disappears behind the rim rather than floating over it.
	_bin = _sprite("bin", Vector2(Layout.BIN_X, Layout.BIN_Y), _world)
	_sprite("chair", Vector2(Layout.CHAIR_X, Layout.CHAIR_Y), _world)


func _build_dust() -> void:
	## Motes drifting through the candle cone. Subtle enough to notice only
	## once, which is exactly right for a room you are meant to settle into.
	_dust = GPUParticles2D.new()
	_dust.texture = load(ART + "dust.png")
	_dust.amount = 26
	_dust.lifetime = 7.0
	_dust.preprocess = 4.0
	_dust.position = Vector2(Layout.FLAME_CX + 30, Layout.FLAME_CY - 40)

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(120, 60, 1)
	mat.direction = Vector3(0.3, -1, 0)
	mat.spread = 40.0
	mat.gravity = Vector3(0, -1.5, 0)
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 5.0
	mat.scale_min = 0.6
	mat.scale_max = 1.3
	mat.color = Color(1.0, 0.855, 0.545, 0.30)
	_dust.process_material = mat
	_world.add_child(_dust)


func _build_overlay() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	_sprite("vignette", Vector2.ZERO, _ui)

	overlay = preload("res://scripts/desk/Overlay.gd").new()
	_ui.add_child(overlay)

	prop_labels = preload("res://scripts/desk/PropLabels.gd").new()
	_ui.add_child(prop_labels)
	prop_labels.build(_font)

	var cursors: Texture2D = load(ART + "cursors.png")
	var img: Image = cursors.get_image()
	Input.set_custom_mouse_cursor(
		ImageTexture.create_from_image(img.get_region(Rect2i(0, 0, 16, 16))),
		Input.CURSOR_ARROW, Vector2(1, 1))
	Input.set_custom_mouse_cursor(
		ImageTexture.create_from_image(img.get_region(Rect2i(16, 0, 16, 16))),
		Input.CURSOR_POINTING_HAND, Vector2(7, 4))
	Input.set_custom_mouse_cursor(
		ImageTexture.create_from_image(img.get_region(Rect2i(32, 0, 16, 16))),
		Input.CURSOR_DRAG, Vector2(7, 4))


# --------------------------------------------------------------------------
# flow
# --------------------------------------------------------------------------

func _open_menu() -> void:
	phase = Phase.MENU
	_menu = preload("res://scripts/desk/MainMenu.gd").new()
	_ui.add_child(_menu)
	_menu.build(_font)
	_menu.start_requested.connect(_on_start)


func _on_start(_diff: int, use_tutorial: bool) -> void:
	if is_instance_valid(_menu):
		_menu.queue_free()
	_menu = null
	RunState.reset()
	_begin_letter()
	if use_tutorial:
		_start_tutorial()


func _begin_letter() -> void:
	phase = Phase.PLAYING
	var doc: DocumentData = RunState.current_document()
	if doc == null:
		_show_game_over()
		return
	var problems := doc.validate(Layout.COLS)
	for p in problems:
		push_warning("document '%s': %s" % [doc.title, p])

	source_letter.build(_font, doc)
	kit.reset_for_letter()
	# a previous letter's sheet or crumpled ball would otherwise stay in the
	# layer forever, still drawing and still catching drags
	for old in _sheet_layer.get_children():
		old.queue_free()

	if ritual != null and is_instance_valid(ritual):
		ritual.queue_free()
	ritual = preload("res://scripts/letter/LetterRitual.gd").new()
	add_child(ritual)
	ritual.setup(typewriter, envelope, kit, source_letter, _stack, _bin,
				 _sheet_layer, doc)
	ritual.completed.connect(_on_letter_done)
	overlay.setup(ritual, _font)


func _start_tutorial() -> void:
	if tutorial != null and is_instance_valid(tutorial):
		tutorial.queue_free()
	tutorial = preload("res://scripts/desk/Tutorial.gd").new()
	_ui.add_child(tutorial)
	tutorial.build(_font, ritual, typewriter)
	tutorial.finished.connect(func() -> void:
		Settings.tutorial_seen = true
		Settings.save_settings())


func _on_letter_done(result: RitualResult) -> void:
	if _headless_test:
		return
	phase = Phase.RESULTS
	var tone: int = RunState.submit(result)
	var lines := result.summary_lines()
	lines.append("")
	lines.append(RunState.standing())
	_result_card = preload("res://scripts/desk/ResultCard.gd").new()
	_ui.add_child(_result_card)
	_result_card.setup(_font, lines)
	_result_card.dismissed.connect(func() -> void: _show_reply(tone))


func _show_reply(tone: int) -> void:
	phase = Phase.READING
	if is_instance_valid(_result_card):
		_result_card.queue_free()
	_result_card = null
	var reply: DocumentData = RunState.take_reply()
	if reply == null:
		_after_reply()
		return
	_reader = preload("res://scripts/desk/LetterReader.gd").new()
	_ui.add_child(_reader)
	_reader.build(_font, reply, tone)
	_reader.dismissed.connect(_after_reply)
	GameEvents.reply_delivered.emit(reply, tone)


func _after_reply() -> void:
	if is_instance_valid(_reader):
		_reader.queue_free()
	_reader = null
	if RunState.failed:
		_show_game_over()
	elif RunState.finished_run:
		_show_game_over()
	else:
		_begin_letter()


func _show_game_over() -> void:
	phase = Phase.GAME_OVER
	GameEvents.run_failed.emit("dismissed" if RunState.failed else "finished")
	_game_over = preload("res://scripts/desk/GameOverCard.gd").new()
	_ui.add_child(_game_over)
	_game_over.build(_font, RunState)
	_game_over.restart_requested.connect(func() -> void:
		get_tree().reload_current_scene())


# --------------------------------------------------------------------------
# input
# --------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if phase == Phase.MENU or phase == Phase.GAME_OVER:
		return                                  # those layers handle themselves

	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		overlay.notify_activity()
		match key.keycode:
			KEY_F5:
				get_tree().reload_current_scene()
				return
			KEY_F9:
				_capture()
				return
			KEY_F1:
				if tutorial != null and is_instance_valid(tutorial):
					tutorial.skip()
				return
			KEY_ESCAPE:
				if phase == Phase.PLAYING:
					get_tree().reload_current_scene()
				return
		if phase == Phase.READING:
			if is_instance_valid(_reader):
				_reader.advance()
			return
		if phase == Phase.RESULTS:
			if is_instance_valid(_result_card):
				_result_card.dismiss()
			return
		match key.keycode:
			KEY_BACKSPACE:
				ritual.handle_backspace()
				return
			KEY_ENTER, KEY_KP_ENTER:
				ritual.handle_enter()
				return
			KEY_TAB:
				ritual.declare_page_finished()
				return
		var uni := key.unicode
		if uni >= 32 and uni < 127:
			ritual.handle_text(char(uni))
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var pos := _to_world(mb.position)
		overlay.notify_activity()

		if phase == Phase.READING:
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT \
					and is_instance_valid(_reader):
				_reader.advance()
			elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN \
					and is_instance_valid(_reader):
				_reader.scroll_by(2)
			elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP \
					and is_instance_valid(_reader):
				_reader.scroll_by(-2)
			return
		if phase == Phase.RESULTS:
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT \
					and is_instance_valid(_result_card):
				_result_card.dismiss()
			return

		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_mouse_down = true
				ritual.mouse_pressed(pos)
			else:
				_mouse_down = false
				ritual.mouse_released(pos)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			source_letter.set_lifted(mb.pressed)
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_DOWN
				or mb.button_index == MOUSE_BUTTON_WHEEL_UP):
			_wheel_roll(mb.button_index == MOUSE_BUTTON_WHEEL_DOWN)
		return

	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var pos := _to_world(mm.position)
		if _mouse_down and phase == Phase.PLAYING:
			overlay.notify_activity()
			ritual.mouse_moved(pos)
		_parallax = ((pos / Vector2(Layout.VIEW_W, Layout.VIEW_H))
					 - Vector2(0.5, 0.5)) * 2.0
		_update_cursor(pos)
		if prop_labels != null:
			var busy: bool = _mouse_down or phase != Phase.PLAYING 				or ritual == null or not ritual.target_at(pos).is_empty()
			prop_labels.update_hover(pos, busy)


## The wheel turns the platen. Carriage.roll() is hard-clamped, so winding past
## the end of the sheet is a no-op instead of scrolling the page off-screen and
## stranding the player with nothing left to click.
func _wheel_roll(down: bool) -> void:
	if phase != Phase.PLAYING or not typewriter.paper_in:
		return
	if ritual.stage != ritual.Stage.PAGE_DONE \
			and ritual.stage != ritual.Stage.ROLL_OUT:
		return
	typewriter.carriage.roll(Layout.LINE_H if down else -Layout.LINE_H)
	if ritual.stage == ritual.Stage.PAGE_DONE \
			and typewriter.carriage.roll_px > 0.0:
		ritual._set_stage(ritual.Stage.ROLL_OUT)


func _to_world(screen_pos: Vector2) -> Vector2:
	return screen_pos - _world.position


func _update_cursor(pos: Vector2) -> void:
	if phase != Phase.PLAYING or ritual == null:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		return
	var over: bool = not ritual.target_at(pos).is_empty()
	if _mouse_down and over:
		Input.set_default_cursor_shape(Input.CURSOR_DRAG)
	elif over:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)


# --------------------------------------------------------------------------
# feel
# --------------------------------------------------------------------------

func _on_shake(strength: float) -> void:
	if Settings.reduced_shake:
		return
	_shake = maxf(_shake, strength)
	_shake_seed = randf() * 100.0


func _on_glyph_struck(_ch: String, _col: int, _row: int, _over: bool) -> void:
	if _hands == null:
		return
	_hand_timer = 0.09
	var frame := 1 if (randi() % 2 == 0) else 2
	_hands.region_rect = Rect2(frame * Layout.HANDS_W, 0,
							   Layout.HANDS_W, Layout.HANDS_H)


func _sync_source_row() -> void:
	source_letter.set_current_row(typewriter.carriage.rows_advanced)


func _process(delta: float) -> void:
	if _hands != null and _hand_timer > 0.0:
		_hand_timer -= delta
		if _hand_timer <= 0.0:
			_hands.region_rect = Rect2(0, 0, Layout.HANDS_W, Layout.HANDS_H)

	if _mouse_down and phase == Phase.PLAYING and ritual != null:
		ritual.mouse_held(delta)

	_breathe += delta
	var offset := Vector2(
		-_parallax.x * 2.5,
		-_parallax.y * 1.5 + sin(_breathe * 0.55) * 0.8)

	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 9.0)
		var t := _shake_seed + _breathe * 40.0
		offset += Vector2(sin(t * 1.7), cos(t * 2.3)) * _shake

	# snapping keeps the pixel grid intact - a fractional camera offset would
	# shimmer every sprite in the room
	_world.position = offset.round()


func _capture() -> void:
	var img := get_viewport().get_texture().get_image()
	var dir := "user://shots/"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir + "shot_%d.png" % Time.get_ticks_msec()
	img.save_png(path)
	print("captured ", ProjectSettings.globalize_path(path))
