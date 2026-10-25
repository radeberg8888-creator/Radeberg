extends Node
# Eingaben aus allen Quellen zusammenführen: Touchscreen (über das HUD), Handy-Neigung (Lenken),
# Xbox-/Bluetooth-Controller und Tastatur/Maus (zum Testen am PC).
# Werte werden jedes Bild neu berechnet; Aktionen (Knopfdruck) werden über pressed(name) abgefragt.

signal aktion(name:String)

# --- Einstellungen (werden gespeichert) ---
var e:={
	"lenkung":"stick",       # stick | neigen
	"neig_empf":1.0,         # Neigungs-Empfindlichkeit
	"neig_umkehren":false,
	"kamera_empf":1.0,
	"kamera_invert_y":false,
	"sichtweite":1,          # 0 niedrig, 1 mittel, 2 hoch
	"schatten":true,
	"vibration":true,
	"hud_groesse":1.0,
}
const DATEI:="user://einstellungen.json"

# --- Touch-Werte (vom HUD gesetzt) ---
var t_move:=Vector2.ZERO
var t_look:=Vector2.ZERO
var t_gas:=0.0
var t_brake:=0.0
var t_hand:=false
var t_nos:=false
var t_sprint:=false

# --- Ergebnis ---
var move:=Vector2.ZERO     # x rechts, y vorwärts
var look:=Vector2.ZERO     # Kameradrehung in Grad für dieses Bild
var steer:=0.0             # -1 links .. +1 rechts
var gas:=0.0
var brake:=0.0
var handbrake:=false
var nos:=false
var sprint:=false
var controller:=false      # ein Controller ist verbunden
var neigung_null:=Vector3(0,-9.8,0)   # kalibrierte Ruhelage
var _pressed:={}

func _ready():
	process_priority=-100
	laden()
	_actions()
	Input.joy_connection_changed.connect(func(_d,_c):controller=Input.get_connected_joypads().size()>0)
	controller=Input.get_connected_joypads().size()>0

func laden():
	var f=FileAccess.open(DATEI,FileAccess.READ)
	if f:
		var d=JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			for k in d:e[k]=d[k]
			if d.has("neigung_null"):var n=d.neigung_null;neigung_null=Vector3(n[0],n[1],n[2])
func speichern():
	var d=e.duplicate();d["neigung_null"]=[neigung_null.x,neigung_null.y,neigung_null.z]
	var f=FileAccess.open(DATEI,FileAccess.WRITE);f.store_string(JSON.stringify(d," "));f.close()

func kalibrieren():
	var g=Input.get_gravity()
	if g.length()>1.0:neigung_null=g
	speichern()

# Tastenbelegung (Tastatur + Xbox-Controller)
func _actions():
	var A={
		"vor":[KEY_W],"zurueck":[KEY_S],"links":[KEY_A],"rechts":[KEY_D],
		"springen":[KEY_SPACE,JOY_BUTTON_A],"einsteigen":[KEY_F,KEY_E,JOY_BUTTON_Y],"karte":[KEY_M,JOY_BUTTON_BACK],
		"pause":[KEY_ESCAPE,KEY_P,JOY_BUTTON_START],"hupe":[KEY_H,JOY_BUTTON_LEFT_STICK],"kamera":[KEY_C,JOY_BUTTON_RIGHT_STICK],
		"handbremse":[KEY_SPACE,JOY_BUTTON_RIGHT_SHOULDER],"nos":[KEY_SHIFT,JOY_BUTTON_X],"sprinten":[KEY_SHIFT,JOY_BUTTON_B],
		"job":[KEY_J,JOY_BUTTON_DPAD_UP],"interagieren":[KEY_E,JOY_BUTTON_DPAD_RIGHT],
	}
	for a in A:
		if InputMap.has_action(a):InputMap.erase_action(a)
		InputMap.add_action(a,0.2)
		for k in A[a]:
			var ev
			if k>=KEY_SPACE:ev=InputEventKey.new();ev.physical_keycode=k
			else:ev=InputEventJoypadButton.new();ev.button_index=k
			InputMap.action_add_event(a,ev)
	# Pfeiltasten zusätzlich
	for p in [["vor",KEY_UP],["zurueck",KEY_DOWN],["links",KEY_LEFT],["rechts",KEY_RIGHT]]:
		var ev=InputEventKey.new();ev.physical_keycode=p[1];InputMap.action_add_event(p[0],ev)

func trigger(name:String):
	_pressed[name]=true;aktion.emit(name)

# Einmalig abfragen (gilt für das aktuelle Bild)
func pressed(name:String)->bool:
	if _pressed.get(name,false):return true
	return InputMap.has_action(name) and Input.is_action_just_pressed(name)

func _process(dt):
	# Controller-Achsen
	var ls=Vector2(Input.get_joy_axis(0,JOY_AXIS_LEFT_X),-Input.get_joy_axis(0,JOY_AXIS_LEFT_Y)) if controller else Vector2.ZERO
	var rs=Vector2(Input.get_joy_axis(0,JOY_AXIS_RIGHT_X),Input.get_joy_axis(0,JOY_AXIS_RIGHT_Y)) if controller else Vector2.ZERO
	if ls.length()<0.15:ls=Vector2.ZERO
	if rs.length()<0.15:rs=Vector2.ZERO
	var kb=Vector2(Input.get_action_strength("rechts")-Input.get_action_strength("links"),Input.get_action_strength("vor")-Input.get_action_strength("zurueck"))
	move=t_move+ls+kb
	if move.length()>1.0:move=move.normalized()
	var inv=-1.0 if e.kamera_invert_y else 1.0
	look=(t_look*0.25+rs*160.0*dt+_mouse)*e.kamera_empf*Vector2(1.0,inv)
	_mouse=Vector2.ZERO;t_look=Vector2.ZERO
	# Lenkung
	var st=t_move.x+ls.x+kb.x
	if e.lenkung=="neigen" and not controller:st=_tilt()+kb.x
	steer=clamp(st,-1.0,1.0)
	var rt=Input.get_joy_axis(0,JOY_AXIS_TRIGGER_RIGHT) if controller else 0.0
	var lt=Input.get_joy_axis(0,JOY_AXIS_TRIGGER_LEFT) if controller else 0.0
	gas=clamp(t_gas+rt+Input.get_action_strength("vor"),0.0,1.0)
	brake=clamp(t_brake+lt+Input.get_action_strength("zurueck"),0.0,1.0)
	handbrake=t_hand or Input.is_action_pressed("handbremse")
	nos=t_nos or Input.is_action_pressed("nos")
	sprint=t_sprint or Input.is_action_pressed("sprinten") or move.length()>0.92

func _physics_process(_d):
	pass

func _input(ev):
	if ev is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		_mouse+=ev.relative*0.15
var _mouse:=Vector2.ZERO

func end_frame():
	_pressed.clear()

# Lenkwinkel aus der Handy-Neigung: Drehung um die Bildschirmachse gegenüber der kalibrierten Lage
func _tilt()->float:
	var g=Input.get_gravity()
	if g.length()<1.0:return 0.0
	var a0=atan2(neigung_null.x,neigung_null.y);var a1=atan2(g.x,g.y)
	var d=wrapf(a1-a0,-PI,PI)
	var s=d/deg_to_rad(28.0)*e.neig_empf
	if e.neig_umkehren:s=-s
	if abs(s)<0.04:s=0.0
	return clamp(s,-1.0,1.0)
