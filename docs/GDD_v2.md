# GDD v2: cambios por el primer playtest del usuario

> **Qué es.** Es un documento de **cambios** sobre `docs/GDD.md`, escrito después de que el usuario jugó el juego completo y dejó ocho comentarios. **Donde los dos documentos difieran, prevalece este.** Lo que este documento no menciona sigue vigente tal cual: historia, canon, elenco, reacciones de Holmes y de Moran, calendario, informes, confrontación, finales e invariante del grafo.
> **Fuente de verdad del usuario:** `design.md`. **Técnica:** cuando este documento da un *spec técnico*, prevalece sobre `ARCHITECTURE.md` en ese punto; el resto de ARCHITECTURE sigue igual.
> **Verificado antes de escribir:** la nueva disponibilidad de contenido se probó contra el modelo real del grafo (T1 y T3 sobre una copia de `data/` con las ventanas del peor caso). Resultado: 0 fallas y un plan global factible (§B.8).

---

## 0. Resumen

### 0.1 Respuesta a cada punto del feedback

| # | Lo que dijo el usuario | Decisión | Dónde |
|---|---|---|---|
| 1 | El lenguaje es demasiado de época y costó entender hasta el tutorial («erratas»). Pide español neutro o argentino, no de España | Glosario de términos viejos y nuevos con palabras comunes. Guía de estilo neutra latinoamericana que un argentino lea con naturalidad. Se reescriben todos los textos de interfaz, el prólogo y los diálogos; los documentos de época conservan un sabor leve | §A |
| 2 | Todo está disponible desde el principio, no hay progresión y después del tutorial no queda claro qué hacer | Se arranca con 3 lugares, la tienda de Crane con 4 papeles y los tomos agrupados. Lugares y novedades se suman con disparadores del mundo y siempre con una hora garantizada. La guía es indirecta: la tira de «Pendientes» de Lisle y la página «Lo que me preguntaron». El tutorial pasa a tener dos tiempos | §B |
| 3 | Con esta estética cuesta distinguir los objetos y nada invita a hacer clic | Al pasar el mouse, todo lo examinable se realza por igual y muestra su nombre, con cursor de lupa. Manteniendo Espacio («mirar alrededor») se ve todo lo examinable a la vez, también por igual | §D |
| 4 | Lo usable (cuaderno, bandeja, tintero) debería decir «esto se puede usar», a diferencia de un libro que sólo tiene texto | Señal permanente y sutil (contorno fino en tinta roja, como las cintas de los libros) y cursor de mano, sólo en lo que se puede usar | §D |
| 5 | No convence mover la cámara con las flechitas de los costados | Se eliminan. Se reemplazan por una vista general con mirada libre limitada (bordes de pantalla y arrastre), clic para acercarse y clic derecho o Esc para alejarse | §E |
| 6 | Eligió el look «aguada» | `aguada` queda como look por defecto (ya está en `world/post/looks.gd`) y `grabado` pasa a ser una opción. Reemplaza GDD §14.5 y §16.3 | §D.4 |
| 7 | Las vistas tienen demasiada información | Revelado progresivo de la interfaz: cada vista empieza con lo mínimo y cada control aparece la primera vez que se puede usar | §C |
| 8 | La regla y la lupa del lector no parecen servir para nada | Se eliminan. Todos los documentos llevan una línea uniforme y recortable de **descripción física**. Las rutas que medían papel se reescriben con esas descripciones | §C.5 |

### 0.2 Lo que no cambia (núcleo)

- Holmes reacciona sólo a lo público (leyes 1–8, GDD §9.4). Siguen las voces A y B, sus latencias y las reglas del director D1–D10.
- El grafo sigue con 12 conclusiones obligatorias. Cada una tiene, en todo estado alcanzable, ≥2 rutas intactas, al menos una sólo de fuentes inmutables y ningún ejemplar común a todas (T1, T3).
- **Nada se marca como pista.** Lo nuevo es uniforme (realce de todo lo examinable, descripción física de todos los documentos) o es interfaz de herramientas que no son evidencia (cuaderno, tintero, mapa). Nunca se resalta sólo lo importante. Se justifica caso por caso en §D.1.
- Siguen iguales el calendario de 10 días con 25 turnos libres, los informes a Moran, la confrontación, los finales y el epílogo.

### 0.3 Secciones del GDD que este documento reemplaza

| GDD | Reemplazo |
|---|---|
| §1 Título | Se mantiene «Fe de erratas» hasta que decida el usuario; las propuestas están en §A.2 |
| §3.2 Prólogo y tutorial | §B.7 (tutorial en dos tiempos) |
| §5, columna «Disponible» de L3, L5 (portería), L6 y L7; el mapa con la página Baedeker | §B.3 y §C.3 (mapa) |
| §6 D25 y D46 («se mide con la regla»), §9.9 («papel un centímetro más corto, se mide con la regla»), C7.R1 | §C.5 |
| §8.0 Reglas del asiento (texto) | §A.3, «Cómo se anota una conclusión» |
| §8.6 «No hay marcadores de "aquí hay más", brillos ni contornos de interés» | Se matiza en §D.1: hay contornos, pero uniformes o sólo de herramientas |
| §14.1 Qué hay en pantalla; §14.2 Controles (órbita con flechas); §14.3 Zoom, regla y lupa; §14.4 Encuadres | §C, §D y §E |
| §14.5 Estilo grabado; §16.3 | El look por defecto es aguada (§D.4) |

---

## A. Lenguaje

### A.1 Glosario de términos visibles (de los actuales a los nuevos)

Rige para todo texto visible: interfaz, tutorial, diálogos, notas de Lisle y documentos inventados. Los identificadores internos (`asiento`, `folio`, `pass_clean`, `lot_size`, etc.) **no cambian**. Sólo cambia lo que lee el jugador.

| Término actual | Término nuevo | Dónde aparece | Nota |
|---|---|---|---|
| fe de erratas (lo que encarga Pell) | «lista de errores», «correcciones» | PRO, D23, epílogo («publicar la fe de erratas» pasa a «publicar mis correcciones») | El título del juego se mantiene provisoriamente (§A.2) |
| errata | error (del doctor) | ui_text, PRO, D21, notas de Lisle | En la carta de enero de Lisle (D22) puede quedar «erratas», porque es su oficio, siempre aclarada por el contexto |
| errata inocente | error sin importancia | reglas, libro, D21 | |
| libro mayor | **libro de conclusiones** | HUD, libro, PRO, examen del objeto | En el escritorio, el objeto es «Libro de conclusiones» |
| asiento (del libro) | **conclusión**: a lápiz se dice **borrador** y en tinta, **confirmada** | libro, reglas, informes, mostrar | La palabra «asiento» queda **sólo** para la silla numerada de la Sala de Lectura («asiento 214») |
| folio / Nuevo folio | **hoja** / «Nueva hoja» | libro | |
| plantilla | **tipo de conclusión** | libro | Los nombres de cada tipo están en la tabla siguiente |
| según / fundamento | **pruebas** (la ranura se llama «Pruebas») | libro, chequeo formal | |
| pasar en limpio / pasada | **confirmar** / confirmación | libro, calendario, pendientes | |
| lote de 2 | «de a dos» | reglas, sello | |
| sello «Visto» | sello **«Confirmado»** | libro | |
| tampón seco o entintado | se elimina la palabra | libro | En su lugar: «El sello no tiene tinta hasta el próximo turno.» |
| Reglas del asiento | **Cómo se anota una conclusión** | libro | Texto nuevo en §A.3 |
| Erratas inocentes (página) | **Práctica** | libro | |
| cotejar / Cotejos | **juntar** / **Pares** | cuaderno | Soltar un recorte sobre otro forma un par |
| Marginalia | **Curiosidades** | cuaderno | |
| franja | **turno** (mañana, tarde, noche) | HUD, calendario, mapa, pendientes | «Cerrar la franja» pasa a «Terminar el turno» |
| papeleta | **pedido** | Sala de Lectura, catálogo | «Tres pedidos por visita» |
| ujier / mozo | **bibliotecario** / empleado | L2, diálogo | |
| lámina / Láminas de lo visto | **recuerdo** / **Recuerdos** | mapa, cuaderno, títulos | El recorte de una escena dice «Recorte de un recuerdo» |
| epígrafe (del recorte) | pie del recorte | cuaderno | Interno; casi no se nombra |
| galerada, primera prueba | **prueba de imprenta** | D02, diálogos, examen del cajón | |
| pruebas de la composición americana, canceladas | pruebas de imprenta para Estados Unidos, anuladas | D04 | |
| cajista | tipógrafo | D04 | |
| concordancia | **notas de lectura** (de Lisle) | D21, escritorio | |
| procurador | **abogado** | Pell | |
| Sala de Forasteros | **Sala de Visitas** | L5, HC04, HC06 | |
| agente de fincas / chico del agente | **agencia de alquileres** / el chico de la agencia | L3, L8 | |
| Baedeker (página de horarios) | **Horarios** | mapa | Ver §C.3 |
| columna del *Times* | **avisos personales** del *Times* | compositor, medios de C6 | |
| aviso de testigos | aviso pidiendo testigos | PRO, D23 | |
| Afirmar (verbo de escena) | **Decir** | escena | |
| Presentar · Mostrar / Guardar | **Mostrar** · Mostrar / Mejor no | escena | |
| Refutar · Callar | **Responder con una prueba** · **No responder** | confrontación | |
| errata a medida | **informe trampa** (en la interfaz) | informe final, Mycroft, librero | En el diálogo: «una corrección a medida para el mayor» |
| recorte «de memoria» | **nota de memoria** | Somerset House | |
| dele · véase · sic · *ad fontes* · *in extenso* · *ad cautelam* | corríjalo · vea · (así, tal cual) · se eliminan los latinismos | voz B, Pell, D21 | |
| acera | vereda | lugares, siluetas | |
| «sir» (Mrs. Hudson) | **se mantiene** | diálogo de Mrs. Hudson | Es su tic y se puede contar (GDD §4, K-H). En los demás personajes se usa «señor» |
| índice, diario, cuaderno, recorte, tijera, informe, «Recibido», matasellos | se mantienen | | Son palabras comunes |

**Tipos de conclusión y sus campos.** El lint T6 sigue igual: el artículo va dentro del rótulo y ningún rótulo presupone un hecho.

| ID | Antes | Nuevo nombre | Rótulos nuevos (sólo los que cambian) |
|---|---|---|---|
| T1 | Errata | **Contradicción** | Fuente A: ___ · Dice: ___ · Fuente B: ___ · Dice: ___ |
| T2 | Omisión | Omisión | «Calla:» pasa a «No dice: ___»; «Consta en:» pasa a «Sí aparece en: ___» |
| T3 | Identidad | Identidad | «Es, en verdad:» pasa a «En realidad es: ___» |
| T4 | Autoría | Autoría | «Lo redactó:» pasa a «Lo escribió: ___» |
| T5 | Hecho | Hecho | sin cambios |
| T6 | Relación | Relación | «la columna del Times» pasa a «los avisos del Times» |
| T7 | Estado | Estado | sin cambios |
| T8 | Paradero | Paradero | sin cambios |
| T9 | Propósito | Propósito | sin cambios |

