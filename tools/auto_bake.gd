extends SceneTree
# Alle Fahrzeuge vorbereiten: Modell laden, nach vorne (+Z) drehen, Räder herauslösen, als Szene speichern.
# godot --headless --path . -s res://tools/auto_bake.gd [-- kind kind ...]
const OVR={}
func _own(n:Node,root:Node):
	for c in n.get_children():
		c.owner=root;c.scene_file_path="";_own(c,root)
# flache, breite Platten am Boden (Schattenflächen, Bodenplatten) ausblenden und Auto neu zentrieren
func _ebenen_weg(n:Node3D):
	var F=load("res://scripts/fit.gd")
	var tot=F.aabb(n)
	for m in n.find_children("*","MeshInstance3D",true,false):
		if not m.visible:continue
		var a=F.rel_xf(m,n)*m.get_aabb()
		if a.size.y<0.04 and a.position.y<tot.position.y+0.06 and (a.size.x>tot.size.x*0.8 or a.size.z>tot.size.z*0.8):
			m.visible=false;print("  Bodenplatte ausgeblendet: ",m.name)
	var t2=F.aabb(n);var d=Vector3(t2.get_center().x,t2.position.y,t2.get_center().z)
	if d.length()>0.02:
		for c in n.get_children():c.position-=d
		print("  neu zentriert ",d)
func _unown(n:Node):
	for c in n.get_children():
		c.owner=null;_unown(c)
func _init():
	var VH=load("res://scripts/vehicles.gd");var RS=load("res://scripts/rad_split.gd")
	DirAccess.make_dir_recursive_absolute("res://assets/cache/autos")
	var kinds=OS.get_cmdline_user_args()
	if kinds.is_empty():kinds=VH.LIST.keys()
	for k in kinds:
		var n:Node3D=VH.make(k);root.add_child(n)
		if n.get_meta("front",1.0)<0:
			for c in n.get_children():c.transform=Transform3D(Basis(Vector3.UP,PI))*c.transform
			n.set_meta("front",1.0)
		var ov=VH.RAD.get(VH.LIST[k][0],{})
		_ebenen_weg(n)
		var ov_roh=ov.duplicate();ov_roh["roh"]=true
		var w=RS.find(n,ov_roh)
		# schief liegende Modelle gerade drehen (Achse vorne-hinten auf +Z)
		if w.size()==4:
			var vf=Vector3.ZERO;var hf=Vector3.ZERO
			for x in w:
				if x.vorne:vf+=x.p*0.5
				else:hf+=x.p*0.5
			var d=vf-hf;var yaw=atan2(d.x,d.z)
			if abs(yaw)>0.01 and abs(yaw)<0.6:
				var mid=(vf+hf)*0.5;mid.y=0
				for c in n.get_children():c.transform=Transform3D(Basis(),mid)*Transform3D(Basis(Vector3.UP,-yaw))*Transform3D(Basis(),-mid)*c.transform
				print("  gedreht um ",rad_to_deg(-yaw)," Grad")
				_ebenen_weg(n)
		w=RS.find(n,ov)
		if w.size()==4:
			# auf die Reifen stellen
			var low=INF
			for x in w:low=min(low,x.p.y-x.r)
			if abs(low)>0.005:
				for c in n.get_children():c.position.y-=low
				for x in w:x.p.y-=low
				print("  Höhe korrigiert um ",-low)
		var info=[]
		for x in w:info.append("%s%s p=%s r=%.2f b=%.2f"%["V" if x.vorne else "H","L" if x.links else "R",x.p.snapped(Vector3.ONE*0.01),x.r,x.breite])
		_unown(n)
		var mv=RS.split(n,w)
		print(k,": ",mv," Teile  ",info)
		_own(n,n)
		var ps=PackedScene.new();ps.pack(n)
		var e=ResourceSaver.save(ps,"res://assets/cache/autos/"+k+".scn",ResourceSaver.FLAG_COMPRESS)
		if e!=OK:print("  SPEICHERN FEHLER ",e)
		n.free()
	quit()
