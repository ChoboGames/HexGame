extends Node2D


@export var width = 0
@export var height = 0

@onready var unit_selector = $Camera2D/EditorHUD/UnitSelector
@onready var player_selector = $Camera2D/EditorHUD/PlayerSelector


var turn = 0
var distance_objects = []
var attack_objects = []
var old_hex = null

var edition_mode = true
var game_started = false


var grid = []


func print_grid():
	for i in range(height):
		print(grid[i])
		
		
func reset_colors():
	for i in range(height):
		for j in range(width):
			grid[i][j].set_modulate(Color(1, 1, 1, 1))

# Called when the node enters the scene tree for the first time.
func _ready():
	grid = []
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
	$Camera2D/MapHUD/ToggleEditMode.visible = true
	$Camera2D/MapHUD/FinishMap.visible = true
	
func on_hex_pressed(hex):
	if game_started:
		print(hex)
		print(old_hex)
		print(hex==old_hex)
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
	else:
		if edition_mode:
			hex.activated = !hex.activated
			if hex.activated:
				hex.set_modulate(Color(1, 1, 0, 1))
			else:
				hex.set_modulate(Color(1, 1, 1, 1))
		else:
			if hex.unit:
				remove_child(hex.unit.get_parent())
				hex.unit = null
			else:
				create_unit(hex)
			

func create_unit(hex):
	var unit_name = unit_selector.get_item_text(unit_selector.selected).to_lower()
	var unit = load("res://src/units/" + unit_name + ".tscn").instantiate()
	
	var unit_component = unit.get_node("UnitComponent")
	unit_component.set_hex(hex)
	unit_component.player_index = player_selector.selected
	add_child(unit)


func connect_up_left(i, j):
	var hex = grid[i][j]
	if i == 0:
		return
	var new_connection = grid[i - 1][j]
	if new_connection:
		hex.up_left = new_connection

func connect_up_center(i, j):
	var hex = grid[i][j]
	if i == 0 or j == width - 1:
		return
	var new_connection = grid[i - 1][j + 1]
	hex.up_center = new_connection
	

func connect_up_right(i, j):
	var hex = grid[i][j]
	if j == width - 1:
		return
	var new_connection = grid[i][j + 1]
	hex.up_right = new_connection
		
	
func connect_down_left(i, j):
	var hex = grid[i][j]
	if j == 0:
		return
	var new_connection = grid[i][j - 1]
	hex.down_left = new_connection
	
func connect_down_center(i, j):
	var hex = grid[i][j]
	if j == 0 or i == height - 1:
		return
	var new_connection = grid[i + 1][j - 1]
	hex.down_center = new_connection
	

func connect_down_right(i, j):
	var hex = grid[i][j]
	if i == height - 1:
		return
	var new_connection = grid[i + 1][j]
	hex.down_right = new_connection


func do_connections():
	for i in range(height):
		for j in range(width):
			connect_up_left(i, j)
			connect_up_center(i, j)
			connect_up_right(i, j)
			connect_down_left(i, j)
			connect_down_center(i, j)
			connect_down_right(i, j)


func _on_button_pressed():
	for i in range(height):
		for j in range(width):
			var hex = grid[i][j]
			if hex.activated and !edition_mode:
					hex.set_modulate(Color(1, 1, 0, 1)) # yellow
			elif hex.activated:
				hex.set_modulate(Color(1, 1, 1, 1))	# white
			else:
				hex.visible = !edition_mode

	edition_mode = !edition_mode


func _on_finish_map_pressed():
	edition_mode = true
	_on_button_pressed()
	$Camera2D/MapHUD/FinishMap.visible = false
	$Camera2D/MapHUD/ToggleEditMode.visible = false
	unit_selector.visible = true
	player_selector.visible = true
	$Camera2D/EditorHUD/StartGame.visible = true


func _on_start_game_pressed():
	$Camera2D/EditorHUD.visible = false
	game_started = true
	$Camera2D/GameHUD.visible = true


func _on_finish_turn_pressed():
	reset_colors()
	turn = int(!turn)
	$Camera2D/GameHUD/Turn.text = str(turn)
