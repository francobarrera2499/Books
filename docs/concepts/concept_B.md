# Concepto B: «Fe de erratas»

> Mini-GDD de concepto con ángulo **sistemas primero**: grafo de pistas con rutas redundantes, motor de reacción de Holmes, economía sin estrategias degeneradas y una columna narrativa escrita a mano.
> Fuente de verdad: `design.md`. Base: `docs/research/` (canon_timeline, canon_characters, london_period, game_design_refs). Las citas en inglés están verificadas allí; ⚠ = cotejar con Gutenberg antes de usar. **[INV]** = invención nuestra que rellena un hueco canónico. Marcas de confianza heredadas: [V] verificado, [C] canon, [E] estimación, [?] dudoso.

---

## 1. Pitch y título

**Título tentativo:** *Fe de erratas* (alternativas: *El lector de Church Street*, *El cabrito atado*).

**Pitch.** Londres, lunes 19 de marzo de 1894. Hace tres meses que el *Strand* publicó «The Final Problem» y el mundo llora a Sherlock Holmes. Harriet Lisle, lectora de una agencia de recortes de prensa de Chancery Lane, acepta un encargo demasiado bien pagado. Un procurador que dice actuar por el coronel James Moriarty quiere un informe semanal con cada falsedad de las crónicas del doctor Watson. Harriet lee, recorta y coteja: el «Gran Juego» holmesiano, cuarenta años antes de que tuviera nombre. Pero cada vez que pisa un archivo, alguien mueve una pieza:

- un manuscrito retirado «por orden de Whitehall» al día siguiente de pedirlo;
- un número atrasado con una corrección a lápiz en el margen;
- un anuncio en la columna personal del *Times* dirigido «a la lectora de Took's Court».

Alguien la está leyendo a ella. El juego obliga a deducir dos cosas: **qué es falso en lo publicado** y **quién reacciona a la investigación, por qué canal y para qué**. Cada reacción borra una pista y deja otra: la huella del lector.

Harriet descubrirá tres cosas: que la contrata un cazador de tigres que la usa de cebo, que el viejo librero que le vende los números atrasados es el muerto, y que su propio hermano, condenado con la banda de Moriarty, le escribía a Holmes con otro nombre. Lo último que escribe es una fe de erratas: qué verdad entrega, a quién, y qué calla.

---

## 2. Marco temporal

### 2.1 Fechas

| Tramo | Fechas | Anclas |
|---|---|---|
| Prólogo | dom. 18-mar-1894, noche | Harriet abre la caja de efectos de su hermano |
| Acto I «La crónica» | lun. 19 – sáb. 24-mar | Viernes Santo 23-mar: cierra el Reading Room [V] |
| Acto II «El lector» | lun. 26 – vie. 30-mar | Feriado bancario el 26 [?]. Adair muere el 30-mar, 22:00–23:20, noche sin luna [C][E] |
| Acto III «La trampa» | sáb. 31-mar – jue. 5-abr | Indagatoria. Arresto de Meunier en Victoria el 4-abr [V]. Regreso de Holmes «in my own person» y Camden House el 5-abr (fecha BG) |
| Epílogo / coda | vie. 6-abr-1894 · oct. 1903 | Se publica «The Empty House» |

**Por qué esta ventana:**

- El corpus publicado es cerrado y pequeño (STUD, SIGN y las 24 historias del *Strand*), y FINA está fresca.
- El juego termina donde el canon retoma (EMPT), así que nada de lo que haga el jugador altera lo posterior.
- El calendario real impone restricciones: Viernes Santo, domingos sin correo, Somerset House solo por la mañana y la noche sin luna del crimen.

En total hay 15 días hábiles.

### 2.2 Qué existe el 19-mar-1894

| Categoría | Contenido |
|---|---|
| **Canon publicado (legible)** | STUD (Beeton's 1887; Ward Lock 1888/1891). SIGN (*Lippincott's* feb. 1890; Blackett oct. 1890). *Adventures* (*Strand* jul. 1891–jun. 1892; libro 14-oct-1892). *Memoirs* (*Strand* dic. 1892–dic. 1893, con CARD en ene. 1893; libro Newnes 13-dic-1893 **sin CARD**). *Strand* de mar. 1894, que estrena a Martin Hewitt |
| **Prensa del mundo** | *Journal de Genève* (6-may-1891) y Reuter (7-may-1891), citados en FINA, con texto [INV]. Parodias reales de Barrie: *My Evening with Sherlock Holmes* (1891) y *The Late Sherlock Holmes* (29-dic-1893, que acusa a Watson de matar a Holmes). *Sherlaw Kombs* (1892) |
| **Existe en el canon, contenido [INV]** | Cartas del «coronel James Moriarty» (otoño de 1893, HUE-01). Carta de «Sigerson» (HUE-03). Monografías de Holmes sobre cenizas («a hundred and forty forms», SIGN ✔). Libros de Moran: *Heavy Game of the Western Himalayas* (1881) y *Three Months in the Jungle* (1884) ✔ |
| **Documentos de época [INV]** | Crónica del juicio de 1891 en el *Times* (HUE-02). Avisos a acreedores de la *London Gazette* ⚠. Kelly's 1894. Whitaker's 1888. *Army List* |
| **Existe pero inédito** | EMPT y todo *Return*. Hechos de VALL (1888: Porlock, Birlstone). Notas de Watson. Índice de Holmes. Solo pueden aparecer como papeles privados o testimonios |
| **No existe** | Lista de anacronismos de `london_period.md` §7 (Daily Mail, Marylebone…) |

### 2.3 Coherencia garantizada

- **Calendario canónico en datos.** Cada hecho lleva `fecha_evento`, `fecha_publicacion` y `fuente` (TXT/BG/EXT/INV). Un test verifica que ningún documento ni diálogo disponible en la fecha D cite algo posterior a D, y aplica un lint de anacronismos. Si el texto da fecha, manda el texto (INC-25).
- **Columna inamovible garantizada por el Director.**
  - Adair muere el 30-mar.
  - La indagatoria dicta «wilful murder… unknown».
  - El 5-abr Holmes regresa, Mrs. Hudson tiene su ataque de histeria, Watson se desmaya y Moran cae en Camden House, con el crédito para Lestrade.
  - Nada sobre el regreso se publica antes de 1903 salvo como «ficción».

  El jugador cambia **cómo**, nunca **si**.
- **Restricciones respetadas.**
  - Mrs. Hudson no sabe que Holmes vive.
  - Mycroft nunca pisa Baker Street (su única visita es la de GREE).
  - Watson ignora todo hasta el 5-abr.
  - Sin Shinwell Johnson, sin «Martha», sin Hopkins publicado.
  - Moran no muere.

### 2.4 Inconsistencias usadas a propósito

