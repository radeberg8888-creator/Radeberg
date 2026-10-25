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
	var VH=load("res://scripts/vehicles.gd");var TU=load("res://scripts/tuning.gd")
	var PE=load("res://scripts/people.gd");var prng=RandomNumberGenerator.new();prng.seed=21
	var NPC=load("res://scripts/npc.gd")
	# ---- rechte Straßenseite: Häuser, dann die Tuning-Werkstatt
	var z=-150.0
	z=building("buildings/chicago",1,z,0.25)+2
	z=building("buildings/nyc",1,z,1.0,Vector3(0,0,-1))+2
	z=building("buildings/building",1,z,5.0)+2
	var gz=z+2.0
	_garage(Vector3(FX+9,0.15,gz),26.0)
	z=gz+30
	z=building("buildings/chicago",1,z,0.25)+2
	# ---- linke Straßenseite
	z=-150.0
	z=building("buildings/building",-1,z,5.0)+2
	z=building("buildings/nyc",-1,z,1.0)+2
	z=building("buildings/cityscene",-1,z,1.0,Vector3(1,0,0))+2
	z=building("buildings/chicago",-1,z,0.25)+2
	z=building("buildings/nyc",-1,z,1.0)+2
	# ---- Skyline: New-York-Viertel hinter der linken Häuserzeile
	var ny=gl("buildings/nycity");var nyw=Node3D.new();add_child(nyw);nyw.add_child(ny);var nab=F.aabb(nyw)
	ny.position=Vector3(-FX-60-nab.end.x,-nab.position.y+0.1,-nab.get_center().z)
	# ---- Bäume
	for zz in range(-140,140,18):
		for s in [-1,1]:
			if s>0 and zz>gz-6 and zz<gz+30:continue
			tree(Vector3(s*(AV+1.6),0.15,zz+s*4),rng_h())
	# ---- Bushaltestelle mit Bus
	_busstop(Vector3(-AV-1.2,0.15,-24))
	var bus=VH.make("bus");add_child(bus);bus.position=Vector3(-AV+1.6,0,-22);bus.rotation.y=0
	# ---- Verkehr auf beiden Spuren + parkende Autos
	var traffic=[["taxi",-3.8,-48.0,0.0],["polizei",3.8,4.0,PI],["trabant",-3.8,14.0,0.0],["audi_rs7",3.8,-30.0,PI],["bmw_m8",-3.8,40.0,0.0],
		["hudson",-AV+1.4,62.0,0.0],["porsche911",-3.8,-70.0,0.0],["feuerwehr",3.8,-62.0,PI],["rtw",-AV+1.5,-58.0,0.0],["lkw",3.8,88.0,PI],
		["bmw_e30",-AV+1.3,-6.0,0.0],["small_car",3.8,-12.0,PI],["audi_r8",-3.8,-100.0,0.0],["armored",3.8,30.0,PI],["mercedes",-AV+1.3,24.0,0.0],
		["taxi",3.8,60.0,PI],["bugatti",3.8,110.0,PI],["trabant",-AV+1.3,-38.0,0.0]]
	for t in traffic:
		var v=VH.make(t[0]);add_child(v);v.position=Vector3(t[1],0,t[2]);v.rotation.y=t[3]+(PI if v.get_meta("front",1.0)<0 else 0.0)
	# ---- Passanten
	var civ=["joe","woman","biker","daya","joe","woman","daya","police"]
	for i in 56:
		var b=civ[prng.randi()%civ.size()]
		var p=PE.make(b,prng);p.set_script(NPC);add_child(p)
		var side=1.0 if i%2==0 else -1.0;var lx=side*(AV+prng.randf_range(1.0,4.3));var pz=prng.randf_range(-90,90)
		if side>0 and pz>gz-4 and pz<gz+28:lx=side*(AV+prng.randf_range(1.0,3.0))
		p.position=Vector3(lx,0.15,pz);p.setup(lx,-140,140,i*17,"talk" if i%6==0 else "walk")
	for k in 4:   # Wartende an der Haltestelle
		var p=PE.make(civ[(k*3+1)%civ.size()],prng);add_child(p);p.position=Vector3(-AV-2.6-k*0.6,0.15,-26+k*1.1);p.rotation.y=PI*0.5;PE.play(p,["idle","talk","idle","shake"][k],prng.randf())
	var cop=PE.make("police",prng,{"mix":0.0,"hue":0.0,"sat":1.0,"val":1.0});add_child(cop);cop.position=Vector3(AV+1.0,0.15,6.5);cop.rotation.y=PI;PE.play(cop,"idle")
	# ---- Radeberger Altstadt als zweites Viertel daneben
	var old=Node3D.new();old.set_script(load("res://scripts/street.gd"));add_child(old);old.position=Vector3(260,0,0);old.build(7)
	for i in 30:
		var b=civ[prng.randi()%civ.size()];var p=PE.make(b,prng);p.set_script(NPC);add_child(p)
		var side=1.0 if i%2==0 else -1.0;var lx=260+side*(7+prng.randf_range(1.0,3.8));var pz=prng.randf_range(-60,60)
		p.position=Vector3(lx,0.15,pz);p.setup(lx,-90,90,500+i*13,"talk" if i%5==0 else "walk")
	for t in [["trabant",260-4.6,8.0,0.0],["taxi",260+4.6,-20.0,PI],["polizei",260-4.6,30.0,0.0],["bmw_e30",260+5.6,24.0,PI],["small_car",260-5.6,-36.0,0.0],["mercedes",260+5.6,44.0,PI]]:
		var v=VH.make(t[0]);add_child(v);v.position=Vector3(t[1],0,t[2]);v.rotation.y=t[3]+(PI if v.get_meta("front",1.0)<0 else 0.0)
	var cam=Camera3D.new();cam.near=0.05;cam.far=1500;add_child(cam)
	if not "--play" in args:
		var gx=FX+9
		var sh=load("res://scripts/shots.gd").new();add_child(sh)
		sh.setup([
			[Vector3(-AV-2.0,1.7,-60),Vector3(2,5,30),60.0],
			[Vector3(-AV+1.0,2.0,gz-8),Vector3(gx+4,3.5,gz+13),62.0],
			[Vector3(AV+1.5,1.5,gz+6),Vector3(gx+2,0.8,gz+18),55.0],
			[Vector3(2.5,1.6,-36),Vector3(-AV,1.5,-22),55.0],
			[Vector3(-1,1.4,-2),Vector3(0,1.0,30),55.0],
			[Vector3(70,85,-150),Vector3(10,0,10),55.0],
			[Vector3(260+9,1.7,-40),Vector3(260,4,30),60.0],
			[Vector3(AV+3.5,1.6,-80),Vector3(-60,30,40),62.0]],"stadt_"+mode)

