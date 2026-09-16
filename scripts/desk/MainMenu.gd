extends Node2D
## The title screen, written on a letter lying on the desk.
##
## A menu drawn as a UI panel sits on top of the fiction. A menu written on a
## sheet of paper IS the fiction: this is a note of engagement from Mr Hallow,
## and the player marks the terms that suit before sitting down to work.
##
## It also settles the contrast problem outright. Cream type over a candlelit
## bookshelf is a losing fight; dark ink on bright paper is the most readable
## surface in the game, and it is the same paper the rest of the game is about.
##
## Keyboard or mouse; both work throughout.

const INK := Color(0.145, 0.106, 0.078)
const INK_SOFT := Color(0.40, 0.32, 0.25)
const INK_FAINT := Color(0.56, 0.48, 0.39)
## A second pen, for the marks a reader makes on a set of terms.
const MARK := Color(0.55, 0.16, 0.15)
const DIM := Color(0.02, 0.012, 0.008, 0.58)
const WASH := Color(0.86, 0.62, 0.30)

const TITLE := "THE CORRESPONDENCE"
const SUBTITLE := "a letter, and what comes back"
const SIT := "S I T   D O W N"

var _font: BitmapText
var _sheet: Texture2D
var _selected := 1
var _rows: Array[Dictionary] = []
var _t := 0.0

signal start_requested(difficulty: int, tutorial: bool)


func build(font: BitmapText) -> void:
	_font = font
	_sheet = load("res://assets/art/menu_letter.png")
	z_index = 90
	_rebuild_rows()
	_selected = _row_for_difficulty(RunState.difficulty)
	set_process_unhandled_input(true)


func _rebuild_rows() -> void:
	_rows.clear()
	var order := [RunState.Difficulty.LENIENT, RunState.Difficulty.STANDARD,
				  RunState.Difficulty.UNFORGIVING]
	var tags := ["two warnings", "one warning", "none at all"]
	for i in order.size():
		var d: int = order[i]
		_rows.append({
			"kind": "difficulty",
			"value": d,
			"label": String(RunState.DIFFICULTY_NAMES[d]),
			"tag": tags[i],
			"blurb": String(RunState.DIFFICULTY_BLURB[d]),
		})
	_rows.append({"kind": "tutorial", "value": 0,
				  "label": "a guide to the machine", "tag": "",
				  "blurb": "it points at each thing in turn"})
	_rows.append({"kind": "start", "value": 0,
				  "label": SIT, "tag": "", "blurb": ""})


func _row_for_difficulty(d: int) -> int:
	for i in _rows.size():
		if String(_rows[i]["kind"]) == "difficulty" and int(_rows[i]["value"]) == d:
			return i
	return 1


func origin() -> Vector2:
	return Vector2(Layout.MENU_LETTER_X, Layout.MENU_LETTER_Y)


## Rows are placed by hand, not on a uniform pitch: the terms want to read as a
## list, and the two actions want air around them.
func _row_local_y(i: int) -> int:
	if i < 3:
		return 98 + i * Layout.MENU_ROW_H
	if i == 3:
		return 150
	return 188


func _row_rect(i: int) -> Rect2:
	return Rect2(origin() + Vector2(Layout.MENU_MARGIN, _row_local_y(i)),
				 Vector2(Layout.MENU_LETTER_W - Layout.MENU_MARGIN * 2,
						 Layout.MENU_ROW_H))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_DOWN or k == KEY_S:
			_move(1)
		elif k == KEY_UP or k == KEY_W:
			_move(-1)
		elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
			_activate(_selected)
		elif k == KEY_LEFT or k == KEY_RIGHT:
			if String(_rows[_selected]["kind"]) == "tutorial":
				_activate(_selected)
		else:
			return
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion:
		var p := (event as InputEventMouseMotion).position
		for i in _rows.size():
			if _row_rect(i).has_point(p):
				if _selected != i:
					_selected = i
					Audio.play("carriage_advance", 1.2, -18.0)
				break
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			for i in _rows.size():
				if _row_rect(i).has_point(mb.position):
					_selected = i
					_activate(i)
					get_viewport().set_input_as_handled()
					return


func _move(d: int) -> void:
	_selected = posmod(_selected + d, _rows.size())
	Audio.play("carriage_advance", 1.1, -16.0)


func _activate(i: int) -> void:
	var row := _rows[i]
	match String(row["kind"]):
		"difficulty":
			RunState.difficulty = int(row["value"])
			Audio.play("platen_ratchet", 1.0, -8.0)
		"tutorial":
			RunState.tutorial_enabled = not RunState.tutorial_enabled
			Audio.play("platen_ratchet", 1.0, -8.0)
		"start":
			Audio.play("bell", 1.0, -10.0)
			start_requested.emit(RunState.difficulty, RunState.tutorial_enabled)


