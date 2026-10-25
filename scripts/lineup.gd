extends Node3D
func _ready():
	var E=load("res://scripts/env.gd");E.make(self,"res://assets/hdri/potsdamer_platz_1k.hdr",Vector3(-0.5,0.8,0.6).normalized())
	var g=MeshInstance3D.new();var pm=PlaneMesh.new();pm.size=Vector2(40,40);g.mesh=pm;var mt=StandardMaterial3D.new();mt.albedo_color=Color(0.45,0.44,0.42);mt.roughness=0.9;g.material_override=mt;add_child(g)
	var names=["ch14","rpm","rpm2","michelle","soldier","hvgirl"];var x=-5.0
	for n in names:
		var s=load("res://assets/characters/%s.glb"%n).instantiate();add_child(s);s.position=Vector3(x,0,0)
		var aabb=_aabb(s);var h=aabb.size.y
		if h>0.01 and (h<1.2 or h>2.4):s.scale*=1.75/h;print(n," height ",h)
		var ap=s.find_child("AnimationPlayer",true,false)
		if ap and ap.get_animation_list().size()>0:print(n," anims ",ap.get_animation_list())
		x+=2.0
	var cam=Camera3D.new();add_child(cam);cam.position=Vector3(0,1.4,6)
	var sh=load("res://scripts/shots.gd").new();add_child(sh)
	sh.setup([[Vector3(0,1.3,7.5),Vector3(0,1.0,0),40.0],[Vector3(-4.2,1.6,1.4),Vector3(-5,1.55,0),30.0],[Vector3(-2.2,1.6,1.4),Vector3(-3,1.5,0),30.0]],"lineup")
func _aabb(n:Node)->AABB:
	var a=AABB();var first=true
	for m in n.find_children("*","MeshInstance3D",true,false):
		var b=m.global_transform*m.get_aabb()
		if first:a=b;first=false
		else:a=a.merge(b)
	return a
