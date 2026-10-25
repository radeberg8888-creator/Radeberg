extends Node3D
# Innenstadt Radeberg (sauberer Neuaufbau)
#  - Straße mit 2 Fahrspuren + Parkstreifen, Bordstein, Gehwege
#  - geschlossene Häuserzeilen (nur vollständige Modelle, Bodenplatten der Modelle entfernt, Wände beidseitig)
#  - Bäume in Baumscheiben, eigene Straßenlaternen, Bushaltestelle mit Busbucht
#  - Tuning-Werkstatt mit echten Rolltoren (hochfahrend) und sichtbarer Halle
# Startoptionen: -- --qa (nur Bauten, Prüfkameras)  -- --tor (Werkstatt-Tor-Animation)  sonst Übersichtsbilder
const F=preload("res://scripts/fit.gd")
const U=preload("res://scripts/anim_util.gd")
const Mats=preload("res://scripts/mats.gd")
const Batch=preload("res://scripts/batch.gd")
const TOR=preload("res://scripts/rolltor.gd")
const AV:=7.5        # halbe Fahrbahnbreite (2 Spuren + 2 Parkstreifen)
const WALK:=5.5      # Gehwegbreite
const L:=130.0       # halbe Straßenlänge
var FX:=AV+WALK
var args:=[]
var shots:=[]
var garage_doors:=[]
var gz:=0.0;var gx:=0.0;var gw:=26.0
var footprints:=[]
var _doors_z_cache:=[]

func gl(d:String)->Node3D:
	var p="res://assets/"+d+"/"+d.get_file()+".gltf"
	if ResourceLoader.exists("res://assets/"+d+".glb"):p="res://assets/"+d+".glb"
	return load(p).instantiate()

# ---------------- Gebäude ----------------
# Bodenplatten/Gehwegstücke des Modells entfernen und alle Materialien beidseitig darstellen
func clean_building(n:Node3D):
	var tot=F.aabb(n)
	for m in n.find_children("*","MeshInstance3D",true,false):
		var a=F.rel_xf(m,n)*m.get_aabb()
		var low=a.end.y<tot.position.y+tot.size.y*0.03+0.35
		var flat=a.size.y<0.6 and max(a.size.x,a.size.z)>2.0
		if low and flat:m.visible=false;continue
		for i in m.mesh.get_surface_count():
			var mt=m.get_active_material(i)
			if mt is BaseMaterial3D and mt.cull_mode!=BaseMaterial3D.CULL_DISABLED:
				var d=mt.duplicate();d.cull_mode=BaseMaterial3D.CULL_DISABLED;m.set_surface_override_material(i,d)

func building(d:String,side:int,z0:float,scale:float,front:=Vector3(0,0,1))->float:
	var n=gl(d);n.scale=Vector3.ONE*scale
	var w=Node3D.new();add_child(w);w.add_child(n)
	var want=Vector3(-side,0,0)
	n.rotation.y=atan2(want.x,want.z)-atan2(front.x,front.z)
	clean_building(w)
	var ab=_visible_aabb(w)
	var x=(FX-ab.position.x) if side>0 else (-FX-(ab.position.x+ab.size.x))
	n.position+=Vector3(x,-ab.position.y+0.15,z0-ab.position.z)
	footprints.append(_visible_aabb(w))
	return z0+ab.size.z

func _visible_aabb(root:Node3D)->AABB:
	var ab=AABB();var first=true
	for m in root.find_children("*","MeshInstance3D",true,false):
		if not m.visible:continue
		var a=F.rel_xf(m,root)*m.get_aabb()
		if first:ab=a;first=false
		else:ab=ab.merge(a)
	return ab

