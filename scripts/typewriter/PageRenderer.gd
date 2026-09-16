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
const ERROR_COLOR := Color("#691407")
const GHOST_COLOR := Color(0.165, 0.122, 0.094, 0.35)

var page: TypedPage
var font: BitmapText
var document: DocumentData

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

	# Draw ghost letters from the target document
	if document != null:
		for row in document.line_count():
			if reveal_rows >= 0 and row > reveal_rows:
				continue
			var text = document.line(row)
			for col in text.length():
				var ch = text[col]
				if ch != " ":
					font.draw_glyph(self, ch, cell_position(col, row), GHOST_COLOR)

	for s in page.smudges:
		_draw_smudge(int(s["col"]), int(s["row"]), int(s["seed"]))

	for g in page.glyphs:
		var row := int(g["row"])
		var col_idx := int(g["col"])
		if reveal_rows >= 0 and row > reveal_rows:
			continue
		var pos := cell_position(col_idx, row)
		pos.y += float(g["dy"])
		
		# Check if it's a mistake
		var is_error := false
		var ch := String(g["ch"])
		
		# 1. Overwrite check
		var key := "%d,%d" % [col_idx, row]
		if page._occupied.get(key, 0) > 1:
			is_error = true
		
		# 2. Wrong letter check
		if document != null:
			if row < document.line_count():
				var line_text = document.line(row)
				if col_idx < 0 or col_idx >= line_text.length() or line_text[col_idx] != ch:
					is_error = true
			else:
				is_error = true # Typed beyond document length
				
		var col := ERROR_COLOR if is_error else INK
		if not is_error:
			col.a = float(g["ink"])
			
		if bool(g["heavy"]):
			# a hard strike bites twice - draw it again a hair off for weight
			font.draw_glyph(self, ch, pos + Vector2(0, 1),
							Color(col.r, col.g, col.b, col.a * 0.5))
		font.draw_glyph(self, ch, pos, col)


func _draw_smudge(col: int, row: int, seed_value: int) -> void:
	## Jams leave ink on the page. Permanently.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var base := cell_position(col, row) + Vector2(_adv * 0.5, font.glyph_h * 0.5)
	for i in 14:
		var off := Vector2(rng.randf_range(-4.0, 5.0), rng.randf_range(-3.0, 3.5))
		var r := rng.randf_range(0.6, 2.1)
		# Smudges are errors now, drawn in red
		var c := ERROR_COLOR
		c.a *= rng.randf_range(0.35, 1.0)
		draw_circle(base + off, r, c)
