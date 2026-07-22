extends Node2D


func color_hexagons(hex, range=0):
	# hex.set_modulate(Color(1, 1, 1, 1))
	hex.set_modulate(Color(0.5, 1, 0.5, 1))
	var distance_objects = dijkstra_hexagonal(hex)
	var new_distance_objects = []
	for distance_object in distance_objects:
		var destination_hex = distance_object
		if not destination_hex.visible or destination_hex.unit:
			continue
		var distance = distance_objects[destination_hex]
		var player_index = hex.unit.player_index
		if distance > 0 and range > 0 and distance <= range:
			destination_hex.set_modulate(Color(1 * player_index, 0.7, 1 * (1 - player_index), 1))
			new_distance_objects.append(distance_object)

	return new_distance_objects
	
	
func color_hexagon_attack(hex, range=0):
	# hex.set_modulate(Color(1, 1, 1, 1))
	hex.set_modulate(Color(0.5, 1, 0.5, 1))
	var distance_objects = dijkstra_hexagonal(hex, true)
	var new_distance_objects = []
	for distance_object in distance_objects:
		var destination_hex = distance_object

		var distance = distance_objects[destination_hex]
		var player_index = hex.unit.player_index
		if distance > 0 and range > 0 and distance <= range and destination_hex.unit:
			destination_hex.set_modulate(Color(1, 0, 0, 1))
			new_distance_objects.append(distance_object)

	return new_distance_objects

# Simple Priority Queue implementation
class PriorityQueue:
	var queue = []

	func push_back(item, start_hexagon=null, count_everything=false):
		# Add item to the queue based on its priority
		if not count_everything and not item[1].visible or (start_hexagon != item[1] and item[1].unit):
			return
			
		var index = 0
		while index < queue.size() and queue[index][0] < item[0]:
			index += 1
		queue.insert(index, item)

	func pop_front():
		# Remove and return the item with the highest priority
		return queue.pop_front()

	func size():
		# Return the size of the queue
		return queue.size()

	func clear():
		# Clear the queue
		queue.clear()

# Dijkstra's algorithm function
func dijkstra_hexagonal(start_hexagon: Node2D, count_everything=false) -> Dictionary:
	# Initialize distances to all hexagons as infinity
	var distances = {
		start_hexagon: 0
	}
	
	# Priority queue to keep track of hexagons to visit
	var pq = PriorityQueue.new()
	pq.push_back([0, start_hexagon], start_hexagon, count_everything)
	
	while pq.size() > 0:
		# Pop hexagon with smallest tentative distance
		var hex_vector = pq.pop_front()
		var current_distance = hex_vector[0]
		var current_hexagon = hex_vector[1]
		
		# Visit neighboring hexagons
		for neighbor in get_neighbors(current_hexagon):
			# Calculate tentative distance through current hexagon
			var tentative_distance = current_distance + 1  # Assuming uniform distance between hexagons
			
			# Update distance if shorter path found
			if not distances.has(neighbor) or tentative_distance < distances[neighbor]:
				distances[neighbor] = tentative_distance
				pq.push_back([tentative_distance, neighbor], start_hexagon, count_everything)
	
	return distances

# Function to get neighboring hexagons based on current hexagon
func get_neighbors(hexagon: Node2D) -> Array:
	var neighbors = []
	if hexagon.up_left:
		neighbors.append(hexagon.up_left)
	if hexagon.up_center:
		neighbors.append(hexagon.up_center)
	if hexagon.up_right:
		neighbors.append(hexagon.up_right)
	if hexagon.down_left:
		neighbors.append(hexagon.down_left)
	if hexagon.down_center:
		neighbors.append(hexagon.down_center)
	if hexagon.down_right:
		neighbors.append(hexagon.down_right)
	
	return neighbors
