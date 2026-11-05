class_name Generador
extends Node3D

@export var pelota: PackedScene
@export var intervalo := 1.5
@export var maximo := 9

var creadas: Array[Node3D] = []
var reloj := 0.0

func _physics_process(delta: float) -> void:
	reloj += delta
	if reloj >= intervalo:
		reloj -= intervalo
		crear()

func crear() -> void:
	var p := pelota.instantiate() as Node3D
	get_parent().add_child(p)
	p.global_position = global_position
	creadas.append(p)
	
	# Imprime en consola cuántas pelotas activas hay en la lista
	print("pelotas: ", creadas.size())
	
	while creadas.size() > maximo:
		var vieja = creadas.pop_front() # Saca la más vieja (la primera)
		if is_instance_valid(vieja):
			vieja.queue_free()
