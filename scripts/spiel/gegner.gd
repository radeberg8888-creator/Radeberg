extends CharacterBody3D
# Bewaffneter NPC (Gang, Polizei, Wachen): sucht Deckung auf Abstand, umkreist, schießt in Salven, stirbt.
const PE=preload("res://scripts/people.gd")
const WD=preload("res://scripts/spiel/waffen_daten.gd")
const HALTER=preload("res://scripts/spiel/waffen_halter.gd")
const FARBEN={"kobras":Color(0.12,0.45,0.18),"ratten":Color(0.3,0.33,0.38),"ost":Color(0.5,0.05,0.06),"fuechse":Color(0.66,0.55,0.36),
	"lindenhof":Color(0.36,0.16,0.5),"wache":Color(0.1,0.1,0.12),"polizei":Color(0.08,0.12,0.3)}
var kampf
var fraktion:="kobras"
var waffe:="pistole"
var figur:Node3D
var halter
var hp:=100.0
var tot:=false
var tot_zeit:=0.0
var beute:=0
var mission:=false          # gehört zu einer Mission (nicht automatisch entfernen)
var alarm:=false
var sicht:=38.0
var _cool:=0.0
var _salve:=0
var _seite:=1.0
var _seite_t:=0.0
var _anim:=""
var _denk:=0.0
var _ziel_dist:=12.0
var stationaer:=false       # bleibt am Platz (Wachen, Scharfschützen-Ziele)
var verbuendet:=false       # kämpft auf Seite des Spielers

func setup(f:String,w:String,opt:={}):
	fraktion=f;waffe=w
	mission=opt.get("mission",false);stationaer=opt.get("stationaer",false);verbuendet=opt.get("verbuendet",false)
	hp=float(opt.get("hp",100.0 if f!="polizei" else 110.0))
	collision_layer=2;collision_mask=1|8
	var cs=CollisionShape3D.new();var cap=CapsuleShape3D.new();cap.radius=0.3;cap.height=1.75;cs.shape=cap;cs.position.y=0.88;add_child(cs)
	floor_snap_length=0.5
	var r=RandomNumberGenerator.new();r.randomize()
	var basis:String=opt.get("basis",["joe","biker","daya"][r.randi()%3] if f!="polizei" else "police")
	var look={}
	if f!="polizei":look={"tint":FARBEN.get(f,Color(0.2,0.2,0.2)),"mix":0.8,"sat":1.0,"val":1.0,"hue":0.0}
	figur=PE.make(basis,r,look);add_child(figur)
	PE.play(figur,"idle",r.randf())
	halter=HALTER.new();add_child(halter);halter.setup(figur);halter.setze_waffe(w)
	beute=0 if f=="polizei" else r.randi_range(20,120)
	_ziel_dist={"nah":1.3,"pistole":9.0,"mp":11.0,"schrot":6.0,"gewehr":16.0,"mg":18.0,"sniper":30.0}[WD.daten(w).typ]
	if opt.get("alarm",false):alarm=true
	_seite=1.0 if randf()<0.5 else -1.0

func ist_mensch()->bool:return true

func treffer(dmg:float,von,punkt:Vector3):
	if tot:return
	if verbuendet and (von==kampf.spiel.spieler):dmg*=0.25
	# Kopftreffer
	if punkt.y>global_position.y+1.5:dmg*=2.2
	hp-=dmg;alarm=true
	_alarmiere(von)
	if hp<=0.0:sterben(von)

func _alarmiere(von):
	for g in kampf.gegner:
		if is_instance_valid(g) and g!=self and g.fraktion==fraktion and g.global_position.distance_to(global_position)<45.0:g.alarm=true

