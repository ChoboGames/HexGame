extends Node2D

@export var stats: UnitStats:
	set(value):
		stats = value
		if is_node_ready():
			apply_stats()

@export var unit_letter: String
@export var base_hp: int
@export var damage: int
@export var movement: int
@export var range: int

var hp: int
var player_index: int
var hex
var movement_used: int = 0
var has_attacked: bool = false

func set_player_index(idx: int):
	player_index = idx
	update_action_visual()

func is_exhausted() -> bool:
	return movement_used >= movement and has_attacked

func refresh():
	movement_used = 0
	has_attacked = false
	update_action_visual()

func update_action_visual():
	var color = Color(1 * player_index, 0.5, 1 * (1 - player_index), 1)
	if is_exhausted():
		color.a = 0.4
	set_modulate(color)

func apply_stats():
	if stats:
		unit_letter = stats.unit_letter
		base_hp = stats.base_hp
		damage = stats.damage
		movement = stats.movement
		range = stats.range
		
	if has_node("Label"):
		$Label.text = unit_letter
	set_hp(base_hp if base_hp > 0 else 10)

func _ready():
	apply_stats()
	set_player_index(player_index)

func set_hex(hex):
	self.hex = hex
	hex.unit = self
	position_in_hex()

signal unit_died(unit: Node2D)

func is_king() -> bool:
	if stats and stats.unit_name.to_lower() == "king":
		return true
	return unit_letter == "K"

func set_hp(new_hp):
	if new_hp <= 0:
		if hex:
			hex.unit = null
		unit_died.emit(self)
		queue_free()
		return
	hp = new_hp
	if has_node("UI/HP"):
		$UI/HP.text = str(hp)

func position_in_hex():
	if not hex:
		return
	self.position = hex.position

func attack(unit):
	if unit:
		unit.set_hp(unit.hp - damage)
