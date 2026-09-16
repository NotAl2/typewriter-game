extends Node2D
## The carriage assembly: rail, platen, knobs, return lever, and the sheet.
##
## The carriage is the machine's memory of where you are. It slides one column
## LEFT per keystroke so the next blank column arrives under the fixed strike
## point, which means returning it is a shove to the RIGHT - and that is why the
## lever lives on its left end and the player's drag runs left to right.
##
## The return is a proportional drag, not a button. Push the lever a third of
## the way and the carriage moves a third of the way; let go early and it
## springs back with no line feed. Committing to the full sweep is the gesture.

const ADVANCE_TIME := 0.045          # snap per column while typing
const RETURN_SLAM_TIME := 0.20       # carriage flying home after the drag
const RETURN_COMMIT := 0.72          # fraction of the sweep that counts
const LINE_FEED_AT := 10.0           # px of drag that trips the platen ratchet
const MIN_SWEEP := 34.0              # shortest meaningful return stroke

## How far the sheet must travel past the strike line before the platen lets go.
const GRIP_RELEASE := Layout.SHEET_H

## Absolute ceiling on how far the platen will wind a sheet.
##
## Without this the scroll wheel drives `roll_px` forever, the sheet climbs off
## the top of the screen, and because the pull-it-free hitbox IS the sheet, the
## run softlocks with nothing left to click. The platen simply stops once the
## whole sheet has cleared the grip.
const MAX_PAPER_OFFSET := Layout.SHEET_H + Layout.MAX_PAPER_OVERSHOOT

var col := 0
var rows_advanced := 0
var roll_px := 0.0
var paper_loaded := false
## True once the paper release lever has been thrown: the rollers are lifted and
## the sheet can be drawn straight out regardless of how far it was wound.
var released := false

var _carriage_sprite: Sprite2D
var _platen: Sprite2D
var _paper: Sprite2D
var _knob_l: Sprite2D
var _knob_r: Sprite2D
var _lever: Sprite2D
var _release: Sprite2D

var _knob_frames := 8
var _knob_cell := 26

var _target_x := 0.0
var _slam_from := 0.0
var _slam_t := -1.0

var _lever_home := Vector2.ZERO
var _dragging_lever := false
var _drag_dx := 0.0
var _drag_fed := false
var _spring_t := -1.0
var _spring_from := 0.0

signal return_completed(row: int)
signal line_fed(row: int)
signal ratchet_notch()


func build(carriage_tex: Texture2D, platen_tex: Texture2D, knob_tex: Texture2D,
		lever_tex: Texture2D, release_tex: Texture2D, page_tex: Texture2D) -> void:
	_knob_cell = knob_tex.get_height()
	_knob_frames = maxi(1, knob_tex.get_width() / _knob_cell)

	# Child order IS draw order, and it has to match the real machine: the sheet
	# rests AGAINST the paper table, so the table goes behind it, and the platen
	# goes in front of the sheet's bottom edge. Get this wrong and the line the
	# player just typed disappears behind the carriage.
	_carriage_sprite = Sprite2D.new()
	_carriage_sprite.texture = carriage_tex
	_carriage_sprite.centered = false
	_carriage_sprite.position = Vector2(0, Layout.CARRIAGE_Y)
	add_child(_carriage_sprite)

	_paper = Sprite2D.new()
	_paper.texture = page_tex
	_paper.centered = false
	_paper.region_enabled = true
	_paper.visible = false
	add_child(_paper)

	_platen = Sprite2D.new()
	_platen.texture = platen_tex
	_platen.centered = false
	_platen.position = Vector2(Layout.PLATEN_INSET_X, Layout.PLATEN_Y)
	add_child(_platen)

	_knob_l = _make_knob(knob_tex, -_knob_cell / 2.0 + 4.0)
	_knob_r = _make_knob(knob_tex, Layout.CARRIAGE_W - _knob_cell / 2.0 - 4.0)

	_lever = Sprite2D.new()
	_lever.texture = lever_tex
	_lever.centered = false
	_lever_home = Vector2(Layout.RETURN_LEVER_OX,
						  Layout.CARRIAGE_Y + Layout.RETURN_LEVER_OY)
	_lever.position = _lever_home
	add_child(_lever)

	_release = Sprite2D.new()
	_release.texture = release_tex
	_release.centered = false
	_release.region_enabled = true
	_release.region_rect = Rect2(0, 0, Layout.RELEASE_LEVER_W,
								 Layout.RELEASE_LEVER_H)
	_release.position = Vector2(Layout.RELEASE_LEVER_OX,
								Layout.CARRIAGE_Y + Layout.RELEASE_LEVER_OY)
	add_child(_release)

	set_col(0, false)
	_update_paper()


