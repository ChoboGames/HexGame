class_name MapSerializer
extends RefCounted

const USER_MAPS_DIR = "user://maps/"
const DEFAULT_MAPS_DIR = "res://maps/"

static func ensure_user_maps_dir():
	if not DirAccess.dir_exists_absolute(USER_MAPS_DIR):
		DirAccess.make_dir_recursive_absolute(USER_MAPS_DIR)

static func save_map(map_name: String, width: int, height: int, active_hexes: Array, units: Array) -> String:
	ensure_user_maps_dir()
	var clean_name = map_name.strip_edges()
	if clean_name.is_empty():
		clean_name = "Mapa_" + str(Time.get_unix_time_from_system())
	
	var file_name = clean_name.validate_filename() + ".json"
	var full_path = USER_MAPS_DIR + file_name
	
	var map_data = {
		"name": clean_name,
		"width": width,
		"height": height,
		"active_hexes": active_hexes,
		"units": units
	}
	
	var json_string = JSON.stringify(map_data, "  ")
	var file = FileAccess.open(full_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("Mapa guardado exitosamente en: ", full_path)
		return full_path
	else:
		print("Error al guardar el archivo: ", FileAccess.get_open_error())
		return ""

static func load_map(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		print("El archivo no existe: ", file_path)
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}
	
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(content)
	if parse_result == OK:
		var data = json.data
		if data is Dictionary:
			data["path"] = file_path
			return data
	
	print("Error parsing JSON map file: ", file_path)
	return {}

static func list_maps() -> Array:
	var map_list: Array = []
	ensure_user_maps_dir()
	
	# Scan res://maps/
	if DirAccess.dir_exists_absolute(DEFAULT_MAPS_DIR):
		var dir = DirAccess.open(DEFAULT_MAPS_DIR)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir() and file_name.ends_with(".json"):
					var path = DEFAULT_MAPS_DIR + file_name
					var map_data = load_map(path)
					if not map_data.is_empty():
						map_list.append({
							"name": map_data.get("name", file_name.get_basename()),
							"path": path
						})
				file_name = dir.get_next()
	
	# Scan user://maps/
	var user_dir = DirAccess.open(USER_MAPS_DIR)
	if user_dir:
		user_dir.list_dir_begin()
		var file_name = user_dir.get_next()
		while file_name != "":
			if not user_dir.current_is_dir() and file_name.ends_with(".json"):
				var path = USER_MAPS_DIR + file_name
				var map_data = load_map(path)
				if not map_data.is_empty():
					map_list.append({
						"name": map_data.get("name", file_name.get_basename()),
						"path": path
					})
			file_name = user_dir.get_next()
			
	return map_list
