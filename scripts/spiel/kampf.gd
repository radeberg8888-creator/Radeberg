extends Node
# Kampfsystem: Waffen des Spielers (Inventar, Zielen, Schießen, Nachladen, Nahkampf), Trefferberechnung,
# Effekte (Mündungsfeuer, Leuchtspur, Einschläge, Blut, Einschusslöcher), Schussgeräusche,
# Gesundheit/Rüstung, Fahndungsstufe mit Polizei, Krankenhaus, Gegner-Verwaltung.
const WD=preload("res://scripts/spiel/waffen_daten.gd")
const HALTER=preload("res://scripts/spiel/waffen_halter.gd")
const GEGNER=preload("res://scripts/spiel/gegner.gd")
var spiel
# --- Spieler ---
var hp:=100.0
var ruestung:=0.0
var waffen:={"faust":0}       # id -> Reservemunition
var magazin:={}               # id -> Schuss im Magazin
var aktuell:="faust"
var halter
var _cool:=0.0
var _laden:=0.0
var _schlag:=0.0
var zielt:=false
var _zielen_alt:=false
# --- Welt ---
var gegner:=[]
var sterne:=0.0               # Fahndungsstufe 0..5
var _ohne_sicht:=0.0
var _pol_spawn:=0.0
var tot:=false
# --- Effekte ---
var _sounds:={}
var _spieler_audio:=[]
var _decals:=[];var _decal_i:=0
var _tex_loch:Texture2D
var _funken:=[];var _funken_i:=0
var _blut:=[];var _blut_i:=0
var _blitz:MeshInstance3D;var _blitz_licht:OmniLight3D;var _blitz_t:=0.0
var _spuren:=[]
var treffer_marke:=0.0
var schaden_blitz:=0.0
const MASKE:=1|2|4|8|16

func _ready():
	add_to_group("kampf")
	_effekte_bauen()

# Explosion (Auto): Lichtblitz, Feuerball, Schaden im Umkreis, Kettenreaktion
func explosion(p:Vector3,quelle=null):
	_ton("sniper",p,1.0);_ton("schrot",p,1.0)
	var l=OmniLight3D.new();l.light_color=Color(1,0.6,0.2);l.light_energy=12.0;l.omni_range=18.0;add_child(l);l.global_position=p+Vector3(0,1,0)
	var fb=_partikel(Color(1.0,0.7,0.2),Color(0.2,0.15,0.1),40,0.9)
	fb.global_position=p;fb.direction=Vector3.UP;fb.spread=180.0;fb.initial_velocity_min=3.0;fb.initial_velocity_max=9.0;fb.scale_amount_min=0.4;fb.scale_amount_max=1.2;fb.gravity=Vector3(0,2,0)
	fb.restart();fb.emitting=true
	var tw=create_tween();tw.tween_property(l,"light_energy",0.0,0.8);tw.tween_callback(l.queue_free);tw.tween_interval(2.0);tw.tween_callback(fb.queue_free)
	var sp=spiel.spieler
	if spiel.auto==null and sp.global_position.distance_to(p)<7.0:spieler_treffer(90.0*(1.0-sp.global_position.distance_to(p)/7.0)+10.0)
	elif spiel.auto!=null and spiel.auto!=quelle and spiel.auto.global_position.distance_to(p)<6.0:spiel.auto.treffer(500.0,quelle,p)
	elif spiel.auto==quelle:spieler_treffer(70.0)
	for g in gegner:
		if is_instance_valid(g) and not g.tot and g.global_position.distance_to(p)<7.0:g.treffer(150.0,quelle,g.global_position+Vector3(0,1,0))
	for c in spiel.verkehr+spiel.geparkt:
		if is_instance_valid(c) and c!=quelle and c.global_position.distance_to(p)<6.0:c.treffer(450.0,quelle,p)
	spiel.kam.rueckstoss(4.0)

func setup_spieler():
	halter=HALTER.new();add_child(halter);halter.setup(spiel.spieler.figur)
	halter.setze_waffe(aktuell)

# ---------------- Inventar ----------------
func gib_waffe(id:String,magazine:=3):
	var d=WD.daten(id)
	if not waffen.has(id):waffen[id]=0
	if d.typ!="nah":
		waffen[id]+=int(d.get("magazin",10))*magazine
		if not magazin.has(id):magazin[id]=int(d.magazin);waffen[id]-=int(d.magazin)
	waehle(id)

