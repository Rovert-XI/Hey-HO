extends Control
## Créditos del equipo Rovert XI.

@onready var boton_volver: Button = %BotonVolver


func _ready() -> void:
	boton_volver.pressed.connect(func() -> void: Navegador.ir_a(self, Navegador.MENU))
	boton_volver.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Navegador.ir_a(self, Navegador.MENU)
