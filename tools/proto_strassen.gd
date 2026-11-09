extends SceneTree
# PROTOTYP (nicht im Spiel): Bergstraße mit Serpentine, Übergang Asphalt -> Schotter -> Sandweg,
# angebundener Abzweig, schräge Bankette statt harter Kante, Gelände sauber unter der Fahrbahn,
# Auto mit Staubwolke auf Schotter. Rendert Bilder nach /home/claude/work/proto_strasse/.
const OUT="/home/claude/work/proto_strasse/"
var rng=RandomNumberGenerator.new()
var W:Node3D
var haupt:=[]    # Abtastpunkte der Hauptstraße: {p:Vector2, y, t:Vector2, s, art, w}
var neben:=[]

func gelaende_roh(x:float,z:float)->float:
	return 16.0*sin(x*0.011+0.6)*cos(z*0.009)+28.0*exp(-((x+10.0)*(x+10.0)+(z+30.0)*(z+30.0))/9000.0)+3.0*sin(x*0.05)*sin(z*0.043)+12.0

# ---------- Straßenverlauf ----------
func catmull(P:Array,schritt:float)->Array:
	var out=[]
	for i in P.size()-1:
		var p0=P[max(i-1,0)];var p1=P[i];var p2=P[i+1];var p3=P[min(i+2,P.size()-1)]
		var n=int(ceil(p1.distance_to(p2)/schritt))
		for k in n:
			var t=float(k)/n;var t2=t*t;var t3=t2*t
			out.append(0.5*((2.0*p1)+(-p0+p2)*t+(2.0*p0-5.0*p1+4.0*p2-p3)*t2+(-p0+3.0*p1-3.0*p2+p3)*t3))
	out.append(P[P.size()-1]);return out
func strasse(P:Array,arten:Callable,breite:Callable,start_y=null)->Array:
	var pts=catmull(P,1.0);var R=[];var s=0.0
	for i in pts.size():
		if i>0:s+=pts[i].distance_to(pts[i-1])
		R.append({"p":pts[i],"s":s,"y":gelaende_roh(pts[i].x,pts[i].y)})
	var L=s
	# Längsprofil: glätten (±20 m) und Steigung begrenzen (10 %)
	var Y=[];for e in R:Y.append(e.y)
	var G=[]
	for i in R.size():
		var a=0.0;var n=0
		for k in range(max(0,i-20),min(R.size(),i+21)):a+=Y[k];n+=1
		G.append(a/n)
	for i in range(1,G.size()):G[i]=clamp(G[i],G[i-1]-0.1,G[i-1]+0.1)
	for i in range(G.size()-2,-1,-1):G[i]=clamp(G[i],G[i+1]-0.1,G[i+1]+0.1)
	if start_y!=null:
		for i in min(30,G.size()):G[i]=lerp(start_y,G[i],float(i)/30.0)
	for i in R.size():
		var e=R[i];e.y=G[i]
		e.t=(R[min(i+1,R.size()-1)].p-R[max(i-1,0)].p).normalized()
		e.art=arten.call(e.s/L);e.w=breite.call(e.s/L)
	return R

