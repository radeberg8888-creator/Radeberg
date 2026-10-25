extends Node3D
# Alle Fahrzeuge auf einem Platz (Vorschau): zwei Reihen Pkw, eine Reihe große Fahrzeuge
const VH=preload("res://scripts/vehicles.gd")
func _ready():
	var args=OS.get_cmdline_user_args()
	load("res://scripts/env.gd").make(self,"sunset" if "--sunset" in args else "day")
	var M=preload("res://scripts/mats.gd")
	var g=MeshInstance3D.new();g.mesh=PlaneMesh.new();g.mesh.size=Vector2(400,400);add_child(g);g.material_override=M.pbr("asphalt",0.18)
	var big=["feuerwehr","rtw","lkw","autotransporter","armored","rtw_alt","feuerwehr_alt","lkw_blau"]
	var small=[];for k in VH.LIST:if not k in big:small.append(k)
	for i in small.size():
		var v=VH.make(small[i]);add_child(v);v.position=Vector3((i%7)*3.6,0,-(i/7)*9.0);v.rotation.y=deg_to_rad(-20)
		_label(small[i],v.position+Vector3(0,0.02,3.4))
	for i in big.size():
		var v=VH.make(big[i]);add_child(v);v.position=Vector3(i*4.6,0,-34.0);v.rotation.y=deg_to_rad(-20)
		_label(big[i],v.position+Vector3(0,0.02,9.6 if big[i].begins_with("lkw") or big[i]=="feuerwehr" else 4.5))
	var c=Camera3D.new();c.far=600;add_child(c)
	var sh=load("res://scripts/shots.gd").new();add_child(sh)
	var pf="srs" if "--sunset" in args else "sr"
	sh.setup([[Vector3(6,2.2,9),Vector3(6,0.7,0),55.0],[Vector3(17,2.2,9),Vector3(17,0.7,0),55.0],[Vector3(5,2.4,0),Vector3(5,0.7,-9),55.0],[Vector3(17,2.4,0),Vector3(17,0.7,-9),55.0],[Vector3(6,2.4,-9),Vector3(6,0.7,-18),55.0],[Vector3(17,2.4,-9),Vector3(17,0.7,-18),55.0],[Vector3(3,3.0,-20),Vector3(4,1.4,-34),62.0],[Vector3(-3,3.5,-18),Vector3(0,1.6,-30),55.0]],pf)
func _label(k:String,p:Vector3):
	var lb=Label3D.new();lb.text=preload("res://scripts/vehicles.gd").LIST[k][2];lb.font_size=40;lb.pixel_size=0.006;add_child(lb);lb.position=p;lb.rotation_degrees=Vector3(-90,0,0);lb.modulate=Color(1,1,0.8)
