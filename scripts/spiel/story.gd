extends Node
# Story-Kampagne: mehrere Hauptfiguren mit eigener Handlung. Jede Figur wohnt an einem festen Ort
# (Buchstabe auf Karte/Minimap). Hinfahren, in den gelben Kreis gehen -> Briefing -> Mission.
# Kapitel einer Figur bauen aufeinander auf; neue Figuren schalten sich durch Fortschritt frei.
var spiel
const FIGUREN:=[
	{"id":"rudi","buchst":"R","farbe":Color(0.95,0.75,0.15),"ort":"ghetto","art":"Gangster","frei":[]},
	{"id":"mara","buchst":"M","farbe":Color(0.95,0.35,0.6),"ort":"werkstatt","art":"Tunerin","frei":[["rudi",2]]},
	{"id":"viktor","buchst":"V","farbe":Color(0.3,0.75,0.95),"ort":"docks","art":"Schmuggler","frei":[["rudi",4]]},
	{"id":"jojo","buchst":"J","farbe":Color(0.4,0.95,0.45),"ort":"altstadt","art":"Hacker","frei":[["mara",2]]},
	{"id":"ines","buchst":"I","farbe":Color(0.85,0.85,0.95),"ort":"sonnenhuegel","art":"Millionärin","frei":[["viktor",3]]},
	{"id":"brandt","buchst":"K","farbe":Color(0.45,0.55,1.0),"ort":"downtown","art":"korrupter Kommissar","frei":[["rudi",6]]},
	{"id":"baron","buchst":"B","farbe":Color(0.85,0.45,0.2),"ort":"staubwinkel","art":"Waffenhändler in der Wüste","frei":[["viktor",5]]},
	{"id":"petro","buchst":"P","farbe":Color(0.75,0.4,0.95),"ort":"oststadt","art":"Clubbesitzer","frei":[["ines",3]]},
]
var punkte:={}       # id -> Vector3
var marker:={}       # id -> Node3D
var alle_frei:=false

func setup():
	for f in FIGUREN:
		var p:Vector3=spiel.mis.ort(f.ort,hash(f.id)+77)
		punkte[f.id]=p
		var n=Node3D.new();spiel.add_child(n);n.global_position=p
		var m=MeshInstance3D.new();var cy=CylinderMesh.new();cy.top_radius=1.6;cy.bottom_radius=1.6;cy.height=1.6;cy.cap_top=false;cy.cap_bottom=false;m.mesh=cy
		var mt=StandardMaterial3D.new();mt.albedo_color=Color(f.farbe.r,f.farbe.g,f.farbe.b,0.3);mt.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		mt.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mt.cull_mode=BaseMaterial3D.CULL_DISABLED
		m.material_override=mt;m.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;n.add_child(m);m.position.y=0.8
		var l=Label3D.new();l.text=f.buchst;l.font_size=96;l.pixel_size=0.02;l.billboard=BaseMaterial3D.BILLBOARD_ENABLED;l.modulate=f.farbe;l.outline_size=16
		n.add_child(l);l.position.y=3.4;l.visibility_range_end=250.0
		marker[f.id]=n
		spiel.zonen.append({"typ":"story","p":p,"r":2.0,"text":"","d":f})
	aktualisieren()

func kapitel(id:String)->Array:
	var out=[]
	for m in spiel.mis.spielbare():
		if m.kontakt==id:out.append(m)
	out.sort_custom(func(a,b):return int(a.id)<int(b.id))
	return out

func erledigt_zahl(id:String)->int:
	var n=0
	for m in kapitel(id):
		if spiel.mis.erledigt.has(str(m.id)):n+=1
	return n

func ist_frei(f:Dictionary)->bool:
	if alle_frei or spiel.admin:return true
	for b in f.frei:
		if erledigt_zahl(b[0])<b[1]:return false
	return true

func naechste(id:String):
	for m in kapitel(id):
		if not spiel.mis.erledigt.has(str(m.id)):return m
	return null

func aktualisieren():
	var pts=[]
	for f in FIGUREN:
		var aktiv=ist_frei(f) and naechste(f.id)!=null
		marker[f.id].visible=aktiv
		for z in spiel.zonen:
			if z.typ=="story" and z.d.id==f.id:z.text=(spiel.mis.kontakt_name(f.id)+" – Mission starten") if aktiv else ""
		if aktiv:pts.append([Vector2(punkte[f.id].x,punkte[f.id].z),f.buchst,f.farbe])
	if spiel.mini:spiel.mini.story_punkte=pts

func alles_frei():
	alle_frei=true;aktualisieren()

func betreten(f:Dictionary):
	if spiel.mis.aktiv!=null:spiel.hud.zeige("Erst die laufende Mission beenden.",2.0);return
	if not ist_frei(f):return
	var m=naechste(f.id)
	if m==null:return
	var ks=kapitel(f.id);var nr=ks.find(m)+1
	var v=spiel._panel(spiel.mis.kontakt_name(f.id).to_upper())
	var rolle=spiel.mis.daten.get("kontakte",{}).get(f.id,{}).get("rolle",f.art)
	for t in [[f.art.capitalize()+" – "+rolle,18,Color(0.75,0.75,0.75)],["Kapitel %d von %d:  %s"%[nr,ks.size(),m.titel],24,f.farbe],[m.get("briefing",""),20,Color(1,1,1)],["Belohnung: $"+str(int(m.belohnung)),20,Color(0.4,0.95,0.45)]]:
		var l=Label.new();l.text=t[0];l.autowrap_mode=TextServer.AUTOWRAP_WORD;l.custom_minimum_size=Vector2(470,0)
		l.add_theme_font_size_override("font_size",t[1]);l.add_theme_color_override("font_color",t[2]);v.add_child(l)
	spiel._btn(v,"MISSION STARTEN",func():spiel.panel_zu();spiel.mis.starten(m))
	spiel._btn(v,"Später",func():spiel.panel_zu())

func _process(_dt):
	# Nach jeder Mission Marker/Freischaltungen neu berechnen
	var n=spiel.mis.erledigt.size() if spiel and spiel.mis else 0
	if n!=_letzt:_letzt=n;aktualisieren()
var _letzt:=-1
