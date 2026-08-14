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
@onready var unit_info_bar = $CanvasLayerUI/UnitInfoBar
@onready var unit_name_label = $CanvasLayerUI/UnitInfoBar/MarginContainer/HBoxContainer/UnitNameLabel
@onready var unit_hp_label = $CanvasLayerUI/UnitInfoBar/MarginContainer/HBoxContainer/HPLabel
@onready var unit_damage_label = $CanvasLayerUI/UnitInfoBar/MarginContainer/HBoxContainer/DamageLabel
@onready var unit_range_label = $CanvasLayerUI/UnitInfoBar/MarginContainer/HBoxContainer/RangeLabel
@onready var unit_movement_label = $CanvasLayerUI/UnitInfoBar/MarginContainer/HBoxContainer/MovementLabel
@onready var unit_attack_status_label = $CanvasLayerUI/UnitInfoBar/MarginContainer/HBoxContainer/AttackStatusLabel
@onready var summon_panel = $CanvasLayerUI/SummonPanel
@onready var btn_summon_archer = $CanvasLayerUI/SummonPanel/MarginContainer/HBoxContainer/BtnSummonArcher
@onready var btn_summon_wolf = $CanvasLayerUI/SummonPanel/MarginContainer/HBoxContainer/BtnSummonWolf
@onready var btn_summon_eagle = $CanvasLayerUI/SummonPanel/MarginContainer/HBoxContainer/BtnSummonEagle
@onready var btn_summon_soldier = $CanvasLayerUI/SummonPanel/MarginContainer/HBoxContainer/BtnSummonSoldier

var turn = 0
var distance_objects = {}
var attack_objects = []
var old_hex = null
var grid = []
var is_game_over: bool = false
var summon_mode: bool = false
var summon_type: String = ""
var summon_hexes: Array = []
var summonable_types: Array = ["archer", "wolf", "eagle", "soldier"]

var player_resources: Dictionary = {
	0: {"energy": 0, "gold": 0},
	1: {"energy": 0, "gold": 0}
}

func _ready() -> void:
	grid = []
	
	resources_changed.connect(func(_idx, _e, _g): update_temp_resource_ui())
	player_resources[0] = {"energy": initial_energy, "gold": initial_gold}
	player_resources[1] = {"energy": initial_energy, "gold": initial_gold}
	resources_changed.emit(0, player_resources[0]["energy"], player_resources[0]["gold"])
	resources_changed.emit(1, player_resources[1]["energy"], player_resources[1]["gold"])
	update_temp_resource_ui()
	
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
	summon_mode = false
	summon_type = ""
	summon_hexes = []
	reset_colors()
	hide_unit_info_bar()
	if summon_panel:
		summon_panel.visible = false

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
	update_unit_info_bar(unit)
	update_summon_panel(hex)

func update_unit_info_bar(unit) -> void:
	if not unit_info_bar:
		return
	var display_name = unit.unit_letter
	if unit.stats and unit.stats.unit_name.length() > 0:
		display_name = unit.stats.unit_name
	unit_name_label.text = "🔫 " + display_name
	unit_hp_label.text = "❤ Vida: " + str(unit.hp) + "/" + str(unit.base_hp)
	unit_damage_label.text = "⚔ Daño: " + str(unit.damage)
	unit_range_label.text = "🎯 Rango: " + str(unit.range)
	unit_movement_label.text = "👣 Pasos: " + str(unit.movement - unit.movement_used) + "/" + str(unit.movement)
	if unit.has_attacked:
		unit_attack_status_label.text = "✗ Ya atacó"
		unit_attack_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	else:
		unit_attack_status_label.text = "✓ Puede atacar"
		unit_attack_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5, 1))
	unit_info_bar.visible = true

func hide_unit_info_bar() -> void:
	if unit_info_bar:
		unit_info_bar.visible = false

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
		var unit_type = str(unit_data.get("unit_type", "archer"))
		var player_idx = int(unit_data.get("player_index", 0))
		if i >= 0 and i < height and j >= 0 and j < width:
			spawn_unit_at(grid[i][j], unit_type, player_idx)

func spawn_unit_at(hex, unit_type: String, player_idx: int) -> void:
	var clean_type = unit_type.to_lower()

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

func get_unit_stats(unit_type: String) -> Resource:
	var clean_type = unit_type.to_lower()
	var stats_path = "res://src/units/resources/" + clean_type + "_stats.tres"
	if ResourceLoader.exists(stats_path):
		return load(stats_path)
	return null

