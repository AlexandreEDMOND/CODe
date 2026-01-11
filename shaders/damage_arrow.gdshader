shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color : source_color = vec4(1.0, 0.1, 0.1, 0.9);

void fragment() {
	vec2 uv = UV;
	float edge = 1.0 - abs(uv.x - 0.5) * 2.0;
	float mask = step(uv.y, edge);
	COLOR = vec4(color.rgb, color.a * mask * intensity);
}
