extends SceneTree
# Comic-Musterblock: Kreuzung, eigene Häuser (Ziegel, Putz, Läden), Straßenmöbel, Autos (Trabant, Wartburg,
# Sportwagen), Figuren. Alles aus Code erzeugt, Toon-Licht + schwarze Konturen (Hülle mit Rückseiten).
const OUT:="/tmp/claude-0/-home-claude/28bc4cd7-234a-5fda-badb-fa2be879c9df/scratchpad/comic/"
const RW:=5.0      # halbe Fahrbahnbreite
const SW:=4.0      # Gehwegbreite
const KB:=0.15     # Bordsteinhöhe
const ENDE:=105.0
var rng:=RandomNumberGenerator.new()
var st:={}         # Material -> SurfaceTool
var mats:={}
var ink:StandardMaterial3D
var BOX:=BoxMesh.new()
var SPH:SphereMesh
var CYL:CylinderMesh
var CAP:CapsuleMesh
var welt:Node3D
var M:={}          # benannte Materialien

func _init():
	rng.seed=7
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	SPH=SphereMesh.new();SPH.radial_segments=16;SPH.rings=8
	CYL=CylinderMesh.new();CYL.radial_segments=14;CYL.rings=0
	CAP=CapsuleMesh.new();CAP.radial_segments=12;CAP.rings=4
	welt=Node3D.new();root.add_child(welt)
	_materialien()
	_umgebung()
	_strassen()
	_bebauung()
	_moebel()
	_hof()
	_strommasten()
	_autos()
	_leute()
	_fertig()
	await _bilder()
	quit()

# ---------------- Materialien ----------------
func _toon(c:Color,rough:=0.8)->StandardMaterial3D:
	var m=StandardMaterial3D.new();m.albedo_color=c;m.roughness=rough
	m.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON;m.specular_mode=BaseMaterial3D.SPECULAR_TOON
	return m
func _shader(code:String,params:={})->ShaderMaterial:
	var s=Shader.new();s.code=code
	var m=ShaderMaterial.new();m.shader=s
	for k in params:m.set_shader_parameter(k,params[k])
	return m

const KOPF:="""
shader_type spatial;
render_mode diffuse_toon, specular_toon;
varying vec3 wp; varying vec3 wn;
void vertex(){ wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; wn=normalize((MODEL_MATRIX*vec4(NORMAL,0.0)).xyz); }
float h21(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float vn(vec2 p){ vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(h21(i),h21(i+vec2(1,0)),f.x),mix(h21(i+vec2(0,1)),h21(i+vec2(1,1)),f.x),f.y); }
vec2 flaeche(){ vec3 n=abs(wn); if(n.y>0.7) return wp.xz; if(n.x>n.z) return vec2(wp.z,wp.y); return vec2(wp.x,wp.y); }
"""
const ZIEGEL:=KOPF+"""
uniform vec3 farbe:source_color=vec3(0.66,0.3,0.2);
uniform vec3 fuge:source_color=vec3(0.86,0.82,0.74);
uniform float bw=0.42; uniform float bh=0.15;
void fragment(){
	vec2 uv=flaeche();
	vec2 g=uv/vec2(bw,bh); float row=floor(g.y); g.x+=mod(row,2.0)*0.5;
	vec2 id=floor(g); vec2 f=fract(g);
	vec2 d=min(f,1.0-f)*vec2(bw,bh);
	float e=min(d.x,d.y);
	float mortar=1.0-smoothstep(0.014,0.024,e);
	float r=h21(id);
	vec3 c=farbe*(0.82+0.32*r);
	if(h21(id+3.7)>0.86) c*=vec3(0.78,0.74,0.72);
	if(h21(id+9.1)>0.93) c=mix(c,vec3(0.9,0.75,0.6),0.35);
	// gemalte Kante: oben hell, unten/rechts dunkel -> Ziegel wirken plastisch
	float oben=1.0-smoothstep(0.02,0.045,(1.0-f.y)*bh);
	float unten=1.0-smoothstep(0.02,0.04,f.y*bh);
	float rechts=1.0-smoothstep(0.02,0.04,(1.0-f.x)*bw);
	c*=1.0+0.22*oben-0.28*unten-0.12*rechts;
	vec3 fg=fuge*0.92;
	ALBEDO=mix(c,fg,mortar);
	ROUGHNESS=0.95;
}
"""
const PUTZ:=KOPF+"""
uniform vec3 farbe:source_color=vec3(0.9,0.8,0.6);
void fragment(){
	vec2 uv=flaeche();
	float n=vn(uv*2.0)*0.5+vn(uv*6.0)*0.5;
	vec3 c=farbe*(0.95+0.08*n);
	// leichte Verschmutzung unten
	c*=mix(0.88,1.0,smoothstep(0.0,2.5,wp.y));
	ALBEDO=c; ROUGHNESS=0.9;
}
"""
const PFLASTER:=KOPF+"""
uniform vec3 farbe:source_color=vec3(0.74,0.72,0.68);
uniform float gr=0.6;
void fragment(){
	vec2 g=wp.xz/gr; vec2 id=floor(g); vec2 f=fract(g);
	float e=min(min(f.x,1.0-f.x),min(f.y,1.0-f.y))*gr;
	float fuge=1.0-smoothstep(0.012,0.022,e);
	vec3 c=farbe*(0.9+0.16*h21(id));
	c*=1.0+0.12*(1.0-smoothstep(0.02,0.05,(1.0-f.y)*gr))-0.12*(1.0-smoothstep(0.02,0.05,f.y*gr));
	ALBEDO=mix(c,farbe*0.62,fuge); ROUGHNESS=0.9;
}
"""
const ASPHALT:=KOPF+"""
uniform vec3 farbe:source_color=vec3(0.3,0.31,0.33);
void fragment(){
	vec2 p=wp.xz;
	float k=vn(p*6.0); float g=vn(p*0.8);
	vec3 c=farbe*(0.94+0.1*k)*(0.96+0.06*g);
	// Flickstellen
	if(vn(p/4.0)>0.78) c*=0.9;
	ALBEDO=c; ROUGHNESS=0.95;
}
"""
const GLAS:=KOPF+"""
uniform vec3 farbe:source_color=vec3(0.16,0.3,0.42);
uniform float licht=0.0;
void fragment(){
	vec3 c=farbe;
	// gemalte Spiegelung: heller Schrägstreifen + Himmel oben
	float s=fract((wp.x+wp.z)*0.35+wp.y*0.5);
	float streif=smoothstep(0.0,0.05,s)*(1.0-smoothstep(0.12,0.17,s));
	c=mix(c,vec3(0.75,0.88,0.98),streif*0.55);
	c=mix(c,vec3(0.55,0.75,0.92),smoothstep(0.55,1.0,fract(wp.y/3.1))*0.35);
	ALBEDO=c; ROUGHNESS=0.15; SPECULAR=0.8;
	EMISSION=farbe*licht;
}
"""
const GRAS:=KOPF+"""
uniform vec3 farbe:source_color=vec3(0.32,0.52,0.24);
void fragment(){
	vec2 p=wp.xz;
	float k=vn(p*1.5)*0.6+vn(p*0.25)*0.4;
	ALBEDO=farbe*(0.85+0.25*k); ROUGHNESS=1.0;
}
"""

func _materialien():
	ink=StandardMaterial3D.new();ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color=Color(0.07,0.05,0.06);ink.cull_mode=BaseMaterial3D.CULL_FRONT
	M.ziegel=[_shader(ZIEGEL,{"farbe":Color(0.68,0.3,0.2)}),_shader(ZIEGEL,{"farbe":Color(0.55,0.24,0.18)}),
		_shader(ZIEGEL,{"farbe":Color(0.78,0.45,0.28)}),_shader(ZIEGEL,{"farbe":Color(0.62,0.52,0.45),"fuge":Color(0.9,0.88,0.82)}),
		_shader(ZIEGEL,{"farbe":Color(0.45,0.2,0.2)})]
	M.putz=[]
	for c in [Color(0.95,0.85,0.6),Color(0.62,0.8,0.82),Color(0.95,0.72,0.62),Color(0.82,0.88,0.7),Color(0.93,0.93,0.88),Color(0.78,0.7,0.88),Color(0.98,0.8,0.45)]:
		M.putz.append(_shader(PUTZ,{"farbe":c}))
	M.pflaster=_shader(PFLASTER,{})
	M.hof=_shader(PFLASTER,{"farbe":Color(0.6,0.58,0.55),"gr":0.35})
	M.asphalt=_shader(ASPHALT,{})
	M.glas=[_shader(GLAS,{}),_shader(GLAS,{"farbe":Color(0.12,0.24,0.32)}),_shader(GLAS,{"farbe":Color(0.95,0.78,0.42),"licht":0.25}),_shader(GLAS,{"farbe":Color(0.2,0.36,0.4)})]
	M.gras=_shader(GRAS,{})
	M.stein=_toon(Color(0.86,0.83,0.76))
	M.stein_d=_toon(Color(0.62,0.6,0.56))
	M.weiss=_toon(Color(0.96,0.95,0.92))
	M.dunkel=_toon(Color(0.17,0.17,0.19),0.5)
	M.metall=_toon(Color(0.25,0.27,0.3),0.4)
	M.dach=_toon(Color(0.3,0.29,0.3))
	M.holz=_toon(Color(0.55,0.36,0.2))
	M.erde=_toon(Color(0.4,0.28,0.18))
	M.laub=[_toon(Color(0.3,0.58,0.22)),_toon(Color(0.4,0.66,0.25)),_toon(Color(0.24,0.5,0.24))]
	M.rinde=_toon(Color(0.4,0.27,0.17))
	M.markierung=_toon(Color(0.97,0.97,0.94))
	M.gelb=_toon(Color(0.98,0.8,0.15))
	M.rot=_toon(Color(0.85,0.15,0.12))
	M.gruen_l=_toon(Color(0.2,0.95,0.4));M.gruen_l.emission_enabled=true;M.gruen_l.emission=Color(0.1,0.8,0.3)
	M.rot_l=_toon(Color(0.95,0.2,0.1));M.rot_l.emission_enabled=true;M.rot_l.emission=Color(0.8,0.1,0.05)
	M.lampe=_toon(Color(1,0.95,0.75));M.lampe.emission_enabled=true;M.lampe.emission=Color(0.6,0.55,0.35)
	M.chrom=_toon(Color(0.78,0.8,0.82),0.2);M.chrom.metallic=0.6
	M.reifen=_toon(Color(0.1,0.1,0.11))
	M.tuer=[_toon(Color(0.2,0.35,0.55)),_toon(Color(0.55,0.15,0.15)),_toon(Color(0.2,0.45,0.3)),_toon(Color(0.35,0.22,0.12)),_toon(Color(0.15,0.15,0.18))]
	M.markise=[[_toon(Color(0.85,0.18,0.15)),M.weiss],[_toon(Color(0.15,0.5,0.35)),M.weiss],[_toon(Color(0.2,0.35,0.7)),_toon(Color(0.95,0.85,0.4))],[_toon(Color(0.95,0.55,0.15)),M.weiss]]
	M.blume=[_toon(Color(0.95,0.3,0.4)),_toon(Color(0.98,0.85,0.2)),_toon(Color(0.8,0.4,0.9))]

# ---------------- Geometrie-Sammler ----------------
func _st(m:Material,eigen:=false)->SurfaceTool:
	# eigen: von Hand gebaute Flächen getrennt halten (SurfaceTool mischt append_from und add_vertex nicht sauber)
	var k=str(m.get_instance_id())+("h" if eigen else "")
	if not st.has(k):
		var s=SurfaceTool.new();s.begin(Mesh.PRIMITIVE_TRIANGLES);st[k]=s;mats[k]=m
	return st[k]
# Kasten: Mitte, Größe, Drehung; Kontur als etwas größerer Kasten mit Rückseiten
func box(m:Material,c:Vector3,s:Vector3,b:=Basis(),kontur:=0.035):
	if s.x<0.001 or s.y<0.001 or s.z<0.001:return
	_st(m).append_from(BOX,0,Transform3D(b*Basis().scaled(s),c))
	if kontur>0.0 and (int(s.x>0.25)+int(s.y>0.25)+int(s.z>0.25))>=2:
		_st(ink).append_from(BOX,0,Transform3D(b*Basis().scaled(s+Vector3.ONE*kontur*2.0),c))
func mesh(m:Material,me:Mesh,xf:Transform3D,kontur:=1.06):
	_st(m).append_from(me,0,xf)
	if kontur>1.0:_st(ink).append_from(me,0,Transform3D(xf.basis*Basis().scaled(Vector3.ONE*kontur),xf.origin))
func kugel(m:Material,c:Vector3,r:Vector3,kontur:=1.07):
	var xf=Transform3D(Basis().scaled(r*2.0),c)
	mesh(m,SPH,xf,kontur)
func zyl(m:Material,a:Vector3,b:Vector3,r:float,kontur:=1.0):
	var d=b-a;var L=d.length();if L<0.001:return
	var q=Quaternion(Vector3.UP,d/L) if abs((d/L).dot(Vector3.UP))<0.9999 else (Quaternion() if d.y>0 else Quaternion(Vector3.RIGHT,PI))
	var xf=Transform3D(Basis(q)*Basis().scaled(Vector3(r*2.0,L*0.5,r*2.0)),(a+b)*0.5)
	_st(m).append_from(CYL,0,xf)
	if kontur>1.0:_st(ink).append_from(CYL,0,Transform3D(Basis(q)*Basis().scaled(Vector3(r*2.0*kontur+0.05,L*0.5+0.025,r*2.0*kontur+0.05)),(a+b)*0.5))
func kapsel(m:Material,a:Vector3,b:Vector3,r:float,kontur:=true):
	var d=b-a;var L=d.length()
	var q=Quaternion(Vector3.UP,d/L) if abs((d/L).dot(Vector3.UP))<0.9999 else Quaternion()
	var me=CapsuleMesh.new();me.radius=r;me.height=L+2.0*r;me.radial_segments=12;me.rings=4
	_st(m).append_from(me,0,Transform3D(Basis(q),(a+b)*0.5))
	if kontur:
		var mi=CapsuleMesh.new();mi.radius=r+0.018;mi.height=L+2.0*r+0.036;mi.radial_segments=12;mi.rings=4
		_st(ink).append_from(mi,0,Transform3D(Basis(q),(a+b)*0.5))
# Körper aus 8 Eckpunkten (unten 4, oben 4, gleiche Reihenfolge) – für Autos, Torso
func hex(m:Material,p:Array,kontur:=0.03):
	_hex_in(_st(m,true),p)
	if kontur>0.0:
		var c=Vector3.ZERO
		for v in p:c+=v
		c/=8.0
		var q=[]
		for v in p:q.append(v+(v-c).normalized()*kontur*1.4)
		_hex_in(_st(ink,true),q,true)
func _hex_in(s:SurfaceTool,p:Array,innen:=false):
	var c=Vector3.ZERO
	for v in p:c+=v
	c/=8.0
	var faces=[[0,1,2,3],[7,6,5,4],[0,4,5,1],[1,5,6,2],[2,6,7,3],[3,7,4,0]]
	for f in faces:
		var a=p[f[0]];var b=p[f[1]];var cc=p[f[2]];var d=p[f[3]]
		var n=(b-a).cross(d-a)
		if n.length()<1e-6:n=(cc-b).cross(a-b)
		n=n.normalized()
		var fm=(a+b+cc+d)*0.25
		var aussen=n.dot(fm-c)>0
		if not aussen:
			var t=b;b=d;d=t;n=-n
		# Godot: Vorderseite = im Uhrzeigersinn (von außen gesehen)
		for v in [a,cc,b,a,d,cc]:s.set_normal(n);s.add_vertex(v)
func _fertig():
	for k in st:
		var s:SurfaceTool=st[k]
		var mi=MeshInstance3D.new();mi.mesh=s.commit();mi.material_override=mats[k];welt.add_child(mi)
		if mats[k]==ink:mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# ---------------- Umgebung ----------------
func _umgebung():
	var we=WorldEnvironment.new();var e=Environment.new();we.environment=e;welt.add_child(we)
	var sky=Sky.new();var sm=ProceduralSkyMaterial.new()
	sm.sky_top_color=Color(0.22,0.5,0.92);sm.sky_horizon_color=Color(0.72,0.86,0.98);sm.ground_horizon_color=Color(0.72,0.86,0.98);sm.ground_bottom_color=Color(0.4,0.45,0.4)
	sm.sun_angle_max=8.0;sky.sky_material=sm;e.sky=sky;e.background_mode=Environment.BG_SKY
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color(0.72,0.78,0.9);e.ambient_light_energy=0.55
	e.tonemap_mode=Environment.TONE_MAPPER_LINEAR;e.tonemap_exposure=1.0
	e.fog_enabled=true;e.fog_light_color=Color(0.75,0.85,0.97);e.fog_density=0.0015;e.fog_aerial_perspective=0.5
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,-35,0);sun.light_color=Color(1.0,0.95,0.86);sun.light_energy=1.15
	RenderingServer.directional_shadow_atlas_set_size(8192,true)
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_enabled=true;sun.directional_shadow_max_distance=90.0;sun.shadow_bias=0.04;sun.shadow_normal_bias=1.0;sun.shadow_blur=0.5
	welt.add_child(sun)
	# Wolken: dicke Comic-Wolken aus Kugeln
	for i in 9:
		var c=Vector3(rng.randf_range(-200,200),rng.randf_range(55,80),rng.randf_range(-200,200))
		for k in 5:
			kugel(M.weiss,c+Vector3(k*6.0-12.0,rng.randf_range(-1,2),rng.randf_range(-3,3)),Vector3(7,4.5,6)*rng.randf_range(0.8,1.3),1.0)