func waehle(id:String):
	if not waffen.has(id):return
	aktuell=id;_laden=0.0
	if halter:halter.setze_waffe(id)
	if spiel and spiel.hud:spiel.hud.zeige(WD.daten(id).name,1.2)

func weiter(schritt:=1):
	var liste=WD.REIHE.filter(func(i):return waffen.has(i))
	var i=liste.find(aktuell)
	waehle(liste[(i+schritt+liste.size())%liste.size()])

func munition_text()->String:
	var d=WD.daten(aktuell)
	if d.typ=="nah":return d.name
	if _laden>0.0:return d.name+"  lädt …"
	return "%s  %d / %d"%[d.name,magazin.get(aktuell,0),waffen.get(aktuell,0)]

func nachladen():
	var d=WD.daten(aktuell)
	if d.typ=="nah" or _laden>0.0:return
	if magazin.get(aktuell,0)>=int(d.magazin) or waffen.get(aktuell,0)<=0:return
	_laden=float(d.nachladen)
	_ton("laden",spiel.spieler.global_position,0.6)

func _laden_fertig():
	var d=WD.daten(aktuell)
	var fehlt=int(d.magazin)-magazin.get(aktuell,0)
	var n=min(fehlt,waffen.get(aktuell,0))
	magazin[aktuell]=magazin.get(aktuell,0)+n;waffen[aktuell]-=n

# ---------------- Spieler pro Bild ----------------
func spieler_schritt(dt:float):
	if tot or halter==null:return
	var st=spiel.st
	var sp=spiel.spieler
	if st.pressed("waffe"):weiter(1)
	if st.pressed("waffe_zurueck"):weiter(-1)
	if st.pressed("nachladen"):nachladen()
	if _laden>0.0:
		_laden-=dt
		if _laden<=0.0:_laden=0.0;_laden_fertig()
	_cool=max(0.0,_cool-dt)
	var d=WD.daten(aktuell)
	zielt=(st.zielen or st.feuer) and d.typ!="nah" and d.typ!="spray"
	if zielt!=_zielen_alt:
		_zielen_alt=zielt;spiel.kam.zielen=zielt
	spiel.kam.scope=zielt and d.typ=="sniper" and st.zielen
	# Zielrichtung aus der Kamera (Fadenkreuz) + Zielhilfe
	var cam:Camera3D=spiel.kam.cam
	var von=cam.global_position;var fw=-cam.global_transform.basis.z
	var reich=float(d.get("reichweite",100))
	var hit=_ray(von+fw*1.0,von+fw*reich,[sp])
	var punkt:Vector3=hit.position if hit else von+fw*reich
	var hilfe=_zielhilfe(von,fw,reich)
	if hilfe!=null:punkt=hilfe
	halter.zielen=zielt
	halter.ziel_richtung=(punkt-halter.muendung()).normalized() if zielt else sp.figur.global_transform.basis.z
	if zielt:
		var yaw=atan2(fw.x,fw.z)
		sp.figur.rotation.y=lerp_angle(sp.figur.rotation.y,yaw,clamp(dt*18.0,0.0,1.0))
		sp.blick_fest=true
	else:sp.blick_fest=false
	halter.aktualisieren(dt)
	# Sprühen (Graffiti)
	if d.typ=="spray":
		_spray_schritt(dt,st.feuer,von,fw)
		return
	# Schießen / Schlagen
	if d.typ=="nah":
		if _schlag>0.0:
			_schlag+=dt*float(d.rate)*1.6
			halter.schwung=clamp(_schlag,0.0,1.0)
			if _schlag>=0.45 and _schlag-dt*float(d.rate)*1.6<0.45:_nahkampf_treffer(sp,d)
			if _schlag>=1.0:_schlag=0.0;halter.schwung=0.0
		elif st.feuer:
			_schlag=0.01
		return
	if st.feuer and _cool<=0.0 and _laden<=0.0:
		if magazin.get(aktuell,0)<=0:
			if waffen.get(aktuell,0)>0:nachladen()
			else:spiel.hud.zeige("Keine Munition!",1.0);_cool=0.4
			return
		magazin[aktuell]-=1
		_cool=1.0/float(d.rate)
		var mz=halter.muendung()
		var dir=(punkt-mz).normalized()
		schuss(sp,mz,dir,aktuell,[sp],true)
		halter.rueckstoss=1.0
		spiel.kam.rueckstoss(0.6 if d.typ in ["pistole","mp"] else 1.2)
		if d.typ=="sniper" or d.typ=="schrot":_cool=1.0/float(d.rate)
		# Schüsse in der Stadt: Fahndung, wenn Zeugen in der Nähe
		if spiel.mis==null or spiel.mis.aktiv==null or not spiel.mis.aktiv.get("kampf",false):
			if _zeugen(sp.global_position)>0:verbrechen(0.15)

