# Referencias de diseño: juegos de deducción, adversarios reactivos y documentos

Investigación para el juego "Books" (Godot 4.7, 3D, crónicas de Sherlock Holmes; Holmes sabe que lo investigamos y reacciona).
Fuente de verdad del proyecto: `design.md`. Este documento NO decide el diseño: reúne evidencia y propone opciones fundamentadas.

Convención de fuentes:
- **[P]** fuente primaria (declaración del desarrollador o reglas oficiales).
- **[S]** secundaria (reseña, wiki, foro, análisis de terceros). Puede tener errores; se marca cuando hay una sola fuente.
- **[A]** análisis propio, sin fuente externa.

Las URLs están al final (sección 7), numeradas; en el texto se citan como `[n]`.

---

## 0. Hallazgos clave (TL;DR)

1. **Observar es gratis, comprometerse cuesta.** Todos los juegos que funcionan separan la recolección (sin costo) de la afirmación (con costo o validación). Ace Attorney: *press* gratis / *present* penalizado. Papers, Please: mirar es libre, sellar tiene consecuencias. Esta separación es la defensa principal contra la fuerza bruta y evita castigar la exploración. [P/S 5, 9, 20]
2. **Validar en lote, nunca de a una.** Obra Dinn confirma sólo cuando hay 3 destinos correctos a la vez. Pope lo diseñó porque el feedback instantáneo invita al ensayo y error (lo aprendió de Papers, Please), y eligió 3 porque 2 era poco. [P 2]
3. **Feedback parcial calibrado.** Golden Idol añadió "dos o menos casillas incorrectas" porque calificar todo o nada frustraba. Pero eso permite fuerza bruta por panel, y la gramática de las oraciones filtra respuestas. En español la concordancia de género y número filtra todavía más. [P 11, S 13, A]
4. **Señal de suficiencia, no de pista.** Obra Dinn desenfoca las caras hasta que existe evidencia suficiente para identificar a esa persona. Indica "ya se puede deducir" sin decir de dónde. Es la forma más limpia de ayudar sin violar "ninguna pista es entregada". [P 2]
5. **La regla de las tres pistas** (Alexandrian): cada conclusión necesita al menos 3 pistas, porque el jugador perderá una, ignorará otra y malinterpretará la tercera. Golden Idol agrega un matiz: la redundancia hacia una conclusión es buena, pero los atajos que se saltan pasos de razonamiento se eliminan. [P 30, 10]
6. **Construir herramientas de análisis del grafo de pistas.** Pope casi no hizo playtesting formal: construyó herramientas que analizaban las conexiones de nodos y cuándo se enfocaba cada cara. Para un juego hecho por agentes IA, esto se traduce en **tests automáticos de invariantes de deducción**. [P 2]
7. **El adversario necesita "dos cerebros".** Alien: Isolation separa un director, que sabe todo y regula el ritmo, de un agente que sólo sabe lo que percibe. Además, nunca desbloquea comportamientos a partir de muertes del jugador, para no castigarlo con reglas invisibles. Es el modelo natural para Holmes. [P/S 22]
8. **La reacción debe citar la acción concreta del jugador.** El sistema Nemesis funciona porque el orco recuerda la cicatriz que le hiciste. Si Holmes reacciona de forma genérica, no se lee como reacción. [P/S 24, 25]
9. **La reacción misma es una pista.** Holmes es canónico en esto ("el perro no hizo nada durante la noche"). Y el propio canon tiene a Holmes reaccionando a quienes hurgan en los papeles de Watson (*The Veiled Lodger*). El núcleo del juego tiene precedente canónico directo. [P 40, 41]
10. **Arquitectura "columna + parches"** (Overboard!): un guion base que asume que el jugador no hizo nada, más mini-escenas que se insertan si aplican y se saltan si no. Es robusto, testeable y apto para generar reacciones de Holmes con datos. [P 26]
11. **Lo procedural sin columna narrativa no da historia memorable.** A Shadows of Doubt le critican repetición y poca narrativa. Nuestro requisito de "historia memorable y profunda" pide contenido escrito a mano con sistemas encima, no al revés. [S 15]
12. **Presentación barata y potente: dioramas congelados.** Obra Dinn (1-bit, escenas de muerte congeladas), la *Danza de la deducción* de Great Ace Attorney (escena 3D quieta que se rota y se señala) y Golden Idol (escenas estáticas) demuestran que la deducción no necesita animación. Encaja perfecto con primitivas/CSG en Godot. [P/S 2, 7, 18]

---

## 1. Deducción: qué hicieron excepcionalmente bien

### 1.1 Return of the Obra Dinn (Lucas Pope, 2018)

**Qué es.** El jugador es perito de seguros de la Compañía de las Indias Orientales. Hay que determinar identidad, causa de muerte y, si corresponde, autor del destino de las 60 personas a bordo. Un reloj, el *Memento Mortem*, muestra el audio de los últimos segundos y un diorama congelado del instante de la muerte. Todo se registra en un libro. [S 4, 6]

**Cómo evita la fuerza bruta.**
- Confirmación por **lotes de 3** destinos completamente correctos. Pope lo decidió a mitad del desarrollo [P 2]:
  - de Papers, Please aprendió que el feedback debe ser inmediato, pero que el feedback instantáneo invita a "hacer trampa" probando;
  - agrupar en 3 dificulta mucho adivinar y conserva el feedback;
  - un amigo le desaconsejó usar 2, y el 3 "suena fuerte" en el misterio occidental;
  - en el capítulo final dos causas de muerte se revelan solas, así que las últimas deducciones se confirman de a pares.
- Efecto secundario: cuando se confirma un lote, el jugador sabe que sus otros borradores son incorrectos. Es información negativa que guía sin regalar. [S 3, 4]
- Límite conocido: al final, con pocas opciones restantes, los jugadores "pescan" respuestas rotando nombres. [S 3, 4] Pope admite que los marineros y vigías quedaron demasiado difíciles y que mucha gente adivinó. Por agotamiento, tras 4,5 años, no agregó más pistas. [P 2]

**Cómo el jugador decide qué es pista.** Nada está resaltado. La escena congelada contiene todo: posición, ropa, con quién está cada uno, idioma y acento en el audio, hamacas numeradas, el retrato grupal y el plano del barco. [S 5, 6] El 1-bit niega el color como pista fácil y obliga a leer forma, disposición, sonido e idioma. [S 6]

**Señal de suficiencia.** Las caras están desenfocadas hasta que el juego considera que ya existe evidencia para identificar a esa persona. También hay estrellas de dificultad por identificación. Antes del lanzamiento el desenfoque estaba roto, y la primera jugadora (la esposa de Pope) no podía saber qué personajes eran resolubles. [P 2] Lección: sin esa señal, el jugador intenta deducir lo imposible y se frustra.

**Redundancia y estructura.**
- Las identidades se cruzan por varios ejes. Ejemplo de jugador: un grupo habla ruso en una escena, uno de ellos tiene un rol único visible en otra, y el resto se infiere. [S 4]
- Pope construyó herramientas para analizar la estructura (conexiones de nodos, en qué momento se levanta cada desenfoque) en lugar de depender del playtesting. [P 2]
- Casi todo el juego se puede recorrer sin resolver nada. La motivación es el deseo de completar la lista. [P 2]
- El diario se añadió a mitad del desarrollo, al ver que seguir a más de 60 personajes en una línea temporal no lineal era inmanejable. [P 2]
- La estructura en capítulos ("desastres") fue lo más difícil y le "ató las manos". Terminó priorizando identidades sobre medios de muerte. [P 8]

**Para nosotros:** confirmación en lotes, señal de suficiencia, ninguna pista resaltada y un grafo de pistas validado por herramienta.

### 1.2 The Case of the Golden Idol (2022) y The Rise of the Golden Idol (2024), Color Gray Games

**Qué es.** Escenas estáticas de un crimen. Al hacer clic en personas y objetos aparecen textos. Ciertas palabras pasan a un banco y, en la pantalla "Pensar", se arrastran a oraciones con huecos (estilo Mad Libs), a una tabla de nombres y a otros paneles. [S 12, 13]

**Anti-fuerza bruta y feedback.**
- Cada panel se califica completo. Calificar todo o nada frustraba, así que añadieron el aviso **"dos o menos casillas son incorrectas"**. Según el diseñador, eso redujo la dificultad y la duración del juego. Citan el principio de que, si tienen la oportunidad, los jugadores optimizan la diversión hasta eliminarla. [P 11]
- Crítica: la calificación por panel permite fuerza bruta (probar sospechosos uno a uno), y **la gramática de la oración filtra respuestas**: a veces sólo un verbo encaja. [S 13]
- [A] Riesgo propio del español: artículos, género y número ("la ___ fue envenenada") delatan la respuesta. Las plantillas deben usar formas neutras o huecos que incluyan el artículo.

**Construcción de pistas.** [P 10, 11]
- Sólo incluyeron contenido necesario para la solución o que creara un desvío interesante. Pusieron a propósito un *red herring* fuerte: la escritura con sangre en la pared.
- Usaron un esquema de "camino de pensamiento" (*thought path*): cada descubrimiento lleva al siguiente. Admiten no haber logrado un marco confiable para construir misterios.
- Donde fue posible, distintas pistas llevan a la misma conclusión, lo que hace muy disfrutable ver jugar a otros.
- **Pero eliminaron las pistas que permitían saltarse pasos.** Si un tester se saltaba la deducción por otra pista, la quitaban.
- Querían evitar dos extremos: entender el misterio de inmediato, o quedarse trabado 30 minutos en un tecnicismo.
- Testearon temprano con prototipos crudos (tablas, arte provisional) y un grupo fijo de 4 a 5 personas. Su análisis fue cualitativo: observar qué hacían y decían los jugadores.
- La historia llega como pista, sin "muros de exposición".

