extends Node3D
const U=preload("res://scripts/anim_util.gd")
func _ready():
	var E=load("res://scripts/env.gd");E.make(self,"res://assets/hdri/potsdamer_platz_1k.hdr",Vector3(-0.5,0.8,0.6).normalized())
	var g=MeshInstance3D.new();var pm=PlaneMesh.new();pm.size=Vector2(40,40);g.mesh=pm;var mt=StandardMaterial3D.new();mt.albedo_color=Color(0.45,0.44,0.42);mt.roughness=0.9;g.material_override=mt;add_child(g)
	var wsrc=load("res://assets/animations/walking.glb").instantiate();add_child(wsrc);wsrc.visible=false
	var wap:AnimationPlayer=wsrc.find_child("AnimationPlayer",true,false);print("walk anims ",wap.get_animation_list())
	var wanim=wap.get_animation(wap.get_animation_list()[0]);var wskel=U.find_skel(wsrc)
	var x=-3.0
	for n in ["rpm","rpm2","michelle","soldier"]:
		var s=load("res://assets/characters/%s.glb"%n).instantiate();add_child(s);s.position=Vector3(x,0,0)
		var sk=U.find_skel(s);var old=s.find_child("AnimationPlayer",true,false);if old:old.stop()
		var an=U.retarget(wanim,wskel,sk,s);U.play(s,an,"walk",0.4+x*0.1);x+=2.0
	var cam=Camera3D.new();add_child(cam)
	var sh=load("res://scripts/shots.gd").new();add_child(sh)
	sh.setup([[Vector3(0,1.3,6.5),Vector3(0,1.0,0),40.0],[Vector3(4,1.4,4),Vector3(-1,1.0,0),40.0]],"walk")
