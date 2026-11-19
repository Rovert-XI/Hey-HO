extends Control
## Pantalla final: el barco está reparado y zarpa al atardecer.

@onready var barco: Control = %Barco
@onready var boton_otra: Button = %BotonOtraVez
@onready var boton_menu: Button = %BotonMenu


func _ready() -> void:
	boton_otra.pressed.connect(func() -> void:
		EstadoJuego.borrar_progreso()
		EstadoJuego.nivel_actual = 1
		Navegador.ir_a(self, EstadoJuego.RUTA_NIVEL))
	boton_menu.pressed.connect(func() -> void: Navegador.ir_a(self, Navegador.MENU))
	boton_otra.grab_focus()
	await get_tree().process_frame
	var ancho := get_viewport_rect().size.x
	barco.position.x = ancho * 0.12
	var t := create_tween()
	t.tween_property(barco, "position:x", ancho + 40.0, 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	var vaiven := create_tween().set_loops()
	vaiven.tween_property(barco, "rotation_degrees", 2.0, 1.2).set_trans(Tween.TRANS_SINE)
	vaiven.tween_property(barco, "rotation_degrees", -2.0, 1.2).set_trans(Tween.TRANS_SINE)
