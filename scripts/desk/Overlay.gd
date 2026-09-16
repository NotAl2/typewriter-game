extends Node2D
## Screen-space layer: the idle affordance pulse and a very small readout.
##
## There is no tutorial and no popup. If the player sits still for a few
## seconds, whatever they should reach for next breathes gently - enough to
## teach the ritual, quiet enough to ignore once they know it. The readout is
## four short words in paper-coloured type, low in the frame, and it goes away
## entirely once typing starts.

const IDLE_BEFORE_HINT := 3.2
const PULSE_SPEED := 3.1

const PAPER := Color(0.949, 0.910, 0.816)
const DIM := Color(1.0, 0.945, 0.855, 0.62)
const WARN := Color(0.96, 0.62, 0.34)
const HINT_COL := Color(1.0, 0.855, 0.545)

var ritual
var font: BitmapText

var _idle := 0.0
var _pulse := 0.0
var _flash := 0.0
var _flash_text := ""
var _wired := false


func setup(r, f: BitmapText) -> void:
	ritual = r
	font = f
	# setup() is called again for every letter, so the one-time wiring below has
	# to happen exactly once or the flash messages stack up
	if _wired:
		return
	_wired = true
	GameEvents.margin_bell_rang.connect(func() -> void: _flash_now("margin"))
	GameEvents.paper_torn.connect(func() -> void: _flash_now("the sheet tore"))
	GameEvents.wax_scorched.connect(func() -> void: _flash_now("the wax is spoiled"))
	GameEvents.jam_started.connect(func(_a: int, _b: int) -> void:
		_flash_now("jammed"))
	GameEvents.paper_released.connect(func() -> void: _flash_now("released"))
	GameEvents.wax_stick_spent.connect(func() -> void:
		_flash_now("the stick is gone"))
	GameEvents.paper_scrapped.connect(func(_w: String) -> void:
		_flash_now("spoiled"))


func notify_activity() -> void:
	_idle = 0.0


func _flash_now(text: String) -> void:
	_flash_text = text
	_flash = 2.2


func _process(delta: float) -> void:
	_idle += delta
	_pulse += delta * PULSE_SPEED
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
	queue_redraw()


func _draw() -> void:
	if ritual == null or font == null or not is_instance_valid(ritual):
		return

	# --- the affordance pulse ---
	if _idle >= IDLE_BEFORE_HINT:
		var r: Rect2 = ritual.target_rect()
		if r.size.x > 1.0 and r.size.y > 1.0:
			var a := 0.16 + 0.14 * (0.5 + 0.5 * sin(_pulse))
			var grown := r.grow(2.0)
			draw_rect(grown, Color(HINT_COL.r, HINT_COL.g, HINT_COL.b, a * 0.5),
					  false, 1.0)
			draw_rect(r, Color(HINT_COL.r, HINT_COL.g, HINT_COL.b, a), false, 1.0)

	# --- stage hint, bottom left ---
	var hint: String = ritual.hint()
	if not hint.is_empty():
		var col := DIM
		if _idle >= IDLE_BEFORE_HINT:
			col.a = 0.62 + 0.30 * (0.5 + 0.5 * sin(_pulse))
		# a dark pass underneath keeps it legible over the lit desk
		font.draw_text(self, hint, Vector2(11, Layout.VIEW_H - 13),
					   Color(0.05, 0.03, 0.02, col.a * 0.8))
		font.draw_text(self, hint, Vector2(10, Layout.VIEW_H - 14), col)

	# --- momentary alerts, bottom right ---
	if _flash > 0.0 and not _flash_text.is_empty():
		var a: float = clampf(_flash / 0.6, 0.0, 1.0)
		var w := font.width_of(_flash_text)
		font.draw_text(self, _flash_text,
					   Vector2(Layout.VIEW_W - w - 10, Layout.VIEW_H - 14),
					   Color(WARN.r, WARN.g, WARN.b, a))


## Draw the end-of-ritual verdict. Called by DeskScene once, on completion.
func draw_result(lines: PackedStringArray) -> void:
	var panel := Node2D.new()
	panel.set_script(preload("res://scripts/desk/ResultCard.gd"))
	add_child(panel)
	panel.setup(font, lines)
