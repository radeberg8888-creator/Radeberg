extends Control
# Kartenbildschirm (Pause-Menü "Karte"): Luftbild der Insel, Symbole für Läden/Orte, Legende, Spielerpfeil.
# Weltkoordinaten -> Bild: x in [-1800,1800], z in [-1500,1500] (Norden oben)
var X0:=-1800.0;var Z0:=-1500.0;var WX:=3600.0;var WZ:=3000.0
var icons:=[]
var tex:Texture2D
var player:=Vector2(-180,600)
var player_dir:=0.6
var font:Font
const COL={"werkstatt":Color(0.95,0.6,0.1),"waffen":Color(0.85,0.12,0.1),"kleider":Color(0.65,0.3,0.85),"zuhause":Color(0.15,0.7,0.3),
	"bahnhof":Color(0.2,0.45,0.85),"hafen":Color(0.1,0.6,0.75),"flugplatz":Color(0.55,0.55,0.6)}
const NAMES={"werkstatt":"Tuning-Werkstatt","waffen":"Waffenladen","kleider":"Kleiderladen","zuhause":"Zuhause / Speichern","bahnhof":"Hauptbahnhof","hafen":"Hafen","flugplatz":"Flugplatz"}

func _ready():
	var img=load("res://assets/ui/karte_basis.png").get_image()
	tex=ImageTexture.create_from_image(img)
	var f=FileAccess.open("res://assets/ui/karte_icons.json",FileAccess.READ);icons=JSON.parse_string(f.get_as_text())
	font=ThemeDB.fallback_font
	var fb=FileAccess.open("res://assets/ui/karte_bereich.json",FileAccess.READ)
	if fb:
		var b=JSON.parse_string(fb.get_as_text());X0=b.x0;Z0=b.z0;WX=b.x1-b.x0;WZ=b.z1-b.z0
		# auf die Insel zuschneiden (x -1850..1850)
		var px0=int((-1850.0-X0)/WX*img.get_width());var px1=int((1850.0-X0)/WX*img.get_width())
		if px0>0:
			img=img.get_region(Rect2i(px0,0,px1-px0,img.get_height()));tex=ImageTexture.create_from_image(img)
			X0=-1850.0;WX=3700.0
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if "--shot" in OS.get_cmdline_user_args():
		await get_tree().process_frame;await get_tree().process_frame;await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("/home/claude/shots_godot/karte.png");get_tree().quit()

func map_rect()->Rect2:
	var s=get_viewport_rect().size;var h=s.y-40;var w=h*WX/WZ
	return Rect2(Vector2(30,20),Vector2(w,h))
func w2m(p:Vector2)->Vector2:
	var r=map_rect();return r.position+Vector2((p.x-X0)/WX*r.size.x,(p.y-Z0)/WZ*r.size.y)

func _draw():
	draw_rect(Rect2(Vector2.ZERO,get_viewport_rect().size),Color(0.06,0.07,0.08))
	var r=map_rect()
	draw_texture_rect(tex,r,false,Color(0.92,0.95,0.98))
	draw_rect(r,Color(0.85,0.85,0.8),false,2.0)
	# Gitter (Planquadrate)
	for k in range(1,6):
		var x=r.position.x+r.size.x*k/6.0;draw_line(Vector2(x,r.position.y),Vector2(x,r.end.y),Color(1,1,1,0.08),1.0)
		var y=r.position.y+r.size.y*k/6.0;draw_line(Vector2(r.position.x,y),Vector2(r.end.x,y),Color(1,1,1,0.08),1.0)
	for i in icons:
		var p=w2m(Vector2(i.x,i.z))
		icon(p,i.typ,15.0)
	# Spieler
	var pp=w2m(player);var d=Vector2(sin(player_dir),-cos(player_dir))
	var n=Vector2(-d.y,d.x)
	draw_colored_polygon(PackedVector2Array([pp+d*14,pp-d*9+n*9,pp-d*4,pp-d*9-n*9]),Color(1,1,1))
	draw_polyline(PackedVector2Array([pp+d*14,pp-d*9+n*9,pp-d*4,pp-d*9-n*9,pp+d*14]),Color(0,0,0),2.0)
	# Kompass
	var c=Vector2(r.end.x-40,r.position.y+45)
	draw_circle(c,22,Color(0,0,0,0.55));draw_colored_polygon(PackedVector2Array([c+Vector2(0,-18),c+Vector2(7,0),c+Vector2(-7,0)]),Color(0.9,0.15,0.1))
	draw_string(font,c+Vector2(-6,-24),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color(1,1,1))
	# Legende
	var lx=r.end.x+30;var ly=r.position.y+10
	draw_string(font,Vector2(lx,ly+28),"RADEBERG",HORIZONTAL_ALIGNMENT_LEFT,-1,40,Color(0.98,0.85,0.35))
	draw_string(font,Vector2(lx,ly+56),"Karte",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color(0.8,0.8,0.8))
	var y=ly+100
	for k in ["zuhause","werkstatt","waffen","kleider","bahnhof","hafen","flugplatz"]:
		icon(Vector2(lx+16,y),k,15.0)
		draw_string(font,Vector2(lx+42,y+7),NAMES[k],HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color(0.95,0.95,0.92))
		y+=44
	y+=10
	var pp2=Vector2(lx+16,y);draw_colored_polygon(PackedVector2Array([pp2+Vector2(0,-13),pp2+Vector2(9,9),pp2+Vector2(0,4),pp2+Vector2(-9,9)]),Color(1,1,1))
	draw_string(font,Vector2(lx+42,y+7),"Du",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color(0.95,0.95,0.92))
	y+=60
	for t in ["Gebiete:","  Downtown · Altstadt · Ghetto","  Hafen · Industrie · Vorort","  Berg (Wald) · Wüste"]:
		draw_string(font,Vector2(lx,y),t,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color(0.75,0.75,0.72));y+=26

