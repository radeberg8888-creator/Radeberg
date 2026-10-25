extends SceneTree
func _init():
	var VH=load("res://scripts/vehicles.gd");var F=load("res://scripts/fit.gd")
	for k in ["jdm","bus"]:
		var v=VH.make(k)
		var rows=[]
		for m in v.find_children("*","MeshInstance3D",true,false):
			if not m.visible:continue
			var a=F.rel_xf(m,v)*m.get_aabb()
			rows.append([a.position.y,str(m.name)+" "+VH._matname(m),a.size])
		rows.sort_custom(func(a,b):return a[0]<b[0])
		print("== ",k)
		for r in rows.slice(0,8):print("  ",snapped(r[0],0.001)," ",r[1]," ",r[2])
	quit()
