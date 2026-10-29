extends Node
# Gebäude nach und nach einblenden (nah zuerst), damit das Spiel schnell startet.
# Jedes Haus bekommt beim Einblenden seinen Kollisionskasten.
var welt
var zelle:=160.0
var gitter:={}          # Vector2i -> [indizes]
var fertig:={}          # index -> true
var _wurzel:Node3D
var radius:=750.0
var budget_ms:=5.0

func setup(w):
	welt=w
	_wurzel=welt.get_node_or_null("Gebaeude")
	if _wurzel==null:_wurzel=Node3D.new();_wurzel.name="Gebaeude";welt.add_child(_wurzel)
	for i in welt.B.placed.size():
		var c:Vector2=welt.B.placed[i].c
		var k=Vector2i(floor(c.x/zelle),floor(c.y/zelle))
		if not gitter.has(k):gitter[k]=[]
		gitter[k].append(i)

func _bauen(i:int):
	var w=welt.B.einzeln(_wurzel,i)
	var pl=welt.B.placed[i];var t=welt.B.get_tpl(pl.t)
	var sb=StaticBody3D.new();w.add_child(sb)
	var cs=CollisionShape3D.new();var bx=BoxShape3D.new();bx.size=t.ab.size*Vector3(0.96,1.0,0.96);cs.shape=bx;sb.add_child(cs)
	cs.position=Vector3(0,t.ab.size.y*0.5+0.02,0)
	fertig[i]=true

# alles im Umkreis sofort (beim Start)
func sofort(p:Vector3,r:float):
	for k in _zellen(p,r):
		for i in gitter[k]:
			if not fertig.has(i):_bauen(i)

func _zellen(p:Vector3,r:float)->Array:
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
	if p.distance_to(_letzt)>60.0 or _offen.is_empty():
		_letzt=p;_offen=[]
		for k in _zellen(p,radius):
			for i in gitter[k]:
				if not fertig.has(i):_offen.append(i)
	var t0=Time.get_ticks_usec()
	while not _offen.is_empty() and (Time.get_ticks_usec()-t0)<budget_ms*1000.0:
		var i=_offen.pop_front()
		if not fertig.has(i):_bauen(i)

func anteil()->float:return float(fertig.size())/max(1,welt.B.placed.size())
