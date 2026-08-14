shader_type canvas_item;

uniform vec4 ring_color : source_color = vec4(1.0);
uniform vec2 quad_size = vec2(540.0, 540.0);
uniform float ring_width = 32.0;

void fragment() {
	vec2 local = (UV - vec2(0.5)) * quad_size;
	float r = min(quad_size.x, quad_size.y) * 0.5;
	float d = length(local);
	float outer = 1.0 - smoothstep(r - 1.5, r + 1.5, d);
	float inner = 1.0 - smoothstep(r - ring_width - 1.5, r - ring_width + 1.5, d);
	float ring = outer - inner;
	COLOR = vec4(ring_color.rgb, ring_color.a * ring);
}
