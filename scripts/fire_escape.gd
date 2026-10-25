extends RefCounted
# Setzt eine Feuertreppe (Poly Haven, modular) über mehrere Stockwerke zusammen.
# Lokal: x entlang der Wand, y hoch, -z von der Wand weg (Rückseite liegt an der Wand bei z=0)
const D="res://assets/props/polyhaven/fire_escape/fe_"
static func _p(n:String)->Node3D:return load(D+n+".glb").instantiate()
static func build(levels:Array)->Node3D:
	var root=Node3D.new()
	for i in levels.size():
		var y:float=levels[i]
		var pl=_p("platform_middle");root.add_child(pl);pl.position=Vector3(-0.077,y-0.072,0.168-0.68)
		var rl=_p("railing_middle");root.add_child(rl);rl.position=Vector3(0.002-0.077+0.075,y+0.635,0.419-0.68)
		if i+1<levels.size():
			var st=_p("stairs");root.add_child(st)
			var rise=levels[i+1]-y
			st.scale=Vector3(1,rise/3.1,1);st.position=Vector3(0.2,y+2.402*st.scale.y,0.456-0.68)
	var ld=_p("ladder_bottom");root.add_child(ld);var ls=(levels[0]+0.9-1.4)/6.466;ld.scale=Vector3(1,ls,1);ld.position=Vector3(-1.8,levels[0]+0.9-2.901*ls,-1.2)
	return root