**Rise (cambios).** [S 14]
- Los paneles se superponen a la escena en lugar de cambiar de pantalla.
- Al abrir una ventana se vuelcan todas sus palabras al banco.
- Hay paneles opcionales (nombres, significado de un código) que no son necesarios pero ayudan.
- Al final de cada capítulo hay paneles que **unen los casos entre sí**.

**Para nosotros:** la idea de "oraciones con huecos" es excelente para validar conclusiones. Pero el banco de palabras es una forma suave de marcar pistas: el juego decide qué es recolectable. Ver la propuesta de "recorte libre" en la sección 4.

### 1.3 Ace Attorney (Shu Takumi, 2001–) y The Great Ace Attorney

- **Núcleo:** encontrar contradicciones entre testimonios y golpearlas con evidencia. [P 17]
  - El primer prototipo exigía hallar una sola contradicción en todo el juicio, y los jugadores no sabían qué hacer. Pasaron a dividir el juicio en tramos con muchos momentos "ajá".
  - Primero se escucha el testimonio entero; luego se contrainterroga. [P 17]
  - Takumi buscó que el jugador pudiera "armarlo todo aunque le falte una parte de la evidencia". Es redundancia explícita. [P 17]
- **Economía:**
  - *Press* (pedir detalle) casi nunca se penaliza; *present* (afirmar una contradicción) sí. [S 9]
  - La penalización sale de un recurso compartido: signos de exclamación y, más tarde, la barra de paciencia del juez.
  - Hay recuperación: otros personajes dan pistas, y presionar de nuevo resetea elecciones. [S 9]
- **Defecto conocido:** a veces se acepta sólo una prueba, aunque otra también probaría lo mismo ("lógica Ace Attorney"). [S 9] Es un antipatrón directo para nuestra regla de conclusiones accesibles desde varios lugares.
- **The Great Ace Attorney:**
  - Takumi propuso un juego de Sherlock Holmes porque hacía años que quería hacer uno. Una idea temprana era un gran detective que deduce mal y el jugador lo corrige. [P 18]
  - La **Danza de la deducción**: Herlock propone una cadena de razonamiento con errores; la escena se congela en 3D, el jugador rota la cámara y señala el objeto que corrige el error. [S 19]
  - **Advertencia:** Herlock Sholmes es una caricatura (excéntrico, lógica defectuosa) por razones de licencia y de tono. La mecánica es útil; la caracterización contradice nuestro requisito de fidelidad al canon.

### 1.4 Papers, Please (Lucas Pope, 2013): deducción por discrepancia

- **Modo inspección:** el jugador resalta **dos datos que no concuerdan**, por ejemplo un nombre escrito distinto en dos documentos o una foto que no coincide, y eso habilita opciones como interrogar. [S 20]
  - El jugador propone la relación; el juego sólo confirma que existe una discrepancia.
  - El protocolo se evalúa en el momento en que la persona sale de la cabina. [S 20]
- **Para nosotros:** "señalar dos fragmentos de dos crónicas que se contradicen" es el verbo central perfecto para investigar publicaciones. Es exactamente el "Gran Juego" holmesiano (sección 2.9): fechas que no cuadran, la herida de Watson que cambia de lugar, etc.

### 1.5 Shadows of Doubt (ColePowered Games, 2023)

- **Ciudad simulada.** Las pistas salen del rastro de la simulación: recibos, CCTV, huellas y testigos. Cartas y diarios son plantillas personalizadas. [S 15, 16]
  - Jefferies: en la escena del crimen el juego no empuja hacia ninguna pista; el jugador decide qué hay y cuándo terminó. [P vía S 16]
- **Resolución:**
  - Se envía un formulario. Sólo el nombre es obligatorio; los campos opcionales correctos (dirección, prueba, arma) dan bonificación. [S 15]
  - Una acusación errónea implica multa, **y el asesino sigue matando**. [S 15] Es una consecuencia en el mundo, no un "game over".
- **Críticas:**
  - repetición de objetos, diálogos y casos;
  - personajes poco memorables;
  - las investigaciones tienen pocas consecuencias;
  - falta una historia que una los casos;
  - el diseño sin ayudas lleva a callejones frustrantes. [S 15]
- **Para nosotros:** la acusación con campos opcionales es buena. Lo procedural puro no cumple "historia memorable".

### 1.6 Her Story (Sam Barlow, 2015)

- Se buscan clips de interrogatorio escribiendo palabras en una terminal policial de los 90. Barlow resumió la accesibilidad con una idea: si sabes usar Google, puedes jugar. [P 27, 28]
- **El jugador decide qué palabra es pista, con libertad total**, y la búsqueda devuelve sólo los primeros resultados, lo que obliga a refinar hipótesis. [S 28]
- Crítica: se puede tropezar con un clip clave sin haber razonado. [S 29]
- **Para nosotros:** un índice de época con resultados limitados, como el catálogo de la Reading Room del British Museum o un índice de *The Strand Magazine*. La consulta del jugador ya es una hipótesis.

### 1.7 Outer Wilds (Mobius Digital, 2019)

- La progresión es sólo conocimiento: el juego nunca da habilidades, da comprensión. [S 31] El GDC 2020 "Curiosity-Driven Exploration" cubre la meta-estructura del misterio. [P 32]
- La "respuesta" es una acción en el mundo que sólo funciona si se entendió el sistema. No hay formulario que adivinar, así que la fuerza bruta es imposible.
- Un bucle de unos 22 minutos reinicia el mundo, pero el conocimiento persiste. Es presión de tiempo que no castiga la exploración.
- El *ship log* es un grafo de rumores con marcadores: "?" para un lugar no visitado y "*" para "aquí hay más". [S 31]
- **Para nosotros:** el log como grafo es buena referencia, pero los marcadores "hay más aquí" son pistas meta. Contradicen "ninguna pista es entregada" y no deberían usarse.

### 1.8 Heaven's Vault (inkle, 2019)

- Se traduce una lengua antigua proponiendo significados. Ingold: el juego no va a decirte si acertaste. Los errores pueden encadenarse. Hicieron unas 20 iteraciones de prototipo. [P 33, 34]
- **Confirmación por corroboración:** una palabra se confirma, o se refuta, cuando aparece en suficientes contextos distintos. Una fuente habla de dos contextos; el umbral exacto no está confirmado. [S 35] La mayoría de las palabras nunca se confirman. [S 35]
- Crítica: el sistema a veces no acepta lecturas obvias y limita los tipos de conjetura. [S 33]
- La tecnología de *modelado de conocimiento* (qué sabe y cree cada personaje) se reutilizó en Overboard!. [P 26]
- **Para nosotros:** las hipótesis del jugador se "confirman" cuando son coherentes con dos o más fuentes independientes. Es la traducción mecánica del requisito "accesible desde varios lugares".

### 1.9 Disco Elysium (ZA/UM, 2019)

- **Chequeos blancos** (reintentables al mejorar) **vs. rojos** (una sola oportunidad). Fallar genera contenido y nunca bloquea el progreso: siempre hay otra vía, aunque sea peor. [S 36]
- **Thought Cabinet:** los pensamientos entran "boca abajo" y tardan tiempo de juego en internalizarse; mientras tanto suelen dar penalizaciones. Hay 53 en total y unos 16 por partida. [P repost 37]
- Las habilidades hablan como un coro de personalidades. [S 36]
- **Para nosotros:**
  - "fallar hacia adelante" en acciones de campo;
  - hipótesis que maduran con el tiempo;
  - voces interiores distintas, por ejemplo el propio razonamiento del jugador frente a la voz de Watson en sus textos.
  - **Cuidado:** los chequeos pasivos de Disco Elysium entregan información al jugador. Eso viola nuestra regla de que ninguna pista es entregada.

### 1.10 Paradise Killer (Kaizen Game Works, 2020)

- Investigación abierta en una isla 3D. Al final hay un juicio donde **se puede acusar a cualquiera** y "probar tu versión de la verdad". No hay estado de fallo. [P pre-lanzamiento vía S 38]
- Crítica: tensión entre no tener fallo y ofrecer pistas de ayuda. [S 39]
- Para nosotros: en el juicio final el jugador argumenta con lo que juntó, y equivocarse tiene consecuencias narrativas, no un "game over".

### 1.11 Pentiment (Obsidian, 2022)

- Sawyer: para que fuera interesante, **no podía haber una respuesta correcta**. [P 42]
  - Quitaron el sistema de coartadas porque sólo sirve para excluir sospechosos, y ellos querían incluir sospechosos, no descartarlos. El foco está en el móvil. [P 42]
  - El tiempo limitado obliga a elegir qué investigar: no se puede seguir todo. [S 42, 43]
- **Para nosotros:** la verdad indeterminada choca con el MUST "ninguna conclusión sin pista alcanzable". Sirve sólo para dilemas morales, por ejemplo qué hacer con lo descubierto. La economía de franjas de tiempo es aprovechable.

### 1.12 The Roottrees are Dead (Jeremy Johnston, 2025)

