extends SceneTree

func _init() -> void:
	print("Checking color mask...")
	var img = Image.new()
	img.load("res://assets/art/bg_room.png")
	
	# Check sky pixel
	var sky = img.get_pixel(550, 70)
	print("Sky: R=", sky.r, " G=", sky.g, " B=", sky.b)
	
	# Check wood pixel (pane)
	var wood = img.get_pixel(550, 60) # roughly, might hit sky
	# let's just sample a few
	print("Checking top right quadrant:")
	for y in range(40, 50):
		for x in range(500, 510):
			var c = img.get_pixel(x,y)
			var is_sky = c.b >= c.r - 0.05
			if not is_sky:
				print("Found Wood: ", c)
				break
	quit()
