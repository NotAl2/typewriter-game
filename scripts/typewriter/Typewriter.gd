extends Node2D
## The machine. Owns the carriage, the keyboard, the basket and the page.
##
## Everything a keystroke has to do passes through `type_char`, in the order the
## real machine does it: the key goes down, a bar swings, ink lands on the
## paper, the escapement lets the carriage slip one column, and somewhere near
## the right margin a bell rings to warn you that you are running out of line.
##
## What it deliberately does NOT have is a backspace that erases. `back_space`
## moves the carriage back a column and prints nothing; strike a character there
## and it lands on top of what is already inked. A mistake on this machine is
## permanent, and the whole story starts with one.

const ART := "res://assets/art/"

# Left untyped on purpose: these are duck-typed collaborators built at
# runtime, and typing them as Node2D would hide their own API from GDScript.
var carriage
var keyboard
var basket
var page: TypedPage
var renderer: Node2D
var jam: JamController

var input_enabled := false
var paper_in := false

var _viewport: SubViewport
var _font: BitmapText

var _last_char := ""
var _last_time_ms := 0.0
var _typing_started_ms := 0.0
var _chars_typed := 0
var _bell_rung_this_line := false

signal page_full()


func build(font: BitmapText) -> void:
	_font = font
	page = TypedPage.new(randi())
	jam = JamController.new(randi())

	# --- the page renders into its own viewport, so the finished sheet is a
	# real texture we can pull out of the machine later ---
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(Layout.SHEET_W, Layout.SHEET_H)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.disable_3d = true
	add_child(_viewport)

	var sheet_bg := Sprite2D.new()
	sheet_bg.texture = load(ART + "paper_sheet.png")
	sheet_bg.centered = false
	_viewport.add_child(sheet_bg)

	renderer = preload("res://scripts/typewriter/PageRenderer.gd").new()
	renderer.setup(page, _font)
	_viewport.add_child(renderer)

	# --- carriage (holds the sheet, so it must be built after the viewport) ---
	carriage = preload("res://scripts/typewriter/Carriage.gd").new()
	add_child(carriage)
	carriage.build(load(ART + "tw_carriage.png"), load(ART + "tw_platen.png"),
				   load(ART + "tw_knob.png"), load(ART + "tw_return_lever.png"),
				   load(ART + "tw_release_lever.png"), _viewport.get_texture())
	carriage.return_completed.connect(_on_return_completed)
	carriage.line_fed.connect(_on_line_fed)
	carriage.ratchet_notch.connect(func() -> void: Audio.play("platen_ratchet", 1.0, -6.0))

	# --- basket in front of the carriage, body in front of that ---
	basket = preload("res://scripts/typewriter/TypebarBasket.gd").new()
	add_child(basket)
	basket.build(load(ART + "tw_basket.png"), load(ART + "tw_typebar_swing.png"),
				 load(ART + "tw_typebar_jam.png"))
	basket.jam_freed.connect(_on_jam_freed)

	var body := Sprite2D.new()
	body.texture = load(ART + "tw_body.png")
	body.centered = false
	body.position = Vector2(Layout.TW_BODY_X, Layout.TW_BODY_Y)
	add_child(body)

	keyboard = preload("res://scripts/typewriter/Keyboard.gd").new()
	add_child(keyboard)
	keyboard.build(load(ART + "tw_keycaps.png"), load(ART + "tw_spacebar.png"))


# --------------------------------------------------------------------------
# paper
# --------------------------------------------------------------------------

func load_paper() -> void:
	page.clear()
	jam.reset_page()
	carriage.load_paper()
	carriage.set_col(0, false)
	paper_in = true
	_bell_rung_this_line = false
	_chars_typed = 0
	_typing_started_ms = 0.0
	renderer.queue_redraw()


func take_paper() -> Texture2D:
	## Bake the viewport to a standalone texture so the sheet survives being
	## pulled out of the machine and the viewport can be reused for the next one.
	# frame_post_draw guarantees the viewport has actually been rendered before
	# we read it back, but it never fires under the headless dummy renderer -
	# awaiting it there would strand this coroutine and the sheet would never
	# come out of the machine.
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw
	var tex: Texture2D = null
	var img: Image = _viewport.get_texture().get_image()
	if img != null and img.get_width() > 0:
		tex = ImageTexture.create_from_image(img)
	else:
		# headless / dummy renderer has no readable render target; the blank
		# sheet keeps the fold-and-post steps testable without a GPU
		tex = load(ART + "paper_sheet.png")
	carriage.release_paper()
	paper_in = false
	return tex


func current_row() -> int:
	return int(carriage.rows_advanced)


# --------------------------------------------------------------------------
# typing
# --------------------------------------------------------------------------

