# FE DE ERRATAS: GDD definitivo

> **Fuente de verdad:** `design.md`. **Base:** `docs/research/` (canon_timeline, canon_characters, london_period, game_design_refs) y los conceptos A, B y C de `docs/concepts/`.
> **Origen del diseño:** se parte del concepto C («experiencia primero», Edmund Lisle), que ganó en historia y canon y en factibilidad técnica. Se le injerta la **garantía estructural de B** (fuentes inmutables, ley de la huella, invariante verificada, bots) y lo mejor de **A** (galerada intervenida, confrontación, gancho del día 1, rastro que lee el tigre). Se aplican todos los arreglos obligatorios de los tres jueces (trazabilidad en §0.3) y la revisión adversarial de cinco lentes (canon, grafo, jugador, *exploits*, técnica), registrada hallazgo por hallazgo en §17.
> **Idioma:** todo el texto del juego está en español neutro. Las citas de Doyle se traducen fielmente (dominio público) y el original inglés queda sólo en los datos (`src_en`) para el test de citas.

## 0. Cómo leer este documento

### 0.1 Marcas

- **[C]**: canon verificado (Gutenberg, en `research/` o cotejado en `.work/dl_canon/` y `.work/dl_verify/`).
- **[BG]**: cronología de Baring-Gould, adoptada donde el canon no da fecha (por ejemplo, jue. 5-abr-1894: EMPT sólo dice «that April evening»).
- **[H]**: dato histórico verificado en la investigación.
- **[INV]**: invención nuestra, ubicada en un hueco catalogado del canon (HUE-xx) sin contradecirlo.
- **⚠**: dato a verificar antes de redactar el texto que lo use. Ninguna ruta ni refutación obligatoria depende de un ⚠ (test T7).
- **I / P / C**: clase de fuente para el grafo (§10.1). **I** = inmutable; **P** = original en posesión, puede faltar como mucho un día; **C** = de campo, cortable por una reacción.
- IDs: **D##** documentos, **L#** lugares, **C#** conclusiones, **C#.R#** rutas, **HC##** reacciones fijas de columna, **HA#/HB#** reacciones de Holmes (voz A / voz B), **M#** reacciones de Moran, **K-xx** canales, **T##** tests.

### 0.2 Reglas de implementación que este documento fija

1. Todo lo que aquí tiene ID existe en datos (`data/*.json`) con el mismo ID.
2. Nada de lo que no figura aquí se inventa sin agregarlo antes a este documento.
3. Las tablas de §9 (reacciones) y §10 (grafo) son **normativas**: los tests las leen desde los datos y fallan si el contenido no las cumple.

### 0.3 Trazabilidad de los arreglos obligatorios

| Arreglo (juez) | Dónde se aplica |
|---|---|
| Preguntas/folios nunca generados por la verdad oculta; sin enunciados que presupongan hechos (J1) | §8.3: los folios **los crea el jugador** (o usa la página «Varios»); sólo hay plantillas genéricas, sin presuposiciones (§8.4) |
| Validación: lote, fundamento con ≥2 orígenes por etiquetas de afirmación, inmediata pero acotada (J1, J3) | §8.5: lote de 2 (de 1 el día 10), fundamento **por línea** con «según», chequeo formal visible y chequeo de contenido silencioso |
| Señal de suficiencia eliminada (J1, J3) | §8.6; los objetivos llegan como preguntas de personajes (§3.2); queda como decisión abierta (§16) |
| Invariante en todo estado alcanzable, ≥2 rutas intactas, ≥1 sólo-I, sin rutas que dependan de disparadores opcionales (J1) | §10.1, §10.3 (verificador acotado), tests T1–T5 |
| Efectos que quitan objetos del jugador nunca dejan sin ruta (J1) | M1 + HB10 (Ley 3), clase P, §10.1 |
| Ceguera verificable de Holmes y Moran (J1) | §9.2, test T8 sobre el registro de actos públicos |
| Guardado determinista sin espiar reacciones (J1) | §7.6: guardado **por compromiso** (registro de eventos); confirmación en §16 |
| Holmes ya sabe desde el día 1 con línea de base legible (J1) | HC01 (§9.6) |
| Itinerario de C y busto encargado antes del 30-mar (J1, J2) | §2.2 |
| Antispam: Ley 2 completa, cierre de canal probado dos veces, ≤1 reacción fuerte por día (J1, J3) | §9.4, §9.5, HB2, HB11, D2 |
| Acciones inmediatas con costo y límite duro (J1) | §8.7 (presentar en dos pasos), §8.8 (confrontación, 3 errores) |
| Mejor final exige la cadena del lector (J1) | §12: F1 exige C6, C7, C10, ≥8 conclusiones selladas y crédito ante Moran |
| Antiestancamiento motivado, nunca el documento clave (J1) | HB13 (sólo por inactividad observable) y test T16 |
| Pistas falsas con refutación desde ≥2 fuentes; nada apoyado en ⚠ (J1) | §10.5 |
| Easter eggs en Marginalia, sin contador, ≤1 por visita, sin rutas (J1) | §13, test T13 |
| Canon de personajes: Mycroft sin campo ni 221B; Mrs. Hudson ignora; Moran vivo; Holmes no se revela antes que a Watson; Watson nunca miente (J1, J2) | §4 y restricciones de §2.4 |
| Llegada de Holmes según EMPT (J2) | §2.2: llega el jueves 5 de madrugada, va a Baker Street en persona **por la mañana** (histeria de Mrs. Hudson); a las 14 h está en su sillón |
| Mrs. Hudson no prepara nada «para él» (J2) | El escribiente de Mycroft trae el *shag* y ordena airear (§4, HC05) |
| Mycroft no escribe a máquina (J2) | Dicta a su escribiente, Cotter [INV], que no sabe para quién trabaja |
| Watson: por qué no reclamó el pasaje cortado (J2) | Aceptó por escrito el pedido del Foreign Office; lo anotó en su tomo (§3.2) |
| Moran pregunta «dónde», no «si vive» (J2) | M6, M7; ningún documento público da el paradero de Holmes (T7) |
| Un solo coronel James Moriarty, real, en Bath (J2) | §4, D28 |
| Porlock | No se usa (evita depender de VALL sin verificar) |
| Corpus por fecha y CARD/RESI sin verificar (J2) | CARD/RESI sólo como easter egg, nunca como ruta |
| Una única fecha de muerte de Mary y un único canal por el que Holmes se entera (J2) | §2.3 y §3.2: sáb. 25-nov-1893; Holmes se entera **por Lisle** (Mycroft lo sabía y lo calló a propósito) |
| Coincidencias motivadas (J2) | §3.2: Moran elige a Lisle por su carta; Moran compró los tomos en la venta de Watson |
| Personas reales sin diálogo; firma de la *Strand* (J2) | §2.5 |
| Inconsistencias intencionales declaradas (J2) | §2.4, §2.6 |
| Corpus ≤ 25–30 mil palabras; duración honesta (J3) | §15.1: presupuesto de 25.600 palabras; unas 3¼ h |
| Informes a Moran en 3–4 fechas fijas (J3) | §7.3: mié. 28, sáb. 31, mar. 3 y jue. 5 |
| Lector 2D fuera del post-proceso; recorte por tramos; dioramas por JSON (J3) | §14.3–14.5 |
| Canales ≤5, uno nuevo por día; firma por emisor (J3) | §9.2 |
| Actor físicamente posible en cada reacción (J3) | Columna «actor» de §9.6, test T12 |
| Holmes «en persona» antes del final; confrontación jugable (J3) | HC06 (Mycroft transmite su voz) y HC07 |
| Render Forward+, defectos de máquina con `RichTextEffect`, audio WAV generado al cargar, tests con runner propio (J3) | §14, §15 |
| Dos libros consolidados, dinero como sabor, sin contador (J3) | §14.1, §7.5 |
| Rebanada vertical primero, precedida de *spikes* técnicos (J3) | §15.6 (H0–H7) |
| Revisión adversarial (canon, grafo, jugador, *exploits*, técnica) | §17, una línea por hallazgo |

---

## 1. Pitch y título

**Título:** *Fe de erratas*.

**Pitch.** Londres, lunes de Pascua de 1894. Hace cuatro meses la *Strand* publicó la muerte de Sherlock Holmes. Edmund Lisle, corrector de pruebas que se está quedando sin vista, leyó en noviembre la primera galerada de «El problema final» y sabe algo que nadie sabe: lo impreso no es lo que Watson escribió. Un procurador y un «mayor Harris», que dicen actuar por la familia Moriarty, le pagan una guinea diaria para que pruebe que la crónica es «una perversión de los hechos».

Lisle recorta, coteja y asienta erratas desde su buhardilla de Holywell Street. El primer día le devuelven por correo una carta que publicó en enero, con dos palabras a lápiz: «No lo es.». Desde entonces, **cada mañana el mundo contesta lo que hizo ayer**: una carta a máquina que sabe su número de asiento, una carta firmada «—S.» que corrige una frase que sólo le dijo a una persona, una casera que dice «sir» demasiadas veces. Las respuestas tienen dos letras y dos relojes. Una mano cercana obedece órdenes y siempre tarda una noche; otra, lejana, piensa, y cada día tarda menos. Hay además un tercer lector, que también lee esas respuestas.

**La experiencia en una frase:** *la mañana es la respuesta*.

**Tres pilares**
1. **El ritual de la mañana.** Correo y diario caen en la bandeja. Ahí llegan las reacciones, sin música ni aviso.
2. **Todo se puede recortar; nada brilla.** El juego nunca distingue lo importante de lo trivial. El jugador decide qué es pista y qué pregunta vale un folio. El juego explica la **forma** de una prueba, nunca su **contenido**.
3. **Holmes es un autor que corrige.** No ataca: enmienda, retira, desvía, calla. Su orgullo por la exactitud es su punto débil, y el tigre lo sabe.

**Giros**
1. (días 1–3) Alguien me lee y sabe cosas que nadie publicó.
2. (días 5–7) Hay dos lectores: uno corrige y protege, el otro roba y rompe. Mi patrón es el asesino de Park Lane y yo soy el cabrito atado al árbol: cada respuesta que provoco es el rastro que el tigre sigue.
3. (día 10 y epílogo) Lisle es «a tall, thin man with coloured glasses» de «La casa vacía» [C], y los cinco tomos que tuvo en las manos diez días son «that gap on that second shelf» [C] del estudio de Watson.

---

## 2. Marco temporal y canon

### 2.1 Calendario jugable (días de la semana verificados)

Franjas: **M** mañana (9–13), **T** tarde (13–18), **N** noche (18–22). El escritorio no gasta franja; quedarse en casa sí la gasta.

| Día | Fecha (1894) | Columna: ocurre aunque el jugador no haga nada | Holmes, en verdad | Franjas |
|---|---|---|---|---|
| P | lun. 26 mar. (Lunes de Pascua) | Noche: Pell y «Harris» contratan a Lisle, le dejan los cinco tomos y le hacen redactar un aviso de testigos para el *Times*; afuera esperan Parker y, enfrente, Cotter | Montpellier | prólogo (tutorial) |
| 1 | mar. 27 | Correo: vuelve la carta de enero con «No lo es.» (HC01). El *Times* trae el aviso de testigos de Lisle | Montpellier | M T N |
| 2 | mié. 28 | Primera carta a máquina, voz A (HA1 o, si no hubo papeleta, HA0). Noche: **informe 1** | Montpellier | M T N |
| 3 | jue. 29 | Desde hoy Wiggins sigue a Lisle (HC02) | Montpellier | M T N |
| 4 | vie. 30 | Columna: «—S.» contesta el aviso de testigos (HC10). Grand National (ruido) [H]. 22:00–23:20: asesinato de Adair [C] | Montpellier | M T N |
| 5 | sáb. 31 | *Times*: «El misterio de Park Lane». Al amanecer, Pell paga: «El mayor no pregunta si vive. Pregunta dónde.» (M6). Mycroft escribe a Montpellier, como cada noche. Noche: **informe 2** | Montpellier | M T N |
| 6 | dom. 1 abr. | Sin correo ni *Times*; Sala de Lectura, Somerset House y tiendas cerradas; visitas de 16 a 18 h [H]. Si hubo actos el sábado, voz A llega **en mano** | Montpellier | T |
| 7 | lun. 2 | Se abre la indagatoria; se oyen los testimonios y se aplaza [INV la fecha]. «Harris» recibe la llave de Camden House del agente (D32). Desde la tarde se puede ver Camden House (L8). 22 h: visita de «Harris» (M7) | Lee el *Times* del sábado: Park Lane. Parte en el acto; noche en Grenoble | M T N |
| 8 | mar. 3 | *Times* y *Daily Graphic*: testimonios de la indagatoria y compañeros de whist (Murray, Sir John Hardy, coronel Moran) [C]. Tarjeta de Mycroft (HC04). 221B: airean los cuartos (HC05). Voz B: lo observado los días 4 y 5, si hubo algo, se contesta junto. Noche: **informe 3** | Grenoble (aprueba el busto) → París | M T N |
| 9 | mié. 4 | Concluye la indagatoria: «willful murder against some person or persons unknown» [C]. Ultimátum de Pell (M8). Por la tarde llega a 221B el cajón de Grenoble «para Mr. Mycroft Holmes». Arresto del anarquista Théodule Meunier en Victoria [H]. Sin voz B | París; correo de la noche | M T N (dos pasadas en limpio de noche) |
| 10 | jue. 5 [BG] | Mañana: Watson lee el veredicto en el *Times*; voz B en tanda (lo observado los días 6 a 8). 9:30: el librero viejo en la tienda de Crane (HC07). Hacia las 11: Holmes llega en persona a 221B, Mrs. Hudson tiene un ataque de histeria y los vigías de Moran lo ven llegar [C] (fuera de escena). 12 h: **informe final**. 14 h: Holmes en su sillón [C]. 18 h: Park Lane, Watson choca con el librero [C]. 21:30: Holmes y Watson salen en coche; hacia las 22 h, Camden House; cerca de medianoche, «a strange, loud whiz and a long, silvery tinkle of broken glass» [C] | Londres | M (escena fija e informe) T (Park Lane) N (dónde pasar la noche) |
| E | oct. 1903 | La *Strand* publica «La casa vacía» [C] | — | epílogo |

**Luz y clima [H, C]:** segunda quincena de marzo luminosa y templada; sin niebla espesa. Puesta de sol ~18:28 el 30-mar y ~18:38 el 5-abr. Noche sin luna el 30-mar; luna nueva el 6-abr: las noches del 4 y 5 sólo tienen gas. El 5 a las 18 h, luz rasante dorada en Park Lane: la única escena cálida del juego. La noche del 5 es fría y ventosa: «It was a bleak and boisterous night and the wind whistled shrilly down the long street» [C]; los transeúntes van abrigados.

### 2.2 Itinerario oculto de Holmes (respeta EMPT)

