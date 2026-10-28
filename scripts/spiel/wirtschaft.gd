extends Node
# Immobilien (Wohnungen = Speicherpunkte, Garagen), Geschäfte mit Angestellten (Taxizentrale, Logistikzentrum, Club …)
# und Fahrzeug-Jobs (Polizei, Feuerwehr, Rettungsdienst, LKW, Bus). Daten: assets/data/missionen.json
const AUTO=preload("res://scripts/spiel/fahrzeug.gd")
const PE=preload("res://scripts/people.gd")
var spiel
var immobilien:=[]       # aus JSON + Position
var geschaefte:=[]
var besitz:={}           # id -> true
var personal:={}         # id -> {fahrer, lkw, stapler, mitarbeiter, upgrades:[]}
var garagen:={}          # id -> [ {kind, tuning} ]
var _tag:=-1
var kasse:={}            # id -> angesammelte Einnahmen
# Job
var job:=""
var job_stufe:={}        # job -> erreichte Stufe
var job_ziel=null
var job_ziel_auto=null
var job_feuer=null
var job_gast=null
var job_phase:=0
var job_zeit:=0.0
var job_marker:MeshInstance3D
var _stapler:=[]
const JOB_FZ={"polizei":"polizei","feuerwehr":"feuerwehr","feuerwehr_alt":"feuerwehr","rtw":"rettung","rtw_alt":"rettung","lkw":"lkw","lkw_blau":"lkw","bus":"bus"}
const JOB_NAME={"polizei":"POLIZEI","feuerwehr":"FEUER","rettung":"RETTUNG","lkw":"FRACHT","bus":"BUS"}

func setup():
	var d=spiel.mis.daten
	for e in d.get("immobilien",[]):
		var x=e.duplicate();x["p"]=spiel.mis.ort(e.ort,hash(e.id));immobilien.append(x)
		if int(e.preis)==0:besitz[e.id]=true
	for e in d.get("geschaefte",[]):
		var x=e.duplicate();x["p"]=spiel.mis.ort(e.ort,hash(e.id)+3);geschaefte.append(x)
	for x in immobilien:
		spiel.zonen.append({"typ":"immobilie","p":x.p,"r":2.2,"text":x.titel,"d":x})
		_schild(x.p,x.titel,Color(0.2,0.85,0.35))
	for x in geschaefte:
		spiel.zonen.append({"typ":"geschaeft","p":x.p,"r":2.2,"text":x.titel,"d":x})
		_schild(x.p,x.titel,Color(0.25,0.55,1.0))

func _schild(p:Vector3,t:String,c:Color):
	var m=MeshInstance3D.new();var cy=CylinderMesh.new();cy.top_radius=1.2;cy.bottom_radius=1.2;cy.height=1.2;cy.cap_top=false;cy.cap_bottom=false;m.mesh=cy
	var mt=StandardMaterial3D.new();mt.albedo_color=Color(c.r,c.g,c.b,0.28);mt.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mt.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mt.cull_mode=BaseMaterial3D.CULL_DISABLED
	m.material_override=mt;m.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;spiel.add_child(m);m.global_position=p+Vector3(0,0.6,0)
	var l=Label3D.new();l.text=t;l.font_size=48;l.pixel_size=0.01;l.billboard=BaseMaterial3D.BILLBOARD_ENABLED;l.modulate=c;l.outline_size=8;spiel.add_child(l);l.global_position=p+Vector3(0,2.6,0)
	l.visibility_range_end=60.0