### A.2 Título (lo decide el usuario; mientras tanto queda «Fe de erratas»)

> **Decidido por el usuario:** **What the Ink Says**, siempre en inglés (CLAUDE.md). Está en `project.godot` (`config/name`), la pantalla de título y el colofón del epílogo; las propuestas de abajo quedan como historia.

1. **«Lo que Watson no escribió»**. **Recomendado.** Dice la premisa (a un texto famoso le cortaron algo), nombra a un personaje que todos conocen y usa palabras comunes. Subtítulo posible: «Un caso de Sherlock Holmes, 1894».
2. **«Al lector de Holywell Street»**. Es el encabezado con que Holmes le contesta a Lisle en el diario, es decir, el núcleo del juego: alguien te lee y te contesta. En contra: «Holywell Street» no le dice nada a quien no jugó.
3. **«El tercer lector»**. Resume el giro del acto II: Holmes, Moran y el jugador leen lo mismo. En contra: es abstracto y no dice que el juego es de Holmes.

El título visible sale de `shell.title.name` (ui_text) y del nombre del proyecto. Cambiarlo es cambiar una clave y `project.godot`; no toca ningún dato del caso.

### A.3 Guía de estilo

**Variante.** Español neutro latinoamericano que un argentino lea con naturalidad. Ortografía de la RAE vigente: «solo» y «este» sin tilde, salvo ambigüedad real.

**Prohibido en todo texto visible:**
- *vosotros*, *os*, *vuestro*;
- peninsularismos: *vale*, *coger*, *acera*, *ordenador*, *gafas*, *zumo*, *patata*, *chaval*, *tío* (por «hombre»), *enfadarse* (usar «enojarse»), *aparcar*, *piso* (por «departamento»), *conducir* (por «manejar»), *móvil*;
- latinismos de oficio: *in extenso*, *ad cautelam*, *ad fontes*, *sic*;
- jerga de corrector sin explicar: *dele*, *véase*, *galerada*, *cajista*, *pliego*.

**Diálogos:**
- Siempre «usted»; el plural es «ustedes». Wiggins también trata de usted («jefe»).
- Sintaxis actual: sin enclíticos arcaicos («díjome»), sin futuro de subjuntivo («hubiere») y con frases de ≤20 palabras de promedio.
- Los tics de personaje se conservan porque son pistas o carácter:
  - el «sir» contable de Mrs. Hudson;
  - los adjetivos repetidos de Harris y Moran («cruel, cruel») y sus metáforas de caza;
  - «Le ahorraré el trabajo» de Mycroft;
  - «Hum» de Holmes;
  - «la vieja tarifa» y «jefe» de Wiggins;
  - «en debida forma» de Pell, que es su único tic y queda una vez por escena.

**Interfaz:**
- Infinitivo o impersonal («Elegir dos conclusiones», «Soltar un recorte acá»). Nunca tú, vos ni usted en botones.
- Botones de ≤3 palabras y frases de ayuda de ≤12 palabras.
- Los errores de forma van en la voz de Lisle, en primera persona y en una sola oración («No tengo eso en el índice.»).

**Documentos de época:**
- Sabor leve: fórmulas de carta, títulos, «señor», dinero de época.
- Legibles sin esfuerzo: oraciones de ≤25 palabras de promedio y como mucho un término de época por párrafo, que el contexto explique.
- Las citas de Doyle [C] siguen fieles; se pueden modernizar palabras raras sin cambiar el sentido.

**Ejemplos (antes y después):**

| Antes | Después |
|---|---|
| «Lo que se pasa en limpio se pasa de dos en dos (de uno en uno el último día). Si uno no se sostiene, ninguno se entinta.» | «Las conclusiones se confirman de a dos (el último día, de a una). Si una no se sostiene, no se confirma ninguna.» |
| «Falta un *según*.» | «A esta línea le falta una prueba.» |
| «El tampón está seco hasta la franja que viene.» | «El sello no tiene tinta hasta el próximo turno.» |
| Pell: «La familia desea una fe de erratas de «El problema final», señor Lisle, *in extenso*: dónde se aparta el doctor de lo ocurrido…» | «La familia quiere una lista completa de los errores de «El problema final», señor Lisle: dónde se aparta el doctor de lo que pasó, qué ocurrió de verdad en Suiza y qué dejó dispuesto el difunto.» |
| Pell: «Búsquela en el tomo, *ad fontes*: recorte allí las dos fechas y cotéjelas, una sobre la otra.» | Nota de Lisle, día 1: «Busco las dos fechas en el tomo II, las recorto y las junto: un recorte encima del otro.» |
| Voz B (HB1): «"A pique": dele. Véase el Journal de Genève del 6 de mayo de 1891. —S.» | «"A pique": corríjalo. Vea el Journal de Genève del 6 de mayo de 1891. —S.» |
| «Doy por terminada la tarde del martes. Lo que haya escrito para el correo sale ahora.» | «Termino la tarde del martes. Las cartas que escribí salen ahora.» |
| Mrs. Hudson: «Los cuartos están como él los dejó, sir. Así lo quiere el señor Mycroft, sir.» | Sin cambio: el «sir» es su tic. |

**Reglas de las reglas.** La primera página del libro, «Cómo se anota una conclusión», dice lo siguiente:
1. «Cada conclusión se escribe en un formulario. Cada línea completa necesita al menos una prueba: un recorte.»
2. «Una sola fuente no alcanza. Dos recortes del mismo papel cuentan como una sola fuente.»
3. «Como máximo, cuatro recortes por conclusión.»
4. «Las conclusiones se confirman de a dos (el último día, de a una). Si una no se sostiene, no se confirma ninguna.»
5. «No se confirma dos veces lo mismo.»

La regla 6 actual («una errata inocente se practica aparte») pasa a ser la ayuda de la pestaña «Práctica».

### A.4 Qué archivos se reescriben y con qué intensidad

| Archivos | Intensidad | Qué se hace |
|---|---|---|
| `data/ui_text/*.json` | **total** | Todo según el glosario y la guía; botones de ≤3 palabras; errores de una oración |
| `data/scenes/PRO.json` | **total** | Prólogo nuevo (§B.7): Pell claro, sin latín; Harris conserva la caza y los adjetivos repetidos |
| `data/docs/D23.json` (encargo) | **total** | Es el documento del tutorial. Queda como la carta de un abogado: tres preguntas numeradas, el aviso al pie y una línea nueva: «El doctor Watson atiende en Kensington, por la mañana» (garantiza U3, §B.3) |
| `data/docs/D21.json` (notas de lectura) | alta | Frases simples, sin «sic»; se conservan las dudas «¿?» |
| `data/dialogue/*.json` | media | Vocabulario común y sintaxis actual; se conservan los tics de §A.3. El bibliotecario recibe una línea de tema «testamento, herencia, bienes, sucesión» que nombra Somerset House (disparador de U5) |
| `data/scenes/*.json` (salvo PRO) | media | Igual que los diálogos; HC07, END y EPI con frases cortas |
| `data/reactions/*.json` (textos de las cartas: voz A, voz B, Pell y Moran) | media | Se cambian «dele» por «corríjalo» y «véase» por «vea», y se quitan los latinismos. Se conservan las anclas, las firmas y los giros. **Sólo se tocan los textos**, nunca `corta`, `efecto`, etiquetas ni ids |
| `D22`, `D13`, `D14`, `D29a–c`, `D30–D33`, `D45`, `D46`, `D47–D51` | media | |
| `D19` (*London Gazette*) | baja | Suma una mención de Somerset House (entidad `somerset_house`) en un tramo **sin etiquetas** de conclusión (disparador de U5) |
| `data/docs/D15/*` (*Times*) | baja a media | Noticias en frases de ≤25 palabras; los avisos personales conservan el sentido. D15.0328 suma un aviso de época (ruido) que nombra Somerset House |
| Corpus `D01/*`, `D03`, `D43`, `D44` (Doyle traducido) | baja | Sólo palabras raras o peninsulares |
| `D05` (francés) | baja | La glosa a lápiz de Lisle traduce cada cita francesa |
| `data/places/*.json` y `data/plates/*.json` (`examine`, epígrafes) | media | Cada examen empieza con el sustantivo concreto («Un tintero de vidrio…») y no usa términos de oficio. Se aplican además los cambios de datos de §C.5 y §F |
| `data/entities/*.json` (`name`, `index`, que se ven en el índice) | media | P. ej., la entidad «papel un centímetro más corto» deja de nombrarse así (§C.5) |
| `data/endings.json`, `data/easter_eggs.json`, `ui_text/epilogo.json` | media | Fichas y notas |

### A.5 Reglas técnicas de la reescritura (obligatorias)

- **No cambian** los ids de tramo (`#id`), las etiquetas, la entidad de las menciones (`[[ent|…]]`; sólo cambia la superficie), los ids de línea ni los `src_en` y `q:`.
- Un tramo es una oración de ≤40 palabras (R1). Si una reescritura parte una oración en dos, el tramo se queda con la que afirma el hecho y la otra queda como texto plano.
- Todo valor que pida una conclusión sigue siendo indexable desde su tramo (R4).
- El presupuesto de palabras admite ±10 % y T11 sigue igual (≤1.000 palabras nuevas por mañana).
- Al entregar:
  - `./godot.sh --headless -s devtools/lint.gd -- data` debe dar 0 errores;
  - deben pasar `test_i_integration`, T1, T4, T7, T20 y el nuevo T33 (estilo).

---

## B. Progresión del contenido y guía indirecta

### B.1 Principio

El mundo **se abre de a poco y guía sin señalar**:
- Un lugar o un papel se suma cuando Lisle se entera de él, porque lo lee, lo oye o lo recorta.
- Si no se entera, se suma igual a una hora fija del calendario: la **garantía**.
- Nada se desbloquea por haber acertado, por haber recortado lo importante ni por haber resuelto algo.
- Lo que se abre no se vuelve a cerrar, salvo por los horarios y los cortes que ya existían (HB4, HB6, HB12, M5).

### B.2 Qué hay al empezar (día 1, mañana)

| | Antes | v2 |
|---|---|---|
| Lugares en el mapa | 7 más la casa: BM, Baker Street, Kensington, Diógenes, Somerset House y Park Lane con la persiana baja | **3**: casa (con la tienda de Crane), Sala de Lectura y consultorio de Watson |
| Tienda de Crane | 11 papeles | **4**: la *Strand* de diciembre y las *Memorias* (D03), el Kelly's (D17), Barrie (D40) y Martin Hewitt (D41). Además, el libro de ventas (D33) en el mostrador |
| Tomos de la *Strand* | 26 títulos en una sola lista | **5 tomos**; cada uno abre su índice (≤6 historias) y las notas a lápiz (D01N) van aparte |
| Escritorio | Encargo, recorte de las cartas del coronel, concordancia y todos los *Times* acumulados | Encargo, recorte, notas de lectura y el *Times* **del día**; los anteriores van a la pila «Diarios viejos» |
| Guía | — | Tira de «Pendientes» (≤3 líneas) y página «Lo que me preguntaron» |