| Fecha | Dónde | Qué hace | Base |
|---|---|---|---|
| ene. 1894 | Montpellier | Mycroft le reexpide el recorte de la carta de Lisle (*St James's Gazette*, jue. 18-ene). Holmes escribe al margen «No lo es.» y se lo devuelve a su hermano con una orden: «Si la otra parte se acerca al corrector, devuélvasela.» | [INV, HUE-09] |
| feb.–mar. | Montpellier | Mycroft le avisa que un hombrecito con arpa de boca (Parker) vigila Baker Street. Holmes decide volver y prepara el señuelo | [C] Parker; [INV] el aviso |
| mar. 20-mar | Grenoble (ida y vuelta) | Encarga el busto de cera a Oscar Meunier, que «spent some days in doing the moulding» [C] | [INV] la fecha |
| hasta dom. 1 abr. | Montpellier | Lee las cartas que Mycroft le escribe cada noche (dos días de correo; en Francia no se reparte el domingo [INV]). Contesta por telegrama al Diógenes | [INV] |
| lun. 2, mañana | Montpellier | Llegan juntos el *Times* del sábado (Park Lane) y la carta de Mycroft del sábado: «my movements were hastened by the news of this very remarkable Park Lane Mystery» [C]. Telegrafía su última tanda de respuestas y parte en el acto | [C] la noticia; [INV] el día |
| lun. 2, noche – mar. 3 | Grenoble | Aprueba el busto; Meunier lo despacha en gran velocidad a «Mr. Mycroft Holmes, 221B Baker Street. No abrir.» (llega el mié. 4 por la tarde). Telegrama al Diógenes. Tren de día a París | [INV] |
| mié. 4 | París | Recoge en lista de correos las cartas de Mycroft del lunes y del martes y contesta en tanda por telegrama (3.10 p. m.). No se queda: espera el correo de la noche | [INV] |
| jue. 5, madrugada | Londres | Llega por el correo continental | «I came over at once to London» [C] |
| jue. 5, 9:30 | Holywell Street | Disfrazado de librero viejo, compra en la tienda de Crane los libros de su disfraz (HC07) | [INV] |
| jue. 5, hacia las 11 | 221B | «called in my own person at Baker Street, threw Mrs. Hudson into violent hysterics» [C]; los vigías de Moran: «this morning they saw me arrive» [C] | [C]; [INV] la hora exacta |
| jue. 5, 14 h | 221B | «at two o'clock to-day I found myself in my old armchair» [C] | [C] |
| jue. 5, 18 h | Park Lane | Disfrazado, choca con Watson | [C] |
| jue. 5, noche | Camden House | Entra por la puerta trasera con una llave que Mycroft obtuvo del administrador del propietario (no del agente de Baker Street, D32) [INV]. Esperaba a Moran en la calle: «never dreaming that he would choose the same spot for his attack» [C] | [C]; [INV] la llave |

Se respeta «I came over at once»: entre la noticia (lunes por la mañana) y Londres (jueves de madrugada) Holmes no hace ninguna espera voluntaria. El paso por Grenoble es un rodeo de medio día desde Lyon y París es sólo el enlace con el correo de la noche. La compra en Holywell Street la hace disfrazado; la primera visita **en persona** a Baker Street es la de la mañana, y las 14 h son la hora del sillón. El busto se encargó antes de Adair: la noticia sólo **apresuró** un regreso ya decidido. La fecha del jueves 5 es de Baring-Gould [BG]; el canon dice «that April evening».

### 2.3 Biblia de hechos ocultos (valor único en todos los documentos)

| Fecha | Hecho | Marca |
|---|---|---|
| lun. 4-may-1891 | Reichenbach según EMPT. Holmes ve una cornisa alta, apenas insinuada desde el sendero; trepa con riesgo hasta ella («a ledge several feet deep and covered with soft green moss, where I could lie unseen» [C]) y desde allí no se lo ve. La idea de pasar por muerto se le ocurre **en el momento**: «The instant that the Professor had disappeared, it struck me…» [C]. Su carta de despedida era sincera: «My note to you was absolutely genuine» [C]. Cuando la partida de búsqueda se va, Moran le arroja piedras «against the darkening sky» [C] y **lo ve vivo**. Bajar fue «a hundred times more difficult» [C] | [C] |
| mié. 6-may-1891 | *Journal de Genève*: nota breve («extremely condensed» [C]). Los guías no hallaron ningún cuerpo; el bastón seguía apoyado en la roca; más arriba hay una cornisa que no se ve desde el sendero y a la que sólo subió alguna vez un cazador de nidos temerario; en la pared, una marca reciente. Un pastor oyó caer piedras al anochecer. No se atribuye nada a Watson | [INV] el texto; [C] su existencia y su brevedad |
| jue. 7-may-1891 | Reuter en la prensa inglesa: resumen que omite cornisa y marca | [INV] el texto; [C] su existencia |
| 1892–93 | Despachos de «S. Sigerson» desde el Tíbet en el *Times*, «comunicados por el Foreign Office». Uno envía «la muestra que faltaba al n.º 97 de cierta clasificación inglesa de cenizas». En 1893, una nota comunicada sitúa a Sigerson «en Jartum, huésped del Califa»: es un error (el Califa reside en Omdurmán) y es el origen del «Khartoum» que Holmes dirá a Watson | [INV, HUE-03, HUE-04] |
| lun. 9 y lun. 23-oct-1893 | Cartas del coronel James Moriarty en la *Pall Mall Gazette*. Las firma él, desde Bath; un «amigo del Anglo-Indian», que es Moran, se las «pule». Es la primera sonda de Moran: obliga a Watson a contar lo que sabe | [INV, HUE-01] |
| oct.–nov. 1893 | Watson escribe FINA junto a Mary, que está enferma. El texto se envía en octubre para la sindicación americana | [INV, HUE-06] |
| jue. 2-nov-1893 | Primera galerada de FINA. La corrige Lisle, lector a destajo de la imprenta de la revista, y se guarda una prueba, contra la norma, para su concordancia. La misma imprenta tira pruebas de la composición para la sindicación americana | [INV] |
| jue. 9 – mar. 14-nov-1893 | Pedido del Foreign Office (firma «M. H.», por cuestiones de Estado: FINA menciona trabajos para «the French republic» [C]). Watson ya lo había aceptado por carta al publicarse NAVA. Se suprime una sola cláusula: la raspadura de la roca «como la que dejaría el clavo de una bota». El corte alcanza a tiempo las dos composiciones: la inglesa y la americana; las pruebas americanas se cancelan antes de su envío (los textos estadounidenses publicados el 26-nov y en *McClure's* de diciembre ya salen sin la cláusula) | [INV] |
| sáb. 25-nov-1893 | Muere Mary Watson en Paddington. Registro: 4.º trimestre de 1893, distrito de Paddington. No hubo aviso en el *Times*. Mycroft lo sabe (se cartea con Watson por el corte) y **se lo calla a su hermano a propósito**: «Mi hermano no necesitaba más motivos para volver antes de tiempo» | [INV, HUE-06] |
| dic. 1893 | Sale FINA impresa: «three-foot path, with sheer wall on one side and sheer drop on the other» [C] | [C] |
| mié. 17-ene-1894 | Subasta del menaje de la casa de Paddington (Watson se muda a Kensington). Entre los libros, los vols. II–VI de la *Strand* con notas suyas y de Mary. Los compra un agente de Moran | [INV, HUE-07] |
| jue. 18-ene-1894 | Carta de «E. L., Holywell Street» al *St James's Gazette*, «La aritmética del doctor Watson»: erratas inocentes, y una indiscreción: «en primeras pruebas el doctor fue más honesto con la roca que en la revista» | [INV] |
| sáb. 3-feb-1894 | *The Lancet*, noticias médicas: el Dr. J. H. Watson, «tras su reciente duelo», traslada su consulta de Paddington a Kensington | [INV] |
| sáb. 10-feb-1894 | Carta firmada «S. S.» en el *Times* (Correspondencia), **sin ciudad**: corrige a un químico sobre un derivado del alquitrán que **mancha la piel de amarillo durante semanas** («lo sé por mis propias manos») y agrega que daría para una lámina más de «cierto opúsculo sobre la influencia de los oficios en la forma de la mano» | [INV, HUE-05] |
| mar. 20-mar-1894 | Holmes encarga el busto en Grenoble | [INV] |
| lun. 26-mar-1894 | Moran contrata a Lisle. No quiere saber si Holmes vive (lo vio en la cornisa): quiere que quien guarda el secreto **se mueva**. Lo eligió por la carta de enero, porque Lisle sabe que hubo una mano que cortó | [INV] |
| vie. 30-mar-1894 | Moran mata a Adair con el fusil de aire de Von Herder, desde la calle, por la ventana abierta del segundo piso [C]. El móvil queda abierto («yours is as likely to be correct as mine» [C]) | [C] |
| lun. 2-abr-1894 | Moran, como «mayor Harris», pide la llave de Camden House al agente de fincas «para ver la casa», engrasa la guillotina y deja ceniza y polvo removido. Nadie del bando de Holmes lo sabe | [INV]; compatible con EMPT |
| jue. 5-abr-1894 | Regreso de Holmes y captura de Moran [C]. Lestrade se lleva el crédito [C] | [C] el hecho; [BG] la fecha |

**Cómo se enteró Holmes del duelo de Watson** («In some manner he had learned of my own sad bereavement» [C]): por un solo canal, **Lisle**. Mycroft lo sabía y lo calló (ver arriba); no hubo aviso en el *Times*; la noticia de *The Lancet* no llega a Montpellier; Mycroft no reexpide nada que toque a Mary. Holmes lo sabe el jueves 5 a las 9:30, cuando hojea en la tienda de Crane los tomos con las notas de Mary. Si antes el jugador le habló a Watson de Mary, la reacción es sólo de Mycroft (voz A, HB4) y no llega a Holmes.

### 2.4 Restricciones duras (asserts en datos y tests)

- **Secreto de Holmes.** Nadie salvo Mycroft sabe, por boca de Holmes o de Mycroft, que Holmes vive («I had only one confidant—my brother Mycroft» [C]). Cotter copia y despacha lo que Mycroft le dicta sin saber de quién es; Wiggins cobra «la vieja tarifa» sin oír nada de Francia; las respuestas de «—S.» que se publican no afirman nada sobre la supervivencia de nadie: corrigen datos verificables, en clave de corrector, de modo que un tercero no pueda leerlas como «Holmes vive» (test T23). Moran lo sabe por sí mismo (lo vio en la cornisa).
- **Watson no puede sospechar antes del 5.** Watson lee la prensa a diario: nada publicado antes del 5 contesta lo que Lisle le dijo a él (lo que entra por K-W se contesta sólo en privado) y ninguna frase pública reproduce «not literally true» (T23). El 5 se desmaya «for the first and the last time in my life» [C].
- **Camden House es un secreto de Moran.** Nadie del bando de Holmes (Holmes, Mycroft, Cotter, Wiggins, Mrs. Hudson) recibe por ningún canal, presentación o confrontación un dato sobre la preparación de Camden House. Los sensores filtran esas etiquetas (`secreto_camden`, §9.2), las formas de anuncio no las admiten y Mycroft no lee lo que no contesta a su pregunta (test T22). Holmes consiguió su llave por otra vía (§2.2): «I did not anticipate that you would yourself make use of this empty house» [C].
- Mrs. Hudson no sabe ni sospecha que Holmes vive hasta la mañana del jueves 5. Obedece al «empleado del señor Mycroft» sin saber para qué; no enseña el índice ni los cuartos a desconocidos; no habla de otras casas.
- Mycroft no pisa 221B (su única visita es la de GREE [C]), no hace trabajo de campo y no escribe a máquina: dicta a Cotter. El público no sabe de su poder (BRUC es de 1908).
- Watson no sabe que Holmes vive. Si alguien se lo dice, no lo cree (HB4). Nunca miente en sus crónicas: sus errores son honestos y su única omisión fue aceptar un pedido de Estado.
- Moran sabe desde 1891 que Holmes sobrevivió. Sigue vivo después del juego (ILLU 1902 [C]); el veredicto de su juicio no se especifica.
- Holmes no se revela de palabra a nadie antes que a Watson. En la confrontación (HC07, sin Watson) sólo se endereza un instante y se va. Ante Watson (HC08) no se endereza: «I saw his curved back and white side-whiskers disappear among the throng» [C].
- Holmes no busca crédito, no tiene romance y no deja escapar a un enemigo. **En este asunto no destruye documentos**: necesita que el rastro siga legible para el lector y para el tigre (el canon posterior muestra que puede quemar papeles cuando le conviene, CHAS [C]).
- Ningún documento público del juego da el paradero de Holmes en 1894 (T7). Sigerson firma sin ciudad.
- Nadie relaciona a Moran con Adair antes del mar. 3 (indagatoria). Antes aparece sólo como autor (BM, Crane) y en el Kelly's. Los clubes de Moran (Anglo-Indian) no salen en la prensa: sólo en la carta del coronel (D28).
- No aparecen Shinwell Johnson, Mercer, Hopkins ni Langdale Pike.
- Ningún texto de *Return*, HOUN o VALL existe como publicado. EMPT sólo en el epílogo.
- Anacronismos prohibidos: lista de london_period §7 (Daily Mail, Marylebone, etc.), aplicada por un lint. El Foreign Office no tiene oficina de prensa (se crea en 1914): sus notas se «comunican» a los diarios.

### 2.5 Corpus y mundo editorial

| Categoría | Contenido |
|---|---|
| Canon publicado [C] | STUD (Beeton's Christmas Annual, 1887; libro de Ward Lock) y SIGN (*Lippincott's*, feb. 1890; libro, 1890): **no** salieron en la *Strand* y son documentos propios (D43, D44). Las 24 historias de la *Strand* (jul. 1891 – dic. 1893), que caben en **cinco tomos semestrales, vols. II–VI**. *Adventures* (libro, 14-oct-1892). *Memoirs* Newnes (13-dic-1893, sin CARD). *Memoirs* Harper (feb. 1894, con CARD; sólo Marginalia) |
| Artefacto inédito [INV] | Pruebas de la composición para la sindicación americana de FINA (octubre de 1893), **canceladas** antes de su envío tras el pedido del F.O.: conservan la cláusula de la raspadura. Un juego terminó como papel de desecho en la tienda de Crane (D04). Ninguna edición real se altera |
| Firma dentro del mundo | La *Strand* encabeza «De las memorias de John H. Watson, M.D.» (convención del Gran Juego). Doyle, Newnes y Greenhough Smith no aparecen ni hablan; los empleados editoriales son inventados |
| Prensa real de fondo [H] | Gladstone y Rosebery, la Reina en Florencia, el pánico anarquista (Greenwich, Meunier), Grand National, final de la FA Cup, Martin Hewitt en la *Strand* de marzo, Barrie «The Late Sherlock Holmes» (29-dic-1893) |
| No existe todavía | *Return*, HOUN, VALL, *Daily Mail*, estación de Marylebone, oficina de prensa del Foreign Office |

### 2.6 Inconsistencias canónicas usadas a propósito

| Inconsistencia | Resolución en el mundo | Uso mecánico |
|---|---|---|
| INC-01, 02, 03, 06, 07, 08, 09, 10 (herida, «James», Mrs. Turner, matrimonio de 1888, madre de Mary, «una mujer», julio/septiembre, fechas de REDH) | Errores honestos de Watson, sin patrón | Tutorial C1 (§10.4). Holmes no reacciona (Ley 7) |
| FINA «sheer wall» frente a EMPT «That was not literally true» [C] | Watson escribió la raspadura; el F.O. la quitó | C2 y C3; HC01 («No lo es.»). La frase inglesa no se reproduce en público antes del 5 |
| «some months later» (EMPT) [C] | Lectura de Lisle en el epílogo: Holmes leyó la galerada que Mycroft le envió en noviembre. No resuelve la cifra de meses; es una conjetura del personaje | Epílogo |
| Dos James Moriarty (INC-14) | El coronel existe en Bath. El nombre del profesor sólo se conoce en 1894 por el tratado del Binomio en el BM | Easter egg 9 |
| «Khartoum» por Omdurmán (INC-28, HUE-04) | Error de la nota comunicada de 1893 sobre Sigerson (D13), que Holmes repite luego a Watson | Pista falsa fija, con refutación (§10.5) |
| WIST «fines de marzo de 1892» (INC-12) | Caso real anterior que Watson pasó en limpio en marzo de 1892 y fechó, por error honesto, al copiarlo | Easter egg 4 |
| El hombre de anteojos de color de Park Lane (cabo suelto de EMPT) | Es Lisle | Giro 3 |
| «that gap on that second shelf» (EMPT) [C] | Hueco de los vols. II–VI vendidos en enero | C14 y epílogo |
| «In some manner he had learned of my own sad bereavement» (EMPT) [C] | Lo supo por Lisle | §2.3 |
| CARD fuera de *Memoirs* Newnes; pasaje de CARD en RESI ⚠ | Sin verificar en primera edición | Sólo Marginalia; nunca ruta |

---

## 3. Protagonista e historia completa

### 3.1 Edmund Lisle [INV]

Treinta y dos años, alto y delgado. Fue corrector («lector») a destajo para la imprenta de la *Strand* hasta diciembre de 1893. Ahora es indexador por encargo y está perdiendo la vista. Usa **anteojos de color azul** por la fotofobia que le dejaron diez años de pruebas bajo el gas. Lee del revés y en espejo, como todo el que corrigió planchas. Desde 1891 lleva una concordancia privada de las crónicas (D21): es el primer holmesiano, diecisiete años antes de Knox. Vive en una buhardilla de Holywell Street [H], sobre la librería de viejo de Abel Crane.

**Cómo lo conoce el jugador sin verse.** El juego es en primera persona, así que su figura se establece en el mundo: su reflejo alto y delgado en el vidrio de la ventana en la lámina del prólogo; Pell, que comenta los anteojos («Con esos vidrios azules, señor Lisle, no sé cómo distingue usted una errata»); y Mycroft, que lo deduce en voz alta (HC06 (a)).

**Por qué lo eligen las dos partes.** Su carta de enero (D22) deja ver que leyó una prueba anterior a la impresión. Moran entiende que hubo una mano que cortó, y que quien corta es quien guarda el secreto. Mycroft entiende lo mismo, al revés: Lisle es una fuga.

**Por qué investiga.** Por la guinea diaria (no tiene otro trabajo), por orgullo de oficio (alguien tocó un texto que él corrigió) y, desde el día 1, por curiosidad: alguien le contestó.

**Arco.** De «el texto es todo» a «las erratas son el lugar donde vive la gente». Empieza cazando errores de Watson y termina protegiendo lo que Watson no imprimió.

**Voz (notas del diario y del cuaderno):** precisa, seca, con jerga de corrector («dele», «sic», «errata», «galerada»). Ejemplo: «Mar. 27. Nadie corrige con lápiz blando una carta ajena si no está seguro. *No lo es.* Dos palabras, sin firma, matasellos S.W.».

### 3.2 La historia completa en actos

**Prólogo, «El encargo» (lun. 26, noche; tutorial, unos 15 min).** Josiah Pell sube a la buhardilla con el «mayor Harris», un caballero de bigote canoso enorme, «amigo de la familia del coronel». Encargan una *fe de erratas* de las crónicas por una guinea diaria, con informes las noches del miércoles, el sábado y el martes, y uno final el jueves 5 a mediodía. El contrato exige «no menos de seis asientos pasados en limpio para el jueves» (así el mundo dice cuánto se espera). Pagan por adelantado en billetes de £5 numerados [H]. Dejan los cinco tomos de la *Strand* «adquiridos en una venta, con anotaciones que el mayor desea que usted lea» y el recorte de las cartas del coronel. Harris habla poco y en metáforas de caza («Cacé en la India, señor. Allí se aprende a esperar arriba, donde se domina el claro.»; «Hay que mover el monte»). Pell formula las preguntas del encargo, abiertas y sin presuponer nada: dónde se aparta el doctor de los hechos, qué ocurrió de verdad en Suiza, qué dejó el difunto. Harris exige un aviso en el *Times*: Lisle lo **redacta con el compositor de anuncios** (forma «Se busca testigo de ___», llenada desde el índice) y Pell se lo lleva para el diario del martes.

El tutorial enseña, con instructores dentro del mundo y un verbo por paso: recortar (una línea del encargo), vincular dos recortes (el par INC-10 que la concordancia de Lisle, D21, marca como duda propia), abrir un folio, escribir un asiento con su «según» en cada línea y pasarlo en limpio en un **lote guiado de 1** (C1, que no cuenta para los finales). La primera página del libro mayor, «Reglas del asiento», explica en la voz del oficio la **forma** de una prueba y nunca su contenido (§8.0). La galerada de noviembre queda en el cajón, sin guion: encontrarla y cotejarla es del jugador. La escena queda congelada como **lámina del prólogo**: en el vidrio, el reflejo de Lisle; en la calle, un hombrecito que espera junto a la puerta y, enfrente, un hombre con un fajo de papel bajo el brazo.

**Acto I, «La caza de erratas» (días 1–4).** Gancho del día 1: vuelve la carta de enero con «No lo es.» a lápiz junto a «a pique» (HC01). Lisle coteja ediciones, va a la Sala de Lectura (el ujier le explica papeletas y asiento), pide el *Journal de Genève*, visita a Watson como paciente (sus ojos), telegrafía a Meiringen, escribe al coronel a Bath. El día 2 llega la primera carta a máquina, firmada «Un amigo de la exactitud», que sabe su número de asiento; esa noche el chico de Pell le explica cómo se entrega un informe. Desde el día 3 hay un muchacho alto con gorra al fondo de cada lugar. El viernes la columna contesta su aviso de testigos, firmada «—S.»; y si el martes le habló a Watson de la roca, una carta a máquina firmada igual corrige una frase que Lisle sólo le dijo a él: tres días después. El viernes 30, Adair muere. *Giro 1: alguien me lee, y sabe cosas que nadie publicó.*

**Acto II, «El otro lector» (días 5–7).** El sábado los diarios publican «El misterio de Park Lane». Al amanecer, Pell paga y transmite una pregunta que no corresponde a un pleito por difamación: «El mayor no pregunta si vive. Pregunta dónde.» El domingo no hay correo; si Lisle hizo algo el sábado, la carta a máquina llega **en mano**: la mano está en Londres. Lisle visita a Watson en su casa (el respiro emocional del juego) y ve el hueco del segundo estante. Si su informe dijo demasiado, aparecen las huellas de la otra mano: un registro que se lleva originales, ceniza de cheroot indio, un ladrillo que cae de un alero como en Vere Street (FINA [C]). El lunes se abre la indagatoria y, a las 22 h, «Harris» sube en persona: «Un trabajo inteligente, inteligente. No me diga que vive. Dígame dónde duerme el tigre.» Fuma, pregunta si le molesta el humo («Es de Trichinópolis») y deja ceniza en el escritorio. *Giro 2: hay dos lectores. Uno corrige y devuelve; el otro roba y rompe. Mi patrón es un cazador y yo soy el cabrito atado. Cada respuesta que provoco es un rastro que él también lee.*

**Acto III, «La casa vacía» (días 8–10).** El martes los diarios dibujan a los testigos de la indagatoria. El «coronel Moran» del *Daily Graphic* tiene el bigote de Harris. Llega la tarjeta de Mycroft: «Sala de Forasteros, 16:45 a 19:40, martes y miércoles». En el Diógenes, Mycroft deduce la vida de Lisle en diez segundos, cita sus actos, transmite una frase de su hermano y, al final, lo desafía: «¿Y quién cree usted que le contesta, señor Lisle? Muéstremelo; en limpio, si es tan amable.» Si Lisle se lo muestra, le propone convertir el último informe en **una errata a medida** para el tigre. En Baker Street, el empleado de Mycroft hace airear unos cuartos que nadie usa; el miércoles llega un cajón de Grenoble. Enfrente, en la casa vacía que el chico del agente enseña desde el lunes, hay polvo removido junto a una ventana y una guillotina que se abre sin ruido. El miércoles Pell trae el ultimátum: el lugar, antes del jueves a mediodía.

- **Jueves, 9:30.** Crane llama a Lisle: un librero viejo y encorvado compra *British Birds*, *Catullus*, *The Holy War* y *The Origin of Tree Worship* [C], pide precio de gremio y escribe de su puño la dirección de su «tiendita de la esquina de Church Street». Pregunta por «los tomos de la *Strand*», los hojea, ve las notas de Mary y los devuelve: «Éstos tienen dueño, señor.» Empieza la **confrontación** (HC07): cuatro afirmaciones del librero, cada una refutable con un recorte o asiento del grupo indicado, con tres errores como máximo.
- **Hacia las 11 (fuera de escena).** Holmes llega en persona a Baker Street; Mrs. Hudson, histeria [C]; Parker lo ve.
- **12 h.** Informe final: la verdad, el silencio o la errata a medida.
- **18 h, Park Lane.** Lisle, con sus anteojos azules, expone su teoría y los curiosos se juntan a escucharlo; un médico de luto se acerca, la juzga absurda y se aleja disgustado [C]. Detrás choca con un librero viejo y caen los libros: es lo único que se mueve en todo el juego. El librero gruñe y se va encorvado.
- **Noche fría y ventosa.** Si Lisle está en Baker Street: los cuartos de hora, el arpa de boca que se calla, un silbido y «a long, silvery tinkle of broken glass» [C].

**Epílogo (octubre de 1903).** Lisle, casi ciego, compra la *Strand* y lee «La casa vacía». Encuentra su propia silueta en el texto: «A tall, thin man with coloured glasses, whom I strongly suspected of being a plain-clothes detective» [C], y «With five volumes you could just fill that gap on that second shelf» [C]. Lee «some months later» y anota su conjetura: Holmes leyó la galerada. Su último gesto es recortarse. Después de los créditos, el libro mayor completo aparece corregido con lápiz azul (§12.3).

### 3.3 Por qué Holmes reacciona como reacciona

Prioridades, en orden:
1. Atrapar al último enemigo en Londres sin que nadie sepa antes que vive («if all the world was convinced that I was dead they would take liberties» [C]).
2. Proteger a Watson.
3. Proteger a Mycroft y al Estado.
4. Proteger al lector que Moran puso de cebo, y usarlo.

Las filtra su carácter: vanidad de artista y orgullo por la exactitud (corrige), desprecio por el romanticismo, caballerosidad con el rival digno, impaciencia. Por eso obstruye lo que roza a Watson y al Estado, **no estorba** la investigación sobre el coronel y Moran (quiere que el lector llegue ahí) y responde en público a sabiendas de que el tigre también lee la columna: mientras el tigre mire la columna, mira donde Holmes quiere. Así sus anuncios son a la vez correcciones y cebo.

**Las dos manos no quieren lo mismo.** Mycroft ejecuta órdenes de prudencia: desvía al lector de las fuentes que hablan de la cornisa (HA1). Sherlock no resiste corregir y señala fuentes («véase el *Journal*»). El jugador ve el desacuerdo entre las dos voces y aprende a leerlo.

**Qué puede publicar «—S.».** Sólo correcciones verificables en clave de corrector, que remiten a una fuente, sin afirmar nada sobre quién vive. Frente al público, una corrección pedante firmada con una inicial no significa nada. Frente a Moran, que ya sabe que Holmes vive, no revela el paradero. Lo que Lisle dijo en privado se contesta en privado (Ley 5), porque Watson lee la prensa.

### 3.4 Temas y por qué es memorable

- **Autoría y verdad.** Watson edita sus casos, Mycroft edita a Watson, Holmes edita el mundo, Moran falsifica a un coronel y Lisle corrige a todos.
- **El precio del secreto.** El silencio de Holmes dejó a su amigo tres años de luto y además lo protegió. Mycroft también calla: no le dijo a su hermano que Mary había muerto. El juego no absuelve ni condena.
- **Leer como acto moral.** Lo único que Lisle publica (sus informes) lo lee un asesino.
- **Las erratas como humanidad.** Detrás de «James» hay una mujer que llamaba así a su marido.

Es memorable por tres revelaciones que reordenan lo jugado, porque el clímax es el verbo del juego (recortar), porque termina sobre frases reales de Doyle que cambian de sentido («sheer», «some months later», «in some manner», «that gap on that second shelf», «a tall, thin man with coloured glasses») y porque el jugador sabe lo que Watson no sabe mientras a Watson se le caen los libros.

---

## 4. Elenco

Nueve personajes con diálogo, más el protagonista. Cameos sin diálogo: Parker (arpa de boca) y Lestrade (la noche final). Sólo por escrito: el coronel James Moriarty y Steiler el joven. En cada visita, Lisle puede hacerle **hasta tres preguntas** a cada personaje (Crane, sin límite); la frase exacta se muestra antes de decirla (§8.7).

| Personaje | Base | Personalidad y voz (ejemplo de línea) | *Tells* (pistas de conducta) | Secreto | Restricciones | Rol mecánico |
|---|---|---|---|---|---|---|
| **Sherlock Holmes** | [C] FINA, EMPT; críticas a Watson (SIGN, COPP); «That was not literally true»; vanidad (GREE); caballerosidad (DYIN) | **Voz B (escrita):** precisa, irónica, en clave de corrector («dele», «véase»), con alguna cita e imágenes químicas. «Las coincidencias son el refugio del lector perezoso.» **Librero:** voz cascada y servil que se le cae al precisar: «Una ganga, señor, cada uno de ellos.» | No deja pasar una inexactitud sobre sí mismo; tamborilea con los dedos por impaciencia (EMPT [C]); dedos manchados de amarillo (alquitrán de Montpellier); sombra demasiado alta bajo el gas; «Hum!» | Vive. Decidió pasar por muerto en la cornisa, en el momento. Inventó a Sigerson. Leyó la galerada en noviembre. No supo de Mary hasta el jueves | No se revela de palabra; en este asunto no destruye; no busca crédito | Reactor principal (voz B). En persona sólo el día 10 |
| **Mycroft Holmes** | [C] GREE: corpulento, mejor observador que su hermano, Diógenes de 16:45 a 19:40, camina cada día de Pall Mall a Whitehall y vuelve, rapé, pañuelo de seda roja; afable («said he blandly, smiling» [C]); único confidente (EMPT) | Afable, suave, irónico; ahorra esfuerzo físico, no palabras. «Le ahorraré el trabajo, señor Lisle: tiene usted treinta y dos años, mala vista, anteojos de color por la fotofobia y una deuda con su librero.» | Habla de su hermano en presente una vez, a propósito, para probar al lector. Anuncia una ruptura de su rutina: «El jueves no estaré en el club.» Repite el giro de la voz A («Le ahorraré el trabajo») | Paga 221B, guarda los papeles, pidió el corte del F.O. Sabe que Mary murió y se lo calló a su hermano: «Mi hermano no necesitaba más motivos para volver antes de tiempo» | Nunca en 221B; sin trabajo de campo; no teclea | Mano en Londres (**voz A**, por Cotter). Entrevista los días 8–9 (HC06) |
| **Cotter** [INV], escribiente de Mycroft | Empleado de una oficina de auditoría | Monosílabos: «Por encargo.» | Papel del Diógenes con el membrete recortado; tira las tiras al cesto; teclea en una Remington con la «s» alzada y la «t» pálida | **No sabe para quién trabaja** más allá de Mycroft: copia lo que le dictan, pone avisos sin saber de quién son y echa al correo sobres cerrados | No decide nada; ejecuta órdenes permanentes | Sensor de la Sala de Lectura (lee las papeletas en la canastilla del mostrador [H]); mecanógrafo de las voces A y B privadas; paga a Wiggins; lleva el *shag* a 221B |
| **Dr. John H. Watson** | [C] EMPT: viudo, consultorio en Kensington; «Good heavens!»; honesto con sus errores; lee con cuidado los crímenes de la prensa | Cálido, leal, herido; se cierra si lo presionan. «Un hombre puede ser herido más de una vez, señor Lisle.» | Se toca el hombro y luego cojea; crespón en el sombrero; mira el hueco del estante | Aceptó el corte del F.O. Guarda la carta original de Reichenbach y, en un cajón, un caso real anterior que pasó en limpio en marzo de 1892 | Nunca miente; no cree que Holmes viva; el 5 se desmaya «for the first and the last time» [C] | Testigo; corazón emocional; canal hacia Mycroft: le escribe tras cada pregunta sobre la roca, «como cuando lo de las pruebas» |
| **Mrs. Hudson** | [C] «sir» en cada frase; «stood in the deepest awe of him» (DYIN); no sabe nada (EMPT) | Concreta, orgullosa de su respetabilidad. «Los cuartos están como él los dejó, sir. Así lo quiere el señor Mycroft, sir.» | Cuanto más oculta, más «sir» por frase (el *tell* se puede contar) | Obedece al empleado del señor Mycroft y le cuenta las visitas | Ignora el secreto; no muestra el índice; no prepara nada «para él»; no habla de otras casas («Esa casa no es asunto mío, sir») | Sensor sin saberlo (canal K-H); fuente de la fecha (HC05) |
| **Wiggins** | [C] STUD y SIGN; «Yes, guv'nor» y «lounging superiority» (SIGN); «the old scale of pay» (SIGN). En 1894 es un joven (inferencia justificada: Mycroft recurre a la vieja red de su hermano) | Insolente y leal a un muerto. «La vieja tarifa, jefe. El que la paga escribe a máquina; el que la manda no camina más que de Pall Mall a Whitehall.» | Gorra y mondadientes; aparece al fondo de los dioramas desde el día 3 | Sospecha quién está detrás de la tarifa; nadie le dijo nada | Leal: sólo acepta encargos contra Moran | Canal K-S; reclutable (HB8) |
| **Cnel. Sebastian Moran** («mayor Harris») | [C] ficha de EMPT (Conduit St., Anglo-Indian, Bagatelle, *Heavy Game*); «clever, clever fiend»; formalista | Seco y cortés, metáforas de caza, **adjetivos repetidos**. «Un trabajo inteligente, inteligente. No me diga que vive, señor Lisle. Dígame dónde duerme el tigre.» | Pequeño suspiro de satisfacción; exige «la forma debida»; cheroot de Trichinópolis | Mató a Adair; pulió las cartas del coronel; vio a Holmes en la cornisa; preparó Camden House | Vive después; no se lo relaciona con Adair antes del mar. 3; vanidoso: no cambia de árbol aunque se lo informen | Reactor secundario: lee los informes, lo que ve Parker y la columna del *Times* |
| **Josiah Pell** [INV] | Procurador menor de Chancery Lane | Quisquilloso, latinajos, miedo a los pleitos. «En debida forma, señor Lisle, *in extenso*.» | Se seca la frente; mira la ventana | Nunca vio al coronel; obedece al «mayor» | — | Interfaz con el patrón; formula las preguntas del encargo; su chico recoge los informes |
| **Abel Crane** [INV] | Librero de viejo de Holywell Street [H] | Chismoso, mercachifle. «Lo cambiaron por un gordo que sonríe, señor.» (sobre Martin Hewitt) | Se rasca la oreja con el lápiz | Ninguno. **No es un canal** | — | Tienda de documentos (bajar no gasta franja); testigo del día 10; libro de ventas; interlocutor gratuito para practicar «presentar» |
| Parker (cameo) | [C] EMPT: «a garroter by trade, and a remarkable performer upon the jew's-harp» | — | El arpa de boca | Centinela de Moran en Baker Street | Inofensivo | Ojo de Moran sobre 221B (M10) |
| Lestrade (cameo) | [C] EMPT | — | — | — | Se lleva el crédito | Noche final |
| Cnel. James Moriarty (por carta) | [C] FINA (las cartas); que viva en Bath es [INV] | Prosa militar seca, opuesta a la de las cartas publicadas | «la terquedad de nuestro padre con los nombres» | Un amigo del Anglo-Indian le pulió las cartas | Existe y es distinto del profesor | Respuesta D28 |
| Steiler el joven (por telegrama) | [C] «Peter Steiler the elder» implica un joven | Telegráfico | — | — | — | Respuesta D27 |

**Siluetas de placeholder (un rasgo cada una):** Watson, bombín con crespón; Mycroft, volumen esférico y pañuelo rojo; Cotter, fajo de papel bajo el brazo; Mrs. Hudson, cofia; Wiggins, gorra larga; Harris/Moran, chistera de ópera y bigote enorme; Pell, cartera; Crane, ligas en las mangas; Parker, bajito y agachado; el librero, joroba, patillas blancas y una pila de libros; el hombre de Moran (M11), abrigo de cochero. Los nombres se conocen sólo cuando el personaje se presenta o por una tarjeta de visita.

---

## 5. Lugares

Ocho lugares visitables más láminas. Ir a un lugar gasta una franja; dentro, mirar y recortar es gratis y preguntar tiene el límite de §4. **Todo lo visible se puede examinar**, también lo irrelevante, y cada objeto da al menos una línea neutra que enuncia lo observable. Cada visita se archiva como **lámina congelada** que se puede volver a mirar y recortar (clase I).

El mapa lleva pegada una página de horarios del Baedeker [H]. Los lugares cerrados en una franja se dibujan con la persiana baja y **no se pueden elegir**: ningún clic gasta una franja en un lugar cerrado (test T26).

| ID | Lugar | Disponible | Objetos examinables | Quién observa | 3D |
|---|---|---|---|---|---|
| **L1** | **Buhardilla de Holywell Street** y, abajo, **tienda de Crane** (*hub*) [calle real, H] | Siempre. Bajar a la tienda no gasta franja (cerrada el domingo y la noche del prólogo) | Escritorio (lector, cuaderno, libro mayor, tijera, lupa, regla, sello «Visto»), bandeja (correo y *Times*; todo lo que entra lleva el sello «Recibido» con fecha y franja), cinco tomos (D01), cajón con la galerada (D02), concordancia (D21), mapa con horarios, calendario de escritorio, estufa, ventana a la calle (aleros salientes; Wiggins desde el día 3; el chico de Pell). Tienda: estantes (D03 suelto, D04, D07, D09 atrasado, D10, D17, D41, D42, D43, D44), libro de ventas (D33), mostrador | Nadie (ciego). Moran puede registrar (M1). El día 10, el librero | Tres encuadres fijos (escritorio, ventana, pared); la luz cambia con la franja; tras M1, objetos corridos |
| **L2** | **Sala de Lectura del British Museum** y Sala de Periódicos [H] | Días 1–5 y 7–9; M, T y N hasta las 20 h. Cerrada el domingo ⚠ | Catálogo general (búsqueda por cualquier entidad o concepto del índice; devuelve hasta 5 asientos de catálogo, mezclados con obras de época sin relación; `catalog.json`), papeletas blancas y verdes (**3 por visita**), número de asiento (lo elige el jugador), mesas radiales, mostrador con canastilla [H] y, junto a ella, Cotter; su escritorio dos mesas más allá con el cesto de tiras de papel | **K-BM**: Cotter lee las papeletas en la canastilla | Cúpula y mesas radiales; luz eléctrica fría [H] |
| **L3** | **Baker Street**: vestíbulo y salita de Mrs. Hudson en 221B, más la calle (Camden House enfrente, oficina del agente de fincas con su chico, Parker en la esquina) [C] | Interior: días 1–9, M y T (el domingo sólo T). Exterior y oficina del agente: siempre (el agente, días hábiles) | Libro de recibos (D30; Mrs. Hudson lo muestra sólo en la primera visita, cuando Lisle pregunta por cuartos de alquiler), escalera vedada (diecisiete escalones), puerta entreabierta (no se sube), olor a *shag* fresco (desde el día 8), ventanas del primer piso abiertas (día 8), cajón de Grenoble con etiqueta legible (vestíbulo, día 9 T), cartel «Se alquila» en Camden House, libro de llaves del agente (D32), el chico del agente (desde el día 7: «la casa de enfrente la anda viendo un militar»), Parker y su arpa (de noche) | **K-H**: Mrs. Hudson → Cotter (sólo temas de 221B). Parker → Moran (M10) | Fachadas enfrentadas; interior del vestíbulo; arriba sólo una puerta entreabierta |
| **L4** | **Consultorio de Watson, Kensington** [C] | Días 1–5 y 7–9, M (consulta). Domingo 6, T (visita en su casa, en el estudio). Si Watson cierra la consulta (HB4), dice hasta cuándo: «Vuelva usted el lunes» | Sala de espera, estudio: **hueco del segundo estante**, sombrero con crespón, carta original de Reichenbach (D29b; luz rasante; Watson la muestra el domingo o si no se lo presiona), sus pruebas de FINA (D29a), cajón con un manuscrito (easter egg 4), ventana a Church Street (en la esquina no hay librería). Desde M3, dos hombres apoyados enfrente | **K-W**: Watson escribe a Mycroft después de cada pregunta sobre la roca, FINA, Reichenbach o Mary | Diorama del estudio; luz de ventana |
| **L5** | **Club Diógenes**: portería y Sala de Forasteros [C] | Portería: días 1–9, cualquier franja (se deja tarjeta). Sala de Forasteros: días 8–9, entre las 16:45 y las 19:40 (T o N); el portero admite a Lisle **por su nombre** (Mycroft dejó dicho); la tarjeta HC04 es la invitación, no la llave | Libro de telegramas de la portería (D31), abierto sobre el mostrador para que los socios firmen el recibo: Lisle lo lee del revés; papel del club (medible con la regla), Mycroft, ventana a Pall Mall | Mycroft en persona (inmediato) | Silencio absoluto; sólo suena el papel |
| **L6** | **Somerset House** [H] | Días 1–5 y 7–9, M y T (de 10 a 15 h [H]) | Índices de sucesiones (*calendars*) 1891–93 e índices trimestrales de defunciones (D18), mostrador, 1 chelín por búsqueda [H]. Los índices se recortan como cualquier página. De los testamentos posteriores a 1700 **no se pueden sacar extractos** [H]: de ellos se «memorizan» hasta 3 fragmentos por visita (recortes «de memoria») o se pide copia oficial por correo (llega en dos días) | Nadie (ciego) | Mostrador y estantes de índices |
| **L7** | **Park Lane 427**, exterior [C] | Desde el día 5, cualquier franja. Día 10, 18 h: escena fija | Ventana del segundo piso, reja de no más de cinco pies, macizo de azafranes intactos, franja de césped, parada de coches a cien yardas, el parque, la multitud; **línea de tiro** (nodo propio, recortable sola) desde la calle | K-S (Wiggins: sólo «Park Lane») | Multitud congelada; el día 10, luz rasante dorada |
| **L8** | **Camden House**, interior [C] | Desde el día 7 T hasta el día 9, M o T, con el chico del agente (pretexto: alquilar; el agente tiene otra llave). El jueves la casa «ya está tomada»: sólo el exterior desde Baker Street | Tablas desnudas, papel en tiras, ventana polvorienta con **polvo removido en el alféizar**, **ceniza de cheroot** en el suelo, **guillotina engrasada** (se abre medio pie sin ruido), vista que **domina** la ventana de 221B | Nadie. Wiggins informa sólo «Baker Street» (no distingue una casa de otra) | Diorama a la luz del farol de la calle |

**Láminas que no se visitan** (conjuntos de utilería en JSON, una variante por fuente; no se derivan del texto en tiempo de ejecución):
- **Reichenbach**, en tres variantes conmutables: FINA (pared lisa), *Journal de Genève* (cornisa alta, invisible desde el sendero, y una marca en la roca) y fotografía de Crane (la cornisa vista desde la otra orilla). Se elige la variante con el documento abierto; el juego no dice cuál es cierta.
- **Lámina del prólogo** (Pell y Harris en la buhardilla; en el vidrio, el reflejo de Lisle; por la ventana, Parker y Cotter) y **lámina de la visita de Harris** del día 7 (ceniza en el escritorio). Se archivan automáticamente.

**Viaje:** mapa de época coloreado con la paleta de Booth [H]. Tres segundos de cascos; el coche cuesta 1–2 chelines (sabor). El día 6 sólo hay una franja (T).

---

## 6. Documentos

Son 45. **Clase:** I inmutable, P original en posesión (puede faltar como mucho un día, §10.1), C de campo (cortable). Un mismo documento puede tener **varios ejemplares** en lugares distintos (por ejemplo D03 en la tienda de Crane y en el BM); el grafo cuenta ejemplares (§10.3). Las «afirmaciones» (etiquetas ocultas) que lleva cada tramo están en §10.4; aquí se lista el contenido clave. Palabras = presupuesto de texto nuevo en español.

| ID | Documento | Clase | Dónde / desde | Contenido clave | Palabras |
|---|---|---|---|---|---|
| D01 | Cinco tomos de la *Strand*, vols. II–VI, con notas a lápiz | P | L1, prólogo | Las 24 historias (§15.1: escena inicial y escena central de cada una, más FINA ampliado). Notas de Watson: «¿pierna?, ¿hombro? — que quede así»; en FINA: «suprimido a pedido del F.O. — la raspadura — pase. J.»; «nov. 93 — junto a ella». Nota de Mary en TWIS: «mi James». Los mismos volúmenes, sin notas, están en el BM (I) | 9.500 (corpus) + 150 |
| D02 | Galerada de FINA de Lisle (jue. 2-nov-1893) | P | L1, cajón | Sello «1.ª prueba — lector: E. L.». La cláusula después suprimida: «con una pared a pique a un lado —salvo que, a la altura del hombro, la roca mostraba una raspadura fresca, como la que dejaría el clavo de una bota; la atribuí a algún cabrero— y un precipicio a pique al otro» | 300 |
| D03 | FINA impreso | I | *Strand* dic. 1893 suelto y *Memoirs* Newnes (L1, Crane); vol. VI (L2, BM); tomo de Watson (P, en D01) | «three-foot path, with sheer wall on one side and sheer drop on the other» [C]; carta de Reichenbach completa [C] («I made every disposition of my property before leaving England, and handed it to my brother Mycroft»; «I was quite convinced that the letter from Meiringen was a hoax»); Steiler: «Certainly not!… it must have been written by that tall Englishman» [C]; «Any attempt at recovering the bodies was absolutely hopeless» [C]; «Of air-guns» [C]; «concentrate my attention upon my chemical researches» [C]; el cochero era Mycroft [C] | (en D01) |
| D04 | Pruebas de la composición americana de FINA (oct. 1893), canceladas [INV] | I | L1 (Crane: llegaron en un lote de papel de imprenta vendido al peso) | Conservan la cláusula de la raspadura. Al margen, del cajista: «Cancelado. Rehacer la pág. por orden recibida el 14-xi (F.O.).» No es ninguna edición publicada | 120 |
| D05 | *Journal de Genève*, mié. 6-may-1891 | I | L2 (Sala de Periódicos) | Nota breve («extremely condensed» [C]): dos viajeros ingleses; «on n'a retrouvé aucun corps»; «le bâton ferré appuyé contre le rocher»; «plus haut, une corniche que l'on ne voit pas du sentier; un dénicheur téméraire y monta jadis»; «sur la paroi, une marque récente»; un pastor oyó caer piedras «à la tombée de la nuit». No atribuye nada al «docteur anglais». Texto en español con palabras francesas y glosa a lápiz de Lisle («marque = marca, raspadura») | 110 |
| D06 | *Times*, jue. 7-may-1891, despacho de Reuter | I | L2 | Resumen sin cornisa ni marca | 120 |
| D07 | Fotografía-recuerdo del Reichenbach [INV] | I | L1 (Crane) | Vista desde la orilla opuesta: en la pared, por encima del final del sendero, una línea oscura (la cornisa). Epígrafe del fotógrafo de Meiringen. El juego no dice que sea la cornisa: hay que mirarla | 30 |
| D08 | Guía de viajeros por Suiza (1891) [INV, título genérico] | I | L2 | «Más arriba del final del sendero, invisible desde éste, una cornisa (*Kanzel*) a la que sólo ha llegado algún cazador de nidos temerario. No se recomienda a nadie» | 80 |
| D09 | Cartas del coronel James Moriarty, *Pall Mall Gazette*, lun. 9 y lun. 23-oct-1893 [INV] | I (BM y números atrasados en Crane) / P (recorte de Pell) | L2; L1 (Crane; prólogo) | 9-oct: «se ha perseguido su memoria como se sigue a un tigre herido por el desagüe». 23-oct: «una persecución cruel, cruel, que no honra a quien la escribe». Nota del redactor: «entregada en mano por un caballero de bigote canoso que no dejó su nombre» | 700 |
| D10 | *Heavy Game of the Western Himalayas* (1881), de Moran [C el título; INV el contenido] | I | L2; L1 (Crane) | Portada: «por el coronel Sebastian Moran, antes del 1.º de Pioneros de Bangalore». Frontispicio con retrato grabado del autor (mismo bigote). Capítulo «Del cabrito atado»: atar el cebo bajo el árbol, apostarse en el árbol o *machan* **que domine** al cebo, tirar a la silueta contra la luz; «la bala blanda se abre dentro de la bestia». Adjetivos repetidos («una noche larga, larga»); la frase «cruel, cruel» idéntica a la carta del 23-oct | 600 |
| D11 | *Three Months in the Jungle* (1884), de Moran [C el título; INV el contenido] | I | L2 | El desagüe tras el tigre herido (eco de EMPT [C]), con la misma frase que la carta del 9-oct; «un cabrito que no bala no atrae a nadie: hay que hacerlo balar»; «el mejor tiro de la India» | 400 |
| D12 | Monografía «Sobre la distinción entre las cenizas de los diversos tabacos» [C la obra] | I | L2 | Clasificación numerada; «n.º 97: té en ladrillo del Tíbet — sin muestra». Lámina de la ceniza negra de Trichinópolis. Ejemplar dedicado a lápiz: «Al Museo, con los cumplidos del autor. S. H.»: **muestra de su letra** | 150 |
| D13 | Despachos de «S. Sigerson» desde el Tíbet, *Times* 1892–93, y nota comunicada de 1893 [INV] | I | L2 | «Comunicado por el Foreign Office». Un despacho remite «la muestra que faltaba al n.º 97 de cierta clasificación inglesa de cenizas» (sin cifra de variedades). Nota de 1893: «el explorador noruego S. Sigerson, en Jartum, huésped del Califa» (pista falsa fija) | 380 |
| D14 | Carta firmada «S. S.», *Times* (Correspondencia), sáb. 10-feb-1894 [INV] | I | L2 | Sin ciudad. Corrige a un químico: cierto derivado del alquitrán «mancha la piel de amarillo durante semanas; lo sé por mis propias manos»; «daría para una lámina más de cierto opúsculo sobre la influencia de los oficios en la forma de la mano: la del químico del alquitrán» | 200 |
| D15 | *The Times* del día | I | L1 (bandeja, días 1–5 y 7–10), L2 (archivo) | Noticias reales [H] y columna de anuncios (unos 12 por día, casi todos ruido de época). Mar. 27: el aviso de testigos de Lisle. Sáb. 31: Park Lane (sin nombres de compañeros de juego). Mar. 3: testimonios de la indagatoria (puerta cerrada por dentro, 20 pies, azafranes intactos, nadie oyó el disparo, bala expansiva, ventana abierta, dinero en pilas, la hoja con nombres; compañeros de whist «Mr. Murray, Sir John Hardy y el coronel Moran» [C], del Bagatelle [INV la mención]; las £420 ganadas con Moran [C]). Jue. 5: veredicto «willful murder… persons unknown» [C]; arresto de Théodule Meunier [H] | 2.000 (10 días) |
| D16 | *Daily Graphic*, mar. 3-abr | I | Quiosco (L1), L2 | Grabados de los testigos de la indagatoria: Murray, Hardy y el «coronel Moran» (el bigote de Harris) | 80 |
| D17 | Kelly's Post Office London Directory, ediciones 1893 y 1894 (ésta compilada en 1893) | I | L1 (Crane), L2 | Ambas: «Watson, J. H., médico, Paddington». «Moran, Col. S., Conduit St.». 221B: «Hudson, Mrs.». En la esquina de Church Street (Kensington), ninguna librería | 150 |
| D18 | Somerset House: índices | I | L6 | *Calendars* de sucesiones 1891–93: la página «Holmes, Rebecca — Holmes, Thomas» sin ningún Sherlock. Índice de defunciones, 4.º trimestre de 1893: «Watson, Mary — Paddington» ⚠ (verificar que el índice trimestral se podía consultar a fines de marzo de 1894) | 60 |
| D19 | *London Gazette* 1891–93, avisos a acreedores (Ley 22 y 23 Vict. c. 35) [H] | I | L2 | Aviso por los bienes del profesor James Moriarty, «cuya muerte se presume ocurrida el 4 de mayo de 1891» (administra su hermano, jefe de estación) [INV]. En el índice alfabético, **ningún** aviso a nombre de Sherlock Holmes | 150 |
| D20 | *Times*, mié. 10-ene-1894, anuncio de subasta [INV] | I | L2 | «Menaje de un consultorio médico, Paddington… libros, entre ellos *The Strand Magazine*, vols. II–VI, encuadernados» (subasta del mié. 17) | 70 |
| D21 | Concordancia de Lisle (1891–93) | P | L1 | Índice de sus lecturas: el sumario de las 24 historias y las fechas que no le cierran; marca INC-10 como duda propia (par del tutorial) y otras dos | 600 |
| D22 | Carta de «E. L.» al *St James's Gazette*, jue. 18-ene-1894 [INV] | I (BM) | L2 | «La aritmética del doctor Watson»: erratas inocentes; «si el doctor no sabe en qué miembro lleva la bala, ¿cómo creerle que la pared era a pique?»; «en primeras pruebas el doctor fue más honesto con la roca que en la revista» | 350 |
| D23 | Encargo de Pell y expediente (prólogo) | P | L1 | Condiciones, plazos, informes; cláusula «no menos de seis asientos pasados en limpio para el jueves». Párrafo dictado por Harris con adjetivos repetidos («una memoria cruel, cruel»). Preguntas abiertas del encargo: «dónde se aparta el doctor de los hechos», «qué ocurrió de verdad en Suiza», «qué dejó el difunto». Borrador del aviso de testigos | 450 |
| D24 | Notas de Pell (días 5, 7 y 9) | P | L1 (en mano) | M6: «El mayor no pregunta si vive. Pregunta dónde.» M8: ultimátum (§9.7) | 150 |
| D25 | Cartas a máquina, voz A | P | L1 (bandeja; el domingo, en mano) | Remington con la «s» alzada y la «t» pálida; papel del Diógenes con el membrete recortado (un centímetro más corto: se mide con la regla); firma «Un amigo de la exactitud»; matasellos S.W. Contenido según reacción (§9.6) | 1.000 |
| D26 | Respuestas de «—S.» (voz B) | I (columna) / P (cartas) | L1, L2 | En la columna, bajo «AL LECTOR DE HOLYWELL STREET.», contestan lo que Lisle publicó. Por carta a máquina (la misma Remington, firma «—S.», misma demora que la columna), contestan lo que Lisle dijo en privado. Contenido según reacción | 700 |
| D27 | Telegrama de Steiler el joven, Meiringen (respuesta) | P | L1 (al día siguiente de telegrafiar) | «CORNISA ALTA EN LA PARED SOBRE EL SENDERO. NO SE VE DESDE ABAJO. SOLO NIDEROS TEMERARIOS. PADRE NO ESCRIBIO NOTA ALGUNA. STEILER» | 25 |
| D28 | Carta del coronel James Moriarty desde Bath (respuesta) | P | L1 (dos días después de escribirle) | «No conozco a ningún Pell. Un amigo del Anglo-Indian, cazador, me pulió las cartas; yo sólo firmé.» Easter egg: «la terquedad de nuestro padre con los nombres» | 200 |
| D29 | Papeles de Watson: (a) sus pruebas de FINA con la tachadura «omitir — a pedido del F.O. — M. H.»; (b) carta original de Reichenbach: bajo luz rasante, surcos de la hoja anterior del mismo bloc: «My dear Mycroft — as arranged —»; (c) manuscrito en el cajón | C | L4 | (a) prueba del corte; (b) Holmes escribió primero a su hermano: «as arranged» remite al arreglo de bienes y papeles hecho antes de salir de Inglaterra, en previsión de su muerte (no a un plan de fuga); (c) easter egg 4 | 200 |
| D30 | Libro de recibos de 221B | C | L3 | Recibos tecleados con la misma Remington: «Recibido por cuenta del Sr. M. Holmes», trimestre por trimestre desde 1891 | 80 |
| D31 | Libro de telegramas de la portería del Diógenes | I | L5 (portería; se lee del revés) | Muestra las entradas hasta el día de la visita. Desde enero, dos por semana «de Montpellier, para Mr. M. Holmes»; desde el jue. 29, uno diario; «Lun. 2, 11.40 a. m., de Montpellier»; «Mar. 3, 9.50 a. m., de Grenoble»; «Mié. 4, 3.10 p. m., de París». Sólo hora, origen y destinatario. Son de columna: Holmes acusa recibo aunque no haya nada que contestar | 50 |
| D32 | Libro de llaves del agente de fincas de Baker Street | C | L3 | «Camden House: llave prestada al mayor Harris, lun. 2-abr., para ver la casa». (La llave de Holmes no salió de aquí.) | 30 |
| D33 | Libro de ventas de Crane | I | L1 | Jue. 5: «Un anciano, librero (dice). *British Birds*, *Catullus*, *The Holy War*, *The Origin of Tree Worship*. Precio de gremio. Dirección, de su puño: "esquina de Church Street, Kensington". Se los lleva.» | 40 |
| D34 | Ohrwalder, *Ten Years' Captivity in the Mahdi's Camp* (1892) [H; Gutenberg #32875] | I | L2 | «Shortly after my visit, Khartum was reduced to ruins» [H]; Omdurmán, «hence the name of the Mahdiist capital» [H] (pasajes verificados en `.work/dl_verify/`) | 150 |
| D35 | *Times*, notas del Sudán 1892–93 [INV] | I | L2 | «El Califa, en Omdurmán»; Jartum en ruinas | 80 |
| D36 | Diario de Lisle (automático) | I | Cuaderno | Una línea por acto observable: fecha, franja, lugar, qué pidió o dijo, a quién y qué publicó. Una línea neutra por cada llegada a la bandeja («Recibido: sobre, matasellos S.W.»), sin contenido ni valoración | generado |
| D37 | Precio a lápiz del librero en un libro que no se llevó (día 10) | P | L1 | Su letra («2s. 6d.») | 5 |
| D38 | *Strand*, oct. 1903 | — | Epílogo | «A tall, thin man with coloured glasses…» [C] | 200 |
| D39 | Tratado sobre el Binomio de Newton, de James Moriarty [C la obra] | I | L2 | Portada con el nombre del profesor (easter egg 9) | 30 |
| D40 | Barrie, «The Late Sherlock Holmes», *St James's Gazette*, 29-dic-1893 [H] | I | L1 (Crane), L2 | Acusa a Watson de haber matado a Holmes (marginalia) | 150 |
| D41 | *Strand*, marzo de 1894: Martin Hewitt [H] | I | L1 (Crane) | Marginalia | 80 |
| D42 | Prensa de época de relleno (Gladstone, Rosebery, la Reina, Greenwich, Grand National, FA Cup) [H] | I | Bandeja | Ruido | (en D15) |
| D43 | *A Study in Scarlet* (Ward Lock, 1887) [C] | I | L1 (Crane), L2 | Mismo tratamiento que las historias (§15.1), con los pasajes de INC-01, 02 y 06 y la escena de los irregulares | 600 (corpus) |
| D44 | *The Sign of the Four* (*Lippincott's*, feb. 1890, y libro) [C] | I | L1 (Crane), L2 | Mismo tratamiento; incluye las monografías de Holmes del cap. 1 («a hundred and forty forms»; «a curious little work upon the influence of a trade upon the form of the hand» [C]), «Yes, guv'nor» y «The old scale of pay» [C], y los pasajes de INC-01, 03, 06, 07 y 09 | 600 (corpus) |
| D45 | *The Lancet*, sáb. 3-feb-1894, noticias médicas [INV] | I | L2 | «El Dr. J. H. Watson, tras su reciente duelo, ha trasladado su consulta de Paddington a Kensington» | 40 |

**Diálogo** (no son documentos, pero sí fuentes recortables: cada línea dicha queda en el diario y se puede recortar en el momento o después; su origen es la escena): Watson, Mrs. Hudson, Mycroft, Wiggins, Crane, Pell, Harris, el librero y el chico del agente. Presupuesto: 4.000 palabras.

---

## 7. Core loop y estructura

### 7.1 Un día

1. **Amanecer (gratis).** Campanas de St Clement Danes, el carro del lechero, el golpe de Crane al abrir. El correo y el *Times* caen en la bandeja (el domingo no). Todo lo que entra recibe el sello «Recibido» con fecha y franja, también las cuentas y el ruido. **Toda reacción llega aquí o se descubre en el mundo**. No hay notificaciones.
2. **Escritorio (gratis, sin reloj).** Leer, recortar, vincular, abrir folios y asentar en el libro mayor. **Pasar en limpio** (validar un lote) una vez por franja (§8.5). Redactar anuncios, telegramas y cartas: se envían al pasar a la franja siguiente. Bajar a la tienda de Crane.
3. **Franjas (M, T, N).** Elegir un lugar abierto en el mapa gasta la franja; quedarse en casa también. Al terminar se vuelve al escritorio.
4. **Noches de informe** (días 2, 5 y 8, a las 22 h): el chico de Pell espera en la puerta (§7.3).
5. **Dormir.** El director resuelve las colas de reacción con su latencia (§9.3).

### 7.2 Calendario de franjas

Hay 25 franjas libres: días 1–5 y 7–9 con tres cada uno, y el día 6 con una. El día 10 tiene escenas fijas (§3.2); el jugador sólo elige dónde pasa la noche. La ruta mínima al mejor final usa unas 18 franjas; una investigación cómoda, unas 22. Se elige sin pasar hambre (Pentiment).

### 7.3 Informes a Moran (compromisos)

| Informe | Cuándo | Contenido posible |
|---|---|---|
| 1 | mié. 28, 22 h | 0 a 3 elementos (recortes o asientos del libro mayor, en lápiz o en tinta), o «Sin novedad» |
| 2 | sáb. 31, 22 h | Ídem |
| 3 | mar. 3, 22 h | Ídem |
| Final | jue. 5, 12 h | Ídem, o **quemarlo**, o la **errata a medida** (sólo si la ofrecieron Mycroft o el librero) |

Es lo único que Lisle publica, y sólo lo lee Moran. Holmes no lo ve (Ley 1); se entera por las consecuencias que causa (M3 → HB9). El contenido se compone con elementos ya existentes, sin texto libre. Moran lee lo que el elemento **dice**: un asiento por sus valores (lo que afirma, aunque su fundamento sea verdadero) y un recorte por su texto y su procedencia visible. Las reacciones de Moran se disparan por categorías que el jugador puede reconocer en lo que entregó (notas de Watson, paradero de Holmes, Camden House, su propio nombre).

**Crédito ante Moran.** Un informe con al menos un dato verdadero y comprobable sobre el asunto (por ejemplo, la cornisa o el corte del F.O.) le da a Lisle crédito ante su patrón; Moran ya sabe que Holmes vive, así que esos datos no le dan el paradero. Los informes vacíos lo erosionan (M7 lo dice: «Un cabrito mudo no me sirve»), igual que un dato falso que Parker puede verificar (M9). La errata a medida sólo engaña a un tigre que le cree al cabrito (F1, §12).

### 7.4 Diario de actos (D36)

Se escribe solo, una línea por acto **observable**: «Mar. 27, M: Sala de Lectura, asiento 214. Pedí el *Journal de Genève* del 6-may-1891.» o «Mié. 28, T: Kensington. Le dije al doctor: "La pared era a pique, ¿no?"». Y una línea neutra por cada llegada a la bandeja: «Vie. 30, amanecer: Recibido: sobre, matasellos S.W.». Registra actos y llegadas, no pistas. Sirve para cruzar acto con respuesta y medir latencias. Los actos ciegos (cuaderno, Somerset House, telegramas al extranjero, carta a Bath, tienda de Crane) también se anotan, sin marca alguna: el jugador descubre solo que nadie les contesta.

### 7.5 Economía

- **Tiempo:** 25 franjas. Es la única restricción dura.
- **Dinero (sabor):** una guinea diaria de Pell; anuncio 2s 6d ⚠ (sabor), telegrama ½d por palabra (mínimo 6d), Suiza ~3d por palabra, Somerset House 1s, coche 1–2s [H]. Las monedas están sobre la mesa. Nunca falta: no bloquea ninguna ruta.
- **Límites diegéticos:** un anuncio por día (la oficina del *Times* cierra a las 18 h para el día siguiente; el día del acto, para la latencia, es el de la **publicación**); 3 papeletas por visita a la Sala de Lectura; 3 preguntas por personaje y visita; 3 recortes «de memoria» de testamentos por visita a Somerset House.
- **Exposición (la economía real):** cada acto en un canal vigilado alimenta a Holmes y cada informe alimenta a Moran. Lo que se decide es qué ve cada uno.

### 7.6 Guardado: por compromiso

El juego guarda un **registro de eventos**. Cada acto comprometido (pasar en limpio, presentar, responder en la confrontación, enviar un anuncio, telegrama, carta o informe, viajar, cerrar una franja) se agrega al registro y se escribe a disco **en el acto**, antes de mostrar su resultado. El estado es `replay(semilla, registro)`. Cerrar el juego y volver reanuda exactamente después del último acto comprometido: no se puede deshacer una pasada fallida, un error ante Mycroft ni una respuesta del librero (test T25). Las reacciones son deterministas con semilla fija por partida. Dentro del mundo: «Holmes no olvida». Detalle técnico en §15.4; confirmación del usuario en §16.

### 7.7 Ritmo y duración

| Tramo | Duración estimada |
|---|---|
| Prólogo (tutorial: un verbo por paso, aviso de testigos, lote guiado de 1) | 15 min |
| Acto I (días 1–4; un verbo nuevo por franja con instructor: ujier, chico de Pell, oficina de anuncios) | 70 min |
| Acto II (días 5–7; el domingo es el respiro) | 55 min |
| Acto III (días 8–10) | 50 min |
| Epílogo y corrección en lápiz azul | 7 min |
| **Total** | **unas 3¼ h** (3,5 h con relectura intensa) |

El cálculo supone 25.600 palabras de texto, leídas a unas 180 palabras por minuto con un 30 % de relectura: unos 185 minutos de lectura, más el tiempo de deducción. El bot novato de T10 mide la duración real del Acto III (que abre ocho rutas el día 8) y, si supera los 60 minutos, se adelanta material según §15.7.

**Reglas de ritmo (con test, T11):**
- Como mucho 1.000 palabras nuevas por mañana en la bandeja.
- Nunca más de 2 franjas seguidas sin material nuevo, sea reacción, documento o escena.
- Como mucho una reacción **disparada** fuerte por mañana y una mañana de calma después de ella (director D2). La columna, la voz B, HB10 y M1 desde el día 8 no cuentan (§9.8).

---

## 8. Sistema de deducción

Pensar es gratis; comprometerse cuesta. Recoger material (leer, recortar, vincular) no tiene costo ni validación. Afirmar (pasar en limpio, presentar, informar, confrontar) sí.

**Principio de claridad.** El juego explica la **forma** de una prueba (qué campos hay, que cada línea necesita su «según», que hacen falta dos fuentes distintas) y la verifica a la vista. Nunca explica el **contenido** (qué es pista, qué fuente sirve, qué valor es correcto): eso se verifica en silencio.

### 8.0 Reglas del asiento (primera página del libro mayor)

Página fija, en la voz del oficio de Lisle, presente desde el prólogo. Sin ningún dato del caso:
1. «Todo asiento se escribe en una plantilla. Cada línea llena lleva su *según*: el recorte que la sostiene.»
2. «Una sola fuente no es prueba. Dos recortes del mismo papel son una sola fuente.»
3. «No más de cuatro recortes por asiento.»
4. «Lo que se pasa en limpio se pasa de a dos (de a uno el último día). Si uno no se sostiene, ninguno se entinta.»
5. «No se pasa en limpio dos veces lo mismo.»
6. «Una errata inocente se practica aparte.» (C1, §10.4)

### 8.1 Recortar

- **Modo tijera** (tecla C o la tijera del escritorio). Se arrastra sobre palabras de cualquier documento: **mínimo una palabra; máximo una oración** (no cruza un punto) **y 40 palabras**. Razón en el mundo: la tira es del ancho de una columna y entra en un renglón del cuaderno. El recorte vuela al cuaderno. El modo tijera está separado del arrastre de vinculación, para que no choquen.
- Cada documento está escrito en **tramos** con etiquetas ocultas: entidad, fecha, lugar y afirmación (§10.2).
  - **Entidades:** el recorte lleva todas las entidades que aparecen en las palabras recortadas (también las de ruido: todo lo nombrable es entidad). Son visibles en su epígrafe. El epígrafe de un recorte de diálogo, diorama o lámina incluye además el lugar y a quien habla o aparece.
  - **Afirmaciones:** el recorte hereda las afirmaciones de **un solo tramo**, el que tenga mayor parte cubierta, y sólo si cubre al menos la mitad de ese tramo. Si no, el recorte no lleva afirmaciones (sólo entidades).
- **Dioramas y láminas:** se encuadra un rectángulo de como mucho 1/8 de la pantalla. Captura **como mucho 2 nodos**: los que tienen al menos la mitad de su ancla de recorte (`clip_anchor`) dentro del rectángulo y no están tapados. Las afirmaciones vienen sólo del nodo con mayor cobertura, y sólo si el encuadre es ajustado (el rectángulo no supera 3 veces el área proyectada de su ancla). El recorte lleva una miniatura y un **epígrafe automático** con los sustantivos de todos los objetos que tocó, relevantes o no («mesa, cesto, mozo con gorra»): no revela importancia porque lo lista todo. Recortar la pared vacía es legal y no sirve.
- **Diálogo:** cada línea dicha se puede recortar en el momento o después, desde el diario. Un recorte hecho desde el diario **conserva el origen** de la escena.
- **Somerset House:** los índices se recortan normalmente; de los testamentos sólo hay recortes «de memoria», hasta 3 por visita (prohibido sacar extractos [H]).
- Los recortes son copias: **sobreviven a cualquier robo o retiro del original** y Holmes no los ve.
- **Línea de fuente.** Todo recorte muestra debajo, en letra chica, su origen: título, fecha y tipo en palabras de época («prensa extranjera», «registro», «papel privado», «dicho por el doctor Watson»). Es una cita, no una pista: permite ver si dos recortes vienen del mismo papel.

### 8.2 Índice y listas cerradas

- Todo recorte agrega sus entidades al índice del jugador: personas, lugares, documentos, objetos, fechas y conceptos («raspadura», «cornisa», «fusil de aire», «cebo», «vivo»). Como también entran las entidades de ruido, que el índice crezca no dice qué importa. El índice llena los campos de entidad de las plantillas: **no se puede escribir «Moran» sin haber recortado algo que lo nombre**. También se usa para preguntar y para redactar anuncios, telegramas y cartas.
- **Listas cerradas, visibles desde el prólogo e iguales para todas las conclusiones** (no las genera la verdad):
  - **Verbos** (campo «Hizo» y «Para»): ceder, vender, comprar, matar, disparar, ocultar, suprimir, vigilar, pagar, escribir, dictar, volver, preparar, separarse de, seguir, hallar.
  - **Relaciones** (T6): lee a, paga a, vigila a, obedece a, usa a, busca a.
  - **Medios** (T6): la Sala de Lectura, el consultorio de Watson, 221B, la calle, la columna del *Times*. También valen los sensores si están en el índice (el hombre de la canastilla, el doctor Watson, Mrs. Hudson, el muchacho de la gorra, el *Times*).
  - **Estados** (T7): vivo, muerto, desconocido.
- **Compositor de anuncios** (se enseña en el prólogo). Formas cerradas, con el texto final visible antes de enviar:
  1. «Se busca testigo de [suceso]»: Reichenbach (4-may-1891), Park Lane (30-mar-1894), Vere Street.
  2. «A propósito de [fuente]: [afirmación]»: la afirmación es una frase de tema (pared a pique, cayeron los dos, no sabía de la carta falsa, murió sin testamento, el doctor mintió, Holmes vive), disponible cuando sus entidades están en el índice.
  3. «Al corresponsal S.: [frase]» (desde que «—S.» existe).
  4. «Perdido: [objeto del índice]» (canario).
  Ninguna forma admite lugares de Londres ni las entidades marcadas `secreto_camden` (§2.4). Telegramas y cartas usan las mismas piezas.

### 8.3 Vincular y folios

- **Vincular:** se suelta un recorte sobre otro y queda un par con una nota libre opcional («contradice», «es copia de», lo que el jugador quiera). Es privado y nada lo valida. Un par vale por sus dos recortes en un fundamento. Los pares no se anidan.
- **Folios: los crea el jugador.** Se arrastra **cualquier** recorte al libro mayor y se abre una página encabezada por ese recorte. Así el jugador decide qué pregunta vale un folio. Abrir folios es opcional: siempre existe una página en blanco, «Varios», donde se puede asentar cualquier cosa. El juego **nunca** abre un folio ni formula una pregunta en el libro mayor (las preguntas las hacen personajes con intereses, §3.2).

### 8.4 Plantillas genéricas

Todas usan la forma «Campo: ___» con el artículo dentro del rótulo, para que el género o el número no delaten la respuesta (R7). Cada campo acepta entidades del índice de un tipo amplio, o un valor de una lista cerrada (§8.2). Todas están disponibles desde el principio. Ninguna presupone un hecho: no hay «Me usa como», sino «Usa a · Como»; no hay «Lo que hago llega a», sino una relación genérica entre dos personas.

| ID | Plantilla | Líneas (cada línea llena lleva su «según») |
|---|---|---|
| T1 | Errata | [Fuente A · Dice] · [Fuente B · Dice] |
| T2 | Omisión | [Fuente · Calla] · [Consta en] |
| T3 | Identidad | [Persona] · [Es, en verdad] |
| T4 | Autoría | [Documento] · [Lo redactó] |
| T5 | Hecho | [Persona · Hizo (verbo) · Qué o a quién] · [A o contra] · [Con] · [Dónde] · [Cuándo]. Las líneas después de la primera son opcionales |
| T6 | Relación | [Persona · Relación · A quién · Por medio de] · [Y de] (opcional) |
| T7 | Estado | [Persona] · [En marzo de 1894: estado] |
| T8 | Paradero | [Persona] · [Lugar] · [Día] |
| T9 | Propósito | [Persona] · [Usa a · Como] · [Para (verbo) · A quién] |

Un **asiento** es una plantilla llena más su fundamento: uno a cuatro recortes repartidos en las ranuras «según» de sus líneas. Un mismo recorte puede sostener varias líneas (cuenta una vez). Se escribe a lápiz en un folio o en «Varios». Se puede borrar y rehacer gratis.

### 8.5 Validación: «pasar en limpio»

- **Lote:** el jugador elige **2 asientos a lápiz** y aprieta el sello «Visto». El tamaño del lote es `min(2, conclusiones obligatorias y C14 sin sellar)` y **sólo baja por calendario**: el día 10, antes del informe de las 12 h, el lote es de 1. No depende de cuántos asientos haya a lápiz.
- **Frecuencia:** una pasada por franja (la franja se gasta también quedándose en casa). La noche del día 9 hay **dos** pasadas. Unas 27 en toda la partida.
- **Chequeo formal (visible, inmediato, no gasta la pasada):** si alguna línea llena no tiene «según», si el asiento tiene un solo origen o más de 4 recortes, el plumín no toma tinta y Lisle lo dice: «Falta un *según*.» / «Una sola fuente no es prueba.» / «Demasiado papel.» Es forma, no contenido.
- **Resultado (inmediato, silencioso en el contenido):** si los dos asientos son correctos y corresponden a **conclusiones distintas y no selladas**, se pasan a tinta: rasguido de plumín, secante y golpe del sello. Si no, el sello cae **sin tinta** y Lisle dice sólo: «Alguno no se sostiene.» No dice cuál ni por qué. El tampón queda seco hasta la franja siguiente (así se ve que la pasada se usó).
- **Un asiento es correcto si:**
  1. los valores pertenecen al conjunto de respuestas válidas de su conclusión (algunas aceptan varias; §10.4);
  2. para cada **grupo de afirmaciones** de la conclusión, la línea que ese grupo sostiene (§10.4) tiene en su «según» al menos un recorte con una etiqueta del grupo;
  3. el fundamento tiene al menos **2 orígenes distintos** (en C1, dos pasajes distintos);
  4. cada recorte lleva al menos una etiqueta de esa conclusión y ninguno lleva la etiqueta `refutado`;
  5. los recortes están **enlazados**: cada uno comparte al menos una entidad clave de la conclusión (§10.4, «claves») con otro recorte del mismo fundamento, de modo que todos quedan conectados. Dos recortes del mismo origen quedan enlazados entre sí. Las entidades son visibles en el epígrafe.
- **Origen** = el documento o la escena de donde viene el texto (D03 es un solo origen aunque se lo recorte en Crane y en el BM). Las láminas, el diario y los pares heredan el origen de lo que copian.
- Se acepta **toda prueba válida** (R8): no hay lista cerrada de rutas. Las rutas de §10 son ejemplos que demuestran que existen; el validador mira etiquetas, líneas, orígenes y claves.
- Un asiento en tinta queda **sellado**. Los sellados cuentan para los finales (§12) y se pueden presentar como prueba.
- **C1 (práctica):** los asientos de C1 se pasan en limpio aparte, de a uno, sin gastar la pasada de la franja, y no cuentan para nada. Es la práctica del oficio.

### 8.6 Lo que no hay

- No hay **señal de suficiencia**: ningún título se entinta solo, nada cambia al recortar o leer un fragmento. El umbral se conoce dentro del mundo (el contrato de Pell pide seis asientos en limpio).
- No hay *feedback* por casilla ni aviso de «uno mal» o «dos mal».
- No hay marcadores de «aquí hay más», brillos ni contornos de interés.

### 8.7 Preguntar y presentar

**Preguntar.** En una escena, el jugador elige un tema del índice; antes de hablar ve la frase exacta que dirá Lisle («La pared era a pique, ¿no, doctor?») y la confirma. Hasta 3 preguntas por personaje y visita (Crane, sin límite). La respuesta se elige por propiedades **visibles** del tema y del recorte (documento, entidades), nunca por sus etiquetas ocultas (test T20b).

**Presentar** (sólo dentro de una escena, en dos pasos, como el botón *Present* de Ace Attorney): se suelta un recorte o un asiento sobre el personaje, Lisle formula la frase que va a decir y un clic en «Mostrar» la confirma; «Guardar» la retira sin costo. Fuera de una escena, soltar sobre una silueta no hace nada. Crane sirve para practicar: comenta como librero y no es canal.

| Ante | Qué pasa | Costo o límite |
|---|---|---|
| Watson | Responde en personaje. Si lo presentado afirma que Holmes vive, o toca a Mary | HB4: la primera vez se toca el crespón y cambia de tema (aviso); la segunda cierra la consulta dos días (no la visita del domingo) |
| Mrs. Hudson | Responde; se cierra más | HB6 inmediato |
| Mycroft (días 8–9, después de su desafío) | Si se presenta un **asiento sellado** de C6 o de C7, ofrece la **errata a medida** (HB12) | Primer error tolerado («Otra vez, señor Lisle; no tengo toda la tarde»); el segundo cierra la Sala de Forasteros |
| Pell | Si lo presentado nombra a Moran o a Harris como autor o asesino, palidece | M4: lo despiden |
| Wiggins | Recluta (HB8) | Dos engaños con él y Holmes lo retira |
| Crane | Comentario de librero | Ninguno (no es canal) |

### 8.8 La confrontación (día 10, tienda de Crane)

Escena al estilo Ace Attorney. El librero sostiene cuatro afirmaciones, en este orden. Cada una se refuta con **cualquier recorte o asiento** (en dos pasos, como presentar) que lleve una etiqueta del **grupo refutador propio** de esa afirmación (R8). En cada afirmación se puede **callar** sin que cuente como error. Ninguna afirmación toca Camden House (§2.4).

| # | Afirmación del librero | Grupo refutador | Respuesta si el jugador acierta | Respuesta si falla |
|---|---|---|---|---|
| 1 | «Su patrón, señor, es un caballero que llora a un hermano.» | `harris_es_moran` | «Hum. Un hermano muy bien informado sobre tigres.» | «Eso prueba que su patrón lee, señor; no que caza.» |
| 2 | «El relato del doctor es exacto en lo esencial: uno cayó y el otro no volvió.» | `cornisa_existe` o `raspadura_registrada` | Tamborilea con los dedos sobre el mostrador: «Literalmente, no.» | «Eso prueba que el doctor no sabe de geología.» |
| 3 | «Nadie lo lee a usted, señor. Usted lee demasiado.» | `ancla_<canal>` (cualquier respuesta que cite un acto propio) | «Asiento doscientos catorce. Sí, sí.» (cita un acto real del diario) | «Eso prueba que el correo funciona.» |
| 4 | «Yo no soy más que un pobre librero de Church Street.» | `librero_falso` | Se endereza un instante, a su altura entera; la sombra bajo el gas llega al techo. Vuelve a encorvarse | «Eso prueba que leo a Bunyan, señor.» |

- **Paciencia a la vista:** con el primer error el librero recoge su paquete; con el segundo se pone el sombrero; con el tercero se va: «Buenos días, señor.» La escena queda incompleta y no se repite.
- **Cuatro aciertos:** no dice quién es. Deja en el tomo VI una nota a lápiz, «Faltan cinco tomos en un estante de Kensington.», y ofrece, si Mycroft no lo hizo, «corregirle las pruebas» del informe final (la errata a medida). Pide silencio «hasta que el autor lo autorice».
- La confrontación alimenta las variantes del epílogo; la conclusión C12 se valida sólo en el libro mayor.
- Holmes no se revela de palabra a nadie antes que a Watson (§2.4).

### 8.9 Por qué la fuerza bruta no conviene (números)

- A mitad de juego hay unas 60 entidades en el índice y unos 120 recortes. Cada recorte lleva afirmaciones de un solo tramo o nodo; un grupo dado aparece en unos 3 de ellos (2,5 %).
- **Sin las pruebas:** una línea al azar tiene un 2,5 % de recibir un recorte del grupo correcto; una conclusión de 2 grupos, alrededor de 6×10⁻⁴; con el enlace por claves y valores al azar (1 entre 10 por campo), del orden de 10⁻⁵ por asiento y de 10⁻¹⁰ por lote de 2. Hay unas 27 pasadas en toda la partida.
- **Con las pruebas y dudando del valor:** rotar un campo entre k candidatos cuesta hasta k pasadas, y cada pasada cuesta una franja de calendario. Para aislar una hipótesis hay que acompañarla con otro asiento correcto **de otra conclusión sin sellar**, que se consume si el lote pasa. No compra el mejor final, que exige compromisos en el mundo (§12). Es verificar una hipótesis, no pescar.
- **Presupuesto que verifica T10:** un bot con fundamentos correctos y valores al azar no sella C6, C7 y C10 en la misma partida con probabilidad mayor al 5 %; el bot «pesca» y el de fuerza bruta no alcanzan un final mejor que el del bot deductor.

---

## 9. La reacción de Holmes (núcleo)

### 9.1 Arquitectura

- **Columna y parches** (Overboard!). La columna supone un jugador pasivo (§2.1). Cada reacción es un **parche declarativo** en `data/reactions.json` con estos campos: `id`, `disparador`, `condiciones`, `canal`, `actor`, `ancla` (el detalle exacto del acto que cita), `latencia`, `efecto`, `rastro` (fragmentos nuevos y sus etiquetas), `corta[]`, `agrega[]`, `variante_blanda`, `nivel` (0–5), `tipo` (`columna`, `garantizada_por_acto`, `opcional`).
- **Director:** lo sabe todo. Ordena las colas, impone el ritmo, protege las rutas (D1) y dispara el antiestancamiento. Sólo recibe del registro de eventos los de tipo `ActoPublico`; nunca reacciona a fracasos privados.
- **Holmes-agente:** sólo sabe lo que le llega por los canales de §9.2, con la demora de su distancia (§9.3). Mantiene un contador por tema de cebo y una variable oculta de confianza que sólo cambia el tono y la ficha final.
- **Mycroft:** no es un agente libre. Ejecuta **órdenes permanentes** de su hermano por medio de Cotter (voz A, demora fija de una noche), retransmite los textos de Holmes (voz B) y **filtra**: no reexpide a su hermano nada que toque a Mary (§2.3).
- **Moran-agente:** ciego salvo por los informes, lo que ve Parker, lo que ve su hombre cuando sigue a Lisle (M11) y la columna del *Times* (§9.7).
- **Ceguera verificable:** ningún agente lee el cuaderno, el libro mayor, los pares ni las pasadas en limpio. Test T8: dos partidas con el mismo registro de actos públicos y distinto cuaderno producen exactamente las mismas reacciones.

### 9.2 Canales: los ojos de Holmes

Son cinco, y el director presenta como mucho **uno nuevo por mañana** (D3). Cada sensor declara en datos qué transmite y qué **no** puede transmitir; ninguno transmite etiquetas `secreto_camden` (test T22).

| Canal | Qué ve | Qué no transmite | Sensor (actor) | Desde | Demora del sensor | Cómo lo descubre el jugador |
|---|---|---|---|---|---|---|
| **K-T** Prensa y columna | Lo que Lisle publica: su carta de enero y sus anuncios | Lo que no está impreso | Mycroft lee el *Times* y los vespertinos | Prólogo (HC01; el aviso de testigos sale el día 1) | Lectura del día de **publicación** | Una respuesta en la columna cita su anuncio (HC10); HC01 cita su carta |
| **K-BM** Sala de Lectura | Papeletas: asiento, título y hora | Qué se lee, qué se recorta | Cotter, en la canastilla del mostrador [H] | Día 1 | Esa noche | La voz A cita el número de asiento; Cotter está junto a la canastilla; tiras del membrete en su cesto |
| **K-W** Watson | Lo que Lisle le dice o le muestra sobre la roca, FINA, Reichenbach o Mary | Cualquier otro tema; Mary no pasa de Mycroft | Watson le escribe a Mycroft «como cuando lo de las pruebas» | Primera visita | Esa noche | Una carta privada firmada «—S.» corrige palabras que Lisle sólo le dijo a Watson; Watson lo admite si se le pregunta («le escribí al señor Mycroft») |
| **K-H** 221B | Toda visita y lo que se preguntó sobre 221B, los cuartos, el alquiler o el señor Mycroft | Otras casas (Mrs. Hudson no habla de ellas) | Mrs. Hudson se lo cuenta a Cotter en su visita de las 9 | Primera visita | A la mañana siguiente | Más «sir» por frase; «Órdenes del empleado del señor Mycroft, sir» |
| **K-S** La calle | Por qué calles anda Lisle, a qué hora y con quién habla | Qué consulta y en qué casa entra (sólo la calle: «Baker Street») | Wiggins, pagado por Cotter | Día 3 | Esa noche | Silueta de gorra al fondo de los dioramas; la voz A cita su itinerario con calles y horas (HA3) |
| **Ciego** | Cuaderno, libro mayor, pares, informes a Pell, tienda de Crane, Somerset House, telegramas al extranjero, carta a Bath | — | — | — | — | Nada contesta nunca: el silencio informa (Ley 7) |

### 9.3 Latencia: la distancia es la demora

**Voz A** (órdenes permanentes de Mycroft, ejecutadas por Cotter): un acto observado el día D produce su efecto en el correo de la mañana D+1. Si D+1 es domingo, la carta llega **en mano**, sin sello, por debajo de la puerta. Esa constancia es su firma. Si dos reacciones de voz A caen la misma mañana, van **en una sola carta** (D3).

**Voz B** (respuestas de Holmes): Mycroft escribe a su hermano cada noche, cifrado; el correo tarda dos días a Montpellier (en Francia no se reparte el domingo [INV]) y uno a París. Holmes contesta por telegrama al Diógenes (D31) y Cotter pone el anuncio para el día siguiente o, si el acto fue privado, envía la carta para el correo de esa misma mañana. No hay *Times* el domingo. Holmes parte de Montpellier el lunes 2 tras contestar en tanda; desde entonces Mycroft escribe a París, lista de correos.

| Acto observado (o anuncio publicado) el día | Llega a Holmes | Respuesta de voz B | Demora |
|---|---|---|---|
| 1 (mar. 27) | jue. 29, Montpellier | **día 4** (vie. 30) | 3 |
| 2 (mié. 28) | vie. 30, Montpellier | **día 5** (sáb. 31) | 3 |
| 3 (jue. 29) | sáb. 31, Montpellier | **día 7** (lun. 2; no hay *Times* el domingo) | 4 |
| 4 (vie. 30) | lun. 2, Montpellier | **día 8** (mar. 3), en tanda | 4 |
| 5 (sáb. 31) | lun. 2, Montpellier, antes de partir | **día 8**, en tanda | 3 |
| 6 (dom. 1) | los sensores informan el lunes; París, mié. 4 | **día 10** (jue. 5), en tanda | 4 |
| 7 (lun. 2) | París, mié. 4 | **día 10**, en tanda | 3 |
| 8 (mar. 3) | París, mié. 4 | **día 10**, en tanda | 2 |
| 9 (mié. 4) | Cruza esa noche | **día 10**: en persona (9:30) | 1 |

El patrón legible: tres días de demora; cuatro cuando hay un domingo en medio; el martes, **dos respuestas juntas**; el miércoles, nada (el viajero está en camino); el jueves, **una tanda** con demoras que se acortan y, a las 9:30, la respuesta en persona. Dos relojes: uno cercano que cumple y uno lejano que se acerca. Las respuestas en tanda citan la fecha del acto («su anuncio del sábado»). Esa forma es la ruta C9.R3.

**Moran:** reacciona a cada informe al día siguiente y a la columna desde el día 5 (§9.7).

### 9.4 Las leyes de Holmes (el jugador las descubre; el juego nunca las enuncia)

1. **Ve lo público, no lo pensado** (Orwell).
2. **No tolera la inexactitud sobre sí mismo.** Corrige los dos primeros cebos de un tema con un dato verdadero que **remite a una fuente** («dele; véase…»), nunca con el hecho a secas ni con nada que diga que vive (HB1). Al tercero responde con una corrección **falsa y refutable** (HB2). Del cuarto en adelante, silencio.
3. **En este asunto no destruye: retira o desvía. Siempre queda una copia.** Necesita que el rastro siga legible para el lector y para el tigre. Lo que roba Moran, la mano A lo devuelve (HB10). Destruir es cosa de Moran.
4. **Protege a Watson antes que a su secreto.** Es su única reacción sin ironía (HB4, HB9).
5. **Contesta por el mismo canal**: a lo publicado, en la columna; a lo dicho en privado, por carta privada firmada «—S.»; a la papeleta y a la calle, con una carta de voz A.
6. **Su demora mide la distancia** (§9.3).
7. **El silencio informa.** No reacciona a las erratas inocentes, a las cartas del coronel, a los libros de Moran ni a nada sobre Park Lane: quiere que el lector llegue ahí. Es el perro que no ladró (SILV [C]).
8. **Cierra el canal que se le prueba dos veces** (HB11).

Además, una restricción que no es ley del personaje sino del canon: nada de lo que se publica puede leerse como «Holmes vive», y nada que pueda ver Watson contesta lo que Lisle le dijo a él (§2.4).

Las reacciones **nunca son un oráculo**. Dicen qué teme Holmes y por dónde mira, nunca el valor de un asiento. Vienen de personajes con intereses distintos: Mycroft desvía (HA1), Sherlock señala fuentes, a veces mienten (HB2, HB3) y siempre las lee también el tigre.

### 9.5 Escalada (postura)

| Nivel | Postura | Ejemplos | Sube por |
|---|---|---|---|
| 0 | Lector | HC01, HA0 | Columna |
| 1 | Corrector | HA1, HA3, HA4, HB1, HC10 | Primer acto observado de cada canal; el aviso de testigos |
| 2 | Archivero | HB5, HB6 | Que Lisle insista en los papeles de Watson o en 221B |
| 3 | Desvío | HB2, HB3, HB7 | Cebos repetidos, Sigerson, publicar que vive |
| 4 | Invitación | HC04, HC06 | Columna (fijo, día 8) |
| 5 | Presencia | HC07 | Columna (día 10) |

La postura sube por **exposición visible**, nunca por errores del jugador (Alien). La confianza oculta sube cuando Lisle protege a Watson o ve a través de un desvío (refuta HB2 o HB3 en un anuncio). Baja mucho con HB9. Se lee en el tono («Tut.» frente a «Bien visto; no del todo.») y en la ficha del índice de Holmes al final (§12), nunca en un número.

### 9.6 Tabla exhaustiva de reacciones de Holmes

Nivel ≥3 = reacción fuerte (D2). Tipo: **col** = columna (ocurre aunque el jugador no haga nada); **gar** = garantizada por acto (§10.3); **opc** = opcional. Las rutas se nombran como en §10.

| ID | Tipo | Disparador exacto | Condiciones | Actor | Efecto en el mundo (qué, dónde, cuándo) | Cómo lo percibe el jugador | Qué revela (la reacción como pista) | Rutas: corta / agrega |
|---|---|---|---|---|---|---|---|---|
| **HC01** | col | Inicio del día 1 | Ninguna | Cotter, por orden permanente («si un caballero visita al corrector, eche al correo este sobre»); lo echó al correo el lun. 26 de noche al ver a Parker escoltar a Harris | En la bandeja: sobre sin remitente, matasellos S.W., con el recorte de D22. A lápiz blando, junto a «la pared era a pique»: «No lo es.» (letra de Holmes, escrita en enero) | Primer objeto del juego. Línea de base: llega antes de que Lisle haga nada | Alguien sabe que la pared no era lisa; letra comparable con D12; zona de Pall Mall; lo sabían antes de empezar (la lámina del prólogo muestra a Cotter enfrente) | — / agrega C3 (apoyo), C7.R6, C8.R4 |
| **HC02** | col | Desde el día 3 | Lisle sale de L1 | Wiggins | Una silueta con gorra larga al fondo de cada lugar visitado (al menos un encuadre por franja, sin tapar), también en la lámina archivada | Aparece sin aviso; se repite | Canal de la calle | — / agrega C6 (K-S) |
| **HC03** | col | Día 6 | Sin correo | Cotter | Si hubo actos observados el día 5, la carta de voz A llega en mano, sin sello. La voz B no publica nada los días 6 (no hay *Times*) y 9 (§9.3) | Sobre sin sello bajo la puerta; columna muda el miércoles | La mano A está en Londres; la B, de viaje | — / agrega C7 (apoyo), C9.R3 |
| **HC04** | col | Día 8, correo | Ninguna | Cotter, por decisión de Mycroft | Tarjeta tecleada con la misma Remington: «Mr. Mycroft Holmes estará en la Sala de Forasteros de 16:45 a 19:40, martes y miércoles.» Es una invitación: el portero admite a Lisle por su nombre aunque la tarjeta falte | En la bandeja | La máquina de las cartas pertenece al entorno de Mycroft | — / agrega C7.R1 |
| **HC05** | col | Días 8–9 | Ninguna. HB6 **no** corta estas líneas | Cotter; transportista | Mar. 3: ventanas del primer piso abiertas, una libra de *shag*. Si Lisle visita, Mrs. Hudson, en dos tramos separados: «El empleado del señor Mycroft dijo que para el jueves, sir…» / «…todo tiene que estar como siempre. No sé para quién, sir. No hay quien lo fume, sir.» Mié. 4, tarde: en el vestíbulo, un cajón con etiqueta «G.V. — Grenoble — O. Meunier, mouleur — pour M. Mycroft Holmes, 221B Baker Street — NE PAS OUVRIR — cire». «No se abre, sir. Órdenes.» | Exterior de 221B; diálogo; cajón | Alguien vuelve el jueves; un objeto de cera de Grenoble (eco de Meunier/Meunier) | — / agrega C9.R1, C9.R2, C9.R5 |
| **HC06** | col | Días 8–9, Diógenes, Sala de Forasteros | Lisle va a la portería en el horario; dos visitas como máximo (la segunda sólo para presentar) | Mycroft en persona | Las líneas (a)–(f) se dicen **siempre**, antes de admitir presentaciones. (a) Deduce a Lisle en diez segundos, incluidos los «anteojos de color por la fotofobia»; usa el giro de la voz A: «Le ahorraré el trabajo». (b) Cita **un acto por cada canal** que Lisle usó, con fecha y asiento, calle u hora (si no usó ninguno, la carta de enero y la visita del lunes). (c) «Mi hermano detesta las erratas, señor Lisle.» Pausa. «Detestaba.» (d) «Mi hermano me escribía que usted "lee con los dedos". En él era un cumplido.» (e) «El jueves no estaré en el club. Un compromiso de familia.» (f) Papel del club sobre la mesa, que se puede medir. Si Lisle pregunta por Watson o por su duelo: «Mi hermano no necesitaba más motivos para volver antes de tiempo.» (g) El desafío: «¿Y quién cree usted que le contesta, señor Lisle? Muéstremelo; en limpio, si es tan amable.» → HB12 | Escena en silencio; sólo suena el papel | Quién es la mano A; un presente que se corrige; la ruptura de su rutina el jueves; Mycroft sabía de Mary | — / agrega C6 (anclas de todos los canales usados), C7.R2, C7.R8, C8.R3, C9.R2 |
| **HC07** | col | Día 10, 9:30, tienda de Crane | Ninguna | Holmes disfrazado | Compra los cuatro libros a precio de gremio y escribe de su puño la dirección de su «tiendita de la esquina de Church Street» (D33; se los lleva). Pregunta por «los tomos de la *Strand*», los hojea, ve las notas de Mary: «Éstos tienen dueño, señor.» Escribe un precio a lápiz en un libro que no se lleva (D37). Nodos recortables por separado: dedos manchados de amarillo; sombra que llega al techo bajo el gas. Confrontación (§8.8) | Crane llama desde abajo | Dedos amarillos, estatura escondida, reconoce la letra de Watson; Holmes se entera del duelo | — / agrega C12.R1, C12.R3, C12.R4 |
| **HC08** | col | Día 10, 18 h, Park Lane | Ninguna | Holmes, Watson | Watson choca con el librero; caen los libros; *The Origin of Tree Worship* [C]; el librero gruñe con desprecio y se va encorvado entre la gente [C] | La única animación del juego | El disfraz; los libros comprados por la mañana | — / agrega C12.R2 (sólo epílogo) |
| **HC09** | col | Día 10, noche | Lisle elige dónde pasarla | Holmes, Moran, Lestrade | Canon de EMPT: noche fría y ventosa. En Baker Street: cuartos de hora, el arpa que se calla, el silbido, el vidrio, el silbato, Lestrade. En casa: el *Times* del viernes en el epílogo | Sonido; siluetas | Confirma lo deducido (no valida asientos) | — |
| **HC10** | col | Día 4, columna | El aviso de testigos del prólogo (siempre existe) | Holmes (texto); Cotter pone el anuncio | «AL LECTOR DE HOLYWELL STREET. — Busca usted testigos del 4 de mayo. Hubo tres guías, un pastor y un médico; los cuatro primeros hablaron en francés, y lo dijeron en Ginebra. —S.» El ancla es el texto exacto del aviso | Un aviso entre unos doce en la columna | Un corresponsal que contesta en tres días y remite al *Journal*; la mano B no coincide con la A, que desvía | — / agrega C6 (K-T), C9.R3 |
| **HA0** | col | Día 2, correo | Sólo si HA1 no se disparó el día 1 | Cotter; Mycroft dicta | Carta de voz A: «Lunes, nueve y cuarto: tuvo usted visitas. Lea lo que quiera; no publique lo que no sabe. —Un amigo de la exactitud» | Sobre en la bandeja | Alguien vigila la puerta; existe la voz A (papel y máquina) | — / agrega C7.R1, C7.R3 (apoyo) |
| **HA1** | gar | Papeleta en L2 de un documento con tema «Holmes»: crónicas, prensa de mayo de 1891, monografías de Holmes, despachos de Sigerson | Primera vez por tema; días 1–9 salvo domingo. **Excluye** cartas del coronel y libros de Moran (Ley 7) | Cotter; Mycroft dicta | Carta de voz A, mañana siguiente, con el ancla (asiento, título, hora) y un **desvío** hacia la fuente menos informativa. Prensa de 1891: «Asiento 214: los guías hablaron al Journal, el Journal a Reuter y el doctor no habló con nadie. Tres fuentes que son una. Le ahorraré el trabajo: lea a Reuter.» Crónicas: «Asiento 214: el doctor se equivoca dos veces por página; no pierda la vista con la tercera.» Monografía: «La ceniza no es su ramo, señor.» Sigerson: «Los noruegos escriben de montañas, no de usted.» | Sobre en la bandeja, firma «Un amigo de la exactitud» | Canal K-BM; máquina y papel; **qué teme** Mycroft: quiere alejarlo del *Journal* | — / agrega C6 (K-BM), C7.R1, C7.R3 |
| **HA2** | opc | Segunda papeleta del mismo tema | Misma visita | Cotter (descuido) | El volumen llega con un señalador en una página irrelevante: una tira con «…GENES CLUB · PALL MALL…». Cotter, dos mesas más allá, recorta papel | Inmediato, en L2 | Quién vigila la canastilla | — / agrega C7.R4 (apoyo) |
| **HA3** | gar | Primer día, desde el día 3, en que Lisle sale de L1 | Wiggins activo | Cotter (informe de Wiggins) | Voz A a la mañana siguiente, con calles y horas: «Kensington a las diez, el Strand a las tres. Un hombre de su vista no debería caminar tanto.» Nombra calles, nunca lo consultado ni una casa | Bandeja | Canal de la calle; qué ve y qué no | — / agrega C6 (K-S), C7.R3 |
| **HA4** | opc | Primer canario confirmable en un canal: un dato falso **sobre Lisle mismo**, ajeno a Holmes (a Mrs. Hudson: «me mudo a Chelsea»; un «Perdido: [objeto]» en la columna; a Watson: una cita inventada) | Una vez por canal | Cotter | Voz A a la mañana siguiente, que repite el dato con sequedad: «Chelsea es húmeda para sus ojos, señor.» | Bandeja | Canal confirmado | — / agrega C6 (ancla del canal) |
| **HB1** | gar (1.er cebo en K-T) / opc (resto) | Cebo 1 o 2 de un tema: Lisle afirma una inexactitud sobre Holmes o Reichenbach en su anuncio (K-T), a Watson (K-W) o a Mrs. Hudson (K-H). Temas en datos: pared a pique, cayeron los dos, no sabía de la carta falsa, murió sin testamento, el doctor mintió | Contador por tema ≤2 | Holmes (texto); Cotter pone el anuncio o envía la carta | En la fecha de §9.3. Si el cebo fue publicado, en la columna; si fue privado, por carta a máquina firmada «—S.». Ancla: las palabras exactas de Lisle. Textos (1.º / 2.º): **Pared:** «"A pique": dele. Véase el Journal de Genève del 6 de mayo de 1891. —S.» / «Quien fotografía la cascada desde la otra orilla ve lo que no ve quien camina el sendero. —S.» **Cayeron:** «"Cayeron los dos": el doctor escribió que no se recuperó a nadie. Un corrector no imprime lo que el texto no dice. —S.» / «El Journal tampoco: "aucun corps". —S.» **Carta:** «"No sabía": la carta del 4 de mayo dice lo contrario, y el doctor la imprimió entera. —S.» / «Pregunte en el Englischer Hof quién escribió esa nota. —S.» **Testamento:** «"Sin testamento": el 4 de mayo el difunto dispuso de lo suyo por carta; el doctor la imprimió. —S.» / «Somerset House cobra un chelín por no hallar nada. —S.» **Watson:** «"Mintió", dice usted. Un cronista no es su cajista. —S.» / (sólo en privado) «El "omitir" de la prueba no es de la mano del doctor. —S.» | Un aviso entre unos doce, o un sobre a máquina con otra firma | Un corresponsal con datos exactos que remite a fuentes; la latencia; el canal; y que el tigre también lo lee (M8, M11) | — / agrega C6 (K-T, K-W o K-H), C9.R3 |
| **HB2** | opc | Tercer cebo del mismo tema | — | Holmes | Corrección **falsa** en la fecha de §9.3, por el mismo medio que HB1. **Pared:** «Insiste usted. Se lo concedo: el muchacho suizo se llevó el bastón, y lo demás es literatura. —S.» **Cayeron:** «Se lo concedo: el río devolvió un cuerpo en junio. —S.» **Carta:** «Se lo concedo: la nota la escribió el posadero, y el profesor la aprovechó. —S.» **Testamento:** «Se lo concedo: el hermano reclamó la herencia ante el tribunal en 1892. —S.» **Watson:** «Se lo concedo: el doctor tachó la frase por su cuenta, por miedo al ridículo. —S.» Cada una se refuta desde 2 fuentes (§10.5) | Igual que HB1 | Prueba si el lector copia o razona. El fragmento lleva la etiqueta `refutado` y no sirve de fundamento | — / — |
| **HB2b** | opc | Cuarto cebo o más del mismo tema | — | — | Silencio | Nada | Ley 2 | — / — |
| **HB3** | opc | Primera mención o papeleta de «Sigerson» en un canal vigilado | Nivel 3 | Mycroft, por una nota comunicada a los diarios por el Foreign Office | En la fecha de §9.3, en las **noticias** (no en la columna): «Nota comunicada por el Foreign Office: el explorador noruego S. Sigerson, cuyos despachos de Jartum publicó este diario, ha seguido viaje hacia el Alto Nilo.» Desvío pensado para Moran. Excepción documentada a la regla de anclas: su ancla es sólo el nombre y la fecha | Noticia en el *Times* | Alguien con acceso al F.O. fabrica el paradero de Sigerson y lo aleja de Europa. Refuerza la pista falsa de D13 | — / agrega C7 (apoyo), C8 (apoyo) |
| **HB4** | opc | Hablarle a Watson de Mary o de su duelo, o decirle o presentarle que Holmes vive | K-W | Watson; Cotter (voz A) | **Primera vez:** Watson se toca el crespón y cambia de tema («Prefiero no hablar de eso, señor Lisle»); a la mañana siguiente, voz A sin ironía: «Deje al doctor su duelo.» **Segunda vez:** «Mi amigo está muerto, señor Lisle, y yo tengo pacientes. Vuelva usted el [fecha].» Cierra la consulta dos días (la visita del domingo a su casa no se cierra). Nada llega a Holmes: Mycroft no lo reexpide | Gesto; carta; puerta cerrada con fecha | El protector cuida a Watson antes que a sí mismo (Ley 4); Mycroft sabe de Mary | Corta 2 días (sólo la segunda vez): C2.R4, C4.R4, C14.R3 / agrega C6 (K-W), C7 (la carta) |
| **HB5** | opc | Segunda visita a Watson preguntando por las pruebas o por FINA, o mostrarle D02 o D04 | Nivel 2 | Cotter recoge, por pedido «de Estado» | Al día siguiente las pruebas de Watson (D29a) están «prestadas a un caballero del Foreign Office»; queda un recibo «p.p. M. H.». La carta original (D29b) no se presta nunca. Watson: «Se las llevaron ayer. Asuntos de Estado, me dijeron.» | Diálogo y recibo en L4 | M. H. custodia el corte | Corta C2.R4 / agrega C7.R5 (recibo) |
| **HB6** | opc | Primera visita al interior de 221B | Nivel 2. En esa primera visita el libro de recibos todavía se puede ver | Cotter instruye a Mrs. Hudson a las 9 | Desde el día siguiente Mrs. Hudson no muestra el libro de recibos ni habla del alquiler; dobla los «sir». Sigue diciendo las líneas de HC05 | Más «sir»; «Órdenes del empleado del señor Mycroft, sir» | Mycroft controla 221B; canal K-H | Corta C4.R3, C4.R5, C7.R3 (desde la segunda visita) / agrega C6 (K-H) |
| **HB7** | opc | Anuncio de Lisle que afirme que Holmes vive o se dirija a «S.» | — | Holmes | Voz B en la columna, en la fecha de §9.3: «AL LECTOR. — Los muertos no leen la columna. Usted sí; y no es el único. —S.» | Columna | Hay un tercer lector | — / agrega C10.Cc |
| **HB8** | opc | Hablarle a Wiggins en un diorama y pagarle un chelín, o mostrarle el recorte de «the old scale of pay» (D44) | Desde el día 3 | Wiggins | Se vuelve aliado: «La vieja tarifa, jefe. El que la paga escribe a máquina; el que la manda no camina más que de Pall Mall a Whitehall.» Acepta un encargo por día, **sólo contra Moran**: seguir al chico de Pell (o a quien retire la lista de correos) o seguir a Parker | Diálogo; informe al día siguiente en la ventana | Mycroft paga; dónde vive el patrón | — / agrega C7.R7, C10.Id |
| **HB8b** | opc | Usar a Wiggins dos veces para pasar información falsa a Holmes | — | Cotter | Voz A: «Un chelín compra a un chico, señor; no compra un hecho.» Otro muchacho sin gorra sigue a Lisle; Wiggins ya no habla | Cambia la silueta; carta | Ley 8 | Corta C7.R7, C10.Id / agrega C7 (la carta) |
| **HB9** | opc | M3 (hombres de Moran frente a la consulta de Watson) | Nivel 3 | Wiggins o el muchacho de Cotter los ve; Cotter | Voz A, sin ironía: «Puede usted leer lo que él imprimió. Lo que no imprimió no es suyo.» Es un **aviso**: no marca nada. Si después de esta carta otro informe vuelve a entregar `watson_privado`, se activa `watson_expuesto` (bloquea F1) y llega una segunda carta: «Se lo dije.» Desde entonces la voz B calla salvo HB10 | Carta | El informe llegó a un enemigo: dos lectores | — / agrega C10.Cd |
| **HB10** | opc | M1 observado (registro de la buhardilla) | Desde el día 3 | Wiggins (o, tras HB8b, el muchacho de Cotter) los recupera; Cotter los devuelve | A la mañana siguiente del registro, los originales vuelven **intactos** en un paquete en el mostrador de Crane, con una tarjeta a máquina: «Devuelto. Ponga cerrojo.» Si Wiggins está reclutado, añade: «Estaban en una casa de Conduit Street.» No lo difiere D2 | Paquete | Ley 3: hay una mano que roba y otra que devuelve | Restaura las rutas P / agrega C10 (apoyo) |
| **HB11** | opc | Segundo canario confirmado en un mismo canal (HA4 ya ocurrió en ese canal). Los cebos no son canarios | La primera prueba ya produjo reacción | Cotter | Voz A: «Su experimento con [la señora Hudson / la columna / el doctor] fue elegante. No lo repita.» Ese canal deja de producir reacciones **opcionales** nuevas; las de columna y las garantizadas por acto siguen; lo ya obtenido queda | Carta | Canal confirmado | Ninguna ruta se pierde: exige dos reacciones del canal ya obtenidas (T5) / — |
| **HB12** | opc | Presentar a Mycroft, después de su desafío (HC06 (g)), un asiento **sellado** de C6 o de C7 | Los fragmentos de origen HC06 no cuentan. Lo que no contesta la pregunta (por ejemplo, material de Camden House) es un error y Mycroft no lo lee | Mycroft | Éxito: «Su último informe, señor Lisle. ¿Me permite dictarle una errata?» Desbloquea la **errata a medida**. Primer error: «Otra vez, señor Lisle; no tengo toda la tarde.» Segundo error: «Ha confundido usted mi pereza con mi ignorancia. Buenas tardes.» Se cierra la Sala de Forasteros; la portería y D31 siguen abiertas. Si no hubo presentación el día 8, se puede volver el 9 sólo a presentar | Escena | — | — / — |
| **HB13** | opc | Antiestancamiento: dos franjas seguidas sin actos observados (Lisle no sale de L1 ni publica) | Motivo de Holmes: el cabrito tiene que moverse para que se mueva el tigre | Cotter | Voz A con un empujón **hacia actividades, nunca hacia el documento clave** de una conclusión: «Un hombre que no sale no es leído, señor.» / «El doctor acostumbra equivocarse dos veces en la misma página.» / «La Sala de Periódicos abre hasta las ocho.» | Carta | Lo quieren activo | — / — (T16: sólo las etiquetas de C6 y C7 propias de toda carta de voz A) |
| **HB14** | — | Silencios explícitos (Ley 7): papeletas sobre cartas del coronel, libros de Moran, Ohrwalder, *Gazette*, Kelly's; Somerset House; telegrama a Meiringen; carta a Bath; erratas inocentes; tienda de Crane | — | — | Nada | Ausencia | Lo que Holmes no teme, o no ve | — / — |

### 9.7 Moran, el otro lector

Moran sabe lo que dicen los informes (§7.3), lo que ve Parker en Baker Street, lo que ve su hombre cuando sigue a Lisle (M11) y lo que se publica en la columna. Su firma es opuesta a la de Holmes: **roba, rompe y responde exactamente a lo informado**. Es vanidoso: no cambia de árbol aunque le cuenten que se lo vio («El árbol lo elige el cazador, señor, no el cabrito»).

| ID | Tipo | Disparador exacto | Condiciones | Actor | Efecto | Percepción | Qué revela | Rutas: corta / agrega |
|---|---|---|---|---|---|---|---|---|
| **M1** | opc | El informe contiene ≥1 elemento que proviene de un original P (galerada, tomos, cartas recibidas, telegrama, copia de Somerset House) | Nivel 3. Desde el día 8 no lo difiere D2 | Hombres de Moran | Al día siguiente, en la primera franja en que Lisle sale (o de noche, si no sale), registran la buhardilla. Se llevan **esos originales**; los recortes, el cuaderno y el libro mayor no, porque Lisle los lleva encima. Dejan ceniza de cheroot y una pisada pesada. HB10 los devuelve a la mañana siguiente | Encuadre alterado al volver | La otra mano; la ceniza es la de Harris | Corta un día las rutas P de los originales informados (según cuáles: C2.R1, C2.R5, C3.R4, C5.R3, C7.R1, C7.R6, C8.R4, C10.R3, C14.R1) / agrega C10 y C13 (ceniza) |
| **M2** | opc | El informe afirma que Holmes vive (un asiento C8 o un recorte con `holmes_vive`) | Nivel 3 | Hombre de Moran | Al salir al día siguiente, cae un ladrillo de un alero de Holywell Street a un paso de Lisle. Nota de Pell: «El mayor está muy preocupado por su seguridad.» | Sonido y polvo; nota | «Hay que hacerlo balar» (D11); eco de Vere Street (FINA [C]) | — / agrega C10.Cd |
| **M3** | opc | El informe contiene material privado de Watson (`watson_privado`: notas de los tomos, Mary, papeles de Watson; se reconoce por su procedencia visible) | — | Hombres de Moran | Desde el día siguiente, dos hombres vigilan la consulta de Watson (visibles en L4). Dispara HB9. La segunda entrega, después de HB9, activa `watson_expuesto` | Siluetas en L4 | El patrón usa lo que informo contra Watson | — / agrega C10 |
| **M4** | opc | El informe nombra a Moran o a Harris como autor o asesino (asiento con valores de C5, C10, C10a, C11 o C13), o Lisle se lo presenta a Pell | — | Moran | Despiden a Pell (nota temblorosa: «Le ruego no me nombre.»). Los informes siguientes se dejan en lista de correos de Charing Cross, «a nombre de H.»; los retira Parker. M6 y M7 ocurren igual (M6 como nota firmada «H.», con la misma línea y las mismas etiquetas; M7 más frío) | Nota; el chico ya no viene | Pell era sólo una pantalla | Corta C10.Id en su forma «seguir al chico»; variante blanda: Wiggins sigue a Parker desde Charing Cross hasta Conduit Street / agrega C10 (la nota «H.») |
| **M5** | opc | El informe contiene etiquetas de C13 (Camden House) o de C9 (jueves, regreso) | — | Moran | El libro de llaves del agente aparece con la página del 2-abr arrancada. El chico del agente: «Ayer vino un caballero a consultar el libro.» Moran no cambia de plan (vanidad; canon). Pell o la nota «H.»: «El árbol lo elige el cazador, señor, no el cabrito» | En L3; nota | Moran limpia su rastro | Corta C13.R3 / agrega C13 (apoyo: la línea del chico) |
| **M6** | col | Día 5, al amanecer | — | Pell (o nota «H.» si M4) | Paga y dice: «El mayor no pregunta si vive, señor Lisle. Pregunta dónde.» | Escena en L1 | El patrón sabe que Holmes vive | — / agrega C8 (apoyo), C10.Ca |
| **M7** | col | Día 7, 22 h, en el escritorio de L1 | Lisle siempre está en casa a esa hora (la franja N termina a las 22 h) | Moran como Harris | Sube a la buhardilla: «Un trabajo inteligente, inteligente. No me diga que vive. Dígame dónde duerme el tigre.» Metáforas de caza; exige «la forma debida». Enciende un cheroot: «¿Le molesta el humo? Es de Trichinópolis.» Deja ceniza en el escritorio (lámina archivada). Variante si M4: más frío. Variante si los informes estuvieron vacíos: «Un cabrito mudo no me sirve, señor.» Variante si M9: «Le ruego exactitud, exactitud.» | Escena | Adjetivos repetidos, ceniza, «dónde» | — / agrega C10.Ib, C10.Cb, C13.R1 |
| **M8** | col | Día 9, mañana | — | Pell (o nota «H.») | Ultimátum: «El mayor exige el lugar antes del jueves a mediodía.» Variante si algún informe incluyó respuestas de «—S.» con fecha: «…El mayor observa que su corresponsal "S." contesta cada vez más deprisa.» | Nota | **Giro:** el tigre mide las mismas latencias que Lisle | — / agrega C10 (apoyo), C9 (apoyo) |
| **M9** | opc | El informe contiene un dato falso verificable por Parker (un paradero inventado en Londres) | — | Parker | Paga reducida a media guinea. Pell: «El mayor verificó su informe. Le ruego exactitud, exactitud.» Lisle pierde el crédito ante Moran (§7.3). No hay *game over* | Nota | Lo verificable se verifica | — / — |
| **M10** | opc | Lisle visita 221B o Camden House (Parker lo ve en Baker Street) | — | Parker | En la siguiente comunicación de Pell o de Harris: «El mayor celebra su diligencia en Baker Street.» | Línea | El patrón vigila Baker Street | — / agrega C13.R5 |
| **M11** | opc | Desde el día 5, la columna trae una respuesta de «—S.» a un anuncio de Lisle | Una vez | Hombre de Moran (abrigo de cochero) | Desde el día siguiente, un hombre de abrigo de cochero sigue a Lisle (silueta en los dioramas, además de Wiggins). En la siguiente comunicación de Pell o de Harris se nombra un lugar que Lisle visitó: «El mayor sabe que usted pasea, señor.» | Segunda silueta; línea | El tigre lee la columna y sigue al cabrito | — / agrega C10 (apoyo) |
| **M12** | opc | El informe da un paradero de Holmes **fuera de Londres** (Montpellier, Grenoble, París; por ejemplo, leído en D31) | — | Moran | Moran no viaja: el cazador espera en el cebo (D10). En la siguiente comunicación de Pell o de Harris: «El mayor no caza en monte ajeno, señor. Quiere saber dónde va a estar, no dónde estuvo.» Cuenta como haber entregado a Holmes (F1, §12.1) | Línea | «Dónde» significa dónde va a estar en Londres | — / agrega C10 (apoyo) |

### 9.8 Reglas del director

- **D1 Guardia de rutas.** Antes de aplicar una reacción que corta, verifica la invariante (§10.3) para la conclusión afectada. Si la violaría, aplica la `variante_blanda`. Toda reacción que corta tiene una.
- **D2 Ritmo.** Como mucho una reacción **disparada** de nivel ≥3 por mañana y una mañana de calma después. Lo que choca se difiere un día, en este orden: primero Moran, después los cortes de voz A. Quedan fuera de esta regla (no se difieren ni cuentan): la columna (HC, HA0, M6–M8), toda respuesta de voz B (la latencia es evidencia), HB10 y M1 desde el día 8. Lo que se difiriera más allá del día 10 se fusiona con la reacción del día anterior, no se descarta.
- **D3 Canales de a uno.** La primera reacción de un canal no coincide en la misma mañana con la primera de otro canal; si son de voz A, van **fusionadas en una sola carta** (no se difieren, para no romper la demora de una noche).
- **D4 Antiestancamiento:** HB13, sólo por inactividad observable.
- **D5 Columna inevitable.** Adair muere el 30; la indagatoria se abre el 2 y concluye el 4; Holmes vuelve el 5; Moran cae en Camden House; Lestrade se lleva el crédito.
- **D6 Nada reacciona a fracasos privados:** lotes fallidos, asientos, pares, cuaderno.
- **D7 Determinismo.** Semilla por partida; cada valor aleatorio es `hash([semilla, id_evento, día])`; orden de resolución fijo, por ID.
- **D8 Coherencia de actor.** Toda reacción tiene un actor que puede estar físicamente en ese lugar en esa fecha (test T12). Holmes no actúa en Londres antes del día 10: sus manos son Cotter, Wiggins y las notas que el Foreign Office comunica a los diarios.
- **D9 Fuentes únicas.** Ningún efecto puede cerrar un lugar, una franja, un canal o un actor que sea la única fuente de un fragmento I (extensión de T2).
- **D10 Secreto de Camden House.** Ningún sensor, presentación ni escena entrega etiquetas `secreto_camden` al Holmes-agente ni a Mycroft (T22).

### 9.9 Cómo se percibe sin que nadie lo explique

- **Anclas** (Nemesis): toda reacción contiene un detalle exacto del acto (asiento, frase, calle, hora), que también está en el diario. Única excepción documentada: HB3.
- **Dos voces con firma física.** La A es seca y perezosa, firma «Un amigo de la exactitud» y tarda siempre una noche. La B es precisa e irónica, firma «—S.», escribe en clave de corrector y tarda lo que mide la distancia; sale en la columna si contesta algo publicado y por carta si contesta algo privado. Las dos cartas salen de la misma Remington con la «s» alzada y la «t» pálida, sobre papel un centímetro más corto (se mide con la regla; mide lo mismo que el papel del Diógenes): la mano cercana transmite a la lejana.
- **El diario y el sello «Recibido»:** cruzar fechas de actos y de llegadas muestra la demora constante de A, la demora de B que se acorta, la tanda del martes, el miércoles mudo y la tanda del jueves.
- **Personas y sonido:** cuántos «sir» dice Mrs. Hudson, la gorra de Wiggins, el abrigo de cochero, el arpa de Parker, la ceniza de cheroot.
- **El silencio:** las líneas del diario que nunca recibieron respuesta.
- **Nada más:** ni sonido de alerta, ni registro de reacciones, ni medidor.

**Ejemplo, momento a momento.**
- *Martes 27, amanecer:* en el *Times*, entre un perro perdido y unas clases de dibujo, el aviso de testigos que Lisle redactó la noche anterior.
- *Martes 27, M:* Lisle pide el *Journal de Genève* en el asiento 214 y lo recorta.
- *Martes 27, T:* en el consultorio de Watson se despide con «La pared era a pique, ¿no, doctor?». Watson palidece. Esa noche le escribe a Mycroft.
- *Miércoles 28, amanecer:* entre la cuenta del sastre y el *Times*, un sobre sin remitente: «Asiento 214: los guías hablaron al Journal… Le ahorraré el trabajo: lea a Reuter.» El jugador abre su diario. ¿Por qué alguien querría que no leyera el *Journal*?
- *Viernes 30, amanecer:* en la columna, «AL LECTOR DE HOLYWELL STREET», alguien contesta el aviso del martes: «…los cuatro primeros hablaron en francés, y lo dijeron en Ginebra. —S.» En la bandeja, otro sobre a máquina, con otra firma: «"A pique": dele. Véase el Journal de Genève del 6 de mayo de 1891. —S.» Lisle le dijo «a pique» sólo a Watson. Tres días. Una mano lo aleja del *Journal* y la otra lo manda ahí.
- *Martes 3:* dos respuestas de «—S.» a la vez. *Miércoles 4:* nada. *Jueves 5:* tres respuestas juntas, cada una más rápida; a las 9:30, la respuesta entra en persona por la tienda de Crane.

Ningún sistema se lo explicó al jugador. Y la frase de EMPT [C] tiene aquí su origen dentro del mundo.

---

## 10. Grafo de pistas

### 10.1 Clases de fuente

| Clase | Qué incluye | Por qué ninguna reacción la toca (en el mundo) | Garantía en el motor |
|---|---|---|---|
| **I** inmutable | Lo impreso y distribuido (BM por depósito legal [H], el *Times*, la *Strand*, Kelly's, la *Gazette*, *The Lancet*, libros); los ejemplares de la **tienda de Crane** (no es canal y Moran sólo registra la buhardilla); registros públicos (índices de Somerset House, libro de telegramas de la portería, libro de ventas de Crane); **escenas y líneas de columna** declaradas inmutables (HC05, HC06, HC07, HC08, HC10, M6, M7, el exterior de los lugares, la línea del chico del agente, las láminas archivadas, las líneas del prólogo); el diario; los recortes del jugador | Nadie deshace el depósito legal ni 300.000 ejemplares. En este asunto Holmes no destruye (Ley 3). Moran no sabe de qué fragmentos depende el jugador. Las líneas de columna son de personajes que actúan por sí mismos (Mrs. Hudson chismea aunque le ordenen callar) | Test estático T2: ningún `efecto` de `reactions.json` apunta a un ítem I; D9: ningún efecto cierra la única fuente de un ítem I |
| **P** original en posesión | Galerada (D02), tomos (D01), concordancia (D21), cartas recibidas (D25, D26 por carta, D27, D28, HA0, HC01, HC04), notas de Pell (D23, D24), copias de Somerset House, precio a lápiz (D37) | Sólo M1 los toca, y sólo los que aparecieron en un informe. HB10 los devuelve **intactos** a la mañana siguiente (Ley 3) | Ausencia como máximo de un día. No cuentan como sólo-I |
| **C** de campo | Papeles de Watson (D29), libro de recibos de 221B (D30), libro de llaves (D32), líneas de Mrs. Hudson sobre el alquiler, testimonios de Wiggins | Las reacciones listadas en §9.6 y §9.7 | Cada corte figura en `corta[]`, tiene `variante_blanda` y deja rastro (ley de la huella, T5) |

**Ley de conservación de la huella** (NORW: «the knowledge of when to stop» [C]). Toda reacción **de Holmes** que corta una ruta agrega al menos un fragmento nuevo con etiquetas de C6, C7 u C8: un recibo «p.p. M. H.», más «sir», una carta. Holmes encarece el camino de «qué pasó» y, al hacerlo, abre el de «quién me lee». Toda reacción **de Moran** que corta agrega al menos un fragmento con etiquetas de C10 o C13: ceniza, una nota «H.», la línea del chico del agente. Moran limpia y, al limpiar, firma.

### 10.2 Orígenes para el fundamento

El fundamento exige **≥2 orígenes distintos** (§8.5). El origen es el **documento o la escena** de donde viene el texto, no el lugar donde se lo leyó: D03 recortado en Crane y en el BM es un solo origen. Las láminas heredan el origen del lugar y la visita; el diario y los pares heredan el origen de lo que copian; las líneas de diálogo tienen como origen su escena.

La línea de fuente de cada recorte muestra su tipo en palabras de época (esto es presentación, no regla): crónica, otra edición o prueba, prensa extranjera, prensa de Londres, registro, libro, papel privado o carta recibida, testimonio o escena, lugar u objeto, diario.

### 10.3 Invariante

**Definiciones.**
- Un **ejemplar** es un documento en un lugar (`D03@Crane`, `D03@BM`, `D03@tomo`) o una escena o lámina concreta. Las líneas del diario son ejemplares distintos (una por acto) y no pueden cortarse (T2).
- Una **ruta** es un conjunto de 2 a 4 fragmentos que cumple las condiciones 2 a 5 de §8.5 para su conclusión: cubre cada grupo en su línea, tiene ≥2 orígenes, todos sus fragmentos llevan etiquetas de la conclusión y están enlazados por claves.
- Una ruta está **intacta** en un estado si ninguno de sus fragmentos fue cortado por una reacción y cada uno está recortado o todavía es obtenible en las franjas que quedan (su lugar y su ventana siguen abiertos, o es un original P que vuelve al día siguiente).
- Una ruta es **sólo-I** (★) si todos sus fragmentos son de clase I.
- Una reacción es **garantizada por acto** si es determinista, su único disparador es un acto propio del jugador, no tiene otras condiciones y nada puede cortarla ni bloquearla antes de que llegue (ni HB9 ni HB11). Lista cerrada: HA1 (primera papeleta de un tema), HA3 (primera salida desde el día 3), HB1 en su primer cebo publicado en la columna (K-T) y la cita de actos de HC06 (b). T15 lo verifica.

**Invariante (test T3).** Para todo estado alcanzable y para toda conclusión obligatoria (C2–C13) sin sellar:
1. hay ≥2 rutas intactas;
2. al menos una es sólo-I;
3. las rutas usadas para cumplir 1 y 2 dependen sólo de la columna, de escenas fijas y de reacciones garantizadas por acto, nunca de reacciones opcionales;
4. **ningún ejemplar ni escena aparece en todas** las rutas usadas en 1 (conectividad de vértices ≥2), salvo las líneas del diario.

**Por qué se cumple.** Toda conclusión obligatoria tiene **≥2 rutas sólo-I** sin un ejemplar común a todas (tablas de §10.4), y ninguna reacción toca I (T2) ni cierra su única fuente (D9). Lo único que puede vencer una ruta sólo-I es que el jugador deje pasar su ventana, y eso no es un corte. Aun así, T3 exige que hasta el día 8 inclusive cada conclusión tenga ≥2 rutas completables con las franjas que quedan.

**Cómo se verifica sin explosión combinatoria (T3).** Un recorrido literal de todos los informes y disparos tiene unos 10²⁵ estados. Se acota así:
1. Cada efecto se clasifica en datos como `corta{fragmentos|acceso, ventana}` o `agrega`. Por la condición 3, los `agrega` no afectan la invariante, que es anti-monótona en los cortes.
2. Peor caso del jugador: no recortó nada todavía.
3. Descomposición por conclusión: cada una depende de k ≤ 5 cortes relevantes. Se enumeran los 2^k subconjuntos de cortes, cada uno en su día más temprano y más tardío, con el diferimiento de D2 incluido (menos de 10⁴ estados por conclusión, exacto). Como control, se prueba también la unión de todos los cortes.
4. Factibilidad global: programación dinámica sobre (franja, máscara de las 12 conclusiones) × 8 lugares, con 3 papeletas por visita y 3 preguntas por personaje (unos 820.000 pasos).
5. *Fuzzing* sembrado de unas 10.000 partidas con actos públicos al azar, verificadas con el mismo código de D1.
Se modelan como recursos la tarjeta HC04, la consulta de Watson cerrada, la Sala de Forasteros cerrada y el chico del agente.

### 10.4 Tablas por conclusión

Formato: **Plantilla y respuestas válidas** · **Grupos → línea que sostienen** · **Claves** (entidades que enlazan el fundamento) · rutas. ★ = ruta sólo-I que garantiza la invariante. «Desde» indica cuándo puede completarse.

#### C1 (tutorial, no obligatoria): errata inocente de Watson

T1. Cada par es un asiento propio, que se practica aparte (§8.5). Basta con **dos pasajes distintos**, aunque sean del mismo documento. Grupos: `inc_a` → [Fuente A · Dice] · `inc_b` → [Fuente B · Dice]. Clave: la entidad en disputa (herida, nombre, fecha).

| Par | Fuente A | Fuente B | Etiqueta |
|---|---|---|---|
| INC-01 | STUD cap. 1, «hombro» (D43) | SIGN cap. 1, «pierna» (D44) | `inc01` |
| INC-02 | STUD, «John H. Watson» (D43) | TWIS, «James» (D01, BM) | `inc02` |
| INC-03 | SPEC, Mrs. Hudson (D01, BM) | SCAN, «Mrs. Turner» (D01, BM) | `inc03` |
| INC-06 | SCAN, casado en marzo de 1888 (D01, BM) | SIGN, conoce a Mary en 1888 (D44) | `inc06` |
| INC-07 | FIVE, «visita a su madre» (1887) (D01, BM) | SIGN, «my mother was dead» (D44) | `inc07` |
| INC-08 | FIVE, «una mujer» (1887) (D01, BM) | SCAN, 1888 (D01, BM) | `inc08` |
| INC-09 | SIGN cap. 2, «July 7» (D44) | SIGN cap. 3, «September evening» (D44) | `inc09` |
| INC-10 | REDH, 27 de abril más ocho semanas (D01, BM) | REDH, 9 de octubre (D01, BM) | `inc10` |

Los pares de STUD y SIGN están en D43 y D44 (Crane y BM), no en los tomos. INC-03, 08 y 10 están enteros en los tomos (P) y en el BM (I). INC-10 es el par del tutorial (marcado en D21). Nada los corta (Ley 7). Test: cada par listado pasa el validador de práctica.

#### C2: FINA impreso calla la raspadura de la roca

T2. Fuente: FINA (impreso) · Calla: **la raspadura** (vale «la marca en la roca») · Consta en: cualquiera de {galerada, pruebas americanas canceladas, *Journal de Genève*, pruebas de Watson, nota de Watson en su tomo}.
Grupos: `fina_impreso_sin_raspadura` (D03, «sheer wall») → [Fuente · Calla] · `raspadura_registrada` → [Consta en]. Claves: FINA, Reichenbach, roca, raspadura.

| Ruta | Fragmentos (ejemplar) | Clases | Desde | Lo puede cortar |
|---|---|---|---|---|
| C2.R1 | D02 cláusula (L1, cajón) + D03 «sheer wall» | P + I | Prólogo (si se encuentra la galerada) | M1 (un día; HB10 la devuelve) |
| **C2.R2 ★** | D05 «une marque récente» (L2) + D03@Crane | I + I | Día 1 | Nada |
| **C2.R3 ★** | D04 cláusula de las pruebas americanas (L1, Crane) + D03@BM | I + I | Día 1 | Nada |
| C2.R4 | D29a pruebas de Watson (L4) + D03 | C + I | Día 1 | HB5 (definitivo), HB4 (2 días, la segunda vez) |
| C2.R5 | D01 nota «suprimido a pedido del F.O. — la raspadura — pase. J.» (L1) + D03 | P + I | Prólogo | M1 (un día) |

Garantía: R2 y R3 son sólo-I y no comparten ejemplar.

#### C3: Reichenbach tenía salida

T1 (sólo errata; así no se confunde con C2). Fuente A: FINA · Dice: «a pique» · Fuente B: X · Dice: **una cornisa en la pared, sobre el sendero** (vale «una cornisa»).
Grupos: `fina_a_pique` (D03) → [Fuente A · Dice] · `cornisa_existe` → [Fuente B · Dice]. Claves: Reichenbach, pared, sendero, cornisa.

| Ruta | Fragmentos | Clases | Desde | Corte |
|---|---|---|---|---|
| **C3.R1 ★** | D05 «plus haut, une corniche que l'on ne voit pas du sentier» + D03@Crane | I + I | Día 1 | — |
| **C3.R2 ★** | D07 fotografía desde la otra orilla (Crane) + D03@BM | I + I | Día 1 (la tienda está cerrada la noche del prólogo) | — |
| **C3.R3 ★** | D08 guía de Suiza (L2) + D03@Crane | I + I | Día 1 | — |
| C3.R4 | D27 telegrama de Steiler + D03 | P + I | Día siguiente a telegrafiar | M1 (un día) |
| Apoyo | HC01 «No lo es.», HC10 (remite al *Journal*) | P / I | — | No cubren `cornisa_existe` |

#### C4: Holmes dispuso de sus bienes en vida, ante una muerte probable

T5. Persona: Sherlock Holmes · Hizo: **ceder** · Qué: **sus bienes** · A: **Mycroft Holmes** · Cuándo: **en vida** (vale «antes de partir», «antes del 4 de mayo de 1891»). No hay ninguna respuesta válida que hable de preparar una desaparición: según EMPT la idea fue del momento.
Grupos: `bienes_a_mycroft` (D03, carta de Reichenbach) → [Persona · Hizo · Qué] y [A] · `en_vida` (ninguna sucesión ni aviso a acreedores a su nombre; alquiler pagado sin pausa por Mycroft; «as arranged») → [Cuándo]. Claves: Holmes, Mycroft, bienes.

| Ruta | Fragmentos | Clases | Desde | Corte |
|---|---|---|---|---|
| **C4.R1 ★** | D03@Crane «handed it to my brother Mycroft» + D18, página de *calendars* sin ningún Sherlock (L6) | I + I | Día 1 | — |
| **C4.R2 ★** | D03@BM + D19, índice de la *Gazette* sin aviso a nombre de Holmes (L2) | I + I | Día 1 | — |
| C4.R3 | D03 + D30 recibos «por cuenta del Sr. M. Holmes» (L3) | I + C | Día 1 | HB6 (desde la 2.ª visita) |
| C4.R4 | D03 + D29b surcos «My dear Mycroft — as arranged —» (L4, luz rasante) | I + C | Día 1; el domingo Watson la muestra sin pedirla | HB4 (2 días, la segunda vez) |
| C4.R5 | D03 + línea de Mrs. Hudson: «el señor Mycroft paga y manda no tocar nada» | I + C | Día 1 | HB6 |

#### C5: las cartas del coronel las pulió Sebastian Moran

T4. Documento: cartas del coronel James Moriarty · Lo redactó: **Sebastian Moran** (vale «el autor de *Heavy Game*»; «el mayor Harris» bajo la regla de alias de C10a).
Grupos: `estilo_cartas_coronel` (frases de D09) → [Documento] · `estilo_o_rostro_moran` (D10, D11) → [Lo redactó]. Claves: tigre, desagüe, cruel, bigote, cazador.

| Ruta | Fragmentos | Clases | Desde | Corte |
|---|---|---|---|---|
| **C5.R1 ★** | D09@BM, carta del 9-oct, «como se sigue a un tigre herido por el desagüe» + D11@BM, la misma frase | I + I | Día 1 | — |
| **C5.R2 ★** | D09@Crane, carta del 23-oct, «cruel, cruel» + D10@Crane, la misma frase | I + I | Día 1 | — |
| C5.R3 | D28 «un amigo del Anglo-Indian, cazador, me pulió las cartas» + D10 portada «coronel Sebastian Moran» (cazador) | P + I | Día 3 (dos días después de escribir a Bath) | M1 (un día) |
| **C5.R4 ★** | D09@BM, nota del redactor «bigote canoso» + D10@BM, frontispicio (retrato del autor) | I + I | Día 1 | — |

Ningún ejemplar aparece en las tres rutas ★ (D09 y D10 tienen ejemplares en el BM y en Crane).

#### C6: me leen por dos canales concretos

T6. Persona: **Sherlock Holmes** (valen también Mycroft Holmes y «S.») · Relación: **lee a** · A quién: **yo** (Lisle) · Por medio de: X · Y de: Y, con X ≠ Y en la lista cerrada de medios (§8.2). Se aceptan los diez pares.
Grupos, por cada medio nombrado: `acto_<canal>` (línea del diario) + `ancla_<canal>` (fragmento que cita ese acto) → la línea de ese medio. Claves: el detalle del acto (n.º de asiento, frase, calle, hora, texto del anuncio). Una ruta es un **par de subrutas** de canal (hasta 4 recortes).

| Subruta | Fragmentos | Clases | Tipo | Desde | Corte |
|---|---|---|---|---|---|
| **K-S ★** | D36 salida (día ≥3) + silueta de Wiggins en la lámina de ese lugar y franja (HC02) | I + I | columna | Día 3 | Nada: HB8b cambia de muchacho pero el canal sigue |
| **K-T ★** | D15 el aviso de testigos (día 1) + HC10 en la columna (día 4) | I + I | columna | Día 4 | Nada |
| K-T' ★ | D15 un anuncio-cebo propio + HB1 en la columna que lo cita | I + I | garantizada por acto | 3–4 días después de publicar | Nada |
| K-BM ★ | D36 «asiento 214» + HC06 (b) que lo cita | I + I | columna | Día 8 | — |
| K-BM | D36 + carta HA1 que cita el asiento | I + P | garantizada por acto | Día 2 | M1 (un día) |
| K-W ★ | D36 «le dije al doctor…» + HC06 (b) | I + I | columna | Día 8 | — |
| K-W | D36 + carta «—S.» (HB1) o de voz A (HB4) | I + P | opcional | Día 4 | M1 (un día) |
| K-H ★ | D36 visita a 221B + HC06 (b) | I + I | columna | Día 8 | — |
| K-H | D36 + línea «órdenes del empleado…» (HB6) o carta de voz A | I + C/P | opcional | Día 2 | HB11 |

Garantía (T1 específico de C6): hay al menos dos pares sólo-I que difieren en una subruta y no comparten ejemplar salvo líneas del diario: {K-S, K-T} desde el día 4 (sólo columna, más cualquier salida desde el día 3) y {K-T, K-x vía HC06 (b)} desde el día 8, para cualquier canal x que Lisle haya usado. «La calle» entra al índice con el primer recorte de la silueta (epígrafe «muchacho de gorra, calle») o con HA3.

#### C7: la mano que me escribe a máquina obedece a Mycroft Holmes

T4. Documento: las cartas a máquina · Lo redactó: **Mycroft Holmes**.
Grupos: `me_vigila_de_cerca` (alguien cercano conoce mis actos observados: cartas de voz A, HC06 (b), Cotter junto a la canastilla, el sobre de HC01) → [Documento] · `vinculo_mycroft` (lo que ata esa mano a Mycroft: papel o membrete del Diógenes, GREE, D31 «para Mr. M. Holmes», tarjeta HC04, recibo «p.p. M. H.», línea de Wiggins, el giro «Le ahorraré el trabajo») → [Lo redactó]. Claves: Diógenes, Pall Mall, Mycroft, asiento, Remington.

| Ruta | Fragmentos | Clases | Desde | Corte |
|---|---|---|---|---|
| C7.R1 | D25 carta (papel un centímetro más corto, tipos) + papel del club medido en HC06 (f), o tarjeta HC04 | P + I/P | Día 8 | M1 (un día) |
| **C7.R2 ★** | HC06 (b): Mycroft cita mis actos con fecha y asiento + D31 «para Mr. M. Holmes» (portería) | I + I | Día 8 | — |
| C7.R3 | D25 o HA0 + D30 recibos tecleados con la misma Remington | P + C | Día 2 | HB6; M1 |
| **C7.R4 ★** | Lámina de L2: nodo «Cotter junto a la canastilla» + nodo «cesto con tiras …GENES CLUB · PALL MALL…» + GREE@BM: Mycroft, «one of the founders» del Diógenes, vive en Pall Mall [C] | I + I | Día 1 | — |
| C7.R5 | Watson: «le escribí al señor Mycroft, como cuando lo de las pruebas», o recibo «p.p. M. H.» (HB5) + carta «—S.» que cita palabras dichas sólo a Watson | C + P | Día 4 | HB4 (2 días) |
| C7.R6 | Sobre de HC01, matasellos S.W. + GREE: Mycroft vive en Pall Mall, frente al club [C] | P + I | Día 1 | M1 (un día) |
| C7.R7 | Wiggins: «el que la manda no camina más que de Pall Mall a Whitehall» (HB8) + GREE: «walks round the corner into Whitehall every morning» [C] | C + I | Día 3 | HB8b |
| C7.R8 | HA1 o HA0 «Le ahorraré el trabajo» + HC06 (a), el mismo giro en boca de Mycroft | P + I | Día 8 | M1 (un día) |

#### C8: Sherlock Holmes vive

T7. Persona: Sherlock Holmes · En marzo de 1894: **vivo**.
Grupos: `identidad_holmes` (algo que ata una actividad concreta a Holmes) → [Persona] · `actividad_posterior_a_mayo_1891` → [Estado]. Claves: monografía de cenizas (n.º 97), opúsculo de los oficios y la mano, Mr. M. Holmes, letra.

| Ruta | Fragmentos | Clases | Desde | Corte |
|---|---|---|---|---|
| **C8.R1 ★** | D13, despacho de Sigerson (1892–93): «la muestra que faltaba al n.º 97 de cierta clasificación inglesa de cenizas» + D12, monografía del BM: «n.º 97: té en ladrillo — sin muestra», dedicada «S. H.» | I + I | Día 1 | — |
| **C8.R2 ★** | D14, carta «S. S.» (feb. 1894, sin ciudad): «una lámina más de cierto opúsculo sobre la influencia de los oficios en la forma de la mano» + D44, SIGN cap. 1: «a curious little work upon the influence of a trade upon the form of the hand» [C] (Crane o BM) | I + I | Día 1 | — |
| **C8.R3 ★** | HC06 (c): «Mi hermano detesta… Detestaba.» + D31: telegramas de 1894 desde Montpellier, Grenoble y París «para Mr. M. Holmes» | I + I | Día 8 | — |
| C8.R4 | HC01 «No lo es.» (letra) + D12 dedicatoria «S. H.» (letra) | P + I | Día 1 | M1 (un día) |
| Apoyo | D13, nota de 1893 «Sigerson en Jartum» + D34 o D35 (el Califa en Omdurmán): el paradero de Sigerson es fabricado | I + I | Día 1 | No cubre `identidad_holmes` |

Ningún documento público da el paradero de Holmes en 1894: D14 no tiene ciudad, D31 está en la portería del Diógenes y Moran no cruza fuentes (T7).

#### C9: Holmes vuelve a Baker Street el jueves 5

T8. Persona: Sherlock Holmes · Lugar: **Baker Street** (vale 221B) · Día: **jueves 5 de abril** (vale «el jueves»: el motor lo resuelve al jueves siguiente, el 5).
Grupos: `preparativos_221b` → [Lugar] · `dia_jueves` → [Día]. La línea [Persona] sólo pide un «según» cualquiera de la conclusión. Claves: jueves, 221B, Mycroft.

| Ruta | Fragmentos | Clases | Desde | Corte |
|---|---|---|---|---|
| **C9.R1 ★** | HC05, tramo de Mrs. Hudson «para el jueves, sir» + exterior de 221B, día ≥8: ventanas del primer piso abiertas, el *shag* | I + I | Día 8 | — (HB6 no lo corta) |
| **C9.R2 ★** | HC06 (e): «El jueves no estaré en el club. Un compromiso de familia.» + lámina del vestíbulo de 221B, día 9 T: cajón «pour M. Mycroft Holmes, 221B Baker Street» | I + I | Día 9 T | — |
| C9.R3 | D36 y sellos «Recibido» + fechas de las respuestas de voz B (3 → 4 → tanda del martes → miércoles mudo → tanda del jueves) | I + I | Día 10 M | — (depende de disparos: no cuenta) |
| C9.R5 | Mrs. Hudson (HC05) + D31, Montpellier → Grenoble → París | I + I | Día 8 | — (apoyo: D31 no cubre `preparativos_221b`) |

C9.R4 (coche del club, vía Wiggins) se eliminó: Wiggins sólo acepta encargos contra Moran.

#### C10: quien me paga es Moran y me usa como cebo para hallar a Holmes

T9. Persona: **Sebastian Moran** (vale «el mayor Harris» bajo la regla de alias de C10a) · Usa a: **yo** · Como: **cebo** (vale «cabrito», «cabrito atado») · Para: **hallar** · A quién: **Sherlock Holmes**.
Grupos: `harris_es_moran` → [Persona] · `cebo` → [Usa a · Como] · `busca_a_holmes` → [Para · A quién]. Fundamento de hasta 4 recortes. Claves: Harris, Moran, bigote, cabrito, dónde.

Subrutas de identidad (`harris_es_moran`):
- **Ia ★** lámina del prólogo (Harris) + D16 grabado del «coronel Moran» (I + I, día 8).
- **Ib ★** M7, la visita de Harris (adjetivos repetidos, «la forma debida») + D10@Crane, los adjetivos repetidos de Moran (I + I, día 7).
- Ic: D23, párrafo dictado («cruel, cruel») + D10 (P + I, prólogo).
- Id: Wiggins sigue al chico de Pell (o a Parker desde la lista de correos) hasta Conduit Street + D17 «Moran, Col. S., Conduit St.» (C + I, día 3; cortable por HB8b).

Subrutas de propósito (`cebo` y `busca_a_holmes`):
- **Ca ★** D10@BM cap. «Del cabrito atado» + M6, Pell: «Pregunta dónde» (I + I, día 5).
- **Cb ★** D11 «un cabrito que no bala no atrae a nadie» + M7: «No me diga que vive. Dígame dónde duerme el tigre.» (I + I, día 7).
- Cc: HB7 «no es el único» + D10 (opcional).
- Cd: M2 el ladrillo, o HB9, + D11 «hay que hacerlo balar» (opcional).

| Ruta | Composición | Clases | Desde | Corte |
|---|---|---|---|---|
| **C10.R1 ★** | Ia + Ca: lámina del prólogo, D16, D10@BM, M6 | I | Día 8 | — |
| **C10.R2 ★** | Ib + Cb: M7, D10@Crane, D11, M7 | I | Día 7 | — |
| C10.R3 | Ic + Ca | P + I | Día 5 | M1 (un día) |
| C10.R4 | Id + Cb | C + I | Día 7 | HB8b; M4 (variante blanda: seguir a Parker) |

R1 y R2 no comparten ejemplar. Bajo M4, M6 llega como nota «H.» con la misma línea y las mismas etiquetas, y R1 se mantiene.

**C10a (opcional, auxiliar): «Harris es, en verdad, Sebastian Moran».** T3. Grupos: `harris` → [Persona] · `moran` → [Es, en verdad]. Rutas: las subrutas Ia, Ib, Ic e Id. **Regla de alias uniforme:** desde que C10a está sellada, «el mayor Harris» y «Sebastian Moran» valen igual en cualquier campo y como clave. Sin C10a, sólo valen donde la conclusión lo dice.

#### C11: Moran mató a Adair con un fusil de aire, desde la calle

T5. Persona: **Sebastian Moran** · Hizo: **matar** · A: **Ronald Adair** · Con: **un fusil de aire** (vale «arma de aire comprimido») · Dónde: **desde la calle** (vale «desde fuera, por la ventana abierta»). El móvil **no se valida**: es hipótesis abierta («yours is as likely to be correct as mine» [C]).
Grupos: `autor_moran` (compañero de whist, las £420, el mejor tiro, la bala blanda) → [Persona · Hizo · A] · `arma_de_aire` → [Con] · `disparo_desde_fuera` (nadie oyó, ventana abierta, 20 pies, azafranes intactos) → [Dónde]. Claves: Adair, Moran, disparo, bala, fusil de aire, Park Lane (el tramo «Of air-guns» de D03 lleva las entidades «fusil de aire» y «disparo»).

| Ruta | Fragmentos | Clases | Desde | Corte |
|---|---|---|---|---|
| **C11.R1 ★** | D15 mar. 3 (dos recortes: «coronel Moran, compañero de whist»; «nadie oyó el disparo… ventana abierta») + D03@BM «air-guns» + D10@BM «la bala blanda se abre dentro de la bestia» | I | Día 8 | — |
| **C11.R2 ★** | L7, nodo «línea de tiro» desde la calle hasta la ventana + D11 «el mejor tiro de la India» + D16 «coronel Moran», testigo de la indagatoria + D03@Crane «air-guns» | I | Día 8 (L7 desde el día 5) | — |

#### C12: el librero viejo es Sherlock Holmes

T3. Persona: **el librero** (vale «el anciano de la tienda de Crane») · Es, en verdad: **Sherlock Holmes**. Se valida sólo en el libro mayor (lote de 1 del día 10, antes de las 12 h). La afirmación 4 de la confrontación es otra cosa (§8.8) y alimenta el epílogo.
Grupos: `librero_falso` (no hay librería en esa esquina; estatura escondida) → [Persona] · `rasgo_holmes` (dedos amarillos de alquitrán, letra de Holmes) → [Es, en verdad]. Claves: librero, Church Street, letra, amarillo.

| Ruta | Fragmentos | Clases | Desde | Corte |
|---|---|---|---|---|
| **C12.R1 ★** | HC07 nodo «dedos manchados de amarillo» + D14 «mancha la piel de amarillo durante semanas» + HC07 nodo «la sombra llega al techo» | I + I | Día 10 M | — |
| C12.R2 | HC08 *Tree Worship* + D33 «un anciano… *The Origin of Tree Worship*» | I + I | Día 10 T | — (sólo epílogo: llega después de las 12 h) |
| **C12.R3 ★** | D33 dirección de gremio «de su puño»: «esquina de Church Street, Kensington» + D17, ninguna librería en esa esquina + D12 dedicatoria «S. H.» (la misma letra) | I + I | Día 10 M | — |
| C12.R4 | D37 precio a lápiz + D12 dedicatoria «S. H.» + HC07 nodo «sombra» | P + I | Día 10 M | — |

R1 y R3 no comparten ejemplar. Sólo puede resolverse el día 10; por eso **no** es requisito del mejor final (J3).

#### C13: el tigre disparará contra 221B desde Camden House

T5. Persona: **Sebastian Moran** (vale «el mayor Harris») · Hizo: **disparar** · Contra: **221B** (vale «la ventana de Holmes», «Sherlock Holmes») · Dónde: **Camden House** (vale «la casa vacía de enfrente»). Se valida sólo en el libro mayor, antes de las 12 h del día 10. Todo lo que sostiene esta conclusión lleva además la marca `secreto_camden` y no llega al bando de Holmes (D10, T22).
Grupos: `tirador` (quién y cómo tira: D10, M7, la línea del prólogo) → [Persona · Hizo · Contra] · `escondite_preparado` (sólo L8, la línea del chico del agente o D32; el cartel «Se alquila» **no** lo lleva) → [Dónde]. Claves: Camden House, Harris, Moran, cheroot, 221B.

| Ruta | Fragmentos | Clases | Desde | Corte |
|---|---|---|---|---|
| **C13.R1 ★** | L8 nodo «guillotina engrasada» + L8 nodo «ceniza de cheroot» + M7: «¿Le molesta el humo? Es de Trichinópolis.» (lámina con la misma ceniza) | I + I | Día 7 N | — |
| **C13.R2 ★** | Chico del agente (L3, día ≥7): «La casa de enfrente la anda viendo un militar, el mayor Harris; se llevó una llave el lunes» + línea de Harris en el prólogo: «Cacé en la India, señor. Allí se aprende a esperar arriba, donde se domina el claro.» (enlazadas por «Harris»; D10@BM, «apostarse en el árbol que domine al cebo», puede sumarse como tercer recorte) | I + I | Día 7 | Nada: M5 arranca la página de D32, no la memoria del chico |
| C13.R3 | D32 «llave prestada al mayor Harris, 2-abr.» + lámina del prólogo (Harris) | C + I | Día 7 | M5 |
| C13.R5 | M10 «El mayor celebra su diligencia en Baker Street» + D10 | I + I | Día 5 | — (opcional) |

C13.R4 (Wiggins vigila Camden House) se eliminó: nadie del bando de Holmes mira esa casa.

#### C14 (opcional, íntima): los tomos eran de Watson, y el hueco del estante

T5. Persona: John H. Watson · Hizo: **separarse de** · Qué: **los tomos** (vols. II–VI) · Dónde: **la subasta de Paddington** · Cuándo: **tras la muerte de Mary** (vale «enero de 1894»).
Grupos: `tomos_de_watson` → [Persona · Hizo · Qué] y [Dónde] · `duelo` → [Cuándo]. Claves: Watson, Paddington, tomos, Mary.

| Ruta | Fragmentos | Clases | Desde | Corte |
|---|---|---|---|---|
| C14.R1 | D01 notas «mi James», «nov. 93 — junto a ella» + D18 defunción de Mary ⚠ | P + I | Día 1 | M1 (un día) |
| **C14.R2 ★** | D20 subasta de un consultorio de Paddington con los vols. II–VI + D45 *The Lancet*: «tras su reciente duelo, ha trasladado su consulta de Paddington a Kensington» | I + I | Día 1 | — |
| C14.R3 | L4 el hueco del segundo estante y el crespón + D01 | C + P | Día 1 | HB4 (2 días, la segunda vez) |

El Kelly's de 1894 (D17), compilado en 1893, todavía dice «Paddington»: refuerza que la mudanza es reciente.

### 10.5 Pistas falsas y refutaciones (R9)

Ninguna refutación se apoya en un dato ⚠.

| Pista falsa | Origen | Refutación 1 | Refutación 2 |
|---|---|---|---|
| «El muchacho suizo se llevó el bastón» | HB2 (pared) | D03, «Alpine-stock still leaning against the rock» [C] | D05, «le bâton ferré appuyé contre le rocher» |
| «El río devolvió un cuerpo en junio» | HB2 (cayeron) | D03, «Any attempt at recovering the bodies was absolutely hopeless» [C] (escrito en 1893) | D19, aviso por los bienes del profesor «cuya muerte se presume» |
| «La nota la escribió el posadero» | HB2 (carta) | D03, Steiler: «Certainly not!… it must have been written by that tall Englishman» [C] | D27, «PADRE NO ESCRIBIO NOTA ALGUNA» |
| «El hermano reclamó la herencia en 1892» | HB2 (testamento) | D18, ninguna sucesión a nombre de Sherlock Holmes 1891–93 | D19, ningún aviso a acreedores a su nombre |
| «El doctor tachó la frase por su cuenta» | HB2 (Watson) | D04, nota del cajista: «Rehacer la pág. por orden recibida el 14-xi (F.O.)» | D01, nota de Watson: «suprimido a pedido del F.O.» (o D29a, «a pedido del F.O. — M. H.») |
| «Sigerson en Jartum, huésped del Califa» | D13 (nota de 1893, fija) y HB3 | D34, Ohrwalder (1892): «Shortly after my visit, Khartum was reduced to ruins»; Omdurmán, «the Mahdiist capital» [H] | D35, notas del Sudán en el *Times*: el Califa en Omdurmán |
| «Lea a Reuter»: tres fuentes que son una | HA1 | D05 contiene lo que D06 omite | D07 o D08, la cornisa |
| Park Lane fue obra de anarquistas (prensa de época) | D15 | Nada falta en la casa y el dinero quedó en pilas (D15, indagatoria) | Nadie oyó el disparo; ventana a 20 pies con azafranes intactos (L7) |
| Meunier, el anarquista detenido en Victoria (jue. 5) | D15 | Etiqueta del cajón: «O. Meunier, mouleur, Grenoble — cire» (HC05) | D15: «Théodule Meunier, ebanista, detenido en Victoria el 4» [H] |

### 10.6 Tests del grafo (runner propio, *headless*)

- **T1** Para toda conclusión obligatoria: ≥2 rutas sólo-I sin un ejemplar ni una escena común a todas (salvo líneas del diario); cada ruta con ≥2 orígenes, enlazada por claves y con su «Desde» anterior a la última pasada posible para esa conclusión. Para C6: ≥2 pares sólo-I que difieren en una subruta.
- **T2** Estático: ningún efecto de reacción apunta a un ítem I, y ningún efecto cierra la única fuente de un ítem I (D9).
- **T3** Verificador acotado de la invariante (§10.3: peor caso, descomposición por conclusión, factibilidad global y *fuzzing*); hasta el día 8 hay ≥2 rutas completables en las franjas restantes.
- **T4** Sobre los **recortes legales máximos** (cada oración de ≤40 palabras de cada documento, escena, lámina y día del diario; cada par de nodos de cada diorama): ningún recorte legal cubre todos los grupos de una conclusión.
- **T5** Ley de la huella: toda reacción de Holmes con `corta[]` no vacío agrega etiquetas de C6, C7 u C8; toda reacción de Moran que corta agrega etiquetas de C10 o C13. **T5'** deriva los cortes comparando alcanzabilidad con y sin cada reacción y falla si alguno no figura en `corta[]`. HB11 sólo puede dispararse con ≥2 reacciones del canal ya obtenidas.
- **T17** Toda pista falsa tiene ≥2 refutaciones alcanzables, y ninguna es ⚠.
- **T22** Secreto de Camden House: ninguna etiqueta `secreto_camden` llega al Holmes-agente ni a Mycroft por ningún canal, presentación o escena.

---

## 11. Justificación de las reglas y estrategias degeneradas

Cada regla responde a una línea de `design.md`: no hay estrategia que salga más barata que deducir; Holmes nunca puede cerrar una conclusión; todo tiene base de época o de canon.

| Tentación | Por qué tienta | Contramedida | Fundamento | Resultado |
|---|---|---|---|---|
| Probar combinaciones en el libro mayor | Hay *feedback* | Lote de 2 cuyo tamaño sólo baja por calendario; conclusiones distintas y sin sellar; sin *feedback* por asiento; fundamento por línea con ≥2 orígenes y claves; una pasada por franja; los finales dependen de compromisos | Obra Dinn; §8.9 | Pescar sin pruebas: ~10⁻¹⁰ por lote. Con pruebas, es verificar, y cuesta franjas |
| Borrar asientos para obtener lotes de 1 | Feedback por asiento | El tamaño del lote no depende del inventario (§8.5) | J1, J3 | Cerrado |
| Rellenar el lote con asientos seguros | Aislar una hipótesis | Los dos asientos deben ser de conclusiones **distintas y no selladas**; C1 se practica aparte; el compañero seguro se consume si el lote pasa | Obra Dinn | Cuesta una conclusión y una franja por prueba |
| Recortar todo | Nada está marcado | Permitido. Un recorte toma afirmaciones de un solo tramo o nodo, con tope de una oración y 40 palabras, o de 1/8 de pantalla; el fundamento admite 4 recortes, todos pertinentes y enlazados. Hay búsqueda y filtros | Golden Idol, Roottrees | Sólo ruido propio |
| Guardar, provocar y recargar | Deshacer un error caro | Guardado por compromiso: cada acto se escribe a disco antes de mostrar su resultado (§7.6); reacciones deterministas | Undertale; R16 | Sin ventaja (T25) |
| Cebar a Holmes sin parar | Cada corrección informa | Ley 2: dos correcciones verdaderas que remiten a una fuente (no dan el valor), una falsa y después silencio, por tema. Un anuncio por día. Moran lee la columna (M8, M11) | Vanidad canónica; SpyParty | La tercera respuesta engaña; el tigre empieza a seguir al cabrito |
| Probar canales con canarios | Confirma la vigilancia | El canario es un dato falso sobre Lisle mismo (no un cebo): funciona una vez (HA4); la segunda, HB11 cierra el canal | Hitman; B | Legítimo, con límite |
| No hacer nada para no ser leído | Evita exponerse | HB13 empuja; la columna avanza; con menos de 6 asientos sellados, F4 | Alexandrian; Alien | No existe «no ser leído» |
| Ir a todas partes cada día | Exhaustividad | 25 franjas; HA3 cita el itinerario (también lo ve el tigre si se informa o desde M11) | Pentiment | Elegir es parte del juego |
| Preguntar todo a todos | Barrido de aventura gráfica | 3 preguntas por personaje y visita, con la frase visible antes; Watson avisa antes de cerrar | Ace Attorney | Preguntar es decidir |
| Usar a Crane como clasificador | Presentarle es gratis | Crane responde por propiedades visibles (documento, entidades), nunca por etiquetas ocultas (T20b) | — | Sólo comentario de librero |
| Investigar sólo en la Sala de Lectura | Sus fuentes son I | La Sala está vigilada (K-BM); 3 papeletas por visita; hay que saber qué pedir (el catálogo mezcla ruido). C9 y C13 piden lugares de campo | Her Story | Estilo válido, no atajo: igual provoca a Holmes |
| Contarle todo al patrón | Parece cumplir el encargo | M1 a M5: registro, ladrillo, Watson vigilado (aviso y después bloqueo de F1), Pell despedido, página arrancada; F2 | Orwell; Shadows of Doubt | Siempre peor que deducir |
| No informar nada | Esconderse | M7 «un cabrito mudo no me sirve»; sin crédito ante Moran no hay F1; F3 | Fallar hacia adelante | Sin *game over* |
| Mentirle siempre a Moran | Proteger a Holmes | Parker verifica lo verificable (M9, pierde el crédito). Mentir con lo inverificable es legítimo | SpyParty | Riesgo que se aprende |
| Ir directo a F1 con tres salidas | Atajo | F1 exige ≥8 conclusiones selladas, C6, C7 y C10, crédito ante Moran y no haber entregado a Holmes | J1 | Hay que investigar Reichenbach y el regreso |
| Presentar al azar ante Mycroft | Respuesta inmediata | Sólo vale un asiento sellado; un error tolerado, el segundo cierra la Sala | Ace Attorney | Caro |
| Mostrarlo todo en la confrontación | Fuerza bruta | Un grupo refutador por afirmación; tres errores y el librero se va, sin repetición; callar no cuesta | Ace Attorney | Caro |
| Usar a Wiggins para engañar a Holmes | Engañar es barato | La segunda vez, HB8b | A | Funciona una vez |
| Decirle a Watson que Holmes vive | Ganar un aliado | No le cree (canon); avisa y, a la segunda, cierra la consulta (HB4) | EMPT | Pierde dos días de Watson |
| Leer la gramática de la plantilla | Fugas lingüísticas | Forma «Campo: ___»; plantillas sin presuposiciones; listas cerradas iguales para todas las conclusiones; test T6 | Golden Idol | Cerrado |
| Leer el crecimiento del índice | Oráculo de relevancia | Todo recorte agrega entidades, también las de ruido | — | Cerrado |
| Usar las reacciones como oráculo | La reacción es pista | Dicen qué teme Holmes y por dónde mira, nunca el valor de un asiento; señalan fuentes, no hechos; HB2 y HB3 son falsas; HA1 desvía | §9.4 | Hay que cotejarlas |

---

## 12. Finales

Todos comparten la noche canónica: Moran dispara contra el busto desde Camden House, lo arrestan, Lestrade se lleva el crédito y Watson se entera esa tarde. Nada se publica antes de 1903. Cambian el informe de Lisle, lo que Holmes piensa de él y el epílogo.

### 12.1 Condiciones (se evalúan en este orden a las 12 h del día 10, con lo sellado hasta el informe final)

| Final | Condición | Qué ocurre | Ficha «L» del índice de Holmes |
|---|---|---|---|
| **F1 «Al menos un lector»** | C6, C7 y C10 sellados **y** al menos 8 conclusiones de C2–C13 selladas **y** el informe final es la **errata a medida** (ofrecida por Mycroft en HB12 o por el librero al completar la confrontación) **y** no `watson_expuesto` **y** Lisle tiene **crédito ante Moran** (algún informe 1–3 con un dato verdadero y comprobable, y nunca M9) **y** ningún informe entregó el regreso, un paradero de Holmes (M12), Baker Street ni Camden House | El informe es un segundo señuelo, además del centinela Parker [C]: «El empleado de Mycroft hizo airear los cuartos de Baker Street. El jueves por la noche estará en su ventana.» El sábado 7, Holmes sube en persona a la buhardilla (Watson ya lo sabe). Corrige el último asiento erróneo del libro mayor, si queda alguno («Su cuarta entrada no es literalmente cierta»; si no queda ninguno, «Hum. Nada que corregir»). Le impone silencio «hasta que el autor lo autorice», como a Watson entre 1894 y 1903 [C]. Le pide devolver los cinco tomos «sin nombre, a un estante de Kensington. Se ve desordenado» | «Lisle, Edmund. Lector. Sabe dónde se esconde la gente en una errata.» |
| **F4 «Ve, pero no observa»** | Menos de 6 conclusiones obligatorias (C2–C13) selladas (el contrato de Pell pedía seis) | En Park Lane la multitud oye una teoría equivocada; Lisle no reconoce al librero que choca con el médico | «Ve, pero no observa.» (SCAN [C]) |
| **F2 «El informe fiel»** | El informe final contiene datos verdaderos de regreso, lugar o Camden House (asientos con valores de C8, C9 o C13, o recortes con `holmes_vive`, `regreso_jueves`, `baker_street`, `camden`), sin coordinación | Moran cae igual. Lestrade encuentra los informes de Lisle en Conduit Street. Lo interrogan y lo sueltan «a pedido de un caballero que prefiere no figurar» | «Útil al bando equivocado. Vigilar.» |
| **F3 «El silencio»** | El informe final es «Sin novedad» o se quema (F3a). O contiene sólo datos falsos o irrelevantes, sin coordinación (F3b). También cae aquí quien cumple lo demás de F1 pero no tiene crédito ante Moran o entregó a Holmes en un informe anterior | Al día siguiente, los hombres de Moran buscan el cuaderno; Wiggins (o el muchacho de Cotter) está en la puerta | F3a: «Supo cuándo callar.» F3b: «Mintió bien, y solo. Imprudente.» |

`endings.json` declara un `rank` explícito para cada final y variante (T10).

### 12.2 Variantes del epílogo (acumulables)

- **Confrontación completa:** la ficha agrega «Cuatro de cuatro». Incompleta: «Tres errores; buen papel».
- **C12 sellado, o C12.R2 vista en Park Lane:** en el epílogo, Lisle reconoce los libros caídos.
- **C14 sellado:** después del 5 (nunca antes, porque EMPT ve el hueco [C]) Lisle puede dejar los tomos en la puerta de Watson. La última lámina muestra el segundo estante completo.
- **`watson_expuesto`:** en 1903, al leer «for the first and the last time in my life» [C], Lisle subraya la línea y no escribe nada.
- **C11 sellado:** en Park Lane, la teoría de Lisle es correcta; los curiosos se juntan a escucharlo y un médico de luto la juzga absurda y se aleja disgustado. En 1903 se lee «pointing out some theory of his own, while the others crowded round to listen» [C].
- **F1:** en octubre de 1903 llega por correo un ejemplar de la *Strand* con una nota al margen: «No era un detective de paisano. Era un lector. —S. H.»
- **Publicar la verdad (F2, F3, F4):** en el epílogo se ofrece publicar la fe de erratas. Si lo hace, una reseña la llama «un romance muy entretenido» y se archiva junto a Barrie y *Sherlaw Kombs*: **la verdad, en el formato equivocado, se lee como ficción** (de B). El canon posterior queda intacto.

### 12.3 Cierre común y revelación

En todos los finales Lisle, casi ciego, compra la *Strand* de octubre de 1903, encuentra «A tall, thin man with coloured glasses…» y lo recorta. Créditos sobre el sonido de la tijera.

**Después de los créditos:** el libro mayor completo aparece corregido con el lápiz azul de Holmes. Cada asiento erróneo o faltante recibe una nota marginal breve («Dele: la cornisa no se ve desde el sendero», «Falta: quién paga el alquiler»). Revelar al terminar no entrega ninguna pista durante el juego y muestra al jugador qué se le escapó.

---

## 13. Easter eggs (Marginalia)

Viven en la pestaña **Marginalia** del cuaderno, **sin contador**. Hay como mucho uno por visita a un lugar. Nunca son necesarios. El test T13 verifica que sus fragmentos no llevan etiquetas de C2–C13 y que ninguna reacción que provoquen agrega fragmentos a una ruta.

1. **«Mi James».** Mary anota en TWIS un apodo íntimo (INC-02 con ternura).
2. **La herida.** Watson se toca el hombro y después cojea. Si se le menciona: «La bala no leyó mis crónicas, señor.»
3. **El 4 de mayo.** Si se vinculan STUD (D43), las perlas de SIGN (D44) y Reichenbach (D03), la concordancia de Lisle suma una nota: «Tres veces el 4 de mayo. Sic.» Nadie reacciona.
4. **El cajón de Watson.** Un caso real anterior que Watson pasó en limpio en marzo de 1892 y fechó, por error honesto, al copiarlo («fines de marzo de 1892», INC-12): «Lo pasé en limpio para no olvidarle la voz.»
5. **Martin Hewitt.** Crane: «Lo cambiaron por un gordo que sonríe.»
6. **Barrie** acusa a Watson de asesinato (D40). Watson: «Un escocés con sentido del humor. Lo perdono los martes.»
7. **«La segunda mancha»**, anunciada en NAVA y nunca publicada. Crane jura que vio el manuscrito.
8. **El *bull pup*.** Mrs. Hudson: «Era su revólver, sir… creo, sir.» (teoría ✖ en boca de un personaje, sin afirmarse).
9. **Dos James Moriarty.** El coronel alude a «la terquedad de nuestro padre con los nombres» (D28); el tratado del Binomio en el BM (D39) lleva el nombre del profesor.
10. **Meunier y Meunier.** El arresto del anarquista Théodule Meunier en el *Times* del jueves, frente a la etiqueta del cajón (O. Meunier, mouleur, «cire») [H].
11. **Mrs. Turner.** Mrs. Hudson: «Me suplió una primavera, sir. Cocinaba mejor, sir.» (SCAN ocurre el 20 de marzo de 1888 [C].)
12. **La ficha «L»** del índice de Holmes, justo después de «Lestrade» (final).
13. **Trichinópolis.** Si se vincula la ceniza de Harris con la lámina de D12 o con SIGN («the black ash of a Trichinopoly» [C]), Lisle anota: «El autor de la monografía habría sabido de quién era.»

El canon propio sobre el hombre de anteojos de color es uno solo: es Lisle. Ningún huevo de pascua lo contradice.

---

## 14. UI y UX, controles, 3D y audio

### 14.1 Lo que hay en pantalla

- **HUD:** sólo el calendario de escritorio (fecha y franja) y las monedas sobre la mesa.
- **Dos libros:**
  - el **Cuaderno**, con pestañas Recortes (búsqueda, filtros por persona, lugar y fecha **de la crónica**, agrupados por calendario de la crónica; cada recorte con su epígrafe y su línea de fuente), Índice, Pares, Diario y Marginalia;
  - el **Libro mayor** (la *Fe de erratas*): primera página «Reglas del asiento» (§8.0), la página «Varios», los folios que abre el jugador, los asientos a lápiz o tinta con una ranura «según» por línea, y el sello «Visto».
- **Objetos:** escritorio, bandeja, mapa (con la página de horarios del Baedeker), ventana y estufa.
- **Prohibido:** brillos, contornos de interés, contadores (tampoco en Marginalia), registro de misiones, medidor de sospecha, registro de reacciones, señal de suficiencia.

### 14.2 Controles (se juega con el mouse; sin WASD)

| Acción | Entrada |
|---|---|
| Examinar o abrir | Clic izquierdo |
| Recortar | Modo tijera (tecla **C** o la tijera del escritorio) y arrastrar |
| Vincular | Soltar un recorte sobre otro |
| Asentar | Soltar un recorte en la ranura «según» de una línea |
| Preguntar | Elegir un tema del índice; se ve la frase; confirmar |
| Presentar | Soltar un recorte o un asiento sobre un personaje **en una escena**; se ve la frase; clic en «Mostrar» (o «Guardar» para retirarlo) |
| Abrir folio | Soltar un recorte sobre el libro mayor |
| Volver | Clic derecho o **Esc** |
| Zoom; órbita del diorama | Rueda; arrastrar con el botón izquierdo sobre el vacío, o flechas del teclado |
| Cuaderno, libro mayor, mapa | **Tab**, **L**, **M** |

### 14.3 Lector de documentos

- **Capa 2D a pantalla completa** (`CanvasLayer`), **fuera del post-proceso** de grabado. El 3D sólo sirve para tomar o dejar el objeto en el escritorio. Nada se lee en un `SubViewport` sobre un *quad*.
- **Fuentes: un único `Theme` con fuentes intercambiables.** Prohibido `SystemFont` (leería fuentes del sistema, fuera de `C:\Dev\books`; test T21). Cuatro ranuras: `imprenta`, `maquina`, `manuscrito` y `ui`. Cada una es un `FontVariation` sobre un `FontFile` propio cuyo `data` es una copia de `ThemeDB.fallback_font.data` (la fuente embebida de Godot), con `allow_system_fallback = false` y `multichannel_signed_distance_field = true`. El manuscrito usa `variation_transform` (inclinación) y `opentype_features = {liga: 0}`. Un autoload instala el Theme al arrancar sobre el tema por defecto y sobre `ThemeDB.fallback_font` (no en `root.theme`, que no se propaga bajo `CanvasLayer` ni `Node3D`). Si el usuario aprueba fuentes OFL (§16), se agregan en `game/assets/fonts/` y sólo cambia el `data` de cada ranura. Hasta entonces la firma de la voz A **no depende** de que la letra sea monoespaciada: depende de los defectos de la máquina y del papel medido.
- **Cobertura de glifos:** todo carácter de `data/*.json` debe existir en la fuente (`has_char`); se prohíben los que falten (por ejemplo ⅓ y ℔) y se escriben de otra forma.
- **Zoom** del 80 al 300 % por `Control.scale` sobre una página con geometría en milímetros (px por mm × zoom), así la **regla** mide el papel igual a cualquier zoom. **Lupa** de 3× para comparar tipos: un segundo `RichTextLabel` a 3× dentro de un panel recortado (no una ampliación de la textura de pantalla). Modo de alto contraste.
- **Defectos de la Remington con `RichTextEffect`**, **estáticos** (sin `elapsed_time`, con *jitter* sembrado por `range.x`): la «s» desplazada hacia arriba, la «t» con menos peso de tinta y la «e» girada 3°; los caracteres se identifican con `TextServer.font_get_char_from_glyph_index`; ligaduras desactivadas; desplazamientos proporcionales al tamaño de letra; en alto contraste se conservan los defectos de forma (desplazamiento y giro). La identidad de la máquina también es una etiqueta en los datos. No hay cirugía de glifos.
- **Construcción del texto:** cada documento se arma con un *builder* que usa `add_text`/`push_*` (o BBCode sólo en línea: b, i, color, font y efectos), con «\n» como único separador; sin `[p]`, `[ul]`, `[table]`, `[indent]` ni `[img]`, que alteran los índices. Los tramos se calculan sobre el mismo texto plano que produce el *builder* (test: `get_parsed_text() == builder.plain`). Documentos paginados de 300 a 600 palabras; los tomos, por historia.
- **Recorte de texto:** sólo en modo tijera `selection_enabled = true`; `drag_and_drop_selection_enabled = false`, `context_menu_enabled = false`, `threaded = false`. El inicio es `get_selection_from()` y el fin `from + get_selected_text().length()` (no `get_selection_to()`, cuyo sentido varía); se verifica `parsed.substr(from, len) == selected` y se ajusta a límites de palabra; luego se aplican los topes de §8.1.
- **Luz rasante de D29b, en 2D:** la línea oculta se dibuja en un `RichTextLabel` con un `ShaderMaterial` de `canvas_item` que hace *emboss* sobre la alfa del glifo, con un *uniform* de dirección de luz que sigue al mouse. El texto sigue siendo seleccionable y recortable. En alto contraste, los surcos se muestran como texto tenue.
- Los documentos conservan su color de época (fuera del post-proceso): el *Times* hueso, el papel del Diógenes crema, el telegrama ante, la tinta azul del lápiz de Holmes.

### 14.4 Cámara, 3D y placeholders

- **Render Forward+**, porque hace falta `normal_roughness` para los contornos.
- **Hub:** tres encuadres fijos con transición suave. **Lugares:** de 2 a 4 encuadres fijos y una órbita corta de ±25° alrededor de un pivote (la «Danza de la deducción»). Los objetos se examinan en primer plano y se pueden rotar.
- **Nodos lógicos:** cada objeto etiquetado del JSON de un lugar tiene un `clip_anchor` (una AABB chica y explícita), un `examine_text` que enuncia el hecho observable («manchas amarillas en los dedos», «la sombra llega al techo») y sus etiquetas, separados de la geometría. Ninguna ruta depende de percibir un color o un matiz (test T29).
- **Recorte en dioramas:** reglas de §8.1. La oclusión se resuelve con `intersect_ray` contra `StaticBody3D` de cajas generadas del mismo JSON, después de un frame de física. Cada lámina guarda una instantánea explícita (lugar, variante, ids de los nodos presentes, cámara); nada se rederiva del mundo actual. La miniatura es opcional y la lógica nunca depende de ella.
- **Dioramas** con `MeshInstance3D` y `PrimitiveMesh` desde `data/places/*.json`; CSG sólo para restas (vanos, arcos), horneado con `bake_static_mesh()` al construir el lugar, liberando los nodos CSG. **Variantes por fuente** (Reichenbach) armadas a mano.
- **La luz como pista:**
  - un `OmniLight3D` de gas en la tienda de Crane proyecta la sombra demasiado alta del librero (y el nodo lo dice en su `examine_text`);
  - Park Lane tiene luz dorada a las 18 h;
  - la noche del 5 sopla viento: transeúntes abrigados, faroles que parpadean.
- **Personajes:** maniquíes de primitivas con un solo rasgo de silueta (§4). Hay una captura de cada lugar con `devtools/shot.gd` para verificar que cada silueta se distingue en 1 bit y que Wiggins se ve sin tapar en al menos un encuadre de cada lugar desde el día 3.
- **Rendimiento:** cada lugar se precalienta (compilación de *pipelines*) renderizándolo una vez detrás de un fundido. Para presentar, un `Control` de pantalla completa se activa con `NOTIFICATION_DRAG_BEGIN` y resuelve el destino 3D con la misma selección por proyección que el clic.

### 14.5 Estilo: grabado de la *Strand*

- Post-proceso en un *quad* de pantalla con plantilla fija:
  - vértice con Z invertida (`POSITION = vec4(VERTEX.xy, 1.0, 1.0);`, Godot ≥4.3) y profundidad lineal; el *quad* cuelga de la cámara o lleva `extra_cull_margin` para que no lo descarte el *frustum*;
  - contornos por profundidad y normales (`normal_roughness`, sólo Forward+ y sólo lo que pasa por el *prepass*);
  - trama Bayer 8×8 procedural anclada a una esfera centrada en la cámara, con tamaño de celda derivado del FOV y del alto del *viewport* (en la órbita la trama «nada» un poco: se acepta);
  - grano de papel procedural.
- Paleta por defecto: **dos tintas**, #1b1712 sobre #efe6d2 (§16).
- La hora se lee en el tono del papel: gris perla por la mañana, ámbar de gas por la noche.
- Cada diorama lleva un epígrafe al estilo de las láminas de Paget: «—¿El *Journal de Genève*, señor?».

### 14.6 Audio procedural

- **Todo se genera una sola vez al cargar**, como `AudioStreamWAV` con semilla fija (determinista y testeable por *hash* del PCM; generar 2 s mono a 44,1 kHz cuesta unos 19 ms):
  - tijera, papel, plumín, secante, sello y sobre;
  - campanas de St Clement Danes (aditiva inarmónica);
  - cascos sobre madera y sobre granito;
  - arpa de boca de Parker (diente de sierra con barrido de formantes);
  - silbato policial;
  - el silbido y «a long, silvery tinkle of broken glass» (ruido con envolvente y campanas filtradas);
  - los cuartos de hora;
  - **ambientes** (la calle, el siseo del gas, el reloj, el murmullo de la Sala de Lectura, el tono de sala del Diógenes, el viento de la noche del 5): bucles de 4 a 8 s con fundido cruzado en el punto de bucle y `loop_mode` *forward*, más eventos sueltos vía `AudioStreamRandomizer` o `AudioStreamPolyphonic`.
- No se usa `AudioStreamGenerator`.
- No hay violín ni música de alerta. Las reacciones llegan sin sonido propio.

### 14.7 Accesibilidad

- No hay reloj en tiempo real.
- Tamaño de texto ajustable y alto contraste (con los defectos de la máquina y los surcos de D29b conservados).
- Subtítulos de sonido **encendidos por defecto**. Describen el sonido («arpa de boca, lejos») sin interpretarlo.
- La órbita se hace con el botón izquierdo o con las flechas (no hace falta botón central).

---

## 15. Alcance (Godot 4.7, agentes por código)

### 15.1 Presupuesto de texto: 25.600 palabras

| Bloque | Palabras |
|---|---|
| Corpus: las 24 historias de los tomos con el **mismo tratamiento** (escena inicial y una escena central, unas 300 palabras cada una, mismo formato, todas etiquetadas) | 7.200 |
| STUD (D43) y SIGN (D44), mismo tratamiento | 1.200 |
| FINA ampliado (es el objeto del encargo: se justifica en el mundo) | 2.300 |
| Documentos inventados (D02–D45 salvo el *Times* y el corpus) | 5.900 |
| *Times* diario (10 números: noticias de época y columna) | 2.000 |
| Voces A y B (incluidas las respuestas privadas y las falsas de HB2) | 1.700 |
| Diálogos (respaldo tema × personaje por capas) | 4.000 |
| Diario, interfaz, reglas del asiento, epílogo y lápiz azul | 1.300 |

El tratamiento uniforme del corpus evita que una selección marque las pistas. No se traduce el corpus completo.

### 15.2 Volumen

| Elemento | Cantidad |
|---|---|
| Lugares | 8 (más 3 láminas) |
| Personajes con diálogo | 9, más el protagonista; 2 cameos; 2 sólo por escrito |
| Conclusiones | 15: 12 obligatorias (C2–C13), 1 tutorial (C1), 2 opcionales (C10a, C14) |
| Documentos | 45 (D01–D45) |
| Reacciones | 42: Holmes 30 (11 de columna, 3 garantizadas por acto, 16 opcionales) y Moran 12 (3 de columna y 9 disparadas), más los silencios explícitos de HB14 |
| Informes | 4 |
| Finales | 4, con 7 variantes |
| Easter eggs | 13 |
| Duración | unas 3¼ h |

### 15.3 Datos

- `data/docs/*.json`: tramos con etiquetas (entidad, fecha, lugar, afirmación, clave, origen, clase I/P/C), ejemplares por lugar y `src_en` para las citas de Doyle.
- `data/entities.json` (todas las entidades, también las de ruido).
- `data/lists.json`: verbos, relaciones, medios, estados y formas de anuncio (listas cerradas, §8.2).
- `data/catalog.json`: catálogo de la Sala de Lectura; cada documento con ≥2 entidades puente obtenibles antes de necesitarlo, y obras de ruido de época en los resultados.
- `data/conclusions.json`: plantilla, respuestas válidas, grupos y la línea que sostiene cada uno, claves, campos opcionales y rutas de ejemplo.
- `data/reactions.json`: los parches de §9.6 y §9.7, con `tipo` y `corta{fragmentos|acceso, ventana}`.
- `data/schedule.json`: columna, franjas y ventanas de cada lugar (también la página de horarios del mapa).
- `data/places/*.json`: nodos lógicos (`clip_anchor`, `examine_text`, etiquetas), geometría y variantes.
- `data/dialogue.json`: tema × personaje con respaldo por capas elegidas por propiedades visibles (línea específica, luego por documento o entidad, luego genérica del personaje).
- `data/canon_bible.json`: hechos con `fecha_evento`, `fecha_publicacion`, `fecha_conocible` y marca C, BG, H o INV.
- `data/endings.json`, con `rank` por final y variante.
- Serialización: `var_to_str`, o JSON con *cast* explícito según esquema (el JSON de Godot convierte los enteros en *floats*: «Asiento 214.0»).

### 15.4 Sistemas

`DocumentReader` (*builder* y selección), `Clipper` (texto y diorama), `Notebook`, `Ledger` (folios, asientos, ranuras «según», chequeo formal, validador por grupos, orígenes y claves, lotes), `DayCycle` (franjas, calendario), `EventLog` (registro de eventos, escritura atómica: `.tmp` → `.bak` → renombrar; `replay`), `PlayerActions` (única capa que crea folios y registra actos), `Travel`, `ReactionDirector` (sensores con filtros, colas, latencias, D1–D10), `HolmesAgent` (contadores por tema, confianza), `MoranAgent`, `ReportComposer`, `AdComposer`, `Dialogue` (preguntar y presentar en dos pasos), `Confrontation`, `DioramaBuilder`, `ThemeInstaller` (autoload de fuentes), `EngravingPost`, `ProcAudio` y `Endings`.

La lógica va en clases sin escena, para que los tests corran *headless*. Reglas de código para agentes:
- **Sin `class_name`** en `game/`: se usa `const X = preload("res://…")` (en un clon limpio, sin la caché del editor, `class_name` no resuelve).
- Determinismo: prohibidos por *lint* `randi()`, `randf()`, `randomize()` y `Time.*` en la lógica; aleatoriedad sin estado por `hash([semilla, id_evento, día])`; claves siempre ordenadas al iterar.
- Los tests escriben sólo en rutas explícitas bajo `.work/`.

### 15.5 Tests (runner propio `game/tests/run_tests.gd` vía `./godot.sh --headless -s tests/run_tests.gd`; nada de GUT ni de *addons* descargados)

El runner arranca con `_run.call_deferred()` (no en `_init`, para que existan los autoloads), tiene un *watchdog* por test y un `Logger` (`OS.add_logger`) que convierte cualquier ERROR del motor en fallo. `--check-only` sirve como *lint* rápido.

- **Grafo:** T1–T5, T17 y T22 (§10.6).
- **T6** Plantillas: *lint* de que ninguna plantilla tiene artículo o flexión fuera del rótulo «Campo: ___», de que ninguna presupone un hecho y de que las listas cerradas son iguales para todas las conclusiones.
- **T7** Fechas, días de la semana y conocimiento:
  - nadie sabe algo antes de su `fecha_conocible`;
  - nadie relaciona a Moran con Adair antes del día 8;
  - ningún documento público I contiene un paradero de Holmes en 1894;
  - el poder de Mycroft no es público;
  - *lint* de anacronismos;
  - toda cita marcada [C] coincide con su `src_en`, comparada contra extractos de dominio público copiados en `game/tests/fixtures/`;
  - ninguna ruta ni refutación depende de un ⚠.
- **T8** Ceguera: el director sólo recibe eventos `ActoPublico`; mismos actos públicos con distinto cuaderno producen las mismas reacciones.
- **T9** Determinismo: dos `replay` del mismo registro dan el mismo estado; guardar, cargar y volver a guardar da bytes idénticos.
- **T10** Bots: deductor, novato (sólo usa verbos ya enseñados), pasivo, pesca, fuerza bruta, recorta-todo (recortes legales máximos), cebo sin parar, informa-todo, sólo Sala de Lectura, acusador al azar en la confrontación y presentador al azar ante Mycroft. Ninguno alcanza un final de `rank` mejor que el del deductor. El pasivo termina en F4. Presupuesto de pesca de §8.9 (≤5 %). El novato mide la duración del Acto III.
- **T11** Ritmo: como mucho 1.000 palabras nuevas por mañana, nunca más de 2 franjas sin material nuevo y ≤1 reacción disparada fuerte por mañana (con las exenciones de D2).
- **T12** Coherencia actor-lugar-fecha de cada reacción.
- **T13** Los easter eggs no llevan etiquetas de C2–C13 ni producen fragmentos de ruta.
- **T14** Estático: sólo `PlayerActions` llama a `create_folio`.
- **T15** Ley 2 (contadores por tema; la tercera respuesta es falsa y la cuarta, silencio) y reacciones garantizadas por acto: deterministas, sin condiciones extra, no bloqueables.
- **T16** HB13 no lleva etiquetas de C2–C5 ni C8–C13.
- **T18** Confrontación: un grupo refutador por afirmación, «callar» no cuenta, como mucho 3 errores, una sola vez.
- **T19** Selección: tests puros de `map(from, texto_seleccionado) → tramos` y un único test de integración con ventana (`devtools/shot.gd`, 1600×900, `Input.parse_input_event`).
- **T20** Todo par personaje × entidad del índice devuelve una línea. **T20b** Ceguera del diálogo: dos recortes con las mismas propiedades visibles y distintas etiquetas ocultas producen la misma respuesta.
- **T21** Fuentes: *lint* que falla si aparece «SystemFont» en `game/`; en *runtime*, todo `FontFile` cargado tiene `allow_system_fallback = false`; cobertura de glifos de `data/*.json`.
- **T23** Secreto: ningún texto público lleva `afirma_que_vive`; ninguna respuesta pública reproduce contenido llegado por K-W; ninguna frase pública traduce «not literally true».
- **T24** Rampa: el bot novato toca cada verbo en un contexto guiado o gratuito antes de su primer uso con costo.
- **T25** Guardado: matar el proceso después de una pasada fallida, de un error ante Mycroft y de una respuesta en la confrontación; al recargar, figuran como hechos.
- **T26** Mapa: ningún clic gasta una franja en un lugar cerrado.
- **T27** Shaders: todos compilan en *headless* (capturado por el `Logger`); calibración del grabado con ventana en los hitos (un plano a 5 m da el gris esperado).
- **T28** Audio: *hash* del PCM de cada sonido estable entre corridas.
- **T29** Dioramas: todo nodo etiquetado tiene `examine_text` con el hecho observable; con `root.size` fijo, Wiggins queda dentro del *frustum* y sin tapar en al menos un encuadre de cada lugar desde el día 3; la línea de tiro de L7 se puede recortar sola.

### 15.6 Orden de construcción

1. **H0: herramientas y *spikes*** (cada uno con criterio de salida; alrededor de un día de agente cada uno): Theme de fuentes sin respaldo del sistema (T21); *builder* de documentos y selección (T19); rectángulo, oclusión y lámina en 3D (T29); *quad* de grabado legible con captura (T27); registro de eventos y `replay` (T9, T25); runner con *watchdog* y `Logger`.
2. **H1: lógica *headless* sin escenas**, del prólogo al día 3: esquemas de datos, validador, director con sensores filtrados, verificador acotado de la invariante y bots. No se redacta texto final mientras el esquema no pase H1.
3. **H2: interfaz 2D**: lector, cuaderno, libro mayor con ranuras «según», compositor de anuncios, arrastrar y soltar, preguntar y presentar en dos pasos.
4. **H3: hub 3D**, L2 y L4 con selección por proyección y láminas. Rebanada vertical jugable: prólogo y días 1–3, cinco reacciones (HC01, HA1, HB1 desde Watson, HC02, HC10), un lote, el informe 1 con M1 o M3, el diario y el guardado.
5. **H4: todo el contenido en tablas**, con T1–T29 pasando.
6. **H5:** post-proceso de grabado y luz rasante 2D.
7. **H6:** audio WAV.
8. **H7:** Marginalia, variantes del epílogo y lápiz azul.

### 15.7 Qué recortar primero

Cada recorte se acepta sólo si T1 y T3 siguen pasando.
1. Easter eggs 5 a 13.
2. Variantes del epílogo, salvo el cierre común y el lápiz azul.
3. HB8 y HB8b (reclutar a Wiggins): sólo dan rutas C extra.
4. Las variantes conmutables de Reichenbach (queda una lámina).
5. M9, M10 y M11.
6. Somerset House como diorama (queda un mostrador simple).

**Nunca se recorta:** el ritual de la mañana, las dos voces y sus latencias, el diario, la invariante, Watson, el Diógenes del día 8, el librero y la confrontación, Park Lane, los tomos, los informes y la rampa de enseñanza.

### 15.8 Verificaciones pendientes antes de redactar (tareas de investigación, no decisiones)

- El cierre dominical de la Sala de Lectura en 1894: Baedeker 1894 da el horario y los cierres de marzo, octubre, Viernes Santo y Navidad, pero no menciona el domingo. Si abría, se agrega una franja de L2 el día 6. No afecta ninguna ruta.
- Que el índice trimestral de defunciones del 4.º trimestre de 1893 se pudiera consultar a fines de marzo de 1894 (D18 ⚠; sólo afecta a C14.R1, que no es ★).
- Tarifa de anuncios del *Times* (sólo sabor).
- Horarios del correo continental Londres–París y del reparto dominical en Francia en 1894 (la tabla de §9.3 los fija como [INV]; ninguna ruta ★ depende de la hora exacta).
- Hecho: el pasaje de Ohrwalder (D34) ya está verificado (`.work/dl_verify/`).

---

## 16. Decisiones abiertas para el usuario

El diseño adopta un valor por defecto para cada una y se puede construir sin esperar la respuesta.

1. **Guardado.** Por defecto: guardado por compromiso (cada acto se escribe a disco antes de mostrar su resultado), sin volver atrás, con reacciones deterministas. La alternativa (reiniciar el día) permitiría espiar reacciones gratis; no se recomienda.
2. **Señal de suficiencia.** Por defecto no existe (choca con «ninguna pista es entregada por el juego»); los objetivos llegan como preguntas de personajes y el contrato de Pell pide seis asientos. Si se la quisiera, sería una opción apagada que dependa sólo de lo sellado, nunca de recortes ni de lecturas.
3. **Estilo visual.** Por defecto: grabado a dos tintas. La alternativa es sepia.
4. **Citas de Doyle.** Por defecto: todo en español. Alternativa: mostrar además el original inglés en la pestaña Marginalia.
5. **Invenciones en huecos del canon** que conviene validar:
   - Lisle como el hombre de anteojos de color de EMPT;
   - la galerada, el corte del F.O. pedido por Mycroft y las **pruebas americanas canceladas** (reemplazan la variante de *Memoirs* Harper, que alteraba una edición real);
   - la muerte de Mary el 25-nov-1893 en Paddington, y que **Mycroft lo supiera y se lo callara** a su hermano;
   - que Moran compró los tomos de Watson en la subasta;
   - el coronel James Moriarty real, en Bath;
   - Cotter, que no sabe para quién trabaja;
   - los textos de Sigerson (firma sin ciudad; la nota de 1893 sobre Jartum);
   - Wiggins adulto en 1894;
   - que Moran preparó Camden House desde el lunes 2 y que Holmes obtuvo su llave por otra vía (opción B de la revisión: se conservan los rastros con filtros y test). La alternativa A (Moran entra sólo la noche del 5, sin rastros) quitaría L8 como lugar con pistas.
6. **Duración.** Unas 3¼ h con 25.600 palabras. ¿Sirve, o se prefieren 2–2,5 h (se recorta según §15.7 y el tratamiento del corpus)?
7. **Fuentes.** Por defecto, la fuente embebida de Godot en las cuatro ranuras del Theme. ¿Se aprueba agregar fuentes OFL dentro de `game/assets/fonts/` (por ejemplo Old Standard TT para imprenta y Cutive Mono o Courier Prime para la máquina)? `SystemFont` queda prohibido.
8. **Caché del controlador de video.** `godot.sh` redirige APPDATA, LOCALAPPDATA y TEMP a `.work/`, pero el controlador de NVIDIA probablemente escribe su caché de *shaders* en la carpeta real de AppData\Local, fuera de `C:\Dev\books`. No se verificó (verificarlo exige leer fuera del repo). ¿Se aceptan esas escrituras del controlador? Mientras tanto: tests *headless* y corridas con ventana sólo en los hitos.
9. **Tamaño del lote.** Por defecto, 2 (1 el día 10). Alternativa: 3, más fiel a Obra Dinn pero más dura para un novato con 12 conclusiones.
10. **Exigencia de F1.** Por defecto: C6, C7, C10, ≥8 conclusiones selladas, crédito ante Moran y no haber entregado a Holmes. Se puede bajar a ≥6 si las pruebas con jugadores lo piden.

---

## 17. Registro de la revisión adversarial

Una línea por hallazgo. Prefijos: **CAN** canon, **GRA** grafo, **JUG** jugador, **EXP** *exploits*, **TEC** técnica; el número sigue el orden del informe de cada lente. Decisión: **aplicado**, **parcial** (se aplica lo compatible y se justifica el resto) o **rechazado** (con la razón).

| ID | Hallazgo | Decisión | Dónde |
|---|---|---|---|
| CAN-01 | Desaparición premeditada (C4, secreto de Holmes, «as arranged») | Aplicado: C4 = cedió sus bienes en vida ante una muerte probable; se quita «preparó su desaparición»; «as arranged» = arreglo de bienes; HB1 testamento sin insinuar plan | §2.3, §4, D29, HB1, C4 |
| CAN-02 | El bando de Holmes podía saber de Camden House | Aplicado (opción B): rastros conservados; K-S informa sólo calles; Wiggins no vigila Camden; la llave de Holmes no sale de D32; filtros `secreto_camden`, D10 y T22 | §2.2, §2.4, §5 L8, §9.2, §9.8, C13, T22, §16.5 |
| CAN-03 | Holmes llegaba a 221B a las 14 h | Aplicado: llega en persona por la mañana (hacia las 11), histeria de Mrs. Hudson por la mañana; las 14 h son la hora del sillón | §0.3, §2.1, §2.2, §2.4, §3.2 |
| CAN-04 | Cinco días de rodeo frente a «came over at once»; 5-abr marcado [C] | Aplicado: Holmes se entera el lunes 2 y parte en el acto; Grenoble y París sólo de paso; marca [BG] | §0.1, §2.1, §2.2, §9.3, D31 |
| CAN-05 | Dos días entre veredicto y paseo de Watson | Aplicado: indagatoria se abre el 2, veredicto el 4, publicado el 5; Watson lo lee el jueves | §2.1, D15 |
| CAN-06 | Cornisa «a pocos pies» y fácil | Aplicado: cornisa alta, invisible desde el sendero, sólo un nidero temerario; C3 sin «a pocos pies» | §2.3, D05, D07, D08, D27, C3 |
| CAN-07 | *Journal de Genève* demasiado detallado | Aplicado: nota de ~110 palabras, «marque récente» sin atribuir a Watson; la raspadura del clavo de bota sólo en galerada, pruebas y notas | §2.3, D05, C2 |
| CAN-08 | Variante falsa sobre la edición real de Harper | Aplicado: D04 = pruebas americanas canceladas en la tienda de Crane; el F.O. cortó a tiempo las dos composiciones | §2.3, §2.5, D04, C2, §16.5 |
| CAN-09 | Fugas del secreto (Cotter, Wiggins, «Cayó uno») | Aplicado: Cotter no sabe para quién trabaja; Wiggins no oye de Francia; «—S.» sólo corrige y remite a fuentes; restricción y T23 | §2.4, §3.3, §4, HB1, HB8, T23 |
| CAN-10 | Respuestas públicas a lo dicho a Watson | Aplicado: lo que entra por K-W se contesta por carta privada «—S.» (Ley 5); fuera HB4(a) de la columna; sin «not literally true» público | §2.4, §9.2, §9.4, HB1, HB4, T23 |
| CAN-11 | Sigerson publicaba su paradero | Aplicado: D14 firmada «S. S.» sin ciudad; D13 remite al n.º 97 de D12 (sin la cifra de SIGN); test T7. Además, si Lisle informa un paradero extranjero (D31), Moran no viaja (M12) y F1 se pierde | §2.3, D13, D14, C8, M12, §12.1, T7 |
| CAN-12 | «Holmes nunca destruye» contra CHAS | Aplicado: decisión de este asunto, no rasgo absoluto; Ley 3 reformulada | §2.4, §4, §9.4 |
| CAN-13 | STUD y SIGN no están en la *Strand* | Aplicado: D43 y D44 (Crane y BM) con presupuesto; C1, C8.R2, HB8 corregidos | §2.5, §6, §10.4 C1, C8, HB8, §15.1 |
| CAN-14 | El Kelly's 1894 no podía tener a Watson en Kensington | Aplicado: ambas ediciones dicen Paddington; nuevo D45 (*The Lancet*) para C14.R2 | §2.3, D17, D45, C14 |
| CAN-15 | El librero se enderezaba ante Watson | Aplicado: en HC08 se va encorvado; C12.R2 queda sólo para el epílogo | §2.4, §3.2, HC08, C12 |
| CAN-16 | Mycroft «lacónico» y «nunca camina» | Aplicado: afable, suave, irónico; línea de Wiggins «no camina más que de Pall Mall a Whitehall»; C7.R7 coherente con GREE | §4, HB8, C7.R7 |
| CAN-17 | Citas mal atribuidas | Aplicado: DYIN, SIGN, «por impaciencia», «that gap on that second shelf» | §1, §2.6, §4 |
| CAN-18 | C5.R3 con «Anglo-Indian» en la prensa del sábado | Aplicado: D15 del sáb. 31 sin nombres; Anglo-Indian sólo en D28; C5.R3 = D28 + D10 | §2.4, D15, C5 |
| CAN-19 | «Oficina de prensa del F.O.» es anacrónica | Aplicado: «nota comunicada a los diarios por el Foreign Office»; lint | §2.4, §2.5, HB3, D8 |
| CAN-20 | Mycroft ignorando la muerte de Mary | Aplicado: Mycroft lo sabe y lo calla a propósito; filtro de K-W; línea en HC06 | §2.3, §4, §9.1, HC06 |
| CAN-21 | Manuscrito de WIST haría mentir a Watson | Aplicado: caso real pasado en limpio en marzo de 1892, mal fechado por error honesto | §2.6, §4, §13.4 |
| CAN-22 | Clima de la noche del 5 | Aplicado: fría y ventosa; audio de viento; transeúntes abrigados | §2.1, §3.2, §14.4, §14.6 |
| CAN-23 | 21:30 era la salida, no la llegada | Aplicado: salen 21:30, Camden House hacia las 22, disparo cerca de medianoche | §2.1 |
| CAN-24 | El librero pedía los tomos «para un médico de Kensington»; D33 con entrega | Aplicado: pregunta por «los tomos de la *Strand*»; D33 «se los lleva» | §3.2, HC07, D33 |
| CAN-25 | *Machan* «frente» al cebo | Aplicado: «que domine al cebo»; C13 usa «dominar» | D10, §5 L8, C13 |
| CAN-26 | Somerset House: extractos, horario, índice de defunciones | Aplicado: «de memoria» sólo para testamentos; 10–15 h; D18 ⚠ (C14.R1 no es ★) | §5 L6, D18, §15.8 |
| CAN-27 | Easter eggs 11 y 12 | Aplicado: «una primavera»; «después de Lestrade» | §13 |
| CAN-28 | «some months later», hora del pastor, «se ríen», «Khartoum» opcional | Aplicado: conjetura de Lisle; «al anochecer»; «se juntan a escucharlo y el doctor se aleja disgustado»; nota de Jartum de 1893 fija (D13) | §2.3, §2.6, §3.2, §12.2, D05, D13 |
| GRA-01 | Recorte sin máximo; procedencia por medio | Aplicado: una oración y 40 palabras, afirmaciones de un solo tramo o nodo; origen = documento o escena; reetiquetado de HC05, HC06 (b), L8, HC07; T4 sobre recortes legales máximos | §8.1, §8.5, §10.2, HC05, HC06, HC07, T4 |
| GRA-02 | C6 no podía cumplir la invariante | Aplicado: ruta = par de subrutas; HC10 de columna (K-T); HC06 (b) cita un acto por canal; HA3 garantizada; categoría «garantizada por acto»; sin HB2; fechas corregidas; medios como lista cerrada | §8.2, §9.6, §10.3, C6 |
| GRA-03 | «Hizo» sin fuente en el índice | Aplicado: lista cerrada de verbos; T5 por líneas, sin campos dobles | §8.2, §8.4, C4, C11, C13, C14 |
| GRA-04 | HC06 como punto único de falla | Aplicado: (a)–(f) siempre antes; portero admite por nombre; HB12 cierra sólo la Sala; D9 y T2 extendido | §5 L5, HC04, HC06, HB12, §9.8, T2 |
| GRA-05 | Ley de la huella incumplida | Aplicado: ley separada para Holmes (C6–C8) y Moran (C10, C13); HB8b agrega C7; M6 bajo M4 como nota «H.»; T5'; variante blanda obligatoria | §9.6, §9.7, §9.8 D1, §10.1, T5 |
| GRA-06 | «Sin documentos compartidos» falso | Aplicado: T1 por ejemplar y escena (conectividad ≥2); ejemplares en Crane y BM | §6, §10.3, §10.4, T1 |
| GRA-07 | EDIC faltante; C13.R1 sin línea en M7 | Aplicado: regla por orígenes; línea «Es de Trichinópolis» en M7 | §10.2, M7, C13 |
| GRA-08 | STUD/SIGN fuera del corpus; D14 sin enlace | Aplicado: D43, D44; C8.R2 = D14 + D44 («influence of a trade upon the form of the hand») | §6, C1, C8 |
| GRA-09 | Contenidos de §6 y §10.4 no coincidían | Aplicado: frases de D09 asignadas a D10/D11; «la raspadura» en la nota del tomo; D45 cubre `duelo`; C7.R4 con nodo propio; C9.R1 interior/exterior; fechas | §6, §10.4 |
| GRA-10 | Grupos sin enlace entre sí | Aplicado: condición 5 (claves visibles; mismo origen enlaza); §8.9 recalculado; T10 | §8.5, §8.9, §10.4 |
| GRA-11 | Índice y catálogo como oráculo | Aplicado: entidades de ruido; `catalog.json` con puentes y ruido; D10 también en Crane | §5 L2, §6, §8.2, §15.3 |
| GRA-12 | Latencias, D31, D2 y D3 incoherentes | Aplicado: nueva tabla de latencias; D31 de columna con horas antes de las 18 h; D3 fusiona; exenciones de D2 y T11; M8 al día 9 | §9.3, §9.8, D31, M8, T11 |
| GRA-13 | HB13 leía actividad privada | Aplicado: sólo inactividad observable | HB13, §9.8 D4 |
| GRA-14 | Validación del día 10 tardía para C12.R2 y C13 | Aplicado: C12.R2 sin ★ (sólo epílogo); C13 sólo en el libro mayor | C12, C13, §12 |
| GRA-15 | C13 sellable el día 1 con el cartel | Aplicado: `escondite_preparado` sólo en L8, el chico del agente o D32 | C13 |
| GRA-16 | T6/T9 presuponían hechos; alias de Harris | Aplicado: T6 Relación y T9 Propósito genéricas; C10a con regla de alias; C7 sin «Cotter» (no es entidad conocida) | §8.4, C7, C10a |
| GRA-17 | Tamaño de lote explotable | Aplicado: `min(2, obligatorias sin sellar)`, sólo baja por calendario | §8.5 |
| GRA-18 | El prólogo entregaba C2 | Aplicado: galerada en el cajón sin guion; tutorial con INC-10; preguntas de D23 abiertas | §3.2, D21, D23 |
| GRA-19 | HB12 autorreferente | Aplicado: exige un asiento sellado de C6 o C7; fuera los orígenes HC06 | §8.7, HB12 |
| GRA-20 | D34 ⚠; falsas de HB2 sin escribir | Aplicado: pasaje de Ohrwalder verificado; las cinco falsas con dos refutaciones | D34, HB2, §10.5 |
| GRA-21 | «Desde» y ventanas | Aplicado: C3.R2 día 1; HA0 como respaldo de columna; C13.R5 día 5; HC04 P; HB4 coherente; canario ≠ cebo; «jueves» se resuelve al 5; HC05 y M7 sobreviven a HB11 y variantes | §10.4, HA0, HA4, HB4, HB11 |
| JUG-01 | Onboarding de 3 verbos | Aplicado: «Reglas del asiento»; un verbo por paso con instructores (Pell, ujier, chico de Pell, oficina de anuncios, Crane); T24 | §3.2, §7.7, §8.0, T24 |
| JUG-02 | Fundamento con metadatos invisibles | Aplicado: «según» por línea; línea de fuente visible; chequeo formal inmediato; orígenes unificados | §8.1, §8.4, §8.5, §10.2 |
| JUG-03 | C1 contradictorio | Aplicado: «dos pasajes distintos»; práctica aparte; test de pares | §8.5, C1 |
| JUG-04 | Informe 1 bloqueaba F1 sin aviso | Aplicado: primera entrega = M3 visible + HB9 aviso; sólo la segunda activa `watson_expuesto` | M3, HB9 |
| JUG-05 | «Hizo» sin fuente | Aplicado: lista cerrada de verbos (ver GRA-03) | §8.2 |
| JUG-06 | Prólogo entregaba C2 | Aplicado (opción B, ver GRA-18) | §3.2 |
| JUG-07 | Lotes de 3 demasiado gruesos | Aplicado: lote de 2; sello sin tinta y «Alguno no se sostiene»; tampón seco | §8.5, §16.9 |
| JUG-08 | Voz B no garantizada | Aplicado: aviso de testigos en el prólogo y respuesta fija HC10 el día 4; compositor de anuncios definido | §3.2, §8.2, HC10 |
| JUG-09 | Preguntar parecía gratis | Aplicado: 3 preguntas por personaje y visita; frase visible; Watson avisa antes de cerrar y no cierra el domingo | §4, §8.7, HB4 |
| JUG-10 | Presentar sin confirmación | Aplicado: dos pasos («Mostrar» / «Guardar»); sólo en escenas | §8.7, §14.2 |
| JUG-11 | Mycroft no enmarcaba el momento | Aplicado: desafío explícito (HC06 (g)); primer error tolerado | HC06, HB12 |
| JUG-12 | Objetivos invisibles | Aplicado: preguntas de Pell (prólogo), Harris (día 7), Mycroft (día 8); contrato de seis asientos. Watson no formula una pregunta propia: el domingo es respiro | §3.2, D23 |
| JUG-13 | Recorte de diorama neutro sin aviso | Aplicado: captura por ≥50 % del ancla; epígrafe con todos los objetos | §8.1 |
| JUG-14 | Horarios no comunicados | Aplicado: página del Baedeker en el mapa; persianas; T26 | §5, T26 |
| JUG-15 | Latencia ilegible | Aplicado: sello «Recibido» y línea de llegada en el diario; las tandas citan la fecha del acto | §7.1, §7.4, §9.3 |
| JUG-16 | Acto III concentrado | Aplicado: L8 desde el día 7 T; D31 desde el día 3; dos pasadas la noche del 9; T10 mide | §2.1, §5, §7.7 |
| JUG-17 | Aspecto de Lisle no establecido | Aplicado: reflejo en el prólogo, comentario de Pell, deducción de Mycroft; el epílogo muestra el estante | §3.1, §3.2, HC06 |
| JUG-18 | HB13 no ayuda al novato activo | Parcial: no se agrega un disparador por estado privado (rompe T8 y D6); el novato activo tiene las reglas del asiento, el chequeo formal y las preguntas de personajes | §8.0, §8.5, §9.8 D6 |
| JUG-19 | Carga cognitiva | Aplicado: folio opcional («Varios»); «vincular» en un solo gesto; fuente visible | §8.3, §14.1 |
| JUG-20 | Confrontación sin indicador | Aplicado: paquete y sombrero como paciencia visible | §8.8 |
| JUG-21 | Validación nocturna sin crédito | Aplicado (ver GRA-14) | C12, C13, §12.2 |
| JUG-22 | HB3 sin ancla | Aplicado: excepción documentada | HB3, §9.9 |
| JUG-23 | C2 y C3 se confundían | Aplicado: C3 sólo T1 | C3 |
| JUG-24 | Accesibilidad | Aplicado: órbita con botón izquierdo o flechas; defectos relativos y en alto contraste; subtítulos encendidos | §14.2, §14.3, §14.7 |
| JUG-25 | Sin revelación final | Aplicado: libro mayor corregido con lápiz azul después de los créditos | §12.3 |
| EXP-01 | Lote de 1 a voluntad | Aplicado (ver GRA-17) | §8.5 |
| EXP-02 | Guardar y recargar para deshacer | Aplicado: guardado por compromiso; T25 | §7.6, §15.4, T25 |
| EXP-03 | Recorte gigante | Aplicado (ver GRA-01) | §8.1, T4 |
| EXP-04 | F1 perdido en el informe 1 | Aplicado (ver JUG-04); el bloqueo siempre va precedido de un aviso | M3, HB9 |
| EXP-05 | Relleno de lotes; §8.9 y T10 | Aplicado: conclusiones distintas y sin sellar; C1 aparte; §8.9 reescrito; presupuesto de T10 | §8.5, §8.9, T10 |
| EXP-06 | Diálogo por categoría de etiqueta | Aplicado: capas por propiedades visibles; T20b | §8.7, §15.3, T20b |
| EXP-07 | F1 con tres salidas | Aplicado: F1 exige ≥8 conclusiones y crédito | §12.1 |
| EXP-08 | Ley 2 como oráculo; Moran no reacciona a la columna | Aplicado: respuestas que remiten a fuentes; M11; fuera «Cayó uno» | HB1, M11 |
| EXP-09 | Informes sin tensión | Aplicado: crédito ante Moran y no entregar a Holmes como condiciones de F1, con avisos en el mundo (M7, M9) | §7.3, §12.1 |
| EXP-10 | Confrontación refutable con cualquier grupo | Aplicado: un grupo refutador por afirmación; «callar» | §8.8, T18 |
| EXP-11 | HC06/HB12 inconsistentes | Aplicado (ver GRA-04 y GRA-19); regreso el día 9 si no hubo presentación | HC06, HB12 |
| EXP-12 | HB13 y T8/T16 | Aplicado: disparo observable; T16 permite C6 y C7 | HB13, T16 |
| EXP-13 | Canario mal definido | Aplicado: canario = dato falso sobre Lisle mismo; cebos no cuentan; HA4 | HA4, HB11, §8.2 |
| EXP-14 | D2 y T11 insatisfacibles | Aplicado: exenciones; fusión en lugar de descarte | §9.8 D2, T11 |
| EXP-15 | Hora de M7 | Aplicado: M7 a las 22 h en el escritorio; M6 al amanecer | M6, M7 |
| EXP-16 | Invariante, T3 y T5 | Aplicado: verificador acotado; dependencia de C6 declarada; T5' | §10.3, T3, T5 |
| EXP-17 | Informes evaluados por etiquetas ocultas | Aplicado: asientos por sus valores; recortes por su texto y procedencia visible | §7.3, M2–M5, §12.1 |
| EXP-18 | Latencia del anuncio | Aplicado: cuenta el día de publicación | §7.5, §9.2, §9.3 |
| EXP-19 | D3 rompía la demora de A | Aplicado: fusión en una carta | §9.3, §9.8 D3 |
| EXP-20 | HB10 sin actor tras HB8b; M1 y el libro mayor | Aplicado: muchacho de Cotter; Lisle lleva encima el libro mayor | HB10, M1 |
| EXP-21 | Wiggins demasiado servicial | Aplicado: sólo encargos contra Moran; fuera C9.R4 | HB8, C9 |
| EXP-22 | Ventanas sin causa | Aplicado: L8 por la llave y «ya está tomada»; cajón llega el 9 T; Watson anuncia la fecha | §5, HB4 |
| EXP-23 | Catálogo como resaltador | Aplicado: ruido de época; búsqueda por concepto | §5 L2, §15.3 |
| EXP-24 | Diario como segunda procedencia; pares anidados | Aplicado: el diario hereda el origen; sin anidar | §8.1, §8.3, §10.2 |
| EXP-25 | Campos opcionales no declarados | Aplicado: en `conclusions.json` | §8.4, §15.3 |
| EXP-26 | La estructura delata el jueves | Rechazado: adivinar «jueves» no basta; la línea [Día] exige un recorte de `dia_jueves` (HC05, HC06 o latencias) en su «según» | C9 |
| EXP-27 | Moran no cambia de plan sin razón | Aplicado: vanidad («El árbol lo elige el cazador») | §4, §9.7, M5 |
| EXP-28 | Encuadre parcial sin explicación | Aplicado (ver JUG-13) | §8.1 |
| EXP-29 | Validación por el mundo de noche | Aplicado (ver GRA-14) | C12, C13 |
| EXP-30 | Registros privados mostrados sin motivo | Aplicado: D31 leído del revés en el mostrador; D30 con el pretexto del alquiler | §5 L3, L5, D31 |
| TEC-01 | `SystemFont` fuera de `C:\Dev\books` | Aplicado: Theme de cuatro ranuras sobre la fuente embebida sin respaldo del sistema; autoload; T21; decisión OFL | §14.3, T21, §16.7 |
| TEC-02 | T1 y T3 imposibles | Aplicado: categoría «garantizada por acto»; ejemplares | §10.3, T1, T3 |
| TEC-03 | BFS inviable | Aplicado: verificador acotado (monotonía, por conclusión, programación dinámica, *fuzzing*); recursos modelados | §10.3, T3 |
| TEC-04 | Selección en `RichTextLabel` frágil | Aplicado: *builder*, fin por longitud, propiedades fijas, T19 partido | §14.3, T19 |
| TEC-05 | Herencia de etiquetas sin tope | Aplicado (ver GRA-01) | §8.1, T4 |
| TEC-06 | Rectángulo 3D sin oclusión ni anclas | Aplicado: `clip_anchor`, rayos, instantánea de lámina, encuadre ajustado; T29 | §8.1, §14.4, T29 |
| TEC-07 | Luz rasante de D29b en 3D | Aplicado: *emboss* en 2D con *shader* `canvas_item` | §14.3 |
| TEC-08 | Post-proceso: Z invertida, color como pista | Aplicado: plantilla fija; `examine_text` obligatorio; Bayer 8×8; T27, T29 | §14.4, §14.5 |
| TEC-09 | Guardado y determinismo en GDScript | Aplicado: registro de eventos, `replay`, `var_to_str` o *cast*, RNG por *hash*, escritura atómica, T9 | §7.6, §9.8 D7, §15.3, §15.4 |
| TEC-10 | `AudioStreamGenerator` | Aplicado: todo WAV generado; bucles con fundido; T28 | §14.6 |
| TEC-11 | `class_name`, autoloads y *timeout* en el runner | Aplicado: sin `class_name`; `call_deferred`; *watchdog*; `Logger` | §15.4, §15.5 |
| TEC-12 | Orden de construcción riesgoso | Aplicado: H0–H7 con *spikes* primero | §15.6 |
| TEC-13 | Defectos de la Remington | Aplicado: efectos estáticos, sin ligaduras, proporcionales | §14.3 |
| TEC-14 | Zoom y lupa | Aplicado: MSDF, `Control.scale` en mm, lupa como segundo `RichTextLabel` | §14.3 |
| TEC-15 | CSG | Aplicado: `PrimitiveMesh`; CSG horneado sólo para restas | §14.4 |
| TEC-16 | Especificación de tests | Aplicado: T14 estático, T6 *lint*, T7 con *fixtures*, `rank` en `endings.json` | §12.1, §15.5 |
| TEC-17 | Caché del controlador de video fuera del repo | Aplicado como decisión del usuario; no se verificó (está prohibido leer fuera) | §16.8 |
| TEC-18 | Rendimiento y arrastre 2D→3D | Aplicado: paginación, verificador <10 s, precalentado, `Control` de arrastre | §14.3, §14.4, §10.3 |