# ---------- Texturen ----------
func tex(art:String)->ImageTexture:
	var N=256;var img=Image.create(N,N,false,Image.FORMAT_RGB8);var r=RandomNumberGenerator.new();r.seed=art.hash()
	for y in N:
		for x in N:
			var c:Color
			match art:
				"asphalt":var v=0.33+r.randf()*0.06;c=Color(v,v,v*1.03)
				"schotter":var v=r.randf();c=Color(0.55,0.5,0.44)*(0.85+v*0.25);c.a=1
				"sand":var v=r.randf();c=Color(0.8,0.69,0.5)*(0.92+v*0.12)
			img.set_pixel(x,y,c)
	if art=="schotter":
		for k in 900:
			var p=Vector2i(r.randi()%N,r.randi()%N);var g=r.randf_range(0.35,0.75)
			for dy in 3:
				for dx in 3:img.set_pixel((p.x+dx)%N,(p.y+dy)%N,Color(g,g*0.96,g*0.9))
	if art=="sand":
		# zwei Fahrspuren (dunkler, verdichtet), Mitte mit Grasbüscheln
		for y in N:
			for x in N:
				var u=float(x)/N
				var spur=exp(-pow((u-0.27)/0.07,2))+exp(-pow((u-0.73)/0.07,2))
				var c=img.get_pixel(x,y).darkened(spur*0.22)
				if abs(u-0.5)<0.09 and r.randf()<0.35:c=Color(0.45,0.62,0.3)
				img.set_pixel(x,y,c)
	if art=="asphalt":
		for k in 40:
			var p=Vector2i(r.randi()%N,r.randi()%N);var L=r.randi_range(10,40)
			for i in L:img.set_pixel((p.x+i)%N,(p.y+int(i*0.3))%N,Color(0.18,0.18,0.19))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
func mat(art:String)->StandardMaterial3D:
	var m=StandardMaterial3D.new();m.albedo_texture=tex(art);m.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON;m.roughness=0.95
	m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

# ---------- Gelände mit Einschnitt/Damm ----------
func naechst(p:Vector2)->Array:
	var best=null;var bd=1e9
	for R in [haupt,neben]:
		for i in range(0,R.size(),2):
			var d=R[i].p.distance_to(p)
			if d<bd:bd=d;best=R[i]
	return [best,bd]
func je_strasse(p:Vector2)->Array:   # nächster Punkt jeder Straße: [[punkt,abstand],...]
	var out=[]
	for R in [haupt,neben]:
		var best=null;var bd=1e9
		for i in R.size():
			var d=R[i].p.distance_to(p)
			if d<bd:bd=d;best=R[i]
		out.append([best,bd])
	return out
func gelaende_bauen():
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var N=200;var S=2.0;var X0=-200.0;var Z0=-200.0
	var H=[];var C=[]
	for k in N+1:
		for i in N+1:
			var x=X0+i*S;var z=Z0+k*S;var h=gelaende_roh(x,z)
			var alle=je_strasse(Vector2(x,z))
			var e=alle[0] if alle[0][1]<=alle[1][1] else alle[1];var r=e[0];var d:float=e[1]
			var band=r.w+3.2   # Fahrbahn + Bankett: flach unter Straßenhöhe
			var dh=abs(h-r.y);var R=band+clamp(dh*2.0+6.0,8.0,45.0)
			var farbe=Color(0.42,0.6,0.3).lerp(Color(0.5,0.64,0.32),0.5+0.5*sin(x*0.03+z*0.02))
			# unter JEDER Fahrbahn in Reichweite: Gelände höchstens auf deren Höhe (Minimum) -> nie Gras im Asphalt
			var unter=INF
			for q in alle:
				if q[1]<=q[0].w+3.2:unter=min(unter,q[0].y-0.15)
			if unter<INF:h=unter
			elif d<R:
				var t=smoothstep(band,R,d);h=lerp(r.y-0.1,h,t)
				farbe=farbe.lerp(Color(0.6,0.55,0.42),(1.0-t)*clamp(dh/6.0,0.0,0.7))   # Böschung: Erde
			if h>34.0:farbe=farbe.lerp(Color(0.78,0.72,0.55),clamp((h-34.0)/8.0,0,0.6))
			H.append(h);C.append(farbe)
	for k in N:
		for i in N:
			var a=k*(N+1)+i;var b=a+1;var c=a+N+1;var d=c+1
			for v in [a,b,c,b,d,c]:
				var x=X0+(v%(N+1))*S;var z=Z0+(v/(N+1))*S
				st.set_color(C[v]);st.add_vertex(Vector3(x,H[v],z))
	st.generate_normals()
	var m=StandardMaterial3D.new();m.vertex_color_use_as_albedo=true;m.vertex_color_is_srgb=true;m.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON;m.roughness=1.0
	var mi=MeshInstance3D.new();mi.mesh=st.commit();mi.material_override=m;W.add_child(mi)

