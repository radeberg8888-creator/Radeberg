extends Node
# Biker-Clubs: jeder Club hat sein Revier, einen Treffpunkt mit abgestellten Maschinen und fährt im Rudel
# (2–5 Harleys hintereinander). Fährt ein Rudel durch fremdes Revier und trifft auf den Gegner-Club,
# steigen alle ab und es gibt eine Schießerei. Wer die Biker angreift, hat den ganzen Club am Hals.
const AUTO=preload("res://scripts/spiel/fahrzeug.gd")
var spiel
const CLUBS:={
	"hoellenhunde":{"name":"Höllenhunde MC","farbe":Color(0.85,0.1,0.08),"mitte":Vector2(-480,1180),"r":520.0,"feind":["elbewoelfe","sachsenriders"]},
	"elbewoelfe":{"name":"Elbe Wölfe MC","farbe":Color(0.4,0.65,0.95),"mitte":Vector2(1150,850),"r":600.0,"feind":["hoellenhunde","wuestenraben"]},
	"sachsenriders":{"name":"Sachsen Riders MC","farbe":Color(0.15,0.6,0.25),"mitte":Vector2(-1050,-550),"r":650.0,"feind":["hoellenhunde","wuestenraben"]},
	"wuestenraben":{"name":"Wüstenraben MC","farbe":Color(0.95,0.55,0.1),"mitte":Vector2(1700,-5900),"r":950.0,"feind":["elbewoelfe","sachsenriders"]},
}
var rudel:=[]       # {club, leit:Fahrzeug, folger:[Fahrzeug], spur:[[t,Transform3D]], abgestiegen:bool}
var treffs:={}      # club -> {an, bikes:[], leute:[], p}
var _t:=0.0
var _zeit:=0.0

func setup(s):
	spiel=s
	for c in CLUBS:
		treffs[c]={"an":false,"bikes":[],"leute":[],"p":_treff_punkt(CLUBS[c].mitte)}
		if spiel.mini and "icons" in spiel.mini:spiel.mini.icons.append({"typ":"biker","x":treffs[c].p[0].x,"z":treffs[c].p[0].y})

func _treff_punkt(m:Vector2)->Array:
	# Straßenrand nahe der Reviermitte: [Position, Tangente]
	var S=spiel.welt.S;var best=null;var bd=1e9
	for r in S.roads:
		if not r.typ in ["strasse","land","gasse"]:continue
		for i in range(0,r.P.size(),3):
			var d=r.P[i].distance_to(m)
			if d<bd and not r.tunnel_flags[i]:bd=d;best=[r,i]
	if best==null:return [m,Vector2(1,0),0.0,5.0]
	var r=best[0];var i=best[1];var t:Vector2=r.T[i];var n=Vector2(-t.y,t.x)
	return [r.P[i]+n*(r.w+4.0),t,r.h[i],r.w]

func revier(p:Vector2)->String:
	for c in CLUBS:
		if p.distance_to(CLUBS[c].mitte)<CLUBS[c].r:return c
	return ""

func schritt(dt:float):
	_zeit+=dt
	var me=spiel.auto if spiel.auto!=null else spiel.spieler
	var mp=Vector2(me.global_position.x,me.global_position.z)
	_rudel_schritt(dt,mp)
	_t-=dt
	if _t>0.0:return
	_t=1.5
	# Treffpunkte erzeugen/abbauen
	for c in treffs:
		var tr=treffs[c];var d=mp.distance_to(tr.p[0])
		if not tr.an and d<170.0:_treff_an(c)
		elif tr.an and d>240.0:_treff_aus(c)
	# Rudel: Revier des Spielers bekommt eins, manchmal kommt ein verfeindetes auf Beutezug dazu
	for e in rudel.duplicate():
		if not is_instance_valid(e.leit) or e.leit.global_position.distance_to(me.global_position)>450.0:_rudel_weg(e)
	if rudel.size()>=2:return
	var hier=revier(mp)
	if hier=="":return
	if rudel.filter(func(e):return e.club==hier).is_empty():_rudel_neu(hier,mp,hier)
	elif randf()<0.15:
		var f:Array=CLUBS[hier].feind;_rudel_neu(f[randi()%f.size()],mp,hier)

