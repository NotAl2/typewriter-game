extends Node2D
## Wax stick, molten pool, and the brass rose die.
##
## The whole point of this step is that wax has a temperature and the player has
## to read it. Hold the stick in the flame too briefly and nothing drips; hold it
## too long and it scorches black and you take a fresh stick. Once poured, the
## pool starts cooling immediately, and the press is graded on the temperature at
## the moment the die goes in - too hot and the rose smears, too cold and only
## half of it takes. There is a window, and finding it is the skill.
##
## The die carries a rose. Section 10 of the design document makes the rose the
## story's recurring symbol, so every letter the player seals goes out marked
## with one, long before the rose starts meaning anything.

enum StickState { COLD, SOFT, MOLTEN, SCORCHED }
enum Phase { IDLE, MELTING, POURING, READY_TO_STAMP, STAMPED }

# --- stick thermodynamics -------------------------------------------------
const HEAT_RATE := 1.0 / 2.0         # per second, in the flame
# Slow enough that wax heated properly stays workable for a couple of seconds
# after it leaves the flame. Any faster and a player who heats to exactly the
# molten threshold has nothing left by the time they reach the envelope, which
# reads as the mechanic being broken rather than as their mistake.
const COOL_RATE := 1.0 / 5.0         # per second, out of it
const SOFT_AT := 0.30
const MOLTEN_AT := 0.55
const SCORCH_AT := 1.15

# --- the pool -------------------------------------------------------------
const POUR_RATE := 0.55              # volume per second
const POOL_COOL_RATE := 1.0 / 4.5    # this is the timing window
const VOLUME_MIN := 0.45             # below this the seal cannot take
const VOLUME_GOOD := 0.68
const VOLUME_MESSY := 1.05

# --- pressing -------------------------------------------------------------
const TEMP_IDEAL_LO := 0.34
const TEMP_IDEAL_HI := 0.80
const PRESS_HOLD := 0.30             # seconds the die must stay down
const CENTRE_TOLERANCE := 7.0        # px

# --- the stick burns away --------------------------------------------------
# Wax is consumed by the flame, not just by pouring. Leave a stick in the fire
# and it shortens until there is nothing left to hold, which is what stops
# "park it in the flame and forget about it" from being a viable strategy.
const BURN_RATE := 9.0               # px of stick lost per second, scorching
const MELT_RATE := 4.5               # px lost per second while merely molten
const POUR_COST := 7.0               # px lost per second of actual pouring

var phase: int = Phase.IDLE
var heat := 0.0
var pool_volume := 0.0
var pool_temp := 0.0
var sticks_spoiled := 0
var sticks_used := 0
## How much of the current stick is left, in pixels of its sprite.
var stick_length := float(Layout.WAX_STICK_H)

var seal_grade: int = RitualResult.Grade.GOOD
var seal_score := 0.0

var _stick: Sprite2D
var _pool: Sprite2D
var _impression: Sprite2D
var _stamp: Sprite2D

var _stick_home := Vector2.ZERO
var _stamp_home := Vector2.ZERO
var _seal_point := Vector2.ZERO

var _stick_held := false
var _stamp_held := false
var _press_time := 0.0
var _press_offset := 0.0
var _press_sink := 0.0
var _sizzling := false
var _drip_accum := 0.0

signal stick_scorched()
signal wax_poured(volume: float)
signal seal_stamped(grade: int, score: float)


func build(seal_point: Vector2) -> void:
	_seal_point = seal_point

	_pool = Sprite2D.new()
	_pool.texture = load("res://assets/art/wax_pool.png")
	_pool.centered = true
	_pool.position = _seal_point
	_pool.region_enabled = true
	_pool.visible = false
	add_child(_pool)

	_impression = Sprite2D.new()
	_impression.texture = load("res://assets/art/seal_impressions.png")
	_impression.centered = true
	_impression.position = _seal_point
	_impression.region_enabled = true
	_impression.visible = false
	add_child(_impression)

	_stick = Sprite2D.new()
	_stick.texture = load("res://assets/art/wax_stick.png")
	_stick.centered = false
	_stick.region_enabled = true
	_stick_home = Vector2(Layout.WAX_STICK_X, Layout.WAX_STICK_Y)
	_stick.position = _stick_home
	add_child(_stick)

	_stamp = Sprite2D.new()
	_stamp.texture = load("res://assets/art/seal_stamp.png")
	_stamp.centered = false
	_stamp_home = Vector2(Layout.SEAL_STAMP_X, Layout.SEAL_STAMP_Y)
	_stamp.position = _stamp_home
	add_child(_stamp)

	_refresh_stick()


