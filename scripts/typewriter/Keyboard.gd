extends Node2D
## The four arced rows of keycaps, plus the spacebar.
##
## Purely presentational - it never decides whether a keystroke is legal, it
## just shows the key going down. Watching the right cap dip under your finger
## is most of what makes typing here feel like operating a machine instead of
## filling in a text field, so it also handles the *rejected* case: a key that
## is refused still moves, it just refuses with a shudder.

const PRESS_TIME := 0.075
const REJECT_TIME := 0.16

var _caps: Array[Sprite2D] = []
var _legends: String = ""
var _press_left: PackedFloat32Array = PackedFloat32Array()
var _reject_left: PackedFloat32Array = PackedFloat32Array()
var _home: PackedVector2Array = PackedVector2Array()

var _spacebar: Sprite2D
var _space_press := 0.0
var _space_home := Vector2.ZERO

var _cell := Vector2i(15, 18)


func build(keycap_tex: Texture2D, spacebar_tex: Texture2D) -> void:
	_cell = Vector2i(Layout.KEY_W, Layout.KEY_H + 3)
	for row_index in Layout.KEY_ROWS.size():
		var row: String = Layout.KEY_ROWS[row_index]
		var n := row.length()
		var x0 := Layout.TW_CX - (n * Layout.KEY_SPACING_X) / 2.0
		for i in n:
			var idx := _legends.length()
			_legends += row[i]
			# rows bow downward at their edges, like the real curved deck
			var t := (i - (n - 1) / 2.0) / maxf(1.0, (n - 1) / 2.0)
			var arc := roundi(Layout.KEY_ROW_ARC * t * t)
			var pos := Vector2(
				roundi(x0 + i * Layout.KEY_SPACING_X),
				Layout.KEYBOARD_TOP_Y + row_index * Layout.KEY_SPACING_Y + arc)

			var s := Sprite2D.new()
			s.texture = keycap_tex
			s.centered = false
			s.region_enabled = true
			s.region_rect = Rect2(idx * _cell.x, 0, _cell.x, _cell.y)
			s.position = pos
			add_child(s)
			_caps.append(s)
			_home.append(pos)
			_press_left.append(0.0)
			_reject_left.append(0.0)

	_spacebar = Sprite2D.new()
	_spacebar.texture = spacebar_tex
	_spacebar.centered = false
	_spacebar.region_enabled = true
	_spacebar.region_rect = Rect2(0, 0, Layout.SPACEBAR_W, Layout.SPACEBAR_H)
	_space_home = Vector2(Layout.TW_CX - Layout.SPACEBAR_W / 2.0, Layout.SPACEBAR_Y)
	_spacebar.position = _space_home
	add_child(_spacebar)


func index_of(ch: String) -> int:
	return _legends.find(ch.to_upper())


## Where a key sits on screen - used to point hints at it.
func key_position(ch: String) -> Vector2:
	var i := index_of(ch)
	if i < 0:
		return Vector2(Layout.TW_CX, Layout.KEYBOARD_TOP_Y)
	return _home[i] + Vector2(Layout.KEY_W / 2.0, Layout.KEY_H / 2.0)


func press(ch: String) -> void:
	if ch == " ":
		_space_press = PRESS_TIME
		return
	var i := index_of(ch)
	if i >= 0:
		_press_left[i] = PRESS_TIME


## The key moved but nothing printed - margin locked, or the machine is jammed.
func reject(ch: String) -> void:
	if ch == " ":
		_space_press = PRESS_TIME
		return
	var i := index_of(ch)
	if i >= 0:
		_press_left[i] = PRESS_TIME
		_reject_left[i] = REJECT_TIME


func _process(delta: float) -> void:
	for i in _caps.size():
		var s := _caps[i]
		var down := false
		if _press_left[i] > 0.0:
			_press_left[i] = maxf(0.0, _press_left[i] - delta)
			down = _press_left[i] > 0.0
		s.region_rect = Rect2(i * _cell.x, (_cell.y if down else 0),
							  _cell.x, _cell.y)

		if _reject_left[i] > 0.0:
			_reject_left[i] = maxf(0.0, _reject_left[i] - delta)
			# a refused key judders and flushes warm, which reads as "stuck"
			var f := _reject_left[i] / REJECT_TIME
			s.position = _home[i] + Vector2(sin(_reject_left[i] * 90.0) * 1.5 * f, 0)
			s.modulate = Color(1.0, 1.0 - 0.45 * f, 1.0 - 0.55 * f)
		elif s.position != _home[i] or s.modulate != Color.WHITE:
			s.position = _home[i]
			s.modulate = Color.WHITE

	if _space_press > 0.0:
		_space_press = maxf(0.0, _space_press - delta)
		_spacebar.region_rect = Rect2(
			(Layout.SPACEBAR_W if _space_press > 0.0 else 0), 0,
			Layout.SPACEBAR_W, Layout.SPACEBAR_H)
