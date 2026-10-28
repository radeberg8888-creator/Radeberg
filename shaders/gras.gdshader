shader_type spatial;
render_mode cull_disabled;
// Gras-Büschel: Alpha-Schnitt, Wind, Farbe je Instanz (frisch/trocken), sanft ausblenden am Rand
uniform sampler2D tex : source_color, filter_linear_mipmap;
varying float fade;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = VERTEX.y;
	float wind = sin(TIME * 1.7 + w.x * 0.35 + w.z * 0.25) * 0.08 + sin(TIME * 3.1 + w.x * 1.3) * 0.025;
	VERTEX.x += wind * h * 1.8;
	VERTEX.z += wind * h * 0.9;
	NORMAL = vec3(0.0, 1.0, 0.0);
	float d = length(w.xz - (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xz);
	fade = 1.0 - smoothstep(24.0, 33.0, d);
	COLOR = COLOR;
}
void fragment() {
	vec4 c = texture(tex, UV);
	float n = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
	if (c.a < 0.5 || fade < n) discard;
	ALBEDO = c.rgb * COLOR.rgb * (0.75 + 0.25 * (1.0 - UV.y));
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
	BACKLIGHT = vec3(0.25, 0.35, 0.1);
}