# ---------------- Graffiti ----------------
var _tags:=[]
var _spray_dc:Decal=null
var _spray_t:=0.0
var _spray_pos:=Vector3.ZERO
var tags_gesprueht:=0
var tag_daten:=[]   # gespeicherte eigene Tags [x,y,z,nx,ny,nz,nr]
func _tag_tex(i:int)->Texture2D:
	return load("res://assets/textures/graffiti/tag_%02d.png"%(i%16))
static func tag_basis(n:Vector3)->Basis:
	n=n.normalized()
	var x=Vector3.UP.cross(n) if abs(n.y)<0.9 else Vector3.RIGHT
	x=x.normalized();var z=x.cross(n).normalized()
	return Basis(x,n,z)
func _spray_schritt(dt:float,an:bool,von:Vector3,fw:Vector3):
	if not an:
		if _spray_dc and _spray_t<1.0:_spray_dc.queue_free();_spray_dc=null
		_spray_t=0.0;return
	var h=_ray(von+fw*1.0,von+fw*7.0,[spiel.spieler])
	if h==null or h.collider.has_method("ist_mensch"):return
	if _spray_dc==null or h.position.distance_to(_spray_pos)>1.2:
		if _spray_dc:_spray_dc.queue_free()
		_spray_dc=Decal.new();add_child(_spray_dc);_spray_t=0.0;_spray_pos=h.position
		var nr=randi()%16;_spray_dc.set_meta("nr",nr)
		_spray_dc.texture_albedo=_tag_tex(nr);_spray_dc.size=Vector3(3.2,0.8,1.6)
		_spray_dc.global_transform=Transform3D(tag_basis(h.normal),h.position)
	_spray_t+=dt/1.6
	_spray_dc.modulate=Color(1,1,1,clamp(_spray_t,0.05,1.0))
	if int(_spray_t*10)%3==0:_ton("schlag",h.position,0.15)
	if _spray_t>=1.0 and not _spray_dc.has_meta("fertig"):
		_spray_dc.set_meta("fertig",true);tags_gesprueht+=1
		var p=_spray_dc.global_position;var n=h.normal
		tag_daten.append([p.x,p.y,p.z,n.x,n.y,n.z,_spray_dc.get_meta("nr")])
		_tags.append(_spray_dc);_spray_dc=null;_spray_t=0.0
		spiel.hud.zeige("Graffiti gesprüht! (%d)"%tags_gesprueht,1.5)
		if spiel.mis:spiel.mis.tag_gesprueht()
func tags_wiederherstellen():
	for t in tag_daten:
		var dc=Decal.new();add_child(dc);dc.texture_albedo=_tag_tex(int(t[6]));dc.size=Vector3(3.2,0.8,1.6)
		dc.global_transform=Transform3D(tag_basis(Vector3(t[3],t[4],t[5])),Vector3(t[0],t[1],t[2]));_tags.append(dc)

func _zielhilfe(von:Vector3,fw:Vector3,reich:float):
	var best=null;var bw=deg_to_rad(7.0 if not spiel.st.controller else 5.0)
	for g in gegner:
		if not is_instance_valid(g) or g.tot:continue
		var p=g.global_position+Vector3(0,1.25,0)
		var v=p-von;var dist=v.length()
		if dist>reich or dist<1.5:continue
		var w=fw.angle_to(v)
		if w<bw:
			var h=_ray(von+fw*1.0,p,[spiel.spieler])
			if h and h.collider==g:bw=w;best=p
	return best

func _zeugen(p:Vector3)->int:
	var n=0
	for e in spiel.passanten:
		if e.n.visible and e.n.global_position.distance_to(p)<45.0:n+=1
	return n

# ---------------- Schuss / Treffer ----------------
func _ray(a:Vector3,b:Vector3,aus:Array=[]):
	var space=spiel.get_world_3d().direct_space_state
	var q=PhysicsRayQueryParameters3D.create(a,b,MASKE)
	var rids=[]
	for e in aus:
		if e is CollisionObject3D:rids.append(e.get_rid())
	q.exclude=rids;q.collide_with_areas=false
	var r=space.intersect_ray(q)
	return r if r.size()>0 else null

