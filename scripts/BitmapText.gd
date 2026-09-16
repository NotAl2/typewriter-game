class_name BitmapText
extends RefCounted
## Draws the generated 5x7 / 3x5 bitmap faces glyph by glyph.
##
## The page deliberately does NOT use a Label or a Font resource. Every
## character on a typed page needs its own vertical jitter, ink density and
## overstrike state, and a text node gives you none of that - it would render a
## clean line of type where the whole point is an imperfect one.

var texture: Texture2D
var glyph_w := 5
var glyph_h := 7
var advance := 6
var line_height := 9
var baseline := 6

var _chars: Dictionary = {}          # String -> Vector2 atlas origin

const _DIR := "res://assets/fonts/"


static func load_face(face: String) -> BitmapText:
	var bt := BitmapText.new()
	var meta_path := _DIR + face + ".json"
	var png_path := _DIR + face + ".png"
	if not ResourceLoader.exists(png_path):
		push_error("BitmapText: missing atlas %s" % png_path)
		return bt
	bt.texture = load(png_path)
	var f := FileAccess.open(meta_path, FileAccess.READ)
	if f == null:
		push_error("BitmapText: missing metrics %s" % meta_path)
		return bt
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		push_error("BitmapText: bad metrics %s" % meta_path)
		return bt
	bt.glyph_w = int(data["glyph_w"])
	bt.glyph_h = int(data["glyph_h"])
	bt.advance = int(data["advance"])
	bt.line_height = int(data["line_height"])
	bt.baseline = int(data["baseline"])
	for ch: String in (data["chars"] as Dictionary):
		var m: Dictionary = data["chars"][ch]
		bt._chars[ch] = Vector2(float(m["x"]), float(m["y"]))
	return bt


func has_char(ch: String) -> bool:
	return _chars.has(ch)


func region_of(ch: String) -> Rect2:
	var o: Vector2 = _chars.get(ch, _chars.get("?", Vector2.ZERO))
	return Rect2(o, Vector2(glyph_w, glyph_h))


## Draw one glyph with its top-left at `pos`.
func draw_glyph(ci: CanvasItem, ch: String, pos: Vector2,
		color: Color = Color.WHITE) -> void:
	if texture == null or ch == " ":
		return
	if not _chars.has(ch):
		ch = "?"
		if not _chars.has(ch):
			return
	ci.draw_texture_rect_region(texture,
		Rect2(pos.round(), Vector2(glyph_w, glyph_h)), region_of(ch), color)


func draw_text(ci: CanvasItem, text: String, pos: Vector2,
		color: Color = Color.WHITE) -> void:
	for i in text.length():
		draw_glyph(ci, text[i], pos + Vector2(i * advance, 0), color)


func width_of(text: String) -> int:
	return text.length() * advance
