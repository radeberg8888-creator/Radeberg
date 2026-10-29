extends SceneTree
# Sichtbare Dreiecke (obere Grenze, ohne Blickfeld) an einigen Orten nach Sichtweiten
var mc={}
func _tri(mesh)->int:
	if mc.has(mesh):return mc[mesh]
	var t=0
	for s in mesh.get_surface_count():
		var a=mesh.surface_get_arrays(s);var I=a[Mesh.ARRAY_INDEX];t+=(I.size() if I else a[0].size())/3
	mc[mesh]=t;return t
func _init():
	var w:Node3D=load("res://assets/cache/welt/welt.scn").instantiate()
	var liste=[]
	var unbegrenzt=0
	for m in w.find_children("*","GeometryInstance3D",true,false):
		var tri=0;var ab=AABB();var dc=0
		if m is MeshInstance3D and m.mesh:tri=_tri(m.mesh);ab=m.global_transform*m.get_aabb() if m.is_inside_tree() else _gx(m)*m.get_aabb();dc=m.mesh.get_surface_count()
		elif m is MultiMeshInstance3D and m.multimesh and m.multimesh.mesh:tri=_tri(m.multimesh.mesh)*m.multimesh.instance_count;ab=_gx(m)*m.get_aabb();dc=m.multimesh.mesh.get_surface_count()
		else:continue
		if m.visibility_range_end<=0.0:unbegrenzt+=tri
		liste.append([ab,m.visibility_range_begin,m.visibility_range_end,tri,dc,str(w.get_path_to(m)).get_slice("/",0)])
	print("AUD Knoten ",liste.size()," unbegrenzt sichtbare Dreiecke ",unbegrenzt)
	for ort in [["Grove",Vector3(-250,20,730)],["Downtown",Vector3(300,20,-330)],["Flusstal",Vector3(-1300,150,-4400)],["Berg",Vector3(-750,500,-7800)],["Sonnenhuegel",Vector3(-250,100,-1750)]]:
		var p:Vector3=ort[1];var sum=0;var dcs=0;var grp={}
		for e in liste:
			var ab:AABB=e[0]
			var q=p.clamp(ab.position,ab.end);var d=p.distance_to(q)
			if d<e[1] or (e[2]>0.0 and d>e[2]):continue
			sum+=e[3];dcs+=e[4];grp[e[5]]=grp.get(e[5],0)+e[3]
		print("AUD ",ort[0]," Dreiecke ",sum," Aufrufe ",dcs," ",grp)
	quit()
func _gx(n:Node)->Transform3D:
	var t=Transform3D.IDENTITY;var c=n
	while c!=null and c is Node3D:
		t=c.transform*t;c=c.get_parent()
	return t
