extends VehicleBody3D
# Fahrbares Auto: Optik aus vehicles.gd, Physik als VehicleBody3D mit vier Rädern.
# Modi: "geparkt" (schläft), "ki" (Verkehr, kinematisch entlang der Straße), "spieler" (gefahren).
const VH=preload("res://scripts/vehicles.gd")
const F=preload("res://scripts/fit.gd")
var kind:="small_car"
var modus:="geparkt"
var ab:AABB
var max_kmh:=170.0
var kraft:=7000.0
var nos_vorrat:=1.0
var radius:=0.34
var wheels:=[]
var visual:Node3D
var kopf_hoehe:=1.4
var _kopfueber:=0.0
# KI
var ki_road=null;var ki_s:=0.0;var ki_dir:=1;var ki_lane:=0.0;var ki_speed:=0.0;var ki_ziel:=11.0
var S

static var _tmpl:={}
static func vorlage(k:String)->Node3D:
	if not _tmpl.has(k):
		var p="res://assets/cache/autos/"+k+".scn"
		if ResourceLoader.exists(p):_tmpl[k]=load(p).instantiate()   # vorbereitet: Räder einzeln, Front = +Z
		else:_tmpl[k]=VH.make(k)
	return _tmpl[k]

var hp:=1000.0
var wrack:=false
var zaeh:=false   # Missionsziel: fährt trotz Treffern weiter
var _rauch:CPUParticles3D=null
var _brand:=0.0
func ist_mensch()->bool:return false
# Beschuss / Unfallschaden: Rauch, Feuer, Explosion
func treffer(dmg:float,von,punkt:Vector3):
	if wrack:return
	hp-=dmg
	if modus=="ki" and (not zaeh or hp<350.0):ki_ziel=0.0;ki_speed=max(0.0,ki_speed-4.0)
	if hp<380.0 and _rauch==null:_rauch_an()
	if hp<=0.0 and _brand<=0.0:_brand=4.0
func _rauch_an():
	_rauch=CPUParticles3D.new();add_child(_rauch);_rauch.position=Vector3(0,ab.end.y*0.7,ab.end.z-0.9)
	_rauch.amount=24;_rauch.lifetime=1.6;_rauch.direction=Vector3.UP;_rauch.spread=15;_rauch.initial_velocity_min=1.0;_rauch.initial_velocity_max=2.2;_rauch.gravity=Vector3(0,0.6,0)
	_rauch.scale_amount_min=0.4;_rauch.scale_amount_max=1.0
	var m=SphereMesh.new();m.radius=0.5;m.height=1.0;m.radial_segments=6;m.rings=3;_rauch.mesh=m
	var mt=StandardMaterial3D.new();mt.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mt.vertex_color_use_as_albedo=true;mt.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.material=mt
	var g=Gradient.new();g.set_color(0,Color(0.35,0.35,0.35,0.6));g.set_color(1,Color(0.2,0.2,0.2,0.0));_rauch.color_ramp=g
func _brand_schritt(dt:float):
	if _brand<=0.0:return
	if _rauch:
		var g=Gradient.new();g.set_color(0,Color(1.0,0.55,0.1,0.9));g.set_color(1,Color(0.15,0.12,0.1,0.0));_rauch.color_ramp=g
	_brand-=dt
	if _brand<=0.0:
		wrack=true;engine_force=0.0;brake=3.0
		var k=get_tree().get_first_node_in_group("kampf")
		if k:k.explosion(global_position+Vector3(0,0.8,0),self)
		var dunkel=StandardMaterial3D.new();dunkel.albedo_color=Color(0.04,0.035,0.03,0.88);dunkel.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;dunkel.roughness=1.0
		for m in visual.find_children("*","GeometryInstance3D",true,false):m.material_overlay=dunkel
		apply_central_impulse(Vector3(0,mass*4.0,0));apply_torque_impulse(Vector3(randf_range(-1,1),0,randf_range(-1,1))*mass*1.5)

# ---------------- Verfolger (Polizei) ----------------
var _stau:=0.0;var _rueck:=0.0
func verfolge(ziel:Node3D,dt:float):
	if modus!="verfolger":
		modus="verfolger";freeze=false;sleeping=false;brake=0.0;_schicht(false)
	var me=global_transform
	var d=ziel.global_position-me.origin;var dist=d.length()
	var lok=me.basis.inverse()*d
	var winkel=atan2(lok.x,lok.z)
	var v=linear_velocity.dot(me.basis.z)
	if _rueck>0.0:
		_rueck-=dt;engine_force=-kraft*0.6;steering=clamp(winkel,-0.5,0.5);brake=0.0;return
	if abs(v)<1.0:_stau+=dt
	else:_stau=0.0
	if _stau>2.0:_stau=0.0;_rueck=1.5
	steering=move_toward(steering,clamp(-winkel*1.2,-0.6,0.6),dt*3.0)
	var soll=34.0 if dist>60.0 else max(10.0,dist*0.6)
	if abs(winkel)>1.2:soll=8.0
	engine_force=kraft*0.9 if v<soll else 0.0
	brake=8.0 if v>soll+4.0 else 0.0
	# Stabilisierung wie beim Spieler
	var bx=me.basis
	apply_torque(bx.z*(-bx.x.y)*mass*9.0+bx.x*(bx.z.y)*mass*4.0)
	if me.basis.y.y<0.3 and linear_velocity.length()<2.0:aufrichten()