# ---------------- Rudel ----------------
func _rudel_neu(club:String,mp:Vector2,im_revier:String):
	var S=spiel.welt.S;var kand=[]
	var mitte:Vector2=CLUBS[im_revier].mitte;var rr:float=CLUBS[im_revier].r
	for r in S.roads:
		if not r.typ in ["strasse","allee","land"]:continue
		for i in range(0,r.P.size(),4):
			var d=r.P[i].distance_to(mp)
			if d>110.0 and d<230.0 and r.P[i].distance_to(mitte)<rr and not r.tunnel_flags[i]:kand.append([r,i])
	if kand.is_empty():return
	var e=kand[randi()%kand.size()];var r=e[0]
	var n=randi_range(2,5)
	var leit=AUTO.new();spiel.add_child(leit);leit.setup("c_harley_"+club)
	var dir=1 if randf()<0.5 else -1
	var s=float(e[1])*S.DS+(-dir*n*9.0)
	leit.als_ki(r,clamp(s,5.0,S.length(r)-5.0),dir,leit._lane(r)*0.8,S)
	leit.ki_ziel=13.0;leit.set_meta("club",club)
	var eintrag={"club":club,"leit":leit,"folger":[],"spur":[],"abgestiegen":false}
	for k in n-1:
		var f=AUTO.new();spiel.add_child(f);f.setup("c_harley_"+club)
		f.freeze_mode=RigidBody3D.FREEZE_MODE_KINEMATIC;f.freeze=true;f.modus="folger";f.set_meta("club",club)
		f.global_transform=leit.global_transform;eintrag.folger.append(f)
	rudel.append(eintrag)
	spiel.verkehr.append(leit)   # Leittier fährt wie Verkehr (Abstand, Kreuzungen)
	if im_revier!=club:spiel.hud.zeige("%s fahren durch das Revier der %s!"%[CLUBS[club].name,CLUBS[im_revier].name],3.0)

func _rudel_schritt(dt:float,mp:Vector2):
	for e in rudel.duplicate():
		if e.abgestiegen or not is_instance_valid(e.leit):continue
		var L=e.leit
		# Leittier gestohlen oder angehalten/beschädigt -> absteigen
		if L.modus!="ki" or L.hp<1000.0:_absteigen(e,null);continue
		var getroffen=false
		for f in e.folger:
			if is_instance_valid(f) and f.hp<1000.0:getroffen=true
		if getroffen:_absteigen(e,null);continue
		# Spur aufzeichnen, Folger fahren versetzt hinterher
		e.spur.push_front([_zeit,L.global_transform])
		if e.spur.size()>400:e.spur.resize(400)
		for k in e.folger.size():
			var f=e.folger[k]
			if not is_instance_valid(f) or f.modus!="folger":continue
			var ziel_t=_zeit-0.75*(k+1)
			var xf=null
			for q in e.spur:
				if q[0]<=ziel_t:xf=q[1];break
			if xf==null:xf=e.spur[e.spur.size()-1][1]
			var seite=0.75 if k%2==0 else -0.55
			f.global_transform=Transform3D(xf.basis,xf.origin+xf.basis.x*seite)
		# Begegnung mit verfeindetem Rudel oder Treffpunkt -> Krieg
		var hier=Vector2(L.global_position.x,L.global_position.z)
		for o in rudel:
			if o==e or o.abgestiegen or not is_instance_valid(o.leit):continue
			if o.club in CLUBS[e.club].feind and o.leit.global_position.distance_to(L.global_position)<55.0:
				_absteigen(e,o.club);_absteigen(o,e.club)
				spiel.hud.zeige("BANDENKRIEG: %s gegen %s!"%[CLUBS[e.club].name,CLUBS[o.club].name],3.5)
				break
		for c in treffs:
			var tr=treffs[c]
			if tr.an and c in CLUBS[e.club].feind and hier.distance_to(tr.p[0])<45.0:
				_absteigen(e,c);_treff_krieg(c,e.club)
				spiel.hud.zeige("%s greifen den Treffpunkt der %s an!"%[CLUBS[e.club].name,CLUBS[c].name],3.5)

