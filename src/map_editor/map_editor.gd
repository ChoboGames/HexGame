extends Node2D

class_name MapEditor

# Parámetros estáticos para lanzar la escena desde el Menú Principal
static var selected_map_path: String = ""
static var launch_mode: String = "EDITOR" # "EDITOR" o "GAME"

@export var width = 6
@export var height = 6

@onready var unit_selector = $CanvasLayerUI/EditorToolBar/MarginContainer/HBoxContainer/UnitSelector
@onready var player_selector = $CanvasLayerUI/EditorToolBar/MarginContainer/HBoxContainer/PlayerSelector
@onready var save_name_input = $CanvasLayerUI/TopBar/MarginContainer/HBoxContainer/MapNameInput
@onready var save_status_label = $CanvasLayerUI/TopBar/MarginContainer/HBoxContainer/StatusLabel
@onready var btn_mode_terrain = $CanvasLayerUI/EditorToolBar/MarginContainer/HBoxContainer/BtnModeTerrain
@onready var btn_mode_units = $CanvasLayerUI/EditorToolBar/MarginContainer/HBoxContainer/BtnModeUnits

@onready var top_bar = $CanvasLayerUI/TopBar
@onready var editor_toolbar = $CanvasLayerUI/EditorToolBar
@onready var game_hud = $CanvasLayerUI/GameHUD
@onready var turn_label = $CanvasLayerUI/GameHUD/MarginContainer/HBoxContainer/Turn

@onready var dim_overlay = $CanvasLayerUI/DimOverlay
@onready var load_map_panel = $CanvasLayerUI/LoadMapPanel
@onready var map_load_option_button = $CanvasLayerUI/LoadMapPanel/MarginContainer/VBoxContainer/MapLoadOptionButton

var turn = 0
var distance_objects = {}
var attack_objects = []
var old_hex = null

var game_started = false
var current_tool: String = "TERRAIN" # "TERRAIN" o "UNITS"

var grid = []
var available_editor_maps: Array = []

func print_grid():
	for i in range(height):
		print(grid[i])

func reset_colors():
	for i in range(height):
		for j in range(width):
			if grid[i][j] and grid[i][j].activated:
				grid[i][j].set_modulate(Color(1, 1, 1, 1))

func clear_selection():
	old_hex = null
	distance_objects = {}
	attack_objects = []
	reset_colors()

func show_available_actions(hex):
	var unit = hex.unit
	reset_colors()
	if unit.movement_used < unit.movement:
		distance_objects = $Dijkstra.color_hexagons(hex, unit.movement - unit.movement_used)
	else:
		distance_objects = {}
	if not unit.has_attacked:
		attack_objects = $Dijkstra.color_hexagon_attack(hex, unit.range)
	else:
		attack_objects = []

func _ready():
	dim_overlay.visible = false
	load_map_panel.visible = false
	grid = []
	
	# Cargar datos de mapa si se especificó una ruta
	var map_data: Dictionary = {}
	if not selected_map_path.is_empty():
		map_data = MapSerializer.load_map(selected_map_path)
		if not map_data.is_empty():
			width = map_data.get("width", 6)
			height = map_data.get("height", 6)
			if save_name_input and map_data.has("name"):
				save_name_input.text = map_data.get("name")
	
	# Construir la rejilla de hexágonos
	for i in range(height):
		grid.insert(i, [])
		for j in range(width):
			var hex = load("res://src/hex/hex.tscn").instantiate()
			hex.name = str(i) + "," + str(j)
			hex.i = i
			hex.j = j
			hex.connect("hex_pressed", on_hex_pressed)
			var x = j * 720  + i * 720
			var y = -j * 720 + i * 720
			x *= 4.5 / 6
			y /= 2
			hex.position = Vector2(x, y)
			add_child(hex)
			grid[i].insert(j, hex)

	do_connections()
	
	# Aplicar el mapa cargado o inicializar por defecto
	if not map_data.is_empty():
		apply_map_data(map_data)
	else:
		# Por defecto, todos los hexágonos activados
		for i in range(height):
			for j in range(width):
				grid[i][j].activated = true
				grid[i][j].visible = true

	# Configurar los modos de la UI
	if launch_mode == "GAME":
		start_game_mode()
	else:
		start_editor_mode()

