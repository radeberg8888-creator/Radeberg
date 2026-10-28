extends Node
# Hält die Waffe einer Figur (Spieler oder NPC): Waffenmodell vor dem Körper, Arme per IK an Griff und Handschutz.
# zielen=true: Waffe im Anschlag in Blickrichtung; sonst locker vor dem Körper (Laufhaltung).
const WD=preload("res://scripts/spiel/waffen_daten.gd")
const IK=preload("res://scripts/spiel/arm_ik.gd")
const U=preload("res://scripts/anim_util.gd")
static var _cache:={}
var figur:Node3D          # people.gd-Figur (dreht sich in Laufrichtung)
var sk:Skeleton3D
var ik
var waffe_id:="faust"
var modell:Node3D=null
var zielen:=false
var ziel_richtung:=Vector3.FORWARD   # Welt
var schwung:=0.0          # Nahkampf-Schlag 0..1
var rueckstoss:=0.0
var _schulter_r:=-1;var _schulter_l:=-1;var _hand_r:=-1

static func modell_szene(id:String)->PackedScene:
	if not _cache.has(id):
		var p="res://assets/cache/waffen/"+id+".scn"
		_cache[id]=load(p) if ResourceLoader.exists(p) else null
	return _cache[id]

func setup(f:Node3D):
	figur=f
	sk=U.find_skel(f)
	if sk==null:return
	ik=IK.new();ik.name="ArmIK";sk.add_child(ik);ik.setup(sk)
	for i in sk.get_bone_count():
		var k=U.human_key(sk.get_bone_name(i))
		if k=="RightArm":_schulter_r=i
		elif k=="LeftArm":_schulter_l=i
		elif k=="RightHand":_hand_r=i

func setze_waffe(id:String):
	if id==waffe_id and (modell!=null or id=="faust"):return
	waffe_id=id
	if modell:modell.queue_free();modell=null
	var ps=modell_szene(id)
	if ps!=null:
		modell=ps.instantiate();figur.get_parent().add_child(modell)
		for m in modell.find_children("*","GeometryInstance3D",true,false):m.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func entfernen():
	if modell:modell.queue_free();modell=null
	if ik:ik.gewicht_ziel=0.0

func knochen_pos(i:int)->Vector3:
	if sk==null or i<0:return figur.global_position+Vector3(0,1.4,0)
	return sk.global_transform*sk.get_bone_global_pose(i).origin

func muendung()->Vector3:
	if modell==null:return knochen_pos(_hand_r)
	return modell.global_transform*modell.get_meta("muendung",Vector3(0,0,0.3))

# jedes Bild nach der Bewegung aufrufen
func aktualisieren(dt:float):
	if sk==null or ik==null or not ik.bereit():return
	var d=WD.daten(waffe_id)
	rueckstoss=move_toward(rueckstoss,0.0,dt*8.0)
	var fb=figur.global_transform.basis.orthonormalized()
	var fw=fb.z;var up=Vector3.UP;var rt=-fb.x   # people-Figuren schauen nach +Z
	var sr=knochen_pos(_schulter_r);var sl=knochen_pos(_schulter_l) if _schulter_l>=0 else sr+rt*-0.35
	var brust=(sr+sl)*0.5
	if d.typ=="nah":
		# Nahkampf: Waffe in der rechten Hand, Schlag schwingt von oben nach vorn
		ik.gewicht_ziel=1.0 if schwung>0.0 or waffe_id!="faust" else 0.0
		# Ruhe: Klinge locker nach vorn unten an der Seite; Schlag: von oben über die Schulter nach vorn unten
		var k=clamp(schwung,0.0,1.0)
		var ruhe_h=sr-up*0.55+fw*0.15+rt*0.06
		var oben_h=sr+up*0.15+fw*0.1+rt*0.05
		var vorn_h=sr+fw*0.55-up*0.25
		var hand=ruhe_h
		var blade=(fw*0.85-up*0.5).normalized()
		if k>0.0:
			if k<0.5:hand=ruhe_h.lerp(oben_h,k*2.0);blade=blade.slerp((up*0.9-fw*0.3).normalized(),k*2.0)
			else:hand=oben_h.lerp(vorn_h,(k-0.5)*2.0);blade=(up*0.9-fw*0.3).normalized().slerp((fw-up*0.2).normalized(),(k-0.5)*2.0)
		ik.ziel_r=hand;ik.ziel_l=null;ik.pol_r=(rt*0.6-up).normalized()
		if modell:modell.global_transform=Transform3D(_basis_aus(blade,up if abs(blade.dot(up))<0.95 else fw),hand)
		return
	ik.gewicht_ziel=1.0
	var dir:Vector3
	var griff:Vector3
	var zwei=WD.zweihand(waffe_id)
	if zielen:
		dir=ziel_richtung.normalized()
		var flach=Vector3(dir.x,0,dir.z).normalized()
		if zwei:griff=sr+flach*0.18+up*-0.1+dir*0.12
		else:griff=brust+dir*0.48+up*-0.05
		ik.oberkoerper_pitch=asin(clamp(dir.y,-0.8,0.8))
	else:
		# Laufhaltung: Lauf schräg nach unten vorn
		dir=(fw*0.75-up*0.5+(rt*-0.25 if zwei else Vector3.ZERO)).normalized()
		if zwei:griff=sr+fw*0.2-up*0.28+rt*0.02
		else:griff=sr+fw*0.18-up*0.42
		ik.oberkoerper_pitch=0.0
	griff-=dir*rueckstoss*0.06
	var b=_basis_aus(dir+up*rueckstoss*0.15,up)
	if modell:modell.global_transform=Transform3D(b,griff)
	ik.ziel_r=griff;ik.pol_r=(rt*0.5-up+(-fw*0.3)).normalized()
	if zwei and modell:
		ik.ziel_l=modell.global_transform*modell.get_meta("vorn",Vector3(0,-0.03,0.3))
		ik.pol_l=(-rt*0.7-up).normalized()
	elif zielen:
		ik.ziel_l=griff+(-rt)*0.04-dir*0.02;ik.pol_l=(-rt*0.6-up).normalized()   # Pistole beidhändig
	else:ik.ziel_l=null

static func _basis_aus(z:Vector3,up:Vector3)->Basis:
	z=z.normalized()
	var x=up.cross(z)
	if x.length()<0.01:x=Vector3.RIGHT
	x=x.normalized();var y=z.cross(x).normalized()
	return Basis(x,y,z)