| Inconsistencia | Uso mecánico |
|---|---|
| Tres versiones de la muerte: FINA, *Journal de Genève*, Reuter (INC-27) | Rutas de P2 y P3 por comparación |
| FINA «sheer wall» frente a EMPT «That was not literally true» ✔ | Es la reacción canónica de Holmes. Se convierte en la reacción H3: corrección a lápiz en un número atrasado |
| Dos hermanos «James» (INC-14) | Error del falsificador: las cartas son de Moran, que también es coronel (P5) |
| Fragilidad del relato del hiato (INC-28: Lhasa cerrada, Jartum frente a Omdurmán) | Refuta el desvío «Sigerson» (H6) |
| «two… at liberty» y «only one of my enemies was now left in London» ✔ | El segundo es Ludgrove, que huye el 27-mar empujado por Holmes (H11). La frase de EMPT **se vuelve cierta por eventos del juego** |
| EMPT: «called in my own person at Baker Street» ✔ | Capa oculta: Holmes está en Londres disfrazado desde el 1-mar. Su relato a Watson simplifica los hechos, con el precedente de BRUC, donde admite haberle mentido. Es intencional y se cobra en la coda de 1903 |
| Watson conoce a Moriarty en VALL, pero en FINA dice «Never» (INC-13) | Discreción de Watson: ruta de P12 y K1 |
| CARD, WIST en 1892, la herida, «James», el bull pup | Solo *marginalia* (§13) |

---

## 3. Protagonista e historia

### 3.1 Harriet Lisle [INV]

