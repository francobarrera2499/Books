# GDD v3: el Expediente Holmes

> **Qué es.** Especificación **normativa** de la iteración v3, escrita a partir de las 13 decisiones acordadas con el usuario. **Prevalece sobre `docs/GDD.md`, `docs/GDD_v2.md` y `docs/ARCHITECTURE.md`** donde difieran. Lo que este documento no toca sigue vigente: canon y calendario (GDD §2), elenco (§4), voces A y B y sus latencias (§9.3), leyes de Holmes (§9.4), reglas del director D1–D10 (§9.8), informes a Moran (§7.3), confrontación (§8.8), lenguaje simple (GDD_v2 §A), título **What the Ink Says**, look aguada.
> **Objetivo del usuario (literal):** «que yo me pueda sentar a jugar y no necesite preguntar qué hago después; que al leer una pregunta se me ocurran varias cosas que puedo hacer y sepa dónde puedo resolver mis dudas». El juego trata de **qué le pasó a Sherlock Holmes** (lo que Watson no escribió), no de cazar errores en crónicas.
> **Lectores:** seis implementadores en paralelo (§7). Los ids, textos y esquemas de este documento son **contrato**: se copian tal cual.

---

## 0. Resumen

### 0.1 Decisiones del usuario → dónde se aplican

| # | Decisión (resumen) | Sección |
|---|---|---|
| 1 | Expediente Holmes: preguntas en lenguaje simple que nacen de lo que hace el jugador; 8–10 en total, 2–3 abiertas; dudas de Lisle | §1 |
| 2 | Responder = 1 respuesta + 2 pruebas; lápiz → «Pasar en limpio» de a una; tinta con texto de Lisle; «Algo no cierra»; sin límite de intentos | §1.6, §1.9 |
| 3 | Sólo 6 crónicas, con ficha de Lisle, nota del cliente en tarjeta y marquitas; las demás desactivadas | §3 |
| 4 | Canon intacto; el misterio es lo que el canon no cuenta | §1.2, §3.2 |
| 5 | Dónde buscar: plano con «qué hay» y «por qué apareció»; dudas; Crane como guía | §5 |
| 6 | La pieza: sólo lo útil y lo que cambió; intrusiones con dos firmas | §4, §6.4 |
| 7 | Plano sólo en la pared; cada salida es departamento → lugar → departamento | §5.4 |
| 8 | Recortes cortos (≤15 palabras), como tarjetas; se eliminan los pares | §6.2, §6.3 |
| 9 | Hover: sólo contorno blanco; cursor lupa / mano; sin filete rojo | §6.5 |
| 10 | Cámara sin posiciones intermedias; se desliza sola al girar | §6.6 |
| 11 | Lector flotante; tijera ícono; paginación abajo; notas al margen | §6.7 |
| 12 | Sonido tranquilo; sin siseo de gas | §6.8 |
| 13 | Una sola forma de hacer cada cosa | §6.3, §6.4 |

### 0.2 Qué se retira del GDD

- **Libro de conclusiones**, hojas/folios, «Varios», plantillas T1–T9, ranuras «según» por línea, sello «Confirmado», lote de a dos, pasadas por turno, práctica C1, «Cómo se anota una conclusión», «Lo que me preguntaron» (GDD §8.0–§8.5, §8.9; GDD_v2 §A.3 reglas, §B.6.1, §B.7 día 1).
- **Pares/Cotejos** (GDD §8.3; acción `link`).
- Conclusiones C1–C14 como unidad de juego: se reemplazan por las preguntas Q1–Q10 (§1.4).
- Del escritorio: cama, calendario 3D, sello, tijera 3D, pliegos, atril, lámpara, estufa y demás decoración examinable (§6.4). Del HUD: la cinta «Plano». Del teclado: M y Espacio. La etiqueta flotante y el contorno rojo permanente (GDD_v2 §D).
- El recorte por rectángulo de dioramas en la interfaz (el sim lo conserva para bots y tests): todo lo del 3D se recorta del texto de su tarjeta de examen (§6.2).

---

## 1. El Expediente Holmes

### 1.1 Principio

Una carpeta de cartón con la palabra «Holmes» en la tapa. Dentro: el encargo de Pell (D23) y **hojas de preguntas**. Al empezar hay **una sola**; las demás **nacen de lo que hace el jugador** (leer, recibir, oír, ver, cerrar otra pregunta). Nunca hay un mapa de todo lo que va a pasar: una pregunta no nacida no existe en la interfaz.

Cada hoja muestra: la pregunta (letra de Lisle), una línea de **origen** («Me lo pregunté al leer «El problema final».»), **2–3 dudas de Lisle** (lápiz, chico: avenidas, nunca respuestas), la **Respuesta**, las **dos Pruebas** y el estado (**lápiz** o **tinta**).

### 1.2 Las diez preguntas

| Id | Pregunta | Nace (resumen) | Respuesta válida | Antes era |
|---|---|---|---|---|
| **Q1** | ¿Qué no contó Watson? | Inicio (el encargo) | la raspadura | C2 |
| **Q2** | ¿Qué pasó en la cascada? | Leer «El problema final» o la nota «No lo es.» | la cornisa | C3 |
| **Q3** | ¿Quién me escribe las cartas sin firma? | Llega la primera carta a máquina | Mycroft Holmes | C7 (+C6) |
| **Q4** | ¿Quién cortó la frase? | Q1 en tinta, o leer la orden de rehacer la página | Mycroft Holmes | nueva (material de C2 y C4) |
| **Q5** | ¿Quién me contesta firmando «S.»? | Llega la primera respuesta firmada «—S.» | Sherlock Holmes | C8 |
| **Q6** | ¿Quién es en realidad mi cliente? | El mayor pregunta «dónde» (M6) o el coronel contesta desde Bath (D28) | Sebastian Moran | C10a (+C5) |
| **Q7** | ¿Quién mató a Ronald Adair? | Sale la noticia de Park Lane | Sebastian Moran | C11 |
| **Q8** | ¿Quién entró a mi pieza? | El jugador nota una intrusión | A: el muchacho (los de Holmes) · B: el mayor (los de Moran) | nueva (§4) |
| **Q9** | ¿Para qué me contrató el mayor? | El mayor sube a verme (M7) | el cebo (cabrito) | C10 |
| **Q10** | ¿Qué va a pasar el jueves? | Todos hablan del jueves (HC05, HC06 e, AGENTE, M8) | A: Holmes vuelve · B: Moran dispara desde la casa vacía | C9 / C13 |

Diez preguntas, todas `obligatoria: true` (cuentan para los finales); Q4 y Q8 pueden no nacer en una partida (§1.5) y entonces no cuentan.

### 1.3 Fichas normativas

Formato: **texto** · **nace** (disparadores exactos, OR; cada uno con su línea de origen) · **dudas** · **variantes** (respuestas, tipos aceptados en el selector, grupos que deben cubrir las dos pruebas, claves de enlace, texto en tinta) · **lápiz azul** (post-créditos: falta / incorrecta). Ventana de validez de todas: desde que nace hasta el informe final (`10.M`).

Gramática de disparadores (§1.7): `inicio` · `leer <doc>#<tramo>` (la acción `read` de la hoja que contiene ese tramo) · `leer R:<rid>.*` (leer una instancia de esa reacción) · `llega voz:A|voz:B|R:<rid>.*|<doc>` (entrega en bandeja, mostrador o columna) · `dicho S:<escena>.<línea>` · `tinta <Qn>` · `nota <rid>` (§4.4).

#### Q1 — ¿Qué no contó Watson?
- **Nace:** `inicio` (está en el expediente desde el prólogo). Origen: «La pregunta del cliente, en el encargo.»
- **Dudas:** «¿Qué dice la crónica, palabra por palabra, del sendero y de la pared?» · «¿Hay otra versión del texto, anterior a la que se imprimió?» · «¿Qué publicaron los diarios suizos esos días?»
- **Variante única.** Respuestas: `raspadura`, `marca_en_la_roca`. Acepta: concepto, objeto. Grupos: `fina_impreso_sin_raspadura` · `raspadura_registrada`. Claves: fina, reichenbach, roca, pared, raspadura, marca_en_la_roca.
- **Tinta:** «Watson vio en la roca una raspadura fresca, como la que deja el clavo de una bota, y la escribió. En la revista esa frase no está: alguien la sacó antes de imprimir.»
- **Lápiz azul:** falta «Falta: lo que el impreso calla.» · mal «Corríjalo: el impreso calla una marca, no una opinión.»

#### Q2 — ¿Qué pasó en la cascada?
- **Nace:** `leer D03#sheer` (origen «Me lo pregunté leyendo «El problema final».») · `leer R:HC01.*` (origen «Me lo pregunté por la nota «No lo es.».»).
- **Dudas:** «¿Cómo era el sendero, y qué había más arriba?» · «¿Qué dijeron los guías y la gente del lugar?» · «¿Hay fotos o guías de viaje de la cascada?»
- **Variante única.** Respuestas: `cornisa`. Acepta: lugar, concepto, objeto. Grupos: `fina_a_pique` · `cornisa_existe`. Claves: reichenbach, pared, sendero, cornisa.
- **Tinta:** «La pared no era lisa. Más arriba del final del sendero hay una cornisa que no se ve desde abajo. Un hombre que llega ahí desaparece sin caer.»
- **Lápiz azul:** «Falta: lo que no se ve desde el sendero.» · «Corríjalo: la cornisa no se ve desde el sendero.»

#### Q3 — ¿Quién me escribe las cartas sin firma?
- **Nace:** `llega voz:A` (primera entrega de una reacción `voz: "A"`: HA0/HA1 la garantizan el `2.dawn`). Origen: «Me lo pregunté al recibir la primera carta a máquina.»
- **Dudas:** «¿Cómo sabe lo que hice, y dónde pudo verlo?» · «¿De dónde sale este papel, y quién lo usa?» · «¿Qué sé de la gente que rodeaba a Holmes?»
- **Variante única.** Respuestas: `mycroft`. Acepta: persona. Grupos: `me_vigila_de_cerca` · `vinculo_mycroft`. Claves: club_diogenes, pall_mall, mycroft, remington, remington_s_alzada, papel_crema_grueso, giro_ahorrare, whitehall, matasellos_sw, watson.
- **Tinta:** «Las cartas las escribe alguien que sabe lo que hago el mismo día, y todo lo que las rodea lleva al club Diógenes y a Mycroft Holmes. Me las manda el hermano.»
- **Lápiz azul:** «Falta: de quién es la mano que escribe a máquina.» · «Corríjalo: el escribiente teclea; otro dicta.»

#### Q4 — ¿Quién cortó la frase?
- **Nace:** `tinta Q1` · `leer D04#cajista` · `leer D29a#tachadura`. Origen: «Me lo pregunté cuando entendí que alguien había sacado la frase.»
- **Dudas:** «¿Quién puede mandar a rehacer una página ya compuesta?» · «¿Quedó algún papel de la imprenta, o del doctor, que lo diga?» · «¿Quién se ocupaba de los asuntos de Holmes cuando él se fue?»
- **Variante única.** Respuestas: `mycroft`. Acepta: persona. Grupos: `corte_por_orden` (nuevo) · `mycroft_gobierno` (nuevo). Claves: gobierno, pedido_del_fo, foreign_office, mycroft.
- **Tinta:** «La frase la sacaron por orden de un ministerio, y en los ministerios trabaja Mycroft Holmes. El hermano mandó cortar la roca: no quería que nadie leyera que hubo una salida.»
- **Lápiz azul:** «Falta: quién pidió el corte.» · «Corríjalo: el doctor no tachó nada por su cuenta.»

#### Q5 — ¿Quién me contesta firmando «S.»?
- **Nace:** `llega voz:B` (HC10 lo garantiza el `4.dawn`; antes, una HB1). Origen: «Me lo pregunté cuando alguien que firma «S.» me contestó.»
- **Dudas:** «¿Quién más firmó con esa inicial después de 1891?» · «¿Qué escribió Holmes, además de sus casos?» · «¿Qué publicó el Times desde lugares lejanos?»
- **Variante única.** Respuestas: `holmes`. Acepta: persona. Grupos: `identidad_holmes` · `actividad_posterior_a_mayo_1891`. Claves: numero_97, monografia_cenizas, opusculo_oficios, forma_de_la_mano, mycroft, letra.
- **Tinta:** «Alguien siguió los trabajos de Holmes después de mayo de 1891 y firma con su inicial. Ningún muerto hace eso: Sherlock Holmes está vivo, y es él quien me contesta.»
- **Lápiz azul:** «Falta: quién firma después de mayo de 1891.» · «Corríjalo: los muertos no completan monografías.»

#### Q6 — ¿Quién es en realidad mi cliente?
- **Nace:** `dicho S:M6.donde` (origen «Me lo pregunté cuando el mayor mandó a preguntar «dónde».») · `llega R:D28.*` (origen «Me lo pregunté cuando el coronel me contestó que no conoce a ningún Pell.»).
- **Dudas:** «¿Dónde vi antes esa cara y esa manera de hablar?» · «¿Qué libros escribió un cazador de la India?» · «¿Qué fuma el mayor, y quién más fuma eso?»
- **Variante única.** Respuestas: `moran`, `autor_heavy_game`. Acepta: persona. Grupos: `rasgo_de_harris` (nuevo) · `rasgo_de_moran` (nuevo). Claves: bigote, adjetivos_repetidos, cruel, cheroot, trichinopolis, conduit_street.
- **Tinta:** «El mayor Harris no es amigo de ningún coronel: es el coronel Sebastian Moran, el cazador de tigres. Tiene su cara, su manera de hablar y su tabaco.»
- **Lápiz azul:** «Falta: quién es el mayor.» · «Corríjalo: un bigote no es una prueba; dos sí.»
- **Alias:** desde que Q6 está en tinta, `harris` ≡ `moran` ≡ `autor_heavy_game` en toda respuesta y como clave (regla `alias`, §1.7). Reemplaza a C10a.

#### Q7 — ¿Quién mató a Ronald Adair?
- **Nace:** `llega D15.0331` (el Times del sábado en la bandeja, `5.dawn`). Origen: «Me lo pregunté al leer en el Times lo de Park Lane.»
- **Dudas:** «¿Con quién jugaba a las cartas Adair?» · «¿Desde dónde pudieron disparar, si nadie oyó nada?» · «¿Quién en Londres tira así de bien?»
- **Variante única.** Respuestas: `moran`, `autor_heavy_game`, `@alias:harris`. Acepta: persona. Grupos: `junto_a_adair` (nuevo) · `tiro_de_cazador` (nuevo). Claves: moran, ronald_adair, whist, bala, bala_blanda, disparo.
- **Tinta:** «A Ronald Adair lo mataron desde afuera, sin ruido, con una bala que se abre adentro. Esa noche había jugado a las cartas con el coronel Moran, el mejor tiro de la India. Fue Moran.»
- **Lápiz azul:** «Falta: quién disparó.» · «Corríjalo: nadie oyó el disparo; el aire no hace ruido.»
- Nadie relaciona a Moran con Adair antes del día 8 (GDD §2.4): la pregunta nace el 5, sus pruebas existen desde el `8.dawn`.

