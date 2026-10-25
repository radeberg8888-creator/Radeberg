extends Node3D
const VH=preload("res://scripts/vehicles.gd")
const F=preload("res://scripts/fit.gd")
func _ready():
	load("res://scripts/env.gd").make(self,"day")
	var g=MeshInstance3D.new();g.mesh=PlaneMesh.new();g.mesh.size=Vector2(200,200);add_child(g)
	var x=0.0
	for k in ["bus","jdm"]:
		var v=VH.make(k);add_child(v);v.position=Vector3(x,0,0);x+=8
		var ab=F.aabb(v);print("AB ",k," ",ab)
		for m in v.find_children("*","MeshInstance3D",true,false):
			if not m.visible:print("  versteckt ",k," ",m.name," ",VH._matname(m))
	var c=Camera3D.new();add_child(c)
	var sh=load("res://scripts/shots.gd").new();add_child(sh)
	sh.setup([[Vector3(-9,1.2,0.01),Vector3(0,0.8,0),45.0],[Vector3(8,0.6,-7),Vector3(8,0.5,0),45.0]],"vchk")
