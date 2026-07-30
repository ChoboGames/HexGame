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

		if current_hexagon != start_hexagon and not count_everything \
				and current_hexagon.has_method("stops_movement_on_enter") \
				and current_hexagon.stops_movement_on_enter():
			continue
		
		var neighbors = current_hexagon.get_neighbors() if current_hexagon.has_method("get_neighbors") else []
		for neighbor in neighbors:
			if not count_everything:
				if not neighbor.visible or (neighbor != start_hexagon and neighbor.unit):
					continue
			
			var cost = neighbor.get_cost(count_everything) if neighbor.has_method("get_cost") else 1
			if cost < 0:
				continue
				
			var tentative_distance = current_distance + cost
			
			if not distances.has(neighbor) or tentative_distance < distances[neighbor]:
				distances[neighbor] = tentative_distance
				pq.push_back([tentative_distance, neighbor])
	
	return distances
