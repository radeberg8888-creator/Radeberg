extends SceneTree
func _init():
	await process_frame
	var W=load("res://scripts/welt.gd").new();W.spiel=true;root.add_child(W)
	var t0=Time.get_ticks_msec()
	await W.generate(func(a,b):print("  -> ",a," ",(Time.get_ticks_msec()-t0)/1000.0," s  RAM ",OS.get_static_memory_usage()/1048576))
	print("GESAMT ",(Time.get_ticks_msec()-t0)/1000.0," s")
	var cnt={}
	for p in W.B.placed:cnt[p.d]=cnt.get(p.d,0)+1
	print("PLATZ ",cnt," Villen ",W.A.villen.size())
	quit()
