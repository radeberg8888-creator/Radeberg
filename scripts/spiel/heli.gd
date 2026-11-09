extends AnimatableBody3D
# Fahndungs-Hubschrauber: Polizei (ab 3 Sternen) oder Armee (5 Sterne).
# Kreist über dem Spieler, Suchscheinwerfer nachts, Schütze in der offenen Tür,
# Armee-Heli setzt Soldaten am Seil ab. Kann abgeschossen werden.
var kampf
var armee:=false
var hp:=900.0
var tot:=false
var _rotor:Node3D
var _heck:Node3D
var _licht:SpotLight3D
var _kegel:MeshInstance3D
var _winkel:=0.0
var _schuss_t:=2.0
var _abgesetzt:=false
var _absetz_t:=0.0
var _seile:=[]
var _vel:=Vector3.ZERO
var _fall:=0.0

func _box(p:Node3D,s:Vector3,pos:Vector3,c:Color,rot:=Vector3.ZERO)->MeshInstance3D:
	var m=MeshInstance3D.new();var b=BoxMesh.new();b.size=s;m.mesh=b;p.add_child(m);m.position=pos;m.rotation=rot
	var mt=StandardMaterial3D.new();mt.albedo_color=c;mt.diffuse_mode=BaseMaterial3D.DIFFUSE_TOON;mt.roughness=0.6;m.material_override=mt
	return m

func setup(k,ist_armee:bool):
	kampf=k;armee=ist_armee
	sync_to_physics=false
	collision_layer=8;collision_mask=0
	var cs=CollisionShape3D.new();var bx=BoxShape3D.new();bx.size=Vector3(2.4,2.4,7.5);cs.shape=bx;cs.position=Vector3(0,0.2,0.8);add_child(cs)
	var rumpf:Color=Color(0.33,0.36,0.22) if armee else Color(0.08,0.12,0.3)
	var zweit:Color=Color(0.25,0.27,0.17) if armee else Color(0.92,0.92,0.95)
	var v=Node3D.new();add_child(v);v.name="Optik"
	# Rumpf, Kanzel, Heckausleger, Leitwerk, Kufen
	_box(v,Vector3(2.2,2.0,4.2),Vector3(0,0,0),rumpf)
	_box(v,Vector3(2.0,1.2,1.0),Vector3(0,0.15,-2.45),zweit)
	var glas=_box(v,Vector3(1.9,1.0,1.1),Vector3(0,0.35,-2.6),Color(0.35,0.55,0.7));glas.material_override.metallic=0.6;glas.material_override.roughness=0.1
	_box(v,Vector3(2.24,0.5,4.0),Vector3(0,-0.55,0),zweit)
	_box(v,Vector3(0.6,0.6,5.5),Vector3(0,0.4,4.6),rumpf)
	_box(v,Vector3(0.18,1.6,1.0),Vector3(0,1.1,7.1),rumpf)
	_box(v,Vector3(1.8,0.12,0.6),Vector3(0,0.5,6.9),rumpf)
	for sx in [-1.0,1.0]:
		_box(v,Vector3(0.12,0.12,4.2),Vector3(sx*1.1,-1.45,0),Color(0.1,0.1,0.1))
		for sz in [-1.0,1.0]:_box(v,Vector3(0.1,0.6,0.1),Vector3(sx*0.95,-1.15,sz*1.2),Color(0.1,0.1,0.1))
	_box(v,Vector3(0.5,0.4,0.6),Vector3(0,1.2,0),Color(0.15,0.15,0.15))
	if not armee:
		var schrift=Label3D.new();schrift.text="POLIZEI";schrift.font_size=90;schrift.modulate=Color(1,1,1);schrift.outline_size=0
		v.add_child(schrift);schrift.position=Vector3(1.13,-0.1,0.3);schrift.rotation.y=PI*0.5;schrift.pixel_size=0.006
		var s2=schrift.duplicate();v.add_child(s2);s2.position.x=-1.13;s2.rotation.y=-PI*0.5
	# Hauptrotor (zwei Blätter + Unschärfescheibe) und Heckrotor
	_rotor=Node3D.new();v.add_child(_rotor);_rotor.position=Vector3(0,1.45,0)
	for a in 2:_box(_rotor,Vector3(0.35,0.06,11.0),Vector3.ZERO,Color(0.08,0.08,0.08),Vector3(0,a*PI*0.5,0))
	var sch=MeshInstance3D.new();var cy=CylinderMesh.new();cy.top_radius=5.5;cy.bottom_radius=5.5;cy.height=0.02;sch.mesh=cy;_rotor.add_child(sch)
	var sm=StandardMaterial3D.new();sm.albedo_color=Color(0.1,0.1,0.1,0.18);sm.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;sm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;sch.material_override=sm
	_heck=Node3D.new();v.add_child(_heck);_heck.position=Vector3(0.25,1.0,7.2)
	for a in 2:_box(_heck,Vector3(0.05,1.6,0.18),Vector3.ZERO,Color(0.08,0.08,0.08),Vector3(a*PI*0.5,0,0))
	# Suchscheinwerfer mit sichtbarem Lichtkegel
	_licht=SpotLight3D.new();add_child(_licht);_licht.position=Vector3(0,-1.2,-2.2);_licht.light_energy=14.0;_licht.spot_range=120.0;_licht.spot_angle=11.0;_licht.light_color=Color(1,0.97,0.88)
	_kegel=MeshInstance3D.new();var kc=CylinderMesh.new();kc.top_radius=0.3;kc.bottom_radius=9.0;kc.height=60.0;kc.radial_segments=16;_kegel.mesh=kc
	var km=StandardMaterial3D.new();km.albedo_color=Color(1,0.97,0.85,0.08);km.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;km.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;km.cull_mode=BaseMaterial3D.CULL_DISABLED;_kegel.material_override=km
	_kegel.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(_kegel)