# ---------- Fahrbahn-Bänder ----------
func haupt_hoehe(q:Vector2)->float:   # Fahrbahnhöhe der Hauptstraße genau an dieser Stelle (INF = nicht drauf)
	var best=null;var bd=1e9
	for e in haupt:
		var d=e.p.distance_to(q)
		if d<bd:bd=d;best=e
	return best.y if bd<best.w+0.4 else INF
func band(R:Array,von:float,bis:float,art:String,y_off:float,w_fak:float,zacken:=false):
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var Lp=[];var Rp=[];var V=[]
	for e in R:
		var f=e.s/R[R.size()-1].s
		if f<von or f>bis:continue
		var n=Vector2(-e.t.y,e.t.x);var w=e.w*w_fak
		var wl=w;var wr=w
		if zacken:   # ausgefranster Asphaltrand im Übergang
			var z=clamp((f-von)/(bis-von),0,1)
			wl=w*clamp(1.0-z*(0.55+0.45*sin(e.s*0.9)),0.0,1.0);wr=w*clamp(1.0-z*(0.55+0.45*sin(e.s*0.7+2.0)),0.0,1.0)
		var a3=Vector3(e.p.x+n.x*wl,e.y+y_off,e.p.y+n.y*wl);var b3=Vector3(e.p.x-n.x*wr,e.y+y_off,e.p.y-n.y*wr)
		if R==neben:   # Seitenweg: auf der Hauptfahrbahn immer unter deren Asphalt
			for v in [a3,b3]:
				var hh=haupt_hoehe(Vector2(v.x,v.z))
				if hh<INF:v.y=min(v.y,hh-0.03)
			a3.y=min(a3.y,haupt_hoehe(Vector2(a3.x,a3.z))-0.03);b3.y=min(b3.y,haupt_hoehe(Vector2(b3.x,b3.z))-0.03)
		Lp.append(a3);Rp.append(b3);V.append(e.s/4.0)
	for i in Lp.size()-1:
		for q in [[Lp[i],0.0,V[i]],[Rp[i],1.0,V[i]],[Lp[i+1],0.0,V[i+1]],[Lp[i+1],0.0,V[i+1]],[Rp[i],1.0,V[i]],[Rp[i+1],1.0,V[i+1]]]:
			st.set_normal(Vector3.UP);st.set_uv(Vector2(q[1],q[2]));st.add_vertex(q[0])
	var mi=MeshInstance3D.new();mi.mesh=st.commit();mi.material_override=mat(art);W.add_child(mi)
	mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # Fahrbahn wirft keinen Schatten (sonst Zacken am Rand)
	return mi
