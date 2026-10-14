# audio/sound_bank.gd — W1-AUDIO → W4-AUDIO (ARCHITECTURE §8). Tabla de sonidos: id → receta y parámetros.
# Subtítulos, ambientes por lugar y secuencias: data/audio.json (los lee el autoload Audio).
# Mezcla (W4-AUDIO): el nivel de cada suelto se fija con level (pico tras normalizar; ≤ 0,85 por la rodilla del
# limitador) para que su sonoridad máxima (ponderación K, ventana de 0,4 s; analysis.loudness_max) caiga en su escalón:
# foley del clic −27…−29 · tijera/sello −21…−24 · lo que pasa abajo o lejos (lechero, persiana, cuartos, arpa, cascos)
# −21…−23 · campanas del amanecer −17 · lo que pasa cerca la noche del 5 (silbido, silbato) −17 y el vidrio −16.
# Los rangos y el enmascaramiento contra cada ambiente los verifica tests/test_u_sound_bank.gd (tabla: w4audio_mix).
# v3 (GDD_v3 §6.8): calma en los bucles de ambiente (RMS ≤ −32 dBFS, siseo 2–8 kHz ≤ −40 dBFS, eventos sueltos ≥ 8 s
# entre sí): tests/test_t35_calma.gd. Sin amb.gas ni amb.gas_parker.
# Campos: recipe (receta de proc_audio.gd) · dur (s; en bucles = cuerpo del bucle) · loop · gain (ganancia final
# lineal, después de normalizar; 1 = sin cambio; para que W4-AUDIO equilibre sin tocar recetas) · fade (s de fundido
# cruzado del bucle; se generan dur+fade) · norm "peak" (level = pico lineal) | "none" (niveles absolutos de la
# receta) · variants (n.º de variantes, sembradas por "<id>#<v>"; las usa el AudioStreamRandomizer) ·
# pitch (random_pitch del Randomizer; 1 = fijo) · out (s de fundido final en sonidos sueltos).
extends RefCounted