Harriet tiene 24 años y es lectora de la **Agencia de Recortes Pembury** (3 Took's Court, Chancery Lane). Vive en el altillo y lleva la agencia sola porque Mr. Pembury está en Brighton por su pecho. Tiene pase del Reading Room: más de 21 años y la recomendación de un *householder* [V]. Su oficio es leerlo todo y recortar lo que un cliente pague, como Holmes, que «docketed all paragraphs» (SCAN ✔).

**Por qué investiga.**

1. **Por el encargo.** Paga £3 por semana más gastos, más del doble del sueldo de un oficinista [V]. El precio mismo es un dato sospechoso.
2. **Por su hermano Thomas.** Thomas era copista en la academia del profesor («set up as an Army coach», FINA ✔). Lo arrestaron el 27-abr-1891 y lo condenaron con la banda a siete años por las pruebas de «pigeonhole M». Murió en la cárcel de Portland en feb. 1892 [INV, HUE-02]. Harriet odia el «romance» que Watson hizo del caso y busca la mentira que condenó a Thomas.

**Carácter.** Es precisa, seca y honesta. Su defecto es que **lee a las personas como si fueran textos**. Es la única voz narradora: anota en el margen de su cuaderno.

### 3.2 La historia verdadera (lo que se reconstruye)

| Fecha | Hecho oculto |
|---|---|
| 1888 | Thomas, como «Porlock», le manda avisos cifrados a Holmes desde dentro de la organización. Holmes nunca supo quién era (VALL: «a nom-de-plume… the pilot fish with the shark» ✔; ⚠ «defied me ever to trace him») |
| 4-may-1891 | Moran, desde lo alto, ve a Holmes vivo y le tira piedras (EMPT ✔). **Desde entonces sabe que Holmes sobrevivió** |
| jul. 1891 | En el juicio, Ludgrove, procurador de la organización, sale absuelto. Thomas calla que fue informante para proteger a Harriet de los dos que quedaron libres |
| feb. 1892 | Muere Thomas. Harriet recibe su caja: un papel cifrado, un sobre a «S. Holmes, Esq.» firmado «Porlock» y dos billetes de £10 sin gastar |
| inv. 1892–93 | Muere Mary Watson (fecha [INV]; la causa no se precisa, por respeto). Watson se muda a Kensington (HUE-07) |
| oct.–nov. 1893 | **Primera sonda de Moran:** escribe las cartas del «coronel» para forzar a Watson a contar Reichenbach. FINA prueba que Watson no sabe nada («you would not have written so convincing an account…», EMPT ✔) |
| ene. 1894 | En Montpellier, Holmes lee FINA y, por vanidad, manda al *Strand* una carta firmada «Un lector, Montpellier» corrigiendo lo de la pared |
| feb.–mar. 1894 | Mycroft le avisa que un hombre con un arpa de boca (Parker) vigila Baker Street. Holmes vuelve en secreto, encarga el busto en Grenoble («some days in doing the moulding» ✔) y el 1-mar abre la librería **«J. Basil»** en la esquina de Church Street, frente a Watson. Contrata a Wiggins como recadero |
| ~14-mar | **Segunda sonda:** Moran contrata a un lector para que investigue FINA en voz alta, contando con que quien guarda el secreto reaccionará. Elige a la hermana de Porlock, convencido de que eso atraerá a Holmes |

### 3.3 Actos y giros

**Prólogo.** Harriet abre la caja de Thomas: un papel con números («534 C2 13 127 36…», el cifrado de VALL ⚠) y un sobre firmado «Porlock».

**Acto I: La crónica.**
- **Encargo n.º 1:** «Señale toda afirmación del doctor Watson que no esté probada: la caída, las huellas, la herencia, la carta».
- **Acciones:** lectura del corpus y del archivo de la agencia; salidas a Newnes, Somerset House y Baker Street.
- **Primeras reacciones:** el manuscrito retirado, el tomo que está «en el encuadernador» y el catálogo de un librero de Kensington que ofrece «Holmesiana».
- **Conclusiones:** P1–P3.
- **Giro 1:** FINA es un relato convincente de algo que nadie vio, y **alguien vivo cuida esa versión**.

**Acto II: El lector.**
- **Encargo n.º 2:** cambia de tono. «¿Quién retiró el manuscrito? ¿Hay noticia de un explorador noruego llamado Sigerson?» ¿Por qué le importaría eso a un hermano en duelo?
- **Acciones:** Harriet mapea quién reacciona y con qué demora.
- **Conclusiones:** P4–P8.
- **Giro 2:** el cliente es el hombre que tiraba piedras en el Reichenbach.
- **Giro 3:** el anciano que le vende números atrasados lleva un mes leyéndola a ella.
- El viernes 30 muere Adair.

**Acto III: La trampa.**
- **Ultimátum:** «Nombre el lugar antes del jueves».
- Moran visita el altillo. Si Harriet ya identificó a Holmes, él le propone redactar juntos el último informe.
- **Conclusiones:** P9–P12.
- **Giro 4:** el hombre al que Harriet culpaba es el que su hermano servía, y quien la contrató es aquel de quien su hermano la protegía.
- El 5-abr, a las 21:30, Holmes caza al tigre fuera de escena gracias a lo que ella escribió o calló.

**Coda (1903).** Harriet lee «The Empty House» y descubre que en esa historia ella no existe.

### 3.4 Temas y por qué es memorable

**Temas.**

1. **Leer es cazar o cuidar.** Harriet tiene dos lectores: Moran la lee para cazar y Holmes para proteger. Ella aprende a leerlos a los dos.
2. **El duelo produce versiones.** Watson escribe para llenar un vacío, el «coronel» finge duelo, Harriet llora a Thomas y Holmes se entera del duelo de Watson desde un escaparate («In some manner he had learned of my own sad bereavement», EMPT ✔).
3. **¿De quién es una vida contada?** Watson edita, Holmes corrige, Moran falsifica y Harriet decide.
4. **El precio de la muerte fingida.** Thomas murió sin el único testigo que podía hablar por él, y Holmes nunca supo quién era Porlock.

**Momentos que el jugador contará:**

- «Retirado ayer, señorita, el día después de su visita».
- Un anuncio del *Times* con su nombre.
- El arpa de boca bajo la ventana a medianoche.
- Descubrir que las cartas del «coronel» y el propio encargo repiten adjetivos («cruel, cruel») igual que el libro de un cazador de tigres.
- Descifrar el papel del hermano.
- Escribirle el último informe al tigre.
- Encontrar en 1903 el hueco con su forma en la historia oficial.

---

## 4. Elenco

| Personaje | Base canónica | Habla y tells | Secreto | Rol mecánico |
|---|---|---|---|---|
| **Holmes / «J. Basil, librero»** | Disfraz de EMPT: «my little bookshop at the corner of Church Street» y «a tall man has to take a foot off his stature» ✔. Crítico de Watson (SIGN, COPP, EMPT ✔). Teatral, caballeroso con las mujeres (DYIN ✔), evita el crédito (NORW ✔) | Voz cascada de oficio; se le escapa la erudición. Por escrito, seco e irónico. **Tells:** tamborilea con los dedos ante un error de Watson (EMPT ✔), junta las yemas (FINA ✔), murmura «Hum!» (SCAN ✔), deja ceniza de *shag* y su silueta en la persiana es alta | Está vivo, lleva un mes en Londres y no sabe que Porlock era Thomas | Agente principal del motor de reacción; posible aliado en el acto III |
| **Dr. Watson** | Viudo («my own sad bereavement» ✔), consulta en Kensington (NORW ✔) | Cálido, divaga, dice «By Jove!». Defensivo desde que Barrie lo «acusó». Lleva cinta negra y tiene un hueco en el segundo estante (EMPT ✔) | Conoce a Porlock y a Moriarty desde 1888, y en FINA lo calló | Testigo; ruta de P12 y K1. Si Harriet le dice «Holmes vive», **no le cree** y le cierra la consulta (el canon queda intacto) |
| **Mycroft** | Pall Mall, el Diogenes y Whitehall («Mycroft has his rails», BRUC ✔); rapé y pañuelo rojo (GREE ✔); único confidente (EMPT ✔) | Notas de dos líneas en papel del Diogenes. Nunca contesta lo que se le pregunta | Paga 221B y retira documentos | **Canal** y **palanca burocrática** de Holmes. Sin trabajo de campo: solo se lo cruza en su paseo |
| **Mrs. Hudson** | Dice «sir» en cada frase y «stood in the deepest awe of him» (DYIN ✔). Ignora que Holmes vive (EMPT ✔) | Concreta y piadosa. Habla de más: «el empleado del señor Mycroft trajo *shag* fresco, aunque no hay quien lo fume» | Ninguno | Canal **sin saberlo**: cada sábado, al cobrar la renta, le reporta las visitas al empleado de Mycroft |
| **Cnel. Moran («el cliente»)** | Ficha de EMPT: Conduit Street, el Bagatelle, *Heavy Game*. Tic «You clever, clever fiend!» y legalismo ✔ | Escribe con metáforas de caza y **adjetivos duplicados** (es su huella estilística). Fuma cigarro indio | Vio vivo a Holmes en 1891, escribió las cartas del «coronel» y mata a Adair | Segundo lector: agente con canales propios (§9.5). Antagonista del acto III |
| **Silas Ludgrove** [INV] | Procurador en 4 Raymond Buildings, Gray's Inn. Segundo miembro libre de la banda (HUE-02) | Fórmulas legales («sin perjuicio»). Limpia los anteojos cuando miente | Absuelto en 1891 | Intermediario. Huye el 27-mar (carta desde Calais) |
| **Wiggins** | STUD/SIGN: «lounging superiority», «Yes, guv'nor», «hain't» ✔. ~20 años ⚠ | «El viejo paga como pagaba el señor 'Olmes» | Sospecha quién es su patrón | Canal de Holmes (vigila Gray's Inn y Took's Court). «Sobrino» en H9 |
| **Lestrade** | NORW (1894): «I am a practical man… when I have got my evidence I come to my conclusions» ✔ | Hechos, no teorías | — | Solo en el acto III, si Harriet le escribe o avisó a Adair. Recibe pruebas |

**Sin diálogo largo:**
- Parker (✔ «remarkable performer upon the jew's-harp»): leitmotiv de amenaza.
- Thomas: aparece a través de sus cartas.
- El subeditor de Newnes es un personaje funcional. No es Greenhough Smith, para no ponerle palabras a una persona real.
- Porteros y empleados.

---

## 5. Lugares

Son ocho dioramas 3D con cámara fija y órbita corta (§14).

| Lugar | Origen | Qué hay | Regla de época | Quién observa |
|---|---|---|---|---|
| **Took's Court** (hub: agencia + altillo) | Original (calle real) | Archivo de recortes con índice; referencias (Kelly's, Whitaker's 1885–94, *Strand* encuadernado); caja de Thomas; correo; ventana | Hasta 12 repartos diarios, ninguno el domingo [V] | Wiggins; Parker desde el 29-mar |
| **British Museum** (Reading Room y Newspaper Room) | Real | Catálogo con búsqueda limitada. **Depósito legal de todo lo publicado** (Copyright Act 1842 [V]) | Papeletas; **3 pedidos por visita**; cerrado el Viernes Santo | **Nadie: punto ciego** |
| **Newnes**, 8–11 Southampton St. [V] | Real | Subeditor, manuscrito y pruebas de FINA, fajo de cartas de lectores, mostrador para libreros | Horario de oficina | El librero (va martes y viernes) |
| **Somerset House** | Real | Calendarios de sucesiones 1891–93 | 10–15 h; 1 s; **no se puede copiar** [V]: se memoriza un asiento por visita | Mycroft |
| **Baker Street** (221B, la calle, Camden House) | Canon | Mrs. Hudson; cuartos conservados (índice M/P/V, álbumes, babucha persa); Parker | Visitas de 16 a 18 h [V] | Hudson → Mycroft (los sábados) |
| **Kensington, Church Street** (librería y consulta de Watson) | Canon (EMPT) | Librería «J. Basil»; enfrente, la consulta de Watson | Watson atiende por la mañana | El librero, desde el escaparate |
| **Pall Mall** (puerta del Diogenes) | Canon | Paseo de Mycroft a Whitehall (9:40 [INV]); portero | Club de caballeros: Harriet solo puede dejar tarjeta o abordarlo en la calle | Mycroft |
| **Gray's Inn** (bufete de Ludgrove) | Original | Papel secante, cajas de papel de carta, portero | Cerrado desde el 27-mar | Moran; Wiggins |

**Viaje.** Se elige en un mapa coloreado con la paleta de Booth [V]. Cada visita cuesta una franja. Dos lugares a menos de 1 km (Newnes y Somerset House) se pueden encadenar en la misma franja.

---

## 6. Documentos

I = inmutable, ninguna reacción puede quitarlo (§10.1). C = de campo, se puede cortar.

| Documento | Dónde | I/C | Detalles clave |
|---|---|---|---|
| *Strand* dic. 1893 (FINA) + ilustración de Paget | Hub, BM | I | «sheer wall»; «every disposition of my property… Mycroft» ✔; «air-guns»; roca del Daubensee; huellas. **La ilustración muestra una cornisa** |
| Extractos de STUD, SIGN, *Adventures* y *Memoirs* | Hub, BM | I | Disfraces de anciano (SIGN, TWIS), Wiggins, GREE (Mycroft), las 140 cenizas |
| *Journal de Genève* 6-may-1891 (traducido) | Hub | I | Musgo arrancado en una cornisa. Un pastor oye caer piedras «hacia las siete», con Watson ya abajo. El muchacho suizo estaba en Meiringen a las seis |
| Reuter, 7-may-1891 | Hub, BM | I | «Una segunda caída de piedras» |
| Cartas del «coronel» (3, *St James's Gazette*) | Hub | I | Adjetivos duplicados. Una frase tomada de *Heavy Game*. «Las piedras que rodaron por el sendero»: ningún relato lo menciona |
| Carta de «Sigerson» (*Times*, 1892) | Hub | I | Ceniza de té tibetano en ladrillo, «según mi pequeña investigación sobre ciento cuarenta variedades» |
| Monografía de cenizas de Holmes | BM | I | Ejemplar dedicado «S. H.»: **muestra de su letra que nadie puede quitar** |
| *Heavy Game of the Western Himalayas* | BM (y, opcionalmente, un paquete) | I | Capítulo «Del cabrito atado» [INV]; adjetivos duplicados; «el mejor tiro» |
| *Binomial Theorem* y *Army List* 1893 | BM | I | Autor: «James Moriarty». Ningún coronel James Moriarty en la lista |
| *London Gazette* 1891–93 | Hub, BM | I | Aviso por la herencia del profesor: el administrador es el hermano jefe de estación y el procurador, **Ludgrove**. **Ningún** aviso a nombre de Sherlock Holmes |
| *Times*, juicio de jul. 1891 | Hub | I | Thomas, condenado. Ludgrove, «absuelto por falta de pruebas» |
| *Times* ene. 1888, «tragedia de Birlstone» | Hub | I | Douglas, Birlstone (para P12) |
| Whitaker's 1888, p. 534 | Hub, BM | I | Clave del cifrado (la página se diseña para el mensaje de VALL ⚠) |
| Kelly's 1894 | Hub | I | Ninguna librería en esa esquina; «Moran, Col. S., Conduit St.» |
| Caja de Thomas | Hub (en posesión) | I | Papel cifrado; sobre firmado «Porlock»; cartas censuradas; dos billetes de £10 numerados |
| Encargos 1–4 y carta de Calais | Hub (en posesión) | I | Las preguntas derivan de «la verdad» a «quién vigila». Adjetivos duplicados. El n.º 2 trae por descuido «c/o Conduit Street» |
| *Times* diario | Hub, cada mañana | I | Entre 6 y 10 anuncios de relleno en la columna personal; **algunos son reacciones**, sin nada resaltado |
| *Times* 31-mar a 3-abr: Park Lane | Hub | I | Bala expansiva; nadie oyó el disparo; ventana abierta; compañeros de whist: Murray, Hardy y **Moran** ✔ |
| Manuscrito y pruebas de FINA | Newnes | C | Frase tachada: «la pared, que me pareció lisa» |
| Cartas de lectores | Newnes | C | «Un lector, Montpellier» (ene. 1894): corrige la pared; manchas de anilina |
| Calendarios de sucesiones | Somerset House | C | Sin sucesión de Holmes. La de Moriarty figura en 1892 |
| Índice de Holmes (M: Moran, Parker, Von Herder; P: Porlock) | 221B | C | M ✔. P [INV]: números de los dos billetes |
| Libro de renta | 221B | C | Pagado cada trimestre «por el empleado de Mr. M. H.» |
| Precios a lápiz de «J. Basil» | Librería, luego en posesión | I al comprar | La misma letra que la dedicatoria del BM |

---

## 7. Loop principal y estructura

**El día:**

1. Mañana en el hub: el *Times* y el correo.
2. Franja de mañana: una visita.
3. Franja de tarde: una visita.
4. Noche: leer, recortar, cotejar y proponer, gratis y sin reloj, con más repartos de correo. Al final, la **revisión nocturna** (§8.5).

Los domingos son solo de lectura.

**La semana:** cada sábado se entrega un informe (el 24 y el 31). Los lunes llega un encargo nuevo. El 3-abr llega el ultimátum.

| Recurso | Costo | Justificación |
|---|---|---|
| Tiempo (~30 franjas) | 1 franja por visita; leer y pensar es gratis | «Observar es gratis, comprometerse cuesta» (R17). No hay reloj real mientras se deduce |
| Exposición (invisible) | Toda acción observable deja rastro en un canal | Alimenta las reacciones. Se infiere del mundo, sin medidor (R15) |
| Dinero (£2 10s al empezar) | Hansom 1 s–1 s 6 d; Somerset House 1 s + 1 s; telegrama ½ d por palabra; libros de 6 d a 2 guineas [V]; anuncio ⚠ | Restricción leve con peso moral: el dinero del cliente viene del Bagatelle. Sin derrota por dinero, porque el sueldo de la agencia alcanza |
| Papeletas del BM (3 por visita) | Cada pedido es una hipótesis | Como en Her Story: la consulta ya es un razonamiento |

Duración estimada: entre 2 y 2,5 h (15 días hábiles × 7–9 min).

---

## 8. Sistema de deducción

### 8.1 Recolectar sin que el juego marque nada

- **Lectura.** Cada documento está hecho de **fragmentos** (oraciones o regiones de imagen) con etiquetas ocultas: entidad, fecha, lugar y afirmación.
- **Recorte libre.** Cualquier fragmento puede ir al cuaderno, también lo irrelevante. Es privado y gratis.
- **Dioramas.** Todo objeto se puede inspeccionar, y la mayoría es mundano. No hay brillos ni objetos privilegiados.
- **Excepciones de época.** En Somerset House se memoriza un asiento por visita, que se transcribe de noche como recorte «de memoria». En el BM, cada papeleta trae un volumen.

### 8.2 Cotejar

Se unen dos recortes como **«contradice»** o **«concuerda»**. Es privado y gratis, y nada lo valida. Un cotejo cuenta como dos recortes de fundamento.

### 8.3 Preguntas

Las preguntas nacen de **sucesos**: encargos, calendario, PNJ o reacciones. **Nunca de un recorte**, porque eso revelaría qué recorte importa. Por ejemplo, «¿Quién es el librero?» aparece tras visitar la librería, no tras recortar el Kelly's.

### 8.4 Proposiciones

Son plantillas con huecos que se llenan con **fichas de entidad salidas de los recortes del jugador**: sin recortar a Moran, no se puede escribir «Moran». Ejemplo: «Las cartas firmadas por el coronel James Moriarty las redactó [PERSONA]».

- **Fundamento obligatorio:** entre 2 y 3 casillas con recortes o cotejos de **al menos dos documentos de procedencia distinta** (Watson, Paget, prensa suiza, *Times*, Gazette, Moran, papeles privados, objetos).
- **Plantillas sin filtraciones** (R7): cada hueco incluye su determinante. Un test verifica que todo candidato sea gramatical.

### 8.5 Validación: «la noche aconseja»

Cada noche el jugador elige qué proposiciones en lápiz entran a revisión. Una proposición es correcta si el relleno es correcto **y** el fundamento pertenece a una ruta válida (§10).

- Las correctas pasan **a tinta de a 3**, como en Obra Dinn [P].
- El resto queda en lápiz sin explicación: puede ser incorrecta o el sobrante de un grupo incompleto.
- La última noche (4-abr) el grupo baja a 1.

Fallar es **privado**: ningún agente se entera (regla de Alien, R10).

### 8.6 Comprometerse ante otros

- **Presentar.** Ante un PNJ, se señala a alguien con 2 o 3 recortes de fundamento. Hay cuatro confrontaciones posibles: el librero, Mycroft, Moran y Lestrade. La respuesta depende de que el fundamento sea válido, aunque no esté en tinta. Equivocarse tiene consecuencias en el mundo (H9; Lestrade deja de recibirla).
- **Informes.** Se pueden enviar al cliente, a la prensa, a Watson, a Lestrade o al librero. Llevan proposiciones, en tinta o no, **o mentiras deliberadas**. Cada destinatario reacciona según lo que lee.

### 8.7 Por qué la fuerza bruta no conviene

- Con unas 12 fichas por hueco y unos 80 recortes, C(80,2) ≈ 3.160 pares: unos 38.000 intentos por proposición.
- Agrupadas de a 3, son unos 10¹³ intentos, con **una sola revisión por noche** y unas 17 noches.
- Acertar el nombre sin el fundamento correcto no da tinta.
- Las confrontaciones dan respuesta inmediata, pero cada error cuesta en el mundo.

---

## 9. El sistema de reacción de Holmes (núcleo)

### 9.1 Dos lectores, tres cerebros

| Cerebro | Qué sabe | Qué hace |
|---|---|---|
| **Holmes-agente** | Solo lo que le llega por canales concretos y con demora. Nunca ve el cuaderno ni las revisiones | Mantiene un **modelo de Harriet**: qué sabe, si informa a Moran, cuánto lo expone. Aplica reglas declarativas |
| **Moran-agente** | Los informes, lo que ve Parker (con un día de demora) y la prensa | Encarga, paga, presiona y amenaza |
| **Director** | Todo | Protege las rutas (§10), marca el ritmo, empuja si el jugador se estanca y garantiza la columna. **Nunca reacciona a fracasos privados** |

Arquitectura «columna + parches» (Overboard! [P]). La columna supone una Harriet pasiva. Cada reacción es un parche con condición, efecto, huella y cita. Todo es determinista.

### 9.2 Canales: la latencia es la firma

| Canal | Qué transmite | Latencia |
|---|---|---|
| **Mostrador** (la librería) | Todo lo que Harriet dice o compra allí | 0 |
| **Escaparate** | Quién entra a la consulta de Watson, pero no lo que dice | 0 |
| **Gremio** | Pedidos en editoriales y librerías | Hasta el martes o viernes siguiente, cuando el librero va a Newnes |
| **Mycroft** | Consultas en registros del Estado; su paseo | Esa noche (mensajero, 3 d [V]) |
| **Mrs. Hudson** | Visitas a 221B y lo que se preguntó | Hasta el sábado |
| **Wiggins** | Entregas en Gray's Inn, movimientos en Took's Court, Parker | Media jornada |
| **Prensa** | Lo que Harriet publique | La mañana siguiente |
| **Punto ciego** | BM, cuaderno, contenido de lo que habla con Watson o Lestrade | Nunca |

La regla se puede aprender («lo de Kensington lo sabe al instante, lo de Baker Street los sábados y lo del Museo, nunca»). Con eso el jugador dibuja la red.

### 9.3 Modelo y escalada

Holmes estima tres cosas:

- `proximidad[P]` sobre su cadena (P1–P4, P6, P8, P12);
- `informa_a_Moran` (desconocido / sí / no);
- `exposicion`.

El nivel solo sube:

| Nivel | Conducta | Condición típica |
|---|---|---|
| 0 Observación | Silencio | Inicio |
| 1 Obstrucción | Retira o cierra rutas de campo (con variante blanda) | Primer acceso a un archivo de su cadena |
| 2 Sonda y desvío | Corrección en el margen (canario) y falso Sigerson | Proximidad media a P6 o P8 |
| 3 Advertencia | Anuncio «el tigre» | Un canario confirma `informa_a_Moran` |
| 4 Reclutamiento | Se revela a medias en la trastienda | Harriet **presenta** P8 con fundamento válido, o muestra a Porlock |
| 5 Revelación | «In his own person» | 5 o 6 de abril; antes solo si ella amenaza con publicar |

### 9.4 Reglas de Holmes

| ID | Canal | Disparador (lo que se cita) | Efecto y ruta cortada | Huella y ruta creada | Variante blanda |
|---|---|---|---|---|---|
| H1 | Gremio → Mycroft | Pedir en Newnes el manuscrito de FINA | Se lo retira. Corta P2-C | Recibo: «retirado [día siguiente] por orden de Whitehall, M. H.» → P4-C | Quedan las galeradas en la imprenta |
| H1b | ídem | Pedir las cartas de lectores | Se retira el fajo. Corta P6-B | «El caballero de Whitehall se llevó también las cartas» → P4-C | Queda la copia del secretario |
| H2 | Mycroft | Buscar el testamento de «Holmes, Sherlock» | El calendario de 1891 «está en el encuadernador». Corta parte de P1-B | «Lo pidió Hacienda la mañana siguiente» → P4-C | Los de 1892 y 1893 siguen |
| H3 | Mostrador | Comprar FINA allí o mencionar «la pared» | Ejemplar anotado a lápiz: «No era lisa». **Canario:** si la frase aparece en su informe y Parker se presenta en Kensington, Holmes concluye que ella informa a Moran | Letra → P8-C; cadena del canario → P9-B | — |
| H4 | Hudson o Mycroft | Segunda visita a 221B preguntando por Mycroft o por el índice | «Órdenes del señor Mycroft»: no puede subir. Corta P1-C, P4-B, P7-C, P11-B y P12-B | La orden llega **después del sábado** → firma del canal → P4-C | Mrs. Hudson le baja **un** objeto que ella pida |
| H5 | Mycroft | Abordarlo o dejarle tarjeta | Nota: «Señorita Lisle: los muertos no tienen habitaciones. M. H.» | Papel del Diogenes, evasiva → P4-C, P6 | — |
| H6 | Mycroft | `proximidad[P6]` media | La *Pall Mall Gazette* publica: «Sigerson **telegrafía** desde Lhasa». Es un desvío **pensado para Moran** | Refutación: sin telégrafo en Lhasa en 1894 ⚠[EXT] y sin europeos allí desde 1846 [V]; «comunicado por el F. O.» → P4, P6-C | — |
| H7 | Wiggins | Primera visita a la librería | «Queda lejos Kensington de Took's Court para un número que en Holywell Street sale a cuatro peniques» | Sabe dónde vive → P8-C | — |
| H8 | Mostrador | Mencionar «Porlock» o mostrar el papel | Cierra temprano por primera vez. Al día siguiente, un paquete: copia manuscrita de la ficha «PORLOCK» | → P12-D, P8-C. Sube al nivel 4 | — |
| H9 | Mostrador | **Presentar** «usted es Holmes» sin fundamento | El viejo «está enfermo» y atiende un «sobrino». Corta P8-B por dos días | El sobrino dice «Yes, guv'nor», «hain't» (Wiggins) → P8-C | Vuelve al tercer día |
| H10 | Wiggins | Entrega de un informe tras un canario confirmado | En el *Times*: «A LA LECTORA DE TOOK'S COURT. El tigre no le paga al cabrito: lo ata. Pregúntese quién firma las instrucciones. Un lector» | → P7-D, P9-C. Eco de EMPT en 1903 | — |
| H11 | Columna (~26-mar) | — | «A S. L., DE RAYMOND BUILDINGS. El casillero M tenía dos sobres. Calais es agradable en primavera». Ludgrove huye el 27 | Crea P10-C. Vuelve **cierto el «only one… left in London»** | — |
| H12 | Director (3 franjas sin avance) | — | Paquete sin nota con *Heavy Game* | El librero conoce el encargo → P8; sirve a P5, P7 y P9 | — |
| H13 | Mostrador | Presentar P8 con fundamento válido, o nivel 4 | En la trastienda deja la voz, no el disfraz. Propone que ella siga informando a Moran y que él «corrija las pruebas» | Abre E1 | Ella puede rechazar |
| H14 | Punto ciego | BM, cuaderno | **Silencio** | El silencio es dato: el Museo es seguro | — |
| H15 | Prensa | Publicar «Holmes vive» antes del 5-abr | Nivel 5 anticipado: visita nocturna, fría. Moran también lo lee y adelanta el ultimátum | §12 | — |

### 9.5 Reacciones de Moran

| ID | Disparador | Efecto | Huella |
|---|---|---|---|
| M1 | Informe del sábado | El encargo siguiente **cita** el informe y gira hacia «quién vigila» | P9-A |
| M2 | Un informe menciona a Mycroft o Kensington (o la columna del 29-mar) | Parker bajo la ventana; arpa de boca de noche | P7-C, P9-B |
| M3 | Dos informes vacíos o falsos verificables por Parker | Le baja el pago; amenaza velada | Adjetivos duplicados → P7 |
| M4 | Un informe menciona la librería | Parker va a Kensington (cierra el canario de Holmes) | P9-B, K3 |
| M5 | Acto III, si desconfía | Registran el altillo. No se llevan pruebas, pero dejan ceniza de cigarro indio | P7 (con la monografía de cenizas) |
| M6 | Columna, 3-abr | «Nombre el lugar antes del jueves» | Precipita el final |
| M7 | Acto III | Moran en persona, como «amigo del coronel»: «astuta, astuta»; «su hermano también tenía buena mano para las cartas» | P7-E, P12-E |

**El jugador también pone canarios.** Cada afirmación que Harriet suelta queda etiquetada, y si un agente la repite, la cita revela el canal. Por ejemplo, contarle a Mrs. Hudson un dato falso sobre el violín y ver si lo menciona el librero.

### 9.6 Cómo lo percibe el jugador

Ninguna interfaz dice «Holmes reaccionó». Las reacciones se notan en el mundo:

- el comentario de un empleado;
- un recibo de retiro;
- un tomo ausente;
- un anuncio entre muchos;
- un paquete en el umbral;
- una frase del librero que no debería saber;
- el arpa de boca bajo la ventana;
- una puerta cerrada «por órdenes».

Hay como máximo una reacción fuerte por día.

### 9.7 La reacción como pista

1. **Ley de conservación de la huella.** Toda reacción que corta una ruta deja al menos un fragmento nuevo en la cadena del lector (P4, P8, P9 o K3). Con base canónica en NORW: «the knowledge of when to stop» ✔. Se verifica con un test.
2. **Cita concreta** (Nemesis): día, lugar y palabras. Revela qué le llegó a Holmes.
3. **La latencia identifica el canal** (§9.2).
4. **El silencio informa:** «The dog did nothing in the night-time» ✔.
5. **Lo que Holmes protege revela lo que teme:** las reacciones se concentran en P6 y P8, mientras que sobre Moriarty no hay ninguna.

### 9.8 Garantías del Director

- **D1:** antes de aplicar una reacción, verifica la invariante de §10. Si quedarían menos de dos rutas intactas para una proposición sin sellar, usa la variante blanda.
- **D2:** como máximo una reacción de nivel 3 o más por día, y al día siguiente solo de nivel 1 o menos.
- **D3:** tres franjas sin avance disparan un empujón.
- **D4:** la columna canónica es inevitable.
- **D5:** ninguna reacción por fracasos privados.
- **D6:** determinismo con semilla.

---

## 10. Grafo de pistas

### 10.1 Fuentes inmutables

**I** = impreso y distribuido (BM por depósito legal [V] y archivo de la agencia) o **ya en posesión de Harriet**. Por regla del motor, verificada con un test estático, **ninguna reacción tiene efecto sobre fragmentos I**.

Justificación en el mundo: Holmes puede comprar ejemplares y Mycroft retirar manuscritos, pero nadie deshace el depósito legal ni 300.000 ejemplares del *Strand*. M5 no se lleva nada porque busca el cuaderno, y Harriet lo lleva encima.

### 10.2 Conclusiones y rutas

Cada ruta exige como mínimo dos fragmentos de dos documentos de procedencia distinta. **La ruta A es siempre de fuentes solo I.**

| # | Conclusión (origen de la pregunta) | Rutas | Cortes posibles |
|---|---|---|---|
| **P1** | Holmes dispuso de sus bienes a favor de Mycroft antes de dejar Inglaterra (encargo 1) | **A:** FINA + índice de la Gazette (nada a nombre de Holmes; sí a nombre de Moriarty). **B:** Somerset House. **C:** libro de renta | B: H2 (parcial). C: H4 |
| **P2** | La pared tenía cornisa: las huellas no prueban la caída (encargo 1) | **A:** *Journal de Genève* + FINA. **B:** Paget + FINA. **C:** manuscrito tachado. **D:** nota a lápiz (H3) | C: H1 |
| **P3** | Un tercero estaba arriba después de la caída (encargo 1) | **A:** *Journal de Genève* (piedras a las 7) + Reuter + horario de FINA. **B:** cartas del «coronel» («las piedras») + FINA. **C:** Daubensee y la sonrisa de Holmes (apoyo). **D:** M7 | — |
| **P4** | Mycroft custodia los asuntos de Holmes y actúa (reacciones H1/H2 o Mrs. Hudson) | **A:** FINA (bienes; «It was my brother Mycroft») + GREE. **B:** Mrs. Hudson (renta, *shag*). **C:** huellas H1, H1b, H2, H4 y H5 | B: H4 |
| **P5** | Las cartas del «coronel» no son de un hermano; el único hermano es jefe de estación (encargo 1) | **A:** cartas + *Binomial Theorem* («James») + *Army List*. **B:** Gazette (administrador). **C:** Somerset House, 1892. **D:** papel secante de Ludgrove | D: cierre del 27-mar |
| **P6** | Holmes no murió y en 1892 escribía como Sigerson (encargo 2) | **A:** carta de Sigerson («ciento cuarenta variedades») + SIGN. **B:** carta de Montpellier. **C:** refutación de H6. **D:** P8 en tinta | B: H1b (blanda) |
| **P7** | Quien paga es el coronel Moran (encargo 2) | **A:** encargos + cartas + *Heavy Game* (estilometría). **B:** encargo 2 («c/o Conduit Street») + Kelly's. **C:** Parker + su ficha en el índice. **D:** H10 + título del libro. **E:** M5/M7 | C: H4 |
| **P8** | El librero es Sherlock Holmes (primera visita) | **A:** precio a lápiz + dedicatoria del BM. **B:** silueta, latencia 0 con Watson, Kelly's (la tienda no existía) y SIGN/TWIS (disfraces de anciano). **C:** H3, H7, H8, H9 y H12. **D:** Watson se inquieta ante los tells que le describe Harriet | B: H9 (2 días) |
| **P9** | El cliente usa a Harriet como cebo («cabrito atado») para que el protector de Holmes se delate (encargo 2) | **A:** evolución de los encargos 1→3 + capítulo «Del cabrito atado». **B:** cadena del canario. **C:** H10 | — |
| **P10** | Ludgrove, absuelto en 1891, es el intermediario (carta del 27-mar) | **A:** crónica judicial + membrete. **B:** Gazette + membrete. **C:** portero + H11 | — |
| **P11** | Moran mató a Adair con un fusil de aire (prensa del 31-mar) | **A:** indagatoria + FINA («air-guns») + *Heavy Game* («el mejor tiro»). **B:** ficha de Von Herder. **C:** Lestrade | B: H4 |
| **P12** | Thomas era «Porlock», informante de Holmes (prólogo) | **A:** papel cifrado y sobre + Whitaker's 1888 + recortes de Birlstone. **B:** ficha PORLOCK + billetes de Thomas. **C:** Watson reconoce el formato. **D:** H8. **E:** M7 | B: H4. C: si Harriet le dijo a Watson que Holmes vive |
| *K1* | Watson cree de buena fe en la muerte (conciencia) | FINA + Barrie; su reacción; la carta sin enviar «a Holmes» | — |
| *K2* | Adair ya sabía de la trampa (conciencia; solo si Harriet le escribió) | Indagatoria («figures… names») + Lestrade (notas del 27-mar) | — |
| *K3* | Holmes supo del duelo de Watson desde la librería (conciencia) | Vista del escaparate + cinta negra + hueco en el estante | — |

### 10.3 Por qué siempre queda una ruta

1. Toda P tiene una ruta A solo con fuentes I, y ninguna reacción afecta fuentes I. Por lo tanto, **ante cualquier combinación de reacciones, toda P conserva al menos una ruta**.
2. **Redundancia blanda:** D1 garantiza al menos dos rutas para toda P no sellada. H4, la reacción que más corta, tiene variante blanda. P2, P3, P9 y P10 no tienen rutas cortables.
3. **Las reacciones suman.** Por la ley de la huella, cada corte en «qué pasó» (P1, P2, P6) crea rutas en «quién vigila» (P4, P8, P9). Holmes encarece el camino, pero nunca lo cierra.
4. **Precedencia:** P11 está disponible desde el 31-mar y la parte de «huyó» de P10 desde el 27-mar. Hay un test para esto.

### 10.4 Tests obligatorios

- **(a)** Toda P tiene al menos dos rutas y al menos una solo con fuentes I, y cada ruta abarca dos o más documentos.
- **(b)** Ningún efecto toca fuentes I.
- **(c)** Un BFS sobre todas las secuencias de reacciones alcanzables comprueba que se conservan al menos dos rutas mientras P no esté sellada.
- **(d)** Ningún fragmento por sí solo es un fundamento válido (no hay atajos).
- **(e)** Todo corte deja huella.
- **(f)** Las plantillas no filtran la respuesta.
- **(g)** Coherencia de fechas.
- **(h)** Bots «fuerza bruta», «pasivo», «exhaustivo», «acusa a todos» y «solo BM»: ninguno supera a deducir.

---

## 11. Reglas y estrategias degeneradas

| Estrategia | Contramedida | Resultado |
|---|---|---|
| Probar combinaciones | Lotes de 3, fundamento obligatorio y una revisión por noche (§8.7) | Inviable |
| Recortarlo todo | Recortar no valida nada y el fundamento tiene como máximo 3 casillas | Ruido para uno mismo |
| Provocar a Holmes para sacar respuestas | Las reacciones informan **quién vigila**, no responden P1–P3 ni P5. El ritmo está limitado. Holmes cierra el canal que se le prueba dos veces («Su experimento con la señora Hudson fue elegante. No lo repita») | Solo rinde en la cadena del lector, que es su función |
| No salir, para no ser leído | Holmes la busca igual: catálogo del 22-mar, Wiggins, H12. El cliente exige tareas de campo y P8 requiere comprar en la librería | No existe «no ser leído» |
| Investigar solo en el BM (punto ciego e inmutable) | Es lento: 3 papeletas por visita y hay que saber qué pedir. Las preguntas nacen de sucesos de campo | Estilo válido, no un exploit |
| Acusar a todos o decirle a Moran «está en A, B, C o D» | Equivocarse cuesta: H9, Lestrade deja de recibirla, Moran desconfía (M3) y Parker revisa cada lugar, lo que expone la red de Holmes. Además, Holmes lo juzga al final | Siempre peor que deducir |
| Mentirle siempre a Moran | Parker verifica lo verificable (los lugares) y la amenaza se adelanta. Mentir con lo que no se puede verificar es legítimo (SpyParty) | Riesgo que se aprende |
| Guardar, provocar y recargar | **Un solo guardado automático** («Holmes no olvida») y determinismo | Sin ventaja |
| Leer la gramática de la plantilla o usar las preguntas como pista | Plantillas neutras con test; las preguntas solo nacen de sucesos | Cerrado |
| Despreocuparse del final porque es fijo | El final y el epílogo dependen del contenido del último informe | Elegir importa |

Todas las reglas tienen respaldo de época: horarios de Baedeker 1894, la prohibición de copiar en Somerset House, las papeletas del BM, las tarifas y el correo con 12 repartos. Ninguna es arbitraria.

---

## 12. Finales y coherencia con el canon posterior

| Final | Condición | Qué ocurre |
|---|---|---|
| **E1 «Los otros cañones»** | P7 y P8 conocidas y reclutamiento aceptado (H13) | Harriet y Holmes redactan el último informe: «Mycroft hizo airear los cuartos; el jueves vuelve a Baker Street». Es el cebo para el tigre («These are my other guns» ✔). A las 23 h Wiggins le trae una nota: «Su informe lo leyó el hombre indicado. S. H.». El 6-abr Holmes la visita en persona |
| **E2 «El cabrito»** | No identificó a Holmes o no se alió | Informa a Moran con honestidad o en blanco. Holmes la protege igual (Wiggins en su puerta). Se entera por el *Times* del arresto, con el crédito para Lestrade. Recibe un paquete con un juicio de Holmes sobre su método y la ficha de Porlock si llegó a esa pista |
| **E3 «La venta»** | Conocía P8 y entregó la librería a Moran | Moran encuentra la librería vacía (Wiggins dio aviso). Confirma que Holmes está en Londres y el 5 cae igual en Camden House. Holmes la visita, frío y caballeroso, y le revela quién era Porlock: ella vendió al hombre al que su hermano sirvió hasta morir |
| **E4 «La ficción»** | Publica el relato completo después del 5-abr (o lo intenta antes: H15) | Una carta anónima en la *Pall Mall Gazette* lo llama «un romance muy entretenido», la crítica de siempre de Holmes. El público lo archiva junto a Barrie y *Sherlaw Kombs*. **La verdad, publicada en el formato equivocado, se lee como ficción** |

**Modificadores.**
- **Porlock:** si está resuelto, Holmes reconoce en privado una deuda que no puede pagar en público.
- **Adair:** si Harriet le escribió, Lestrade la interroga el 3-abr. K2 consuela por deducción («Each may form his own hypothesis» ✔).
- **Watson:** si se lo contó, él no le creyó, y en 1903 ella lee que se desmayó igual.

**Coda (oct. 1903).** Harriet lee «The Empty House» y no aparece. Entiende «called in my own person». En E1 y E2 recibe un ejemplar con una nota al margen: «Omitida a petición mía. S. H.».

**Coherencia en todos los finales:**
- Adair muere el 30-mar.
- Moran es arrestado el 5-abr con el crédito para Lestrade, y sigue vivo (ILLU, 1902).
- Mrs. Hudson tiene su ataque de histeria y Watson se desmaya.
- Nada se publica antes de 1903 salvo como «ficción».
- Harriet no está en Camden House, y por eso Watson no la nombra.

---

## 13. Easter eggs (*marginalia*)

Son una capa separada, en la pestaña «Márgenes». No usan el verbo de proposición, nunca forman ruta (hay un test) y son ocho como máximo.

1. **El hombre de anteojos de color** (EMPT ✔, nunca identificado): era Wiggins.
2. **Meunier contra Meunier.** Llega a 221B una caja de «O. Meunier, Grenoble» y el *Times* del 5-abr informa del arresto del anarquista Meunier [V]. Es una pista falsa de época, refutable por el nombre, la ciudad y la palabra «cire» en el albarán.
3. **El 4 de mayo** en STUD, en las perlas de Mary y en Reichenbach. Mencionárselo a Watson abre un momento de duelo tratado con respeto.
4. **«Wisteria Lodge, marzo de 1892».** Un manuscrito de Watson en Newnes lleva la fecha **de redacción**, lo que explica INC-12.
5. **La herida, «James» y el bull pup.** Respuestas con humor que no resuelven nada.
6. **CARD fuera del libro** y el párrafo trasplantado en las pruebas (INC-18).
7. **Martin Hewitt.** El subeditor intenta vendérselo y el librero lo despacha con una línea de desprecio.
8. **El torso en los cimientos de New Scotland Yard** (1888 [V]), en el archivo de la agencia.

Al cierre aparece un recuento discreto («Notas al margen: 5/8»).

---

## 14. UI y UX, cámara, placeholders y audio

**UI limpia.**
- En pantalla solo hay un **calendario de escritorio** con la fecha y la franja. El resto son objetos del mundo.
- **Cuaderno** con cuatro pestañas: Recortes (con filtros y búsqueda), Cotejos, Preguntas/Proposiciones y Márgenes.
- **Lápiz o tinta** es la única señal de validación.
- Sin medidor de sospecha, sin lista de misiones y sin contador de pistas.
- La señal de suficiencia es opcional y viene **apagada** por defecto (§16).

**Controles.**
- Todo se hace con el mouse.
- El lector ocupa la pantalla completa y tiene zoom.
- Para recortar se arrastra sobre la oración. Para cotejar se suelta un recorte sobre otro.
- En «Preguntar por…» se acepta **cualquier ficha o recorte**.

**Cámara y 3D.**
- El hub tiene cámara fija con un paralaje leve.
- Los dioramas son escenas congeladas con órbita corta (Obra Dinn, la «Danza de la deducción»).
- **Dioramas derivados del texto:** Reichenbach en tres versiones conmutables (FINA, *Journal de Genève* y Paget) y Park Lane según la indagatoria. Cambiar la fuente cambia la geometría, así que comparar dioramas es otra forma de cotejar.

**Placeholders legibles.**
- **Personajes:** maniquíes de primitivas con un rasgo de silueta cada uno: el librero encorvado con patillas blancas y libros, Watson con bigote y cinta negra, Mycroft voluminoso con pañuelo rojo, Mrs. Hudson con cofia, Moran con chistera de ópera y bigote erizado, Wiggins alto con gorra, Lestrade estrecho y Parker agachado con el arpa.
- **Estilo:** grabado a dos tintas, con *hatching* anclado al mundo y contornos Sobel, como la plumilla de Paget. Las marcas del jugador van en lápiz gris y en tinta sepia.
- **Luz:** gris perla de día y gas ámbar de noche.
- **Clima:** el registrado en 1894. Sin niebla, salvo en los recuerdos.

**Audio procedural** (AudioStreamGenerator):
- Cascos sobre madera o granito, ruedas, reloj, papel, siseo del gas, campanas aditivas y pregones de vendedores de diarios.
- **Leitmotivs:** el arpa de boca de Parker (FM) suena solo cuando él está. Un violín suena **una única vez**, la noche del 5-abr, desde Baker Street.

---

## 15. Alcance realista (Godot 4.7, implementado por agentes)

**Volumen:**

| Elemento | Cantidad |
|---|---|
| Lugares | 8 |
| Dioramas | 10 |
| Personajes con diálogo | 8 |
| Documentos | ~45 (12 largos, entre ellos FINA completa traducida) |
| Conclusiones | 12 principales + 3 de conciencia + 8 *marginalia* |
| Reglas de reacción | 15 de Holmes + 7 de Moran |
| Finales | 4 + 3 modificadores |

**Datos en JSON:** `documents` (fragmentos con etiquetas), `routes`, `templates`, `reactions` (disparador, condición, efecto, huella, cita, variante), `calendar`, `channels` y `characters`.

**Sistemas:** World, Calendar, Channels, HolmesAgent, MoranAgent, Director, Notebook, Validator, DioramaBuilder y Audio.

**Tests:** GUT en modo headless vía `C:\Dev\books\godot.sh`. Cubren §10.4, determinismo y bots.

**Orden de construcción:**
1. Prototipo «de tablas» sin 3D: documentos, cuaderno, validación y la ruta A de P1–P3.
2. Canales y reacciones H1–H5.
3. Librería y cadena del lector (P4–P9).
4. Acto III y finales.
5. Dioramas y estilo.
6. Audio.
7. *Marginalia*.

**Qué recortar primero, en orden:**
1. Pall Mall (Mycroft solo por notas; se pierde H5).
2. Gray's Inn (Ludgrove visita el hub).
3. Lestrade y el modificador Adair (K2).
4. La memorización en Somerset House.
5. Las tres versiones del diorama de Reichenbach.
6. E4, que se fusiona con E2.
7. *Marginalia* 5–8.
8. P3 y P10 (mínimo, 10 conclusiones).

**No se recorta nunca:** el hub, el BM, la librería, Newnes y 221B; el motor de canales y latencias; la validación por lotes; la ley de la huella; P2 y P4–P9.

---

## 16. Decisiones abiertas y riesgos

1. **Cartas del «coronel» falsificadas por Moran.** Usa INC-14 de forma intencional y audaz. Alternativa: el coronel existe y Moran le redactó las cartas.
2. **Holmes en Londres desde el 1-mar.** Contradice la letra de su relato en EMPT. Es intencional (precedente en BRUC; el detalle «in my own person»). Alternativa: llega hacia el 22-mar.
3. **Porlock = Thomas.** Rellena un hueco de VALL. Hay que cotejar las citas ⚠ y el cifrado con Gutenberg #3289.
4. **Wiggins en 1894.** Es plausible, pero no canónico después del hiato.
5. **Guardado:** único automático, o libre con determinismo.
6. **Señal de suficiencia:** aquí queda apagada por defecto.
7. **Estilo:** grabado a dos tintas o sepia.
8. **Peso moral de la carta a Adair:** K2 lo atenúa para que no sea una culpa gratuita.
9. **Pendiente de verificar:** la falta de telégrafo en Lhasa en 1894, la práctica de avisos a acreedores en la *Gazette*, la tarifa de anuncios del *Times* y el feriado del 26-mar.
