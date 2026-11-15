extends RefCounted
# Musterhaus für die Stil-Probe 2: zweistöckiges Holzhaus wie im Referenzbild – Holzverschalung, Schindel-
# Satteldach mit Überstand und weißen Blenden, Fenster mit Rahmen, Sprossen und Fensterläden, Veranda mit
# Pfosten, Geländer, Dach und Treppe, Backsteinschornstein, Sockel, Briefkasten. Vorderseite = +z.
# Die Oberflächen (Holz, Schindeln, Backstein) kommen aus stil.gd nach Farbe/Flächenrichtung.

static var _mc:={}
static func M(c:Color)->StandardMaterial3D:
	var k=c.to_html()
	if not _mc.has(k):
		var m=StandardMaterial3D.new();m.albedo_color=c;m.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON
		m.specular_mode=BaseMaterial3D.SPECULAR_DISABLED;m.roughness=1.0;_mc[k]=m
	return _mc[k]

static func box(p:Node3D,c:Color,pos:Vector3,gr:Vector3,rot:=Basis()):
	var mi=MeshInstance3D.new();var b=BoxMesh.new();b.size=gr;mi.mesh=b
	mi.material_override=M(c);mi.transform=Transform3D(rot,pos);p.add_child(mi)
	return mi

static func giebel(p:Node3D,c:Color,breite:float,tiefe:float,y0:float,hoehe:float):
	# zwei dreieckige Giebelwände (links/rechts, x=±breite/2) als Prismen
	for sx in [-1.0,1.0]:
		var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var x=sx*breite*0.5
		var a=Vector3(x,y0,-tiefe*0.5);var b=Vector3(x,y0,tiefe*0.5);var t=Vector3(x,y0+hoehe,0)
		var n=Vector3(sx,0,0)
		st.set_normal(n)
		if sx>0:st.add_vertex(a);st.add_vertex(t);st.add_vertex(b)
		else:st.add_vertex(a);st.add_vertex(b);st.add_vertex(t)
		var mi=MeshInstance3D.new();mi.mesh=st.commit();mi.material_override=M(c);p.add_child(mi)

static func fenster(p:Node3D,pos:Vector3,yaw:float,laden:Color,b:=1.1,h:=1.5):
	var r=Basis(Vector3.UP,yaw);var vor=r*Vector3(0,0,1)
	var weiss=Color(0.95,0.94,0.9)
	box(p,weiss,pos+vor*0.06,Vector3(b+0.2,h+0.2,0.1),r)
	box(p,Color(0.16,0.24,0.33),pos+vor*0.1,Vector3(b,h,0.04),r)
	box(p,weiss,pos+vor*0.13,Vector3(0.07,h,0.04),r)
	box(p,weiss,pos+vor*0.13,Vector3(b,0.07,0.04),r)
	box(p,weiss,pos+vor*0.12+Vector3(0,-h*0.5-0.1,0),Vector3(b+0.4,0.08,0.22),r)
	for sx in [-1.0,1.0]:
		box(p,laden,pos+vor*0.08+r*Vector3(sx*(b*0.5+0.33),0,0),Vector3(0.42,h+0.1,0.05),r)
		for k in 5:box(p,laden.darkened(0.25),pos+vor*0.11+r*Vector3(sx*(b*0.5+0.33),-h*0.4+k*h*0.2,0),Vector3(0.36,0.03,0.02),r)

