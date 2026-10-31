extends SceneTree
# Comic-Musterblock: Kreuzung, eigene Häuser (Ziegel, Putz, Läden), Straßenmöbel, Autos (Trabant, Wartburg,
# Sportwagen), Figuren. Alles aus Code erzeugt, Toon-Licht + schwarze Konturen (Hülle mit Rückseiten).
const OUT:="/home/claude/work/stadt/"
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
	rng.seed=11
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	SPH=SphereMesh.new();SPH.radial_segments=16;SPH.rings=8
	CYL=CylinderMesh.new();CYL.radial_segments=14;CYL.rings=0
	CAP=CapsuleMesh.new();CAP.radial_segments=12;CAP.rings=4
	welt=Node3D.new();root.add_child(welt)
	_materialien()
	_umgebung()
	var t0=Time.get_ticks_msec()
	_stadt()
	print("STADT ",Time.get_ticks_msec()-t0," ms")
	_fertig()
	print("FERTIG ",Time.get_ticks_msec()-t0," ms")
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
vec2 flaeche(){ vec3 n=abs(wn); if(n.y>0.7) return wp.xz; vec2 t=normalize(vec2(-wn.z,wn.x)+vec2(1e-5)); return vec2(dot(wp.xz,t),wp.y); }
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
	M.mauer=_shader(ZIEGEL,{"farbe":Color(0.62,0.6,0.56),"fuge":Color(0.45,0.44,0.42),"bw":0.6,"bh":0.3})
	M.linie=StandardMaterial3D.new();M.linie.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;M.linie.albedo_color=Color(0.07,0.05,0.06)
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
	var k=str(m.get_instance_id())+("h" if eigen else "")+("n" if fest_modus else ("s" if strassen_modus else ""))
	if st.has(k) and not eigen:
		zaehler[k]=zaehler.get(k,0)+1
		if zaehler[k]>5000:
			_mesh_aus(k)
			st.erase(k);zaehler[k]=0
	if not st.has(k):
		var s=SurfaceTool.new();s.begin(Mesh.PRIMITIVE_TRIANGLES);st[k]=s;mats[k]=m
	return st[k]
var zaehler:={}
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
var fest_modus:=false      # Tunnel: unter der Erde, keine Höhenverschiebung
var strassen_modus:=false   # Geometrie folgt nur dem Höhenfeld (Straßen, Autos), nicht den Blockstufen
var hoehen_an:=false
func _mesh_aus(k:String):
	var mi=MeshInstance3D.new();mi.material_override=mats[k];welt.add_child(mi)
	if mats[k]==ink:mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not hoehen_an:
		mi.mesh=st[k].commit();return
	var arr=st[k].commit_to_arrays()
	var V:PackedVector3Array=arr[Mesh.ARRAY_VERTEX]
	if k.ends_with("n"):
		mi.mesh=st[k].commit();return
	var nur_feld=k.ends_with("s")
	for i in V.size():
		var v=V[i]
		# Boden (Gehweg, Hof, Wandfuß) folgt dem Gelände; alles darüber steht auf der Hausplatte (falls auf einem Grundstück)
		v.y+=(FY(v.x,v.z) if (nur_feld or v.y<KB+0.03) else Y_at(v.x,v.z));V[i]=v
	arr[Mesh.ARRAY_VERTEX]=V
	var am=ArrayMesh.new();am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr);mi.mesh=am
func _fertig():
	for k in st.keys():_mesh_aus(k)
	st.clear()
# ---------------- Umgebung ----------------
func _umgebung():
	var we=WorldEnvironment.new();var e=Environment.new();we.environment=e;welt.add_child(we)
	var sky=Sky.new();var sm=ProceduralSkyMaterial.new()
	sm.sky_top_color=Color(0.22,0.5,0.92);sm.sky_horizon_color=Color(0.72,0.86,0.98);sm.ground_horizon_color=Color(0.72,0.86,0.98);sm.ground_bottom_color=Color(0.4,0.45,0.4)
	sm.sun_angle_max=8.0;sky.sky_material=sm;e.sky=sky;e.background_mode=Environment.BG_SKY
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color(0.72,0.78,0.9);e.ambient_light_energy=0.55
	e.tonemap_mode=Environment.TONE_MAPPER_LINEAR;e.tonemap_exposure=1.0
	e.fog_enabled=true;e.fog_light_color=Color(0.75,0.85,0.97);e.fog_density=0.0006;e.fog_aerial_perspective=0.25
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,-35,0);sun.light_color=Color(1.0,0.95,0.86);sun.light_energy=1.15
	RenderingServer.directional_shadow_atlas_set_size(8192,true)
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_enabled=true;sun.directional_shadow_max_distance=90.0;sun.shadow_bias=0.04;sun.shadow_normal_bias=1.0;sun.shadow_blur=0.5
	welt.add_child(sun)
	# Wolken: dicke Comic-Wolken aus Kugeln
	for i in 9:
		var c=Vector3(rng.randf_range(-300,300),rng.randf_range(115,145),rng.randf_range(-300,300))
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
func _fassade(o:Vector3,r:Vector3,a:Vector3,w:float,H:float,stock:int,eg:float,oh:float,stil:Dictionary,laden:bool,vorne:bool,ecken:=[true,true],haupt:=true):
	var b=Basis(r,Vector3.UP,a)
	var P=func(x:float,y:float,z:float)->Vector3:return o+r*x+Vector3.UP*y+a*z
	var trim:Material=stil.trim
	# Sockel
	box(M.stein_d,P.call(w*0.5,0.35,0.05),Vector3(w,0.7,0.12),b,0.03)
	# Ecksteine (Putzbauten): echte 3D-Quader, abwechselnd lang/kurz
	if not stil.ziegel:
		for ei in 2:
			if not ecken[ei]:continue
			var x0=[0.0,w][ei]
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
	if stil.feuer and vorne and stock>=3 and w>=7.0:_feuertreppe(P,b,w,eg,oh,stock)
	# Erdgeschoss
	if laden and w>=2.8:_laden(P,b,w,eg,stil,haupt)
	elif haupt and w>=3.5:_eingang(P,b,w,eg,stil)
	else:
		for k in n:_fenster(P,b,(k+0.5)*w/n,1.0,1.0,1.55,stil,0)

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

func _laden(P:Callable,b:Basis,w:float,eg:float,stil:Dictionary,mit_schild:=true):
	var mk=stil.get("markise",M.markise[rng.randi()%M.markise.size()])
	var schild:Material=mk[0]
	# Pfeiler + große Schaufenster
	var n=max(1,int(w/3.2))
	box(M.dunkel,P.call(w*0.5,1.65,0.0),Vector3(w-0.4,2.5,0.04),b,0.0)
	for k in n+1:
		var x=0.2+k*(w-0.4)/n
		box(stil.trim if not stil.ziegel else M.stein,P.call(x,1.6,0.1),Vector3(0.35,2.6,0.22),b,0.03)
	for k in n:
		var x=0.2+(k+0.5)*(w-0.4)/n;var bw=(w-0.4)/n-0.4
		if k==n/2 and w>6.0 and mit_schild:
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
	var lb=Label3D.new();lb.text=stil.get("laden_name",_laeden[rng.randi()%_laeden.size()]) if mit_schild else "";lb.font_size=96;lb.pixel_size=0.0045
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
	zyl(M.dunkel,bx-ax*0.004,bx+ax*0.004,r+0.045,1.0)
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

# Superellipse-Ring (abgerundetes Rechteck): p=2 Ellipse, p=4..6 eckiger
func ring_s(c:Vector3,u:Vector3,v:Vector3,ru:float,rv:float,p:=4.0,n:=20)->PackedVector3Array:
	var r=PackedVector3Array()
	for k in n:
		var a=TAU*k/n;var ca=cos(a);var sa=sin(a)
		r.append(c+u*(sign(ca)*pow(abs(ca),2.0/p))*ru+v*(sign(sa)*pow(abs(sa),2.0/p))*rv)
	return r
# Seitenleiste, die an den Radläufen unterbrochen wird (deckt nie die Räder ab)
func streifen(m:Material,T:Transform3D,x:float,y:float,d:float,z0:float,z1:float,raeder:Array,r:float,kontur:=0.0):
	var a=max(z0,z1);var e=min(z0,z1)
	var stuecke=[[a,e]]
	if y-d*0.5<r*2.0+0.08:
		for zw in raeder:
			var neu=[]
			for st_ in stuecke:
				var lo=zw-r-0.12;var hi=zw+r+0.12
				if hi<st_[1] or lo>st_[0]:neu.append(st_);continue
				if st_[0]>hi:neu.append([st_[0],hi])
				if lo>st_[1]:neu.append([lo,st_[1]])
			stuecke=neu
	for st_ in stuecke:
		if st_[0]-st_[1]>0.15:lstab(m,T,Vector3(x,y,st_[0]),Vector3(x,y,st_[1]),d,kontur)

# Trabant 601 (Comic): rundliche Wanne, Kotflügel mit aufgesetzten Rundscheinwerfern, Grill als "Lächeln"
# zwischen den Scheinwerfern, Nebelleuchten, Chromstoßstange mit schwarzen Gummihörnern, kleine Heckflossen,
# große Fensterflächen mit dünnen Säulen, helles, flaches Dach mit Überstand.
func _trabant(T:Transform3D,farbe:Color,dachfarbe:Color):
	var lack=_lack(farbe);var dach=_lack(dachfarbe)
	var X=T.basis*Vector3(1,0,0);var Y=T.basis*Vector3(0,1,0);var Z=T.basis*Vector3(0,0,1)
	# Wanne: Ringe quer zur Fahrtrichtung (z), abgerundetes Rechteck
	var secs=[[1.79,0.53,0.50,0.15,3.0],[1.74,0.55,0.66,0.21,3.5],[1.58,0.57,0.74,0.25,4.0],[1.2,0.58,0.755,0.27,4.5],[0.0,0.585,0.758,0.275,4.5],
		[-1.2,0.59,0.758,0.275,4.5],[-1.58,0.60,0.745,0.265,4.0],[-1.74,0.62,0.68,0.225,3.5],[-1.79,0.63,0.54,0.17,3.0]]
	var R=[]
	for q in secs:R.append(ring_s(T*Vector3(0,q[1],q[0]),X,Y,q[2],q[3],q[4],22))
	loft(lack,R,true,0.03)
	# Kotflügel vorn: Wölbungen, auf denen die Scheinwerfer sitzen
	for sd in [-1,1]:
		var K=[]
		for q in [[1.82,0.13,0.11],[1.70,0.19,0.15],[1.35,0.2,0.16],[1.0,0.17,0.12],[0.75,0.08,0.05]]:
			K.append(ring_s(T*Vector3(sd*0.55,0.70,q[0]),X,Y,q[1],q[2],2.6,16))
		loft(lack,K,true,0.025)
		# Rundscheinwerfer mit Chromring
		var hp=T*Vector3(sd*0.55,0.70,1.80)
		zyl(M.chrom,hp-Z*0.03,hp+Z*0.045,0.118,1.1)
		zyl(M.lampe,hp+Z*0.045,hp+Z*0.06,0.095,1.0)
		kugel(M.weiss,hp+Z*0.062+X*0.03+Y*0.035,Vector3(0.026,0.02,0.006),1.0)
		# Blinker außen, Nebelleuchte unten
		kugel(_toon(Color(1.0,0.55,0.1)),T*Vector3(sd*0.70,0.50,1.73),Vector3(0.05,0.035,0.035),1.15)
		var nb=T*Vector3(sd*0.40,0.43,1.80)
		zyl(M.chrom,nb-Z*0.02,nb+Z*0.03,0.06,1.12)
		zyl(M.lampe,nb+Z*0.03,nb+Z*0.04,0.048,1.0)
	# Grill-"Lächeln": dunkle, gerundete Öffnung mit Chromrahmen und Gitter, Emblem darüber
	var gc=T*Vector3(0,0.56,1.792)
	loft(M.chrom,[ring_s(gc-Z*0.02,X,Y,0.42,0.105,5.0,20),ring_s(gc+Z*0.015,X,Y,0.42,0.105,5.0,20)],false,0.018)
	loft(M.dunkel,[ring_s(gc+Z*0.012,X,Y,0.38,0.08,5.0,20),ring_s(gc+Z*0.02,X,Y,0.38,0.08,5.0,20)],false,0.0)
	for k in 5:lbox(M.chrom,T,Vector3(0,0.505+k*0.028,1.814),Vector3(0.72,0.012,0.01))
	for k in 9:lbox(M.chrom,T,Vector3(-0.32+k*0.08,0.56,1.815),Vector3(0.008,0.15,0.008))
	zyl(M.chrom,T*Vector3(0,0.76,1.66),T*Vector3(0,0.785,1.7),0.04,1.15)
	# Stoßstangen: Chrom mit schwarzen Gummihörnern
	for z in [1.83,-1.83]:
		var sz=sign(z)
		loft(M.chrom,[ring_s(T*Vector3(0,0.37,z-sz*0.07),X,Y,0.79,0.045,4.0,16),ring_s(T*Vector3(0,0.37,z),X,Y,0.77,0.045,4.0,16)],true,0.018)
		for sd in [-1,1]:
			lbox(M.dunkel,T,Vector3(sd*0.62,0.37,z+sz*0.005),Vector3(0.1,0.13,0.1),0.018)
			lbox(M.dunkel,T,Vector3(sd*0.78,0.37,z-sz*0.09),Vector3(0.06,0.11,0.18),0.015)
	lbox(M.weiss,T,Vector3(0,0.27,1.82),Vector3(0.46,0.1,0.01),0.008)
	_schrift("RDB-601",T*Vector3(0,0.27,1.828),T.basis.orthonormalized(),0.0013,Color(0.1,0.1,0.12))
	# Kabine: Glas als gerundeter Kegelstumpf (Ringe übereinander)
	if _glas_auto==null:_glas_auto=_shader(GLAS,{"farbe":Color(0.2,0.33,0.43)})
	var G=[ring_s(T*Vector3(0,0.855,-0.30),X,Z,0.715,1.10,6.0,24),ring_s(T*Vector3(0,1.12,-0.33),X,Z,0.68,0.87,6.0,24),ring_s(T*Vector3(0,1.39,-0.36),X,Z,0.635,0.60,6.0,24)]
	loft(_glas_auto,G,true,0.02,false)
	# Dach: hell, flach, mit Überstand und Alu-Rand
	loft(dach,[ring_s(T*Vector3(0,1.385,-0.36),X,Z,0.665,0.64,6.0,24),ring_s(T*Vector3(0,1.44,-0.36),X,Z,0.67,0.65,6.0,24),ring_s(T*Vector3(0,1.47,-0.36),X,Z,0.62,0.6,5.0,24)],true,0.025)
	loft(M.chrom,[ring_s(T*Vector3(0,1.375,-0.36),X,Z,0.672,0.652,6.0,24),ring_s(T*Vector3(0,1.392,-0.36),X,Z,0.672,0.652,6.0,24)],false,0.0,false)
	# Säulen: A (schräg, dünn), B (senkrecht), C (breit, mit Lüftungsgitter)
	for sd in [-1,1]:
		lstab(lack,T,Vector3(sd*0.70,0.87,0.78),Vector3(sd*0.625,1.38,0.22),0.05,0.012)
		lstab(lack,T,Vector3(sd*0.708,0.87,-0.40),Vector3(sd*0.655,1.38,-0.34),0.06,0.012)
		hex(lack,[T*Vector3(sd*0.69,0.86,-1.12),T*Vector3(sd*0.72,0.86,-1.12),T*Vector3(sd*0.72,0.86,-1.38),T*Vector3(sd*0.69,0.86,-1.38),
			T*Vector3(sd*0.61,1.38,-0.80),T*Vector3(sd*0.645,1.38,-0.80),T*Vector3(sd*0.645,1.38,-0.95),T*Vector3(sd*0.61,1.38,-0.95)],0.018)
		for k in 3:lbox(M.dunkel,T,Vector3(sd*0.705,1.0+k*0.05,-1.08+k*0.05),Vector3(0.01,0.018,0.12))
		# Fensterunterkante (Gummi), Türfugen, Griff, Spiegel
		lstab(M.dunkel,T,Vector3(sd*0.725,0.87,0.80),Vector3(sd*0.725,0.87,-1.40),0.025)
		lstab(M.dunkel,T,Vector3(sd*0.758,0.36,0.80),Vector3(sd*0.758,0.85,0.80),0.014)
		lstab(M.dunkel,T,Vector3(sd*0.758,0.36,-0.42),Vector3(sd*0.745,0.85,-0.42),0.014)
		lbox(M.chrom,T,Vector3(sd*0.765,0.78,-0.28),Vector3(0.025,0.035,0.13),0.01)
		kugel(lack,T*Vector3(sd*0.83,0.98,0.62),Vector3(0.07,0.045,0.03),1.12)
		lstab(M.dunkel,T,Vector3(sd*0.74,0.93,0.66),Vector3(sd*0.80,0.98,0.62),0.02)
		# Zierlinie (Sicke) an der Flanke über den Radläufen
		lstab(M.chrom,T,Vector3(sd*0.759,0.74,1.6),Vector3(sd*0.759,0.74,0.82),0.018)
		# Heckflossen
		hex(lack,[T*Vector3(sd*0.66,0.85,-0.75),T*Vector3(sd*0.735,0.85,-0.75),T*Vector3(sd*0.735,0.85,-1.77),T*Vector3(sd*0.66,0.85,-1.77),
			T*Vector3(sd*0.69,0.855,-0.80),T*Vector3(sd*0.73,0.855,-0.80),T*Vector3(sd*0.72,0.895,-1.76),T*Vector3(sd*0.68,0.89,-1.76)],0.015)
		# Heckleuchten: hängend, rot/orange
		var hl=Vector3(sd*0.58,0.68,-1.80)
		lbox(M.rot_l,T,hl,Vector3(0.2,0.16,0.035),0.014,Basis(Vector3(0,0,1),sd*0.22))
		lbox(_toon(Color(1.0,0.55,0.1)),T,hl+Vector3(sd*0.02,0.12,0),Vector3(0.18,0.07,0.035),0.012,Basis(Vector3(0,0,1),sd*0.22))
	# Heckscheibenrahmen, Kofferraumgriff, Kennzeichen, Auspuff
	lbox(M.chrom,T,Vector3(0,0.74,-1.795),Vector3(0.22,0.035,0.02),0.0)
	lbox(M.weiss,T,Vector3(0,0.5,-1.795),Vector3(0.44,0.11,0.01),0.008)
	_schrift("RDB-601",T*Vector3(0,0.5,-1.802),T.basis.orthonormalized()*Basis(Vector3.UP,PI),0.0013,Color(0.1,0.1,0.12))
	zyl(M.metall,T*Vector3(0.45,0.25,-1.7),T*Vector3(0.45,0.25,-1.9),0.035,1.2)
	# Räder: kleine 13-Zöller mit großer Chromkappe
	for sx in [-1,1]:
		for sz in [1.02,-1.02]:_rad(T,Vector3(sx*0.69,0.29,sz),0.29,0.16,sx,"stahl",lack,0.70)
	box(M.dunkel,T*Vector3(0,0.006,0),Vector3(1.45,0.004,3.4),T.basis,0.0)

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
		streifen(M.chrom,T,sd*0.825,0.64,0.02,1.95,-1.95,[1.3,-1.25],0.3,0.0)
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
		streifen(M.stein_d,T,sd*0.875,0.47,0.1,2.2,-2.2,[1.4,-1.42],0.31,0.01)
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
		streifen(blau,T,sd*0.885,0.66,0.2,2.15,-2.2,[1.42,-1.35],0.32,0.012)
		streifen(M.weiss,T,sd*0.888,0.53,0.03,2.15,-2.2,[1.42,-1.35],0.32,0.0)
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
		streifen(weissm,T,sd*1.252,0.95,0.14,3.6,-3.7,[2.65,-1.95],0.52,0.0)
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
	_schrift("FEUERWEHR",T*Vector3(0,2.68,3.765),T.basis.orthonormalized(),0.0028,Color(1,1,1))
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