func wpm() -> float:
	if _typing_started_ms <= 0.0 or _chars_typed < 2:
		return 0.0
	var minutes := (Time.get_ticks_msec() - _typing_started_ms) / 60000.0
	if minutes <= 0.0001:
		return 0.0
	return (_chars_typed / 5.0) / minutes


## Print one character. Returns true if ink actually landed.
func type_char(ch: String) -> bool:
	if not input_enabled or not paper_in:
		return false
	if Settings.uppercase_only:
		ch = ch.to_upper()

	if jam.jammed:
		keyboard.reject(ch)
		Audio.play("key_dead", 1.05, -6.0)
		GameEvents.key_rejected.emit(ch, "jammed")
		return false

	if carriage.is_locked():
		keyboard.reject(ch)
		Audio.play("key_dead", 1.0, -3.0)
		GameEvents.key_rejected.emit(ch, "margin")
		GameEvents.margin_locked.emit()
		return false

	var row: int = carriage.rows_advanced
	if row >= Layout.ROWS:
		keyboard.reject(ch)
		Audio.play("key_dead", 0.95, -3.0)
		GameEvents.key_rejected.emit(ch, "page_full")
		return false

	var now := float(Time.get_ticks_msec())
	var gap := now - _last_time_ms if _last_time_ms > 0.0 else 9999.0
	if _typing_started_ms <= 0.0:
		_typing_started_ms = now

	var col: int = carriage.col
	# force is a rough proxy for how hard the player is hammering
	var force: float = clampf(1.0 - gap / 200.0, 0.0, 1.0)
	var overstruck: bool = page.strike(ch, col, row, force)

	keyboard.press(ch)
	basket.strike()
	renderer.queue_redraw()
	Audio.play_key(clampf(wpm() / 60.0, 0.0, 1.0))
	if overstruck:
		Audio.play("typebar_strike", 0.88, -4.0)

	_chars_typed += 1
	GameEvents.glyph_struck.emit(ch, col, row, overstruck)

	carriage.advance()
	Audio.play("carriage_advance", 1.0, -12.0)

	if carriage.col >= Layout.BELL_COL and not _bell_rung_this_line:
		_bell_rung_this_line = true
		Audio.play("bell", 1.0, -7.0)
		GameEvents.margin_bell_rang.emit()

	# a clash needs two strikes close together on neighbouring bars
	if jam.consider(ch, _last_char, gap, wpm(), col, row):
		_enter_jam()

	_last_char = ch
	_last_time_ms = now
	return true


## Run the carriage back one column without printing. This is how a period
## typist corrects: back up, then strike an x over the mistake.
func back_space() -> bool:
	if not input_enabled or not paper_in or jam.jammed:
		return false
	if not carriage.back_space():
		return false
	Audio.play("carriage_advance", 0.82, -8.0)
	if carriage.col < Layout.BELL_COL:
		_bell_rung_this_line = false
	return true


func begin_return_drag() -> bool:
	return input_enabled and carriage.begin_return_drag()


func update_return_drag(dx: float) -> void:
	carriage.update_return_drag(dx)


func end_return_drag() -> bool:
	return carriage.end_return_drag()


func assisted_return() -> void:
	if input_enabled and Settings.assist_carriage_return:
		carriage.assisted_return()


# --------------------------------------------------------------------------
# jams
# --------------------------------------------------------------------------

func _enter_jam() -> void:
	basket.show_jam(jam.bar_a, jam.bar_b)
	Audio.play("jam_clunk", 1.0, 0.0)
	GameEvents.shake_requested.emit(1.6)
	GameEvents.jam_started.emit(jam.bar_a, jam.bar_b)


func _on_jam_freed() -> void:
	# the bars come away inked, and that ink goes on the page
	page.add_smudge(jam.jam_col, jam.jam_row)
	renderer.queue_redraw()
	Audio.play("jam_clear", 1.0, -2.0)
	GameEvents.jam_cleared.emit(jam.jam_col, jam.jam_row)
	jam.clear_jam()
	_last_char = ""
	_last_time_ms = 0.0


func _on_return_completed(row: int) -> void:
	Audio.play("carriage_return", 1.0, -1.0)
	GameEvents.shake_requested.emit(1.2)
	GameEvents.carriage_returned.emit(row)
	_bell_rung_this_line = false
	_last_char = ""
	if row >= Layout.ROWS:
		page_full.emit()
		GameEvents.page_finished.emit()


func _on_line_fed(_row: int) -> void:
	Audio.play("platen_ratchet", 0.9, -4.0)
	if Settings.blind_write:
		# in blind-writer mode only the lines that have rolled up are legible
		renderer.reveal_rows = carriage.rows_advanced - 1
		renderer.queue_redraw()
