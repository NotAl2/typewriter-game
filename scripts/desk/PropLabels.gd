extends Node2D
## Hover captions for the things on the desk.
##
## The desk carries objects the ritual never touches - an inkwell, a quill, a
## journal, a portrait. Players reasonably ask whether those are props or
## controls they have not found yet, and the honest answer differs per object.
## Resting the cursor on one for a moment says which it is, in the voice of
## someone who works at this desk rather than in the voice of a tooltip.
##
## Objects the ritual DOES use are not labelled here - the guide and the
## affordance ring cover those, and a caption on every single thing would turn a
## quiet room into a museum.

const HOVER_DELAY := 0.55
const FADE := 0.16
const PAPER := Color(0.898, 0.855, 0.749, 0.95)
const EDGE := Color(0.42, 0.34, 0.26, 0.85)
const INK := Color(0.145, 0.106, 0.078)
const INK_SOFT := Color(0.42, 0.34, 0.26)

var _font: BitmapText
var _labels: Array[Dictionary] = []
var _hover: Dictionary = {}
var _hover_time := 0.0
var _fade := 0.0
var _mouse := Vector2.ZERO


func build(font: BitmapText) -> void:
	_font = font
	z_index = 30
	_labels = [
		_label(Layout.INKWELL_X, Layout.INKWELL_Y, 30, 30, "inkwell",
			   "For the pen, not the machine.", "Set dressing, for now."),
		_label(Layout.QUILL_X, Layout.QUILL_Y, 54, 40, "quill",
			   "For signing, and for the",
			   "ledger. Set dressing, for now."),
		_label(Layout.JOURNAL_X, Layout.JOURNAL_Y, 66, 26, "day book",
			   "Where the day's jobs are",
			   "entered. Set dressing, for now."),
		_label(Layout.PHOTO_X, Layout.PHOTO_Y, 74, 104, "eleanor, 1879",
			   "Ten years ago now.", ""),
		_label(Layout.PAPER_STACK_X, Layout.PAPER_STACK_Y, 92, 34, "foolscap",
			   "Drag one into the machine.", ""),
		_label(Layout.BIN_X, Layout.BIN_Y, Layout.BIN_W, Layout.BIN_H, "basket",
			   "Crushed paper goes in here.", ""),
		_label(Layout.CANDLE_X, Layout.CANDLE_Y, Layout.CANDLE_W,
			   Layout.CANDLE_H, "candle",
			   "Light to work by, and heat", "for the wax."),
		_label(Layout.WAX_BOX_X, Layout.WAX_BOX_Y, 34, 22, "sealing wax",
			   "Take a stick to the flame.", ""),
	]


func _label(x: int, y: int, w: int, h: int, name: String,
		line_a: String, line_b: String) -> Dictionary:
	var body := PackedStringArray()
	if not line_a.is_empty():
		body.append(line_a)
	if not line_b.is_empty():
		body.append(line_b)
	return {"rect": Rect2(x, y, w, h), "name": name, "body": body}


## Called from DeskScene whenever the cursor moves. `blocked` is true when the
## cursor is already over something the ritual wants - a caption must never
## compete with an interaction.
func update_hover(pos: Vector2, blocked: bool) -> void:
	_mouse = pos
	if blocked:
		_clear()
		return
	for l: Dictionary in _labels:
		if (l["rect"] as Rect2).has_point(pos):
			if _hover.is_empty() or _hover["name"] != l["name"]:
				_hover = l
				_hover_time = 0.0
				_fade = 0.0
			return
	_clear()


func _clear() -> void:
	if not _hover.is_empty():
		_hover = {}
		_hover_time = 0.0


func _process(delta: float) -> void:
	if _hover.is_empty():
		if _fade > 0.0:
			_fade = maxf(0.0, _fade - delta / FADE)
			queue_redraw()
		return
	_hover_time += delta
	if _hover_time >= HOVER_DELAY:
		_fade = minf(1.0, _fade + delta / FADE)
	queue_redraw()


func _draw() -> void:
	if _font == null or _fade <= 0.0 or _hover.is_empty():
		return
	var name := String(_hover["name"])
	var body: PackedStringArray = _hover["body"]

	var w := _font.width_of(name)
	for b in body:
		w = maxi(w, _font.width_of(b))
	w += 14
	var h := (body.size() + 1) * Layout.LINE_H + 9

	# tuck it beside the cursor, and keep it on screen
	var at := _mouse + Vector2(12, 10)
	at.x = clampf(at.x, 4.0, Layout.VIEW_W - w - 4.0)
	at.y = clampf(at.y, 4.0, Layout.VIEW_H - h - 4.0)
	var r := Rect2(at.round(), Vector2(w, h))

	draw_rect(Rect2(r.position + Vector2(2, 2), r.size),
			  Color(0, 0, 0, 0.45 * _fade))
	draw_rect(r, Color(PAPER.r, PAPER.g, PAPER.b, PAPER.a * _fade))
	draw_rect(r, Color(EDGE.r, EDGE.g, EDGE.b, EDGE.a * _fade), false, 1.0)

	_font.draw_text(self, name, r.position + Vector2(7, 5),
					Color(INK.r, INK.g, INK.b, _fade))
	for i in body.size():
		_font.draw_text(self, body[i],
						r.position + Vector2(7, 5 + (i + 1) * Layout.LINE_H),
						Color(INK_SOFT.r, INK_SOFT.g, INK_SOFT.b, _fade))
