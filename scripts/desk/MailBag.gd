extends Node2D

var _font
var is_hovered := false
var _flap_lift := 0.0

func build(font) -> void:
	_font = font
	position = Vector2(30, 95)
	queue_redraw()

func set_hovered(h: bool) -> void:
	if is_hovered != h:
		is_hovered = h
		if is_hovered:
			Audio.play("paper_rustle", 0.6, -2.0)
		set_process(true)

func _process(delta: float) -> void:
	var target = 1.0 if is_hovered else 0.0
	if not is_equal_approx(_flap_lift, target):
		_flap_lift = move_toward(_flap_lift, target, delta * 5.0)
		queue_redraw()
	else:
		if target == 0.0:
			set_process(false)

func _draw() -> void:
	var bag_w = 90.0
	var bag_h = 60.0
	
	# New Briefcase palette
	var c_outline = Color(0.04, 0.02, 0.02)
	var c_base = Color(0.35, 0.11, 0.11)       # Dark maroon/red base
	var c_base_light = Color(0.40, 0.13, 0.13)
	var c_flap = Color(0.55, 0.31, 0.16)       # Medium brown flap
	var c_trim = Color(0.85, 0.65, 0.35)       # Tan/gold trim
	var c_strap = Color(0.12, 0.08, 0.06)      # Very dark brown/black straps
	var c_buckle_gold = Color(0.75, 0.55, 0.25)
	var c_interior = Color(0.15, 0.05, 0.05)   # Dark interior
	
	# Drop Shadow (hanging on wall)
	draw_rect(Rect2(4, 6, bag_w + 10, bag_h), Color(0, 0, 0, 0.3))
	
	# Shoulder Strap (Side)
	var strap_pts = PackedVector2Array([
		Vector2(-5, bag_h * 0.6), Vector2(-15, bag_h * 0.9), Vector2(10, bag_h),
		Vector2(bag_w + 5, bag_h * 0.5), Vector2(bag_w + 15, bag_h * 0.8), Vector2(bag_w - 5, bag_h)
	])
	draw_polygon(strap_pts, PackedColorArray([c_outline, c_outline, c_outline, c_outline, c_outline, c_outline]))
	var strap_inner = PackedVector2Array([
		Vector2(-3, bag_h * 0.6 + 2), Vector2(-12, bag_h * 0.9 - 2), Vector2(8, bag_h - 2),
		Vector2(bag_w + 3, bag_h * 0.5 + 2), Vector2(bag_w + 12, bag_h * 0.8 - 2), Vector2(bag_w - 3, bag_h - 2)
	])
	draw_polygon(strap_inner, PackedColorArray([c_strap, c_strap, c_strap, c_strap, c_strap, c_strap]))

	# --- BACK HALF (Visible when open) ---
	var back_y = 12.0
	# Interior hole
	var interior_rect = Rect2(0, back_y - 8, bag_w, 20)
	draw_rect(interior_rect, c_outline)
	draw_rect(Rect2(2, back_y - 6, bag_w - 4, 18), c_interior)

	# --- LOWER BODY ---
	var body_rect = Rect2(0, back_y + 10, bag_w, bag_h - 22)
	draw_rect(body_rect, c_outline)
	draw_rect(Rect2(2, back_y + 12, bag_w - 4, bag_h - 26), c_base)
	draw_rect(Rect2(2, back_y + 12, bag_w - 4, 4), c_base_light) # Highlight
	# Lower trim line
	draw_rect(Rect2(0, bag_h - 12, bag_w, 4), c_outline)
	draw_rect(Rect2(0, bag_h - 11, bag_w, 2), c_trim)
	
	# --- TOP FLAP (Animates up when hovering) ---
	# _flap_lift goes from 0.0 (closed) to 1.0 (open)
	var lift_offset = Vector2(0, -25.0 * _flap_lift)
	var flap_h = 35.0
	var flap_y = back_y + lift_offset.y
	
	var flap_rect = Rect2(0, flap_y, bag_w, flap_h)
	draw_rect(flap_rect, c_outline)
	draw_rect(Rect2(2, flap_y + 2, bag_w - 4, flap_h - 4), c_flap)
	
	# Flap Trim
	draw_rect(Rect2(4, flap_y + 4, bag_w - 8, flap_h - 8), c_trim, false, 2.0)
	
	# Vertical Straps on Flap
	var s_w = 8.0
	var sx1 = 18.0
	var sx2 = bag_w - 18.0 - s_w
	
	# Left Strap
	draw_rect(Rect2(sx1, flap_y, s_w, flap_h - 6), c_outline)
	draw_rect(Rect2(sx1 + 2, flap_y, s_w - 4, flap_h - 6), c_trim)
	draw_rect(Rect2(sx1 + 4, flap_y, s_w - 8, flap_h - 6), c_outline) # Center line
	
	# Right Strap
	draw_rect(Rect2(sx2, flap_y, s_w, flap_h - 6), c_outline)
	draw_rect(Rect2(sx2 + 2, flap_y, s_w - 4, flap_h - 6), c_trim)
	draw_rect(Rect2(sx2 + 4, flap_y, s_w - 8, flap_h - 6), c_outline)
	
	# Top Handle (attached to flap)
	var hw = 24.0
	var hh = 10.0
	var hx = (bag_w - hw) / 2
	var hy = flap_y - hh
	draw_rect(Rect2(hx, hy, hw, hh), c_outline)
	draw_rect(Rect2(hx + 2, hy + 2, hw - 4, hh - 2), c_strap)
	# Handle hole
	draw_rect(Rect2(hx + 6, hy + 4, hw - 12, hh - 4), c_outline)
	draw_rect(Rect2(hx + 8, hy + 6, hw - 16, hh - 6), Color(0,0,0,0)) # Transparent hole isn't possible by drawing over, so we simulate the back
	# Instead of transparent hole, draw the wall behind it or let it just be dark
	draw_rect(Rect2(hx + 6, hy + 4, hw - 12, hh - 4), Color(0.7, 0.6, 0.5)) # Wall color approx
	
	# Handle mounts
	draw_rect(Rect2(hx - 4, flap_y, 8, 4), c_outline)
	draw_rect(Rect2(hx - 2, flap_y, 4, 4), c_strap)
	draw_rect(Rect2(hx + hw - 4, flap_y, 8, 4), c_outline)
	draw_rect(Rect2(hx + hw - 2, flap_y, 4, 4), c_strap)
	
	# Buckles (Black rectangles with gold pins)
	# These stay mostly fixed on the body, but the straps slide through them.
	# When flap lifts, the strap pulls out. We can just draw the buckles on the flap if they are attached,
	# or on the body. Usually buckles are on the body. Let's draw them on the flap for simplicity, 
	# but overlapping the edge.
	var bx1 = sx1 - 4
	var bx2 = sx2 - 4
	var by_buckle = flap_y + flap_h - 16
	# Left Buckle
	draw_rect(Rect2(bx1, by_buckle, 16, 12), c_outline)
	draw_rect(Rect2(bx1 + 2, by_buckle + 2, 12, 8), c_strap) # Black buckle body
	draw_rect(Rect2(bx1 + 4, by_buckle + 4, 8, 4), c_buckle_gold) # Gold inner
	draw_rect(Rect2(bx1 + 6, by_buckle + 6, 4, 2), c_strap) # Hole
	
	# Right Buckle
	draw_rect(Rect2(bx2, by_buckle, 16, 12), c_outline)
	draw_rect(Rect2(bx2 + 2, by_buckle + 2, 12, 8), c_strap)
	draw_rect(Rect2(bx2 + 4, by_buckle + 4, 8, 4), c_buckle_gold)
	draw_rect(Rect2(bx2 + 6, by_buckle + 6, 4, 2), c_strap)
	
	# Lower strap pieces (on the body, sticking out below the flap)
	var low_strap_y = back_y + flap_h - 2
	draw_rect(Rect2(sx1, low_strap_y, s_w, 14), c_outline)
	draw_rect(Rect2(sx1 + 2, low_strap_y, s_w - 4, 12), c_trim)
	draw_rect(Rect2(sx2, low_strap_y, s_w, 14), c_outline)
	draw_rect(Rect2(sx2 + 2, low_strap_y, s_w - 4, 12), c_trim)
	# Little gold pegs
	draw_rect(Rect2(sx1 + 3, low_strap_y + 8, 2, 2), c_buckle_gold)
	draw_rect(Rect2(sx2 + 3, low_strap_y + 8, 2, 2), c_buckle_gold)

	if _font:
		var txt = "POST"
		var tw = _font.width_of(txt)
		_font.draw_text(self, txt, Vector2((bag_w - tw)/2.0, flap_y + 18), Color(0.2, 0.1, 0.05, 0.5))
