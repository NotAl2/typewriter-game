class_name JamController
extends RefCounted
## Decides when two typebars clash.
##
## Modelled on the real failure rather than as a random tax on the player. On a
## Remington the bars swing up through a shared basket and fall back under
## gravity; if you strike a second key before the first bar has dropped clear,
## and the two bars are close together in the fan, they lock. So a jam here
## needs BOTH conditions - two strikes inside the clash window AND two bars that
## are near neighbours in the basket. Typing fast makes it likelier; typing fast
## and evenly does not.
##
## The consequences: it can never happen in the opening keystrokes of a page, it
## can never chain, and `Settings.jam_rate_scale` scales or disables it.

## Order the bars sit in the basket. Neighbours here can foul each other.
const BASKET_ORDER := "1234567890QWERTYUIOPASDFGHJKL;ZXCVBNM,.?'-"

## Two strikes closer together than this can foul.
const CLASH_WINDOW_MS := 55.0
## Bars this close in the fan are near enough to lock.
const NEIGHBOUR_SPAN := 3

const BASE_CHANCE := 0.012
const SPEED_CHANCE := 0.085          # extra chance at flat-out typing speed
const SPEED_REF_WPM := 55.0

## No jam in the opening strikes of a page - a jam on the first word reads as
## the game being broken rather than the machine being temperamental.
const GRACE_KEYS := 10
## Nor twice in quick succession.
const COOLDOWN_KEYS := 30

var jammed := false
var bar_a := -1
var bar_b := -1
var jam_col := 0
var jam_row := 0

var _keys_this_page := 0
var _keys_since_jam := 999
var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value if seed_value != 0 else randi()


func reset_page() -> void:
	jammed = false
	bar_a = -1
	bar_b = -1
	_keys_this_page = 0
	_keys_since_jam = 999


static func bar_index(ch: String) -> int:
	return BASKET_ORDER.find(ch.to_upper())


## Call on every accepted keystroke. Returns true if the machine just jammed.
func consider(ch: String, prev_ch: String, gap_ms: float, wpm: float,
		col: int, row: int) -> bool:
	_keys_this_page += 1
	_keys_since_jam += 1
	if jammed:
		return false
	if Settings.jam_rate_scale <= 0.0:
		return false
	if _keys_this_page <= GRACE_KEYS or _keys_since_jam <= COOLDOWN_KEYS:
		return false
	if prev_ch.is_empty() or gap_ms > CLASH_WINDOW_MS:
		return false

	var a := bar_index(prev_ch)
	var b := bar_index(ch)
	if a < 0 or b < 0 or a == b:
		return false
	if absi(a - b) > NEIGHBOUR_SPAN:
		return false

	# how far inside the clash window, and how hard the player is pushing
	var closeness := 1.0 - clampf(gap_ms / CLASH_WINDOW_MS, 0.0, 1.0)
	var speed := clampf(wpm / SPEED_REF_WPM, 0.0, 1.4)
	var chance := (BASE_CHANCE + SPEED_CHANCE * speed) * closeness \
		* Settings.jam_rate_scale
	if _rng.randf() >= chance:
		return false

	jammed = true
	bar_a = a
	bar_b = b
	jam_col = col
	jam_row = row
	_keys_since_jam = 0
	return true


func clear_jam() -> void:
	jammed = false
	bar_a = -1
	bar_b = -1