# ================= Organische Stadt =================
# Straßen sind Kurvenzüge. Blöcke = Stadtfläche minus Straßenbänder (nichts kann je auf einer Straße stehen).
# Jeder Block: massive Gehwegplatte, Bebauungsring (Parzellen entlang der Bordkante, Fronten exakt an der
# Gehweg-Hinterkante, Eckhäuser über die Ecke), Hof innen. Autobahn als Hochstraße mit Rampen und Schleife.
const SWB:=3.5        # Gehwegbreite
const TIEFE_B:=13.0   # Bebauungstiefe
const H_AB:=10.0      # Höhe der Autobahn
var R:=[]             # Straßen {n,P,S,w,typ,closed,aussen}
var JN:=[]            # Kreuzungen {p,r,a,b}
var RAMPEN:=[]
var TUN:={}        # {P,S,H,w}
var HW:={}            # Autobahn
var RING_POLY:PackedVector2Array
var STADT_STUECKE:=[]
var AUSSEN_STUECKE:=[]
var SHOW:={}
var SPITZ:={}
var _raster:={}

func _cr(p0:Vector2,p1:Vector2,p2:Vector2,p3:Vector2,t:float)->Vector2:
	var t2=t*t;var t3=t2*t
	return 0.5*((2.0*p1)+(p2-p0)*t+(2.0*p0-5.0*p1+4.0*p2-p3)*t2+(3.0*p1-p0-3.0*p2+p3)*t3)
func _kurve(pts:Array,schritt:=2.5)->PackedVector2Array:
	var out=PackedVector2Array();var n=pts.size()
	if n==2:
		var k=max(1,int(pts[0].distance_to(pts[1])/schritt))
		for i in k+1:out.append(pts[0].lerp(pts[1],float(i)/k))
		return out
	for i in n-1:
		var p0=pts[max(i-1,0)];var p1=pts[i];var p2=pts[i+1];var p3=pts[min(i+2,n-1)]
		var k=max(2,int(p1.distance_to(p2)/schritt))
		for j in k:out.append(_cr(p0,p1,p2,p3,float(j)/k))
	out.append(pts[n-1]);return out
func _laengen(P:PackedVector2Array)->PackedFloat32Array:
	var S=PackedFloat32Array();S.append(0.0)
	for i in range(1,P.size()):S.append(S[i-1]+P[i].distance_to(P[i-1]))
	return S
func _bei_s(P:PackedVector2Array,S:PackedFloat32Array,s:float)->Array:
	s=clamp(s,0.0,S[S.size()-1])
	var i=S.bsearch(s)
	i=clamp(i,1,P.size()-1)
	var a=P[i-1];var b=P[i];var L=max(S[i]-S[i-1],1e-4)
	var t=(b-a)/L
	return [a+t*(s-S[i-1]),t.normalized()]
func _s_von(P:PackedVector2Array,S:PackedFloat32Array,p:Vector2)->float:
	var bd=INF;var bs=0.0
	for i in P.size()-1:
		var q=Geometry2D.get_closest_point_to_segment(p,P[i],P[i+1]);var d=q.distance_to(p)
		if d<bd:bd=d;bs=S[i]+P[i].distance_to(q)
	return bs
func _strasse(n:String,P:PackedVector2Array,w:float,typ:String,closed:=false,aussen:=false):
	var r={"n":n,"P":P,"S":_laengen(P),"w":w,"typ":typ,"closed":closed,"aussen":aussen}
	R.append(r)
	for i in P.size():
		var k=Vector2i(floor(P[i].x/20.0),floor(P[i].y/20.0))
		if not _raster.has(k):_raster[k]=[]
		_raster[k].append([P[i],r])
	return r
func _naechste(p:Vector2,max_d:=40.0)->Array:
	var bd=INF;var br=null
	var k0=Vector2i(floor(p.x/20.0),floor(p.y/20.0));var n=int(ceil(max_d/20.0))
	for dz in range(-n,n+1):
		for dx in range(-n,n+1):
			for e in _raster.get(k0+Vector2i(dx,dz),[]):
				var d=e[0].distance_to(p)
				if d<bd:bd=d;br=e[1]
	return [br,bd]
func _rn(t:Vector2)->Vector2:return Vector2(-t.y,t.x)   # rechte Seite (Fahrtrichtung t)
func _flaeche2(p:PackedVector2Array)->float:
	var a=0.0
	for i in p.size():a+=p[i].x*p[(i+1)%p.size()].y-p[(i+1)%p.size()].x*p[i].y
	return a*0.5
func _groesstes(polys:Array)->PackedVector2Array:
	var best=PackedVector2Array();var ba=0.0
	for q in polys:
		if Geometry2D.is_polygon_clockwise(q):continue
		var a=abs(_flaeche2(q))
		if a>ba:ba=a;best=q
	return best
func _vereinf(p:PackedVector2Array)->PackedVector2Array:
	var q=Array(p);var ch=true
	while ch and q.size()>3:
		ch=false;var i=0
		while i<q.size() and q.size()>3:
			var n=q.size();var a=q[(i-1+n)%n];var b=q[i];var c=q[(i+1)%n]
			if b.distance_to(a)<0.7 or Geometry2D.get_closest_point_to_segment(b,a,c).distance_to(b)<0.14:q.remove_at(i);ch=true
			else:i+=1
	return PackedVector2Array(q)
func _rundrechteck(a:Vector2,b:Vector2,r:float)->PackedVector2Array:
	var c=[Vector2(b.x-r,a.y+r),Vector2(b.x-r,b.y-r),Vector2(a.x+r,b.y-r),Vector2(a.x+r,a.y+r)]
	var out=PackedVector2Array()
	for i in 4:
		var w0=-PI*0.5+PI*0.5*i
		for k in 9:out.append(c[i]+Vector2(cos(w0+PI*0.5*k/8.0),sin(w0+PI*0.5*k/8.0))*r)
		# gerade Strecke bis zur nächsten Ecke in 3-m-Schritten
		var e=out[out.size()-1];var nx=c[(i+1)%4]+Vector2(cos(w0+PI*0.5),sin(w0+PI*0.5))*r
		var k2=int(e.distance_to(nx)/3.0)
		for j in range(1,k2):out.append(e.lerp(nx,float(j)/k2))
	return out
# Fläche als Platte extrudieren (y0..y1), Deckel mit Material oben, Seiten mit Material seite
func _platte(poly:PackedVector2Array,y0:float,y1:float,oben:Material,seite:Material):
	var idx=Geometry2D.triangulate_polygon(poly)
	if idx.is_empty():return
	var so=_st(oben,true)
	for i in range(0,idx.size(),3):
		_tri(so,Vector3(poly[idx[i]].x,y1,poly[idx[i]].y),Vector3(poly[idx[i+1]].x,y1,poly[idx[i+1]].y),Vector3(poly[idx[i+2]].x,y1,poly[idx[i+2]].y),Vector3.UP)
	var ss=_st(seite,true);var sg=sign(_flaeche2(poly))
	for i in poly.size():
		var p=poly[i];var q=poly[(i+1)%poly.size()];var t=(q-p).normalized();var n=Vector2(t.y,-t.x)*sg
		var A=Vector3(p.x,y0,p.y);var B=Vector3(q.x,y0,q.y);var C=Vector3(q.x,y1,q.y);var D=Vector3(p.x,y1,p.y)
		var o=Vector3(n.x,0,n.y);_tri(ss,A,B,C,o);_tri(ss,A,C,D,o)