# ---------------- Menüs ----------------
func immobilie_menue(x:Dictionary):
	var v=spiel._panel(x.titel.to_upper())
	var info=Label.new();v.add_child(info);info.autowrap_mode=TextServer.AUTOWRAP_WORD
	if besitz.has(x.id):
		info.text="Dein Besitz.  Garage: %d Stellplätze%s"%[int(x.garage),"   •  hier kannst du speichern" if x.speichern else ""]
		if x.speichern:spiel._btn(v,"SPEICHERN + AUSRUHEN",func():spiel.kampf.hp=100.0;spiel.speichern();spiel.hud.zeige("Gespeichert",2.0);spiel.panel_zu())
		var g:Array=garagen.get(x.id,[])
		for i in g.size():
			var e=g[i]
			spiel._btn(v,"Auto holen: "+str(e.kind),func():_auto_holen(x,i))
		if spiel.auto==null:
			var c=spiel._naechstes_auto(12.0)
			if c and g.size()<int(x.garage):spiel._btn(v,"Auto in die Garage stellen (%s)"%c.kind,func():_auto_einstellen(x,c))
	else:
		info.text="Preis: $%s\nGarage: %d Stellplätze%s\nDein Geld: $%s"%[_f(int(x.preis)),int(x.garage),"\nSpeicherpunkt" if x.speichern else "",_f(spiel.geld)]
		spiel._btn(v,"KAUFEN  $"+_f(int(x.preis)),func():
			if spiel._zahlen(int(x.preis)):besitz[x.id]=true;spiel.hud.zeige(x.titel+" gehört jetzt dir!",3.0);spiel.speichern();spiel.panel_zu())
	spiel._btn(v,"SCHLIESSEN",spiel.panel_zu)

func _auto_einstellen(x,c):
	var g:Array=garagen.get(x.id,[])
	g.append({"kind":c.kind,"tuning":c.visual.get_meta("tuning",{})});garagen[x.id]=g
	spiel.geparkt.erase(c);c.queue_free();spiel.hud.zeige("Auto eingestellt",1.5);spiel.panel_zu()

func _auto_holen(x,i):
	var g:Array=garagen.get(x.id,[])
	if i>=g.size():return
	var e=g[i];g.remove_at(i)
	var c=AUTO.new();spiel.add_child(c);c.setup(e.kind)
	if e.tuning is Dictionary and e.tuning.size()>0:spiel.TU.apply(c.visual,e.tuning)
	c.global_position=x.p+Vector3(3,0.6,0);spiel.geparkt.append(c)
	spiel.panel_zu();spiel.hud.zeige("Dein %s steht bereit"%e.kind,2.0)

func geschaeft_menue(x:Dictionary):
	var v=spiel._panel(x.titel.to_upper())
	var info=Label.new();v.add_child(info);info.autowrap_mode=TextServer.AUTOWRAP_WORD;info.custom_minimum_size=Vector2(460,0)
	var b:Dictionary=x.get("betrieb",{})
	if not besitz.has(x.id):
		info.text="Preis: $%s\n%s\nDein Geld: $%s"%[_f(int(x.preis)),_beschreibung(x),_f(spiel.geld)]
		spiel._btn(v,"KAUFEN  $"+_f(int(x.preis)),func():
			if spiel._zahlen(int(x.preis)):
				besitz[x.id]=true;personal[x.id]={"fahrer":0,"lkw":0,"stapler":0,"mitarbeiter":0,"upgrades":[]}
				spiel.hud.zeige(x.titel+" gehört jetzt dir! Stell Personal ein.",3.5);spiel.panel_zu();_betrieb_bauen()
			)
	else:
		var p:Dictionary=personal.get(x.id,{"fahrer":0,"lkw":0,"stapler":0,"mitarbeiter":0,"upgrades":[]})
		personal[x.id]=p
		info.text="%s\nKasse: $%s   (Einnahmen einmal pro Spieltag)"%[_bilanz(x),_f(int(kasse.get(x.id,0)))]
		if kasse.get(x.id,0)>0:
			spiel._btn(v,"KASSE LEEREN  +$"+_f(int(kasse[x.id])),func():spiel.geld+=int(kasse[x.id]);kasse[x.id]=0;spiel.hud.zeige("Einnahmen abgeholt",1.5);geschaeft_menue(x))
		if x.id=="taxizentrale":
			if p.fahrer<int(b.fahrer_max):spiel._btn(v,"Taxi + Fahrer einstellen  $"+_f(int(b.taxi_preis)),func():
				if spiel._zahlen(int(b.taxi_preis)):p.fahrer+=1;spiel.hud.zeige("Fahrer %d eingestellt"%p.fahrer,1.5);geschaeft_menue(x))
		elif x.id=="logistik":
			if p.mitarbeiter<int(b.mitarbeiter_max):spiel._btn(v,"Lagerarbeiter einstellen  $2.000",func():
				if spiel._zahlen(2000):p.mitarbeiter+=1;geschaeft_menue(x))
			if p.stapler<int(b.stapler_max):spiel._btn(v,"Gabelstapler + Fahrer  $9.000",func():
				if spiel._zahlen(9000):p.stapler+=1;_betrieb_bauen();geschaeft_menue(x))
			if p.lkw<int(b.lkw_max):spiel._btn(v,"LKW + Fahrer  $35.000",func():
				if spiel._zahlen(35000):p.lkw+=1;geschaeft_menue(x))
		for u in b.get("upgrades",[]):
			if not u in p.upgrades:
				spiel._btn(v,"Ausbau: %s  $15.000"%u,func():
					if spiel._zahlen(15000):p.upgrades.append(u);geschaeft_menue(x))
				break
	spiel._btn(v,"SCHLIESSEN",spiel.panel_zu)