# ---------------- Straße ----------------
const XW:=110.0   # halbe Länge der Querstraßen
func _street():
	var b=Batch.new()
	var asph=Mats.pbr("asphalt",0.18);var pav=Mats.pbr("pavers",0.45);var curb=Mats.pbr("concrete",0.6,Color(0.78,0.78,0.76))
	var zc0=L+WALK;var zc1=L+WALK+2*AV   # Querstraße (Fahrbahn) bei +z, gespiegelt bei -z
	b.box(asph,Vector3(-AV,-0.2,-zc0),Vector3(AV,0,zc0))
	for e in [-1,1]:
		b.box(asph,Vector3(-XW+WALK,-0.2,min(e*zc0,e*zc1)),Vector3(XW-WALK,0,max(e*zc0,e*zc1)))
		for sx in [-1,1]:
			b.box(pav,Vector3(min(sx*(XW-WALK+0.25),sx*XW),-0.2,min(e*zc0,e*zc1)),Vector3(max(sx*(XW-WALK+0.25),sx*XW),0.15,max(e*zc0,e*zc1)))
			b.box(curb,Vector3(min(sx*(XW-WALK),sx*(XW-WALK+0.25)),-0.2,min(e*zc0,e*zc1)),Vector3(max(sx*(XW-WALK),sx*(XW-WALK+0.25)),0.16,max(e*zc0,e*zc1)))
		# gegenüberliegender Gehweg + Bordstein
		b.box(pav,Vector3(-XW,-0.2,min(e*(zc1+0.25),e*(zc1+WALK+30))),Vector3(XW,0.15,max(e*(zc1+0.25),e*(zc1+WALK+30))))
		b.box(curb,Vector3(-XW,-0.2,min(e*zc1,e*(zc1+0.25))),Vector3(XW,0.16,max(e*zc1,e*(zc1+0.25))))
		# Mittellinie Querstraße
		var x=-XW
		var white=Mats.flat(Color(0.9,0.9,0.87),0.55)
		while x<XW-WALK-3:
			if abs(x)>AV+1:b.box(white,Vector3(x,0.001,e*(zc0+AV)-0.06),Vector3(x+3,0.012,e*(zc0+AV)+0.06))
			x+=9
	for s in [-1,1]:
		# Gehwege der Hauptstraße (bis zur Querstraße) und um die Ecke
		b.box(pav,Vector3(min(s*(AV+0.25),s*(FX+12)),-0.2,-zc0+0.25),Vector3(max(s*(AV+0.25),s*(FX+12)),0.15,zc0-0.25))
		b.box(Mats.pbr("grass",0.25),Vector3(min(s*(FX+12),s*XW),-0.2,-L),Vector3(max(s*(FX+12),s*XW),0.15,L))
		b.box(pav,Vector3(min(s*(FX+12),s*XW),-0.2,-zc0+0.25),Vector3(max(s*(FX+12),s*XW),0.15,-L))
		b.box(pav,Vector3(min(s*(FX+12),s*XW),-0.2,L),Vector3(max(s*(FX+12),s*XW),0.15,zc0-0.25))
		b.box(curb,Vector3(min(s*AV,s*(AV+0.25)),-0.2,-zc0),Vector3(max(s*AV,s*(AV+0.25)),0.16,zc0))
		for e in [-1,1]:b.box(curb,Vector3(min(s*(AV+0.25),s*XW),-0.2,min(e*(zc0-0.25),e*zc0)),Vector3(max(s*(AV+0.25),s*XW),0.16,max(e*(zc0-0.25),e*zc0)))
	b.box(Mats.pbr("grass",0.2),Vector3(-400,-0.3,-400),Vector3(400,-0.2,400))
	b.commit(self)
	var white=Mats.flat(Color(0.9,0.9,0.87),0.55);var mb=Batch.new();var z=-L
	while z<L:
		mb.box(white,Vector3(-0.06,0.001,z),Vector3(0.06,0.012,z+3.0));z+=9.0
	for s in [-1,1]:mb.box(white,Vector3(s*(AV-2.2)-0.06,0.001,-L),Vector3(s*(AV-2.2)+0.06,0.012,L))
	for e in [-1,1]:
		for k in 9:mb.box(white,Vector3(-AV+0.4+k*1.6,0.001,min(e*(L-1),e*(L+3))),Vector3(-AV+0.9+k*1.6,0.012,max(e*(L-1),e*(L+3))))   # Zebrastreifen an den Kreuzungen
		mb.box(white,Vector3(-AV,0.001,min(e*(L-1.6),e*(L-1.3))),Vector3(AV,0.012,max(e*(L-1.6),e*(L-1.3))))   # Haltelinie
	mb.commit(self,false)

# Altbau-Generator (deutsche Gründerzeithäuser) für Lückenfüller und Querstraßen
var alt:Node3D
func _alt()->Node3D:
	if alt==null:
		alt=Node3D.new();alt.set_script(load("res://scripts/street.gd"));add_child(alt);alt.FX=FX;alt.rng.seed=99
	return alt
func fill(side:int,z0:float,z1:float):
	var A=_alt();var z=z0
	while z1-z>0.5:
		var w=min(z1-z,randf_range(12.0,17.0))
		if z1-(z+w)<9.0:w=z1-z
		A._building(side,z+0.001,w);z+=w
# Häuserzeilen an den Querstraßen: gegenüberliegende Seite, Eckseite (beidseits der Einmündung) und Querriegel am Ende
func _row_node(seed_:int)->Node3D:
	var n=Node3D.new();n.set_script(load("res://scripts/street.gd"));add_child(n);n.FX=FX;n.rng.seed=seed_;return n