# Tuning-Werkstatt von außen: Backsteinhalle mit drei Rolltoren, Leuchtschrift, getunte Autos auf dem Vorplatz
func _garage(p:Vector3,width:float):
	var b=Batch.new();var brick=Mats.bricks(0.45);var conc=Mats.pbr("concrete",0.4,Color(0.72,0.72,0.74))
	var D=18.0;var H=8.0;var x0=p.x;var z0=p.z
	b.box(conc,Vector3(FX,0.0,z0-2),Vector3(x0+D+2,0.16,z0+width+2))           # Vorplatz
	b.box(brick,Vector3(x0,0,z0),Vector3(x0+D,H,z0+0.6))
	b.box(brick,Vector3(x0,0,z0+width-0.6),Vector3(x0+D,H,z0+width))
	b.box(brick,Vector3(x0+D-0.6,0,z0),Vector3(x0+D,H,z0+width))
	b.box(Mats.flat(Color(0.2,0.2,0.22),0.7),Vector3(x0-0.2,H,z0-0.2),Vector3(x0+D+0.2,H+0.4,z0+width+0.2))
	var dark=Mats.flat(Color(0.03,0.03,0.035),0.9)
	# Fassade mit Toröffnungen
	var dw=5.2;var gap=(width-3*dw)/4.0
	var zz=z0
	for k in 4:
		b.box(brick,Vector3(x0,0,zz),Vector3(x0+0.6,H,zz+gap));zz+=gap
		if k<3:
			b.box(brick,Vector3(x0,4.6,zz),Vector3(x0+0.6,H,zz+dw))
			b.box(Mats.flat(Color(0.85,0.6,0.1),0.4,0.5),Vector3(x0-0.05,4.4,zz-0.1),Vector3(x0+0.05,4.6,zz+dw+0.1))
			zz+=dw
	b.box(dark,Vector3(x0+0.6,0.16,z0+0.6),Vector3(x0+D-0.6,H-0.1,z0+width-0.6))   # Innenraum dunkel
	b.box(Mats.flat(Color(0.95,0.75,0.1),0.5),Vector3(x0-0.6,0.16,z0-2),Vector3(x0-0.45,0.17,z0+width+2))
	b.commit(self)
	# Rolltore: zwei geschlossen, eines offen (Blick in die Halle)
	var sh=load("res://assets/props/polyhaven/rollershutter.glb")
	zz=z0+gap
	for k in 3:
		if k!=1:
			var r:Node3D=sh.instantiate();add_child(r)
			r.transform=Transform3D(Basis(Vector3.UP,-PI*0.5).scaled(Vector3(dw/5.1*1.0,4.4/1.85,1.0)),Vector3(x0-0.02,0.16,zz+dw*0.5))
		zz+=dw+gap
	# Leuchtschrift
	var lb=Label3D.new();lb.text="RADEBERG CUSTOMS";lb.font_size=220;lb.pixel_size=0.012;lb.modulate=Color(1,0.72,0.15);lb.outline_size=8;lb.outline_modulate=Color(0.2,0.08,0,1)
	add_child(lb);lb.position=Vector3(x0-0.1,H-1.3,z0+width*0.5);lb.rotation.y=-PI*0.5
	var lb2=Label3D.new();lb2.text="TUNING · LACK · FELGEN · NOS · BODYKITS";lb2.font_size=90;lb2.pixel_size=0.01;lb2.modulate=Color(0.95,0.95,0.92);lb2.outline_size=0
	add_child(lb2);lb2.position=Vector3(x0-0.1,H-2.4,z0+width*0.5);lb2.rotation.y=-PI*0.5
	for k in 6:
		var l=OmniLight3D.new();add_child(l);l.position=Vector3(x0-0.6,H-0.4,z0+2+k*(width-4)/5.0);l.light_color=Color(1,0.85,0.6);l.light_energy=1.2;l.omni_range=7
		var lamp=MeshInstance3D.new();lamp.mesh=BoxMesh.new();lamp.mesh.size=Vector3(0.4,0.15,0.3);add_child(lamp);lamp.position=l.position+Vector3(0.2,0.15,0)
		var em=StandardMaterial3D.new();em.emission_enabled=true;em.emission=Color(1,0.85,0.6);em.emission_energy_multiplier=4;lamp.material_override=em
	# Innen: Hebebühne und Licht hinter dem offenen Tor
	var il=OmniLight3D.new();add_child(il);il.position=Vector3(x0+6,5,z0+width*0.5);il.light_energy=2.5;il.omni_range=12;il.light_color=Color(0.95,0.97,1)
	# Reifenstapel
	for s in 4:
		for k in 4:
			var t=MeshInstance3D.new();t.mesh=CylinderMesh.new();t.mesh.top_radius=0.36;t.mesh.bottom_radius=0.36;t.mesh.height=0.26;add_child(t)
			t.position=Vector3(x0-1.4+(s%2)*0.8,0.3+k*0.28,z0+0.8+(s/2)*0.8);t.material_override=Mats.flat(Color(0.03,0.03,0.03),0.85)
	# getunte Autos auf dem Vorplatz
	var VH=load("res://scripts/vehicles.gd");var TU=load("res://scripts/tuning.gd")
	var tuned=[["jdm",{"front":4,"side":4,"rear":3,"spoiler":5,"widebody":1,"rim":3,"rim_size":3,"rim_color":"Gold","caliper":"Rot","neon":"Türkis"}],
		["supra",{"front":4,"side":4,"rear":4,"spoiler":4,"hood":1,"widebody":1,"paint":"Racing-Gelb","finish":"Perleffekt","rim":4,"rim_size":4,"rim_color":"Tiefschwarz","caliper":"Rot","neon":"Blau"}],
		["audi_r8",{"front":3,"side":3,"rear":3,"spoiler":3,"paint":"Lila","finish":"Perleffekt","rim":0,"rim_size":4,"rim_color":"Silber","rim_finish":"Chrom","caliper":"Gelb","neon":"Lila"}],
		["bmw_m8",{"front":2,"side":2,"rear":2,"spoiler":1,"paint":"Nachtblau","rim":6,"rim_size":5,"rim_color":"Gold","rim_finish":"Satin","caliper":"Blau","tint":2}]]
	for i in tuned.size():
		var v=VH.make(tuned[i][0]);add_child(v)
		var c=TU.default_cfg();for k in tuned[i][1]:c[k]=tuned[i][1][k]
		TU.apply(v,c)
		v.position=Vector3(x0-4.2-(i%2)*0.0,0.16,z0+3.5+i*5.6);v.rotation.y=-PI*0.5+0.35+(PI if v.get_meta("front",1.0)<0 else 0.0)