# ---------------- Straßen ----------------
func _strassen():
	box(M.gras,Vector3(0,-0.06,0),Vector3(600,0.1,600),Basis(),0.0)
	# Fahrbahn: Kreuz aus zwei Bändern (massiv, kein Hohlraum)
	box(M.asphalt,Vector3(0,-0.05,0),Vector3(ENDE*2,0.1,RW*2),Basis(),0.0)
	box(M.asphalt,Vector3(0,-0.05,0),Vector3(RW*2,0.1,ENDE*2),Basis(),0.0)
	# Gehwege je Viertel: massive Blöcke bis Bordsteinhöhe, Bordstein als eigener Stein
	for sx in [-1,1]:
		for sz in [-1,1]:
			var x0=RW;var x1=ENDE;var z0=RW;var z1=RW+SW
			box(M.pflaster,Vector3(sx*(x0+x1)*0.5,KB*0.5-0.05,sz*(z0+z1)*0.5),Vector3(x1-x0,KB+0.1,z1-z0),Basis(),0.0)
			box(M.pflaster,Vector3(sx*(z0+z1)*0.5,KB*0.5-0.05,sz*(x0+x1+SW)*0.5),Vector3(z1-z0,KB+0.1,x1-x0-SW),Basis(),0.0)
			# Bordsteine
			box(M.stein,Vector3(sx*(RW+x1)*0.5,KB*0.5-0.04,sz*(RW+0.15)),Vector3(x1-RW,KB+0.1,0.3),Basis(),0.02)
			box(M.stein,Vector3(sx*(RW+0.15),KB*0.5-0.04,sz*(RW+x1)*0.5),Vector3(0.3,KB+0.1,x1-RW),Basis(),0.02)
			# Hinterhof-Fläche hinter den Häusern (im Hofblock Asphalt statt Rasen, kommt aus _hof)
			if not (sx==1 and sz==1):box(M.gras,Vector3(sx*(RW+SW+ENDE)*0.5,0.05,sz*(RW+SW+ENDE)*0.5),Vector3(ENDE-RW-SW,0.1,ENDE-RW-SW),Basis(),0.0)
	# Markierungen: Mittellinie gestrichelt, Zebrastreifen, Haltelinien
	for arm in [Vector2(1,0),Vector2(-1,0),Vector2(0,1),Vector2(0,-1)]:
		var a=Vector3(arm.x,0,arm.y);var quer=Vector3(-arm.y,0,arm.x)
		var b=Basis(Vector3.UP,atan2(a.x,a.z))
		var s=RW+SW+5.5
		while s<ENDE:
			box(M.markierung,a*(s+1.5)+Vector3(0,0.006,0),Vector3(0.15,0.012,3.0),b,0.0);s+=6.0
		for k in range(-4,5):
			box(M.markierung,a*(RW+2.6)+quer*(k*1.05)+Vector3(0,0.006,0),Vector3(0.55,0.012,3.2),b,0.0)
		box(M.markierung,a*(RW+4.7)+quer*(RW*0.5)+Vector3(0,0.006,0),Vector3(RW,0.012,0.4),b,0.0)
		for sd in [-1,1]:box(M.markierung,a*((RW+ENDE)*0.5)+quer*(sd*(RW-0.35))+Vector3(0,0.006,0),Vector3(0.14,0.012,ENDE-RW),b,0.0)
	# Gullydeckel
	for p in [Vector3(RW-0.6,0.01,12),Vector3(-RW+0.6,0.01,-18),Vector3(20,0.01,RW-0.6),Vector3(-26,0.01,-RW+0.6)]:
		zyl(M.dunkel,p,p+Vector3(0,0.02,0),0.32)

# ---------------- Häuser ----------------
var _laeden:=["BÄCKEREI","KIOSK","DÖNER","FRISEUR","APOTHEKE","BLUMEN","PFANDLEIHE","WASCHSALON","BUCHLADEN","IMBISS","ELEKTRO","CAFÉ"]
const HOF0:=21.0
const HOF1:=62.0
func _bebauung():
	var C=15.0;var T=12.0;var vorn=RW+SW
	for sx in [-1,1]:
		for sz in [-1,1]:
			var o1=Vector3(0,0,-sz);var o2=Vector3(-sx,0,0)
			var mitte=Vector3(sx*(vorn+C*0.5),KB,sz*(vorn+C*0.5))
			var hofblock=(sx==1 and sz==1)
			var grove=(sx==-1 and sz==1)
			_haus(mitte+o1*(C*0.5),C,C,o1,{"eck":o2,"stock":(3 if grove else rng.randi_range(4,5)),"laden":true,"hof":hofblock})
			for reihe in [[Vector3(sx,0,0),o1,0],[Vector3(0,0,sz),o2,1]]:
				var lauf:Vector3=reihe[0];var o:Vector3=reihe[1]
				var s=vorn+C
				var ende=HOF1 if hofblock else ENDE
				if grove and reihe[2]==1:
					_holzreihe(lauf,o,s,ende);continue
				while s<ende-6.0:
					var w=[7.5,8.5,9.5,11.0,12.5][rng.randi()%5]
					if s+w>ende:w=ende-s
					if w<6.0:break
					# Durchfahrt in den Hof
					if hofblock and reihe[2]==0 and s<38.0 and s+w>38.0:
						w=38.0-s
						var g0=38.0
						if w>=6.0:_haus(lauf*(s+w*0.5)-o*vorn+Vector3(0,KB,0),w,T,o,{"stock":rng.randi_range(3,5),"laden":rng.randf()<0.5,"hof":true})
						else:g0=s
						_durchfahrt(lauf*((g0+42.0)*0.5)-o*vorn,o,42.0-g0,T)
						s=42.0;continue
					var p=lauf*(s+w*0.5)-o*vorn+Vector3(0,KB,0)
					_haus(p,w,T,o,{"stock":(rng.randi_range(2,3) if grove else rng.randi_range(2,5)),"laden":rng.randf()<0.45,"hof":hofblock})
					s+=w
	# Hinterreihen schließen den Hofblock (Fronten nach außen, Rückseiten zum Hof)
	var s2=HOF0
	while s2<HOF1+12.0-0.1:
		var w=min([8.5,10.0,11.5][rng.randi()%3],HOF1+12.0-s2)
		_haus(Vector3(s2+w*0.5,KB,HOF1+12.0),w,12.0,Vector3(0,0,1),{"stock":rng.randi_range(3,5),"hof":true})
		s2+=w
	s2=HOF0
	while s2<HOF1-0.1:
		var w=min([8.5,10.0,11.5][rng.randi()%3],HOF1-s2)
		_haus(Vector3(HOF1+12.0,KB,s2+w*0.5),w,12.0,Vector3(1,0,0),{"stock":rng.randi_range(3,5),"hof":true})
		s2+=w

func _haus(front:Vector3,w:float,d:float,aussen:Vector3,opt:Dictionary):
	var oben=Vector3.UP;var rechts=oben.cross(aussen)
	var stock:int=opt.stock;var eg=3.7;var oh=3.15
	var H=eg+(stock-1)*oh
	var ziegel=rng.randf()<0.55
	var wand:Material=M.ziegel[rng.randi()%M.ziegel.size()] if ziegel else M.putz[rng.randi()%M.putz.size()]
	var b=Basis(rechts,oben,aussen)
	var mitte=front-aussen*(d*0.5)+Vector3(0,H*0.5,0)
	box(wand,mitte,Vector3(w,H,d),b,0.04)
	# Dach: Teerdach, Attika
	box(M.dach,mitte+Vector3(0,H*0.5+0.02,0),Vector3(w-0.5,0.06,d-0.5),b,0.0)
	var stil={"ziegel":ziegel,"wand":wand,"glas":M.glas[rng.randi()%M.glas.size()],"tuer":M.tuer[rng.randi()%M.tuer.size()],
		"trim":(M.stein if rng.randf()<0.7 else M.weiss),"laeden":(not ziegel and rng.randf()<0.4),"feuer":(ziegel and rng.randf()<0.45),
		"balkon":(not ziegel and rng.randf()<0.5),"fenster":rng.randi_range(0,2)}
	_fassade(front-rechts*(w*0.5),rechts,aussen,w,H,stock,eg,oh,stil,opt.get("laden",false),true)
	if opt.has("eck"):
		var o2:Vector3=opt.eck;var r2=oben.cross(o2)
		var f2=mitte-Vector3(0,H*0.5,0)+o2*(w*0.5)
		_fassade(f2-r2*(d*0.5),r2,o2,d,H,stock,eg,oh,stil,true,false)
		# Ladeneingang schräg an der Ecke: Laterne + Schild darüber
	# Rückseite: einfache Fenster
	var hinten=-aussen;var rh=oben.cross(hinten)
	var fh=mitte-Vector3(0,H*0.5,0)+hinten*(d*0.5)
	for i in range(1,stock):
		var y=eg+(i-1)*oh+0.9
		var n=int((w-1.0)/2.6)
		for k in n:
			var x=(k+0.5)*w/n-w*0.5
			box(M.glas[0],fh+rh*x+Vector3(0,y+0.75,0)+hinten*0.02,Vector3(1.0,1.4,0.04),Basis(rh,oben,hinten),0.0)
			box(stil.trim,fh+rh*x+Vector3(0,y-0.05,0)+hinten*0.08,Vector3(1.2,0.1,0.16),Basis(rh,oben,hinten),0.0)
	if opt.get("hof",false):_rueckseite(fh,rh,hinten,w,stock,eg,oh,stil)
	# Dachaufbauten
	var dachy=H+KB
	if stil.ziegel and rng.randf()<0.5:_wassertank(mitte+Vector3(0,H*0.5,0)-aussen*1.5+rechts*rng.randf_range(-w*0.2,w*0.2))
	for k in rng.randi_range(0,2):
		var p=mitte+Vector3(0,H*0.5,0)+rechts*rng.randf_range(-w*0.35,w*0.35)-aussen*rng.randf_range(0,d*0.35)
		if rng.randf()<0.5:box(wand,p+Vector3(0,0.8,0),Vector3(0.7,1.6,0.7),b,0.035);box(M.stein_d,p+Vector3(0,1.65,0),Vector3(0.85,0.12,0.85),b,0.03)
		else:box(M.metall,p+Vector3(0,0.4,0),Vector3(1.0,0.8,0.8),b,0.035)

func _wassertank(p:Vector3):
	for l in [Vector3(0.7,0,0.7),Vector3(-0.7,0,0.7),Vector3(0.7,0,-0.7),Vector3(-0.7,0,-0.7)]:
		zyl(M.metall,p+l,p+l+Vector3(0,1.8,0),0.07)
	zyl(M.holz,p+Vector3(0,1.8,0),p+Vector3(0,3.8,0),1.05,1.05)
	for y in [2.2,3.0,3.6]:zyl(M.metall,p+Vector3(0,y,0),p+Vector3(0,y+0.06,0),1.08)
	var dach=ConeHelper.kegel(1.15,0.7)
	mesh(M.dach,dach,Transform3D(Basis(),p+Vector3(0,3.8,0)),1.05)

class ConeHelper:
	static func kegel(r:float,h:float)->CylinderMesh:
		var c=CylinderMesh.new();c.top_radius=0.0;c.bottom_radius=r;c.height=h;c.radial_segments=14;c.rings=0
		# Mittelpunkt des CylinderMesh liegt in der Mitte -> nach oben verschieben macht der Aufrufer nicht; ok für Optik
		return c

# Fassade: o = linke untere Ecke auf der Wandfläche, r = nach rechts, a = nach außen
func _fassade(o:Vector3,r:Vector3,a:Vector3,w:float,H:float,stock:int,eg:float,oh:float,stil:Dictionary,laden:bool,vorne:bool):
	var b=Basis(r,Vector3.UP,a)
	var P=func(x:float,y:float,z:float)->Vector3:return o+r*x+Vector3.UP*y+a*z
	var trim:Material=stil.trim
	# Sockel
	box(M.stein_d,P.call(w*0.5,0.35,0.05),Vector3(w,0.7,0.12),b,0.03)
	# Ecksteine (Putzbauten): echte 3D-Quader, abwechselnd lang/kurz
	if not stil.ziegel:
		for x0 in [0.0,w]:
			var y=0.7;var k=0
			while y<H-0.4:
				var lw=0.55 if k%2==0 else 0.35
				var xx=x0+(lw*0.5 if x0==0.0 else -lw*0.5)
				box(trim,P.call(xx,y+0.15,0.04),Vector3(lw,0.28,0.1),b,0.025);y+=0.32;k+=1
	# Gesimsbänder je Stockwerk
	for i in range(1,stock):
		var y=eg+(i-1)*oh
		box(trim,P.call(w*0.5,y-0.08,0.07),Vector3(w,0.16,0.16),b,0.03)
	# Hauptgesims mit Konsolen + Attika
	box(trim,P.call(w*0.5,H-0.2,0.22),Vector3(w+0.3,0.4,0.5),b,0.04)
	var kx=0.4
	while kx<w-0.2:
		box(trim,P.call(kx,H-0.55,0.12),Vector3(0.18,0.3,0.26),b,0.02);kx+=0.9
	box(stil.wand,P.call(w*0.5,H+0.35,-0.15),Vector3(w,0.7,0.3),b,0.035)
	box(M.stein_d,P.call(w*0.5,H+0.74,-0.15),Vector3(w+0.1,0.1,0.42),b,0.03)
	# Obergeschosse: Fenster
	var n=max(1,int((w-0.8)/2.35))
	var fw=1.1;var fhoch=1.65
	for i in range(1,stock):
		var y0=eg+(i-1)*oh+0.85
		for k in n:
			var x=(k+0.5)*w/n
			_fenster(P,b,x,y0,fw,fhoch,stil,i)
			if stil.balkon and i>=2 and k%2==0 and rng.randf()<0.6:_balkon(P,b,x,y0,stil)
	# Feuertreppe (Ziegelbauten, vorne)
	if stil.feuer and vorne and stock>=3:_feuertreppe(P,b,w,eg,oh,stock)
	# Erdgeschoss
	if laden:_laden(P,b,w,eg,stil)
	else:_eingang(P,b,w,eg,stil)

func _fenster(P:Callable,b:Basis,x:float,y0:float,fw:float,fh:float,stil:Dictionary,i:int):
	var glas:Material=M.glas[rng.randi()%M.glas.size()] if rng.randf()<0.35 else stil.glas
	var t=0.09
	# Laibung (dunkler Rücksprung) + Glas leicht zurück
	box(M.dunkel,P.call(x,y0+fh*0.5,0.005),Vector3(fw+0.08,fh+0.08,0.03),b,0.0)
	box(glas,P.call(x,y0+fh*0.5,0.02),Vector3(fw-0.05,fh-0.05,0.03),b,0.0)
	var rahmen:Material=M.weiss if stil.fenster!=1 else stil.tuer
	box(rahmen,P.call(x-fw*0.5,y0+fh*0.5,0.07),Vector3(t,fh+t,0.12),b,0.02)
	box(rahmen,P.call(x+fw*0.5,y0+fh*0.5,0.07),Vector3(t,fh+t,0.12),b,0.02)
	box(rahmen,P.call(x,y0+fh,0.07),Vector3(fw+t,t,0.12),b,0.02)
	box(rahmen,P.call(x,y0,0.07),Vector3(fw+t,t,0.12),b,0.02)
	box(rahmen,P.call(x,y0+fh*0.5,0.06),Vector3(0.06,fh,0.06),b,0.0)
	box(rahmen,P.call(x,y0+fh*0.62,0.06),Vector3(fw,0.06,0.06),b,0.0)
	# Vorhang innen (halb zugezogen)
	if rng.randf()<0.4:
		var vc=[M.weiss,M.blume[0],M.gelb][rng.randi()%3]
		box(vc,P.call(x-fw*0.25,y0+fh*0.55,0.03),Vector3(fw*0.42,fh*0.8,0.01),b,0.0)
	# Fensterbank
	box(M.stein,P.call(x,y0-0.07,0.13),Vector3(fw+0.35,0.12,0.26),b,0.025)
	# Sturz: Ziegel = Rollschicht aus einzelnen 3D-Ziegeln, Putz = Verdachung
	if stil.ziegel:
		var nz=9;var bz=(fw+0.4)/nz
		for k in nz:
			var xx=x-(fw+0.4)*0.5+(k+0.5)*bz
			box(M.ziegel[(k+i)%2] if k%3!=1 else M.stein,P.call(xx,y0+fh+0.2,0.035),Vector3(bz-0.025,0.32,0.08),b,0.0)
		box(M.dunkel,P.call(x,y0+fh+0.03,0.03),Vector3(fw+0.4,0.025,0.05),b,0.0)
	else:
		box(stil.trim,P.call(x,y0+fh+0.18,0.1),Vector3(fw+0.45,0.14,0.22),b,0.025)
		if i%2==1:
			box(stil.trim,P.call(x,y0+fh+0.32,0.1),Vector3(fw*0.7,0.12,0.18),b,0.02)
		if stil.laeden:
			var lc:Material=stil.tuer
			for sd in [-1,1]:
				box(lc,P.call(x+sd*(fw*0.5+0.32),y0+fh*0.5,0.06),Vector3(0.52,fh+0.05,0.06),b,0.02)
				for q in 6:box(M.dunkel,P.call(x+sd*(fw*0.5+0.32),y0+0.15+q*0.27,0.095),Vector3(0.44,0.02,0.01),b,0.0)
	# Klimagerät / Blumenkasten
	var z=rng.randf()
	if z<0.12:
		box(M.weiss,P.call(x+0.2,y0-0.45,0.3),Vector3(0.7,0.45,0.5),b,0.03)
		for q in 4:box(M.stein_d,P.call(x+0.2,y0-0.6+q*0.1,0.56),Vector3(0.6,0.03,0.01),b,0.0)
	elif z<0.3:
		box(M.holz,P.call(x,y0+0.05,0.32),Vector3(fw,0.22,0.24),b,0.025)
		for q in 6:kugel(M.blume[rng.randi()%3] if q%2==0 else M.laub[0],P.call(x-fw*0.4+q*fw*0.16,y0+0.22,0.32),Vector3(0.11,0.1,0.11),1.0)

