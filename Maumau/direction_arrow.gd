extends Control

class_name DirectionArrow

var pointing_left: bool = true:
	set(v):
		pointing_left = v
		queue_redraw()

func _init():
	custom_minimum_size = Vector2(55, 55)

func _draw():
	var w = size.x
	var h = size.y
	var mid_y = h / 2.0

	# Draw Arrow
	if pointing_left:
		# Green (Clockwise)
		var color = Color(0.2, 0.8, 0.2) 
		# Head (Triangle pointing Left)
		var points = PackedVector2Array([
			Vector2(0, mid_y),
			Vector2(w * 0.4, 0),
			Vector2(w * 0.4, h)
		])
		draw_colored_polygon(points, color)
		# Shaft (Rect)
		draw_rect(Rect2(w * 0.4, h * 0.3, w * 0.6, h * 0.4), color)
	else:
		# Red (Counter-Clockwise)
		var color = Color(0.9, 0.2, 0.2) 
		# Head (Triangle pointing Right)
		var points = PackedVector2Array([
			Vector2(w, mid_y),
			Vector2(w * 0.6, 0),
			Vector2(w * 0.6, h)
		])
		draw_colored_polygon(points, color)
		# Shaft (Rect)
		draw_rect(Rect2(0, h * 0.3, w * 0.6, h * 0.4), color)