func _make_knob(tex: Texture2D, x: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, _knob_cell, _knob_cell)
	s.position = Vector2(x, Layout.PLATEN_Y - 2)
	add_child(s)
	return s


# --------------------------------------------------------------------------
# column position
# --------------------------------------------------------------------------

func home_x() -> float:
	return float(Layout.CARRIAGE_HOME_X)


func x_for_col(c: int) -> float:
	return home_x() - c * Layout.CHAR_ADV


func set_col(c: int, animate: bool = true) -> void:
	col = clampi(c, 0, Layout.COLS)
	_target_x = x_for_col(col)
	if not animate:
		position.x = _target_x
	GameEvents.carriage_moved.emit(col)


func is_locked() -> bool:
	return col >= Layout.COLS


func advance() -> void:
	if col < Layout.COLS:
		set_col(col + 1)


## Move back one column WITHOUT printing - the real backspace. It is what lets a
## typist run the carriage back and strike an x over a mistake.
func back_space() -> bool:
	if col <= 0:
		return false
	set_col(col - 1)
	return true


# --------------------------------------------------------------------------
# the return lever
# --------------------------------------------------------------------------

func lever_rect() -> Rect2:
	var pad := 4.0 + Settings.drag_assist
	return Rect2(position.x + _lever.position.x - pad,
				 _lever.position.y - pad,
				 Layout.RETURN_LEVER_W + pad * 2.0,
				 Layout.RETURN_LEVER_H + pad * 2.0)


func sweep_distance() -> float:
	## How far right the carriage has to travel to get home from here.
	##
	## Floored at MIN_SWEEP so a return from the left margin is still a real
	## gesture rather than a twitch. A typist absolutely can throw the carriage
	## with nothing typed on the line - that is how you get a blank line - so
	## refusing the stroke at column zero would make blank lines impossible and
	## most documents untypeable.
	return maxf(MIN_SWEEP, home_x() - x_for_col(col))


func begin_return_drag() -> bool:
	if _dragging_lever or _slam_t >= 0.0:
		return false
	_dragging_lever = true
	_drag_dx = 0.0
	_drag_fed = false
	_spring_t = -1.0
	return true


func update_return_drag(dx: float) -> void:
	if not _dragging_lever:
		return
	var sweep := sweep_distance()
	_drag_dx = clampf(_drag_dx + dx, 0.0, sweep)

	# the first part of the stroke trips the line-feed ratchet, as it does on
	# the real machine, before any carriage travel happens
	if not _drag_fed and _drag_dx >= LINE_FEED_AT:
		_drag_fed = true
		feed_line()

	var travel: float = maxf(0.0, _drag_dx - LINE_FEED_AT)
	position.x = minf(home_x(), x_for_col(col) + travel)
	_lever.position.x = _lever_home.x + minf(travel * 0.35, 16.0)


func end_return_drag() -> bool:
	if not _dragging_lever:
		return false
	_dragging_lever = false
	_lever.position = _lever_home
	var sweep := maxf(1.0, sweep_distance())
	var progress: float = maxf(0.0, _drag_dx - LINE_FEED_AT) / sweep
	if progress >= RETURN_COMMIT:
		_finish_return()
		return true
	# not committed: fall back to where the line was, keeping any line feed
	_spring_from = position.x
	_spring_t = 0.0
	return false


## Complete the return outright - the accessibility path bound to Enter.
func assisted_return() -> void:
	if not _drag_fed:
		feed_line()
	_slam_from = position.x
	_slam_t = 0.0
	_finish_return()


func _finish_return() -> void:
	_slam_from = position.x
	_slam_t = 0.0
	set_col(0, true)
	_drag_fed = false
	return_completed.emit(rows_advanced)


func feed_line() -> void:
	rows_advanced += 1
	_update_paper()
	line_fed.emit(rows_advanced)
	GameEvents.line_fed.emit(rows_advanced)


# --------------------------------------------------------------------------
# paper
# --------------------------------------------------------------------------

func load_paper() -> void:
	paper_loaded = true
	rows_advanced = 0
	roll_px = 0.0
	released = false
	_paper.visible = true
	_set_release_frame()
	_update_paper()
	GameEvents.paper_loaded.emit()


func release_paper() -> void:
	paper_loaded = false
	released = false
	_paper.visible = false
	rows_advanced = 0
	roll_px = 0.0
	_set_release_frame()
	_update_paper()


