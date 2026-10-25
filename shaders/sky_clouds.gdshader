shader_type sky;
// Realistischer Himmel: Rayleigh-ähnlicher Verlauf, Sonne mit Halo, ziehende Wolken (mehrlagiges Rauschen, von der Sonne beleuchtet)
uniform vec3 zenith : source_color = vec3(0.22, 0.42, 0.75);
uniform vec3 horizon : source_color = vec3(0.70, 0.80, 0.90);
uniform vec3 ground : source_color = vec3(0.30, 0.30, 0.30);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.5;
uniform float cloud_speed = 0.006;
uniform vec2 wind = vec2(1.0, 0.35);
uniform vec3 cloud_light : source_color = vec3(1.0, 0.98, 0.95);
uniform vec3 cloud_shadow : source_color = vec3(0.52, 0.56, 0.64);
uniform float sun_size = 0.9997;
uniform float time_offset = 0.0;

float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p){
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p){
	float v = 0.0; float a = 0.5;
	mat2 r = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 6; i++){ v += a * noise(p); p = r * p * 2.03 + 3.1; a *= 0.5; }
	return v;
}
void sky(){
	vec3 d = EYEDIR;
	float t = TIME + time_offset;
	vec3 sun = LIGHT0_DIRECTION;
	float h = d.y;
	// Atmosphäre
	vec3 col = mix(horizon, zenith, pow(clamp(h, 0.0, 1.0), 0.55));
	float sd = max(dot(d, sun), 0.0);
	col += LIGHT0_COLOR * (pow(sd, 8.0) * 0.18 + pow(sd, 64.0) * 0.35) * LIGHT0_ENERGY * 0.25;
	if (h < 0.0){ col = mix(horizon, ground, clamp(-h * 4.0, 0.0, 1.0)); }
	// Sonnenscheibe
	if (sd > sun_size) col += LIGHT0_COLOR * 6.0;
	// Wolken: Projektion auf eine Wolkendecke in großer Höhe
	if (h > 0.0){
		vec2 uv = d.xz / (h + 0.08) * 0.9;
		vec2 drift = wind * t * cloud_speed;
		float n = fbm(uv * 1.3 + drift);
		float n2 = fbm(uv * 3.1 + drift * 1.7 + 7.0);
		float dens = smoothstep(1.0 - cloud_cover - 0.1, 1.0 - cloud_cover + 0.35, n * 0.75 + n2 * 0.35);
		// Beleuchtung: Probe in Richtung Sonne -> dünnere Stelle = heller Rand
		float ns = fbm((uv + sun.xz * 0.12) * 1.3 + drift);
		float shade = clamp(0.55 + (n - ns) * 2.5, 0.0, 1.0);
		vec3 c = mix(cloud_shadow, cloud_light, shade);
		c += LIGHT0_COLOR * pow(sd, 6.0) * 0.4 * (1.0 - dens);   // Durchleuchtung nahe der Sonne
		float fade = smoothstep(0.0, 0.18, h);                     // zum Horizont ausblenden
		col = mix(col, c, dens * fade * 0.95);
	}
	COLOR = col;
}
