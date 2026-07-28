shader_type canvas_item;

uniform sampler2D hex_mask : hint_default_white;

void fragment() {
	COLOR.a *= texture(hex_mask, UV).a;
}
