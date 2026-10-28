extends SceneTree
func _init():
	for p in ["res://scripts/welt_anlagen.gd","res://scripts/welt.gd","res://scripts/welt_leben.gd","res://scripts/welt_bauten.gd","res://scripts/spiel/story.gd","res://scripts/spiel/wirtschaft.gd","res://scripts/spiel/kampf.gd","res://scripts/spiel/spiel.gd"]:
		var s=load(p);print(p," ",s!=null and s.can_instantiate())
	quit()