**Nota.** «3 lugares» es el caso de quien en el prólogo sólo lee el encargo. Si además lee una crónica o el recorte de las cartas del coronel, que nombran Baker Street, el mapa ya trae Baker Street al amanecer del día 1. Es lo que se busca: el mapa crece porque Lisle se entera leyendo, nunca porque acierte.

**Por qué estos tres lugares.** Corresponden a las tres preguntas del encargo:
1. dónde se equivoca el doctor: los tomos y Watson;
2. qué pasó en Suiza: la Sala de Lectura y la tienda de Crane;
3. qué dejó el difunto: la Sala de Lectura (la *Gazette*) y, desde el día 3 a más tardar, Somerset House.

### B.3 Tabla de desbloqueos

**Garantía** = cuándo se suma como más tarde, aunque el jugador no haga nada. Es lo que usa el grafo (§B.8). **Antes, si…** = disparador diegético anticipado.

| ID | Qué se suma | Garantía | Antes, si… | Cómo se entera Lisle (portador en el mundo) |
|---|---|---|---|---|
| U1 | Casa y tienda de Crane | P.N (la tienda abre 1.M) | — | Vive ahí |
| U2 | Sala de Lectura (L2) | 1.dawn | — | Es su lugar de trabajo y tiene carnet de lector |
| U3 | Consultorio de Watson (L4, consulta) | 1.dawn | — | El encargo (D23) dice dónde atiende |
| U4 | Baker Street (L3: calle, 221B y agencia) | 2.dawn | Lisle **lee, oye o recorta** `baker_street` o `221b` | Diez crónicas de los tomos, el recorte de las cartas del coronel (D09), el Kelly's (D17) y la carta de enero (D22). En la práctica aparece la primera vez que se lee una crónica |
| U5 | Somerset House (L6) | 3.dawn | … `somerset_house` | Hoy sólo la nombran L6 y dos reacciones. Por eso se agregan menciones (§A.4): la línea nueva del bibliotecario (tema «testamento, herencia, bienes, sucesión»), D19 (*Gazette*: «…según el registro de Somerset House»), el aviso de época del *Times* del día 2 y la respuesta HB1 sobre el testamento, que ya la nombra |
| U6 | Club Diógenes, portería (L5) | 8.dawn | … `club_diogenes` **y** `pall_mall` (las dos: saber qué es el club y dónde queda) | GREE (tomo VI) y D14 traen las dos. Las notas de lectura D21 (el club) junto con FINA (Pall Mall) también. Garantía: la tarjeta HC04 |
| U7 | Sala de Visitas del Diógenes | días 8–9, T–N (sin cambio) | — | HC04 |
| U8 | Park Lane (L7) | 5.dawn | — | El *Times* del sábado (D15.0331) |
| U9 | Camden House (L8) | 7.T | — | El chico de la agencia; reemplaza a `map.json places.L8.show` |
| S1 | Crane: un lote de papel de imprenta (D04) y una caja de fotografías de Suiza (D07) | 2.dawn (accesible desde 2.M) | — | Crane: «Me entró un lote de papel de imprenta, al peso, y fotos de Suiza de un viajante.» |
| S2 | Crane: diarios atrasados (D09), libros de viaje y de caza (D10) y prensa de época (D42) | 3.dawn | — | «Me trajeron diarios atrasados y unos libros de viaje y de caza.» |
| S3 | Crane: *Estudio en escarlata* (D43) y *El signo de los cuatro* (D44) | 4.dawn | — | «Llegaron dos libros del doctor que no salieron en la Strand.» |
| T | Los cinco tomos | P.N | — | Los deja Pell. **No cambia su disponibilidad**; sólo se presentan agrupados (§C.3) |

Las novedades de Crane se ponen en la **mesa de novedades** (hoy `mesa_saldos`), lo más nuevo primero, y se mencionan en Pendientes. Se tratan igual que el ruido: S2 trae D42 (prensa de relleno) junto con D09 y D10.

### B.4 «Conocido»: qué sabe Lisle

- `st.world.known: {entidad: tk}` reúne las entidades que Lisle **vio** (en hojas leídas), **oyó** (en líneas dichas en escenas y diálogos, que ya quedan en el diario) o **recortó**.
  - Es **distinto del índice**. El índice sigue creciendo sólo con recortes (GDD §8.2 sin cambios) y es lo único que llena campos de conclusión.
  - `known` sólo decide qué aparece en el mapa.
- **Acción nueva `read`**: `{t:"read", view:String, part:int}`.
  - Es libre (no comprometida), no emite evento público (ceguera, T8) y vale en toda fase salvo `done`.
  - La emite el lector la primera vez que muestra cada hoja en la sesión.
  - Agrega a `known` las menciones de esa hoja (`parsed.mentions`) y anota `st.world.read[view] = [partes]`.
  - Entra en el registro como toda acción libre (con debounce) y en `replay` (T9).
- **`Reveal.update(st, repo)`** (nuevo, `core/sim/reveal.gd`) corre después de cada `apply` y en cada tk cruzado. Revela un lugar cuando `tk ≥ by`, cuando alguna de sus `ents` está en `known` o cuando **todas** sus `ents_all` están en `known`. Entonces escribe `st.world.revealed[L] = tk` y avisa a la interfaz con `st.note("map", {"revealed": L})`.
- `Clock.place_open` devuelve `{open:false, reason:"desconocido"}` para lo no revelado. `q_places()` lo **omite**: no se dibuja, ni siquiera con la persiana baja.

### B.5 Esquema de datos

En `schedule.json` (dueño: PROGRESIÓN):

```json
"reveal": {
  "L2": {"by": "1.dawn"},
  "L4": {"by": "1.dawn"},
  "L3": {"by": "2.dawn", "ents": ["baker_street", "221b"]},
  "L6": {"by": "3.dawn", "ents": ["somerset_house"]},
  "L5": {"by": "8.dawn", "ents_all": ["club_diogenes", "pall_mall"], "areas": ["porteria"]},
  "L7": {"by": "5.dawn"},
  "L8": {"by": "7.T"}
},
"stock": [
  {"tk": "2.dawn", "copies": ["D04@Crane", "D07@Crane"], "line": "pend.crane.s1"},
  {"tk": "3.dawn", "copies": ["D09@Crane", "D10@Crane", "D42@Crane"], "line": "pend.crane.s2"},
  {"tk": "4.dawn", "copies": ["D43@Crane", "D44@Crane"], "line": "pend.crane.s3"}
]
```

- L1 no lleva entrada: siempre está.
- `areas` limita la revelación a esas áreas; la Sala de Visitas conserva su propia ventana.
- `stock` lo aplica `DataRepo` **al cargar**: `copy.from = max(copy.from, franja siguiente a tk)`. Así hay una sola fuente de verdad y WorldModel, Availability y los bots ven lo mismo. Los documentos (`data/docs`) no se tocan.
- `Availability.area_open` agrega `from_mask(idx(by))`, que es **sólo la garantía**. Los disparadores anticipados se ignoran: sólo suman bits, igual que los `agrega`, y la invariante es antimonótona en los cortes (ARCHITECTURE §5.6).
- `map.json`: se retira `places.L8.show` (lo reemplaza `reveal.L8`). Cada lugar suma `"hours"`: una línea de horario, la de la página Baedeker partida por lugar (§C.3).
- `lists.json` suma `"preguntas"`. Son citas de personajes; el juego **no redacta preguntas propias**:

```json
"preguntas": [
  {"id": "q.pell.1", "src": "D23#punto_uno"}, {"id": "q.pell.2", "src": "D23#punto_dos"}, {"id": "q.pell.3", "src": "D23#punto_tres"},
  {"id": "q.m6", "src": "S:M6.donde"}, {"id": "q.m7", "src": "S:M7.donde_duerme"},
  {"id": "q.hc06", "src": "S:HC06.g"}, {"id": "q.m8", "src": "R:M8.*"}
]
```

### B.6 Guía indirecta

#### B.6.1 «Lo que me preguntaron» (primera página del libro de conclusiones)

- Cita **textualmente** a quien preguntó y cuándo («Pell, lunes 26: "Dónde se aparta el doctor de los hechos."»).
- Cada pregunta aparece cuando su fuente se dijo o se entregó.
- No se marca como resuelta ni pendiente.
- Debajo, plegado, va «Cómo se anota una conclusión» (§A.3).

Con esto no se rompe la regla del GDD («el juego nunca formula una pregunta en el libro»): son citas, como el diario.

#### B.6.2 «Pendientes»: la tira de Lisle

Es una tira manuscrita prendida al calendario del escritorio. `q_guide()` (nuevo, `core/sim/guide.gd`) devuelve **≤3 líneas** `[{key, vars}]`, en este orden de prioridad:

1. **Obligación con hora, hoy**: el informe de las 22 h, la Sala de Visitas de 16:45 a 19:40 (días 8 y 9), «esta noche, dos confirmaciones» (día 9) o el informe final del mediodía.
2. **Novedades desde ayer**: un lugar nuevo en el plano (si son varios, se juntan en una línea) y las novedades de Crane (`stock.line`).
3. **Práctica guiada pendiente**, sólo el día 1 y hasta que se haga (§B.7).
4. **Papeles sin abrir**: «Sin abrir: el Times de hoy y un sobre.» Cuenta lo que llegó a la bandeja y no se leyó (`read`), sin juzgarlo.
5. **Lugares conocidos sin visitar**: «Todavía no fui a Somerset House.» Como máximo dos nombres.
6. **Una pregunta abierta en rotación fija**: índice `día mod n` sobre las de §B.6.1, citada en corto.

**Reglas duras:**
- Nunca nombra un documento como importante, nunca nombra una conclusión y nunca cuenta progreso.
- No depende de etiquetas ocultas. Test: dos estados que sólo difieren en etiquetas ocultas o en lo sellado dan la misma tira.
- Se muestra desplegada al amanecer, después de la bandeja, durante 4 s; después queda en una línea y se despliega al pasar el mouse.
- No es recortable: es interfaz y no tiene información nueva.

#### B.6.3 Día por día (lo que guía sin señalar), en el peor caso

| Día | Pendientes (ejemplo) | Preguntas nuevas | Novedad del mundo |
|---|---|---|---|
| P | (el instructor guía; §B.7) | Las tres del encargo | — |
| 1 | «Antes de salir: practicar con un error viejo del doctor (Pelirrojos, tomo II).» · «En el plano: la Sala de Lectura y el consultorio del doctor Watson (Kensington, de mañana).» · «Miércoles 22 h: primer informe para el mayor.» | — | *Times* con mi aviso; sobre «No lo es» |
| 2 | «Hoy 22 h: el chico del señor Pell viene por el informe.» · «Nuevo en el plano: Baker Street.» (si no apareció antes) · «Crane: papel de imprenta al peso y fotos de Suiza.» | — | Primera carta a máquina |
| 3 | «Nuevo en el plano: Somerset House.» (si no apareció antes) · «Crane: diarios atrasados y libros de viaje y de caza.» · «Sin abrir: el Times de hoy.» | — | El muchacho de gorra aparece al fondo |
| 4 | «Crane: dos libros del doctor que no salieron en la Strand.» · pregunta en rotación | — | Primera respuesta «—S.» en el diario |
| 5 | «Hoy 22 h: segundo informe.» · «Nuevo en el plano: Park Lane.» · «El mayor pregunta dónde.» | M6 | Park Lane |
| 6 | «Domingo: no hay correo. El doctor recibe en su casa de 16 a 18.» | — | — |
| 7 | «Nuevo en el plano: Camden House (desde la tarde).» · pregunta en rotación | M7 (22 h) | — |
| 8 | «Hoy 22 h: tercer informe.» · «Mr. Mycroft Holmes: Sala de Visitas, de 16:45 a 19:40.» · «Nuevo en el plano: Club Diógenes.» (si no estaba) | HC06 (g) | — |
| 9 | «Esta noche: dos confirmaciones.» · «El mayor quiere el lugar antes del jueves a mediodía.» | M8 | — |
| 10 | (escenas fijas) | — | — |

