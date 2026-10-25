extends Control
# Bildschirmanzeige + Touch-Steuerung (Mehrfinger): linker Stick (frei platzierbar), rechter Bereich = Kamera,
# runde Knöpfe je nach Modus (zu Fuß / im Auto). Minikarte, Geld, Uhr, Tacho, Hinweise.
var st      # Steuerung
var spiel   # Hauptspiel
var modus:="fuss"     # fuss | auto | menue
var touches:={}       # index -> {rolle, start, pos}
var joy_basis:=Vector2.ZERO
var joy_pos:=Vector2.ZERO
var joy_aktiv:=false
const JOY_R:=105.0
var knoepfe:=[]       # aktuell sichtbare Knöpfe
var prompt:=""
var prompt_knopf:=""  # welcher Knopf den Hinweis auslöst
var meldung:="";var meldung_zeit:=0.0
var geld:=0
var tacho:=0.0
var nos:=1.0
var gang:=""
var font:Font
var minimap:Control
var zeige_touch:=true
var job_text:=""

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_IGNORE
	font=ThemeDB.fallback_font

func knopf_layout():
	var s=get_viewport_rect().size;var k=[]
	var sc=st.e.hud_groesse
	var R=func(x):return x*sc
	if modus=="fuss":
		k.append({"n":"springen","t":"SPRUNG","p":Vector2(s.x-110,s.y-120),"r":R.call(62)})
		k.append({"n":"sprinten","t":"RENNEN","p":Vector2(s.x-240,s.y-80),"r":R.call(50),"hold":true})
		if prompt_knopf!="":k.append({"n":prompt_knopf,"t":"E" if prompt_knopf=="interagieren" else "AUTO","p":Vector2(s.x-130,s.y-280),"r":R.call(56),"hi":true})
	elif modus=="auto":
		k.append({"n":"gas","t":"GAS","p":Vector2(s.x-105,s.y-115),"r":R.call(72),"hold":true})
		k.append({"n":"bremse","t":"BREMSE","p":Vector2(s.x-265,s.y-90),"r":R.call(60),"hold":true})
		k.append({"n":"handbremse","t":"HAND","p":Vector2(s.x-230,s.y-235),"r":R.call(48),"hold":true})
		k.append({"n":"nos","t":"NOS","p":Vector2(s.x-90,s.y-285),"r":R.call(46),"hold":true})
		k.append({"n":"einsteigen","t":"RAUS","p":Vector2(s.x-90,230),"r":R.call(44)})
		k.append({"n":"hupe","t":"HUPE","p":Vector2(s.x-200,230),"r":R.call(40)})
		if spiel.ist_taxi():k.append({"n":"job","t":"TAXI","p":Vector2(s.x-310,230),"r":R.call(40),"hi":spiel.taxi_aktiv})
		if st.e.lenkung=="neigen":
			k.append({"n":"kalib","t":"NULL","p":Vector2(70,s.y-60),"r":R.call(32)})
	if modus!="menue":
		k.append({"n":"pause","t":"II","p":Vector2(s.x-50,50),"r":R.call(34)})
		k.append({"n":"karte","t":"KARTE","p":Vector2(250,70),"r":R.call(38)})
	knoepfe=k

func _process(dt):
	if meldung_zeit>0:meldung_zeit-=dt
	knopf_layout()
	queue_redraw()

func _hit(p:Vector2):
	for b in knoepfe:
		if p.distance_to(b.p)<b.r*1.15:return b
	return null

func _input(ev):
	if modus=="menue" or not visible:return
	if ev is InputEventScreenTouch:
		if ev.pressed:
			var b=_hit(ev.position)
			if b!=null:
				touches[ev.index]={"rolle":"btn","b":b.n,"hold":b.get("hold",false)}
				if not b.get("hold",false):_tap(b.n)
				_hold_update()
			elif ev.position.x<get_viewport_rect().size.x*0.42 and ev.position.y>get_viewport_rect().size.y*0.3 and not (modus=="auto" and st.e.lenkung=="neigen"):
				touches[ev.index]={"rolle":"joy"};joy_basis=ev.position;joy_pos=ev.position;joy_aktiv=true
			else:
				touches[ev.index]={"rolle":"look","pos":ev.position}
		else:
			var t=touches.get(ev.index)
			if t!=null:
				if t.rolle=="joy":joy_aktiv=false;st.t_move=Vector2.ZERO
				touches.erase(ev.index);_hold_update()
		get_viewport().set_input_as_handled()
	elif ev is InputEventScreenDrag:
		var t=touches.get(ev.index)
		if t==null:return
		if t.rolle=="joy":
			joy_pos=ev.position
			var d=(joy_pos-joy_basis)
			if d.length()>JOY_R:joy_basis=joy_pos-d.normalized()*JOY_R   # Stick wandert mit
			d=(joy_pos-joy_basis)/JOY_R
			st.t_move=Vector2(d.x,-d.y)
		elif t.rolle=="look":
			st.t_look+=ev.relative
		get_viewport().set_input_as_handled()

func _hold_update():
	var held={}
	for i in touches:
		var t=touches[i]
		if t.rolle=="btn" and t.hold:held[t.b]=true
	st.t_gas=1.0 if held.has("gas") else 0.0
	st.t_brake=1.0 if held.has("bremse") else 0.0
	st.t_hand=held.has("handbremse");st.t_nos=held.has("nos");st.t_sprint=held.has("sprinten")

func _tap(n:String):
	if n=="kalib":st.kalibrieren();zeige("Lenkung auf Mitte gestellt");return
	st.trigger(n)

func reset_touch():
	touches.clear();joy_aktiv=false;st.t_move=Vector2.ZERO;_hold_update()

