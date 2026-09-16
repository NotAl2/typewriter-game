extends Node2D
## The letter being transcribed, lying on the desk and genuinely readable.
##
## The text is drawn straight onto the prop rather than into a floating panel,
## which is the whole reason the sheet is sized to hold exactly one machine line
## across. Per-glyph jitter and a slightly uneven baseline make it read as
## something a person wrote rather than something a UI printed.
##
## The line the player is currently typing is lit; lines already done fade back.
## Hold the mouse on it and it lifts toward the reader, because squinting at a
## desk prop should be solvable by picking it up.

const INK := Color(0.165, 0.122, 0.094)
const INK_DONE := Color(0.42, 0.34, 0.26)
const INK_ACTIVE := Color(0.10, 0.07, 0.05)
const HIGHLIGHT := Color(1.0, 0.93, 0.75, 0.16)

const LIFT_TIME := 0.18

var document: DocumentData
var current_row := 0

var _font: BitmapText
var _sprite: Sprite2D
var _big: Sprite2D
var _scroll := 0
var _lift := 0.0
var _lifting := false
var _jitter: PackedInt32Array = PackedInt32Array()


func build(font: BitmapText, doc: DocumentData) -> void:
	_font = font
	document = doc
	position = Vector2(Layout.SOURCE_LETTER_X, Layout.SOURCE_LETTER_Y)

	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/art/source_letter.png")
	_sprite.centered = false
	# child sprites draw ON TOP of their parent's own _draw(), so the stock has
	# to be pushed behind or it buries every word written on it
	_sprite.show_behind_parent = true
	add_child(_sprite)

	_big = Sprite2D.new()
	_big.texture = load("res://assets/art/reading_sheet.png")
	_big.centered = false
	_big.visible = false
	_big.show_behind_parent = true
	add_child(_big)

	# a fixed per-character wobble removed to ensure uniform, readable text
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x10FE
	for i in 512:
		_jitter.append(0)
	queue_redraw()


func rect() -> Rect2:
	return Rect2(position, Vector2(Layout.SOURCE_LETTER_W, Layout.SOURCE_LETTER_H))


func set_current_row(row: int) -> void:
	if row == current_row:
		return
	current_row = row
	# keep the active line inside the visible window, a page at a time
	var rows := Layout.SOURCE_LETTER_ROWS
	if current_row < _scroll:
		_scroll = current_row
	elif current_row > _scroll + rows - 2:
		_scroll = current_row - rows + 2
	_scroll = maxi(0, _scroll)
	queue_redraw()


func set_lifted(on: bool) -> void:
	_lifting = on


func _process(delta: float) -> void:
	var want := 1.0 if _lifting else 0.0
	if not is_equal_approx(_lift, want):
		_lift = move_toward(_lift, want, delta / LIFT_TIME)
		var big := _lift > 0.5
		_sprite.visible = not big
		_big.visible = big
		scale = Vector2.ONE * (1.0 + _lift * 0.02)
		# lift it toward the middle of the desk as it is raised
		position = Vector2(Layout.SOURCE_LETTER_X, Layout.SOURCE_LETTER_Y).lerp(
			Vector2(Layout.VIEW_W * 0.5 - Layout.SOURCE_LETTER_W,
					Layout.VIEW_H * 0.5 - Layout.SOURCE_LETTER_H * 0.9), _lift)
		queue_redraw()


func _draw() -> void:
	if _font == null or document == null:
		return
	var big := _lift > 0.5
	var s := 2 if big else 1
	var m := Layout.SOURCE_LETTER_MARGIN * s
	var line_h := Layout.LINE_H * s
	var rows := Layout.SOURCE_LETTER_ROWS

	for i in rows:
		var row := _scroll + i
		if row >= document.line_count():
			break
		var text := document.line(row)
		var y := m + i * line_h + 4 * s
		var col := INK
		if row < current_row:
			col = INK_DONE
		elif row == current_row:
			col = INK_ACTIVE
			draw_rect(Rect2(m - 2 * s, y - 1 * s,
							Layout.COLS * Layout.CHAR_ADV * s + 4 * s,
							(Layout.LINE_H - 1) * s), HIGHLIGHT)
		if text.is_empty():
			continue
		for c in text.length():
			var jx := _jitter[(row * 31 + c) % _jitter.size()]
			var jy := _jitter[(row * 17 + c * 7 + 3) % _jitter.size()]
			var p := Vector2(m + c * Layout.CHAR_ADV * s + jx,
							 y + jy)
			if big:
				_draw_glyph_scaled(text[c], p, col, s)
			else:
				_font.draw_glyph(self, text[c], p, col)

	# who it is from, in the corner, always visible
	if not document.sender.is_empty() and not big:
		_font.draw_glyph(self, "-", Vector2(m, Layout.SOURCE_LETTER_H - 12),
						 INK_DONE)


func _draw_glyph_scaled(ch: String, pos: Vector2, color: Color, s: int) -> void:
	if ch == " " or not _font.has_char(ch):
		return
	draw_texture_rect_region(_font.texture,
		Rect2(pos.round(), Vector2(_font.glyph_w * s, _font.glyph_h * s)),
		_font.region_of(ch), color)