- Se reconstruye un árbol genealógico investigando en una web y biblioteca simuladas. Al fijar suficientes parientes, el "empleador" entrega material nuevo. [S 44]
  - No se pudo verificar si confirma en grupos de 3 como Obra Dinn.
- **Ayudas:** un patito de goma da pistas graduales, de lo general ("recuerda este concepto") a lo explícito ("busca esto"). Se considera muy bien calibrado. [S 44]
  - Defecto: si el patito te da pistas sobre algo que ya completaste, te revela que está mal. [S 45]
- Las notas se vuelven difíciles de navegar cuando crecen. [S 44]

### 1.13 Strange Horticulture (Bad Viking, 2022)

- Se identifican plantas leyendo descripciones y bocetos de un libro, más una inspección por tacto y olor. [P 46]
  - Incluyeron a propósito rasgos del boceto que no ayudan.
  - Ajustaron las plantas parecidas hasta que cada una tuviera un rasgo distintivo.
  - Limitaron la cantidad de plantas para que la guía no revelara demasiado.
- El mapa de pistas está inspirado en *Sherlock Holmes: Consulting Detective*. [P 46]
- Tres errores en un día llevan a un minijuego de "recomponer la mente" **sin pérdida de progreso**. El reseñista dice que la decepción consigo mismo pesa más que la penalización. [S 47]

### 1.14 Orwell (Osmotic Studios, 2016)

- El jugador decide qué fragmentos de datos (*datachunks*) sube al sistema. No todo lo que encuentra es correcto o debería subirse. [P 48]
  - Si dos fragmentos se contradicen, sólo uno puede subirse. [S 49]
  - Lo subido no se puede retirar, y el sistema actúa sobre ello: puede arrestar a un inocente o evitar un atentado. [S 49]
- **Para nosotros:** registrar una pista es una decisión con consecuencias. Idea directa: **Holmes lee lo que el jugador anota, publica o consulta** (sección 6).

### 1.15 Sherlock Holmes: Consulting Detective (juego de mesa, 1981) y Crimes & Punishments (Frogwares, 2014)

- **Consulting Detective:**
  - Holmes resuelve cada caso con N pistas y vale 100 puntos. Cada pista extra del jugador resta 5 y cada una de menos suma 5. [P reglas 50]
  - Un análisis defiende que esa penalización *es* la estética holmesiana: inferir con poca evidencia, citando "We balance probabilities and choose the most likely". [S 51]
  - La crítica habitual es que desincentiva explorar Londres. [S 51]
  - Además, el periódico del día es fuente de pistas. [S 50]
- **Crimes & Punishments:**
  - Tablero de deducción donde se enlazan pistas en una red, con nodos de interpretación alternativa. [S 52]
  - Holmes puede equivocarse y mandar inocentes a la cárcel. [P vía S 52]
  - Al final se elige absolver o condenar. [S 52]

### 1.16 Aviary Attorney (Sketchy Logic, 2015)

- Perder un juicio no termina el juego: la historia continúa y se ramifica, y los casos finales cambian según los resultados previos. [S 53]

### 1.17 Teoría transversal

- **The Three Clue Rule** (Justin Alexander, 2008) [P 30]:
  - Para toda conclusión necesaria, al menos 3 pistas. Una sola pista son en realidad varios cuellos de botella: buscar, examinar, identificar y deducir.
  - Todo cuello de botella necesita 3 soluciones.
  - Corolarios:
    - búsqueda permisiva: más pistas siempre es mejor;
    - pistas proactivas: si se estancan, que pase algo ("que entre un tipo con un arma", Chandler);
    - los *red herrings* están sobrevalorados y, si se usan, necesitan una refutación incontrovertible;
    - llevar una **lista de revelaciones** (conclusión → pistas que llevan a ella) y marcar una conclusión sólo cuando el jugador la *acepta*, no cuando la considera.
  - Rechaza el modelo de "migas de pan" automáticas de GUMSHOE porque deja de sentirse misterio.
- **"We are terrible detectives"** (Luis Díaz, 2018) [S 54]:
  - aguja en un pajar: muchas respuestas posibles y una correcta;
  - cuidado con lo que dice la UI, porque cada detalle acota las posibilidades;
  - dejar fallar, acusar mal y seguir pistas muertas.
- **Game Maker's Toolkit** clasifica los juegos de detectives en tres tipos: deducción (Obra Dinn, Golden Idol), contradicción (Ace Attorney, Lucifer Within Us) e investigación abierta. [S 55, 56] Nuestro juego combina deducción (conclusiones) con contradicción (discrepancias entre crónicas).

### 1.18 Síntesis A: mecanismos anti-fuerza bruta

| Mecanismo | Juego | Qué previene | Riesgo | Aplicabilidad para nosotros |
|---|---|---|---|---|
| Confirmar sólo lotes de N correctos | Obra Dinn | probar 1 a 1 | "pesca" al final con pocas opciones | **Alta** (conclusiones principales) |
| Feedback parcial ("≤2 mal") | Golden Idol | frustración de todo o nada | fuerza bruta por panel; fugas gramaticales | Media (sólo dentro de un lote) |
| Recurso de paciencia por error | Ace Attorney | presentar al azar | castiga experimentar si está mal calibrado | Media (sólo en acusaciones ante terceros) |
| Sin confirmación | Heaven's Vault, Pentiment, Paradise Killer | — | insatisfacción, choca con el MUST | Baja (sólo dilemas morales) |
| Confirmación por corroboración | Heaven's Vault | adivinar aislado | opacidad del umbral | **Alta** (hipótesis intermedias) |
| Resultados de búsqueda limitados | Her Story | leer todo sin pensar | tropiezo fortuito | Media (índices de biblioteca) |
| Conocimiento como llave | Outer Wilds | formulario adivinable | requiere sistema rico | **Alta** (acciones que sólo funcionan si se entendió) |
| Costo por acción vs. referencia (Holmes) | Consulting Detective | exhaustividad mecánica | desincentiva explorar | Media (como reacción narrativa, no como puntaje) |
| Irreversibilidad de lo registrado | Orwell | prueba y error | ansiedad | Media (publicar o mostrar pruebas) |
| Consecuencia en el mundo al errar | Shadows of Doubt | acusar a todos | si es excesiva, frustra | **Alta** |
| Penalización sin pérdida de progreso | Strange Horticulture | spam de respuestas | puede sentirse trivial | Alta (acciones de campo) |

### 1.19 Síntesis B: ¿quién decide qué es pista? (espectro)

| Grado de marcado | Ejemplo | Comentario |
|---|---|---|
| Libertad total (texto libre) | Her Story | máxima agencia; riesgo de tropiezo y de frustración por vocabulario |
| Selección libre sobre material | Shadows of Doubt (fijar cualquier cosa al corcho), Papers, Please (resaltar cualquier par) | **objetivo recomendado** |
| Fragmentos pre-segmentados | Orwell (*datachunks*) | el juego decide la granularidad, no la relevancia |
| Palabras recolectables pre-elegidas | Golden Idol | el juego decide qué es recolectable: marca suave |
| Señal de suficiencia | Obra Dinn (caras desenfocadas) | aceptable: no dice qué ni dónde |
| Marcadores de "hay más" | Outer Wilds ("*") | viola la regla |
| Resaltado de objetos / visión especial | Hitman (Instinto), modos de "concentración" | viola la regla; Hitman deja desactivarlo [S 23] |

---

## 2. Sistemas reactivos y adversarios que responden al jugador

### 2.1 Hitman (IO Interactive, 2016–2021)

- **Sensores locales y servicios compartidos.** Cada NPC tiene una base de conocimiento (pública y privada) y sensores inmediatos. Los "servicios" de disfraz, cadáver o asesino se actualizan periódicamente, así que **su información puede estar desactualizada**: un hueco explotable y aprendible. [S 21]
- **Legibilidad.** Las animaciones son críticas para telegrafiar las decisiones de cada personaje. [S 21] Hay estados graduales de alerta y la escalada es legible: el policía primero intenta arrestar, no disparar. [S 57]
- **Ejecutores** (*enforcers*): sólo ciertos NPC ven a través de ciertos disfraces, y es aprendible. [S 57]
- **Contra la frustración:**
  - Hitman 2 interrumpe las rutas de los objetivos cuando el jugador prepara una oportunidad, para no hacerlo esperar 20 minutos. [S 21]
  - Las "oportunidades" guiadas y la visión de Instinto se pueden desactivar. [S 23]

### 2.2 Alien: Isolation (Creative Assembly, 2014)

- **Dos cerebros.** El director sabe dónde está el jugador y empuja al alien hacia su zona. El alien sólo sabe lo que perciben sus sensores. [S 22]
- **Medidor de amenaza.** Sube con la cercanía y la línea de visión. Al llegar al pico, el director aleja al alien (a otra zona o a los ductos) para dar respiro. [S 22]
- **Reglas justas:**
  - nunca teletransporta (sólo hay dos casos, en cinemáticas);
  - hay zonas que nunca revisa;
  - **nunca desbloquea comportamientos por muertes del jugador**, para no castigarlo con reglas invisibles que no pudo aprender. [S 22]
- **"Serendipia psicópata":** parece estar siempre en el lugar justo sin estar guionado. Evitaron sustos fijos porque pierden efecto al rejugar. [S 22]
- **Desbloqueo progresivo** de ramas del árbol de comportamiento, que se percibe como aprendizaje. [S 22]

### 2.3 F.E.A.R. (Monolith, 2005)

