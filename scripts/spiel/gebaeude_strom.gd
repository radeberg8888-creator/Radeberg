extends Node
# Gebäude zellenweise einblenden und wieder entfernen.
# Jedes Gebäudemodell liegt vorbereitet als EIN Mesh mit Detailstufen vor (assets/cache/geb/, tools/gebaeude_bake.gd).
# Pro Zelle wird je Modell ein MultiMesh gebaut (Tönung/Schmutz über die Instanzfarbe) und ein Körper mit
# Kollisionskästen. Modelle werden im Hintergrund-Thread geladen – im Spielbild wird nie auf die Festplatte gewartet.
const GEB:="res://assets/cache/geb/"
var welt
var zelle:=128.0
var gitter:={}          # Vector2i -> [indizes]
var zellen:={}          # Vector2i -> Node3D (fertig gebaut)
var _wurzel:Node3D
var radius:=700.0       # einblenden
var radius_weg:=880.0   # wieder entfernen
var budget_ms:=4.0
var sicht_f:=1.0
var meshes:={}          # Vorlagenname -> Mesh
var _angefragt:={}      # Vorlagenname -> Pfad
var _alt:=false         # keine vorbereiteten Modelle -> altes Verfahren

const TINTS=[Color(1,1,1),Color(1.0,0.93,0.84),Color(0.86,0.9,0.95)]

func setup(w):
	welt=w
	_wurzel=welt.get_node_or_null("Gebaeude")
	if _wurzel==null:_wurzel=Node3D.new();_wurzel.name="Gebaeude";welt.add_child(_wurzel)
	for i in welt.B.placed.size():
		var c:Vector2=welt.B.placed[i].c
		var k=Vector2i(floor(c.x/zelle),floor(c.y/zelle))
		if not gitter.has(k):gitter[k]=[]
		gitter[k].append(i)
	_alt=not ResourceLoader.exists(GEB+"house.res")
	welt.B.ohne_dach=not _alt
	if _alt:push_warning("Gebäude: keine vorbereiteten Modelle gefunden, langsames Verfahren")

func _pfad(t:String)->String:return GEB+t+".res"

# Modell anfordern (Hintergrund); true, wenn schon da.
# Immer nur EIN Ladeauftrag gleichzeitig und ohne Unter-Threads: viele parallele Aufträge mit gemeinsamen
# Texturen können sich auf dem Handy gegenseitig blockieren (Spiel hängt).
var _laed:="";var _laed_seit:=0
var _warte:=[]
func _bereit(t:String)->bool:
	if meshes.has(t):return true
	if not t in _warte and t!=_laed:_warte.append(t)
	_pumpe()
	return meshes.has(t)
func _pumpe():
	if _laed!="":
		var p=_pfad(_laed)
		var s=ResourceLoader.load_threaded_get_status(p)
		if s==ResourceLoader.THREAD_LOAD_LOADED:meshes[_laed]=ResourceLoader.load_threaded_get(p);_laed=""
		elif s==ResourceLoader.THREAD_LOAD_FAILED or s==ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:meshes[_laed]=null;_laed=""
		elif Time.get_ticks_msec()-_laed_seit>30000:push_warning("Gebäude lädt zu lange: "+_laed);meshes[_laed]=null;_laed=""
		else:return
	while _laed=="" and not _warte.is_empty():
		var t=_warte.pop_front()
		if meshes.has(t):continue
		if not ResourceLoader.exists(_pfad(t)):meshes[t]=null;continue
		if ResourceLoader.load_threaded_request(_pfad(t),"",false)!=OK:meshes[t]=null;continue
		_laed=t;_laed_seit=Time.get_ticks_msec()

func _zelle_bereit(k:Vector2i)->bool:
	var ok=true
	for i in gitter[k]:
		if not _bereit(welt.B.placed[i].t):ok=false
	return ok

func _farbe(pl)->Color:
	var v=int(pl.v)%3;var dirt=float(pl.dirt)
	dirt=0.2 if dirt<0.35 else (0.5 if dirt<0.7 else 0.9)
	var grime=Color(0.78,0.72,0.62).lerp(Color(1,1,1),1.0-dirt)
	var t=TINTS[v]
	return Color(t.r*grime.r,t.g*grime.g,t.b*grime.b,1.0)

