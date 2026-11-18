extends Node
# Belebte Orte: Figuren, die an festen Orten ihrer Arbeit nachgehen (Knast, Militär, Hafen, Lager, Autohandel,
# Polizei-, Feuer- und Taxiwachen). Werden erst in der Nähe des Spielers erzeugt und in der Ferne wieder entfernt.
const PE=preload("res://scripts/people.gd")
const HALTER=preload("res://scripts/spiel/waffen_halter.gd")
var spiel
var orte:=[]        # {name, mitte:Vector3, an:bool, figuren:[], plan:Callable, fahrzeuge:[]}
const AN:=150.0
const AUS:=210.0
var _t:=0.0

const WESTE:=Color(1.0,0.5,0.05)
const HAEFTLING:=Color(0.95,0.45,0.08)
const WAERTER:=Color(0.18,0.22,0.3)
const SOLDAT:=Color(0.3,0.33,0.2)
const FEUERWEHR:=Color(0.12,0.12,0.14)

func setup(s):
	spiel=s
	var kn=Vector2(2000,-5050);var mi=Vector2(-2600,-5450)
	_ort("knast",kn,func(o):_knast(o,kn))
	_ort("militaer",mi,func(o):_militaer(o,mi))
	for p in [Vector2(500,2090),Vector2(700,2200),Vector2(1500,820),Vector2(1350,700)]:
		_ort("hafen",p,func(o):_hafen(o,p))
	var W=spiel.welt
	if "IMMO" in W:
		for im in W.IMMO:
			var p2=Vector2(im.p.x,im.p.z) if im.p is Vector3 else im.p
			if im.art=="lager":_ort("lager",p2,func(o):_lager(o,p2))
			elif im.art=="autohandel":_ort("autohandel",p2,func(o):_autohandel(o,p2))
	# Straßenleben (Abschnitt 4.2): Szenen auf Gehwegen in den Vierteln
	for e in [["bar",Vector2(250,-350)],["bar",Vector2(-2300,700)],["club",Vector2(-150,-650)],["gang",Vector2(-262,1040)],["gang",Vector2(-120,980)],
			["strand",Vector2(-2300,760)],["strand",Vector2(-2200,640)],["angler",Vector2(560,2160)],["musiker",Vector2(-150,-650)],["musiker",Vector2(300,-300)],
			["obdachlos",Vector2(-262,1040)],["obdachlos",Vector2(320,-420)],["touristen",Vector2(-120,-700)],["touristen",Vector2(-2350,700)],
			["laden",Vector2(250,-350)],["laden",Vector2(496,-168)],["laden",Vector2(2550,850)],["baustelle",Vector2(900,640)],["baustelle",Vector2(-1083,-504)],
			["liefer",Vector2(250,1560)],["liefer",Vector2(2550,850)],["taxistand",Vector2(200,-380)],["bus",Vector2(-150,-620)],["jogger",Vector2(-150,-1450)]]:
		var art:String=e[0];var m:Vector2=e[1]
		_ort(art,m,func(o):_szene(o,art,m))
	if "DIENSTE" in W:
		for d in W.DIENSTE:
			var p3:Vector2=d.p;var yaw:float=d.yaw
			_ort(d.art,p3,func(o):_dienst(o,d.art,p3,yaw))

func _ort(name:String,p:Vector2,plan:Callable):
	orte.append({"name":name,"p":p,"an":false,"figuren":[],"fahrzeuge":[],"plan":plan})

func schritt(dt:float):
	_t-=dt
	var me=spiel.auto if spiel.auto!=null else spiel.spieler
	var mp=Vector2(me.global_position.x,me.global_position.z)
	if _t<=0.0:
		_t=0.7
		for o in orte:
			var d=mp.distance_to(o.p)
			if not o.an and d<AN:o.an=true;o.plan.call(o)
			elif o.an and d>AUS:_weg(o)
	for o in orte:
		if not o.an:continue
		for f in o.figuren:_figur_schritt(f,dt)

func _weg(o):
	o.an=false
	for f in o.figuren:
		if is_instance_valid(f.n):f.n.queue_free()
	for c in o.fahrzeuge:
		if is_instance_valid(c) and c!=spiel.auto:spiel.geparkt.erase(c);c.queue_free()
	o.figuren=[];o.fahrzeuge=[]

# ---------------- Figuren ----------------
func _boden(p:Vector2)->float:
	var h=spiel.kampf._ray(Vector3(p.x,600,p.y),Vector3(p.x,-60,p.y),[])
	return h.position.y if h else spiel.welt.G.h_at(p.x,p.y)