- La planificación de la IA usa sólo 3 estados más un planificador A*. Los soldados **se gritan órdenes**, y eso comunica al jugador lo que planean. Gran parte de la "inteligencia" percibida viene de que la IA anuncia sus intenciones. [P 58, S 59]
- Para nosotros: Holmes debe "anunciar" sus movimientos de forma diegética y en personaje.

### 2.4 Middle-earth: Shadow of Mordor (Monolith, 2014): sistema Nemesis

- Rastrea a los orcos que hacen algo notable contra el jugador (matarlo, sobrevivirle). Los asciende y **recuerdan el último encuentro**. Sus fortalezas y debilidades son visibles y cambian. [S 24]
- De Plater: el sistema genera detalle en los puntos clave ("anclas") y deja que la mente del jugador complete el resto. Durante el desarrollo recortaron complejidad (facciones, barras de moral) que convertía la UI en un "árbol de Navidad". [S 25]
- Para nosotros: **la reacción de Holmes debe referirse específicamente a lo que hizo el jugador** (qué documento, qué fecha, qué discrepancia).

### 2.5 Overboard! (inkle, 2021)

- Juegas como la asesina. Los demás personajes tienen horarios, actúan en tiempo real, recuerdan lo que ven y oyen, y quedan **"un paso detrás"** del jugador; la farsa son los cuasi-fallos. [P 26, S 60]
- **Arquitectura:** una "columna" (guion por defecto que asume que el jugador no hizo nada) más "parches" (mini-escenas que se insertan donde encajan y se saltan si no aplican o si ya ocurrieron). [P 26]
- Un menú de **"Preguntas"** lista lo que la protagonista vio a medias. Sirve de objetivo opcional para la próxima partida y anuncia que el juego es más amplio de lo que parece. [P 26]
- Usaron autoplay y aserciones del tipo "¿hace rato que no pasa nada interesante?" para detectar tramos muertos. [P 26]

### 2.6 SpyParty (Chris Hecker)

- Juego asimétrico: el francotirador observa una fiesta y busca, por conducta sutil, cuál de los invitados es el espía humano. [P/S 61]
- Hecker diseña para que el francotirador lea conductas en lugar de buscar una única delación mecánica. [P 61]
- Para nosotros: Holmes "lee" la conducta del jugador (qué consulta, en qué orden, a quién visita), y el jugador puede **disimular** o plantar señuelos. El engaño es una herramienta legítima contra Holmes.

### 2.7 Undertale y la meta-memoria

- Flowey recuerda las recargas y los reinicios normales del jugador. Fans y críticos lo leen como responsabilizar al jugador por sus reintentos. [S 62]
- Para nosotros: si Holmes reacciona, la **recarga de partida** es una estrategia degenerada evidente: ver la reacción, recargar y evitarla. Las opciones son que Holmes "recuerde" (diegéticamente plausible: él lo sabe todo) o que el guardado sea único y automático. Ver la sección 6.

### 2.8 Shadows of Doubt y Duskwood

- En Shadows of Doubt, una acusación errónea deja al asesino libre y sigue matando. [S 15]
- En Duskwood el jugador participa como sí mismo, los personajes "viven" en un chat, y el antagonista usa el mismo medio que el jugador para alcanzarlo. [P prensa 63]
- Para nosotros: Holmes usa los mismos canales que el jugador (la prensa, el correo, la biblioteca) para responder.

### 2.9 Precedentes en el canon de Doyle (dominio público)

Estos pasajes justifican canónicamente que Holmes lea, juzgue y reaccione a las publicaciones. Texto verificado en Project Gutenberg.

- **The Veiled Lodger** (Case-Book): Watson denuncia "the attempts which have been made lately to get at and to destroy these papers". Advierte que la fuente es conocida y que, con autorización de Holmes, si se repite, se publicará "the politician, the lighthouse and the trained cormorant". Cierra con "There is at least one reader who will understand." [P 41]
  - Es **la reacción de Holmes a un investigador, hecha a través de la propia publicación**: el núcleo de nuestro juego.
- **The Abbey Grange** (Return): Holmes acusa a Watson de su "fatal habit of looking at everything from the point of view of a story instead of as a scientific exercise". [P 40b] Holmes lee y critica las crónicas.
- **The Copper Beeches** (Adventures): "You have degraded what should have been a course of lectures into a series of tales." [P 40c]
- **The Blanched Soldier** (Case-Book): Holmes narra él mismo, porque Watson "ha insistido mucho" en que escriba una experiencia propia. Holmes puede ser autor, no sólo sujeto. [P 41]
- **Thor Bridge** (Case-Book): la caja de despacho de lata de Watson con casos inéditos, guardada en Cox & Co., Charing Cross. Es un objeto investigable perfecto. [P 41]
- **Silver Blaze** (Memoirs): "The dog did nothing in the night-time." / "That was the curious incident." [P 40] **La ausencia de reacción es una pista**: Holmes que *no* reacciona también informa.
- **El Gran Juego (Sherlockian game):** desde Ronald Knox (1911) los holmesianos tratan a Holmes y Watson como reales y reconcilian las incoherencias del canon (fechas, la herida de Watson, etc.). [S 64] **Nuestro game loop es literalmente el Gran Juego, con un Holmes que se entera.**

### 2.10 Principios: reacción legible sin explicarla, sin frustrar, y que sea pista

1. **Diegesis, no HUD.** No mostrar un medidor de sospecha (Hitman lo tiene, y no encaja con una UI limpia ni con la regla de no entregar pistas). Las reacciones se ven en objetos del mundo:
   - una nueva edición con cambios;
   - un anuncio en la columna personal (*agony column*) del *Times*;
   - una ficha de préstamo de biblioteca firmada;
   - un telegrama;
   - un Irregular que te sigue;
   - un documento que ya no está.
2. **Telegrafiar en personaje** (F.E.A.R., Hitman). Holmes canónico es teatral y disfruta las revelaciones dramáticas: sus reacciones pueden ser mensajes deliberados. No obstante, debe haber también reacciones *encubiertas* que el jugador descubre comparando.
3. **Citar la acción del jugador** (Nemesis). Cada reacción referencia algo concreto que el jugador hizo y que puede reconocer.
4. **Sensores aprendibles** (Hitman, Alien). Holmes sólo se entera por canales identificables: registros de biblioteca, editores, Irregulares, Mrs. Hudson, Mycroft. El jugador puede descubrir *cómo* se enteró, y esa pregunta ("¿cómo lo supo?") es en sí misma un misterio con pistas.
5. **Latencia y huecos** (servicios desactualizados de Hitman). Holmes se entera con retraso según el canal. Esto da ventanas de acción y un patrón aprendible.
6. **Nunca reglas ocultas por fracaso** (Alien). La escalada de Holmes depende de acciones visibles del jugador, no de errores invisibles.
7. **Ritmo con respiro** (director de Alien). Tras una reacción fuerte, un período de calma.
8. **Proactividad ante el estancamiento** (Alexandrian, Hitman 2). Si el jugador se traba, Holmes hace algo, y eso genera material nuevo. La reacción de Holmes es también el sistema anti-atasco.
9. **Información negativa** (Silver Blaze). Que Holmes no reaccione a una línea de investigación también es un dato: indica que no le preocupa, o que todavía no lo sabe.
10. **Engaño posible** (SpyParty, Overboard!). El jugador puede ocultar rastros, usar seudónimos o plantar consultas señuelo. La reacción de Holmes ante un señuelo confirma que la vigilancia existe y por qué canal.
11. **Coherencia del personaje.** Las reacciones de Holmes deben ser plausibles para el Holmes canónico: disfraces, Irregulares, columnas personales, química, monografías, Mycroft, respeto por un adversario digno como Irene Adler, y desdén por la "romantización" de Watson. Nunca una caricatura (la advertencia de Great Ace Attorney).

---

## 3. Presión de tiempo y economía de acciones sin castigar la exploración

### 3.1 Papers, Please

- **Tensión:** velocidad contra precisión. Se cobran 5 créditos por persona procesada. [S 65] [P/S 66]
- **Tolerancia:** las primeras **2 citaciones del día son gratis** (sólo se pierde el pago de esa persona). Desde la tercera hay multas crecientes: 5, 5, 10, 15... Se reinicia cada día. [S 65]
- El juego "sólo te quita tiempo cuando quiere presionarte": los días con mucho diálogo tienen menos carga, y los atentados cortan el día. [S 67]
- **Espacio de escritorio limitado** como fuente de dificultad. Las etiquetas son menos prominentes que los datos. [S 67]
- Pope no introducía reglas nuevas en las mañanas en que alguien le hablaba al jugador, porque el boletín se ignoraba. [S 66]
- **Recortes:** quitó la luz que avisaba cuando el supervisor vigilaba, porque la gente la clicaba como si fuera un botón. También quitó la inspección de equipaje, la luz UV y los tiroteos. [S 68] Lección: un indicador de vigilancia invita a interactuar con él como mecánica en lugar de leerlo como ambiente.
- La familia es unos pocos puntos y texto: la imaginación del jugador hace el resto. [P 66]

### 3.2 Pentiment

- Franjas de tiempo limitadas: no se puede investigar todo, y hay que elegir. [S 42, 43] Cada elección produce contenido, así que no hay elecciones "vacías".

### 3.3 Outer Wilds

- Bucle de unos 22 minutos: el mundo se resetea y el conocimiento persiste. La presión de tiempo existe, pero perder nunca borra lo aprendido. [S 31]

### 3.4 Sherlock Holmes: Consulting Detective