func _stadt():
	hoehen_an=true
	# ---------- Straßennetz ----------
	var ring=_rundrechteck(Vector2(-195,-165),Vector2(195,165),30.0)
	RING_POLY=ring
	var rp=PackedVector2Array(ring);rp.append(ring[0])
	_strasse("ring",rp,5.5,"strasse",true)
	_strasse("allee",_kurve([Vector2(-201,-20),Vector2(-120,-38),Vector2(-40,-12),Vector2(40,-22),Vector2(120,12),Vector2(201,8)]),7.0,"allee")
	_strasse("ns1",_kurve([Vector2(-60,-171),Vector2(-70,-100),Vector2(-45,-20),Vector2(-62,60),Vector2(-40,171)]),5.0,"strasse")
	_strasse("ns2",_kurve([Vector2(80,-171),Vector2(65,-90),Vector2(92,0),Vector2(70,90),Vector2(84,171)]),5.0,"strasse")
	_strasse("ew2",_kurve([Vector2(-201,95),Vector2(-120,80),Vector2(-20,105),Vector2(80,88),Vector2(201,100)]),5.0,"strasse")
	_strasse("diag",_kurve([Vector2(-158,93),Vector2(-4,-26)]),3.6,"einbahn")
	_strasse("spitz",_kurve([Vector2(116,-171),Vector2(150,-100),Vector2(201,-40)]),4.5,"strasse")
	_strasse("bogen",_kurve([Vector2(-201,40),Vector2(-160,47),Vector2(-128,22),Vector2(-119,-42)]),4.5,"strasse")
	_strasse("gasse1",_kurve([Vector2(-128,-170),Vector2(-127,-40)]),2.2,"gasse")
	_strasse("gasse2",_kurve([Vector2(15,-24),Vector2(18,101)]),2.2,"gasse")
	_strasse("gasse3",_kurve([Vector2(140,4),Vector2(147,101)]),2.2,"gasse")
	_strasse("land",_kurve([Vector2(196,8),Vector2(260,10),Vector2(330,12),Vector2(460,12)]),6.0,"land",false,true)
	_strasse("allee_west",_kurve([Vector2(-201,-20),Vector2(-250,-23),Vector2(-300,-20)]),5.5,"land",false,true)
	_strasse("westring",_kurve([Vector2(-300,-298),Vector2(-306,-200),Vector2(-300,-110),Vector2(-300,-20),Vector2(-304,60),Vector2(-300,110),Vector2(-306,200),Vector2(-300,298)]),6.0,"land",false,true)
	# langer Tunnel: U-Bogen unter der Westhälfte der Stadt, Portale am Westring
	var tp=_kurve([Vector2(-294,-110),Vector2(-262,-110),Vector2(-210,-104),Vector2(-150,-88),Vector2(-80,-55),Vector2(-38,5),Vector2(-62,70),Vector2(-140,104),Vector2(-210,112),Vector2(-262,110),Vector2(-294,110)],2.5)
	var ts=_laengen(tp);var tl=ts[ts.size()-1];var th=PackedFloat32Array()
	for i in tp.size():th.append(-8.0*smoothstep(4.0,70.0,ts[i])*smoothstep(4.0,70.0,tl-ts[i]))
	TUN={"P":tp,"S":ts,"H":th}
	for teil in [[0.0,46.0],[tl-46.0,tl]]:
		var pp=PackedVector2Array()
		for i in tp.size():
			if ts[i]>=teil[0] and ts[i]<=teil[1]:pp.append(tp[i])
		_strasse("tunnelrampe",pp,5.0,"tunnelrampe",false,true)
	# Autobahn (Hochstraße, U-Form um die Stadt)
	var hp=_kurve([Vector2(-460,-238),Vector2(-150,-238),Vector2(100,-236),Vector2(215,-222),Vector2(262,-165),Vector2(272,-60),Vector2(272,80),Vector2(262,170),Vector2(215,226),Vector2(100,238),Vector2(-150,240),Vector2(-460,242)],3.0)
	HW={"P":hp,"S":_laengen(hp),"w":9.0}
	# Rampen: Straßenteil (Kontrollpunkte ab Straße) + Einfädelstreifen parallel zur Autobahn (aus der Autobahnlinie berechnet)
	var kreis=[]
	for k in range(0,19):
		var a=deg_to_rad(-90.0+k*15.0);kreis.append(Vector2(307.5,38.0)+Vector2(cos(a),sin(a))*22.0)
	var rdefs=[
		# [Name, Kontrollpunkte ab Straße, Referenz Start, Referenz Ende, Seite]
		["Auffahrt Nord",[Vector2(-40,-163),Vector2(-40,-182),Vector2(-32,-202),Vector2(-12,-218)],Vector2(5,-224),Vector2(95,-224),1],
		["Abfahrt Nord",[Vector2(-120,-163),Vector2(-120,-182),Vector2(-128,-202),Vector2(-146,-218)],Vector2(-165,-224),Vector2(-250,-224),1],
		["Abfahrt Süd",[Vector2(0,163),Vector2(0,182),Vector2(10,202),Vector2(32,218)],Vector2(55,225),Vector2(135,222),1],
		["Abfahrt Ost",[Vector2(193,-45),Vector2(214,-45),Vector2(236,-50),Vector2(252,-62)],Vector2(258,-80),Vector2(255,-140),1],
		["Auffahrt Süd",[Vector2(240,13),Vector2(249,15),Vector2(255,22),Vector2(258,32)],Vector2(258,42),Vector2(258,112),1],
		["Schleife",kreis,Vector2(285,28),Vector2(285,-45),-1],
	]
	for d in rdefs:
		var ctrl=Array(d[1])
		var s0=_s_von(HW.P,HW.S,d[2]);var s1=_s_von(HW.P,HW.S,d[3])
		var n=int(abs(s1-s0)/10.0)
		var par0=ctrl.size()
		for i in n+1:
			var b=_bei_s(HW.P,HW.S,lerp(s0,s1,float(i)/n));var rn=_rn(b[1])
			var tt=float(i)/n
			ctrl.append(b[0]+rn*d[4]*lerp(HW.w+4.5-0.4,5.0,smoothstep(0.55,1.0,tt)))
		var P=_kurve(ctrl,2.5);var S=_laengen(P);var L=S[S.size()-1]
		var s_par=_s_von(P,S,ctrl[par0])
		var H=PackedFloat32Array()
		for i in P.size():H.append(H_AB*smoothstep(6.0,max(s_par,12.0),S[i]))
		RAMPEN.append({"P":P,"S":S,"H":H,"w":4.5,"n":d[0],"par":s_par})
		var flach=PackedVector2Array()
		for i in P.size():
			if H[i]<0.45:flach.append(P[i])
		if flach.size()>1:_strasse("rampe_"+d[0],flach,4.5,"rampe",false,true)
	_kreuzungen()
	# ---------- Flächen ----------
	var start=_groesstes(Geometry2D.offset_polygon(ring,-5.5))
	var stuecke=[start]
	for r in R:
		if r.closed or r.aussen:continue
		var baender=Geometry2D.offset_polyline(r.P,r.w,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND)
		var neu=[]
		for pc in stuecke:
			var teile=[pc]
			for band in baender:
				var t2=[]
				for t in teile:
					for x in Geometry2D.clip_polygons(t,band):
						if not Geometry2D.is_polygon_clockwise(x):t2.append(x)
				teile=t2
			neu.append_array(teile)
		stuecke=neu
	STADT_STUECKE=stuecke
	# Asphalt der ganzen Stadtfläche (alles, was kein Block ist, ist Straße)
	var asph=_groesstes(Geometry2D.offset_polygon(ring,5.5))
	# Fahrbahnen als Bänder je Straße (folgen dem Höhenfeld; alles zwischen den Blöcken ist so abgedeckt)
	strassen_modus=true
	for r in R:
		if r.aussen:continue
		for band in Geometry2D.offset_polyline(r.P,r.w+0.05,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND):_band(band)
	strassen_modus=false
	# Außenbereich (Grün) in Quadranten, ohne Ring und Außenstraßen
	var ringaussen=asph
	for q in [[-470,-300,0,0],[0,-300,470,0],[-470,0,0,300],[0,0,470,300]]:
		var rect=PackedVector2Array([Vector2(q[0],q[1]),Vector2(q[2],q[1]),Vector2(q[2],q[3]),Vector2(q[0],q[3])])
		var teile=[]
		for x in Geometry2D.clip_polygons(rect,ringaussen):
			if not Geometry2D.is_polygon_clockwise(x):teile.append(x)
		for r in R:
			if not r.aussen:continue
			for band in Geometry2D.offset_polyline(r.P,r.w,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND):
				var t2=[]
				for t in teile:
					for x in Geometry2D.clip_polygons(t,band):
						if not Geometry2D.is_polygon_clockwise(x):t2.append(x)
				teile=t2
		AUSSEN_STUECKE.append_array(teile)
	for r in R:
		if r.aussen and r.typ!="tunnelrampe":
			for band in Geometry2D.offset_polyline(r.P,r.w,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND):_platte(band,-0.2,0.015,M.asphalt,M.stein_d)
	for pc in AUSSEN_STUECKE:
		_platte(pc,-0.2,KB,M.gras,M.stein)
		_aussen_gehweg(pc)
	# ---------- Blöcke ----------
	var n_haus=0
	for pc in STADT_STUECKE:
		var A=abs(_flaeche2(pc))
		_platte(pc,-1.2,KB,M.pflaster,M.stein)
		_spitze_ecke_merken(pc)
		if A<150:continue
		n_haus+=_block(pc)
	print("HAEUSER ",n_haus," BLOECKE ",STADT_STUECKE.size()," KREUZUNGEN ",JN.size())
	strassen_modus=true
	_markierungen()
	strassen_modus=false
	_ampeln()
	_strassenmoebel()
	strassen_modus=true
	_autobahn()
	_rampen()
	_parken()
	strassen_modus=false
	_tunnel()
	fest_modus=true
	_langtunnel()
	fest_modus=false
	_aussen_baeume()
	_fussgaenger()
	_schaustueck()
	_hoehenraster()

func _bbox(P:PackedVector2Array)->Rect2:
	var r=Rect2(P[0],Vector2.ZERO)
	for v in P:r=r.expand(v)
	return r.grow(1.0)
func _kreuzungen():
	for i in R.size():
		for j in range(i+1,R.size()):
			var a=R[i];var b=R[j]
			if not _bbox(a.P).intersects(_bbox(b.P)):continue
			for p in range(a.P.size()-1):
				for q in range(b.P.size()-1):
					var x=Geometry2D.segment_intersects_segment(a.P[p],a.P[p+1],b.P[q],b.P[q+1])
					if x==null:continue
					var neu=true
					for k in JN:
						if k.p.distance_to(x)<18.0:neu=false
					if neu:JN.append({"p":x,"r":max(a.w,b.w)+SWB+1.0,"a":a,"b":b})
	# Ein-/Ausmündungen ohne echten Schnitt (Endpunkt nahe an anderer Straße)
	for a in R:
		if a.closed:continue
		for e in [a.P[0],a.P[a.P.size()-1]]:
			var nr=null;var nd=INF
			for b in R:
				if b==a:continue
				var d=b.P[0].distance_to(e)
				for i in b.P.size()-1:d=min(d,Geometry2D.get_closest_point_to_segment(e,b.P[i],b.P[i+1]).distance_to(e))
				if d<nd:nd=d;nr=b
			if nr and nd<nr.w+2.0:
				var neu=true
				for k in JN:
					if k.p.distance_to(e)<18.0:neu=false
				if neu:JN.append({"p":e,"r":max(a.w,nr.w)+SWB+1.0,"a":a,"b":nr})
func _nah_kreuzung(p:Vector2,extra:=0.0)->bool:
	for k in JN:
		if k.p.distance_to(p)<k.r+extra:return true
	return false

func _aussen_gehweg(pc:PackedVector2Array):
	# Gehweg nur entlang der Kanten, die an eine Straße grenzen
	var sg=sign(_flaeche2(pc))
	for i in pc.size():
		var p=pc[i];var q=pc[(i+1)%pc.size()]
		if p.distance_to(q)<0.3:continue
		var m=(p+q)*0.5;var nr=_naechste(m,30.0)
		if nr[0]==null:continue
		var r=nr[0]
		if r.typ=="rampe" or r.typ=="tunnelrampe":continue
		var t=(q-p).normalized();var inn=Vector2(-t.y,t.x)*sg
		if abs(nr[1]-r.w)>1.6:continue
		var a=p;var b=q;var c=q+inn*SWB;var d=p+inn*SWB
		var s=_st(M.pflaster,true)
		_tri(s,Vector3(a.x,KB+0.004,a.y),Vector3(b.x,KB+0.004,b.y),Vector3(c.x,KB+0.004,c.y),Vector3.UP)
		_tri(s,Vector3(a.x,KB+0.004,a.y),Vector3(c.x,KB+0.004,c.y),Vector3(d.x,KB+0.004,d.y),Vector3.UP)

func _spitze_ecke_merken(pc:PackedVector2Array):
	if abs(_flaeche2(pc))<400:return
	var v=_vereinf(pc);var sg=sign(_flaeche2(v));var n=v.size()
	for i in n:
		var a=v[(i-1+n)%n];var b=v[i];var c=v[(i+1)%n]
		var u=(a-b).normalized();var w=(c-b).normalized()
		if (b-a).cross(c-b)*sg<=0:continue   # nur konvexe Ecken
		var ang=acos(clamp(u.dot(w),-1.0,1.0))
		if ang<SPITZ.get("ang",PI*0.42) and b.distance_to(a)>12 and b.distance_to(c)>12:
			SPITZ={"ang":ang,"p":b,"aus":-(u+w).normalized()}

# ---------- Block: Parzellen entlang der Bordkante ----------
var _block_nr:=0
func _block(pc:PackedVector2Array)->int:
	_block_nr+=1
	var anz=0
	for aussen in Geometry2D.offset_polygon(pc,-SWB,Geometry2D.JOIN_MITER):
		if Geometry2D.is_polygon_clockwise(aussen) or abs(_flaeche2(aussen))<70:continue
		aussen=_vereinf(aussen)
		var innen=[]
		for q in Geometry2D.offset_polygon(aussen,-TIEFE_B,Geometry2D.JOIN_MITER):
			if not Geometry2D.is_polygon_clockwise(q) and abs(_flaeche2(q))>30:innen.append(q)
		var lots=_parzellen(aussen,innen)
		var c=Vector2.ZERO
		for v in aussen:c+=v
		c/=aussen.size()
		var basis=5 if c.length()<95 else (4 if c.length()<160 else 3)
		var alle=lots.map(func(x):return x[0])
		for lot in lots:
			_gebaeude(lot[0],aussen,innen,clampi(basis+rng.randi_range(-1,1)+(1 if lot[1] else 0),2,7),lot[1],alle)
			anz+=1
		for q in innen:
			var Ah=abs(_flaeche2(q))
			if Ah>1500:
				_hof2(q,false)
				var q2=_groesstes(Geometry2D.offset_polygon(q,-7.0,Geometry2D.JOIN_MITER))
				if q2.size()>=3 and abs(_flaeche2(q2))>350:
					q2=_vereinf(q2)
					var in2=[]
					for x in Geometry2D.offset_polygon(q2,-11.0,Geometry2D.JOIN_MITER):
						if not Geometry2D.is_polygon_clockwise(x) and abs(_flaeche2(x))>30:in2.append(x)
					var l2=_parzellen(q2,in2,11.0);var a2=l2.map(func(x):return x[0])
					for lot in l2:
						_gebaeude(lot[0],q2,in2,rng.randi_range(2,4),lot[1],a2);anz+=1
					for x in in2:_hof2(x,true)
					continue
			_hof2(q,true)
	return anz