const BANK := {
	"sfx.tijera": {"recipe": "tijera", "dur": 0.22, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.6, "variants": 3, "pitch": 1.05},
	"sfx.papel": {"recipe": "papel", "dur": 0.6, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.29, "variants": 3, "pitch": 1.06},
	"sfx.pagina": {"recipe": "pagina", "dur": 0.9, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.45, "variants": 3, "pitch": 1.05},
	"sfx.plumin": {"recipe": "plumin", "dur": 1.2, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.24, "variants": 2, "pitch": 1.03},
	"sfx.secante": {"recipe": "secante", "dur": 0.4, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.21, "variants": 2, "pitch": 1.04},
	"sfx.sello": {"recipe": "sello", "dur": 0.45, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.8, "variants": 2, "pitch": 1.03},
	"sfx.sello_seco": {"recipe": "sello_seco", "dur": 0.3, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.65, "variants": 2, "pitch": 1.03},
	"sfx.sobre": {"recipe": "sobre", "dur": 0.7, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.36, "variants": 2, "pitch": 1.04},
	"evt.persiana_crane": {"recipe": "persiana", "dur": 2.0, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.55},
	"evt.lechero": {"recipe": "lechero", "dur": 3.0, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.42},
	"bells.st_clement": {"recipe": "bells", "dur": 6.0, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.61, "out": 0.2},
	"clock.cuartos": {"recipe": "cuartos", "dur": 4.0, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.36, "out": 0.2},
	"clock.tic": {"recipe": "tic", "dur": 2.0, "loop": true, "gain": 1.0, "fade": 0.25, "norm": "peak", "level": 0.25},
	"hooves.madera": {"recipe": "hooves_madera", "dur": 3.0, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.53, "variants": 3, "pitch": 1.03},
	"hooves.granito": {"recipe": "hooves_granito", "dur": 3.0, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.65, "variants": 3, "pitch": 1.03},
	"harp.parker": {"recipe": "harp", "dur": 3.6, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.45, "out": 0.15},
	"whistle.policia": {"recipe": "whistle", "dur": 1.5, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.34, "out": 0.1},
	"shot.silbido": {"recipe": "silbido", "dur": 0.4, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.67},
	"glass.tintineo": {"recipe": "glass", "dur": 3.0, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.76, "out": 0.25},
	"evt.ladrillo": {"recipe": "ladrillo", "dur": 1.8, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.85, "out": 0.1},
	"evt.golpe_puerta": {"recipe": "golpe_puerta", "dur": 1.5, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.7, "out": 0.1},
	"amb.calle": {"recipe": "amb_calle", "dur": 8.0, "loop": true, "gain": 1.0, "fade": 1.0, "norm": "none"},
	"amb.sala_lectura": {"recipe": "amb_sala_lectura", "dur": 8.0, "loop": true, "gain": 1.0, "fade": 1.0, "norm": "none"},
	"amb.diogenes": {"recipe": "amb_diogenes", "dur": 8.0, "loop": true, "gain": 1.0, "fade": 0.8, "norm": "none"},
	"amb.tienda": {"recipe": "amb_tienda", "dur": 6.0, "loop": true, "gain": 1.0, "fade": 0.8, "norm": "none"},
	"amb.viento": {"recipe": "amb_viento", "dur": 8.0, "loop": true, "gain": 1.0, "fade": 1.0, "norm": "none"},
	"amb.parque": {"recipe": "amb_parque", "dur": 8.0, "loop": true, "gain": 1.0, "fade": 1.0, "norm": "none"},
	# W4-AUDIO: la hora de St Clement Danes, el cerrojo de Crane, la carrera de los agentes; Baker Street de noche y
	# el prólogo con la tonada de Parker; Camden House.
	"bells.horas": {"recipe": "bells_horas", "dur": 17.5, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.31, "out": 0.3},
	"evt.cerrojo": {"recipe": "cerrojo", "dur": 1.8, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.5, "out": 0.1},
	"evt.carrera": {"recipe": "carrera", "dur": 2.6, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.52, "out": 0.1},
	"amb.calle_parker": {"recipe": "amb_calle_parker", "dur": 16.0, "loop": true, "gain": 1.0, "fade": 1.0, "norm": "none"},
	"amb.casa_vacia": {"recipe": "amb_casa_vacia", "dur": 16.0, "loop": true, "gain": 1.0, "fade": 0.8, "norm": "none"},
	# playtest v3: cada casa con su sonido (antes el consultorio y el vestíbulo usaban amb.tienda)
	"amb.consultorio": {"recipe": "amb_consultorio", "dur": 8.0, "loop": true, "gain": 1.0, "fade": 0.8, "norm": "none"},
	"amb.vestibulo": {"recipe": "amb_vestibulo", "dur": 8.0, "loop": true, "gain": 1.0, "fade": 0.8, "norm": "none"},
	# v3 (REACCIONES-PIEZA, GDD_v3 §6.8): sin siseo de gas. La noche casi en silencio (un coche lejano y la campana de
	# los cuartos; en el prólogo, el arpa de Parker abajo de vez en cuando) y la corriente de aire al entrar en la pieza
	# con la ventana abierta (evento intrusion_techos, una sola vez, −29 dB aprox.: playtest v3, sin alerta).
	"amb.noche": {"recipe": "amb_noche", "dur": 24.0, "loop": true, "gain": 1.0, "fade": 1.0, "norm": "none"},
	"amb.noche_parker": {"recipe": "amb_noche_parker", "dur": 27.0, "loop": true, "gain": 1.0, "fade": 1.0, "norm": "none"},
	# playtest v3: −8 dB (era lo más fuerte de la sesión, +18 dB sobre el ambiente; el pedido es «sin sonido de alerta»)
	"evt.corriente": {"recipe": "corriente", "dur": 3.0, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.143, "out": 0.3},
}

# Alias de los ids del ejemplo de ARCHITECTURE §4.17 (los canónicos son los de §8).
const ALIASES := {
	"amb.street": "amb.calle",
	"amb.reading_room": "amb.sala_lectura",
	"evt.milk_cart": "evt.lechero",
	"evt.crane_shutter": "evt.persiana_crane",
}

static func resolve(id: String) -> String:
	return String(ALIASES.get(id, id))

static func has(id: String) -> bool:
	return BANK.has(resolve(id))

static func ids() -> Array:
	var k := BANK.keys()
	k.sort()
	return k

static func entry(id: String) -> Dictionary:
	return BANK.get(resolve(id), {})

static func variants(id: String) -> int:
	return int(entry(id).get("variants", 1))

static func is_loop(id: String) -> bool:
	return bool(entry(id).get("loop", false))