# schuetze: Node (Spieler oder Gegner); spieler_schuss: zählt für Fahndung/Missionen
func schuss(schuetze,mz:Vector3,dir:Vector3,id:String,aus:Array,spieler_schuss:=false,treff_chance:=1.0):
	var d=WD.daten(id)
	var kugeln=int(d.get("kugeln",1))
	var streu=deg_to_rad(float(d.get("streuung",1.0)))
	if spieler_schuss and zielt and spiel.spieler.velocity.length()<0.5:streu*=0.6
	_ton(d.typ,mz,1.0 if spieler_schuss else 0.8)
	_muendungsfeuer(mz,dir)
	for k in kugeln:
		var rd=dir
		var s=streu*(1.0 if kugeln==1 else 1.0)
		rd=(rd+Vector3(randf_range(-s,s),randf_range(-s,s),randf_range(-s,s))).normalized()
		var ende=mz+rd*float(d.get("reichweite",100))
		var h=_ray(mz,ende,aus)
		var p:Vector3=h.position if h else ende
		if k<2:_spur(mz,p)
		if h:
			var c=h.collider
			var dmg=float(d.schaden)
			if c.has_method("treffer"):
				if treff_chance<1.0 and randf()>treff_chance:
					_einschlag(p+rd*0.4,h.normal,false);continue
				var mensch=c.has_method("ist_mensch") and c.ist_mensch()
				if mensch:_blutfx(p,-rd)
				else:_einschlag(p,h.normal,false)
				c.treffer(dmg,schuetze,p)
				if spieler_schuss and mensch:treffer_marke=0.25
			else:
				_einschlag(p,h.normal,true)

func _nahkampf_treffer(sp,d):
	var fw=sp.figur.global_transform.basis.z
	var p=sp.global_position+Vector3(0,1.1,0)
	_ton("schlag",p,0.7)
	for g in gegner:
		if not is_instance_valid(g) or g.tot:continue
		var v=g.global_position+Vector3(0,1.1,0)-p
		if v.length()<float(d.reichweite)+0.4 and fw.angle_to(v)<0.9:
			g.treffer(float(d.schaden),sp,g.global_position+Vector3(0,1.3,0));_blutfx(g.global_position+Vector3(0,1.3,0),fw)
	for e in spiel.passanten:
		var n=e.n
		if n.visible and n.global_position.distance_to(sp.global_position)<float(d.reichweite)+0.5:
			spiel.passant_treffer(e,sp);verbrechen(0.3)

# Spieler wird getroffen
func spieler_treffer(dmg:float,von=null):
	if tot:return
	if spiel.admin and spiel.admin_gott:return
	if ruestung>0.0:
		var a=min(ruestung,dmg*0.7);ruestung-=a;dmg-=a
	hp-=dmg;schaden_blitz=0.45
	if spiel.st.e.vibration:Input.vibrate_handheld(60)
	if hp<=0.0:_spieler_tot()

func _spieler_tot():
	tot=true;hp=0.0
	spiel.hud.zeige("AUSGESCHALTET",4.0)
	if spiel.mis:spiel.mis.abbrechen(false)
	var t=get_tree().create_timer(3.5)
	t.timeout.connect(_krankenhaus)

func _krankenhaus():
	var verlust=min(int(spiel.geld*0.1),2500)
	spiel.geld-=verlust
	var p=spiel.mis.ort("altstadt",77) if spiel.mis else spiel.spieler.global_position
	if spiel.auto!=null:spiel.aussteigen_sofort()
	spiel.spieler.global_position=p+Vector3(0,0.5,0);spiel.spieler.velocity=Vector3.ZERO
	hp=100.0;tot=false;sterne=0.0
	for g in gegner:
		if is_instance_valid(g) and g.fraktion=="polizei":g.queue_free()
	spiel.hud.zeige("Krankenhaus: Behandlung kostete $"+str(verlust),4.0)

# ---------------- Fahndung ----------------
func verbrechen(stufe:float):
	var alt=int(sterne)
	sterne=clamp(sterne+stufe,0.0,5.0);_ohne_sicht=0.0
	if int(sterne)>alt and int(sterne)>0:spiel.hud.zeige("Fahndungsstufe %d"%int(sterne),2.0)