func _parzellen(P0:PackedVector2Array,innen:Array,tiefe:=TIEFE_B)->Array:
	var sg=sign(_flaeche2(P0));var n=P0.size()
	var S=PackedFloat32Array();S.append(0.0)
	for i in n:S.append(S[i]+P0[i].distance_to(P0[(i+1)%n]))
	var T=S[n]
	# Ecken
	var ecken=[]
	for i in n:
		var a=P0[(i-1+n)%n];var b=P0[i];var c=P0[(i+1)%n]
		var d=rad_to_deg(abs((b-a).angle_to(c-b)))
		if d>28.0:ecken.append(S[i])
	var schnitte=[]
	if ecken.is_empty():
		var k=max(2,int(round(T/10.0)))
		for j in k:schnitte.append(T*j/k)
	else:
		# Ecken bündeln
		var gruppen=[[ecken[0],ecken[0]]]
		for e in range(1,ecken.size()):
			if ecken[e]-gruppen[gruppen.size()-1][1]<9.0:gruppen[gruppen.size()-1][1]=ecken[e]
			else:gruppen.append([ecken[e],ecken[e]])
		if gruppen.size()>1 and gruppen[0][0]+T-gruppen[gruppen.size()-1][1]<9.0:
			gruppen[0][0]=gruppen[gruppen.size()-1][0]-T;gruppen.pop_back()
		var ng=gruppen.size()
		for gi in ng:
			var hi=gruppen[gi][1]+rng.randf_range(5.5,7.5)
			var lo_n=gruppen[(gi+1)%ng][0]-rng.randf_range(5.5,7.5)+(T if gi==ng-1 else 0.0)
			var g=lo_n-hi
			if g<5.0:
				schnitte.append(fposmod((hi+lo_n)*0.5,T));continue
			var k=max(1,int(round(g/rng.randf_range(8.5,12.5))))
			for j in k+1:schnitte.append(fposmod(hi+g*j/k,T))
	schnitte.sort()
	var dedup=[]
	for s in schnitte:
		if dedup.is_empty() or s-dedup[dedup.size()-1]>2.0:dedup.append(s)
	if dedup.size()>1 and dedup[0]+T-dedup[dedup.size()-1]<2.0:dedup.pop_back()
	schnitte=dedup
	if schnitte.size()<2:return [[P0,true]]
	# Polygon mit eingefügten Schnittpunkten
	var Q=[];var schnitt_i=[]
	var si=0
	for i in n:
		Q.append(P0[i])
		while si<schnitte.size() and schnitte[si]<S[i+1]-0.01:
			var s=schnitte[si]
			if s>S[i]+0.3:
				Q.append(P0[i].lerp(P0[(i+1)%n],(s-S[i])/max(S[i+1]-S[i],1e-4)));schnitt_i.append(Q.size()-1)
			else:schnitt_i.append(Q.size()-1)
			si+=1
	var m=Q.size()
	# Einwärts-Gehrung je Punkt
	var innv=[]
	for i in m:
		var a=Q[(i-1+m)%m];var b=Q[i];var c=Q[(i+1)%m]
		var t1=(b-a).normalized();var t2=(c-b).normalized()
		var i1=Vector2(-t1.y,t1.x)*sg;var i2=Vector2(-t2.y,t2.x)*sg
		var mm=(i1+i2).normalized()
		if mm.length()<0.1:mm=i2
		innv.append(mm/max(mm.dot(i2),0.35))
	var lots=[];var vorher=[]
	for k in schnitt_i.size():
		var i0=schnitt_i[k];var i1=schnitt_i[(k+1)%schnitt_i.size()]
		var kette=[];var j=i0
		while true:
			kette.append(j)
			if j==i1:break
			j=(j+1)%m
		if kette.size()<2:continue
		var poly=PackedVector2Array()
		for q in kette:poly.append(Q[q])
		var hat_ecke=false
		for q in range(1,kette.size()-1):
			if rad_to_deg(abs((Q[kette[q]]-Q[kette[q-1]]).angle_to(Q[kette[q+1]]-Q[kette[q]])))>28.0:hat_ecke=true
		for q in range(kette.size()-1,-1,-1):poly.append(Q[kette[q]]+innv[kette[q]]*(tiefe+2.0))
		var lot=_groesstes(Geometry2D.intersect_polygons(poly,P0))
		if lot.size()<3:continue
		for q in innen:
			lot=_groesstes(Geometry2D.clip_polygons(lot,q))
			if lot.size()<3:break
		if lot.size()<3:continue
		for v in vorher:
			lot=_groesstes(Geometry2D.clip_polygons(lot,v))
			if lot.size()<3:break
		if lot.size()<3 or abs(_flaeche2(lot))<18.0:continue
		lot=_vereinf(lot)
		vorher.append(lot);lots.append([lot,hat_ecke])
	return lots

func _auf_rand(p:Vector2,q:Vector2,poly:PackedVector2Array)->bool:
	var m=(p+q)*0.5
	for i in poly.size():
		if Geometry2D.get_closest_point_to_segment(m,poly[i],poly[(i+1)%poly.size()]).distance_to(m)<0.06:return true
	return false

const LADEN_NAMEN:=["BÄCKEREI","KIOSK","DÖNER","FRISEUR","APOTHEKE","BLUMEN","PFANDLEIHE","WASCHSALON","BUCHLADEN","IMBISS","ELEKTRO","CAFÉ","SPÄTI","OPTIKER","FAHRSCHULE","BAR","SPIELHALLE","ZEITUNGEN","METZGEREI","TATTOO"]
func _gebaeude(lot:PackedVector2Array,aussen:PackedVector2Array,innen:Array,stock:int,ecke:bool,alle:=[]):
	_lot_mark(lot)
	var eg=3.7;var oh=3.15;var H=eg+(stock-1)*oh;var y0=KB;var y1=KB+H
	var ziegel=rng.randf()<0.5
	var wand:Material=M.ziegel[rng.randi()%M.ziegel.size()] if ziegel else M.putz[rng.randi()%M.putz.size()]
	var stil={"ziegel":ziegel,"wand":wand,"glas":M.glas[rng.randi()%M.glas.size()],"tuer":M.tuer[rng.randi()%M.tuer.size()],
		"trim":(M.stein if rng.randf()<0.7 else M.weiss),"laeden":(not ziegel and rng.randf()<0.4),"feuer":(ziegel and rng.randf()<0.4),
		"balkon":(not ziegel and rng.randf()<0.5),"fenster":rng.randi_range(0,2),
		"markise":M.markise[rng.randi()%M.markise.size()],"laden_name":LADEN_NAMEN[rng.randi()%LADEN_NAMEN.size()]}
	var laden=ecke or rng.randf()<0.45
	var sg=sign(_flaeche2(lot));var n=lot.size()
	# Wände + Dach
	var sw=_st(wand,true)
	for i in n:
		var p=lot[i];var q=lot[(i+1)%n];var t=(q-p).normalized();var o=Vector3(t.y,0,-t.x)*sg
		var A=Vector3(p.x,y0-0.05,p.y);var B=Vector3(q.x,y0-0.05,q.y);var C=Vector3(q.x,y1,q.y);var D=Vector3(p.x,y1,p.y)
		_tri(sw,A,B,C,o);_tri(sw,A,C,D,o)
	var idx=Geometry2D.triangulate_polygon(lot)
	var sd=_st(M.dach,true)
	for i in range(0,idx.size(),3):
		_tri(sd,Vector3(lot[idx[i]].x,y1,lot[idx[i]].y),Vector3(lot[idx[i+1]].x,y1,lot[idx[i+1]].y),Vector3(lot[idx[i+2]].x,y1,lot[idx[i+2]].y),Vector3.UP)
	# Kanten: Umrisslinien (Comic) und Dachrand
	for i in n:
		var p=lot[i];var q=lot[(i+1)%n];var pr=lot[(i-1+n)%n]
		if rad_to_deg(abs((p-pr).angle_to(q-p)))>15.0:
			box(M.linie,Vector3(p.x,(y0+y1)*0.5,p.y),Vector3(0.07,H,0.07),Basis(),0.0)
		var d=q-p;var L=d.length();if L<0.2:continue
		var t=d/L;var o=Vector2(t.y,-t.x)*sg
		var bb=Basis(Vector3(t.x,0,t.y),Vector3.UP,Vector3(o.x,0,o.y))
		box(M.stein_d,Vector3((p.x+q.x)*0.5-o.x*0.12,y1+0.08,(p.y+q.y)*0.5-o.y*0.12),Vector3(L+0.05,0.16,0.3),bb,0.0)
		box(M.linie,Vector3((p.x+q.x)*0.5,y1+0.17,(p.y+q.y)*0.5),Vector3(L,0.05,0.05),bb,0.0)
	# Fassaden zur Straße
	var fronten=[]
	for i in n:
		var p=lot[i];var q=lot[(i+1)%n]
		if p.distance_to(q)>=1.2 and _auf_rand(p,q,aussen):fronten.append(i)
	var haupt=-1;var hl=0.0
	for i in fronten:
		var L=lot[i].distance_to(lot[(i+1)%n])
		if L>hl:hl=L;haupt=i
	for i in fronten:
		var p=lot[i];var q=lot[(i+1)%n];var t=(q-p).normalized();var o2=Vector2(t.y,-t.x)*sg
		var a3=Vector3(o2.x,0,o2.y);var r3=Vector3.UP.cross(a3)
		var start=p;var ende=q
		if Vector3(q.x-p.x,0,q.y-p.y).dot(r3)<0:start=q;ende=p
		var w=p.distance_to(q)
		# Ecksteine nur an echten Hausecken (nicht zwischen zwei Fassadenstücken einer Kurve)
		var ip=(i-1+n)%n;var inx=(i+1)%n
		var e_prev=not (ip in fronten and rad_to_deg(abs((lot[i]-lot[ip]).angle_to(q-p)))<20.0)
		var e_next=not (inx in fronten and rad_to_deg(abs((q-p).angle_to(lot[(inx+1)%n]-q)))<20.0)
		var ecken=[e_prev,e_next] if start==p else [e_next,e_prev]
		var o=Vector3(start.x,y0,start.y)
		if w<2.6:
			for k in range(1,stock):_fenster_klein(o,r3,a3,w,eg+(k-1)*oh+0.85,stil)
			continue
		_fassade(o,r3,a3,w,H,stock,eg,oh,stil,laden,true,ecken,i==haupt)
	# Rückseiten zum Hof
	for i in n:
		var p=lot[i];var q=lot[(i+1)%n]
		if p.distance_to(q)<4.0:continue
		if i in fronten:continue
		# Brandwand zum Nachbarhaus: keine Fenster
		var mm=(p+q)*0.5;var tt=(q-p).normalized();var aus=Vector2(tt.y,-tt.x)*sg*0.6
		var nachbar=false
		for l2 in alle:
			if l2!=lot and Geometry2D.is_point_in_polygon(mm+aus,l2):nachbar=true
		if nachbar:continue
		var zum_hof=false
		for qq in innen:
			if _auf_rand(p,q,qq):zum_hof=true
		var t=(q-p).normalized();var o2=Vector2(t.y,-t.x)*sg
		var a3=Vector3(o2.x,0,o2.y);var r3=Vector3.UP.cross(a3)
		var start=p if Vector3(q.x-p.x,0,q.y-p.y).dot(r3)>=0 else q
		var w=p.distance_to(q);var o=Vector3(start.x,y0,start.y)
		var b=Basis(r3,Vector3.UP,a3)
		for k in range(1,stock):
			var nf=max(1,int((w-1.0)/2.6))
			for f in nf:
				var x=(f+0.5)*w/nf
				box(M.glas[0],o+r3*x+Vector3(0,eg+(k-1)*oh+1.6,0)+a3*0.02,Vector3(1.0,1.4,0.04),b,0.0)
				box(stil.trim,o+r3*x+Vector3(0,eg+(k-1)*oh+0.8,0)+a3*0.08,Vector3(1.2,0.1,0.16),b,0.0)
		if zum_hof:_rueckseite(o,r3,a3,w,stock,eg,oh,stil)
	# Dachaufbauten
	var c=Vector2.ZERO
	for v in lot:c+=v
	c/=n
	if Geometry2D.is_point_in_polygon(c,lot):
		if ziegel and rng.randf()<0.4 and abs(_flaeche2(lot))>90:_wassertank(Vector3(c.x,y1,c.y))
		elif rng.randf()<0.6:box(M.metall,Vector3(c.x,y1+0.45,c.y),Vector3(1.2,0.9,0.9),Basis(),0.035)
		if rng.randf()<0.5:
			var p2=c+Vector2(rng.randf_range(-2,2),rng.randf_range(-2,2))
			if Geometry2D.is_point_in_polygon(p2,lot):box(wand,Vector3(p2.x,y1+0.8,p2.y),Vector3(0.7,1.6,0.7),Basis(),0.035)

func _fenster_klein(o:Vector3,r:Vector3,a:Vector3,w:float,y:float,stil:Dictionary):
	var b=Basis(r,Vector3.UP,a)
	var fw=min(w-0.5,1.0)
	if fw<0.5:return
	box(M.dunkel,o+r*(w*0.5)+Vector3(0,y+0.8,0)+a*0.005,Vector3(fw+0.08,1.6,0.03),b,0.0)
	box(stil.glas,o+r*(w*0.5)+Vector3(0,y+0.8,0)+a*0.02,Vector3(fw-0.05,1.5,0.03),b,0.0)
	box(M.stein,o+r*(w*0.5)+Vector3(0,y-0.05,0)+a*0.12,Vector3(fw+0.3,0.1,0.24),b,0.02)

var _hofbelag:Material
func _hof2(q:PackedVector2Array,deko:=true):
	if _hofbelag==null:_hofbelag=_shader(ASPHALT,{"farbe":Color(0.42,0.41,0.4)})
	var s=_st(_hofbelag,true)
	var idx=Geometry2D.triangulate_polygon(q)
	for i in range(0,idx.size(),3):
		_tri(s,Vector3(q[idx[i]].x,KB+0.012,q[idx[i]].y),Vector3(q[idx[i+1]].x,KB+0.012,q[idx[i+1]].y),Vector3(q[idx[i+2]].x,KB+0.012,q[idx[i+2]].y),Vector3.UP)
	if not deko:return
	var rand=Geometry2D.offset_polygon(q,-3.0)
	if rand.is_empty():return
	var inner=_groesstes(rand)
	if inner.size()<3:return
	var mn=Vector2(INF,INF);var mx=-mn
	for v in inner:mn=mn.min(v);mx=mx.max(v)
	var A=abs(_flaeche2(inner))
	var belegt=[]
	var platz=func(p:Vector2,r:float)->bool:
		if not Geometry2D.is_point_in_polygon(p,inner):return false
		for b in belegt:
			if b[0].distance_to(p)<b[1]+r:return false
		return true
	for k in int(A/60.0)+2:
		var p=Vector2(rng.randf_range(mn.x,mx.x),rng.randf_range(mn.y,mx.y))
		var art=rng.randi()%6
		var rr=[2.2,1.4,2.6,1.5,1.2,2.4][art]
		if not platz.call(p,rr):continue
		belegt.append([p,rr])
		var y=KB+0.012
		match art:
			0:_baum(Vector3(p.x,y,p.y))
			1:_container(Vector3(p.x,y,p.y),rng.randf()*TAU,[Color(0.18,0.42,0.3),Color(0.2,0.3,0.55),Color(0.55,0.5,0.2)][rng.randi()%3])
			2:
				var tf=Transform3D(Basis(Vector3.UP,rng.randf()*TAU),Vector3(p.x,y,p.y))
				if rng.randf()<0.6:_trabant(tf,_auto_farbe(),Color(0.95,0.94,0.88))
				else:_wartburg(tf,_auto_farbe())
			3:_sofa(Vector3(p.x,y,p.y),rng.randf()*TAU)
			4:
				for j in 4:kugel(_toon(Color(0.1,0.1,0.11),0.3),Vector3(p.x+rng.randf_range(-0.7,0.7),y+0.3,p.y+rng.randf_range(-0.7,0.7)),Vector3(0.36,0.3,0.34),1.06)
			5:
				var bp=Vector3(p.x,y,p.y)
				box(_toon(Color(0.55,0.3,0.25)),bp+Vector3(0,0.012,0),Vector3(4.0,0.02,4.0),Basis(),0.0)
				_korb(bp+Vector3(-1.6,0,0),Vector3(1,0,0))

const AUTOFARBEN:=[Color(0.62,0.7,0.25),Color(0.42,0.66,0.78),Color(0.9,0.85,0.72),Color(0.85,0.55,0.2),Color(0.72,0.25,0.2),Color(0.35,0.42,0.55),Color(0.95,0.8,0.3),Color(0.55,0.62,0.52),Color(0.2,0.25,0.3),Color(0.95,0.95,0.93)]
func _auto_farbe()->Color:return AUTOFARBEN[rng.randi()%AUTOFARBEN.size()]

