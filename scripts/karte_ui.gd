extends Control
# Kartenbildschirm (Pause-Menü "Karte"): Luftbild der Insel, Symbole für Läden/Orte, Legende, Spielerpfeil.
# Weltkoordinaten -> Bild: x in [-1800,1800], z in [-1500,1500] (Norden oben)
var X0:=-1800.0;var Z0:=-1500.0;var WX:=3600.0;var WZ:=3000.0
var icons:=[]
var tex:Texture2D
var player:=Vector2(-180,600)
var player_dir:=0.6
var font:Font
var tippen=null   # Callable(Vector2 Welt) – Admin: Teleport per Antippen
const COL={"polizei":Color(0.15,0.35,0.95),"feuerwehr":Color(0.95,0.15,0.1),"taxi":Color(1.0,0.85,0.15),"biker":Color(0.12,0.12,0.12),"autohandel":Color(0.9,0.85,0.2),"werkstatt":Color(0.95,0.6,0.1),"waffen":Color(0.85,0.12,0.1),"kleider":Color(0.65,0.3,0.85),"zuhause":Color(0.15,0.7,0.3),
	"bahnhof":Color(0.2,0.45,0.85),"hafen":Color(0.1,0.6,0.75),"flugplatz":Color(0.55,0.55,0.6),"militaer":Color(0.4,0.45,0.25),"lack":Color(0.85,0.25,0.65),"auto":Color(0.2,0.45,0.9),"premium":Color(0.85,0.7,0.15),"lager":Color(0.55,0.4,0.25),"park":Color(0.3,0.7,0.3),"canyon":Color(0.8,0.3,0.15),"stadt":Color(0.9,0.9,0.9)}
const NAMES={"polizei":"Polizeiwache","feuerwehr":"Feuerwache","taxi":"Taxizentrale (Taxi-Jobs)","biker":"Biker-Treffpunkt","autohandel":"Autohandel (kaufbar)","lager":"Lagerhalle (kaufbar)","werkstatt":"Tuning-Werkstatt","waffen":"Waffenladen","kleider":"Kleiderladen","zuhause":"Zuhause / Speichern","bahnhof":"Hauptbahnhof","hafen":"Hafen","flugplatz":"Flughafen","militaer":"Militärbasis / Gefängnis","lack":"Lackiererei","auto":"Autohaus","premium":"Premium-Autohaus","canyon":"Roter Canyon","stadt":"Stadt / Dorf"}

func _ready():
	tex=load("res://assets/ui/karte_basis.png")
	var f=FileAccess.open("res://assets/ui/karte_icons.json",FileAccess.READ);icons=JSON.parse_string(f.get_as_text())
	font=ThemeDB.fallback_font
	var fb=FileAccess.open("res://assets/ui/karte_bereich.json",FileAccess.READ)
	if fb:
		var b=JSON.parse_string(fb.get_as_text());X0=b.x0;Z0=b.z0;WX=b.x1-b.x0;WZ=b.z1-b.z0
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if "--shot" in OS.get_cmdline_user_args():
		await get_tree().process_frame;await get_tree().process_frame;await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("/home/claude/shots_godot/karte.png");get_tree().quit()

# Ansicht: zoombar (Zwei-Finger, Mausrad, +/-), verschiebbar (Wischen); Straßen als Linien (scharf bei jedem Zoom)
var strassen:=[]        # Straßen der Welt (P, w, typ) – Comic-Welt
var story:=[]           # [Vector2, Buchstabe, Farbe, "Name (Rolle)"] – Missionsfiguren
var stadt=null          # Rect2 der Stadt (Weltkoordinaten)
var zoom:=1.0           # 1 = ganze Insel
var mitte_w=null        # Vector2 Welt-Mitte der Ansicht
var teleport_an:=false
var _touch:={};var _gezogen:=0.0;var _pinch0:=0.0;var _zoom0:=1.0
func map_rect()->Rect2:
	var s=get_viewport_rect().size;return Rect2(Vector2(20,20),Vector2(s.x-360,s.y-40))
func _skala()->float:
	var r=map_rect();return min(r.size.x/WX,r.size.y/WZ)*zoom
func w2m(p:Vector2)->Vector2:
	if mitte_w==null:mitte_w=player
	var r=map_rect();return r.position+r.size*0.5+(p-mitte_w)*_skala()
func m2w(p:Vector2)->Vector2:
	var r=map_rect();return mitte_w+(p-r.position-r.size*0.5)/_skala()