func _busstop(p:Vector3):
	var b=Batch.new();var steel=Mats.flat(Color(0.25,0.27,0.3),0.4,0.8);var glass=Mats.shop_glass()
	b.box(steel,p+Vector3(-1.6,0,-2.2),p+Vector3(-1.5,2.6,2.2))
	b.box(steel,p+Vector3(-1.8,2.6,-2.4),p+Vector3(0.2,2.75,2.4))
	for s in [-1,1]:b.box(steel,p+Vector3(-0.1,0,s*2.2-0.05),p+Vector3(0.0,2.6,s*2.2+0.05))
	b.box(glass,p+Vector3(-1.55,0.2,-2.15),p+Vector3(-1.5,2.55,2.15))
	b.box(Mats.flat(Color(0.35,0.22,0.12),0.7),p+Vector3(-1.45,0.45,-1.5),p+Vector3(-1.0,0.5,1.5))
	b.commit(self)
	var sign=Label3D.new();sign.text="H  Linie 7 · Bahnhof";sign.font_size=80;sign.pixel_size=0.006;sign.modulate=Color(0.05,0.35,0.15);add_child(sign);sign.position=p+Vector3(0.05,2.3,0);sign.rotation.y=PI*0.5

func rng_h()->float:return randf_range(8.0,11.0)