func get_summon_hexes(king_hex, unit_type: String) -> Array:
	var valid = []
	var stats = get_unit_stats(unit_type)
	var is_flying = stats != null and stats.is_flying
	for neighbor in king_hex.get_neighbors():
		if not neighbor.activated or not neighbor.visible:
			continue
		if neighbor.unit:
			continue
		if not is_flying and neighbor.has_method("can_spawn_unit") and not neighbor.can_spawn_unit():
			continue
		valid.append(neighbor)
	return valid

func can_afford(player_idx: int, stats) -> bool:
	if stats == null:
		return false
	return get_player_energy(player_idx) >= stats.energy_cost and get_player_gold(player_idx) >= stats.resource_cost

func get_summon_button(unit_type: String):
	match unit_type:
		"archer":
			return btn_summon_archer
		"wolf":
			return btn_summon_wolf
		"eagle":
			return btn_summon_eagle
		"soldier":
			return btn_summon_soldier
	return null

func update_summon_panel(king_hex) -> void:
	if summon_panel == null:
		return
	if king_hex == null or king_hex.unit == null or not king_hex.unit.is_king() or king_hex.unit.player_index != turn:
		summon_panel.visible = false
		return
	summon_panel.visible = true
	for unit_type in summonable_types:
		var button = get_summon_button(unit_type)
		if button == null:
			continue
		var affordable = can_afford(turn, get_unit_stats(unit_type))
		var has_space = not get_summon_hexes(king_hex, unit_type).is_empty()
		button.disabled = not (affordable and has_space)

func start_summon_mode(unit_type: String) -> void:
	if old_hex == null or old_hex.unit == null or not old_hex.unit.is_king():
		return
	if not can_afford(turn, get_unit_stats(unit_type)):
		return
	var valid = get_summon_hexes(old_hex, unit_type)
	if valid.is_empty():
		return
	summon_mode = true
	summon_type = unit_type
	summon_hexes = valid
	reset_colors()
	old_hex.set_modulate(Color(0.5, 1, 0.5, 1))
	for hex in summon_hexes:
		hex.set_modulate(Color(1, 0.9, 0.3, 1))

func cancel_summon_mode() -> void:
	summon_mode = false
	summon_type = ""
	summon_hexes = []
	if old_hex != null and old_hex.unit != null:
		show_available_actions(old_hex)
	else:
		clear_selection()

func handle_summon_click(hex) -> bool:
	if not summon_mode:
		return false
	if hex in summon_hexes:
		do_summon(hex)
	else:
		cancel_summon_mode()
	return true

func do_summon(hex) -> void:
	var stats = get_unit_stats(summon_type)
	if stats == null or not can_afford(turn, stats):
		cancel_summon_mode()
		return
	add_player_energy(turn, -stats.energy_cost)
	add_player_gold(turn, -stats.resource_cost)
	spawn_unit_at(hex, summon_type, turn)
	var new_unit = hex.unit
	if new_unit:
		new_unit.movement_used = new_unit.movement
		new_unit.has_attacked = true
		new_unit.update_action_visual()
	summon_mode = false
	summon_type = ""
	summon_hexes = []
	show_available_actions(old_hex)

func _on_summon_archer_pressed() -> void:
	start_summon_mode("archer")

func _on_summon_wolf_pressed() -> void:
	start_summon_mode("wolf")

func _on_summon_eagle_pressed() -> void:
	start_summon_mode("eagle")

func _on_summon_soldier_pressed() -> void:
	start_summon_mode("soldier")

func _on_summon_cancel_pressed() -> void:
	if summon_mode:
		cancel_summon_mode()

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

	if handle_summon_click(hex):
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
			
	if hex.unit and hex.unit.player_index == turn and (not hex.unit.is_exhausted() or hex.unit.is_king()):
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

func update_temp_resource_ui() -> void:
	var p0_label = get_node_or_null("CanvasLayerUI/TempResourceHUD/MarginContainer/HBoxContainer/P0Label")
	var p1_label = get_node_or_null("CanvasLayerUI/TempResourceHUD/MarginContainer/HBoxContainer/P1Label")
	if p0_label:
		p0_label.text = "[P0 Test] ⚡ Energía: " + str(get_player_energy(0)) + " | 🪙 Oro: " + str(get_player_gold(0))
	if p1_label:
		p1_label.text = "[P1 Test] ⚡ Energía: " + str(get_player_energy(1)) + " | 🪙 Oro: " + str(get_player_gold(1))

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
