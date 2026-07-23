extends Node2D

class_name MapEditor

static var selected_map_path: String = ""

@onready var grid_overlay = $GridOverlay

@onready var save_name_input = $CanvasLayerUI/TopBar/MarginContainer/HBoxContainer/MapNameInput
@onready var save_status_label = $CanvasLayerUI/TopBar/MarginContainer/HBoxContainer/StatusLabel
@onready var label_dimensions = $CanvasLayerUI/TopBar/MarginContainer/HBoxContainer/LabelDimensions

@onready var top_bar = $CanvasLayerUI/TopBar
@onready var editor_toolbar = $CanvasLayerUI/EditorToolBar

@onready var btn_tool_brush = $CanvasLayerUI/EditorToolBar/MarginContainer/HBoxContainer/BtnToolBrush
@onready var btn_tool_eraser = $CanvasLayerUI/EditorToolBar/MarginContainer/HBoxContainer/BtnToolEraser
@onready var btn_tool_units = $CanvasLayerUI/EditorToolBar/MarginContainer/HBoxContainer/BtnToolUnits

@onready var size_container = $CanvasLayerUI/EditorToolBar/MarginContainer/HBoxContainer/SizeContainer
@onready var btn_size_1 = $CanvasLayerUI/EditorToolBar/MarginContainer/HBoxContainer/SizeContainer/BtnSize1
@onready var btn_size_2 = $CanvasLayerUI/EditorToolBar/MarginContainer/HBoxContainer/SizeContainer/BtnSize2
@onready var btn_size_3 = $CanvasLayerUI/EditorToolBar/MarginContainer/HBoxContainer/SizeContainer/BtnSize3

@onready var units_container = $CanvasLayerUI/EditorToolBar/MarginContainer/HBoxContainer/UnitsContainer
@onready var btn_player_1 = $CanvasLayerUI/EditorToolBar/MarginContainer/HBoxContainer/UnitsContainer/BtnPlayer1
@onready var btn_player_2 = $CanvasLayerUI/EditorToolBar/MarginContainer/HBoxContainer/UnitsContainer/BtnPlayer2
@onready var btn_unit_king = $CanvasLayerUI/EditorToolBar/MarginContainer/HBoxContainer/UnitsContainer/BtnUnitKing
@onready var btn_unit_marine = $CanvasLayerUI/EditorToolBar/MarginContainer/HBoxContainer/UnitsContainer/BtnUnitMarine
@onready var btn_unit_zealot = $CanvasLayerUI/EditorToolBar/MarginContainer/HBoxContainer/UnitsContainer/BtnUnitZealot
@onready var btn_unit_zergling = $CanvasLayerUI/EditorToolBar/MarginContainer/HBoxContainer/UnitsContainer/BtnUnitZergling

@onready var dim_overlay = $CanvasLayerUI/DimOverlay
@onready var load_map_panel = $CanvasLayerUI/LoadMapPanel
@onready var map_load_option_button = $CanvasLayerUI/LoadMapPanel/MarginContainer/VBoxContainer/MapLoadOptionButton

var current_tool: String = "BRUSH" # "BRUSH", "ERASER", "UNITS"
var current_brush_size: int = 1 # 1, 2, 3
var selected_unit_type: String = "marine"
var selected_player_index: int = 0

var is_left_clicking: bool = false
var active_hexes: Dictionary = {} # Vector2i(i, j) -> Hex Node2D
var available_editor_maps: Array = []

func _ready() -> void:
	dim_overlay.visible = false
	load_map_panel.visible = false
	active_hexes.clear()
	
	var map_data: Dictionary = {}
	if not selected_map_path.is_empty():
		map_data = MapSerializer.load_map(selected_map_path)
		if not map_data.is_empty() and save_name_input and map_data.has("name"):
			save_name_input.text = map_data.get("name")
	
	if not map_data.is_empty():
		apply_map_data(map_data)
	else:
		for i in range(6):
			for j in range(6):
				get_or_create_hex(Vector2i(i, j))

	_on_tool_brush_pressed()
	_on_size_1_pressed()
	_on_player_1_pressed()
	_on_unit_marine_pressed()
	update_overlay()

func update_dimensions_label() -> void:
	if label_dimensions:
		label_dimensions.text = str(active_hexes.size()) + " Hexes"

func update_overlay() -> void:
	if grid_overlay:
		grid_overlay.update_bounds_from_coords(active_hexes.keys(), active_hexes)
	update_dimensions_label()

