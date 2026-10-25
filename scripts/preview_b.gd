extends Node3D
const F=preload("res://scripts/fit.gd")
func _ready():
	load("res://scripts/env.gd").make(self,"day")
	var cams=[];var x=0.0
	for d in ["buildings/nycity"]:
		var n=load("res://assets/"+d+"/"+d.get_file()+".gltf").instantiate();add_child(n);n.position=Vector3(x,0,0)
		var ab=F.aabb(n);ab.position+=n.position
		var c=ab.get_center();var r=ab.size.length()*0.55
		for v in [Vector3(0.6,0.5,0.8),Vector3(-0.7,0.35,-0.6)]:cams.append([c+v*r*0.9,c,50.0])
		cams.append([Vector3(c.x,1.7,c.z+ab.size.z*0.15),Vector3(c.x+20,4,c.z-30),62.0])
		print("B ",d," ",ab.size)
		x+=1500
	var c=Camera3D.new();c.far=4000;add_child(c)
	var sh=load("res://scripts/shots.gd").new();add_child(sh);sh.setup(cams,"bld")
