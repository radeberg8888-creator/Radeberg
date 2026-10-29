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
	_auswahl()

# ---------- Spieldaten aus dem Download-Ordner übernehmen (Teile vorher im Browser laden) ----------
const ORDNER:=["/storage/emulated/0/Download/","/storage/emulated/0/Downloads/","/sdcard/Download/"]
const RECHT:="android.permission.MANAGE_EXTERNAL_STORAGE"
var _warte_recht:=false
func _auswahl():
	balken.value=0.0
	text.text="Spieldaten fehlen (Version %s).\n\nLade im Browser auf der GitHub-Seite dieser Version die %d Dateien radeberg_daten.part00 … part%02d herunter (in den Download-Ordner) und tippe dann auf „Aus Download-Ordner übernehmen“."%[str(info.build),info.teile.size(),info.teile.size()-1]
	knopf.text="Aus Download-Ordner übernehmen";knopf.visible=true
	for c in knopf.pressed.get_connections():knopf.pressed.disconnect(c.callable)
	knopf.pressed.connect(_uebernehmen)
	if knopf2==null:
		knopf2=Button.new();knopf2.custom_minimum_size=Vector2(420,70);knopf2.add_theme_font_size_override("font_size",24);knopf.get_parent().add_child(knopf2)
		knopf2.pressed.connect(func():knopf.visible=false;knopf2.visible=false;_herunterladen())
	knopf2.text="Stattdessen online laden";knopf2.visible=true
var knopf2:Button

func _recht_da()->bool:
	if OS.get_name()!="Android":return true
	return RECHT in OS.get_granted_permissions()

func _notification(what):
	if what==NOTIFICATION_APPLICATION_RESUMED and _warte_recht:
		_warte_recht=false;_uebernehmen()

func _uebernehmen():
	if not _recht_da():
		text.text="Bitte im nächsten Fenster „Zugriff auf alle Dateien“ für Radeberg erlauben und dann zurückkehren."
		_warte_recht=true;OS.request_permission(RECHT);return
	var dir=""
	var fehlt=[]
	for d in ORDNER:
		fehlt=[]
		for t in info.teile:
			var f=FileAccess.open(d+t.name,FileAccess.READ)
			if f==null or f.get_length()!=int(t.groesse):fehlt.append(t.name)
		if fehlt.is_empty():dir=d;break
	if dir=="":
		text.text="Im Download-Ordner fehlen noch (oder sind unvollständig):\n"+", ".join(fehlt)+"\n\nBitte herunterladen und erneut tippen."
		return
	knopf.visible=false
	if knopf2:knopf2.visible=false
	var aus=FileAccess.open(TMP,FileAccess.WRITE)
	if aus==null:_fehler("Kein Speicherplatz frei? Es werden etwa %s benötigt."%_mb(gesamt));return
	var fertig=0
	for t in info.teile:
		var ein=FileAccess.open(dir+t.name,FileAccess.READ)
		while ein.get_position()<ein.get_length():
			aus.store_buffer(ein.get_buffer(8*1048576))
			if aus.get_error()!=OK:_fehler("Speichern fehlgeschlagen (Speicher voll?).");return
			fertig+=0
			balken.value=float(fertig_bytes_lokal(aus))/max(gesamt,1)
			text.text="Spieldaten werden übernommen … %s von %s"%[_mb(aus.get_position()),_mb(gesamt)]
			await get_tree().process_frame
		ein.close()
	aus.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(TMP),ProjectSettings.globalize_path(ZIEL))
	var okf=FileAccess.open(OK_DATEI,FileAccess.WRITE);okf.store_string(str(info.build));okf.close()
	text.text="Fertig! Die Dateien radeberg_daten.part… im Download-Ordner kannst du jetzt löschen."
	await get_tree().create_timer(3.0).timeout
	_starten()
func fertig_bytes_lokal(f:FileAccess)->int:return f.get_position()

func _ui():
	var bg=ColorRect.new();bg.color=Color(0.07,0.07,0.09);add_child(bg);bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cc=CenterContainer.new();add_child(cc);cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v=VBoxContainer.new();v.add_theme_constant_override("separation",22);cc.add_child(v)
	titel=Label.new();titel.text="RADEBERG";titel.add_theme_font_size_override("font_size",72);titel.add_theme_color_override("font_color",Color(0.98,0.82,0.3));titel.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;v.add_child(titel)
	text=Label.new();text.text="Wird vorbereitet …";text.add_theme_font_size_override("font_size",26);text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;text.custom_minimum_size=Vector2(760,0);text.autowrap_mode=TextServer.AUTOWRAP_WORD;v.add_child(text)
	balken=ProgressBar.new();balken.custom_minimum_size=Vector2(760,34);balken.max_value=1.0;balken.step=0.0001;v.add_child(balken)
	knopf=Button.new();knopf.text="Erneut versuchen";knopf.custom_minimum_size=Vector2(420,80);knopf.add_theme_font_size_override("font_size",30);knopf.visible=false;v.add_child(knopf)
	knopf.pressed.connect(func():knopf.visible=false;_herunterladen())
	# Hinweis: _auswahl() verbindet den Knopf später neu

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
	text.text=t
	if info.has("teile"):_auswahl();text.text=t+"\n\n"+text.text
	else:knopf.visible=true
