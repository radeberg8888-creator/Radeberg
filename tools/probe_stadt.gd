extends SceneTree
# Probestück Blockrandbebauung (Grove): 3x2 Blöcke mit Straßen, Gehwegen, Laternen, Bäumen, parkenden Autos.
# Rendert mehrere Ansichten nach OUT.
const OUT="/tmp/claude-0/-home-claude/28bc4cd7-234a-5fda-badb-fa2be879c9df/scratchpad/probe/"
const BS=preload("res://scripts/blockstadt.gd")
func _init():
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	var w=Node3D.new();root.add_child(w)
	var sun=load("res://scripts/env.gd").make(w,"day")
	sun.shadow_enabled=true
	var bs=BS.new();bs.rng.seed=7
	var Mats=load("res://scripts/mats.gd")
	# Straße: große Asphaltfläche
	var st=MeshInstance3D.new();var pm=PlaneMesh.new();pm.size=Vector2(600,600);st.mesh=pm;w.add_child(st)
	st.material_override=Mats.pbr("asphalt",0.12,Color(0.62,0.62,0.62))
	# Grove: niedrige Backstein- und Mietshäuser, Läden im Erdgeschoss, einzelne hellere Reihenhäuser
	var reihe=[["ghetto",4],["nyc_01",3],["chicago_00",3],["cityscene2_22",1],["cityscene2_35",1],
		["cityscene2_01",2],["cityscene2_02",2],["cityscene2_07",2],["cityscene2_11",2],["cityscene2_00",1],["cityscene2_05",1],["marino",1],["house",3]]
	var eck=[["house",4],["ghetto",2],["nyc_01",1]]
	var BW=84.0;var BH=62.0;var STR=13.0
	var linien=Batch_neu()
	for bx in 3:
		for bz in 2:
			var x0=bx*(BW+STR)-1.5*(BW+STR)+STR*0.5;var z0=bz*(BH+STR)-(BH+STR)+STR*0.5
			var ecken=[Vector2(x0,z0),Vector2(x0,z0+BH),Vector2(x0+BW,z0+BH),Vector2(x0+BW,z0)]
			bs.block(w,ecken,0.0,reihe,eck,21.0)
			_ausstattung(w,ecken,bs)
	# Mittellinien
	var weiss=StandardMaterial3D.new();weiss.albedo_color=Color(0.92,0.92,0.88)
	for bz in 3:
		var z=bz*(BH+STR)-(BH+STR)
		for k in 60:linien.box(weiss,Vector3(-150+k*5.0,0.005,z-0.08),Vector3(-148+k*5.0,0.02,z+0.08))
	for bx in 4:
		var x=bx*(BW+STR)-1.5*(BW+STR)
		for k in 30:linien.box(weiss,Vector3(x-0.08,0.005,-80+k*5.0),Vector3(x+0.08,0.02,-78+k*5.0))
	linien.commit(w,false)
	var cam=Camera3D.new();w.add_child(cam);cam.fov=62;cam.far=1500
	var ansichten=[[Vector3(-120,3.0,-2.0),Vector3(-60,6,-6)],[Vector3(-46,3.0,-55),Vector3(-52,7,0)],[Vector3(-44,2.2,-4),Vector3(-75,5,-30)],
		[Vector3(-160,80,110),Vector3(-20,0,-10)],[Vector3(50,3.0,60),Vector3(46,7,10)],[Vector3(46,3.0,-70),Vector3(-10,6,-76)]]
	if OS.get_cmdline_user_args().has("oben"):
		cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=330;cam.position=Vector3(0,300,0);cam.rotation_degrees=Vector3(-90,0,0)
		for k in 6:await process_frame
		root.get_viewport().get_texture().get_image().save_png(OUT+"oben.png");quit();return
	for i in ansichten.size():
		cam.position=ansichten[i][0];cam.look_at(ansichten[i][1])
		for k in 6:await process_frame
		root.get_viewport().get_texture().get_image().save_png(OUT+"ansicht_%d.png"%i)
	quit()

func Batch_neu():return load("res://scripts/batch.gd").new()

func _ausstattung(w:Node3D,ecken:Array,bs):
	var L=load("res://scripts/welt_leben.gd").new(null,null,null)
	var lampe=L.lamp_mesh();var baum=L.baum_nah()
	var autos=["small_car","taxi","mercedes","bmw_e30","f100","audi_rs7","polizei","porsche911"]
	var n=ecken.size()
	for i in n:
		var a:Vector2=ecken[i];var c:Vector2=ecken[(i+1)%n];var Lk=a.distance_to(c);var t=(c-a)/Lk;var nn=bs._aussen(PackedVector2Array(ecken),a,c)
		var s=8.0
		while s<Lk-8.0:
			var p=a+t*s-nn*0.6
			var lm=MeshInstance3D.new();lm.mesh=lampe;w.add_child(lm);lm.transform=Transform3D(Basis(Vector3.UP,atan2(nn.x,nn.y)+PI),Vector3(p.x,0.15,p.y))
			var p2=a+t*(s+9.0)-nn*1.4
			if bs.rng.randf()<0.6:
				var bm=MeshInstance3D.new();bm.mesh=baum;w.add_child(bm);bm.position=Vector3(p2.x,0.1,p2.y);bm.scale=Vector3.ONE*bs.rng.randf_range(0.7,0.9)
			# parkendes Auto am Straßenrand
			if bs.rng.randf()<0.45:
				var k=autos[bs.rng.randi()%autos.size()]
				var auto=load("res://assets/cache/autos/"+k+".scn").instantiate();w.add_child(auto)
				var q=a+t*(s+4.5)+nn*1.25
				auto.position=Vector3(q.x,0.0,q.y);auto.rotation.y=atan2(t.x,t.y)
			s+=18.0