static func bauen(wand:Color,laden:Color,dach:=Color(0.42,0.36,0.33),zwei_stock:=true)->Node3D:
	var hs=Node3D.new();hs.name="Musterhaus"
	var B:=9.0;var T:=10.0;var H:=6.2 if zwei_stock else 3.4;var DH:=3.4
	var weiss=Color(0.95,0.94,0.9);var stein=Color(0.55,0.54,0.52)
	# Sockel + Wände
	box(hs,stein,Vector3(0,0.35,0),Vector3(B+0.2,0.7,T+0.2))
	box(hs,wand,Vector3(0,0.7+H*0.5,0),Vector3(B,H,T))
	giebel(hs,wand,B,T,0.7+H,DH)
	# Eckbretter + Stockwerksband
	for sx in [-1.0,1.0]:
		for sz in [-1.0,1.0]:box(hs,weiss,Vector3(sx*B*0.5,0.7+H*0.5,sz*T*0.5),Vector3(0.22,H,0.22))
	if zwei_stock:box(hs,weiss,Vector3(0,0.7+3.1,T*0.5+0.02),Vector3(B,0.18,0.06))
	# Satteldach mit Überstand (First entlang x), weiße Blenden
	var w=atan2(DH,T*0.5);var lang=sqrt(DH*DH+T*T*0.25)+0.7
	for sz in [-1.0,1.0]:
		var r=Basis(Vector3.RIGHT,sz*w)
		box(hs,dach,Vector3(0,0.7+H+DH*0.5+0.12,sz*(T*0.25+0.12)),Vector3(B+1.0,0.22,lang),r)
		box(hs,weiss,Vector3(0,0.7+H-0.1,sz*(T*0.5+0.55)),Vector3(B+1.0,0.25,0.1))
	for sx in [-1.0,1.0]:
		for sz in [-1.0,1.0]:
			var r=Basis(Vector3.RIGHT,sz*w)
			box(hs,weiss,Vector3(sx*(B*0.5+0.5),0.7+H+DH*0.5,sz*T*0.25),Vector3(0.12,0.3,lang),r)
	box(hs,dach.darkened(0.2),Vector3(0,0.7+H+DH+0.18,0),Vector3(B+1.0,0.2,0.4))
	# Schornstein (Backstein)
	box(hs,Color(0.62,0.3,0.24),Vector3(B*0.3,0.7+H+DH*0.6,-T*0.15),Vector3(1.0,DH+1.6,1.0))
	box(hs,stein,Vector3(B*0.3,0.7+H+DH*0.6+DH*0.5+0.85,-T*0.15),Vector3(1.2,0.15,1.2))
	# Fenster vorne / Seiten / Dachgiebel
	var unten=[Vector3(-2.6,2.2,T*0.5),Vector3(2.6,2.2,T*0.5)]
	for f in unten:fenster(hs,f,0.0,laden)
	if zwei_stock:
		for x in [-2.6,0.0,2.6]:fenster(hs,Vector3(x,5.2,T*0.5),0.0,laden)
	for sz in [-2.5,2.5]:
		fenster(hs,Vector3(B*0.5,2.2,sz),PI*0.5,laden);fenster(hs,Vector3(-B*0.5,2.2,sz),-PI*0.5,laden)
		if zwei_stock:fenster(hs,Vector3(B*0.5,5.2,sz),PI*0.5,laden);fenster(hs,Vector3(-B*0.5,5.2,sz),-PI*0.5,laden)
	fenster(hs,Vector3(B*0.5,0.7+H+1.1,0),PI*0.5,laden,0.8,0.9);fenster(hs,Vector3(-B*0.5,0.7+H+1.1,0),-PI*0.5,laden,0.8,0.9)
	# Haustür
	box(hs,weiss,Vector3(0,1.85,T*0.5+0.05),Vector3(1.3,2.4,0.1))
	box(hs,Color(0.38,0.24,0.16),Vector3(0,1.8,T*0.5+0.1),Vector3(1.0,2.2,0.06))
	box(hs,Color(0.85,0.7,0.3),Vector3(0.35,1.75,T*0.5+0.15),Vector3(0.08,0.08,0.06))
	# Veranda: Boden, Pfosten, Geländer, Dach, Treppe
	var vz=T*0.5+1.4
	box(hs,Color(0.55,0.4,0.28),Vector3(0,0.65,vz),Vector3(B-0.6,0.18,2.8))
	box(hs,weiss,Vector3(0,0.4,vz+1.38),Vector3(B-0.6,0.5,0.08))
	for x in [-B*0.5+0.5,-1.0,1.0,B*0.5-0.5]:box(hs,weiss,Vector3(x,0.7+1.4,vz+1.25),Vector3(0.18,2.8,0.18))
	box(hs,dach,Vector3(0,3.75,vz+0.2),Vector3(B-0.2,0.15,3.4),Basis(Vector3.RIGHT,0.18))
	box(hs,weiss,Vector3(0,3.5,vz+1.7),Vector3(B-0.2,0.25,0.08))
	for sx in [-1.0,1.0]:
		var x0=sx*(B*0.25+0.6)
		box(hs,weiss,Vector3(x0,1.65,vz+1.25),Vector3(B*0.5-2.2,0.08,0.08))
		box(hs,weiss,Vector3(x0,0.85,vz+1.25),Vector3(B*0.5-2.2,0.06,0.06))
		var n=int((B*0.5-2.2)/0.28)
		for k in n:box(hs,weiss,Vector3(x0-(B*0.5-2.2)*0.5+0.14+k*0.28,1.25,vz+1.25),Vector3(0.05,0.8,0.05))
	for k in 3:box(hs,Color(0.6,0.45,0.32),Vector3(0,0.5-k*0.2,vz+1.6+k*0.32),Vector3(2.0,0.2,0.34))
	return hs

static func briefkasten(p:Node3D,pos:Vector3,yaw:float):
	var r=Basis(Vector3.UP,yaw)
	box(p,Color(0.35,0.26,0.18),pos+Vector3(0,0.55,0),Vector3(0.1,1.1,0.1),r)
	box(p,Color(0.25,0.3,0.42),pos+Vector3(0,1.2,0),Vector3(0.3,0.3,0.55),r)
static func gully(p:Node3D,pos:Vector3):
	var mi=MeshInstance3D.new();var c=CylinderMesh.new();c.top_radius=0.42;c.bottom_radius=0.42;c.height=0.03;c.radial_segments=16
	mi.mesh=c;mi.material_override=M(Color(0.2,0.2,0.21));mi.position=pos;p.add_child(mi)
	var mi2=MeshInstance3D.new();var c2=CylinderMesh.new();c2.top_radius=0.34;c2.bottom_radius=0.34;c2.height=0.035;c2.radial_segments=16
	mi2.mesh=c2;mi2.material_override=M(Color(0.3,0.3,0.31));mi2.position=pos+Vector3(0,0.005,0);p.add_child(mi2)
