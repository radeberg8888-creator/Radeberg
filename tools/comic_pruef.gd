extends SceneTree
# Prüft die gebackene Comic-Welt per Strahl: Fahrbahnhöhe entlang Rampen/Autobahn (Buckel) und Leitplanken-Kollision.
func _init():
	await process_frame
	var w=load("res://assets/cache/comic/welt.scn").instantiate();root.add_child(w);w.aus_cache()
	for k in 3:await physics_frame
	var sp=w.get_world_3d().direct_space_state
	var ray=func(a:Vector3,b:Vector3):
		var q=PhysicsRayQueryParameters3D.create(a,b);return sp.intersect_ray(q)
	for r in w.S.roads:
		if not r.typ in ["rampe","autobahn"]:continue
		var schlecht=0;var maxd=0.0;var bei=Vector2.ZERO;var n=0
		for i in range(0,r.P.size(),1):
			var p:Vector2=r.P[i];var h:float=r.h[i]
			var hit=ray.call(Vector3(p.x,h+2.5,p.y),Vector3(p.x,h-3,p.y))
			if hit.is_empty():continue
			n+=1
			var d=hit.position.y-h
			if r.name in ["Abfahrt Nord","Auffahrt Süd"]:print("  ",r.name," i=",i," p=",p.round()," lokal=",(p-Vector2(-200,500)).round()," h=%.2f d=%.2f "%[h-7.0,d],hit.collider.name)
			if abs(d)>0.12:
				schlecht+=1
				if abs(d)>abs(maxd):maxd=d;bei=p
		# Leitplanke: quer von der Mitte nach außen auf 0.5 m Höhe
		var ohne=0;var ges=0
		for i in range(2,r.P.size()-2,5):
			var p:Vector2=r.P[i];var h:float=r.h[i];var t:Vector2=r.T[i];var rn=Vector2(-t.y,t.x)
			if h<1.0:continue
			for sd in [-1,1]:
				ges+=1
				var a=Vector3(p.x,h+0.5,p.y);var e=a+Vector3(rn.x,0,rn.y)*sd*(r.w+2.5)
				if ray.call(a,e).is_empty():ohne+=1
		print("PRUEF %s typ=%s punkte=%d buckel=%d max=%.2f bei %s  leitplanke_fehlt=%d/%d"%[r.name,r.typ,n,schlecht,maxd,str(bei.round()),ohne,ges])
	quit()
