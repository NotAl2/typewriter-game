class_name TypedPage
extends Resource
## What is actually on the sheet.
##
## Pure data, no rendering and no node references, so the page can be scored,
## saved as evidence for the investigation later, or handed to a distorted
## renderer during the horror acts without any of that touching the machine.
##
## A glyph is never removed. There is no backspace on an 1870s typewriter, so
## the only correction is to run the carriage back and strike over what is
## already there - which stacks a second glyph in the same cell and leaves a
## permanent scar. That is the mechanic the whole story turns on.

const INK_MIN := 0.72
const INK_MAX := 1.0

## Every mark on the page, in strike order.
## { ch, col, row, dy, ink, heavy }
var glyphs: Array[Dictionary] = []

## Ink smudges left behind by cleared jams. { col, row, seed }
var smudges: Array[Dictionary] = []

## Seeded so a page re-renders identically every frame and across sessions.
var render_seed := 0

var _rng := RandomNumberGenerator.new()
var _occupied: Dictionary = {}       # "col,row" -> count


func _init(seed_value: int = 0) -> void:
	render_seed = seed_value if seed_value != 0 else randi()
	_rng.seed = render_seed


func clear() -> void:
	glyphs.clear()
	smudges.clear()
	_occupied.clear()
	_rng.seed = render_seed


func _key(col: int, row: int) -> String:
	return "%d,%d" % [col, row]


func has_glyph(col: int, row: int) -> bool:
	return _occupied.has(_key(col, row))


## Print a character. Returns true if it landed on top of an existing one.
func strike(ch: String, col: int, row: int, force: float = 0.5) -> bool:
	var k := _key(col, row)
	var over: bool = _occupied.has(k)
	_occupied[k] = int(_occupied.get(k, 0)) + 1
	glyphs.append({
		"ch": ch,
		"col": col,
		"row": row,
		# a real typebar never lands twice in exactly the same place
		"dy": _rng.randi_range(-1, 1),
		"ink": _rng.randf_range(INK_MIN, INK_MAX),
		# hit a key hard and the slug bites deeper
		"heavy": _rng.randf() < (0.06 + force * 0.14),
	})
	return over


func add_smudge(col: int, row: int) -> void:
	smudges.append({"col": col, "row": row, "seed": _rng.randi()})


## The text of one line, with unoccupied cells as spaces. Overstruck cells
## report the LAST character struck there, which is what a reader would see.
func line_text(row: int, cols: int) -> String:
	var buf := []
	buf.resize(cols)
	buf.fill(" ")
	for g in glyphs:
		if int(g["row"]) == row:
			var c := int(g["col"])
			if c >= 0 and c < cols:
				buf[c] = g["ch"]
	return "".join(buf)


func full_text(rows: int, cols: int) -> String:
	var out := PackedStringArray()
	for r in rows:
		out.append(line_text(r, cols))
	return "\n".join(out)


func overstrike_count() -> int:
	var n := 0
	for k: String in _occupied:
		n += maxi(0, int(_occupied[k]) - 1)
	return n


func is_empty() -> bool:
	return glyphs.is_empty()