func _beschreibung(x)->String:
	match x.id:
		"taxizentrale":return "Stell Fahrer ein – jedes Taxi bringt täglich Umsatz. Deine Taxis fahren in der Stadt."
		"logistik":return "Lager mit Rampe: Stapler laden Paletten, LKW liefern aus. Mehr Personal = mehr Aufträge."
	return "Bringt jeden Spieltag Einnahmen."

func _bilanz(x)->String:
	var p=personal.get(x.id,{})
	match x.id:
		"taxizentrale":return "Taxis/Fahrer: %d   Lohn je Fahrer/Tag: $150"%p.get("fahrer",0)
		"logistik":return "Lagerarbeiter %d  •  Stapler %d  •  LKW %d"%[p.get("mitarbeiter",0),p.get("stapler",0),p.get("lkw",0)]
	return "Betrieb läuft."

func _f(v:int)->String:return spiel.hud._fmt(v)

# Einnahmen einmal pro Spieltag (Mitternacht)
func schritt(dt:float):
	var stunde=int(spiel.zeit/60.0)
	if _tag==-1:_tag=stunde
	if stunde==0 and _tag!=0:_abrechnen()
	_tag=stunde
	_job(dt)
	for st in _stapler:_stapler_bewegen(st,dt)

func _abrechnen():
	var summe=0
	for x in geschaefte:
		if not besitz.has(x.id):continue
		var b=x.get("betrieb",{});var p=personal.get(x.id,{});var e=0
		var bonus=1.0+0.12*p.get("upgrades",[]).size()
		match x.id:
			"taxizentrale":e=int(p.get("fahrer",0)*(randi_range(250,450)-150)*bonus)
			"logistik":e=int((p.get("mitarbeiter",0)*90+p.get("stapler",0)*260+p.get("lkw",0)*700)*bonus)
			_:
				var u=b.get("umsatz_tag",[300,600]);e=int(randi_range(int(u[0]),int(u[1]))*bonus)
		kasse[x.id]=kasse.get(x.id,0)+e;summe+=e
	if summe>0:spiel.hud.zeige("Neuer Tag: deine Geschäfte haben $%s eingenommen (Kasse abholen!)"%_f(summe),5.0)

