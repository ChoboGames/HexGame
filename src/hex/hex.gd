extends Node2D

var i: int
var j: int

var activated: bool

@export var up_left: Node2D
@export var up_center: Node2D
@export var up_right: Node2D
@export var down_left: Node2D
@export var down_center: Node2D
@export var down_right: Node2D

signal hex_pressed
signal hex_hovered

var unit
var terrain_type: String = "grass"

const HEX_SIZE := 702
static var _variants_cache: Dictionary = {}
static var _hex_material: ShaderMaterial = null
static var _hex_click_mask: BitMap = null
static var _texture_cache: Dictionary = {}

func _ready():
	$Label.text = name
	set_terrain_type(terrain_type)

func set_terrain_type(new_type: String) -> void:
	terrain_type = new_type
	var button = $TextureButton
	if not button:
		return
	button.material = _get_hex_material()
	button.texture_click_mask = _get_hex_click_mask()
	var texture = _load_terrain_texture(new_type)
	if texture:
		button.texture_normal = texture

static func _get_variant_paths(terrain: String) -> Array:
	if _variants_cache.has(terrain):
		return _variants_cache[terrain]
	var base := "res://assets/textures/terrain/" + terrain + "/" + terrain
	var paths: Array = []
	var single := base + ".png"
	if ResourceLoader.exists(single):
		paths.append(single)
	var n := 1
	while true:
		var p := base + str(n) + ".png"
		if ResourceLoader.exists(p):
			paths.append(p)
			n += 1
		else:
			break
	_variants_cache[terrain] = paths
	return paths

func _load_terrain_texture(terrain: String) -> Texture2D:
	var paths := _get_variant_paths(terrain)
	if paths.size() > 0:
		var count := paths.size()
		var idx := ((i * 31 + j * 17) % count + count) % count
		return _get_scaled_texture(paths[idx])
	var fallback := "res://assets/textures/hexagon.png"
	if ResourceLoader.exists(fallback):
		return load(fallback)
	return null

static func _get_scaled_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]
	var tex = load(path)
	if tex and tex.get_image():
		var img = tex.get_image()
		if img.get_width() != HEX_SIZE or img.get_height() != HEX_SIZE:
			img = img.duplicate()
			img.resize(HEX_SIZE, HEX_SIZE)
		var out = ImageTexture.create_from_image(img)
		_texture_cache[path] = out
		return out
	return tex

static func _get_hex_material() -> ShaderMaterial:
	if _hex_material == null:
		var shader := load("res://src/hex/hex_mask.gdshader")
		if shader:
			_hex_material = ShaderMaterial.new()
			_hex_material.shader = shader
			_hex_material.set_shader_parameter("hex_mask", load("res://assets/textures/hexagon.png"))
	return _hex_material

static func _get_hex_click_mask() -> BitMap:
	if _hex_click_mask == null:
		var tex := load("res://assets/textures/hexagon.png")
		if tex:
			_hex_click_mask = BitMap.new()
			_hex_click_mask.create_from_image_alpha(tex.get_image())
	return _hex_click_mask

func _on_texture_button_pressed():
	emit_signal("hex_pressed", self)

func _on_texture_button_mouse_entered():
	emit_signal("hex_hovered", self)