func _absteigen(e,gegen):
	if e.abgestiegen:return
	e.abgestiegen=true
	var K=spiel.kampf
	var alle=[e.leit]+e.folger
	spiel.verkehr.erase(e.leit)
	for b in alle:
		if not is_instance_valid(b) or b==spiel.auto:continue
		b.ki_ton_aus();b.parken();b.freeze=false;spiel.geparkt.append(b)
		var fn=b.visual.get_node_or_null("Fahrer") if b.visual else null
		if fn:fn.visible=false
		var p=b.global_position+b.global_transform.basis.x*1.0+Vector3(0,0.3,0)
		var w=["pistole","pistole","mossberg","mp5","machete"][randi()%5]
		var g=K.spawn(p,e.club,w,{"basis":"biker","feinde":[gegen] if gegen else [],"alarm":true,"hp":120.0})
	if gegen==null:spiel.hud.zeige("Die %s steigen ab!"%CLUBS[e.club].name,2.0)

func _rudel_weg(e):
	rudel.erase(e)
	for b in [e.leit]+e.folger:
		if is_instance_valid(b) and b!=spiel.auto:spiel.verkehr.erase(b);spiel.geparkt.erase(b);b.queue_free()

# ---------------- Treffpunkte ----------------
func _treff_an(c):
	var tr=treffs[c];tr.an=true
	var p:Vector2=tr.p[0];var t:Vector2=tr.p[1];var n=Vector2(-t.y,t.x)
	var h=_boden(p)
	# abgestellte Maschinen schräg in einer Reihe, Mitglieder davor (friedlich, solange man sie in Ruhe lässt)
	for k in 5:
		var q=p+t*(-6.0+k*2.4)
		var b=AUTO.new();spiel.add_child(b);b.setup("c_harley_%s_p"%c)
		b.global_transform=Transform3D(Basis(Vector3.UP,atan2(n.x,n.y)+0.5),Vector3(q.x,_boden(q)+0.5,q.y))
		b.modus="geparkt";spiel.geparkt.append(b);tr.bikes.append(b)
	for k in 5:
		var q=p+t*(-5.0+k*2.5)+n*3.0
		var g=spiel.kampf.spawn(Vector3(q.x,_boden(q)+0.1,q.y),c,["pistole","mossberg","machete","pistole","mp5"][k],{"basis":"biker","friedlich":true,"stationaer":k%2==0,"hp":120.0})
		tr.leute.append(g)
	# Clubschild
	# Clubschild auf zwei Pfosten hinter den Maschinen, zur Straße gedreht
	var schild=Node3D.new();spiel.add_child(schild)
	var hinten=p+n*6.5;schild.global_position=Vector3(hinten.x,_boden(hinten),hinten.y);schild.rotation.y=atan2(-n.x,-n.y)
	var holz=StandardMaterial3D.new();holz.albedo_color=Color(0.12,0.1,0.09)
	for sx in [-1,1]:
		var pf=MeshInstance3D.new();var bm=BoxMesh.new();bm.size=Vector3(0.18,3.4,0.18);pf.mesh=bm;pf.material_override=holz;schild.add_child(pf);pf.position=Vector3(sx*2.4,1.7,0)
	var tafel=MeshInstance3D.new();var tb=BoxMesh.new();tb.size=Vector3(5.6,1.1,0.12);tafel.mesh=tb;tafel.material_override=holz;schild.add_child(tafel);tafel.position=Vector3(0,3.0,0)
	var lb=Label3D.new();lb.text=CLUBS[c].name.to_upper();lb.font_size=96;lb.pixel_size=0.009;lb.modulate=CLUBS[c].farbe;lb.outline_size=14;lb.outline_modulate=Color(0,0,0)
	schild.add_child(lb);lb.position=Vector3(0,3.0,0.08)
	tr["schild"]=schild

func _treff_aus(c):
	var tr=treffs[c];tr.an=false
	for b in tr.bikes:
		if is_instance_valid(b) and b!=spiel.auto:spiel.geparkt.erase(b);b.queue_free()
	for g in tr.leute:
		if is_instance_valid(g) and not g.tot:spiel.kampf.gegner.erase(g);g.queue_free()
	tr.bikes=[];tr.leute=[]
	if tr.has("schild") and is_instance_valid(tr.schild):tr.schild.queue_free()

func _treff_krieg(c,angreifer):
	for g in treffs[c].leute:
		if is_instance_valid(g):g.friedlich=false;g.feinde=[angreifer];g.alarm=true;g.stationaer=false

func _boden(p:Vector2)->float:
	var hit=spiel.kampf._ray(Vector3(p.x,600,p.y),Vector3(p.x,-60,p.y),[])
	return hit.position.y if hit else spiel.welt.G.h_at(p.x,p.y)