func welt_schritt(dt:float):
	schaden_blitz=max(0.0,schaden_blitz-dt);treffer_marke=max(0.0,treffer_marke-dt)
	_blitz_t-=dt
	if _blitz_t<=0.0 and _blitz.visible:_blitz.visible=false;_blitz_licht.visible=false
	for sp in _spuren.duplicate():
		sp.t-=dt
		if sp.t<=0.0:sp.n.queue_free();_spuren.erase(sp)
		else:sp.n.transparency=1.0-sp.t/0.07
	# Gegner aufräumen
	var me=spiel.auto if spiel.auto!=null else spiel.spieler
	for g in gegner.duplicate():
		if not is_instance_valid(g):gegner.erase(g);continue
		if g.tot and g.tot_zeit>25.0:gegner.erase(g);g.queue_free()
		elif g.global_position.distance_to(me.global_position)>260.0 and not g.mission:gegner.erase(g);g.queue_free()
	if tot:return
	# Polizei wie im Original: Suchgebiet um den zuletzt gesehenen Ort, Streifenwagen jagen dich,
	# wer das Gebiet verlässt und nicht gesehen wird, ist die Sterne los
	_streifen_pflege(dt,me)
	# Militärbasis: Sperrgebiet -> sofort 4 Sterne
	var mp=me.global_position
	if mp.distance_to(Vector3(2000,mp.y,-5050))<215.0 and sterne<3.0 and not (spiel.admin and spiel.admin_keine_polizei):
		sterne=3.0;such_mitte=mp;_ohne_sicht=0.0;spiel.hud.zeige("GEFÄNGNISGELÄNDE! Fahndungsstufe 3",2.5)
	if mp.x>-3360.0 and mp.x<-1840.0 and mp.z>-5600.0 and mp.z<-5020.0 and sterne<4.0:
		if not (spiel.admin and spiel.admin_keine_polizei):
			sterne=4.0;such_mitte=mp;_ohne_sicht=0.0;spiel.hud.zeige("SPERRGEBIET! Fahndungsstufe 4",2.5)
	if spiel.admin and spiel.admin_keine_polizei:sterne=0.0
	if sterne>=1.0:
		var sieht=polizei_sieht_dich()
		if sieht:_ohne_sicht=0.0;such_mitte=me.global_position
		else:_ohne_sicht+=dt
		such_r=110.0+65.0*int(sterne)
		var draussen=me.global_position.distance_to(such_mitte)>such_r
		var grenze=(5.0+int(sterne)*2.0) if draussen else (28.0+int(sterne)*7.0)
		if _ohne_sicht>grenze:
			sterne=0.0;_ohne_sicht=0.0
			spiel.hud.zeige("Die Polizei hat dich verloren",2.5)
			for c in streifen:
				if is_instance_valid(c):c.modus="geparkt";c.parken()
			streifen.clear()
		_pol_spawn-=dt
		var n=gegner.filter(func(g):return is_instance_valid(g) and g.fraktion=="polizei" and not g.tot).size()
		if _pol_spawn<=0.0 and n<int(sterne)*2+1 and spiel.auto==null:
			_pol_spawn=8.0
			_polizei_spawn(me.global_position)
	elif sterne>0.0:
		sterne=max(0.0,sterne-dt*0.02)

var such_mitte:=Vector3.ZERO
var such_r:=0.0
var streifen:=[]          # verfolgende Streifenwagen
var _streifen_t:=0.0
func polizei_sieht_dich()->bool:
	var me=spiel.auto if spiel.auto!=null else spiel.spieler
	var p=me.global_position
	for g in gegner:
		if is_instance_valid(g) and g.fraktion=="polizei" and not g.tot and g.global_position.distance_to(p)<70.0:
			var h=_ray(g.global_position+Vector3(0,1.6,0),p+Vector3(0,1.0,0),[g,me])
			if h==null:return true
	for c in streifen:
		if is_instance_valid(c) and c.global_position.distance_to(p)<90.0:
			var h2=_ray(c.global_position+Vector3(0,1.5,0),p+Vector3(0,1.0,0),[c,me])
			if h2==null:return true
	return false