func sterben(von):
	tot=true;hp=0.0
	collision_layer=0
	halter.entfernen()
	var ap:AnimationPlayer=figur.get_meta("anim",null)
	if ap:ap.pause()
	# umfallen
	var tw=create_tween();var dir=1.0 if randf()<0.5 else -1.0
	tw.tween_property(figur,"rotation:x",dir*PI*0.5,0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(figur,"position:y",0.15,0.45)
	kampf.gegner_tot(self,von)

func _feind():
	# Ziel: Spieler (oder Spieler-Auto); Verbündete greifen Feinde des Spielers an
	if verbuendet:
		var best=null;var bd=sicht
		for g in kampf.gegner:
			if is_instance_valid(g) and not g.tot and not g.verbuendet:
				var d=g.global_position.distance_to(global_position)
				if d<bd:bd=d;best=g
		return best
	var sp=kampf.spiel
	return sp.auto if sp.auto!=null else sp.spieler

func _physics_process(dt):
	if tot:
		tot_zeit+=dt;return
	if kampf.tot and not verbuendet:alarm=false
	var f=_feind()
	var dt_v=Vector3.ZERO
	if not is_on_floor():velocity.y-=19.6*dt
	else:velocity.y=0.0
	if f==null or not is_instance_valid(f):
		_bewegen(Vector3.ZERO,dt);return
	var ziel=f.global_position+Vector3(0,1.2,0)
	var zu=ziel-(global_position+Vector3(0,1.4,0));var dist=zu.length()
	if not alarm and dist<sicht*0.6:alarm=true
	if not alarm:
		_bewegen(Vector3.ZERO,dt);return
	# blicken
	var flach=Vector3(zu.x,0,zu.z).normalized()
	figur.rotation.y=lerp_angle(figur.rotation.y,atan2(flach.x,flach.z),clamp(dt*8.0,0.0,1.0))
	# Bewegung: Abstand halten und seitlich ausweichen
	_seite_t-=dt
	if _seite_t<=0.0:_seite_t=randf_range(1.5,3.5);_seite=-_seite if randf()<0.6 else _seite
	var wunsch=Vector3.ZERO
	if not stationaer:
		if dist>_ziel_dist+3.0:wunsch=flach*(4.2 if dist>25 else 2.6)
		elif dist<_ziel_dist-3.0:wunsch=-flach*1.8
		wunsch+=Vector3(-flach.z,0,flach.x)*_seite*1.4
	_bewegen(wunsch,dt)
	halter.zielen=dist<sicht*1.6
	halter.ziel_richtung=zu.normalized()
	halter.aktualisieren(dt)
	# schießen
	_cool-=dt
	var d=WD.daten(waffe)
	if d.typ=="nah":
		if dist<2.0 and _cool<=0.0:
			_cool=1.0/float(d.rate)*1.5
			halter.schwung=1.0
			get_tree().create_timer(0.25).timeout.connect(func():if is_instance_valid(self):halter.schwung=0.0)
			if f==kampf.spiel.spieler:kampf.spieler_treffer(float(d.schaden)*0.6,self)
			elif f.has_method("treffer"):f.treffer(float(d.schaden),self,f.global_position+Vector3(0,1.3,0))
		return
	if dist>float(d.reichweite)*0.9 or _cool>0.0:return
	_denk-=dt
	if _denk<=0.0:
		_denk=0.4
		var h=kampf._ray(global_position+Vector3(0,1.5,0),ziel,[self])
		_frei=h==null or h.collider==f or (f is Node and h.collider.get_parent()==f)
	if not _frei:return
	if _salve<=0:
		_salve={"pistole":2,"mp":5,"gewehr":4,"mg":8,"schrot":1,"sniper":1}[d.typ]
		_cool=randf_range(0.8,1.8)
		return
	_salve-=1
	_cool=1.0/float(d.rate)*1.35
	var mz=halter.muendung()
	# Trefferwahrscheinlichkeit: Entfernung, Bewegung des Ziels
	var v=f.velocity.length() if f is CharacterBody3D else (f.linear_velocity.length() if f is RigidBody3D else 0.0)
	var p=clamp(0.42-dist/75.0-v*0.04,0.05,0.45)
	if verbuendet:p=0.5
	if f==kampf.spiel.spieler or f==kampf.spiel.auto:
		# Schuss auf den Spieler: Treffer würfeln, Effekt sichtbar
		var streu=Vector3(randf_range(-1,1),randf_range(-0.5,0.8),randf_range(-1,1))*(0.0 if randf()<p else randf_range(0.6,2.0))
		kampf.schuss(self,mz,(ziel+streu-mz).normalized(),waffe,[self]+_eigene(),false,1.0)
		if streu==Vector3.ZERO and f==kampf.spiel.spieler:kampf.spieler_treffer(float(d.schaden)*0.35,self)
	else:
		kampf.schuss(self,mz,(ziel-mz).normalized(),waffe,[self],false,p)
var _frei:=true

func _eigene()->Array:
	# eigene Leute nicht treffen; Spieler-Kapsel wird separat behandelt
	var out=[kampf.spiel.spieler]
	return out

func _bewegen(wunsch:Vector3,dt:float):
	velocity.x=move_toward(velocity.x,wunsch.x,dt*14.0);velocity.z=move_toward(velocity.z,wunsch.z,dt*14.0)
	move_and_slide()
	var hs=Vector2(velocity.x,velocity.z).length()
	var a="idle"
	if hs>3.0:a="run"
	elif hs>0.4:a="walk"
	if a!=_anim:_anim=a;PE.play(figur,a)
