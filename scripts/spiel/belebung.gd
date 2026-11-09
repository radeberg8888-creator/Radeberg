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