## Wipe the wax back to a fresh stick and a bare envelope for the next letter.
func reset_for_letter() -> void:
	phase = Phase.IDLE
	heat = 0.0
	pool_volume = 0.0
	pool_temp = 0.0
	sticks_spoiled = 0
	sticks_used = 0
	stick_length = float(Layout.WAX_STICK_H)
	seal_grade = RitualResult.Grade.GOOD
	seal_score = 0.0
	_stick_held = false
	_stamp_held = false
	_press_time = 0.0
	_press_sink = 0.0
	_stop_sizzle()
	if _stick != null:
		_stick.position = _stick_home
		_refresh_stick()
	if _stamp != null:
		_stamp.position = _stamp_home
	if _pool != null:
		_pool.visible = false
	if _impression != null:
		_impression.visible = false


# --------------------------------------------------------------------------
# state readouts
# --------------------------------------------------------------------------

func stick_state() -> int:
	if heat >= SCORCH_AT:
		return StickState.SCORCHED
	if heat >= MOLTEN_AT:
		return StickState.MOLTEN
	if heat >= SOFT_AT:
		return StickState.SOFT
	return StickState.COLD


func stick_rect() -> Rect2:
	var pad := 7.0 + Settings.drag_assist
	return Rect2(_stick.position.x - pad, _stick.position.y - pad,
				 Layout.WAX_STICK_W + pad * 2.0, stick_length + pad * 2.0)


func stamp_rect() -> Rect2:
	var pad := 4.0 + Settings.drag_assist
	return Rect2(_stamp.position.x - pad, _stamp.position.y - pad,
				 Layout.SEAL_STAMP_W + pad * 2.0, Layout.SEAL_STAMP_H + pad * 2.0)


func pool_ready() -> bool:
	return pool_volume >= VOLUME_MIN


# --------------------------------------------------------------------------
# the stick
# --------------------------------------------------------------------------

func grab_stick() -> void:
	_stick_held = true
	phase = Phase.MELTING


func move_stick(pos: Vector2) -> void:
	if not _stick_held:
		return
	_stick.position = pos - Vector2(Layout.WAX_STICK_W / 2.0, 6.0)


func drop_stick() -> void:
	if not _stick_held:
		return
	_stick_held = false
	_stop_sizzle()
	if stick_state() == StickState.SCORCHED:
		_discard_stick()
	else:
		_stick.position = _stick_home


## The tip of the stick - what has to be in the flame or over the flap. As the
## stick burns down the tip creeps back toward the player's hand, so a nearly
## spent stick has to be held noticeably lower to reach the flame.
func stick_tip() -> Vector2:
	return _stick.position + Vector2(Layout.WAX_STICK_W / 2.0, stick_length)


func _discard_stick() -> void:
	sticks_spoiled += 1
	_take_fresh_stick()
	stick_scorched.emit()
	GameEvents.wax_scorched.emit()


## The stick burned away entirely. Not a mistake exactly - wax is consumable -
## but it costs time and it counts against a tidy job.
func _spend_stick() -> void:
	sticks_used += 1
	_take_fresh_stick()
	Audio.play("wax_drip", 0.65, -4.0)
	GameEvents.wax_stick_spent.emit()


func _take_fresh_stick() -> void:
	heat = 0.0
	stick_length = float(Layout.WAX_STICK_H)
	_stick_held = false
	_stop_sizzle()
	_stick.position = _stick_home
	_refresh_stick()


