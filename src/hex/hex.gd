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

func _ready():
	$Label.text = name
	var button = $TextureButton
	if button and button.texture_normal:
		var bitmap = BitMap.new()
		bitmap.create_from_image_alpha(button.texture_normal.get_image())
		# Se hace de esta forma para asegurarnos que la parte clickeable de cada hexagono
		# corresponda a la parte visual del hexagono
		button.texture_click_mask = bitmap

func _on_texture_button_pressed():
	emit_signal("hex_pressed", self)

func _on_texture_button_mouse_entered():
	emit_signal("hex_hovered", self)
