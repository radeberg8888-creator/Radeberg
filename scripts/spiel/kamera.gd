extends Node3D
# Verfolgerkamera (3. Person): frei drehbar per Wischen/rechtem Stick, im Auto automatisch hinter dem Wagen.
var ziel:Node3D
var yaw:=0.0
var pitch:=-12.0
var dist:=4.2
var hoehe:=1.6
var im_auto:=false
var _ruhe:=0.0
var cam:Camera3D
var arm:SpringArm3D
var nah:=false
var zielen:=false
var scope:=false
var _kick:=0.0
var _ziel_t:=0.0

func rueckstoss(st:float):_kick+=st

func _ready():
	arm=SpringArm3D.new();add_child(arm);arm.spring_length=dist;arm.margin=0.3
	var sh=SphereShape3D.new();sh.radius=0.25;arm.shape=sh
	cam=Camera3D.new();arm.add_child(cam);cam.far=4000.0;cam.near=0.15;cam.fov=68.0;cam.current=true

func setze_ziel(n:Node3D,auto:bool,ausnahme:=[]):
	ziel=n;im_auto=auto
	arm.clear_excluded_objects()
	for e in ausnahme:arm.add_excluded_object(e.get_rid())
	if auto:
		dist=7.5 if not nah else 5.0;hoehe=2.2
		if n.has_method("kmh") and n.ab.size.z>7.0:dist=13.0;hoehe=3.6
	else:dist=4.0 if not nah else 2.6;hoehe=1.55

func drehen(d:Vector2):
	yaw-=deg_to_rad(d.x);pitch=clamp(pitch-d.y,-70.0,35.0)
	if d.length()>0.01:_ruhe=0.0

func _process(dt):
	if ziel==null:return
	_ruhe+=dt
	var p=ziel.global_position+Vector3(0,hoehe,0)
	if im_auto:
		var fw=ziel.global_transform.basis.z;fw.y=0
		if fw.length()>0.1 and _ruhe>1.2:
			var want=atan2(fw.x,fw.z)+PI
			var v=ziel.linear_velocity.dot(ziel.global_transform.basis.z) if ziel is RigidBody3D else 0.0
			if v<-2.0:want+=PI   # rückwärts: nach vorn schauen
			yaw=lerp_angle(yaw,want,clamp(dt*2.5,0.0,1.0));pitch=lerp(pitch,-9.0,dt*1.5)
	# Zielen: über die rechte Schulter, näher dran, engeres Sichtfeld
	_ziel_t=move_toward(_ziel_t,1.0 if zielen and not im_auto else 0.0,dt*6.0)
	var rechts=Vector3(cos(yaw),0,-sin(yaw))
	p+=rechts*0.55*_ziel_t+Vector3(0,0.05,0)*_ziel_t
	global_position=global_position.lerp(p,clamp(dt*14.0,0.0,1.0)) if global_position.distance_to(p)<20 else p
	_kick=move_toward(_kick,0.0,dt*10.0)
	pitch=clamp(pitch+_kick*dt*6.0,-70.0,35.0)
	rotation=Vector3(deg_to_rad(pitch),yaw,0)
	arm.spring_length=lerp(arm.spring_length,lerp(dist,1.9,_ziel_t),dt*8.0)
	cam.fov=lerp(68.0,16.0 if scope else 52.0,_ziel_t)
	# Kamera an der Wand ganz nah an die Figur gedrückt: Figur ausblenden statt durch den Kopf zu schauen
	if not im_auto and ziel is Node3D:
		var nah_dran=arm.get_hit_length()<1.0
		if ziel.visible==nah_dran:ziel.visible=not nah_dran
	elif ziel and not ziel.visible:ziel.visible=true

# Blickrichtung (für die Laufsteuerung): Vorwärts der Kamera auf dem Boden
func blick_yaw()->float:return yaw+PI
