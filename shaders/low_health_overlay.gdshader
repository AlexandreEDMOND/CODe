shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float vignette_softness : hint_range(0.0, 1.0) = 0.4;
uniform float blur_strength : hint_range(0.0, 4.0) = 1.5;
uniform vec3 tint = vec3(1.0, 0.1, 0.1);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv - vec2(0.5);
	float edge = max(abs(centered.x), abs(centered.y)) * 2.0;
	float vignette = smoothstep(0.6 - vignette_softness, 1.0, edge);
	float effect = clamp(vignette * intensity, 0.0, 1.0);

	vec2 texel = SCREEN_PIXEL_SIZE * blur_strength;
	vec4 col = texture(screen_tex, uv);
	vec4 blur = (
		texture(screen_tex, uv + vec2(texel.x, 0.0)) +
		texture(screen_tex, uv + vec2(-texel.x, 0.0)) +
		texture(screen_tex, uv + vec2(0.0, texel.y)) +
		texture(screen_tex, uv + vec2(0.0, -texel.y))
	) * 0.25;

	vec3 mixed = mix(col.rgb, blur.rgb, effect);
	mixed = mix(mixed, tint, effect * 0.6);
	COLOR = vec4(mixed, 1.0);
}
