# core/util/det.gd — azar determinista sin estado (D7). Dueño: W1-ENG. Contrato: ARCHITECTURE §3.1, §3.8.
# h32 = primeros 8 hex de md5_text("|".join(parts)) como int (0..2^32-1). Nada de RNG global.
extends RefCounted

static func h32(parts: Array) -> int:
	var ps := PackedStringArray()
	for p in parts:
		ps.append(_s(p))
	return "|".join(ps).md5_text().substr(0, 8).hex_to_int()

static func _s(p) -> String:
	if typeof(p) == TYPE_FLOAT and is_finite(p) and p == floorf(p) and absf(p) < 9007199254740992.0:
		return str(int(p))
	return str(p)

static func rand01(seed: int, parts: Array) -> float:
	return float(h32([seed] + parts)) / 4294967296.0

static func pick(seed: int, parts: Array, arr: Array):
	if arr.is_empty():
		return null
	return arr[h32([seed] + parts) % arr.size()]

# Fisher-Yates sembrado; no muta la entrada.
static func shuffle(seed: int, parts: Array, arr: Array) -> Array:
	var out := arr.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := h32([seed] + parts + ["sh", i]) % (i + 1)
		var t = out[i]
		out[i] = out[j]
		out[j] = t
	return out
