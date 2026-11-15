extends RefCounted
# Comic-Stil 2 ("gemalt"): ersetzt flache Toon-Materialien der Welt durch einen Shader mit gemalten
# Detailtexturen (Holzverschalung, Schindeln, Backstein, Asphalt, Gehwegplatten, Gras, Putz), die nach
# Flächenrichtung und Farbe gewählt werden, dazu Tusche-Konturen als Nachbearbeitung und wärmeres Licht.
# Probe: galerie --nur=stil. Materialien werden in den Meshes getauscht und können zurückgestellt werden.

const TEX:=["holz","schindel","backstein","asphalt","platten","gras","putz"]
static var _texturen:={}
static var _shader:Shader
static var _cache:={}       # StandardMaterial3D -> ShaderMaterial
static var _rueck:=[]       # [mesh, surface, original]
static var _terr_alt:={}    # Knoten -> altes material_override

static func _tex(n:String)->Texture2D:
	if not _texturen.has(n):_texturen[n]=load("res://assets/stil/%s.png"%n)
	return _texturen[n]

const CODE:="""shader_type spatial;
render_mode diffuse_toon,specular_disabled;
uniform vec4 farbe:source_color=vec4(1.0);
uniform sampler2D t_holz:repeat_enable,filter_linear_mipmap;
uniform sampler2D t_schindel:repeat_enable,filter_linear_mipmap;
uniform sampler2D t_backstein:repeat_enable,filter_linear_mipmap;
uniform sampler2D t_asphalt:repeat_enable,filter_linear_mipmap;
uniform sampler2D t_platten:repeat_enable,filter_linear_mipmap;
uniform sampler2D t_gras:repeat_enable,filter_linear_mipmap;
uniform sampler2D t_putz:repeat_enable,filter_linear_mipmap;
void fragment(){
	vec3 wp=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;
	vec3 n=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
	vec3 c=farbe.rgb;
	float mx=max(c.r,max(c.g,c.b));float mn=min(c.r,min(c.g,c.b));float sat=mx-mn;
	float lum=dot(c,vec3(0.3,0.59,0.11));
	float d=0.82;
	vec2 hor=normalize(vec2(-n.z,n.x)+vec2(0.0001));
	if(n.y>0.8){
		if(c.g>c.r*1.08&&c.g>c.b*1.08)d=texture(t_gras,wp.xz/3.5).r;
		else if(sat<0.09&&lum<0.42)d=texture(t_asphalt,wp.xz/7.0).r;
		else if(sat<0.2&&lum>=0.42)d=texture(t_platten,wp.xz/2.4).r;
		else d=texture(t_putz,wp.xz/3.0).r;
	}else if(n.y>0.22){
		vec2 uv=vec2(dot(wp.xz,hor),wp.y/max(length(n.xz),0.3));
		d=texture(t_schindel,uv/3.2).r;
	}else if(n.y>-0.5){
		vec2 uv=vec2(dot(wp.xz,hor),wp.y);
		if(c.r>c.g*1.22&&c.r>c.b*1.35&&lum<0.62)d=texture(t_backstein,uv/2.6).r;
		else if(sat<0.07)d=texture(t_putz,uv/3.0).r;
		else d=texture(t_holz,uv/2.2).r;
	}
	// in der Ferne weich zum Mittelwert (kein Flimmern)
	float dist=length(VERTEX);
	d=mix(d,0.82,smoothstep(45.0,140.0,dist));
	ALBEDO=c*d/0.82;
	ROUGHNESS=0.95;
}
"""

const TERR:="""shader_type spatial;
render_mode diffuse_toon,specular_disabled;
uniform sampler2D rausch:repeat_enable,filter_linear_mipmap;
uniform sampler2D t_gras:repeat_enable,filter_linear_mipmap;
uniform sampler2D t_putz:repeat_enable,filter_linear_mipmap;
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	float a=texture(rausch,wp.xz/9.0).r;float b=texture(rausch,wp.xz/53.0).r;
	vec3 c=COLOR.rgb*(0.86+0.18*a+0.12*(b-0.5));
	float gr=step(c.r*1.05,c.g);
	float d=mix(texture(t_putz,wp.xz/4.0).r,texture(t_gras,wp.xz/3.0).r,gr);
	d=mix(d,0.82,smoothstep(40.0,130.0,length(VERTEX)));
	ALBEDO=c*d/0.82;ROUGHNESS=1.0;
}
"""

static func _mat(m:StandardMaterial3D)->Material:
	if _cache.has(m):return _cache[m]
	if _shader==null:_shader=Shader.new();_shader.code=CODE
	var s=ShaderMaterial.new();s.shader=_shader
	s.set_shader_parameter("farbe",m.albedo_color)
	for t in TEX:s.set_shader_parameter("t_"+t,_tex(t))
	_cache[m]=s
	return s

static func _geeignet(m)->bool:
	if not (m is StandardMaterial3D):return false
	var s:StandardMaterial3D=m
	if s.albedo_texture!=null or s.vertex_color_use_as_albedo:return false
	if s.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:return false
	if s.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED:return false   # Tusche-Hüllen, Lichter
	if s.cull_mode==BaseMaterial3D.CULL_FRONT:return false
	if s.emission_enabled:return false
	var c=s.albedo_color
	if c.r+c.g+c.b<0.12:return false
	return true

