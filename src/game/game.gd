extends Node2D

class_name Game

static var selected_map_path: String = ""

@export var width = 6
@export var height = 6

@export var initial_energy: int = 0
@export var initial_gold: int = 0
@export var energy_per_turn: int = 1
@export var gold_per_turn: int = 1

signal resources_changed(player_index: int, energy: int, gold: int)
signal territory_control_updated(hex: Node2D, owner_player: int)

@onready var turn_label = $CanvasLayerUI/GameHUD/MarginContainer/HBoxContainer/Turn
@onready var victory_panel = $CanvasLayerUI/VictoryPanel
@onready var victory_message = $CanvasLayerUI/VictoryPanel/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/VictoryMessage

var turn = 0
var distance_objects = {}
var attack_objects = []
var old_hex = null
var grid = []
var is_game_over: bool = false

var player_resources: Dictionary = {
	0: {"energy": 0, "gold": 0},
	1: {"energy": 0, "gold": 0}
}

func _ready() -> void:
	grid = []
	
	player_resources[0] = {"energy": initial_energy, "gold": initial_gold}
	player_resources[1] = {"energy": initial_energy, "gold": initial_gold}
	resources_changed.emit(0, player_resources[0]["energy"], player_resources[0]["gold"])
	resources_changed.emit(1, player_resources[1]["energy"], player_resources[1]["gold"])
	
	if selected_map_path.is_empty():
		selected_map_path = "res://maps/default_map.json"
		
	var map_data: Dictionary = {}
	if not selected_map_path.is_empty():
		map_data = MapSerializer.load_map(selected_map_path)
		if not map_data.is_empty():
			width = map_data.get("width", 6)
			height = map_data.get("height", 6)
	
	# Construir la rejilla de hexágonos
	for i in range(height):
		grid.insert(i, [])
		for j in range(width):
			var hex = load("res://src/hex/hex.tscn").instantiate()
			hex.name = str(i) + "," + str(j)
			hex.i = i
			hex.j = j
			hex.connect("hex_pressed", on_hex_pressed)
			hex.position = ShapeGenerator.hex_to_world(i, j)
			add_child(hex)
			grid[i].insert(j, hex)

	do_connections()
	
	if not map_data.is_empty():
		apply_map_data(map_data)
	else:
		for i in range(height):
			for j in range(width):
				grid[i][j].activated = true
				grid[i][j].visible = true
				grid[i][j].set_modulate(Color(1, 1, 1, 1))

func reset_colors() -> void:
	for i in range(height):
		for j in range(width):
			if grid[i][j] and grid[i][j].activated:
				grid[i][j].set_modulate(Color(1, 1, 1, 1))

func clear_selection() -> void:
	old_hex = null
	distance_objects = {}
	attack_objects = []
	reset_colors()

func highlight_movement_range(hex, range_val: int = 0) -> Dictionary:
	hex.set_modulate(Color(0.5, 1, 0.5, 1))
	var distance_objects = $Dijkstra.dijkstra_hexagonal(hex, false)
	var reachable = {}
	for destination_hex in distance_objects:
		if not destination_hex.visible or destination_hex.unit:
			continue
		var distance = distance_objects[destination_hex]
		var player_index = hex.unit.player_index
		if distance > 0 and range_val > 0 and distance <= range_val:
			destination_hex.set_modulate(Color(1 * player_index, 0.7, 1 * (1 - player_index), 1))
			reachable[destination_hex] = distance
	return reachable

func highlight_attack_range(hex, range_val: int = 0) -> Array:
	hex.set_modulate(Color(0.5, 1, 0.5, 1))
	var distance_objects = $Dijkstra.dijkstra_hexagonal(hex, true)
	var attackable = []
	for destination_hex in distance_objects:
		var distance = distance_objects[destination_hex]
		var player_index = hex.unit.player_index
		if distance > 0 and range_val > 0 and distance <= range_val and destination_hex.unit and destination_hex.unit.player_index != player_index:
			destination_hex.set_modulate(Color(1, 0, 0, 1))
			attackable.append(destination_hex)
	return attackable

func show_available_actions(hex) -> void:
	var unit = hex.unit
	reset_colors()
	if unit.movement_used < unit.movement:
		distance_objects = highlight_movement_range(hex, unit.movement - unit.movement_used)
	else:
		distance_objects = {}
	if not unit.has_attacked:
		attack_objects = highlight_attack_range(hex, unit.range)
	else:
		attack_objects = []