### B.7 Tutorial en dos tiempos

**Prólogo, «El encargo»** (≈8 min; instructores Pell y Harris; los pasos se cumplen en orden):

| Paso | Quién lo pide | Qué hace el jugador | Qué se enseña |
|---|---|---|---|
| 1 | Pell | Abrir el encargo (acción `read` de D23) | `read` |
| 2 | Pell | Recortar el aviso al pie del encargo | `clip_text`, `clip_plate` |
| 3 | Harris | Redactar el aviso con la forma «Se busca testigo» | `compose_ad` |
| 4 | Pell | Dormir con el calendario | `sleep` |

Pell entrega el libro de conclusiones («para el jueves, seis conclusiones confirmadas»), pero el libro **no se abre** en el prólogo.

**Día 1, «Primera conclusión»** (≈6 min, gratis, no gasta turno). El instructor son **las notas de Lisle** (manuscrito, mismo componente que el instructor del prólogo, voz en primera persona):

| Paso | Qué hace el jugador | Qué se enseña |
|---|---|---|
| 5 | Recortar las dos fechas de REDH en el tomo II (C1.10) | — |
| 6 | Juntar los dos recortes en un par | `link` |
| 7 | Abrir una hoja con el par | `folio_open` |
| 8 | Escribir una Contradicción con sus pruebas | `entry_*` |
| 9 | Confirmarla con el sello de práctica | `practice` y `pass_clean` |

- **No bloquea nada**: se puede salir antes. El único control nuevo es `pass_clean`, que pide la práctica hecha y si no devuelve el error `practica_pendiente`. La interfaz tampoco muestra el sello del libro hasta entonces (§C.3).
- Los pasos quedan en Pendientes hasta que se hagan.
- `Tutorial.STEPS` se parte en `PROLOGUE` (pasos 1–4, que bloquean como hoy) y `DAY1` (pasos 5–9, que guían sin bloquear).
- Los textos son `tut.d1.*` (ui_text, TEXTOS-UI) y las líneas `PRO.t_read`, `t_clip`, `t_ad` y `t_sleep` (TEXTOS-UI). Desaparecen las líneas `t_link`, `t_folio`, `t_entry` y `t_practice` de Pell.
- El índice se sigue alimentando desde el instructor sólo en `t_ad` (excepción W4, ARCHITECTURE §5.1).

### B.8 La invariante con la nueva disponibilidad

**Argumento:**
1. `reveal` y `stock` sólo **atrasan el comienzo** de algunas ventanas. Ningún final de ventana cambia.
2. El grafo usa sólo la garantía (`by`). Los disparadores anticipados suman bits y no pueden romper nada.
3. Una ruta está intacta en la franja *i* si cada fragmento se puede obtener en [*i*, última franja útil]. Todas las rutas atrasadas tienen ventanas hasta los días 9 o 10, así que siguen intactas en toda *i* ≤ 8.N, que es lo que mide T3.
4. Factibilidad global:
   - la tienda de Crane no gasta turno;
   - Somerset House (C4.R1) tiene 10 turnos en [3.M, 9.T];
   - Baker Street sólo hace falta para rutas ★ desde el día 7 (C13.R2) y el día 8 (C9);
   - el Diógenes se usa los días 8 y 9, como antes.

**Verificación ejecutada** (copia de `data/` en `.work/v2check/` con las ventanas del peor caso; `patch.py` + `check.gd`; reproducible con `./godot.sh --headless -s C:/Dev/books/.work/v2check/check.gd -- <raíz de data> 300`):

| Datos | T1 (12 obligatorias) | T3 | Plan global desde P.N |
|---|---|---|---|
| Actuales | 0 errores | 0 fallas, 12 222 estados, 560 ms (fuzzing 100) | factible |
| **v2** (L3 2.M, L6 3.M, L5 8.M, stock S1–S3) | **0 errores** | **0 fallas**, 31 422 estados, 1 353 ms (fuzzing 300) | **factible** |
| v2 estrecha (L3 3.M, L6 4.M; sólo para medir el margen) | 0 errores | 0 fallas, 1 319 ms | factible |

**Rutas ★ con un «desde» nuevo** (calculado por `RouteDB` sobre los datos v2):
- C2.R3 pasa a 2.M (antes 1.M); C2.R2 sigue en 1.M.
- C3.R2 pasa a 2.M; C3.R1 y C3.R3 siguen en 1.M.
- C4.R1 pasa a 3.M; C4.R2 sigue en 1.M.
- C5.R2 pasa a 3.M; C5.R1 y C5.R4 siguen en 1.M.
- C8.R2 pasa a 4.M; C8.R1 sigue en 1.M y C8.R3 en 8.T.
- Las demás no cambian.

En `conclusions.json` se actualiza el `from` declarado de esas rutas y de las C1 que usan D43 o D44 en la tienda de Crane (C1.01, C1.06 y C1.09 pasan a 4.M), de C4.R3, C4.R5 y C7.R3 (L3: 2.M) y de C7.R3b (L3: 2.M).

### B.9 Tests que cambian

| Test | Cambio |
|---|---|
| T1 | `from` declarados nuevos; C7.R1 y C7.R1c con referencias nuevas y C7.R1d nueva (§C.5.4); sigue 0 errores con datos reales |
| T3 | Availability con `reveal` y `stock`; mismo presupuesto (<10 s) |
| T10 | Los bots respetan lo revelado: el deductor planifica con Availability (ya incluye la garantía) y el novato emite `read` al leer. Los ranks y el resultado del pasivo (F4) no cambian |
| T24 | El tutorial va en dos tiempos: `pass_clean` exige la práctica; el novato la hace el día 1 antes de su primera confirmación |
| T26 | Lo no revelado no aparece en `q_places()` y un `go` a ese lugar devuelve `cerrado` sin escribir a disco. Se mantiene lo cerrado con persiana |
| Nuevos | `test_u_reveal` (garantía y disparadores), `test_u_guide` (≤3 líneas, determinista, ciega a etiquetas ocultas) y `test_u_ui_state` (§C.2) |
| Unitarios | `test_u_tutorial`, `test_u_clock`, `test_u_world_model`, `test_u_actions` (acción `read`) y `test_u_route_db` (referencias `R:<rid>.fisica` y `D#fisica`) |

---

## C. Progresión de la interfaz (revelado progresivo)

### C.1 Reglas generales y límites

1. **Nada visible que todavía no se pueda usar**: botones, pestañas, verbos, formas, herramientas y contornos de «usable». Cada cosa aparece la primera vez que se puede usar. Lo que ya apareció no vuelve a desaparecer, salvo los paneles contextuales.
2. **Límites de información simultánea:**
   - un panel principal y uno acoplado como máximo (como hoy);
   - barras de ≤4 botones;
   - listas de ≤7 ítems a la vista; si hay más, buscador, «Recientes» y «Ver todo» plegado;
   - una sola etiqueta flotante;
   - Pendientes de ≤3 líneas;
   - tarjeta de examen de ≤1 párrafo y ≤4 enlaces; si hay más, lista en dos niveles;
   - ayudas de una línea, que se muestran sólo hasta el primer uso de su control.
3. **El revelado depende del estado de la partida y nunca de lo importante.** No mira etiquetas ocultas ni conclusiones selladas; lo sellado sólo puede ordenar listas, nunca mostrar u ocultar.
4. Sin contadores, como siempre.

### C.2 Fuente única: `q_ui()`

`GameSim.q_ui() -> {flag: bool}` (nuevo, `core/sim/ui_state.gd`) se calcula **sólo con el estado**: deterministas, persistentes al cargar y probables sin pantalla. Las áreas de interfaz lo consumen y no deciden por su cuenta.

| Bandera | Se enciende cuando | Qué muestra |
|---|---|---|
| `desk.tijera` | Se alcanza el paso «recortar» del prólogo | Tijera usable; botón «Tijera» en el lector, la escena y la confrontación |
| `desk.tintero` | Se alcanza el paso «aviso», o algún compositor está disponible | Tintero usable |
| `desk.calendario` | Se alcanza el paso «dormir», o la fase es `desk` o `night` | Calendario usable |
| `desk.mapa` | Fase distinta de `prologue` | Mapa usable |
| `desk.bandeja` | Día ≥1 | Bandeja usable |
| `hud.cuaderno` | Hay ≥1 recorte | Cinta «Cuaderno»; cuaderno usable |
| `hud.libro` | Empezó la práctica del día 1 o hay ≥1 conclusión | Cinta «Libro de conclusiones»; libro usable |
| `nb.pares` | Hay ≥1 par | Pestaña «Pares» |
| `nb.diario` | Hay ≥1 línea de diario (día 1) | Pestaña «Diario» |
| `nb.indice` | El índice tiene ≥12 entradas | Pestaña «Índice» |
| `nb.curiosidades` | Hay ≥1 curiosidad | Pestaña «Curiosidades» |
| `nb.buscar` | Hay ≥10 recortes | Buscador de recortes |
| `nb.filtros` | Hay ≥20 recortes | Filtros Persona, Lugar y Fecha; cada uno sólo si tiene ≥2 opciones |
| `nb.agrupar` | Los recortes tienen ≥2 meses de crónica distintos | Encabezados por fecha |
| `lg.hoja_nueva` | Se enseñó `folio_open` | «Nueva hoja» |
| `lg.varios` | Hay ≥1 conclusión sin hoja | Página «Varios» |
| `lg.practica` | Hay conclusiones de práctica | Página «Práctica», al final |
| `lg.sello` | Hay práctica hecha y ≥1 borrador que no es de práctica | Panel del sello |
| `sc.mostrar` | Hay ≥1 recorte o conclusión | Verbo «Mostrar» |
| `sc.decir` | `q_assertions()` no está vacío | Verbo «Decir» |
| `cmp.telegrama`, `cmp.carta` | Hay ≥1 destino válido en el índice (`Composers`) | Opciones del tintero |
| `cmp.forma.<id>` | Cada blanco de la forma tiene ≥1 opción | Esa forma del aviso |
| `map.recuerdos` | Hay ≥1 recuerdo archivado | Botón «Recuerdos» |
| `tray.anteriores` | Día ≥2 | «Días anteriores», plegado |
| `cat.mesa` | Hay ≥1 pedido en la visita | «Sobre mi mesa» |
| `look.ayuda` | Día 1, hasta el primer uso de «mirar alrededor» | Línea de Pendientes: «Mantener Espacio para ver qué se puede mirar.» |

### C.3 Vista por vista

