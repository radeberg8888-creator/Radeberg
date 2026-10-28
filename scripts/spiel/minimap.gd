extends Control
# Runde Minikarte (oben links), dreht sich mit der Blickrichtung; Symbole für Läden, Ziel, Spieler.
var tex:Texture2D
var X0:=-1850.0;var Z0:=-1500.0;var WX:=3700.0;var WZ:=3000.0
var icons:=[]
var mitte:=Vector2.ZERO     # Spielerposition (Welt x,z)
var drehung:=0.0            # Kamerablick (rad)
var zoom:=260.0             # sichtbarer Radius in Metern
var ziel=null               # Vector2 oder null
var rect_mat:ShaderMaterial
var R:=88.0
const COL={"werkstatt":Color(0.95,0.6,0.1),"waffen":Color(0.85,0.12,0.1),"kleider":Color(0.65,0.3,0.85),"zuhause":Color(0.15,0.7,0.3),
	"bahnhof":Color(0.2,0.45,0.85),"hafen":Color(0.1,0.6,0.75),"flugplatz":Color(0.55,0.55,0.6),"canyon":Color(0.8,0.3,0.15),"stadt":Color(0.9,0.9,0.9)}

func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var fb=FileAccess.open("res://assets/ui/karte_bereich.json",FileAccess.READ)
	if fb:
		var b=JSON.parse_string(fb.get_as_text());X0=b.x0;Z0=b.z0;WX=b.x1-b.x0;WZ=b.z1-b.z0
	tex=load("res://assets/ui/karte_basis.png")
	var f=FileAccess.open("res://assets/ui/karte_icons.json",FileAccess.READ);icons=JSON.parse_string(f.get_as_text())
	var cr=ColorRect.new();add_child(cr);cr.size=Vector2(R*2,R*2);cr.position=Vector2(0,0);cr.mouse_filter=Control.MOUSE_FILTER_IGNORE
	rect_mat=ShaderMaterial.new();rect_mat.shader=load("res://shaders/minimap.gdshader");rect_mat.set_shader_parameter("map",tex);cr.material=rect_mat
	size=Vector2(R*2,R*2)

func _process(_d):
	var c=Vector2((mitte.x-X0)/WX,(mitte.y-Z0)/WZ)
	rect_mat.set_shader_parameter("center",c)
	rect_mat.set_shader_parameter("span",Vector2(zoom*2.0/WX,zoom*2.0/WZ))
	rect_mat.set_shader_parameter("rot",drehung)
	queue_redraw()

func w2m(p:Vector2)->Vector2:
	var d=(p-mitte)/zoom*R
	return Vector2(R,R)+d.rotated(-drehung)

func _draw():
	draw_arc(Vector2(R,R),R,0,TAU,64,Color(0,0,0,0.85),5.0)
	for i in icons:
		var p=w2m(Vector2(i.x,i.z))
		var d=p-Vector2(R,R)
		if d.length()>R-10:p=Vector2(R,R)+d.normalized()*(R-10)
		draw_circle(p,8,Color(0,0,0,0.8));draw_circle(p,6.5,COL.get(i.typ,Color(0.6,0.6,0.6)))
	if ziel!=null:
		var p2=w2m(ziel);var d2=p2-Vector2(R,R)
		if d2.length()>R-8:p2=Vector2(R,R)+d2.normalized()*(R-8)
		draw_circle(p2,9,Color(0,0,0));draw_circle(p2,7,Color(1,0.85,0.1))
	# Spielerpfeil (zeigt immer nach oben = Blickrichtung)
	var c=Vector2(R,R)
	draw_colored_polygon(PackedVector2Array([c+Vector2(0,-11),c+Vector2(8,8),c+Vector2(0,4),c+Vector2(-8,8)]),Color(1,1,1))
	# Norden
	var n=Vector2(0,-1).rotated(-drehung)*(R-2)+c
	draw_circle(n,10,Color(0,0,0,0.85));draw_string(ThemeDB.fallback_font,n+Vector2(-5,6),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(1,1,1))