func _row(n:Node3D,a:float,b:float):
	var x=a
	while b-x>0.5:
		var w=min(b-x,randf_range(12.0,17.0))
		if b-(x+w)<9.0:w=b-x
		n._building(-1,x+0.001,w);x+=w
func cross_row(e:int):
	var zf=e*(L+2*WALK+2*AV)
	var far=_row_node(200+e);far.rotation.y=PI*0.5*e;far.position=Vector3(0,0,zf-e*FX)
	_row(far,-XW,XW)
	# Eckseite: Fassade an der Gehwegkante z=±L, Blick zur Querstraße
	var near=_row_node(300+e);near.rotation.y=-PI*0.5*e;near.position=Vector3(0,0,e*(L+FX))
	var start=FX+12.0
	_row(near,-XW,-start);_row(near,start,XW)
	# Querriegel an beiden Enden der Querstraße
	for sx in [-1,1]:
		var cap=_row_node(400+e*10+sx);cap.position=Vector3(sx*(XW-FX),0,0)
		var z0=min(e*L,e*(L+2*WALK+2*AV));var z1=max(e*L,e*(L+2*WALK+2*AV))
		var zz=z0
		while z1-zz>0.5:
			var w=min(z1-zz,14.0)
			if z1-(zz+w)<9.0:w=z1-zz
			cap._building(sx,zz+0.001,w);zz+=w

# Baum in einer Baumscheibe: Erde, Granit-Einfassung, Gitterrost
func tree(p:Vector3):
	var b=Batch.new();var soil=Mats.flat(Color(0.2,0.14,0.09),0.95);var granite=Mats.pbr("concrete",0.5,Color(0.55,0.55,0.56))
	b.box(soil,p+Vector3(-0.8,-0.05,-0.8),p+Vector3(0.8,0.005,0.8))
	b.box(granite,p+Vector3(-0.9,-0.05,-0.9),p+Vector3(0.9,0.03,-0.8));b.box(granite,p+Vector3(-0.9,-0.05,0.8),p+Vector3(0.9,0.03,0.9))
	b.box(granite,p+Vector3(-0.9,-0.05,-0.8),p+Vector3(-0.8,0.03,0.8));b.box(granite,p+Vector3(0.8,-0.05,-0.8),p+Vector3(0.9,0.03,0.8))
	var iron=Mats.flat(Color(0.12,0.12,0.13),0.5,0.8)
	for k in 7:
		if k==3:continue
		b.box(iron,p+Vector3(-0.78+k*0.26,0.0,-0.78),p+Vector3(-0.74+k*0.26,0.02,0.78))
	b.commit(self)
	var n=gl("props/tree");var w=F.place(n,randf_range(8.5,10.5));var holder=Node3D.new();add_child(holder);holder.add_child(w)
	# Stammfuß finden (unterste Punkte des Modells) und genau in die Mitte der Baumscheibe setzen
	var lo=_trunk_base(w)
	w.position=Vector3(-lo.x,-0.45,-lo.z)   # Wurzelknolle 45 cm in die Erde
	holder.position=p;holder.rotation.y=randf()*TAU

var _tb=null
func _trunk_base(w:Node3D)->Vector3:
	var acc=Vector3();var n=0
	for m in w.find_children("*","MeshInstance3D",true,false):
		var xf=F.rel_xf(m,w)
		for s in m.mesh.get_surface_count():
			var v:PackedVector3Array=m.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for i in range(0,v.size(),3):
				var p=xf*v[i]
				if p.y<0.4:acc+=p;n+=1
	return acc/max(n,1)

# Straßenlaterne (Mast, Ausleger, LED-Kopf)
func lamp(p:Vector3,dir:float):
	var b=Batch.new();var steel=Mats.flat(Color(0.22,0.24,0.26),0.45,0.7)
	b.cyl(steel,p+Vector3(0,0.25,0),0.11,0.5);b.cyl(steel,p+Vector3(0,3.5,0),0.07,6.5)
	b.box_rot(steel,p+Vector3(dir*0.8,6.65,0),Vector3(1.6,0.08,0.1),Basis(Vector3(0,0,1),dir*0.12))
	b.box(steel,p+Vector3(dir*1.45-0.3,6.6,-0.15),p+Vector3(dir*1.45+0.3,6.75,0.15))
	b.commit(self)
	var led=MeshInstance3D.new();led.mesh=BoxMesh.new();led.mesh.size=Vector3(0.5,0.02,0.24);add_child(led);led.position=p+Vector3(dir*1.45,6.59,0)
	var em=StandardMaterial3D.new();em.albedo_color=Color(1,0.96,0.88);em.emission_enabled=true;em.emission=Color(1,0.94,0.85);em.emission_energy_multiplier=2.0;led.material_override=em

