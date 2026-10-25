extends Node3D
func _ready():
	load("res://scripts/env.gd").make(self,"day")
	for c in get_children():
		if c is WorldEnvironment:c.environment.fog_enabled=false
	var g=MeshInstance3D.new();g.mesh=PlaneMesh.new();g.mesh.size=Vector2(4000,4000);add_child(g)
	var GEL=load("res://scripts/welt_gelaende.gd").new();var BAU=load("res://scripts/welt_bauten.gd").new(GEL,null)
	var names=["cityscene2_04","cityscene2_13","cityscene2_20","city_13","city_01","nyc_00","chicago_00","city3_02","cityscene_00","nycity_02","proc3_01","seoul_01"]
	var i=0;var t0=Time.get_ticks_msec()
	for n in names:
		var t=BAU.get_tpl(n);var w=BAU.instance(t,0,0.2);add_child(w);w.position=Vector3((i%4)*110,0,(i/4)*110)
		print(n," Dach ",t.roof!=null);i+=1
	print("Zeit ",Time.get_ticks_msec()-t0)
	var cam=Camera3D.new();cam.far=3000;add_child(cam)
	var sh=load("res://scripts/shots.gd").new();add_child(sh);var cams=[]
	for k in names.size():
		var c=Vector3((k%4)*110,0,(k/4)*110)
		cams.append([c+Vector3(45,70,60),c+Vector3(0,15,0),50.0])
	sh.setup(cams,"dach")
