extends SceneTree
# Zerlegt Stadt-Chunks in Einzelgebäude: Meshes, deren Grundrisse sich überlappen, bilden ein Gebäude.
# Boden-/Straßenteile (flach & groß) werden ausgelassen. Ergebnis: res://assets/buildings/library.json
func _init():
	var F=load("res://scripts/fit.gd")
	var lib={}
	var cfg={"buildings/proc3":1.0,"buildings/nycity":1.0,"buildings/city3":1.0,"buildings/beautiful":9.0,"buildings/seoul":8.0,"buildings/cityscene":1.0,"buildings/cityscene2":1.0}
	for p in cfg:
		var sc:float=cfg[p]
		var n=load("res://assets/"+p+"/"+p.get_file()+".gltf").instantiate()
		var tot=F.aabb(n);var gy=tot.position.y
		var items=[]
		for m in n.find_children("*","MeshInstance3D",true,false):
			var a:AABB=F.rel_xf(m,n)*m.get_aabb()
			var flat=a.size.y<1.2/sc and max(a.size.x,a.size.z)>6.0/sc
			if flat:continue
			if max(a.size.x,a.size.z)>0.7*max(tot.size.x,tot.size.z):continue
			items.append([str(n.get_path_to(m)),a])
		# Union-Find über Grundriss-Überlappung (leicht vergrößert)
		var par=range(items.size())
		var find=func(f,i):
			while par[i]!=i:par[i]=par[par[i]];i=par[i]
			return i
		for i in items.size():
			var ai:AABB=items[i][1];var ri=Rect2(ai.position.x,ai.position.z,ai.size.x,ai.size.z).grow(0.15/sc)
			for j in range(i+1,items.size()):
				var aj:AABB=items[j][1];var rj=Rect2(aj.position.x,aj.position.z,aj.size.x,aj.size.z)
				if ri.intersects(rj):
					var x=find.call(find,i);var y=find.call(find,j)
					if x!=y:par[x]=y
		var groups={}
		for i in items.size():
			var r=find.call(find,i)
			if not groups.has(r):groups[r]=[[],items[i][1]]
			groups[r][0].append(items[i][0]);groups[r][1]=groups[r][1].merge(items[i][1])
		var out=[]
		for g in groups.values():
			var a:AABB=g[1]
			var h=(a.end.y-gy)*sc;var w=a.size.x*sc;var d=a.size.z*sc
			if h<6.0 or w<5.0 or d<5.0 or w>90 or d>90:continue
			out.append({"nodes":g[0],"pos":[a.position.x,gy,a.position.z],"size":[a.size.x,a.end.y-gy,a.size.z],"scale":sc,"h":h,"w":w,"d":d})
		lib[p]=out
		print(p," Gebäude: ",out.size()," Höhen: ",out.map(func(o):return int(o.h)))
	var f=FileAccess.open("res://assets/buildings/library.json",FileAccess.WRITE);f.store_string(JSON.stringify(lib));f.close()
	quit()