func _balkon(P:Callable,b:Basis,x:float,y0:float,stil:Dictionary):
	box(M.stein,P.call(x,y0-0.05,0.55),Vector3(1.9,0.15,1.1),b,0.03)
	box(M.metall,P.call(x,y0+0.85,1.08),Vector3(1.9,0.06,0.06),b,0.0)
	for sd in [-1,1]:box(M.metall,P.call(x+sd*0.93,y0+0.85,0.55),Vector3(0.06,0.06,1.1),b,0.0)
	var q=-0.9
	while q<=0.91:
		box(M.metall,P.call(x+q,y0+0.45,1.08),Vector3(0.035,0.8,0.035),b,0.0);q+=0.15
	if rng.randf()<0.5:
		for k in 3:kugel(M.laub[k%3],P.call(x-0.6+k*0.6,y0+0.3,0.9),Vector3(0.22,0.25,0.22),1.05)

func _feuertreppe(P:Callable,b:Basis,w:float,eg:float,oh:float,stock:int):
	var x0=w*0.25;var bw=w*0.45
	for i in range(1,stock):
		var y=eg+(i-1)*oh+0.75
		box(M.metall,P.call(x0+bw*0.5,y,0.65),Vector3(bw,0.07,1.25),b,0.02)
		box(M.metall,P.call(x0+bw*0.5,y+0.95,1.28),Vector3(bw,0.05,0.05),b,0.0)
		box(M.metall,P.call(x0+bw*0.5,y+0.5,1.28),Vector3(bw,0.04,0.04),b,0.0)
		var q=0.0
		while q<=bw:
			box(M.metall,P.call(x0+q,y+0.48,1.28),Vector3(0.035,0.95,0.035),b,0.0);q+=0.25
		for sd in [0.0,bw]:box(M.metall,P.call(x0+sd,y+0.95,0.65),Vector3(0.05,0.05,1.25),b,0.0)
		# schräge Leiter zum nächsten Podest
		if i<stock-1:
			var lb=Basis(b.x,b.y,b.z)*Basis(Vector3.FORWARD,0.0)
			var a=P.call(x0+0.4,y+0.05,0.75);var e=P.call(x0+bw-0.4,y+oh,0.75)
			var d=e-a
			var lr=Basis(d.normalized(),b.z.cross(d.normalized()).normalized()*-1.0,b.z)
			box(M.metall,(a+e)*0.5,Vector3(d.length(),0.05,0.6),Basis(d.normalized(),b.z.cross(d.normalized()).normalized(),b.z) if false else _rich(d,b.z),0.0)
	# Hängeleiter unten
	box(M.metall,P.call(x0+bw-0.3,eg-0.4,1.2),Vector3(0.5,1.6,0.05),b,0.0)

func _rich(d:Vector3,z:Vector3)->Basis:
	var x=d.normalized();var y=z.cross(x).normalized();var zz=x.cross(y).normalized()
	return Basis(x,y,zz)

func _laden(P:Callable,b:Basis,w:float,eg:float,stil:Dictionary):
	var mk=M.markise[rng.randi()%M.markise.size()]
	var schild:Material=mk[0]
	# Pfeiler + große Schaufenster
	var n=max(1,int(w/3.2))
	box(M.dunkel,P.call(w*0.5,1.65,0.0),Vector3(w-0.4,2.5,0.04),b,0.0)
	for k in n+1:
		var x=0.2+k*(w-0.4)/n
		box(stil.trim if not stil.ziegel else M.stein,P.call(x,1.6,0.1),Vector3(0.35,2.6,0.22),b,0.03)
	for k in n:
		var x=0.2+(k+0.5)*(w-0.4)/n;var bw=(w-0.4)/n-0.4
		if k==n/2 and w>6.0:
			box(stil.tuer,P.call(x,1.25,0.03),Vector3(1.2,2.3,0.06),b,0.02)
			box(M.glas[2],P.call(x,1.6,0.07),Vector3(0.8,1.2,0.03),b,0.0)
			box(M.chrom,P.call(x+0.4,1.2,0.12),Vector3(0.05,0.4,0.05),b,0.0)
			box(M.stein,P.call(x,0.07,0.35),Vector3(1.5,0.14,0.7),b,0.02)
		else:
			box(M.glas[2] if rng.randf()<0.5 else M.glas[0],P.call(x,1.65,0.04),Vector3(bw,2.0,0.04),b,0.0)
			box(M.weiss,P.call(x,0.62,0.12),Vector3(bw+0.1,0.08,0.22),b,0.02)
			# Auslage: bunte Kisten/Regale hinter dem Glas
			for q in 4:box([M.blume[0],M.gelb,M.blume[2],M.laub[1]][q],P.call(x-bw*0.35+q*bw*0.23,0.85,-0.15),Vector3(bw*0.18,0.35,0.2),b,0.0)
	# Schildband mit Schrift
	box(schild,P.call(w*0.5,3.15,0.18),Vector3(w-0.2,0.7,0.12),b,0.035)
	box(M.weiss,P.call(w*0.5,3.15,0.25),Vector3(w-0.5,0.5,0.02),b,0.0)
	var lb=Label3D.new();lb.text=_laeden[rng.randi()%_laeden.size()];lb.font_size=96;lb.pixel_size=0.0045
	lb.modulate=Color(0.12,0.1,0.12);lb.outline_size=0;lb.shaded=false;lb.double_sided=false
	lb.transform=Transform3D(b,P.call(w*0.5,3.15,0.27));welt.add_child(lb)
	# Markise: gestreift, schräg (an den Hausenden etwas eingerückt, damit sich Markisen an der Ecke nicht schneiden)
	var tief=1.6;var y0=2.85;var m0=0.6;var mw=w-1.2
	var streifen=int(mw/0.55)
	var tb=b*Basis(Vector3.RIGHT,deg_to_rad(28))
	for k in streifen:
		var x=m0+(k+0.5)*mw/streifen
		box(mk[k%2],P.call(x,y0-tief*0.25,tief*0.5+0.1),Vector3(mw/streifen+0.003,0.05,tief),tb,0.0)
		box(mk[k%2],P.call(x,y0-tief*0.48-0.18,tief*0.93+0.1),Vector3(mw/streifen,0.3,0.04),b,0.0)
	_st(ink).append_from(BOX,0,Transform3D(tb*Basis().scaled(Vector3(mw+0.07,0.12,tief+0.07)),P.call(w*0.5,y0-tief*0.25,tief*0.5+0.1)))
	for sd in [0.0,1.0]:box(mk[0],P.call(m0+sd*mw,y0-tief*0.3,tief*0.5+0.1),Vector3(0.04,0.6,tief),b,0.0)

func _eingang(P:Callable,b:Basis,w:float,eg:float,stil:Dictionary):
	var x=w*0.5 if w<9.0 else w*0.3
	# Haustür mit Oberlicht, Rahmen, Stufen, Lampe, Klingelschild
	box(M.dunkel,P.call(x,1.55,0.0),Vector3(1.5,3.0,0.04),b,0.0)
	box(stil.tuer,P.call(x,1.3,0.04),Vector3(1.25,2.4,0.06),b,0.02)
	for q in 2:box(stil.tuer,P.call(x,0.75+q*1.05,0.08),Vector3(0.95,0.85,0.03),b,0.0)
	box(M.glas[2],P.call(x,2.8,0.04),Vector3(1.25,0.5,0.03),b,0.0)
	box(stil.trim,P.call(x,1.55,0.1),Vector3(1.75,3.2,0.08),b,0.03) if false else null
	for sd in [-1,1]:box(stil.trim,P.call(x+sd*0.75,1.55,0.1),Vector3(0.18,3.1,0.16),b,0.025)
	box(stil.trim,P.call(x,3.15,0.15),Vector3(1.9,0.22,0.3),b,0.03)
	box(M.chrom,P.call(x+0.45,1.2,0.12),Vector3(0.05,0.3,0.05),b,0.0)
	box(M.stein,P.call(x,0.08,0.45),Vector3(1.8,0.16,0.9),b,0.025)
	box(M.stein,P.call(x,0.24,0.25),Vector3(1.6,0.16,0.5),b,0.025)
	box(M.metall,P.call(x+1.0,2.2,0.12),Vector3(0.12,0.3,0.12),b,0.02)
	kugel(M.lampe,P.call(x+1.0,2.45,0.2),Vector3(0.12,0.14,0.12),1.08)
	box(M.chrom,P.call(x-1.0,1.3,0.06),Vector3(0.22,0.45,0.04),b,0.0)
	# EG-Fenster neben der Tür (mit Gitter)
	var xs=[]
	if w<9.0:xs=[w*0.15,w*0.85]
	else:xs=[w*0.62,w*0.85]
	for xx in xs:
		if abs(xx-x)<1.4:continue
		_fenster(P,b,xx,1.0,1.0,1.55,stil,0)
		var q=-0.4
		while q<=0.41:box(M.metall,P.call(xx+q,1.78,0.2),Vector3(0.035,1.6,0.035),b,0.0);q+=0.2

# ---------------- Straßenmöbel ----------------
func _moebel():
	var vorn=RW+SW
	# Ampeln an den vier Ecken
	for sx in [-1,1]:
		for sz in [-1,1]:
			_ampel(Vector3(sx*(RW+0.7),KB,sz*(RW+0.7)),Vector3(0,0,-sz) if sx*sz>0 else Vector3(-sx,0,0),(sx*sz>0))
	# Laternen, Bäume, Bänke, Mülleimer, Hydranten entlang der Gehwege
	for arm in [Vector3(1,0,0),Vector3(-1,0,0),Vector3(0,0,1),Vector3(0,0,-1)]:
		var quer=Vector3(-arm.z,0,arm.x)
		for sd in [-1,1]:
			var kante=quer*sd*(RW+0.7)
			var s=vorn+4.0;var k=0
			while s<ENDE-4.0:
				var p=arm*s+kante+Vector3(0,KB,0)
				if k%2==0:_laterne(p,-quer*sd)
				else:_baum(p+quer*sd*0.6)
				if k%3==1:_bank(arm*(s+3.0)+quer*sd*(RW+SW-0.8)+Vector3(0,KB,0),-quer*sd)
				if k%4==2:_muell(arm*(s-2.5)+quer*sd*(RW+1.0)+Vector3(0,KB,0))
				if k%5==3:_hydrant(arm*(s+2.0)+quer*sd*(RW+0.6)+Vector3(0,KB,0))
				s+=9.0;k+=1
	# Briefkasten + Litfaßsäule an der Ecke
	_litfass(Vector3(RW+2.4,KB,-(RW+2.6)))
	box(M.gelb,Vector3(-(RW+1.0),KB+0.55,RW+2.2),Vector3(0.5,0.8,0.4),Basis(),0.03)
	box(M.dunkel,Vector3(-(RW+1.0),KB+0.75,RW+2.42),Vector3(0.3,0.04,0.02),Basis(),0.0)
	zyl(M.dunkel,Vector3(-(RW+1.0),KB,RW+2.2),Vector3(-(RW+1.0),KB+0.15,RW+2.2),0.08)

func _ampel(p:Vector3,blick:Vector3,gruen:bool):
	zyl(M.metall,p,p+Vector3(0,3.4,0),0.07,1.3)
	var b=Basis(Vector3.UP,atan2(blick.x,blick.z))
	var k=p+Vector3(0,2.9,0)+blick*0.18
	box(M.dunkel,k,Vector3(0.38,1.05,0.3),b,0.035)
	box(M.gelb,k+blick*0.02,Vector3(0.48,1.15,0.24),b,0.0)
	for i in 3:
		var c=[M.rot_l if not gruen else M.dunkel,M.dunkel,M.gruen_l if gruen else M.dunkel][i]
		var lp=k+Vector3(0,0.32-i*0.32,0)+blick*0.16
		mesh(c,CYL,Transform3D(b*Basis(Vector3.RIGHT,PI*0.5)*Basis().scaled(Vector3(0.22,0.02,0.22)),lp),1.0)
		box(M.dunkel,lp+Vector3(0,0.11,0)+blick*0.06,Vector3(0.26,0.03,0.14),b,0.0)
	box(M.gelb,p+Vector3(0,1.1,0)-blick*0.1,Vector3(0.14,0.22,0.12),b,0.02)

func _laterne(p:Vector3,zur_strasse:Vector3):
	zyl(M.metall,p,p+Vector3(0,0.5,0),0.14,1.2)
	zyl(M.metall,p,p+Vector3(0,5.2,0),0.07,1.3)
	var a=p+Vector3(0,5.0,0)
	var e=a+zur_strasse*1.3+Vector3(0,0.25,0)
	zyl(M.metall,a,e,0.05,1.3)
	var b=Basis(Vector3.UP,atan2(zur_strasse.x,zur_strasse.z))
	box(M.metall,e+Vector3(0,-0.05,0),Vector3(0.45,0.18,0.7),b,0.03)
	box(M.lampe,e+Vector3(0,-0.17,0),Vector3(0.35,0.06,0.55),b,0.0)

func _baum(p:Vector3):
	# runder Erdfleck mit Steinring
	zyl(M.erde,p+Vector3(0,0.0,0),p+Vector3(0,0.03,0),0.9)
	for k in 12:
		var a=TAU*k/12.0
		box(M.stein,p+Vector3(cos(a)*0.98,0.06,sin(a)*0.98),Vector3(0.18,0.12,0.5),Basis(Vector3.UP,-a),0.015)
	var h=rng.randf_range(3.2,4.2)
	zyl(M.rinde,p,p+Vector3(0.1,h,0.05),0.17,1.25)
	zyl(M.rinde,p+Vector3(0,h*0.65,0),p+Vector3(0.9,h+0.6,0.3),0.08,1.3)
	zyl(M.rinde,p+Vector3(0,h*0.7,0),p+Vector3(-0.7,h+0.7,-0.5),0.08,1.3)
	var lm:Material=M.laub[rng.randi()%M.laub.size()]
	var c=p+Vector3(0.1,h+1.3,0.05)
	kugel(lm,c,Vector3(1.9,1.6,1.9),1.06)
	for k in 6:
		var a=TAU*k/6.0+rng.randf()
		kugel(M.laub[(k+1)%3] if k%2==0 else lm,c+Vector3(cos(a)*1.4,rng.randf_range(-0.6,0.7),sin(a)*1.4),Vector3(1.0,0.85,1.0)*rng.randf_range(0.8,1.15),1.07)
	kugel(lm,c+Vector3(0,1.2,0),Vector3(1.2,1.0,1.2),1.07)

func _bank(p:Vector3,blick:Vector3):
	var b=Basis(Vector3.UP,atan2(blick.x,blick.z))
	for sd in [-0.8,0.8]:
		box(M.metall,p+b*Vector3(sd,0.22,0),Vector3(0.08,0.44,0.5),b,0.02)
		box(M.metall,p+b*Vector3(sd,0.65,-0.22),Vector3(0.08,0.5,0.06),b,0.0)
	for q in 3:box(M.holz,p+b*Vector3(0,0.46,-0.18+q*0.16),Vector3(1.9,0.05,0.13),b,0.02)
	for q in 2:box(M.holz,p+b*Vector3(0,0.68+q*0.17,-0.27),Vector3(1.9,0.13,0.05),b,0.02)

func _muell(p:Vector3):
	zyl(M.laub[2],p,p+Vector3(0,0.85,0),0.27,1.15)
	zyl(M.dunkel,p+Vector3(0,0.85,0),p+Vector3(0,0.92,0),0.3,1.1)

func _hydrant(p:Vector3):
	zyl(M.rot,p,p+Vector3(0,0.65,0),0.13,1.2)
	kugel(M.rot,p+Vector3(0,0.68,0),Vector3(0.14,0.12,0.14),1.1)
	for sd in [-1,1]:zyl(M.rot,p+Vector3(0,0.45,0),p+Vector3(sd*0.24,0.45,0),0.06,1.2)

