extends SceneTree
# Welt einmal erzeugen und als fertige Szene + Daten speichern (assets/cache/welt/). Mit echtem Renderer starten (xvfb + opengl3),
# damit MultiMesh-Daten (Bäume, Laternen) mitgespeichert werden.
func _init():
	await process_frame
	var W=load("res://scripts/welt.gd").new();W.spiel=true;root.add_child(W)
	var t0=Time.get_ticks_msec()
	await W.generate(func(a,b):print("  -> ",a," ",(Time.get_ticks_msec()-t0)/1000.0," s"))
	print("ERZEUGT ",(Time.get_ticks_msec()-t0)/1000.0," s")
	W._save_icons()
	var e=W.cache_speichern()
	print("GESPEICHERT ",e," ",(Time.get_ticks_msec()-t0)/1000.0," s")
	quit()