func bankett(R:Array,andere:Array=[]):
	# schräger Rand: von der Fahrbahnkante 2,5 m nach außen bis knapp unter die Geländeoberfläche
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sd in [1,-1]:
		for i in R.size()-1:
			# Bankett nicht in eine andere Fahrbahn hinein (Einmündung)
			var drin=false
			for o in andere:
				for k in range(0,o.size(),2):
					if o[k].p.distance_to(R[i].p)<o[k].w+0.3:drin=true;break
				if drin:break
			if drin:continue
			var A=[];for e in [R[i],R[i+1]]:
				var n=Vector2(-e.t.y,e.t.x)*sd
				var innen=e.p+n*(e.w-0.05);var aussen=e.p+n*(e.w+2.6)
				A.append([Vector3(innen.x,e.y+0.03,innen.y),Vector3(aussen.x,e.y-0.35,aussen.y)])
			var kies=Color(0.62,0.58,0.5);var gras=Color(0.46,0.62,0.31)
			var reihe=[[A[0][0],kies],[A[0][1],gras],[A[1][0],kies],[A[1][0],kies],[A[0][1],gras],[A[1][1],gras]]
			if sd<0:reihe=[[A[0][0],kies],[A[1][0],kies],[A[0][1],gras],[A[1][0],kies],[A[1][1],gras],[A[0][1],gras]]
			for q in reihe:st.set_normal(Vector3.UP);st.set_color(q[1]);st.add_vertex(q[0])
	var m=StandardMaterial3D.new();m.vertex_color_use_as_albedo=true;m.vertex_color_is_srgb=true;m.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON;
	var mi=MeshInstance3D.new();mi.mesh=st.commit();mi.material_override=m;W.add_child(mi)
	mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func mittellinie(R:Array,bis:float):
	var m=StandardMaterial3D.new();m.albedo_color=Color(0.95,0.8,0.15);m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	for e in R:
		if e.s/R[R.size()-1].s>bis:break
		if fmod(e.s,9.0)<1.0:
			var b=MeshInstance3D.new();var bm=BoxMesh.new();bm.size=Vector3(0.15,0.02,2.8);b.mesh=bm;b.material_override=m;b.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;W.add_child(b)
			b.position=Vector3(e.p.x,e.y+0.075,e.p.y);b.rotation.y=atan2(e.t.x,e.t.y)

# ---------- Deko ----------
func baum(p:Vector2,h:float):
	var y=gelaende_roh(p.x,p.y)
	var e=naechst(p)
	if e[1]<e[0].w+4.0:return
	if e[1]<e[0].w+30.0:y=lerp(e[0].y-0.1,y,smoothstep(e[0].w+2.6,e[0].w+30.0,e[1]))
	var st=MeshInstance3D.new();var cy=CylinderMesh.new();cy.top_radius=0.15;cy.bottom_radius=0.22;cy.height=h*0.4;st.mesh=cy;W.add_child(st);st.position=Vector3(p.x,y+h*0.2,p.y)
	var mr=StandardMaterial3D.new();mr.albedo_color=Color(0.4,0.26,0.15);st.material_override=mr
	var k=MeshInstance3D.new();var mg=StandardMaterial3D.new();mg.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON
	if rng.randf()<0.5:
		var c=CylinderMesh.new();c.top_radius=0;c.bottom_radius=h*0.3;c.height=h*0.8;c.radial_segments=8;k.mesh=c;mg.albedo_color=Color(0.2,0.45,0.25);k.position=Vector3(p.x,y+h*0.7,p.y)
	else:
		var sp=SphereMesh.new();sp.radius=h*0.28;sp.height=h*0.5;k.mesh=sp;mg.albedo_color=Color(0.35,0.6,0.25);k.position=Vector3(p.x,y+h*0.62,p.y)
	k.material_override=mg;W.add_child(k)
func huette(p:Vector2,yaw:float):
	var y=naechst(p)[0].y
	var h=Node3D.new();W.add_child(h);h.position=Vector3(p.x,y-0.1,p.y);h.rotation.y=yaw
	var holz=StandardMaterial3D.new();holz.albedo_color=Color(0.5,0.36,0.22);holz.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON
	var dach=StandardMaterial3D.new();dach.albedo_color=Color(0.35,0.3,0.28)
	var b=MeshInstance3D.new();var bm=BoxMesh.new();bm.size=Vector3(6,3,5);b.mesh=bm;b.material_override=holz;h.add_child(b);b.position.y=1.5
	var d=MeshInstance3D.new();var pm=PrismMesh.new();pm.size=Vector3(6.6,1.8,5.6);d.mesh=pm;d.material_override=dach;h.add_child(d);d.position.y=3.9