func _litfass(p:Vector3):
	zyl(M.weiss,p,p+Vector3(0,2.8,0),0.6,1.08)
	for k in 5:
		var a=TAU*k/5.0
		box([M.rot,M.gelb,M.markise[2][0],M.blume[2],M.laub[1]][k],p+Vector3(cos(a)*0.6,1.6,sin(a)*0.6),Vector3(0.62,1.5,0.05),Basis(Vector3.UP,-a+PI*0.5),0.0)
	zyl(M.laub[2],p+Vector3(0,2.8,0),p+Vector3(0,3.0,0),0.72,1.08)
	mesh(M.laub[2],ConeHelper.kegel(0.6,0.5),Transform3D(Basis(),p+Vector3(0,3.25,0)),1.06)

# ================= Geometrie: Loft (Ringe) und Rohre =================
func _tri(s:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,aussen:Vector3,na=null,nb=null,nc=null):
	var cr=(b-a).cross(c-a)
	if cr.length()<1e-9:return
	if cr.dot(aussen)>0:
		var t=b;b=c;c=t;var tn=nb;nb=nc;nc=tn
		cr=(b-a).cross(c-a)
	var fn=-cr.normalized()
	s.set_normal(na if na!=null else fn);s.add_vertex(a)
	s.set_normal(nb if nb!=null else fn);s.add_vertex(b)
	s.set_normal(nc if nc!=null else fn);s.add_vertex(c)
func _mitte_ring(r:PackedVector3Array)->Vector3:
	var c=Vector3.ZERO
	for v in r:c+=v
	return c/r.size()
func _loft_in(s:SurfaceTool,R:Array,glatt:bool,deckel:bool):
	var N=R[0].size();var cs=[]
	for r in R:cs.append(_mitte_ring(r))
	for i in R.size()-1:
		var mid=(cs[i]+cs[i+1])*0.5
		for k in N:
			var a=R[i][k];var b=R[i][(k+1)%N];var c=R[i+1][(k+1)%N];var d=R[i+1][k]
			var out=(a+b+c+d)*0.25-mid
			if glatt:
				var na=(a-cs[i]).normalized();var nb=(b-cs[i]).normalized();var nc=(c-cs[i+1]).normalized();var nd=(d-cs[i+1]).normalized()
				_tri(s,a,b,c,out,na,nb,nc);_tri(s,a,c,d,out,na,nc,nd)
			else:
				_tri(s,a,b,c,out);_tri(s,a,c,d,out)
	if deckel:
		for e in [[0,1],[R.size()-1,R.size()-2]]:
			var r=R[e[0]];var c0=cs[e[0]];var out=c0-cs[e[1]]
			if out.length()<1e-6:out=c0-cs[e[1]-1 if e[1]>0 else e[1]+1]
			for k in N:_tri(s,c0,r[k],r[(k+1)%N],out)
func loft(m:Material,R:Array,glatt:=false,kontur:=0.03,deckel:=true):
	_loft_in(_st(m,true),R,glatt,deckel)
	if kontur>0.0:
		var cs=[];for r in R:cs.append(_mitte_ring(r))
		var E=[]
		for i in R.size():
			var r:PackedVector3Array=R[i];var q=PackedVector3Array()
			var shift=Vector3.ZERO
			if i==0:shift=(cs[0]-cs[1]).normalized()*kontur
			elif i==R.size()-1:shift=(cs[i]-cs[i-1]).normalized()*kontur
			for v in r:q.append(v+(v-cs[i]).normalized()*kontur+shift)
			E.append(q)
		_loft_in(_st(ink,true),E,false,deckel)
func ring_ell(c:Vector3,u:Vector3,v:Vector3,ru:float,rv:float,n:=12)->PackedVector3Array:
	var r=PackedVector3Array()
	for k in n:
		var a=TAU*k/n;r.append(c+u*cos(a)*ru+v*sin(a)*rv)
	return r
func rohr(m:Material,P:Array,rad:Array,kontur:=0.018,n:=10,enden:=true):
	var ges=(P[P.size()-1]-P[0]).normalized()
	var ref=Vector3.RIGHT if abs(ges.x)<0.85 else Vector3.FORWARD
	var R=[]
	for i in P.size():
		var t:Vector3
		if i==0:t=P[1]-P[0]
		elif i==P.size()-1:t=P[i]-P[i-1]
		else:t=(P[i+1]-P[i-1])
		t=t.normalized()
		var u=t.cross(ref).normalized();var v=t.cross(u).normalized()
		R.append(ring_ell(P[i],u,v,rad[i],rad[i],n))
	loft(m,R,true,kontur,true)
	if enden:
		kugel(m,P[0],Vector3.ONE*rad[0],1.0+kontur/max(rad[0],0.01))
		kugel(m,P[P.size()-1],Vector3.ONE*rad[rad.size()-1],1.0+kontur/max(rad[rad.size()-1],0.01))
# Kasten-Ring für Karosserien (lokal: x Breite, y Höhe, z Länge)
func ring_k(T:Transform3D,z:float,y0:float,y1:float,hw0:float,hw1:float,c:float)->PackedVector3Array:
	var r=PackedVector3Array()
	for v in [Vector3(-hw0,y0+c,z),Vector3(-hw0+c,y0,z),Vector3(hw0-c,y0,z),Vector3(hw0,y0+c,z),Vector3(hw1,y1-c,z),Vector3(hw1-c,y1,z),Vector3(-hw1+c,y1,z),Vector3(-hw1,y1-c,z)]:
		r.append(T*v)
	return r
func karosse(m:Material,T:Transform3D,secs:Array,kontur:=0.03):
	var R=[]
	for q in secs:R.append(ring_k(T,q[0],q[1],q[2],q[3],q[4],q[5]))
	loft(m,R,false,kontur,true)
func lbox(m:Material,T:Transform3D,c:Vector3,s:Vector3,kontur:=0.0,b:=Basis()):
	box(m,T*c,s,T.basis.orthonormalized()*b,kontur)
func lstab(m:Material,T:Transform3D,a:Vector3,e:Vector3,d:float,kontur:=0.0):
	var A=T*a;var E=T*e;var dir=E-A
	var side=(T.basis*Vector3.UP).cross(dir).normalized()
	if side.length()<0.1:side=T.basis*Vector3.RIGHT
	box(m,(A+E)*0.5,Vector3(dir.length(),d,d),_rich(dir,side),kontur)
func _schrift(text:String,pos:Vector3,b:Basis,px:float,farbe:Color,umriss:=Color(0,0,0,0),fs:=96):
	var lb=Label3D.new();lb.text=text;lb.font_size=fs;lb.pixel_size=px;lb.modulate=farbe;lb.shaded=false;lb.double_sided=false
	if umriss.a>0:lb.outline_size=int(fs*0.12);lb.outline_modulate=umriss
	else:lb.outline_size=0
	lb.transform=Transform3D(b,pos);welt.add_child(lb)

# ================= Fahrzeuge =================
func _lack(c:Color)->StandardMaterial3D:
	var m=_toon(c*Color(0.86,0.86,0.86,1.0),0.4);m.metallic_specular=0.55;return m
var _glas_auto:Material
func _rad(T:Transform3D,c:Vector3,r:float,br:float,seite:int,art:String,felge:Material,koerper_x:float):
	var ax=T.basis*Vector3(1,0,0)
	var C=T*c
	zyl(M.reifen,C-ax*br*0.5,C+ax*br*0.5,r,1.06)
	# Radlauf: dunkler Kreis auf der Karosserie
	var bx=T*Vector3(seite*(koerper_x+0.004),c.y+0.02,c.z)
	zyl(M.dunkel,bx-ax*0.004,bx+ax*0.004,r+0.07,1.0)
	var F=C+ax*seite*(br*0.5)
	zyl(felge,F-ax*seite*0.01,F+ax*seite*0.012,r*(0.62 if art!="sport" else 0.78),1.0)
	match art:
		"stahl":
			zyl(M.chrom,F,F+ax*seite*0.03,r*0.32,1.0)
			for k in 6:
				var a=TAU*k/6.0;var o=(T.basis*Vector3(0,cos(a),sin(a)))*r*0.47
				kugel(M.dunkel,F+o+ax*seite*0.012,Vector3(0.022,0.022,0.022),1.0)
		"sport":
			zyl(M.dunkel,F+ax*seite*0.005,F+ax*seite*0.015,r*0.72,1.0)
			for k in 5:
				var a=TAU*k/5.0;var o=(T.basis*Vector3(0,cos(a),sin(a)))
				box(felge,F+o*r*0.38+ax*seite*0.025,Vector3(0.03,r*0.68,0.07),_rich(ax,o.cross(ax)) if false else Basis(ax,o,ax.cross(o)).orthonormalized()*Basis(),0.0)
			zyl(M.chrom,F,F+ax*seite*0.035,r*0.16,1.0)
		"lkw":
			zyl(M.chrom,F,F+ax*seite*0.06,r*0.3,1.0)
			for k in 8:
				var a=TAU*k/8.0;var o=(T.basis*Vector3(0,cos(a),sin(a)))*r*0.45
				kugel(M.chrom,F+o+ax*seite*0.02,Vector3(0.03,0.03,0.03),1.0)
		_:
			zyl(M.chrom,F,F+ax*seite*0.025,r*0.5,1.0)
func _kabine(T:Transform3D,secs:Array,lack:Material,dachm:Material,dach_secs:Array,b_saeule:=true,c_dick:=0.09):
	if _glas_auto==null:_glas_auto=_shader(GLAS,{"farbe":Color(0.2,0.33,0.43)})
	karosse(_glas_auto,T,secs,0.02)
	karosse(dachm,T,dach_secs,0.025)
	var n=secs.size()
	for sd in [-1,1]:
		# A-Säule
		var a0=secs[0];var a1=secs[1]
		lstab(lack,T,Vector3(sd*(a0[3]-0.01),a0[1],a0[0]),Vector3(sd*(a1[4]+0.005),a1[2]-0.02,a1[0]),0.07,0.018)
		# C-Säule
		var c0=secs[n-1];var c1=secs[n-2]
		lstab(lack,T,Vector3(sd*(c0[3]-0.01),c0[1],c0[0]),Vector3(sd*(c1[4]+0.005),c1[2]-0.02,c1[0]),c_dick,0.018)
		# B-Säule
		if b_saeule:
			var zb=(a1[0]+c1[0])*0.5-0.05
			lstab(lack,T,Vector3(sd*(a1[3]+0.004),a1[1],zb+0.08),Vector3(sd*(a1[4]+0.006),a1[2]-0.03,zb),0.075,0.015)
		# Fensterrahmen unten (Gürtellinie)
		lstab(M.dunkel,T,Vector3(sd*(a0[3]+0.004),a0[1]+0.02,a0[0]),Vector3(sd*(c0[3]+0.004),c0[1]+0.02,c0[0]),0.03,0.0)
	# Front-/Heckscheibenrahmen
	lstab(lack,T,Vector3(-a_bw(secs,1),secs[1][2]-0.02,secs[1][0]),Vector3(a_bw(secs,1),secs[1][2]-0.02,secs[1][0]),0.06,0.015)
func a_bw(secs:Array,i:int)->float:return secs[i][4]
func _scheinwerfer_rund(T:Transform3D,c:Vector3,r:float):
	var A=T*c;var f=T.basis*Vector3(0,0,1)
	zyl(M.chrom,A-f*0.05,A+f*0.02,r,1.12)
	zyl(M.lampe,A+f*0.02,A+f*0.032,r*0.78,1.0)
	kugel(M.weiss,A+f*0.03+T.basis*Vector3(r*0.25,r*0.3,0),Vector3(r*0.18,r*0.14,0.01),1.0)
func _blaulicht(T:Transform3D,c:Vector3,breite:float):
	var blau=_toon(Color(0.2,0.45,1.0));blau.emission_enabled=true;blau.emission=Color(0.1,0.3,1.0);blau.emission_energy_multiplier=1.4
	lbox(M.dunkel,T,c,Vector3(breite,0.06,0.3),0.02)
	for sd in [-1,1]:lbox(blau,T,c+Vector3(sd*breite*0.3,0.09,0),Vector3(breite*0.36,0.13,0.26),0.02)
	lbox(M.weiss,T,c+Vector3(0,0.09,0),Vector3(breite*0.2,0.11,0.24),0.015)

func _autos():
	# Parkreihe am Straßenrand (Nord-Süd-Straße, Westseite) – für die Nahbilder
	var px=-(RW-1.25)
	_trabant(Transform3D(Basis(Vector3.UP,0.0),Vector3(px,0,-17.0)),Color(0.42,0.66,0.78),Color(0.95,0.94,0.88))
	_wartburg(Transform3D(Basis(Vector3.UP,0.0),Vector3(px,0,-23.5)),Color(0.86,0.78,0.52))
	_taxi(Transform3D(Basis(Vector3.UP,0.0),Vector3(px,0,-31.0)))
	_polizei(Transform3D(Basis(Vector3.UP,0.0),Vector3(px,0,-38.5)))
	_rtw(Transform3D(Basis(Vector3.UP,0.0),Vector3(px-0.1,0,-47.5)))
	_feuerwehr(Transform3D(Basis(Vector3.UP,PI),Vector3(RW-1.5,0,-30.0)))
	_sport(Transform3D(Basis(Vector3.UP,PI*0.5+0.1),Vector3(-1.5,0,-2.0)),Color(0.95,0.18,0.12))
	_trabant(Transform3D(Basis(Vector3.UP,PI),Vector3(RW-1.3,0,-13.0)),Color(0.58,0.74,0.46),Color(0.95,0.94,0.88))
	_trabant(Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(22.0,0,RW-1.3)),Color(0.9,0.85,0.72),Color(0.9,0.85,0.72))
	_wartburg(Transform3D(Basis(Vector3.UP,-PI*0.5),Vector3(-26.0,0,-(RW-1.3))),Color(0.35,0.42,0.55))
	_polizei(Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(30.0,0,-(RW-2.8))))
	# im Hof
	_trabant(Transform3D(Basis(Vector3.UP,0.3),Vector3(30.0,0.06,48.0)),Color(0.72,0.25,0.2),Color(0.95,0.94,0.88))
	_wartburg(Transform3D(Basis(Vector3.UP,PI*0.5+0.1),Vector3(44.0,0.06,52.0)),Color(0.55,0.62,0.52))

func _trabant(T:Transform3D,farbe:Color,dachfarbe:Color):
	var lack=_lack(farbe);var dach=_lack(dachfarbe)
	karosse(lack,T,[[1.755,0.40,0.66,0.60,0.57,0.07],[1.70,0.31,0.77,0.70,0.67,0.08],[1.45,0.29,0.81,0.745,0.71,0.08],[0.78,0.28,0.86,0.75,0.72,0.07],
		[-1.15,0.28,0.86,0.75,0.72,0.07],[-1.55,0.29,0.85,0.745,0.71,0.07],[-1.70,0.32,0.82,0.72,0.69,0.08],[-1.755,0.40,0.74,0.64,0.61,0.07]])
	_kabine(T,[[0.78,0.84,0.87,0.70,0.69,0.02],[0.14,0.84,1.40,0.70,0.60,0.05],[-0.98,0.84,1.40,0.70,0.60,0.05],[-1.32,0.84,0.87,0.70,0.69,0.02]],lack,dach,
		[[0.24,1.36,1.40,0.62,0.60,0.02],[0.17,1.36,1.49,0.65,0.60,0.06],[-1.0,1.36,1.49,0.65,0.60,0.06],[-1.08,1.36,1.40,0.62,0.60,0.02]],true,0.13)
	# Alu-Zierleiste ("Halo") unter dem Dach
	for sd in [-1,1]:lstab(M.chrom,T,Vector3(sd*0.652,1.365,0.16),Vector3(sd*0.652,1.365,-1.0),0.03)
	# Heckflossen
	for sd in [-1,1]:
		hex(lack,[T*Vector3(sd*0.60,0.84,-0.9),T*Vector3(sd*0.74,0.84,-0.9),T*Vector3(sd*0.74,0.84,-1.74),T*Vector3(sd*0.60,0.84,-1.74),
			T*Vector3(sd*0.64,0.85,-0.92),T*Vector3(sd*0.735,0.85,-0.92),T*Vector3(sd*0.715,0.895,-1.73),T*Vector3(sd*0.64,0.885,-1.73)],0.02)
	# Front: runde Scheinwerfer in Chromring, Grill-"Lächeln", Blinker, Stoßstange
	for sd in [-1,1]:
		_scheinwerfer_rund(T,Vector3(sd*0.5,0.6,1.8),0.1)
		lbox(_toon(Color(1.0,0.6,0.1)),T,Vector3(sd*0.5,0.445,1.765),Vector3(0.15,0.06,0.03),0.012)
	# "Lächeln": breite helle Grillblende, darin dunkle Schlitze mit Chromstäben
	lbox(M.weiss,T,Vector3(0,0.585,1.762),Vector3(1.12,0.2,0.03),0.016)
	lbox(M.dunkel,T,Vector3(0,0.575,1.775),Vector3(0.62,0.12,0.012))
	for k in 3:lbox(M.chrom,T,Vector3(0,0.535+k*0.04,1.782),Vector3(0.6,0.014,0.01))
	lstab(M.dunkel,T,Vector3(-0.66,0.745,1.66),Vector3(0.66,0.745,1.66),0.012)
	lbox(M.stein_d,T,Vector3(0,0.355,1.77),Vector3(1.38,0.09,0.12),0.02)
	for sd in [-1,1]:lbox(M.dunkel,T,Vector3(sd*0.70,0.355,1.74),Vector3(0.12,0.1,0.16),0.0)
	# Seite: Alu-Leiste am Kotflügel, Türfugen, Griff, Lüftungsgitter an der C-Säule
	for sd in [-1,1]:
		lstab(M.chrom,T,Vector3(sd*0.753,0.70,1.62),Vector3(sd*0.753,0.70,0.78),0.022)
		lstab(M.dunkel,T,Vector3(sd*0.754,0.32,0.74),Vector3(sd*0.754,0.84,0.74),0.012)
		lstab(M.dunkel,T,Vector3(sd*0.754,0.32,-0.46),Vector3(sd*0.754,0.84,-0.46),0.012)
		lbox(M.stein_d,T,Vector3(sd*0.756,0.76,-0.33),Vector3(0.02,0.04,0.13),0.006)
		lbox(M.dunkel,T,Vector3(sd*0.66,1.0,-1.12),Vector3(0.02,0.16,0.14),0.0)
		lbox(lack,T,Vector3(sd*0.80,0.95,0.62),Vector3(0.08,0.06,0.05),0.012)
	# Heck: hängende Leuchten (rot/orange), Stoßstange, Kennzeichen in der Mulde
	for sd in [-1,1]:
		lbox(M.rot_l,T,Vector3(sd*0.56,0.60,-1.757),Vector3(0.2,0.13,0.025),0.012,Basis(Vector3(0,0,1),sd*0.18))
		lbox(_toon(Color(1.0,0.6,0.1)),T,Vector3(sd*0.56,0.71,-1.757),Vector3(0.2,0.06,0.025),0.01,Basis(Vector3(0,0,1),sd*0.18))
	lbox(M.stein_d,T,Vector3(0,0.37,-1.775),Vector3(1.36,0.09,0.12),0.02)
	lbox(M.weiss,T,Vector3(0,0.5,-1.76),Vector3(0.42,0.11,0.01),0.008)
	for sx in [-1,1]:
		for sz in [0.98,-1.05]:_rad(T,Vector3(sx*0.665,0.28,sz),0.28,0.17,sx,"stahl",lack,0.75)
	box(M.dunkel,T*Vector3(0,0.006,0),Vector3(1.4,0.004,3.3),T.basis,0.0)