func clear_units():
	for i in range(height):
		for j in range(width):
			var hex = grid[i][j]
			if hex and hex.unit:
				hex.unit.queue_free()
				hex.unit = null

func apply_map_data(map_data: Dictionary):
	clear_units()
	
	var active_hexes = map_data.get("active_hexes", [])
	if active_hexes.size() > 0:
		# Desactivar todos y activar solo los que estén en la lista guardada
		for i in range(height):
			for j in range(width):
				grid[i][j].activated = false
				grid[i][j].visible = false
		
		for coord in active_hexes:
			var i = int(coord[0])
			var j = int(coord[1])
			if i >= 0 and i < height and j >= 0 and j < width:
				grid[i][j].activated = true
				grid[i][j].visible = true
				grid[i][j].set_modulate(Color(1, 1, 1, 1))

	var saved_units = map_data.get("units", [])
	for unit_data in saved_units:
		var i = int(unit_data.get("i", 0))
		var j = int(unit_data.get("j", 0))
		var unit_type = str(unit_data.get("unit_type", "marine"))
		var player_idx = int(unit_data.get("player_index", 0))
		if i >= 0 and i < height and j >= 0 and j < width:
			spawn_unit_at(grid[i][j], unit_type, player_idx)

func spawn_unit_at(hex, unit_type: String, player_idx: int):
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

func start_editor_mode():
	game_started = false
	top_bar.visible = true
	editor_toolbar.visible = true
	game_hud.visible = false
	_on_mode_terrain_pressed()

func start_game_mode():
	game_started = true
	top_bar.visible = false
	editor_toolbar.visible = false
	game_hud.visible = true
	
	# Asegurar visibilidad de casillas activas y ocultar las inactivas
	for i in range(height):
		for j in range(width):
			var hex = grid[i][j]
			hex.visible = hex.activated
			if hex.activated:
				hex.set_modulate(Color(1, 1, 1, 1))
	
	# Reiniciar turno y refrescar todas las unidades para una nueva partida
	turn = 0
	clear_selection()
	if turn_label:
		turn_label.text = str(turn)
	for i in range(height):
		for j in range(width):
			if grid[i][j].unit:
				grid[i][j].unit.refresh()

func _on_mode_terrain_pressed():
	current_tool = "TERRAIN"
	btn_mode_terrain.set_modulate(Color(1, 1, 0.4, 1))
	btn_mode_units.set_modulate(Color(1, 1, 1, 1))
	unit_selector.disabled = true
	player_selector.disabled = true

func _on_mode_units_pressed():
	current_tool = "UNITS"
	btn_mode_terrain.set_modulate(Color(1, 1, 1, 1))
	btn_mode_units.set_modulate(Color(1, 1, 0.4, 1))
	unit_selector.disabled = false
	player_selector.disabled = false

