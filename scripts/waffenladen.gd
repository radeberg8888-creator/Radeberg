extends Node3D
# Waffenladen: alle Waffen an der Lochwand, Lackierungen und Anbauteile
const WP=preload("res://scripts/weapons.gd")
const Mats=preload("res://scripts/mats.gd")
func _ready():
	var we=WorldEnvironment.new();var env=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color(0.05,0.05,0.05)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color(0.6,0.6,0.62);env.ambient_light_energy=0.55;env.tonemap_mode=Environment.TONE_MAPPER_AGX
	env.ssao_enabled=true;env.glow_enabled=true;env.glow_intensity=0.3
	var sky=Sky.new();var ps=ProceduralSkyMaterial.new();ps.sky_top_color=Color(0.5,0.5,0.52);ps.sky_horizon_color=Color(0.7,0.7,0.7);sky.sky_material=ps;env.sky=sky;env.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	we.environment=env;add_child(we)
	# Lochwand
	var wall=MeshInstance3D.new();wall.mesh=BoxMesh.new();wall.mesh.size=Vector3(14,6,0.05);add_child(wall);wall.position=Vector3(5.5,2.2,-0.08)
	var wm=StandardMaterial3D.new();wm.albedo_color=Color(0.78,0.74,0.66);wm.roughness=0.85;wall.material_override=wm
	var holes=MultiMeshInstance3D.new();var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;var hm=CylinderMesh.new();hm.top_radius=0.006;hm.bottom_radius=0.006;hm.height=0.002;mm.mesh=hm
	var hs=[]
	for x in range(0,140):
		for y in range(0,60):hs.append(Transform3D(Basis(Vector3(1,0,0),PI*0.5),Vector3(-1.5+x*0.1,-0.8+y*0.1,-0.054)))
	mm.instance_count=hs.size();for i in hs.size():mm.set_instance_transform(i,hs[i])
	holes.multimesh=mm;var hmat=StandardMaterial3D.new();hmat.albedo_color=Color(0.15,0.13,0.11);holes.material_override=hmat;add_child(holes)
	var l=DirectionalLight3D.new();add_child(l);l.rotation_degrees=Vector3(-35,25,0);l.light_energy=1.4;l.shadow_enabled=true
	var l2=OmniLight3D.new();add_child(l2);l2.position=Vector3(5,3.5,3);l2.omni_range=12;l2.light_energy=1.2
	var cats=["Nahkampf","Pistole","Schrotflinte","Maschinenpistole","Sturmgewehr","Gewehr","Scharfschützengewehr"]
	var rows={};for id in WP.LIST:
		var c=WP.LIST[id][1];if not rows.has(c):rows[c]=[]
		rows[c].append(id)
	# Spalten: links kurze Waffen, rechts lange
	var y=4.4;var col_x=0.0
	var layout=[["Pistole",0.0,4.6],["Nahkampf",0.0,3.9],["Schrotflinte",0.0,3.2],["Maschinenpistole",0.0,2.4],["Sturmgewehr",0.0,1.6],["Gewehr",0.0,0.8],["Scharfschützengewehr",0.0,0.0]]
	for L in layout:
		var x=-0.6
		var hdr=Label3D.new();hdr.text=L[0].to_upper();hdr.font_size=60;hdr.pixel_size=0.004;hdr.modulate=Color(0.65,0.08,0.05);hdr.outline_size=0;add_child(hdr);hdr.position=Vector3(-1.2,L[2]+0.08,-0.02);hdr.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		for id in rows.get(L[0],[]):
			var w=WP.make(id);add_child(w)
			var len=WP.LIST[id][4]
			w.position=Vector3(x+len*0.5,L[2],0.0)
			var lb=Label3D.new();lb.text=WP.LIST[id][0];lb.font_size=36;lb.pixel_size=0.0035;lb.modulate=Color(0.1,0.1,0.1);lb.outline_size=0;add_child(lb);lb.position=Vector3(x+len*0.5,L[2]-0.1,-0.02)
			x+=max(len,0.5)+0.35
	# Lackierungen: M4A1 in allen 10 Varianten
	for i in WP.FINISH.size():
		var w=WP.make("m4",WP.FINISH[i]);add_child(w);w.position=Vector3(20+(i%5)*1.1,1.2-(i/5)*0.7,0)
		var lb=Label3D.new();lb.text=WP.FINISH[i];lb.font_size=40;lb.pixel_size=0.0035;lb.modulate=Color(0.1,0.1,0.1);lb.outline_size=0;add_child(lb);lb.position=w.position+Vector3(0,-0.08,-0.02)
	var wall2=MeshInstance3D.new();wall2.mesh=BoxMesh.new();wall2.mesh.size=Vector3(7,3,0.05);add_child(wall2);wall2.position=Vector3(22.2,1.0,-0.08);wall2.material_override=wm
	# Anbauteile: AR-15 in Kombinationen
	var combos=[[],["daempfer"],["visier"],["laser","rotpunkt"],["daempfer","visier","laser"]]
	for i in combos.size():
		var w=WP.make("ar15","Standard" if i<3 else ["Schwarz","Wüste"][i-3],combos[i]);add_child(w);w.position=Vector3(32,2.4-i*0.45,0)
		var lb=Label3D.new();lb.text=" + ".join(combos[i].map(func(a):return WP.ATT_NAME[a])) if combos[i].size()>0 else "ohne Anbauteile";lb.font_size=40;lb.pixel_size=0.0035;lb.modulate=Color(0.1,0.1,0.1);lb.outline_size=0;add_child(lb);lb.position=w.position+Vector3(0,-0.07,-0.02)
	var wall3=MeshInstance3D.new();wall3.mesh=BoxMesh.new();wall3.mesh.size=Vector3(4,3.2,0.05);add_child(wall3);wall3.position=Vector3(32,1.6,-0.08);wall3.material_override=wm
	var tot=Label3D.new();tot.text="%d Waffen · %d Varianten"%[WP.LIST.size(),WP.variant_count()];tot.font_size=80;tot.pixel_size=0.004;tot.modulate=Color(0.65,0.08,0.05);add_child(tot);tot.position=Vector3(3.5,5.15,-0.02)
	var c=Camera3D.new();c.far=200;add_child(c)
	var sh=load("res://scripts/shots.gd").new();add_child(sh)
	sh.setup([[Vector3(1.6,2.4,4.6),Vector3(1.6,2.35,0),62.0],[Vector3(0.9,3.9,1.6),Vector3(0.9,3.9,0),55.0],[Vector3(1.6,2.0,1.9),Vector3(1.6,2.0,0),55.0],[Vector3(2.0,0.5,1.9),Vector3(2.0,0.5,0),55.0],[Vector3(22.2,0.9,3.3),Vector3(22.2,0.9,0),52.0],[Vector3(32,1.55,2.6),Vector3(32,1.55,0),52.0]],"guns")