var kreuzungen:=[]
func _draw():
	if mitte_w==null:mitte_w=player if zoom>1.5 else Vector2(X0+WX*0.5,Z0+WZ*0.5)
	draw_rect(Rect2(Vector2.ZERO,get_viewport_rect().size),Color(0.2,0.42,0.6))
	var r=map_rect()
	# Grundkarte (Gelände) im aktuellen Ausschnitt
	var a=w2m(Vector2(X0,Z0));var e=w2m(Vector2(X0+WX,Z0+WZ))
	draw_texture_rect(tex,Rect2(a,e-a),false)
	# Stadt und Straßen
	var sk=_skala()
	if stadt!=null:
		pass   # Stadtfläche steckt jetzt in der Grundkarte (Blöcke hellgrau)
	for pass_ in 2:
		for st in strassen:
			var P:PackedVector2Array=st.P;var pts=PackedVector2Array()
			for i in range(0,P.size(),2 if zoom<6 else 1):pts.append(w2m(P[i]))
			pts.append(w2m(P[P.size()-1]))
			var bw=max(st.w*2.0*sk,2.0 if st.typ!="autobahn" else 3.5)
			if pass_==0:draw_polyline(pts,Color(0.1,0.08,0.09),bw+3.0)
			else:draw_polyline(pts,Color(0.99,0.78,0.25) if st.typ=="autobahn" else (Color(0.97,0.95,0.9) if st.typ!="rampe" else Color(0.95,0.85,0.6)),bw)
		# Kreuzungen als Scheiben: die Straßenstücke enden kurz vor der Kreuzung, sonst sähe das Netz zerstückelt aus
		for j in kreuzungen:
			var jr=max(j.r*sk,1.2 if pass_==1 else 2.7)
			draw_circle(w2m(j.p),jr+(1.5 if pass_==0 else 0.0),Color(0.1,0.08,0.09) if pass_==0 else Color(0.97,0.95,0.9))
	for i in icons:
		var p=w2m(Vector2(i.x,i.z))
		if r.has_point(p):icon(p,i.typ,15.0)
	for sp in story:
		var p=w2m(sp[0])
		if r.has_point(p):
			draw_circle(p,14,Color(0,0,0,0.85));draw_circle(p,12,sp[2])
			draw_string(font,p+Vector2(-6,7),sp[1],HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color(0,0,0))
	# Spieler
	var pp=w2m(player);var d=Vector2(sin(player_dir),-cos(player_dir))
	var n=Vector2(-d.y,d.x)
	draw_colored_polygon(PackedVector2Array([pp+d*16,pp-d*10+n*10,pp-d*4,pp-d*10-n*10]),Color(1,0.85,0.1))
	draw_polyline(PackedVector2Array([pp+d*16,pp-d*10+n*10,pp-d*4,pp-d*10-n*10,pp+d*16]),Color(0,0,0),2.5)
	# Rand der Kartenfläche + Legende rechts
	var s2=get_viewport_rect().size
	draw_rect(Rect2(Vector2(r.end.x,0),Vector2(s2.x-r.end.x,s2.y)),Color(0.06,0.07,0.08))
	draw_rect(r,Color(0.85,0.85,0.8),false,2.0)
	var c=Vector2(r.end.x-40,r.position.y+45)
	draw_circle(c,22,Color(0,0,0,0.55));draw_colored_polygon(PackedVector2Array([c+Vector2(0,-18),c+Vector2(7,0),c+Vector2(-7,0)]),Color(0.9,0.15,0.1))
	draw_string(font,c+Vector2(-6,-24),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color(1,1,1))
	var lx=r.end.x+24;var ly=r.position.y+10
	draw_string(font,Vector2(lx,ly+28),"RADEBERG",HORIZONTAL_ALIGNMENT_LEFT,-1,36,Color(0.98,0.85,0.35))
	draw_string(font,Vector2(lx,ly+56),"Wischen = verschieben, zwei Finger = zoomen",HORIZONTAL_ALIGNMENT_LEFT,300,14,Color(0.8,0.8,0.8))
	var y=ly+92
	var da={}
	for i in icons:da[i.typ]=true
	# Legende in zwei Spalten, damit sie über den Knöpfen (+ / – / ICH / ZURÜCK) endet
	var bw=s2.x-lx-12;var sp_w=bw*0.5;var unten=s2.y-200.0
	var eintraege=[]
	for k in ["zuhause","werkstatt","waffen","kleider","lack","polizei","feuerwehr","taxi","autohandel","lager","biker","bahnhof","hafen","flugplatz"]:
		if da.has(k):eintraege.append(k)
	var zeilen=int(ceil(eintraege.size()/2.0));var zh=min(28.0,max(20.0,(unten-y-60.0-ceil(story.size()/2.0)*24.0)/max(zeilen,1)))
	for q in eintraege.size():
		var k=eintraege[q];var px=lx+(q%2)*sp_w;var py=y+(q/2)*zh
		icon(Vector2(px+12,py),k,10.0)
		draw_string(font,Vector2(px+28,py+5),NAMES.get(k,k),HORIZONTAL_ALIGNMENT_LEFT,sp_w-30,13,Color(0.95,0.95,0.92))
	y+=zeilen*zh
	if not story.is_empty():
		y+=4;draw_string(font,Vector2(lx,y+6),"Missionen (Buchstaben):",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(0.98,0.85,0.35));y+=24
		for q in story.size():
			var sp=story[q];var px=lx+(q%2)*sp_w;var py=y+(q/2)*24.0
			draw_circle(Vector2(px+12,py),10,Color(0,0,0,0.85));draw_circle(Vector2(px+12,py),8.5,sp[2])
			draw_string(font,Vector2(px+7,py+5),sp[1],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(0,0,0))
			draw_string(font,Vector2(px+28,py+5),sp[3],HORIZONTAL_ALIGNMENT_LEFT,sp_w-30,13,Color(0.95,0.95,0.92))
		y+=ceil(story.size()/2.0)*24.0
	var pp2=Vector2(lx+16,y+8);draw_colored_polygon(PackedVector2Array([pp2+Vector2(0,-11),pp2+Vector2(8,8),pp2+Vector2(0,3),pp2+Vector2(-8,8)]),Color(1,0.85,0.1))
	draw_string(font,Vector2(lx+36,y+14),"Du",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(0.95,0.95,0.92))
	if tippen!=null and teleport_an:
		draw_string(font,Vector2(lx,s2.y-300),"Teleport an: Karte antippen",HORIZONTAL_ALIGNMENT_LEFT,300,18,Color(1,0.85,0.3))

