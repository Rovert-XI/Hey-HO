extends Control
## Selección de nivel (el "hub"): el collar de perlas. Cada perla es un día de trabajo.
## Un día se desbloquea al superar el 60 % del oro del anterior.

const TARJETA := preload("res://componentes/tarjeta_nivel.tscn")

@onready var perlas: HBoxContainer = %Perlas
@onready var barra_rep: ProgressBar = %BarraRep
@onready var oro_rep: Label = %OroRep
@onready var boton_volver: Button = %BotonVolver


func _ready() -> void:
	EstadoJuego.asegurar_carga()
	var con_foco: Button = boton_volver
	for n in range(1, EstadoJuego.TOTAL_NIVELES + 1):
		var tarjeta: TarjetaNivel = TARJETA.instantiate()
		perlas.add_child(tarjeta)
		tarjeta.configurar(n)
		tarjeta.elegido.connect(_elegir)
		if tarjeta.disponible():
			con_foco = tarjeta.boton   # termina en la perla más avanzada disponible

	barra_rep.max_value = EstadoJuego.COSTO_REPARACION
	barra_rep.value = mini(EstadoJuego.oro_total, EstadoJuego.COSTO_REPARACION)
	oro_rep.text = "%d / %d" % [EstadoJuego.oro_total, EstadoJuego.COSTO_REPARACION]
	boton_volver.pressed.connect(func() -> void: Navegador.ir_a(self, Navegador.MENU))
	con_foco.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Navegador.ir_a(self, Navegador.MENU)


func _elegir(nivel: int) -> void:
	EstadoJuego.nivel_actual = nivel
	Navegador.ir_a(self, EstadoJuego.RUTA_NIVEL)