# --------------------------------------------------------------------------
# the paper release
# --------------------------------------------------------------------------

## Screen rect of the release lever.
func release_rect() -> Rect2:
	var pad := 6.0 + Settings.drag_assist
	return Rect2(position.x + _release.position.x - pad,
				 _release.position.y - pad,
				 Layout.RELEASE_LEVER_W + pad * 2.0,
				 Layout.RELEASE_LEVER_H + pad * 2.0)


## Throw the release. The rollers lift off the platen and the sheet is free
## immediately - no winding required. Returns false if there is nothing in the
## machine or it is already thrown.
func throw_release() -> bool:
	if not paper_loaded or released:
		return false
	released = true
	_set_release_frame()
	Audio.play("platen_ratchet", 0.7, -2.0)
	Audio.play("paper_rustle", 1.0, -8.0)
	GameEvents.paper_released.emit()
	return true


func _set_release_frame() -> void:
	if _release == null:
		return
	_release.region_rect = Rect2(
		(Layout.RELEASE_LEVER_W if released else 0), 0,
		Layout.RELEASE_LEVER_W, Layout.RELEASE_LEVER_H)


## How far the top edge of the sheet has travelled above the strike line.
func paper_offset() -> float:
	return Layout.PAGE_MARGIN_TOP + rows_advanced * Layout.LINE_H + roll_px


## True once the sheet can be pulled out without tearing - either because it has
## been wound clear of the grip, or because the release lever has been thrown.
func paper_free_of_grip() -> bool:
	return released or paper_offset() >= GRIP_RELEASE


## True when the platen will wind no further. The affordance layer uses this to
## stop pointing at the knob and start pointing at the sheet.
func fully_wound() -> bool:
	return paper_offset() >= MAX_PAPER_OFFSET - 0.5


func roll(px: float) -> void:
	if not paper_loaded:
		return
	var before := int(roll_px / Layout.LINE_H)
	# Clamped at BOTH ends. The lower bound stops the sheet reversing into the
	# machine; the upper bound is what keeps the wheel from scrolling the page
	# off the top of the screen and stranding the player with nothing to click.
	var max_roll: float = maxf(0.0, MAX_PAPER_OFFSET
		- Layout.PAGE_MARGIN_TOP - rows_advanced * Layout.LINE_H)
	roll_px = clampf(roll_px + px, 0.0, max_roll)
	_update_paper()
	if int(roll_px / Layout.LINE_H) != before:
		ratchet_notch.emit()
		GameEvents.paper_rolled.emit(1)


func knob_rect(right_side: bool) -> Rect2:
	var pad := 3.0 + Settings.drag_assist
	var s := _knob_r if right_side else _knob_l
	return Rect2(position.x + s.position.x - pad, s.position.y - pad,
				 _knob_cell + pad * 2.0, _knob_cell + pad * 2.0)


func _update_paper() -> void:
	if not paper_loaded:
		return
	var off := paper_offset()
	var vh: float = clampf(off, 1.0, float(Layout.SHEET_H))
	_paper.region_rect = Rect2(0, 0, Layout.SHEET_W, vh)
	_paper.position = Vector2(
		roundf((Layout.CARRIAGE_W - Layout.SHEET_W) / 2.0),
		roundf(Layout.STRIKE_Y - off))

	var frame := int(off / 3.0) % _knob_frames
	var region := Rect2(frame * _knob_cell, 0, _knob_cell, _knob_cell)
	_knob_l.region_rect = region
	_knob_r.region_rect = region


## Screen position of the cell currently under the typebars.
func strike_point() -> Vector2:
	return Vector2(Layout.STRIKE_X, Layout.STRIKE_Y)


func _process(delta: float) -> void:
	if _slam_t >= 0.0:
		_slam_t += delta
		var t: float = clampf(_slam_t / RETURN_SLAM_TIME, 0.0, 1.0)
		# fast out, hard stop - the carriage arrives, it does not glide in
		position.x = lerpf(_slam_from, _target_x, 1.0 - pow(1.0 - t, 3.0))
		if t >= 1.0:
			_slam_t = -1.0
			position.x = _target_x
	elif _spring_t >= 0.0:
		_spring_t += delta
		var t2: float = clampf(_spring_t / 0.14, 0.0, 1.0)
		position.x = lerpf(_spring_from, _target_x, t2)
		if t2 >= 1.0:
			_spring_t = -1.0
	elif not _dragging_lever and not is_equal_approx(position.x, _target_x):
		var step := (Layout.CHAR_ADV / ADVANCE_TIME) * delta
		position.x = move_toward(position.x, _target_x, step)
