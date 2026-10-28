extends SceneTree
# Vorab: mittlere Texturfarben aller Figuren in assets/cache/median_farben.json schreiben
# godot --headless --path . -s res://tools/median_bake.gd
func _init():
	var PE=load("res://scripts/people.gd")
	for b in PE.BASES:
		for i in 6:
			var r=RandomNumberGenerator.new();r.seed=i*7919+hash(b)
			var n=PE.make(b,r);n.free()
		print("ok ",b)
	quit()
