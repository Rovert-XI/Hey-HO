extends Control
## Pantalla de arranque con el logo de Rovert XI. Se salta con cualquier tecla o clic.

@onready var logo: TextureRect = %Logo
@onready var presenta: Label = %Presenta

var _saliendo := false


func _ready() -> void:
	EstadoJuego.asegurar_carga()
	logo.modulate.a = 0.0
	presenta.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(logo, "modulate:a", 1.0, 0.7)
	t.tween_property(presenta, "modulate:a", 1.0, 0.4)
	t.tween_interval(1.1)
	t.tween_callback(_continuar)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_continuar()
	elif event is InputEventMouseButton and event.pressed:
		_continuar()


func _continuar() -> void:
	if _saliendo:
		return
	_saliendo = true
	Navegador.ir_a(self, Navegador.MENU)
