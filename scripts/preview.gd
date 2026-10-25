extends Node3D
const F=preload("res://scripts/fit.gd")
const U=preload("res://scripts/anim_util.gd")
func M(d:String,size:float,axis:=1)->Node3D:
	var n=load("res://assets/"+(d if d.get_file().ends_with("_rig") else d+"/"+d.get_file())+".gltf").instantiate()
	for m in n.find_children("*","MeshInstance3D",true,false):
		var nm=(m.name+" "+str(m.mesh.surface_get_material(0).resource_name if m.mesh.get_surface_count()>0 and m.mesh.surface_get_material(0) else "")).to_lower()
		if nm.contains("ground") or nm.ends_with(" floor") or nm.contains("shadow") or nm.contains("plane"):m.visible=false;print("hide ",d," ",nm)
	var w=F.place(n,size,axis);add_child(w);return w
func _ready():
	var wsrc=load("res://assets/animations/walking.glb").instantiate();add_child(wsrc);wsrc.visible=false
	var ap:AnimationPlayer=wsrc.find_child("AnimationPlayer",true,false);ap.stop();var walk=ap.get_animation(ap.get_animation_list()[0]);var wsk=U.find_skel(wsrc)
	load("res://scripts/env.gd").make(self,"day")
	var g=MeshInstance3D.new();g.mesh=PlaneMesh.new();g.mesh.size=Vector2(400,400);add_child(g)
	var x=0.0
	for c in [["vehicles/trabant",3.55,2],["vehicles/hudson",5.3,2],["vehicles/bugatti",4.4,2],["vehicles/dodge",4.9,2]]:
		var w=M(c[0],c[1],c[2]);w.position=Vector3(x,0,0);x+=3.2
	x=0.0
	for c in ["characters/biker","characters/james/james_rig","characters/police/police_rig","characters/daya","characters/woman/woman_rig"]:
		var w=M(c,1.8 if not c.contains("woman") else 1.68);w.position=Vector3(x,0,8);x+=1.4
		var ch=w.get_child(0);var sk=U.find_skel(ch)
		if sk:
			var old=ch.find_child("AnimationPlayer",true,false);if old:old.stop()
			U.play(ch,U.retarget_world(walk,wsk,wsrc,sk,ch),"walk",x*0.13)
	x=0.0
	for c in [["weapons/ar15",0.9,0],["weapons/mp5",0.65,2],["weapons/pistol_tac",0.22,2],["weapons/m1911",0.22,2]]:
		var w=M(c[0],c[1],c[2]);w.position=Vector3(x,1.0,16);x+=1.0
	var c=Camera3D.new();c.near=0.05;add_child(c)
	var sh=load("res://scripts/shots.gd").new();add_child(sh)
	sh.setup([[Vector3(3.5,1.2,14),Vector3(3.5,0.9,8),45.0],[Vector3(13,1.2,8),Vector3(3.5,0.9,8),40.0],[Vector3(3.5,1.4,2.5),Vector3(3.5,1.0,8),60.0],[Vector3(1.5,1.3,14.6),Vector3(1.5,1.05,16),55.0]],"prev")