# ---------- Markierungen, Zebrastreifen, Einbahnpfeile ----------
func _quer(p:Vector2,t:Vector2,lat:float,laengs:float,breite:float,lang:float,y:=0.022,m:Material=null):
	var rn=_rn(t);var c=p+rn*lat+t*laengs
	box(m if m else M.markierung,Vector3(c.x,y,c.y),Vector3(breite,0.012,lang),Basis(Vector3.UP,atan2(t.x,t.y)),0.0)
var ZEBRAS:=[]
func _markierungen():
	for r in R:
		if r.typ in ["gasse","rampe","tunnelrampe"]:continue
		var L=r.S[r.S.size()-1];var s=2.0
		while s<L-1.0:
			var b=_bei_s(r.P,r.S,s);var p:Vector2=b[0];var t:Vector2=b[1]
			if not _nah_kreuzung(p,1.0):
				if r.typ=="allee":
					for sd in [-0.12,0.12]:_quer(p,t,sd,0.0,0.12,2.6)
					if fmod(s,8.0)<2.6:
						for sd in [-1,1]:_quer(p,t,sd*3.5,0.0,0.12,3.0)
				elif r.typ!="einbahn" and fmod(s,6.0)<2.6:_quer(p,t,0.0,0.0,0.14,3.0)
				for sd in [-1,1]:_quer(p,t,sd*(r.w-0.6),0.0,0.12,2.6)
			s+=2.5
		if r.typ=="einbahn":
			s=12.0
			while s<L-8.0:
				var b=_bei_s(r.P,r.S,s);var p:Vector2=b[0];var t:Vector2=b[1]
				if not _nah_kreuzung(p,4.0):
					_quer(p,t,0.0,0.0,0.3,2.4)
					for sd in [-1,1]:
						var tip=p+t*1.6;var d=(t.rotated(sd*2.5));var c=tip+d*0.6
						box(M.markierung,Vector3(c.x,0.022,c.y),Vector3(0.28,0.012,1.3),Basis(Vector3.UP,atan2(d.x,d.y)),0.0)
				s+=24.0
	# Zebrastreifen + Haltelinien an jeder Kreuzung
	for k in JN:
		for paar in [[k.a,k.b],[k.b,k.a]]:
			var r=paar[0];var o=paar[1]
			if r.typ in ["gasse","rampe","tunnelrampe"]:continue
			var s0=_s_von(r.P,r.S,k.p);var L=r.S[r.S.size()-1]
			for dir in [-1,1]:
				var s=s0+dir*(o.w+2.0)
				if s<1.0 or s>L-1.0:continue
				var b=_bei_s(r.P,r.S,s);var p:Vector2=b[0];var t:Vector2=b[1]
				var andere=false
				for k2 in JN:
					if k2!=k and k2.p.distance_to(p)<k2.r+0.5:andere=true
				for zc in ZEBRAS:
					if zc.distance_to(p)<7.0:andere=true
				if andere or o.typ in ["gasse","rampe","tunnelrampe"]:continue
				ZEBRAS.append(p)
				var lat=-r.w+0.7
				while lat<r.w-0.6:
					_quer(p,t,lat,0.0,0.5,3.0,0.023);lat+=1.0
				var b2=_bei_s(r.P,r.S,s+dir*2.6)
				var seite=-dir if r.typ!="einbahn" else 0
				if r.typ=="einbahn":_quer(b2[0],b2[1],0.0,0.0,r.w*2.0-0.6,0.4,0.023)
				else:_quer(b2[0],b2[1],seite*r.w*0.5,0.0,r.w-0.4,0.4,0.023)

func _ampeln():
	for k in JN:
		if k.a.typ in ["gasse","rampe","tunnelrampe"] or k.b.typ in ["gasse","rampe","tunnelrampe"]:continue
		var gruen=true
		for pc in STADT_STUECKE:
			if abs(_flaeche2(pc))<120.0:continue
			var bd=INF;var bv=Vector2.ZERO
			for v in pc:
				var d=v.distance_to(k.p)
				if d<bd:bd=d;bv=v
			if bd>max(k.a.w,k.b.w)+9.0:continue
			var dj=(k.p-bv).normalized()
			var p=bv-dj*0.8
			_ampel(Vector3(p.x,KB,p.y),Vector3(dj.x,0,dj.y),gruen);gruen=not gruen

func _strassenmoebel():
	var schild_gesetzt=false
	for pc in STADT_STUECKE:
		if abs(_flaeche2(pc))<150:continue
		var sg=sign(_flaeche2(pc));var n=pc.size()
		var S=0.0;var naechst=rng.randf_range(3.0,9.0);var k=0
		for i in n:
			var p=pc[i];var q=pc[(i+1)%n];var L=p.distance_to(q)
			while naechst<S+L:
				var x=p.lerp(q,(naechst-S)/max(L,1e-4));var t=(q-p).normalized();var inn=Vector2(-t.y,t.x)*sg
				naechst+=12.0
				if _nah_kreuzung(x,4.0):continue
				var nr=_naechste(x,25.0)
				if nr[0]==null or nr[0].typ=="gasse":continue
				var a=x+inn*0.9;var a3=Vector3(a.x,KB,a.y);var zur=Vector3(-inn.x,0,-inn.y)
				if k%2==0:_laterne(a3,zur)
				else:_baum(a3+Vector3(inn.x,0,inn.y)*0.2)
				var z=rng.randf()
				if z<0.14:_bank(Vector3(x.x+inn.x*(SWB-0.7)+t.x*4.0,KB,x.y+inn.y*(SWB-0.7)+t.y*4.0),zur)
				elif z<0.26:_muell(Vector3(x.x+inn.x*0.6+t.x*3.0,KB,x.y+inn.y*0.6+t.y*3.0))
				elif z<0.34:_hydrant(Vector3(x.x+inn.x*0.55-t.x*3.0,KB,x.y+inn.y*0.55-t.y*3.0))
				if nr[0].typ=="einbahn" and not schild_gesetzt:
					schild_gesetzt=true;_einbahnschild(Vector3(a.x+t.x*2.0,KB,a.y+t.y*2.0),nr[0],zur)
				k+=1
			S+=L

func _einbahnschild(p:Vector3,r,zur:Vector3):
	zyl(M.metall,p,p+Vector3(0,2.6,0),0.045,1.3)
	var t=_bei_s(r.P,r.S,_s_von(r.P,r.S,Vector2(p.x,p.z)))[1]
	var b=Basis(Vector3.UP,atan2(zur.x,zur.z))
	box(_toon(Color(0.12,0.3,0.75)),p+Vector3(0,2.4,0)+zur*0.06,Vector3(0.9,0.32,0.04),b,0.02)
	_schrift("EINBAHN",p+Vector3(0,2.4,0)+zur*0.085,b,0.0018,Color(1,1,1))

# ---------- Autobahn ----------
func _offen(p:Vector2,eigen)->bool:
	# liegt neben dieser Kante (außen) eine andere Hochfahrbahn? Dann keine Leitplanke (Einfädelstreifen)
	for rp in RAMPEN:
		if rp==eigen:continue
		for i in range(0,rp.P.size(),2):
			if rp.H[i]>H_AB-0.6 and rp.P[i].distance_to(p)<rp.w+1.2:return true
	if eigen!=null:
		var s=_s_von(HW.P,HW.S,p)
		if _bei_s(HW.P,HW.S,s)[0].distance_to(p)<HW.w+1.2:return true
	return false
func _deck(P:PackedVector2Array,H:PackedFloat32Array,w:float,dicke:float,mittel:bool,leitplanke:bool,eigen=null):
	var top=_st(M.asphalt,true);var seite=_st(M.stein_d,true);var unten=_st(M.stein_d,true)
	var n=P.size()
	var N=[]
	for i in n:
		var t=(P[min(i+1,n-1)]-P[max(i-1,0)]).normalized();N.append(_rn(t))
	for i in n-1:
		if H[i]<0.03 and H[i+1]<0.03:continue
		var h0=max(H[i],0.03);var h1=max(H[i+1],0.03)
		var a=P[i]-N[i]*w;var b=P[i]+N[i]*w;var c=P[i+1]+N[i+1]*w;var d=P[i+1]-N[i+1]*w
		_tri(top,Vector3(a.x,h0,a.y),Vector3(b.x,h0,b.y),Vector3(c.x,h1,c.y),Vector3.UP);_tri(top,Vector3(a.x,h0,a.y),Vector3(c.x,h1,c.y),Vector3(d.x,h1,d.y),Vector3.UP)
		var u0=max(h0-dicke,0.0) if h0>1.5 else 0.0;var u1=max(h1-dicke,0.0) if h1>1.5 else 0.0
		for sd in [-1,1]:
			var e0=P[i]+N[i]*w*sd;var e1=P[i+1]+N[i+1]*w*sd;var o=Vector3(N[i].x*sd,0,N[i].y*sd)
			_tri(seite,Vector3(e0.x,u0,e0.y),Vector3(e1.x,u1,e1.y),Vector3(e1.x,h1,e1.y),o);_tri(seite,Vector3(e0.x,u0,e0.y),Vector3(e1.x,h1,e1.y),Vector3(e0.x,h0,e0.y),o)
			if leitplanke and (h0>0.7 or h1>0.7) and not (h0>H_AB-0.6 and _offen(P[i]+N[i]*(w+0.8)*sd,eigen)):
				var m0=P[i]+N[i]*(w-0.25)*sd;var m1=P[i+1]+N[i+1]*(w-0.25)*sd;var mm=(m0+m1)*0.5;var dd=m1-m0
				box(M.stein,Vector3(mm.x,(h0+h1)*0.5+0.42,mm.y),Vector3(0.45,0.85,sqrt(dd.length_squared()+(h1-h0)*(h1-h0))+0.05),Basis(Vector3.UP,atan2(dd.x,dd.y))*Basis(Vector3.RIGHT,-atan2(h1-h0,dd.length())),0.0)
				box(M.linie,Vector3(mm.x,(h0+h1)*0.5+0.86,mm.y),Vector3(0.47,0.04,sqrt(dd.length_squared()+(h1-h0)*(h1-h0))+0.05),Basis(Vector3.UP,atan2(dd.x,dd.y))*Basis(Vector3.RIGHT,-atan2(h1-h0,dd.length())),0.0)
		if h0>1.5:
			_tri(unten,Vector3(a.x,u0,a.y),Vector3(b.x,u0,b.y),Vector3(c.x,u1,c.y),Vector3.DOWN);_tri(unten,Vector3(a.x,u0,a.y),Vector3(c.x,u1,c.y),Vector3(d.x,u1,d.y),Vector3.DOWN)
		if mittel:
			var mm=(P[i]+P[i+1])*0.5;var dd=P[i+1]-P[i]
			box(M.stein,Vector3(mm.x,(h0+h1)*0.5+0.42,mm.y),Vector3(0.6,0.85,sqrt(dd.length_squared()+(h1-h0)*(h1-h0))+0.05),Basis(Vector3.UP,atan2(dd.x,dd.y))*Basis(Vector3.RIGHT,-atan2(h1-h0,dd.length())),0.0)
			box(M.linie,Vector3(mm.x,(h0+h1)*0.5+0.86,mm.y),Vector3(0.62,0.04,sqrt(dd.length_squared()+(h1-h0)*(h1-h0))+0.05),Basis(Vector3.UP,atan2(dd.x,dd.y))*Basis(Vector3.RIGHT,-atan2(h1-h0,dd.length())),0.0)

func _ueber_strasse(p:Vector2,extra:float)->bool:
	var nr=_naechste(p,30.0)
	return nr[0]!=null and nr[1]<nr[0].w+extra

func _autobahn():
	var P:PackedVector2Array=HW.P;var S=HW.S;var w=HW.w
	var H=PackedFloat32Array();H.resize(P.size());H.fill(H_AB)
	_deck(P,H,w,1.2,true,true)
	var L=S[S.size()-1];var s=6.0
	# Markierungen
	s=1.0
	while s<L-1.0:
		var b=_bei_s(P,S,s);var p:Vector2=b[0];var t:Vector2=b[1];var rn=_rn(t)
		for sd in [-1,1]:
			for lat in [0.9,w-0.9]:
				var c=p+rn*lat*sd;box(M.markierung,Vector3(c.x,H_AB+0.01,c.y),Vector3(0.15,0.012,2.6),Basis(Vector3.UP,atan2(t.x,t.y)),0.0)
			if fmod(s,12.0)<2.6:
				var c=p+rn*4.9*sd;box(M.markierung,Vector3(c.x,H_AB+0.01,c.y),Vector3(0.15,0.012,4.5),Basis(Vector3.UP,atan2(t.x,t.y)),0.0)
		s+=2.5
	# Pfeiler + Querträger
	s=10.0
	while s<L:
		var b=_bei_s(P,S,s);var p:Vector2=b[0];var t:Vector2=b[1];var rn=_rn(t)
		if not _ueber_strasse(p,3.0):
			for sd in [-1,1]:
				var c=p+rn*4.6*sd
				zyl(M.stein,Vector3(c.x,0,c.y),Vector3(c.x,H_AB-1.6,c.y),0.75,1.05)
			box(M.stein,Vector3(p.x,H_AB-1.95,p.y),Vector3(w*2.0-1.0,0.9,1.6),Basis(Vector3.UP,atan2(t.x,t.y))*Basis(Vector3.UP,PI*0.5),0.04)
		s+=26.0
	# Laternen auf dem Mittelstreifen
	s=20.0
	while s<L:
		var b=_bei_s(P,S,s);var p:Vector2=b[0];var t:Vector2=b[1];var rn=_rn(t)
		var a=Vector3(p.x,H_AB+0.85,p.y)
		zyl(M.metall,a,a+Vector3(0,8.0,0),0.1,1.3)
		for sd in [-1,1]:
			var e=a+Vector3(rn.x*sd*2.2,8.3,rn.y*sd*2.2)
			zyl(M.metall,a+Vector3(0,7.8,0),e,0.06,1.3)
			box(M.lampe,e+Vector3(0,-0.12,0),Vector3(0.5,0.12,0.8),Basis(Vector3.UP,atan2(t.x,t.y)),0.02)
		s+=50.0
	# Schilderbrücken
	for sp in [[Vector2(272,-140),"Radeberg-Ost  →","Dresden  ↑"],[Vector2(0,-237),"Radeberg-Nord  ↘","Görlitz  →"]]:
		var s2=_s_von(P,S,sp[0]);var b=_bei_s(P,S,s2);var p:Vector2=b[0];var t:Vector2=b[1];var rn=_rn(t)
		for sd in [-1,1]:
			var c=p+rn*(w+0.4)*sd;zyl(M.metall,Vector3(c.x,H_AB,c.y),Vector3(c.x,H_AB+7.0,c.y),0.15,1.2)
		var bb=Basis(Vector3.UP,atan2(-t.x,-t.y))
		box(M.metall,Vector3(p.x,H_AB+6.8,p.y),Vector3(w*2.0+1.0,0.3,0.3),bb,0.02)
		for k in 2:
			var c=p+rn*(-4.5+k*9.0)
			var gr=_toon(Color(0.1,0.45,0.25))
			box(gr,Vector3(c.x,H_AB+6.0,c.y)-Vector3(t.x,0,t.y)*0.25,Vector3(7.0,1.8,0.12),bb,0.03)
			_schrift(sp[1+k],Vector3(c.x,H_AB+6.0,c.y)-Vector3(t.x,0,t.y)*0.33,bb,0.006,Color(1,1,1))