func clear_units() -> void:
	for i in range(height):
		for j in range(width):
			var hex = grid[i][j]
			if hex and hex.unit:
				hex.unit.queue_free()
				hex.unit = null

func apply_map_data(map_data: Dictionary) -> void:
	clear_units()
	
	var active_hexes = map_data.get("active_hexes", [])
	if active_hexes.size() > 0:
		for i in range(height):
			for j in range(width):
				grid[i][j].activated = false
				grid[i][j].visible = false
		
		for coord in active_hexes:
			var i = int(coord[0])
			var j = int(coord[1])
			var terrain = "grass"
			if coord.size() > 2:
				terrain = str(coord[2])
			if i >= 0 and i < height and j >= 0 and j < width:
				grid[i][j].activated = true
				grid[i][j].visible = true
				grid[i][j].set_terrain_type(terrain)
				grid[i][j].set_modulate(Color(1, 1, 1, 1))

	var saved_units = map_data.get("units", [])
	for unit_data in saved_units:
		var i = int(unit_data.get("i", 0))
		var j = int(unit_data.get("j", 0))
		var unit_type = str(unit_data.get("unit_type", "marine"))
		var player_idx = int(unit_data.get("player_index", 0))
		if i >= 0 and i < height and j >= 0 and j < width:
			spawn_unit_at(grid[i][j], unit_type, player_idx)

func spawn_unit_at(hex, unit_type: String, player_idx: int) -> void:
	var clean_type = unit_type.to_lower()
	if clean_type == "ling":
		clean_type = "zergling"
		
	var unit_scene = load("res://src/units/unit.tscn").instantiate()
	var stats_path = "res://src/units/resources/" + clean_type + "_stats.tres"
	
	if ResourceLoader.exists(stats_path):
		unit_scene.stats = load(stats_path)
		
	if not unit_scene.is_flying() and hex and hex.has_method("can_spawn_unit") and not hex.can_spawn_unit():
		unit_scene.queue_free()
		return
		
	unit_scene.set_player_index(player_idx)
	unit_scene.set_hex(hex)
	unit_scene.unit_died.connect(_on_unit_died)
	add_child(unit_scene)


func get_units_for_player(player_idx: int) -> Array:
	var list = []
	for i in range(height):
		for j in range(width):
			if grid[i][j] and grid[i][j].unit and not grid[i][j].unit.is_queued_for_deletion():
				if grid[i][j].unit.player_index == player_idx:
					list.append(grid[i][j].unit)
	return list

func _on_unit_died(unit) -> void:
	if is_game_over:
		return
	if not unit:
		return
		
	var victim_player = unit.player_index
	var winner_player = 1 - victim_player
	
	var remaining_units = get_units_for_player(victim_player)
	remaining_units.erase(unit)
	
	if unit.is_king() or remaining_units.is_empty():
		is_game_over = true
		clear_selection()
		if victory_message:
			victory_message.text = "¡El Jugador " + str(winner_player) + " ha ganado!"
		if victory_panel:
			victory_panel.visible = true

func on_hex_pressed(hex) -> void:
	if is_game_over:
		return
		
	if old_hex != null and hex == old_hex:
		clear_selection()
		return
		
	if old_hex != null:
		var unit = old_hex.unit
		if hex in distance_objects:
			var cost = distance_objects[hex]
			old_hex.unit = null
			unit.set_hex(hex)
			if unit.has_method("stops_on_hex") and unit.stops_on_hex(hex):
				unit.movement_used = unit.movement
			elif hex.has_method("stops_movement_on_enter") and hex.stops_movement_on_enter():
				unit.movement_used = unit.movement
			else:
				unit.movement_used += cost

			unit.update_action_visual()
			old_hex = hex
			if unit.movement_used < unit.movement or not unit.has_attacked:
				show_available_actions(hex)
			else:
				clear_selection()
			return
		elif hex in attack_objects:
			unit.attack(hex.unit)
			unit.has_attacked = true
			unit.update_action_visual()
			if is_game_over:
				return
			if unit.movement_used < unit.movement:
				show_available_actions(old_hex)
			else:
				clear_selection()
			return
		else:
			clear_selection()
			
	if hex.unit and hex.unit.player_index == turn and not hex.unit.is_exhausted():
		old_hex = hex
		show_available_actions(hex)

func connect_up_left(i, j) -> void:
	var hex = grid[i][j]
	if i == 0: return
	hex.up_left = grid[i - 1][j]

func connect_up_center(i, j) -> void:
	var hex = grid[i][j]
	if i == 0 or j == width - 1: return
	hex.up_center = grid[i - 1][j + 1]