func ist_mensch()->bool:return false

func treffer(dmg:float,von,punkt:Vector3):
	if tot:return
	hp-=dmg*(0.35 if dmg<100.0 else 1.0)
	if hp<=0.0:
		tot=true;kampf.explosion(global_position,self)
		if von==kampf.spiel.spieler or von==kampf.spiel.auto:kampf.verbrechen(1.0);kampf.spiel.hud.zeige("Hubschrauber abgeschossen!",2.0)

func _nacht()->bool:
	var h=kampf.spiel.zeit/60.0
	return h<6.5 or h>19.5

func schritt(dt:float,me:Node3D):
	_rotor.rotate_y(dt*38.0);_heck.rotate_x(dt*50.0)
	if tot:
		# trudelnd abstürzen, am Boden explodieren
		_fall+=dt*9.0;rotate_y(dt*4.0)
		global_position+=Vector3(0,-_fall*dt,0)+_vel*dt
		var b=kampf._ray(global_position+Vector3(0,1,0),global_position+Vector3(0,-2.5,0),[self])
		if b or _fall>60.0:
			kampf.explosion(global_position,self);kampf.explosion(global_position+Vector3(2,0,1),self)
			return false
		return true
	var mp=me.global_position
	# Bodenhöhe unter dem Ziel
	var bh=mp.y
	var b2=kampf._ray(mp+Vector3(0,80,0),mp+Vector3(0,-30,0),[self,me])
	if b2:bh=b2.position.y
	var hoehe=bh+(22.0 if armee and not _abgesetzt and _absetz_t>0.0 else 34.0)
	_winkel+=dt*(0.25 if _absetz_t<=0.0 else 0.0)
	var r=38.0 if _absetz_t<=0.0 else 14.0
	var soll=Vector3(mp.x+cos(_winkel)*r,hoehe,mp.z+sin(_winkel)*r)
	var zu=soll-global_position
	_vel=_vel.lerp(zu.limit_length(28.0),clamp(dt*0.9,0.0,1.0))
	global_position+=_vel*dt
	# zum Spieler drehen, in Flugrichtung neigen
	var blick=mp-global_position;blick.y=0
	if blick.length()>1.0:
		var ziel_yaw=atan2(-blick.x,-blick.z)
		rotation.y=lerp_angle(rotation.y,ziel_yaw,clamp(dt*1.5,0.0,1.0))
	var lokal=global_transform.basis.inverse()*_vel
	rotation.x=lerp(rotation.x,clamp(-lokal.z*0.02,-0.3,0.3),dt*2.0);rotation.z=lerp(rotation.z,clamp(lokal.x*0.02,-0.3,0.3),dt*2.0)
	# Scheinwerfer auf den Spieler
	var nacht=_nacht()
	_licht.visible=nacht;_kegel.visible=nacht
	if nacht:
		var von=_licht.global_position;var auf=mp+Vector3(0,0.5,0)
		_licht.look_at(auf,Vector3.UP)
		var d=auf-von;var L=d.length()
		_kegel.global_position=von+d*0.5
		_kegel.global_basis=Basis(Quaternion(Vector3.UP,-d.normalized())).scaled(Vector3(1,L/60.0,1))
	# Schütze in der Tür
	_schuss_t-=dt
	if _schuss_t<=0.0 and global_position.distance_to(mp)<90.0:
		_schuss_t=0.18 if randf()<0.7 else 1.6
		var mz=global_position+global_transform.basis.x*(1.3 if randf()<0.5 else -1.3)+Vector3(0,-0.4,0)
		var h=kampf._ray(mz,mp+Vector3(0,1.0,0),[self,me])
		if h==null:kampf.schuss(self,mz,(mp+Vector3(0,1.0,0)-mz).normalized(),"ar15" if armee else "mp5",[self],false,0.22)
	# Armee: Soldaten abseilen
	if armee and not _abgesetzt:
		var hd=Vector2(mp.x-global_position.x,mp.z-global_position.z).length()
		if _absetz_t<=0.0 and hd<45.0:_absetz_t=0.01
		if _absetz_t>0.0:
			_absetz_t+=dt
			if _absetz_t>3.0:_abseilen(bh)
	for s in _seile.duplicate():
		s.t-=dt
		if s.t<=0.0:s.n.queue_free();_seile.erase(s)
	return true