func _rampen():
	for rp in RAMPEN:
		_deck(rp.P,rp.H,rp.w,0.9,false,true,rp)
		var L=rp.S[rp.S.size()-1];var s=8.0
		while s<L:
			var i=rp.S.bsearch(s);i=clamp(i,0,rp.P.size()-1)
			var h=rp.H[i];var p=rp.P[i]
			if h>3.2 and not _ueber_strasse(p,2.0):
				zyl(M.stein,Vector3(p.x,0,p.y),Vector3(p.x,h-1.2,p.y),0.6,1.05)
				var t=(rp.P[min(i+1,rp.P.size()-1)]-rp.P[max(i-1,0)]).normalized()
				box(M.stein,Vector3(p.x,h-1.4,p.y),Vector3(rp.w*2.0-0.6,0.6,1.2),Basis(Vector3.UP,atan2(t.x,t.y))*Basis(Vector3.UP,PI*0.5),0.03)
			s+=15.0
		# Fahrbahnränder
		s=1.0
		while s<L-1.0:
			var i=rp.S.bsearch(s);i=clamp(i,1,rp.P.size()-1)
			var t=(rp.P[i]-rp.P[i-1]).normalized();var rn=_rn(t);var h=max(rp.H[i],0.03)
			for sd in [-1,1]:
				var c=rp.P[i]+rn*(rp.w-0.5)*sd;box(M.markierung,Vector3(c.x,h+0.012,c.y),Vector3(0.14,0.012,2.6),Basis(Vector3.UP,atan2(t.x,t.y)),0.0)
			s+=2.5

# ---------- Autos ----------
func _auto_zufall(tf:Transform3D):
	var z=rng.randf()
	if z<0.34:_trabant(tf,_auto_farbe(),Color(0.95,0.94,0.88) if rng.randf()<0.7 else _auto_farbe())
	elif z<0.58:_wartburg(tf,_auto_farbe())
	elif z<0.7:_taxi(tf)
	elif z<0.78:_polizei(tf)
	elif z<0.93:_sport(tf,[Color(0.95,0.18,0.12),Color(0.98,0.75,0.12),Color(0.15,0.15,0.18),Color(0.2,0.5,0.95)][rng.randi()%4])
	else:_trabant(tf,_auto_farbe(),_auto_farbe())
func _parken():
	var ns2=null
	for r in R:
		if r.n=="ns2":ns2=r
	for r in R:
		if not r.typ in ["strasse","allee","einbahn","land"]:continue
		var L=r.S[r.S.size()-1];var s=rng.randf_range(4,10)
		while s<L-4:
			var b=_bei_s(r.P,r.S,s);var p:Vector2=b[0];var t:Vector2=b[1];var rn=_rn(t)
			s+=rng.randf_range(5.8,7.5)
			if _nah_kreuzung(p,9.0):continue
			if r==ns2 and s>180 and s<255:continue
			if r.typ=="land" and p.x>205 and p.x<300:continue
			for sd in [-1,1]:
				if rng.randf()>0.42:continue
				var h=t*(-sd) if r.typ!="einbahn" else t
				var c=p+rn*sd*(r.w-1.15)
				_auto_zufall(Transform3D(Basis(Vector3.UP,atan2(h.x,h.y)),Vector3(c.x,0.015,c.y)))
		# fahrende Autos auf der Fahrspur
		s=rng.randf_range(20,50)
		while s<L-10:
			var b=_bei_s(r.P,r.S,s);var p:Vector2=b[0];var t:Vector2=b[1];var rn=_rn(t)
			s+=rng.randf_range(35,70)
			if _nah_kreuzung(p,10.0):continue
			var sd=1 if rng.randf()<0.5 else -1
			if r.typ=="einbahn":sd=0
			var h=t if sd>=0 else -t
			var c=p+rn*sd*(r.w*0.5-(0.2 if r.typ!="allee" else -0.6))
			_auto_zufall(Transform3D(Basis(Vector3.UP,atan2(h.x,h.y)),Vector3(c.x,0.015,c.y)))
	# Autobahn
	var s=30.0;var L=HW.S[HW.S.size()-1]
	while s<L-30:
		var b=_bei_s(HW.P,HW.S,s);var p:Vector2=b[0];var t:Vector2=b[1];var rn=_rn(t)
		s+=rng.randf_range(25,60)
		var sd=1 if rng.randf()<0.5 else -1
		var c=p+rn*sd*([2.7,7.0][rng.randi()%2])
		var h=t if sd>0 else -t
		_auto_zufall(Transform3D(Basis(Vector3.UP,atan2(h.x,h.y)),Vector3(c.x,H_AB+0.01,c.y)))

func _aussen_baeume():
	for k in 160:
		var p=Vector2(rng.randf_range(-330,420),rng.randf_range(-290,290))
		var ok=false
		for pc in AUSSEN_STUECKE:
			if Geometry2D.is_point_in_polygon(p,pc):ok=true;break
		if not ok:continue
		var nr=_naechste(p,40.0)
		if nr[0]!=null and nr[1]<nr[0].w+SWB+3.0:continue
		var dh=INF
		for i in range(0,HW.P.size()-1,3):dh=min(dh,HW.P[i].distance_to(p))
		if dh<HW.w+4.0:continue
		if p.x>195 and p.x<252 and p.y>-35 and p.y<55:continue
		if p.x>195 and p.x<250 and p.y>-35 and p.y<55:continue
		var drp=INF
		for rp in RAMPEN:
			for i in range(0,rp.P.size(),2):drp=min(drp,rp.P[i].distance_to(p))
		if drp<8.0:continue
		_baum(Vector3(p.x,KB,p.y))

# ---------- Menschen ----------
func _zufall_mensch()->Dictionary:
	var frau=rng.randf()<0.5
	var hc=[Color(0.08,0.06,0.05),Color(0.25,0.14,0.07),Color(0.55,0.35,0.15),Color(0.85,0.65,0.3),Color(0.6,0.6,0.58),Color(0.7,0.25,0.15)]
	var kl=[Color(0.93,0.42,0.18),Color(0.18,0.55,0.35),Color(0.9,0.75,0.3),Color(0.75,0.2,0.25),Color(0.95,0.95,0.95),Color(0.2,0.25,0.35),Color(0.3,0.5,0.8),Color(0.85,0.3,0.45),Color(0.55,0.75,0.85),Color(0.4,0.3,0.55)]
	var ho=[Color(0.2,0.3,0.55),Color(0.18,0.18,0.2),Color(0.35,0.3,0.25),Color(0.55,0.5,0.4),Color(0.25,0.25,0.3),Color(0.3,0.25,0.5)]
	var o={"frau":frau,"haut":HAUT[rng.randi()%HAUT.size()],"oben":kl[rng.randi()%kl.size()],"unten":ho[rng.randi()%ho.size()],
		"haar":hc[rng.randi()%hc.size()],"geht":rng.randf()<0.6,"ph":rng.randf()*TAU,"gr":rng.randf_range(0.93,1.05)}
	o.frisur=(["lang","zopf","locken","kurz"] if frau else ["kurz","glatze","locken","kurz"])[rng.randi()%4]
	if frau and rng.randf()<0.4:o.rock=true
	if not frau and rng.randf()<0.25:o.bart=true
	if rng.randf()<0.2:o.brille=true
	if rng.randf()<0.2:o.muetze=kl[rng.randi()%kl.size()]
	if rng.randf()<0.35:o.aermel="lang"
	if rng.randf()<0.15:o.kurz=true
	if rng.randf()<0.2:o.tasche=true
	if rng.randf()<0.15:o.kapuze=true;o.aermel="lang"
	if rng.randf()<0.1:o.muster="streifen"
	if rng.randf()<0.08:o.gr=0.78
	o.schuh=[Color(0.95,0.95,0.95),Color(0.15,0.13,0.12),Color(0.6,0.15,0.2),Color(0.35,0.25,0.15)][rng.randi()%4]
	return o
func _fussgaenger():
	var n=0
	for versuch in 400:
		if n>=70:break
		var pc=STADT_STUECKE[rng.randi()%STADT_STUECKE.size()]
		if abs(_flaeche2(pc))<300:continue
		var i=rng.randi()%pc.size();var p=pc[i];var q=pc[(i+1)%pc.size()]
		if p.distance_to(q)<1.0:continue
		var x=p.lerp(q,rng.randf());var t=(q-p).normalized();var inn=Vector2(-t.y,t.x)*sign(_flaeche2(pc))
		if _nah_kreuzung(x,0.0):continue
		var a=x+inn*rng.randf_range(1.6,2.8)
		var yaw=atan2(t.x,t.y)+(PI if rng.randf()<0.5 else 0.0)
		_mensch(Vector3(a.x,KB,a.y),yaw,_zufall_mensch());n+=1

# ---------- Schaustück: Autos und Skelett-Figuren für die Nahbilder ----------
func _schaustueck():
	var r=null
	for x in R:
		if x.n=="ns2":r=x
	SHOW.r=r
	var C=func(s:float,lat:float)->Array:
		var b=_bei_s(r.P,r.S,s);var p:Vector2=b[0];var t:Vector2=b[1];var rn=_rn(t)
		return [p+rn*lat,t,rn]
	SHOW.C=C
	var lat=r.w-1.15
	var liste=[[196.0,"trabant_gruen"],[201.0,"trabant_blau"],[207.2,"wartburg"],[213.6,"taxi"],[220.2,"polizei"],[227.4,"rtw"],[237.2,"feuerwehr"]]
	for e in liste:
		var c=C.call(e[0],lat);var h:Vector2=c[1]
		var tf=Transform3D(Basis(Vector3.UP,atan2(h.x,h.y)),Vector3(c[0].x,0.015,c[0].y))
		match e[1]:
			"trabant_gruen":_trabant(tf,Color(0.62,0.72,0.22),Color(0.96,0.95,0.9))
			"trabant_blau":_trabant(tf,Color(0.45,0.72,0.86),Color(0.96,0.95,0.9))
			"wartburg":_wartburg(tf,Color(0.86,0.78,0.52))
			"taxi":_taxi(tf)
			"polizei":_polizei(tf)
			"rtw":_rtw(tf)
			"feuerwehr":_feuerwehr(tf)
	# Figuren mit beweglichem Skelett (Comic-Teile an den Knochen)
	var f1=C.call(190.0,r.w+1.7);var rn:Vector2=f1[2]
	_skelett_mensch(Vector3(f1[0].x,KB,f1[0].y),atan2(-rn.x,-rn.y),{"haut":HAUT[1],"oben":Color(0.93,0.42,0.18),"unten":Color(0.2,0.3,0.55),"haar":Color(0.2,0.12,0.07),"schuh":Color(0.95,0.95,0.95)},"idle",0.5)
	var f2=C.call(203.0,r.w+1.8);var t2:Vector2=f2[1]
	_skelett_mensch(Vector3(f2[0].x,KB,f2[0].y),atan2(t2.x,t2.y),{"haut":HAUT[3],"oben":Color(0.18,0.55,0.35),"unten":Color(0.18,0.18,0.2),"haar":Color(0.06,0.05,0.05),"schuh":Color(0.6,0.15,0.2),"frau":true},"walk",0.35)
	var f3=C.call(205.5,r.w+2.6)
	_skelett_mensch(Vector3(f3[0].x,KB,f3[0].y),atan2(t2.x,t2.y)+0.2,{"haut":HAUT[0],"oben":Color(0.3,0.5,0.8),"unten":Color(0.35,0.3,0.25),"haar":Color(0.85,0.65,0.3),"schuh":Color(0.15,0.13,0.12)},"walk",0.85)

func _haenge(sk:Skeleton3D,idx:Dictionary,Rx:Transform3D,key:String,fn:Callable):
	if not idx.has(key):return
	var alt=st;var altm=mats;var altz=zaehler;st={};mats={};zaehler={}
	fn.call()
	var ba=BoneAttachment3D.new();ba.bone_name=sk.get_bone_name(idx[key]);sk.add_child(ba)
	var inv=sk.get_bone_global_rest(idx[key]).affine_inverse()*Rx.affine_inverse()
	for k in st:
		var mi=MeshInstance3D.new();mi.mesh=st[k].commit();mi.material_override=mats[k];ba.add_child(mi);mi.transform=inv
		if mats[k]==ink:mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	st=alt;mats=altm;zaehler=altz

