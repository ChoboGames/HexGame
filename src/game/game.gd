extends Node2D

class_name Game

static var selected_map_path: String = ""

@export var width = 6
@export var height = 6

@onready var turn_label = $CanvasLayerUI/GameHUD/MarginContainer/HBoxContainer/Turn

var turn = 0
var distance_objects = []
var attack_objects = []
var old_hex = null
var grid = []

func _ready() -> void:
	grid = []
	
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
			var x = j * 720  + i * 720
			var y = -j * 720 + i * 720
			x *= 4.5 / 6
			y /= 2
			hex.position = Vector2(x, y)
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

func on_hex_pressed(hex) -> void:
	if hex == old_hex:
		distance_objects = null
		attack_objects = null
		reset_colors()
		hex = null
		old_hex = null
		return
	if distance_objects:
		if hex in distance_objects:
			var unit = old_hex.unit
			old_hex.unit = null
			unit.set_hex(hex)
			reset_colors()
		elif hex in attack_objects:
			old_hex.unit.attack(hex.unit)
		distance_objects = null
	elif hex.unit and hex.unit.player_index == turn:
		reset_colors()
		distance_objects = $Dijkstra.color_hexagons(hex, hex.unit.movement)
		attack_objects = $Dijkstra.color_hexagon_attack(hex, hex.unit.range)
		old_hex = hex

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

func _on_finish_turn_pressed() -> void:
	reset_colors()
	turn = int(!turn)
	if turn_label:
		turn_label.text = str(turn)

func _on_back_to_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")