#### Q8 — ¿Quién entró a mi pieza?
- **Nace:** `nota HA5` · `nota HA6` · `nota M1` · `leer R:HA5.*` (el papel devuelto con la marca). Origen: «Me lo pregunté al ver que alguien había entrado en mi pieza.»
- **Dudas:** «¿Por dónde entró, y qué tocó?» · «¿Qué se llevó, y quién sabía que yo lo tenía?» · «¿Quién me sigue por la calle?»
- **Variante A — los de Holmes.** Respuestas: `muchacho`, `muchacho_de_gorra`, `wiggins`, `irregulares`. Acepta: persona. Grupos: `entro_por_los_techos` · `chicos_de_holmes` (nuevos). Claves: muchacho, irregulares, muchacho_de_gorra, wiggins, techos. **Tinta:** «Entró un muchacho por los techos: abrió la traba desde afuera y no rompió nada: buscaba papeles, no dinero. Es de los chicos que trabajaban para Holmes.»
- **Variante B — los de Moran.** Respuestas: `@alias:moran`, `harris`, `hombres_de_moran`. Acepta: persona. Grupos: `entraron_por_la_puerta` · `senas_del_mayor` (nuevos). Claves: cheroot, ceniza_negra, harris. **Tinta:** «Entraron por la puerta, forzando la cerradura, y dejaron ceniza del mismo cigarro que fuma el mayor. Se llevaron lo que yo le había contado. Fue la gente de mi cliente.»
- **Lápiz azul:** «Falta: quién subió por los techos.» · «Corríjalo: el chico entra por arriba; el tigre, por la puerta.»
- La pregunta se cierra con la primera variante que pase. `invariante: "desde_nacimiento"` (§2.2).

#### Q9 — ¿Para qué me contrató el mayor?
- **Nace:** `dicho S:M7.donde_duerme` (`7.night`). Origen: «Me lo pregunté cuando el mayor subió a verme de noche.»
- **Dudas:** «¿Qué cuenta un cazador de cómo atrae a un tigre?» · «¿Qué me pidió el mayor, exactamente, cada vez que habló?» · «¿Por qué alguien me contesta cada vez que publico algo?»
- **Variante única.** Respuestas: `cebo`, `cabrito`, `cabrito_atado`. Acepta: concepto, objeto, persona. Grupos: `cebo` · `busca_a_holmes`. Claves: cabrito, cabrito_atado, cebo, donde, tigre.
- **Tinta:** «No me contrató para corregir a nadie. Soy el cabrito atado al árbol: me hace moverme para que alguien me conteste, y así saber dónde está Holmes.»
- **Lápiz azul:** «Falta: para qué me paga.» · «Corríjalo: el cabrito no elige el árbol.»

#### Q10 — ¿Qué va a pasar el jueves?
- **Nace:** `dicho S:HC05.jueves_a` · `dicho S:HC06.e` · `dicho S:AGENTE.militar` · `llega R:M8.*` (garantía `9.dawn`). Origen: «Me lo pregunté cuando todos empezaron a hablar del jueves.»
- **Dudas:** «¿Qué están preparando en el 221B?» · «¿Quién vuelve, y de dónde?» · «¿Quién anda mirando la casa de enfrente?»
- **Variante A (`principal`).** Respuestas: `holmes`. Acepta: persona. Grupos: `preparativos_221b` · `dia_jueves`. Claves: jueves, 221b, mycroft, baker_street. **Tinta:** «El jueves alguien vuelve al 221B: preparan los cuartos y el hermano deja libre ese día. Sherlock Holmes vuelve a Baker Street.»
- **Variante B.** Respuestas: `harris`, `@alias:moran`, `@alias:autor_heavy_game` (las pruebas son del lado de Harris; Moran vale cuando Q6 está en tinta). Acepta: persona. Grupos: `tirador` · `escondite_preparado`. Claves: camden_house, casa_vacia, harris, moran, cheroot, 221b. **Tinta:** «El mayor va a esperar en la casa vacía de enfrente del 221B, arriba, donde se domina la ventana, como se espera a un tigre. El jueves va a disparar desde ahí.» Todo fragmento de B lleva `f:secreto_camden` (GDD §2.4, T22).
- **Lápiz azul:** «Falta: adónde vuelvo, y qué día.» · «Corríjalo: el jueves se airea un cuarto, no una tumba.»

### 1.4 De C1–C14 a Q1–Q10

| Antes | Destino v3 |
|---|---|
| C1 (erratas inocentes, práctica) | **Desaparece** del juego. Los pares INC que siguen en las 6 crónicas (INC-01 STUD/SIGN, INC-02 STUD/TWIS, INC-06 SCAN/SIGN, INC-09 SIGN/SIGN) pasan a **Curiosidades** (§3.6) |
| C2 | Q1 |
| C3 | Q2 |
| C4 (bienes a Mycroft) | Se elimina como pregunta. D30, D18, D19 y D29b quedan como fuentes (refutación de `falsa_herencia`, Q3 R3) |
| C5 (cartas del coronel) | Se funde en Q6: D23#cruel (Harris) frente a D10#cruel (Moran). D09 queda como lectura |
| C6 (dos canales) | Se funde en Q3: las anclas ya llevan `me_vigila_de_cerca`. Las etiquetas `acto_*`/`ancla_*` quedan para la confrontación (afirmación 3) |
| C7 | Q3 |
| C8 | Q5 |
| C9 | Q10 variante A |
| C10 (cebo) | Q9 (sin el grupo de identidad, que pasa a Q6) |
| C10a | Q6 (con la regla de alias) |
| C11 | Q7 (grupos nuevos: `junto_a_adair`, `tiro_de_cazador`) |
| C12 (el librero) | **Sin pregunta**: lo resuelve la confrontación (GDD §8.8, sin cambios) y las variantes del epílogo |
| C13 | Q10 variante B |
| C14 (tomos de Watson) | **Curiosidad** con flag `curiosidad_tomos` (§3.6); mantiene la variante del epílogo |
| — | Q4 y Q8, nuevas |

`data/conclusions.json` se borra al final del paquete CORE (§7). Sus `_pistas_falsas` pasan a `dossier.json._pistas_falsas` sin cambios (T17 sigue igual).

### 1.5 Nacimiento y tope de abiertas

- Una pregunta **nace** cuando se cumple cualquiera de sus disparadores; queda registrado `{tk, via}` y la línea de origen correspondiente.
- **Tope: 3 abiertas a la vez.** Si nace una cuarta, queda **en espera** (invisible). Las preguntas en espera se muestran, en orden de nacimiento, cuando se cierra una abierta, y **todas** las que estén en espera se muestran el `8.dawn` aunque se pase el tope (el jugador lento llega al final con todo a la vista).
- Una pregunta nunca se vuelve a cerrar ni a abrir; lo que está en tinta no cambia.
- Pendientes (GDD_v2 §B.6.2) suma la línea de novedad «Una pregunta nueva en el expediente.» la mañana después de que una se muestra. No dice cuál ni la resuelve.
- Nada del nacimiento lee etiquetas ocultas: los disparadores son actos y entregas visibles (T8, test `test_u_dossier::test_births_blind`).

### 1.6 Responder y pasar en limpio

**Borrador (lápiz, gratis, sin límite).** La hoja tiene tres ranuras: Respuesta (una entidad del índice del jugador cuyo `kind` esté en `acepta`) y Prueba 1 / Prueba 2 (dos recortes **distintos**, arrastrados directamente desde el cuaderno). Se cambian cuando se quiera.

**Pasar en limpio (botón de la hoja; de a una pregunta; acción comprometida `dq_confirm`).**
1. **Chequeo de forma** (visible, no cuenta como intento, en la voz de Lisle): falta la respuesta → «Me falta la respuesta.» · menos de dos pruebas → «Hacen falta dos pruebas.» · las dos del mismo papel (mismo `origin`) → «Las dos pruebas salen del mismo papel.» (es la regla pública de siempre: dos fuentes distintas).
2. **Chequeo de contenido** (silencioso). Cierra si existe una variante `v` de la pregunta tal que:
   1. la respuesta ∈ `v.respuestas` (con la regla de alias vigente; `@alias:x` vale sólo con el alias activo);
   2. la hora actual está en `v.valida`;
   3. ninguna prueba lleva `f:refutado`;
   4. **cubren los dos grupos**: una prueba tiene alguna etiqueta del grupo 1 y la otra alguna del grupo 2 (en cualquier orden; `Validator.tag_match`, etiqueta sin prefijo = `a:<x>`);
   5. **enlazadas**: comparten al menos una entidad de `v.claves.entities` (canónica bajo alias) o ambas llevan una entidad de un `kind` de `v.claves.kinds`.
3. **Resultado.** Si cierra: la hoja pasa a **tinta**: se borra el lápiz, Lisle escribe `v.tinta` con su letra (revelado de 1,5 s), suena el plumín y el secante, nada más. Si no: la hoja sigue en lápiz y Lisle dice sólo **«Algo no cierra.»** Nunca dice si falló la respuesta o una prueba.
4. **Primera tinta de la partida (momento sobrio):** la carpeta se queda abierta en esa hoja, la luz de la pieza baja un 10 % durante 2 s, se oye sólo el plumín. Sin música, sin cartel, sin contador.
5. Sin límite de intentos: el freno es combinatorio (§1.9). Los intentos se cuentan en el estado (`attempts`) sólo para tests y bots; no se muestran ni son públicos (T8).

### 1.7 Esquema `data/dossier.json` (dueño: CORE)

```json
{
  "_nota": "GDD_v3 §1. Preguntas del Expediente Holmes. Reemplaza a conclusions.json.",
  "max_abiertas": 3,
  "mostrar_todas": "8.dawn",
  "alias": [{"cuando_tinta": "Q6", "equiv": ["harris", "moran", "autor_heavy_game"]}],
  "preguntas": [
    {
      "id": "Q1", "orden": 1, "obligatoria": true,
      "texto": "¿Qué no contó Watson?",
      "nace": [{"inicio": "prologo", "origen": "La pregunta del cliente, en el encargo."}],
      "dudas": ["¿Qué dice la crónica, palabra por palabra, del sendero y de la pared?",
                "¿Hay otra versión del texto, anterior a la que se imprimió?",
                "¿Qué publicaron los diarios suizos esos días?"],
      "acepta": ["concepto", "objeto"],
      "variantes": [
        {"id": "A", "principal": true,
         "respuestas": ["raspadura", "marca_en_la_roca"],
         "grupos": [{"id": "impreso", "tags": ["fina_impreso_sin_raspadura"]},
                    {"id": "registrada", "tags": ["raspadura_registrada"]}],
         "claves": {"entities": ["fina", "reichenbach", "roca", "pared", "raspadura", "marca_en_la_roca"], "kinds": []},
         "valida": {"desde": null, "hasta": "10.M"},
         "tinta": "Watson vio en la roca una raspadura fresca, como la que deja el clavo de una bota, y la escribió. En la revista esa frase no está: alguien la sacó antes de imprimir.",
         "rutas": [
           {"id": "Q1.R2", "star": true, "deps": "fija", "from": "1.M",
            "frags": [{"ref": "D03#sheer", "copy": "D03@Crane"}, {"ref": "D05#marque", "copy": "D05@BM"}], "cut_by": []}
         ]}
      ],
      "blue_pencil": {"missing": "Falta: lo que el impreso calla.", "wrong": "Corríjalo: el impreso calla una marca, no una opinión."},
      "invariante": "normal"
    }
  ],
  "_pistas_falsas": []
}
```

Reglas del esquema (Schema las verifica):
- `nace[]`: exactamente una clave de disparador por objeto (`inicio` | `leer` | `llega` | `dicho` | `tinta` | `nota`) + `origen`. `llega` acepta `"voz:A"`, `"voz:B"`, `"R:<rid>.*"` o un id de documento.
- `variantes[]`: 1 o 2; exactamente una con `principal: true`. Exactamente **2 grupos** por variante. `respuestas` = ids de entidad o `"@alias:<id>"`. `rutas[].frags` = **exactamente 2** fragmentos (sintaxis de `ref` de ARCHITECTURE §4.8, sin `M:`, sin pares ni subrutas). `deps` ∈ `fija` | `columna` | `garantizada` | `opcional`.
- `invariante` ∈ `normal` | `desde_nacimiento`.
- Lint de rutas (`RouteDB.lint`, T1): cada ruta cumple, con las etiquetas y entidades reales de sus fragmentos, las condiciones 3–5 de §1.6 y tiene 2 orígenes distintos.

**Acciones nuevas** (`core/sim/actions.gd`; C = comprometida):

| t | args | C | resultado / errores |
|---|---|---|---|
| `dq_answer` | `q`, `value` (`""` borra) | no | `{}` · `no_abierta`, `en_tinta`, `no_indexado`, `fuera_de_lista` |
| `dq_proof` | `q`, `slot` (0/1), `clip` (`""` borra) | no | `{}` · `no_abierta`, `en_tinta`, `no_existe`. Si el recorte está en la otra ranura, se mueve |
| `dq_confirm` | `q` | **sí** | `{inked:bool, msg, text}` · `{ok:false, err:"formal", formal:[falta_respuesta|faltan_pruebas|mismo_papel]}` (no gasta ni registra intento) · `no_abierta`, `en_tinta` |
| `examine` | `ref`: `"hub/<nodo>"` · `"missing/<copia>"` | no | `{}` (§4.4). Sólo la emite la UI para nodos con `aviso` y para faltantes |
| `ask_donde` | `char` (`crane`), `item` | **sí** | `{line, revealed?}` (§5.2) |

Se retiran del `SPEC`: `link`, `unlink`, `folio_open`, `entry_new`, `entry_set`, `entry_support_add`, `entry_support_remove`, `entry_delete`, `practice`, `pass_clean`, `clip_measure`. `clip_plate` queda (bots y tests), la interfaz no la emite. Cabecera de guardado `"v": 3`; un guardado `v` < 3 muestra «La partida se guardó con otra versión» y sólo ofrece partida nueva (sin replay). `.work/jugador/` no se toca.

**Consultas nuevas** (`GameSim`):
- `q_dossier()` → `{"open": [H], "inked": [H]}` con `H = {id, text, origin, doubts:[3], state:"lapiz"|"tinta", answer:{id,label}|null, proofs:[clip|null, clip|null], formal:[códigos], ink_text, variant}` (`clip` con la forma de `q_clip`). `open` en orden de aparición; `inked` en orden de tinta. Las preguntas en espera no aparecen.
- `q_answer_options(q)` → `[{id, label, kind}]`: entidades del índice con `kind` ∈ `acepta`, ordenadas por `label`.
- `q_donde()` → `[{id, phrase}]` (§5.2). `q_missing()` → `[{copy, title}]` (originales que faltan ahora en casa).
- `q_places()` suma `que_hay` (clave de ui_text) y `por_que: {via, ref, text}` (§5.3).

### 1.8 Etiquetas nuevas y reetiquetados

El dueño del archivo aplica el cambio (§7). «+» agrega; «→» reemplaza.

