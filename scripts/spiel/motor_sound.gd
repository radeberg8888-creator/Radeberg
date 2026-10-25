extends AudioStreamPlayer
# Synthetischer Motorsound (keine Audiodateien nötig): Sägezahn + Rauschen, Tonhöhe folgt Drehzahl/Gang.
var gen:AudioStreamGeneratorPlayback
var phase:=0.0
var phase2:=0.0
var freq:=40.0
var last:=0.0
var lautst:=0.0
var hupe:=0.0
var rate:=22050.0

func _ready():
	var g=AudioStreamGenerator.new();g.mix_rate=rate;g.buffer_length=0.12;stream=g
	volume_db=-8.0;play();gen=get_stream_playback()

func setze(kmh:float,gas:float,an:bool):
	# einfache Gangstufen
	var g=[0,25,50,80,115,155,999]
	var i=0
	while kmh>g[i+1] and i<5:i+=1
	var rel=(kmh-g[i])/max(1.0,g[i+1]-g[i]) if i<5 else min(kmh/250.0,1.0)
	var rpm=900.0+rel*4800.0+gas*500.0
	freq=lerp(freq,rpm/60.0*2.0,0.25)
	lautst=lerp(lautst,(0.25+gas*0.5) if an else 0.0,0.15)

func _process(_d):
	if gen==null:return
	var n=gen.get_frames_available()
	var inc=freq/rate
	for k in n:
		phase=fmod(phase+inc,1.0)
		var saw=phase*2.0-1.0
		var s=saw*0.55+sin(phase*TAU*0.5)*0.35+randf_range(-0.12,0.12)
		if hupe>0.0:
			phase2=fmod(phase2+420.0/rate,1.0)
			s=s*0.3+(0.6 if phase2<0.5 else -0.6)
		last=lerp(last,s,0.35)
		gen.push_frame(Vector2.ONE*last*(lautst*0.5+(0.35 if hupe>0.0 else 0.0)))
	if hupe>0.0:hupe-=_d
