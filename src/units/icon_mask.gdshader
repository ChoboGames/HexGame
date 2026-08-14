shader_type canvas_item;

uniform vec2 icon_size = vec2(10000.0, 10000.0);

void fragment() {
	vec2 local = (UV - vec2(0.5)) * icon_size;
	float r = min(icon_size.x, icon_size.y) * 0.5;
	COLOR.a *= 1.0 - smoothstep(r - 1.5, r + 1.5, length(local));
}
