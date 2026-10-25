extends Node
# Himmel, Sonne, Nebel, Tonemapping. mode: "day" | "sunset"
static func make(root:Node3D,mode:="day")->DirectionalLight3D:
	var we=WorldEnvironment.new();var env=Environment.new()
	var sky=Sky.new();var ps=ProceduralSkyMaterial.new()
	ps.sky_top_color=Color(0.3,0.47,0.74);ps.sky_horizon_color=Color(0.78,0.82,0.86);ps.sky_curve=0.12;ps.sky_energy_multiplier=1.0
	ps.ground_bottom_color=Color(0.2,0.19,0.17);ps.ground_horizon_color=Color(0.6,0.62,0.62);ps.sun_angle_max=20.0;ps.sun_curve=0.12
	if mode=="sunset":
		ps.sky_top_color=Color(0.22,0.3,0.55);ps.sky_horizon_color=Color(1.0,0.62,0.38);ps.ground_horizon_color=Color(0.7,0.5,0.4)
	sky.sky_material=ps;sky.radiance_size=Sky.RADIANCE_SIZE_256
	# Realistischer Himmel mit ziehenden Wolken (statt einfachem Verlauf)
	var sm=ShaderMaterial.new();sm.shader=load("res://shaders/sky_clouds.gdshader")
	if mode=="sunset":
		sm.set_shader_parameter("zenith",Color(0.18,0.26,0.5));sm.set_shader_parameter("horizon",Color(1.0,0.62,0.4))
		sm.set_shader_parameter("cloud_light",Color(1.0,0.75,0.55));sm.set_shader_parameter("cloud_shadow",Color(0.45,0.35,0.42))
	sm.set_shader_parameter("time_offset",123.0)
	sky.sky_material=sm;sky.process_mode=Sky.PROCESS_MODE_REALTIME
	env.background_mode=Environment.BG_SKY;env.sky=sky
	env.ambient_light_source=Environment.AMBIENT_SOURCE_SKY;env.ambient_light_sky_contribution=0.55;env.ambient_light_color=Color(0.62,0.6,0.56);env.ambient_light_energy=1.0;env.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode=Environment.TONE_MAPPER_AGX;env.tonemap_exposure=1.0
	env.glow_enabled=true;env.glow_intensity=0.4;env.glow_bloom=0.04;env.glow_hdr_threshold=1.2
	env.ssao_enabled=true;env.ssao_radius=1.0;env.ssao_intensity=2.0
	env.fog_enabled=true;env.fog_light_color=Color(0.7,0.76,0.84);env.fog_density=0.0018;env.fog_aerial_perspective=0.5;env.fog_sky_affect=0.0
	env.adjustment_enabled=true;env.adjustment_contrast=1.08;env.adjustment_saturation=1.1
	we.environment=env;root.add_child(we)
	var l=DirectionalLight3D.new();l.shadow_enabled=true;l.directional_shadow_max_distance=140.0;l.shadow_blur=1.2;l.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	if mode=="sunset":
		l.light_color=Color(1.0,0.72,0.45);l.light_energy=2.4;l.rotation_degrees=Vector3(-11,-118,0)
		env.fog_light_color=Color(0.95,0.7,0.5);env.adjustment_saturation=1.18;env.tonemap_exposure=1.15
	else:
		l.light_color=Color(1.0,0.93,0.82);l.light_energy=2.6;l.rotation_degrees=Vector3(-42,-125,0)
	root.add_child(l)
	return l
