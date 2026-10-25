extends Node3D
# Innenstadt-Vorschau: Allee mit fotorealistischen Sketchfab-Modellen (Gebäude, Autos, Menschen, Bäume, Waffen)
const F=preload("res://scripts/fit.gd")
const U=preload("res://scripts/anim_util.gd")
const Mats=preload("res://scripts/mats.gd")
const Batch=preload("res://scripts/batch.gd")
const AV:=8.0      # halbe Fahrbahnbreite
const WALK:=5.0    # Gehwegbreite
var FX:=AV+WALK
var walk_anim:Animation;var walk_skel:Skeleton3D;var walk_src:Node3D

func gl(d:String)->Node3D:
	var p="res://assets/"+d+".gltf" if d.get_file().contains("_rig") else "res://assets/"+d+"/"+d.get_file()+".gltf"
	if ResourceLoader.exists("res://assets/"+d+".glb"):p="res://assets/"+d+".glb"
	return load(p).instantiate()

# flache Bodenplatten/Schatten in Fahrzeugmodellen ausblenden
func hide_planes(n:Node3D):
	var tot=F.aabb(n);var mx=max(tot.size.x,tot.size.z)
	for m in n.find_children("*","MeshInstance3D",true,false):
		var a=F.rel_xf(m,n)*m.get_aabb()
		var nm=(m.name+" "+(m.mesh.surface_get_material(0).resource_name if m.mesh.get_surface_count()>0 and m.mesh.surface_get_material(0) else "")).to_lower()
		if (a.size.y<0.02*mx and max(a.size.x,a.size.z)>0.6*mx) or nm.contains("ground") or nm.contains("carshadow") or nm.ends_with(" floor"):m.visible=false

# Gebäude: Front (Richtung front im Modell) zur Straße drehen, Fassade bündig an x=±FX
func building(d:String,side:int,z0:float,scale:float,front:=Vector3(0,0,1))->float:
	var n=gl(d);var w=Node3D.new();add_child(w);w.add_child(n);n.scale=Vector3.ONE*scale
	var want=Vector3(-side,0,0)
	var ang=atan2(front.x,front.z);var angw=atan2(want.x,want.z)
	n.rotation.y=angw-ang
	var ab=F.aabb(w)
	var x=(FX-ab.position.x) if side>0 else (-FX-(ab.position.x+ab.size.x))
	n.position=Vector3(x,-ab.position.y,z0-ab.position.z)
	return z0+ab.size.z

func car(d:String,pos:Vector3,yaw:float,length:float,axis:int,tint:=Color(1,1,1))->Node3D:
	var n=gl(d);hide_planes(n)
	var w=F.place(n,length,axis);add_child(w);w.position=pos;w.rotation.y=yaw+(PI*0.5 if axis==0 else 0.0)
	if tint!=Color(1,1,1):
		for m in n.find_children("*","MeshInstance3D",true,false):
			for i in m.mesh.get_surface_count():
				var mt=m.get_active_material(i)
				if mt is BaseMaterial3D:
					var dm=mt.duplicate();dm.albedo_color=mt.albedo_color*tint;m.set_surface_override_material(i,dm)
	return w

func person(d:String,pos:Vector3,yaw:float,h:float,phase:float)->Node3D:
	var n=gl(d);var w=F.place(n,h);add_child(w);w.position=pos;w.rotation.y=yaw
	var sk=U.find_skel(n)
	if sk:
		var old=n.find_child("AnimationPlayer",true,false);if old:old.stop()
		U.play(n,U.retarget_world(walk_anim,walk_skel,walk_src,sk,n),"walk",phase)
	for m in n.find_children("*","MeshInstance3D",true,false):m.extra_cull_margin=2.0
	return w

func tree(pos:Vector3,h:=9.0):
	var n=gl("props/tree");var w=F.place(n,h);add_child(w);w.position=pos;w.rotation.y=randf()*TAU

# Waffe flach hinlegen: längste Achse -> x, dünnste -> y (liegt auf dem Tisch)
func weapon(d:String,len:float,_axis:int,pos:Vector3,rot:Vector3)->Node3D:
	var n=gl(d);var ab=F.aabb(n);var sz=ab.size
	var ax=[0,1,2];ax.sort_custom(func(a,b):return sz[a]>sz[b])
	var L=ax[0];var T=ax[2];var M=ax[1]
	var e=[Vector3(1,0,0),Vector3(0,1,0),Vector3(0,0,1)]
	# Basis, die Modellachse L auf x, T auf y, M auf z abbildet
	var B=Basis(e[L],e[T],e[M]).transposed()
	if B.determinant()<0:B=Basis(e[L],e[T],-e[M]).transposed()
	var holder=Node3D.new();holder.add_child(n);n.transform=Transform3D(B,Vector3())
	var w=F.place(holder,len,0);add_child(w);w.position=pos;w.rotation_degrees=Vector3(0,rot.y,0);return w