| Etiqueta (`a:`) | Tramos / nodos / líneas que la llevan |
|---|---|
| `corte_por_orden` | + `D04#cajista`, `D01N#fina_fo`, `D29a#tachadura`, **nuevo** `D33#lote_pruebas` |
| `mycroft_gobierno` | **nuevo** `D01.GREE#cuentas`; + `R:HB5.recibo` |
| `rasgo_de_harris` | `harris_es_moran` → `rasgo_de_harris` en `N:PRO.harris`, `N:M7.harris`, `S:PRO.fresco`, `S:M7.inteligente`, `D23#cruel`, `L:wiggins.conduit`; + `S:M7.trichinopolis`, `N:M7.ceniza`, **nuevos** `NC.<código>#tic` (6) |
| `rasgo_de_moran` | `harris_es_moran` / `estilo_o_rostro_moran` → `rasgo_de_moran` en `D16#moran`, `D10#frontispicio`, `D10#adjetivos`, `D10#cruel`, `D10#limpio`, `D11#sucio`, `D17#moran_conduit`, `D17#moran_93`; + `D11#trichinopolis` |
| `junto_a_adair` | `autor_moran` → `junto_a_adair` en `D15.0403#whist`; + `D16#moran` |
| `tiro_de_cazador` | `autor_moran` → `tiro_de_cazador` en `D10#bala_blanda`, `D11#mejor_tiro`; + `D10#aire` |
| `entro_por_los_techos` | **nuevos** `N:L1.ventana_abierta`, `L:crane.pasos_techo` |
| `chicos_de_holmes` | + `D43#oyen_todo`, `D43#agujas`, `D44#pilluelos`, `D44#fuerza`, `N:*.sil_wiggins` (rastro de HC02) |
| `entraron_por_la_puerta` | **nuevos** `N:L1.cerradura_rayada`, `N:L1.cajon_entreabierto`, `N:L1.silla_corrida`, `N:L1.ceniza_escritorio` |
| `senas_del_mayor` | + `S:M7.trichinopolis`, `N:M7.ceniza` |

Entidades implícitas nuevas (`e:`) que exigen las claves: `e:gobierno` en `D04#cajista`, `D01N#fina_fo`, `D33#lote_pruebas`, `D01.GREE#cuentas`; `e:muchacho` en `D43#oyen_todo`, `D43#agujas`, `D44#pilluelos`, `D44#fuerza`; `[[club_diogenes]]` mencionado en el examen de `N:L2.cotter_canastilla`. `harris_es_moran`, `estilo_o_rostro_moran`, `estilo_cartas_coronel` y `autor_moran` desaparecen de los datos (la confrontación pasa a leer `rasgo_de_moran`, §6.10).

**T4 sigue:** ninguna etiqueta de un grupo convive en el mismo tramo/nodo con una del otro grupo **de la misma variante** (un recorte nunca prueba las dos mitades).

### 1.9 Por qué probar al azar no sirve (números)

Sea `A` la cantidad de respuestas que ofrece el selector (entidades del índice de los tipos aceptados), `N` los recortes que tiene el jugador, `P = N(N−1)/2` los pares de pruebas, `a` las respuestas válidas (1–3 con alias) y `v` los pares válidos **entre los recortes que el jugador tiene** (las rutas de §2, típicamente 1–6).

`p(intento al azar) = (a · v) / (A · P)`

| Situación (mitad de juego) | A | N | P | a | v | p | Intentos esperados |
|---|---|---|---|---|---|---|---|
| Al azar | 25 | 40 | 780 | 1 | 4 | 2,1·10⁻⁴ | ≈ 4.900 (≈ 13 h a 10 s por intento) |
| Al azar, mucho recortado | 30 | 60 | 1.770 | 1 | 6 | 1,1·10⁻⁴ | ≈ 8.900 |
| Sabe la respuesta por Doyle, no las pruebas | 1 | 40 | 780 | 1 | 4 | 5,1·10⁻³ | ≈ 195, y **cero** si no recortó lo necesario |
| Tiene las pruebas, duda la respuesta | 25 | — | 1 | 1 | 1 | 0,04 | ≤ 25 |

- Cada recorte (≤15 palabras) hereda las etiquetas de **un** tramo: un grupo dado aparece en un 2–4 % de los recortes. Recortar todo no ayuda: el bot «recorta todo» tiene `N ≈ 2.500`, `P ≈ 3·10⁶`.
- **Saber no es probar:** sin dos recortes que cubran los grupos, ninguna respuesta pasa. Conocer el canon reduce `A` a 1, pero el jugador igual tiene que encontrar, leer y recortar las fuentes.
- **Riesgo aceptado (último renglón):** con las pruebas correctas, probar respuestas cuesta como mucho `A`. Se acepta porque elegir las dos pruebas **es** la deducción y casi siempre nombran la respuesta. Lo mismo hace Obra Dinn con los nombres.
- **T10 (presupuestos):** `bot_fuerza_bruta` (respuesta y par al azar, 100 intentos por pregunta) cierra ≤5 % de las preguntas en 20 semillas; `bot_sabelotodo` (respuesta correcta, par al azar, 50 intentos) se mide y se registra, sin umbral.

---

## 2. Rutas e invariante

### 2.1 Rutas por pregunta

★ = sólo fuentes inmutables (I). El orden de las dos pruebas no importa al validador; la tabla pone primero la del grupo 1. «Desde» incluye los atrasos de `schedule.stock` (D04/D07 en Crane desde `2.M`, D09/D10 `3.M`, D43/D44 `4.M`). Cortes: **M1** (Moran se lleva originales informados, 1 día), **HA5/HA6** (los de Holmes se llevan un original relacionado, 1 día; §4), **HB4**, **HB5**, **HB6**, **HB8b**, **M4**, **M5** (como en GDD §9).

| Ruta | Prueba 1 (grupo 1) | Prueba 2 (grupo 2) | Clases | Desde | Corte |
|---|---|---|---|---|---|
| **Q1.R2 ★** | `D03#sheer` @Crane | `D05#marque` @BM | I+I | 1.M | — |
| **Q1.R3 ★** | `D03#sheer` @BM | `D04#clausula` @Crane | I+I | 2.M | — |
| Q1.R1 | `D03#sheer` @tomo | `D02#clausula` @L1 | P+P | P.N | M1, HA5 |
| Q1.R4 | `D03#sheer` @BM | `D29a#tachadura` @L4 | I+C | 1.M | HB5, HB4 |
| Q1.R5 | `D03#sheer` @tomo | `D01N#fina_fo` @tomo | P+P | P.N | M1, HA5 |
| **Q2.R1 ★** | `D03#sheer` @Crane | `D05#corniche` @BM | I+I | 1.M | — |
| **Q2.R2 ★** | `D03#sheer` @BM | `N:RB.foto.linea` (D07@Crane) | I+I | 2.M | — |
| **Q2.R3 ★** | `D03#sheer` @Crane | `D08#kanzel` @BM | I+I | 1.M | — |
| Q2.R4 | `D03#sheer` @tomo | `R:D27.texto` | P+P | día siguiente al telegrama | M1, HA5 |
| **Q3.R2 ★** | `S:HC06.b_*` | `D31#para_mholmes` @L5 | I+I | 8.T | — |
| **Q3.R4 ★** | `N:L2.cotter_canastilla` | `D01.GREE#founders` @BM | I+I | 1.M | — |
| Q3.R1 | `R:HA1.fisica` | `D46#fisica` @L5 | P+I | 8.T | M1 |
| Q3.R1d | `R:HA1.fisica` | `N:L2.cesto_tiras` | P+I | 2.M | M1 |
| Q3.R3 | `R:HA1.*` | `D30#recibo` @L3 | P+C | 2.dawn | HB6, M1 |
| Q3.R6 | `R:HC01.sobre` | `D01.GREE#pall_mall` @BM | P+I | 1.M | M1 |
| Q3.R7 | `L:wiggins.vieja_tarifa` | `D01.GREE#whitehall` @BM | C+I | 3.M | HB8b |
| Q3.R8 | `R:HA1.giro` | `S:HC06.a` | P+I | 8.T | M1 |
| **Q4.R1 ★** | `D04#cajista` @Crane | `D01.GREE#cuentas` @BM | I+I | 2.M | — |
| **Q4.R2 ★** | `D33#lote_pruebas` @Crane | `D01.GREE#cuentas` @Crane | I+I | 2.M | — |
| Q4.R3 | `D01N#fina_fo` @tomo | `D01.GREE#cuentas` @tomo | P+P | P.N | M1, HA5 |
| Q4.R4 | `D29a#tachadura` @L4 | `R:HB5.recibo` | C+P | día siguiente a HB5 | — (opcional) |
| **Q5.R1 ★** | `D12#n97` @BM | `D13#muestra97` @BM | I+I | 1.M | — |
| **Q5.R2 ★** | `D44#oficios_mano` @Crane | `D14#opusculo` @BM | I+I | 4.M | — |
| **Q5.R3 ★** | `S:HC06.c` | `D31#telegramas` @L5 | I+I | 8.T | — |
| Q5.R2b | `D44#oficios_mano` @tomo | `D14#opusculo` @BM | P+I | 1.M | M1, HA5 |
| Q5.R4 | `D12#dedicatoria` @BM | `R:HC01.no_lo_es` | I+P | 1.M | M1 |
| **Q6.R1 ★** | `N:PRO.harris` (PL.prologo) | `D16#moran` @BM | I+I | 8.M | — |
| **Q6.R2 ★** | `S:M7.inteligente` | `D10#adjetivos` @Crane | I+I | 7.night | — |
| Q6.R3 | `D23#cruel` @L1 | `D10#cruel` @BM | P+I | 1.M | M1, HA5 |
| Q6.R4 | `N:M7.ceniza` (PL.M7) | `D11#trichinopolis` @BM | I+I | 7.night | — |
| Q6.R5 | `NC.<código>#tic` @tomo | `D10#adjetivos` @BM | P+I | 1.M | M1, HA5 |
| Q6.R6 | `L:wiggins.conduit` | `D17#moran_conduit` @BM | C+I | 4.dawn | HB8b, M4 |
| **Q7.R1 ★** | `D15.0403#whist` @L1 | `D10#bala_blanda` @BM | I+I | 8.dawn | — |
| **Q7.R2 ★** | `D16#moran` @Crane | `D11#mejor_tiro` @BM | I+I | 8.M | — |
| Q7.R3 | `D16#moran` @BM | `D10#aire` @Crane | I+I | 8.M | — |
| **Q8.R1 ★** (A) | `N:L1.ventana_abierta` | `D43#oyen_todo` @BM | I+I | intrusión HA5 | — |
| **Q8.R2 ★** (A) | `L:crane.pasos_techo` | `D44#pilluelos` @Crane | I+I | día siguiente a HA5 | — |
| Q8.R3 (A) | `N:L1.ventana_abierta` | `N:*.sil_wiggins` | I+I | intrusión HA5 | — |
| Q8.R4 (B) | `N:L1.ceniza_escritorio` | `S:M7.trichinopolis` | I+I | M1 y 7.night | — |
| Q8.R5 (B) | `N:L1.ceniza_escritorio` | `N:M7.ceniza` | I+I | M1 y 7.night | — |
| **Q9.Ca ★** | `D10#cabrito_atado` @BM | `S:M6.donde` | I+I | 5.dawn | — |
| **Q9.Cb ★** | `D11#no_bala` @BM | `S:M7.donde_duerme` | I+I | 7.night | — |
| Q9.Cc | `D10#cabrito_atado` @Crane | `R:HB7.col` | I+I | opcional | — |
| Q9.Cd | `D11#hacerlo_balar` @BM | `R:M2.nota` / `R:HB9.carta` | I+P | opcional | — |
| **Q10.R1 ★** (A) | `N:L3.ventanas_abiertas` | `S:HC05.jueves_a` | I+I | 8.M | — (HB6 no lo corta) |
| **Q10.R2 ★** (A) | `N:L3.cajon` | `S:HC06.e` | I+I | 9.T | — |
| Q10.R1b (A) | `N:L3.shag` | `S:HC05.jueves_a` | I+I | 8.M | — |
| **Q10.R3 ★** (B) | `S:M7.trichinopolis` | `N:L8.ceniza` | I+I | 7.T | — |
| **Q10.R4 ★** (B) | `S:PRO.cace_india` | `S:AGENTE.militar` | I+I | 7.M | — |
| Q10.R5 (B) | `N:PRO.harris` | `D32#llave_harris` @L3 | I+C | 7.M | M5 |

Ejemplares nuevos que exigen las rutas: `D43@tomo` y `D44@tomo` (P, `P.N`, las crónicas del cliente), `D01.GREE@Crane` (I, `1.M`: las *Memorias* de Newnes en el estante de Crane, que ya traen FINA), `NC.<código>@tomo` (P, `P.N`). `D33#lote_pruebas` está en una parte con `when: {"tk": {"gte": "2.M"}}`.

### 2.2 Invariante v3

**Definiciones** como GDD §10.3, con «conclusión» = **variante principal de una pregunta** y «ruta» = dos fragmentos que cumplen las condiciones 3–5 de §1.6 con dos orígenes.

**Invariante (T3).** Para todo estado alcanzable y toda pregunta `obligatoria` con `invariante: "normal"` que no esté en tinta, desde `P.N` hasta `8.N` (lectura del GDD §10.3 y ARCHITECTURE §12.1.9): (1) ≥2 rutas intactas de su variante principal; (2) ≥1 sólo-I; (3) sólo con `deps` ∈ {fija, columna, garantizada}; (4) ningún ejemplar ni escena común a todas las rutas de (1).

**Q8 (`desde_nacimiento`).** Se evalúa sólo en estados donde Q8 nació, desde ese tk: ≥2 rutas intactas y ≥1 sólo-I de alguna variante cuya firma ocurrió; no se exige (4). Razón: nace de una reacción; antes no existe. HA5 es `garantizada_por_acto` y deja dos huellas I en lugares distintos (la ventana y la línea de Crane).

**Por qué se cumple.** Toda variante principal tiene ≥2 rutas ★ sin ejemplar común (tabla §2.1): Q1 R2/R3 · Q2 R1/R2 · Q3 R2/R4 · Q4 R1/R2 · Q5 R1/R2 · Q6 R1/R2 · Q7 R1/R2 · Q9 Ca/Cb · Q10 R1/R2. Ninguna reacción toca un ejemplar I (T2) ni cierra su única fuente (D9). HA5/HA6 y M1 sólo retiran originales P un día (§4).

### 2.3 Qué cambia en `core/graph`