**Escritorio (casa) y HUD**

| Al principio | Después | Se va |
|---|---|---|
| Vista general de la buhardilla (§E). HUD: sólo el calendario (día y turno). En el prólogo sólo son usables el encargo (atril y escritorio: leer) y lo que cada paso habilita | Las cintas «Cuaderno» y «Libro de conclusiones» aparecen con sus banderas. Pendientes desde el amanecer del día 1. Una pila «Diarios viejos» desde el día 2 | Las **monedas** dejan el HUD: quedan sobre la mesa como objeto examinable, con su cuenta en el examen. Los chevrones, por §E |

**Tarjeta de examen**

| Al principio | Después | Se va |
|---|---|---|
| Sustantivo, texto recortable y ≤4 enlaces | **Tomos**: primero los 5 volúmenes; cada volumen lista sus historias (≤6) y las notas a lápiz como un ítem aparte. **Estantes de Crane**: un estante por tarjeta y la mesa de novedades, con lo más nuevo primero. **Diarios viejos**: por fecha | La lista larga de 26 títulos |

**Lector**

| Al principio | Después | Se va |
|---|---|---|
| Título, origen (una línea), **descripción física** (una línea, §C.5) y texto. Botón «Volver» | «Tijera» con `desk.tijera`. Las flechas ‹ n/N › sólo si el documento tiene más de una hoja. El zoom va con la rueda; aparece un indicador «130 %» sólo si el zoom es distinto de 100 % (clic para volver a 100 %) | **Lupa**, **Regla**, «Anotar la medida», los botones −/+ y el porcentaje fijo. Archivos: `ui/reader/lens.gd` y `ui/reader/ruler.gd` |

**Cuaderno**

| Al principio | Después | Se va |
|---|---|---|
| Sin pestañas: sólo la lista de recortes. Cada tarjeta muestra el texto y el origen; el pie muestra 3 entidades y «+n» (todas al pasar el mouse) | Pestañas, buscador, filtros y agrupación con sus banderas. En el Diario, el día de hoy abierto y los anteriores plegados | La pestaña vacía de Marginalia visible desde el inicio; los filtros con una sola opción |

**Libro de conclusiones**

| Al principio | Después | Se va |
|---|---|---|
| Se abre el día 1. Primera página: «Lo que me preguntaron» y debajo, plegado, «Cómo se anota una conclusión». Tipos a la vista: Contradicción, Omisión y Hecho, más «Más tipos…» plegado (**los 9 tipos están siempre disponibles**; plegar no oculta nada que dependa del caso) | «Nueva hoja», «Varios», «Práctica» y el panel del sello con sus banderas. El sello muestra los dos lugares «de a dos» y su estado de tinta en una línea | «Modo de asentar» (4 párrafos), reemplazado por ayudas de una línea por control hasta su primer uso. La pestaña «Erratas inocentes» fija. El «Cuaderno» como pestaña del libro (queda la cinta del HUD) |

**Bandeja**

| Al principio | Después | Se va |
|---|---|---|
| Lo llegado hoy: qué es y cómo llegó | «Días anteriores», plegado, desde el día 2 | — |

**Mapa**

| Al principio | Después | Se va |
|---|---|---|
| Sólo los lugares revelados. Al pasar sobre un marcador se ve su horario en una línea (`map.json hours`); si está cerrado, «Cerrado ahora» | «Recuerdos» con su bandera. Lugares nuevos con un sello «Nuevo» durante el día en que aparecen; es uniforme y no marca pistas | La **página Baedeker** completa, partida en horarios por lugar. El **selector de número de asiento** de la Sala de Lectura, que pasa a la Sala (ver Catálogo). Las zonas de color de Booth bajan al 30 % de opacidad |

**Escena (diálogo y mostrar)**

| Al principio | Después | Se va |
|---|---|---|
| Banda con las líneas dichas y el verbo «Preguntar». El selector de temas muestra el buscador, «De esta conversación» (las entidades nombradas en esta visita, ≤6) y «Recientes» (las últimas que entraron al índice, ≤6); «Todo el índice» va plegado | «Mostrar», «Decir», «Pagar» y «Encargar» con sus banderas. «Tijera» con su bandera | La lista completa del índice abierta de entrada |

**Compositores (aviso, telegrama, carta e informe)**

| Al principio | Después | Se va |
|---|---|---|
| Aviso: sólo «Se busca testigo» (prólogo). Informe: tres ranuras y «Sin novedad» | Las formas «A propósito de…», «Al corresponsal S.» y «Perdido» aparecen cuando todos sus blancos tienen opciones. El telegrama y la carta, cuando hay un destino posible. En el informe final se suman «Quemarlo» y, si se ofreció, «Informe trampa» | Formas y destinos que no se pueden llenar |

**Confrontación**

| Al principio | Después | Se va |
|---|---|---|
| La afirmación, «Responder con una prueba», «No responder» y la paciencia del librero (paquete y sombrero) | El selector lista primero las conclusiones confirmadas y después los recortes, los más recientes primero | — |

**Catálogo (Sala de Lectura)**

| Al principio | Después | Se va |
|---|---|---|
| Buscador y «Recientes» (≤8 entradas del índice). En el encabezado, «Asiento 214 · cambiar». El valor por defecto es el último usado; la primera vez, 214. El `go` lo sigue llevando, así que no cambia el sim | «Sobre mi mesa» después del primer pedido | La lista entera del índice como menú; la pregunta del asiento en el mapa |

**Recuerdos (antes «Láminas»)**: una lista por día, con lo más reciente primero.

**Opciones**: se suman «Girar la vista con los bordes de la pantalla» (activada por defecto, §E) y «Estilo de imagen» (Aguada por defecto, Grabado como alternativa).

### C.4 Lo que se elimina

- Del lector: **Lupa**, **Regla**, «Anotar la medida» y los botones de zoom.
- Del escritorio: los props y nodos `lupa` y `regla` (en `L1.json` y en la lámina `M7.json`) y los **chevrones**.
- Del HUD: las monedas.
- Del mapa: la página Baedeker completa y el selector de asiento.
- Del libro: el texto «Modo de asentar», la palabra «tampón», la pestaña fija «Erratas inocentes» y el «Cuaderno» como pestaña.
- Del cuaderno: la pestaña vacía de Marginalia visible desde el inicio.
- De la interfaz: la acción `clip_measure`. **Compatibilidad**: el sim la sigue aceptando para reproducir partidas viejas y la resuelve como el recorte de la descripción física del documento (§C.5.6).

### C.5 Regla y lupa: se reemplazan por la descripción física

#### C.5.1 Decisión

La regla y la lupa se eliminan.

- **La lupa no sostiene ninguna ruta ni refutación.** Se verificó con grep en `conclusions.json`, `_pistas_falsas` y los diálogos. Las rutas que comparan letra (C8.R4, C12.R3 y C12.R4) se apoyan en el texto y en la entidad `letra`, así que no cambian.
- **La regla sostenía sólo C7.R1 y C7.R1c**, dos rutas que no son ★ (`M:HA1.carta` o `M:HA0.carta` + `M:D46`).

La información de las dos herramientas pasa a una **línea de descripción física que tienen todos los documentos por igual**: los estáticos y los que se generan en el juego. Esa línea dice:
- el tipo y color del papel;
- la medida en centímetros;
- cómo está hecho: impreso, a máquina (con sus rasgos visibles) o a mano (en tinta o lápiz, y cómo es la letra);
- su estado.

Se ve en el lector bajo el origen y **se puede recortar** como cualquier texto.

#### C.5.2 Esquema y formato fijo

`data/fisica.json` (nuevo; dueño DESPEJE-UI). Los documentos de `data/docs` no se tocan:

```json
{
  "papeles": {
    "diario":       {"ent": "papel_de_diario",     "txt": "Papel de diario"},
    "revista":      {"ent": "papel_de_revista",    "txt": "Papel de revista"},
    "crema_grueso": {"ent": "papel_crema_grueso",  "txt": "Papel crema grueso"},
    "carta":        {"ent": "papel_de_carta",      "txt": "Papel de carta"},
    "rayado":       {"ent": "papel_rayado",        "txt": "Papel rayado"},
    "telegrama":    {"ent": "papel_de_telegrama",  "txt": "Formulario de telégrafo"},
    "cuaderno":     {"ent": "papel_de_cuaderno",   "txt": "Hoja de cuaderno"},
    "registro":     {"ent": "papel_de_registro",   "txt": "Hoja de libro de registro"},
    "carton":       {"ent": "carton",              "txt": "Tarjeta de cartulina"},
    "foto":         {"ent": "papel_fotografico",   "txt": "Fotografía en cartón"}
  },
  "medios": {
    "impreso":          "impreso",
    "impreso_grabados": "impreso, con grabados",
    "maquina_pell":     "escrito a máquina, de letra pareja",
    "remington_cotter": "escrito a máquina: la «s» queda algo alzada y la «t» sale pálida",
    "mano_holmes":      "a mano, en lápiz blando: letra chica y firme",
    "mano_pell":        "a mano, en tinta: letra grande y apurada",
    "mano_watson":      "a mano, en tinta: letra redonda, con tachaduras",
    "mano_mary":        "a lápiz: letra pequeña y redonda",
    "mano_lisle":       "a mano, en tinta: letra pequeña, con signos de corrector",
    "mano_crane":       "a lápiz: números grandes y letra torcida",
    "mano_coronel":     "a mano, en tinta: letra rígida, de militar",
    "telegrafo":        "en tiras de papel pegadas, en mayúsculas"
  },
  "docs": {
    "D46": {"papel": "crema_grueso", "mm": [203, 254], "medio": [], "estado": "arriba, el membrete grabado del club ocupa una franja de un centímetro; en blanco", "tags": ["a:vinculo_mycroft"]},
    "D23": {"papel": "carta", "medio": ["maquina_pell", "mano_pell"], "estado": "doblado en cuatro"},
    "D01N": {"papel": "revista", "medio": ["mano_watson", "mano_mary"], "estado": "notas en los márgenes de los tomos"}
  },
  "plantillas": {
    "cartas_a_maquina": {"papel": "crema_grueso", "medio": ["remington_cotter"], "estado": "el borde de arriba, cortado a tijera", "tags": ["a:me_vigila_de_cerca"]},
    "respuestas_s":     {"papel": "crema_grueso", "medio": ["remington_cotter"], "estado": "el borde de arriba, cortado a tijera", "tags": ["a:me_vigila_de_cerca"]},
    "tarjeta_de_mycroft": {"papel": "carton", "medio": ["remington_cotter"], "estado": "sin membrete"}
  }
}
```

- **`docs`** cubre todos los documentos de `data/docs`: unos 78, incluidos los del corpus y los *Times*.
- **`plantillas`** cubre cada `doc.entity` de las reacciones (14 tipos hoy): cartas a máquina, respuestas «—S.», tarjetas, notas de Pell y de «H.», telegrama de Steiler, carta de Bath, copia oficial, precio a lápiz, señalador, carta de enero, columna y *Times*.
- **`mm`** es opcional. Si está, `DataRepo` también reemplaza con ella el `paper_mm` del documento al cargar, para que el papel del lector tenga la misma forma. Si no está, se usa `paper_mm`.
- **`tags`** es opcional y sólo admite etiquetas ocultas `a:` y `c:`. **Hoy sólo D46 y las cartas de la Remington llevan etiquetas.** Las demás descripciones son físicas y neutras: el lint impide etiquetas en el resto salvo que una ruta del contrato las pida.