# Logistikzentrum: Stapler fahren zwischen Rampe und Regal hin und her
func _betrieb_bauen():
	if not besitz.has("logistik"):return
	var x=null
	for g in geschaefte:
		if g.id=="logistik":x=g
	if x==null:return
	var n=personal.get("logistik",{}).get("stapler",0)
	while _stapler.size()<max(n,1):
		var st=_stapler_bauen()
		var a=x.p+Vector3(8+_stapler.size()*4,0,6);var b=a+Vector3(0,0,28)
		spiel.add_child(st);st.global_position=a
		_stapler.append({"n":st,"a":a,"b":b,"t":randf()})

func _stapler_bauen()->Node3D:
	var root=Node3D.new()
	var gelb=StandardMaterial3D.new();gelb.albedo_color=Color(0.95,0.7,0.05);gelb.roughness=0.5
	var dunkel=StandardMaterial3D.new();dunkel.albedo_color=Color(0.08,0.08,0.09)
	var holz=StandardMaterial3D.new();holz.albedo_color=Color(0.6,0.45,0.28)
	var teile=[[Vector3(1.1,1.0,2.0),Vector3(0,0.75,0),gelb],[Vector3(1.0,1.3,0.08),Vector3(0,1.9,-0.3),dunkel],[Vector3(0.08,2.6,0.1),Vector3(-0.4,1.6,1.05),dunkel],[Vector3(0.08,2.6,0.1),Vector3(0.4,1.6,1.05),dunkel],
		[Vector3(0.12,0.06,1.1),Vector3(-0.3,0.35,1.6),dunkel],[Vector3(0.12,0.06,1.1),Vector3(0.3,0.35,1.6),dunkel],[Vector3(1.0,0.15,1.0),Vector3(0,0.45,1.6),holz],[Vector3(0.9,0.7,0.9),Vector3(0,0.9,1.6),holz]]
	for t in teile:
		var m=MeshInstance3D.new();var bx=BoxMesh.new();bx.size=t[0];m.mesh=bx;m.material_override=t[2];root.add_child(m);m.position=t[1]
	for p in [Vector3(-0.55,0.3,0.6),Vector3(0.55,0.3,0.6),Vector3(-0.55,0.3,-0.6),Vector3(0.55,0.3,-0.6)]:
		var r=MeshInstance3D.new();var cy=CylinderMesh.new();cy.top_radius=0.3;cy.bottom_radius=0.3;cy.height=0.25;r.mesh=cy;r.material_override=dunkel;root.add_child(r);r.position=p;r.rotation.z=PI*0.5
	return root

func _stapler_bewegen(s,dt):
	s.t+=dt*0.05
	var k=0.5-0.5*cos(s.t*TAU)
	var p=s.a.lerp(s.b,k)
	var h=spiel.kampf._boden(p) if Engine.get_process_frames()%30==0 else s.n.global_position.y
	s.n.global_position=Vector3(p.x,h,p.z)
	s.n.rotation.y=0.0 if sin(s.t*TAU)>0 else PI

# ---------------- Fahrzeug-Jobs ----------------
func job_typ()->String:
	if spiel.auto==null:return ""
	return JOB_FZ.get(spiel.auto.kind,"")

func job_umschalten():
	var t=job_typ()
	if job!="":
		spiel.hud.zeige("Job beendet",2.0);_job_ende();return
	if t=="":return
	job=t;job_phase=0
	spiel.hud.zeige({"polizei":"Polizeieinsatz: Stell die Flüchtigen!","feuerwehr":"Feuerwehr: Lösche die Brände!","rettung":"Rettungsdienst: Bring Verletzte ins Krankenhaus!","lkw":"Fracht: Liefere die Ladung aus!","bus":"Busfahrer: Fahr die Haltestellen an!"}[t],3.0)
	_job_neu()

