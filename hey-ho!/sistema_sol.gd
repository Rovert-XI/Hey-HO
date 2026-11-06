class_name SistemaSol
extends Node

signal cambio_noche(es_noche: bool)

@export var sol: DirectionalLight3D
@export var entorno: WorldEnvironment
@export var energia_sol := 1.0
@export var azimut := -30.0
@export var ambiente_dia := 1.0
@export var ambiente_noche := 0.2
@export var rojo_peligro := Color("#D63A3A")

@onready var ciclo: CicloDia = $CicloDia

var era_noche := false
var peligro := 0.0
var apagado := 1.0

func _ready() -> void:
	aplicar_hora()
	era_noche = CicloDia.factor_sol(ciclo.hora) <= 0.0

func _process(delta: float) -> void:
	ciclo.avanzar(delta)
	aplicar_hora()
	var es_noche := CicloDia.factor_sol(ciclo.hora) <= 0.0
	if es_noche != era_noche:
		era_noche = es_noche
		cambio_noche.emit(es_noche)

func aplicar_hora() -> void:
	var h := ciclo.hora
	var f := CicloDia.factor_sol(h)
	sol.rotation_degrees = Vector3(-CicloDia.elevacion(h), azimut, 0.0)
	sol.light_energy = energia_sol * f * (1.0 - 0.3 * peligro) * apagado
	sol.light_color = CicloDia.color_sol(h).lerp(rojo_peligro, 0.4 * peligro)
	entorno.environment.ambient_light_energy = lerpf(ambiente_noche, ambiente_dia, f)

static func peligro_soga(resistencia: float) -> float:
	return clampf((30.0 - resistencia) / 30.0, 0.0, 1.0)

func poner_peligro(resistencia_min: float) -> void:
	peligro = peligro_soga(resistencia_min)

func anunciar_derrota() -> void:
	var t := create_tween()
	t.tween_property(self, "apagado", 0.0, 2.0)
	cambio_noche.emit(true)

static func _normalizar(v: Vector3) -> Vector3:
	var largo := sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
	if largo == 0.0:
		return Vector3.ZERO
	return v / largo

static func lambert(normal: Vector3, hacia_luz: Vector3) -> float:
	var n := _normalizar(normal)
	var l := _normalizar(hacia_luz)
	return maxf(0.0, n.dot(l))

func prediccion_piso() -> float:
	var hacia_luz := sol.global_transform.basis.z
	return sol.light_energy * sol.light_color.r * lambert(Vector3.UP, hacia_luz)