# --------------------------------------------------------------------------

func _centred(text: String, local_y: int, col: Color) -> void:
	var w := _font.width_of(text)
	_font.draw_text(self, text,
					origin() + Vector2(roundf((Layout.MENU_LETTER_W - w) * 0.5),
									   local_y), col)


## A line ruled by hand. It wanders a pixel, because a perfectly straight one
## reads as a UI underline rather than as somebody's pen.
func _pen_rule(from: Vector2, width: float, col: Color) -> void:
	var x := 0.0
	while x < width:
		var seg: float = minf(6.0, width - x)
		var wobble: float = 0.0 if (int(from.x + x) / 7) % 2 == 0 else 1.0
		draw_line(from + Vector2(x, wobble), from + Vector2(x + seg, wobble),
				  col, 1.0)
		x += seg


func _draw() -> void:
	if _font == null:
		return
	draw_rect(Rect2(Vector2.ZERO, Vector2(Layout.VIEW_W, Layout.VIEW_H)), DIM)

	# the sheet, with a shadow so it reads as lying ON the desk
	var o := origin()
	var size := Vector2(Layout.MENU_LETTER_W, Layout.MENU_LETTER_H)
	draw_texture_rect(_sheet, Rect2(o + Vector2(4, 5), size), false,
					  Color(0, 0, 0, 0.5))
	draw_texture(_sheet, o)

	# --- heading ---
	_centred(TITLE, 16, INK)
	_centred(SUBTITLE, 28, INK_FAINT)

	# --- the note ---
	_font.draw_text(self, "Mr Whitlock -",
					o + Vector2(Layout.MENU_MARGIN, 56), INK_SOFT)
	_font.draw_text(self, "Terms of engagement. Mark what",
					o + Vector2(Layout.MENU_MARGIN, 68), INK_SOFT)
	_font.draw_text(self, "suits you, and sit down.",
					o + Vector2(Layout.MENU_MARGIN, 77), INK_SOFT)
	_font.draw_text(self, "HOW MUCH PATIENCE HAVE THEY?",
					o + Vector2(Layout.MENU_MARGIN, 88), INK)

	# --- the terms ---
	for i in _rows.size():
		var row := _rows[i]
		var r := _row_rect(i)
		var on := i == _selected
		var kind := String(row["kind"])
		var label := String(row["label"])
		var chosen := false
		if kind == "difficulty":
			chosen = int(row["value"]) == RunState.difficulty
		elif kind == "tutorial":
			chosen = RunState.tutorial_enabled

		if on:
			# a faint warm wash, so a mouse user can see the hit area at all
			draw_rect(r.grow(1.0),
					  Color(WASH.r, WASH.g, WASH.b,
							0.10 + 0.06 * (0.5 + 0.5 * sin(_t * 3.4))))

		if kind == "start":
			# the last line is not a term, it is the instruction
			_centred(label, _row_local_y(i) + 4, INK if on else INK_SOFT)
			if on:
				var lw := _font.width_of(label)
				_pen_rule(o + Vector2(roundf((Layout.MENU_LETTER_W - lw) * 0.5) - 2,
									  _row_local_y(i) + 13), lw + 4, MARK)
			continue

		var tx: float = r.position.x
		var ty: float = r.position.y + 4
		_font.draw_text(self, "[", Vector2(tx, ty), INK_SOFT)
		_font.draw_text(self, "]", Vector2(tx + 12, ty), INK_SOFT)
		if chosen:
			_font.draw_text(self, "x", Vector2(tx + 6, ty), MARK)

		_font.draw_text(self, label, Vector2(tx + 24, ty),
						INK if (on or chosen) else INK_SOFT)

		var tag := String(row["tag"])
		if not tag.is_empty():
			_font.draw_text(self, tag,
							Vector2(r.end.x - _font.width_of(tag), ty), INK_FAINT)

		if on:
			_pen_rule(Vector2(tx + 22, r.position.y + 13),
					  _font.width_of(label) + 4, MARK)

	# --- what the marked term actually means ---
	var blurb := String(_rows[_selected]["blurb"])
	if blurb.is_empty():
		blurb = "%s - %d letters to set" % [
			RunState.difficulty_name().to_lower(), RunState.LETTERS.size()]
	# directly beneath the terms, so it reads as a note on what you just marked
	# rather than as a description of "sit down"
	_centred(blurb, 170, MARK)

	# --- signature, beside the seal already pressed into the sheet ---
	var sig := "J. Hallow"
	_font.draw_text(self, sig,
					o + Vector2(Layout.MENU_LETTER_W - Layout.MENU_MARGIN
								- _font.width_of(sig), 216), INK_SOFT)
	_centred("arrows / mouse    enter to choose", 234, INK_FAINT)