var _blau:=[];var _blau_t:=0.0
func blaulicht(an:bool):
	if _blau.is_empty() and an:
		for sx in [-1,1]:
			var l=OmniLight3D.new();add_child(l);l.position=Vector3(sx*0.4,ab.end.y+0.3,ab.get_center().z+0.3);l.light_color=Color(0.15,0.3,1.0) if sx<0 else Color(1,0.1,0.1);l.omni_range=9.0;l.light_energy=3.0
			_blau.append(l)
	for l in _blau:l.visible=an

var _licht:=[]
func scheinwerfer(an:bool):
	if _licht.is_empty() and an:
		for sx in [-1,1]:
			var l=SpotLight3D.new();add_child(l);l.position=Vector3(ab.get_center().x+sx*ab.size.x*0.32,ab.position.y+ab.size.y*0.4,ab.end.z-0.1)
			l.rotation_degrees=Vector3(-4,180,0);l.spot_range=45.0;l.spot_angle=32.0;l.light_energy=3.5;l.light_color=Color(1,0.95,0.85);l.shadow_enabled=false
			_licht.append(l)
	for l in _licht:l.visible=an

var rad_knoten:=[]   # [Node3D Radoptik, VehicleWheel3D, Ruhelage]
# im Hintergrund nachladen (kein Ruckeln beim ersten Auftauchen eines Modells)
static var _laeuft:={}
static func vorladen(k:String):
	var p="res://assets/cache/autos/"+k+".scn"
	if _tmpl.has(k) or _laeuft.has(k) or not ResourceLoader.exists(p):return
	ResourceLoader.load_threaded_request(p);_laeuft[k]=p
static func bereit(k:String)->bool:
	if _tmpl.has(k):return true
	if not _laeuft.has(k):vorladen(k);return false
	if ResourceLoader.load_threaded_get_status(_laeuft[k])==ResourceLoader.THREAD_LOAD_LOADED:
		_tmpl[k]=ResourceLoader.load_threaded_get(_laeuft[k]).instantiate();_laeuft.erase(k);return true
	return false
var _spin:=0.0

func setup(k:String):
	kind=k
	var t=vorlage(k)
	visual=t.duplicate();add_child(visual)
	if t.get_meta("front",1.0)<0:visual.rotation.y=PI
	ab=F.aabb(self)
	var big=ab.size.z>7.0
	mass=6500.0 if big else 1350.0
	kraft=17000.0 if big else 4700.0
	max_kmh=110.0 if big else 175.0
	if k in ["audi_r8","porsche911","bmw_m8","bugatti","hoonicorn","jdm","audi_rs7"]:kraft=6300.0;max_kmh=245.0
	if k in ["trabant","small_car"]:kraft=3900.0;max_kmh=135.0
	center_of_mass_mode=RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM;center_of_mass=Vector3(0.0,0.0,ab.get_center().z)
	# Karosserie als Kollisionskasten (über dem Boden, damit die Räder federn können)
	var cs=CollisionShape3D.new();var bx=BoxShape3D.new()
	var h=ab.size.y*0.62
	bx.size=Vector3(ab.size.x*0.92,h,ab.size.z*0.94);cs.shape=bx;add_child(cs)
	cs.position=Vector3(ab.get_center().x,0.38+h*0.5,ab.get_center().z)
	radius=0.5 if big else 0.34
	var wx=ab.size.x*0.5-0.24;var wz=ab.size.z*0.5-(1.6 if big else 0.82)
	var rd:Array=t.get_meta("raeder",[])
	var plan=[]
	if rd.size()==4:
		for r in rd:plan.append([r.p,r.r,r.vorne,"Rad_"+("V" if r.vorne else "H")+("L" if r.links else "R")])
	else:
		for p in [[-1,1,true],[1,1,true],[-1,-1,false],[1,-1,false]]:
			plan.append([Vector3(ab.get_center().x+wx*p[0],radius,ab.get_center().z+wz*p[1]),radius,p[2],""])
	for q in plan:
		var w=VehicleWheel3D.new()
		var stiff=55.0 if not big else 70.0
		w.wheel_rest_length=0.16;w.suspension_travel=0.22;w.suspension_stiffness=stiff
		# Aufhängepunkt so, dass das Rad im Stand genau dort steht, wo es im Modell sitzt (Einfederung g/(4*k))
		w.position=Vector3(q[0].x,q[0].y+w.wheel_rest_length-9.8/(4.0*stiff),q[0].z)
		w.use_as_steering=q[2]
		w.use_as_traction=not q[2] or k in ["audi_r8","bugatti","audi_rs7"]
		w.wheel_radius=q[1];w.damping_compression=0.9;w.damping_relaxation=1.2
		w.wheel_friction_slip=3.2;w.wheel_roll_influence=0.03;w.suspension_max_force=60000.0 if big else 14000.0
		add_child(w);wheels.append(w)
		if q[3]!="":
			var rn=visual.get_node_or_null(q[3])
			if rn:rad_knoten.append([rn,w,rn.position])
	kopf_hoehe=ab.size.y+0.3
	parken()

