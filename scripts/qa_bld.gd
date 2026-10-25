extends Node3D
# Prüfansicht: ein Gebäudemodell von 4 Seiten + oben (so, wie es im Spiel ohne Korrektur aussieht)
const F=preload("res://scripts/fit.gd")
func _ready():
	var args=OS.get_cmdline_user_args();var d=args[0];var sc=float(args[1]) if args.size()>1 else 1.0
	load("res://scripts/env.gd").make(self,"day")
	var g=MeshInstance3D.new();g.mesh=PlaneMesh.new();g.mesh.size=Vector2(2000,2000);add_child(g)
	var gm=StandardMaterial3D.new();gm.albedo_color=Color(0.35,0.36,0.33);g.material_override=gm
	var n=load("res://assets/"+d+"/"+d.get_file()+".gltf").instantiate();var w=Node3D.new();add_child(w);w.add_child(n);n.scale=Vector3.ONE*sc
	var ab=F.aabb(w);n.position=Vector3(-ab.get_center().x,-ab.position.y,-ab.get_center().z);ab=F.aabb(w)
	var r=max(ab.size.x,ab.size.z)*0.75+ab.size.y*0.4;var c=Vector3(0,ab.size.y*0.4,0)
	var cams=[]
	for v in [Vector3(0,0.3,1),Vector3(1,0.3,0),Vector3(0,0.3,-1),Vector3(-1,0.3,0),Vector3(0.6,1.2,0.6)]:cams.append([c+v.normalized()*r*1.25,c,50.0])
	var cam=Camera3D.new();cam.far=5000;add_child(cam)
	var sh=load("res://scripts/shots.gd").new();add_child(sh);sh.setup(cams,"qa_"+d.get_file())
	print("SIZE ",d," ",ab.size)
