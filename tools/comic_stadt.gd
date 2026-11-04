extends SceneTree
# Probestück der Comic-Stadt rendern (Bilder nach /home/claude/work/stadt/). Baustein: scripts/comic/stadt_lib.gd
func _init():
	await process_frame
	var w=Node3D.new();root.add_child(w)
	var L=load("res://scripts/comic/stadt_lib.gd").new()
	DirAccess.make_dir_recursive_absolute(L.OUT)
	L.init_lib(w)
	L.bauen_probe()
	await L._bilder()
	quit()
