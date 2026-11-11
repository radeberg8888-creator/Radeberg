extends SceneTree
# PROBE (nicht im Spiel): Natur außerhalb der Städte – Wald, Waldrand, Wiese, Felshang, Seeufer,
# Jagdhütte auf einer Lichtung, großes Cannabisfeld. Gelände aus G0 (natürliche Höhen) um den Stausee.
const OUT:="/home/claude/work/proto_natur/"
var REG:=Rect2(-1250,-3350,950,950)
var L;var K;var G0;var N
var W:Node3D;var SUN:DirectionalLight3D
const ST:=5.0
var nx:int;var nz:int;var H:PackedFloat32Array
var FREI:=[]   # [Vector2 Mitte, Radius] (Sonderorte)
var VILLA:Vector2;var VILLA_Y:float;var SEE:Vector2;var UFER:Vector2
var JAGD:Vector2;var HANF:Vector2;var HANF_Y:float;var JAGD_Y:float

func _init():
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	W=Node3D.new();W.name="Probe";root.add_child(W)
	L=load("res://scripts/comic/stadt_lib.gd").new();L.init_lib(W,7)
	K=load("res://scripts/comic/kit_lib.gd").new(L)
	G0=load("res://scripts/welt_gelaende.gd").new()
	N=load("res://scripts/comic/natur_lib.gd").new(L,K,G0)
	var t0=Time.get_ticks_msec()
	N.kits_bauen()
	print("KITS ",(Time.get_ticks_msec()-t0)," ms ",K.KITS.size())
	_feld()
	_orte_waehlen()
	_umgebung();_gelaende();_wasser()
	var frei=func(x,z):
		for f in FREI:
			if Vector2(x,z).distance_to(f[0])<f[1]:return false
		return Y(x,z)>-0.5
	var info=func(x,z):
		var hx=Y(x+3,z)-Y(x-3,z);var hz=Y(x,z+3)-Y(x,z-3)
		return [Vector2(hx,hz).length()/6.0,G0.kuesten_abstand(x,z),_trocken(x,z)]
	var P=N.platzieren(REG,func(x,z):return Y(x,z),frei,info,6.0)
	P.append_array(N.jagd_platz(JAGD,JAGD_Y,0.6))
	P.append_array(N.hanf_platz(HANF,HANF_Y,0.2))
	P.append_array(N.villa_platz(VILLA,VILLA_Y,SEE,UFER))
	var st={}
	for p in P:st[p[0]]=st.get(p[0],0)+1
	print("PLATZ ",P.size()," ",st)
	var r=K.aufstellen(W,P,100.0,260.0)
	print("AUFGESTELLT ",r," ",(Time.get_ticks_msec()-t0)/1000.0," s")
	await _bilder()
	quit()

func _trocken(x,z)->float:
	var i=clampi(int((x-G0.X0)/G0.STEP),0,G0.rx-1);var k=clampi(int((z-G0.Z0)/G0.STEP),0,G0.rz-1);var j=(k*G0.rx+i)*4
	return (G0._bo[j+2]+G0._bo[j+3]*0.0)/255.0
func _feld():
	nx=int(REG.size.x/ST)+1;nz=int(REG.size.y/ST)+1;H.resize(nx*nz)
	for k in nz:
		for i in nx:H[k*nx+i]=G0._nat(REG.position.x+i*ST,REG.position.y+k*ST)
func Y(x:float,z:float)->float:
	var fx=(x-REG.position.x)/ST;var fz=(z-REG.position.y)/ST
	var i=clampi(int(fx),0,nx-2);var k=clampi(int(fz),0,nz-2);var tx=clamp(fx-i,0.0,1.0);var tz=clamp(fz-k,0.0,1.0);var j=k*nx+i
	return lerp(lerp(H[j],H[j+1],tx),lerp(H[j+nx],H[j+nx+1],tx),tz)
func _ebnen(c:Vector2,r:float,rand:float)->float:
	var y=Y(c.x,c.y)
	for k in nz:
		for i in nx:
			var p=Vector2(REG.position.x+i*ST,REG.position.y+k*ST);var d=p.distance_to(c)
			if d<r+rand:H[k*nx+i]=lerp(y,H[k*nx+i],smoothstep(r,r+rand,d))
	return y
