extends Node2D
## A ruined page: crumple it in your fist, then throw it at the basket.
##
## Every failure in the ritual produces one of these - a torn sheet, a page you
## ejected half-typed, a letter you decided was not good enough to send. Giving
## waste a physical destination matters more than it sounds: it turns "I made a
## mistake" from a message into an object you have to deal with, and binning it
## is a small, satisfying full stop before you start again.
##
## Two beats:
##   1. CRUSH  - hold the mouse down on the sheet. It crumples frame by frame
##               under the pressure, with paper noise, until it is a ball.
##   2. THROW  - drag the ball and let go. It flies on a real arc, and either
##               drops into the basket or bounces off the rim onto the desk,
##               where you can pick it up and try again.

enum State { SHEET, CRUSHING, BALL, FLYING, BINNED }

const CRUSH_TIME := 0.62             # seconds of holding to fully crumple
const THROW_GRAVITY := 900.0
const THROW_SPIN := 7.0
## Minimum flick speed for a throw; below this it is just a drop.
const THROW_MIN_SPEED := 90.0
const AIM_ASSIST := 26.0             # px of forgiveness on the basket mouth

var state: int = State.SHEET
var reason := ""

var _page: Sprite2D                  # the sheet, before crumpling
var _ball: Sprite2D
var _ball_frames := 4
var _crush := 0.0
var _carry := false
var _vel := Vector2.ZERO
var _spin := 0.0
var _bin_mouth := Vector2.ZERO
var _rest := Vector2.ZERO
var _prev_pos := Vector2.ZERO
var _prev_dt := 1.0 / 60.0

signal crumpled()
signal landed(went_in: bool)


func build(page_texture: Texture2D, at: Vector2, bin_mouth: Vector2,
		why: String) -> void:
	reason = why
	_bin_mouth = bin_mouth
	_rest = at
	position = at

	_page = Sprite2D.new()
	_page.texture = page_texture
	_page.centered = false
	_page.region_enabled = true
	_page.region_rect = Rect2(0, 0, Layout.SHEET_W, Layout.SHEET_H)
	add_child(_page)

	var ball_tex: Texture2D = load("res://assets/art/paper_ball.png")
	_ball_frames = maxi(1, ball_tex.get_width() / Layout.PAPER_BALL_W)
	_ball = Sprite2D.new()
	_ball.texture = ball_tex
	_ball.centered = true
	_ball.region_enabled = true
	_ball.region_rect = Rect2(0, 0, Layout.PAPER_BALL_W, Layout.PAPER_BALL_H)
	_ball.visible = false
	add_child(_ball)


# --------------------------------------------------------------------------
# hit areas
# --------------------------------------------------------------------------

func rect() -> Rect2:
	var pad := 4.0 + Settings.drag_assist
	if state == State.SHEET or state == State.CRUSHING:
		return Rect2(position - Vector2(pad, pad),
					 Vector2(Layout.SHEET_W, Layout.SHEET_H)
					 + Vector2(pad, pad) * 2.0)
	return Rect2(position - Vector2(Layout.PAPER_BALL_W * 0.5 + pad,
									Layout.PAPER_BALL_H * 0.5 + pad),
				 Vector2(Layout.PAPER_BALL_W, Layout.PAPER_BALL_H)
				 + Vector2(pad, pad) * 2.0)


func is_ball() -> bool:
	return state == State.BALL


func is_done() -> bool:
	return state == State.BINNED


# --------------------------------------------------------------------------
# 1. crushing
# --------------------------------------------------------------------------

func begin_crush() -> void:
	if state == State.SHEET:
		state = State.CRUSHING
		_crush = 0.0


## Called every frame while the player holds the sheet down.
func hold_crush(delta: float) -> void:
	if state != State.CRUSHING:
		return
	var was := _crush_frame()
	_crush = minf(1.0, _crush + delta / CRUSH_TIME)
	var now := _crush_frame()
	if now != was:
		Audio.play("paper_crease", 1.0 + now * 0.10, -4.0 + now * 2.0)
		GameEvents.shake_requested.emit(0.4 + now * 0.2)
	_apply_crush()
	if _crush >= 1.0:
		_finish_crush()