static var _terr_shader:Shader
# Materialien aller Meshes unter "wurzel" umstellen (Fahrzeuge/Figuren ausgenommen)
static func anwenden(wurzel:Node):
	var meshes={}
	for g in wurzel.find_children("*","GeometryInstance3D",true,false):
		var p=g.get_parent();var aus=false
		while p!=null and p!=wurzel:
			if p is VehicleBody3D or p is CharacterBody3D:aus=true;break
			p=p.get_parent()
		if aus:continue
		if g is MeshInstance3D and g.mesh!=null:
			if g.material_override is ShaderMaterial and g.material_override.get_shader_parameter("rausch")!=null:
				_terrain(g)
			else:meshes[g.mesh]=true
		elif g is MultiMeshInstance3D and g.multimesh!=null and g.multimesh.mesh!=null:meshes[g.multimesh.mesh]=true
	var n=0
	for me in meshes:
		for i in me.get_surface_count():
			var m=me.surface_get_material(i)
			if _geeignet(m):
				_rueck.append([me,i,m]);me.surface_set_material(i,_mat(m));n+=1
	return n

static func _terrain(g:MeshInstance3D):
	if _terr_alt.has(g):return
	if _terr_shader==null:_terr_shader=Shader.new();_terr_shader.code=TERR
	var alt:ShaderMaterial=g.material_override
	var s=ShaderMaterial.new();s.shader=_terr_shader
	s.set_shader_parameter("rausch",alt.get_shader_parameter("rausch"))
	s.set_shader_parameter("t_gras",_tex("gras"));s.set_shader_parameter("t_putz",_tex("putz"))
	_terr_alt[g]=alt;g.material_override=s

static func zuruecksetzen():
	for e in _rueck:e[0].surface_set_material(e[1],e[2])
	_rueck.clear()
	for g in _terr_alt:
		if is_instance_valid(g):g.material_override=_terr_alt[g]
	_terr_alt.clear()

# ---------- Tusche-Konturen als Nachbearbeitung (Tiefen- und Farbkanten) ----------
const KONTUR:="""shader_type spatial;
render_mode unshaded,depth_draw_never,depth_test_disabled,cull_disabled,fog_disabled,shadows_disabled;
uniform sampler2D tiefe:hint_depth_texture,filter_nearest;
uniform sampler2D bild:hint_screen_texture,filter_linear_mipmap;
uniform float breite=1.2;
uniform float staerke=0.85;
void vertex(){POSITION=vec4(VERTEX.xy,1.0,1.0);}
float lin(vec2 uv,mat4 ip){
	float d=texture(tiefe,uv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc=vec3(uv,d)*2.0-1.0;
#else
	vec3 ndc=vec3(uv*2.0-1.0,d);
#endif
	vec4 v=ip*vec4(ndc,1.0);
	return -v.z/v.w;
}
void fragment(){
	vec2 px=breite/VIEWPORT_SIZE;
	vec2 uv=SCREEN_UV;
	float z=lin(uv,INV_PROJECTION_MATRIX);
	float zl=lin(uv-vec2(px.x,0.0),INV_PROJECTION_MATRIX);float zr=lin(uv+vec2(px.x,0.0),INV_PROJECTION_MATRIX);
	float zu=lin(uv-vec2(0.0,px.y),INV_PROJECTION_MATRIX);float zo=lin(uv+vec2(0.0,px.y),INV_PROJECTION_MATRIX);
	// Kante, wo die Tiefe springt (relativ, damit nahe und ferne Kanten gleich wirken); Krümmung statt
	// einfacher Differenz -> schräge Flächen (Straße, Hang) bekommen keine Linien
	float k=abs(zl+zr-2.0*z)+abs(zu+zo-2.0*z);
	float e=smoothstep(0.035,0.09,k/max(z,0.5));
	e*=1.0-smoothstep(260.0,600.0,z);
	vec3 c=texture(bild,uv).rgb;
	vec3 cl=texture(bild,uv-vec2(px.x,0.0)).rgb;vec3 cu=texture(bild,uv-vec2(0.0,px.y)).rgb;
	float fk=length(c-cl)+length(c-cu);
	e=max(e,smoothstep(0.22,0.5,fk)*0.55*(1.0-smoothstep(30.0,120.0,z)));
	ALBEDO=mix(c,vec3(0.07,0.06,0.08),e*staerke);
}
"""
static func kontur_knoten()->MeshInstance3D:
	var mi=MeshInstance3D.new();mi.name="StilKontur"
	var q=QuadMesh.new();q.size=Vector2(2,2);q.flip_faces=true;mi.mesh=q
	var s=Shader.new();s.code=KONTUR;var m=ShaderMaterial.new();m.shader=s
	mi.material_override=m;mi.extra_cull_margin=16384.0;mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

# ---------- Licht/Farben: wärmer, weicher, kräftiger Himmel ----------
static func licht(env:Environment,sonne:DirectionalLight3D):
	env.adjustment_enabled=true;env.adjustment_saturation=1.12;env.adjustment_contrast=1.06;env.adjustment_brightness=1.02
	env.ambient_light_energy=max(env.ambient_light_energy,0.6)
	if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
		var sm:ProceduralSkyMaterial=env.sky.sky_material
		sm.sky_top_color=Color(0.22,0.48,0.86);sm.sky_horizon_color=Color(0.72,0.84,0.95)
	env.fog_enabled=true;env.fog_light_color=Color(0.74,0.84,0.95);env.fog_density=max(env.fog_density,0.0009)
	if sonne:sonne.light_color=Color(1.0,0.93,0.8);sonne.light_energy=1.15