func zoom_um(f:float,um:Vector2):
	var w=m2w(um);zoom=clamp(zoom*f,1.0,60.0)
	var r=map_rect();mitte_w=w-(um-r.position-r.size*0.5)/_skala()
	queue_redraw()

# Symbole: runde Plakette mit Piktogramm
func icon(p:Vector2,typ:String,r:float):zeichne(self,p,typ,r)
static func zeichne(ci:CanvasItem,p:Vector2,typ:String,r:float):
	ci.draw_circle(p,r+2,Color(0,0,0,0.8));ci.draw_circle(p,r,COL.get(typ,Color(0.5,0.5,0.5)))
	var w=Color(1,1,1);var f=r/15.0
	ci.draw_set_transform(p,0.0,Vector2(f,f));p=Vector2.ZERO
	match typ:
		"polizei":     # Stern
			var st=PackedVector2Array()
			for k in 10:st.append(Vector2(0,-1).rotated(k*PI/5)*(9.0 if k%2==0 else 4.0))
			ci.draw_colored_polygon(st,w)
		"feuerwehr":   # Flamme
			ci.draw_colored_polygon(PackedVector2Array([Vector2(0,-10),Vector2(5,-2),Vector2(7,4),Vector2(4,9),Vector2(-4,9),Vector2(-7,4),Vector2(-4,-1),Vector2(-2,2)]),w)
		"taxi":        # Auto
			ci.draw_rect(Rect2(Vector2(-9,-1),Vector2(18,6)),Color(0.1,0.1,0.1));ci.draw_rect(Rect2(Vector2(-5,-6),Vector2(10,6)),Color(0.1,0.1,0.1))
			ci.draw_circle(Vector2(-5,6),2.2,Color(0.1,0.1,0.1));ci.draw_circle(Vector2(5,6),2.2,Color(0.1,0.1,0.1))
		"biker":       # Rad
			ci.draw_arc(Vector2(-5,3),4.0,0,TAU,12,w,2.0);ci.draw_arc(Vector2(5,3),4.0,0,TAU,12,w,2.0);ci.draw_line(Vector2(-5,3),Vector2(2,-5),w,2.0);ci.draw_line(Vector2(2,-5),Vector2(5,3),w,2.0)
		"autohandel":  # Dollar
			ci.draw_string(ThemeDB.fallback_font,Vector2(-5,7),"$",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color(0.1,0.1,0.1))
		"lager":       # Halle
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-9,8),Vector2(-9,-2),Vector2(0,-8),Vector2(9,-2),Vector2(9,8)]),w);ci.draw_rect(Rect2(Vector2(-3,2),Vector2(6,6)),COL.lager)
		"lack":        # Pinsel
			ci.draw_line(Vector2(-6,7),Vector2(4,-3),w,3.0);ci.draw_rect(Rect2(Vector2(2,-9),Vector2(7,7)),w)
	_zeichne_alt(ci,typ,w)
	ci.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
