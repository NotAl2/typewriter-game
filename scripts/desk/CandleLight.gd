extends Node2D
## Candle, flame, and the warm light it throws.
##
## The flicker is one shared value: it drives the flame's frame timing, the size
## and brightness of the glow, and a faint warm wash over the whole room. Wiring
## them to one signal is what stops the candle looking like a looping sprite
## sitting next to an unrelated light.
##
## The wobble is two detuned sine waves plus occasional gusts, rather than pure
## noise, because a real flame breathes.

const FRAME_MIN := 0.075
const FRAME_MAX := 0.13
const GUST_CHANCE := 0.004           # per frame, a bigger lurch

var flicker := 1.0                   # ~0.7 .. 1.15

var _flame: Sprite2D
var _glow: Sprite2D
var _frames := 6
var _frame := 0
var _frame_timer := 0.0
var _t := 0.0
var _gust := 0.0
var _rng := RandomNumberGenerator.new()

signal flickered(value: float)


func build() -> void:
	var stick := Sprite2D.new()
	stick.texture = load("res://assets/art/candlestick.png")
	stick.centered = false
	stick.position = Vector2(Layout.CANDLE_X, Layout.CANDLE_Y)
	add_child(stick)

	var flame_tex: Texture2D = load("res://assets/art/flame.png")
	_frames = maxi(1, flame_tex.get_width() / Layout.FLAME_W)
	_flame = Sprite2D.new()
	_flame.texture = flame_tex
	_flame.centered = false
	_flame.region_enabled = true
	_flame.region_rect = Rect2(0, 0, Layout.FLAME_W, Layout.FLAME_H)
	_flame.position = Vector2(Layout.FLAME_X, Layout.FLAME_Y)
	add_child(_flame)

	_glow = Sprite2D.new()
	_glow.texture = load("res://assets/art/flame_glow.png")
	_glow.centered = true
	_glow.position = Vector2(Layout.FLAME_CX, Layout.FLAME_CY)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.modulate = Color(1, 1, 1, 0.5)
	add_child(_glow)

	_rng.randomize()


## The glow sprite, so DeskScene can lift it above the machine in draw order.
func glow_sprite() -> Sprite2D:
	return _glow


func _process(delta: float) -> void:
	_t += delta

	# two detuned waves read as breathing; a gust reads as a draught
	var base := 0.94 + 0.055 * sin(_t * 5.3) + 0.035 * sin(_t * 11.7 + 1.4)
	if _gust > 0.0:
		_gust = maxf(0.0, _gust - delta * 2.2)
		base -= _gust * 0.30
	elif _rng.randf() < GUST_CHANCE:
		_gust = _rng.randf_range(0.4, 1.0)
	flicker = clampf(base, 0.62, 1.16)
	flickered.emit(flicker)

	# frames hold for uneven lengths, so the loop never reads as a loop
	_frame_timer -= delta
	if _frame_timer <= 0.0:
		_frame_timer = _rng.randf_range(FRAME_MIN, FRAME_MAX) / maxf(0.4, flicker)
		_frame = (_frame + 1 + (1 if _rng.randf() < 0.18 else 0)) % _frames
		_flame.region_rect = Rect2(_frame * Layout.FLAME_W, 0,
								   Layout.FLAME_W, Layout.FLAME_H)

	_glow.scale = Vector2.ONE * (0.92 + flicker * 0.16)
	_glow.modulate.a = 0.34 + (flicker - 0.62) * 0.30
