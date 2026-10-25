extends Node3D
# Kleiderladen "Stoffwechsel": Innenraum mit Regalen, Spiegel und Umkleide; die Spielfigur steht auf dem Podest,
# rechts das Menü (Oberteil / Hose / Schuhe / Kopf / Extras) mit Preisen. Auswahl ändert die Kleidung sofort.
const Mats=preload("res://scripts/mats.gd")
const Batch=preload("res://scripts/batch.gd")
const O=preload("res://scripts/outfit.gd")
var player:Node3D
var base:="joe"
var sel:={"top":0,"bottom":0,"shoes":0,"hat":0,"glasses":false,"chain":false}
var cat:=0
var ui:Control
var cam:Camera3D
const CATS=["Oberteil","Hose","Schuhe","Kopf","Extras"]

func _ready():
	var sun=load("res://scripts/env.gd").make(self,"day");sun.light_energy=0.6
	for c in get_children():
		if c is WorldEnvironment:c.environment.fog_enabled=false;c.environment.ambient_light_energy=0.7
	room()
	cam=Camera3D.new();add_child(cam);cam.position=Vector3(-0.9,1.45,3.6);cam.look_at(Vector3(-0.9,1.0,0));cam.fov=42
	make_player()
	ui=Control.new();ui.set_anchors_preset(Control.PRESET_FULL_RECT);var cl=CanvasLayer.new();add_child(cl);cl.add_child(ui)
	ui.draw.connect(_draw_ui)
	var a=OS.get_cmdline_user_args()
	if "--shots" in a:_shots()
	if "--kopf" in a:_kopf()

func room():
	var b=Batch.new()
	var floor_m=Mats.pbr("pavers",0.6,Color(0.55,0.45,0.36));var wall=Mats.pbr("plaster_white",0.4,Color(0.92,0.9,0.86));var dark=Mats.flat(Color(0.12,0.12,0.13),0.4,0.6)
	b.box(floor_m,Vector3(-7,-0.1,-6),Vector3(7,0,5))
	b.box(wall,Vector3(-7,0,-6.2),Vector3(7,4.2,-6));b.box(wall,Vector3(-7.2,0,-6),Vector3(-7,4.2,5));b.box(wall,Vector3(7,0,-6),Vector3(7.2,4.2,5))
	b.box(Mats.flat(Color(0.95,0.95,0.93),0.8),Vector3(-7,4.2,-6),Vector3(7,4.3,5))
	# Podest
	b.cyl(Mats.flat(Color(0.2,0.2,0.22),0.3,0.4),Vector3(-0.9,0.06,0),0.8,0.12)
	# Kleiderstangen mit Kleidung an den Wänden
	var cols=[]
	for t in O.TOPS:cols.append(t[1])
	for k in 3:
		var x0=-6.5+k*4.4
		b.box(dark,Vector3(x0,1.75,-5.6),Vector3(x0+3.6,1.79,-5.56))
		for j in 16:
			var c=cols[(j+k*3)%cols.size()]
			b.box(Mats.flat(c,0.85),Vector3(x0+0.1+j*0.215,0.85,-5.75),Vector3(x0+0.27+j*0.215,1.72,-5.35))
	for s in [-1,1]:
		for k in 4:   # Regale mit gefalteten Hosen
			for j in 6:
				var c=O.BOTTOMS[(j+k)%O.BOTTOMS.size()][1]
				b.box(Mats.flat(c,0.9),Vector3(s*6.95-0.25*s-0.25,0.5+k*0.75,-4.6+j*0.7),Vector3(s*6.95-0.25*s+0.25,0.62+k*0.75,-4.1+j*0.7))
			b.box(Mats.flat(Color(0.75,0.68,0.55),0.7),Vector3(s*6.95-0.45,0.48+k*0.75,-5),Vector3(s*6.95+0.0,0.5+k*0.75,0))
	# Schuhwand
	for j in 8:
		for k in 3:b.box(Mats.flat(O.SHOE_LIST[(j+k)%4][1],0.5),Vector3(2.5+j*0.5,0.6+k*0.5,-5.9),Vector3(2.78+j*0.5,0.72+k*0.5,-5.6))
	# Spiegel + Umkleide
	var mirror=StandardMaterial3D.new();mirror.albedo_color=Color(0.85,0.88,0.9);mirror.metallic=1.0;mirror.roughness=0.02
	b.box(Mats.flat(Color(0.15,0.12,0.1),0.5),Vector3(-3.7,0.2,-5.99),Vector3(-2.3,2.5,-5.93))
	b.box(Mats.flat(Color(0.55,0.6,0.62),0.05,0.9),Vector3(-3.6,0.3,-5.98),Vector3(-2.4,2.4,-5.9))
	b.box(Mats.flat(Color(0.5,0.1,0.12),0.9),Vector3(4.2,0,-1),Vector3(6.9,2.6,-0.95))
	b.commit(self)
	for x in [-4.0,0.0,4.0]:
		var l=OmniLight3D.new();add_child(l);l.position=Vector3(x,3.8,-1.5);l.omni_range=9;l.light_energy=1.4;l.light_color=Color(1,0.95,0.88)
	var spot=SpotLight3D.new();add_child(spot);spot.position=Vector3(-0.9,4.0,1.5);spot.look_at(Vector3(-0.9,1,0));spot.light_energy=4;spot.spot_angle=28;spot.shadow_enabled=true
	var sign=Label3D.new();sign.text="STOFFWECHSEL";sign.font_size=160;sign.pixel_size=0.0032;sign.modulate=Color(0.15,0.15,0.17);sign.outline_size=0;add_child(sign);sign.position=Vector3(-3.0,3.4,-5.9)