# ---------- Staub ----------
func staub(an:Node3D,menge:int)->CPUParticles3D:
	var p=CPUParticles3D.new();an.add_child(p)
	p.amount=menge;p.lifetime=2.4;p.local_coords=false;p.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX;p.emission_box_extents=Vector3(0.9,0.1,0.3)
	p.direction=Vector3(0,0.6,-1);p.spread=35.0;p.initial_velocity_min=1.0;p.initial_velocity_max=3.0;p.gravity=Vector3(0,0.35,0)
	p.damping_min=1.0;p.damping_max=2.0;p.scale_amount_min=1.2;p.scale_amount_max=3.2
	var kurve=Curve.new();kurve.add_point(Vector2(0,0.3));kurve.add_point(Vector2(0.3,1.0));kurve.add_point(Vector2(1,1.6));p.scale_amount_curve=kurve
	var grad=Gradient.new();grad.set_color(0,Color(0.82,0.72,0.55,0.75));grad.set_color(1,Color(0.85,0.78,0.65,0.0));p.color_ramp=grad
	var sm=SphereMesh.new();sm.radius=0.5;sm.height=1.0;sm.radial_segments=8;sm.rings=4
	var m=StandardMaterial3D.new();m.vertex_color_use_as_albedo=true;m.vertex_color_is_srgb=true;m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material=m;p.mesh=sm;p.position=Vector3(0,0.3,-2.2)
	return p

