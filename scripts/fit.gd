extends RefCounted
# Hilfen für fremde Modelle: echte Begrenzung (über alle Eltern-Transformationen) und Einpassen auf Zielgröße
static func rel_xf(n:Node,root:Node)->Transform3D:
	var t=Transform3D.IDENTITY;var c=n
	while c!=null and c!=root:
		if c is Node3D:t=c.transform*t
		c=c.get_parent()
	return t
static func aabb(root:Node3D)->AABB:
	var ab=AABB();var first=true
	for m in root.find_children("*","MeshInstance3D",true,false):
		if not m.visible:continue
		var a:AABB
		if m.skin!=null or m.skeleton!=NodePath():
			a=rel_xf(m,root)*m.get_aabb()
		else:a=rel_xf(m,root)*m.get_aabb()
		if first:ab=a;first=false
		else:ab=ab.merge(a)
	return ab
# Modell so skalieren, dass seine Höhe (axis=1) bzw. Länge (axis=2/0) = size, Boden auf y=0, mittig
static func place(root:Node3D,size:float,axis:=1)->Node3D:
	var ab=aabb(root);var s=size/max(ab.size[axis],0.0001)
	var wrap=Node3D.new();wrap.add_child(root)
	root.scale=root.scale*s
	var c=ab.get_center()*s
	root.position=Vector3(-c.x,-ab.position.y*s,-c.z)
	return wrap
