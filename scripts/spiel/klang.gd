extends Node
# Umgebungsgeräusche (Abschnitt 4.4): Stadt/Verkehr, Vögel, Wind, Wellen am Strand, Musik aus Bars, Baustellen,
# Sirenen und Hupen. Alles im Code erzeugt (kurze Schleifen, 22 kHz mono), Lautstärke nach Ort und Tageszeit.
# Billig: wenige Player, nur Lautstärken werden 4x pro Sekunde angepasst.
var spiel
var _p:={}          # Name -> AudioStreamPlayer (Flächenklang)
var _orte:=[]       # [AudioStreamPlayer3D, Pos]
var _t:=0.0
const RATE:=22050
const STRAND:=[Vector2(-2300,700),Vector2(-2200,640),Vector2(500,2150)]
const BARS:=[Vector2(250,-350),Vector2(-2300,700),Vector2(-150,-650)]
const BAU:=[Vector2(900,640),Vector2(-1083,-504)]
const STADT:=[Vector2(250,-350),Vector2(-150,-650),Vector2(496,-168),Vector2(2550,850),Vector2(250,1560),Vector2(-262,1040),
	Vector2(900,640),Vector2(500,2090),Vector2(-1083,-504),Vector2(2900,-300)]

func setup(s):
	spiel=s
	for e in [["voegel",_voegel()],["wind",_wind()],["wellen",_wellen()]]:
		var a=AudioStreamPlayer.new();a.stream=e[1];a.volume_db=-60.0;a.name="Klang_"+e[0];add_child(a);a.play();_p[e[0]]=a
	for b in BARS:_ort(_musik(),b,-6.0,45.0)
	for b in BAU:_ort(_baustelle(),b,-4.0,60.0)

func _ort(st:AudioStreamWAV,p:Vector2,db:float,weit:float):
	var a=AudioStreamPlayer3D.new();a.stream=st;a.volume_db=db;a.max_distance=weit;a.unit_size=8.0
	a.attenuation_model=AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE;add_child(a)
	_orte.append([a,p])

func _process(dt):
	_t-=dt
	if _t>0.0 or spiel==null:return
	_t=0.25
	var me=spiel.auto if spiel.auto!=null else spiel.spieler
	if me==null:return
	var p=Vector2(me.global_position.x,me.global_position.z)
	var h=spiel.zeit/60.0;var nacht=h<6.0 or h>=21.5
	var stadt=0.0
	for c in STADT:stadt=max(stadt,1.0-clamp(p.distance_to(c)/900.0,0.0,1.0))
	var strand=0.0
	for c in STRAND:strand=max(strand,1.0-clamp(p.distance_to(c)/260.0,0.0,1.0))
	var hoehe=me.global_position.y
	_lauter("voegel",(1.0-stadt*0.7)*(0.0 if nacht else 0.6))
	_lauter("wind",0.25+clamp(hoehe/250.0,0.0,0.6))
	_lauter("wellen",strand*0.9)
	for e in _orte:
		var a:AudioStreamPlayer3D=e[0];var q:Vector2=e[1]
		var nah=p.distance_to(q)<a.max_distance+20.0
		if nah and not a.playing:
			var y=spiel.welt.G.h_at(q.x,q.y)+2.0
			a.global_position=Vector3(q.x,y,q.y);a.play()
		elif not nah and a.playing:a.stop()
	var amb=spiel.get_node_or_null("Umgebung")
	if amb:amb.volume_db=lerp(-30.0,3.0,stadt)*(0.85 if nacht else 1.0)

func _lauter(n:String,f:float):
	var a:AudioStreamPlayer=_p[n]
	a.volume_db=lerp(a.volume_db,linear_to_db(max(f,0.0005)),0.5)

# einmalige Signale an einer Stelle (Hupe, Sirene)
func signal_bei(art:String,pos:Vector3):
	var a=AudioStreamPlayer3D.new();a.stream=_hupe() if art=="hupe" else _sirene();a.max_distance=120.0;a.unit_size=10.0
	add_child(a);a.global_position=pos;a.play();a.finished.connect(a.queue_free)

