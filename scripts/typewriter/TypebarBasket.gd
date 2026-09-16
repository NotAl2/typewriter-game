extends Node2D
## The fan of typebars, the one that swings up on a strike, and the two that
## cross when the machine jams.
##
## The jam is a physical object on screen, not a status message: two bars locked
## against the platen that the player has to reach in and pull apart. The drag
## resists a little before it gives, because a jam that clears on a tap is not
## worth having.

const SWING_UP := 0.045              # seconds from rest to struck
const SWING_DOWN := 0.085            # and falling back
const JAM_PULL_DISTANCE := 14.0      # px the player must drag to free the bars

var _fan: Sprite2D
var _striker: Sprite2D
var _jam: Sprite2D

var _frame_size := 0
var _jam_size := 0
var _swing_t := 0.0
var _swinging := false

var _jam_grab := false
var _jam_pull := 0.0
var _jam_home := Vector2.ZERO

signal jam_freed


func build(fan_tex: Texture2D, swing_tex: Texture2D, jam_tex: Texture2D) -> void:
	_frame_size = swing_tex.get_height()

	_fan = Sprite2D.new()
	_fan.texture = fan_tex
	_fan.centered = false
	_fan.position = Vector2(Layout.BASKET_CX - Layout.BASKET_W / 2.0,
							Layout.BASKET_PIVOT_Y - Layout.BASKET_H)
	add_child(_fan)

	_striker = Sprite2D.new()
	_striker.texture = swing_tex
	_striker.centered = false
	_striker.region_enabled = true
	_striker.region_rect = Rect2(0, 0, _frame_size, _frame_size)
	_striker.position = Vector2(Layout.BASKET_CX - _frame_size / 2.0,
								Layout.BASKET_PIVOT_Y - _frame_size / 2.0)
	_striker.visible = false
	add_child(_striker)

	_jam = Sprite2D.new()
	_jam.texture = jam_tex
	_jam.centered = false
	_jam_size = jam_tex.get_width()
	_jam_home = Vector2(Layout.BASKET_CX - jam_tex.get_width() / 2.0,
						Layout.BASKET_PIVOT_Y - jam_tex.get_height() / 2.0)
	_jam.position = _jam_home
	_jam.visible = false
	add_child(_jam)


## Swing one bar up and let it fall back.
func strike() -> void:
	_swinging = true
	_swing_t = 0.0
	_striker.visible = true


func show_jam(_bar_a: int, _bar_b: int) -> void:
	_swinging = false
	_striker.visible = false
	# push the resting fan back into shadow so the locked pair is unmistakably
	# the thing that is wrong
	_fan.modulate = Color(0.42, 0.40, 0.38)
	_jam.visible = true
	_jam_pull = 0.0
	_jam.position = _jam_home
	_jam.modulate = Color.WHITE


func hide_jam() -> void:
	_fan.modulate = Color.WHITE
	_jam.visible = false
	_jam_grab = false
	_jam_pull = 0.0
	_jam.position = _jam_home


func is_jam_visible() -> bool:
	return _jam.visible


## Screen-space rect the player has to grab to start clearing a jam.
func jam_rect() -> Rect2:
	var pad := Settings.drag_assist
	# only the upper half of the frame holds the crossed bars, and only the part
	# above the machine's notch is actually on screen for the player to grab
	return Rect2(_jam_home.x + _jam_size * 0.30 - pad,
				 _jam_home.y + _jam_size * 0.10 - pad,
				 _jam_size * 0.40 + pad * 2.0,
				 _jam_size * 0.42 + pad * 2.0)


func begin_jam_pull() -> void:
	_jam_grab = true
	_jam_pull = 0.0


## Feed the drag delta in. Bars come free once pulled far enough downward.
func update_jam_pull(delta_y: float) -> void:
	if not _jam_grab:
		return
	# only downward drag counts, and the bars resist as they bind
	_jam_pull = clampf(_jam_pull + maxf(0.0, delta_y) * 0.85, 0.0,
					   JAM_PULL_DISTANCE)
	var f := _jam_pull / JAM_PULL_DISTANCE
	_jam.position = _jam_home + Vector2(sin(_jam_pull * 2.4) * 1.2, f * 5.0)
	_jam.modulate = Color(1.0, 1.0 - 0.15 * f, 1.0 - 0.2 * f)
	if _jam_pull >= JAM_PULL_DISTANCE:
		_jam_grab = false
		hide_jam()
		jam_freed.emit()


func end_jam_pull() -> void:
	if not _jam_grab:
		return
	_jam_grab = false
	_jam_pull = 0.0
	_jam.position = _jam_home
	_jam.modulate = Color.WHITE


func _process(delta: float) -> void:
	if not _swinging:
		return
	_swing_t += delta
	var frames := Layout.TYPEBAR_FRAMES
	var f := 0
	if _swing_t <= SWING_UP:
		f = int((_swing_t / SWING_UP) * (frames - 1))
	elif _swing_t <= SWING_UP + SWING_DOWN:
		var d := (_swing_t - SWING_UP) / SWING_DOWN
		f = int((1.0 - d) * (frames - 1))
	else:
		_swinging = false
		_striker.visible = false
		return
	f = clampi(f, 0, frames - 1)
	_striker.region_rect = Rect2(f * _frame_size, 0, _frame_size, _frame_size)