var SKELETTE:=[]
func _skelett_mensch(pos:Vector3,yaw:float,o:Dictionary,anim:String,zeit:float):
	var PE=load("res://scripts/people.gd");var U=load("res://scripts/anim_util.gd");var F=load("res://scripts/fit.gd")
	var rr=RandomNumberGenerator.new();rr.seed=3
	var p:Node3D=PE.make("joe",rr);welt.add_child(p);p.position=pos;p.rotation.y=yaw;SKELETTE.append(p)
	for m in p.find_children("*","MeshInstance3D",true,false):m.visible=false
	var sk:Skeleton3D=U.find_skel(p)
	if sk==null:print("SKELETT fehlt");return
	var Rx:Transform3D=F.rel_xf(sk,p)
	var idx={}
	for i in sk.get_bone_count():
		var k=U.human_key(sk.get_bone_name(i))
		if not idx.has(k):idx[k]=i
	var J=func(k:String)->Vector3:return Rx*sk.get_bone_global_rest(idx[k]).origin
	for k in ["Hips","Spine","Neck","Head","LeftArm","LeftForeArm","LeftHand","LeftUpLeg","LeftLeg","LeftFoot","RightArm","RightForeArm","RightHand","RightUpLeg","RightLeg","RightFoot"]:
		if not idx.has(k):print("SKELETT ohne ",k);return
	var s=(J.call("Head").y-J.call("LeftFoot").y)/1.52
	var frau:bool=o.get("frau",false)
	var haut=_toon(o.haut);var oben=_toon(o.oben);var unten=_toon(o.unten);var haar=_toon(o.haar,0.6);var schuh=_toon(o.schuh)
	var X=Vector3(1,0,0);var Z=Vector3(0,0,1)
	var hy=J.call("Hips").y;var ny=J.call("Neck").y;var hx=J.call("Hips")
	var brust="Spine2" if idx.has("Spine2") else ("Spine1" if idx.has("Spine1") else "Spine")
	# Becken
	_haenge(sk,idx,Rx,"Hips",func():
		loft(unten,[ring_ell(Vector3(hx.x,hy-0.11*s,hx.z),X,Z,0.15*s,0.1*s,14),ring_ell(Vector3(hx.x,hy-0.01*s,hx.z),X,Z,(0.175 if frau else 0.165)*s,0.115*s,14),ring_ell(Vector3(hx.x,hy+0.09*s,hx.z),X,Z,(0.15 if frau else 0.16)*s,0.105*s,14)],true,0.016)
		box(_toon(Color(0.22,0.16,0.11)),Vector3(hx.x,hy+0.065*s,hx.z),Vector3(0.33*s,0.045*s,0.225*s),Basis(),0.0))
	# Oberkörper (Taille bis Schultern)
	var sh=(0.2 if not frau else 0.172)*s
	_haenge(sk,idx,Rx,brust,func():
		var R2=[]
		var L=ny-hy
		for q in [[0.08,0.155,0.105],[0.3,0.15 if not frau else 0.13,0.1],[0.55,0.18 if not frau else 0.155,0.12],[0.75,sh/s,0.125 if not frau else 0.135],[0.92,sh/s-0.01,0.11],[1.0,0.11,0.07]]:
			R2.append(ring_ell(Vector3(hx.x,hy+L*q[0],hx.z+0.01*s),X,Z,q[1]*s,q[2]*s,16))
		loft(oben,R2,true,0.018))
	# Hals, Kopf, Gesicht, Haare
	var nk=J.call("Neck");var kh=J.call("Head")
	_haenge(sk,idx,Rx,"Neck",func():rohr(haut,[nk,kh+Vector3(0,0.03*s,0)],[0.05*s,0.048*s],0.014,10,false))
	_haenge(sk,idx,Rx,"Head",func():
		var kc=kh+Vector3(0,0.1*s,0.01*s)
		kugel(haut,kc,Vector3(0.1,0.12,0.11)*s,1.07)
		kugel(haut,kc+Vector3(0,-0.06,0.025)*s,Vector3(0.08,0.07,0.085)*s,1.0)
		for sd in [-1,1]:
			kugel(haut,kc+Vector3(sd*0.098,0,-0.005)*s,Vector3(0.022,0.035,0.022)*s,1.15)
			var aug=kc+Vector3(sd*0.038,0.012,0.096)*s
			kugel(M.weiss,aug,Vector3(0.025,0.022,0.012)*s,1.0)
			kugel(_toon(Color(0.3,0.22,0.12)),aug+Vector3(0,-0.002,0.01)*s,Vector3(0.013,0.014,0.006)*s,1.0)
			kugel(M.dunkel,aug+Vector3(0,-0.002,0.0145)*s,Vector3(0.007,0.008,0.003)*s,1.0)
			box(haar,aug+Vector3(sd*0.004,0.042,0.004)*s,Vector3(0.05,0.013,0.012)*s,Basis(Vector3(0,0,1),-sd*0.12),0.0)
		kugel(haut,kc+Vector3(0,-0.018,0.11)*s,Vector3(0.02,0.03,0.024)*s,1.0)
		box(_toon(Color(0.7,0.3,0.28) if not frau else Color(0.82,0.25,0.3)),kc+Vector3(0,-0.072,0.098)*s,Vector3(0.05,0.012,0.01)*s,Basis(),0.0)
		if frau:
			kugel(haar,kc+Vector3(0,0.04,-0.018)*s,Vector3(0.115,0.104,0.117)*s,1.04)
			loft(haar,[ring_ell(kc+Vector3(0,0,-0.035)*s,X,Z,0.11*s,0.09*s,12),ring_ell(kc+Vector3(0,-0.16,-0.05)*s,X,Z,0.12*s,0.075*s,12),ring_ell(kc+Vector3(0,-0.28,-0.065)*s,X,Z,0.1*s,0.05*s,12)],true,0.016)
			box(haar,kc+Vector3(0,0.08,0.075)*s,Vector3(0.16,0.045,0.06)*s,Basis(Vector3(1,0,0),-0.5),0.0)
		else:
			kugel(haar,kc+Vector3(0,0.042,-0.02)*s,Vector3(0.108,0.098,0.11)*s,1.04)
			box(haar,kc+Vector3(0,0.09,0.07)*s,Vector3(0.17,0.05,0.07)*s,Basis(Vector3(1,0,0),-0.35),0.0))
	# Arme: Schulterkugel + Ärmel am Oberarm, Unterarm mit Ellbogenkugel, Hand mit Daumen
	for seite in ["Left","Right"]:
		var A=J.call(seite+"Arm");var E=J.call(seite+"ForeArm");var W=J.call(seite+"Hand")
		_haenge(sk,idx,Rx,seite+"Arm",func():
			kugel(oben,A,Vector3.ONE*0.075*s,1.08)
			rohr(oben,[A,A.lerp(E,0.55)],[0.072*s,0.066*s],0.016,12,false)
			rohr(haut,[A.lerp(E,0.5),E],[0.052*s,0.047*s],0.015,12,false))
		_haenge(sk,idx,Rx,seite+"ForeArm",func():
			kugel(haut,E,Vector3.ONE*0.048*s,1.1)
			rohr(haut,[E,W],[0.046*s,0.036*s],0.015,12,false))
		_haenge(sk,idx,Rx,seite+"Hand",func():
			var d=(W-E).normalized()
			kugel(haut,W+d*0.06*s,Vector3(0.06,0.04,0.035)*s,1.1)
			kugel(haut,W+d*0.03*s+Z*0.035*s,Vector3(0.025,0.018,0.018)*s,1.12))
		var U2=J.call(seite+"UpLeg");var K=J.call(seite+"Leg");var Fu=J.call(seite+"Foot")
		_haenge(sk,idx,Rx,seite+"UpLeg",func():rohr(unten,[U2,K],[0.095*s,0.072*s],0.016,12,false))
		_haenge(sk,idx,Rx,seite+"Leg",func():
			kugel(unten,K,Vector3.ONE*0.072*s,1.08)
			rohr(unten,[K,Fu+Vector3(0,0.03*s,0)],[0.07*s,0.06*s],0.016,12,false))
		_haenge(sk,idx,Rx,seite+"Foot",func():
			var gy=Fu.y-0.085*s
			loft(schuh,[ring_ell(Vector3(Fu.x,gy+0.055*s,Fu.z-0.07*s),X,Vector3.UP,0.05*s,0.05*s,10),ring_ell(Vector3(Fu.x,gy+0.055*s,Fu.z+0.04*s),X,Vector3.UP,0.056*s,0.055*s,10),
				ring_ell(Vector3(Fu.x,gy+0.04*s,Fu.z+0.14*s),X,Vector3.UP,0.05*s,0.035*s,10),ring_ell(Vector3(Fu.x,gy+0.032*s,Fu.z+0.18*s),X,Vector3.UP,0.03*s,0.025*s,10)],true,0.016)
			box(_toon(Color(0.15,0.13,0.12)),Vector3(Fu.x,gy+0.008*s,Fu.z+0.05*s),Vector3(0.11*s,0.016*s,0.3*s),Basis(),0.0))
	var ap:AnimationPlayer=p.get_meta("anim")
	if ap and ap.has_animation(anim):
		ap.play(anim);ap.seek(zeit,true);ap.speed_scale=0.0

# ================= Höhen: Terrassen =================
# Höhenfeld: ein Hügelviertel im Nordwesten (Plateau), Straßen steigen weich an.
# Jeder Block liegt auf EINER Höhe (in 2-m-Stufen) – zur tieferen Straße hin entsteht eine Stützmauer.
const PLATEAU:=Vector2(-125,-100)
func FY(x:float,z:float)->float:
	var d=Vector2(x,z).distance_to(PLATEAU)
	return 6.0*(1.0-smoothstep(40.0,92.0,d))
var LG:PackedFloat32Array
const LGX0:=-202.0
const LGZ0:=-172.0
const LGC:=0.5
var LGN:=0;var LGM:=0
func Y_at(x:float,z:float)->float:
	var i=int((x-LGX0)/LGC);var k=int((z-LGZ0)/LGC)
	if i>=0 and k>=0 and i<LGN and k<LGM:
		var v=LG[k*LGN+i]
		if v>-1000.0:return v
	return FY(x,z)
func _lot_mark(lot:PackedVector2Array)->float:
	if LG.is_empty():
		LGN=int(404.0/LGC);LGM=int(344.0/LGC);LG=PackedFloat32Array();LG.resize(LGN*LGM);LG.fill(-1e9)
	# Grundstück um 1,3 m erweitert: Gesimse, Fensterbänke, Markisen ragen über die Bauflucht
	var g=_groesstes(Geometry2D.offset_polygon(lot,1.3,Geometry2D.JOIN_MITER))
	if g.size()>=3:lot=g
	var hb=0.0
	for v in lot:hb=max(hb,FY(v.x,v.y))
	if hb<0.05:return 0.0
	var bb=_bbox(lot)
	var k0=max(0,int((bb.position.y-LGZ0)/LGC));var k1=min(LGM-1,int((bb.end.y-LGZ0)/LGC))
	for k in range(k0,k1+1):
		var z=LGZ0+(k+0.5)*LGC;var xs=[]
		for i in lot.size():
			var a=lot[i];var b=lot[(i+1)%lot.size()]
			if (a.y<=z)!=(b.y<=z):xs.append(a.x+(z-a.y)/(b.y-a.y)*(b.x-a.x))
		xs.sort()
		for j in range(0,xs.size()-1,2):
			var i0=max(0,int((xs[j]-LGX0)/LGC)-1);var i1=min(LGN-1,int((xs[j+1]-LGX0)/LGC)+1)
			for i in range(i0,i1+1):LG[k*LGN+i]=hb
	return hb
func _block_hoehe(pc:PackedVector2Array)->float:
	var m=0.0
	for v in pc:m=max(m,FY(v.x,v.y))
	return ceil(m/2.0-0.15)*2.0
func _hoehenraster():
	# einzelne Knoten (Schrift, Figuren) auf Gelände-/Hausplattenhöhe setzen
	for c in welt.get_children():
		if c is Label3D:c.position.y+=Y_at(c.position.x,c.position.z)
	for p in SKELETTE:p.position.y+=FY(p.position.x,p.position.z)

# Fahrbahnband: Fläche fein unterteilt (damit sie dem Höhenfeld folgt)
func _band(poly:PackedVector2Array):
	if Geometry2D.is_polygon_clockwise(poly):return   # Innenrand eines Rings ist ein Loch, keine Fläche
	var idx=Geometry2D.triangulate_polygon(poly)
	if idx.is_empty():return
	var so=_st(M.asphalt,true)
	for i in range(0,idx.size(),3):
		_tri_fein(so,poly[idx[i]],poly[idx[i+1]],poly[idx[i+2]],0.015,7)
func _tri_fein(so:SurfaceTool,a:Vector2,b:Vector2,c:Vector2,y:float,tiefe:int):
	var L=max(a.distance_to(b),max(b.distance_to(c),c.distance_to(a)))
	if L>6.0 and tiefe>0:
		var ab=(a+b)*0.5;var bc=(b+c)*0.5;var ca=(c+a)*0.5
		_tri_fein(so,a,ab,ca,y,tiefe-1);_tri_fein(so,ab,b,bc,y,tiefe-1);_tri_fein(so,ca,bc,c,y,tiefe-1);_tri_fein(so,ab,bc,ca,y,tiefe-1)
		return
	_tri(so,Vector3(a.x,y,a.y),Vector3(b.x,y,b.y),Vector3(c.x,y,c.y),Vector3.UP)

# ================= Tunnel durch den Hügel an der Landstraße =================
func _tunnel():
	var x0=208.0;var x1=236.0;var zc=10.5;var hb=7.5;var th=6.2
	var dunkel=_toon(Color(0.32,0.32,0.34));var beton=_toon(Color(0.78,0.76,0.72))
	var gr=_shader(GRAS,{});var fels=_toon(Color(0.55,0.5,0.45))
	# Röhre: Wände, Decke, Gehsteige, Lampen
	for sd in [-1,1]:
		box(dunkel,Vector3((x0+x1)*0.5,th*0.5,zc+sd*(hb+0.4)),Vector3(x1-x0,th,0.8),Basis(),0.0)
		box(beton,Vector3((x0+x1)*0.5,0.3,zc+sd*(hb-0.4)),Vector3(x1-x0,0.6,0.8),Basis(),0.0)
	box(dunkel,Vector3((x0+x1)*0.5,th+0.5,zc),Vector3(x1-x0,1.0,hb*2+1.6),Basis(),0.0)
	var x=x0+3.0
	while x<x1:
		box(M.lampe,Vector3(x,th-0.05,zc),Vector3(1.6,0.08,0.4),Basis(),0.0);x+=6.0
	# Portale: Betonrahmen mit Stirnwand
	for xp in [x0,x1]:
		var o=-1.0 if xp==x0 else 1.0
		box(beton,Vector3(xp+o*0.3,th+0.9,zc),Vector3(1.0,1.8,hb*2+3.0),Basis(),0.04)
		for sd in [-1,1]:box(beton,Vector3(xp+o*0.3,th*0.5,zc+sd*(hb+1.0)),Vector3(1.0,th,1.4),Basis(),0.04)
		box(M.mauer,Vector3(xp+o*0.2,4.5,zc-hb-8.0),Vector3(0.8,9.0,13.0),Basis(),0.04)
		box(M.mauer,Vector3(xp+o*0.2,4.5,zc+hb+8.0),Vector3(0.8,9.0,13.0),Basis(),0.04)
		_schrift("TUNNEL RADEBERG",Vector3(xp+o*0.82,th+0.95,zc),Basis(Vector3.UP,o*PI*0.5),0.007,Color(0.1,0.1,0.12))
	# Hügelkuppen links und rechts der Röhre, begrünte Decke dazwischen
	var X=Vector3(1,0,0);var Z=Vector3(0,0,1)
	box(gr,Vector3((x0+x1)*0.5,th+1.6,zc),Vector3(x1-x0-0.4,1.2,hb*2+3.0),Basis(),0.04)
	for sd in [-1,1]:
		var c=Vector3((x0+x1)*0.5,0,zc+sd*25.0)
		var Rg=[]
		for q in [[0.0,17.0,16.5],[3.5,15.0,14.0],[7.0,11.5,10.5],[9.5,7.5,7.0],[10.8,3.0,3.0]]:
			Rg.append(ring_s(c+Vector3(0,q[0],0),X,Z,q[1],q[2],2.6,24))
		loft(gr,Rg,true,0.04)
		for k in 4:
			var a=rng.randf()*TAU
			kugel(fels,c+Vector3(cos(a)*9.0,5.5+rng.randf()*2.0,sin(a)*8.5),Vector3(1.6,1.2,1.4)*rng.randf_range(0.8,1.4),1.06)
		_baum(c+Vector3(2.0,10.6,0.0))
		_baum(c+Vector3(-5.0,8.8,sd*-3.0))