**Generador** (`core/text/fisica.gd`, nuevo; dueño DESPEJE-UI):
- `static func line(spec: Dictionary, mm: Array, fis: Dictionary) -> String` produce marcado con **un solo formato** para todos:

```
<f=ui><i><ink=tenue>{{#fisica TAGS e:<ent del papel>|[[<ent del papel>|<Papel>]], <W> × <H> cm; <medio 1>[ y <medio 2>]; <estado>.}}</ink></i></f>
```

- La medida se redondea a centímetros enteros (203 × 244 mm da «20 × 24 cm»).
- Siempre es **una oración de ≤40 palabras y un solo tramo** (T4).

**Dónde se inyecta** (dueño de los ganchos: PROGRESIÓN):
- **Documentos estáticos**: `DataRepo`, al cargar, antepone la línea y un `\n` al texto de `parts[0]`. Por eso `D46#fisica` se resuelve con `doc_tramo`, como cualquier tramo, y T4 lo incluye solo.
  - En los números del *Times* (con `inserts`), `WorldModel._merge_inserts` cuenta las unidades **después** de la línea `fisica`. Así las inserciones de la columna y de las noticias caen donde caen hoy (T11 y los tests de inserciones no cambian).
- **Documentos del juego**: `Effects.instance_text` antepone la línea de su plantilla. `RouteDB` resuelve la referencia **`R:<rid>.fisica`** con las etiquetas y entidades de esa plantilla, el origen de la instancia, la clase del documento y la disponibilidad de la reacción.

**Ejemplos (texto final, idéntico en formato):**
- Carta de la voz A: «Papel crema grueso, 20 × 24 cm; escrito a máquina: la «s» queda algo alzada y la «t» sale pálida; el borde de arriba, cortado a tijera.»
- D46: «Papel crema grueso, 20 × 25 cm; arriba, el membrete grabado del club ocupa una franja de un centímetro; en blanco.»
- D23: «Papel de carta, 20 × 33 cm; escrito a máquina, de letra pareja y a mano, en tinta: letra grande y apurada; doblado en cuatro.»
- *Times*: «Papel de diario, 38 × 54 cm; impreso; doblado en cuatro.»
- D12 (monografía): «Papel de revista, 14 × 22 cm; impreso y a mano, en lápiz blando: letra chica y firme; dedicatoria en la portadilla.»

#### C.5.3 Por qué no marca pistas

- La línea está en **todos** los documentos, con el mismo formato y la misma posición.
- Sus palabras salen de tablas cerradas: papel, medios y estado breve.
- La descripción de la carta de un sastre es tan precisa como la de la carta de Cotter.

Cotejar dos descripciones es el razonamiento que antes pedía la regla y ahora pide la lectura.

#### C.5.4 Reescritura de C7 (la mano que escribe a máquina obedece a Mycroft)

| Ruta | Antes | Ahora | Clases | Desde | Corte |
|---|---|---|---|---|---|
| C7.R1 | `M:HA1.carta` + `M:D46` | **`R:HA1.fisica`** (carta: 20 × 24 cm, borde de arriba cortado, papel crema grueso) + **`D46#fisica`** (papel del club: 20 × 25 cm, membrete en una franja de 1 cm) | P + I | 8.T | M1 (un día) |
| C7.R1c | `M:HA0.carta` + `M:D46` | **`R:HA0.fisica`** + **`D46#fisica`** | P + I | 8.T | M1 |
| **C7.R1d** (nueva, no ★) | — | **`R:HA1.fisica`** + **`N:L2.cesto_tiras`** («tiras de papel crema grueso, de un centímetro, con letras grabadas: "…GENES CLUB · PALL MALL…"») | P + I | 2.M | M1 |

Las rutas ★ de C7 no cambian: C7.R2 (8.T) y C7.R4 (1.M).

**La deducción** es la misma que pedía la regla, pero se hace leyendo. La carta usa el mismo papel crema grueso que el pliego del club, mide un centímetro menos y tiene el borde de arriba cortado; el membrete del club ocupa justo esa franja; y en la Sala de Lectura hay un cesto con tiras de un centímetro de ese papel. Conclusión: es papel del Diógenes con el membrete recortado.

**Datos:**
- `conclusions.json`:
  - C7 suma `papel_crema_grueso` a `keys.entities` (enlace por claves, condición 5);
  - C7.R1 y C7.R1c cambian sus `frags`;
  - se agrega C7.R1d (`deps: "garantizada"`, `from: "2.M"`, `cut_by: ["M1"]`).
- `fisica.json`: D46 lleva `mm: [203, 254]` (antes medía lo mismo que las cartas).
- `data/places/L2.json`: el examen de `cesto_tiras` y del `puesto_cotter` menciona `[[papel_crema_grueso|papel crema grueso]]` y «de un centímetro».
- `data/places/L5.json`: lo mismo en el examen de `papel_club` y `papel_mesa`.
- La entidad `papel_corto` («un papel un centímetro más corto», que ya era una interpretación) se retira de C7 `keys`. Queda como alias en los diálogos que la nombran (Mycroft, Crane, portero), que suman `papel_crema_grueso` a su `match`.

**Invariante de C7:**
- C7.R1 y C7.R1c conservan sus ventanas y sus `deps` (garantizada y columna): las máscaras son idénticas a las de hoy.
- C7.R1d sólo **agrega** una ruta intacta desde 2.M.
- Las ★ (R2 y R4) no se tocan.
- T4 no cambia: `D46#fisica` lleva sólo `vinculo_mycroft` y la carta sólo `me_vigila_de_cerca`, así que ningún recorte legal cubre los dos grupos.
- T5 (ley de la huella) no cambia: M1 sigue cortando originales P un día y HB10 los devuelve.

#### C.5.5 Otras rutas o refutaciones que usaban medida o lupa

Ninguna. Esto se verificó en `conclusions.json` (refs `M:` sólo en C7.R1 y C7.R1c), en `_pistas_falsas` (sin `M:`), en la confrontación (grupos `a:` de texto) y en HB12 (asientos sellados). Las comparaciones de letra quedan además a la vista en las descripciones (`mano_holmes` aparece igual en HC01, D12 y D37), pero **sin etiquetas nuevas**: no se agrega ninguna ruta por letra.

#### C.5.6 Compatibilidad y limpieza

- `clip_measure` sigue en `Actions.SPEC` para reproducir partidas viejas y se resuelve como el recorte de la línea `fisica` del documento. La interfaz no lo emite.
- `Tutorial.STEPS` deja de contarla.
- Los campos `measure` de D46 y de las plantillas de reacciones se borran (TEXTOS-DOCUMENTOS). Mientras tanto se ignoran.
- Las referencias `M:` siguen soportadas por `RouteDB`, sin uso.
- El cambio de contenido cambia `content_hash`: una partida vieja muestra «otra versión» y se reproduce con `_replay_safe`.

#### C.5.7 Tests

- **T30, nuevo** (`test_t30_fisica.gd`): todo documento de `data/docs` y toda plantilla de reacción tiene descripción. El texto generado cumple el formato fijo (una oración, ≤40 palabras, un tramo `#fisica`). Sólo D46 y las plantillas de la Remington llevan etiquetas `a:`. `D46#fisica` y `R:HA1.fisica` se resuelven en `RouteDB`.
- **T1 y T3** verdes con C7 nueva.
- **T4** incluye las líneas `fisica`.
- **T29**: no existen los nodos `lupa` ni `regla`.

---

## D. Afordancias: qué se puede mirar y qué se puede usar

### D.1 Reglas (cómo encajan con «nada marcado»)

**Examinable** (todo nodo con `examine`, incluidas siluetas y personajes). Al pasar el mouse:
- se dibuja un contorno de tinta y el objeto se aclara un poco;
- aparece una etiqueta discreta con su sustantivo (`noun`, o el nombre del personaje si ya se presentó);
- el cursor pasa a ser una **lupa**.

Es **igual para todo**: la silla, la estufa, los tomos y la ceniza.

**Usable**: tiene un vínculo de acción en `map.json objects` (cuaderno, libro, bandeja, tintero, pliegos, tijera, mapa, calendario, cama, puerta y escalera, catálogo), es una salida o es un **personaje en primer plano**. Además de lo anterior:
- lleva **siempre** un contorno fino en tinta roja apagada (`#8a2b22`, el rojo de las cintas de los libros);
- el cursor pasa a ser una **mano**;
- la etiqueta suma el verbo: «Cuaderno · abrir», «Tintero · escribir», «Calendario · terminar el turno», «Watson · hablar».

Lo usable se marca **sólo cuando su función existe** (§C.2): el mapa no lleva contorno en el prólogo y el libro no lo lleva antes del día 1.

**Siluetas de fondo** (Wiggins, el muchacho sin gorra, el cochero, los dos hombres de M3): son sólo examinables y **no llevan contorno permanente**. Si se les puede hablar, el cursor de mano aparece al pasar por encima, igual que con cualquier personaje.
- **Razón:** su presencia es evidencia (C6, K-S). Un contorno permanente señalaría una pista. Un cursor al pasar no la señala: es la misma respuesta que da cualquier figura con la que se puede hablar.

**«Mirar alrededor»** (mantener **Espacio**, acción nueva `fe_mirar`): mientras se mantiene, todos los examinables del encuadre se contornean y muestran su nombre a la vez, por igual. Se enseña con una línea de Pendientes el día 1 (`look.ayuda`).

**Por qué no rompe `design.md`.** La regla prohíbe resaltar **sólo lo importante**. Acá se resalta:
- **todo** lo examinable, por igual; o
- una categoría de **interfaz** (herramientas de Lisle, salidas, interlocutores en primer plano) que no es evidencia del caso.

El GDD §8.6 queda matizado en ese sentido.

### D.2 Etiqueta y cursores

- **`ui/desk/hover_label.gd`** (nuevo):
  - una tira de papel pequeña en la capa del HUD, a (18, 22) px del cursor y siempre dentro de la pantalla;
  - aparece a los 0,08 s y se va al salir del objeto;
  - con «mirar alrededor», hay una etiqueta por examinable en el centro proyectado de su ancla, con un antisolapamiento simple (se corre hacia abajo).
- **`ui/desk/cursors.gd`** (nuevo): dibuja por código, sin archivos, una lupa y una mano de 32×32 en tinta sobre papel.
  - Se asignan con `Input.set_custom_mouse_cursor` a `CURSOR_HELP` (lupa) y `CURSOR_POINTING_HAND` (mano).
  - `WorldRoot` pone `Input.set_default_cursor_shape` según lo que hay bajo el mouse. El pick se hace 30 veces por segundo como máximo, con el mismo `picker.gd` del clic.

### D.3 Spec técnico del realce (funciona igual con cualquier look)

**Códigos en la rugosidad del material**, que se leen en el canal A del buffer `normal_roughness` de Forward+, el mismo que ya leen los looks:

