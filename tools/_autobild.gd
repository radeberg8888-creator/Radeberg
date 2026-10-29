extends SceneTree
# Einzelbilder von Fahrzeugen (Räder prüfen): -- kind1 kind2 ...
func _init():
	await process_frame
	var w=Node3D.new();root.add_child(w)
	load("res://scripts/env.gd").make(w,"day")
	var boden=MeshInstance3D.new();var pm=PlaneMesh.new();pm.size=Vector2(60,60);boden.mesh=pm;w.add_child(boden)
	var cam=Camera3D.new();w.add_child(cam)
	var AUTO=load("res://scripts/spiel/fahrzeug.gd")
	for k in OS.get_cmdline_user_args():
		var c=AUTO.new();w.add_child(c);c.setup(k);c.freeze=true;c.position=Vector3(0,0.0,0)
		for e in c.rad_knoten:e[0].rotation=Vector3(1.1,(0.45 if e[1].use_as_steering else 0.0),0)
		for ansicht in [[Vector3(3.0,1.2,3.4),"schraeg"],[Vector3(4.2,0.6,0),"seite"],[Vector3(-3.0,1.0,-3.0),"hinten"]]:
			cam.position=ansicht[0];cam.look_at(Vector3(0,0.5,0));cam.fov=55
			for i in 6:await process_frame
			root.get_viewport().get_texture().get_image().save_png("/home/claude/shots_godot/auto_%s_%s.png"%[k,ansicht[1]])
		c.queue_free();await process_frame
	quit()
