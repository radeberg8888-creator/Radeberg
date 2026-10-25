extends Node3D
# Rolltor: ein durchgehendes Tor aus gewellten Stahllamellen, das nach oben hinter den Sturz fährt.
# setup(breite, höhe): Tor steht in der Ebene x=0, Breite entlang z, unten bei y=0.
# open (0..1) stellt die Öffnung ein; animate_open() fährt es in 2,5 s hoch.
var w:=5.0;var h:=4.4
var door:MeshInstance3D
var open:=0.0:
	set(v):open=clamp(v,0.0,1.0);if door:door.position.y=open*(h+0.1)

static func _slat_mesh(w:float,h:float)->ArrayMesh:
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n=int(h/0.075)   # Lamellenhöhe 7,5 cm
	var seg=6
	for i in n:
		var y0=i*h/n
		for k in seg:
			var a0=float(k)/seg;var a1=float(k+1)/seg
			# Wellenprofil: leichte Rundung je Lamelle + Fuge
			var x0=sin(a0*PI)*0.018-(0.006 if k==0 else 0.0);var x1=sin(a1*PI)*0.018-(0.006 if k==seg-1 else 0.0)
			var ya=y0+a0*h/n;var yb=y0+a1*h/n
			var p=[Vector3(x0,ya,-w*0.5),Vector3(x0,ya,w*0.5),Vector3(x1,yb,w*0.5),Vector3(x1,yb,-w*0.5)]
			st.set_uv(Vector2(0,ya/h));st.add_vertex(p[0]);st.set_uv(Vector2(1,ya/h));st.add_vertex(p[1]);st.set_uv(Vector2(1,yb/h));st.add_vertex(p[2])
			st.set_uv(Vector2(0,ya/h));st.add_vertex(p[0]);st.set_uv(Vector2(1,yb/h));st.add_vertex(p[2]);st.set_uv(Vector2(0,yb/h));st.add_vertex(p[3])
	st.generate_normals();return st.commit()

func setup(width:float,height:float,color:=Color(0.62,0.64,0.66)):
	w=width;h=height
	var m=StandardMaterial3D.new();m.albedo_color=color;m.metallic=0.75;m.roughness=0.42;m.cull_mode=BaseMaterial3D.CULL_DISABLED
	door=MeshInstance3D.new();door.mesh=_slat_mesh(w,h);door.material_override=m;add_child(door)
	# Bodenschiene (unterste Lamelle verstärkt) und Griff
	var dark=StandardMaterial3D.new();dark.albedo_color=Color(0.15,0.15,0.16);dark.metallic=0.8;dark.roughness=0.35
	var rail=MeshInstance3D.new();rail.mesh=BoxMesh.new();rail.mesh.size=Vector3(0.05,0.08,w);rail.material_override=dark;door.add_child(rail);rail.position=Vector3(0.01,0.04,0)
	var grip=MeshInstance3D.new();grip.mesh=BoxMesh.new();grip.mesh.size=Vector3(0.04,0.03,0.4);grip.material_override=dark;door.add_child(grip);grip.position=Vector3(-0.03,0.9,0)
	# seitliche Führungsschienen (bleiben stehen)
	for s in [-1,1]:
		var g=MeshInstance3D.new();g.mesh=BoxMesh.new();g.mesh.size=Vector3(0.09,h,0.07);g.material_override=dark;add_child(g);g.position=Vector3(0.0,h*0.5,s*(w*0.5+0.03))
	open=open

func animate_open(t:=2.5):
	var tw=create_tween();tw.tween_property(self,"open",1.0,t).set_trans(Tween.TRANS_SINE)
func animate_close(t:=2.5):
	var tw=create_tween();tw.tween_property(self,"open",0.0,t).set_trans(Tween.TRANS_SINE)
