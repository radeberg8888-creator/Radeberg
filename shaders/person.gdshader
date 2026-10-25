shader_type spatial;
// Personen-Variation: Hautfarbe, Haarfarbe und Kleiderfarbe pro Figur, Details der Originaltextur bleiben erhalten
render_mode cull_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_albedo = true;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool use_vcol = false;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform bool has_normal = false;
uniform sampler2D rough_tex : hint_default_white;
uniform bool has_rough = false;
uniform int rough_channel = 1;
uniform float roughness = 0.6;
uniform float metallic = 0.0;
uniform bool alpha_cut = false;
uniform bool use_uv2 = false;
uniform int mat_class = 0; // 0 Kleidung, 1 Haut, 2 Haare
uniform vec3 ref_skin : source_color = vec3(0.75,0.55,0.45);
uniform vec3 ref_hair : source_color = vec3(0.1,0.07,0.05);
uniform vec3 skin : source_color = vec3(0.75,0.55,0.45);
uniform vec3 hair : source_color = vec3(0.1,0.07,0.05);
uniform float cloth_hue = 0.0;
uniform float cloth_sat = 1.0;
uniform float cloth_val = 1.0;
uniform vec3 cloth_tint : source_color = vec3(0.3);
uniform float cloth_mix = 0.0;
varying float vh;
void vertex(){ vh = VERTEX.y; }

float lum(vec3 c){ return dot(c, vec3(0.299,0.587,0.114)); }
vec3 rgb2hsv(vec3 c){
	vec4 K = vec4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y); float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
vec3 hsv2rgb(vec3 c){
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0/3.0, 1.0/3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}
void fragment(){
	vec4 t = has_albedo ? texture(albedo_tex, UV) : vec4(1.0);
	vec3 c = t.rgb * albedo_color.rgb;
	if (use_vcol) c *= COLOR.rgb;
	float ms = 0.0; float mh = 0.0; float keep = 0.0;
	if (use_uv2){ ms = UV2.x; mh = max(UV2.y, 0.0); keep = max(-UV2.y, 0.0); }
	else if (mat_class == 1){ ms = 1.0; }
	else if (mat_class == 2){ mh = 1.0; }
	// Haut: Helligkeitsdetails behalten, Farbton der Zielhaut
	vec3 s = skin * (lum(c) / max(lum(ref_skin), 1e-3));
	vec3 h = hair * (0.35 + 1.3 * lum(c) / max(lum(ref_hair), 0.05));
	vec3 hsv = rgb2hsv(c); hsv.x = fract(hsv.x + cloth_hue); hsv.y = clamp(hsv.y * cloth_sat, 0.0, 1.0); hsv.z = clamp(hsv.z * cloth_val, 0.0, 1.0);
	vec3 cl = hsv2rgb(hsv);
	vec3 tinted = cloth_tint * clamp(lum(c) / 0.32, 0.0, 2.2);
	cl = mix(cl, tinted, cloth_mix);
	float mc = clamp(1.0 - ms - mh - keep, 0.0, 1.0);
	ALBEDO = mix(clamp(s * ms + h * mh + cl * mc, 0.0, 1.0), c, keep);
	if (alpha_cut){ ALPHA = t.a * albedo_color.a; ALPHA_SCISSOR_THRESHOLD = 0.4; }
	if (has_normal){ NORMAL_MAP = texture(normal_tex, UV).rgb; }
	float r = roughness;
	if (has_rough){ vec4 rt = texture(rough_tex, UV); r *= rough_channel==0?rt.r:(rough_channel==1?rt.g:(rough_channel==2?rt.b:rt.a)); }
	ROUGHNESS = mix(r, 0.55, ms*0.5);
	METALLIC = metallic * mc;
	SPECULAR = 0.5;
}
