extends Node
# Motorsound aus zwei Schleifen je Fahrzeugklasse (Leerlauf / hohe Drehzahl, tools/sounds_gen.py),
# Tonhöhe folgt der Drehzahl, Gangwechsel, Überblendung zwischen den Schleifen. Dazu Hupe.
const KLASSE:={"c_jdm":"vier","c_kompakt":"vier","c_e30":"vier","c_luxus":"v8","c_muscle":"v8","c_suv":"diesel","c_trabant":"trabant","c_wartburg":"wartburg","c_taxi":"vier","c_polizei":"vier","c_sport":"v8","c_rtw":"diesel","c_feuerwehr":"diesel"}
const DREH:={"trabant":[900.0,4500.0,4],"wartburg":[850.0,4800.0,4],"vier":[800.0,6000.0,5],"v8":[850.0,7500.0,6],"diesel":[650.0,2600.0,5],
	"turbo6":[900.0,7800.0,5],"reihe6":[850.0,7000.0,5],"kompakt4":[900.0,6800.0,5],"v8leise":[650.0,6000.0,6],"v8gross":[750.0,6500.0,4],"v6diesel":[700.0,4500.0,6]}
const VMAX:={"trabant":125.0,"wartburg":145.0,"vier":180.0,"v8":290.0,"diesel":120.0,"turbo6":235.0,"reihe6":205.0,"kompakt4":180.0,"v8leise":215.0,"v8gross":225.0,"v6diesel":175.0}
var lo:AudioStreamPlayer;var hi:AudioStreamPlayer;var horn:AudioStreamPlayer
var klasse:=""
var rpm:=800.0
var lautst:=0.0
var hupe:=0.0
static var _cache:={}

static func klasse_von(kind:String)->String:
	var CA=load("res://scripts/comic/comic_autos.gd")
	if CA.LISTE.has(kind) and CA.LISTE[kind].size()>3 and ResourceLoader.exists("res://assets/sounds/motor_%s_leer.wav"%CA.LISTE[kind][3]):return CA.LISTE[kind][3]
	for k in KLASSE:
		if kind.begins_with(k):return KLASSE[k]
	return "vier"
static func schleife(name:String)->AudioStream:
	if not _cache.has(name):
		var s=load("res://assets/sounds/"+name+".wav") as AudioStreamWAV
		if s:s=s.duplicate();s.loop_mode=AudioStreamWAV.LOOP_FORWARD;s.loop_begin=0;s.loop_end=int(s.get_length()*s.mix_rate)
		_cache[name]=s
	return _cache[name]

func _ready():
	lo=AudioStreamPlayer.new();hi=AudioStreamPlayer.new();horn=AudioStreamPlayer.new()
	for p in [lo,hi,horn]:add_child(p)
	var g=AudioStreamGenerator.new();g.mix_rate=22050
	horn.stream=_hupton()

func waehle(kind:String):
	var k=klasse_von(kind)
	if k==klasse:return
	klasse=k;lo.stream=schleife("motor_%s_leer"%k);hi.stream=schleife("motor_%s_hoch"%k)

func setze(kmh:float,gas:float,an:bool):
	if klasse=="":waehle("c_trabant")
	var d=DREH.get(klasse,DREH.vier);var leer:float=d[0];var maxr:float=d[1];var gaenge:int=d[2]
	# Gang aus Geschwindigkeit, Drehzahl im Gang
	var vmax=VMAX.get(klasse,180.0)
	var g=clamp(kmh/vmax*gaenge,0.0,gaenge-0.001);var gi=int(g);var f=g-gi
	var ziel=leer+(maxr-leer)*(0.28+0.72*f)*(0.8+0.2*float(gi)/gaenge) if kmh>3.0 else leer+gas*(maxr*0.5-leer)
	rpm=lerp(rpm,ziel,0.18)
	lautst=lerp(lautst,(0.55+gas*0.45) if an else 0.0,0.12)
	var hoch_r=maxr*0.65
	var m=clamp((rpm-leer)/(hoch_r-leer),0.0,1.0)
	lo.pitch_scale=clamp(rpm/leer,0.5,4.0);hi.pitch_scale=clamp(rpm/hoch_r,0.3,2.5)
	lo.volume_db=linear_to_db(max(lautst*(1.0-m),0.0001))-4.0;hi.volume_db=linear_to_db(max(lautst*m*(0.8+0.2*gas),0.0001))-4.0
	if an and not lo.playing:lo.play();hi.play()
	if not an and lautst<0.01 and lo.playing:lo.stop();hi.stop()

func _process(dt):
	if hupe>0.0:
		if not horn.playing:horn.play()
		hupe-=dt
	elif horn.playing:horn.stop()

static func _hupton()->AudioStreamWAV:
	var rate=22050;var n=int(rate*0.5);var data=PackedByteArray();data.resize(n*2)
	for i in n:
		var t=float(i)/rate
		var v=(0.5 if fmod(t*415.0,1.0)<0.5 else -0.5)+(0.4 if fmod(t*523.0,1.0)<0.5 else -0.4)
		data.encode_s16(i*2,int(clamp(v*0.45,-1.0,1.0)*32767))
	var s=AudioStreamWAV.new();s.format=AudioStreamWAV.FORMAT_16_BITS;s.mix_rate=rate;s.data=data
	s.loop_mode=AudioStreamWAV.LOOP_FORWARD;s.loop_end=n
	return s