- Cada pista visitada cuenta contra la referencia de Holmes. Es elegante como estética, pero desincentiva explorar. [S 51]
- Para nosotros: usar esa idea como **reacción narrativa** ("Holmes llegó a esto con tres visitas; ustedes necesitaron nueve"), nunca como penalización mecánica del progreso.

### 3.5 Ace Attorney, Disco Elysium, Strange Horticulture, Aviary Attorney, Shadows of Doubt

- Ace Attorney: *press* gratis, *present* con costo. [S 9]
- Disco Elysium: chequeos blancos reintentables, rojos únicos; fallar genera contenido. [S 36]
- Strange Horticulture: el error no borra progreso. [S 47]
- Aviary Attorney: perder un juicio ramifica la historia. [S 53]
- Shadows of Doubt: errar tiene consecuencias en el mundo. [S 15]

### 3.6 Obra Dinn y Golden Idol: sin reloj

- Ninguno de los dos tiene presión de tiempo. Leer y deducir bajo reloj real deteriora la deducción. [A]

### 3.7 Principios para nuestro juego

1. **Pensar es gratis; actuar en el mundo cuesta.**
   - Gratis: leer, comparar, recortar, anotar y formular hipótesis en el cuaderno.
   - Consume tiempo diegético (días o franjas) y puede alertar a Holmes: ir a un lugar, consultar un registro, entrevistar, publicar o enviar una carta.
2. **Sin reloj en tiempo real** durante la lectura y la deducción. El tiempo avanza por acciones, como en Pentiment, no por segundos, como en Papers, Please.
3. **El costo de una acción es información, no castigo.** Una visita "cara", porque alerta a Holmes, debe devolver contenido: la propia reacción. Así explorar nunca es inútil; sólo cambia la configuración del tablero.
4. **Tolerancia explícita a errores baratos** (las 2 citaciones gratis de Papers, Please). Las primeras equivocaciones de procedimiento no tienen costo.
5. **Fallar hacia adelante.** Una acusación errónea o una línea cerrada por Holmes abre otra rama (Aviary Attorney), nunca un "game over" mudo.
6. **Holmes como cronómetro diegético.** En vez de un reloj, el ritmo lo marca la agenda de Holmes (director de Alien): si el jugador no actúa, Holmes avanza su propio plan.

---

## 4. UI limpia en juegos de documentos

### 4.1 Patrones observados

| Juego | Elemento | Qué aporta | Advertencia |
|---|---|---|---|
| Obra Dinn | Libro: lista de tripulación, plano, retrato grupal, capítulos | todo el estado en un objeto diegético; desenfoque como señal de suficiencia [P 2] | se añadió tarde, por necesidad |
| Golden Idol | Banco de palabras con colores por tipo; paneles con huecos; en Rise, superpuestos a la escena | validar conclusiones con poco texto; no cambiar de pantalla [P 11, S 14] | el color por tipo y la gramática filtran |
| Papers, Please | Escritorio limitado; modo inspección (resaltar 2 datos) | la comparación es el verbo; etiquetas discretas [S 20, 67] | la incomodidad es intencional |
| Her Story | Escritorio de los 90; buscador; resultados limitados | interfaz = ficción [P 27] | tropiezo |
| Shadows of Doubt | Fichas como expedientes; corcho con hilos (color = incriminación, grosor = fiabilidad); tooltips; HUD en 2 zonas compactas | máximo espacio para documentos [P 16b] | el hilo que se enrojece solo es una pista entregada |
| Outer Wilds | Grafo de rumores | memoria externa del jugador [S 31] | marcadores "*" y "?" |
| Heaven's Vault | Diccionario personal; confirmación por corroboración [S 35] | la memoria del jugador es el progreso | umbral opaco |
| Orwell | *Datachunks*; contradictorios excluyentes; subida irreversible [S 49] | registrar es decidir | segmentación previa |
| Strange Horticulture | Libro diegético con páginas animadas en 3D; un único cuarto [P 46] | tactilidad con pocos recursos | — |
| Disco Elysium | Thought Cabinet: hipótesis que maduran [P 37] | ritmo del pensamiento | — |
| Roottrees | Árbol genealógico; ayudas graduales [S 44] | estructura visible del objetivo | las notas grandes son difíciles de navegar |

### 4.2 Recomendaciones de UI

1. **Lector de documentos como objeto físico.** Página de época (tipografía de imprenta victoriana, columnas de *The Strand*). Zoom y paso de página. Nada resaltado.
2. **Recorte libre.** El jugador selecciona cualquier fragmento de texto (o una región de imagen) y lo guarda en el cuaderno. Internamente cada fragmento lleva etiquetas ocultas de entidad, fecha, lugar y afirmación, de modo que el juego "entiende" el recorte **sin haber marcado de antemano qué era recortable**. Los fragmentos irrelevantes también se pueden recortar, y eso es parte de la deducción. [A, inspirado en 16b, 20, 28]
3. **Comparación lado a lado y "cotejo".** Dos documentos abiertos a la vez; el jugador vincula dos recortes como *contradicción* o *corroboración* (Papers, Please). Ver la sección 6 para cómo y cuándo se valida.
4. **Cotejo de ediciones (diff).** La reacción principal de Holmes llega como nueva edición o nueva versión de un texto. El jugador puede superponer dos ediciones y ver diferencias **sólo en lo que elige comparar**, no con un resaltado automático global.
5. **Cuaderno con dos capas:**
   - "recortes" (evidencia cruda);
   - "proposiciones": oraciones con huecos al estilo Golden Idol, cuyas casillas se llenan arrastrando recortes o entidades ya nombradas por el jugador.
   - Evitar los colores por tipo de palabra y las plantillas con concordancia que filtre (ver 1.2).
6. **Tablero opcional** (corcho con hilo) para quien lo quiera. Los hilos no cambian de color según "la verdad" (Shadows of Doubt lo hace; para nosotros sería entregar la pista).
7. **Pocas zonas fijas.** Un indicador diegético de fecha, como el calendario de escritorio de la época, y nada más. Todo lo demás está en objetos.
8. **Sin marcadores de "hay más aquí"** ni contadores de pistas restantes. La única señal permitida es la de suficiencia (sección 6, R5).
9. **Escalabilidad del cuaderno** (problema de Roottrees): búsqueda en el cuaderno, filtros por persona, lugar y crónica, y agrupación por fecha **del calendario de la crónica**, no por orden de descubrimiento.

---

## 5. Presentación 3D en juegos de investigación con pocos recursos

### 5.1 Observado

- **Obra Dinn:**
  - 1-bit con *dithering* ordenado. Pope pasó de Bayer a una variante de ruido azul porque resistía mejor el escalado y la compresión de video. [S 70, 71]
  - Para que el patrón no parpadee al girar la cámara, lo **mapeó sobre una esfera centrada en la cabeza del jugador**: el patrón queda fijo al girar, aunque no al trasladarse. [S 69, 70]
  - Contornos por detección de bordes en post-proceso. [S 70]
  - Escenas de muerte **congeladas**: cero animación y todo el contenido en poses, objetos y audio. [S 6]
  - Los recuerdos anidados (usar el reloj dentro de un recuerdo) son satisfactorios la primera vez y tediosos al repetirse. [S 5]
- **Golden Idol:** escenas estáticas, pixel art en Case y estilo pictórico en Rise. Toda la información de un crimen cabe en una pantalla. [S 14]
- **Great Ace Attorney, Danza de la deducción:** escena 3D congelada que el jugador rota para señalar. [S 19]
- **Paradise Killer:** mundo 3D explorable con personajes 2D. Mundo fantástico para no depender de reglas reales, a costa de mucho *worldbuilding*. [S 38]
- **Papers, Please / Strange Horticulture:** un único espacio (cabina, tienda) como escenario permanente. Tactilidad en 3D para pasar páginas y abrir el mapa. [P 46, 66] Pope: colores apagados y menos detalle para expresar el tono; la baja resolución vino de sus limitaciones y le permitió producir rápido. [P 66]

### 5.2 Propuesta para Godot 4.7 con primitivas y CSG

1. **Escenario base fijo:** el estudio del investigador (escritorio, estantería, ventana a la calle). Es el "hub" diegético donde viven los documentos, como la cabina de Papers, Please o la tienda de Strange Horticulture. Cámara fija con puntos de interés (*point-and-click* 3D), sin WASD.
2. **Reconstrucciones como dioramas congelados.** Cada escena clave de una crónica se representa como diorama estático (primitivas/CSG, maniquíes en pose) que el jugador rota y examina, como Obra Dinn o la Danza de la deducción.
   - [A] **Idea de alto valor:** el diorama se construye *a partir del texto publicado*. Si Holmes hace que una edición cambie un detalle, el diorama de esa edición cambia, y comparar dioramas de dos ediciones es otra vía de cotejo. Esto da redundancia de rutas: el texto y la imagen son dos fuentes.
3. **Estilo unificador que disimula placeholders:**
   - Opción A, grabado/tinta 1-bit: post-proceso con *dithering* y contornos. Evoca las ilustraciones de Sidney Paget en *The Strand*: blanco y negro, plumilla. Hace que las primitivas parezcan ilustración de época.
   - Opción B, sepia plano con niebla de gas.
   - [A] La A es la más coherente con "investigar publicaciones".