func _figur(o,basis:String,farbe,punkte:Array,anim:="walk",waffe:="",tempo:=1.25)->Dictionary:
	var r=RandomNumberGenerator.new();r.randomize()
	var look={}
	if farbe!=null:look={"tint":farbe,"mix":0.88,"sat":1.0,"val":1.0,"hue":0.0}
	var n=PE.make(basis,r,look);spiel.add_child(n)
	var P=[]
	for q in punkte:P.append(Vector3(q.x,_boden(q),q.y))
	n.global_position=P[0]
	if waffe!="":
		var h=HALTER.new();n.add_child(h);h.setup(n);h.setze_waffe(waffe)
	var f={"n":n,"P":P,"i":1 if P.size()>1 else 0,"warte":r.randf_range(0.0,3.0),"anim":anim,"tempo":tempo,"steht":anim!="walk"}
	PE.play(n,"idle" if anim=="walk" else anim,r.randf())
	if P.size()==1:n.rotation.y=r.randf()*TAU
	o.figuren.append(f)
	return f
func _figur_schritt(f,dt:float):
	var n:Node3D=f.n
	if not is_instance_valid(n) or f.P.size()<2:return
	if f.warte>0.0:
		f.warte-=dt
		if f.warte<=0.0:PE.play(n,"walk")
		return
	var ziel:Vector3=f.P[f.i];var v=ziel-n.global_position
	var flach=Vector2(v.x,v.z)
	if flach.length()<0.4:
		f.i=(f.i+1)%f.P.size();f.warte=randf_range(1.5,6.0)
		PE.play(n,"talk" if randf()<0.3 else "idle")
		return
	var schritt=flach.normalized()*f.tempo*dt
	n.global_position+=Vector3(schritt.x,0,schritt.y)
	n.global_position.y=lerp(n.global_position.y,ziel.y,clamp(dt*3.0,0.0,1.0))
	n.rotation.y=lerp_angle(n.rotation.y,atan2(flach.x,flach.y),clamp(dt*6.0,0.0,1.0))
func _kreis(m:Vector2,r:float,n:int,dreh:=0.0)->Array:
	var a=[];for i in n:a.append(m+Vector2(cos(dreh+TAU*i/n),sin(dreh+TAU*i/n))*r)
	return a
func _zufall_um(m:Vector2,r:float,n:int)->Array:
	var a=[];for i in n:a.append(m+Vector2(randf_range(-r,r),randf_range(-r,r)))
	return a
func _auto(o,kind:String,p:Vector2,yaw:float):
	var c=load("res://scripts/spiel/fahrzeug.gd").new();spiel.add_child(c);c.setup(kind)
	c.global_transform=Transform3D(Basis(Vector3.UP,yaw),Vector3(p.x,_boden(p)+0.6,p.y))
	c.modus="geparkt";spiel.geparkt.append(c);o.fahrzeuge.append(c)
	return c

# ---------------- Orte ----------------
func _knast(o,kn:Vector2):
	# Häftlinge im Hof: laufen Runden, stehen in Grüppchen, boxen
	for i in 6:_figur(o,["joe","daya","biker"][i%3],HAEFTLING,_kreis(kn+Vector2(0,10),35.0+i*4,6,i*0.9),"walk","",1.0)
	for g in 3:
		var m=kn+Vector2(-50+g*50,30)
		for k in 3:
			var f=_figur(o,["joe","daya","biker"][(g+k)%3],HAEFTLING,[m+Vector2(cos(k*2.1),sin(k*2.1))*1.3],"talk" if g!=1 else ("punch" if k<2 else "idle"))
			f.n.rotation.y=atan2(-cos(k*2.1),-sin(k*2.1))
	# Wärter: am Tor, auf Streife im Hof, an den Zellenblöcken
	var tor=kn+Vector2(0,190)
	for sx in [-1,1]:_figur(o,"police",WAERTER,[tor+Vector2(sx*7,6)],"idle","mossberg")
	_figur(o,"police",WAERTER,[kn+Vector2(-80,-20),kn+Vector2(80,-20),kn+Vector2(80,50),kn+Vector2(-80,50)],"walk","pistole",1.1)
	_figur(o,"police",WAERTER,[kn+Vector2(-60,-45),kn+Vector2(60,-45)],"walk","mp5",1.0)
	_auto(o,"c_polizei",tor+Vector2(14,14),0.3)
func _militaer(o,mi:Vector2):
	# Streifen, Wachen an Hangars und Panzern, Exerzierplatz
	_figur(o,"police",SOLDAT,[mi+Vector2(-420,-40),mi+Vector2(-250,-40),mi+Vector2(-250,10),mi+Vector2(-420,10)],"walk","ar15",1.3)
	_figur(o,"police",SOLDAT,[mi+Vector2(200,-60),mi+Vector2(320,-60)],"walk","ar15",1.2)
	for k in 4:_figur(o,"police",SOLDAT,[mi+Vector2(-500+k*90,-55)],"idle","ar15")
	for r in 2:
		for k in 4:_figur(o,"police",SOLDAT,[mi+Vector2(60+k*2.0,40+r*2.0)],"idle","")
	var ausbilder=_figur(o,"police",SOLDAT,[mi+Vector2(64,35)],"talk","");ausbilder.n.rotation.y=PI