func is_mouse_over_ui() -> bool:
	var mouse_pos = get_viewport().get_mouse_position()
	if top_bar and top_bar.visible and top_bar.get_global_rect().has_point(mouse_pos):
		return true
	if editor_toolbar and editor_toolbar.visible and editor_toolbar.get_global_rect().has_point(mouse_pos):
		return true
	if load_map_panel and load_map_panel.visible and load_map_panel.get_global_rect().has_point(mouse_pos):
		return true
	return false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_left_clicking = event.pressed
		if is_left_clicking and not is_mouse_over_ui():
			var mouse_pos = get_global_mouse_position()
			var coord = ShapeGenerator.world_to_hex(mouse_pos)
			apply_tool_at_coord(coord)
			
	elif event is InputEventMouseMotion:
		if not is_mouse_over_ui():
			var mouse_pos = get_global_mouse_position()
			var coord = ShapeGenerator.world_to_hex(mouse_pos)
			if grid_overlay:
				grid_overlay.update_hover_coord(coord)
			if is_left_clicking and (current_tool == "BRUSH" or current_tool == "ERASER"):
				apply_tool_at_coord(coord)
		else:
			if grid_overlay:
				grid_overlay.update_hover_coord(Vector2i(999999, 999999))

func get_or_create_hex(coord: Vector2i) -> Node2D:
	if active_hexes.has(coord):
		return active_hexes[coord]
		
	var hex = load("res://src/hex/hex.tscn").instantiate()
	hex.name = str(coord.x) + "," + str(coord.y)
	hex.i = coord.x
	hex.j = coord.y
	hex.hex_pressed.connect(on_hex_pressed)
	hex.hex_hovered.connect(on_hex_hovered)
	hex.position = ShapeGenerator.hex_to_world(coord.x, coord.y)
	hex.activated = true
	hex.visible = true
	hex.set_modulate(Color(1, 1, 1, 1))
	
	active_hexes[coord] = hex
	add_child(hex)
	reconnect_all_neighbors()
	update_overlay()
	return hex

func remove_hex(coord: Vector2i) -> void:
	if active_hexes.has(coord):
		var hex = active_hexes[coord]
		if hex.unit:
			hex.unit.queue_free()
			hex.unit = null
		active_hexes.erase(coord)
		hex.queue_free()
		reconnect_all_neighbors()
		update_overlay()

func reconnect_all_neighbors() -> void:
	for coord in active_hexes.keys():
		var hex = active_hexes[coord]
		hex.up_left = active_hexes.get(Vector2i(coord.x - 1, coord.y))
		hex.up_center = active_hexes.get(Vector2i(coord.x - 1, coord.y + 1))
		hex.up_right = active_hexes.get(Vector2i(coord.x, coord.y + 1))
		hex.down_left = active_hexes.get(Vector2i(coord.x, coord.y - 1))
		hex.down_center = active_hexes.get(Vector2i(coord.x + 1, coord.y - 1))
		hex.down_right = active_hexes.get(Vector2i(coord.x + 1, coord.y))

func _on_expand_canvas_pressed() -> void:
	var coords = active_hexes.keys()
	if coords.is_empty():
		for i in range(6):
			for j in range(6):
				get_or_create_hex(Vector2i(i, j))
		return
		
	var min_i = coords[0].x
	var max_i = coords[0].x
	var min_j = coords[0].y
	var max_j = coords[0].y
	for c in coords:
		min_i = min(min_i, c.x)
		max_i = max(max_i, c.x)
		min_j = min(min_j, c.y)
		max_j = max(max_j, c.y)
		
	for i in range(min_i - 1, max_i + 2):
		for j in range(min_j - 1, max_j + 2):
			get_or_create_hex(Vector2i(i, j))

func _on_clear_canvas_pressed() -> void:
	for coord in active_hexes.keys():
		var hex = active_hexes[coord]
		if hex.unit:
			hex.unit.queue_free()
		hex.queue_free()
	active_hexes.clear()
	update_overlay()

func clear_units() -> void:
	for coord in active_hexes.keys():
		var hex = active_hexes[coord]
		if hex and hex.unit:
			hex.unit.queue_free()
			hex.unit = null