func _refresh_stick() -> void:
	# The region takes the BOTTOM `stick_length` rows of the cell, so the melted
	# tip artwork survives and the stick visibly shortens from the burning end.
	var len_px: float = clampf(stick_length, 1.0, float(Layout.WAX_STICK_H))
	_stick.region_rect = Rect2(stick_state() * Layout.WAX_STICK_W,
							   Layout.WAX_STICK_H - len_px,
							   Layout.WAX_STICK_W, len_px)


func _start_sizzle() -> void:
	if _sizzling:
		return
	_sizzling = true
	Audio.start_loop("wax_sizzle", -14.0)


func _stop_sizzle() -> void:
	if not _sizzling:
		return
	_sizzling = false
	Audio.stop_loop("wax_sizzle")


# --------------------------------------------------------------------------
# the die
# --------------------------------------------------------------------------

func grab_stamp() -> bool:
	if not pool_ready():
		return false
	_stamp_held = true
	_press_time = 0.0
	return true


func move_stamp(pos: Vector2) -> void:
	if not _stamp_held:
		return
	# `_press_sink` rides along here rather than being applied separately,
	# because this runs every frame and would otherwise overwrite it
	_stamp.position = pos - Vector2(Layout.SEAL_STAMP_W / 2.0,
									Layout.SEAL_STAMP_H - 6.0 - _press_sink)


## Called each frame while the die is held down on the pool.
func press_stamp(delta: float) -> void:
	if not _stamp_held:
		return
	var die := _stamp.position + Vector2(Layout.SEAL_STAMP_W / 2.0,
										 Layout.SEAL_STAMP_H)
	var offset := die.distance_to(_seal_point)
	if offset > CENTRE_TOLERANCE * 3.0:
		_press_time = 0.0
		return
	if _press_time <= 0.0:
		Audio.play("stamp_press", 1.0, -2.0)
		GameEvents.shake_requested.emit(1.0)
	_press_time += delta
	_press_offset = offset
	# the die visibly settles into the wax as it is held down
	_press_sink = minf(3.0, _press_time * 8.0)


func release_stamp() -> void:
	if not _stamp_held:
		return
	_stamp_held = false
	_stamp.position = _stamp_home
	_press_sink = 0.0
	if _press_time >= PRESS_HOLD and pool_ready():
		_resolve_press(_press_offset, _press_time)
	_press_time = 0.0


func _resolve_press(offset: float, hold: float) -> void:
	# Temperature is the dominant term: the wax has to be soft enough to take
	# the die but set enough to hold the shape.
	var temp_score := 0.0
	if pool_temp > TEMP_IDEAL_HI:
		temp_score = clampf(1.0 - (pool_temp - TEMP_IDEAL_HI) / 0.20, 0.0, 1.0)
	elif pool_temp < TEMP_IDEAL_LO:
		temp_score = clampf(pool_temp / maxf(0.01, TEMP_IDEAL_LO), 0.0, 1.0)
	else:
		temp_score = 1.0

	var vol_score: float = clampf(pool_volume / VOLUME_GOOD, 0.0, 1.0)
	if pool_volume > VOLUME_MESSY:
		vol_score *= 0.82
	var centre_score: float = clampf(1.0 - offset / (CENTRE_TOLERANCE * 2.5), 0.0, 1.0)
	var hold_score: float = clampf(hold / (PRESS_HOLD * 1.6), 0.0, 1.0)

	seal_score = temp_score * 0.52 + vol_score * 0.20 + centre_score * 0.18 \
		+ hold_score * 0.10

	# which of the four impressions to show
	var frame := 0
	if pool_temp > TEMP_IDEAL_HI + 0.08:
		frame = 3                                   # smeared
		seal_grade = RitualResult.Grade.POOR
	elif seal_score >= 0.90:
		frame = 0
		seal_grade = RitualResult.Grade.PERFECT
	elif seal_score >= 0.72:
		frame = 1
		seal_grade = RitualResult.Grade.GOOD
	elif seal_score >= 0.45:
		frame = 2
		seal_grade = RitualResult.Grade.POOR
	else:
		frame = 2
		seal_grade = RitualResult.Grade.RUINED

	var cell := _impression.texture.get_height()
	_impression.region_rect = Rect2(frame * cell, 0, cell, cell)
	_impression.visible = true
	_pool.visible = true
	pool_temp = minf(pool_temp, TEMP_IDEAL_LO * 0.5)   # the press sets it
	_refresh_pool()

	phase = Phase.STAMPED
	Audio.play("stamp_peel", 1.0, -4.0)
	seal_stamped.emit(seal_grade, seal_score)
	GameEvents.seal_pressed.emit(seal_grade, seal_score)


