class_name Dijkstra
extends Node2D

# Simple Priority Queue implementation
class PriorityQueue:
	var queue = []

	func push_back(item):
		var index = 0
		while index < queue.size() and queue[index][0] < item[0]:
			index += 1
		queue.insert(index, item)

	func pop_front():
		return queue.pop_front()

	func size():
		return queue.size()

	func clear():
		queue.clear()

# Dijkstra's algorithm function
func dijkstra_hexagonal(start_hexagon: Node2D, count_everything=false) -> Dictionary:
	var moving_unit = start_hexagon.unit
	var distances = {
		start_hexagon: 0
	}
	
	var pq = PriorityQueue.new()
	pq.push_back([0, start_hexagon])
	
	while pq.size() > 0:
		var hex_vector = pq.pop_front()
		var current_distance = hex_vector[0]
		var current_hexagon = hex_vector[1]

		if current_distance > distances.get(current_hexagon, INF):
			continue

		var stops_movement = false
		if moving_unit and moving_unit.has_method("stops_on_hex"):
			stops_movement = moving_unit.stops_on_hex(current_hexagon)
		elif current_hexagon.has_method("stops_movement_on_enter"):
			stops_movement = current_hexagon.stops_movement_on_enter()

		if current_hexagon != start_hexagon and not count_everything and stops_movement:
			continue
		
		var neighbors = current_hexagon.get_neighbors() if current_hexagon.has_method("get_neighbors") else []
		for neighbor in neighbors:
			if not count_everything:
				if moving_unit and moving_unit.has_method("can_pass_through_hex"):
					if neighbor != start_hexagon and not moving_unit.can_pass_through_hex(neighbor):
						continue
				else:
					if not neighbor.visible or (neighbor != start_hexagon and neighbor.unit):
						continue
			
			var cost = 1
			if moving_unit and moving_unit.has_method("get_hex_cost"):
				cost = moving_unit.get_hex_cost(neighbor)
			elif neighbor.has_method("get_cost"):
				cost = neighbor.get_cost(count_everything)
				
			if cost < 0:
				continue
				
			var tentative_distance = current_distance + cost
			
			if not distances.has(neighbor) or tentative_distance < distances[neighbor]:
				distances[neighbor] = tentative_distance
				pq.push_back([tentative_distance, neighbor])
	
	return distances