func release_crush() -> void:
	## Letting go early relaxes the paper - you have to mean it.
	if state != State.CRUSHING:
		return
	if _crush < 1.0:
		state = State.SHEET
		_crush = 0.0
		_apply_crush()


func _crush_frame() -> int:
	return clampi(int(_crush * _ball_frames), 0, _ball_frames - 1)


func _apply_crush() -> void:
	if _crush <= 0.0:
		_page.visible = true
		_ball.visible = false
		_page.scale = Vector2.ONE
		return
	# the sheet shrinks toward the fist while the ball fades up under it
	_page.visible = _crush < 0.45
	_page.scale = Vector2.ONE * (1.0 - _crush * 0.5)
	_ball.visible = _crush >= 0.45
	_ball.region_rect = Rect2(_crush_frame() * Layout.PAPER_BALL_W, 0,
							  Layout.PAPER_BALL_W, Layout.PAPER_BALL_H)
	_ball.position = Vector2(Layout.SHEET_W, Layout.SHEET_H) * 0.5 \
		* (1.0 - _crush) if _crush < 1.0 else Vector2.ZERO


func _finish_crush() -> void:
	state = State.BALL
	# from here the node's own position IS the ball's centre
	position += Vector2(Layout.SHEET_W, Layout.SHEET_H) * 0.5 * 0.5
	_page.visible = false
	_ball.visible = true
	_ball.position = Vector2.ZERO
	_ball.region_rect = Rect2((_ball_frames - 1) * Layout.PAPER_BALL_W, 0,
							  Layout.PAPER_BALL_W, Layout.PAPER_BALL_H)
	Audio.play("paper_rustle", 0.8, -1.0)
	crumpled.emit()
	GameEvents.paper_crumpled.emit()

	# It drops out of your fist onto the desk rather than hovering wherever the
	# sheet happened to be - a ball resting in mid-air on the machine's
	# nameplate reads as a bug.
	state = State.FLYING
	_vel = Vector2(randf_range(-18.0, 18.0), 10.0)
	_spin = randf_range(-2.0, 2.0)


# --------------------------------------------------------------------------
# 2. throwing
# --------------------------------------------------------------------------

func grab_ball() -> void:
	if state != State.BALL:
		return
	_carry = true
	_prev_pos = position
	_vel = Vector2.ZERO


func carry_to(pos: Vector2, delta: float) -> void:
	if not _carry:
		return
	# track hand speed so a flick actually throws rather than drops
	var dt: float = maxf(0.001, delta)
	_vel = (pos - position) / dt
	_prev_pos = position
	_prev_dt = dt
	position = pos


func release_ball() -> void:
	if not _carry:
		return
	_carry = false
	state = State.FLYING
	_spin = signf(_vel.x) * THROW_SPIN
	if _vel.length() < THROW_MIN_SPEED:
		# a limp release: let it drop straight down
		_vel = Vector2(0, 40)
	else:
		_vel = _vel.limit_length(700.0)
	Audio.play("paper_rustle", 1.2, -6.0)


func _process(delta: float) -> void:
	if state != State.FLYING:
		return
	_vel.y += THROW_GRAVITY * delta
	position += _vel * delta
	rotation += _spin * delta

	# into the basket?
	if _vel.y > 0.0 and position.distance_to(_bin_mouth) <= AIM_ASSIST:
		_land(true)
		return
	# onto the desk
	if position.y >= Layout.VIEW_H - 26.0:
		position.y = Layout.VIEW_H - 26.0
		_land(false)
		return
	# off the sides
	if position.x < -40.0 or position.x > Layout.VIEW_W + 40.0:
		_land(false)


func _land(went_in: bool) -> void:
	rotation = 0.0
	_vel = Vector2.ZERO
	if went_in:
		state = State.BINNED
		visible = false
		Audio.play("paper_crease", 0.75, -3.0)
		Audio.play("paper_rustle", 0.7, -8.0)
	else:
		state = State.BALL
		Audio.play("paper_rustle", 0.9, -9.0)
		position.x = clampf(position.x, 20.0, Layout.VIEW_W - 20.0)
	landed.emit(went_in)
	GameEvents.paper_binned.emit(went_in)