# ---------- Klangerzeugung ----------
static var _cache:={}
func _wav(name:String,dauer:float,f:Callable,schleife:=true)->AudioStreamWAV:
	if _cache.has(name):return _cache[name]
	var n=int(dauer*RATE);var d=PackedByteArray();d.resize(n*2)
	for i in n:d.encode_s16(i*2,int(clamp(f.call(float(i)/RATE,i),-1.0,1.0)*26000))
	var st=AudioStreamWAV.new();st.format=AudioStreamWAV.FORMAT_16_BITS;st.mix_rate=RATE;st.data=d
	if schleife:st.loop_mode=AudioStreamWAV.LOOP_FORWARD;st.loop_end=n
	_cache[name]=st;return st
func _voegel()->AudioStreamWAV:
	var r=RandomNumberGenerator.new();r.seed=5
	var rufe=[]
	for k in 14:rufe.append([r.randf()*7.5,r.randf_range(2200,4200),r.randf_range(0.06,0.16)])
	var f=func(t,_i):
		var v=0.0
		for c in rufe:
			var u=t-c[0]
			if u>0.0 and u<c[2]:v+=sin(TAU*(c[1]+900.0*sin(u*60.0))*u)*sin(PI*u/c[2])*0.35
		return v
	return _wav("voegel",8.0,f)
func _wind()->AudioStreamWAV:
	var r=RandomNumberGenerator.new();r.seed=9;var lp=[0.0,0.0]
	var f=func(t,_i):
		lp[0]+=(r.randf_range(-1,1)-lp[0])*0.02;lp[1]+=(lp[0]-lp[1])*0.02
		return lp[1]*6.0*(0.6+0.4*sin(TAU*t/6.0))
	return _wav("wind",6.0,f)
func _wellen()->AudioStreamWAV:
	var r=RandomNumberGenerator.new();r.seed=3;var lp=[0.0]
	var f=func(t,_i):
		lp[0]+=(r.randf_range(-1,1)-lp[0])*0.08
		var env=pow(max(sin(PI*t/4.0),0.0),3.0)
		return lp[0]*1.6*(0.15+env)
	return _wav("wellen",8.0,f)
func _musik()->AudioStreamWAV:
	# einfacher Club-Takt: Bassdrum, Bass, Akkord (120 BPM)
	var akk=[220.0,261.6,329.6]
	var f=func(t,_i):
		var b=fmod(t,0.5);var kick=sin(TAU*(55.0+120.0*exp(-b*30.0))*b)*exp(-b*12.0)
		var bass=sin(TAU*[55.0,55.0,73.4,65.4][int(t/1.0)%4]*t)*0.35
		var ak=0.0
		for q in akk:ak+=sin(TAU*q*t)*0.08
		return kick*0.7+bass+ak*(1.0 if fmod(t,1.0)>0.5 else 0.3)
	return _wav("musik",4.0,f)
func _baustelle()->AudioStreamWAV:
	var r=RandomNumberGenerator.new();r.seed=4
	var f=func(t,_i):
		var u=fmod(t,0.75)
		var schlag=r.randf_range(-1,1)*exp(-u*40.0)*0.8+sin(TAU*900.0*u)*exp(-u*60.0)*0.4
		var bohr=sin(TAU*180.0*t)*0.12*(1.0 if t>1.8 else 0.0)
		return schlag+bohr
	return _wav("bau",3.0,f)
func _hupe()->AudioStreamWAV:
	var f=func(t,_i):
		var e=min(t*30.0,1.0)*min((0.6-t)*30.0,1.0)
		return (sign(sin(TAU*415.0*t))*0.25+sign(sin(TAU*523.0*t))*0.25)*e
	return _wav("hupe",0.6,f,false)
func _sirene()->AudioStreamWAV:
	var f=func(t,_i):
		var q=660.0 if fmod(t,1.0)<0.5 else 880.0
		return sin(TAU*q*t)*0.5*min(t*10.0,1.0)*min((3.0-t)*10.0,1.0)
	return _wav("sirene",3.0,f,false)
