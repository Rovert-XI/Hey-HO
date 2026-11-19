class_name SistemaEventos
extends Node

@export var luz_evento: OmniLight3D
@export var pico_destello := 4.0
@export var k_destello := 6.0 # 1/s: qué tan rápido se apaga

func _ready() -> void:
	for d in get_tree().get_nodes_in_group("disparadores"):
		d.evento.connect(_on_evento)
	luz_evento.light_energy = 0.0
	
	# Configuramos el color de alerta con el tono de peligro de la paleta (#D63A3A)
	luz_evento.light_color = Color("#D63A3A")

func _process(delta: float) -> void:
	luz_evento.light_energy = decaer(luz_evento.light_energy, 0.0, k_destello, delta)
	print(snappedf(luz_evento.light_energy, 0.001))

func _on_evento(posicion: Vector3) -> void:
	luz_evento.global_position = posicion + Vector3.UP * 1.5
	luz_evento.light_energy = pico_destello

static func decaer(actual: float, base: float, k: float, dt: float) -> float:
	# NOTA: Se calcula el alpha exponencial de manera local ya que la ZonaB 
	# no utiliza CamaraSeguidora (arquitectura de cámara ortogonal fija).
	var alpha := 1.0 - exp(-k * dt)
	return actual + (base - actual) * alpha
