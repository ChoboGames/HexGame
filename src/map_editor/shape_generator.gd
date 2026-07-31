class_name ShapeGenerator
extends RefCounted

static func hex_to_world(i: int, j: int) -> Vector2:
	var x = (j * 720.0 + i * 720.0) * (4.5 / 6.0)
	var y = (-j * 720.0 + i * 720.0) / 2.0
	return Vector2(x, y)

static func world_to_hex(pos: Vector2) -> Vector2i:
	var u = pos.x / 540.0
	var v = pos.y / 360.0
	var fi = (u + v) / 2.0
	var fj = (u - v) / 2.0
	var fs = -(fi + fj)
	var ri = round(fi)
	var rj = round(fj)
	var rs = round(fs)
	var di = abs(ri - fi)
	var dj = abs(rj - fj)
	var ds = abs(rs - fs)
	if di > dj and di > ds:
		ri = -(rj + rs)
	elif dj > ds:
		rj = -(ri + rs)
	return Vector2i(int(ri), int(rj))

static func hex_distance(i1: int, j1: int, i2: int, j2: int) -> int:
	var q1 = j1
	var r1 = i1
	var q2 = j2
	var r2 = i2
	return (abs(q1 - q2) + abs(r1 - r2) + abs((q1 + r1) - (q2 + r2))) / 2
