extends Node2D
class_name GridOverlay

var min_i: int = -3
var max_i: int = 8
var min_j: int = -3
var max_j: int = 8

var active_coords_set: Dictionary = {}
var hovered_coord: Vector2i = Vector2i(999999, 999999)

# Flat-topped hexagon 6 corners matching flat-top orientation of hexagon.png
const HOLLOW_HEX_POINTS = [
	Vector2(-173, -346),
	Vector2(173, -346),
	Vector2(346, 0),
	Vector2(173, 346),
	Vector2(-173, 346),
	Vector2(-346, 0),
	Vector2(-173, -346)
]

func update_bounds_from_coords(coords: Array, active_set: Dictionary = {}, margin: int = 2) -> void:
	active_coords_set = active_set
	if coords.is_empty():
		min_i = -2
		max_i = 7
		min_j = -2
		max_j = 7
	else:
		var first = coords[0]
		min_i = first.x
		max_i = first.x
		min_j = first.y
		max_j = first.y
		for c in coords:
			min_i = min(min_i, c.x)
			max_i = max(max_i, c.x)
			min_j = min(min_j, c.y)
			max_j = max(max_j, c.y)
		
		min_i -= margin
		max_i += margin
		min_j -= margin
		max_j += margin
	
	queue_redraw()

func update_hover_coord(coord: Vector2i) -> void:
	if hovered_coord != coord:
		hovered_coord = coord
		queue_redraw()

func _draw() -> void:
	var outline_color = Color(0.35, 0.65, 1.0, 0.35)
	var default_line_width = 3.5
	
	var hover_fill_color = Color(0.4, 0.75, 1.0, 0.28)
	var hover_border_color = Color(0.6, 0.9, 1.0, 0.95)
	var hover_line_width = 6.0

	# 1. Draw standard guide grid around active bounds
	for i in range(min_i, max_i + 1):
		for j in range(min_j, max_j + 1):
			var coord = Vector2i(i, j)
			var center = ShapeGenerator.hex_to_world(i, j)
			var poly_points = PackedVector2Array()
			for pt in HOLLOW_HEX_POINTS:
				poly_points.append(center + pt)
			
			var is_hovered = (coord == hovered_coord)
			var is_active = active_coords_set.has(coord)
			
			if is_hovered:
				if not is_active:
					draw_colored_polygon(poly_points, hover_fill_color)
				draw_polyline(poly_points, hover_border_color, hover_line_width)
			elif not is_active:
				draw_polyline(poly_points, outline_color, default_line_width)

	# 2. Always draw hover highlight even if hovered_coord is OUTSIDE the grid bounds!
	if hovered_coord.x != 999999 and hovered_coord.y != 999999:
		var inside_loop = (hovered_coord.x >= min_i and hovered_coord.x <= max_i and hovered_coord.y >= min_j and hovered_coord.y <= max_j)
		if not inside_loop:
			var center = ShapeGenerator.hex_to_world(hovered_coord.x, hovered_coord.y)
			var poly_points = PackedVector2Array()
			for pt in HOLLOW_HEX_POINTS:
				poly_points.append(center + pt)
			
			var is_active = active_coords_set.has(hovered_coord)
			if not is_active:
				draw_colored_polygon(poly_points, hover_fill_color)
			draw_polyline(poly_points, hover_border_color, hover_line_width)
