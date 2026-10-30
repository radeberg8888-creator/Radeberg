extends SceneTree
func _init():
	await process_frame
	var w=Node3D.new();root.add_child(w)
	load("res://scripts/env.gd").make(w,"day")
	var FA=load("res://scripts/fahrer.gd");var r=RandomNumberGenerator.new();r.seed=3
	var p=FA.sitzend("joe",r);w.add_child(p);p.position=Vector3(-1.5,0,0)
	var auto=load("res://assets/cache/autos/mercedes.scn").instantiate();w.add_child(auto);auto.position=Vector3(1.5,0,0)
	FA.einsetzen(auto,FA.sitzend("daya",r))
	var cam=Camera3D.new();w.add_child(cam);cam.position=Vector3(1.5,1.5,5.5);cam.look_at(Vector3(1.5,0.9,0))
	for k in 8:await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/-home-claude/28bc4cd7-234a-5fda-badb-fa2be879c9df/scratchpad/fahrer.png")
	cam.position=Vector3(5.5,1.4,0.3);cam.look_at(Vector3(1.5,0.9,0))
	for k in 4:await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/-home-claude/28bc4cd7-234a-5fda-badb-fa2be879c9df/scratchpad/fahrer2.png")
	quit()
