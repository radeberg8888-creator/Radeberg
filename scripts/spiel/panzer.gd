extends AnimatableBody3D
# Armee-Panzer bei 5 Sternen: rollt auf den Spieler zu, Turm folgt, feuert Granaten (Explosion am Einschlag).
var kampf
var hp:=2600.0
var tot:=false
var _turm:Node3D
var _rohr:Node3D
var _feuer_t:=4.0
var _ketten:=[]
var _brand:=0.0

func _box(p:Node3D,s:Vector3,pos:Vector3,c:Color)->MeshInstance3D:
	var m=MeshInstance3D.new();var b=BoxMesh.new();b.size=s;m.mesh=b;p.add_child(m);m.position=pos
	var mt=StandardMaterial3D.new();mt.albedo_color=c;mt.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON;mt.roughness=0.85;m.material_override=mt
	return m

func setup(k):
	kampf=k;sync_to_physics=false
	collision_layer=8;collision_mask=0
	var cs=CollisionShape3D.new();var bx=BoxShape3D.new();bx.size=Vector3(3.6,2.4,7.2);cs.shape=bx;cs.position.y=1.2;add_child(cs)
	var oliv=Color(0.32,0.35,0.21);var dunkel=Color(0.12,0.12,0.1)
	_box(self,Vector3(3.3,1.0,6.8),Vector3(0,1.15,0),oliv)
	_box(self,Vector3(3.0,0.5,1.6),Vector3(0,1.5,-3.0),oliv).rotation.x=-0.35
	for sx in [-1.0,1.0]:
		_ketten.append(_box(self,Vector3(0.8,1.0,7.2),Vector3(sx*1.6,0.55,0),dunkel))
		for i in 6:
			var r=MeshInstance3D.new();var cy=CylinderMesh.new();cy.top_radius=0.42;cy.bottom_radius=0.42;cy.height=0.82;r.mesh=cy;add_child(r)
			r.position=Vector3(sx*1.6,0.5,-2.8+i*1.12);r.rotation.z=PI*0.5
			var mt=StandardMaterial3D.new();mt.albedo_color=Color(0.2,0.2,0.18);r.material_override=mt
	_turm=Node3D.new();add_child(_turm);_turm.position=Vector3(0,1.65,0.4)
	_box(_turm,Vector3(2.4,0.9,3.0),Vector3(0,0.45,0),oliv)
	_box(_turm,Vector3(0.7,0.4,0.7),Vector3(0.6,1.05,0.4),dunkel)
	_rohr=Node3D.new();_turm.add_child(_rohr);_rohr.position=Vector3(0,0.5,-1.4)
	var rm=MeshInstance3D.new();var rc=CylinderMesh.new();rc.top_radius=0.13;rc.bottom_radius=0.16;rc.height=4.6;rm.mesh=rc;_rohr.add_child(rm)
	rm.rotation.x=PI*0.5;rm.position.z=-2.3
	var mt2=StandardMaterial3D.new();mt2.albedo_color=oliv*0.85;rm.material_override=mt2

func ist_mensch()->bool:return false

func treffer(dmg:float,von,punkt:Vector3):
	if tot:return
	hp-=dmg*(0.08 if dmg<100.0 else 1.0)   # Kugeln prallen fast ab, Explosionen wirken
	if hp<=0.0:
		tot=true;kampf.explosion(global_position+Vector3(0,1.5,0),self)
		_turm.position.y+=0.6;_turm.rotation.z=0.4
		if von==kampf.spiel.spieler or von==kampf.spiel.auto:kampf.spiel.hud.zeige("Panzer zerstört!",2.0)

func schritt(dt:float,me:Node3D)->bool:
	if tot:
		_brand+=dt
		return _brand<30.0
	var mp=me.global_position
	var zu=mp-global_position;zu.y=0
	var d=zu.length()
	# fahren (bis auf 30 m heran), dem Gelände folgen
	if d>30.0:
		var ziel_yaw=atan2(-zu.x,-zu.z)
		rotation.y=lerp_angle(rotation.y,ziel_yaw,clamp(dt*0.6,0.0,1.0))
		var vor=-global_transform.basis.z;vor.y=0
		var np=global_position+vor.normalized()*7.0*dt
		var b=kampf._ray(np+Vector3(0,6,0),np+Vector3(0,-10,0),[self,me])
		if b:np.y=lerp(global_position.y,b.position.y,clamp(dt*6.0,0.0,1.0))
		global_position=np
		# Autos im Weg werden zerquetscht
		for c in kampf.spiel.verkehr+kampf.spiel.geparkt:
			if is_instance_valid(c) and c.global_position.distance_to(global_position)<4.0 and not c.wrack:c.treffer(600.0,self,c.global_position)
	# Turm und Rohr auf das Ziel
	var lokal=global_transform.basis.inverse()*(mp-_turm.global_position)
	_turm.rotation.y=lerp_angle(_turm.rotation.y,atan2(-lokal.x,-lokal.z),clamp(dt*1.2,0.0,1.0))
	_feuer_t-=dt
	if _feuer_t<=0.0 and d<140.0:
		_feuer_t=5.5
		var mz=_rohr.global_position-_rohr.global_basis.z*4.6
		var ziel=mp+Vector3(randf_range(-5,5),0,randf_range(-5,5))
		var h=kampf._ray(mz,ziel+(ziel-mz).normalized()*20.0,[self])
		var p=h.position if h else ziel
		kampf._muendungsfeuer(mz,(p-mz).normalized())
		kampf.spiel.kam.rueckstoss(1.5)
		var tw=create_tween();tw.tween_interval(mz.distance_to(p)/180.0);tw.tween_callback(func():kampf.explosion(p,self))
	return true
