extends RefCounted
# Materialbibliothek: alle Oberflächen mit Farbe, Normalen und Rauheit (PBR)
const T="res://assets/textures/"
static var cache:={}

static func pbr(name:String,scale:float,tint:=Color(1,1,1),triplanar:=true)->StandardMaterial3D:
	var key=name+str(scale)+str(tint)+str(triplanar)
	if cache.has(key):return cache[key]
	var m=StandardMaterial3D.new()
	m.albedo_texture=load(T+name+"_albedo.jpg");m.albedo_color=tint
	if ResourceLoader.exists(T+name+"_normal.png"):
		m.normal_enabled=true;m.normal_texture=load(T+name+"_normal.png");m.normal_scale=1.0
	if ResourceLoader.exists(T+name+"_orm.png"):
		var orm=load(T+name+"_orm.png")
		m.roughness_texture=orm;m.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_GREEN;m.roughness=1.0
		m.ao_enabled=true;m.ao_texture=orm;m.ao_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED;m.ao_light_affect=0.6
	if triplanar:
		m.uv1_triplanar=true;m.uv1_world_triplanar=true;m.uv1_scale=Vector3(scale,scale,scale);m.uv1_triplanar_sharpness=4.0
	else:
		m.uv1_scale=Vector3(scale,scale,1)
	m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	cache[key]=m;return m

static func flat(c:Color,rough:=0.7,metal:=0.0)->StandardMaterial3D:
	var key="flat"+str(c)+str(rough)+str(metal)
	if cache.has(key):return cache[key]
	var m=StandardMaterial3D.new();m.albedo_color=c;m.roughness=rough;m.metallic=metal
	cache[key]=m;return m

static func glass()->StandardMaterial3D:
	if cache.has("glass"):return cache["glass"]
	var m=StandardMaterial3D.new();m.albedo_color=Color(0.10,0.13,0.16);m.metallic=0.6;m.roughness=0.04;m.metallic_specular=1.0
	cache["glass"]=m;return m

static func emissive(c:Color,e:float)->StandardMaterial3D:
	var m=StandardMaterial3D.new();m.albedo_color=c;m.emission_enabled=true;m.emission=c;m.emission_energy_multiplier=e;m.roughness=0.6;return m

static func bricks(scale:=0.5)->StandardMaterial3D:
	if cache.has("bricks"):return cache["bricks"]
	var m=StandardMaterial3D.new();m.albedo_texture=load(T+"bricks_albedo.jpg");m.normal_enabled=true;m.normal_texture=load(T+"bricks_normal.jpg")
	m.ao_enabled=true;m.ao_texture=load(T+"bricks_ao.jpg");m.roughness=0.85
	m.uv1_triplanar=true;m.uv1_world_triplanar=true;m.uv1_scale=Vector3(scale,scale,scale)
	cache["bricks"]=m;return m

static func shop_glass()->StandardMaterial3D:
	if cache.has("shopglass"):return cache["shopglass"]
	var m=StandardMaterial3D.new();m.albedo_color=Color(0.75,0.85,0.9,0.12);m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.metallic=0.2;m.roughness=0.03;m.metallic_specular=1.0
	cache["shopglass"]=m;return m
