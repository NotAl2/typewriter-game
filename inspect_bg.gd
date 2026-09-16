extends SceneTree

func _init() -> void:
	var img = Image.new()
	var err = img.load("res://assets/art/bg_room.png")
	if err != OK:
		print("Failed to load bg_room.png")
		quit()
		return
		
	print("Size: ", img.get_width(), "x", img.get_height())
	
	var min_x = 9999
	var max_x = 0
	var min_y = 9999
	var max_y = 0
	
	for y in range(img.get_height()):
		for x in range(img.get_width() / 2, img.get_width()):
			var c = img.get_pixel(x, y)
			# Look for dark blueish
			if c.b > c.r + 0.05 and c.b > c.g + 0.05 and c.b < 0.6:
				if x < min_x: min_x = x
				if x > max_x: max_x = x
				if y < min_y: min_y = y
				if y > max_y: max_y = y
				
	print("Window bounds: x=", min_x, "-", max_x, ", y=", min_y, "-", max_y)
	
	var wood_colors = {}
	if min_x < max_x:
		for y in range(min_y, max_y):
			for x in range(min_x, max_x):
				var c = img.get_pixel(x, y)
				if not (c.b > c.r + 0.05 and c.b > c.g + 0.05 and c.b < 0.6):
					var key = "%s,%s,%s" % [int(c.r*255), int(c.g*255), int(c.b*255)]
					wood_colors[key] = true
	print("Wood colors: ", wood_colors.keys())
	quit()