func _init():
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	rng.seed=5
	W=Node3D.new();root.add_child(W)
	var we=WorldEnvironment.new();var env=Environment.new()
	var sky=Sky.new();var ps=ProceduralSkyMaterial.new();ps.sky_top_color=Color(0.32,0.55,0.85);ps.sky_horizon_color=Color(0.72,0.82,0.92);ps.ground_horizon_color=Color(0.72,0.82,0.92);sky.sky_material=ps
	env.background_mode=Environment.BG_SKY;env.sky=sky;env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color(0.6,0.65,0.75);env.ambient_light_energy=0.45
	env.tonemap_mode=Environment.TONE_MAPPER_LINEAR;env.fog_enabled=true;env.fog_density=0.0012;env.fog_light_color=Color(0.75,0.83,0.92)
	we.environment=env;W.add_child(we)
	var sun=DirectionalLight3D.new();W.add_child(sun);sun.rotation_degrees=Vector3(-48,-35,0);sun.shadow_enabled=true;sun.light_energy=1.0
	sun.directional_shadow_max_distance=250.0
	# Hauptstraße: Asphalt (0–40 %), Übergang (40–47 %), Schotter (47–75 %), Sandweg (ab 75 %)
	var art=func(f):return "asphalt" if f<0.4 else ("uebergang" if f<0.47 else ("schotter" if f<0.75 else "sand"))
	var br=func(f):return 3.4 if f<0.4 else lerp(3.4,2.7,clamp((f-0.4)/0.07,0,1)) if f<0.75 else lerp(2.7,1.9,clamp((f-0.75)/0.05,0,1))
	haupt=strasse([Vector2(-195,150),Vector2(-120,120),Vector2(-60,70),Vector2(-30,10),Vector2(-70,-30),Vector2(-40,-70),Vector2(20,-60),Vector2(60,-10),Vector2(110,-40),Vector2(140,-110),Vector2(195,-160)],art,br)
	# Abzweig (Schotter) vom Asphaltstück zur Hütte – setzt auf Straßenhöhe an
	var ab=haupt[int(haupt.size()*0.18)]
	var an=ab.p
	var nb=strasse([an,an+Vector2(-ab.t.y,ab.t.x)*-12.0,an+Vector2(-ab.t.y,ab.t.x)*-30.0,Vector2(-150,40),Vector2(-160,-20)],func(f):return "schotter",func(f):return 2.4,ab.y)
	for e in nb:
		var dd=e.p.distance_to(ab.p)
		if dd<ab.w+2.0:e.y=lerp(ab.y,e.y,smoothstep(ab.w,ab.w+2.0,dd))   # setzt auf Straßenhöhe an
	neben=nb
	for k in 8:print("DBG neben ",k," p=",nb[k].p.snapped(Vector2(0.1,0.1))," y=",snapped(nb[k].y,0.01)," abst_haupt=",snapped(nb[k].p.distance_to(ab.p),0.1))
	print("DBG ab.y=",ab.y," w=",ab.w)
	gelaende_bauen()
	band(haupt,0.0,0.4,"asphalt",0.04,1.0,false).name="Asphalt"
	band(haupt,0.395,0.47,"asphalt",0.045,1.0,true)
	band(haupt,0.38,0.8,"schotter",0.02,1.0)
	band(haupt,0.75,1.0,"sand",0.02,1.0)
	band(neben,0.0,1.0,"schotter",0.025,1.0)
	bankett(haupt);bankett(neben,[haupt])
	mittellinie(haupt,0.38)
	huette(Vector2(-162,-32),0.3)
	for k in 260:baum(Vector2(rng.randf_range(-195,195),rng.randf_range(-195,195)),rng.randf_range(5,9))
	# Auto auf Schotter mit Staubwolke: über einige Sekunden die Strecke entlang bewegen
	var auto=load("res://assets/cache/autos/c_e30_silber.scn").instantiate();W.add_child(auto)
	var st=staub(auto,70)
	var cam=Camera3D.new();W.add_child(cam);cam.fov=60;cam.far=2000;cam.current=true
	var i0=int(haupt.size()*0.52)
	for f in 150:
		var e=haupt[i0+f/2]
		auto.position=Vector3(e.p.x,e.y+0.04,e.p.y)+Vector3(-e.t.y,0,e.t.x)*0.0;auto.rotation.y=atan2(e.t.x,e.t.y)
		await process_frame
	var e=haupt[i0+75];var fw=Vector3(e.t.x,0,e.t.y);var q=Vector3(-e.t.y,0,e.t.x)
	cam.global_position=auto.global_position+fw*9.0+q*5.5+Vector3(0,2.6,0);cam.look_at(auto.global_position-fw*5.0+Vector3(0,1.0,0))
	await _bild("5_staub_schotter")
	# Ansichten
	var ansichten=[
		["1_uebersicht",Vector3(-40,130,190),Vector3(-10,10,-20)],
		["2_uebergang_asphalt_schotter",null,0.385],
		["3_sandweg",null,0.83],
		["4_serpentine_boeschung",Vector3(-95,30,-45),Vector3(-50,14,-35)],
		["6_abzweig",null,0.155],
		["7_rand_nah",null,0.25],
	]
	for a in ansichten:
		if a[1]==null:
			var k=haupt[int(haupt.size()*a[2])];var t3=Vector3(k.t.x,0,k.t.y)
			cam.global_position=Vector3(k.p.x,k.y+1.7,k.p.y)+Vector3(-k.t.y,0,k.t.x)*1.2
			if a[0]=="6_abzweig":
				var z=haupt[int(haupt.size()*0.18)];cam.global_position=Vector3(z.p.x,z.y+4.5,z.p.y)+Vector3(-z.t.y,0,z.t.x)*12.0-t3*14.0
				cam.look_at(Vector3(z.p.x,z.y,z.p.y)-Vector3(-z.t.y,0,z.t.x)*12.0)
			elif a[0].begins_with("7_"):
				var q3=Vector3(-k.t.y,0,k.t.x);cam.global_position=Vector3(k.p.x,k.y+1.4,k.p.y)+q3*1.5
				cam.look_at(Vector3(k.p.x,k.y,k.p.y)+t3*12.0+q3*k.w*1.3)
			elif a[0].begins_with("2_"):
				cam.global_position+=Vector3(0,2.2,0);var z2=haupt[int(haupt.size()*0.43)]
				cam.look_at(Vector3(z2.p.x,z2.y,z2.p.y))
			else:cam.look_at(cam.global_position+t3*30.0+Vector3(0,-1.6,0))
		else:cam.global_position=a[1];cam.look_at(a[2])
		await _bild(a[0])
	quit()

func _bild(n:String):
	for k in 4:await process_frame
	root.get_viewport().get_texture().get_image().save_png(OUT+n+".png");print("BILD ",n)
