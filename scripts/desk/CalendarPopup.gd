extends Node2D

var _font: BitmapText
var _noise_tex: ImageTexture

func build(font: BitmapText) -> void:
	_font = font
	z_index = 100
	set_process_input(true)
	
	var img = Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, randf()))
	_noise_tex = ImageTexture.create_from_image(img)
	
func _draw() -> void:
	# Dim background
	draw_rect(Rect2(0, 0, Layout.VIEW_W, Layout.VIEW_H), Color(0.02, 0.012, 0.008, 0.78))
	
	var cx = Layout.VIEW_W / 2.0
	var cy = Layout.VIEW_H / 2.0
	var shadow_col = Color(0.05, 0.03, 0.02, 0.65)
	
	# Board
	var w = 260
	var h = 240
	var bx = cx - w/2
	var by = cy - h/2
	
	# Board shadow (Grainy)
	draw_texture_rect(_noise_tex, Rect2(bx + 12, by + 12, w, h), true, shadow_col)
	
	# Board Base & Grain
	draw_rect(Rect2(bx, by, w, h), Color(0.32, 0.2, 0.13))
	draw_texture_rect(_noise_tex, Rect2(bx, by, w, h), true, Color(0.15, 0.08, 0.04, 0.25))
	
	# Board inner shading (Darker grain on bottom and right)
	var shade_c = Color(0.12, 0.05, 0.02, 0.4)
	draw_texture_rect(_noise_tex, Rect2(bx, by + h - 16, w, 16), true, shade_c)
	draw_texture_rect(_noise_tex, Rect2(bx + w - 16, by, 16, h), true, shade_c)
	draw_rect(Rect2(bx, by, w, h), Color(0.15, 0.08, 0.04), false, 4.0)
	
	# Paper
	var pw = 236
	var ph = 210
	var px_start = cx - pw/2
	var py_start = cy - ph/2 + 15
	
	# Paper shadow
	draw_texture_rect(_noise_tex, Rect2(px_start + 6, py_start + 6, pw, ph), true, shadow_col)
	
	# Paper Base & Grain
	draw_rect(Rect2(px_start, py_start, pw, ph), Color(0.92, 0.89, 0.82))
	draw_texture_rect(_noise_tex, Rect2(px_start, py_start, pw, ph), true, Color(0.65, 0.55, 0.45, 0.15))
	
	# Paper inner shading (Thinner, grainy)
	draw_texture_rect(_noise_tex, Rect2(px_start, py_start + ph - 8, pw, 8), true, Color(0.6, 0.5, 0.4, 0.35))
	draw_texture_rect(_noise_tex, Rect2(px_start + pw - 8, py_start, 8, ph), true, Color(0.6, 0.5, 0.4, 0.35))
	draw_rect(Rect2(px_start, py_start, pw, ph), Color(0.55, 0.5, 0.4), false, 2.0)
	
	# Rings
	var r_w = 12
	var r_h = 24
	var ring1 = cx - pw/2 + 45
	var ring2 = cx + pw/2 - 45
	var r_y = cy - h/2 - 5
	
	# Ring shadows
	draw_rect(Rect2(ring1 - r_w/2 + 4, r_y + 4, r_w, r_h), Color(0.05, 0.03, 0.02, 0.5))
	draw_rect(Rect2(ring2 - r_w/2 + 4, r_y + 4, r_w, r_h), Color(0.05, 0.03, 0.02, 0.5))
	
	draw_rect(Rect2(ring1 - r_w/2, r_y, r_w, r_h), Color(0.45, 0.45, 0.5))
	draw_texture_rect(_noise_tex, Rect2(ring1 - r_w/2, r_y, r_w, r_h), true, Color(0.2, 0.2, 0.2, 0.3))
	draw_rect(Rect2(ring1 - r_w/2, r_y, r_w, r_h), Color(0.15, 0.15, 0.15), false, 2.0)
	
	draw_rect(Rect2(ring2 - r_w/2, r_y, r_w, r_h), Color(0.45, 0.45, 0.5))
	draw_texture_rect(_noise_tex, Rect2(ring2 - r_w/2, r_y, r_w, r_h), true, Color(0.2, 0.2, 0.2, 0.3))
	draw_rect(Rect2(ring2 - r_w/2, r_y, r_w, r_h), Color(0.15, 0.15, 0.15), false, 2.0)
	
	# Month Title
	if _font:
		_font.draw_text(self, "OCTOBER 1874", Vector2(cx - 36, py_start + 14), Color(0.2, 0.1, 0.05))
		
	# Grid
	var start_x = px_start + 20
	var start_y = py_start + 40
	var cell_size = 28
	var spacing = 28
	
	var current_day = 12 + RunState.day_offset
	var day_num = 1
	var start_day_of_week = 3 # Thu
	
	for r in range(6):
		for c in range(7):
			if r == 0 and c < start_day_of_week:
				continue
			if day_num > 31:
				break
				
			var rx = start_x + c * spacing
			var ry = start_y + r * spacing
			
			# Solid, subtle box instead of harsh dither
			draw_rect(Rect2(rx, ry, cell_size - 4, cell_size - 4), Color(0.85, 0.8, 0.72, 0.7))
			
			# Draw day text
			if _font:
				var text_off = Vector2(11, 10) if day_num < 10 else Vector2(8, 10)
				_font.draw_text(self, str(day_num), Vector2(rx, ry) + text_off, Color(0.25, 0.2, 0.15))
			
			# Cross out past days
			if day_num < current_day:
				var c1 = Vector2(rx + 2, ry + 2)
				var c2 = Vector2(rx + cell_size - 6, ry + cell_size - 6)
				var c3 = Vector2(rx + cell_size - 6, ry + 2)
				var c4 = Vector2(rx + 2, ry + cell_size - 6)
				draw_line(c1, c2, Color(0.45, 0.1, 0.08), 2.0)
				draw_line(c3, c4, Color(0.45, 0.1, 0.08), 2.0)
			# Circle current day
			elif day_num == current_day:
				var center = Vector2(rx + (cell_size - 4)/2.0, ry + (cell_size - 4)/2.0)
				_draw_circle_hollow(center, (cell_size - 2)/2.0, Color(0.65, 0.15, 0.1), 2.0)
				
			day_num += 1

func _draw_circle_hollow(center: Vector2, radius: float, color: Color, width: float) -> void:
	var pts = PackedVector2Array()
	var segs = 32
	for i in range(segs + 1):
		var a = (float(i) / segs) * TAU
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_polyline(pts, color, width)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			get_viewport().set_input_as_handled()
			queue_free()
			Audio.play("paper_rustle", 0.9, 1.0)