func _bauen(k:Vector2i):
	var n=Node3D.new();n.name="Z_%d_%d"%[k.x,k.y];_wurzel.add_child(n)
	var gruppen={}
	var sb=StaticBody3D.new();n.add_child(sb)
	for i in gitter[k]:
		var pl=welt.B.placed[i];var t=welt.B.get_tpl(pl.t)
		var xf=Transform3D(Basis(Vector3.UP,pl.yaw),Vector3(pl.c.x,pl.y-0.12,pl.c.y))
		if _alt:
			welt.B.einzeln(n,i)
		else:
			if not gruppen.has(pl.t):gruppen[pl.t]=[]
			gruppen[pl.t].append([xf,_farbe(pl)])
		var cs=CollisionShape3D.new();var bx=BoxShape3D.new();bx.size=t.ab.size*Vector3(0.96,1.0,0.96);cs.shape=bx;sb.add_child(cs)
		cs.transform=xf*Transform3D(Basis(),Vector3(0,t.ab.size.y*0.5+0.02,0))
	for name in gruppen:
		var mesh=meshes.get(name)
		if mesh==null:continue
		var l=gruppen[name]
		var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=mesh;mm.instance_count=l.size()
		for j in l.size():mm.set_instance_transform(j,l[j][0]);mm.set_instance_color(j,l[j][1])
		var mi=MultiMeshInstance3D.new();mi.multimesh=mm;mi.name=name;n.add_child(mi)
		var h=welt.B.get_tpl(name).ab.size.y
		var vr=1100.0 if h>40 else 480.0
		mi.set_meta("vr",vr);mi.visibility_range_end=vr*sicht_f
	zellen[k]=n

func sichtweite_anwenden():
	for k in zellen:
		for mi in zellen[k].get_children():
			if mi.has_meta("vr"):mi.visibility_range_end=mi.get_meta("vr")*sicht_f

# alles im Umkreis sofort (Ladebildschirm): Modelle der Reihe nach direkt laden, Fortschritt melden
func sofort(p:Vector3,r:float,fortschritt:Callable=Callable()):
	var ks=_zellen_um(p,r)
	if not _alt:
		var namen=[]
		for k in ks:
			for i in gitter[k]:
				var t=welt.B.placed[i].t
				if not t in namen:namen.append(t)
		for j in namen.size():
			var t=namen[j]
			if not meshes.has(t):
				meshes[t]=load(_pfad(t)) if ResourceLoader.exists(_pfad(t)) else null
			if fortschritt.is_valid():fortschritt.call(j+1,namen.size())
			await get_tree().process_frame
	for k in ks:
		if not zellen.has(k):_bauen(k)

func _zellen_um(p:Vector3,r:float)->Array:
	var out=[]
	var c=Vector2i(floor(p.x/zelle),floor(p.z/zelle));var n=int(ceil(r/zelle))
	for dz in range(-n,n+1):
		for dx in range(-n,n+1):
			var k=c+Vector2i(dx,dz)
			if gitter.has(k) and Vector2(dx,dz).length()*zelle<=r+zelle:out.append(k)
	out.sort_custom(func(a,b):return (a-c).length_squared()<(b-c).length_squared())
	return out

var _offen:=[]
var _letzt:=Vector3(1e9,0,0)
func schritt(p:Vector3):
	if p.distance_to(_letzt)>40.0:
		_letzt=p
		_offen=[]
		for k in _zellen_um(p,radius):
			if not zellen.has(k):_offen.append(k)
		# ferne Zellen freigeben
		var mitte=Vector2(p.x,p.z)
		for k in zellen.keys():
			var zm=(Vector2(k)+Vector2(0.5,0.5))*zelle
			if zm.distance_to(mitte)>radius_weg:
				zellen[k].queue_free();zellen.erase(k)
	if _offen.is_empty():return
	var t0=Time.get_ticks_usec();var gebaut=0
	var i=0
	while i<_offen.size() and (Time.get_ticks_usec()-t0)<budget_ms*1000.0:
		var k=_offen[i]
		if zellen.has(k):_offen.remove_at(i);continue
		if _alt or _zelle_bereit(k):
			_bauen(k);_offen.remove_at(i);gebaut+=1
			if gebaut>=2:break
		else:
			i+=1
			if i>=6:break   # nur die nächsten Zellen gleichzeitig anfordern

func anteil()->float:return float(zellen.size())/max(1,gitter.size())
