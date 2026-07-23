extends Control

@onready var map_selector_panel = $MapSelectorPanel
@onready var dim_overlay = $DimOverlay
@onready var map_option_button = $MapSelectorPanel/MarginContainer/VBoxContainer/MapOptionButton
@onready var status_label = $MapSelectorPanel/MarginContainer/VBoxContainer/StatusLabel

var maps_data: Array = []

func _ready():
	dim_overlay.visible = false
	map_selector_panel.visible = false
	refresh_map_list()

func refresh_map_list():
	map_option_button.clear()
	maps_data = MapSerializer.list_maps()
	
	if maps_data.is_empty():
		status_label.text = "No se encontraron mapas guardados."
		return
	
	status_label.text = "Selecciona un mapa para iniciar:"
	for map_info in maps_data:
		map_option_button.add_item(map_info.get("name", "Mapa Sin Nombre"))

func _on_editor_button_pressed():
	MapEditor.selected_map_path = ""
	MapEditor.launch_mode = "EDITOR"
	get_tree().change_scene_to_file("res://src/map_editor/map_editor.tscn")

func _on_play_button_pressed():
	refresh_map_list()
	dim_overlay.visible = true
	map_selector_panel.visible = true

func _on_confirm_play_pressed():
	if maps_data.is_empty():
		return
	
	var selected_idx = map_option_button.selected
	if selected_idx >= 0 and selected_idx < maps_data.size():
		var chosen_map = maps_data[selected_idx]
		MapEditor.selected_map_path = chosen_map.get("path", "")
		MapEditor.launch_mode = "GAME"
		get_tree().change_scene_to_file("res://src/map_editor/map_editor.tscn")

func _on_cancel_play_pressed():
	dim_overlay.visible = false
	map_selector_panel.visible = false

func _on_quit_button_pressed():
	get_tree().quit()
