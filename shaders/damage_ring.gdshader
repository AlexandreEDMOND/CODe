shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float radius : hint_range(0.0, 0.5) = 0.5;
uniform float thickness : hint_range(0.0, 0.5) = 0.06;
uniform float softness : hint_range(0.0, 0.2) = 0.02;
uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 0.25);

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered);
	float inner = smoothstep(radius - thickness - softness, radius - thickness, dist);
	float outer = smoothstep(radius - softness, radius, dist);
	float ring = clamp(inner - outer, 0.0, 1.0);
	float alpha = ring * intensity;
	COLOR = vec4(color.rgb, color.a * alpha);
}
