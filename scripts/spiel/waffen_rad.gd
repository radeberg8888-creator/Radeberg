extends Control
# Waffenrad (wie in GTA): Kreis mit 8 Fächern (Nahkampf, Pistolen, MPs, Schrot, Gewehre, MG, Scharfschützen, Spray).
# Fach antippen = Waffe dieser Klasse; nochmal antippen = nächste Waffe derselben Klasse. Mitte antippen = schließen.
# Während das Rad offen ist, läuft das Spiel in Zeitlupe.
const WD=preload("res://scripts/spiel/waffen_daten.gd")
const FAECHER=[["nah","Nahkampf"],["pistole","Pistolen"],["mp","MPs"],["schrot","Schrot"],["gewehr","Gewehre"],["mg","MG"],["sniper","Scharfschütze"],["spray","Spray"]]
var kampf
var wahl:={}      # Klasse -> gewählte Waffen-ID
var R:=260.0
var R_innen:=95.0
var _auf:=false

func _ready():
	mouse_filter=Control.MOUSE_FILTER_STOP;visible=false;set_anchors_preset(Control.PRESET_FULL_RECT)

func oeffnen():
	position=Vector2.ZERO;size=get_viewport_rect().size
	visible=true;_auf=true;Engine.time_scale=0.2
	var d=WD.daten(kampf.aktuell);wahl[d.typ]=kampf.aktuell
	queue_redraw()
func schliessen():
	visible=false;_auf=false;Engine.time_scale=1.0

func _liste(typ:String)->Array:
	return WD.REIHE.filter(func(i):return kampf.waffen.has(i) and WD.daten(i).typ==typ)

func _mitte()->Vector2:return size*0.5

func _gui_input(ev):
	if not (ev is InputEventScreenTouch or ev is InputEventMouseButton) or not ev.pressed:return
	var d=ev.position-_mitte()
	accept_event()
	if d.length()<R_innen or d.length()>R+40.0:schliessen();return
	var a=fposmod(atan2(d.x,-d.y),TAU)
	var i=int(a/(TAU/FAECHER.size()))%FAECHER.size()
	var typ=FAECHER[i][0];var l=_liste(typ)
	if l.is_empty():return
	var jetzt=wahl.get(typ,l[0])
	if WD.daten(kampf.aktuell).typ==typ:jetzt=l[(l.find(jetzt)+1)%l.size()]   # gleiches Fach: weiterschalten
	wahl[typ]=jetzt;kampf.waehle(jetzt);queue_redraw()

func _draw():
	var c=_mitte()
	draw_circle(c,R+8.0,Color(0,0,0,0.45))
	var n=FAECHER.size();var akt_typ=WD.daten(kampf.aktuell).typ
	for i in n:
		var a0=i*TAU/n-PI*0.5;var a1=(i+1)*TAU/n-PI*0.5
		var pts=PackedVector2Array()
		for k in 13:pts.append(c+Vector2.from_angle(lerp(a0,a1,k/12.0))*R)
		for k in 13:pts.append(c+Vector2.from_angle(lerp(a1,a0,k/12.0))*R_innen)
		var typ=FAECHER[i][0];var l=_liste(typ)
		var farbe=Color(0.95,0.75,0.15,0.85) if typ==akt_typ else (Color(0.16,0.17,0.2,0.88) if l.size()>0 else Color(0.1,0.1,0.11,0.6))
		draw_colored_polygon(pts,farbe)
		pts.append(pts[0]);draw_polyline(pts,Color(1,1,1,0.35),2.0)
		var m=c+Vector2.from_angle((a0+a1)*0.5)*(R+R_innen)*0.5
		var f=get_theme_default_font()
		var tc=Color(0.1,0.1,0.1) if typ==akt_typ else Color(1,1,1,0.9 if l.size()>0 else 0.35)
		draw_string(f,m+Vector2(-80,-16),FAECHER[i][1],HORIZONTAL_ALIGNMENT_CENTER,160,17,tc)
		if l.size()>0:
			var id=wahl.get(typ,l[0]) if wahl.get(typ,"") in l else l[0]
			draw_string(f,m+Vector2(-80,10),WD.daten(id).name,HORIZONTAL_ALIGNMENT_CENTER,160,20,tc)
			if l.size()>1:draw_string(f,m+Vector2(-80,34),"%d/%d  ›"%[l.find(id)+1,l.size()],HORIZONTAL_ALIGNMENT_CENTER,160,15,tc)
			var d=WD.daten(id)
			if d.typ!="nah" and d.typ!="spray":draw_string(f,m+Vector2(-80,54),"%d"%(kampf.magazin.get(id,0)+kampf.waffen.get(id,0)),HORIZONTAL_ALIGNMENT_CENTER,160,15,tc)
	draw_circle(c,R_innen-6.0,Color(0,0,0,0.6))
	draw_string(get_theme_default_font(),c+Vector2(-80,8),"ZURÜCK",HORIZONTAL_ALIGNMENT_CENTER,160,20,Color(1,1,1,0.85))