4. **Implementación en Godot:**
   - post-proceso con un `QuadMesh` 2×2 con caras invertidas y shader `spatial` `unshaded`, con `POSITION = vec4(VERTEX.xy, 1.0, 1.0)`;
   - leer `hint_depth_texture` (y `hint_normal_roughness_texture`) para los contornos, y `hint_screen_texture` para el *dithering* [P 72, 73];
   - anclar el patrón al mundo o a la vista (esfera), no a los píxeles de pantalla, para evitar parpadeo [S 69, 70];
   - alternativa moderna: `CompositorEffect` [P 74].
5. **Personajes:** maniquíes de primitivas con un rasgo distintivo de silueta cada uno (sombrero, bastón, pipa), como hace Strange Horticulture con sus plantas parecidas [P 46]. El retrato textual vive en los documentos.
6. **Audio procedural:** ambiente de cabina y escritorio de Papers, Please (calle, carruajes, lluvia, reloj, papel). Pope destaca la mezcla de sonidos ambientales y disparados. [P 66] Los sonidos de papel y sello de Shadows of Doubt refuerzan la tactilidad. [P 16b]

---

## 6. Recomendaciones concretas para nuestro juego, y antipatrones

### 6.1 Recomendaciones (R#), cada una con su fuente y la regla de `design.md` que atiende

**Estructura de deducción**

- **R1. Grafo de revelaciones con invariantes automatizadas.** Mantener en datos la lista de conclusiones, con las pistas (fragmento + documento + edición) que llevan a cada una (Alexandrian). Tests automáticos que verifiquen:
  - (a) cada conclusión requerida tiene **≥3 pistas en ≥2 documentos distintos**;
  - (b) **para cada reacción posible de Holmes**, o combinación de reacciones alcanzable, cada conclusión conserva ≥1 ruta (idealmente ≥2);
  - (c) ninguna pista sola revela una conclusión que debería requerir dos pasos (atajos de Golden Idol);
  - (d) ninguna conclusión depende sólo de un easter egg.
  - Es la versión "agente IA" de las herramientas de Pope. Atiende: MUST deducción, Holmes afecta pistas, cobertura de tests. [P 2, 10, 30]
- **R2. Dos verbos de deducción:**
  - **Cotejar**: vincular dos recortes como contradicción o corroboración (Papers, Please, Ace Attorney, el Gran Juego);
  - **Proponer**: oraciones con huecos (Golden Idol).
  - El cotejo alimenta las proposiciones. [S 13, 20, 64]