# Symbole: runde Plakette mit Piktogramm
func icon(p:Vector2,typ:String,r:float):
	draw_circle(p,r+2,Color(0,0,0,0.8));draw_circle(p,r,COL.get(typ,Color(0.5,0.5,0.5)))
	var w=Color(1,1,1)
	match typ:
		"werkstatt":   # Schraubenschlüssel
			draw_line(p+Vector2(-7,7),p+Vector2(4,-4),w,3.5)
			draw_arc(p+Vector2(5,-5),5.0,PI*0.9,PI*2.4,10,w,3.0)
		"waffen":      # Pistole
			draw_colored_polygon(PackedVector2Array([p+Vector2(-9,-5),p+Vector2(9,-5),p+Vector2(9,-1),p+Vector2(-1,-1),p+Vector2(-3,8),p+Vector2(-8,8),p+Vector2(-6,-1),p+Vector2(-9,-1)]),w)
		"kleider":     # T-Shirt
			draw_colored_polygon(PackedVector2Array([p+Vector2(-4,-8),p+Vector2(-10,-4),p+Vector2(-7,0),p+Vector2(-5,-2),p+Vector2(-5,8),p+Vector2(5,8),p+Vector2(5,-2),p+Vector2(7,0),p+Vector2(10,-4),p+Vector2(4,-8),p+Vector2(0,-5)]),w)
		"zuhause":     # Haus
			draw_colored_polygon(PackedVector2Array([p+Vector2(0,-9),p+Vector2(9,-1),p+Vector2(6,-1),p+Vector2(6,8),p+Vector2(-6,8),p+Vector2(-6,-1),p+Vector2(-9,-1)]),w)
		"bahnhof":     # Zug
			draw_rect(Rect2(p+Vector2(-7,-8),Vector2(14,13)),w);draw_rect(Rect2(p+Vector2(-5,-6),Vector2(10,4)),COL.bahnhof)
			draw_line(p+Vector2(-5,6),p+Vector2(-8,9),w,2.0);draw_line(p+Vector2(5,6),p+Vector2(8,9),w,2.0)
		"hafen":       # Anker
			draw_line(p+Vector2(0,-8),p+Vector2(0,8),w,2.5);draw_line(p+Vector2(-5,-4),p+Vector2(5,-4),w,2.5)
			draw_arc(p+Vector2(0,1),7.0,0.3,PI-0.3,10,w,2.5);draw_circle(p+Vector2(0,-9),2.0,w)
		"flugplatz":   # Flugzeug
			draw_colored_polygon(PackedVector2Array([p+Vector2(0,-10),p+Vector2(1.5,-3),p+Vector2(10,2),p+Vector2(1.5,1),p+Vector2(1.5,6),p+Vector2(4,9),p+Vector2(-4,9),p+Vector2(-1.5,6),p+Vector2(-1.5,1),p+Vector2(-10,2),p+Vector2(-1.5,-3)]),w)
