class_name UnitStats
extends Resource

@export var unit_name: String = "Unidad"
@export var unit_letter: String = "U"
@export var base_hp: int = 10
@export var damage: int = 2
@export var movement: int = 2
@export var range: int = 1
@export var is_flying: bool = false
@export var energy_cost: int = 0
@export var resource_cost: int = 0

static var _icon_cache: Dictionary = {}

static func get_icon_for_type(unit_type: String) -> Texture2D:
	var clean_type = unit_type.to_lower()
	if _icon_cache.has(clean_type):
		return _icon_cache[clean_type]
	var icon_path = "res://assets/units/" + clean_type + ".png"
	var icon: Texture2D = null
	if ResourceLoader.exists(icon_path):
		icon = load(icon_path)
	_icon_cache[clean_type] = icon
	return icon

