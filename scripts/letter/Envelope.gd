extends Node2D
## The envelope: open mouth, letter going in, flap coming down.
##
## Three sprites and no animation system, because each state change is driven by
## a deliberate player drag rather than by a timer. The flap in particular is a
## drag and not a click: closing a letter should take a moment.

enum State { ABSENT, OPEN, STUFFED, CLOSED }

const FLAP_DRAG := 22.0              # px of downward drag to fold the flap shut

var state: int = State.ABSENT

var _open: Sprite2D
var _closed: Sprite2D
var _flap_pull := 0.0
var _font: BitmapText
var _address: PackedStringArray = PackedStringArray()

signal letter_inserted()
signal flap_closed()


func build(font: BitmapText = null) -> void:
	_font = font
	position = Vector2(Layout.ENVELOPE_X, Layout.ENVELOPE_Y)

	_open = Sprite2D.new()
	_open.texture = load("res://assets/art/envelope_open.png")
	_open.centered = false
	# the open sprite carries its raised flap above the body, so it hangs up
	_open.position = Vector2(0, -(_open.texture.get_height() - Layout.ENVELOPE_H))
	_open.visible = false
	_open.show_behind_parent = true
	add_child(_open)

	_closed = Sprite2D.new()
	_closed.texture = load("res://assets/art/envelope_closed.png")
	_closed.centered = false
	_closed.visible = false
	_closed.show_behind_parent = true
	add_child(_closed)

	set_state(State.CLOSED)


## The address is written on the envelope before the player ever sits down, so
## it is never something they can mistype. It is Hallow's hand, not theirs.
func set_address(lines: PackedStringArray, fallback: String = "") -> void:
	_address = lines
	if _address.is_empty() and not fallback.is_empty():
		_address = PackedStringArray([fallback])
	queue_redraw()


func _draw() -> void:
	if _font == null or _address.is_empty() or state == State.ABSENT:
		return
	# only the face-up closed envelope shows its address
	if state != State.CLOSED:
		return
	var ink := Color(0.29, 0.23, 0.18)
	var y := int(Layout.ENVELOPE_H * 0.46)
	for i in mini(_address.size(), 3):
		var text := String(_address[i])
		var x := 14 + i * 5                     # each line indented a little
		for c in text.length():
			# a touch of wobble so it reads as written, not printed
			var jy := ((c * 7 + i * 13) % 3) - 1
			_font.draw_glyph(self, text[c],
							 Vector2(x + c * (Layout.CHAR_ADV - 1), y + jy), ink)
		y += Layout.LINE_H - 1
	# the underline a clerk rules beneath a town name
	_font.draw_glyph(self, "-", Vector2(14, y - 2), ink)


func set_state(s: int) -> void:
	state = s
	_open.visible = s == State.OPEN or s == State.STUFFED
	_closed.visible = s == State.CLOSED
	visible = s != State.ABSENT
	queue_redraw()


func body_rect() -> Rect2:
	return Rect2(position, Vector2(Layout.ENVELOPE_W, Layout.ENVELOPE_H))


## Where the folded letter has to be dropped.
func mouth_rect() -> Rect2:
	var pad := Settings.drag_assist
	return Rect2(position.x - pad, position.y - 6.0 - pad,
				 Layout.ENVELOPE_W + pad * 2.0, 26.0 + pad * 2.0)


## The raised flap, which the player drags down to close.
func flap_rect() -> Rect2:
	var pad := 4.0 + Settings.drag_assist
	var h := _open.texture.get_height() - Layout.ENVELOPE_H
	return Rect2(position.x + 12.0 - pad, position.y - h - pad,
				 Layout.ENVELOPE_W - 24.0 + pad * 2.0, h + pad * 2.0)


## Global point the wax pool forms on.
func seal_point() -> Vector2:
	return position + Vector2(Layout.WAX_POOL_OX, Layout.WAX_POOL_OY)


func accept_letter() -> void:
	if state != State.OPEN:
		return
	set_state(State.STUFFED)
	_flap_pull = 0.0
	Audio.play("paper_slide", 1.05, -3.0)
	letter_inserted.emit()
	GameEvents.letter_inserted.emit()


func begin_flap_pull() -> void:
	_flap_pull = 0.0


func update_flap_pull(delta_y: float) -> void:
	if state != State.STUFFED:
		return
	_flap_pull = clampf(_flap_pull + maxf(0.0, delta_y), 0.0, FLAP_DRAG)
	var f := _flap_pull / FLAP_DRAG
	# the flap visibly folds over as it is dragged
	_open.scale.y = 1.0
	_open.position.y = -(_open.texture.get_height() - Layout.ENVELOPE_H) * (1.0 - f)
	_open.modulate = Color(1.0, 1.0, 1.0, 1.0 - f * 0.25)
	if _flap_pull >= FLAP_DRAG:
		_open.position.y = -(_open.texture.get_height() - Layout.ENVELOPE_H)
		_open.modulate = Color.WHITE
		set_state(State.CLOSED)
		Audio.play("paper_crease", 1.0, -2.0)
		flap_closed.emit()
		GameEvents.envelope_closed.emit()


func end_flap_pull() -> void:
	if state != State.STUFFED:
		return
	_flap_pull = 0.0
	_open.position.y = -(_open.texture.get_height() - Layout.ENVELOPE_H)
	_open.modulate = Color.WHITE