# Bushaltestelle: Wartehäuschen mit Glas, Bank, Haltestellenschild, Fahrplan
func busstop(p:Vector3):
	var b=Batch.new();var steel=Mats.flat(Color(0.55,0.57,0.6),0.35,0.8);var glass=Mats.shop_glass()
	var x0=p.x;var z0=p.z
	b.box(steel,Vector3(x0-1.6,0.15,z0-2.4),Vector3(x0-1.5,2.7,z0+2.4))      # Rückwandrahmen
	b.box(glass,Vector3(x0-1.56,0.35,z0-2.3),Vector3(x0-1.53,2.6,z0+2.3))
	for s in [-1,1]:
		b.box(steel,Vector3(x0-1.6,0.15,z0+s*2.4-0.05),Vector3(x0+0.1,2.7,z0+s*2.4+0.05))
		b.box(glass,Vector3(x0-1.5,0.35,z0+s*2.4-0.02),Vector3(x0-0.2,2.6,z0+s*2.4+0.02))
	b.box(steel,Vector3(x0-1.75,2.7,z0-2.55),Vector3(x0+0.35,2.82,z0+2.55))
	var wood=Mats.flat(Color(0.42,0.27,0.15),0.7)
	b.box(wood,Vector3(x0-1.45,0.62,z0-1.4),Vector3(x0-1.05,0.67,z0+1.4));for zz in [-1.2,1.2]:b.box(steel,Vector3(x0-1.4,0.15,z0+zz-0.04),Vector3(x0-1.1,0.62,z0+zz+0.04))
	b.cyl(steel,Vector3(x0+0.6,1.4,z0+3.2),0.04,2.5)
	b.commit(self)
	var sign=MeshInstance3D.new();sign.mesh=CylinderMesh.new();sign.mesh.top_radius=0.28;sign.mesh.bottom_radius=0.28;sign.mesh.height=0.03;add_child(sign);sign.position=Vector3(x0+0.6,2.75,z0+3.2);sign.rotation.z=PI*0.5
	var ym=StandardMaterial3D.new();ym.albedo_color=Color(0.95,0.8,0.05);sign.material_override=ym
	for s in [-1,1]:
		var h=Label3D.new();h.text="H";h.font_size=120;h.pixel_size=0.003;h.modulate=Color(0.05,0.45,0.15);h.outline_size=0;add_child(h);h.position=sign.position+Vector3(s*0.02,0,0);h.rotation.y=PI*0.5*s
	var lb=Label3D.new();lb.text="Hauptstraße · Linie 7 Bahnhof";lb.font_size=48;lb.pixel_size=0.005;lb.modulate=Color(1,1,1);lb.outline_size=0;add_child(lb);lb.position=Vector3(x0+0.12,2.76,z0);lb.rotation.y=PI*0.5
	var top=StandardMaterial3D.new();top.albedo_color=Color(0.05,0.35,0.15)