static func _zeichne_alt(ci:CanvasItem,typ:String,w:Color):
	var p=Vector2.ZERO
	match typ:
		"werkstatt":   # Schraubenschlüssel
			ci.draw_line(p+Vector2(-7,7),p+Vector2(4,-4),w,3.5)
			ci.draw_arc(p+Vector2(5,-5),5.0,PI*0.9,PI*2.4,10,w,3.0)
		"waffen":      # Pistole
			ci.draw_colored_polygon(PackedVector2Array([p+Vector2(-9,-5),p+Vector2(9,-5),p+Vector2(9,-1),p+Vector2(-1,-1),p+Vector2(-3,8),p+Vector2(-8,8),p+Vector2(-6,-1),p+Vector2(-9,-1)]),w)
		"kleider":     # T-Shirt
			ci.draw_colored_polygon(PackedVector2Array([p+Vector2(-4,-8),p+Vector2(-10,-4),p+Vector2(-7,0),p+Vector2(-5,-2),p+Vector2(-5,8),p+Vector2(5,8),p+Vector2(5,-2),p+Vector2(7,0),p+Vector2(10,-4),p+Vector2(4,-8),p+Vector2(0,-5)]),w)
		"zuhause":     # Haus
			ci.draw_colored_polygon(PackedVector2Array([p+Vector2(0,-9),p+Vector2(9,-1),p+Vector2(6,-1),p+Vector2(6,8),p+Vector2(-6,8),p+Vector2(-6,-1),p+Vector2(-9,-1)]),w)
		"bahnhof":     # Zug
			ci.draw_rect(Rect2(p+Vector2(-7,-8),Vector2(14,13)),w);ci.draw_rect(Rect2(p+Vector2(-5,-6),Vector2(10,4)),COL.bahnhof)
			ci.draw_line(p+Vector2(-5,6),p+Vector2(-8,9),w,2.0);ci.draw_line(p+Vector2(5,6),p+Vector2(8,9),w,2.0)
		"hafen":       # Anker
			ci.draw_line(p+Vector2(0,-8),p+Vector2(0,8),w,2.5);ci.draw_line(p+Vector2(-5,-4),p+Vector2(5,-4),w,2.5)
			ci.draw_arc(p+Vector2(0,1),7.0,0.3,PI-0.3,10,w,2.5);ci.draw_circle(p+Vector2(0,-9),2.0,w)
		"flugplatz":   # Flugzeug
			ci.draw_colored_polygon(PackedVector2Array([p+Vector2(0,-10),p+Vector2(1.5,-3),p+Vector2(10,2),p+Vector2(1.5,1),p+Vector2(1.5,6),p+Vector2(4,9),p+Vector2(-4,9),p+Vector2(-1.5,6),p+Vector2(-1.5,1),p+Vector2(-10,2),p+Vector2(-1.5,-3)]),w)

func _input(ev):
	if ev is InputEventMouseButton and ev.pressed and ev.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		zoom_um(1.25 if ev.button_index==MOUSE_BUTTON_WHEEL_UP else 0.8,ev.position);get_viewport().set_input_as_handled();return
	if ev is InputEventScreenTouch:
		if ev.pressed:
			_touch[ev.index]=ev.position
			if _touch.size()==1:_gezogen=0.0
			if _touch.size()==2:var k=_touch.keys();_pinch0=_touch[k[0]].distance_to(_touch[k[1]]);_zoom0=zoom
		else:
			var war_tipp=_touch.size()==1 and _gezogen<14.0
			_touch.erase(ev.index)
			if war_tipp and tippen!=null and teleport_an and map_rect().has_point(ev.position):tippen.call(m2w(ev.position))
		get_viewport().set_input_as_handled()
	elif ev is InputEventScreenDrag:
		_touch[ev.index]=ev.position
		if _touch.size()==1:
			_gezogen+=ev.relative.length();mitte_w-=ev.relative/_skala();queue_redraw()
		elif _touch.size()==2:
			var k=_touch.keys();var d=_touch[k[0]].distance_to(_touch[k[1]])
			if _pinch0>10.0:
				var mitte_s=(_touch[k[0]]+_touch[k[1]])*0.5
				zoom_um((_zoom0*d/_pinch0)/zoom,mitte_s)
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton and ev.button_index==MOUSE_BUTTON_LEFT and not ev.pressed and tippen!=null and teleport_an and map_rect().has_point(ev.position):
		tippen.call(m2w(ev.position))
