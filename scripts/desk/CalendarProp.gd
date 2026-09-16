extends Node2D

var _font: BitmapText
var _hovered := false
var _noise_tex: ImageTexture

func build(font: BitmapText) -> void:
	_font = font
	position = Vector2(210, 70) 
	z_index = 5 
	set_process_input(true)
	
	var img = Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			img.set_pixel(x, y, Color(1, 1, 1, randf()))
	_noise_tex = ImageTexture.create_from_image(img)
	
func _draw() -> void:
	var w = 38
	var h = 40
	var shadow_col = Color(0.1, 0.06, 0.03, 0.6)
	
	# Board drop shadow
	draw_texture_rect(_noise_tex, Rect2(-w/2 + 3, -h/2 + 3, w, h), true, shadow_col)
	
	# Backboard
	draw_rect(Rect2(-w/2, -h/2, w, h), Color(0.32, 0.2, 0.13))
	draw_texture_rect(_noise_tex, Rect2(-w/2, -h/2, w, h), true, Color(0.15, 0.08, 0.04, 0.3))
	
	# Board inner shading
	draw_texture_rect(_noise_tex, Rect2(-w/2, h/2 - 4, w, 4), true, Color(0.12, 0.05, 0.02, 0.5))
	draw_texture_rect(_noise_tex, Rect2(w/2 - 4, -h/2, 4, h), true, Color(0.12, 0.05, 0.02, 0.5))
	draw_rect(Rect2(-w/2, -h/2, w, h), Color(0.15, 0.08, 0.04), false, 1.0)
	
	# Paper
	var pw = 32
	var ph = 32
	
	# Paper shadow
	draw_texture_rect(_noise_tex, Rect2(-pw/2 + 2, -ph/2 + 4, pw, ph), true, shadow_col)
	
	# Paper Base
	draw_rect(Rect2(-pw/2, -ph/2 + 2, pw, ph), Color(0.92, 0.89, 0.82))
	draw_texture_rect(_noise_tex, Rect2(-pw/2, -ph/2 + 2, pw, ph), true, Color(0.65, 0.55, 0.45, 0.2))
	
	# Paper inner shading
	draw_texture_rect(_noise_tex, Rect2(-pw/2, -ph/2 + 2 + ph - 3, pw, 3), true, Color(0.6, 0.5, 0.4, 0.4))
	draw_texture_rect(_noise_tex, Rect2(pw/2 - 3, -ph/2 + 2, 3, ph), true, Color(0.6, 0.5, 0.4, 0.4))
	
	# Grid lines/dots (suggesting days)
	var sq_size = 2
	var spacing = 4
	for r in range(5):
		for c in range(7):
			var px = -pw/2 + 3 + c * spacing
			var py = -ph/2 + 6 + r * spacing
			draw_rect(Rect2(px, py, sq_size, sq_size), Color(0.7, 0.65, 0.55))
			
	# Top Rings
	var cx1 = -pw/2 + 6
	var cx2 = pw/2 - 6
	var cy = -h/2 - 3
	draw_rect(Rect2(cx1 - 2, cy + 2, 4, 8), Color(0.1, 0.06, 0.03, 0.6))
	draw_rect(Rect2(cx2 - 2, cy + 2, 4, 8), Color(0.1, 0.06, 0.03, 0.6))
	
	draw_rect(Rect2(cx1 - 2, cy, 4, 8), Color(0.45, 0.45, 0.5))
	draw_rect(Rect2(cx2 - 2, cy, 4, 8), Color(0.45, 0.45, 0.5))
	draw_rect(Rect2(cx1 - 2, cy, 4, 8), Color(0.15, 0.15, 0.15), false, 1.0)
	draw_rect(Rect2(cx2 - 2, cy, 4, 8), Color(0.15, 0.15, 0.15), false, 1.0)
	
	if _hovered:
		draw_rect(Rect2(-w/2 - 2, -h/2 - 4, w + 4, h + 8), Color(1.0, 1.0, 1.0, 0.15), false, 1.0)

func _input(event: InputEvent) -> void:
	var scene = get_tree().current_scene
	if scene and scene.get("phase") != null and (scene.phase <= 0 or scene.phase >= 4):
		if _hovered:
			_hovered = false
			queue_redraw()
		return
		
	if event is InputEventMouseMotion:
		var mm = event as InputEventMouseMotion
		var rect = Rect2(global_position.x - 19, global_position.y - 20, 38, 40)
		var was_hovered = _hovered
		_hovered = rect.has_point(mm.position)
		if was_hovered != _hovered:
			queue_redraw()
			
	elif event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var rect = Rect2(global_position.x - 19, global_position.y - 20, 38, 40)
			if rect.has_point(mb.position):
				get_viewport().set_input_as_handled()
				_open_calendar()

func _open_calendar() -> void:
	var scene = get_tree().current_scene
	if scene.has_node("CalendarPopup"):
		return
	Audio.play("paper_rustle", 0.9, -2.0)
	var popup = preload("res://scripts/desk/CalendarPopup.gd").new()
	popup.name = "CalendarPopup"
	scene.add_child(popup)
	popup.build(_font)
