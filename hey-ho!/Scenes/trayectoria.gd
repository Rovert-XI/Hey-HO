extends Node3D

@export var cantidad_puntos := 24
@export var paso_tiempo := 0.05
@export var radio_punto := 0.06
@export var gravedad_y := -9.8

var _puntos: Array[MeshInstance3D] = []

func _ready() -> void:
	visible = false
	var malla := SphereMesh.new()
	malla.radius = radio_punto
	malla.height = radio_punto * 2.0

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for i in range(cantidad_puntos):
		var punto := MeshInstance3D.new()
		punto.mesh = malla
		punto.material_override = mat
		punto.visible = false
		add_child(punto)
		_puntos.append(punto)

func mostrar_trayectoria(origen: Vector3, velocidad_inicial: Vector3) -> void:
	visible = true
	for i in range(_puntos.size()):
		var t := float(i + 1) * paso_tiempo
		var pos := origen + velocidad_inicial * t
		pos.y += 0.5 * gravedad_y * t * t
		_puntos[i].global_position = pos
		_puntos[i].visible = true

func ocultar_trayectoria() -> void:
	visible = false
	for punto in _puntos:
		punto.visible = false
