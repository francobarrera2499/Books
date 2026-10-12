# audio/sound_bank.gd — W1-AUDIO (ARCHITECTURE §8). Tabla de sonidos: id → receta y parámetros.
# Subtítulos, ambientes por lugar y secuencias: data/audio.json (los lee el autoload Audio).
# Campos: recipe (receta de proc_audio.gd) · dur (s; en bucles = cuerpo del bucle) · loop · gain (ganancia final
# lineal, después de normalizar; 1 = sin cambio; para que W4-AUDIO equilibre sin tocar recetas) · fade (s de fundido
# cruzado del bucle; se generan dur+fade) · norm "peak" (level = pico lineal) | "none" (niveles absolutos de la
# receta) · variants (n.º de variantes, sembradas por "<id>#<v>"; las usa el AudioStreamRandomizer) ·
# pitch (random_pitch del Randomizer; 1 = fijo) · out (s de fundido final en sonidos sueltos).
extends RefCounted

const BANK := {
	"sfx.tijera": {"recipe": "tijera", "dur": 0.22, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.6, "variants": 3, "pitch": 1.05},
	"sfx.papel": {"recipe": "papel", "dur": 0.6, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.4, "variants": 3, "pitch": 1.06},
	"sfx.pagina": {"recipe": "pagina", "dur": 0.9, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.45, "variants": 3, "pitch": 1.05},
	"sfx.plumin": {"recipe": "plumin", "dur": 1.2, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.3, "variants": 2, "pitch": 1.03},
	"sfx.secante": {"recipe": "secante", "dur": 0.4, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.4, "variants": 2, "pitch": 1.04},
	"sfx.sello": {"recipe": "sello", "dur": 0.45, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.8, "variants": 2, "pitch": 1.03},
	"sfx.sello_seco": {"recipe": "sello_seco", "dur": 0.3, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.7, "variants": 2, "pitch": 1.03},
	"sfx.sobre": {"recipe": "sobre", "dur": 0.7, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.4, "variants": 2, "pitch": 1.04},
	"evt.persiana_crane": {"recipe": "persiana", "dur": 2.0, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.5},
	"evt.lechero": {"recipe": "lechero", "dur": 3.0, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.45},
	"bells.st_clement": {"recipe": "bells", "dur": 6.0, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.7, "out": 0.2},
	"clock.cuartos": {"recipe": "cuartos", "dur": 4.0, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.5, "out": 0.2},
	"clock.tic": {"recipe": "tic", "dur": 2.0, "loop": true, "gain": 1.0, "fade": 0.25, "norm": "peak", "level": 0.25},
	"hooves.madera": {"recipe": "hooves_madera", "dur": 3.0, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.6, "variants": 3, "pitch": 1.03},
	"hooves.granito": {"recipe": "hooves_granito", "dur": 3.0, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.6, "variants": 3, "pitch": 1.03},
	"harp.parker": {"recipe": "harp", "dur": 2.5, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.35, "out": 0.15},
	"whistle.policia": {"recipe": "whistle", "dur": 1.5, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.4, "out": 0.1},
	"shot.silbido": {"recipe": "silbido", "dur": 0.4, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.6},
	"glass.tintineo": {"recipe": "glass", "dur": 1.6, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.6, "out": 0.1},
	"evt.ladrillo": {"recipe": "ladrillo", "dur": 1.8, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.85, "out": 0.1},
	"evt.golpe_puerta": {"recipe": "golpe_puerta", "dur": 1.5, "loop": false, "gain": 1.0, "norm": "peak", "level": 0.75, "out": 0.1},
	"amb.calle": {"recipe": "amb_calle", "dur": 8.0, "loop": true, "gain": 1.0, "fade": 1.0, "norm": "none"},
	"amb.gas": {"recipe": "amb_gas", "dur": 4.0, "loop": true, "gain": 1.0, "fade": 0.5, "norm": "none"},
	"amb.sala_lectura": {"recipe": "amb_sala_lectura", "dur": 8.0, "loop": true, "gain": 1.0, "fade": 1.0, "norm": "none"},
	"amb.diogenes": {"recipe": "amb_diogenes", "dur": 6.0, "loop": true, "gain": 1.0, "fade": 0.8, "norm": "none"},
	"amb.tienda": {"recipe": "amb_tienda", "dur": 6.0, "loop": true, "gain": 1.0, "fade": 0.8, "norm": "none"},
	"amb.viento": {"recipe": "amb_viento", "dur": 8.0, "loop": true, "gain": 1.0, "fade": 1.0, "norm": "none"},
	"amb.parque": {"recipe": "amb_parque", "dur": 8.0, "loop": true, "gain": 1.0, "fade": 1.0, "norm": "none"},
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
