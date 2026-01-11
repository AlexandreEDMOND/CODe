shader_type canvas_item;

uniform float softness : hint_range(0.0, 0.2) = 0.02;

void fragment() {
	vec2 uv = UV;
	vec2 centered = uv - vec2(0.5);
	float dist = length(centered) * 2.0;
	float mask = smoothstep(1.0, 1.0 - softness, dist);
	vec4 col = texture(TEXTURE, uv);
	COLOR = vec4(col.rgb, col.a * mask);
}
