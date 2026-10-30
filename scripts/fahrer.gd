extends RefCounted
# Fahrerfigur: eine Person in Sitzhaltung (Oberschenkel nach vorn, Knie angewinkelt, Hände am Lenkrad),
# auf den Fahrersitz eines Autos gesetzt. Keine Animation nötig – kostet daher kaum Leistung.
const PE=preload("res://scripts/people.gd")
const U=preload("res://scripts/anim_util.gd")
const F=preload("res://scripts/fit.gd")

static func sitzend(basis:String,rng:RandomNumberGenerator)->Node3D:
	var p=PE.make(basis,rng)
	var ap:AnimationPlayer=p.get_meta("anim",null)
	var sk:Skeleton3D=U.find_skel(p)
	if sk==null or ap==null:return p
	# Achse "seitlich" (Körper-x) im Skelettraum
	var achse=(F.rel_xf(sk,p).basis.inverse()*Vector3(1,0,0)).normalized()
	var bones={}
	for i in sk.get_bone_count():bones[U.human_key(sk.get_bone_name(i))]=i
	var a=Animation.new();a.length=1.0;a.loop_mode=Animation.LOOP_LINEAR
	var pfad=str(ap.get_node(ap.root_node).get_path_to(sk))
	var winkel={"LeftUpLeg":-85.0,"RightUpLeg":-85.0,"LeftLeg":75.0,"RightLeg":75.0,"LeftArm":-50.0,"RightArm":-50.0,"LeftForeArm":-40.0,"RightForeArm":-40.0}
	var n=0
	for k in winkel:
		if not bones.has(k):continue
		var i=bones[k];var par=sk.get_bone_parent(i)
		var pg:Basis=sk.get_bone_global_rest(par).basis.orthonormalized() if par>=0 else Basis()
		var lok:Quaternion=sk.get_bone_rest(i).basis.orthonormalized().get_rotation_quaternion()
		var R=Basis(achse,deg_to_rad(winkel[k]))
		var neu=(pg.inverse()*R*pg).get_rotation_quaternion()*lok
		var t=a.add_track(Animation.TYPE_ROTATION_3D);a.track_set_path(t,pfad+":"+sk.get_bone_name(i))
		a.rotation_track_insert_key(t,0.0,neu);a.rotation_track_insert_key(t,1.0,neu);n+=1
	var lib:AnimationLibrary=ap.get_animation_library("")
	if lib.has_animation("sitzen"):lib.remove_animation("sitzen")
	lib=lib.duplicate();lib.add_animation("sitzen",a)
	ap.remove_animation_library("");ap.add_animation_library("",lib)
	ap.play("sitzen")
	p.set_meta("sitzt",n)
	return p

# Person auf den Fahrersitz setzen (Auto-Front = +Z, Fahrer links = +X)
static func einsetzen(auto:Node3D,person:Node3D):
	var ab:AABB=F.aabb(auto)
	var sk:Skeleton3D=U.find_skel(person)
	var huefte_y=0.9
	if sk:
		for i in sk.get_bone_count():
			if U.human_key(sk.get_bone_name(i))=="Hips":
				huefte_y=(F.rel_xf(sk,person)*sk.get_bone_global_pose(i).origin).y*person.scale.y;break
	auto.add_child(person)
	var sitz=Vector3(ab.get_center().x+ab.size.x*0.19,ab.position.y+ab.size.y*0.44,ab.get_center().z-ab.size.z*0.09)
	person.position=sitz-Vector3(0,huefte_y,0)
	person.rotation=Vector3.ZERO
