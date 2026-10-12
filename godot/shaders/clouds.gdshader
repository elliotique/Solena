shader_type spatial;
render_mode cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
// Couche de nuages qui défile lentement à 1 100 m d'altitude (éclairée par le soleil, traversable en avion)

uniform sampler2D noise_a : repeat_enable, filter_linear_mipmap;
uniform float cover = 0.56;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wp.xz * 0.00011 + vec2(TIME * 0.0018, TIME * 0.0009);
	float n = texture(noise_a, uv).r * 0.65 + texture(noise_a, uv * 3.1 + vec2(0.3, 0.7)).r * 0.35;
	float a = smoothstep(cover, cover + 0.22, n);
	float d = length(wp.xz - CAMERA_POSITION_WORLD.xz);
	a *= 1.0 - smoothstep(9000.0, 16000.0, d);
	ALBEDO = vec3(1.0) * mix(0.82, 1.0, n);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	ALPHA = a * 0.85;
}
