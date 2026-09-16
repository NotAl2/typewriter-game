extends Node2D

var envelope_pos: Vector2
var knife_start_pos: Vector2
var knife_pos: Vector2

var _font: BitmapText
var _env_sprite: Sprite2D
var _seal_node: Node2D
var _pool: Sprite2D
var _impression: Sprite2D
var _blade_node: Node2D

var is_knife_grabbed := false
var slice_progress := 0.0

var _is_sliced := false

signal opened()

func build(font: BitmapText) -> void:
	_font = font
	envelope_pos = Vector2(460, 220)
	knife_start_pos = Vector2(520, 290)
	knife_pos = knife_start_pos
	z_index = 30
	set_process_input(true)
	
	# 1. Envelope (Bottom layer)
	_env_sprite = Sprite2D.new()
	_env_sprite.texture = load("res://assets/art/envelope_closed.png")
	_env_sprite.centered = false
	_env_sprite.position = envelope_pos
	add_child(_env_sprite)
	
	# 2. Blade Node (Middle layer - goes over envelope, under seal)
	_blade_node = Node2D.new()
	# Attach a custom script to the blade node to handle its own drawing safely
	var script = GDScript.new()
	script.source_code = """
extends Node2D
func _draw():
	var pts = PackedVector2Array([
		Vector2(-10, -7), Vector2(10, -7), Vector2(12, -5), Vector2(12, -2),
		Vector2(10, -2), Vector2(10, 2), Vector2(12, 2), Vector2(12, 5),
		Vector2(10, 7), Vector2(-10, 7), Vector2(-12, 5), Vector2(-12, 2),
		Vector2(-10, 2), Vector2(-10, -2), Vector2(-12, -2), Vector2(-12, -5)
	])
	var base_col = Color(0.28, 0.27, 0.25)
	var edge_col = Color(0.45, 0.42, 0.38)
	var rust_col = Color(0.2, 0.14, 0.1)
	var out_col = Color(0.12, 0.1, 0.08)
	draw_polygon(pts, PackedColorArray([base_col]))
	draw_line(Vector2(-6, 6), Vector2(6, -6), edge_col, 2.0)
	draw_line(Vector2(-10, 2), Vector2(-2, -6), edge_col, 1.0)
	draw_line(Vector2(2, 6), Vector2(10, -2), edge_col, 1.0)
	draw_line(Vector2(-8, -4), Vector2(-6, -5), rust_col, 1.0)
	draw_line(Vector2(5, 4), Vector2(8, 3), rust_col, 1.0)
	draw_line(Vector2(-4, 5), Vector2(-2, 4), rust_col, 2.0)
	pts.append(pts[0])
	draw_polyline(pts, out_col, 1.0)
	var hole_col = Color(0.1, 0.08, 0.06, 0.9)
	draw_rect(Rect2(-7, -1, 14, 2), hole_col)
	draw_rect(Rect2(-2, -3, 4, 6), hole_col)
	draw_rect(Rect2(-8, -2, 2, 4), hole_col)
	draw_rect(Rect2(6, -2, 2, 4), hole_col)
"""
	script.reload()
	_blade_node.set_script(script)
	add_child(_blade_node)
	_blade_node.position = knife_pos
	
	# 3. Seal Node (Top layer)
	_seal_node = Node2D.new()
	_seal_node.position = envelope_pos + Vector2(Layout.WAX_POOL_OX, Layout.WAX_POOL_OY)
	add_child(_seal_node)
	
	_pool = Sprite2D.new()
	_pool.texture = load("res://assets/art/wax_pool.png")
	_pool.centered = true
	_pool.region_enabled = true
	_pool.region_rect = Rect2(5 * Layout.WAX_POOL_W, 3 * Layout.WAX_POOL_H, Layout.WAX_POOL_W, Layout.WAX_POOL_H)
	_seal_node.add_child(_pool)
	
	_impression = Sprite2D.new()
	_impression.texture = load("res://assets/art/seal_impressions.png")
	_impression.region_enabled = true
	var cell = _impression.texture.get_height()
	_impression.region_rect = Rect2(0, 0, cell, cell)
	_impression.centered = true
	_seal_node.add_child(_impression)
	
	# Prompt the player
	var t = Timer.new()
	t.wait_time = 0.5
	t.one_shot = true
	add_child(t)
	t.start()
	await t.timeout
	Audio.play("paper_slide", 0.9, -2.0)

func _draw() -> void:
	if _is_sliced:
		return
		
	var w = Layout.ENVELOPE_W
	var h = Layout.ENVELOPE_H
	
	var seal_pos = envelope_pos + Vector2(Layout.WAX_POOL_OX, Layout.WAX_POOL_OY)
	
	# Slice line on the wax
	if slice_progress > 0.0:
		var slice_start = seal_pos - Vector2(16, 0)
		var slice_end = slice_start + Vector2(32 * slice_progress, 0)
		draw_line(slice_start, slice_end, Color(0.1, 0.1, 0.1, 0.8), 2.0)
	
	if _font and slice_progress == 0.0 and not is_knife_grabbed:
		_font.draw_text(self, "CUT SEAL", envelope_pos + Vector2(25, h + 15), Color(0.8, 0.7, 0.6, 0.7))

func _input(event: InputEvent) -> void:
	if _is_sliced: return
	
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				# grab blade
				var k_rect = Rect2(knife_pos.x - 20, knife_pos.y - 15, 40, 30)
				if k_rect.has_point(mb.position):
					is_knife_grabbed = true
					get_viewport().set_input_as_handled()
			else:
				if is_knife_grabbed:
					is_knife_grabbed = false
					if slice_progress < 1.0:
						knife_pos = knife_start_pos
						_blade_node.position = knife_pos
						slice_progress = 0.0
						queue_redraw()
						
	elif event is InputEventMouseMotion and is_knife_grabbed:
		var mm = event as InputEventMouseMotion
		knife_pos = mm.position
		_blade_node.position = knife_pos
		
		# check slice zone (across the wax seal)
		var seal_pos = envelope_pos + Vector2(Layout.WAX_POOL_OX, Layout.WAX_POOL_OY)
		if abs(knife_pos.y - seal_pos.y) < 20: 
			var progress = clamp((knife_pos.x - (seal_pos.x - 20)) / 40.0, 0.0, 1.0)
			if progress > slice_progress:
				if slice_progress == 0.0:
					Audio.play("stamp_peel", 1.2, -4.0)
				slice_progress = progress
				
			if slice_progress >= 0.95:
				_is_sliced = true
				is_knife_grabbed = false
				_env_sprite.visible = false
				_blade_node.visible = false
				_seal_node.visible = false
				Audio.play("paper_tear", 1.0, -1.0)
				opened.emit()
		queue_redraw()