func zeige(t:String,dauer:=3.0):meldung=t;meldung_zeit=dauer

func _draw():
	if modus=="menue":return
	var s=get_viewport_rect().size
	zeige_touch=not st.controller
	# Geld + Uhr oben rechts
	var uhr=spiel.uhrzeit_text()
	_txt(Vector2(s.x-110,40),uhr,28,Color(1,1,1),HORIZONTAL_ALIGNMENT_RIGHT,true)
	_txt(Vector2(s.x-110,80),"$"+_fmt(geld),34,Color(0.45,0.95,0.45),HORIZONTAL_ALIGNMENT_RIGHT,true)
	if st.e.fps:_txt(Vector2(330,40),str(Engine.get_frames_per_second())+" FPS",22,Color(1,1,0.6),HORIZONTAL_ALIGNMENT_LEFT,true)
	if job_text!="":_txt(Vector2(s.x*0.5,110),job_text,26,Color(1,0.85,0.3),HORIZONTAL_ALIGNMENT_CENTER,true)
	if meldung_zeit>0:
		var a=clamp(meldung_zeit,0.0,1.0)
		var w=font.get_string_size(meldung,HORIZONTAL_ALIGNMENT_LEFT,-1,28).x+40
		draw_rect(Rect2(s.x*0.5-w*0.5,40,w,48),Color(0,0,0,0.6*a))
		_txt(Vector2(s.x*0.5,74),meldung,28,Color(1,1,1,a),HORIZONTAL_ALIGNMENT_CENTER)
	if prompt!="":
		var w2=font.get_string_size(prompt,HORIZONTAL_ALIGNMENT_LEFT,-1,26).x+36
		draw_rect(Rect2(s.x*0.5-w2*0.5,s.y-190,w2,44),Color(0,0,0,0.55))
		_txt(Vector2(s.x*0.5,s.y-158),prompt,26,Color(1,1,1),HORIZONTAL_ALIGNMENT_CENTER)
	# Tacho
	if modus=="auto":
		var c=Vector2(s.x*0.5,s.y-60)
		_txt(c+Vector2(0,-6),str(int(tacho)),54,Color(1,1,1),HORIZONTAL_ALIGNMENT_CENTER,true)
		_txt(c+Vector2(0,24),"km/h",20,Color(0.85,0.85,0.85),HORIZONTAL_ALIGNMENT_CENTER)
		draw_rect(Rect2(c.x-90,c.y+34,180,10),Color(0,0,0,0.5));draw_rect(Rect2(c.x-90,c.y+34,180*nos,10),Color(0.2,0.7,1.0))
	if not zeige_touch:
		return
	# Stick
	if modus=="fuss" or (modus=="auto" and st.e.lenkung!="neigen"):
		if joy_aktiv:
			draw_circle(joy_basis,JOY_R,Color(1,1,1,0.12));draw_arc(joy_basis,JOY_R,0,TAU,48,Color(1,1,1,0.45),3.0)
			draw_circle(joy_pos,44,Color(1,1,1,0.4))
		else:
			var hp=Vector2(190,s.y-170)
			draw_arc(hp,JOY_R*0.8,0,TAU,40,Color(1,1,1,0.22),2.0);draw_circle(hp,34,Color(1,1,1,0.16))
			_txt(hp+Vector2(0,JOY_R*0.8+28),"LENKEN" if modus=="auto" else "LAUFEN",18,Color(1,1,1,0.5),HORIZONTAL_ALIGNMENT_CENTER)
	elif modus=="auto":
		var lw=st.steer
		var c2=Vector2(190,s.y-170)
		draw_arc(c2,70,PI*1.15,PI*1.85,24,Color(1,1,1,0.3),6.0)
		draw_line(c2,c2+Vector2(sin(lw*0.9),-cos(lw*0.9))*70,Color(1,0.85,0.3),6.0)
		_txt(c2+Vector2(0,40),"NEIGEN ZUM LENKEN",18,Color(1,1,1,0.6),HORIZONTAL_ALIGNMENT_CENTER)
	# Knöpfe
	var held={}
	for i in touches:
		if touches[i].rolle=="btn":held[touches[i].b]=true
	for b in knoepfe:
		var col=Color(0.08,0.08,0.1,0.55);var rc=Color(1,1,1,0.55)
		if b.get("hi",false):rc=Color(1,0.8,0.2,0.95)
		if held.has(b.n):col=Color(1,0.75,0.2,0.55)
		draw_circle(b.p,b.r,col);draw_arc(b.p,b.r,0,TAU,40,rc,3.0)
		var fs=int(clamp(b.r*0.42,15,30))
		_txt(b.p+Vector2(0,fs*0.35),b.t,fs,Color(1,1,1,0.95),HORIZONTAL_ALIGNMENT_CENTER)

func _txt(p:Vector2,t:String,sz:int,c:Color,al:=HORIZONTAL_ALIGNMENT_LEFT,schatten:=false):
	var w=font.get_string_size(t,HORIZONTAL_ALIGNMENT_LEFT,-1,sz).x
	var x=p.x
	if al==HORIZONTAL_ALIGNMENT_CENTER:x-=w*0.5
	elif al==HORIZONTAL_ALIGNMENT_RIGHT:x-=w
	if schatten:draw_string(font,Vector2(x+2,p.y+2),t,HORIZONTAL_ALIGNMENT_LEFT,-1,sz,Color(0,0,0,0.7))
	draw_string(font,Vector2(x,p.y),t,HORIZONTAL_ALIGNMENT_LEFT,-1,sz,c)

func _fmt(v:int)->String:
	var s=str(v);var out=""
	for i in s.length():
		if i>0 and (s.length()-i)%3==0:out+="."
		out+=s[i]
	return out
