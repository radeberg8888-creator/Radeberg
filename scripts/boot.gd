extends Control
# Startprogramm der Handy-App: lädt beim ersten Start (und nach Updates) die Spieldaten aus dem GitHub-Release
# in Teilen herunter, setzt sie zu einer Datei zusammen und startet dann das Spiel.
# Grund: Android installiert sehr große APKs nicht zuverlässig, die App selbst bleibt deshalb klein.
const ZIEL:="user://daten.pck"
const TMP:="user://daten.pck.tmp"
const TEIL:="user://teil.tmp"
const OK_DATEI:="user://daten_build.txt"
const FORTSCHRITT:="user://daten_fortschritt.txt"
var info:Dictionary
var titel:Label;var text:Label;var balken:ProgressBar;var knopf:Button
var http:HTTPRequest
var gesamt:=0;var fertig_bytes:=0;var teil_groesse:=0

func _ready():
	_ui()
	var f=FileAccess.open("res://build_info.json",FileAccess.READ)
	if f==null:
		# am PC / im Editor sind alle Daten schon da
		get_tree().change_scene_to_file.call_deferred("res://scenes/spiel.tscn");return
	info=JSON.parse_string(f.get_as_text())
	for t in info.teile:gesamt+=int(t.groesse)
	if FileAccess.file_exists(ZIEL) and FileAccess.get_file_as_string(OK_DATEI).strip_edges()==str(info.build):
		_starten();return
	_herunterladen()

func _ui():
	var bg=ColorRect.new();bg.color=Color(0.07,0.07,0.09);add_child(bg);bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cc=CenterContainer.new();add_child(cc);cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v=VBoxContainer.new();v.add_theme_constant_override("separation",22);cc.add_child(v)
	titel=Label.new();titel.text="RADEBERG";titel.add_theme_font_size_override("font_size",72);titel.add_theme_color_override("font_color",Color(0.98,0.82,0.3));titel.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;v.add_child(titel)
	text=Label.new();text.text="Wird vorbereitet …";text.add_theme_font_size_override("font_size",26);text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;text.custom_minimum_size=Vector2(760,0);text.autowrap_mode=TextServer.AUTOWRAP_WORD;v.add_child(text)
	balken=ProgressBar.new();balken.custom_minimum_size=Vector2(760,34);balken.max_value=1.0;balken.step=0.0001;v.add_child(balken)
	knopf=Button.new();knopf.text="Erneut versuchen";knopf.custom_minimum_size=Vector2(420,80);knopf.add_theme_font_size_override("font_size",30);knopf.visible=false;v.add_child(knopf)
	knopf.pressed.connect(func():knopf.visible=false;_herunterladen())

func _mb(b:int)->String:return "%d MB"%int(b/1048576)

func _herunterladen():
	# Fortschritt eines abgebrochenen Downloads weiterverwenden
	var start_teil=0
	var fs=FileAccess.get_file_as_string(FORTSCHRITT).strip_edges().split(" ")
	if fs.size()==2 and fs[0]==str(info.build) and FileAccess.file_exists(TMP):
		start_teil=int(fs[1])
		var soll=0
		for k in start_teil:soll+=int(info.teile[k].groesse)
		var tf=FileAccess.open(TMP,FileAccess.READ)
		if tf==null or tf.get_length()!=soll:start_teil=0
	if start_teil==0:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ZIEL))
		var neu=FileAccess.open(TMP,FileAccess.WRITE)
		if neu==null:_fehler("Kein Speicherplatz frei? Es werden etwa %s benötigt."%_mb(gesamt*2));return
		neu.close()
	fertig_bytes=0
	for k in start_teil:fertig_bytes+=int(info.teile[k].groesse)
	for k in range(start_teil,info.teile.size()):
		var t=info.teile[k];teil_groesse=int(t.groesse)
		var ok=false
		for versuch in 5:
			if await _teil_laden(info.url+t.name,teil_groesse,k):ok=true;break
			text.text="Verbindung unterbrochen – neuer Versuch (%d/5) …"%(versuch+2)
			await get_tree().create_timer(2.0).timeout
		if not ok:_fehler("Download fehlgeschlagen. Bitte WLAN prüfen und erneut versuchen.");return
		# Teil an die Datendatei anhängen
		text.text="Teil %d von %d wird gespeichert …"%[k+1,info.teile.size()]
		await get_tree().process_frame
		var aus=FileAccess.open(TMP,FileAccess.READ_WRITE);var ein=FileAccess.open(TEIL,FileAccess.READ)
		if aus==null or ein==null:_fehler("Speichern fehlgeschlagen (Speicher voll?).");return
		aus.seek_end()
		while ein.get_position()<ein.get_length():
			aus.store_buffer(ein.get_buffer(8*1048576))
			if aus.get_error()!=OK:_fehler("Speichern fehlgeschlagen (Speicher voll?).");return
		aus.close();ein.close();DirAccess.remove_absolute(ProjectSettings.globalize_path(TEIL))
		fertig_bytes+=teil_groesse
		var pf=FileAccess.open(FORTSCHRITT,FileAccess.WRITE);pf.store_string("%s %d"%[str(info.build),k+1]);pf.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(TMP),ProjectSettings.globalize_path(ZIEL))
	var okf=FileAccess.open(OK_DATEI,FileAccess.WRITE);okf.store_string(str(info.build));okf.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FORTSCHRITT))
	_starten()

func _teil_laden(url:String,groesse:int,k:int)->bool:
	if http:http.queue_free()
	http=HTTPRequest.new();http.use_threads=true;http.download_file=TEIL;http.max_redirects=10;http.download_chunk_size=1048576
	add_child(http)
	if http.request(url)!=OK:return false
	var fertig=[false,0,0]
	http.request_completed.connect(func(res,code,_h,_b):fertig[0]=true;fertig[1]=res;fertig[2]=code)
	while not fertig[0]:
		var jetzt=fertig_bytes+http.get_downloaded_bytes()
		balken.value=float(jetzt)/max(gesamt,1)
		text.text="Spieldaten werden heruntergeladen (einmalig, bitte im WLAN) – Teil %d von %d\n%s von %s"%[k+1,info.teile.size(),_mb(jetzt),_mb(gesamt)]
		await get_tree().create_timer(0.25).timeout
	if fertig[1]!=HTTPRequest.RESULT_SUCCESS or fertig[2]!=200:return false
	var f=FileAccess.open(TEIL,FileAccess.READ)
	return f!=null and f.get_length()==groesse

func _starten():
	text.text="Spiel wird gestartet …";balken.value=1.0
	await get_tree().process_frame
	if not ProjectSettings.load_resource_pack(ZIEL):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OK_DATEI))
		_fehler("Spieldaten beschädigt – bitte erneut herunterladen.");return
	get_tree().change_scene_to_file("res://scenes/spiel.tscn")

func _fehler(t:String):
	text.text=t;knopf.visible=true
