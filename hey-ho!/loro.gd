class_name Loro
extends Node3D

signal aviso_graznido(gancho: int)
signal loro_llego(gancho: int)
signal prenda_robada(gancho: int)
signal loro_huyo(gancho: int)

const T_AVISO := 11.0
const T_LLEGADA := 20.0
const T_ROBO := 3.0
const T_SOMBRA := 3.0

@export var posiciones_gancho: Array[Vector3] = [
	Vector3(5, 0.9, 2.9), Vector3(6, 0.9, 2.9), Vector3(7, 0.9, 2.9)]
@export var modo_prueba := true

var edad := {}
var avisado := {}
var a_salvo := {}
var en_gancho := -1
var t_en_gancho := 0.0
var cuerpo: MeshInstance3D
var sombra: MeshInstance3D
var _id_sombra := 0

func _ready() -> void:
	_crear_visual()
	if modo_prueba:
		aviso_graznido.connect(func(g): print("graznido: gancho ", g))
		loro_llego.connect(func(g): print("loro llegó al gancho ", g))
		prenda_robada.connect(func(g): print("prenda robada del gancho ", g))
		loro_huyo.connect(func(g): print("loro huyó del gancho ", g))

func prenda_tendida(gancho: int) -> void:
	edad[gancho] = 0.0
	avisado[gancho] = false
	a_salvo[gancho] = false

func prenda_retirada(gancho: int) -> void:
	edad.erase(gancho)
	if en_gancho == gancho:
		_irse()

func piedra_acerto() -> void:
	if en_gancho == -1:
		return
	var g := en_gancho
	a_salvo[g] = true
	_irse()
	loro_huyo.emit(g)

func _process(delta: float) -> void:
	for g: int in edad.keys():
		edad[g] += delta
		if not avisado[g] and edad[g] >= T_AVISO:
			avisado[g] = true
			_mostrar_sombra(g)
			aviso_graznido.emit(g)
		if en_gancho == -1 and not a_salvo[g] and edad[g] >= T_LLEGADA:
			_llegar(g)
	if en_gancho != -1:
		t_en_gancho += delta
		if t_en_gancho >= T_ROBO:
			_robar()

func _mostrar_sombra(g: int) -> void:
	var pos := posiciones_gancho[g]
	sombra.position = Vector3(pos.x, 0.02, pos.z)
	sombra.visible = true
	_id_sombra += 1
	get_tree().create_timer(T_SOMBRA).timeout.connect(_ocultar_sombra.bind(_id_sombra))

func _ocultar_sombra(id: int) -> void:
	if id == _id_sombra:
		sombra.visible = false

func _llegar(g: int) -> void:
	en_gancho = g
	t_en_gancho = 0.0
	cuerpo.position = posiciones_gancho[g]
	cuerpo.visible = true
	loro_llego.emit(g)

func _robar() -> void:
	var g := en_gancho
	edad.erase(g)
	_irse()
	prenda_robada.emit(g)

func _irse() -> void:
	en_gancho = -1
	t_en_gancho = 0.0
	cuerpo.visible = false

func _crear_visual() -> void:
	cuerpo = MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.25
	esfera.height = 0.5
	cuerpo.mesh = esfera
	var rojo := StandardMaterial3D.new()
	rojo.albedo_color = Color("#D63A3A")
	cuerpo.material_override = rojo
	cuerpo.visible = false
	add_child(cuerpo)
	sombra = MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = 0.5
	disco.bottom_radius = 0.5
	disco.height = 0.02
	sombra.mesh = disco
	var oscuro := StandardMaterial3D.new()
	oscuro.albedo_color = Color(0, 0, 0, 0.6)
	oscuro.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sombra.material_override = oscuro
	sombra.visible = false
	add_child(sombra)

func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if not modo_prueba or k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_6: prenda_tendida(0)
		KEY_7: prenda_retirada(0)
		KEY_8: piedra_acerto()
		KEY_J: print("prendas: ", edad, " | loro en gancho: ", en_gancho, " | tiempo en gancho: ", snappedf(t_en_gancho, 0.1))
