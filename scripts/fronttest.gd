extends Node3D
const VH=preload("res://scripts/vehicles.gd")
func _ready():
	load("res://scripts/env.gd").make(self,"day")
	var g=MeshInstance3D.new();g.mesh=PlaneMesh.new();g.mesh.size=Vector2(400,400);add_child(g)
	var models={}
	for k in VH.LIST:models[VH.LIST[k][0]]=k
	var keys=models.keys();keys.sort()
	var cams=[]
	for i in keys.size():
		var k=models[keys[i]];var v=VH.make(k);add_child(v)
		var x=(i%5)*9.0;var z=-(i/5)*22.0;v.position=Vector3(x,0,z)
		var ab=load("res://scripts/fit.gd").aabb(v)
		var s=MeshInstance3D.new();s.mesh=SphereMesh.new();s.mesh.radius=0.35;s.mesh.height=0.7;add_child(s);s.position=Vector3(x,2.2,z+ab.end.z+0.4)
		var m=StandardMaterial3D.new();m.albedo_color=Color(1,0,0);m.emission_enabled=true;m.emission=Color(1,0,0);s.material_override=m
		var lb=Label3D.new();lb.text=keys[i];lb.font_size=64;lb.pixel_size=0.012;lb.rotation_degrees=Vector3(-90,0,0);add_child(lb);lb.position=Vector3(x-3.6,0.05,z-7)
	for i in keys.size():
		var x=(i%5)*9.0;var z=-(i/5)*22.0
		var vv=get_child(get_child_count()-1)
		cams.append([Vector3(x+0.01,7.0 if i!=7 and i!=8 and i!=11 else 20.0,z+0.6),Vector3(x,0,z+0.6),45.0])
	var c=Camera3D.new();c.far=500;add_child(c)
	var sh=load("res://scripts/shots.gd").new();add_child(sh);sh.setup(cams,"front")
