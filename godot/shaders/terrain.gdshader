shader_type spatial;
// Terrain de l'île : mélange herbe / herbe sèche / sable / roche / neige selon les couleurs de sommets
uniform sampler2D tex_grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_dry : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_sand : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_normal : hint_normal, filter_linear_mipmap, repeat_enable;

varying vec4 mixw;
varying vec3 wpos;

void vertex() {
	mixw = COLOR;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wpos.xz * 0.09;
	vec2 far_uv = wpos.xz * 0.006;
	float macro = texture(tex_grass, far_uv).g * 1.6;
	vec3 grass = texture(tex_grass, uv).rgb * mix(0.8, 1.15, macro);
	vec3 dry = texture(tex_dry, uv).rgb;
	vec3 sand = texture(tex_sand, uv * 0.8).rgb;
	vec3 rock = texture(tex_rock, vec2(wpos.x + wpos.y * 0.7, wpos.z - wpos.y * 0.5) * 0.04).rgb;
	vec3 c = mix(grass, dry, clamp(mixw.b, 0.0, 1.0));
	c = mix(c, sand, clamp(mixw.r, 0.0, 1.0));
	c = mix(c, rock, clamp(mixw.g, 0.0, 1.0));
	c = mix(c, vec3(0.93, 0.95, 0.98), clamp(mixw.a, 0.0, 1.0));
	ALBEDO = c;
	ROUGHNESS = mix(0.95, 0.7, mixw.a);
	NORMAL_MAP = texture(tex_normal, uv).rgb;
	NORMAL_MAP_DEPTH = 0.8;
}
