extends Node
# Missionen aus assets/data/missionen.json. In dieser Version spielbar: alle Fahr-Missionen
# (Transport, Lieferung, Rennen, Diebstahl, Abschleppen, Flucht, Eskorte, Bergung). Kampf-Missionen folgen mit dem Waffensystem.
const AUTO=preload("res://scripts/spiel/fahrzeug.gd")
var spiel
var daten:={}
var aktiv=null            # laufende Mission
var schritt:=0
var ziel:=Vector3.ZERO
var zeit:=0.0
var limit:=0.0
var auto_m=null           # Missionsfahrzeug
var checkpoints:=[]
var marker:MeshInstance3D
var erledigt:={}
const SPIELBAR=["transport","lieferung","rennen","diebstahl","abschleppen","flucht","eskorte","bergung"]
const ORTE={"ghetto":Vector2(-250,620),"altstadt":Vector2(-150,120),"downtown":Vector2(250,-350),"hafen":Vector2(1400,340),"bahnhof":Vector2(600,120),
	"industrie":Vector2(900,560),"berg":Vector2(-1000,-620),"vorort":Vector2(760,-840),"ost":Vector2(960,-150),"flugplatz":Vector2(-960,520),
	"gueterbahnhof":Vector2(780,560),"autobahn":Vector2(-250,1185),"bahn":Vector2(450,990),"werkstatt":Vector2.ZERO}

func _ready():
	var f=FileAccess.open("res://assets/data/missionen.json",FileAccess.READ)
	if f:daten=JSON.parse_string(f.get_as_text())

func spielbare()->Array:
	var out=[]
	for m in daten.get("missionen",[]):
		if m.typ in SPIELBAR:out.append(m)
	return out

func kontakt_name(k:String)->String:
	var kk=daten.get("kontakte",{})
	if kk.has(k):return kk[k].name
	if k=="fremd":return "Fremde"
	if k=="lindenhof":return "Lindenhof-Crew"
	return k

# Ort -> befahrbarer Punkt am Straßenrand in der Nähe
func ort(key:String,salt:=0)->Vector3:
	var p:Vector2=ORTE.get(key,Vector2.ZERO)
	if key=="werkstatt":
		var w=spiel._shop("werkstatt");var fw=Vector2(sin(w.yaw),cos(w.yaw));p=w.c+fw*(w.d*0.5+8.0)
	var S=spiel.welt.S;var best=null;var bd=1e9
	var r2=RandomNumberGenerator.new();r2.seed=hash(key)+salt
	var off=Vector2(r2.randf_range(-60,60),r2.randf_range(-60,60)) if key!="werkstatt" else Vector2.ZERO
	for r in S.roads:
		if not r.typ in ["strasse","allee","gasse","land","piste","taxi"]:continue
		for i in range(0,r.P.size(),3):
			var d=r.P[i].distance_to(p+off)
			if d<bd:bd=d;best=[r,i]
	var r=best[0];var i=best[1];var t:Vector2=r.T[i];var nn=Vector2(-t.y,t.x)
	var q=r.P[i]-nn*(r.w*0.5)
	return Vector3(q.x,r.h[i]+0.3,q.y)

func starten(m:Dictionary):
	abbrechen(false)
	aktiv=m;schritt=0;zeit=0.0;limit=0.0
	spiel.hud.zeige(kontakt_name(m.kontakt)+": "+m.titel,4.0)
	if m.briefing!="":spiel.hud.zeige(m.briefing,6.0)
	_naechster()

func abbrechen(meldung:=true):
	if aktiv==null:return
	if meldung:spiel.hud.zeige("Mission abgebrochen",2.5)
	aktiv=null;spiel.hud.job_text="";spiel.mini.ziel=null
	if marker:marker.queue_free();marker=null
	for c in checkpoints:if is_instance_valid(c):c.queue_free()
	checkpoints.clear()

func _setze_ziel(p:Vector3,radius:=4.0,farbe:=Color(1,0.85,0.1)):
	ziel=p
	if marker:marker.queue_free()
	marker=MeshInstance3D.new();var cy=CylinderMesh.new();cy.top_radius=radius;cy.bottom_radius=radius;cy.height=2.0;cy.cap_top=false;cy.cap_bottom=false;marker.mesh=cy
	var mt=StandardMaterial3D.new();mt.albedo_color=Color(farbe.r,farbe.g,farbe.b,0.3);mt.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mt.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mt.cull_mode=BaseMaterial3D.CULL_DISABLED
	marker.material_override=mt;spiel.add_child(marker);marker.global_position=p+Vector3(0,1.0,0)
	spiel.mini.ziel=Vector2(p.x,p.z)

func _auto_hier(p:Vector3,kind:String):
	var c=AUTO.new();spiel.add_child(c);c.setup(kind)
	c.global_position=p+Vector3(0,0.6,0)
	spiel.geparkt.append(c);auto_m=c
	return c