func _wartburg(T:Transform3D,farbe:Color):
	var lack=_lack(farbe)
	karosse(lack,T,[[2.11,0.38,0.72,0.76,0.74,0.04],[2.07,0.33,0.80,0.81,0.79,0.05],[0.88,0.32,0.84,0.82,0.80,0.05],[-1.5,0.32,0.86,0.82,0.80,0.05],[-2.07,0.33,0.86,0.81,0.79,0.05],[-2.11,0.40,0.82,0.76,0.74,0.04]])
	_kabine(T,[[0.88,0.84,0.86,0.78,0.77,0.02],[0.17,0.84,1.40,0.78,0.68,0.04],[-0.95,0.84,1.40,0.78,0.68,0.04],[-1.5,0.84,0.86,0.78,0.77,0.02]],lack,lack,
		[[0.19,1.37,1.43,0.69,0.67,0.03],[-0.97,1.37,1.43,0.69,0.67,0.03]],true,0.16)
	# Front: breiter Grill über die ganze Breite, eckige Scheinwerfer im Chromrahmen
	lbox(M.chrom,T,Vector3(0,0.585,2.1),Vector3(1.5,0.24,0.04),0.015)
	lbox(M.dunkel,T,Vector3(0,0.585,2.115),Vector3(0.82,0.17,0.02))
	for k in 5:lbox(M.chrom,T,Vector3(0,0.52+k*0.032,2.125),Vector3(0.8,0.012,0.012))
	for sd in [-1,1]:
		lbox(M.lampe,T,Vector3(sd*0.58,0.585,2.12),Vector3(0.3,0.17,0.02),0.012)
		lbox(_toon(Color(1.0,0.6,0.1)),T,Vector3(sd*0.68,0.43,2.09),Vector3(0.2,0.07,0.04),0.012)
	lbox(M.chrom,T,Vector3(0,0.39,2.13),Vector3(1.6,0.08,0.1),0.02)
	lbox(M.chrom,T,Vector3(0,0.39,-2.13),Vector3(1.6,0.08,0.1),0.02)
	for sd in [-1,1]:
		lbox(M.rot_l,T,Vector3(sd*0.56,0.66,-2.115),Vector3(0.42,0.14,0.02),0.012)
		lbox(_toon(Color(1.0,0.6,0.1)),T,Vector3(sd*0.56,0.56,-2.115),Vector3(0.42,0.06,0.02),0.01)
		lstab(M.chrom,T,Vector3(sd*0.825,0.62,1.95),Vector3(sd*0.825,0.62,-1.95),0.02)
		for z in [0.86,-0.42]:lstab(M.dunkel,T,Vector3(sd*0.824,0.33,z),Vector3(sd*0.824,0.84,z),0.012)
		lbox(M.chrom,T,Vector3(sd*0.83,0.77,0.62),Vector3(0.02,0.03,0.12))
		lbox(M.chrom,T,Vector3(sd*0.83,0.77,-0.6),Vector3(0.02,0.03,0.12))
	lbox(M.weiss,T,Vector3(0,0.52,-2.12),Vector3(0.5,0.11,0.01),0.008)
	for sx in [-1,1]:
		for sz in [1.3,-1.25]:_rad(T,Vector3(sx*0.72,0.3,sz),0.3,0.18,sx,"stahl",M.stein,0.82)
	box(M.dunkel,T*Vector3(0,0.006,0),Vector3(1.55,0.004,4.0),T.basis,0.0)

func _taxi(T:Transform3D):
	var lack=_lack(Color(0.96,0.9,0.62))
	karosse(lack,T,[[2.37,0.40,0.70,0.80,0.77,0.06],[2.30,0.33,0.80,0.86,0.83,0.07],[1.0,0.32,0.86,0.87,0.84,0.06],[-1.6,0.32,0.90,0.87,0.84,0.06],[-2.3,0.34,0.90,0.85,0.82,0.07],[-2.37,0.42,0.86,0.80,0.77,0.06]])
	_kabine(T,[[1.0,0.86,0.88,0.83,0.82,0.02],[0.25,0.86,1.42,0.83,0.72,0.05],[-0.95,0.86,1.42,0.83,0.72,0.05],[-1.65,0.86,0.90,0.83,0.82,0.02]],lack,lack,
		[[0.27,1.39,1.45,0.73,0.71,0.03],[-0.97,1.39,1.45,0.73,0.71,0.03]],true,0.14)
	# stehender Chromgrill mit Stern, breite Scheinwerfer mit Rippen
	lbox(M.chrom,T,Vector3(0,0.6,2.37),Vector3(0.42,0.26,0.06),0.018)
	for k in 7:lbox(M.dunkel,T,Vector3(-0.15+k*0.05,0.6,2.4),Vector3(0.02,0.2,0.01))
	zyl(M.chrom,T*Vector3(0,0.76,2.33),T*Vector3(0,0.8,2.33),0.035,1.2)
	for sd in [-1,1]:
		lbox(M.lampe,T,Vector3(sd*0.55,0.6,2.36),Vector3(0.36,0.16,0.02),0.012)
		for k in 5:lbox(M.weiss,T,Vector3(sd*0.55-0.14+k*0.07,0.6,2.372),Vector3(0.012,0.14,0.006))
		lbox(_toon(Color(1.0,0.6,0.1)),T,Vector3(sd*0.8,0.6,2.3),Vector3(0.06,0.14,0.12),0.01)
		lbox(M.rot_l,T,Vector3(sd*0.56,0.68,-2.37),Vector3(0.44,0.2,0.02),0.012)
		lbox(_toon(Color(1.0,0.6,0.1)),T,Vector3(sd*0.56,0.55,-2.37),Vector3(0.44,0.06,0.02),0.01)
		# Kunststoff-Planke unten an der Seite
		lstab(M.stein_d,T,Vector3(sd*0.875,0.42,2.2),Vector3(sd*0.875,0.42,-2.2),0.1,0.01)
		for z in [1.0,-0.38]:lstab(M.dunkel,T,Vector3(sd*0.874,0.33,z),Vector3(sd*0.874,0.86,z),0.012)
		for z in [0.75,-0.55]:lbox(M.chrom,T,Vector3(sd*0.88,0.8,z),Vector3(0.02,0.03,0.14))
	lbox(M.stein_d,T,Vector3(0,0.42,2.4),Vector3(1.7,0.12,0.1),0.02)
	lbox(M.stein_d,T,Vector3(0,0.42,-2.4),Vector3(1.7,0.12,0.1),0.02)
	lbox(M.weiss,T,Vector3(0,0.55,-2.385),Vector3(0.5,0.11,0.01),0.008)
	# Taxischild
	var gelb=_toon(Color(1.0,0.86,0.2));gelb.emission_enabled=true;gelb.emission=Color(0.4,0.32,0.05)
	lbox(gelb,T,Vector3(0,1.56,-0.35),Vector3(0.6,0.2,0.24),0.02)
	for sd in [-1,1]:_schrift("TAXI",T*Vector3(0,1.56,-0.35+sd*0.125),T.basis.orthonormalized()*Basis(Vector3.UP,0.0 if sd>0 else PI),0.0022,Color(0.1,0.1,0.1))
	for sx in [-1,1]:
		for sz in [1.4,-1.42]:_rad(T,Vector3(sx*0.75,0.31,sz),0.31,0.2,sx,"",M.chrom,0.87)
	box(M.dunkel,T*Vector3(0,0.006,0),Vector3(1.65,0.004,4.5),T.basis,0.0)

func _polizei(T:Transform3D):
	var lack=_lack(Color(0.85,0.87,0.9));var blau=_lack(Color(0.12,0.3,0.7))
	karosse(lack,T,[[2.3,0.42,0.70,0.76,0.70,0.12],[2.22,0.34,0.80,0.85,0.80,0.12],[1.5,0.32,0.92,0.88,0.84,0.1],[0.9,0.32,0.96,0.88,0.84,0.1],[-1.9,0.32,0.98,0.88,0.84,0.1],[-2.25,0.36,0.96,0.84,0.80,0.12],[-2.3,0.45,0.92,0.78,0.75,0.1]])
	_kabine(T,[[0.9,0.95,0.97,0.84,0.83,0.03],[0.05,0.95,1.48,0.84,0.72,0.06],[-1.95,0.95,1.48,0.84,0.72,0.06],[-2.24,0.95,1.02,0.82,0.80,0.04]],lack,blau,
		[[0.08,1.45,1.5,0.72,0.70,0.03],[-1.98,1.45,1.5,0.72,0.70,0.03]],true,0.18)
	# blaue Motorhaube + Streifen, Schriftzug
	karosse(blau,T,[[2.23,0.80,0.82,0.80,0.78,0.02],[1.5,0.92,0.94,0.84,0.82,0.02],[0.92,0.96,0.975,0.84,0.82,0.01]],0.0)
	for sd in [-1,1]:
		lstab(blau,T,Vector3(sd*0.885,0.62,2.15),Vector3(sd*0.885,0.62,-2.2),0.2,0.012)
		lstab(M.weiss,T,Vector3(sd*0.888,0.5,2.15),Vector3(sd*0.888,0.5,-2.2),0.03,0.0)
		_schrift("POLIZEI",T*Vector3(sd*0.995,0.62,-0.2),T.basis.orthonormalized()*Basis(Vector3.UP,sd*PI*0.5),0.0035,Color(1,1,1))
		lbox(M.lampe,T,Vector3(sd*0.55,0.68,2.24),Vector3(0.36,0.13,0.06),0.012,Basis(Vector3(0,0,1),-sd*0.12))
		lbox(M.rot_l,T,Vector3(sd*0.62,0.8,-2.29),Vector3(0.26,0.3,0.03),0.012)
		for z in [0.92,-0.6]:lstab(M.dunkel,T,Vector3(sd*0.884,0.33,z),Vector3(sd*0.884,0.95,z),0.012)
	lbox(M.dunkel,T,Vector3(0,0.55,2.3),Vector3(0.9,0.14,0.03),0.012)
	zyl(M.chrom,T*Vector3(0,0.55,2.29),T*Vector3(0,0.55,2.33),0.07,1.0)
	lbox(M.stein_d,T,Vector3(0,0.4,2.33),Vector3(1.6,0.14,0.1),0.02)
	lbox(M.stein_d,T,Vector3(0,0.42,-2.33),Vector3(1.6,0.14,0.1),0.02)
	lbox(M.weiss,T,Vector3(0,0.6,-2.31),Vector3(0.5,0.11,0.01),0.008)
	_blaulicht(T,Vector3(0,1.53,-0.15),1.2)
	for sx in [-1,1]:
		for sz in [1.42,-1.35]:_rad(T,Vector3(sx*0.76,0.32,sz),0.32,0.21,sx,"sport",M.stein,0.88)
	box(M.dunkel,T*Vector3(0,0.006,0),Vector3(1.7,0.004,4.4),T.basis,0.0)

func _rtw(T:Transform3D):
	var weiss=_lack(Color(0.98,0.98,0.96));var rot=_lack(Color(1.0,0.25,0.15))
	karosse(weiss,T,[[2.95,0.45,0.85,0.88,0.82,0.15],[2.88,0.40,1.02,0.97,0.92,0.13],[2.25,0.38,1.22,1.0,0.96,0.1],[1.45,0.38,1.22,1.0,0.96,0.1]])
	_kabine(T,[[2.25,1.2,1.24,0.96,0.95,0.03],[1.62,1.2,2.2,0.96,0.9,0.06],[1.46,1.2,2.2,0.96,0.9,0.06],[1.42,1.2,1.24,0.96,0.95,0.03]],weiss,weiss,
		[[1.64,2.17,2.24,0.9,0.88,0.04],[1.40,2.17,2.24,0.9,0.88,0.04]],false,0.05)
	karosse(weiss,T,[[1.42,0.5,2.95,1.08,1.08,0.08],[-2.95,0.5,2.95,1.08,1.08,0.08]],0.035)
	for sd in [-1,1]:
		lstab(rot,T,Vector3(sd*1.085,1.25,1.4),Vector3(sd*1.085,1.25,-2.9),0.32,0.01)
		lstab(rot,T,Vector3(sd*1.0,0.95,2.85),Vector3(sd*1.0,0.95,1.45),0.18,0.0)
		lstab(_lack(Color(1.0,0.85,0.2)),T,Vector3(sd*1.087,1.5,1.4),Vector3(sd*1.087,1.5,-2.9),0.06,0.0)
		_schrift("RETTUNGSDIENST",T*Vector3(sd*1.1,1.85,-0.9),T.basis.orthonormalized()*Basis(Vector3.UP,sd*PI*0.5),0.0042,Color(0.85,0.1,0.08))
		# Seitenfenster im Koffer, Tür
		lbox(_glas_auto,T,Vector3(sd*1.085,2.2,0.6),Vector3(0.02,0.5,0.9),0.015)
		lstab(M.dunkel,T,Vector3(sd*1.083,0.52,1.0),Vector3(sd*1.083,2.6,1.0),0.015)
		lbox(M.lampe,T,Vector3(sd*0.62,0.82,2.92),Vector3(0.36,0.2,0.04),0.012)
		lbox(M.rot_l,T,Vector3(sd*0.95,0.85,-2.96),Vector3(0.14,0.5,0.03),0.012)
		_blaulicht(T,Vector3(sd*0.82,2.98,1.3),0.4)
		_blaulicht(T,Vector3(sd*0.82,2.98,-2.85),0.4)
	_blaulicht(T,Vector3(0,2.27,1.55),1.3)
	lbox(M.dunkel,T,Vector3(0,0.7,2.96),Vector3(1.0,0.22,0.03),0.012)
	lbox(M.stein_d,T,Vector3(0,0.48,2.98),Vector3(1.9,0.16,0.12),0.02)
	# Hecktüren mit Fenstern
	lstab(M.dunkel,T,Vector3(0,0.55,-2.955),Vector3(0,2.85,-2.955),0.02)
	for sd in [-1,1]:lbox(_glas_auto,T,Vector3(sd*0.5,2.2,-2.96),Vector3(0.7,0.55,0.02),0.012)
	lstab(rot,T,Vector3(-1.05,1.25,-2.96),Vector3(1.05,1.25,-2.96),0.3,0.0)
	lbox(M.metall,T,Vector3(0,0.4,-3.05),Vector3(1.4,0.08,0.3),0.02)
	for sx in [-1,1]:
		for sz in [2.15,-1.9]:_rad(T,Vector3(sx*0.88,0.36,sz),0.36,0.24,sx,"",M.stein,1.0)
	box(M.dunkel,T*Vector3(0,0.006,0),Vector3(2.0,0.004,5.8),T.basis,0.0)

