shader_type spatial;
render_mode blend_mix, cull_disabled, specular_schlick_ggx;
// Mer autour de l'île : vagues, eau turquoise sur les hauts-fonds, écume au bord des plages

uniform vec3 deep_color : source_color = vec3(0.02, 0.18, 0.32);
uniform vec3 shallow_color : source_color = vec3(0.1, 0.62, 0.66);
uniform sampler2D wave_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D terrain_height : filter_linear, repeat_disable;
uniform float terrain_size = 7200.0;
uniform float sea_level = -3.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME;
	VERTEX.y += sin(world_pos.x * 0.045 + t * 0.9) * 0.3 + cos(world_pos.z * 0.035 + t * 0.7) * 0.25;
}

void fragment() {
	vec2 uv1 = world_pos.xz * 0.03 + vec2(TIME * 0.012, TIME * 0.008);
	vec2 uv2 = world_pos.xz * 0.011 - vec2(TIME * 0.006, -TIME * 0.01);
	NORMAL_MAP = normalize(mix(texture(wave_normal, uv1).rgb, texture(wave_normal, uv2).rgb, 0.5));
	NORMAL_MAP_DEPTH = 0.6;
	vec2 tuv = (world_pos.xz + terrain_size * 0.5) / terrain_size;
	float ground = texture(terrain_height, clamp(tuv, vec2(0.0), vec2(1.0))).r;
	if (tuv.x < 0.0 || tuv.y < 0.0 || tuv.x > 1.0 || tuv.y > 1.0) ground = -40.0;
	float depth = sea_level - ground;
	vec3 col = mix(shallow_color, deep_color, clamp(depth / 14.0, 0.0, 1.0));
	float foam = (1.0 - smoothstep(0.0, 1.4, depth)) * (0.65 + 0.35 * sin(world_pos.x * 0.25 + world_pos.z * 0.2 + TIME * 2.0));
	ALBEDO = mix(col, vec3(0.96), clamp(foam, 0.0, 1.0) * 0.8);
	ROUGHNESS = mix(0.04, 0.45, foam);
	SPECULAR = 0.7;
}
