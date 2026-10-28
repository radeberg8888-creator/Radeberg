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
const SPIELBAR=["transport","lieferung","rennen","diebstahl","abschleppen","flucht","eskorte","bergung",
	"gang","schiesserei","verteidigen","verfolgung","ueberfall","spionage","sniper"]
const KAMPF_TYPEN=["gang","schiesserei","verteidigen","verfolgung","ueberfall","spionage","sniper"]
var feinde:=[]            # Gegner dieser Mission
var freunde:=[]
var welle:=0
var wtimer:=0.0
var ziel_auto=null        # Verfolgungs-/Beschattungsziel
var _nah_t:=0.0
const ORTE={"ghetto":Vector2(-250,620),"altstadt":Vector2(-150,120),"downtown":Vector2(250,-350),"hafen":Vector2(1560,700),"bahnhof":Vector2(600,120),
	"industrie":Vector2(900,560),"berg":Vector2(-800,-8250),"vorort":Vector2(760,-840),"ost":Vector2(960,-150),"flugplatz":Vector2(-1900,1640),
	"gueterbahnhof":Vector2(780,560),"autobahn":Vector2(-250,1185),"bahn":Vector2(450,990),"werkstatt":Vector2.ZERO,
	"kowloon":Vector2(-2050,-1000),"lindstadt":Vector2(1080,-520),"staubwinkel":Vector2(1750,-5900),"canyon":Vector2(-250,-5420),"espenwald":Vector2(-1300,-6350),
	"nordbucht":Vector2(-2200,-8700),"sonnenhuegel":Vector2(-150,-1500),"strand":Vector2(-2150,-100),"farm":Vector2(1950,-7800),"see":Vector2(550,-5850),"stern":Vector2(1080,-520),"oststadt":Vector2(2700,600),"suedstadt":Vector2(250,1580),"docks":Vector2(500,2050),"militaer":Vector2(-1750,-5250),"stausee":Vector2(-1000,-2550),"wueste":Vector2(600,-5500),"weststadt":Vector2(-850,-450),"nordstadt":Vector2(-400,-1000),"sandufer":Vector2(900,-5850),"kornfeld":Vector2(1700,-7550),"fischerdorf":Vector2(-830,-6680),"flughafen":Vector2(-1900,1640),"kleinseoul":Vector2(-1250,850),"hafenviertel":Vector2(1600,1300),"gefaengnis":Vector2(1650,-5050)}

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
	aktiv["kampf"]=m.typ in KAMPF_TYPEN
	if aktiv.kampf:
		var k=spiel.kampf
		var hat_waffe=false
		for id in k.waffen:
			if k.WD.daten(id).typ!="nah":hat_waffe=true
		if not hat_waffe:k.gib_waffe("pistole",4);spiel.hud.zeige(kontakt_name(m.kontakt)+" gibt dir eine Pistole.",3.0)
		if m.typ=="sniper" and not (k.waffen.has("jagdgewehr") or k.waffen.has("m14") or k.waffen.has("mauser")):k.gib_waffe("jagdgewehr",2)
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
	for g in feinde+freunde:
		if is_instance_valid(g):g.mission=false
	feinde.clear();freunde.clear();welle=0
	if ziel_auto and is_instance_valid(ziel_auto) and ziel_auto!=spiel.auto:
		spiel.verkehr.erase(ziel_auto);ziel_auto.queue_free()
	ziel_auto=null

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
		"gang","schiesserei":
			if schritt==0:_setze_ziel(B,14.0,Color(1,0.2,0.15));spiel.hud.job_text="Fahr zum Revier der "+_gang_name(m)
			elif schritt==1:
				_marker_weg();welle=1
				_welle(B,4+_stufe(m),m)
			else:_fertig()
		"verteidigen":
			if schritt==0:_setze_ziel(A,10.0,Color(0.2,1,0.3));spiel.hud.job_text="Fahr zu deinen Leuten"
			elif schritt==1:
				_marker_weg();limit=75.0+_stufe(m)*5;wtimer=3.0;welle=0
				for i in 3:freunde.append(spiel.kampf.spawn(_um(A,4.0),"lindenhof",["pistole","mp5","ak47"][i],{"verbuendet":true,"mission":true,"alarm":true}))
				spiel.hud.job_text="Halte die Stellung!"
			else:_fertig()
		"verfolgung":
			if schritt==0:
				ziel_auto=_flucht_auto(A,22.0);spiel.mini.ziel=null
				spiel.hud.job_text="Halte das rote Auto auf – schieß oder ramm es!"
				limit=150.0
			elif schritt==1:
				var fahrer=spiel.kampf.spawn(ziel_auto.global_position+ziel_auto.global_transform.basis.x*2.2+Vector3(0,0.3,0),m.gang if m.gang!="" else "ost","pistole",{"mission":true,"alarm":true})
				feinde=[fahrer];spiel.hud.job_text="Der Fahrer flieht – schalte ihn aus!";limit=0.0
			else:_fertig()
		"ueberfall":
			if schritt==0:_setze_ziel(B,8.0,Color(1,0.2,0.15));spiel.hud.job_text="Fahr zum Überfallziel"
			elif schritt==1:
				_setze_ziel(B,10.0,Color(1,0.2,0.15));zeit=0.0;limit=0.0;wtimer=25.0
				_welle(B,3+_stufe(m),m,"wache")
				spiel.hud.job_text="Halte dich 25 s im Bereich auf"
			elif schritt==2:
				spiel.kampf.verbrechen(2.0);_setze_ziel(A,6.0);spiel.hud.job_text="Hau ab! Zurück zum Versteck";limit=_zeit(B,A)*1.8
			else:_fertig()
		"spionage":
			if schritt==0:_setze_ziel(A,6.0);spiel.hud.job_text="Fahr zum Treffpunkt"
			elif schritt==1:
				_marker_weg();ziel_auto=_flucht_auto(A+Vector3(25,0,0),12.0);wtimer=90.0
				spiel.hud.job_text="Beschatte das Auto (Abstand 15–110 m)"
			else:_fertig()
		"sniper":
			var V=B+Vector3(70,0,40)
			V=_strassenpunkt(V)
			if schritt==0:_setze_ziel(V,4.0,Color(0.3,0.7,1));spiel.hud.job_text="Geh in Schussposition"
			elif schritt==1:
				_marker_weg()
				for i in 3:feinde.append(spiel.kampf.spawn(_um(B,6.0),m.gang if m.gang!="" else "ost",["pistole","mp5","pistole"][i],{"mission":true,"stationaer":true}))
				spiel.hud.job_text="Schalte die 3 Ziele aus (Scharfschützengewehr: ZIELEN)"
			else:_fertig()
		"rennen":
			if schritt==0:_setze_ziel(A,5.0);spiel.hud.job_text="Fahr zum Start"
			elif schritt==1:_rennstrecke(A,B)
			else:_fertig()