func _ground(L:float):
	var b=Batch.new()
	b.box(Mats.pbr("asphalt",0.18),Vector3(-AV,-0.2,-L),Vector3(AV,0,L))
	for s in [-1,1]:
		b.box(Mats.pbr("pavers",0.45),Vector3(min(s*AV,s*(FX+40)),-0.2,-L),Vector3(max(s*AV,s*(FX+40)),0.15,L))
		b.box(Mats.pbr("concrete",0.6,Color(0.86,0.85,0.82)),Vector3(min(s*AV,s*(AV+0.25)),-0.2,-L),Vector3(max(s*AV,s*(AV+0.25)),0.16,L))
	b.commit(self)
	var paint=Mats.flat(Color(0.9,0.85,0.4),0.5);var mb=Batch.new()
	for s in [-1,1]:mb.box(paint,Vector3(s*0.15-0.06,0.001,-L),Vector3(s*0.15+0.06,0.012,L))
	var white=Mats.flat(Color(0.88,0.88,0.85),0.5);var z=-L
	while z<L:
		for s in [-1,1]:mb.box(white,Vector3(s*AV*0.5-0.07,0.001,z),Vector3(s*AV*0.5+0.07,0.012,z+3))
		z+=9
	mb.commit(self,false)

func _ready():
	randomize();seed(4)
	var args=OS.get_cmdline_user_args();var mode="sunset" if "--sunset" in args else "day"
	load("res://scripts/env.gd").make(self,mode)
	walk_src=load("res://assets/animations/walking.glb").instantiate();add_child(walk_src);walk_src.visible=false
	var ap:AnimationPlayer=walk_src.find_child("AnimationPlayer",true,false);ap.stop();walk_anim=ap.get_animation(ap.get_animation_list()[0]);walk_skel=U.find_skel(walk_src)
	_ground(260)
	# rechte Straßenseite
	var z=-150.0
	z=building("buildings/chicago",1,z,0.25)+2
	z=building("buildings/nyc",1,z,1.0,Vector3(0,0,-1))+2
	z=building("buildings/building",1,z,5.0)+2
	z=building("buildings/chicago",1,z,0.25)+2
	# linke Straßenseite
	z=-150.0
	z=building("buildings/building",-1,z,5.0)+2
	z=building("buildings/nyc",-1,z,1.0)+2
	z=building("buildings/cityscene",-1,z,1.0,Vector3(1,0,0))+2
	z=building("buildings/chicago",-1,z,0.25)+2
	# Bäume und Laternen
	var lantern=load("res://assets/props/Lantern.glb") if ResourceLoader.exists("res://assets/props/Lantern.glb") else null
	for zz in range(-140,140,18):
		for s in [-1,1]:
			tree(Vector3(s*(AV+1.6),0.15,zz+s*4),rng_h())
	# Autos
	# Fahrzeuge (Bibliothek mit Varianten)
	var VH=load("res://scripts/vehicles.gd")
	var traffic=[["taxi",-3.8,-8.0,0.0],["polizei",3.8,4.0,PI],["trabant",-AV+1.3,-20.0,0.0],["audi_rs7",AV-1.3,18.0,PI],["bmw_m8",-3.8,24.0,0.0],
		["hudson",AV-1.4,-16.0,PI],["porsche911",-AV+1.3,10.0,0.0],["feuerwehr",3.8,-40.0,PI],["rtw",-AV+1.5,40.0,0.0],["lkw",3.8,58.0,PI],
		["bmw_e30",-AV+1.3,-34.0,0.0],["small_car",AV-1.3,-28.0,PI],["audi_r8",-3.8,-52.0,0.0],["armored",AV-1.5,34.0,PI],["dodge",-AV+1.4,62.0,0.0],["trabant",AV-1.3,48.0,PI]]
	for t in traffic:
		var v=VH.make(t[0]);add_child(v);v.position=Vector3(t[1],0,t[2]);v.rotation.y=t[3]
	# Passanten: viele verschiedene Menschen, die laufen, stehen und reden
	var PE=load("res://scripts/people.gd");var prng=RandomNumberGenerator.new();prng.seed=21
	var NPC=load("res://scripts/npc.gd")
	for i in 44:
		var b=PE.CIVIL[prng.randi()%PE.CIVIL.size()]
		var p=PE.make(b,prng);p.set_script(NPC);add_child(p)
		var side=1.0 if i%2==0 else -1.0;var lx=side*(AV+prng.randf_range(1.2,4.2));var pz=prng.randf_range(-70,70)
		p.position=Vector3(lx,0.15,pz)
		p.setup(lx,-120,120,i*17,"talk" if i%7==0 else "walk")
	# Gesprächsgruppe vor der Bar
	for k in 3:
		var p=PE.make(PE.CIVIL[(k*2+1)%PE.CIVIL.size()],prng);add_child(p);p.position=Vector3(AV+3.0+k*0.7,0.15,22+(k%2)*0.8);p.rotation.y=-PI*0.5+k*0.9
		PE.play(p,["talk","shake","idle"][k],prng.randf())
	var cop=PE.make("police",prng,{"mix":0.0,"hue":0.0,"sat":1.0,"val":1.0});add_child(cop);cop.position=Vector3(AV+1.0,0.15,6.5);cop.rotation.y=PI;PE.play(cop,"idle")
	# Waffen auf einem Tisch vor der Bar
	var top=MeshInstance3D.new();top.mesh=BoxMesh.new();top.mesh.size=Vector3(1.0,0.05,2.0);add_child(top);top.position=Vector3(AV+3.6,1.05,30)
	var felt=StandardMaterial3D.new();felt.albedo_color=Color(0.32,0.22,0.14);felt.roughness=0.9;top.material_override=felt
	for lx in [-0.42,0.42]:
		for lz in [-0.9,0.9]:
			var leg=MeshInstance3D.new();leg.mesh=BoxMesh.new();leg.mesh.size=Vector3(0.05,0.9,0.05);add_child(leg);leg.position=Vector3(AV+3.6+lx,0.6,30+lz);leg.material_override=Mats.flat(Color(0.2,0.2,0.21),0.4,0.9)
	var y=1.08
	weapon("weapons/ar15",0.92,0,Vector3(AV+3.75,y,29.7),Vector3(0,90,0))
	weapon("weapons/mp5",0.62,2,Vector3(AV+3.35,y,30.0),Vector3(0,80,0))
	weapon("weapons/pistol_tac",0.24,2,Vector3(AV+3.8,y,30.65),Vector3(0,110,0))
	weapon("weapons/m1911",0.22,2,Vector3(AV+3.4,y,30.75),Vector3(0,60,0))
	weapon("weapons/rifle",1.23,0,Vector3(AV+3.95,y,30.0),Vector3(0,90,0))
	weapon("weapons/machete",0.75,1,Vector3(AV+3.45,y,29.2),Vector3(0,100,0))
	weapon("weapons/pistol",0.21,0,Vector3(AV+3.85,y,30.25),Vector3(0,80,0))
	# Küche (Innenraum der Wohnung) abseits
	var k=gl("interiors/kitchen");var kw=Node3D.new();add_child(kw);kw.add_child(k);k.scale=Vector3.ONE*0.01;kw.position=Vector3(600,0,0)
	var kab=F.aabb(kw);k.position=-kab.position
	for p in [Vector3(1.2,2.1,1.6),Vector3(2.4,2.1,3.2)]:
		var l=OmniLight3D.new();add_child(l);l.position=Vector3(600,0,0)+p;l.omni_range=6;l.light_energy=1.2;l.light_color=Color(1,0.9,0.78);l.shadow_enabled=true
	var cam=Camera3D.new();cam.near=0.05;cam.far=900;add_child(cam)
	if not "--play" in args:
		var sh=load("res://scripts/shots.gd").new();add_child(sh)
		sh.setup([
			[Vector3(AV+4.0,1.7,-30),Vector3(0,6,40),62.0],
			[Vector3(-AV+2,1.4,-14),Vector3(AV-1.4,0.9,-14),55.0],
			[Vector3(-1.5,1.3,-1),Vector3(-AV+1.3,0.6,-6),50.0],
			[Vector3(AV+0.8,1.6,-17),Vector3(AV+3,1.1,-4),45.0],
			[Vector3(AV+2.5,1.9,30.0),Vector3(AV+3.6,1.05,30.0),48.0],
			[Vector3(600.5,1.6,0.6),Vector3(600,0,0)+kab.size*Vector3(0.6,0.35,0.7),70.0],
			[Vector3(-30,45,-90),Vector3(0,0,0),55.0]],mode)

func rng_h()->float:return randf_range(8.0,11.0)