func apply_map_data(map_data: Dictionary) -> void:
	_on_clear_canvas_pressed()
	
	var active_coords = map_data.get("active_hexes", [])
	for coord in active_coords:
		var i = int(coord[0])
		var j = int(coord[1])
		get_or_create_hex(Vector2i(i, j))

	var saved_units = map_data.get("units", [])
	for unit_data in saved_units:
		var i = int(unit_data.get("i", 0))
		var j = int(unit_data.get("j", 0))
		var unit_type = str(unit_data.get("unit_type", "marine"))
		var player_idx = int(unit_data.get("player_index", 0))
		var hex = get_or_create_hex(Vector2i(i, j))
		spawn_unit_at(hex, unit_type, player_idx)

func spawn_unit_at(hex, unit_type: String, player_idx: int) -> void:
	var clean_type = unit_type.to_lower()
	if clean_type == "ling":
		clean_type = "zergling"
		
	var unit_scene = load("res://src/units/unit.tscn").instantiate()
	var stats_path = "res://src/units/resources/" + clean_type + "_stats.tres"
	
	if ResourceLoader.exists(stats_path):
		unit_scene.stats = load(stats_path)
		
	unit_scene.set_player_index(player_idx)
	unit_scene.set_hex(hex)
	add_child(unit_scene)

# Tool Mode Selection
func _on_tool_brush_pressed() -> void:
	current_tool = "BRUSH"
	reset_tool_button_styles()
	btn_tool_brush.set_modulate(Color(1, 1, 0.4, 1))
	size_container.visible = true
	units_container.visible = false

func _on_tool_eraser_pressed() -> void:
	current_tool = "ERASER"
	reset_tool_button_styles()
	btn_tool_eraser.set_modulate(Color(1, 1, 0.4, 1))
	size_container.visible = true
	units_container.visible = false

func _on_tool_units_pressed() -> void:
	current_tool = "UNITS"
	reset_tool_button_styles()
	btn_tool_units.set_modulate(Color(1, 1, 0.4, 1))
	size_container.visible = false
	units_container.visible = true

func reset_tool_button_styles() -> void:
	btn_tool_brush.set_modulate(Color(1, 1, 1, 1))
	btn_tool_eraser.set_modulate(Color(1, 1, 1, 1))
	btn_tool_units.set_modulate(Color(1, 1, 1, 1))

# Brush Size Selection
func _on_size_1_pressed() -> void:
	current_brush_size = 1
	btn_size_1.set_modulate(Color(1, 1, 0.4, 1))
	btn_size_2.set_modulate(Color(1, 1, 1, 1))
	btn_size_3.set_modulate(Color(1, 1, 1, 1))

func _on_size_2_pressed() -> void:
	current_brush_size = 2
	btn_size_1.set_modulate(Color(1, 1, 1, 1))
	btn_size_2.set_modulate(Color(1, 1, 0.4, 1))
	btn_size_3.set_modulate(Color(1, 1, 1, 1))

func _on_size_3_pressed() -> void:
	current_brush_size = 3
	btn_size_1.set_modulate(Color(1, 1, 1, 1))
	btn_size_2.set_modulate(Color(1, 1, 1, 1))
	btn_size_3.set_modulate(Color(1, 1, 0.4, 1))

# Player Selection
func _on_player_1_pressed() -> void:
	selected_player_index = 0
	btn_player_1.set_modulate(Color(1, 1, 0.4, 1))
	btn_player_2.set_modulate(Color(1, 1, 1, 1))

func _on_player_2_pressed() -> void:
	selected_player_index = 1
	btn_player_1.set_modulate(Color(1, 1, 1, 1))
	btn_player_2.set_modulate(Color(1, 1, 0.4, 1))

# Unit Selection
func _on_unit_king_pressed() -> void:
	selected_unit_type = "king"
	highlight_unit_button(btn_unit_king)

func _on_unit_marine_pressed() -> void:
	selected_unit_type = "marine"
	highlight_unit_button(btn_unit_marine)

func _on_unit_zealot_pressed() -> void:
	selected_unit_type = "zealot"
	highlight_unit_button(btn_unit_zealot)

func _on_unit_zergling_pressed() -> void:
	selected_unit_type = "zergling"
	highlight_unit_button(btn_unit_zergling)

func highlight_unit_button(target_btn) -> void:
	btn_unit_king.set_modulate(Color(1, 1, 1, 1))
	btn_unit_marine.set_modulate(Color(1, 1, 1, 1))
	btn_unit_zealot.set_modulate(Color(1, 1, 1, 1))
	btn_unit_zergling.set_modulate(Color(1, 1, 1, 1))
	target_btn.set_modulate(Color(1, 1, 0.4, 1))

