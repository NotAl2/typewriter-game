extends Node2D
## The verdict on a finished letter, on a small slip of paper.
##
## Deliberately understated: this is a day's work being totted up in a ledger,
## not a score screen. It fades in, it can be dismissed, and it never blocks the
## desk behind it.

const PAPER := Color(0.910, 0.863, 0.753, 1.0)
const EDGE := Color(0.42, 0.34, 0.26, 0.9)
const INK := Color(0.165, 0.122, 0.094)
const FADE_IN := 0.55

const MIN_SHOW := 0.8                # cannot be clicked away instantly

var _font: BitmapText
var _lines: PackedStringArray
var _t := 0.0
var _rect := Rect2()
var _gone := false

signal dismissed()


func setup(font: BitmapText, lines: PackedStringArray) -> void:
	_font = font
	_lines = lines
	var w := 0
	for l in _lines:
		w = maxi(w, _font.width_of(l))
	var h := _lines.size() * (Layout.LINE_H + 1) + 18
	_rect = Rect2(roundf((Layout.VIEW_W - w - 24) * 0.5),
				  roundf((Layout.VIEW_H - h) * 0.5) - 12.0,
				  w + 24, h)
	z_index = 50


func dismiss() -> void:
	if _gone or _t < MIN_SHOW:
		return
	_gone = true
	dismissed.emit()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if _font == null:
		return
	var a: float = clampf(_t / FADE_IN, 0.0, 1.0)
	var slide := (1.0 - a) * 6.0
	var r := Rect2(_rect.position + Vector2(0, slide), _rect.size)

	draw_rect(Rect2(r.position + Vector2(3, 4), r.size),
			  Color(0, 0, 0, 0.55 * a))
	draw_rect(r, Color(PAPER.r, PAPER.g, PAPER.b, PAPER.a * a))
	draw_rect(r, Color(EDGE.r, EDGE.g, EDGE.b, EDGE.a * a), false, 1.0)

	for i in _lines.size():
		var col := Color(INK.r, INK.g, INK.b, a)
		if i == 0:
			col = Color(INK.r, INK.g, INK.b, a)
		_font.draw_text(self, _lines[i],
						r.position + Vector2(12, 9 + i * (Layout.LINE_H + 1)),
						col)
	if _t >= MIN_SHOW:
		var pulse: float = 0.4 + 0.35 * (0.5 + 0.5 * sin(_t * 2.6))
		_font.draw_text(self, "the post has come. click to read it",
						r.position + Vector2(12, r.size.y - 11),
						Color(INK.r, INK.g, INK.b, pulse))