func _feuerwehr(T:Transform3D):
	var rot=_lack(Color(0.82,0.1,0.08));var weissm=_lack(Color(0.98,0.98,0.96))
	karosse(rot,T,[[3.75,0.7,2.5,1.15,1.08,0.18],[3.62,0.62,2.95,1.24,1.2,0.14],[2.0,0.62,2.95,1.24,1.2,0.1]])
	karosse(rot,T,[[1.95,0.75,2.85,1.25,1.25,0.06],[-3.75,0.75,2.85,1.25,1.25,0.06]])
	var gl=_shader(GLAS,{"farbe":Color(0.2,0.33,0.43)})
	lbox(gl,T,Vector3(0,2.05,3.76),Vector3(2.0,0.75,0.03),0.02)
	lstab(M.dunkel,T,Vector3(0,1.68,3.775),Vector3(0,2.42,3.775),0.04)
	for sd in [-1,1]:
		lbox(gl,T,Vector3(sd*1.245,2.15,3.15),Vector3(0.02,0.7,0.65),0.015)
		lbox(gl,T,Vector3(sd*1.245,2.15,2.45),Vector3(0.02,0.7,0.6),0.015)
		for z in [3.5,2.8,2.1]:lstab(M.dunkel,T,Vector3(sd*1.244,0.65,z),Vector3(sd*1.244,2.9,z),0.015)
		# weißer Streifen über die ganze Länge
		lstab(weissm,T,Vector3(sd*1.252,0.95,3.6),Vector3(sd*1.252,0.95,-3.7),0.14,0.0)
		# Geräteräume mit Rollläden
		for k in 3:
			var z=1.5-k*1.65
			lbox(M.stein,T,Vector3(sd*1.252,1.95,z-0.7),Vector3(0.02,1.5,1.45),0.015)
			for q in 14:lbox(M.stein_d,T,Vector3(sd*1.262,1.25+q*0.1,z-0.7),Vector3(0.006,0.012,1.4))
			lbox(M.chrom,T,Vector3(sd*1.27,1.25,z-0.7),Vector3(0.03,0.04,0.5))
		lbox(M.lampe,T,Vector3(sd*0.82,1.0,3.79),Vector3(0.36,0.2,0.03),0.012)
		lbox(M.rot_l,T,Vector3(sd*1.0,1.0,-3.76),Vector3(0.18,0.3,0.03),0.012)
		lbox(M.dunkel,T,Vector3(sd*1.32,2.2,3.55),Vector3(0.06,0.32,0.18),0.012)
		_schrift("112",T*Vector3(sd*1.26,1.35,2.8),T.basis.orthonormalized()*Basis(Vector3.UP,sd*PI*0.5),0.006,Color(1,1,1),Color(0.3,0.0,0.0))
	_schrift("FEUERWEHR",T*Vector3(0,2.7,3.765),T.basis.orthonormalized(),0.0045,Color(1,1,1))
	lbox(M.dunkel,T,Vector3(0,0.75,3.82),Vector3(2.4,0.32,0.18),0.02)
	lbox(M.dunkel,T,Vector3(0,1.35,3.77),Vector3(1.2,0.5,0.03),0.0)
	for k in 6:lbox(M.chrom,T,Vector3(0,1.15+k*0.08,3.79),Vector3(1.15,0.02,0.01))
	_blaulicht(T,Vector3(0,3.0,3.2),2.0)
	for sd in [-1,1]:_blaulicht(T,Vector3(sd*0.9,2.9,-3.6),0.4)
	# Leiter auf dem Dach
	for sd in [-1,1]:
		lstab(M.chrom,T,Vector3(sd*0.4,3.02,1.7),Vector3(sd*0.4,3.02,-3.6),0.07,0.015)
		lstab(M.metall,T,Vector3(sd*0.6,2.86,1.5),Vector3(sd*0.6,2.98,1.5),0.05)
	var z=1.6
	while z>-3.6:
		lstab(M.chrom,T,Vector3(-0.4,3.02,z),Vector3(0.4,3.02,z),0.04);z-=0.32
	for sx in [-1,1]:
		for sz in [2.65,-1.95]:_rad(T,Vector3(sx*1.05,0.52,sz),0.52,0.34,sx,"lkw",M.stein,1.25)
	box(M.dunkel,T*Vector3(0,0.006,0),Vector3(2.4,0.004,7.4),T.basis,0.0)

func _sport(T:Transform3D,farbe:Color):
	var lack=_lack(farbe)
	karosse(lack,T,[[2.2,0.30,0.50,0.84,0.76,0.12],[2.05,0.25,0.62,0.95,0.9,0.12],[1.0,0.25,0.74,0.97,0.94,0.12],[-0.4,0.25,0.82,0.99,0.95,0.12],[-1.85,0.27,0.86,0.97,0.92,0.1],[-2.2,0.33,0.80,0.9,0.86,0.08]],0.03)
	_kabine(T,[[1.0,0.73,0.75,0.86,0.84,0.02],[0.05,0.76,1.16,0.83,0.63,0.08],[-0.65,0.78,1.16,0.83,0.63,0.08],[-1.85,0.84,0.88,0.87,0.86,0.02]],lack,lack,
		[[0.07,1.13,1.18,0.64,0.62,0.04],[-0.67,1.13,1.18,0.64,0.62,0.04]],false,0.12)
	for sd in [-1,1]:
		lbox(M.lampe,T,Vector3(sd*0.62,0.56,2.08),Vector3(0.42,0.07,0.16),0.014,Basis(Vector3(1,0,0),0.5)*Basis(Vector3(0,1,0),-sd*0.25))
		lbox(M.dunkel,T,Vector3(sd*0.99,0.55,-0.75),Vector3(0.02,0.24,0.6),0.012)
		lbox(M.rot_l,T,Vector3(sd*0.55,0.73,-2.19),Vector3(0.6,0.06,0.03),0.012)
		lbox(lack,T,Vector3(sd*0.95,0.86,0.62),Vector3(0.12,0.06,0.07),0.012)
	lbox(M.dunkel,T,Vector3(0,0.36,2.16),Vector3(1.2,0.12,0.05),0.012)
	lbox(M.dunkel,T,Vector3(0,0.33,-2.2),Vector3(1.4,0.1,0.06),0.012)
	for k in 4:lbox(M.metall,T,Vector3(-0.45+k*0.3,0.3,-2.22),Vector3(0.03,0.1,0.12))
	# Heckflügel
	lbox(M.dunkel,T,Vector3(0,1.03,-1.98),Vector3(1.75,0.04,0.32),0.018)
	for sd in [-1,1]:lbox(M.dunkel,T,Vector3(sd*0.6,0.93,-1.98),Vector3(0.05,0.18,0.18),0.012)
	for sx in [-1,1]:
		for sz in [1.32,-1.3]:_rad(T,Vector3(sx*0.86,0.34,sz),0.34,0.24,sx,"sport",M.chrom,0.97)
	box(M.dunkel,T*Vector3(0,0.006,0),Vector3(1.9,0.004,4.2),T.basis,0.0)

# ================= Menschen =================
const HAUT:=[Color(0.98,0.82,0.7),Color(0.93,0.72,0.56),Color(0.8,0.58,0.42),Color(0.6,0.4,0.28),Color(0.42,0.28,0.2)]
func _mensch(pos:Vector3,yaw:float,o:Dictionary):
	var sk:float=o.get("gr",1.0)
	var T=Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*sk),pos)
	var frau:bool=o.get("frau",false)
	var haut=_toon(o.haut);var oben=_toon(o.oben);var unten=_toon(o.unten);var haar=_toon(o.haar,0.6)
	var schuh=_toon(o.get("schuh",Color(0.95,0.95,0.95)))
	var ph:float=o.get("ph",0.0);var geht:bool=o.get("geht",false)
	var sw=sin(ph)*0.42 if geht else 0.0
	var X=func(v:Vector3)->Vector3:return T*v
	# ---- Beine ----
	var hb=0.085 if not frau else 0.09
	var kurz:bool=o.get("kurz",false);var rock:bool=o.get("rock",false)
	for sd in [-1,1]:
		var a=sw*sd
		var bend=max(0.0,-a)*1.3+0.06
		var H=Vector3(sd*hb,0.93,0)
		var K=H+Vector3(0,-cos(a),sin(a))*0.44
		var A=K+Vector3(0,-cos(a-bend),sin(a-bend))*0.42
		var hebe=max(0.0,0.1-A.y)
		H.y+=hebe;K.y+=hebe;A.y+=hebe
		var bein=unten if not (kurz or rock) else haut
		if kurz or rock:
			rohr(unten if kurz else haut,[X.call(H),X.call(H.lerp(K,0.55))],[0.095*sk,0.085*sk],0.016,10,false)
			rohr(haut,[X.call(H.lerp(K,0.5)),X.call(K),X.call(A)],[0.07*sk,0.06*sk,0.045*sk],0.016)
		else:
			rohr(unten,[X.call(H),X.call(K),X.call(A+Vector3(0,0.03,0))],[0.09*sk,0.068*sk,0.06*sk],0.016)
		# Schuh: von der Ferse zur Spitze
		var f=Vector3(0,0,1).rotated(Vector3.RIGHT,-0.0)
		var Fz=A.z;var Fy=max(A.y-0.06,0.0)
		var spitze=0.21 if not frau else 0.18
		loft(schuh,[ring_ell(X.call(Vector3(A.x,Fy+0.05,Fz-0.06)),T.basis*Vector3(1,0,0),T.basis*Vector3(0,1,0),0.05*sk,0.05*sk,10),
			ring_ell(X.call(Vector3(A.x,Fy+0.05,Fz+0.06)),T.basis*Vector3(1,0,0),T.basis*Vector3(0,1,0),0.055*sk,0.05*sk,10),
			ring_ell(X.call(Vector3(A.x,Fy+0.035,Fz+spitze*0.8)),T.basis*Vector3(1,0,0),T.basis*Vector3(0,1,0),0.05*sk,0.035*sk,10),
			ring_ell(X.call(Vector3(A.x,Fy+0.03,Fz+spitze)),T.basis*Vector3(1,0,0),T.basis*Vector3(0,1,0),0.03*sk,0.025*sk,10)],true,0.016)
		lbox(_toon(Color(0.15,0.13,0.12)),T,Vector3(A.x,Fy+0.006,Fz+0.06),Vector3(0.11,0.015,0.3),0.0)
	# ---- Becken / Rock ----
	var ux=T.basis*Vector3(1,0,0);var uz=T.basis*Vector3(0,0,1)
	if rock:
		loft(unten,[ring_ell(X.call(Vector3(0,1.02,0)),ux,uz,0.15*sk,0.105*sk,14),ring_ell(X.call(Vector3(0,0.9,0)),ux,uz,0.19*sk,0.13*sk,14),ring_ell(X.call(Vector3(0,0.58,0.01)),ux,uz,0.25*sk,0.2*sk,14)],true,0.016)
	else:
		loft(unten,[ring_ell(X.call(Vector3(0,0.82,0)),ux,uz,0.15*sk,0.1*sk,12),ring_ell(X.call(Vector3(0,0.92,0)),ux,uz,(0.175 if frau else 0.165)*sk,0.11*sk,12),ring_ell(X.call(Vector3(0,1.03,0)),ux,uz,(0.15 if frau else 0.158)*sk,0.1*sk,12)],true,0.016)
		lbox(_toon(Color(0.22,0.16,0.11)),T,Vector3(0,1.0,0),Vector3(0.33 if not frau else 0.3,0.045,0.215),0.0)
	# ---- Oberkörper ----
	var sh:float=0.205 if not frau else 0.175
	var lang:bool=o.get("lang",false)
	var R=[]
	var torso=[[0.98,0.158,0.102,0.0],[1.1,0.15,0.1,0.0],[1.24,0.18 if not frau else 0.155,0.118,0.01],[1.34,sh,0.125 if not frau else 0.135,0.02 if frau else 0.012],[1.43,sh-0.005,0.11,0.0],[1.5,0.15,0.085,-0.005],[1.53,0.07,0.06,0.0]]
	if frau:torso[1]=[1.1,0.128,0.092,0.0]
	for q in torso:R.append(ring_ell(X.call(Vector3(0,q[0],q[3])),ux,uz,q[1]*sk,q[2]*sk,14))
	loft(oben,R,true,0.018)
	if o.get("kapuze",false):kugel(oben,X.call(Vector3(0,1.5,-0.1)),Vector3(0.13,0.07,0.07)*sk,1.1)
	if o.get("muster","")=="streifen":
		for k in 3:loft(_toon(Color(0.95,0.95,0.92)),[ring_ell(X.call(Vector3(0,1.15+k*0.1,0.004)),ux,uz,(0.168+k*0.012)*sk,0.115*sk,14),ring_ell(X.call(Vector3(0,1.18+k*0.1,0.006)),ux,uz,(0.172+k*0.012)*sk,0.118*sk,14)],true,0.0,false)
	# ---- Hals & Kopf ----
	rohr(haut,[X.call(Vector3(0,1.48,0)),X.call(Vector3(0,1.6,0.012))],[0.05*sk,0.048*sk],0.014,10,false)
	var kc=Vector3(0,1.69,0.012)
	kugel(haut,X.call(kc),Vector3(0.102,0.122,0.112)*sk,1.07)
	kugel(haut,X.call(kc+Vector3(0,-0.06,0.025)),Vector3(0.082,0.07,0.085)*sk,1.0)
	for sd in [-1,1]:
		kugel(haut,X.call(kc+Vector3(sd*0.1,0.0,-0.005)),Vector3(0.022,0.035,0.022)*sk,1.15)
		var aug=kc+Vector3(sd*0.038,0.012,0.098)
		kugel(M.weiss,X.call(aug),Vector3(0.024,0.021,0.012)*sk,1.0)
		kugel(_toon(o.get("augen",Color(0.3,0.22,0.12))),X.call(aug+Vector3(0,-0.002,0.01)),Vector3(0.013,0.014,0.006)*sk,1.0)
		kugel(M.dunkel,X.call(aug+Vector3(0,-0.002,0.0145)),Vector3(0.007,0.008,0.003)*sk,1.0)
		lbox(_toon(Color(0.1,0.08,0.08)),T,aug+Vector3(0,0.02,0.004),Vector3(0.05,0.008,0.01),0.0)
		lbox(haar,T,aug+Vector3(sd*0.004,0.042,0.004),Vector3(0.048,0.012,0.012),0.0,Basis(Vector3(0,0,1),-sd*0.12))
		if frau:lbox(_toon(Color(0.1,0.08,0.08)),T,aug+Vector3(sd*0.024,0.016,0.0),Vector3(0.012,0.006,0.008),0.0,Basis(Vector3(0,0,1),sd*0.6))
	kugel(haut,X.call(kc+Vector3(0,-0.018,0.112)),Vector3(0.02,0.03,0.024)*sk,1.0)
	var mund=_toon(Color(0.7,0.3,0.28) if not frau else Color(0.82,0.25,0.3))
	lbox(mund,T,kc+Vector3(0,-0.072,0.1),Vector3(0.05,0.012,0.01),0.0)
	if o.get("bart",false):kugel(haar,X.call(kc+Vector3(0,-0.085,0.06)),Vector3(0.075,0.045,0.06)*sk,1.04)
	if o.get("brille",false):
		for sd in [-1,1]:zyl(M.dunkel,X.call(kc+Vector3(sd*0.038,0.012,0.11)),X.call(kc+Vector3(sd*0.038,0.012,0.115)),0.026*sk,1.25)
		lbox(M.dunkel,T,kc+Vector3(0,0.016,0.112),Vector3(0.03,0.006,0.006),0.0)
	# Haare
	match o.get("frisur","kurz"):
		"kurz":
			kugel(haar,X.call(kc+Vector3(0,0.042,-0.02)),Vector3(0.11,0.1,0.112)*sk,1.04)
			lbox(haar,T,kc+Vector3(0,0.09,0.07),Vector3(0.17,0.05,0.07),0.0,Basis(Vector3(1,0,0),-0.35))
		"glatze":
			kugel(haar,X.call(kc+Vector3(0,-0.01,-0.04)),Vector3(0.106,0.07,0.09)*sk,1.02)
		"locken":
			for k in 9:
				var a=TAU*k/9.0
				kugel(haar,X.call(kc+Vector3(cos(a)*0.08,0.06+abs(sin(a))*0.02,-0.03+sin(a)*0.06)),Vector3(0.055,0.055,0.055)*sk,1.05)
			kugel(haar,X.call(kc+Vector3(0,0.06,-0.02)),Vector3(0.11,0.09,0.11)*sk,1.04)
		"lang":
			kugel(haar,X.call(kc+Vector3(0,0.04,-0.018)),Vector3(0.116,0.105,0.118)*sk,1.04)
			loft(haar,[ring_ell(X.call(kc+Vector3(0,0.0,-0.035)),ux,uz,0.11*sk,0.09*sk,12),ring_ell(X.call(kc+Vector3(0,-0.16,-0.05)),ux,uz,0.12*sk,0.075*sk,12),ring_ell(X.call(kc+Vector3(0,-0.3,-0.07)),ux,uz,0.1*sk,0.05*sk,12)],true,0.016)
			lbox(haar,T,kc+Vector3(0.0,0.08,0.075),Vector3(0.16,0.045,0.06),0.0,Basis(Vector3(1,0,0),-0.5))
		"zopf":
			kugel(haar,X.call(kc+Vector3(0,0.04,-0.018)),Vector3(0.114,0.104,0.116)*sk,1.04)
			kugel(haar,X.call(kc+Vector3(0,0.1,-0.09)),Vector3(0.06,0.06,0.06)*sk,1.06)
	if o.has("muetze"):
		var mu=_toon(o.muetze)
		kugel(mu,X.call(kc+Vector3(0,0.06,-0.01)),Vector3(0.118,0.085,0.122)*sk,1.05)
		lbox(mu,T,kc+Vector3(0,0.05,0.13),Vector3(0.17,0.018,0.12),0.015)
	# ---- Arme (mit Ellbogen) ----
	var aermel:String=o.get("aermel","kurz")
	for sd in [-1,1]:
		var b=-sw*sd*0.75
		var S=Vector3(sd*(sh-0.015),1.43,0.0)
		var E=S+Vector3(sd*0.05,-0.28*cos(b),0.28*sin(b)-0.01)
		var flex=0.32+max(0.0,b)*0.6
		var W=E+Vector3(sd*0.005,-0.25*cos(b+flex),0.25*sin(b+flex))
		if o.get("tasche",false) and sd==1:W=E+Vector3(0.02,-0.24,0.04)
		var arm_oben=oben if aermel!="ohne" else haut
		if aermel=="lang":
			rohr(oben,[X.call(S),X.call(E),X.call(W)],[0.068*sk,0.058*sk,0.05*sk],0.016)
		else:
			rohr(arm_oben,[X.call(S),X.call(S.lerp(E,0.5))],[0.07*sk,0.066*sk],0.016,10,false)
			rohr(haut,[X.call(S.lerp(E,0.4)),X.call(E),X.call(W)],[0.05*sk,0.046*sk,0.038*sk],0.015)
		# Hand mit Daumen
		var hd=(W-E).normalized()
		var Hc=W+hd*0.06
		kugel(haut,X.call(Hc),Vector3(0.04,0.06,0.03)*sk,1.1)
		kugel(haut,X.call(Hc+Vector3(0,0.015,0.035)),Vector3(0.016,0.03,0.016)*sk,1.1)
		if o.get("tasche",false) and sd==1:
			var t=_toon(o.get("taschenfarbe",Color(0.55,0.25,0.15)))
			lbox(t,T,Hc+Vector3(0.05,-0.13,0.0),Vector3(0.08,0.22,0.3),0.015)
			lstab(t,T,Hc+Vector3(0.04,0.0,-0.08),Hc+Vector3(0.04,0.0,0.08),0.02)