- **R3. Validación en lote.** Las proposiciones principales se confirman sólo cuando **3 son correctas a la vez**, como Obra Dinn. Cuando un lote se confirma, las demás proposiciones pendientes quedan implícitamente marcadas como no confirmadas. No dar el "≤2 incorrectas" de Golden Idol por panel, o darlo sólo dentro de un lote completo. [P 2, 11]
- **R4. Corroboración en lugar de consulta** para hipótesis intermedias. Un cotejo no se valida al pulsar un botón. Se vuelve "firme" en el cuaderno cuando el jugador lo vincula con una **segunda fuente independiente** (Heaven's Vault). Así, que una conclusión sea accesible desde varios lugares es también la manera de confirmarla. [S 35]
- **R5. Señal de suficiencia, nunca de pista.** Equivalente al desenfoque de Obra Dinn: por ejemplo, una ficha de persona en el cuaderno cuyo retrato a lápiz se "entinta" cuando ya existe evidencia alcanzada suficiente para identificarla. No dice cuál. Opcional, y recomendado tras los problemas de Pope sin ella. [P 2]
- **R6. Recorte libre con etiquetado oculto** (sección 4.2). El juego nunca decide qué es recortable. Atiende: "ninguna pista es entregada". [A]
- **R7. Plantillas sin fugas.** Proposiciones redactadas para que género, número, tipo y longitud del hueco no delaten la respuesta en español. Tests automáticos: para cada hueco, todas las respuestas candidatas deben ser gramaticalmente válidas. [S 13, A]
- **R8. Aceptar toda prueba válida.** Si dos evidencias distintas prueban lo mismo, ambas se aceptan; no repetir la "lógica Ace Attorney". [S 9, P 17]
- **R9. Pocas falsas pistas y siempre refutables.** Cada *red herring* necesita una refutación incontrovertible alcanzable. [P 30, 11]

**Holmes reactivo**

- **R10. Arquitectura de dos cerebros** [S 22]:
  - **Holmes-agente**: sólo sabe lo que percibe por canales concretos y aprendibles (biblioteca, editores, Irregulares, Mycroft, Mrs. Hudson), con latencia por canal (Hitman).
  - **Director**: regula el ritmo (calma tras reacciones fuertes), garantiza las invariantes de R1 (nunca ejecuta una reacción que deje una conclusión sin ruta) y activa la proactividad si el jugador se estanca.
- **R11. Reacciones como "columna + parches"** (Overboard!). La historia base asume un jugador pasivo. Cada reacción de Holmes es un parche declarativo con condición, efecto sobre los documentos y referencia a la acción del jugador, y se salta si no aplica. Es testeable y apto para generación por agentes. [P 26]
- **R12. Cada reacción cita la acción concreta del jugador** (Nemesis) y deja **al menos un rastro nuevo** (un nuevo documento, un cambio de edición, un testigo). Así **la reacción es una pista**: revela qué teme Holmes, por qué canal se enteró y cuándo. [S 24, 25]
- **R13. Repertorio de reacciones canónicas:**
  - nueva edición o "corrección" de Watson;
  - anuncio cifrado en la columna personal del *Times*;
  - carta al editor;
  - préstamo o retiro de un volumen de la biblioteca (con ficha firmada o seudónimo);
  - un Irregular vigilando;
  - una visita disfrazada;
  - un documento desaparecido de la caja de Cox & Co.;
  - silencio deliberado (Silver Blaze).
  - Siempre justificables por el canon (sección 2.9). Atiende: personajes fieles al canon. [P 40, 41]
- **R14. Holmes lee lo que registramos** (Orwell). Lo que el jugador **publica, envía o consulta en registros públicos** es visible para Holmes; lo que anota en su cuaderno privado, no. Esto da al jugador control sobre su exposición y vuelve el engaño una estrategia legítima (SpyParty). [P 48, S 49, P 61]
- **R15. Nada de medidor de sospecha en pantalla.** La luz del supervisor de Papers, Please terminó clicada como botón. El "nivel de alerta" de Holmes se infiere del mundo (frecuencia y tono de las reacciones, tono de las cartas de Watson). [S 68]
- **R16. Contra la recarga degenerada.** Guardado automático único por partida, más justificación diegética: Holmes no "olvida" (Undertale). Alternativamente, reacciones deterministas: recargar y repetir lleva a la misma reacción, así que recargar no da ventaja. Requiere decisión del orquestador (ver 6.4). [S 62]

**Tiempo y economía**

- **R17. Pensar es gratis, actuar cuesta tiempo diegético** (franjas de día, Pentiment). No hay reloj en tiempo real durante la lectura. Las acciones de campo alertan a Holmes según el canal. [S 42, A]
- **R18. Errores baratos tolerados.** Las primeras acusaciones o cotejos fallidos del día no tienen costo (2 citaciones gratis de Papers, Please). Después, el costo es narrativo, como que un testigo deje de confiar, y nunca pérdida de progreso. [S 65, 47]
- **R19. Acusar a todos no debe ser más barato que deducir.** Cada acusación pública formal alerta a Holmes y quema credibilidad ante terceros: editores, Scotland Yard, Watson. Una acusación errónea tiene consecuencia en el mundo (Shadows of Doubt), por ejemplo que la persona real destruya pruebas. Así la acusación múltiple es estrictamente peor que deducir. [S 15, A]
- **R20. Comparación con Holmes como epílogo, no como puntaje.** Al cerrar un capítulo, Holmes (que lo sabía todo) comenta la eficiencia del jugador, al estilo Consulting Detective. Es reacción y easter egg, no penalización. [P 50, S 51]

**Narrativa, easter eggs y presentación**

- **R21. El Gran Juego como espina narrativa.** Las incoherencias del canon (fechas, la herida de Watson, el "James" de Mary Morstan, etc.) se usan **sólo** cuando son intencionales y explicables por Holmes o Watson ocultando algo. Otro agente debe auditar la cronología canónica para que toda incoherencia usada sea deliberada. Atiende: coherencia temporal. [S 64]
- **R22. Easter eggs en una capa separada:** "marginalia" o secretos de personajes. Nunca usan el verbo de proposición principal, nunca son prerrequisito y las invariantes de R1 los excluyen. Rise of the Golden Idol tiene paneles opcionales útiles pero no necesarios. Atiende: balance de easter eggs. [S 14]
- **R23. Paneles que unen crónicas al final de cada acto**, como el fin de capítulo de Rise. Obliga a demostrar comprensión del arco completo, más allá del caso suelto. [S 14]
- **R24. Dioramas congelados derivados del texto y estilo grabado 1-bit** (sección 5.2). [S 6, 70]
- **R25. Playtesting automatizado y temprano.** Agentes que juegan con estrategias degeneradas (6.2) y tests de ritmo del tipo "¿hace cuántas acciones que no pasa nada?" (Overboard!). Prototipos con tablas antes del arte (Golden Idol). [P 10, 26]

### 6.2 Estrategias degeneradas previstas y contramedidas

| Estrategia degenerada | Por qué tienta | Contramedida | Ref. |
|---|---|---|---|
| Probar combinaciones en las proposiciones hasta acertar | feedback inmediato | lote de 3 (R3); sin feedback por casilla | Obra Dinn [2] |
| Rotar sospechosos en la acusación | acusar es barato | cada acusación pública alerta a Holmes y daña la credibilidad; el error tiene consecuencia en el mundo (R19) | Shadows of Doubt [15] |
| Leer la gramática del hueco | fugas lingüísticas | plantillas neutras y testeadas (R7) | Golden Idol [13] |
| Guardar, provocar a Holmes, ver su reacción y recargar | reacciones como espionaje gratis | guardado único o reacciones deterministas (R16) | Undertale [62] |
| No investigar nada para no alertar a Holmes | evitar el costo | Holmes es proactivo y avanza su plan si el jugador está pasivo (R10) | Alexandrian [30], Alien [22] |
| Investigarlo todo de golpe | exhaustividad | las acciones de campo consumen franjas; Holmes reacciona a patrones | Pentiment [42], Consulting Detective [51] |
| Recortar todo el texto | nada está marcado | recortar es gratis pero no valida nada; sólo valen cotejos y proposiciones | [A] |
| Provocar reacciones para que Holmes "revele" la respuesta | la reacción es pista | las reacciones revelan *qué teme* Holmes, no la proposición exacta; siempre requieren cotejo | [A] |
| Usar la señal de suficiencia como oráculo (probar a ver cuándo se entinta) | meta-señal | la señal depende de evidencia *alcanzada* (recortada o leída), no de proposiciones probadas | Obra Dinn [2] |
| Spamear consultas en el índice | búsqueda libre | resultados limitados por consulta y cada consulta registrada es visible para Holmes | Her Story [28], Orwell [49] |

### 6.3 Antipatrones a evitar

1. **Resaltar o marcar pistas** (visión de detective, brillos, "*" de Outer Wilds, hilos que se enrojecen solos). Viola `design.md`.
2. **Una sola prueba aceptada** cuando hay varias válidas ("lógica Ace Attorney").
3. **Contradicción única para todo un tramo** (el primer prototipo de Ace Attorney): el jugador se pierde.
4. **Feedback por casilla o instantáneo** en las conclusiones principales.
5. **Reacción genérica** de Holmes que no cita la acción del jugador: se lee como evento aleatorio.
6. **Reglas invisibles** activadas por fracasos, o reacciones que el jugador nunca puede entender a posteriori.
7. **Holmes omnisciente sin canal.** Rompe la justicia del sistema y la verosimilitud del personaje. El director puede saberlo todo; Holmes, no.
8. **Holmes caricaturizado** (Herlock de Great Ace Attorney) o con personalidad inventada. Cualquier desvío del canon debe justificarse dentro de la historia.
9. **Reloj en tiempo real durante la lectura**: mata la deducción.
10. **Medidor de sospecha en el HUD**: se vuelve botón u objetivo en sí mismo (Papers, Please).
11. **Procedural sin columna narrativa**: repetitivo y olvidable (Shadows of Doubt).
12. **Recuerdos o escenas anidadas obligatorias y repetitivas**: tedio en revisitas (Obra Dinn). Hay que permitir saltar directamente a escenas ya vistas.
13. **Verdad indeterminada en la trama principal** (Pentiment): incompatible con el MUST. Reservarla para dilemas morales.
14. **Atajos** que permiten saltarse pasos de razonamiento (Golden Idol los eliminó).
15. **Cuaderno que no escala** (Roottrees): sin búsqueda ni filtros, el jugador se ahoga.

### 6.4 Ambigüedades y decisiones abiertas para el orquestador o el usuario

- **Guardado y recarga (R16):** ¿guardado único automático, al estilo roguelike o narrativo, o guardado libre con reacciones deterministas? Afecta la percepción de "Holmes sabe".
- **Grado de feedback (R3/R4):** ¿lote de 3 para todas las conclusiones principales, o sólo para el acto final? ¿Se muestra "≤2 incorrectas" dentro de un lote?
- **Señal de suficiencia (R5):** ¿se considera compatible con "ninguna pista es entregada"? Este documento la propone como compatible porque no dice qué ni dónde, pero es interpretable.
- **Estilo visual (5.2):** grabado 1-bit frente a sepia. Conviene decidirlo pronto, porque afecta todo placeholder.
- No se pudieron verificar con fuente primaria: el umbral de confirmación de Heaven's Vault, si Roottrees confirma en lotes de 3, y el contenido de las charlas de GDC de Outer Wilds (sólo resúmenes). Están marcados como [S].

---

## 7. Fuentes

Obra Dinn
1. Film Stories: "Exploring Return of the Obra Dinn's rule of three". https://filmstories.co.uk/?p=83249
2. Automaton (JP), entrevista a Lucas Pope sobre el desarrollo (lotes de 3, desenfoque, herramientas de nodos, dificultad). https://automaton-media.com/articles/interviewsjp/20190719-97599/2/
3. Let's Play Archive, Return of the Obra Dinn. https://lparchive.org/Return-of-the-Obra-Dinn
4. Steam: discusión sobre identificación de tripulantes. https://steamcommunity.com/app/653530/discussions/0/1741104717711187168
5. RPGFan, reseña. https://www.rpgfan.com/review/return-of-the-obra-dinn-2
6. Archania, análisis de Obra Dinn. https://archania.org/p/the-symbolic-world/symbolic-works/video-games/return-of-the-obra-dinn
7. Mechanics of Magic, "Critical Play: Return of the Obra Dinn". https://mechanicsofmagic.com/2026/04/29/critical-play-return-of-the-obra-dinn-4/
8. Gamereactor, "Lucas Pope found structure of Obra Dinn extremely difficult". https://www.gamereactor.eu/lucas-pope-found-structure-of-obra-dinn-extremely-difficult/

Golden Idol
10. Game Developer, Road to IGF 2023: "The Case of the Golden Idol used frequent testing...". https://www.gamedeveloper.com/road-to-igf-2023/-the-case-of-the-golden-idol-i-used-frequent-testing-to-improve-its-mystery-solving
11. Game Developer, "Pursuing the 'Aha!' moment with deductive reasoning game The Case of the Golden Idol" (A. Klavins). https://www.gamedeveloper.com/design/case-of-the-golden-idol
12. Gamepretty, guía de casos (mensajes de feedback). https://gamepretty.com/the-case-of-the-golden-idol-all-cases-guide/
13. Tampere Univ. PlayLab, "Pixelated dioramas of crime and mystery" (fuerza bruta y gramática). https://blogs.tuni.fi/playlab/game-reviews/the-case-of-the-golden-idol-pixelated-dioramas-of-crime-and-mystery/
14. Slant Magazine, reseña de Rise of the Golden Idol. https://www.slantmagazine.com/games/rise-of-the-golden-idol-review ; Thinky Games, reseña. https://thinkygames.com/reviews/the-rise-of-the-golden-idol-review ; Gamereactor, preview. https://www.gamereactor.eu/the-rise-of-the-golden-idol-preview-superior-sleuthing-1398293/

Shadows of Doubt
15. Wikipedia, Shadows of Doubt (resolución, críticas). https://en.wikipedia.org/wiki/Shadows_of_Doubt
16. Wireframe, "Walking the voxelated city streets in Shadows of Doubt". https://wireframe.raspberrypi.com/articles/walking-the-voxelated-city-streets-in-shadows-of-doubt-a-fully-simulated
16b. ColePowered, DevBlog #4: Case Folders & Cork Boards. https://colepowered.com/?p=33958

Ace Attorney
17. Siliconera / Nintendo Life, Shu Takumi sobre el proceso de escritura. https://www.nintendolife.com/news/2014/06/creator_shu_takumi_testifies_on_ace_attorney_writing_process ; https://nintendoeverything.com/ace-attorney-creator-on-initial-prototype-and-nearly-suspending-development-maya-and-mias-origins-more/
18. Nintendo Everything, Takumi sobre los orígenes de The Great Ace Attorney (Holmes). https://nintendoeverything.com/takumi-on-the-great-ace-attorney-origins-started-with-sherlock-holmes-motion-capture-more/
19. Twinfinite, "Dance of Deduction explained". https://twinfinite.net/guides/great-ace-attorney-chronicles-dance-of-deduction-explained-course-correct/ ; Wikipedia, The Great Ace Attorney: Adventures. https://en.wikipedia.org/wiki/The_Great_Ace_Attorney:_Adventures
9. StrategyWiki, jugabilidad de Phoenix Wright. https://strategywiki.org/wiki/Special:MobileDiff/376494 ; Steam, discusión sobre pruebas alternativas. https://steamcommunity.com/app/787480/discussions/0/2605804632893772111

Papers, Please
20. Papers Please Wiki, "Discrepancies". https://papersplease.fandom.com/wiki/Discrepancies
65. Ludo.guide, citaciones. https://www.ludo.guide/guide/papers-please/citations
66. Game Developer, "Designing the bleak genius of Papers, Please". https://www.gamedeveloper.com/design/designing-the-bleak-genius-of-i-papers-please-i- ; Road to the IGF: Lucas Pope. https://gamedeveloper.com/design/road-to-the-igf-lucas-pope-s-i-papers-please-i-
67. Mechanics of Magic, "Design Details in Papers, Please". https://mechanicsofmagic.com/2021/06/05/design-details-in-papers-please/
68. Kill Screen, funciones recortadas (luz del supervisor). https://www.killscreen.com/peek-behind-scenes-papers-please-reveals-baggage-search-and-gun-fights/

Reactivos y adversarios
21. Game Developer (AI and Games), "The AI of Hitman (2016)". https://www.gamedeveloper.com/design/the-ai-of-hitman-2016-
22. Game Developer, "The Perfect Organism: The AI of Alien: Isolation". https://www.gamedeveloper.com/design/the-perfect-organism-the-ai-of-alien-isolation
23. Twinfinite, reseña Hitman Season 1 (oportunidades e Instinto desactivables). https://twinfinite.net/2016/11/hitman-season-1-review/
24. Film Stories, "Killer Feature: Shadow of Mordor's nemesis system". https://filmstories.co.uk/?p=83424 ; GDC Vault, Chris Hoge, "Helping Players Hate (or Love) Their Nemesis". https://www.gdcvault.com/play/1025150/
25. GamesBeat, "Shadow of Mordor's Nemesis system draws from Burnout, football...". https://gamesbeat.com/shadow-of-mordors-nemesis-system-draws-from-burnout-football-and-an-architecture-book/
26. Game Developer, "How to get away with murder in Overboard!" (Jon Ingold). https://www.gamedeveloper.com/design/how-get-away-murder-overboard
57. Shacknews, "Hitman: Absolution focusing on smarter AI". https://www.shacknews.com/article/72044/hitman-absolution-focusing-on-smarter-ai
58. Jeff Orkin, "Three States and a Plan: The AI of F.E.A.R." (GDC 2006). https://gdcvault.com/play/1013282/Three-States-and-a-Plan ; PDF: https://pages.cs.wisc.edu/~dyer/cs540/handouts/gdc2006_orkin_jeff_fear.pdf
59. TechEnclave, "F.E.A.R.'s AI demystified". https://techenclave.com/threads/f-e-a-r-s-ai-demystified.12465
60. Pocket Gamer, Overboard!. https://www.pocketgamer.com/articles/086894/overboard-is-a-reverse-whodunnit-from-the-creators-of-80-days-out-now-for-ios/
61. Game Developer, "SpyParty and the indie ethos: Chris Hecker speaks". https://www.gamedeveloper.com/design/-i-spyparty-i-and-the-indie-ethos-chris-hecker-speaks
62. Steam, discusión sobre la memoria de Flowey (Undertale). https://steamcommunity.com/app/391540/discussions/0/312265327168565162
63. Everbyte, press kit de Duskwood. https://everbytestudio.com/Press/sheet.php?p=duskwood

Otros juegos de deducción
27. PC Gamer, "The story behind Her Story". https://pcgamer.com/the-story-behind-her-story
28. Wikipedia, Her Story. https://en.wikipedia.org/wiki/Her_Story_(video_game) ; Quarter Disorder, reseña. https://quarterdisorder.com/2015/07/09/review-her-story/
29. Amara, transcripción de GMTK "What Makes a Good Detective Game?" (2017). https://amara.org/v/C3BEu
30. The Alexandrian, "The Three Clue Rule". https://thealexandrian.net/wordpress/1118/roleplaying-games/three-clue-rule ; "Node-based design part 5". https://thealexandrian.net/wordpress/8202/roleplaying-games/advanced-node-based-design-part-5-the-two-prongs-of-mystery-design
31. Steam, discusión de Outer Wilds (progresión por conocimiento, ship log). https://steamcommunity.com/app/753640/discussions/0/598515152383419065 ; Wikipedia. https://en.wikipedia.org/wiki/Outer_Wilds
32. GDC, "Curiosity-Driven Exploration: The Design of Outer Wilds" (Beachum y Verneau, 2020). https://www.gdconf.com/news/attend-gdc-and-learn-how-outer-wilds-nailed-curiosity-driven-game-design ; GDC Vault (Kelsey Beachum, 2021). https://gdcvault.com/play/1027008/Independent-Games-Summit-Sparking-Curiosity
33. Emily Short, "Heaven's Vault (inkle)". https://emshort.blog/2019/07/23/heavens-vault-inkle/
34. PCWorld, "inkle's space archaeologist adventure won't tell you if your translations are wrong". https://www.pcworld.com/article/406127/inkles-space-archaeologist-adventure-wont-tell-you-if-your-lost-language-translations-are-wrong.html ; TheSixthAxis, entrevista. https://www.thesixthaxis.com/2018/04/27/interview-talking-with-inkles-about-deciphering-ancient-language-in-heavens-vault/
35. Wurb, "Heaven's Vault: Language" (confirmación por contextos). https://wurb.com/stack/page/47 ; Film Stories, reseña. https://filmstories.co.uk/reviews/heavens-vault-review/
36. Gfinity, "Disco Elysium: can you fail". https://gfinity.net/disco-elysium/can-you-fail/ ; The Fandomentals. https://www.thefandomentals.com/disco-elysium-redefines-stories-rpgs/
37. GameBanshee, "Disco Elysium: Introducing the Thought Cabinet" (devblog de R. Kurvitz). https://gamebanshee.com/39hc9 ; Wikipedia. https://en.wikipedia.org/wiki/Disco_Elysium
38. GamesRadar, "The making of Paradise Killer". https://gamesradar.com/the-making-of-paradise-killer ; Edge (PressReader). https://www.pressreader.com/australia/edge/20191205/281535112845609
39. Wireframe, "Paradise Killer and designing a gripping courtroom drama". https://wireframe.raspberrypi.com/articles/paradise-killer-and-designing-a-gripping-courtroom-drama
42. Shacknews, "Pentiment's creator intentionally designed it so 'there cannot be a right answer'". https://www.shacknews.com/article/146276/pentiment-josh-sawyer-no-correct-answer
43. VGC, reseña de Pentiment. https://www.videogameschronicle.com/review/review-pentiment-is-an-outstanding-tale-of-monks-mystery-and-murder
44. Checkpoint Gaming, reseña de The Roottrees are Dead. https://checkpointgaming.net/reviews/2025/01/the-roottrees-are-dead-review-tracing-family-roots/ ; Thinky Games. https://thinkygames.com/reviews/the-roottrees-are-dead-review/
45. Steam, discusión de Roottrees (pistas del patito). https://steamcommunity.com/app/2754380/discussions/0/592889031515247198
46. Game Developer, "Finding the right plant for the job in Strange Horticulture". https://www.gamedeveloper.com/design/strange-horticulture---bad-viking
47. PC Gamer, reseña de Strange Horticulture. https://www.pcgamer.com/uk/strange-horticulture-review/
48. articy, "Orwell: Keeping an eye on you" (entrevista a Daniel Marx). https://www.articy.com/en/showcase/orwell-keeping-an-eye-on-you/
49. Wikipedia, Orwell. https://en.wikipedia.org/wiki/Orwell_(video_game) ; RAWG, reseña. https://rawg.io/reviews/55274
50. Reglas oficiales de Sherlock Holmes: Consulting Detective. https://officialgamerules.org/game-rules/sherlock-holmes-consulting-detective/
51. Erik Twice, "Sherlock Holmes Consulting Detective: the aesthetics of scoring". https://eriktwice.com/en/2021/03/19/sherlock-holmes-consulting-detective-aesthethics-scoring/
52. TheSixthAxis, reseña de Crimes & Punishments. https://www.thesixthaxis.com/2014/09/30/sherlock-holmes-crimes-punishments-review/ ; Wikipedia. https://en.wikipedia.org/wiki/Sherlock_Holmes:_Crimes_%26_Punishments
53. Emily Short, "Aviary Attorney". https://emshort.blog/2016/09/11/aviary-attorney-sketchy-logic/ ; MobyGames. https://www.mobygames.com/game/80698/aviary-attorney/
54. Luis Díaz, "We are terrible detectives" (Game Developer). https://www.gamedeveloper.com/design/we-are-terrible-detectives
55. GMTK, "The 3 Types of Detective Game" (2023). https://www.youtube.com/watch?v=I7q363Ic26o
56. Wikipedia, Game Maker's Toolkit. https://en.wikipedia.org/wiki/Game_Maker%27s_Toolkit

Canon (dominio público, Project Gutenberg)
40. *The Memoirs of Sherlock Holmes* ("Silver Blaze"). https://www.gutenberg.org/ebooks/834
40b. *The Return of Sherlock Holmes* ("The Abbey Grange"). https://www.gutenberg.org/ebooks/108
40c. *The Adventures of Sherlock Holmes* ("The Copper Beeches"). https://www.gutenberg.org/ebooks/1661
41. *The Case-Book of Sherlock Holmes* ("The Veiled Lodger", "The Blanched Soldier", "Thor Bridge"). https://www.gutenberg.org/ebooks/69700
64. Wikipedia, "Sherlockian game" (el Gran Juego, Ronald Knox). https://en.wikipedia.org/wiki/Sherlockian_game
— *A Study in Scarlet* (la "buhardilla" mental; "A fool takes in all the lumber..."). https://www.gutenberg.org/ebooks/244

Presentación y Godot
69. Lucas Pope, devlog de Obra Dinn en TIGSource (dithering estable). https://forums.tigsource.com/index.php?topic=40832.msg1363742#msg1363742
70. Alan Zucconi, "Shader Showcase Saturday #11: Return of the Obra Dinn". https://www.alanzucconi.com/?p=10365
71. Surma, "Ditherpunk". https://surma.dev/things/ditherpunk/
72. Godot Docs, "Advanced post-processing". https://docs.godotengine.org/en/stable/tutorials/shaders/advanced_postprocessing.html
73. Godot Docs, "Screen-reading shaders". https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html
74. Godot Docs, "The Compositor". https://docs.godotengine.org/en/stable/tutorials/rendering/compositor.html
