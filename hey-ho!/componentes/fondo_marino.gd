extends Control
## Fondo animado de los menús: cielo de atardecer, sol, mar y las tres plataformas atadas con sogas
## (la misma base de trabajo del juego). Es solo decoración: ignora el ratón.

@onready var olas: Control = %Olas
@onready var plataformas: Control = %Plataformas


func _ready() -> void:
	for i in olas.get_child_count():
		_mecer(olas.get_child(i) as Control, 10.0, 5.0 + i * 0.8, i * 1.3, true)
	var n := 0
	for hijo in plataformas.get_children():
		if hijo.name.begins_with("Plataforma"):
			_mecer(hijo as Control, 5.0, 3.2 + n * 0.5, n * 1.7, false)
			n += 1


func _mecer(nodo: Control, amplitud: float, duracion: float, fase: float, horizontal: bool) -> void:
	var base_a := nodo.offset_left if horizontal else nodo.offset_top
	var base_b := nodo.offset_right if horizontal else nodo.offset_bottom
	var t := create_tween().set_loops()
	t.tween_method(_mecer_paso.bind(nodo, base_a, base_b, amplitud, fase, horizontal), 0.0, TAU, duracion)


func _mecer_paso(f: float, nodo: Control, base_a: float, base_b: float, amplitud: float,
		fase: float, horizontal: bool) -> void:
	var d := sin(f + fase) * amplitud
	if horizontal:
		nodo.offset_left = base_a + d
		nodo.offset_right = base_b + d
	else:
		nodo.offset_top = base_a + d
		nodo.offset_bottom = base_b + d
