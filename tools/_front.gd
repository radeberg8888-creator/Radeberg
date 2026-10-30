extends SceneTree
# Je Gebäudevorlage: Vorderseite (Seite mit den meisten Details) und Bodenhöhe der Wände
func _init():
	var B=load("res://scripts/welt_bauten.gd").new(load("res://scripts/welt_gelaende.gd").new(),null)
	var erg={};var erg_cnt={}
	for name in B._meta().keys():
		var t=B.get_tpl(name);var ab:AABB=t.ab
		var m:ArrayMesh=load("res://assets/cache/geb/"+name+".res")
		var hx=ab.size.x*0.5;var hz=ab.size.z*0.5
		var cnt=[0,0,0,0]   # +z,-z,+x,-x
		var wand_y=[]
		for s in m.get_surface_count():
			var a=m.surface_get_arrays(s);var V:PackedVector3Array=a[0];var N=a[Mesh.ARRAY_NORMAL]
			var mt=m.surface_get_material(s)
			if mt is BaseMaterial3D and mt.transparency!=0:continue
			for i in range(0,V.size(),max(1,V.size()/20000)):
				var v=V[i]
				if v.y<1.0:continue
				var d=[hz-v.z,v.z+hz,hx-v.x,v.x+hx]
				var k=0;for j in 4:if d[j]<d[k]:k=j
				if d[k]<1.5:cnt[k]+=1
				if N and abs(N[i].y)<0.3:wand_y.append(v.y)
		# Bodenhöhe der Wände: tiefste Wandecken (ohne Ausreißer)
		var alle=[]
		for s in m.get_surface_count():
			var a=m.surface_get_arrays(s);var V:PackedVector3Array=a[0];var N=a[Mesh.ARRAY_NORMAL]
			for i in range(0,V.size(),max(1,V.size()/20000)):
				if N and abs(N[i].y)<0.3:alle.append(V[i].y)
		alle.sort()
		var boden=alle[int(alle.size()*0.03)] if alle.size()>0 else 0.0
		var k=0;for j in 4:if cnt[j]>cnt[k]:k=j
		var tot=cnt[0]+cnt[1]+cnt[2]+cnt[3]
		erg_cnt[name]=cnt
		var seiten=[]
		for j in 4:
			if cnt[j]>=0.15*max(tot,1):seiten.append(["+z","-z","+x","-x"][j])
		erg[name]={"seiten":seiten,"vorn":["+z","-z","+x","-x"][k],"anteil":snapped(float(cnt[k])/max(tot,1),0.01),"boden":snapped(boden,0.01),"b":snapped(ab.size.x,0.1),"t":snapped(ab.size.z,0.1),"h":snapped(ab.size.y,0.1)}
		print("FRONT ",name," ",erg[name])
	var f=FileAccess.open("res://assets/daten/fronten.json",FileAccess.WRITE);f.store_string(JSON.stringify(erg));f.close()
	quit()
