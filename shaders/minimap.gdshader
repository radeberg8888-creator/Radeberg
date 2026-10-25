shader_type canvas_item;
// Runder, gedrehter Ausschnitt aus dem Kartenbild
uniform sampler2D map : filter_linear;
uniform vec2 center = vec2(0.5);
uniform vec2 span = vec2(0.15);
uniform float rot = 0.0;
void fragment(){
	vec2 d = UV - 0.5;
	float r = length(d);
	if (r > 0.5) discard;
	float c = cos(rot), s = sin(rot);
	vec2 q = vec2(d.x * c - d.y * s, d.x * s + d.y * c);
	vec2 uv = center + q * span;
	vec3 col = texture(map, uv).rgb;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) col = vec3(0.1, 0.25, 0.32);
	col = mix(col, col * 0.75, smoothstep(0.42, 0.5, r));
	COLOR = vec4(col, 0.92);
}