# Kollisionsebenen: 1 Welt/Spieler, 8 stehende und gefahrene Autos, 16 Verkehr (kinematisch).
# Verkehr und Spieler-Figur berühren sich physikalisch nie (das brachte das Spiel zum Hängen) – Anfahren wird von Hand geprüft.
const SCHICHT_AUTO:=8
const SCHICHT_VERKEHR:=16
func _schicht(ki:bool):
	if ki:collision_layer=SCHICHT_VERKEHR;collision_mask=0
	else:collision_layer=SCHICHT_AUTO;collision_mask=1|SCHICHT_AUTO|SCHICHT_VERKEHR

func parken():
	_schicht(false)
	modus="geparkt";freeze=false;engine_force=0;brake=6.0;steering=0
	sleeping=true

func als_ki(road,s:float,dir:int,lane:float,road_sys):
	S=road_sys;ki_road=road;ki_s=s;ki_dir=dir;ki_lane=lane;modus="ki"
	_schicht(true)
	freeze_mode=RigidBody3D.FREEZE_MODE_KINEMATIC;freeze=true
	ki_ziel=randf_range(9.0,14.0) if road.typ!="autobahn" else randf_range(22.0,30.0)
	ki_speed=ki_ziel*0.6
	_ki_place(0.0)

func uebernehmen():
	_schicht(false)
	modus="spieler";freeze=false;brake=0.0;sleeping=false

func kmh()->float:return linear_velocity.length()*3.6

func fahren(st,dt:float):
	if modus!="spieler":return
	if wrack:engine_force=0.0;return
	var v=linear_velocity.dot(global_transform.basis.z)
	var speed=abs(v)*3.6
	# Lenkung: weniger Einschlag bei hoher Geschwindigkeit
	var maxs=lerp(0.6,0.09,clamp(speed/200.0,0.0,1.0))
	steering=move_toward(steering,-st.steer*maxs,dt*2.6)
	var f=0.0;var b=0.0
	if st.gas>0.05:
		f=st.gas*kraft
		if v<-0.5:b=st.gas*45.0;f=0.0
	if st.brake>0.05:
		if v>0.8:b=st.brake*45.0
		else:f=-st.brake*kraft*0.5
	if speed>max_kmh and f>0:f=0.0
	if v<-11.0 and f<0:f=0.0   # rückwärts höchstens ~40 km/h
	if st.nos and nos_vorrat>0.0 and st.gas>0.1:f*=1.7;nos_vorrat=max(0.0,nos_vorrat-dt*0.25)
	else:nos_vorrat=min(1.0,nos_vorrat+dt*0.03)
	if st.gas<0.05 and st.brake<0.05 and not st.handbrake:b=1.5   # Motorbremse
	engine_force=f
	for w in wheels:
		if not w.use_as_steering:w.wheel_friction_slip=1.3 if st.handbrake else 3.2
		w.brake=b
		if not w.use_as_steering and st.handbrake:w.brake=max(b,60.0)
	# Stabilisierung gegen Umkippen (Arcade): Rollen und Nicken sanft zurückdrehen
	var bx=global_transform.basis
	apply_torque(bx.z*(-bx.x.y)*mass*9.0+bx.x*(bx.z.y)*mass*4.0)
	# Aufrichten nach Überschlag
	if global_transform.basis.y.y<0.3 and linear_velocity.length()<2.0:
		_kopfueber+=dt
		if _kopfueber>2.5:aufrichten()
	else:_kopfueber=0.0