func _abseilen(boden:float):
	_abgesetzt=true;_absetz_t=0.0
	for i in 4:
		var seite=1.25 if i%2==0 else -1.25
		var start=global_position+global_transform.basis.x*seite+global_transform.basis.z*(0.8 if i<2 else -0.6)+Vector3(0,-1.0,0)
		var unten=Vector3(start.x,boden+0.1,start.z)
		# Seil
		var sn=MeshInstance3D.new();var cy=CylinderMesh.new();cy.top_radius=0.03;cy.bottom_radius=0.03;cy.height=start.y-unten.y;sn.mesh=cy
		var sm=StandardMaterial3D.new();sm.albedo_color=Color(0.12,0.1,0.08);sn.material_override=sm
		kampf.spiel.add_child(sn);sn.global_position=(start+unten)*0.5
		_seile.append({"n":sn,"t":7.0})
		var g=kampf.spawn(start,"polizei",["ar15","mossberg","ar15"][i%3],{"basis":"police","alarm":true,"hp":150.0,
			"look":{"tint":Color(0.3,0.33,0.2),"mix":0.9,"sat":1.0,"val":0.9,"hue":0.0}})
		g.set_physics_process(false);g.set_process(false)
		var tw=g.create_tween();tw.tween_interval(i*0.6)
		tw.tween_property(g,"global_position",unten,2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(func():g.set_physics_process(true);g.set_process(true))
