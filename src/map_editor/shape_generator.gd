class_name ShapeGenerator
extends RefCounted

const SQRT3 := 1.7320508075688772

# Tamaño detectado dinámicamente desde la textura de hexagon.png
static var HEX_SIZE: float = _init_hex_size()

# Constantes geométricas derivadas automáticamente de HEX_SIZE
static var HEX_RADIUS: float = HEX_SIZE / 2.0
static var STEP_X: float = HEX_SIZE * 3.0 / 4.0       # spacing horizontal
static var STEP_Y: float = HEX_SIZE * SQRT3 / 4.0      # spacing vertical
static var HEX_POINTS: PackedVector2Array = _build_hex_points()

static func _init_hex_size() -> float:
	var tex = load("res://assets/textures/hexagon.png")
	if tex:
		return float(tex.get_width())
	return 702.0

static func _build_hex_points() -> PackedVector2Array:
	var r := HEX_SIZE / 2.0
	var h := r * SQRT3 / 2.0
	return PackedVector2Array([
		Vector2(-r / 2.0, -h), Vector2(r / 2.0, -h),
		Vector2(r, 0), Vector2(r / 2.0, h),
		Vector2(-r / 2.0, h), Vector2(-r, 0),
		Vector2(-r / 2.0, -h)
	])

static func hex_to_world(i: int, j: int) -> Vector2:
	return Vector2((i + j) * STEP_X, (i - j) * STEP_Y)

static func world_to_hex(pos: Vector2) -> Vector2i:
	var u = pos.x / STEP_X
	var v = pos.y / STEP_Y
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
