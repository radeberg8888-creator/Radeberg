shader_type spatial;
// Fahrbahn: Asphalt + Markierungen aus UV (UV.x = seitlicher Abstand zur Mitte in m, UV.y = Lauflänge in m)
// COLOR.a = Markierungen an/aus (an Kreuzungen aus), COLOR.r = Verschleiß (0 neu .. 1 kaputt)
uniform sampler2D alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D crack : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float half_width = 5.5;
uniform int lanes = 1;            // Fahrstreifen je Richtung
uniform float median = 0.0;       // halbe Breite des Mittelstreifens (Autobahn/Allee)
uniform int center_mode = 1;      // 0 keine, 1 gestrichelt, 2 durchgezogen
uniform vec3 line_col : source_color = vec3(0.92, 0.92, 0.88);
uniform vec3 tint : source_color = vec3(1.0);
uniform float edge_lines = 1.0;
varying vec3 wpos;
void vertex(){ wpos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
float band(float x, float c, float w){ return step(abs(x - c), w * 0.5); }
void fragment(){
	float x = UV.x; float ax = abs(x); float s = UV.y;
	vec2 uv = vec2(x, s) / 5.0;
	vec3 a = mix(texture(alb, uv).rgb, texture(alb, wpos.xz * 0.013).rgb, 0.3) * tint;
	a = mix(a, vec3(0.30, 0.30, 0.31) * tint, 0.4);   // weniger fleckig
	float wear = COLOR.r;
	// Flicken und Risse (dunkler) bei Verschleiß
	float patchv = texture(crack, wpos.xz * 0.021).r;
	a *= 1.0 - wear * 0.15 * smoothstep(0.5, 0.85, patchv);
	float m = 0.0;
	float lw = (half_width - 0.5 - median) / float(lanes);
	if (edge_lines > 0.5) m += band(ax, half_width - 0.45, 0.2);
	float dash = step(fract(s / 12.0), 0.5);
	for (int k = 1; k < 4; k++) { if (k < lanes) m += band(ax, median + lw * float(k), 0.15) * dash; }
	if (median < 0.01) {
		if (center_mode == 1) m += band(x, 0.0, 0.14) * dash;
		if (center_mode == 2) m += band(ax, 0.12, 0.12);
	}
	m = clamp(m, 0.0, 1.0) * COLOR.a;
	// abgefahrene Markierung
	m *= 1.0 - wear * 0.6 * smoothstep(0.3, 0.7, texture(crack, wpos.xz * 0.09).g);
	ALBEDO = mix(a, line_col, m);
	ROUGHNESS = mix(0.88, 0.6, m);
	NORMAL_MAP = texture(nrm, uv).rgb;
}