func _orte_waehlen():
	# flachste trockene Stelle (über 15 m) für das Feld, bewaldete Stelle für die Hütte
	var best=INF;var bw=-INF
	for z in range(int(REG.position.y)+150,int(REG.end.y)-150,20):
		for x in range(int(REG.position.x)+150,int(REG.end.x)-150,20):
			var y=Y(x,z)
			if y<15.0:continue
			var m=0.0
			for d in [Vector2(60,0),Vector2(-60,0),Vector2(0,60),Vector2(0,-60),Vector2(45,45),Vector2(-45,-45)]:m=max(m,abs(Y(x+d.x,z+d.y)-y))
			if m<best:best=m;HANF=Vector2(x,z)

	for z in range(int(REG.position.y)+150,int(REG.end.y)-150,20):
		for x in range(int(REG.position.x)+150,int(REG.end.x)-150,20):
			var w=N.nwald.get_noise_2d(x,z)
			var hx=Y(x+3,z)-Y(x-3,z);var hz=Y(x,z+3)-Y(x,z-3)
			if w>bw and Vector2(x,z).distance_to(HANF)>350.0 and Y(x,z)>8.0 and N.biom(x,z,Y(x,z),Vector2(hx,hz).length()/6.0,999.0,0.0)=="wald" and Vector2(hx,hz).length()/6.0<0.25:bw=w;JAGD=Vector2(x,z)
	var g=N.hanf_groesse()
	HANF_Y=_ebnen(HANF,g.length()*0.5,40.0);JAGD_Y=_ebnen(JAGD,16.0,14.0)
	# Villa: Uferpunkt am See suchen, 40 m landeinwärts ebnen
	var bu=INF
	for z in range(int(REG.position.y)+100,int(REG.end.y)-100,10):
		for x in range(int(REG.position.x)+100,int(REG.end.x)-100,10):
			if abs(Y(x,z)-0.5)>0.6:continue
			var g2=Vector2(Y(x+8,z)-Y(x-8,z),Y(x,z+8)-Y(x,z-8))
			if g2.length()<0.5:continue
			var land=g2.normalized();var v=Vector2(x,z)+land*40.0
			var sc=abs(Y(v.x,v.y)-6.0)+abs(g2.length()/16.0-0.25)*10.0
			if sc<bu:bu=sc;UFER=Vector2(x,z);SEE=-land;VILLA=v
	VILLA_Y=_ebnen(VILLA,16.0,12.0)
	for k in 30:
		var q=VILLA+SEE*(16.0+k*0.8)
		var hy=lerp(VILLA_Y,0.8,float(k)/30.0)
		for kk in nz:
			for i in nx:
				var pp=Vector2(REG.position.x+i*ST,REG.position.y+kk*ST)
				if pp.distance_to(q)<9.0 and H[kk*nx+i]>hy:H[kk*nx+i]=hy
	print("VILLA ",VILLA," ",VILLA_Y," ufer ",UFER)
	FREI=[[HANF,g.length()*0.5+4.0],[JAGD,24.0],[VILLA,22.0],[(VILLA+UFER)*0.5,14.0]]
	print("HANF ",HANF," gefälle ",best," JAGD ",JAGD," wald ",bw)

var TMAT:ShaderMaterial
func _gelaende():
	var sh=Shader.new();sh.code="""shader_type spatial;
render_mode diffuse_toon,specular_disabled;
uniform sampler2D rausch:repeat_enable,filter_linear_mipmap;
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	float a=texture(rausch,wp.xz/9.0).r;float b=texture(rausch,wp.xz/53.0).r;
	float f=0.84+0.22*a+0.12*(b-0.5);
	ALBEDO=COLOR.rgb*f;ROUGHNESS=1.0;
}"""
	TMAT=ShaderMaterial.new();TMAT.shader=sh
	var nt=NoiseTexture2D.new();nt.width=256;nt.height=256;nt.seamless=true;var fn=FastNoiseLite.new();fn.frequency=0.03;fn.fractal_octaves=3;nt.noise=fn
	await nt.changed
	TMAT.set_shader_parameter("rausch",nt)
	var stt=SurfaceTool.new();stt.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in nz:
		for i in nx:
			var x=REG.position.x+i*ST;var z=REG.position.y+k*ST;var y=H[k*nx+i]
			var hx=Y(x+ST,z)-Y(x-ST,z);var hz=Y(x,z+ST)-Y(x,z-ST)
			var stg=Vector2(hx,hz).length()/(2*ST)
			var c=N.farbe(x,z,y,stg,G0.kuesten_abstand(x,z),_trocken(x,z))
			for f in FREI:
				var d=Vector2(x,z).distance_to(f[0])
				if d<f[1]:c=c.lerp(Color(0.5,0.42,0.3) if f[0]==HANF else Color(0.5,0.62,0.3),0.55*(1.0-smoothstep(f[1]*0.7,f[1],d)))
			stt.set_color(c);stt.set_normal(Vector3(-hx,2*ST,-hz).normalized());stt.add_vertex(Vector3(x,y,z))
	for k in nz-1:
		for i in nx-1:
			var a=k*nx+i
			for q in [a,a+1,a+nx+1,a,a+nx+1,a+nx]:stt.add_index(q)
	var mi=MeshInstance3D.new();mi.mesh=stt.commit();mi.material_override=TMAT;W.add_child(mi)
