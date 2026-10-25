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
	if not _tmpl.has(k):_tmpl[k]=VH.make(k)
	return _tmpl[k]

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
	for p in [[-1,1,true],[1,1,true],[-1,-1,false],[1,-1,false]]:
		var w=VehicleWheel3D.new()
		w.position=Vector3(ab.get_center().x+wx*p[0],radius+0.09,ab.get_center().z+wz*p[1])
		w.use_as_steering=p[2];w.use_as_traction=not p[2] or big==false and k in ["audi_r8","bugatti","audi_rs7"]
		if not p[2]:w.use_as_traction=true
		w.wheel_radius=radius;w.suspension_travel=0.22;w.wheel_rest_length=0.16
		w.suspension_stiffness=55.0 if not big else 70.0;w.damping_compression=0.9;w.damping_relaxation=1.2
		w.wheel_friction_slip=3.2;w.wheel_roll_influence=0.03;w.suspension_max_force=60000.0 if big else 14000.0
		add_child(w);wheels.append(w)
	kopf_hoehe=ab.size.y+0.3
	parken()

func parken():
	modus="geparkt";freeze=false;engine_force=0;brake=6.0;steering=0
	sleeping=true

func als_ki(road,s:float,dir:int,lane:float,road_sys):
	S=road_sys;ki_road=road;ki_s=s;ki_dir=dir;ki_lane=lane;modus="ki"
	freeze_mode=RigidBody3D.FREEZE_MODE_KINEMATIC;freeze=true
	ki_ziel=randf_range(9.0,14.0) if road.typ!="autobahn" else randf_range(22.0,30.0)
	ki_speed=ki_ziel*0.6
	_ki_place(0.0)

func uebernehmen():
	modus="spieler";freeze=false;brake=0.0;sleeping=false

func kmh()->float:return linear_velocity.length()*3.6

func fahren(st,dt:float):
	if modus!="spieler":return
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
	var target=Transform3D(Basis.looking_at(Vector3(-t.x,0,-t.y),Vector3.UP),Vector3(p.x,y,p.y))
	if dt>0.0:
		var q=global_transform.basis.get_rotation_quaternion().slerp(target.basis.get_rotation_quaternion(),clamp(dt*5.0,0.0,1.0))
		global_transform=Transform3D(Basis(q),target.origin)
	else:global_transform=target
