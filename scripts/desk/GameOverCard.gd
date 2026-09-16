extends Node2D
## Notice of dismissal. The run is over.
##
## Styled as a printed legal notice rather than a game-over screen, because the
## fiction is that a man wrote to your employer, not that you lost. It arrives
## slowly, with the desk gone black behind it.

const FADE := 1.1
const INK := Color(0.16, 0.12, 0.09)
const PAPER := Color(0.878, 0.835, 0.729)
const RULE := Color(0.42, 0.34, 0.26)

var _font: BitmapText
var _t := 0.0
var _lines: PackedStringArray
var _rect := Rect2()

signal restart_requested()


func build(font: BitmapText, run) -> void:
	_font = font
	z_index = 80

	var sent: int = run.history.size()
	_lines = PackedStringArray([
		"NOTICE OF DISMISSAL",
		"",
		"The services of the undersigned",
		"typewriter are no longer",
		"required at this office.",
		"",
		"Letters set:   %d" % sent,
		"Difficulty:    %s" % run.difficulty_name().to_lower(),
		"",
		"A. WHITLOCK",
	])

	var w := 0
	for l in _lines:
		w = maxi(w, _font.width_of(l))
	var h := _lines.size() * (Layout.LINE_H + 1) + 40
	_rect = Rect2(roundf((Layout.VIEW_W - w - 40) * 0.5),
				  roundf((Layout.VIEW_H - h) * 0.5),
				  w + 40, h)
	Audio.play("carriage_return", 0.55, -4.0)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _t < FADE:
		return
	if (event is InputEventKey and event.pressed) \
			or (event is InputEventMouseButton and event.pressed):
		restart_requested.emit()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if _font == null:
		return
	var a: float = clampf(_t / FADE, 0.0, 1.0)

	draw_rect(Rect2(Vector2.ZERO, Vector2(Layout.VIEW_W, Layout.VIEW_H)),
			  Color(0.02, 0.012, 0.008, a))

	var card_a: float = clampf((_t - FADE * 0.4) / FADE, 0.0, 1.0)
	if card_a <= 0.0:
		return
	draw_rect(Rect2(_rect.position + Vector2(3, 4), _rect.size),
			  Color(0, 0, 0, 0.6 * card_a))
	draw_rect(_rect, Color(PAPER.r, PAPER.g, PAPER.b, card_a))
	draw_rect(_rect, Color(RULE.r, RULE.g, RULE.b, card_a), false, 1.0)
	draw_rect(_rect.grow(-4), Color(RULE.r, RULE.g, RULE.b, 0.55 * card_a),
			  false, 1.0)

	for i in _lines.size():
		var text := _lines[i]
		if text.is_empty():
			continue
		var x := _rect.position.x + 20
		if i == 0:
			x = _rect.position.x + (_rect.size.x - _font.width_of(text)) * 0.5
		_font.draw_text(self, text,
						Vector2(x, _rect.position.y + 20 + i * (Layout.LINE_H + 1)),
						Color(INK.r, INK.g, INK.b, card_a))
	# rule under the heading
	draw_line(_rect.position + Vector2(20, 20 + Layout.LINE_H + 2),
			  _rect.position + Vector2(_rect.size.x - 20, 20 + Layout.LINE_H + 2),
			  Color(RULE.r, RULE.g, RULE.b, card_a), 1.0)

	if _t >= FADE:
		var prompt := "press any key to begin again"
		var w := _font.width_of(prompt)
		var pulse: float = 0.4 + 0.35 * (0.5 + 0.5 * sin(_t * 2.4))
		_font.draw_text(self, prompt,
						Vector2((Layout.VIEW_W - w) * 0.5,
								_rect.end.y + 14),
						Color(0.85, 0.80, 0.72, pulse))