func get_coords_in_radius(center: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var max_range = radius + 2
	for i in range(center.x - max_range, center.x + max_range + 1):
		for j in range(center.y - max_range, center.y + max_range + 1):
			if ShapeGenerator.hex_distance(center.x, center.y, i, j) <= radius:
				result.append(Vector2i(i, j))
	return result

func apply_tool_at_coord(center_coord: Vector2i) -> void:
	if current_tool == "BRUSH":
		var r = 0 if current_brush_size == 1 else (1 if current_brush_size == 2 else 2)
		for c in get_coords_in_radius(center_coord, r):
			get_or_create_hex(c)

	elif current_tool == "ERASER":
		var r = 0 if current_brush_size == 1 else (1 if current_brush_size == 2 else 2)
		for c in get_coords_in_radius(center_coord, r):
			remove_hex(c)

	elif current_tool == "UNITS":
		var hex = get_or_create_hex(center_coord)
		if hex.unit:
			hex.unit.queue_free()
			hex.unit = null
		else:
			spawn_unit_at(hex, selected_unit_type, selected_player_index)

func on_hex_pressed(hex) -> void:
	if hex and not is_mouse_over_ui():
		apply_tool_at_coord(Vector2i(hex.i, hex.j))

func on_hex_hovered(hex) -> void:
	if hex and is_left_clicking and not is_mouse_over_ui():
		if current_tool == "BRUSH" or current_tool == "ERASER":
			apply_tool_at_coord(Vector2i(hex.i, hex.j))

func _on_save_map_pressed() -> void:
	var map_name = save_name_input.text.strip_edges()
	if map_name.is_empty():
		map_name = "MiMapa"
	
	var coords = active_hexes.keys()
	if coords.is_empty():
		save_status_label.text = "¡El mapa está vacío!"
		return
		
	var min_i = coords[0].x
	var max_i = coords[0].x
	var min_j = coords[0].y
	var max_j = coords[0].y
	var active_list: Array = []
	
	for c in coords:
		min_i = min(min_i, c.x)
		max_i = max(max_i, c.x)
		min_j = min(min_j, c.y)
		max_j = max(max_j, c.y)
		active_list.append([c.x, c.y])
		
	var width_val = max_i - min_i + 1
	var height_val = max_j - min_j + 1
	
	var units_data: Array = []
	for c in coords:
		var hex = active_hexes[c]
		if hex and hex.unit:
			var unit_type = "marine"
			if hex.unit.stats:
				unit_type = hex.unit.stats.unit_name.to_lower()
			elif not hex.unit.scene_file_path.is_empty():
				unit_type = hex.unit.scene_file_path.get_file().get_basename().to_lower()
			else:
				unit_type = hex.unit.name.to_lower()
			
			if unit_type == "ling":
				unit_type = "zergling"
				
			units_data.append({
				"i": c.x,
				"j": c.y,
				"unit_type": unit_type,
				"player_index": hex.unit.player_index
			})
	
	var saved_path = MapSerializer.save_map(map_name, max(6, width_val + max_i), max(6, height_val + max_j), active_list, units_data)
	if not saved_path.is_empty():
		save_status_label.text = "¡Mapa guardado exitosamente!"
	else:
		save_status_label.text = "Error al guardar mapa."

func _on_load_map_pressed() -> void:
	map_load_option_button.clear()
	available_editor_maps = MapSerializer.list_maps()
	if available_editor_maps.is_empty():
		save_status_label.text = "No se encontraron mapas guardados."
		return
	
	for map_info in available_editor_maps:
		map_load_option_button.add_item(map_info.get("name", "Mapa Sin Nombre"))
	
	dim_overlay.visible = true
	load_map_panel.visible = true

func _on_confirm_load_pressed() -> void:
	if available_editor_maps.is_empty():
		return
	
	var selected_idx = map_load_option_button.selected
	if selected_idx >= 0 and selected_idx < available_editor_maps.size():
		var chosen_map = available_editor_maps[selected_idx]
		var map_data = MapSerializer.load_map(chosen_map.get("path", ""))
		if not map_data.is_empty():
			apply_map_data(map_data)
			if map_data.has("name"):
				save_name_input.text = map_data.get("name")
			save_status_label.text = "¡Mapa cargado exitosamente!"
	
	dim_overlay.visible = false
	load_map_panel.visible = false

func _on_cancel_load_pressed() -> void:
	dim_overlay.visible = false
	load_map_panel.visible = false

func _on_back_to_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")