func _streifen_pflege(dt:float,me):
	for c in streifen.duplicate():
		if not is_instance_valid(c) or c.wrack:streifen.erase(c);continue
		if c.global_position.distance_to(me.global_position)>500.0:streifen.erase(c);spiel.geparkt.erase(c);c.queue_free();continue
		if sterne<1.0:continue
		c.verfolge(me,dt)
		# zu Fuß: Polizisten steigen aus
		if spiel.auto==null and c.global_position.distance_to(me.global_position)<16.0 and not c.has_meta("ausgestiegen"):
			c.set_meta("ausgestiegen",true);c.modus="geparkt";c.parken()
			var w="pistole" if sterne<3 else "mp5"
			for i in 2:spawn(c.global_position+c.global_transform.basis.x*(2.4 if i==0 else -2.4)+Vector3(0,0.3,0),"polizei",w,{"basis":"police","alarm":true})
	if sterne<1.0:return
	_streifen_t-=dt
	var soll=min(int(sterne),4)+(1 if sterne>=4 else 0)
	if _streifen_t<=0.0 and streifen.filter(func(c):return is_instance_valid(c) and not c.has_meta("ausgestiegen")).size()<soll:
		_streifen_t=7.0
		var S=spiel.welt.S;var p2=Vector2(me.global_position.x,me.global_position.z);var kand=[]
		for r in S.roads:
			if not r.typ in ["strasse","allee","land","autobahn","gasse"]:continue
			for i in range(0,r.P.size(),4):
				var d=r.P[i].distance_to(p2)
				if d>90.0 and d<160.0 and not r.tunnel_flags[i]:kand.append([r,i])
		if kand.is_empty():return
		var e=kand[randi()%kand.size()];var r2=e[0];var i2=e[1]
		var c2=load("res://scripts/spiel/fahrzeug.gd").new();spiel.add_child(c2);c2.setup("polizei" if sterne<4 or randf()<0.6 else "armored")
		var t:Vector2=r2.T[i2]
		c2.global_transform=Transform3D(Basis.looking_at(-Vector3(t.x,0,t.y),Vector3.UP),Vector3(r2.P[i2].x,r2.h[i2]+0.8,r2.P[i2].y))
		c2.blaulicht(true)
		streifen.append(c2);spiel.geparkt.append(c2)

func _polizei_spawn(p:Vector3):
	var S=spiel.welt.S;var kand=[]
	var p2=Vector2(p.x,p.z)
	for r in S.roads:
		if not r.typ in ["strasse","allee","gasse","land","autobahn"]:continue
		for i in range(0,r.P.size(),3):
			var d=r.P[i].distance_to(p2)
			if d>35.0 and d<75.0 and not r.tunnel_flags[i]:kand.append(Vector3(r.P[i].x,r.h[i]+0.3,r.P[i].y))
	if kand.is_empty():return
	var q:Vector3=kand[randi()%kand.size()]
	var w="pistole"
	if sterne>=3:w="mp5"
	if sterne>=4:w=["ar15","mossberg"][randi()%2]
	for i in 2:
		spawn(q+Vector3(randf_range(-2,2),0,randf_range(-2,2)),"polizei",w,{"basis":"police","alarm":true})
	# Streifenwagen dazu
	if randf()<0.6:
		var c=load("res://scripts/spiel/fahrzeug.gd").new();spiel.add_child(c);c.setup("polizei");c.global_position=q+Vector3(4,0.6,0);spiel.geparkt.append(c)

# ---------------- Gegner ----------------
# fraktion: "polizei", Gang-Name (z.B. "ballas"), "wache"
func spawn(p:Vector3,fraktion:String,waffe:String,opt:={}):
	var g=GEGNER.new();g.kampf=self;spiel.add_child(g)
	g.global_position=p
	g.setup(fraktion,waffe,opt)
	gegner.append(g)
	return g

func gruppe(mitte:Vector3,anzahl:int,fraktion:String,waffen_liste:Array,opt:={})->Array:
	var out=[]
	for i in anzahl:
		var a=TAU*i/max(anzahl,1)+randf()*0.5
		var p=mitte+Vector3(cos(a),0,sin(a))*randf_range(2.0,7.0)
		p.y=_boden(p)
		out.append(spawn(p,fraktion,waffen_liste[i%waffen_liste.size()],opt))
	return out

func _boden(p:Vector3)->float:
	var h=_ray(p+Vector3(0,30,0),p+Vector3(0,-60,0),[])
	return h.position.y+0.1 if h else p.y

