shader_type spatial;
// Gelände: Mischung aus Gras, Waldboden, Sand, Fels und Trockengras (Gewichte als Vertexfarbe),
// zwei Kachelgrößen gegen sichtbare Wiederholung, Höhenabhängige Variation
uniform sampler2D g_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D g_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D f_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D f_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D s_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D s_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D r_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D r_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D d_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D d_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 wpos;
void vertex(){ wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
vec3 two(sampler2D t, vec2 uv){ return mix(texture(t, uv).rgb, texture(t, uv * 0.13 + 0.37).rgb, 0.35); }
void fragment(){
	vec4 w = COLOR;
	float dry = clamp(1.0 - w.r - w.g - w.b - w.a, 0.0, 1.0);
	vec2 uv = UV;
	vec3 c = two(g_alb, uv) * vec3(0.84, 0.88, 0.7) * w.r + two(f_alb, uv) * w.g + two(s_alb, uv) * w.b + two(r_alb, uv * 0.5) * w.a + two(d_alb, uv) * dry * vec3(0.66, 0.7, 0.46);
	vec3 n = texture(g_nrm, uv).rgb * w.r + texture(f_nrm, uv).rgb * w.g + texture(s_nrm, uv).rgb * w.b + texture(r_nrm, uv * 0.5).rgb * w.a + texture(d_nrm, uv).rgb * dry;
	// großflächige Farbvariation
	float v = sin(wpos.x * 0.011) * sin(wpos.z * 0.013) * 0.08 + sin(wpos.x * 0.0031 + wpos.z * 0.0027) * 0.07 + sin(wpos.x*0.047+wpos.z*0.031)*0.03;
	ALBEDO = c * (1.0 + v) * 0.8;
	NORMAL_MAP = n;
	ROUGHNESS = 0.92;
}