func _naechster():
	var m=aktiv;var typ=m.typ
	var A=ort(m.start,1);var B=ort(m.ziel,2)
	match typ:
		"transport","eskorte","flucht":
			if schritt==0:_auto_hier(A,["mercedes","bmw_e30","audi_rs7","small_car"][hash(m.titel)%4]);_setze_ziel(A,3.0);spiel.hud.job_text="Hol das Fahrzeug ab"
			elif schritt==1:_setze_ziel(B,5.0);spiel.hud.job_text="Bring das Fahrzeug zum Ziel";limit=_zeit(A,B)*(1.6 if typ!="flucht" else 1.25)
			else:_fertig()
		"lieferung","bergung":
			if schritt==0:_setze_ziel(A,4.0);spiel.hud.job_text="Ware abholen (mit einem Auto)"
			elif schritt==1:_setze_ziel(B,5.0);spiel.hud.job_text="Liefern!";limit=_zeit(A,B)*1.35
			else:_fertig()
		"diebstahl","abschleppen":
			if schritt==0:_auto_hier(B,["porsche911","audi_r8","bmw_m8","jdm"][hash(m.titel)%4] if typ=="diebstahl" else "bmw_e30");_setze_ziel(B,3.0);spiel.hud.job_text="Finde den Wagen"
			elif schritt==1:_setze_ziel(A,5.0);spiel.hud.job_text="Bring ihn zu "+m.start.capitalize()
			else:_fertig()
		"rennen":
			if schritt==0:_setze_ziel(A,5.0);spiel.hud.job_text="Fahr zum Start"
			elif schritt==1:_rennstrecke(A,B)
			else:_fertig()

func _zeit(a:Vector3,b:Vector3)->float:return a.distance_to(b)/13.0+25.0

func _rennstrecke(A:Vector3,B:Vector3):
	# 8 Kontrollpunkte auf Straßen zwischen Start und Ziel (Zeitrennen)
	checkpoints.clear()
	var pts=[]
	for k in range(1,9):
		var p=A.lerp(B,k/8.0)+Vector3(randf_range(-150,150),0,randf_range(-150,150))*(0.0 if k==8 else 1.0)
		pts.append(p)
	aktiv["_cp"]=[]
	for p in pts:aktiv._cp.append(_strassenpunkt(p))
	limit=0.0
	var L=0.0;var last=A
	for p in aktiv._cp:L+=last.distance_to(p);last=p
	limit=L/17.0+20.0
	aktiv["_cpi"]=0;_setze_ziel(aktiv._cp[0],6.0,Color(0.2,0.7,1.0));spiel.hud.job_text="Rennen: Kontrollpunkt 1/8"

func _strassenpunkt(p:Vector3)->Vector3:
	var S=spiel.welt.S;var best=null;var bd=1e9
	for r in S.roads:
		if not r.typ in ["strasse","allee","autobahn","land"]:continue
		for i in range(0,r.P.size(),4):
			if r.tunnel_flags[i]:continue
			var d=r.P[i].distance_to(Vector2(p.x,p.z))
			if d<bd:bd=d;best=[r,i]
	return Vector3(best[0].P[best[1]].x,best[0].h[best[1]]+0.3,best[0].P[best[1]].y)

func _fertig():
	var m=aktiv
	spiel.geld+=int(m.belohnung) if int(m.belohnung)>0 else 500
	erledigt[str(m.id)]=true
	spiel.hud.zeige("MISSION ERFÜLLT!  +$"+str(int(m.belohnung) if int(m.belohnung)>0 else 500),5.0)
	abbrechen(false)
	spiel.speichern()

func _gescheitert(grund:String):
	spiel.hud.zeige("MISSION GESCHEITERT – "+grund,4.0)
	if auto_m and is_instance_valid(auto_m) and spiel.auto!=auto_m:pass
	abbrechen(false)

func _process(dt):
	if aktiv==null or not spiel.bereit:return
	var me=spiel.auto if spiel.auto!=null else spiel.spieler
	var p:Vector3=me.global_position
	if limit>0.0:
		zeit+=dt
		var rest=limit-zeit
		spiel.hud.job_text=spiel.hud.job_text.split("   ⏱")[0]+"   ⏱ %d s"%int(rest)
		if rest<=0:_gescheitert("Zeit abgelaufen");return
	if marker:marker.rotate_y(dt)
	var typ=aktiv.typ
	match typ:
		"transport","eskorte","flucht","diebstahl","abschleppen":
			if schritt==0 and spiel.auto!=null and spiel.auto==auto_m:schritt=1;_naechster()
			elif schritt==1 and spiel.auto==auto_m and p.distance_to(ziel)<7.0 and spiel.auto.kmh()<15.0:schritt=2;_naechster()
			elif schritt==1 and spiel.auto!=auto_m:spiel.hud.job_text="Steig wieder in das Missionsfahrzeug!"
		"lieferung","bergung":
			if schritt==0 and spiel.auto!=null and p.distance_to(ziel)<7.0 and spiel.auto.kmh()<12.0:
				schritt=1;spiel.hud.zeige("Ware geladen",2.0);_naechster()
			elif schritt==1 and spiel.auto!=null and p.distance_to(ziel)<7.0 and spiel.auto.kmh()<15.0:schritt=2;_naechster()
		"rennen":
			if schritt==0 and spiel.auto!=null and p.distance_to(ziel)<8.0:schritt=1;spiel.hud.zeige("3 … 2 … 1 … LOS!",2.5);_naechster()
			elif schritt==1 and spiel.auto!=null and p.distance_to(ziel)<10.0:
				aktiv._cpi+=1
				if aktiv._cpi>=aktiv._cp.size():schritt=2;_naechster()
				else:_setze_ziel(aktiv._cp[aktiv._cpi],6.0,Color(0.2,0.7,1.0));spiel.hud.job_text="Rennen: Kontrollpunkt %d/8"%(aktiv._cpi+1)