# ================= Langer Tunnel =================
func _langtunnel():
	var P:PackedVector2Array=TUN.P;var S:PackedFloat32Array=TUN.S;var H:PackedFloat32Array=TUN.H
	var n=P.size();var w=5.0;var wh=6.2;var L=S[n-1]
	var beton=_toon(Color(0.8,0.78,0.73));var dunkel=_toon(Color(0.3,0.3,0.33));var kachel=_toon(Color(0.9,0.88,0.8))
	var gelb=_toon(Color(0.95,0.8,0.2))
	var N=[]
	for i in n:N.append(_rn((P[min(i+1,n-1)]-P[max(i-1,0)]).normalized()))
	var top=_st(M.asphalt,true);var wand=_st(beton,true);var decke=_st(dunkel,true);var band_=_st(kachel,true)
	var portal_s=[]
	for i in n-1:
		var h0=H[i];var h1=H[i+1]
		var a=P[i]-N[i]*w;var b=P[i]+N[i]*w;var c=P[i+1]+N[i+1]*w;var d=P[i+1]-N[i+1]*w
		_tri(top,Vector3(a.x,h0,a.y),Vector3(b.x,h0,b.y),Vector3(c.x,h1,c.y),Vector3.UP);_tri(top,Vector3(a.x,h0,a.y),Vector3(c.x,h1,c.y),Vector3(d.x,h1,d.y),Vector3.UP)
		var zu0=h0+wh+0.4<-0.3;var zu1=h1+wh+0.4<-0.3
		if zu0!=zu1:portal_s.append(i)
		for sd in [-1,1]:
			var e0=P[i]+N[i]*(w+0.8)*sd;var e1=P[i+1]+N[i+1]*(w+0.8)*sd;var o=-Vector3(N[i].x*sd,0,N[i].y*sd)
			var t0=(h0+wh) if zu0 else KB+0.9;var t1=(h1+wh) if zu1 else KB+0.9
			_tri(wand,Vector3(e0.x,h0,e0.y),Vector3(e1.x,h1,e1.y),Vector3(e1.x,t1,e1.y),o);_tri(wand,Vector3(e0.x,h0,e0.y),Vector3(e1.x,t1,e1.y),Vector3(e0.x,t0,e0.y),o)
			# Außenseite der Trogwand (sichtbar von oben) + Kachelband innen
			_tri(wand,Vector3(e0.x,h0,e0.y),Vector3(e1.x,t1,e1.y),Vector3(e1.x,h1,e1.y),-o);_tri(wand,Vector3(e0.x,h0,e0.y),Vector3(e0.x,t0,e0.y),Vector3(e1.x,t1,e1.y),-o)
			var k0=P[i]+N[i]*(w+0.78)*sd;var k1=P[i+1]+N[i+1]*(w+0.78)*sd
			_tri(band_,Vector3(k0.x,h0+0.9,k0.y),Vector3(k1.x,h1+0.9,k1.y),Vector3(k1.x,h1+2.2,k1.y),o);_tri(band_,Vector3(k0.x,h0+0.9,k0.y),Vector3(k1.x,h1+2.2,k1.y),Vector3(k0.x,h0+2.2,k0.y),o)
			# Notgehweg
			var g0=P[i]+N[i]*(w+0.8)*sd;var g1=P[i+1]+N[i+1]*(w+0.8)*sd;var f0=P[i]+N[i]*w*sd;var f1=P[i+1]+N[i+1]*w*sd
			_tri(wand,Vector3(f0.x,h0+0.3,f0.y),Vector3(g0.x,h0+0.3,g0.y),Vector3(g1.x,h1+0.3,g1.y),Vector3.UP);_tri(wand,Vector3(f0.x,h0+0.3,f0.y),Vector3(g1.x,h1+0.3,g1.y),Vector3(f1.x,h1+0.3,f1.y),Vector3.UP)
			_tri(wand,Vector3(f0.x,h0,f0.y),Vector3(f1.x,h1,f1.y),Vector3(f1.x,h1+0.3,f1.y),o);_tri(wand,Vector3(f0.x,h0,f0.y),Vector3(f1.x,h1+0.3,f1.y),Vector3(f0.x,h0+0.3,f0.y),o)
			if not zu0 and h0<-0.4:
				# Geländer oben auf der offenen Trogwand
				var mm=(e0+e1)*0.5;var dd=e1-e0
				box(gelb,Vector3(mm.x,KB+1.35,mm.y),Vector3(0.08,0.08,dd.length()+0.05),Basis(Vector3.UP,atan2(dd.x,dd.y)),0.0)
				if i%3==0:box(gelb,Vector3(e0.x,KB+1.1,e0.y),Vector3(0.07,0.5,0.07),Basis(),0.0)
		if zu0 and zu1:
			var a2=P[i]-N[i]*(w+0.8);var b2=P[i]+N[i]*(w+0.8);var c2=P[i+1]+N[i+1]*(w+0.8);var d2=P[i+1]-N[i+1]*(w+0.8)
			_tri(decke,Vector3(a2.x,h0+wh,a2.y),Vector3(b2.x,h0+wh,b2.y),Vector3(c2.x,h1+wh,c2.y),Vector3.DOWN);_tri(decke,Vector3(a2.x,h0+wh,a2.y),Vector3(c2.x,h1+wh,c2.y),Vector3(d2.x,h1+wh,d2.y),Vector3.DOWN)
	# Markierungen, Lampen
	var s=1.0
	while s<L-1.0:
		var b=_bei_s(P,S,s);var p:Vector2=b[0];var t:Vector2=b[1];var rn=_rn(t)
		var i=clamp(S.bsearch(s),0,n-1);var h=H[i]
		var bas=Basis(Vector3.UP,atan2(t.x,t.y))*Basis(Vector3.RIGHT,-atan2(H[min(i+1,n-1)]-H[max(i-1,0)],5.0))
		if fmod(s,6.0)<2.6:box(M.markierung,Vector3(p.x,h+0.02,p.y),Vector3(0.15,0.012,3.0),bas,0.0)
		for sd in [-1,1]:
			var c=p+rn*(w-0.35)*sd;box(M.markierung,Vector3(c.x,h+0.02,c.y),Vector3(0.14,0.012,2.6),bas,0.0)
		if h+wh+0.4<-0.3 and fmod(s,7.5)<2.6:
			for sd in [-1,1]:
				var c=p+rn*2.4*sd;box(M.lampe,Vector3(c.x,h+wh-0.06,c.y),Vector3(0.35,0.08,1.8),bas,0.0)
			if fmod(s,30.0)<2.6:
				var l=OmniLight3D.new();l.light_color=Color(1.0,0.85,0.6);l.light_energy=2.2;l.omni_range=18.0;welt.add_child(l);l.position=Vector3(p.x,h+wh-0.8,p.y)
		s+=2.5
	# Portale: Stirnwand mit Schrift, Lüftungsventilatoren
	for i in portal_s:
		var p=P[i];var t=(P[min(i+1,n-1)]-P[max(i-1,0)]).normalized();var rn=_rn(t);var h=H[i]
		var raus=t if H[min(i+5,n-1)]>h else -t
		var bas=Basis(Vector3.UP,atan2(raus.x,raus.y))
		var c=p+raus*0.3
		var unten=h+wh;var oben=KB+1.2
		box(beton,Vector3(c.x,(unten+oben)*0.5,c.y),Vector3(w*2+3.4,oben-unten,0.9),bas,0.04)
		box(gelb,Vector3(c.x,unten+0.12,c.y)+Vector3(raus.x,0,raus.y)*0.47,Vector3(w*2+1.6,0.24,0.04),bas,0.0)
		_schrift("STADTTUNNEL",Vector3(c.x,(unten+oben)*0.5,c.y)+Vector3(raus.x,0,raus.y)*0.47,bas,0.006,Color(0.12,0.12,0.14))
	# Ventilatoren unter der Decke
	for f in [0.3,0.5,0.7]:
		var b=_bei_s(P,S,L*f);var p:Vector2=b[0];var t:Vector2=b[1];var i=clamp(S.bsearch(L*f),0,n-1)
		for sd in [-1,1]:
			var c=p+_rn(t)*2.5*sd;var y=H[i]+wh-0.7
			var a3=Vector3(c.x,y,c.y)
			zyl(M.metall,a3-Vector3(t.x,0,t.y)*1.2,a3+Vector3(t.x,0,t.y)*1.2,0.45,1.06)
	# Verkehr im Tunnel
	for e in [[0.35,1],[0.55,-1],[0.72,1],[0.2,-1]]:
		var s2=L*e[0];var b=_bei_s(P,S,s2);var p:Vector2=b[0];var t:Vector2=b[1];var i=clamp(S.bsearch(s2),0,n-1)
		var hd=t*e[1];var c=p+_rn(t)*2.5*e[1]
		_auto_zufall(Transform3D(Basis(Vector3.UP,atan2(hd.x,hd.y)),Vector3(c.x,H[i]+0.015,c.y)))

# ================= Bilder =================
func _bilder():
	var vp=root.get_viewport()
	vp.msaa_3d=Viewport.MSAA_4X
	var cam=Camera3D.new();cam.fov=58;cam.far=1500;welt.add_child(cam);cam.current=true
	var V=func(c:Array,h:float)->Vector3:return Vector3(c[0].x,h,c[0].y)
	var C:Callable=SHOW.C;var r=SHOW.r;var w=r.w
	var views=[
		["01_uebersicht",Vector3(-120,330,430),Vector3(30,0,-10),50],
		["02_autobahnschleife",Vector3(185,60,130),Vector3(262,6,10),58],
		["03_luft_viertel",Vector3(-10,70,150),Vector3(-15,0,40),55],
	]
	var add=func(nm,a,b,f):views.append([nm,a,b,f])
	# Kurvige Allee auf Gehweghöhe
	for x in R:
		if x.n=="allee":
			var L=x.S[x.S.size()-1];var b=_bei_s(x.P,x.S,L*0.36);var p:Vector2=b[0];var t:Vector2=b[1];var rn=_rn(t)
			var c=p+rn*(x.w+1.8);var z=_bei_s(x.P,x.S,L*0.36+55.0)[0]
			add.call("04_kurvige_allee",Vector3(c.x,1.7,c.y),Vector3(z.x,3.5,z.y),62)
		if x.n=="diag":
			var L=x.S[x.S.size()-1];var b=_bei_s(x.P,x.S,L*0.3);var p:Vector2=b[0];var z=_bei_s(x.P,x.S,L*0.3+40.0)[0]
			add.call("05_einbahnstrasse",Vector3(p.x,1.8,p.y),Vector3(z.x,2.5,z.y),62)
		if x.n=="gasse2":
			var L=x.S[x.S.size()-1];var b=_bei_s(x.P,x.S,L*0.35);var p:Vector2=b[0];var z=_bei_s(x.P,x.S,L*0.35+30.0)[0]
			add.call("06_gasse",Vector3(p.x,1.7,p.y),Vector3(z.x,3.0,z.y),62)
	if SPITZ.has("p"):
		var p:Vector2=SPITZ.p;var a:Vector2=SPITZ.aus
		add.call("07_spitze_ecke",Vector3(p.x+a.x*24,1.8,p.y+a.y*24),Vector3(p.x,7.0,p.y),62)
	add.call("08_unter_bruecke",Vector3(228,1.7,8.5),Vector3(280,5.0,11.5),62)
	var hb=_bei_s(HW.P,HW.S,_s_von(HW.P,HW.S,Vector2(-40,-237)));var hp:Vector2=hb[0];var ht:Vector2=hb[1];var hc=hp+_rn(ht)*2.7
	add.call("09_autobahn",Vector3(hc.x,H_AB+1.6,hc.y),Vector3(hc.x+ht.x*60,H_AB+2.0,hc.y+ht.y*60),62)
	for k in JN:
		if (k.a.n=="allee" and k.b.n=="ns1") or (k.a.n=="ns1" and k.b.n=="allee"):
			add.call("10_kreuzung",Vector3(k.p.x+6,24.0,k.p.y+20),Vector3(k.p.x,0.0,k.p.y),62)
	add.call("11_trabant_vorn",V.call(C.call(199.8,w-3.7),1.25),V.call(C.call(196.0,w-1.15),0.72),46)
	add.call("12_trabant_seite",V.call(C.call(196.2,w-6.3),1.0),V.call(C.call(196.0,w-1.15),0.78),40)
	add.call("13_trabant_hinten",V.call(C.call(192.0,w-3.3),1.35),V.call(C.call(196.0,w-1.15),0.72),46)
	add.call("14_taxi_polizei",V.call(C.call(209.0,w-5.6),1.4),V.call(C.call(217.0,w-1.15),0.8),52)
	add.call("15_feuerwehr",V.call(C.call(244.0,w-4.2),2.0),V.call(C.call(237.2,w-1.15),1.6),56)
	add.call("18_tunnel",Vector3(185.0,3.0,13.5),Vector3(215,3.0,10.5),55)
	add.call("19_tunnel_ausfahrt",Vector3(232.0,1.9,8.5),Vector3(300,5.0,14.0),58)
	add.call("20_schleife",Vector3(345,32,85),Vector3(290,4.0,10),58)
	add.call("21_einfaedeln",Vector3(287.5,12.2,60),Vector3(278,10.5,-30),58)
	add.call("22_auffahrt_nord",Vector3(-55,18,-175),Vector3(40,8,-228),58)
	add.call("23_terrassen",Vector3(-60,22,-20),Vector3(-130,4,-100),58)
	add.call("24_hangstrasse",Vector3(-46,FY(-46,-12)+1.8,-12),Vector3(-68,FY(-68,-90)+2.5,-90),60)
	var tb=_bei_s(TUN.P,TUN.S,18.0)
	add.call("25_tunnel_einfahrt",Vector3(-298,4.5,-125),Vector3(tb[0].x,-3.0,tb[0].y),58)
	var tm=_bei_s(TUN.P,TUN.S,TUN.S[TUN.S.size()-1]*0.47);var tmi=clamp(TUN.S.bsearch(TUN.S[TUN.S.size()-1]*0.47),0,TUN.P.size()-1)
	var tz=_bei_s(TUN.P,TUN.S,TUN.S[TUN.S.size()-1]*0.47+40.0)
	add.call("26_tunnel_innen",Vector3(tm[0].x,TUN.H[tmi]+2.0,tm[0].y)+Vector3(_rn(tm[1]).x,0,_rn(tm[1]).y)*2.5,Vector3(tz[0].x,TUN.H[tmi]+1.6,tz[0].y),62)
	add.call("27_tunnel_luft",Vector3(-330,38,-170),Vector3(-262,-4,-108),55)
	add.call("28_tunnel_portal",Vector3(-283,3.2,-113.5),Vector3(-250,-4.5,-109.5),60)
	add.call("16_figur_skelett",V.call(C.call(190.6,w-2.3),1.35),V.call(C.call(190.0,w+1.7),1.0),40)
	add.call("17_figuren_gehend",V.call(C.call(208.5,w+2.2),1.55),V.call(C.call(203.5,w+2.1),1.0),40)
	for k in 3:await process_frame
	for p in SKELETTE:
		for m in p.find_children("*","MeshInstance3D",true,false):
			if not (m.get_parent() is BoneAttachment3D):m.visible=false
	var nur=OS.get_cmdline_user_args()
	for v in views:
		if nur.size()>0 and not v[0] in nur:continue
		cam.fov=v[3];cam.position=v[1];cam.look_at(v[2])
		for k in 8:await process_frame
		vp.get_texture().get_image().save_png(OUT+v[0]+".png")
		print("BILD ",v[0])