| Módulo | Cambio |
|---|---|
| `route_db.gd` | Lee `dossier.json` (`routes(repo, qid, variant := "")`, por defecto la principal). Sin `subroutes` ni `pair` ni refs `M:`. `lint` exige 2 fragmentos, 2 orígenes, cobertura de los 2 grupos por asignación, enlace por claves, y avisa referencias a documentos inactivos (§3.5) |
| `availability.gd` | Ejemplares nuevos (§2.1); documentos inactivos fuera; máscaras de HA5/HA6 (huellas desde la intrusión garantizada más temprana posible: primer acto observado desde el día 3) |
| `cut_model.gd` | Cortes de HA5/HA6 (`{"copias": "relacionada", "ventana": {"dias": 1}}`); M1 igual; desaparecen los cortes por `acceso` a canales que sólo usaba C6 |
| `invariant.gd` | Itera preguntas (`obligatoria`), variante principal; Q8 `desde_nacimiento`; alias por Q6 en tinta |
| `feasibility.gd` | `need` = ≥1 ruta ★ de la variante principal de cada pregunta obligatoria (Q8 excluida) |

### 2.4 Tests del grafo y la rampa

- **T1** (`test_t01_routes.gd`, CORE): para cada pregunta con `invariante: "normal"`, ≥2 rutas ★ de la variante principal sin ejemplar ni escena común; toda ruta (todas las variantes) pasa `RouteDB.lint` con los datos reales; ninguna ruta usa un documento inactivo.
- **T3** (`test_t03_invariant.gd`, CORE): §2.2 con el verificador acotado de ARCHITECTURE §5.6 (peor caso, descomposición por pregunta, factibilidad, *fuzzing* de 300 partidas; `--slow` 10.000); < 10 s.
- **T4** (`test_t04_max_clips.gd`, CORE): recortes legales máximos = ventanas de **15 palabras** dentro de una oración (y cada nodo/línea completo si tiene ≤15 palabras); ninguno cubre los dos grupos de ninguna variante.
- **T10** (`test_t10_bots.gd`, CORE): el deductor usa el oráculo de rutas ★ y llega a F1; el pasivo termina en F4; presupuestos de §1.9; el novato emite `read`, `examine` y `dq_*`; ningún bot supera el `rank` del deductor.
- **T24** (`test_t24_ramp.gd`, CORE): el novato toca `read`, `clip_text`, `compose_ad`, `sleep` en el prólogo y `dq_answer`, `dq_proof`, `dq_confirm` en el día 1 guiado (§6.9) antes de cualquier otro uso; los verbos retirados no existen.
- **T14** se reemplaza: sólo `dossier.gd` escribe `st.ded.dossier.inked`. **T06** (plantillas) se retira.

---

## 3. Las crónicas

### 3.1 Qué recibe Lisle

El cliente entrega, en el prólogo, **seis crónicas**: cuatro **cuadernillos de la Strand** sacados de los tomos que el mayor compró en la venta de Paddington (FINA, GREE, SCAN, TWIS: conservan al margen las notas a lápiz de Watson y de Mary) y dos libros: *Estudio en escarlata* (Beeton's, 1887) y *El signo de los cuatro* (Lippincott's, 1890). Van en el **estante** de la pieza junto con la prueba de imprenta de Lisle (D02), sus notas de lectura (D21) y el recorte de las cartas del coronel (D09@L1). El encargo (D23) va dentro del expediente.

En el mundo: el mayor descosió los tomos de Watson y sólo dio lo que le interesa para su cacería (el hermano, los chicos de la calle, los disfraces, la mujer del doctor). «Destruir es cosa de Moran» (GDD §9.4). El hueco del estante de Watson (EMPT, «five volumes») no cambia.

### 3.2 Ficha de Lisle, nota del cliente y marquitas

La **ficha** son tres renglones de Lisle (tinta tenue, arriba de la primera hoja, **no recortables**). La **nota del cliente** es una tarjeta de cartulina sujeta con un clip al final, escrita por Harris (lápiz grueso; documento propio `NC.<código>`, recortable, clase P). Las **marquitas** son una raya doble a lápiz grueso en el margen izquierdo, junto al tramo indicado (dibujo, no texto). Cada nota lleva un tramo `#tic` con la repetición de adjetivo de Harris (`a:rasgo_de_harris e:adjetivos_repetidos`).

