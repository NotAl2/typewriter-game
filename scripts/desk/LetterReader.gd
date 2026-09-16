extends Node2D
## Full-frame reading of a letter that arrived in the post.
##
## Replies are read, never typed, so they get their own beat: the desk dims, the
## letter comes up, and the player has to actually read it before they can carry
## on. That matters most for the rage letter — the failure state is a piece of
## writing, and cutting straight to a game-over card would throw it away.
##
## Scrolls if the letter is longer than the sheet. Dismissed with a click or a
## key, but not before it has had a moment to settle.

const MARGIN_X := 16
const MARGIN_TOP := 14
const FADE_IN := 0.5
const MIN_READ_TIME := 0.9           # can't be clicked away instantly

const INK := Color(0.165, 0.122, 0.094)
const INK_RAGE := Color(0.36, 0.09, 0.09)
const DIM := Color(0.02, 0.012, 0.008, 0.78)

var document: DocumentData
var tone := 0

var _font: BitmapText
var _sheet_tex: Texture2D
var _t := 0.0
var _scroll := 0
var _rows := 0
var _sheet_pos := Vector2.ZERO
var _sheet_size := Vector2.ZERO
var _dismissable := false

signal dismissed()


func build(font: BitmapText, doc: DocumentData, letter_tone: int) -> void:
	_font = font
	document = doc
	tone = letter_tone
	z_index = 60

	# The sheet is drawn inside _draw() rather than being a child sprite: a child
	# would render BEFORE this node's own drawing, which put it underneath the
	# screen-dimming rect and made the letter unreadable.
	_sheet_tex = load("res://assets/art/reading_sheet.png")
	_sheet_size = _sheet_tex.get_size()
	_sheet_pos = ((Vector2(Layout.VIEW_W, Layout.VIEW_H) - _sheet_size) * 0.5).round()

	_rows = int((_sheet_size.y - MARGIN_TOP * 2) / Layout.LINE_H)
	Audio.play("paper_slide", 0.95, -3.0)


func can_scroll() -> bool:
	return document != null and document.line_count() > _rows


func scroll_by(lines: int) -> void:
	if not can_scroll():
		return
	var max_scroll: int = document.line_count() - _rows
	var before := _scroll
	_scroll = clampi(_scroll + lines, 0, max_scroll)
	if _scroll != before:
		Audio.play("paper_rustle", 1.1, -14.0)
		queue_redraw()


func at_end() -> bool:
	if not can_scroll():
		return true
	return _scroll >= document.line_count() - _rows


## Click / key. Scrolls if there is more to read, dismisses at the end.
func advance() -> bool:
	if not _dismissable:
		return false
	if not at_end():
		scroll_by(_rows - 2)
		return false
	dismissed.emit()
	return true


func _process(delta: float) -> void:
	_t += delta
	if not _dismissable and _t >= MIN_READ_TIME:
		_dismissable = true
	queue_redraw()


func _draw() -> void:
	if _font == null or document == null:
		return
	var a: float = clampf(_t / FADE_IN, 0.0, 1.0)

	# darken the desk behind the letter, then lay the letter on top of it
	draw_rect(Rect2(Vector2.ZERO, Vector2(Layout.VIEW_W, Layout.VIEW_H)),
			  Color(DIM.r, DIM.g, DIM.b, DIM.a * a))

	var sheet_at := _sheet_pos + Vector2(0, (1.0 - a) * 8.0)
	draw_texture_rect(_sheet_tex, Rect2(sheet_at + Vector2(3, 4), _sheet_size),
					  false, Color(0, 0, 0, 0.45 * a))
	draw_texture(_sheet_tex, sheet_at, Color(1, 1, 1, a))

	var ink := INK_RAGE if tone >= RunState.Tone.RAGE else INK
	var origin := sheet_at + Vector2(MARGIN_X, MARGIN_TOP)
	for i in _rows:
		var row := _scroll + i
		if row >= document.line_count():
			break
		var text := document.line(row)
		if text.is_empty():
			continue
		var col := Color(ink.r, ink.g, ink.b, a)
		# the rage letter is written with a pen pressed hard enough to tear
		if tone >= RunState.Tone.RAGE and text == text.to_upper() \
				and text.strip_edges().length() > 2:
			col = Color(INK_RAGE.r, INK_RAGE.g, INK_RAGE.b, a)
		for c in text.length():
			var jy := 0
			# "unsteady hand" effect removed for uniform readability
			_font.draw_glyph(self, text[c],
							 origin + Vector2(c * Layout.CHAR_ADV,
											  i * Layout.LINE_H + jy), col)

	if _dismissable:
		var prompt := "click to read on" if not at_end() else "click to set it down"
		var w := _font.width_of(prompt)
		var pulse: float = 0.45 + 0.3 * (0.5 + 0.5 * sin(_t * 3.0))
		# the prompt lands over the machine, so it needs its own ground
		draw_rect(Rect2((Layout.VIEW_W - w) * 0.5 - 6,
						sheet_at.y + _sheet_size.y + 4, w + 12, 13),
				  Color(0.02, 0.012, 0.008, 0.7 * a))
		_font.draw_text(self, prompt,
						Vector2((Layout.VIEW_W - w) * 0.5,
								sheet_at.y + _sheet_size.y + 8),
						Color(0.95, 0.90, 0.80, pulse * a))