func _stufe(m)->int:return clamp(int(m.get("id",1))/12,0,6)
func _gang_name(m)->String:return daten.get("gangs",{}).get(m.gang,"Gang") if m.gang!="" else "Gang"
func _marker_weg():
	if marker:marker.queue_free();marker=null
	spiel.mini.ziel=null
func _um(p:Vector3,r:float)->Vector3:
	var a=randf()*TAU;var q=p+Vector3(cos(a),0,sin(a))*randf_range(r*0.4,r)
	q.y=spiel.kampf._boden(q);return q
func _welle(mitte:Vector3,n:int,m,fraktion:=""):
	var fr=fraktion if fraktion!="" else (m.gang if m.gang!="" and m.gang!="lindenhof" else "kobras")
	var waffen=["pistole","mp5","pistole","ak47","mossberg","machete"]
	if _stufe(m)>=3:waffen=["mp5","ak47","ar15","mossberg","pistole"]
	for i in n:
		var g=spiel.kampf.spawn(_um(mitte,14.0),fr,waffen[i%waffen.size()],{"mission":true,"alarm":welle>1})
		feinde.append(g)
func _flucht_auto(p:Vector3,v:float):
	var S=spiel.welt.S;var best=null;var bd=1e9
	for r in S.roads:
		if not r.typ in ["strasse","allee","land","autobahn"]:continue
		for i in range(0,r.P.size(),3):
			var d=r.P[i].distance_to(Vector2(p.x,p.z))
			if d<bd and not r.tunnel_flags[i]:bd=d;best=[r,i]
	var c=AUTO.new();spiel.add_child(c);c.setup(["bmw_m8","audi_rs7","mercedes","porsche911"][randi()%4])
	c.als_ki(best[0],best[1]*S.DS,1,c._lane(best[0]),S)
	c.ki_ziel=v;c.ki_speed=v*0.5;c.zaeh=true
	var mt=StandardMaterial3D.new();mt.albedo_color=Color(1,0.1,0.1,0.25);mt.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mt.emission_enabled=true;mt.emission=Color(1,0,0);mt.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var mk=MeshInstance3D.new();var cy=CylinderMesh.new();cy.top_radius=0.0;cy.bottom_radius=0.6;cy.height=1.0;mk.mesh=cy;mk.material_override=mt;c.add_child(mk);mk.position=Vector3(0,c.ab.end.y+1.2,0);mk.rotation.x=PI
	spiel.verkehr.append(c)
	return c

func tag_gesprueht():
	if aktiv==null or aktiv.typ!="graffiti":return
	aktiv["_tags"]=aktiv.get("_tags",0)+1
	spiel.hud.job_text="Graffiti: %d / %d"%[aktiv._tags,aktiv.get("anzahl",5)]
	if aktiv._tags>=aktiv.get("anzahl",5):schritt=1;_fertig()

