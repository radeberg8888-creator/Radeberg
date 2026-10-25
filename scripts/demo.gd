extends Node3D
# Vorschau-Szene: Radeberger Hauptstraße mit Autos und Passanten
func _ready():
	var args=OS.get_cmdline_user_args();var mode="day";var shots=true
	for a in args:
		if a=="--sunset":mode="sunset"
		if a=="--play":shots=false
	load("res://scripts/env.gd").make(self,mode)
	var st=Node3D.new();st.set_script(load("res://scripts/street.gd"));add_child(st);st.build(7)
	st.car("res://assets/vehicles/ferrari.glb",Vector3(4.6,0.0,8),PI,Color(0.55,0.04,0.04))
	st.car("res://assets/vehicles/carconcept.glb",Vector3(4.6,0.0,-24),PI,Color(0.1,0.12,0.14))
	st.car("res://assets/vehicles/ferrari.glb",Vector3(-4.6,0.0,30),0,Color(0.85,0.85,0.82))
	st.car("res://assets/vehicles/carconcept.glb",Vector3(-2,0.0,-52),0,Color(0.1,0.22,0.45))
	st.car("res://assets/vehicles/ferrari.glb",Vector3(2,0.0,-80),PI,Color(0.2,0.3,0.22))
	st.walker("res://assets/characters/rpm2.glb",Vector3(9.0,0.15,4),PI,0.2,Color(0.35,0.4,0.55))
	st.walker("res://assets/characters/rpm.glb",Vector3(8.2,0.15,-6),0,0.7)
	st.walker("res://assets/characters/michelle.glb",Vector3(9.6,0.15,-14),PI,0.4)
	st.walker("res://assets/characters/rpm2.glb",Vector3(-9.0,0.15,12),0,0.9,Color(0.6,0.75,1.0))
	st.walker("res://assets/characters/rpm.glb",Vector3(-8.6,0.15,20),PI,0.1,Color(0.6,1.0,0.7))
	st.walker("res://assets/characters/soldier.glb",Vector3(-9.4,0.15,-20),0,0.5)
	st.car("res://assets/vehicles/carconcept.glb",Vector3(5.6,0.0,40),PI,Color(0.55,0.56,0.58))
	st.car("res://assets/vehicles/ferrari.glb",Vector3(-5.6,0.0,-36),0,Color(0.08,0.08,0.09))
	st.car("res://assets/vehicles/ferrari.glb",Vector3(5.6,0.0,62),PI,Color(0.9,0.75,0.2))
	st.walker("res://assets/characters/michelle.glb",Vector3(-9.8,0.15,40),PI,0.3)
	st.walker("res://assets/characters/rpm.glb",Vector3(9.4,0.15,30),0,0.55,Color(0.9,0.6,0.6))
	st.walker("res://assets/characters/rpm2.glb",Vector3(10.1,0.15,-30),PI,0.75,Color(0.5,0.45,0.4))
	# Held mit Katana (Poly Haven) in der rechten Hand
	var hero=st.walker("res://assets/characters/rpm.glb",Vector3(6.2,0.15,14.5),PI*0.85,0.15,Color(0.35,0.38,0.42))
	var sk=load("res://scripts/anim_util.gd").find_skel(hero)
	var ba=BoneAttachment3D.new();sk.add_child(ba);ba.bone_name="RightHand"
	var kat=load("res://scripts/weapons.gd").katana();ba.add_child(kat);kat.rotation_degrees=Vector3(0,0,-90);kat.position=Vector3(0,0.08,0.02)
	# Waffen auf einer Kiste (Poly Haven: Pistole, Gewehr, Machete)
	var crate=MeshInstance3D.new();crate.mesh=BoxMesh.new();crate.mesh.size=Vector3(1.6,0.06,0.9);add_child(crate);crate.position=Vector3(8.6,0.93,22)
	var felt=StandardMaterial3D.new();felt.albedo_color=Color(0.08,0.2,0.12);felt.roughness=0.95;crate.material_override=felt
	var Mt=load("res://scripts/mats.gd")
	for lx in [-0.7,0.7]:
		for lz in [-0.38,0.38]:
			var leg=MeshInstance3D.new();leg.mesh=BoxMesh.new();leg.mesh.size=Vector3(0.06,0.78,0.06);add_child(leg);leg.position=Vector3(8.6+lx,0.54,22+lz);leg.material_override=Mt.flat(Color(0.2,0.2,0.21),0.4,0.9)
	var W="res://assets/weapons/"
	var gun=load(W+"rifle.glb").instantiate();add_child(gun);gun.position=Vector3(8.6,0.96,22.2);gun.rotation_degrees=Vector3(90,0,0)
	var ps=load(W+"pistol.glb").instantiate();add_child(ps);ps.position=Vector3(8.2,0.96,21.8);ps.rotation_degrees=Vector3(90,25,0)
	var mc=load(W+"machete.glb").instantiate();add_child(mc);mc.position=Vector3(9.0,0.97,21.8);mc.rotation_degrees=Vector3(0,70,90)
	var cam=Camera3D.new();cam.fov=55;add_child(cam);cam.position=Vector3(9.8,1.7,12);cam.near=0.05
	if shots:
		var sh=load("res://scripts/shots.gd").new();add_child(sh)
		var pf="sunset" if mode=="sunset" else "day"
		sh.setup([[Vector3(10.2,1.65,10.5),Vector3(7.5,1.4,-10),58.0],[Vector3(-3,7.5,46),Vector3(2,2.5,0),55.0],[Vector3(6.3,1.2,13.2),Vector3(4.6,0.6,8),45.0],[Vector3(8.4,1.6,6.8),Vector3(9.0,1.45,4),35.0],[Vector3(0,1.6,-6),Vector3(0,4,40),60.0],[Vector3(5.2,1.55,13.3),Vector3(6.2,1.2,14.5),40.0],[Vector3(7.3,1.6,23.2),Vector3(8.7,0.95,21.9),40.0],[Vector3(-4,2.2,-26),Vector3(-10,6,-11),62.0],[Vector3(5,1.8,-34),Vector3(9.5,2.2,-48),55.0]],pf)