# ---------------- Tuning-Werkstatt ----------------
func garage(z0:float,width:float):
	var x0=FX;gx=x0;gz=z0;gw=width
	var D=20.0;var H=8.0
	var b=Batch.new();var brick=Mats.bricks(0.45);var conc=Mats.pbr("concrete",0.4,Color(0.66,0.66,0.68));var trim=Mats.flat(Color(0.18,0.18,0.2),0.6,0.3)
	# Hallenboden innen (Fortsetzung des Vorplatzes), Wände, Dach
	b.box(conc,Vector3(x0,0.0,z0),Vector3(x0+D,0.16,z0+width))
	b.box(brick,Vector3(x0+D-0.5,0.16,z0),Vector3(x0+D,H,z0+width))
	b.box(brick,Vector3(x0,0.16,z0),Vector3(x0+D,H,z0+0.5));b.box(brick,Vector3(x0,0.16,z0+width-0.5),Vector3(x0+D,H,z0+width))
	b.box(trim,Vector3(x0-0.15,H,z0-0.15),Vector3(x0+D+0.15,H+0.45,z0+width+0.15))
	b.box(Mats.flat(Color(0.3,0.3,0.32),0.8),Vector3(x0,H-0.2,z0),Vector3(x0+D,H,z0+width))   # Decke
	# Fassade mit 3 Toröffnungen (5,4 m x 4,6 m)
	var dw=5.4;var dh=4.6;var gap=(width-3*dw)/4.0;var zz=z0
	var doors_z=[]
	for k in 4:
		b.box(brick,Vector3(x0,0.16,zz),Vector3(x0+0.5,H,zz+gap));zz+=gap
		if k<3:
			doors_z.append(zz+dw*0.5)
			b.box(brick,Vector3(x0,0.16+dh,zz),Vector3(x0+0.5,H,zz+dw))                       # Sturz
			b.box(Mats.flat(Color(0.95,0.7,0.1),0.45,0.3),Vector3(x0-0.04,0.16+dh,zz-0.12),Vector3(x0+0.02,0.16+dh+0.18,zz+dw+0.12))   # gelbe Torumrandung oben
			for s in [zz-0.12,zz+dw]:b.box(Mats.flat(Color(0.95,0.7,0.1),0.45,0.3),Vector3(x0-0.04,0.16,s),Vector3(x0+0.02,0.16+dh,s+0.12))
			zz+=dw
	# Innenausstattung: Werkbänke, Regale, Hebebühne, Reifen
	var red=Mats.flat(Color(0.62,0.05,0.04),0.45,0.3);var steel=Mats.flat(Color(0.55,0.55,0.57),0.35,0.8);var yel=Mats.flat(Color(0.85,0.62,0.06),0.45,0.4)
	for i in 6:
		var zb=z0+1.2+i*4.0
		b.box(red,Vector3(x0+D-1.3,0.16,zb),Vector3(x0+D-0.5,1.05,zb+2.6));b.box(steel,Vector3(x0+D-1.35,1.05,zb),Vector3(x0+D-0.5,1.1,zb+2.6))
		b.box(Mats.flat(Color(0.25,0.27,0.3),0.6,0.6),Vector3(x0+D-0.55,1.7,zb),Vector3(x0+D-0.5,3.5,zb+2.6))
	for k in 3:
		var zc=doors_z[k]
		# Zweisäulen-Hebebühne: schlanke Säulen mit Fuß, Tragarme am Boden
		for sz in [-1,1]:
			b.box(yel,Vector3(x0+9.3,0.16,zc+sz*1.85-0.14),Vector3(x0+9.6,3.4,zc+sz*1.85+0.14))
			b.box(steel,Vector3(x0+9.1,0.16,zc+sz*1.85-0.3),Vector3(x0+9.8,0.24,zc+sz*1.85+0.3))
			for ax in [-1,1]:b.box_rot(steel,Vector3(x0+9.45+ax*0.55,0.3,zc+sz*1.3),Vector3(1.2,0.08,0.12),Basis(Vector3.UP,ax*sz*0.5))
		b.box(yel,Vector3(x0+9.3,3.4,zc-2.0),Vector3(x0+9.6,3.55,zc+2.0))
		b.box(Mats.flat(Color(0.95,0.75,0.1),0.6),Vector3(x0+2.5,0.16,zc-0.08),Vector3(x0+13,0.17,zc+0.08))   # Bodenmarkierung
	var tire=Mats.flat(Color(0.03,0.03,0.03),0.85)
	for s in 2:
		for k in 5:b.cyl(tire,Vector3(x0+D-2.0-s*0.9,0.3+k*0.27,z0+0.95),0.36,0.25)
	b.commit(self)
	# Hallenlicht
	for k in 3:
		var l=OmniLight3D.new();add_child(l);l.position=Vector3(x0+9,H-1.0,doors_z[k]);l.omni_range=14;l.light_energy=2.6;l.light_color=Color(0.95,0.97,1)
		var tube=MeshInstance3D.new();tube.mesh=BoxMesh.new();tube.mesh.size=Vector3(2.4,0.06,0.15);add_child(tube);tube.position=Vector3(x0+9,H-0.25,doors_z[k])
		var em=StandardMaterial3D.new();em.emission_enabled=true;em.emission=Color(0.95,0.97,1);em.emission_energy_multiplier=4;tube.material_override=em
	# Bordsteinabsenkung (Rampe) vor jedem Tor
	var rb=Batch.new();var rampm=Mats.pbr("concrete",0.6,Color(0.72,0.72,0.72))
	for k in 3:
		var zc=doors_z[k];var run=1.1;var ang=atan2(0.15,run)
		rb.box_rot(rampm,Vector3(AV-run*0.5+0.25,0.075,zc),Vector3(sqrt(run*run+0.0225)+0.02,0.03,dw+1.0),Basis(Vector3(0,0,1),ang))
		rb.box(rampm,Vector3(AV-run+0.25,-0.05,zc-dw*0.5-0.5),Vector3(AV+0.27,0.06,zc+dw*0.5+0.5))
	rb.commit(self)
	# Rolltore (eines pro Öffnung), stehen in der Fassadenebene, fahren nach oben hinter den Sturz
	for k in 3:
		var t=Node3D.new();t.set_script(TOR);add_child(t);t.setup(dw,dh)
		t.position=Vector3(x0+0.3,0.16,doors_z[k]);garage_doors.append(t)
	# Leuchtschrift und Strahler
	var lb=Label3D.new();lb.text="RADEBERG CUSTOMS";lb.font_size=200;lb.pixel_size=0.011;lb.modulate=Color(1,0.72,0.15);lb.outline_size=0
	add_child(lb);lb.position=Vector3(x0-0.03,H-1.4,z0+width*0.5);lb.rotation.y=-PI*0.5
	var lb2=Label3D.new();lb2.text="TUNING · LACK · FELGEN · NOS";lb2.font_size=80;lb2.pixel_size=0.01;lb2.modulate=Color(0.95,0.95,0.92);lb2.outline_size=0
	add_child(lb2);lb2.position=Vector3(x0-0.03,H-2.45,z0+width*0.5);lb2.rotation.y=-PI*0.5
	for k in 5:
		var lamp_=MeshInstance3D.new();lamp_.mesh=BoxMesh.new();lamp_.mesh.size=Vector3(0.35,0.12,0.25);add_child(lamp_);lamp_.position=Vector3(x0-0.2,H-0.3,z0+2+k*(width-4)/4.0)
		var em=StandardMaterial3D.new();em.emission_enabled=true;em.emission=Color(1,0.88,0.65);em.emission_energy_multiplier=3;lamp_.material_override=em
	return doors_z

