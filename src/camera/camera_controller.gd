extends Camera2D
class_name CameraController2D

@export_category("Zoom Settings")
@export var min_zoom: float = 0.05
@export var max_zoom: float = 2.0
@export var zoom_factor: float = 1.15
@export var zoom_speed: float = 15.0

@export_category("Pan Settings")
@export var drag_button: MouseButton = MOUSE_BUTTON_MIDDLE

var _target_zoom: float = 0.145
var _dragging: bool = false

func _ready() -> void:
	_target_zoom = zoom.x

func _process(delta: float) -> void:
	if not is_equal_approx(zoom.x, _target_zoom):
		var mouse_pos = get_global_mouse_position()
		var new_z = lerp(zoom.x, _target_zoom, zoom_speed * delta)
		if abs(new_z - _target_zoom) < 0.001:
			new_z = _target_zoom
		zoom = Vector2(new_z, new_z)
		global_position += mouse_pos - get_global_mouse_position()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_target_zoom = clamp(_target_zoom * zoom_factor, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_target_zoom = clamp(_target_zoom / zoom_factor, min_zoom, max_zoom)
		elif event.button_index == drag_button:
			_dragging = event.pressed
			
	elif event is InputEventMouseMotion and _dragging:
		global_position -= event.relative / zoom
