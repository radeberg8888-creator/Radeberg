extends SceneTree
func _init():
	for f in ["res://scripts/welt_bloecke.gd","res://scripts/stadtbau.gd","res://scripts/people.gd","res://scripts/spiel/hud.gd"]:print("OK ",f," ",load(f)!=null)
	quit()