func _ready():
	randomize();seed(4)
	args=OS.get_cmdline_user_args()
	var mode="sunset" if "--sunset" in args else "day"
	load("res://scripts/env.gd").make(self,mode)
	_street()
	# ---- rechte Seite: Häuser, Werkstatt, Häuser (lückenlos bis zu den Ecken)
	var z=-L
	fill(1,z,-L+15.0);z=max(z,-L+15.0)
	z=building("buildings/chicago",1,z,0.25)
	z=building("buildings/nyc",1,z,1.0,Vector3(0,0,-1))
	z=max(z,-40.0);fill(1,z-0.0,z)   # Werkstatt schließt direkt an
	var doors_z=garage(z,26.0);z+=26.0
	z=building("buildings/chicago",1,z,0.25)
	fill(1,z,L)
	# ---- linke Seite
	z=-L
	fill(-1,z,-L+14.0);z=max(z,-L+14.0)
	z=building("buildings/building",-1,z,3.2)
	z=building("buildings/nyc",-1,z,1.0)
	fill(-1,z,-38.0);z=max(z,-38.0)
	z=building("buildings/chicago",-1,z,0.25)
	z=building("buildings/building",-1,z,3.2)
	fill(-1,z,L)
	# ---- Querstraßen-Zeilen gegenüber
	cross_row(1);cross_row(-1)
	footprints.append(AABB(Vector3(FX,0,gz),Vector3(20,8,gw)))
	check_overlaps()
	# ---- Bäume (nicht vor Werkstatt-Einfahrten, nicht an der Haltestelle), Laternen dazwischen
	for zz in range(-int(L)+10,int(L)-6,16):
		for s in [-1,1]:
			var tz=float(zz)+(4.0 if s>0 else 0.0)
			if s>0 and tz>gz-4 and tz<gz+gw+4:continue
			if s<0 and tz>-36 and tz<-16:continue
			if abs(tz-60)<5:continue
			tree(Vector3(s*(AV+1.4),0.15,tz))
			var lz=tz+8.0
			if s>0 and lz>gz-4 and lz<gz+gw+4:continue   # keine Laterne vor den Werkstatt-Einfahrten
			if s<0 and lz>-36 and lz<-16:continue
			lamp(Vector3(s*(AV+0.6),0.15,lz),-s)
	busstop(Vector3(-AV-2.0,0.15,-26))
	_courtyards()
	var cam=Camera3D.new();cam.near=0.05;cam.far=1500;add_child(cam)
	_doors_z_cache=doors_z
	if "--qa" in args:
		_qa_cams();return
	if "--nah" in args:
		_traffic(_doors_z_cache);_people()
		var sh=load("res://scripts/shots.gd").new();add_child(sh)
		sh.setup([[Vector3(gx+3.0,1.7,_doors_z_cache[1]-1.5),Vector3(gx+12,1.0,_doors_z_cache[1]+0.5),62.0],
			[Vector3(-AV-3,1.6,36),Vector3(-AV+1.2,0.5,44.5),45.0],
			[Vector3(AV-0.5,1.7,gz-8),Vector3(FX+1,1.6,gz+8),58.0],
			[Vector3(-AV-2.5,1.7,-60),Vector3(0,3,0),60.0],
			[Vector3(2.0,1.6,-44),Vector3(-AV-1,1.4,-26),55.0],
			[Vector3(AV+3,1.6,-70),Vector3(AV+3,1.5,-20),58.0],
			[Vector3(-3,1.7,L-12),Vector3(10,2,L+12),60.0],
			[Vector3(-AV-3.5,1.6,0),Vector3(-AV-3.5,1.4,40),58.0]],"nah");return
	_traffic(doors_z)
	if "--tor" in args:
		_tor_shots(doors_z);return
	_people()
	var sh=load("res://scripts/shots.gd").new();add_child(sh)
	sh.setup([
		[Vector3(-AV-2.5,1.7,-90),Vector3(0,5,20),62.0],
		[Vector3(-AV-2.0,2.0,gz-6),Vector3(gx+3,3.0,gz+13),58.0],
		[Vector3(AV+1.0,1.6,gz-3),Vector3(gx+1,1.0,gz+14),58.0],
		[Vector3(2.5,1.7,-46),Vector3(-AV-1,1.4,-26),55.0],
		[Vector3(0.5,1.5,-10),Vector3(0,1.5,60),58.0],
		[Vector3(-AV-3.2,1.65,36),Vector3(-AV+1,1.2,70),55.0],
		[Vector3(45,60,-120),Vector3(0,0,0),50.0]],"in_"+mode)