func _job_ende():
	job="";spiel.hud.job_text="";spiel.mini.ziel=null
	if job_marker:job_marker.queue_free();job_marker=null
	if job_ziel_auto and is_instance_valid(job_ziel_auto) and job_ziel_auto!=spiel.auto:spiel.verkehr.erase(job_ziel_auto);job_ziel_auto.queue_free()
	job_ziel_auto=null
	if job_feuer and is_instance_valid(job_feuer):job_feuer.queue_free()
	job_feuer=null
	if job_gast and is_instance_valid(job_gast):job_gast.queue_free()
	job_gast=null

func _mark(p:Vector3,farbe:Color,r:=4.0):
	if job_marker:job_marker.queue_free()
	var m=MeshInstance3D.new();var cy=CylinderMesh.new();cy.top_radius=r;cy.bottom_radius=r;cy.height=1.5;cy.cap_top=false;cy.cap_bottom=false;m.mesh=cy
	var mt=StandardMaterial3D.new();mt.albedo_color=Color(farbe.r,farbe.g,farbe.b,0.3);mt.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mt.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mt.cull_mode=BaseMaterial3D.CULL_DISABLED
	m.material_override=mt;spiel.add_child(m);m.global_position=p+Vector3(0,0.75,0);job_marker=m
	spiel.mini.ziel=Vector2(p.x,p.z)

func _stufe()->int:return int(job_stufe.get(job,0))

func _job_neu():
	job_zeit=0.0;job_phase=0
	var me=spiel.auto.global_position
	match job:
		"polizei":
			var p=spiel._taxi_punkt(200.0,500.0)
			job_ziel_auto=spiel.mis._flucht_auto(p,16.0+_stufe()*1.2)
			spiel.hud.job_text="Stufe %d: Halte den Flüchtigen auf (rammen/schießen)"%(_stufe()+1)
		"feuerwehr":
			job_ziel=spiel._taxi_punkt(150.0,500.0)
			job_feuer=_feuer(job_ziel)
			_mark(job_ziel,Color(1,0.4,0.1),6.0)
			spiel.hud.job_text="Stufe %d: Brand löschen – fahr hin und halte an (Wasserwerfer)"%(_stufe()+1)
		"rettung":
			job_ziel=spiel._taxi_punkt(150.0,500.0)
			var r=RandomNumberGenerator.new();r.randomize()
			job_gast=PE.make(PE.CIVIL[r.randi()%PE.CIVIL.size()],r);spiel.add_child(job_gast);job_gast.global_position=job_ziel;job_gast.rotation.x=PI*0.5;job_gast.position.y+=0.15
			_mark(job_ziel,Color(1,1,1),4.0)
			spiel.hud.job_text="Stufe %d: Verletzten abholen"%(_stufe()+1)
		"lkw","bus":
			job_ziel=spiel._taxi_punkt(400.0,1300.0) if job=="lkw" else spiel._taxi_punkt(150.0,400.0)
			_mark(job_ziel,Color(0.3,0.7,1.0),6.0)
			spiel.hud.job_text=("Fracht ausliefern" if job=="lkw" else "Nächste Haltestelle")+"  (Stufe %d)"%(_stufe()+1)

func _feuer(p:Vector3)->Node3D:
	var root=Node3D.new();spiel.add_child(root);root.global_position=p
	var c=AUTO.new();root.add_child(c);c.setup(["small_car","mercedes","bmw_e30"][randi()%3]);c.freeze=true;c.position=Vector3(0,0.1,0)
	c._rauch_an();c.hp=60.0
	var g=Gradient.new();g.set_color(0,Color(1.0,0.55,0.1,0.95));g.set_color(1,Color(0.2,0.15,0.1,0.0));c._rauch.color_ramp=g;c._rauch.amount=40
	var l=OmniLight3D.new();l.light_color=Color(1,0.5,0.15);l.light_energy=4.0;l.omni_range=12.0;root.add_child(l);l.position=Vector3(0,2,0)
	root.set_meta("loesch",0.0)
	return root