func make_player():
	if player:player.queue_free()
	var PE=load("res://scripts/people.gd");var r=RandomNumberGenerator.new();r.seed=5
	player=PE.make(base,r,{"skin":PE.SKIN[5],"hair":PE.HAIR[0],"mix":0.0,"height":1.8});add_child(player)
	player.position=Vector3(-0.9,0.12,0);player.rotation.y=0.25
	PE.play(player,"idle",0.3)
	refresh()

func outfit()->Dictionary:
	return {"top":O.TOPS[sel.top][1],"bottom":O.BOTTOMS[sel.bottom][1],"shoes":O.SHOE_LIST[sel.shoes][1],"hat":O.HATS[sel.hat][1],"glasses":sel.glasses,"chain":sel.chain}
func refresh():
	O.apply(player,outfit())
	if ui:ui.queue_redraw()

func _unhandled_input(e):
	if e is InputEventKey and e.pressed:
		match e.keycode:
			KEY_UP:cat=(cat+CATS.size()-1)%CATS.size()
			KEY_DOWN:cat=(cat+1)%CATS.size()
			KEY_RIGHT:_step(1)
			KEY_LEFT:_step(-1)
		refresh()
func _step(d:int):
	match cat:
		0:sel.top=(sel.top+d+O.TOPS.size())%O.TOPS.size()
		1:sel.bottom=(sel.bottom+d+O.BOTTOMS.size())%O.BOTTOMS.size()
		2:sel.shoes=(sel.shoes+d+O.SHOE_LIST.size())%O.SHOE_LIST.size()
		3:sel.hat=(sel.hat+d+O.HATS.size())%O.HATS.size()
		4:
			if sel.glasses and sel.chain:sel.glasses=false;sel.chain=false
			elif sel.glasses:sel.chain=true
			else:sel.glasses=true

