extends CharacterBody3D
# Spielfigur zu Fuß: Laufen/Rennen relativ zur Kamera, Springen, Animationen, Kleidung (outfit.gd).
const PE=preload("res://scripts/people.gd")
const O=preload("res://scripts/outfit.gd")
var figur:Node3D
var figur_basis:="joe"
var outfit:={"top":0,"bottom":0,"shoes":0,"hat":0,"glasses":false,"chain":false}
var anim:="idle"
var cam_yaw:=0.0
var aktiv:=true
var gehen:=1.9
var rennen:=5.6
var _gelaende_ok:=Vector3.ZERO
var im_wasser:=0.0
var blick_fest:=false   # beim Zielen schaut die Figur in Kamerarichtung (seitwärts gehen)

func _ready():
	var cs=CollisionShape3D.new();var cap=CapsuleShape3D.new();cap.radius=0.32;cap.height=1.75;cs.shape=cap;cs.position.y=0.88;add_child(cs)
	floor_snap_length=0.5;floor_max_angle=deg_to_rad(50)
	collision_mask=1|8   # Welt und stehende Autos; fahrender Verkehr wird von Hand geprüft
	figur_bauen()

func figur_bauen():
	if figur:figur.queue_free()
	var r=RandomNumberGenerator.new();r.seed=5
	figur=PE.make(figur_basis,r,{"skin":PE.SKIN[5],"hair":PE.HAIR[0],"mix":0.0,"height":1.8});add_child(figur)
	PE.play(figur,"idle")
	anim="idle"
	await get_tree().process_frame
	kleidung()

func kleidung():
	O.apply(figur,{"top":O.TOPS[outfit.top][1],"bottom":O.BOTTOMS[outfit.bottom][1],"shoes":O.SHOE_LIST[outfit.shoes][1],"hat":O.HATS[outfit.hat][1],"glasses":outfit.glasses,"chain":outfit.chain})

func steuern(st,dt:float):
	if not aktiv:return
	var mv:Vector2=st.move
	var fw=Vector3(sin(cam_yaw),0,cos(cam_yaw));var rt=Vector3(-fw.z,0,fw.x)
	var dir=(fw*mv.y+rt*mv.x)
	var sp=rennen if st.sprint and not blick_fest else gehen*(1.1 if blick_fest else 1.0)
	if mv.length()<0.6 and not st.sprint:sp=gehen*clamp(mv.length()/0.6,0.3,1.0)
	var want=dir*sp
	velocity.x=move_toward(velocity.x,want.x,dt*22.0);velocity.z=move_toward(velocity.z,want.z,dt*22.0)
	if not is_on_floor():velocity.y-=19.6*dt
	elif st.pressed("springen"):velocity.y=5.2
	move_and_slide()
	_stufe(want)
	if dir.length()>0.05 and not blick_fest:
		var target=atan2(dir.x,dir.z)
		figur.rotation.y=lerp_angle(figur.rotation.y,target,clamp(dt*12.0,0.0,1.0))
	var hs=Vector2(velocity.x,velocity.z).length()
	var a="idle"
	if hs>3.2:a="run"
	elif hs>0.4:a="walk"
	if a!=anim:
		anim=a;PE.play(figur,a,0.0,1.0 if a!="walk" else clamp(hs/1.6,0.7,1.4))
	# Wasser: zurück an Land
	if global_position.y<0.4:
		im_wasser+=dt
		if im_wasser>1.2:global_position=_gelaende_ok+Vector3(0,0.5,0);velocity=Vector3.ZERO;im_wasser=0.0;return true
	else:
		im_wasser=0.0
		if is_on_floor():_gelaende_ok=global_position
	return false


# Stufen (Bordstein, Treppenabsatz) bis 45 cm automatisch hochsteigen
func _stufe(want:Vector3):
	var h=Vector2(want.x,want.z)
	if h.length()<0.5 or not is_on_wall() or velocity.y>0.5:return
	var vor=Vector3(h.x,0,h.y).normalized()*0.3
	var hoch=Vector3(0,0.45,0)
	if test_move(global_transform,hoch):return
	if test_move(global_transform.translated(hoch),vor):return
	global_position+=hoch+vor
	apply_floor_snap()