func connect_up_right(i, j) -> void:
	var hex = grid[i][j]
	if j == width - 1: return
	hex.up_right = grid[i][j + 1]

func connect_down_left(i, j) -> void:
	var hex = grid[i][j]
	if j == 0: return
	hex.down_left = grid[i][j - 1]

func connect_down_center(i, j) -> void:
	var hex = grid[i][j]
	if j == 0 or i == height - 1: return
	hex.down_center = grid[i + 1][j - 1]

func connect_down_right(i, j) -> void:
	var hex = grid[i][j]
	if i == height - 1: return
	hex.down_right = grid[i + 1][j]

func do_connections() -> void:
	for i in range(height):
		for j in range(width):
			connect_up_left(i, j)
			connect_up_center(i, j)
			connect_up_right(i, j)
			connect_down_left(i, j)
			connect_down_center(i, j)
			connect_down_right(i, j)

func get_player_energy(player_idx: int) -> int:
	return player_resources.get(player_idx, {}).get("energy", 0)

func get_player_gold(player_idx: int) -> int:
	return player_resources.get(player_idx, {}).get("gold", 0)

func add_player_energy(player_idx: int, amount: int) -> void:
	if not player_resources.has(player_idx):
		player_resources[player_idx] = {"energy": 0, "gold": 0}
	player_resources[player_idx]["energy"] += amount
	resources_changed.emit(player_idx, player_resources[player_idx]["energy"], player_resources[player_idx]["gold"])

func add_player_gold(player_idx: int, amount: int) -> void:
	if not player_resources.has(player_idx):
		player_resources[player_idx] = {"energy": 0, "gold": 0}
	player_resources[player_idx]["gold"] += amount
	resources_changed.emit(player_idx, player_resources[player_idx]["energy"], player_resources[player_idx]["gold"])

func set_player_energy(player_idx: int, amount: int) -> void:
	if not player_resources.has(player_idx):
		player_resources[player_idx] = {"energy": 0, "gold": 0}
	player_resources[player_idx]["energy"] = amount
	resources_changed.emit(player_idx, player_resources[player_idx]["energy"], player_resources[player_idx]["gold"])

func set_player_gold(player_idx: int, amount: int) -> void:
	if not player_resources.has(player_idx):
		player_resources[player_idx] = {"energy": 0, "gold": 0}
	player_resources[player_idx]["gold"] = amount
	resources_changed.emit(player_idx, player_resources[player_idx]["energy"], player_resources[player_idx]["gold"])

func get_controlled_territories_count(player_idx: int) -> int:
	var count = 0
	for i in range(height):
		for j in range(width):
			var hex = grid[i][j]
			if hex and hex.activated and hex.is_territory and hex.owner_player == player_idx:
				count += 1
	return count

func update_territory_control() -> void:
	var ending_player = turn
	var territory_hexes = []
	for i in range(height):
		for j in range(width):
			var hex = grid[i][j]
			if hex and hex.activated and hex.is_territory:
				territory_hexes.append(hex)
				
	for hex in territory_hexes:
		var ending_player_king_present = false
		var rival_king_present = false
		var rival_player = 1 - ending_player
		
		if hex.unit and hex.unit.is_king():
			if hex.unit.player_index == ending_player:
				ending_player_king_present = true
			elif hex.unit.player_index == rival_player:
				rival_king_present = true
				
		var current_owner = hex.owner_player
		var new_owner = current_owner
		
		if ending_player_king_present:
			new_owner = ending_player
			hex.last_king_claimer = ending_player
		elif current_owner == ending_player and not ending_player_king_present:
			if rival_king_present:
				new_owner = rival_player
				hex.last_king_claimer = rival_player
			else:
				if hex.last_king_claimer != -1:
					new_owner = hex.last_king_claimer
					
		if new_owner != current_owner:
			hex.set_owner_player(new_owner)
			territory_control_updated.emit(hex, new_owner)

func _on_finish_turn_pressed() -> void:
	if is_game_over:
		return
	clear_selection()
	
	update_territory_control()
	
	turn = int(!turn)
	if turn_label:
		turn_label.text = str(turn)
		
	add_player_energy(turn, energy_per_turn)
	var territories_owned = get_controlled_territories_count(turn)
	add_player_gold(turn, gold_per_turn * territories_owned)
	
	for i in range(height):
		for j in range(width):
			if grid[i][j] and grid[i][j].unit:
				grid[i][j].unit.refresh()

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _on_back_to_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")
