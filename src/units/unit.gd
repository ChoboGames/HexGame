extends Node2D


@export var unit_letter: String
@export var base_hp: int
@export var damage: int
@export var movement: int
@export var range: int

var hp: int

var player_index: int

var hex


func _ready():
	$Label.text = unit_letter
	print(player_index)
	set_modulate(Color(1 * player_index, 0.5, 1 * (1 - player_index), 1))
	set_hp(base_hp)
	
	
func set_hex(hex):
	self.hex = hex
	hex.unit = self
	position_in_hex()
	

func set_hp(new_hp):
	if new_hp <= 0:
		hex.unit = null
		queue_free()
		return
	hp = new_hp
	$UI/HP.text = str(hp)


func position_in_hex():
	if not hex:
		return
	
	self.position = hex.position


func attack(unit):
	unit.set_hp(unit.hp - damage)