| Código | Rugosidad | Significado |
|---|---|---|
| 0 | 1,00 | Escenario: paredes, piso y todo lo que no es nodo |
| 1 | 0,75 | Examinable |
| 2 | 0,50 | Usable (permanente) |
| 3 | 0,25 | Bajo el mouse (temporal; pisa 1 y 2) |

- **`world/materials.gd`**: todo material del mundo pasa a `diffuse_mode = LAMBERT`, `specular_mode = DISABLED` y `metallic = 0`. Así la rugosidad **no cambia el color**. Se verifica con una captura que debe ser idéntica con 1,00 y con 0,25.
- **`world/diorama_builder.gd`**:
  - por cada nodo de la instantánea, las `MeshInstance3D` de su prop (`node.prop`) o del maniquí reciben un material duplicado con la rugosidad de su código (caché por material y código);
  - los personajes en primer plano llevan el código 2 y las siluetas, el 1;
  - el código 3 lo pone y lo quita `WorldRoot` al cambiar el objeto bajo el mouse.
- **Quad de afordancias** (`world/post/affordance_post.gd` y `affordance.gdshader`, nuevos):
  - es un segundo `QuadMesh` colgado de la cámara, con el mismo patrón que `engraving_post.gd` y `render_priority` mayor que el del look;
  - `shader_type spatial; render_mode unshaded, blend_mix, cull_disabled, depth_test_disabled, depth_draw_never;`;
  - lee **sólo** `hint_normal_roughness_texture` y **no** lee la pantalla: dibuja encima del resultado del look con alfa;
  - decodificación de la rugosidad (Godot 4): `r = a; if (r > 0.5) r = 1.0 - r; r /= 127.0/255.0;`.
  - Lo que dibuja:
    - **bajo el mouse**: borde = dilatación de la máscara de código 3, con 8 tomas a 2 px (a 900 p), menos la máscara; tinta del look con α 0,8 y el interior aclarado con papel α 0,12;
    - **usable**: borde de 1 px de la máscara de código 2, en `#8a2b22` con α 0,45;
    - **mirar alrededor** (`uniform bool reveal_all`): borde de 1 px de código ≥1, en tinta con α 0,6.
  - En alto contraste usa negro y rojo oscuro con α 1.
- Los **nodos sin prop** (sólo ancla, p. ej. la sombra del librero) no tienen malla: muestran sólo la etiqueta y el cursor.
- **Plan B**, si la decodificación falla en alguna GPU: una máscara en `SubViewport` a media resolución, con una cámara gemela y `cull_mask` de la capa 20, y el mismo contorno dibujado en 2D. Sólo se adopta si falla el test de calibración.

### D.4 Legibilidad con la aguada (look por defecto)

- **Look por defecto: `aguada`** (`Looks.DEFAULT`). `grabado` queda en Opciones.
- **Menos lavado en los objetos.** En `looks/aguada.gdshader`, donde el código es ≥1 (examinables), el suavizado `soften` se multiplica por 0,5 y la pluma `line` por 1,3. Los objetos quedan más nítidos que el escenario, todos por igual.
- **Contraste de albedo en la mesa:**
  - cuaderno de tapas negras sobre el cuero claro del escritorio;
  - libro de conclusiones abierto, de papel claro con columnas rojas;
  - bandeja de madera clara;
  - tintero de vidrio con tapa de latón oscura;
  - tijera de hierro;
  - calendario blanco.
  Diferencia de luminancia mínima con su entorno: 0,15.
- **Tamaño y zona.** Los usables del escritorio quedan juntos en el frente de la mesa y miden ≥36 px proyectados en la vista general a 1600×900.
- **Epígrafe de lugar al entrar** (sin cambio) y «mirar alrededor» para orientarse.

### D.5 Tests

- **T34, nuevo** (`test_t34_affordance.gd`):
  - todo nodo con prop recibe el código 1 o 2;
  - el código 2 lo reciben **sólo** los nodos con vínculo en `map.json` y bandera activa, las salidas y los personajes en primer plano;
  - **ninguna silueta** recibe el código 2;
  - captura idéntica con rugosidad 1,00 y 0,25 (materiales sin especular);
  - prueba con ventana: el pick bajo el mouse cambia el cursor y muestra la etiqueta.
- **T27**: compilan los looks y `affordance.gdshader`; calibración con ventana: un plano con código 3 da un borde detectable en la captura.

---

## E. Cámara: adiós a las flechitas

### E.1 Decisión (una sola)

**Vista general con mirada libre limitada, clic para acercarse y clic derecho o Esc para alejarse.** Las flechas del teclado son opcionales.

- **Vista general.** Cada área (la buhardilla, la tienda, cada lugar) tiene una posición «de pie en la puerta» desde la que se ve casi todo. Llevando el mouse a los **bordes** de la pantalla o **arrastrando** sobre el vacío, la vista gira dentro de límites, como girar la cabeza. No hay traslación ni WASD.
- **Acercarse:**
  - clic en un objeto: la cámara se acerca y lo encuadra (el `examine_aabb` actual, ahora también en casa) y aparece su tarjeta;
  - clic en una **zona** (el escritorio, la ventana, la pared del mapa, los estantes): la cámara va al encuadre de esa zona, que son los `frames` actuales, y los objetos chicos quedan grandes;
  - rueda: zoom hacia el cursor.
- **Alejarse:** clic derecho o Esc vuelve un nivel: de objeto a zona y de zona a vista general.

### E.2 Comportamiento exacto

| Entrada | Efecto | Límite o suavizado |
|---|---|---|
| Mouse en la banda de borde: 8 % del ancho a izquierda y derecha, 10 % del alto arriba y abajo | Gira la vista hacia ese lado | Arranca después de 0,15 s en la banda. Velocidad = 45 °/s × smoothstep de la profundidad en la banda. **Nunca** gira si el mouse está sobre un control de la interfaz, si hay un panel abierto, si la tijera está activa o durante un arrastre |
| Arrastrar con el botón izquierdo sobre el vacío (umbral de 6 px) | Gira la vista siguiendo el arrastre | Como la órbita actual |
| Rueda | Cerca: FOV −3° por muesca y gira el 25 % hacia el cursor. Lejos: deshace | FOV entre base −18° y base +4° |
| Flechas ← → ↑ ↓ (`fe_orbita_*`) | Giran la vista | 60 °/s |
| Clic en un objeto | Se acerca a él y abre su tarjeta, o lo usa si es usable | Transición de 0,45 s, ease in-out |
| Clic en una zona | Va al encuadre de la zona | 0,45 s |
| Clic derecho o Esc | Baja un nivel en la pila de poses; si no hay nada que bajar, Esc abre Opciones (como hoy) | 0,45 s |
| Mantener Espacio | Mirar alrededor (§D) | — |

**Límites por área**, en `data/camera.json`:

| Área | Giro horizontal | Giro vertical |
|---|---|---|
| Buhardilla | ±70° | ±14° |
| Tienda | ±60° | ±12° |
| Lugares (por defecto) | ±max(orbit.yaw, 35°) | ±12° |
| Láminas fijas | ±15° | ±8° |

En un encuadre de zona, la mirada se reduce a ±12°.

**Suavizado.** Los giros y el FOV siguen a su objetivo con `x += (objetivo − x) · (1 − e^(−12·dt))`. No hay saltos.

**Opciones.** «Girar la vista con los bordes de la pantalla» (activada por defecto). El arrastre y las flechas siempre funcionan.

### E.3 Spec técnico

- **`data/camera.json`** (nuevo; dueño CÁMARA). Las coordenadas de la buhardilla son una propuesta que se calibra con capturas; el resto sigue el mismo patrón:

```json
{
  "L1.buhardilla": {"overview": {"pos": [1.3, 1.62, 1.7], "look": [-0.2, 1.05, -1.5], "fov": 62, "yaw": 70, "pitch": 14},
                    "zones": {"escritorio": "escritorio", "atril": "escritorio", "ventana": "ventana",
                              "mapa": "pared", "estante": "pared", "percha": "pared"}},
  "L1.tienda":     {"overview": {"pos": [1.4, -4.75, -1.7], "look": [-0.6, -5.1, 1.6], "fov": 62, "yaw": 60, "pitch": 12},
                    "zones": {"mostrador": "mostrador", "estantes_libros": "estantes", "estantes_revistas": "estantes",
                              "escaparate": "escaparate"}},
  "*": {"overview": "first_frame", "yaw_min": 35, "pitch": 12}
}
```

  `zones` va de un **id de nodo** al **id de un encuadre** de `places/*.json` (los frames siguen ahí). `map.json` no se toca.
- **`world/camera_rig.gd`:**
  - modos `overview` (gira en el lugar: el pivote es la posición de la cámara), `zone` (el frame, con mirada reducida) y `examine` (la órbita actual alrededor del objeto);
  - pila de poses: `push(pose)` y `back()` saca una;
  - objetivos `yaw_target`, `pitch_target` y `fov_target` con el suavizado de E.2;
  - `limits()` por modo;
  - se mantienen `set_frame()` y `frames` para el director, el tutorial y los drivers.
- **`world/world_root.gd`:**
  - `_process` aplica la banda de borde (sólo si `input_enabled`, la ventana tiene foco, `gui_get_hovered_control() == null` y la opción está activa);
  - en `_unhandled_input`, rueda hacia el cursor (`project_ray_normal` → ángulo) y clic sobre zona o nodo;
  - `auto_examine = true` también en casa;
  - se suma el código 3 del realce (§D.3).
- **`ui/desk/game_screen.gd`**: se borran `_chevron`, `_chev_l`, `_chev_r`, `_step_frame` y `CHEVRON_DY`. `on_node` mira primero `camera.json zones` (si la pose es `overview`, va a la zona y después aplica el vínculo normal). Siguen `go_frame` y `frames()` para el tutorial y los drivers.
- **`ui/input_router.gd`**: `fe_mirar` (Espacio, manejado en `_input` si no hay foco en un campo de texto). El clic derecho sigue siendo volver.

### E.4 Tests

- **T32, nuevo** (`test_t32_camera.gd`).
  - Sin pantalla:
    - límites por modo;
    - el suavizado converge sin saltos mayores a 3° por cuadro a 60 fps;
    - la pila de poses funciona: objeto → zona → general → nada;
    - la banda de borde no gira sobre la interfaz ni con un panel abierto.
  - Con ventana y **sin `--fast`**, con eventos reales al estilo de `devtools/drivers/title_smoke.gd` (`warp_mouse` + `Input.parse_input_event`):
    - mouse en el borde → la vista gira;
    - clic en el escritorio → encuadre `escritorio`;
    - clic derecho → vista general;
    - no existe ningún botón `ChevronIzq` ni `ChevronDer`.
- Se actualizan los drivers que usan chevrones: `w3shell_raton`, `w4novato`, `w4novato_pick` y `w3int_flow`.

---

## F. Plan por áreas (dueños disjuntos)

### F.1 Dueños

Cada archivo tiene **un** dueño. Los textos nuevos que necesite un área de código van en su propio `ui_text/v2_<área>.json`: el merge de claves ya existe y una clave duplicada es un error. TEXTOS-UI los revisa al final, sólo por estilo.