func _wasser():
	var mi=MeshInstance3D.new();var pm=PlaneMesh.new();pm.size=Vector2(4000,4000);mi.mesh=pm;W.add_child(mi);mi.position=Vector3(REG.get_center().x,0,REG.get_center().y)
	var m=StandardMaterial3D.new();m.albedo_color=Color(0.22,0.46,0.62);m.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON;m.roughness=0.25;mi.material_override=m
func _umgebung():
	var we=WorldEnvironment.new();var e=Environment.new();we.environment=e;W.add_child(we)
	var sky=Sky.new();var sm=ProceduralSkyMaterial.new()
	sm.sky_top_color=Color(0.25,0.52,0.9);sm.sky_horizon_color=Color(0.75,0.86,0.96);sm.ground_horizon_color=Color(0.75,0.86,0.96);sm.ground_bottom_color=Color(0.4,0.45,0.4)
	sky.sky_material=sm;e.sky=sky;e.background_mode=Environment.BG_SKY
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color(0.72,0.78,0.9);e.ambient_light_energy=0.55
	e.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	e.fog_enabled=true;e.fog_light_color=Color(0.78,0.86,0.96);e.fog_density=0.0007
	SUN=DirectionalLight3D.new();SUN.rotation_degrees=Vector3(-50,-35,0);SUN.light_color=Color(1.0,0.95,0.86);SUN.light_energy=1.15
	SUN.shadow_enabled=true;SUN.directional_shadow_max_distance=160.0;SUN.shadow_bias=0.04;SUN.shadow_normal_bias=1.0
	W.add_child(SUN)
func _cam(pos:Vector3,ziel:Vector3,fov:=62.0)->Camera3D:
	var c=Camera3D.new();W.add_child(c);c.fov=fov;c.far=4000.0;c.look_at_from_position(pos,ziel);c.current=true;return c
func _bild(n:String):
	for k in 5:await process_frame
	root.get_viewport().get_texture().get_image().save_png(OUT+n+".png");print("BILD ",n)
func _blick(n:String,p:Vector2,aug:float,ziel:Vector2,zh:=1.5,fov:=62.0):
	var c=_cam(Vector3(p.x,Y(p.x,p.y)+aug,p.y),Vector3(ziel.x,Y(ziel.x,ziel.y)+zh,ziel.y),fov)
	await _bild(n);c.queue_free()
func _suche(biom:String)->Vector2:
	for z in range(int(REG.position.y)+120,int(REG.end.y)-120,15):
		for x in range(int(REG.position.x)+120,int(REG.end.x)-120,15):
			var y=Y(x,z);var hx=Y(x+3,z)-Y(x-3,z);var hz=Y(x,z+3)-Y(x,z-3)
			var b=N.biom(x,z,y,Vector2(hx,hz).length()/6.0,G0.kuesten_abstand(x,z),_trocken(x,z))
			if b==biom and y>1.0 and N.biom(x+20,z,Y(x+20,z),0.0,999.0,0.0)==biom and N.biom(x-20,z,Y(x-20,z),0.0,999.0,0.0)==biom:return Vector2(x,z)
	return REG.get_center()
func _bilder():
	root.size=Vector2i(1600,900)
	var m=REG.get_center()
	SUN.directional_shadow_max_distance=1200.0
	var vs=VILLA+SEE*40.0+Vector2(-SEE.y,SEE.x)*30.0
	var c=_cam(Vector3(vs.x,9.0,vs.y),Vector3(VILLA.x,VILLA_Y+3,VILLA.y),60.0);await _bild("01_villa");c.queue_free()
	SUN.directional_shadow_max_distance=160.0
	var w=_suche("wiese");await _blick("02_wiese",w,1.6,w+Vector2(40,-25),1.0)
	var r=_suche("rand");await _blick("03_waldrand",r,1.6,r+Vector2(-35,-30),2.0)
	var wa=_suche("wald");await _blick("04_wald_innen",wa,1.7,wa+Vector2(30,20),2.0)
	await _blick("05_jagdhuette",JAGD+Vector2(14,9),1.8,JAGD+Vector2(0,-3),2.0)
	await _blick("06_hanffeld_nah",HANF+Vector2(-25,47),1.8,HANF+Vector2(5,10),0.8)
	SUN.directional_shadow_max_distance=500.0
	await _blick("07_hanffeld_luft",HANF+Vector2(-120,130),70.0,HANF,0.0)
	var u=_suche("ufer");await _blick("08_seeufer",u,1.6,u+Vector2(30,30),0.5)
	var f=_suche("fels");await _blick("09_felshang",f+Vector2(-70,70),16.0,f,0.0)
	SUN.directional_shadow_max_distance=900.0
	await _blick("10_fahrt_hoehe",w+Vector2(-60,80),14.0,w+Vector2(150,-200),0.0)
