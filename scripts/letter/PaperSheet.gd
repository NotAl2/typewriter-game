extends Node2D
## The finished sheet once it is out of the machine: folding it, then carrying
## it to the envelope.
##
## It keeps the baked page texture the whole way through, so the player can see
## their own typing - the typos, the overstruck x's, the smudge a jam left -
## disappearing fold by fold into the envelope. Folding an anonymous blank
## rectangle would throw away the only thing that made the page theirs.

enum Fold { FLAT, ONCE, TWICE, GONE }

const FOLD_DRAG := 20.0              # px of drag to complete one fold
const CREASE := Color(0.77, 0.70, 0.58, 0.9)
const CREASE_SHADOW := Color(0.42, 0.34, 0.26, 0.5)

var fold: int = Fold.FLAT

var _sprite: Sprite2D
var _page_tex: Texture2D
var _rest_pos := Vector2.ZERO
var _carry := false
var _fold_pull := 0.0
var _folding := false

signal folded(stage: int)
signal dropped(at: Vector2)


func build(page_texture: Texture2D, rest_position: Vector2) -> void:
	_page_tex = page_texture
	_rest_pos = rest_position
	_sprite = Sprite2D.new()
	_sprite.texture = _page_tex
	_sprite.centered = false
	_sprite.region_enabled = true
	add_child(_sprite)
	position = _rest_pos
	_apply_fold()


func _apply_fold() -> void:
	var w := float(Layout.SHEET_W)
	var h := float(Layout.SHEET_H)
	match fold:
		Fold.FLAT:
			_sprite.region_rect = Rect2(0, 0, w, h)
		Fold.ONCE:
			# bottom third folded up behind
			_sprite.region_rect = Rect2(0, 0, w, h * 2.0 / 3.0)
		_:
			# top third folded down over it: only the middle band still shows
			_sprite.region_rect = Rect2(0, h / 3.0, w, h / 3.0)
	queue_redraw()


func size() -> Vector2:
	return _sprite.region_rect.size


func rect() -> Rect2:
	var pad := Settings.drag_assist
	return Rect2(position - Vector2(pad, pad), size() + Vector2(pad, pad) * 2.0)


## The lower half, which the player drags UP to make the first fold.
func lower_rect() -> Rect2:
	var s := size()
	return Rect2(position + Vector2(0, s.y * 0.5), Vector2(s.x, s.y * 0.5))


## The upper half, which the player drags DOWN to make the second.
func upper_rect() -> Rect2:
	var s := size()
	return Rect2(position, Vector2(s.x, s.y * 0.5))


func can_fold() -> bool:
	return fold == Fold.FLAT or fold == Fold.ONCE


func begin_fold() -> void:
	_folding = true
	_fold_pull = 0.0


## `amount` is the drag distance in the correct direction for the current fold.
func update_fold(amount: float) -> void:
	if not _folding or not can_fold():
		return
	_fold_pull = clampf(_fold_pull + maxf(0.0, amount), 0.0, FOLD_DRAG)
	# the sheet visibly creeps closed as it is dragged
	var f := _fold_pull / FOLD_DRAG
	var w := float(Layout.SHEET_W)
	var h := float(Layout.SHEET_H)
	if fold == Fold.FLAT:
		_sprite.region_rect = Rect2(0, 0, w, lerpf(h, h * 2.0 / 3.0, f))
	else:
		var top := lerpf(0.0, h / 3.0, f)
		_sprite.region_rect = Rect2(0, top, w, lerpf(h * 2.0 / 3.0, h / 3.0, f))
	queue_redraw()
	if _fold_pull >= FOLD_DRAG:
		_complete_fold()


func end_fold() -> void:
	if not _folding:
		return
	_folding = false
	_fold_pull = 0.0
	_apply_fold()


func _complete_fold() -> void:
	_folding = false
	_fold_pull = 0.0
	fold = Fold.ONCE if fold == Fold.FLAT else Fold.TWICE
	_apply_fold()
	Audio.play("paper_crease", 1.0 + (0.06 if fold == Fold.TWICE else 0.0), -2.0)
	folded.emit(fold)
	GameEvents.letter_folded.emit(fold)


# --------------------------------------------------------------------------
# carrying
# --------------------------------------------------------------------------

func grab() -> void:
	_carry = true
	Audio.play("paper_rustle", 1.1, -8.0)


func carry_to(pos: Vector2) -> void:
	if _carry:
		position = (pos - size() * 0.5).round()


func release() -> Vector2:
	_carry = false
	dropped.emit(position + size() * 0.5)
	return position + size() * 0.5


func return_to_rest() -> void:
	position = _rest_pos


func consume() -> void:
	fold = Fold.GONE
	visible = false


func _draw() -> void:
	if fold == Fold.FLAT:
		return
	# creases along the folded edges, so the packet reads as folded paper rather
	# than as a cropped picture of a page
	var s := size()
	draw_line(Vector2(0, s.y - 1), Vector2(s.x, s.y - 1), CREASE_SHADOW, 1.0)
	draw_line(Vector2(0, s.y - 2), Vector2(s.x, s.y - 2), CREASE, 1.0)
	if fold == Fold.TWICE:
		draw_line(Vector2(0, 0), Vector2(s.x, 0), CREASE, 1.0)
		draw_line(Vector2(0, 1), Vector2(s.x, 1), CREASE_SHADOW, 1.0)