func _draw_ui():
	var f=ThemeDB.fallback_font;var s=ui.size
	var x0=s.x-430.0;var y0=40.0
	ui.draw_rect(Rect2(x0-20,y0-20,410,s.y-50),Color(0.04,0.04,0.05,0.82))
	ui.draw_string(f,Vector2(x0,y0+28),"STOFFWECHSEL",HORIZONTAL_ALIGNMENT_LEFT,-1,34,Color(0.98,0.85,0.35))
	ui.draw_string(f,Vector2(x0,y0+56),"Mode · Schuhe · Caps",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color(0.75,0.75,0.72))
	var vals=[O.TOPS[sel.top],O.BOTTOMS[sel.bottom],O.SHOE_LIST[sel.shoes],O.HATS[sel.hat],["Brille "+("ja" if sel.glasses else "nein")+" · Kette "+("ja" if sel.chain else "nein"),null,(25 if sel.glasses else 0)+(150 if sel.chain else 0)]]
	var y=y0+110.0;var total=0
	for k in CATS.size():
		var active=k==cat
		ui.draw_rect(Rect2(x0-8,y-30,386,62),Color(0.95,0.75,0.2,0.22) if active else Color(1,1,1,0.05))
		ui.draw_string(f,Vector2(x0,y-6),CATS[k],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color(0.7,0.7,0.68))
		var v=vals[k];var price=0
		if k<3:price=v[2]
		elif k==4:price=v[2]
		elif k==3 and sel.hat>0:price=20
		total+=price
		ui.draw_string(f,Vector2(x0,y+20),("◀  " if active else "")+str(v[0])+("  ▶" if active else ""),HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color(1,1,1))
		if v.size()>1 and v[1] is Color:ui.draw_rect(Rect2(x0+300,y-2,28,22),v[1]);ui.draw_rect(Rect2(x0+300,y-2,28,22),Color(1,1,1,0.6),false,1.0)
		ui.draw_string(f,Vector2(x0+340,y+20),"$"+str(price),HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color(0.5,0.95,0.5))
		y+=78
	ui.draw_line(Vector2(x0,y-10),Vector2(x0+370,y-10),Color(1,1,1,0.3),1.0)
	ui.draw_string(f,Vector2(x0,y+22),"Gesamt",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color(0.9,0.9,0.9))
	ui.draw_string(f,Vector2(x0+300,y+22),"$"+str(total),HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color(0.5,0.95,0.5))
	ui.draw_rect(Rect2(x0,y+50,180,52),Color(0.2,0.55,0.25));ui.draw_string(f,Vector2(x0+42,y+84),"KAUFEN",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color(1,1,1))
	ui.draw_rect(Rect2(x0+195,y+50,175,52),Color(0.3,0.3,0.33));ui.draw_string(f,Vector2(x0+222,y+84),"VERLASSEN",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color(1,1,1))
	ui.draw_string(f,Vector2(x0,s.y-30),"Wischen: Teil wechseln · Tippen: Kategorie",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(0.6,0.6,0.58))

func _shots():
	var looks=[
		[{"top":0,"bottom":0,"shoes":0,"hat":0,"glasses":false,"chain":false},0,"joe"],
		[{"top":2,"bottom":2,"shoes":0,"hat":4,"glasses":true,"chain":true},3,"joe"],
		[{"top":4,"bottom":1,"shoes":2,"hat":1,"glasses":false,"chain":true},0,"joe"],
		[{"top":3,"bottom":0,"shoes":1,"hat":3,"glasses":true,"chain":false},1,"daya"],
		[{"top":7,"bottom":4,"shoes":3,"hat":2,"glasses":true,"chain":true},2,"biker"],
	]
	for i in looks.size():
		sel=looks[i][0].duplicate();cat=looks[i][1]
		if base!=looks[i][2]:base=looks[i][2];make_player()
		else:refresh()
		for k in 12:await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("/home/claude/shots_godot/kleider_%d.png"%i)
	get_tree().quit()

func _kopf():
	var looks=[["joe",{"top":0,"bottom":0,"shoes":0,"hat":1,"glasses":true,"chain":true}],["daya",{"top":0,"bottom":0,"shoes":0,"hat":3,"glasses":true,"chain":true}],["joe",{"top":0,"bottom":0,"shoes":0,"hat":4,"glasses":false,"chain":false}]]
	var i=0
	for l in looks:
		base=l[0];sel=l[1];make_player()
		await get_tree().process_frame
		var sk=player.find_children("*","Skeleton3D",true,false)[0]
		var hb=-1
		for k in sk.get_bone_count():if sk.get_bone_name(k).contains("Head") and hb<0:hb=k
		var hp=sk.global_transform*sk.get_bone_global_pose(hb).origin
		for v in [Vector3(0.25,0.08,0.75),Vector3(0.9,0.1,0.05)]:
			var dir=player.global_transform.basis*v
			cam.global_position=hp+dir*0.9+Vector3(0,0.12,0);cam.look_at(hp+Vector3(0,0.1,0));cam.fov=30
			for k in 8:await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("/home/claude/shots_godot/kopf_%d.png"%i);i+=1
	get_tree().quit()
