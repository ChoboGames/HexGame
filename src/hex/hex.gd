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


var unit


func _ready():
	$Label.text = name

func _on_texture_button_pressed():
	emit_signal("hex_pressed", self)