# Innenhöfe: Rasen, Bäume, Wäschestangen-freie einfache Begrünung; nur dort, wo kein Gebäude steht
func _courtyards():
	var rng2=RandomNumberGenerator.new();rng2.seed=77
	for s in [-1,1]:
		var placed=0;var tries=0
		while placed<14 and tries<400:
			tries+=1
			var p=Vector3(s*rng2.randf_range(FX+18,XW-18),0.15,rng2.randf_range(-L+18,L-18))
			var ok=true
			for fp in footprints:
				if fp.grow(3.0).has_point(Vector3(p.x,fp.position.y+1,p.z)):ok=false;break
			if not ok:continue
			var n=gl("props/tree");var w=F.place(n,rng2.randf_range(7.0,11.0));var holder=Node3D.new();add_child(holder);holder.add_child(w)
			var lo=_trunk_base(w);w.position=Vector3(-lo.x,-0.45,-lo.z);holder.position=p;holder.rotation.y=rng2.randf()*TAU
			placed+=1

func _qa_cams():
	var cams=[]
	for z in range(-int(L)+15,int(L),22):
		cams.append([Vector3(-AV+0.5,1.8,z),Vector3(FX,6,z+10),62.0])     # rechte Häuserzeile
		cams.append([Vector3(AV-0.5,1.8,z),Vector3(-FX,6,z+10),62.0])     # linke Häuserzeile
	cams.append([Vector3(-3,1.8,L-30),Vector3(10,4,L+20),62.0]);cams.append([Vector3(3,1.8,-L+30),Vector3(-10,4,-L-20),62.0])
	cams.append([Vector3(30,2.0,L+WALK+AV),Vector3(-30,4,L+WALK+AV),62.0])
	cams.append([Vector3(60,70,-180),Vector3(0,0,0),55.0]);cams.append([Vector3(-60,70,180),Vector3(0,0,0),55.0])
	cams.append([Vector3(FX+60,40,0),Vector3(FX+10,5,0),55.0]);cams.append([Vector3(-FX-60,40,0),Vector3(-FX-10,5,0),55.0])  # Rückseiten
	var sh=load("res://scripts/shots.gd").new();add_child(sh);sh.setup(cams,"qa_in")