func on_hex_pressed(hex):
	if game_started:
		# Lógica de juego de combate por turnos
		# Re-seleccionar el mismo hex -> deseleccionar
		if old_hex != null and hex == old_hex:
			clear_selection()
			return
		# Si hay unidad seleccionada, intentar ejecutar una acción
		if old_hex != null:
			var unit = old_hex.unit
			if hex in distance_objects:
				# Mover (costo = distancia recorrida en hexágonos)
				var cost = distance_objects[hex]
				old_hex.unit = null
				unit.set_hex(hex)
				unit.movement_used += cost
				unit.update_action_visual()
				old_hex = hex
				# Selección persistente si aún puede actuar
				if unit.movement_used < unit.movement or not unit.has_attacked:
					show_available_actions(hex)
				else:
					clear_selection()
				return
			elif hex in attack_objects:
				# Atacar
				unit.attack(hex.unit)
				unit.has_attacked = true
				unit.update_action_visual()
				# Selección persistente si aún puede mover
				if unit.movement_used < unit.movement:
					show_available_actions(old_hex)
				else:
					clear_selection()
				return
			else:
				# Click en otro lado: limpiar selección y caer a selección
				clear_selection()
		# Selección: unidad del jugador actual que aún pueda actuar
		if hex.unit and hex.unit.player_index == turn and not hex.unit.is_exhausted():
			old_hex = hex
			show_available_actions(hex)
	else:
		# Lógica del Editor de Mapas
		if current_tool == "TERRAIN":
			hex.activated = !hex.activated
			hex.visible = true
			if hex.activated:
				hex.set_modulate(Color(1, 1, 1, 1))
			else:
				hex.set_modulate(Color(0.4, 0.4, 0.4, 0.4))
		elif current_tool == "UNITS":
			if not hex.activated:
				hex.activated = true
				hex.visible = true
				hex.set_modulate(Color(1, 1, 1, 1))
				
			if hex.unit:
				hex.unit.queue_free()
				hex.unit = null
			else:
				var unit_name = unit_selector.get_item_text(unit_selector.selected).to_lower()
				spawn_unit_at(hex, unit_name, player_selector.selected)

func connect_up_left(i, j):
	var hex = grid[i][j]
	if i == 0: return
	hex.up_left = grid[i - 1][j]

func connect_up_center(i, j):
	var hex = grid[i][j]
	if i == 0 or j == width - 1: return
	hex.up_center = grid[i - 1][j + 1]

func connect_up_right(i, j):
	var hex = grid[i][j]
	if j == width - 1: return
	hex.up_right = grid[i][j + 1]

func connect_down_left(i, j):
	var hex = grid[i][j]
	if j == 0: return
	hex.down_left = grid[i][j - 1]

func connect_down_center(i, j):
	var hex = grid[i][j]
	if j == 0 or i == height - 1: return
	hex.down_center = grid[i + 1][j - 1]

func connect_down_right(i, j):
	var hex = grid[i][j]
	if i == height - 1: return
	hex.down_right = grid[i + 1][j]

func do_connections():
	for i in range(height):
		for j in range(width):
			connect_up_left(i, j)
			connect_up_center(i, j)
			connect_up_right(i, j)
			connect_down_left(i, j)
			connect_down_center(i, j)
			connect_down_right(i, j)

func _on_finish_turn_pressed():
	clear_selection()
	turn = int(!turn)
	if turn_label:
		turn_label.text = str(turn)
	# Refrescar todas las unidades al cambiar de turno
	for i in range(height):
		for j in range(width):
			if grid[i][j].unit:
				grid[i][j].unit.refresh()

func _on_save_map_pressed():
	var map_name = save_name_input.text.strip_edges()
	if map_name.is_empty():
		map_name = "MiMapa"
	
	var active_hexes: Array = []
	for i in range(height):
		for j in range(width):
			if grid[i][j].activated:
				active_hexes.append([i, j])
	
	var units_data: Array = []
	for i in range(height):
		for j in range(width):
			var hex = grid[i][j]
			if hex.unit:
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
					"i": i,
					"j": j,
					"unit_type": unit_type,
					"player_index": hex.unit.player_index
				})
	
	var saved_path = MapSerializer.save_map(map_name, width, height, active_hexes, units_data)
	if not saved_path.is_empty():
		save_status_label.text = "¡Mapa guardado exitosamente!"
	else:
		save_status_label.text = "Error al guardar mapa."

func _on_load_map_pressed():
	map_load_option_button.clear()
	available_editor_maps = MapSerializer.list_maps()
	if available_editor_maps.is_empty():
		save_status_label.text = "No se encontraron mapas guardados."
		return
	
	for map_info in available_editor_maps:
		map_load_option_button.add_item(map_info.get("name", "Mapa Sin Nombre"))
	
	dim_overlay.visible = true
	load_map_panel.visible = true

func _on_confirm_load_pressed():
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

func _on_cancel_load_pressed():
	dim_overlay.visible = false
	load_map_panel.visible = false

func _on_back_to_menu_pressed():
	get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")
