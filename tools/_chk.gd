extends SceneTree
func _init():
	for f in ["res://scripts/welt.gd","res://scripts/welt_leben.gd","res://scripts/welt_bauten.gd","res://scripts/welt_strassen.gd","res://scripts/vereinfachen.gd","res://scripts/spiel/spiel.gd","res://scripts/spiel/gebaeude_strom.gd"]:
		var s=load(f);print("CHK ",f," ",s!=null and s.can_instantiate())
	quit()
