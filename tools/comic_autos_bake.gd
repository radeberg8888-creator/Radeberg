extends SceneTree
# Comic-Autos als fahrbare Vorlagen (assets/cache/autos/c_*.scn), Liste in scripts/comic/comic_autos.gd
func _owner(n:Node,o:Node):
	for c in n.get_children():c.owner=o;_owner(c,o)
func _init():
	await process_frame
	var CA=load("res://scripts/comic/comic_autos.gd")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/cache/autos/"))
	var nur=OS.get_cmdline_user_args()
	for k in CA.LISTE:
		if nur.size()>0 and not k in nur:continue
		var car=CA.bauen(k);root.add_child(car)
		_owner(car,car)
		var ps=PackedScene.new();ps.pack(car)
		var err=ResourceSaver.save(ps,"res://assets/cache/autos/"+k+".scn",ResourceSaver.FLAG_COMPRESS)
		print("AUTO ",k," räder ",car.get_meta("raeder").size()," ",error_string(err))
		car.queue_free()
	quit()