func _leute():
	var leute=[
		# Hauptfigur vorn
		[Vector3(1.6,0,-8.5),PI*0.92,{"haut":HAUT[1],"oben":Color(0.93,0.42,0.18),"unten":Color(0.2,0.3,0.55),"haar":Color(0.2,0.12,0.07),"frisur":"kurz","geht":true,"ph":0.9}],
		[Vector3(-7.2,KB,-11.0),0.1,{"haut":HAUT[3],"oben":Color(0.18,0.55,0.35),"unten":Color(0.18,0.18,0.2),"haar":Color(0.06,0.05,0.05),"frisur":"locken","geht":true,"ph":2.2,"aermel":"lang","kapuze":true}],
		[Vector3(-7.6,KB,-14.0),PI,{"frau":true,"haut":HAUT[0],"oben":Color(0.9,0.75,0.3),"unten":Color(0.3,0.25,0.5),"haar":Color(0.85,0.6,0.25),"frisur":"lang","rock":true,"schuh":Color(0.6,0.15,0.2),"tasche":true}],
		[Vector3(7.3,KB,-16.0),-PI*0.5,{"haut":HAUT[2],"oben":Color(0.75,0.2,0.25),"unten":Color(0.35,0.3,0.25),"haar":Color(0.1,0.08,0.06),"frisur":"glatze","bart":true,"brille":true,"aermel":"lang"}],
		[Vector3(7.5,KB,-22.0),PI,{"frau":true,"haut":HAUT[4],"oben":Color(0.95,0.95,0.95),"unten":Color(0.2,0.3,0.6),"haar":Color(0.08,0.06,0.05),"frisur":"zopf","geht":true,"ph":0.3}],
		[Vector3(-12.0,KB,7.4),-PI*0.5,{"haut":HAUT[1],"oben":Color(0.2,0.25,0.35),"unten":Color(0.55,0.5,0.4),"haar":Color(0.6,0.6,0.58),"frisur":"kurz","aermel":"lang","muetze":Color(0.25,0.3,0.25),"geht":true,"ph":1.5}],
		[Vector3(-18.0,KB,7.2),PI*0.5,{"haut":HAUT[2],"oben":Color(0.3,0.5,0.8),"unten":Color(0.25,0.25,0.3),"haar":Color(0.12,0.08,0.05),"frisur":"kurz","kurz":true,"muster":"streifen","gr":0.8,"geht":true,"ph":2.8}],
		[Vector3(12.5,KB,7.5),-PI*0.45,{"frau":true,"haut":HAUT[1],"oben":Color(0.85,0.3,0.45),"unten":Color(0.15,0.15,0.2),"haar":Color(0.25,0.12,0.06),"frisur":"lang","tasche":true,"taschenfarbe":Color(0.15,0.15,0.18)}],
		[Vector3(-7.3,KB,22.0),PI,{"haut":HAUT[3],"oben":Color(0.95,0.85,0.2),"unten":Color(0.3,0.35,0.5),"haar":Color(0.05,0.05,0.05),"frisur":"kurz","muetze":Color(0.8,0.15,0.15),"kurz":true}],
		# im Hof
		[Vector3(38.0,0.03,36.0),PI*0.3,{"haut":HAUT[3],"oben":Color(0.85,0.85,0.85),"unten":Color(0.2,0.2,0.25),"haar":Color(0.05,0.05,0.05),"frisur":"locken","aermel":"ohne","kurz":true}],
		[Vector3(40.0,0.03,37.5),PI*1.2,{"haut":HAUT[2],"oben":Color(0.2,0.45,0.25),"unten":Color(0.3,0.3,0.35),"haar":Color(0.08,0.05,0.04),"frisur":"kurz","muetze":Color(0.1,0.1,0.12),"aermel":"lang","kapuze":true}],
		[Vector3(27.5,0.03,27.0),PI*0.75,{"frau":true,"haut":HAUT[0],"oben":Color(0.55,0.75,0.85),"unten":Color(0.75,0.7,0.55),"haar":Color(0.55,0.55,0.55),"frisur":"zopf","rock":true,"aermel":"lang","brille":true,"geht":true,"ph":1.1}],
	]
	for l in leute:
		var p:Vector3=l[0]
		if p.y==0.0 and abs(p.x)<RW and abs(p.z)>RW:p.y=0.0
		_mensch(p,l[1],l[2])

# ================= Holzhäuser (Grove) =================
const HOLZ:=KOPF+"""
uniform vec3 farbe:source_color=vec3(0.75,0.82,0.85);
void fragment(){
	float y=wp.y/0.2; float id=floor(y); float f=fract(y);
	vec3 c=farbe*(0.93+0.1*h21(vec2(id,floor((wp.x+wp.z)/3.0))));
	c*=mix(0.72,1.0,smoothstep(0.0,0.18,f));   // Schattenkante unter jedem Brett
	c*=1.0+0.06*smoothstep(0.85,1.0,f);
	c*=mix(0.9,1.0,vn(wp.xz*0.8+wp.y));
	ALBEDO=c; ROUGHNESS=0.95;
}
"""
const MASCHE:="""
shader_type spatial;
render_mode cull_disabled, diffuse_toon;
uniform vec3 farbe:source_color=vec3(0.62,0.64,0.66);
varying vec3 wp; varying vec3 wn;
void vertex(){ wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; wn=normalize((MODEL_MATRIX*vec4(NORMAL,0.0)).xyz); }
void fragment(){
	vec3 n=abs(wn); vec2 uv=(n.x>n.z)?vec2(wp.z,wp.y):vec2(wp.x,wp.y);
	float d=fract((uv.x+uv.y)/0.09); float e=fract((uv.x-uv.y)/0.09);
	float w=min(min(d,1.0-d),min(e,1.0-e));
	if(w>0.11) discard;
	ALBEDO=farbe; ROUGHNESS=0.4; METALLIC=0.5;
}
"""
func _holzreihe(lauf:Vector3,o:Vector3,s0:float,ende:float):
	var vorn=RW+SW;var s=s0+1.5
	var farben=[Color(0.72,0.82,0.86),Color(0.92,0.88,0.75),Color(0.75,0.85,0.7),Color(0.9,0.75,0.65),Color(0.82,0.8,0.88)]
	while s<ende-10.0:
		var w=rng.randf_range(8.0,9.5)
		var mitte=lauf*(s+w*0.5)-o*vorn+Vector3(0,KB,0)
		_holzhaus(mitte,w,o,farben[rng.randi()%farben.size()])
		# Einfahrt neben dem Haus mit Auto
		var e=lauf*(s+w+1.75)-o*(vorn+5.0)
		box(M.hof,e+Vector3(0,0.03,0),Vector3(3.2,0.06,10.0) if abs(lauf.x)<0.5 else Vector3(10.0,0.06,3.2),Basis(),0.0)
		s+=w+3.5

func _holzhaus(front:Vector3,w:float,aussen:Vector3,farbe:Color):
	var oben=Vector3.UP;var rechts=oben.cross(aussen);var b=Basis(rechts,oben,aussen)
	var holz=_shader(HOLZ,{"farbe":farbe})
	var zurueck=4.5;var d=9.0;var H=5.6
	var f=front-aussen*zurueck
	var m=f-aussen*(d*0.5)+Vector3(0,H*0.5+0.5,0)
	# Sockel, Wand, Satteldach (Giebel zur Straße)
	box(M.stein_d,f-aussen*(d*0.5)+Vector3(0,0.25,0),Vector3(w+0.1,0.5,d+0.1),b,0.03)
	box(holz,m,Vector3(w,H,d),b,0.04)
	var dy=f.y+0.5+H;var ue=0.45
	var P=func(x:float,y:float,z:float)->Vector3:return f+rechts*x+Vector3.UP*y+aussen*z
	var dachm=_toon(Color(0.35,0.3,0.32))
	for sd in [-1,1]:
		var a0=P.call(sd*(w*0.5+ue),0.5+H-0.25,ue);var a1=P.call(sd*(w*0.5+ue),0.5+H-0.25,-d-ue)
		var g0=P.call(0,0.5+H+2.6,ue);var g1=P.call(0,0.5+H+2.6,-d-ue)
		hex(dachm,[a0,a1,a1+Vector3(0,-0.15,0),a0+Vector3(0,-0.15,0),g0,g1,g1+Vector3(0,-0.15,0),g0+Vector3(0,-0.15,0)] if false else
			[a0+Vector3(0,-0.18,0),a1+Vector3(0,-0.18,0),g1+Vector3(0,-0.18,0),g0+Vector3(0,-0.18,0),a0,a1,g1,g0],0.03)
	# Giebeldreiecke vorn/hinten
	for z in [0.0,-d]:
		var p0=P.call(-w*0.5,0.5+H,z);var p1=P.call(w*0.5,0.5+H,z);var p2=P.call(0,0.5+H+2.35,z)
		var q=PackedVector3Array([p0,p1,p2])
		var s:SurfaceTool=_st(holz,true)
		var out=aussen if z==0.0 else -aussen
		_tri(s,p0,p1,p2,out);_tri(s,p0,p2,p1,-out)
	box(M.weiss,P.call(0,0.5+H+0.8,0.05),Vector3(0.9,0.9,0.06),b,0.03)
	box(M.glas[2],P.call(0,0.5+H+0.8,0.08),Vector3(0.7,0.7,0.03),b,0.0)
	# Ecklisenen, Traufbretter
	for sd in [-1,1]:
		box(M.weiss,P.call(sd*(w*0.5-0.06),0.5+H*0.5,0.03),Vector3(0.16,H,0.1),b,0.02)
	# Veranda: Holzdeck, Säulen, Dach, Geländer, Stufen
	var vb=w-1.0;var vt=2.2
	box(M.holz,P.call(0,0.62,vt*0.5),Vector3(vb,0.14,vt),b,0.03)
	for k in 4:box(M.holz,P.call(0,0.2+k*0.0,vt+0.2+k*0.0),Vector3(0,0,0),b,0.0)
	for k in 3:box(M.holz,P.call(0,0.12+k*0.17,vt+0.55-k*0.3),Vector3(1.6,0.12,0.32),b,0.02)
	for x in [-vb*0.5+0.12,-0.95,0.95,vb*0.5-0.12]:
		box(M.weiss,P.call(x,0.69+1.35,vt-0.12),Vector3(0.16,2.7,0.16),b,0.02)
	box(M.weiss,P.call(0,3.45,vt-0.12),Vector3(vb+0.2,0.25,0.25),b,0.025)
	box(dachm,P.call(0,3.62,vt*0.5-0.1),Vector3(vb+0.5,0.1,vt+0.6),b*Basis(Vector3(1,0,0),0.12),0.03)
	for sd in [-1,1]:
		var x0=sd*0.95;var x1=sd*(vb*0.5-0.12)
		box(M.weiss,P.call((x0+x1)*0.5,1.55,vt-0.12),Vector3(abs(x1-x0),0.08,0.08),b,0.0)
		var x=min(x0,x1)+0.15
		while x<max(x0,x1):box(M.weiss,P.call(x,1.12,vt-0.12),Vector3(0.05,0.8,0.05),b,0.0);x+=0.16
	# Haustür, Fenster mit Fensterläden
	box(M.dunkel,P.call(0,1.85,0.0),Vector3(1.1,2.25,0.04),b,0.0)
	box(M.tuer[rng.randi()%M.tuer.size()],P.call(0,1.75,0.04),Vector3(0.95,2.1,0.05),b,0.02)
	box(M.glas[2],P.call(0,2.35,0.07),Vector3(0.5,0.6,0.02),b,0.0)
	var st={"ziegel":false,"glas":M.glas[0],"tuer":M.tuer[rng.randi()%M.tuer.size()],"trim":M.weiss,"laeden":true,"fenster":0}
	for x in [-w*0.32,w*0.32]:_fenster(P,b,x,1.45,1.0,1.4,st,0)
	for x in [-w*0.3,0.0,w*0.3]:_fenster(P,b,x,3.75,0.9,1.25,st,1)
	# Schaukelstuhl/Bank auf der Veranda, Blumenkübel
	_bank(P.call(-vb*0.3,0.69,0.8),aussen)
	zyl(_toon(Color(0.7,0.4,0.25)),P.call(vb*0.35,0.69,1.6),P.call(vb*0.35,1.05,1.6),0.22,1.15)
	kugel(M.laub[1],P.call(vb*0.35,1.2,1.6),Vector3(0.3,0.25,0.3),1.06)
	# Vorgarten: Rasen, Weg zur Treppe, Lattenzaun mit Tor
	box(M.gras,P.call(0,0.03,zurueck*0.5+0.0),Vector3(w,0.06,zurueck),b,0.0)
	box(M.hof,P.call(0,0.07,(zurueck+vt+0.6)*0.5),Vector3(1.4,0.06,zurueck-vt-0.6),b,0.0)
	var zaun=M.weiss
	for sd in [-1,1]:
		var x0=sd*0.85;var x1=sd*(w*0.5)
		box(zaun,P.call((x0+x1)*0.5,0.45,zurueck-0.15),Vector3(abs(x1-x0),0.06,0.04),b,0.0)
		box(zaun,P.call((x0+x1)*0.5,0.8,zurueck-0.15),Vector3(abs(x1-x0),0.06,0.04),b,0.0)
		var x=min(x0,x1)+0.05
		while x<max(x0,x1):
			box(zaun,P.call(x,0.55,zurueck-0.12),Vector3(0.09,1.0,0.03),b,0.012)
			x+=0.2
	if rng.randf()<0.6:
		for k in 3:kugel(M.laub[k%3],P.call(-w*0.3+k*0.5,0.35,zurueck*0.4),Vector3(0.4,0.35,0.4),1.05)
	# Briefkasten am Zaun
	zyl(M.holz,P.call(w*0.4,0,zurueck-0.1),P.call(w*0.4,1.0,zurueck-0.1),0.04,1.3)
	box(M.metall,P.call(w*0.4,1.08,zurueck-0.1),Vector3(0.22,0.22,0.4),b,0.02)
	# Klimaanlage / Satellitenschüssel an der Seite
	box(M.weiss,P.call(w*0.5+0.25,1.5,-2.0),Vector3(0.45,0.55,0.8),b,0.025)
	if rng.randf()<0.6:
		zyl(M.weiss,P.call(-w*0.5-0.1,4.4,-1.5),P.call(-w*0.5-0.25,4.4,-1.5),0.32,1.08)

# ================= Durchfahrt, Hof, Strommasten =================
var _masche:Material
func _zaun(a:Vector3,e:Vector3,h:float):
	if _masche==null:_masche=_shader(MASCHE,{})
	var d=e-a;var L=d.length();var t=d/L;var n=Vector3.UP.cross(t)
	var b=Basis(t,Vector3.UP,-n)
	var k=0.0
	while k<=L+0.01:
		zyl(M.metall,a+t*k,a+t*k+Vector3(0,h,0),0.035,1.3);k+=2.5
	zyl(M.metall,a+Vector3(0,h,0),e+Vector3(0,h,0),0.025,1.3)
	box(_masche,(a+e)*0.5+Vector3(0,h*0.5,0),Vector3(L,h,0.01),b,0.0)