# Radoptik: im gefahrenen Auto folgt sie der Physik (Federweg, Lenkeinschlag, Drehung), im Verkehr dreht sie sich mit
func _process(dt):
	_brand_schritt(dt)
	if not _blau.is_empty():
		_blau_t+=dt
		_blau[0].light_energy=4.0 if int(_blau_t*6.0)%2==0 else 0.2;_blau[1].light_energy=4.0 if int(_blau_t*6.0)%2==1 else 0.2
	if rad_knoten.is_empty() or not visible:return
	if modus=="spieler" or modus=="verfolger":
		for e in rad_knoten:
			e[0].transform=e[1].transform
	elif modus=="ki":
		_spin=wrapf(_spin+ki_speed*dt/max(rad_knoten[0][1].wheel_radius,0.2),0.0,TAU)
		var b=Basis(Vector3.RIGHT,_spin)
		for e in rad_knoten:e[0].transform=Transform3D(b,e[2])

func aufrichten():
	var fw=global_transform.basis.z;fw.y=0;fw=fw.normalized()
	global_transform=Transform3D(Basis.looking_at(-fw,Vector3.UP),global_position+Vector3(0,1.2,0))
	linear_velocity=Vector3.ZERO;angular_velocity=Vector3.ZERO;_kopfueber=0.0

func aussteig_punkt()->Vector3:
	return global_transform*Vector3(ab.position.x-0.9,0.3,ab.get_center().z+0.4)

# ---------------- KI-Verkehr ----------------
var blockiert:=false
func ki_schritt(dt:float,hindernisse:Array):
	if modus!="ki":return
	# Abstand halten: etwas direkt vor mir?
	var fw=global_transform.basis.z;var me=global_position;var frei=ki_ziel
	for o in hindernisse:
		if o==self:continue
		var d=o.global_position-me;d.y=0
		var dist=d.length()
		if dist<1.0 or dist>28.0:continue
		var ahead=d.dot(fw)
		if ahead<0:continue
		var side=abs(d.dot(global_transform.basis.x))
		if side<2.4:frei=min(frei,max(0.0,(dist-8.0)*0.9))
	ki_speed=move_toward(ki_speed,frei,dt*(6.0 if frei<ki_speed else 2.5))
	ki_s+=ki_speed*dt*ki_dir
	var L=S.length(ki_road)
	if ki_s<2.0 or ki_s>L-2.0:_ki_weiter()
	_ki_place(dt)

func _ki_weiter():
	# am Straßenende: an einer Kreuzung abbiegen, sonst wenden
	var p=S.at(ki_road,clamp(ki_s,0.0,S.length(ki_road)))[0]
	var opts=[]
	for j in S.junctions:
		if j.p.distance_to(p)<14.0:
			for ri in [j.a,j.b]:
				var r=S.roads[ri]
				if r!=ki_road and r.typ in ["strasse","allee","gasse","land","autobahn","rampe"]:opts.append(r)
	if opts.size()>0:
		var r=opts[randi()%opts.size()]
		var best=0;var bd=1e9
		for i in r.P.size():
			var d=r.P[i].distance_to(p)
			if d<bd:bd=d;best=i
		ki_road=r;ki_s=best*S.DS
		var L=S.length(r)
		ki_dir=1 if ki_s<L*0.5 else -1
		ki_s+=ki_dir*3.0
		ki_lane=_lane(r)
	else:
		ki_dir=-ki_dir;ki_s=clamp(ki_s,2.5,S.length(ki_road)-2.5)

func _lane(r)->float:
	if r.typ=="autobahn":return r.med+0.3+(r.w-0.5-r.med)*0.3
	if r.typ=="allee":return r.med+(r.w-r.med)*0.35
	if r.typ in ["gasse","rampe","land"]:return r.w*0.45
	return r.w*0.5

func _ki_place(dt:float):
	var a=S.at(ki_road,clamp(ki_s,0.0,S.length(ki_road)))
	var t:Vector2=a[2]*ki_dir;var n=Vector2(-t.y,t.x)
	var p:Vector2=a[0]-n*ki_lane    # Rechtsverkehr
	var y=a[1]+0.04
	# Steigung der Straße übernehmen (sonst steckt bei Gefälle Bug oder Heck in der Fahrbahn)
	var L=S.length(ki_road)
	var hv=S.at(ki_road,clamp(ki_s+2.0*ki_dir,0.0,L))[1];var hh=S.at(ki_road,clamp(ki_s-2.0*ki_dir,0.0,L))[1]
	var dy=(hv-hh)/4.0
	var fwd=Vector3(t.x,dy,t.y).normalized()
	var target=Transform3D(Basis.looking_at(-fwd,Vector3.UP),Vector3(p.x,y,p.y))
	if dt>0.0:
		var q=global_transform.basis.get_rotation_quaternion().slerp(target.basis.get_rotation_quaternion(),clamp(dt*5.0,0.0,1.0))
		global_transform=Transform3D(Basis(q),target.origin)
	else:global_transform=target