| Crónica | Ficha (de qué trata · cuándo · por qué me la dio) | Nota del cliente (`NC.<código>`) | Marquitas (tramos) |
|---|---|---|---|
| **FINA** (`D03`) | «Watson cuenta cómo Holmes y el profesor Moriarty cayeron juntos en la cascada de Reichenbach, en Suiza.» · «Pasó en abril y mayo de 1891; salió en la Strand en diciembre de 1893.» · «El cliente quiere saber qué no contó el doctor en esta crónica.» | «El sendero y la carta, señor: ahí el doctor se apura. {{#tic…\|Léalos despacio, despacio.}} —H.» | `#sheer`, `#a_mycroft` |
| **GREE** (`D01.GREE`) | «Holmes le presenta a Watson a su hermano Mycroft, en el club Diógenes, y juntos ayudan a un intérprete griego.» · «Pasó hacia 1888; salió en la Strand en septiembre de 1893.» · «El cliente marcó todo lo que dice del hermano de Holmes.» | «El hermano, señor. {{#tic…\|Un hombre que va siempre del mismo sillón al mismo club deja un rastro fácil, fácil.}} —H.» | `#pall_mall`, `#whitehall`, `#club`, `#horario` |
| **STUD** (`D43`) | «Cómo se conocieron Holmes y Watson, y el primer caso que Watson contó.» · «Pasó en 1881; salió en el Beeton's de Navidad de 1887.» · «El cliente marcó a los chicos de la calle que trabajaban para Holmes.» | «Los chicos de la calle, señor. {{#tic…\|Si el difunto tuviera un recado que mandar, se lo daría a estos, a estos.}} —H.» | `#oyen_todo`, `#wiggins_solo` |
| **SIGN** (`D44`) | «Un tesoro robado, unas perlas y la señorita Mary Morstan, con quien Watson se casó después.» · «Pasó en 1888; salió en el Lippincott's de febrero de 1890.» · «El cliente marcó la monografía de las cenizas y a la señorita Morstan.» | «La ceniza dice quién fumó, señor, y la señorita Morstan dice dónde vive el doctor. {{#tic…\|Lea las dos cosas, las dos.}} —H.» | `#ceniza_negra`, `#oficios_mano`, `#conoce_mary` |
| **SCAN** (`D01.SCAN`) | «Holmes trabaja para el rey de Bohemia contra Irene Adler, la única que le ganó.» · «Pasó en marzo de 1888; salió en la Strand en julio de 1891.» · «El cliente marcó los disfraces de Holmes.» | «Fíjese en los disfraces, señor. {{#tic…\|Un hombre que se disfraza tan bien no necesita morirse para desaparecer, para desaparecer.}} —H.» | `#mozo`, `#clerigo` (tramos nuevos, §3.4) |
| **TWIS** (`D01.TWIS`) | «Un hombre desaparece y Holmes lo encuentra en el lugar menos pensado.» · «Pasó en junio de 1889; salió en la Strand en diciembre de 1891.» · «El cliente marcó un disfraz y la línea donde la esposa del doctor lo llama «James».» | «Un señor respetable que vive de mendigo, señor. {{#tic…\|Hasta los nombres se disfrazan, se disfrazan: lea cómo llama la señora al doctor.}} —H.» | `#viejo`, `#james` |

Las notas de STUD y SCAN («si el difunto tuviera un recado», «no necesita morirse») son a propósito cosas que **no cierran** en boca de un cliente que dice llorar a un muerto: abren la sospecha que Q6 formaliza.

### 3.3 Notas al margen de Watson y Mary

`D01N` deja de listarse como papel suelto: sus tramos se muestran **en el margen derecho** de la crónica correspondiente, junto al tramo ancla, con su propio origen (`D01N`, ejemplar `D01N@tomo`, `visible_cats: watson_privado`). Quedan `#fina_fo` (FINA, junto a `#sheer`), `#nov93` (FINA, al pie) y `#mi_james` (TWIS, junto a `#james`). `#herida` y `#nochebuena` están en crónicas inactivas: se borran.

### 3.4 Esquema de datos (dueño: CONTENIDO)

En cada documento de crónica activa (`D03`, `D01.GREE`, `D01.SCAN`, `D01.TWIS`, `D43`, `D44`) se agrega:

```json
"v3": {
  "ficha": {"trata": "…", "cuando": "…", "por_que": "…"},
  "nota_cliente": "NC.GREE",
  "marcas": [{"parte": "p1", "tramo": "pall_mall"}, {"parte": "p1", "tramo": "whitehall"}],
  "margen": [{"doc": "D01N", "tramo": "fina_fo", "junto_a": {"parte": "p7", "tramo": "sheer"}}]
}
```

- `D01N` lleva `"v3": {"solo_margen": true}`; cada `NC.*` lleva `"v3": {"tarjeta_de": "<id de crónica>"}`. Ninguno de los dos se lista solo en el estante.
- `NC.<código>` (`data/docs/NC/<código>.json`): `entity: "nota_del_cliente"`, `src_type: "papel_privado"`, `class: "P"`, `font: "manuscrito"`, `paper: "tarjeta"`, `paper_mm: [127, 76]`, ejemplar `NC.<código>@tomo` (`holder: "tomo"`, `P.N`). Su descripción física en `fisica.json` usa el medio nuevo `mano_harris` («a lápiz grueso: letra grande y apretada, que subraya dos veces»).
- Tramos nuevos obligatorios: `D01.GREE#cuentas` («Tiene una facultad extraordinaria para los números y revisa las cuentas de algunos ministerios.», `q:cuentas`, `src_en` de `tests/fixtures/canon/gree.txt`, `a:mycroft_gobierno e:mycroft e:gobierno`); `D01.SCAN#mozo` y `#clerigo` (los dos disfraces, con `q:` y `src_en` de `scan.txt`); `D33#lote_pruebas` («Mié. 28. Lote de papel de imprenta, al peso, de la imprenta de la Strand: pruebas que mandaron rehacer en noviembre por orden de un ministerio, según el que las trajo. 3 chelines.» con `a:corte_por_orden e:gobierno e:pedido_del_fo`, en una parte con `when` desde `2.M`); `D29a#tachadura` conserva su texto.
- **Tramos con etiqueta `a:` o `c:` de ≤30 palabras** (lint, §6.2). Lista inicial de los que hoy pasan de 30 y hay que partir o acortar (manda el lint): `D02#clausula`, `D04#clausula`, `D03#sheer`, `D05#corniche`, `D01.SCAN#marzo_1888`, `D09#oficio`, `D09#nota_redactor`, `D10#frontispicio`, `D10#cabrito_atado`, `D10#apostarse`, `D10#aire`, `D11#desague`, `D15.*#anarquistas`, `D20#subasta`, `D29a#tachadura`, y los rastros `pedidas` (HB5) y `conduit` (HB10). Al partir, el `#id` queda en la oración que afirma el hecho (GDD_v2 §A.5).

### 3.5 Las otras veinte, desactivadas sin borrar

`data/corpus.json` (dueño: CORE):

```json
{"activas": ["D03", "D01.GREE", "D01.SCAN", "D01.TWIS", "D43", "D44"],
 "inactivas": ["D01.BERY", "D01.BLUE", "D01.BOSC", "D01.CARD", "D01.COPP", "D01.CROO", "D01.ENGR", "D01.FIVE", "D01.GLOR",
               "D01.IDEN", "D01.MUSG", "D01.NAVA", "D01.NOBL", "D01.REDH", "D01.REIG", "D01.RESI", "D01.SILV", "D01.SPEC",
               "D01.STOC", "D01.YELL"]}
```

- `DataRepo` no carga los documentos de `inactivas` (quedan en el repo intactos) y expone `inactive_docs()`. Sus ejemplares del BM y sus fichas de catálogo desaparecen con ellos.
- Error de datos: cualquier `ref`, `match.doc`, huevo o ruta que nombre un documento inactivo (lint y T38).
- Un futuro «capítulo siguiente» los reactiva moviéndolos de lista.
- **Nota:** el pedido decía «las otras 18»; son **20** (las 24 historias de la Strand menos FINA, GREE, SCAN y TWIS; STUD y SIGN no son de la Strand).

### 3.6 Curiosidades (ex C1 y C14)

En `easter_eggs.json` (CORE), con disparador nuevo `{"clips_tag": "a:<etiqueta>", "n": 2, "pasajes_distintos": true}` y sin etiquetas de preguntas (T13):

| Id | Disparador | Nota de Lisle |
|---|---|---|
| EE-INC01 | 2 recortes con `a:inc01` | «Hombro en un libro, pierna en el otro. El doctor no sabe dónde lleva la bala.» |
| EE-INC02 | `a:inc02` | «En un libro firma John; su mujer lo llama James.» |
| EE-INC06 | `a:inc06` | «Casado en marzo del 88 y novio en septiembre del mismo año. Las fechas del doctor también se enamoran.» |
| EE-INC09 | `a:inc09` | «Julio en un capítulo, septiembre en el siguiente, y la misma tarde.» |
| EE14 | 1 recorte `a:tomos_de_watson` + 1 `a:duelo` | «Estos cuadernillos salieron de los tomos del doctor Watson. Los vendió en enero, después de su duelo.» → flag `curiosidad_tomos` (variante del epílogo «devuelve los cuadernillos») |

---

## 4. Intrusiones

### 4.1 Dos firmas

| | Los de Holmes (HA5, HA6) | Los de Moran (M1) |
|---|---|---|
| Quién | Un chico de los Irregulares (Wiggins o el muchacho que lo reemplaza), por orden permanente de Mycroft vía Cotter | Los hombres de Moran |
| Por dónde | Los techos y la ventana | La puerta, con ganzúa |
| Qué deja | Ventana abierta con la traba levantada **desde afuera**, hollín en el alféizar, dos hojas movidas por el viento cerca de la ventana; todo lo demás en orden | Rayones nuevos en la cerradura, cajón entreabierto, silla corrida, ceniza de cheroot de Trichinópolis **sobre el escritorio** |
| Qué se lleva | **Un** original P relacionado con lo que Lisle hizo ese día (§4.2) | **Los originales que Lisle le informó al cliente** (como hoy) |
| Cuándo vuelve | Solo, **al día siguiente** al amanecer, en su lugar del estante, con una marca chica a lápiz en el margen | **No vuelve solo**: los de Holmes lo recuperan y lo dejan en el mostrador de Crane al día siguiente (HB10, sin cambios) |
| Por qué | Mycroft hace copiar para su hermano lo que el corrector está trabajando (lee, no destruye: Ley 3) | Moran quiere lo que el cabrito encontró |

Reglas comunes: sin carteles, sin sonido de alerta; los recortes nunca se pierden (son copias); todo original vuelve como máximo al día siguiente; ≤3 intrusiones por partida (HA5 una vez, HA6 una vez, M1 como mucho dos; la tercera M1 no ocurre).

### 4.2 Reacciones nuevas y modificadas (dueño: REACCIONES-PIEZA)

**HA5 — «El muchacho de los techos» (nueva).** `tipo: "garantizada_por_acto"`, `lado: "mycroft"`, `voz: "A"`, `nivel: 2`, `actor: ["wiggins", "cotter"]`, `canal: "*"`.
- **Disparador:** el primer acto observado desde el día 3 (Wiggins trabaja desde el 3, HC02) por K-BM, K-W, K-H o K-T, siempre que haya en casa un original P relacionado (tabla siguiente). Una sola vez.
- **Original relacionado** (`relacion` en el JSON de la reacción; el primero que esté en casa y no retirado):

| Grupo del acto (`lists.topic_groups` o canal) | Se lleva |
|---|---|
| `roca` (FINA, pared, Reichenbach, galerada…) | `D02@L1`, si no `D03@tomo` |
| `mary` | `D01.TWIS@tomo` |
| `221b` (Mycroft, alquiler…) | `D01.GREE@tomo` |
| `sigerson`, papeleta de monografías | `D44@tomo` |
| papeleta de crónicas (`holmes_cronicas`) | `D03@tomo` |
| anuncio publicado (K-T) | `D23@L1` (el encargo, con el borrador del aviso) |

- **Latencia `intrusion`:** si el acto lo ve Cotter en el momento (K-BM, K-T), ocurre mientras Lisle sigue afuera en esa salida y se aplica al `leave`; si lo cuenta otro sensor esa noche (K-W, K-H), ocurre en la primera salida del día siguiente. Si Lisle no sale, de noche.
- **Efectos:** `{"op": "retirar", "copias": "relacionada", "dias": 1}`, `{"op": "alterar_lugar", "place": "L1", "variant": "techos"}`, y al amanecer siguiente `{"op": "devolver", "copias": "relacionada", "entrega": "estante", "marca": {"texto": "v.", "mano": "copista"}}` (el documento vuelve con un bloque al margen, origen `R.HA5.<n>`, clase P, sin etiquetas).
- **Rastro:** `N:L1.ventana_abierta` (`a:entro_por_los_techos e:techos e:muchacho`), `N:L1.papeles_viento` (sin etiquetas) y la línea de Crane `L:crane.pasos_techo` disponible desde la mañana siguiente.
- `corta: [{"copias": "relacionada", "ventana": {"dias": 1}}]`; `variante_blanda`: sólo la ventana abierta, no se lleva nada. `agrega: ["Q8"]`. Exenta de D2.

**HA6 — «Otra vez los techos» (nueva).** Igual que HA5, `tipo: "opcional"`, una vez: la primera vez, después de HA5, que Lisle **muestra** un original P a Watson o a Mrs. Hudson (evento `show` por K-W/K-H); se lleva ese mismo original.

**M1 (modificada).** Disparador, retiro y HB10 sin cambios. Cambia la variante `registrada` de L1 (§4.3): sin pisada, ceniza sobre el escritorio (no en el piso), con cerradura, cajón y silla. Rastro: `N:L1.ceniza_escritorio` (`a:entraron_por_la_puerta e:cheroot e:ceniza_negra`, **sin** `f:secreto_camden`), `N:L1.cerradura_rayada`, `N:L1.cajon_entreabierto`, `N:L1.silla_corrida` (todos `a:entraron_por_la_puerta`). `agrega: ["Q8", "Q6"]`. Máximo dos veces por partida.

**HB10:** sin cambios (devuelve por el mostrador de Crane lo que se llevó M1).

**Ley de la huella (T5, v3):** toda reacción del bando de Holmes que corta agrega etiquetas de Q3, Q5 u Q8; toda reacción de Moran que corta agrega etiquetas de Q6, Q8, Q9 o Q10.

### 4.3 Estados visuales de la pieza (`data/places/L1.json`, `world/props/l1.gd`)

Props nuevos en la base de L1: `hoja_ventana` (hoja baja de la guillotina, cerrada), `cortina`, `traba` (pestillo). Variantes:

| Variante | `move` | `add_props` | `hide_nodes` | `add_nodes` (examen) |
|---|---|---|---|---|
| `techos` | `hoja_ventana` sube 0,45 m; `cortina` rota 25° hacia adentro | `papeles_suelo` (2 hojas, junto a la ventana) | `ventana` | `ventana_abierta`: «Está abierta. Yo no la abrí. La traba está levantada desde afuera y en el alféizar hay hollín de los techos, con la marca de una suela chica, de [[muchacho\|muchacho]].» (`aviso: "HA5"`) · `papeles_viento`: «Dos hojas en el piso, junto a la ventana. Las movió el viento.» (`aviso: "HA5"`) |
| `registrada` | `silla` corrida y girada; `cajon` abierto 12 cm | `ceniza_escritorio` (`small.ash_pile` sobre el cuero) | — | `cerradura_rayada`: «Rayones nuevos alrededor del ojo de la cerradura. Yo cierro con llave.» · `cajon_entreabierto`: «El cajón está entreabierto. Yo lo dejo cerrado.» · `silla_corrida`: «La silla no está donde la dejé.» · `ceniza_escritorio`: «[[ceniza_negra\|Ceniza negra]] y escamosa sobre el cuero del escritorio, y la colilla de un [[cheroot\|cheroot]]. Yo no fumo cigarros.» (todos `aviso: "M1"`) |

- `hide_nodes` es un campo nuevo de variante: `WorldModel.plate_snapshot` (CORE) omite esos nodos.
- Duración: `techos` desde la intrusión hasta el final del día siguiente; `registrada` desde la intrusión hasta el final del día siguiente. Las dos pueden coexistir.
- Lo que falta: el estante muestra el hueco y su tarjeta lista «No está. La dejé acá anoche.» con el título del original (`q_missing()`).
- Ambiente al entrar a la pieza con `techos` activa: una ráfaga corta (`evt.corriente`, una vez, −20 dB) y la cortina se mueve 4 s. Subtítulo neutro «una corriente de aire». Con `registrada`, nada suena.
- Los mismos nodos se reflejan en `plates/PRO.json` y `plates/M7.json` sólo para la decoración (§6.4); las variantes viven sólo en L1.

### 4.4 Cómo nace Q8

- La UI emite la acción libre `examine {ref:"hub/<nodo>"}` al abrir la tarjeta de un nodo con `aviso`, y `examine {ref:"missing/<copia>"}` al tocar un faltante en el estante.
- El sim registra `st.ded.dossier.noticed[<rid>] = tk` y el expediente aplica el disparador `nota <rid>`. También nace al leer el documento devuelto con la marca (`leer R:HA5.*`).
- Ver la pieza cambiada no basta: hay que mirar (examinar la ventana, buscar el papel). Si el jugador no lo nota, Q8 no nace y no cuenta.

---

## 5. Dónde buscar: Crane y el plano

### 5.1 Crane se presenta

Escena automática `CRANE.intro` (`scenes/CRANE.json`, `place L1`, `area tienda`, `auto: true`, `once: true`) la primera vez que Lisle baja a la tienda (desde `1.M`; la tienda está cerrada la noche del prólogo y el domingo):

> —Abel Crane, librero de viejo, para servirle; y su casero, aunque eso usted ya lo sabe. Si busca algo impreso en Londres, señor, pregúnteme **dónde**: lo que no tengo yo, sé quién lo tiene.

Desde entonces el panel de Crane tiene, además de «Preguntar», la lista **«¿Dónde consigo…?»**.

### 5.2 «¿Dónde consigo…?» (`dialogue/crane.json`, sección `donde`; motor: CORE)

Cada ítem se ofrece cuando Lisle **conoce** (`st.world.known`: leyó, oyó o recortó) alguna de las entidades de `requiere` (`[]` = siempre). Crane contesta en personaje; si `revela` no estaba en el plano, entra con `via: "crane"`. Preguntar es gratis y sin límite; la acción es `ask_donde` (comprometida, no pública: Crane no es canal).

| Id | Frase de Lisle | Requiere conocer | Crane contesta | Revela |
|---|---|---|---|---|
| `donde.diarios` | «¿Dónde consigo diarios viejos, de cualquier año?» | — | «Los del año pasado los tengo yo, atados, y me llegan más esta semana. Los de cualquier año, en el Museo Británico: tienen todo lo que se imprimió en el reino. Usted tiene carnet, señor.» | L2 |
| `donde.extranjero` | «¿Dónde leo diarios de Suiza o de Francia?» | journal_de_geneve, suiza, meiringen, reichenbach | «En la Sala de Periódicos del Museo, señor. Pida el número por la fecha.» | L2 |
| `donde.registros` | «¿Dónde se ve si alguien murió, o qué dejó al morir?» | testamento, herencia, bienes, muerte, duelo, mary_watson | «En Somerset House, en el Strand, a diez minutos: muertes, nacimientos y testamentos. Un chelín por búsqueda, de diez a tres.» | L6 |
| `donde.club` | «¿Dónde queda el club Diógenes?» | club_diogenes | «En Pall Mall, señor, pero no tiene cartel. La portería toma recados de cualquiera; adentro no entra nadie que no invitan.» | L5 (portería) |
| `donde.direcciones` | «¿Dónde busco la dirección de alguien en Londres?» | — | «En el Kelly's, señor: lo tengo ahí, el de este año y el del pasado. Si alguien no figura, es que no quiere que lo encuentren.» | — (D17 en la tienda) |
| `donde.suiza` | «¿Dónde consigo fotos o guías de Suiza?» | suiza, reichenbach, meiringen | Antes de `2.M`: «Me entran unas fotos de recuerdo esta semana, señor. Guías de viaje hay en el Museo.» Desde `2.M`: «Fotos de recuerdo, en la caja del mostrador. Guías de viaje, en el Museo.» | L2 |
| `donde.casas` | «¿Dónde se averigua quién alquila una casa?» | camden_house, casa_vacia, agente_de_fincas | «En la agencia de la misma calle, señor: llevan un libro de llaves y un chico que muestra las casas.» | L3 |
| `donde.crimen` | «¿Dónde leo lo que se sabe de un crimen?» | park_lane, ronald_adair | «En el Times, señor; cuando declaren los testigos, también en el Daily Graphic, con dibujos. Y la casa la ve cualquiera desde la vereda.» | L7 |
| `donde.telegrama` | «¿Cómo mando un telegrama a Suiza?» | meiringen, steiler | «Escríbalo con su tintero, señor, y mi chico lo lleva a la oficina del Strand.» | — |
| `donde.watson` | «¿Dónde atiende el doctor Watson?» | watson | «En Kensington, por la mañana. El Kelly's del año pasado todavía lo pone en Paddington, señor.» | L4 |

Como máximo 7 ítems a la vista (GDD_v2 §C.1); si hay más, los ya preguntados van abajo, plegados.

### 5.3 El plano

Cada marcador muestra, al pasar el mouse, tres renglones: **qué hay** (estilo guía de época), **por qué está** y el horario (`map.json hours`). Textos en `ui_text/v3_plano.json` (CONTENIDO):

| Lugar | `plano.que_hay.<L>` | `plano.por_que.<L>` (si llegó por la garantía de hora) |
|---|---|---|
| L1 | «Holywell Street: mi pieza y, abajo, la librería de Crane: libros usados, diarios atrasados, guías de viaje, fotografías.» | — |
| L2 | «Museo Británico, Sala de Lectura: libros y diarios de cualquier año, a pedido.» | «Es mi lugar de trabajo.» |
| L3 | «Baker Street: la casa del 221B, la calle y una agencia de alquileres.» | «Holmes vivía ahí: lo dicen todas las crónicas.» |
| L4 | «Kensington, consultorio del doctor Watson: atiende por la mañana; el domingo recibe en su casa.» | «Lo dice el encargo.» |
| L5 | «Club Diógenes, Pall Mall: club de caballeros; la portería atiende a cualquiera.» | «Lo dice la tarjeta del señor Mycroft.» |
| L6 | «Somerset House: registros de muertes, nacimientos y testamentos.» | «Lo nombra un aviso del Times.» |
| L7 | «Park Lane 427: la casa del crimen; se ve desde la vereda.» | «Lo dice el Times del sábado.» |
| L8 | «Camden House: casa vacía que se alquila; la muestra el chico de la agencia.» | «Me lo dijo el chico de la agencia.» |

**Por qué apareció** (`q_places().por_que`, generado por `Reveal` con `st.world.revealed_via[L] = {via, ref}`): `via: "leer"` → «Lo menciona: «<título del documento>».» · `via: "oir"` → «Lo dijo <nombre del personaje>.» · `via: "crane"` → «Me lo dijo Crane.» · `via: "garantia"` → la línea de la tabla.

### 5.4 Viaje

- El plano está **sólo en la pared** de la pieza (nodo `mapa`). No hay cinta en el HUD ni tecla M.
- Cada salida es **pieza → lugar → pieza**: `go` a un lugar que no sea la tienda sólo se acepta desde la buhardilla (`err: "desde_casa"`); `leave` de cualquier lugar vuelve a la buhardilla. La tienda de Crane se alcanza por la puerta y no gasta turno (sin cambios).

---

## 6. Interfaz

### 6.1 El expediente (UI-EXPEDIENTE, `ui/expediente/*`)

- **Objeto:** carpeta de cartón sobre el escritorio (nodo `expediente`, reemplaza a `libro_mayor`). Clic = abre (capa 20). Fuera de casa, la cinta «Expediente» del HUD (§6.4).
- **Vista (dos páginas):** izquierda, el índice de la carpeta: «El encargo» (abre D23 en el lector), las preguntas abiertas (≤3, con su texto) y, plegadas, «En tinta (n)». Derecha, la hoja elegida: pregunta en letra de Lisle; origen (una línea, chica); dudas (≤3, lápiz); **Respuesta: ___**; **Pruebas:** dos ranuras con forma de tarjeta; botón **«Pasar en limpio»** (aparece cuando las tres ranuras están llenas).
- **Respuesta:** clic en la ranura → selector con buscador y la lista de `q_answer_options(q)` (≤7 a la vista, el resto con el buscador); también se puede soltar una ficha del Índice del cuaderno. `dq_answer`.
- **Pruebas:** se sueltan recortes **directamente** desde el cuaderno (que se acopla a la izquierda al abrir la carpeta); cada ranura muestra la tarjeta completa del recorte (§6.2). Soltar sobre una ranura ocupada reemplaza. Clic derecho en una ranura la vacía. `dq_proof`.
- **Lápiz y tinta:** el borrador se ve en grafito gris; la tinta, negra con la letra de Lisle. Una hoja en tinta muestra el texto de Lisle, la respuesta y las dos pruebas (sin poder tocarlas).
- **Mensajes:** los de forma junto a la ranura; «Algo no cierra.» en la voz de Lisle, debajo del botón, 3 s.
- Sin contadores de preguntas, de intentos ni de pendientes.

### 6.2 Recortes (UI-EXPEDIENTE para las tarjetas; CORE para las reglas)

- **Tope: 15 palabras**, una sola oración (`ClipRules.MAX_WORDS = 15`; error `mas_de_15`, línea de Lisle «Me alcanza una frase corta.»). Herencia sin cambios: etiquetas del tramo ganador si cubre ≥50 % de él. Por eso todo tramo con etiquetas `a:`/`c:` mide ≤30 palabras (lint de `Markup`/`DataRepo`, error de datos).
- Todo lo del 3D (nodos, siluetas, personajes) se recorta **del texto de su tarjeta de examen** con la misma tijera (`src {kind:"node"}`); los exámenes con etiquetas también ≤30 palabras.
- **Tarjeta** (cuaderno, ranuras del expediente, informe, mostrar): papel claro con borde de 1 px y 8 px de margen interno; el texto en la letra del documento; abajo, en letra chica (≈70 %), la línea de fuente (««El problema final», crónica»); las entidades, sólo al pasar el mouse. Entre tarjetas, 10 px.
- **T4** con ventanas de 15 palabras (§2.4).

### 6.3 Lo que se elimina (y quién lo borra)

| Qué | Dueño |
|---|---|
| Pares/Cotejos: pestaña, soltar recorte sobre recorte, acción `link` | UI-EXPEDIENTE (UI), CORE (sim) |
| Libro de conclusiones, folios, plantillas, sello, práctica, «Lo que me preguntaron»: `ui/ledger/*` se borra; `ui/epilogue/blue_pencil.gd` lee el expediente | UI-EXPEDIENTE |
| `core/deduction/ledger.gd`, `lists.templates/verbos/relaciones/estados/preguntas`, `conclusions.json` | CORE |
| Hojas de aviso duplicadas (`pliegos`): sólo el **tintero** escribe avisos, telegramas y cartas | UI-MUNDO (`map.json`), REACCIONES (nodo en L1) |
| Cinta «Plano» del HUD, tecla M, tecla Espacio («mirar alrededor»), etiqueta flotante (`ui/desk/hover_label.gd`), contorno rojo permanente | UI-MUNDO |
| Pila de poses general → zona → examen; botón «‹ Alejarse» | UI-MUNDO |
| Rectángulo de tijera sobre el 3D y `ui/desk/scissors3d.gd` | UI-MUNDO |
| Decoración examinable de la pieza (§6.4) | REACCIONES (L1), CONTENIDO (PRO, M7) |

### 6.4 La pieza

**Interactivos de la buhardilla** (nodos de L1 con `examine`; `map.json objects.L1`):

| Nodo | Cursor | Al clic |
|---|---|---|
| `bandeja` | mano | bandeja (`tray`) |
| `tintero` | mano | compositor (`compose`) |
| `cuaderno` | mano | cuaderno (`notebook`) |
| `expediente` | mano | expediente (`dossier`, nuevo) |
| `mapa` | mano | plano (`map`) |
| `estante` | mano | lista de papeles de casa (`docs`, `via: ["tome", "desk"]`): las 6 crónicas, D02, D21, D09@L1 y lo devuelto; los faltantes con «No está.» |
| `puerta` | mano | baja a la tienda (`go L1 tienda`) |
| `ventana` | lupa | tarjeta de examen (afuera se ven las siluetas, que se examinan aparte) |
| nodos de intrusión (§4.3) | lupa | tarjeta de examen + `examine` |
| `calle`, `enfrente` (vistos por la ventana) | lupa | tarjeta |

Se quitan de `nodes` (quedan como props sin examen ni hover): escritorio, cajón (salvo en `registrada`), tomos, calendario, sello, lámpara, atril, libro_mayor, tijera, monedas, silla (salvo en `registrada`), mesita, pliegos, concordancia, estuche, brazos de gas, estufa, cama, lavamanos, percha, media_luna, puesto_libros, farol. En la tienda se quitan `estantes_sermones`, `estantes_varios`, `estantes_fondo`, `escaparate`, `puerta_calle`.

**HUD:** el calendario (fecha y turno; clic = terminar el turno, dormir de noche o volver de una visita, con confirmación), la tira Pendientes y, **sólo fuera de la buhardilla** (lugares, tienda, escenas), las cintas «Cuaderno» y «Expediente». Teclas que quedan: Tab (cuaderno), E (expediente), C (tijera), Esc/clic derecho (volver).

### 6.5 Hover y cursores (UI-MUNDO)

- Al pasar el mouse sobre un nodo o personaje: **sólo un contorno blanco** (`#ffffff`, α 0,9, 2 px a 900 p) y el cursor: **lupa** si se mira, **mano** si se usa (usable = vínculo en `map.json objects`, salida, personaje en primer plano, silueta con la que se habla). Nada más: sin etiqueta, sin aclarado, sin contorno permanente.
- Códigos en la rugosidad: se quedan 1,00 (escenario), examinable y bajo el mouse; desaparece el código «usable permanente». El quad de afordancias dibuja sólo el borde del código «bajo el mouse».
- T34 se reescribe: contorno blanco sólo bajo el mouse; ningún píxel de contorno sin hover; cursor correcto con eventos reales.

### 6.6 Cámara (UI-MUNDO)

- **Sin posiciones intermedias:** un clic usa el objeto en el acto (abre su panel o su tarjeta) **sin mover la cámara**. No hay zona ni examen con órbita.
- **Riel por área** (`world/camera.json`): `{"<lugar>.<área>": {"rail": [{"yaw": -70, "pos": […], "look": […], "fov": 58}, …], "yaw": [min, max]}`. Mientras el jugador gira (bordes, arrastre o flechas), la cámara **interpola sola** posición, mirada y FOV entre los dos puntos del riel que rodean al giro actual (Catmull-Rom; suavizado `x += (obj − x)·(1 − e^(−8·dt))`). Así, mirando al escritorio la cámara se acerca al escritorio; mirando la pared, se para frente al plano; mirando la ventana, se acerca a la ventana.
- Buhardilla: 5 puntos (puerta, estante, escritorio, ventana, plano); tienda: 4; cada lugar: sus encuadres actuales como puntos del riel, ordenados por yaw. Los drivers y el tutorial siguen pudiendo pedir `set_frame(id)` (salta al punto del riel con ese id).
- Rueda: zoom de FOV ±(−18°, +4°) hacia el cursor, sin traslación. Clic derecho/Esc cierra el panel abierto; con nada abierto, abre Opciones.
- T32 se reescribe: interpolación continua (saltos < 3° y < 5 cm por cuadro a 60 fps), límites, clic usa sin mover la cámara, con ventana y mouse real sin `--fast`.

### 6.7 Lector (LECTOR, `ui/reader/*`)

- **Flotante:** detrás del papel, la escena 3D desenfocada y oscurecida un 25 % (`ColorRect` con shader `canvas_item` que lee `hint_screen_texture, filter_linear_mipmap` con `textureLod(…, 2.5)`). El papel es **recto** (el texto nunca se rota) con sombra proyectada en perspectiva (polígono de sombra inclinado 2°, desplazado 10/14 px) y un degradé de luz muy leve de arriba a la izquierda: se lee como una hoja levantada frente a la cara.
- **Tijera:** un ícono suelto dibujado por código (tijera de tinta, 28 px), arriba a la derecha, afuera del papel. Sin recuadro y sin la palabra «Tijera». Clic o C la toman o la dejan; con la tijera en la mano el cursor es una tijera.
- **Paginación:** abajo al centro, debajo del papel: «‹  2 / 5  ›» (flechas clicables; ←/→ también). Con una sola hoja, nada.
- **Márgenes:** columna izquierda de 14 mm para las **marquitas del cliente** (raya doble a lápiz grueso a la altura de la primera línea del tramo marcado); columna derecha de 38 mm para las **notas a lápiz** (Watson, Mary, la marca del copista), en letra manuscrita gris, alineadas con su tramo ancla (si chocan, se apilan hacia abajo), separadas del cuerpo por 6 mm de papel en blanco. Se recortan con la tijera como cualquier bloque (su origen es el de la nota, no el de la crónica).
- **Ficha de Lisle:** tres renglones en tinta tenue arriba de la primera hoja de cada crónica, no recortables.
- **Tarjeta del cliente:** última hoja, en cartulina (`#e9dcb8`), más chica, con un clip dibujado arriba; recortable.
- Se mantienen: zoom con la rueda, descripción física, defectos de la Remington, luz rasante, alto contraste.
- **Forma de `q_view` v3** (la produce CORE en `WorldModel.view`):

```text
{view, title, src_line, paper, paper_mm, font, machine,
 ficha: {trata, cuando, por_que} | null,
 pages: [[{doc, origin, copy, parsed, slot: "cuerpo"|"margen"|"tarjeta", hand?, anchor?: {block, tramo}, segs?}]],
 marks: [{page, block, tramo}]}
```

### 6.8 Sonido (REACCIONES-PIEZA, `audio/*`, `data/audio.json`)

- Se retira `amb.gas` y `amb.gas_parker` de todo uso. Noche en la pieza y láminas PRO/M7: `amb.noche` nuevo (casi silencio: un coche lejano cada 20–40 s, una campana de cuarto de hora; en PRO, el arpa de Parker lejos, de vez en cuando).
- **Regla de calma (test nuevo T35, `audio/analysis.gd`):** todo ambiente en bucle tiene RMS ≤ −32 dBFS y, en la banda de 2–8 kHz (siseo), ≤ −40 dBFS; los eventos sueltos del ambiente están separados ≥8 s; el tic del reloj (L4 estudio) ≤ −26 dBFS. Lo puntual (tijera, papel, plumín, campanas del amanecer) no cambia.
- Nuevo `evt.corriente` (ráfaga de 3 s, ruido rosa filtrado 200–900 Hz con envolvente suave) y el evento `intrusion_techos: ["evt.corriente"]`.
- T28 actualiza los *hashes*.

### 6.9 Tutorial, Pendientes y revelado

**Prólogo** (bloquea; instructores Pell y Harris):
1. **read** — Pell: «Antes que nada, abra el expediente y lea el encargo. La familia quiere saber una sola cosa.» (abrir el expediente y leer D23).
2. **clip** — Pell pide recortar el aviso al pie del encargo (sin cambios).
3. **ad** — Harris: el aviso con el tintero (sin cambios).
4. **sleep** — Pell se despide.

D23 (CONTENIDO) se reescribe: una sola pregunta numerada («Primero: la familia quiere saber qué no contó el doctor en «El problema final».»), las seis crónicas en el punto Quinto (§3.1), y «Para el jueves 5 de abril, por lo menos seis respuestas confirmadas, con sus pruebas.»

**Día 1** (guía con notas de Lisle; no bloquea; cada paso se cumple por estado):
5. «Leo «El problema final», que está en el estante.» (`read` de D03) → nace Q2.
6. «Una respuesta y dos pruebas: dos recortes de papeles distintos.» (≥2 recortes y una hoja con respuesta y dos pruebas).
7. «Paso en limpio la pregunta del cliente.» (`dq_confirm` de cualquier pregunta).

**Pendientes** (≤3 líneas): obligación con hora de hoy · novedades (lugar nuevo, Crane, «Una pregunta nueva en el expediente.») · papeles de hoy sin abrir · lugares conocidos sin visitar. Se quitan la práctica y la pregunta en rotación.

**`q_ui()` v3:** se retiran `lg.*`, `nb.pares`, `hud.libro`, `look.ayuda`, `map.recuerdos` sigue; se agregan `desk.expediente` (desde el paso read), `hud.cintas` (falso en la buhardilla), `exp.pasar` (por hoja: tres ranuras llenas), `sc.donde` (Crane presentado).

### 6.10 Informes, mostrar, Mycroft, confrontación y finales (adaptadores)

- **Ítems de informe y de «Mostrar»:** recortes o **preguntas** (`{kind:"pregunta", id}`, en lápiz o en tinta). `Dossier.item_view(st, repo, q)` → `{q, answer, inked, variant, tags}` (tags = unión de las etiquetas de sus dos pruebas).
- **Categorías de Moran** (`lists.report_cats` v3; las lee `MoranAgent.report_cats`):

| Categoría | Pregunta (respuesta, lápiz o tinta) | Recorte |
|---|---|---|
| `holmes_vive` (M2, F2) | Q5 con `holmes` | `c:holmes_vive` |
| `regreso_jueves`, `baker_street` (M5, F2) | Q10 con `holmes` | `c:regreso_jueves`, `c:baker_street` |
| `camden` (M5, F2) | Q10 con `moran`/`harris`/`autor_heavy_game` | `c:camden` |
| `moran_autor` (M4) | Q6, Q7 o Q8 con `moran`/`harris`/`autor_heavy_game`; Q9 con cualquier respuesta | — |
| `verdadero` (crédito) | Q1 o Q2 **en tinta** | `c:verdadero` |
| `falso_verificable` (M9) | Q10 en lápiz con una persona que no es Holmes, Moran ni Harris | — |
| `watson_privado`, `original_p`, `paradero_extranjero`, `respuesta_s` | — | sin cambios |

- **HB12 (Mycroft):** se le muestra **Q3 en tinta**; vale si ninguna de sus dos pruebas tiene origen `S.HC06`. Ofrece el informe trampa.
- **Confrontación:** cada afirmación se responde con un recorte o una pregunta en tinta cuyas etiquetas contengan el grupo. Afirmación 1: `rasgo_de_moran` (antes `harris_es_moran`); 2: `cornisa_existe` o `raspadura_registrada`; 3: `ancla_*`; 4: `librero_falso`.
- **Finales** (`endings.json`, átomos nuevos de `Cond`: `inked: "Q3"`, `inked_all: [...]`, `inked_count: {gte|lt}`):
  - **F1:** `inked_all ["Q3","Q6","Q9"]` ∧ `inked_count ≥ 7` ∧ informe final = trampa ∧ ¬`watson_expuesto` ∧ `moran_credito` ∧ ¬`moran_credito_perdido` ∧ ¬`holmes_entregado`.
  - **F4:** `inked_count < 6` (el contrato pide seis).
  - **F2, F3a, F3b:** sin cambios (con las categorías de arriba).
  - Variantes: `V.C11` → Q7 en tinta; `V.C14` → flag `curiosidad_tomos`; el resto sin cambios. **Lápiz azul:** por pregunta obligatoria nacida sin tinta, `blue_pencil.missing`; por hoja en lápiz completa que no cierra, `blue_pencil.wrong`.

---

## 7. Plan de implementación

### 7.1 Contratos que se publican primero (día 0) para trabajar en paralelo

Todo lo que necesitan los demás ya está fijado en este documento; además:

1. **CORE publica stubs que compilan** (primera hora): `core/deduction/dossier.gd` con las firmas de abajo, las acciones nuevas en `Actions.SPEC`, `q_dossier`, `q_answer_options`, `q_donde`, `q_missing`, `data/dossier.json` completo según §1.3/§2.1, `data/corpus.json`, y fixtures en `tests/fixtures/v3/` (un `GameSim` con Q1 abierta y una en tinta, recortes de ejemplo, una vista de FINA con margen y tarjeta) para que las UI prueben sin esperar.

```gdscript
# core/deduction/dossier.gd (CORE)
static func init_state(st, repo) -> void          # st.ded.dossier = {open:{}, waiting:[], drafts:{}, inked:{}, attempts:{}, noticed:{}, born:{}}
static func update(st, repo) -> void              # nacimientos y tope; GameSim lo llama tras cada apply y en cada tk cruzado
static func act_answer(st, repo, a) -> Dictionary
static func act_proof(st, repo, a) -> Dictionary
static func act_confirm(st, repo, a) -> Dictionary
static func act_examine(st, repo, a) -> Dictionary
static func check(st, repo, qid: String, opts := {}) -> Dictionary   # {ok, variant, formal:[]}; opts.exclude_origins
static func view(st, repo) -> Dictionary          # q_dossier
static func answer_options(st, repo, qid: String) -> Array
static func item_view(st, repo, qid: String) -> Dictionary
static func inked(st) -> Dictionary
static func alias_groups(repo, st) -> Array
```

2. **Hooks entre paquetes:**
   - `Clock.act_leave` (CORE) llama a `Director.on_leave(st, repo, visit_id)` (REACCIONES) para la latencia `intrusion`.
   - `Effects` (REACCIONES) escribe `st.world.withdrawn` (como hoy), `st.world.marcas[<copia>] = [{tk, texto, mano, iid}]`; `WorldModel.view` (CORE) los lee y arma los bloques `margen`.
   - Variantes de lugar: campo nuevo `hide_nodes` (CORE lo aplica en `plate_snapshot`); campo `aviso` en nodos (REACCIONES lo escribe, la UI lo lee en `q_hub_plate().node_defs`).
   - `MoranAgent.report_cats` (REACCIONES) usa `Dossier.item_view` (CORE) para ítems `pregunta`.
   - Audio: `Audio.play_event("intrusion_techos")` lo llama UI-MUNDO al mostrar la buhardilla con `techos` por primera vez en esa visita.
3. **Ids fijos** (nadie los cambia): preguntas Q1–Q10 y variantes A/B; etiquetas de §1.8; nodos `ventana_abierta`, `papeles_viento`, `cerradura_rayada`, `cajon_entreabierto`, `silla_corrida`, `ceniza_escritorio`, `expediente`, `estante`; props `hoja_ventana`, `cortina`, `traba`; variantes `techos`, `registrada`; reacciones HA5, HA6; documentos `NC.FINA`, `NC.GREE`, `NC.STUD`, `NC.SIGN`, `NC.SCAN`, `NC.TWIS`; tramos de §3.4; línea `L:crane.pasos_techo`; escena `CRANE.intro`; ítems `donde.*`; claves de ui_text `exp.*` (UI-EXPEDIENTE), `mundo.*` (UI-MUNDO), `lector.*` (LECTOR), `plano.*` (CONTENIDO), `v3core.*` (CORE), `react.*` (REACCIONES).
4. **Entidades nuevas** (cada paquete en su archivo `data/entities/v3_<paquete>.json`; duplicado = error): CORE — ninguna; REACCIONES — `techos`, `muchacho`, `traba`, `cerradura`, `suela_chica`, `hoja_ventana`; CONTENIDO — `gobierno`, `nota_del_cliente`, `mano_harris` (si hace falta como entidad), y las que pidan sus textos nuevos.

### 7.2 Paquetes y dueños (archivos disjuntos)

#### P1 · CORE-EXPEDIENTE
**Posee:** `core/deduction/*` (nuevo `dossier.gd`; borra `ledger.gd`; `validator.gd` queda con `tag_match`, orígenes y claves; `clipper.gd` sin pares), `core/text/clip_rules.gd`, `core/text/markup.gd` (lint ≤30 palabras en tramos etiquetados), `core/sim/*`, `core/scenes/*`, `core/graph/*`, `core/data/*`, `core/util/cond.gd`, `data/dossier.json` (nuevo), `data/corpus.json` (nuevo), `data/conclusions.json` (se borra), `data/lists.json`, `data/schedule.json`, `data/endings.json`, `data/easter_eggs.json`, `data/entities/v3_core.json`, `data/ui_text/v3_core.json`, `devtools/bots/*`, `devtools/scripts/*`, `devtools/lint.gd`, `devtools/play_cli.gd`, tests T01, T03, T04, T06 (borra), T09, T10, T13, T14, T17, T18, T24, T25, T26, T36 (`test_t36_dossier.gd`, nuevo), T38 (`test_t38_corpus.gd`, nuevo), `test_i_integration`, `test_slice_*`, `test_u_dossier` (nuevo; borra `test_u_validator` y `test_u_ledger`), `test_u_clip_rules`, `test_u_clipper`, `test_u_guide`, `test_u_ui_state`, `test_u_tutorial`, `test_u_reveal`, `test_u_route_db`, `test_u_availability`, `test_u_invariant`, `test_u_feasibility`, `test_u_cut_model`, `test_u_dialogue`, `test_u_composers`, `test_u_endings`, `test_u_game_sim`, `test_u_actions`, `test_u_world_model`, `test_u_repo`, `test_u_schema`, `test_u_cond`, `tests/fixtures/v3/`.
**Aceptación:**
- [ ] Partida nueva: en `P.N`, tras abrir el expediente, `q_dossier().open` = [Q1]; tras `read` de la hoja de `D03#sheer`, nace Q2; Q3 nace el `2.dawn` en un pasivo; Q5 el `4.dawn`; Q6 y Q7 el `5.dawn`; Q9 el `7.night`; Q10 a más tardar el `9.dawn`. Con 3 abiertas, la cuarta espera y aparece al cerrar una o el `8.dawn`.
- [ ] `dq_confirm` con cada ruta de §2.1 (respuesta válida) da `inked: true` y el texto en tinta exacto; cambiando la respuesta, una prueba o el orden de los grupos por otra inválida da «Algo no cierra.»; los tres errores de forma no registran intento.
- [ ] Alias: Q7 con `harris` falla antes de Q6 en tinta y pasa después.
- [ ] `clip_text` de 16 palabras → `mas_de_15`; lint de datos falla con un tramo etiquetado de 31 palabras.
- [ ] T1, T3 (<10 s), T4, T10 (deductor F1, pasivo F4, fuerza bruta ≤5 %), T24, T25, T36, T38 verdes; `test_i_integration` verde con los datos v3.
- [ ] Ningún documento inactivo se carga; `grep` de `conclusions.json`, `pass_clean`, `folio_open`, `"link"` en `game/core` y `game/data` = 0.
- [ ] Guardado `v:3`; replay determinista (T9); un guardado v2 ofrece sólo partida nueva y no toca `.work/jugador/`.

#### P2 · REACCIONES-PIEZA
**Posee:** `core/react/*`, `data/reactions/*.json`, `data/places/L1.json`, `world/props/l1.gd`, `audio/*`, `data/audio.json`, `data/entities/v3_reacciones.json`, `data/ui_text/v3_reacciones.json`, tests T02, T05, T08, T11, T12, T15, T16, T22, T23, T28, T35 (`test_t35_calma.gd`, nuevo), T37 (`test_t37_intrusiones.gd`, nuevo), `test_u_director`, `test_u_effects`, `test_u_holmes_agent`, `test_u_moran_agent`, `test_u_sensors`, `test_u_latency`, `test_u_l1`, `test_u_sound_bank`, drivers `devtools/drivers/v3pieza_*.gd`.
**Aceptación:**
- [ ] HA5: con una papeleta de crónicas el día 3 por la mañana, al volver a casa esa franja falta `D03@tomo`, la variante `techos` está activa y `D03@tomo` vuelve el `4.dawn` con un bloque al margen «v.»; con un `say` a Watson el día 3, ocurre en la primera salida del día 4. Una sola vez; HA6 una vez; M1 ≤2.
- [ ] M1: variante `registrada` con cerradura, cajón, silla y ceniza sobre el escritorio; los originales vuelven sólo por HB10 en el mostrador de Crane.
- [ ] Examinar `ventana_abierta` o un nodo de `registrada` hace nacer Q8 (con P1 integrado).
- [ ] L1: sólo los nodos interactivos de §6.4 tienen `examine`; T29 verde (Wiggins visible desde el día 3).
- [ ] T02, T05 (ley de la huella v3), T08, T11, T12, T22, T23, T28, T35, T37 verdes; ningún ambiente usa `amb.gas`.
- [ ] Capturas con ventana, sin `--fast`: `v3pieza_techos`, `v3pieza_registrada`, revisadas.

#### P3 · UI-EXPEDIENTE
**Posee:** `ui/expediente/*` (nuevo), `ui/ledger/*` (borra), `ui/notebook/*`, `ui/epilogue/blue_pencil.gd`, `data/ui_text/v3_expediente.json`, tests `test_u_expediente_ui` (nuevo; borra `test_u_ledger_ui`), `test_u_notebook`, `test_u_epilogue` (parte del lápiz azul), drivers `devtools/drivers/v3exp_*.gd`.
**Aceptación:**
- [ ] Driver sin `--fast` con eventos reales (como `title_smoke.gd`): abre el expediente desde el escritorio, arrastra dos recortes desde el cuaderno a las ranuras, elige la respuesta con el selector, «Pasar en limpio» → la hoja queda en tinta con el texto de Lisle; con una prueba cambiada, «Algo no cierra.» y la hoja sigue en lápiz. Capturas `v3exp_lapiz`, `v3exp_tinta`, `v3exp_no_cierra` revisadas.
- [ ] El cuaderno no tiene pestaña ni gesto de pares; las tarjetas tienen borde, separación y la fuente en chico; ningún recorte mostrado pasa de 15 palabras.
- [ ] Sin contadores visibles; la carpeta muestra ≤3 abiertas y «En tinta» plegado.
- [ ] `test_u_expediente_ui`, `test_u_notebook`, T31 (parte del expediente y el cuaderno) verdes.

#### P4 · UI-MUNDO
**Posee:** `world/camera_rig.gd`, `world/camera.json`, `world/world_root.gd`, `world/picker.gd`, `world/rect_clip.gd`, `world/affordance/*`, `world/diorama_builder.gd`, `world/materials.gd`, `ui/desk/*`, `ui/shell.gd`, `ui/input_router.gd`, `ui/map/*`, `ui/drag/*`, `ui/scene/*`, `ui/compose/*`, `ui/menus/options.gd`, `data/map.json`, `project.godot` (acciones de entrada), `data/ui_text/v3_mundo.json`, tests T26 (parte UI), T27, T29 (parte motor), T31 (escritorio, HUD, plano, escena), T32, T34, `test_u_shell`, `test_u_scene_panel`, `test_u_report_composer`, `test_u_ad_composer`, `test_u_telegram_composer`, `test_u_confrontation_view`, `test_u_props`, drivers `devtools/drivers/v3mundo_*.gd` y los drivers existentes que usan cámara o HUD.
**Aceptación:**
- [ ] No existe la cinta «Plano», ni `hover_label.gd`, ni `scissors3d.gd`; M y Espacio no hacen nada; el plano se abre sólo desde la pared.
- [ ] Con ventana y mouse real: sobre `tintero`, contorno blanco y mano; sobre `ventana`, contorno blanco y lupa; sobre la cama, nada; clic en `expediente` lo abre sin mover la cámara; girar con el borde desliza la cámara hacia el escritorio y luego hacia la ventana sin saltos (T32).
- [ ] Crane: después de `CRANE.intro`, «¿Dónde consigo…?» lista los ítems visibles; preguntar `donde.registros` agrega Somerset House al plano con «Me lo dijo Crane.» y su línea «qué hay».
- [ ] El compositor sólo se abre con el tintero; el informe acepta recortes y preguntas.
- [ ] T26, T27, T29, T31, T32, T34 verdes; capturas `v3mundo_general`, `v3mundo_hover`, `v3mundo_plano`, `v3mundo_crane` revisadas.

#### P5 · LECTOR
**Posee:** `ui/reader/*`, `ui/kit/*`, `data/ui_text/v3_lector.json`, tests T19, `test_u_text_builder`, `test_u_reader_v3` (nuevo: márgenes, paginación, ficha, tarjeta), `test_u_confirm_layout`, drivers `devtools/drivers/v3lector_*.gd`.
**Aceptación:**
- [ ] FINA abre flotante sobre la pieza desenfocada, con la ficha arriba, las marquitas a la izquierda de `#sheer` y `#a_mycroft`, la nota «suprimido a pedido del F.O.» en el margen derecho junto a `#sheer`, la paginación abajo al centro y la tarjeta del cliente como última hoja.
- [ ] La tijera es un ícono sin recuadro ni texto; recortar una nota del margen da un recorte de origen `D01N`; recortar la tarjeta, de origen `NC.FINA`.
- [ ] El texto nunca está rotado; T19 verde; `rtl.get_parsed_text() == parsed.plain` en cada bloque (cuerpo, margen, tarjeta).
- [ ] Capturas sin `--fast`: `v3lector_fina_1`, `v3lector_fina_tarjeta`, `v3lector_twis_margen`, revisadas.

#### P6 · CONTENIDO
**Posee:** `data/docs/**` (incluye `NC/*`, nuevos), `data/dialogue/*.json`, `data/scenes/*.json` (incluye `CRANE.json`, nuevo), `data/places/L2.json`–`L8.json`, `data/plates/*.json`, `data/entities/*.json` salvo `v3_core` y `v3_reacciones`, `data/fisica.json`, `data/canon_bible.json`, `data/catalog/*`, `data/ui_text/*` existentes y `v3_plano.json`, `tests/fixtures/canon/*` (sólo lectura), `tests/fixtures/style_exceptions.json`, tests T07, T20, T21, T30, T33, drivers `devtools/drivers/v3cont_*.gd`.
**Aceptación:**
- [ ] Las 6 crónicas con `v3.ficha`, `nota_cliente`, `marcas`, `margen` según §3.2–§3.4; las 6 `NC.*` con su `#tic`; tramos nuevos de §3.4; reetiquetados de §1.8 en documentos, escenas, diálogos, lugares y láminas de su propiedad.
- [ ] D23 v3; PRO v3 (la línea `t_read` del expediente); `CRANE.intro`; `crane.json` con `donde.*` y `pasos_techo` (con `when` desde la mañana siguiente a HA5); L2 `cotter_canastilla` con `[[club_diogenes]]`; PRO y M7 sin la decoración de §6.4.
- [ ] Textos visibles sin «conclusión», «libro de conclusiones», «asiento» (salvo el de la Sala de Lectura) ni «errata»; HC07 y el epílogo hablan de cuadernillos.
- [ ] `./godot.sh --headless -s devtools/lint.gd -- data` = 0 hallazgos (incluido ≤30 palabras en tramos etiquetados y ≤15 en exámenes que el jugador recorta enteros); T07, T13, T20, T21, T30, T33 verdes; `test_i_integration` sin SKIP de contenido propio.

### 7.3 Orden

1. **Hora 0:** CORE publica stubs, `dossier.json`, `corpus.json` y fixtures v3. REACCIONES publica `L1.json` con los ids de §7.1 (aunque las mallas lleguen después).
2. **En paralelo:** los seis paquetes. Las UI trabajan contra `tests/fixtures/v3/` con `sim_override`; CONTENIDO contra el lint; REACCIONES y CORE se integran por los hooks de §7.1.
3. **Integración (CORE dirige):** suite completa redirigida a `.work/v3_suite.log`; bots (`run_bots.gd`) del deductor, pasivo y fuerza bruta; drivers con ventana sin `--fast`, capturas revisadas.

### 7.4 Reglas comunes

- Nada fuera de `C:\Dev\books`; temporales en `.work/`; sin descargas ni commits; no tocar `.work/jugador/`.
- Godot sólo con `./godot.sh` desde la raíz, nunca en paralelo ni en segundo plano; timeouts largos; tests filtrados mientras se trabaja y suite completa al final.
- Cada paquete edita sólo sus archivos; lo ajeno se propone como diff en la respuesta final.
- Ante una ambigüedad de este documento: se reporta, no se asume.

---

## 8. Decisiones abiertas y riesgos

1. **Forma física de las crónicas.** Por defecto: cuadernillos sacados de los tomos de Watson (§3.1). Alternativa: los cinco tomos enteros en el estante con sólo las cuatro historias marcadas legibles (cambia menos el giro 3, pero contradice «no se entregan»).
2. **«Las otras 18»:** son 20 (§3.5).
3. **Tope de 3 abiertas con espera** y apertura total el `8.dawn` (§1.5): si al jugar se siente que «esconde» preguntas, se sube el tope a 4.
4. **Probar respuestas con las pruebas correctas** cuesta ≤25 intentos (§1.9). Aceptado por la decisión 2 («sin límite de intentos»).
5. **Etiqueta flotante:** se quita (decisión 9, «sólo contorno blanco»). Si el jugador no sabe qué es cada cosa sin tocarla, se puede devolver sólo el sustantivo, sin verbo.
6. **Teclas Tab, E y C** quedan como atajos de accesibilidad; no hay botones duplicados en pantalla.
7. **Q8 depende de que el jugador note la intrusión;** si no la nota, no nace y no cuenta para los finales.
8. **Riesgo técnico:** el desenfoque del lector lee la textura de pantalla; si en alguna GPU sale negro, plan B: captura de `get_viewport().get_texture()` al abrir el lector, reducida y escalada.

## 9. Notas de la integración (cambios hechos al integrar los seis paquetes)

- **Prólogo:** la lámina `PRO` tiene el nodo `expediente` (carpeta, `map.json objects.PRO → dossier`) en lugar de las hojas `encargo`: «abra el expediente y lea el encargo» se hace con la carpeta → «El encargo» (una sola forma, decisión 13). El examen de la carpeta (PRO y L1) menciona `[[encargo]]`, así la mención de la nota de Pell lleva a la carpeta.
- **D23#aviso** en 15 palabras («Se busca testigo de lo ocurrido en el Reichenbach el 4 de mayo de 1891.»), con «Aviso para el Times del martes:» en su renglón: el primer recorte del tutorial sale entero.
- **Epílogo:** `D38#hombre_alto` es sólo «Un hombre alto y delgado, de anteojos de color,» (el resto de la oración es `#detective`): el último corte cumple el tope de 15 palabras; un clic corta el tramo bajo el puntero.
- **Q4.R4 / Q9.Cc / Q9.Cd / Q9.Cd2 enlazan por claves:** rastro `HB5.recibo` con `e:gobierno` (sin `e:mycroft`, que delataba la respuesta); `HB7 #otro` «…el [[tigre]] también lee»; `M2 #nota` «…le ruega que nos diga [[donde|dónde]] anda»; `HB9 #hombres` «…esperan ver [[donde|adónde]] va usted»; `D11#hacerlo_balar` «…hasta que el [[tigre]] sabe [[donde|dónde]] está».
- **Siluetas:** `N:*.sil_<who>` lleva, además del ancla, las etiquetas del rastro que la declara (HC02: `a:chicos_de_holmes`, `e:muchacho`…), en `Clipper.node_def` y `RouteDB` (Q8.R3).
- **END.F1:** «Nada que corregir» = sin notas de lápiz azul (átomo nuevo `pencil_missing`); antes pedía diez en tinta, imposible si Q4 u Q8 no nacen.
- **Guardado:** cabecera `v: 3`; un guardado anterior no se repite: el título avisa «La partida se guardó con otra versión.» y sólo ofrece «Partida nueva» (`Game.save_too_old`).
- **CRANE.intro `once`:** `WorldModel.start_visit` no repite una escena automática `once` ya dicha.
- **T28:** el presupuesto «banco < 2 s» se mide en `tests/test_a00_audio_budget.gd` (primer archivo de la suite, proceso fresco); en medio de la suite la misma generación tarda ~2,5 veces más.
- **Partida real de punta a punta:** `devtools/drivers/v3integ_partida.gd` (título → prólogo → día 1 → día 2, mouse real, sin `--fast`).

## 10. Correcciones del playtest v3 (corrector final)

Lo que cambió después del playtest de novato (capturas `.work/shots/v3n_*`). Prevalece sobre lo anterior de este documento donde difiera.

- **Rótulo de cada prueba (§1.6):** cada pregunta de `data/dossier.json` lleva `pruebas: [r1, r2]` (voz de Lisle; p. ej. Q3 «Prueba de que me vigila de cerca» / «Prueba de quién es»). La hoja los muestra a lápiz encima de cada ranura (`q_dossier` → `proof_labels`). El orden sigue sin importar para la validación; el mensaje de error sigue siendo sólo «Algo no cierra.».
- **El selector de respuestas (§1.6, §1.9):** `q_answer_options(q)` ofrece todo lo que el jugador conoce, sea por el índice de recortes o por `st.world.known` (leído u oído), con `kind ∈ acepta`; `dq_answer` acepta lo conocido (`Dossier.knows`). Con «El problema final» leído, Q1 ofrece unas 45 opciones, y Q3 unas 55 el día 3: el freno combinatorio de §1.9 vuelve a valer.
- **Notas al margen recortadas (§3.3):** el bloque de margen trae su propia línea de fuente («Nota a lápiz al margen de «El problema final» (J.)»; firma en `v3.margen[].firma`), la fecha de su crónica (se agrupa con ella en el cuaderno) y `hand: "lapiz"`. La tarjeta va en grafito, con letra manuscrita. Las marcas del copista dicen «Marca a lápiz al margen de …».
- **HUD fuera de casa:** las cintas «Cuaderno» y «Expediente» van arriba de Pendientes. Al desplegarse, Pendientes ya no las empuja.
- **Q5 nace de una columna:** si la respuesta de «S.» llegó en los avisos del Times (inserto), la línea de origen lo dice: `nace[].origen_columna`.
- **Huecos del aviso:** son anchos, con borde punteado y «elegir…».
- **Tijera del lector:** queda anclada a la esquina de arriba a la derecha del papel, apenas afuera. Sigue al papel cuando se desplaza o se acerca, y nunca sale de la pantalla.
- **Tintero:** se acercó al frente del escritorio y su zona de clic es más grande (L1, PRO y M7). De noche, su tarjeta agrega una línea de Lisle: «A esta hora ya no escribo: el chico de Pell espera el informe.» en las noches de informe, y «…lo que haga falta, lo mando mañana temprano.» las demás.
- **Plano:** con la tarjeta de áreas abierta no se muestra la ayuda del marcador. «Lo menciona: …» ya no envuelve en «» un título que trae sus propias comillas.
- **Bandeja al continuar:** se abre sola sólo si tiene papeles sin leer (`q_tray()[].read`).
- **Corriente de aire de la intrusión:** bajó 8 dB, a unos −29 dB.
- **Tirar un recorte:** con clic derecho sobre una tarjeta del cuaderno aparece «Tirar este recorte» (acción libre `clip_drop {clip}`). El recorte no se borra: queda marcado `dropped`, sale de `q_clips`, de las hojas a lápiz y de las pruebas posibles. Un recorte que es prueba de una hoja en tinta no se tira (`en_tinta`). El InputRouter le pregunta al cuaderno y a la carpeta (`context_click`) antes de tomar el clic derecho como «volver».
- **Margen del cuaderno:** la fecha de la crónica dice «4 may.» (y el año debajo mientras no hay encabezados de mes, antes de `nb.agrupar`), no un número suelto ni «día 4», que se leía como el día 4 de la partida (integración final).
- **«Una pregunta nueva en el expediente.»** se va de Pendientes cuando el jugador abre esa hoja (acción libre `examine {ref: "sheet/<qid>"}`, `dossier.looked`). La acción vale también en el prólogo.
- **Sonido propio:** el consultorio de Watson suena como `amb.consultorio` («una sala de espera; alguien hojea una revista») y el vestíbulo de Mrs. Hudson como `amb.vestibulo` («una casa en calma; cruje la escalera»). Ya no suenan como la tienda de Crane.
- **Prólogo:** el primer paso («abra el expediente») encuadra la carpeta de cerca, con un punto `expediente` en el riel de PRO. El rótulo «Holmes» de la tapa es más grande, y el sello ya no está encima de la carpeta.
- **Sala de Lectura:** el epígrafe de llegada es «—Anote el número de su asiento en la papeleta, señor.». El de antes adelantaba el Journal de Genève.
- **Partida real:** `v3integ_partida.gd` llega al día 3: informe con la prueba de imprenta, intrusión de los de Moran al volver de Kensington y la ceniza que hace nacer Q8. Con `V3I_HASTA=dia2` se corta antes; con `V3I_DESDE=dia2` sigue la misma partida con «Continuar».

## 11. Integración final (después de la verificación de los paquetes)

- **La misma tarjeta en todos lados (§6.2):** el selector de «Mostrar» y del informe (`ui/scene/item_picker.gd`) y las ranuras llenas del sobre (`ui/compose/report_composer.gd`) dibujan un recorte con `ClipCard.tarjeta` (la letra del documento y la línea de fuente), como el cuaderno y las ranuras del expediente. Las preguntas siguen con su ficha propia.
- **Elegir una tarjeta del selector** usa la posición del clic (local al evento), no la del cursor del sistema.
- **Partida real:** `v3integ_partida.gd` separa los respaldos de recorte causados por el cursor del sistema (aviso de entorno: el usuario mueve su mouse durante la corrida con ventana) de los respaldos de UI.
- **La letra del tramo:** un recorte guarda `font` cuando un estilo `<f=…>` cubre más de la mitad del tramo (`Clipper.span_font`; p. ej. el aviso manuscrito de Pell al pie del encargo, que es a máquina) y la tarjeta usa esa letra.

## 12. Correcciones del segundo playtest v3 (corrector final, 14-oct)

Hallazgos del playtest de novato con capturas `.work/shots/v3p_*`. Prevalece sobre lo anterior de este documento donde difiera.

- **Cámara al cerrar un panel (§6.6):** las franjas del borde quedan «desarmadas» cada vez que se reactiva la entrada (`WorldRoot.set_input_enabled(true)`) o vuelve `edge_enabled` (se cerró un panel): no giran hasta que llega un movimiento del mouse **fuera** de las franjas. Antes, «Volver» del expediente, «Salir»/«Subir» y «Cerrar el plano» dejaban el mouse en la franja y la vista salía disparada.
- **Asentado del riel:** soltado el giro, el objetivo se asienta en el punto hacia el que se venía girando si se pasó el 20 % del tramo (`SETTLE_DIR_T`); si no, en el más cercano. Un empujón corto por el borde ya no vuelve al escritorio.
- **Escritorio:** se quitaron los props `tomos` y `tijera` (L1, PRO, M7): parecían usables y no hacían nada. Pendientes del día 1: «Leo «El problema final», que está en el estante.» La ficha de FINA dice «El cliente quiere saber qué no contó el doctor en esta crónica.».
- **Lector (§6.7):** la **rueda desplaza** la hoja (Mayúsculas + rueda, de costado); **Ctrl + rueda** o +/− acercan. El papel se dibuja con un ancho mínimo de 90 mm y una tira angosta (alto ≥ 3 × ancho) se muestra **acostada**: el señalador de HA2 (22 × 190 mm) se lee en cinco renglones. Su descripción física sigue diciendo «2 × 19 cm».
- **Señalador de HA2:** se entrega con `entrega: "del_libro"` («me la traje del Museo: estaba entre las páginas del volumen»), `src_type: papel_privado`.
- **Temas de conversación:** Preguntar ofrece el índice **y** lo que Lisle conoce por haberlo leído u oído (`st.world.known`), como el selector de respuestas. `ask` acepta esos temas.
- **Trato:** un personaje con `addr_anon` (Mrs. Hudson: «señora») se trata así hasta que se presenta (índice o `known`), igual que el rótulo del panel.
- **La regla del enlace es pública (§1.6):** la hoja muestra bajo «Pruebas:» el renglón «Las dos pruebas tienen que tocarse: una persona, un lugar o una cosa en común.». Si las dos pruebas no comparten **ninguna** entidad (bajo alias), el intento cuenta igual pero Lisle dice «Algo no cierra: estas dos pruebas no se tocan.» (`v3core.no_se_tocan`, `no_link` en el resultado). Nunca dice nada de la respuesta ni de los rótulos.
- **Descripción física recortada (§6.2):** el tramo `#fisica` hereda sus etiquetas con ≥ 25 % cubierto (los demás tramos, 50 %): describe un solo objeto, y «Papel crema grueso, 20 × 24 cm; escrito a máquina» ya sirve como prueba de la carta.
- **Expediente sin hojas abiertas:** el índice dice «Ninguna pregunta abierta por ahora. Lo nuevo sale de lo que leo, de lo que oigo y de lo que publico con el tintero.» y Pendientes suma «Nada abierto en el expediente: publico un aviso con el tintero o salgo a preguntar.» (`v3core.pend.sin_abiertas`, después del día 1 guiado). Ninguno nombra una pregunta.
- **Pendientes** ya no se pliega sola a un renglón con «…»: las ≤ 3 líneas quedan a la vista.
- **Prólogo:** un clic en el 3D (o en un personaje) con líneas de la escena todavía en cola pasa a la siguiente línea y no usa el objeto; ya no borra la presentación de Pell.
- **Bandeja:** en la primera carga (Partida nueva / Continuar) se abre sólo con papeles sin leer y no se repiten los eventos del amanecer. La primera vez que se ve la pieza revuelta (capa `techos` o `registrada` de ≤ 1 franja) la bandeja no se abre sola encima.
- **Corriente de aire:** suena una vez por intrusión (por el `from_tk` de su capa `techos`) y sólo en la primera vuelta a la pieza después de ella.
- **Q8 en tinta (variante A):** «Entró un muchacho por los techos: abrió la traba desde afuera y no rompió nada: buscaba papeles, no dinero. Es de los chicos que trabajaban para Holmes.» (sin «devolvió», que podía ser falso a esa hora).
- **Estante:** lo que falta va primero y a la vista, con rótulo corto «No está: <título hasta la primera coma>».
- **Informe:** «¿Qué no contó Watson? Raspadura» (sin el punto de más); el selector no ofrece lo que ya está en el sobre; la caja del texto final crece hasta el 26 % de la pantalla y después se desplaza.
- **22 h:** el chico de Pell lleva la mano (el clic abre el informe) y la vista mira la puerta; el aviso dura 9 s.
- **Somerset House:** 14 objetos para mirar (antes 28); en una visita, un objeto cuya tarjeta ofrece un papel para leer o pedir lleva la mano (por la entidad del documento o por `_doc` del nodo, `Objects.own_doc`). El botón de salida de las visitas dice «Salir» en todos lados.
- **Fechas de crónica:** STUD (`D43`) 1881-03-04 y SIGN (`D44`) 1888-07-07: sus recortes ya no van a «Sin fecha de crónica».
- **Tijera:** tomarla (C o el ícono) ya no suena a «un corte de tijera».
