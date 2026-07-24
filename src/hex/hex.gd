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

func _ready():
	$Label.text = name
	set_terrain_type(terrain_type)

func set_terrain_type(new_type: String) -> void:
	terrain_type = new_type
	var button = $TextureButton
	if not button:
		return
		
	var path = "res://assets/textures/terrain/hex_" + new_type + ".png"
	if not ResourceLoader.exists(path):
		path = "res://assets/textures/hexagon.png"
		
	var texture = load(path)
	if texture:
		button.texture_normal = texture
		var bitmap = BitMap.new()
		bitmap.create_from_image_alpha(texture.get_image())
		button.texture_click_mask = bitmap

func _on_texture_button_pressed():
	emit_signal("hex_pressed", self)

func _on_texture_button_mouse_entered():
	emit_signal("hex_hovered", self)
