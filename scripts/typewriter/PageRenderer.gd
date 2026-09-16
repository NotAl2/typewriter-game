extends Node2D
## Draws a TypedPage onto the paper texture inside a SubViewport.
##
## Rendering into a viewport rather than straight to the screen buys three
## things the mechanic needs:
##   * the finished page becomes a real texture, so it can be pulled out of the
##     machine, folded, posted, and filed as evidence later;
##   * every glyph gets its own offset and ink density, which a Label cannot do;
##   * `reveal_rows` separates *committed* from *visible*, which is the entire
##     implementation of the blind-writer horror variant - flip one flag and the
##     player types without seeing a word until they roll the platen up.

const INK := Color(0.165, 0.122, 0.094)          # palette "ink"
const SMUDGE := Color(0.165, 0.122, 0.094, 0.55)

var page: TypedPage
var font: BitmapText

## Rows at or above this index are drawn. -1 means "draw everything".
var reveal_rows := -1

var _margin_x := 0
var _margin_top := 0
var _line_h := 9
var _adv := 6


func setup(p: TypedPage, f: BitmapText) -> void:
	page = p
	font = f
	_margin_x = Layout.PAGE_MARGIN_X
	_margin_top = Layout.PAGE_MARGIN_TOP
	_line_h = Layout.LINE_H
	_adv = Layout.CHAR_ADV
	queue_redraw()


func cell_position(col: int, row: int) -> Vector2:
	return Vector2(_margin_x + col * _adv,
				   _margin_top + row * _line_h - font.glyph_h)


func _draw() -> void:
	if page == null or font == null:
		return

	for s in page.smudges:
		_draw_smudge(int(s["col"]), int(s["row"]), int(s["seed"]))

	for g in page.glyphs:
		var row := int(g["row"])
		if reveal_rows >= 0 and row > reveal_rows:
			continue
		var pos := cell_position(int(g["col"]), row)
		pos.y += float(g["dy"])
		var col := INK
		col.a = float(g["ink"])
		if bool(g["heavy"]):
			# a hard strike bites twice - draw it again a hair off for weight
			font.draw_glyph(self, String(g["ch"]), pos + Vector2(0, 1),
							Color(INK.r, INK.g, INK.b, col.a * 0.5))
		font.draw_glyph(self, String(g["ch"]), pos, col)


func _draw_smudge(col: int, row: int, seed_value: int) -> void:
	## Jams leave ink on the page. Permanently.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var base := cell_position(col, row) + Vector2(_adv * 0.5, font.glyph_h * 0.5)
	for i in 14:
		var off := Vector2(rng.randf_range(-4.0, 5.0), rng.randf_range(-3.0, 3.5))
		var r := rng.randf_range(0.6, 2.1)
		var c := SMUDGE
		c.a *= rng.randf_range(0.35, 1.0)
		draw_circle(base + off, r, c)