func gegner_tot(g,von):
	if von==spiel.spieler or von==spiel.auto:
		if g.fraktion=="polizei":verbrechen(1.0)
		elif g.fraktion=="zivil":verbrechen(0.6)
		spiel.geld+=g.beute
		if g.beute>0:spiel.hud.zeige("+$%d"%g.beute,1.2)
	if spiel.mis:spiel.mis.gegner_tot(g)

# ---------------- Effekte ----------------
func _effekte_bauen():
	# Einschussloch-Textur (prozedural)
	var img=Image.create(32,32,false,Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var r=Vector2(x-15.5,y-15.5).length()/16.0
			var a=clamp(1.0-r*1.25,0.0,1.0)
			var c=0.05 if r<0.35 else 0.18
			img.set_pixel(x,y,Color(c,c,c,a*(1.0 if r<0.35 else 0.55)))
	_tex_loch=ImageTexture.create_from_image(img)
	for i in 40:
		var dc=Decal.new();dc.texture_albedo=_tex_loch;dc.size=Vector3(0.12,0.2,0.12);dc.visible=false;dc.cull_mask=1
		add_child(dc);_decals.append(dc)
	for i in 8:
		_funken.append(_partikel(Color(1.0,0.75,0.35),Color(0.5,0.48,0.44),14,0.35))
		_blut.append(_partikel(Color(0.45,0.02,0.02),Color(0.3,0.0,0.0),18,0.5))
	_blitz=MeshInstance3D.new();var sm=SphereMesh.new();sm.radius=0.07;sm.height=0.14;_blitz.mesh=sm
	var bm=StandardMaterial3D.new();bm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;bm.albedo_color=Color(1,0.85,0.45);bm.emission_enabled=true;bm.emission=Color(1,0.7,0.3);bm.emission_energy_multiplier=6
	_blitz.material_override=bm;_blitz.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(_blitz);_blitz.visible=false
	_blitz_licht=OmniLight3D.new();_blitz_licht.light_color=Color(1,0.75,0.4);_blitz_licht.light_energy=3.0;_blitz_licht.omni_range=5.0;add_child(_blitz_licht);_blitz_licht.visible=false
	# Geräusche
	_sounds["pistole"]=_knall(0.28,0.9,1.0)
	_sounds["mp"]=_knall(0.22,1.2,0.8)
	_sounds["gewehr"]=_knall(0.4,0.75,1.0)
	_sounds["mg"]=_knall(0.38,0.7,1.0)
	_sounds["schrot"]=_knall(0.5,0.55,1.0)
	_sounds["sniper"]=_knall(0.7,0.5,1.0)
	_sounds["schlag"]=_knall(0.08,2.5,0.4)
	_sounds["laden"]=_klick()
	for i in 10:
		var a=AudioStreamPlayer3D.new();a.unit_size=12.0;a.max_distance=400.0;a.bus="Master";add_child(a);_spieler_audio.append(a)

func _partikel(c1:Color,c2:Color,n:int,leben:float)->CPUParticles3D:
	var p=CPUParticles3D.new();p.emitting=false;p.one_shot=true;p.amount=n;p.lifetime=leben;p.explosiveness=1.0
	p.direction=Vector3(0,0,1);p.spread=55.0;p.initial_velocity_min=1.5;p.initial_velocity_max=5.0;p.gravity=Vector3(0,-9.8,0)
	p.scale_amount_min=0.02;p.scale_amount_max=0.05
	var m=SphereMesh.new();m.radius=0.5;m.height=1.0;m.radial_segments=6;m.rings=3;p.mesh=m
	var mt=StandardMaterial3D.new();mt.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mt.vertex_color_use_as_albedo=true;m.material=mt
	var g=Gradient.new();g.set_color(0,c1);g.set_color(1,c2);p.color_ramp=g
	add_child(p);return p

func _muendungsfeuer(p:Vector3,dir:Vector3):
	_blitz.global_position=p+dir*0.05;_blitz.visible=true;_blitz.scale=Vector3.ONE*randf_range(0.8,1.4)
	_blitz_licht.global_position=p+dir*0.2;_blitz_licht.visible=true;_blitz_t=0.05

func _spur(a:Vector3,b:Vector3):
	var L=a.distance_to(b)
	if L<1.0:return
	var m=MeshInstance3D.new();var bx=BoxMesh.new();bx.size=Vector3(0.012,0.012,L);m.mesh=bx
	var mt=StandardMaterial3D.new();mt.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mt.albedo_color=Color(1,0.9,0.55,0.8);mt.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material_override=mt;m.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(m)
	var mid=(a+b)*0.5;m.global_transform=Transform3D(HALTER._basis_aus(b-a,Vector3.UP),mid)
	_spuren.append({"n":m,"t":0.07})

func _einschlag(p:Vector3,n:Vector3,loch:bool):
	var f=_funken[_funken_i];_funken_i=(_funken_i+1)%_funken.size()
	f.global_position=p+n*0.03
	if n.length()>0.1:f.global_transform.basis=HALTER._basis_aus(n,Vector3.UP if abs(n.y)<0.9 else Vector3.RIGHT)
	f.restart();f.emitting=true
	if loch and n.length()>0.1:
		var dc=_decals[_decal_i];_decal_i=(_decal_i+1)%_decals.size()
		dc.visible=true
		var up=n.normalized()
		var x=up.cross(Vector3.FORWARD if abs(up.z)<0.9 else Vector3.RIGHT).normalized()
		dc.global_transform=Transform3D(Basis(x,up,x.cross(up)).orthonormalized(),p)

func _blutfx(p:Vector3,dir:Vector3):
	var b=_blut[_blut_i];_blut_i=(_blut_i+1)%_blut.size()
	b.global_position=p;b.global_transform.basis=HALTER._basis_aus(dir,Vector3.UP if abs(dir.y)<0.9 else Vector3.RIGHT)
	b.restart();b.emitting=true

func _ton(typ:String,p:Vector3,laut:=1.0):
	var s=_sounds.get(typ,_sounds.pistole)
	for a in _spieler_audio:
		if not a.playing:
			a.stream=s;a.global_position=p;a.volume_db=linear_to_db(laut)-2.0;a.pitch_scale=randf_range(0.93,1.07);a.play();return

# Schussknall: Rauschen mit kurzem Druckstoß und Nachhall
static func _knall(dauer:float,hell:float,laut:float)->AudioStreamWAV:
	var rate=22050;var n=int(dauer*rate)
	var data=PackedByteArray();data.resize(n*2)
	var lp=0.0;var lp2=0.0
	var rng=RandomNumberGenerator.new();rng.seed=int(dauer*1000+hell*100)
	for i in n:
		var t=float(i)/rate
		var env=exp(-t*(18.0/dauer*0.25))*0.9+exp(-t*120.0)*0.6
		var w=rng.randf_range(-1,1)
		var k=clamp(hell*0.35,0.05,0.95)
		lp+=(w-lp)*k;lp2+=(lp-lp2)*k
		var boom=sin(TAU*55.0*t)*exp(-t*30.0)*0.8
		var v=clamp((lp2*1.6+boom)*env*laut,-1.0,1.0)
		data.encode_s16(i*2,int(v*30000))
	var st=AudioStreamWAV.new();st.format=AudioStreamWAV.FORMAT_16_BITS;st.mix_rate=rate;st.stereo=false;st.data=data
	return st

static func _klick()->AudioStreamWAV:
	var rate=22050;var n=int(0.35*rate)
	var data=PackedByteArray();data.resize(n*2)
	for i in n:
		var t=float(i)/rate
		var v=0.0
		for k in [0.0,0.18,0.3]:
			if t>=k:v+=sin(TAU*1800.0*(t-k))*exp(-(t-k)*90.0)*0.6
		data.encode_s16(i*2,int(clamp(v,-1,1)*26000))
	var st=AudioStreamWAV.new();st.format=AudioStreamWAV.FORMAT_16_BITS;st.mix_rate=rate;st.data=data
	return st

# ---------------- Speichern ----------------
func daten()->Dictionary:
	return {"waffen":waffen,"magazin":magazin,"aktuell":aktuell,"ruestung":ruestung,"tags":tag_daten}
func lade_daten(d:Dictionary):
	if d.has("waffen"):waffen=d.waffen;magazin=d.get("magazin",{});ruestung=float(d.get("ruestung",0.0))
	tag_daten=d.get("tags",[]);tags_gesprueht=tag_daten.size();tags_wiederherstellen()
	for k in waffen:waffen[k]=int(waffen[k])
	for k in magazin:magazin[k]=int(magazin[k])
	if not waffen.has("faust"):waffen["faust"]=0
	waehle(d.get("aktuell","faust") if waffen.has(d.get("aktuell","faust")) else "faust")