| Área | Archivos que posee |
|---|---|
| **PROGRESIÓN** | `core/sim/*`, más los nuevos `reveal.gd`, `guide.gd` y `ui_state.gd`, y la acción `read` en `actions.gd` y `player_actions.gd` · `core/graph/*` (`reveal` y `stock` en Availability; `R:<rid>.fisica` en RouteDB) · `core/data/data_repo.gd` y `schema.gd` (aplicar `stock`, inyectar `fisica` llamando a `core/text/fisica.gd`, esquemas nuevos) · `core/react/effects.gd` (**sólo** el gancho de `fisica` en `instance_text`) · `data/schedule.json`, `data/map.json`, `data/conclusions.json`, `data/lists.json` · `ui/map/*` · `devtools/bots/*` · tests T1, T3, T10, T24, T26, `test_u_tutorial`, `test_u_clock`, `test_u_world_model`, `test_u_actions`, `test_u_route_db` y los nuevos `test_u_reveal`, `test_u_guide`, `test_u_ui_state` · `ui_text/v2_progresion.json` |
| **CÁMARA + AFORDANCIAS** | `world/camera_rig.gd`, `world/world_root.gd` (entrada y realce), `world/picker.gd`, `world/rect_clip.gd`, `world/diorama_builder.gd`, `world/materials.gd`, `world/props/*` · `world/post/affordance_post.gd` y `affordance.gdshader` (nuevos) y el ajuste de §D.4 en `world/post/looks/aguada.gdshader` · `ui/desk/*` **salvo** `catalog.gd` y `tray.gd` (incluye la tarjeta de examen jerárquica, la pila de diarios, la tira de Pendientes, `hover_label.gd` y `cursors.gd`) · `ui/input_router.gd`, `ui/shell.gd`, `ui/drag/*`, `ui/menus/options.gd` (opción de bordes) · `data/camera.json` (nuevo) · `project.godot` (acción `fe_mirar`) · tests T32, T34, T27 (parte de afordancias), `test_t29_dioramas` (si hace falta) · drivers `devtools/drivers/v2cam_*.gd` · `ui_text/v2_camara.json` |
| **DESPEJE-UI** | `ui/reader/*` (borra `lens.gd` y `ruler.gd`; línea `fisica`; emite `read`) · `ui/notebook/*`, `ui/ledger/*` (página «Lo que me preguntaron», tipos plegados, sello con su bandera), `ui/scene/*`, `ui/compose/*`, `ui/kit/*` · `ui/desk/catalog.gd` y `ui/desk/tray.gd` · `core/text/fisica.gd` (nuevo) · `data/fisica.json` (nuevo) · `data/entities/v2_fisica.json` (nuevo: entidades de papel, entre ellas `papel_crema_grueso`) · tests T30, T31 (`test_t31_ui_reveal.gd` y su driver con ventana), `test_u_text_builder`, `test_u_ledger_ui`, `test_u_w4ui` · `ui_text/v2_despeje.json` |
| **TEXTOS-UI** | `data/ui_text/*.json` existentes (y revisión de estilo de los `v2_*.json` al final) · `data/scenes/PRO.json` (prólogo y tutorial) · claves `tut.d1.*` · test T33 (`test_t33_style.gd` y `tests/fixtures/style_exceptions.json`) |
| **TEXTOS-DIÁLOGOS** | `data/dialogue/*.json` · `data/scenes/*.json` salvo PRO |
| **TEXTOS-DOCUMENTOS** | `data/docs/**/*.json` (textos y títulos; borrar `measure` de D46) · `data/reactions/*.json` (**sólo** textos de `rastro`, títulos y firmas de `doc`; borrar `measure`) · `data/places/*.json` y `data/plates/*.json` (`examine` y epígrafes; **borrar los props y nodos `lupa` y `regla` de L1 y M7**; menciones de `papel_crema_grueso` en L2 `cesto_tiras` y `puesto_cotter` y en L5 `papel_club` y `papel_mesa`) · `data/entities/*.json` salvo `v2_fisica.json` (`name` e `index`) · `data/endings.json`, `data/easter_eggs.json`, `data/canon_bible.json` (sólo textos) |

### F.2 Orden y dependencias

1. **Primero**, DESPEJE-UI publica la firma de `core/text/fisica.gd` como stub que compila:
   ```
   static func line(spec, mm, fis) -> String
   static func tags(spec) -> Array
   static func ents(spec, fis) -> Array
   ```
   También crea `data/fisica.json` con D46 y las plantillas de la Remington.
2. **Después, en paralelo**: PROGRESIÓN, CÁMARA + AFORDANCIAS y DESPEJE-UI (código).
3. **Cuando el código está integrado**, en paralelo: TEXTOS-UI, TEXTOS-DIÁLOGOS y TEXTOS-DOCUMENTOS. Son sólo datos y respetan §A.5.
4. **Cierre:** suite completa con salida redirigida a `.work/`, drivers con ventana **sin `--fast`** y revisión de las capturas.

Reglas comunes a todas las áreas:
- Godot sólo vía `./godot.sh`, nunca en paralelo ni en segundo plano.
- Tests filtrados mientras se trabaja y suite completa sólo al final.
- Nada fuera de `C:\Dev\books`, sin descargas, sin commits.
- No tocar `.work/jugador/`.

### F.3 Criterios de aceptación (verificables)

**PROGRESIÓN**
- [ ] Con una partida nueva, `q_places()` en 1.M lista sólo L1 (con la tienda), L2 y L4.
- [ ] L3 aparece apenas se lee una hoja que menciona Baker Street y, si no, el 2.dawn. L6 sigue la misma regla y aparece a más tardar el 3.dawn; L5 portería, el 8.dawn; L7, el 5.dawn; L8, el 7.T. Lo verifica `test_u_reveal`.
- [ ] D04 y D07 son legibles en la tienda desde 2.M; D09, D10 y D42 desde 3.M; D43 y D44 desde 4.M. Nada de eso antes.
- [ ] T1 y T3 verdes con los datos reales; T3 tarda menos de 10 s.
- [ ] T26 ampliado y T24 verdes.
- [ ] T10: ningún bot supera al deductor y el pasivo termina en F4.
- [ ] `q_guide()` devuelve ≤3 líneas y es igual para dos estados que sólo difieren en etiquetas ocultas o en lo sellado.
- [ ] `q_ui()` implementa la tabla de §C.2 con un test por bandera.
- [ ] `read` se registra y `replay` da el mismo `state_hash` (T9).
- [ ] C7.R1, C7.R1c y C7.R1d se resuelven y pasan `RouteDB.lint`.

**CÁMARA + AFORDANCIAS**
- [ ] No existe ningún chevrón en ningún modo. Lo verifican un grep de `ChevronIzq` y el driver.
- [ ] En el driver con ventana sin `--fast`:
  - mouse en el borde izquierdo durante 1 s → la vista gira 20° o más hacia la izquierda;
  - clic en el escritorio → encuadre de la zona;
  - clic derecho → vista general;
  - rueda → el FOV baja y la vista apunta hacia el cursor.
- [ ] Al pasar sobre la silla aparecen el contorno, la etiqueta «silla» y el cursor de lupa. Sobre el cuaderno (con su bandera) aparecen el contorno, «Cuaderno · abrir» y la mano. Sobre la silueta de Wiggins no hay contorno permanente.
- [ ] Manteniendo Espacio, todas las etiquetas del encuadre a la vez.
- [ ] T34 y T32 verdes; T27 verde (compila `affordance.gdshader`).
- [ ] Capturas de la buhardilla en vista general con look aguada: `v2cam_general`, `v2cam_hover_silla`, `v2cam_mirar`.

**DESPEJE-UI**
- [ ] El lector no tiene Lupa, Regla, «Anotar la medida» ni botones de zoom. `lens.gd` y `ruler.gd` no existen.
- [ ] Todo documento muestra su línea `fisica`, que se puede recortar. Recortar la de D46 da un recorte con `papel_crema_grueso` en el pie.
- [ ] T30 verde: 100 % de los documentos y plantillas.
- [ ] T31 verde: para cada vista, al arrancar el día 1 sólo están los controles de «Al principio» de §C.3, y cada control aparece con su bandera. Su driver con ventana sin `--fast` saca una captura por vista al empezar y otra a mitad de partida (`script` del bot deductor hasta el día 5).
- [ ] Con 30 recortes, el cuaderno muestra buscador y filtros. Con 3, no muestra ni pestañas ni buscador.
- [ ] El libro muestra «Lo que me preguntaron» con las tres citas del encargo el día 1.

**TEXTOS-UI**
- [ ] T33 da 0 hallazgos en `ui_text` (lista de §A.3 más los términos viejos del glosario §A.1, con excepciones justificadas en `style_exceptions.json`, p. ej. «asiento 214»).
- [ ] El prólogo nuevo (4 pasos) y el día 1 (5 pasos) se juegan de punta a punta con el driver sin `--fast`.
- [ ] Ninguna clave de ui_text tiene botones de más de 3 palabras.

**TEXTOS-DIÁLOGOS**
- [ ] T33 da 0 hallazgos de vosotros y peninsularismos y 0 latinismos en los diálogos.
- [ ] Siguen los tics de §A.3. Test: el «sir» por frase de Mrs. Hudson sigue creciendo con HB6 (la cuenta de las líneas `hb6` es mayor que la de las genéricas).
- [ ] `DataRepo.errors() == []`; T1, T4, T20 y `test_i_integration` verdes.

**TEXTOS-DOCUMENTOS**
- [ ] El encargo (D23) se lee en 2 minutos, con tres preguntas numeradas y una línea sobre dónde atiende Watson.
- [ ] Las voces A y B no tienen «dele», «véase» ni «sic».
- [ ] Sin `measure` en los datos.
- [ ] Sin nodos `lupa` ni `regla`.
- [ ] Están las menciones de `papel_crema_grueso` de §C.5.4.
- [ ] Lint de datos en 0; T1, T4, T7, T11 y T33 (documentos: peninsularismos y latinismos) verdes.

---

## G. Decisiones abiertas para el usuario y riesgos

1. **Título**: ver §A.2 (se recomienda «Lo que Watson no escribió»). Mientras el usuario no decida, sigue «Fe de erratas».
2. **El «sir» de Mrs. Hudson**: se propone mantenerlo porque es una pista que se cuenta. La alternativa sería «señor», que pierde contraste con el resto.
3. **Girar con los bordes**: se propone activado por defecto. Si molesta en las pruebas, se apaga por defecto y quedan el arrastre y las flechas.
4. **Ritmo**: la garantía de Somerset House es el día 3 y la de Baker Street el día 2. Hay margen medido para atrasarlas un día más (variante estrecha de §B.8) si se quiere un arranque todavía más lento.
5. **Riesgo técnico**: la decodificación de la rugosidad (§D.3) depende del formato del buffer en Godot 4.7. Lo controla la calibración de T27 y, si falla, se pasa al plan B (máscara en `SubViewport`).
6. **Riesgo de diseño**: Pendientes podría sentirse como una lista de misiones. Se mitiga con ≤3 líneas, sin marcas de hecho o pendiente, sin progreso y siempre en la voz de Lisle. Si al jugar se siente así, se reduce a la obligación con hora y a la novedad del día.