func _durchfahrt(front:Vector3,o:Vector3,w:float,T:float):
	var rechts=Vector3.UP.cross(o);var b=Basis(rechts,Vector3.UP,o)
	# Bordstein abgesenkt + Asphaltgasse bis in den Hof
	box(M.asphalt,front-o*(T*0.5+0.5)+Vector3(0,0.03,0),Vector3(w+0.3,0.08,T+1.0),b,0.0)
	_zaun(front-o*1.0+rechts*(-w*0.5),front-o*1.0+rechts*(w*0.1),2.0)
	box(M.gelb,front-o*1.0+rechts*(w*0.42)+Vector3(0,0.5,0),Vector3(0.12,1.0,0.12),b,0.02)
	_schrift("KOTTI",front-o*6.0+rechts*(-w*0.5+0.03)+Vector3(0,1.4,0),Basis(Vector3.UP.cross(rechts),Vector3.UP,rechts),0.01,Color(0.95,0.55,0.1),Color(0.2,0.05,0.0))
	kugel(M.lampe,front-o*4.0+rechts*(w*0.5-0.15)+Vector3(0,3.2,0),Vector3(0.12,0.14,0.12),1.08)
	_schrift("EINFAHRT\nFREIHALTEN",front+rechts*(-w*0.5-0.02)+Vector3(0,2.0,-0.0)-o*0.3,Basis(o,Vector3.UP,-rechts),0.0035,Color(0.9,0.1,0.1),Color(1,1,1))

func _hof():
	var a=HOF0;var e=HOF1;var mid=Vector3((a+e)*0.5,0,(a+e)*0.5)
	var hofasph=_shader(ASPHALT,{"farbe":Color(0.36,0.36,0.37)})
	box(hofasph,mid+Vector3(0,0.03,0),Vector3(e-a,0.06,e-a),Basis(),0.0)
	# Ölflecken, Pfützen, Risse
	for k in 14:
		var p=Vector3(rng.randf_range(a+2,e-2),0.065,rng.randf_range(a+2,e-2))
		zyl(_toon(Color(0.22,0.22,0.24)),p,p+Vector3(0,0.004,0),rng.randf_range(0.3,1.0))
	for k in 5:
		var p=Vector3(rng.randf_range(a+3,e-3),0.066,rng.randf_range(a+3,e-3))
		var pf=_toon(Color(0.45,0.55,0.65),0.05);pf.metallic_specular=1.0
		zyl(pf,p,p+Vector3(0,0.004,0),rng.randf_range(0.6,1.4))
	# Garagenzeile an der Rückseite (vor den Hinterhäusern, Tore zum Hof)
	var gz=e-3.2
	for k in 6:
		var x=a+4.0+k*3.4
		var g=Vector3(x,0,gz)
		box(M.putz[4],g+Vector3(0,1.3,0),Vector3(3.4,2.6,6.0),Basis(),0.035)
		box(M.dach,g+Vector3(0,2.65,0.2),Vector3(3.5,0.12,6.5),Basis(),0.03)
		var torf=[Color(0.75,0.75,0.72),Color(0.55,0.6,0.68),Color(0.7,0.55,0.4),Color(0.45,0.5,0.42)][k%4]
		box(_toon(torf),g+Vector3(0,1.05,-3.0),Vector3(2.6,2.1,0.06),Basis(),0.02)
		for q in 7:box(_toon(torf*0.8),g+Vector3(0,0.15+q*0.28,-3.04),Vector3(2.5,0.03,0.02),Basis(),0.0)
	# Graffiti auf der Garagenwand
	_schrift("GROVE",Vector3(a+12.0,1.3,gz-3.06),Basis(Vector3.UP,PI),0.012,Color(0.2,0.75,0.3),Color(0.05,0.1,0.05))
	_schrift("RDB 4 LIFE",Vector3(a+20.5,1.6,gz-3.06),Basis(Vector3.UP,PI),0.008,Color(0.95,0.4,0.8),Color(0.15,0.0,0.1))
	# Müllcontainer mit Säcken, Paletten, altes Sofa
	for k in 3:_container(Vector3(a+1.6,0.06,a+6.0+k*2.4),PI*0.5,[Color(0.18,0.42,0.3),Color(0.2,0.3,0.55),Color(0.55,0.5,0.2)][k])
	for k in 6:kugel(_toon(Color(0.1,0.1,0.11),0.3),Vector3(a+1.4+rng.randf_range(0,1.2),0.35,a+13.5+rng.randf_range(0,1.5)),Vector3(0.38,0.32,0.36)*rng.randf_range(0.8,1.1),1.06)
	for k in 3:
		var p=Vector3(e-2.5,0.1+k*0.15,a+3.0)
		for q in 5:box(M.holz,p+Vector3(-0.5+q*0.25,0,0),Vector3(0.12,0.04,1.2),Basis(),0.01)
		box(M.holz,p+Vector3(0,-0.06,0),Vector3(1.2,0.08,1.2),Basis(),0.012)
	_sofa(Vector3(a+3.5,0.06,a+20.0),PI*0.5)
	# eingezäunter Basketballplatz
	var bp=Vector3(a+14.0,0.07,a+12.0)
	box(_toon(Color(0.55,0.3,0.25)),bp,Vector3(12.0,0.02,9.0),Basis(),0.0)
	for z in [-4.5,4.5]:box(M.weiss,bp+Vector3(0,0.012,z),Vector3(12.0,0.012,0.08),Basis(),0.0)
	for x in [-6.0,6.0]:box(M.weiss,bp+Vector3(x,0.012,0),Vector3(0.08,0.012,9.0),Basis(),0.0)
	box(M.weiss,bp+Vector3(0,0.012,0),Vector3(0.08,0.012,9.0),Basis(),0.0)
	_korb(bp+Vector3(-5.6,0,0),Vector3(1,0,0))
	_zaun(bp+Vector3(-6.5,0,-5.0),bp+Vector3(6.5,0,-5.0),3.0)
	_zaun(bp+Vector3(6.5,0,-5.0),bp+Vector3(6.5,0,5.0),3.0)
	_zaun(bp+Vector3(-6.5,0,-5.0),bp+Vector3(-6.5,0,5.0),3.0)
	# kleiner Garten mit Wäscheleine, trockenem Rasen, Baum
	var gp=Vector3(e-8.0,0.06,a+14.0)
	box(_shader(GRAS,{"farbe":Color(0.55,0.58,0.3)}),gp,Vector3(10.0,0.04,10.0),Basis(),0.0)
	_zaun(gp+Vector3(-5,0,-5),gp+Vector3(5,0,-5),1.2);_zaun(gp+Vector3(-5,0,-5),gp+Vector3(-5,0,3),1.2)
	for x in [-3.5,3.5]:zyl(M.metall,gp+Vector3(x,0,1.0),gp+Vector3(x,2.0,1.0),0.04,1.3)
	zyl(_toon(Color(0.9,0.9,0.9)),gp+Vector3(-3.5,1.95,1.0),gp+Vector3(3.5,1.95,1.0),0.008,1.0)
	var waesche=[Color(0.95,0.3,0.3),Color(0.95,0.95,0.95),Color(0.3,0.5,0.9),Color(0.95,0.85,0.3),Color(0.4,0.8,0.5)]
	for k in 7:box(_toon(waesche[k%5]),gp+Vector3(-3.0+k*0.9,1.6,1.0),Vector3(0.6,0.7 if k%2==0 else 0.5,0.02),Basis(),0.012)
	_baum(gp+Vector3(2.5,0,-2.5))
	# Kinderschaukel
	for x in [-1.2,1.2]:
		lstab(M.metall,Transform3D.IDENTITY,gp+Vector3(x,0,-3.6),gp+Vector3(x*0.85,2.2,-3.0),0.07,0.015)
		lstab(M.metall,Transform3D.IDENTITY,gp+Vector3(x,0,-2.4),gp+Vector3(x*0.85,2.2,-3.0),0.07,0.015)
	zyl(M.metall,gp+Vector3(-1.05,2.2,-3.0),gp+Vector3(1.05,2.2,-3.0),0.05,1.3)
	for x in [-0.25,0.25]:zyl(M.metall,gp+Vector3(x,2.2,-3.0),gp+Vector3(x,0.5,-3.0),0.01,1.0)
	box(_toon(Color(0.85,0.2,0.15)),gp+Vector3(0,0.48,-3.0),Vector3(0.6,0.05,0.25),Basis(),0.012)

func _container(p:Vector3,yaw:float,farbe:Color):
	var b=Basis(Vector3.UP,yaw);var m=_toon(farbe,0.5)
	hex(m,[p+b*Vector3(-0.9,0,-0.6),p+b*Vector3(0.9,0,-0.6),p+b*Vector3(0.9,0,0.6),p+b*Vector3(-0.9,0,0.6),
		p+b*Vector3(-1.0,1.25,-0.75),p+b*Vector3(1.0,1.25,-0.75),p+b*Vector3(1.0,1.15,0.75),p+b*Vector3(-1.0,1.15,0.75)],0.03)
	box(_toon(farbe*0.7),p+b*Vector3(0,1.28,0.0),Vector3(2.05,0.06,1.6),b*Basis(Vector3(1,0,0),-0.06),0.02)
	for x in [-0.85,0.85]:
		zyl(M.reifen,p+b*Vector3(x,0.1,0.5),p+b*Vector3(x,0.0,0.5),0.08,1.2)
	box(M.metall,p+b*Vector3(0,0.7,0.78),Vector3(1.6,0.06,0.06),b,0.0)
func _sofa(p:Vector3,yaw:float):
	var b=Basis(Vector3.UP,yaw);var m=_toon(Color(0.45,0.3,0.5))
	box(m,p+b*Vector3(0,0.25,0),Vector3(2.0,0.4,0.9),b,0.03)
	box(m,p+b*Vector3(0,0.6,-0.35),Vector3(2.0,0.6,0.25),b,0.03)
	for x in [-0.95,0.95]:box(m,p+b*Vector3(x,0.5,0),Vector3(0.2,0.4,0.9),b,0.03)
	for x in [-0.45,0.45]:box(_toon(Color(0.55,0.38,0.6)),p+b*Vector3(x,0.5,0.05),Vector3(0.85,0.12,0.75),b,0.025)
func _korb(p:Vector3,blick:Vector3):
	var b=Basis(Vector3.UP,atan2(blick.x,blick.z))
	zyl(M.metall,p,p+Vector3(0,3.2,0),0.08,1.3)
	lstab(M.metall,Transform3D.IDENTITY,p+Vector3(0,3.0,0),p+blick*0.6+Vector3(0,3.15,0),0.06,0.015)
	box(M.weiss,p+blick*0.65+Vector3(0,3.4,0),Vector3(1.6,1.0,0.05),b,0.03)
	box(M.rot,p+blick*0.68+Vector3(0,3.3,0),Vector3(0.55,0.45,0.02),b,0.0)
	box(M.weiss,p+blick*0.69+Vector3(0,3.3,0),Vector3(0.45,0.35,0.02),b,0.0)
	zyl(_toon(Color(1.0,0.45,0.1)),p+blick*0.95+Vector3(0,3.05,0),p+blick*0.95+Vector3(0,3.08,0),0.24,1.0)

func _rueckseite(fh:Vector3,rh:Vector3,hinten:Vector3,w:float,stock:int,eg:float,oh:float,stil:Dictionary):
	var b=Basis(rh,Vector3.UP,hinten)
	var P=func(x:float,y:float,z:float)->Vector3:return fh+rh*x+Vector3.UP*y+hinten*z
	# Hintertür mit Metalltreppe, Lampe
	var x=w*0.25
	box(M.dunkel,P.call(x,1.6,0.0),Vector3(1.1,2.2,0.04),b,0.0)
	box(M.metall,P.call(x,1.55,0.03),Vector3(0.95,2.05,0.05),b,0.02)
	box(M.metall,P.call(x,0.5,0.7),Vector3(1.4,0.08,1.4),b,0.02)
	for k in 3:box(M.metall,P.call(x+1.1,0.12+k*0.13,0.7),Vector3(0.6,0.04,0.6),b,0.01) if false else box(M.metall,P.call(x+0.0,0.12+k*0.13,1.6+0.3*(2-k)),Vector3(1.0,0.04,0.3),b,0.01)
	box(M.metall,P.call(x+0.7,0.95,0.7),Vector3(0.04,0.9,1.4),b,0.0)
	box(M.metall,P.call(x-0.7,0.95,0.7),Vector3(0.04,0.9,1.4),b,0.0)
	kugel(M.lampe,P.call(x,2.9,0.15),Vector3(0.1,0.12,0.1),1.08)
	# Fallrohr, Klimageräte, Satellitenschüsseln, Feuertreppe
	zyl(M.metall,P.call(w-0.3,0.0,0.12),P.call(w-0.3,eg+(stock-1)*oh,0.12),0.06,1.25)
	for i in range(1,stock):
		if rng.randf()<0.5:box(M.weiss,P.call(rng.randf_range(1.0,w-1.0),eg+(i-1)*oh+0.5,0.3),Vector3(0.7,0.45,0.5),b,0.03)
		if rng.randf()<0.3:
			var s=P.call(rng.randf_range(1.0,w-1.0),eg+(i-1)*oh+2.2,0.35)
			zyl(M.weiss,s,s+hinten*0.12,0.3,1.08)
	if stock>=3 and rng.randf()<0.6:_feuertreppe(P,b,w,eg,oh,stock)

func _strommasten():
	# Holzmasten mit durchhängenden Leitungen entlang der Grove-Straße und über den Hof
	var reihen=[[Vector3(-(RW+0.7),KB,RW+SW+3.0),Vector3(0,0,1),5],[Vector3(HOF0+1.0,0.06,HOF0+1.0),Vector3(1,0,0),3]]
	for r in reihen:
		var p0:Vector3=r[0];var t:Vector3=r[1];var n:int=r[2]
		var vorher=[]
		for k in n:
			var p=p0+t*(k*16.0)
			zyl(M.holz,p,p+Vector3(0,8.0,0),0.13,1.2)
			var q=Vector3.UP.cross(t)
			box(M.holz,p+Vector3(0,7.4,0),Vector3(0.16,0.14,2.2),Basis(t,Vector3.UP,q).orthonormalized(),0.02)
			var punkte=[]
			for sd in [-0.9,-0.3,0.3,0.9]:
				var a=p+q*sd+Vector3(0,7.5,0)
				zyl(M.weiss,a,a+Vector3(0,0.15,0),0.04,1.2)
				punkte.append(a+Vector3(0,0.15,0))
			if k%2==0:zyl(M.metall,p+q*0.5+Vector3(0,6.0,0),p+q*0.5+Vector3(0,6.9,0),0.25,1.1)
			if vorher.size()>0:
				for i in 4:_kabel(vorher[i],punkte[i])
			vorher=punkte
func _kabel(a:Vector3,e:Vector3):
	var n=8;var prev=a
	for k in range(1,n+1):
		var t=float(k)/n
		var p=a.lerp(e,t)-Vector3(0,sin(t*PI)*0.45,0)
		zyl(M.dunkel,prev,p,0.012,1.0);prev=p

# ================= Bilder =================
func _bilder():
	var vp=root.get_viewport()
	vp.msaa_3d=Viewport.MSAA_4X
	var cam=Camera3D.new();cam.fov=58;cam.far=600;welt.add_child(cam);cam.current=true
	var px=-(RW-1.25)
	var views=[
		["01_strasse",Vector3(1.0,2.2,-2.0),Vector3(-1.0,1.4,-20.0),60],
		["02_trabant_vorn",Vector3(px+2.6,1.2,-13.8),Vector3(px,0.75,-17.0),45],
		["03_trabant_seite",Vector3(px+4.6,1.0,-17.6),Vector3(px,0.8,-17.4),42],
		["04_trabant_hinten",Vector3(px+2.4,1.3,-20.6),Vector3(px,0.75,-17.8),45],
		["05_wartburg_taxi",Vector3(px+3.6,1.5,-21.0),Vector3(px,0.8,-28.0),50],
		["06_polizei_rtw",Vector3(px+4.0,1.7,-35.0),Vector3(px,1.1,-44.0),52],
		["07_feuerwehr",Vector3(RW-1.5-5.5,2.0,-38.5),Vector3(RW-1.5,1.6,-32.0),55],
		["08_sportwagen",Vector3(3.5,1.2,-6.5),Vector3(-1.5,0.6,-2.0),45],
		["09_figur_nah",Vector3(1.3,1.55,-12.2),Vector3(1.6,1.1,-8.5),38],
		["10_leute",Vector3(-8.6,1.6,-21.5),Vector3(-7.4,1.1,-12.0),48],
		["11_grove_holzhaeuser",Vector3(-2.5,2.0,24.0),Vector3(-16.0,3.0,40.0),58],
		["12_einfahrt_hof",Vector3(40.0,1.7,10.0),Vector3(40.0,1.8,30.0),62],
		["13_hinterhof",Vector3(25.0,2.2,27.5),Vector3(40.0,1.4,55.0),62],
		["14_hinterhof2",Vector3(56.0,2.0,30.0),Vector3(33.0,1.5,40.0),62],
		["15_luft",Vector3(70.0,45.0,-10.0),Vector3(30.0,0.0,35.0),55],
		["16_figur_frau",Vector3(-5.8,1.5,-16.2),Vector3(-7.6,1.05,-14.0),38],
	]
	var nur=OS.get_cmdline_user_args()
	for v in views:
		if nur.size()>0 and not v[0] in nur:continue
		cam.fov=v[3];cam.position=v[1];cam.look_at(v[2])
		for k in 8:await process_frame
		vp.get_texture().get_image().save_png(OUT+v[0]+".png")
		print("BILD ",v[0])
