extends Node2D

const DISC_DIAMETER := 460.0
const RING_WIDTH := 28.0
const PLAYER_COLORS: Array = [
	Color(0, 0.5, 1, 1),
	Color(1, 0.5, 0, 1)
]

static var _icon_materials: Dictionary = {}
static var _ring_materials: Dictionary = {}
static var _white_texture: ImageTexture = null

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
	if has_node("Ring"):
		var ring_material = _get_ring_material(player_index)
		if ring_material:
			$Ring.material = ring_material
	var alpha = 0.4 if is_exhausted() else 1.0
	set_modulate(Color(1, 1, 1, alpha))

func apply_stats():
	if stats:
		unit_letter = stats.unit_letter
		base_hp = stats.base_hp
		damage = stats.damage
		movement = stats.movement
		range = stats.range

	var icon: Texture2D = null
	if stats:
		icon = UnitStats.get_icon_for_type(stats.unit_name)
	if has_node("Icon"):
		$Icon.texture = icon
		if icon:
			var target: float = DISC_DIAMETER
			var tex_min: int = min(icon.get_width(), icon.get_height())
			if tex_min > 0:
				var s: float = target / tex_min
				$Icon.scale = Vector2(s, s)
				var icon_material = _get_icon_material(icon)
				if icon_material:
					$Icon.material = icon_material
	if has_node("Label"):
		$Label.visible = icon == null
		$Label.text = unit_letter
	set_hp(base_hp if base_hp > 0 else 10)

static func _get_icon_material(icon: Texture2D) -> ShaderMaterial:
	var key := Vector2i(icon.get_width(), icon.get_height())
	if not _icon_materials.has(key):
		var shader := load("res://src/units/icon_mask.gdshader")
		if shader:
			var material := ShaderMaterial.new()
			material.shader = shader
			material.set_shader_parameter("icon_size", Vector2(key))
			_icon_materials[key] = material
	return _icon_materials[key]

static func _get_ring_material(player_index: int) -> ShaderMaterial:
	if not _ring_materials.has(player_index):
		var shader := load("res://src/units/ring_mask.gdshader")
		if shader:
			var material := ShaderMaterial.new()
			material.shader = shader
			material.set_shader_parameter("ring_color", PLAYER_COLORS[player_index])
			material.set_shader_parameter("quad_size", Vector2(DISC_DIAMETER, DISC_DIAMETER))
			material.set_shader_parameter("ring_width", RING_WIDTH)
			_ring_materials[player_index] = material
	return _ring_materials[player_index]

static func _get_white_texture() -> ImageTexture:
	if _white_texture == null:
		var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		image.fill(Color(1, 1, 1, 1))
		_white_texture = ImageTexture.create_from_image(image)
	return _white_texture

func _ready():
	z_index = 10
	if has_node("Ring"):
		$Ring.texture = _get_white_texture()
		$Ring.scale = Vector2(DISC_DIAMETER / 4.0, DISC_DIAMETER / 4.0)
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

func is_flying() -> bool:
	return stats != null and stats.is_flying

func can_enter_hex(target_hex: Node2D) -> bool:
	if not target_hex or not target_hex.visible:
		return false
	if is_flying():
		return true
	if target_hex.has_method("is_walkable"):
		return target_hex.is_walkable()
	return target_hex.terrain_type != "mountain" and target_hex.terrain_type != "water"

func can_pass_through_hex(target_hex: Node2D) -> bool:
	if not can_enter_hex(target_hex):
		return false
	if target_hex.unit and not is_flying():
		return false
	return true

func stops_on_hex(target_hex: Node2D) -> bool:
	if is_flying():
		return false
	if target_hex.has_method("stops_movement_on_enter"):
		return target_hex.stops_movement_on_enter()
	return target_hex.terrain_type == "swamp"

func get_hex_cost(target_hex: Node2D) -> int:
	return 1 if can_enter_hex(target_hex) else -1


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