func _hafen(o,p:Vector2):
	# Hafenarbeiter mit Warnweste: laufen zwischen Containern, stehen und reden, einer weist ein
	for i in 4:_figur(o,["joe","hqman","daya"][i%3],WESTE,_zufall_um(p,30.0,4),"walk","",1.15)
	for k in 2:
		var m=p+Vector2(randf_range(-20,20),randf_range(-20,20))
		var f1=_figur(o,"joe",WESTE,[m],"talk");var f2=_figur(o,"hqman",WESTE,[m+Vector2(1.4,0)],"idle")
		f1.n.rotation.y=PI*0.5;f2.n.rotation.y=-PI*0.5
	_auto(o,["c_lkw_blau","c_lkw_weiss","c_transporter_weiss"][randi()%3],p+Vector2(12,8),randf()*TAU)
func _lager(o,p:Vector2):
	for i in 2:_figur(o,["joe","daya"][i],WESTE,_zufall_um(p,14.0,3),"walk","",1.1)
	_figur(o,"hqman",null,[p+Vector2(4,6)],"talk")
	if randf()<0.7:_auto(o,["c_lkw_radeberger","c_lkw_blau","c_lkw_weiss","c_transporter_weiss"][randi()%4],p+Vector2(-8,12),randf()*TAU)
func _autohandel(o,p:Vector2):
	var v=_figur(o,"hqman",Color(0.15,0.15,0.2),[p+Vector2(-6,8),p+Vector2(6,8),p+Vector2(6,14)],"walk","",0.9)
	var kunde=_figur(o,["female","joe"][randi()%2],null,[p+Vector2(-3,10),p+Vector2(3,12)],"walk","",0.8)
func _dienst(o,art:String,p:Vector2,yaw:float):
	var vor=Vector2(sin(yaw),cos(yaw))   # zeigt vom Gebäude zur Straße
	var quer=Vector2(vor.y,-vor.x)
	var hof=p-vor*(9.0 if art=="taxi" else 7.0)   # Hof zwischen Straße und Gebäude
	match art:
		"polizei":
			for k in 2:_auto(o,"c_polizei",hof+quer*(-6+k*4.5),yaw+PI*0.5)
			_figur(o,"police",null,[hof+quer*3.0],"talk");_figur(o,"police",null,[hof+quer*4.2],"idle")
			_figur(o,"police",null,[hof+quer*-9.0,hof+quer*9.0],"walk","",1.0)
		"feuerwehr":
			for k in 2:_auto(o,"c_feuerwehr",hof+quer*(-5+k*7),yaw)
			for k in 3:_figur(o,["joe","daya","biker"][k],FEUERWEHR,[hof+quer*(8+k*1.3)],"talk" if k==0 else "idle")
			_figur(o,"joe",FEUERWEHR,[hof+quer*-8.0,hof+quer*-8.0+vor*6.0],"walk","",0.9)
		"taxi":
			for k in 3:_auto(o,"c_taxi",hof+quer*(3.0+k*3.2),yaw)
			_figur(o,"daya",null,[hof+quer*5.0],"idle");_figur(o,"joe",null,[hof+quer*6.2],"talk")

# ---------------- Straßenszenen ----------------
# nächster Gehwegpunkt (Straße + seitlich auf den Gehweg) und Richtung zur Straße
func _gehweg(m:Vector2,k:int)->Array:
	var S=spiel.welt.S;var best=null;var bd=1e9;var bi=0
	for r in S.roads:
		if not r.typ in ["strasse","allee","gasse"] or float(r.get("sw",0.0))<=0.0:continue
		var P:PackedVector2Array=r.P
		for i in range(0,P.size(),3):
			var d=P[i].distance_to(m)
			if d<bd:bd=d;best=r;bi=i
	if best==null:return [m,Vector2(0,1)]
	var P:PackedVector2Array=best.P;var i=clamp(bi+k*3,0,P.size()-2)
	var t=(P[i+1]-P[i]).normalized();var n=Vector2(-t.y,t.x)*(1.0 if k%2==0 else -1.0)
	var q=P[i]+n*(float(best.w)+float(best.sw)*0.6)
	return [q,-n]
