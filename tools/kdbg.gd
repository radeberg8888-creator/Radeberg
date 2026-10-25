extends SceneTree
func _init():
	var n=Node3D.new();n.set_script(load("res://scripts/stadtkarte.gd"));get_root().add_child(n)
	for i in 3:await process_frame
	quit()