# ---------------- Verkehr ----------------
func _traffic(doors_z:Array):
	var VH=load("res://scripts/vehicles.gd");var TU=load("res://scripts/tuning.gd")
	var place=func(kind,x,z,yaw):
		var v=VH.make(kind);add_child(v);v.position=Vector3(x,0,z);v.rotation.y=yaw+(PI if v.get_meta("front",1.0)<0 else 0.0);return v
	# fahrende Spur (rechts: +z Richtung auf x<0? -> Rechtsverkehr: Fahrtrichtung +z auf x>0)
	var lane=[["taxi",3.6,-70.0],["polizei",-3.6,-10.0],["audi_rs7",3.6,10.0],["trabant",-3.6,34.0],["bmw_m8",3.6,48.0],["porsche911",-3.6,-60.0],["mercedes",3.6,-104.0],["lkw",-3.6,90.0]]
	for t in lane:place.call(t[0],t[1],t[2],0.0 if t[1]>0 else PI)
	# Parkstreifen
	var parked=[["small_car",-AV+1.2,-100.0],["trabant",-AV+1.2,-6.0],["mercedes",-AV+1.2,4.0],["taxi",-AV+1.2,30.0],["audi_r8",-AV+1.2,44.0],["polizei",AV-1.2,-40.0],["bmw_e30",AV-1.2,-96.0],["trabant",AV-1.2,-86.0],["rtw",AV-1.3,80.0]]
	for t in parked:place.call(t[0],t[1],t[2],0.0 if t[1]>0 else PI)
	var bus=place.call("bus",-AV+1.6,-24.0,PI)
	# getunte Autos auf dem Werkstatt-Vorplatz (vor den Toren 1 und 3) und eines in der Halle
	var tuned=[["jdm",{"front":1,"side":1,"spoiler":1,"neon":"Türkis","lights":"Xenon Blau"},Vector3(FX-2.6,0.15,doors_z[0]),-PI*0.5+0.25],
		["porsche911",{"spoiler":3,"paint":"Signalrot","finish":"Glanz","neon":"Rot"},Vector3(FX-2.6,0.15,doors_z[2]+0.5),-PI*0.5-0.25],
		["audi_r8",{"paint":"Lila","finish":"Perleffekt","neon":"Lila","spoiler":3},Vector3(gx+9.5,0.16,doors_z[1]),PI*0.5]]
	for t in tuned:
		if "--tor" in args and t[0]=="jdm":continue   # Einfahrt freihalten
		var v=VH.make(t[0]);add_child(v)
		var c=TU.default_cfg();for k in t[1]:c[k]=t[1][k]
		TU.apply(v,c);v.position=t[2];v.rotation.y=t[3]+(PI if v.get_meta("front",1.0)<0 else 0.0)
	garage_doors[1].open=1.0   # mittleres Tor offen

func _people():
	var PE=load("res://scripts/people.gd");var prng=RandomNumberGenerator.new();prng.seed=21;var NPC=load("res://scripts/npc.gd")
	var civ=["joe","biker","daya","female","joe","daya","female"]
	for i in 44:
		var b=civ[prng.randi()%civ.size()];var p=PE.make(b,prng);p.set_script(NPC);add_child(p)
		var side=1.0 if i%2==0 else -1.0;var lx=side*(AV+prng.randf_range(2.6,4.6));var pz=prng.randf_range(-100,100)
		p.position=Vector3(lx,0.15,pz);p.setup(lx,-L+10,L-10,i*17,"talk" if i%6==0 else "walk")
	for k in 3:
		var p=PE.make(civ[(k*3+1)%civ.size()],prng);add_child(p);p.position=Vector3(-AV-3.0,0.15,-27+k*1.2);p.rotation.y=PI*0.5;PE.play(p,["idle","talk","idle"][k],prng.randf())

# ---------------- Tor-Animation (Einzelbilder) ----------------
func _tor_shots(doors_z:Array):
	var VH=load("res://scripts/vehicles.gd");var TU=load("res://scripts/tuning.gd")
	var car=VH.make("jdm");add_child(car)
	var c=TU.default_cfg();c.front=1;c.side=1;c.spoiler=1;c.neon="Türkis";TU.apply(car,c)
	var dz=doors_z[0];garage_doors[0].open=0.0
	var cam:Camera3D=get_viewport().get_camera_3d()
	cam.position=Vector3(AV-2.5,1.7,dz-8.0);cam.look_at(Vector3(FX+3.0,1.4,dz+0.5));cam.fov=58
	var face=PI*0.5+(PI if car.get_meta("front",1.0)<0 else 0.0)
	var yat=func(x):return clamp((x-(AV-0.85))/1.1,0.0,1.0)*0.15+(0.01 if x>FX else 0.0)
	var n=14
	for f in 3:await get_tree().process_frame
	for i in n:
		var t=float(i)/(n-1)
		garage_doors[0].open=clamp(t/0.45,0.0,1.0)
		var x=lerp(0.5,FX+9.0,clamp((t-0.3)/0.7,0.0,1.0))
		car.position=Vector3(x,yat.call(x),dz);car.rotation.y=face
		for k in 6:await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("/home/claude/shots_godot/tor_%02d.png"%i)
	get_tree().quit()

# Überschneidungsprüfung der Gebäude (Konsole)
func check_overlaps():
	for i in footprints.size():
		for j in range(i+1,footprints.size()):
			var a:AABB=footprints[i].grow(-0.3);var b:AABB=footprints[j].grow(-0.3)
			if a.intersects(b):print("UEBERLAPPUNG ",i," ",j," ",a," ",b)