func gegner_tot(g):
	if aktiv==null:return
	if g in feinde:
		var rest=feinde.filter(func(x):return is_instance_valid(x) and not x.tot).size()
		if rest>0:spiel.hud.job_text="Gegner übrig: %d"%rest

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
	if m.get("kampf",false):spiel.kampf.sterne=min(spiel.kampf.sterne,1.0) if m.typ!="ueberfall" else spiel.kampf.sterne
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
		"gang","schiesserei":
			if schritt==0 and p.distance_to(ziel)<40.0:schritt=1;_naechster()
			elif schritt==1:
				var rest=feinde.filter(func(x):return is_instance_valid(x) and not x.tot).size()
				if rest==0:
					if typ=="schiesserei" and welle==1:
						welle=2;spiel.hud.zeige("Verstärkung kommt!",2.5)
						var B=ort(aktiv.ziel,2);_welle(B+Vector3(30,0,-25),5+_stufe(aktiv),aktiv)
					else:schritt=2;_naechster()
		"verteidigen":
			if schritt==0 and p.distance_to(ziel)<14.0:schritt=1;_naechster()
			elif schritt==1:
				wtimer-=dt
				if wtimer<=0.0:
					wtimer=22.0;welle+=1
					var A=ort(aktiv.start,1);var a=randf()*TAU
					_welle(A+Vector3(cos(a),0,sin(a))*40.0,3+welle,aktiv)
					for g in feinde:
						if is_instance_valid(g):g.alarm=true
					spiel.hud.zeige("Angriff! Welle %d"%welle,2.0)
				if limit>0.0 and zeit>=limit-0.5:schritt=2;limit=0.0;_naechster()
		"verfolgung":
			if not is_instance_valid(ziel_auto):_gescheitert("Ziel verloren");return
			spiel.mini.ziel=Vector2(ziel_auto.global_position.x,ziel_auto.global_position.z)
			if schritt==0:
				if ziel_auto.hp<=350.0 or ziel_auto.wrack:
					ziel_auto.ki_ziel=0.0;ziel_auto.ki_speed=0.0;schritt=1;_naechster()
				elif p.distance_to(ziel_auto.global_position)>400.0:_gescheitert("Ziel entkommen")
			elif schritt==1:
				if feinde.filter(func(x):return is_instance_valid(x) and not x.tot).is_empty():schritt=2;_naechster()
		"ueberfall":
			if schritt==0 and p.distance_to(ziel)<12.0:schritt=1;_naechster()
			elif schritt==1:
				if p.distance_to(ziel)<16.0:
					wtimer-=dt;spiel.hud.job_text="Beute einsammeln: %d s"%int(wtimer)
					if wtimer<=0.0:schritt=2;_naechster()
				else:spiel.hud.job_text="Zurück in den Bereich!"
			elif schritt==2 and p.distance_to(ziel)<8.0:schritt=3;_naechster()
		"spionage":
			if schritt==0 and p.distance_to(ziel)<10.0:schritt=1;_naechster()
			elif schritt==1:
				if not is_instance_valid(ziel_auto):_gescheitert("Ziel verloren");return
				var d=p.distance_to(ziel_auto.global_position)
				spiel.mini.ziel=Vector2(ziel_auto.global_position.x,ziel_auto.global_position.z)
				wtimer-=dt
				spiel.hud.job_text="Beschatten: %d s   Abstand %d m"%[int(wtimer),int(d)]
				if d<15.0:
					_nah_t+=dt
					if _nah_t>3.0:_gescheitert("Du wurdest entdeckt");return
				else:_nah_t=0.0
				if d>130.0:_gescheitert("Ziel aus den Augen verloren");return
				if wtimer<=0.0:schritt=2;_naechster()
		"sniper":
			if schritt==0 and p.distance_to(ziel)<5.0:schritt=1;_naechster()
			elif schritt==1:
				var rest=feinde.filter(func(x):return is_instance_valid(x) and not x.tot).size()
				if rest==0:schritt=2;_naechster()
				else:spiel.hud.job_text="Ziele übrig: %d"%rest
		"rennen":
			if schritt==0 and spiel.auto!=null and p.distance_to(ziel)<8.0:schritt=1;spiel.hud.zeige("3 … 2 … 1 … LOS!",2.5);_naechster()
			elif schritt==1 and spiel.auto!=null and p.distance_to(ziel)<10.0:
				aktiv._cpi+=1
				if aktiv._cpi>=aktiv._cp.size():schritt=2;_naechster()
				else:_setze_ziel(aktiv._cp[aktiv._cpi],6.0,Color(0.2,0.7,1.0));spiel.hud.job_text="Rennen: Kontrollpunkt %d/8"%(aktiv._cpi+1)