# --------------------------------------------------------------------------
# per-frame simulation
# --------------------------------------------------------------------------

func _refresh_pool() -> void:
	if pool_volume <= 0.0:
		_pool.visible = false
		return
	_pool.visible = true
	var stage := clampi(int(pool_volume * Layout.WAX_POOL_STAGES), 0,
						Layout.WAX_POOL_STAGES - 1)
	# four temperature rows: molten, hot, setting, set
	var row := clampi(3 - int(pool_temp * 3.999), 0, 3)
	var w := Layout.WAX_POOL_W
	var h := Layout.WAX_POOL_H
	_pool.region_rect = Rect2(stage * w, row * h, w, h)


func _process(delta: float) -> void:
	if _stick_held:
		var tip := stick_tip()
		var in_flame := tip.distance_to(
			Vector2(Layout.FLAME_CX, Layout.FLAME_CY)) <= Layout.FLAME_HEAT_R
		var was := stick_state()
		if in_flame and heat < SCORCH_AT:
			heat = minf(SCORCH_AT + 0.001, heat + HEAT_RATE * delta)
			_start_sizzle()
			Audio.set_loop_pitch("wax_sizzle", 0.9 + heat * 0.35)
		else:
			_stop_sizzle()
			heat = maxf(0.0, heat - COOL_RATE * delta)

		# the flame eats the stick: fastest when it is scorching, slower when it
		# is merely molten, and not at all when it is cold
		var burn := 0.0
		if in_flame:
			if heat >= SCORCH_AT:
				burn = BURN_RATE
			elif heat >= MOLTEN_AT:
				burn = MELT_RATE
			elif heat >= SOFT_AT:
				burn = MELT_RATE * 0.4
		if burn > 0.0:
			stick_length = maxf(0.0, stick_length - burn * delta)
			_refresh_stick()
			if stick_length <= float(Layout.WAX_STICK_MIN_LEN):
				_spend_stick()
				return

		if stick_state() != was:
			_refresh_stick()
			GameEvents.wax_heat_changed.emit(heat)
			if stick_state() == StickState.SCORCHED:
				Audio.play("paper_tear", 0.6, -12.0)   # a dry, burnt hiss

		# molten wax held over the flap drips into the pool
		if stick_state() == StickState.MOLTEN \
				and tip.distance_to(_seal_point) <= 16.0:
			phase = Phase.POURING
			pool_volume = minf(1.4, pool_volume + POUR_RATE * delta)
			pool_temp = 1.0
			# pouring consumes the stick too
			stick_length = maxf(0.0, stick_length - POUR_COST * delta)
			_refresh_stick()
			if stick_length <= float(Layout.WAX_STICK_MIN_LEN):
				_spend_stick()
				return
			_drip_accum += delta
			if _drip_accum >= 0.22:
				_drip_accum = 0.0
				Audio.play("wax_drip", 1.0, -8.0)
				GameEvents.wax_dripped.emit(pool_volume)
			wax_poured.emit(pool_volume)
			_refresh_pool()
	elif _sizzling:
		_stop_sizzle()

	# the pool cools whether anyone is watching or not - this is the clock the
	# player is racing when they reach for the die
	if pool_volume > 0.0 and pool_temp > 0.0 and phase != Phase.STAMPED:
		pool_temp = maxf(0.0, pool_temp - POOL_COOL_RATE * delta)
		_refresh_pool()
		if phase == Phase.POURING and not _stick_held:
			phase = Phase.READY_TO_STAMP


func hide_seal() -> void:
	if is_instance_valid(_pool):
		_pool.visible = false
	if is_instance_valid(_impression):
		_impression.visible = false