func _blick(f,zu:Vector2):f.n.rotation.y=atan2(zu.x,zu.y)
func _szene(o,art:String,m:Vector2):
	var nacht=spiel.zeit/60.0<6.0 or spiel.zeit/60.0>=22.0
	match art:
		"bar","club":
			var g=_gehweg(m,1);var q:Vector2=g[0];var zu:Vector2=g[1]
			var tuer=_figur(o,"hqman",Color(0.05,0.05,0.06),[q-zu*1.0],"idle");_blick(tuer,zu)   # Türsteher
			for k in (6 if nacht else 2):
				_figur(o,["female","joe","daya","biker"][k%4],null,[q+Vector2(randf_range(-4,4),randf_range(-4,4))+zu*1.5],"dance" if nacht and k%2==0 else "talk")
			if art=="club":
				for k in 3:_figur(o,"biker",Color(0.1,0.08,0.06),[q+zu*3.0+Vector2(k*1.2,0)],"talk")
				_auto(o,["c_harley_hoellenhunde","c_harley_sachsenriders","c_harley_elbewoelfe"][randi()%3],q+zu*5.0,randf()*TAU)
		"gang":
			var g=_gehweg(m,2);var q:Vector2=g[0]
			for k in 5:
				var a=k*TAU/5.0;var f=_figur(o,["daya","biker","joe"][k%3],[Color(0.45,0.1,0.55),Color(0.1,0.35,0.15)][k%2],[q+Vector2(cos(a),sin(a))*1.6],"talk" if k%2==0 else "idle")
				f.n.rotation.y=atan2(-cos(a),-sin(a))
		"strand":
			for k in 6:_figur(o,["female","joe","daya"][k%3],[Color(0.95,0.85,0.2),Color(0.2,0.6,0.85),Color(0.9,0.3,0.3)][k%3],_zufall_um(m,25.0,3),"walk","",0.9)   # Badegäste
			for k in 2:_figur(o,"joe",Color(0.1,0.3,0.6),[m+Vector2(8+k*1.3,4)],"talk")   # Surfer
		"angler":
			for k in 3:
				var f=_figur(o,["joe","hqman","daya"][k],Color(0.3,0.33,0.2),[m+Vector2(k*6.0,0)],"idle");f.n.rotation.y=PI
		"musiker":
			var g=_gehweg(m,3);var f=_figur(o,"biker",null,[g[0]],"dance");_blick(f,g[1])
			for k in 3:
				var z=_figur(o,["female","joe","hqman"][k],null,[g[0]+g[1]*2.5+Vector2(k-1.0,0)],"idle");_blick(z,-g[1])
		"obdachlos":
			var g=_gehweg(m,4);var f=_figur(o,"joe",Color(0.3,0.26,0.2),[g[0]-g[1]*1.2],"idle");_blick(f,g[1])
		"touristen":
			var g=_gehweg(m,5)
			for k in 4:_figur(o,["female","hqman"][k%2],[Color(0.95,0.95,0.9),Color(0.9,0.6,0.2)][k%2],[g[0]+Vector2(k*0.9,0),g[0]+Vector2(k*0.9+8,2)],"walk","",0.7)
		"laden":
			for k in 2:
				var g=_gehweg(m,6+k*2);var f=_figur(o,"hqman",Color(0.6,0.15,0.12),[g[0]-g[1]*1.4],"idle");_blick(f,g[1])   # Verkäufer vor dem Laden
		"baustelle":
			var g=_gehweg(m,2)
			for k in 3:_figur(o,["joe","daya","biker"][k],WESTE,[g[0]+Vector2(k*1.5,0)],"talk" if k==0 else "idle")
			_auto(o,"c_lkw_bau",g[0]+g[1]*4.0,randf()*TAU)
		"liefer":
			var g=_gehweg(m,3);_auto(o,["c_transporter_post","c_transporter_weiss"][randi()%2],g[0]+g[1]*3.0,atan2(g[1].y,-g[1].x))
			_figur(o,"joe",Color(0.95,0.75,0.1),[g[0],g[0]-g[1]*3.0],"walk","",1.0)
		"taxistand":
			var g=_gehweg(m,1)
			for k in 3:_auto(o,"c_taxi",g[0]+g[1]*3.0+Vector2(g[1].y,-g[1].x)*k*5.0,atan2(g[1].y,-g[1].x))
			_figur(o,"daya",null,[g[0]],"talk")
		"bus":
			var g=_gehweg(m,2)
			for k in 4:
				var f=_figur(o,["female","joe","hqman","daya"][k],null,[g[0]+Vector2(g[1].y,-g[1].x)*k*0.9],"idle");_blick(f,g[1])
		"jogger":
			var g=_gehweg(m,0);var g2=_gehweg(m,8)
			for k in 2:_figur(o,["female","joe"][k],Color(0.2,0.5,0.9),[g[0],g2[0]],"walk","",2.6)
