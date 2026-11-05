extends SceneTree
# Sucht Hindernisse AUF den Fahrbahnen (Strahl über die ganze Breite) und Rampenbuckel
func _init():
	await process_frame
	var w=load("res://assets/cache/comic/welt.scn").instantiate();root.add_child(w);w.aus_cache()
	for k in 3:await physics_frame
	var sp=w.get_world_3d().direct_space_state
	var n=0
	for r in w.S.roads:
		var schlecht=0
		for i in range(0,r.P.size(),2):
			var p:Vector2=r.P[i];var h:float=r.h[i];var t:Vector2=r.T[i];var nn=Vector2(-t.y,t.x)
			for f in [-0.8,-0.5,-0.2,0.2,0.5,0.8]:
				var q=p+nn*r.w*f
				var hit=sp.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(q.x,h+2.5,q.y),Vector3(q.x,h-1.0,q.y)))
				if hit and hit.position.y-h>0.3:
					schlecht+=1
					if schlecht<=2:print("  HINDERNIS ",r.name," bei ",q.round()," +%.2f m"%(hit.position.y-h))
		if schlecht>0:print("PRUEF ",r.name," Hindernisse ",schlecht);n+=schlecht
	print("GESAMT ",n)
	quit()