func _job(dt:float):
	if job=="":return
	if spiel.auto==null or job_typ()!=job:
		if spiel.auto==null:return   # kurz ausgestiegen: Job läuft weiter
	job_zeit+=dt
	var me=spiel.auto.global_position if spiel.auto else spiel.spieler.global_position
	match job:
		"polizei":
			if not is_instance_valid(job_ziel_auto):_job_neu();return
			spiel.mini.ziel=Vector2(job_ziel_auto.global_position.x,job_ziel_auto.global_position.z)
			if job_ziel_auto.hp<=400.0 or job_ziel_auto.wrack or (me.distance_to(job_ziel_auto.global_position)<6.0 and job_ziel_auto.ki_speed<1.0):
				_job_lohn(400+_stufe()*150,"Flüchtiger gestellt!")
				spiel.verkehr.erase(job_ziel_auto);job_ziel_auto.queue_free();job_ziel_auto=null;_job_neu()
			elif me.distance_to(job_ziel_auto.global_position)>450.0:spiel.hud.zeige("Er ist entkommen",2.0);spiel.verkehr.erase(job_ziel_auto);job_ziel_auto.queue_free();job_ziel_auto=null;_job_neu()
		"feuerwehr":
			if spiel.auto and me.distance_to(job_ziel)<14.0 and spiel.auto.kmh()<6.0:   # Wasserwerfer läuft im Stand
				var l=job_feuer.get_meta("loesch")+dt;job_feuer.set_meta("loesch",l)
				spiel.hud.job_text="Löschen … %d %%"%int(l/4.0*100)
				if l>=4.0:
					_job_lohn(300+_stufe()*120,"Feuer gelöscht!");job_feuer.queue_free();job_feuer=null;_job_neu()
		"rettung":
			if job_phase==0 and me.distance_to(job_ziel)<6.0 and spiel.auto.kmh()<8.0:
				job_gast.queue_free();job_gast=null;job_phase=1
				job_ziel=spiel.mis.ort("altstadt",77);_mark(job_ziel,Color(1,0.2,0.2),5.0)
				spiel.hud.job_text="Ins Krankenhaus (Altstadt)! Zeit: 90 s";job_zeit=0.0
			elif job_phase==1:
				spiel.hud.job_text="Ins Krankenhaus: %d m   %d s"%[int(me.distance_to(job_ziel)),int(90-job_zeit)]
				if me.distance_to(job_ziel)<7.0 and spiel.auto.kmh()<8.0:_job_lohn(350+_stufe()*120,"Patient gerettet!");_job_neu()
				elif job_zeit>90.0:spiel.hud.zeige("Zu spät …",2.0);_job_neu()
		"lkw","bus":
			if me.distance_to(job_ziel)<8.0 and spiel.auto.kmh()<8.0:
				_job_lohn((600 if job=="lkw" else 120)+_stufe()*(100 if job=="lkw" else 25),"Abgeliefert!" if job=="lkw" else "Haltestelle erreicht");_job_neu()

func _job_lohn(b:int,txt:String):
	spiel.geld+=b
	job_stufe[job]=min(_stufe()+1,12)
	spiel.hud.zeige("%s  +$%d   (Stufe %d)"%[txt,b,_stufe()],3.0)
	if _stufe()==12:spiel.hud.zeige("Job gemeistert! Bonus freigeschaltet.",4.0)

# ---------------- Speichern ----------------
func daten()->Dictionary:
	return {"besitz":besitz.keys(),"personal":personal,"garagen":garagen,"kasse":kasse,"job_stufe":job_stufe}
func lade_daten(d:Dictionary):
	for k in d.get("besitz",[]):besitz[k]=true
	personal=d.get("personal",{});garagen=d.get("garagen",{});kasse=d.get("kasse",{});job_stufe=d.get("job_stufe",{})
	for k in personal:
		for f in ["fahrer","lkw","stapler","mitarbeiter"]:personal[k][f]=int(personal[k].get(f,0))
	_betrieb_bauen()
