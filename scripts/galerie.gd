extends Node3D
# Galerie: alle Einzelgebäude nebeneinander, je ein Foto (Schrägansicht)
const F=preload("res://scripts/fit.gd")
func _ready():
	load("res://scripts/env.gd").make(self,"day")
	var g=MeshInstance3D.new();g.mesh=PlaneMesh.new();g.mesh.size=Vector2(20000,20000);add_child(g)
	var gm=StandardMaterial3D.new();gm.albedo_color=Color(0.4,0.4,0.38);g.material_override=gm
	var files=[]
	for d in DirAccess.get_directories_at("res://assets/buildings/einzeln"):
		for f in DirAccess.get_files_at("res://assets/buildings/einzeln/"+d):
			if f.ends_with(".gltf"):files.append("res://assets/buildings/einzeln/"+d+"/"+f)
	files.sort()
	var cams=[];var i=0
	for f in files:
		var n=load(f).instantiate();add_child(n);n.position=Vector3(i*400,0,0)
		var ab=F.aabb(n);ab.position+=n.position
		var c=ab.get_center();var r=ab.size.length()*0.62
		cams.append([c+Vector3(0.62,0.32,0.72).normalized()*r*1.25,c,50.0])
		print("GAL ",i," ",f.get_file()," ",ab.size.snapped(Vector3.ONE*0.1))
		i+=1
	var cam=Camera3D.new();cam.far=3000;add_child(cam)
	var sh=load("res://scripts/shots.gd").new();add_child(sh);sh.setup(cams,"gal")
