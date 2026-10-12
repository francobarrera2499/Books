# Concepto A — «Fe de erratas»

> Mini-GDD con el ángulo **narrativa primero**. La fuente de verdad es `design.md`; la base es `docs/research/` (canon_timeline, canon_characters, london_period, game_design_refs). Las obras se citan con los códigos de cuatro letras de la investigación. **[nuestro]** = inventado por nosotros; **⚠** = verificar. Las citas del canon quedan en inglés (dominio público).

---

## 1. Pitch y título

**Título tentativo:** *Fe de erratas*. Alternativas: *La mano del muerto*, *Un lector que entenderá*.

**Pitch.** Londres, del 27 de marzo al 5 de abril de 1894. Hace cuatro meses que la *Strand* publicó la muerte de Sherlock Holmes. Ada Pryce, mecanógrafa que pasa a máquina manuscritos para la editorial de la revista, guarda la copia al carbón de «El problema final» tal como lo escribió Watson, y el texto impreso no coincide: alguien quitó tres pasajes. Su padre cumple siete años de presidio; lo condenaron en 1891 con la banda de Moriarty usando como prueba principal los papeles de un hombre muerto. Si ese hombre vive, el juicio fue una farsa, y un tal «coronel James Moriarty» le paga a Ada para que lo demuestre.

El jugador lee, recorta y coteja las crónicas publicadas para armar un alegato. Holmes está vivo, primero en Montpellier y luego en Londres disfrazado de librero viejo. Sabe desde el primer día que Ada lo lee y responde: corrige, retira papeles, planta pistas, calla y, al final, conversa. Cada reacción revela qué teme y por qué canal se enteró. Lo que Ada tarda en descubrir es que no es la única que lee esas reacciones: su cliente la ató bajo el árbol, como a un cabrito, para que el tigre se moviera.

---

## 2. Marco temporal, corpus publicado y coherencia

### 2.1 Calendario (días de la semana verificados)

| Día | Fecha | Eventos fijos (ocurren haga lo que haga el jugador) |
|---|---|---|
| Prólogo | lun. 26 mar. 1894 (Lunes de Pascua), noche | Parker entrega la comisión del «Coronel» con £5. Tutorial: carbón contra impreso. |
| 1 | mar. 27 | Vuelve por correo la carta de Ada al *Westminster Gazette*, anotada a lápiz: «No lo es.» (H01). |
| 2 | mié. 28 | Primeras reacciones, vía Mycroft. Llega a 221B un cajón de Grenoble «para Mr. Mycroft». |
| 3 | jue. 29 | — |
| 4 | vie. 30 | Informe n.º 1 al Coronel (último correo, 17:30). Esa noche no suena el birimbao. Asesinato de Adair fuera de escena (22:00–23:20). |
| 5 | sáb. 31 | Los diarios publican «El misterio de Park Lane». Holmes viaja: ninguna reacción (H15). |
| 6 | dom. 1 abr. | Sin reparto. Museo, editorial y Somerset House cerrados (⚠ horario dominical del Museo). Una nota llega en mano (H11). |
| 7 | lun. 2 | La encuesta nombra a los compañeros de whist de Adair: Murray, Sir John Hardy, coronel Moran. Moran visita a Ada. |
| 8 | mar. 3 | Informe n.º 2. |
| 9 | mié. 4 | Arresto de Meunier en Victoria (histórico). Encuentro en la librería de Church Street. |
| 10 | jue. 5 | Informe final. 14:00, grito en 221B; 18:00, Park Lane; 21:30, Camden House (EMPT). |
| Epílogo | oct. 1903 y feb. 1927 | Ada lee EMPT y, años después, VEIL. |

Holmes está en Montpellier hasta el sábado 31 (reacciona por telegrama a través de Mycroft, con un día de demora); viaja por París y Calais; desde el domingo 1 está en Londres, en la «librería de la esquina de Church Street» que EMPT le hace inventar, y el jueves a las 14:00 se presenta en 221B «in my own person». Así se respeta EMPT: la noticia de Adair *hastened* un regreso ya planeado (el busto se encargó en Grenoble antes del crimen).

### 2.2 Qué existe publicado

- **Corpus publicado:** STUD; SIGN; las 12 *Adventures* (*Strand* jul. 1891–jun. 1892; libro 14 oct. 1892); los 12 relatos de *Memoirs* (*Strand* dic. 1892–dic. 1893, FINA en diciembre); el libro *Memoirs* (13 dic. 1893, fechado 1894, sin CARD).
- **Material jugable:** STUD, SIGN, SCAN, REDH, BOSC, TWIS, SPEC, COPP, GREE, NAVA y FINA. CARD y RESI, como easter egg.
- **Prensa real de fondo:** Gladstone y Rosebery, la Reina en Florencia, el pánico anarquista (Greenwich, Meunier), el Grand National, la final de Copa y Martin Hewitt en la *Strand* de marzo.
- **No existe en 1894:** EMPT y todo *Return*, HOUN, VALL, Hopkins, Langdale Pike. Lo que el canon cuenta después existe sólo como **hechos u objetos del mundo** (el índice de Holmes, Porlock, el busto), nunca como texto. EMPT entra únicamente en el epílogo.

### 2.3 Cómo se garantiza la coherencia

1. **Biblia de canon en datos:** cada documento lleva fecha, medio, autor y hechos que afirma; los tests verifican días de la semana, que nada cite textos posteriores y que nadie sepa lo que aún no puede saber.
2. **Reglas duras** (canon_characters §9): Mrs. Hudson no sabe nada hasta el 5 de abril; Mycroft no sale de su rutina ni pisa 221B (actúa con un escribiente y el Foreign Office); Watson no se entera (si Ada se lo dice, no le cree: en EMPT se desmaya igual); Moran no muere; Holmes no tiene romance.
3. **EMPT intacto:** sus hechos ocurren igual y a la misma hora; el juego llena huecos (HUE-01, 02, 03, 06, 07, 09) sin contradecirlos. Un test de léxico aplica la lista de anacronismos de london_period §7.

### 2.4 Inconsistencias canónicas usadas a propósito

| Inconsistencia o hueco | Uso |
|---|---|
| FINA contra las cartas del coronel James Moriarty (INC-27, HUE-01) | Eje del Pliego II: dos versiones publicadas enfrentadas. |
| Dos hermanos llamados James (INC-14) | Error de un falsificador: el coronel no existe (C7). |
| «you assert that the wall was sheer. That was not literally true» (EMPT) | Watson anotó una raspadura en la roca y Holmes la cortó de las pruebas. Primera reacción: «No lo es.» |
| Holmes leyó FINA «some months later», aunque se escribió dos años después | Lo leyó en pruebas, antes de publicarse, y lo mutiló. El epílogo de 1903 deja la mentira a la vista. |
| La frase de Steiler cortada en «He said—» | El mecanografiado conserva un párrafo posterior, basado en una carta de Steiler: «un amigo que caza». |
| Muerte de Mary; de Paddington a Kensington (HUE-06, 07) | Mary muere de tisis el 2 mar. 1893 en Kensington, adonde se mudaron buscando aire sano **[nuestro]**. |
| «In some manner he had learned of my own sad bereavement» (EMPT) | Holmes se enteró por la investigación de Ada (C15). |
| Juicio de la banda; dos miembros libres (HUE-02) | Es el juicio del padre (Pliego III). |
| «Sigerson» (HUE-03); busto de Grenoble | Publicación falsa cotejable (C6); regreso planeado (C14). |
| Herida, «James», Mrs. Turner, fechas de REDH, «seventy odd cases» | Ada los enumera en su carta de enero. Enseñan a separar el **error honesto** de Watson (sin patrón) del **corte deliberado** de Holmes (con propósito). |
| WIST en 1892, CARD fuera del libro, el 4 de mayo, el hombre de anteojos de color | Easter eggs (§13). |

---

## 3. Protagonista, historia y temas

### 3.1 Ada Pryce **[nuestro]**

Tiene 26 años y una oficina de mecanografía de una sola habitación en Exeter Street, pegada a George Newnes Ltd. Se crió sobre el taller de su padre, Thomas Pryce, grabador y litógrafo de Holywell Street, y cuando lo condenaron aprendió el oficio nuevo de las mujeres que necesitan independencia.

Investiga por tres motivos que se tensan entre sí. **Justicia:** si Holmes vivía en julio de 1891, a su padre lo condenaron con los papeles de un testigo que pudo declarar y no se dejó interrogar. **Dinero:** el Coronel paga, y ya gastó parte en el alquiler. **Orgullo de oficio:** ella pasó a máquina ese texto y alguien lo alteró.

El detonante fue su carta de enero al *Westminster Gazette* (papel verde), «La aritmética del doctor Watson», donde se le escapa que vio el texto antes de la imprenta. Esa indiscreción atrajo a los dos cazadores. Su arco va de querer derribar un mito con el texto a decidir qué verdad cuenta y cuál calla: de lectora usada como instrumento a autora del final.

### 3.2 La verdad oculta

1. **1888–1891.** Thomas Pryce graba planchas de cheques para la organización y, por mala conciencia y por £10, informa a Holmes en cifra bajo el seudónimo de **Porlock**. Holmes nunca supo quién era (VALL: «a nom-de-plume» ⚠ verificar la cita).
2. **Abril–mayo de 1891.** FINA y EMPT tal como los cuenta el canon. Moran ve a Holmes vivo en la cornisa y le arroja rocas.
3. **13–17 de julio de 1891, Old Bailey.** Juicio con la prueba del «sobre azul, casillero M». La defensa protesta que el testigo principal es un muerto cuyos papeles no se pueden interrogar; un periodista titula «La mano del muerto» y Watson repetirá la frase en FINA. Pryce no puede decir que era Porlock (Moran sigue libre y el único que podría avalarlo yace «en el fondo de un río suizo»). Siete años en Parkhurst.
4. **1892–1893.** Mary enferma y los Watson se mudan a Kensington. Muere el 2 de marzo de 1893. **Mycroft no se lo dice a Sherlock**, para que no vuelva antes de tiempo **[nuestro]**.
5. **Octubre de 1893.** Moran publica dos cartas en el *Morning Post* firmadas «coronel James Moriarty» para provocar a Watson y averiguar qué sabe. Funciona: Watson escribe FINA.
6. **Noviembre de 1893.** Ada mecanografía el manuscrito y guarda el carbón. Desde «El tratado naval», Mycroft exige que lo que toque asuntos de Estado pase por el Foreign Office; las pruebas de FINA van a él y por valija a Montpellier. Sherlock tacha tres pasajes: **A**, la raspadura de una bota en la roca (delataría su escalada); **B**, la segunda habitación que el inglés alto reservó en el Englischer Hof «para un amigo que bajaría de los montes después de cazar» (pondría en guardia a Moran); **C**, «me retuvo la mano un instante más de lo que era su costumbre» (romanticismo).
7. **Enero de 1894.** La agencia de recortes de «S. Sigerson» reexpide a Montpellier la carta de Ada; Holmes la anota y se la devuelve por medio de Mycroft.
8. **Febrero–marzo de 1894.** Moran lee la misma carta y contrata a Ada como «coronel Moriarty». No quiere probar que Holmes vive (lo sabe): quiere que **se mueva**. Hacia el 20 de marzo Holmes encarga el busto en Grenoble.

### 3.3 Actos

**Prólogo, «La copia al carbón»** (lunes 26, noche). Parker, bajito y con un birimbao, entrega la carta del Coronel: «Pruebe que el relato del doctor es falso. Informe el viernes por el último correo». Ada pone lado a lado su carbón y la *Strand* de diciembre; el primer cotejo muestra que falta una frase. Título.

**Acto I, «Fe de erratas»** (martes 27–viernes 30). Gancho: su carta publicada vuelve con «No lo es.» junto a «cortada a pico»; alguien que sabe que la pared no lo era la está leyendo. Ada recorre la editorial (pruebas, hoja de ruta, cartas de lectores), la Sala de Lectura (Journal de Genève, el juicio de 1891, Sigerson, el aviso de Mary), a Watson (sus pruebas, la carta de Steiler, el duelo), 221B (Mrs. Hudson, el índice, la cuenta de la agencia) y a Mycroft. Las reacciones son burocráticas y llegan con un día de demora: tarjetas, retiros, un escribiente con anteojos de color. Clímax: el primer informe al Coronel, donde el jugador elige qué contar. Esa noche el birimbao calla y en Park Lane alguien muere.

**Acto II, «El tigre»** (sábado 31–martes 3). El crimen de Adair llena los diarios y las reacciones se cortan un día. El domingo, sin correo, llega una nota en mano: quien escribe está en Londres, y el estilo se vuelve teatral y físico. Ada investiga al Coronel (*Army List*, Somerset House, los libros de caza de Moran, el Kelly, la encuesta). El lunes Moran la visita («un trabajo inteligente, inteligente») y pregunta «dónde», no «si». Holmes planta una factura de Montpellier demasiado perfecta, dirigida al cliente. **Giro:** el Coronel es Moran y Ada era el cebo. **Segundo giro:** su padre era Porlock, revelado por su carta cifrada, el índice de Holmes o un anuncio en clave de Holmes, que reconoce el método.

**Acto III, «La casa vacía»** (miércoles 4–jueves 5). En la librería, un viejo deforme ofrece *British Birds*, *Catullus* y *The Holy War*. En la confrontación (§8.5) Ada lo desenmascara y lo obliga a reconocer que editó su necrológica, que su «muerte» dejó preso a su propio informante y que el cliente de ella es su enemigo. Holmes, vencido, propone usar el último informe como cebo. El jueves: el informe final, el grito de Mrs. Hudson, Watson chocando con el librero en Park Lane y la silueta del busto en la persiana. Desde la calle se oyen «a strange, loud whiz and a long, silvery tinkle of broken glass» y «You fiend! You clever, clever fiend!».

**Epílogo.** Octubre de 1903: Ada, a los 35, lee en la *Strand* «…which I read with great interest some months later» y sabe que es mentira. Febrero de 1927: VEIL termina con «There is at least one reader who will understand».

### 3.4 Por qué Holmes reacciona como reacciona

Cuatro prioridades, en orden: **P1**, sostener su ficción, que es su arma contra Moran («if all the world was convinced that I was dead they would take liberties», EMPT); **P2**, proteger a Watson, a quien le causó un duelo que no puede consolar («Several times… I have taken up my pen to write to you»); **P3**, proteger a Mycroft y al Estado; **P4**, hacer salir al falsificador del coronel, de quien sospecha.

Las filtra su carácter: vanidad de artista («the joy and pride which the artist takes in his own creation»), desprecio por el romanticismo (SIGN, COPP), cortesía con las mujeres («always a chivalrous opponent», DYIN) y honor profesional («In over a thousand cases I am not aware that I have ever used my powers upon the wrong side», FINA). Por eso obstruye lo que toca P1 y P2, **no estorba** la investigación sobre el Coronel (y esa ausencia se puede leer) y, cuando descubre a Porlock, su honor le gana a su estrategia: pasa de adversario a deudor.

### 3.5 Temas y por qué es memorable

- **La mano del muerto.** Todos viven gobernados por el texto de un muerto o de un falso muerto: Watson por la última carta de Holmes, Pryce por el sobre azul, Mrs. Hudson por unas habitaciones intactas, Moran por la memoria fingida de un hermano, Holmes por la ficción que inventó.
- **El autor que desprecia la ficción.** Holmes, que se burlaba de los «fairy-tales» de Watson, escribió la mayor de todas y corrigió su propia necrológica, borrando incluso el único gesto de afecto de su despedida.
- **El costo de la ficción.** La muerte falsa dejó a un viudo sin amigo y a un informante preso.
- **La lectora.** Los dos cazadores la usan como cebo: lo que el jugador hace con las reacciones de Holmes, Moran lo hace con la investigación del jugador.

Se recuerda porque **el giro reinterpreta la mecánica central** (las reacciones provocadas eran el rastro que seguía el cazador) y porque, para quien jugó, cambian de sentido líneas del canon: «sheer», «some months later», «in some manner he had learned», el cabrito atado y «once by a woman».

---

## 4. Elenco

Diez personajes. Fuera de escena: Thomas Pryce (cartas), Mary (aviso fúnebre), Steiler (carta), Adair (encuesta).

| Personaje | Base canónica | Personalidad y habla | *Tells* | Secreto | Rol mecánico |
|---|---|---|---|---|---|
| **Ada Pryce** **[nuestro]** | Holywell St. y mecanógrafas de 1894 (london_period §3.8); «New Woman» (mar. 1894) | Precisa, seca, ira contenida. Habla poco y exacto. | Tamborilea un ritmo de teclado al pensar. | Guarda carbones sin permiso: Newnes la despediría. | Avatar. Informes y anuncios son sus compromisos. |
| **Sherlock Holmes** («el librero» desde el domingo) | «I cannot agree with those who rank modesty among the virtues» (GREE); «tinge it with romanticism» (SIGN); «a series of tales» (COPP); «The stage lost a fine actor» (SCAN) | Librero: voz cascada y servil que se le cae al precisar. Holmes: impaciente, irónico, pedante. | El soberano de Irene en la cadena («I mean to wear it on my watch chain», SCAN); sombra demasiado alta a la luz de gas; dedos amarillos de ácido pícrico; dice «untidy». | Editó FINA. No sabía quién era Porlock ni que Mary había muerto. | El reactor. Lo que hace es pista. Se lo confronta en el acto III. |
| **Dr. John H. Watson** | «my own sad bereavement», «I must have fainted for the first and the last time» (EMPT); «By Jove!» | Cálido, herido, defensivo con la memoria de Holmes; honesto con sus errores («un hombre puede ser herido más de una vez, señorita»). | Crespón de luto. Se toca el bolsillo donde guarda la carta de Reichenbach. | Las manchas del manuscrito donde escribió «tisis». | Tiene sus pruebas, la carta de Steiler y la de Holmes. Holmes lo protege (P2). |
| **Mycroft Holmes** | «audits the books in some of the government departments»; Diogenes «from quarter to five to twenty to eight»; rapé y «red silk handkerchief»; «better powers of observation than I» (GREE) | Lacónico. Deduce de golpe la vida de Ada y nunca confirma nada. | Una vez habla de su hermano en presente. Matasellos S.W. (Pall Mall). | Le ocultó a Sherlock la muerte de Mary; nunca tramitó la sucesión de su hermano. | Canal de Holmes en el acto I. Sala de Forasteros. |
| **Mrs. Hudson** | «stood in the deepest awe of him… She was fond of him, too» (DYIN); «violent hysterics» (EMPT); el «sir» constante | Leal, temerosa, sola. «Señorita» en cada frase. | Desempolva mientras habla; mira la persiana. | Guarda el correo de 221B «para Mr. Mycroft», incluida la cuenta de la agencia. | Puerta de 221B y sensor sin saberlo: avisa a Mycroft. |
| **Coronel Sebastian Moran** | Ficha del índice (EMPT): Conduit Street, Bagatelle, *Heavy Game of the Western Himalayas* (1881), *Three Months in the Jungle* (1884); «You clever, clever fiend!»; «let things be done in a legal way» | Pulido de Eton, amenaza cortés, formalista. | **Repite adjetivos** en cartas, libros y voz. Metáforas de caza (ojeadores, cebo, *machan*). | Es el «coronel James Moriarty». Mató a Adair. | Antagonista oculto. Lee los informes. |
| **Parker** | «a harmless enough fellow… a garroter by trade, and a remarkable performer upon the jew's-harp» (EMPT) | Monosílabos, amenaza sin dientes: «Al Coronel no le gusta esperar, señorita». | El birimbao. | De noche vigila a Ada; de día, 221B. | Mensajero del cliente; su doble guardia es pista (C9). |
| **Wiggins** | «an air of lounging superiority», «Yes, guv'nor» (SIGN); en 1894, un joven (⚠ inferencia) | Engreído, callejero, en registro neutro: «Sí, jefe». | Aparece en las vistas de calle donde estuvo Ada. | Cobra «la tarifa de siempre» de un caballero que telegrafía desde Francia. | Sensor de Holmes; sobornable con 1 chelín para engañarlo. |
| **Inspector Lestrade** | «I am a practical man… when I have got my evidence I come to my conclusions» (NORW, 1894); «tenacious as a bulldog» (CARD) | Sardónico: hechos contra teorías. | «Señorita» con retintín; cara de hurón. | Ninguno: es honesto. | Lleva el caso Adair. Canal de acusación formal con credibilidad agotable. |
| **Silas Hebden** **[nuestro]**, empleado de pruebas | — | Puntilloso y nervioso; recita cifras de tirada; teme al Foreign Office. | Puños manchados de tinta; cuenta en voz baja. | Mandó las pruebas a Whitehall sin decírselo a Watson. | Custodio de pruebas y cartas de lectores; sensor de Mycroft. |

---

## 5. Lugares

Ocho, con cámara fija y tres o cuatro encuadres. Todo se puede inspeccionar y nada se resalta.

1. **Oficina de Ada, Exeter Street (centro).** Escritorio con el lector de documentos; la máquina de escribir, donde se pasa en limpio el Alegato; estante con la *Strand*, *Memoirs*, STUD y SIGN; la caja del padre (Whitaker 1888 anotado, un billete de £10, cartas); la puerta del correo; el mapa para viajar; y la **ventana**, donde se ve a Wiggins de día, se oye a Parker de noche y se nota el silencio del viernes 30.
2. **George Newnes Ltd., 8–11 Southampton Street.** Mostrador, armario de pruebas, archivo de cartas de lectores, Hebden.
3. **Sala de Lectura del British Museum.** Cúpula, mesas en rayos, catálogo en anillo, papeletas blancas y verdes con **número de asiento**, la **K7** con su lector de anteojos de color, la sala de periódicos.
4. **221B Baker Street.** Diecisiete escalones; la sala conservada (rincón químico, «V. R.» a balazos, babucha persa, **índice**, álbumes). En el acto III, la calle de noche con Camden House enfrente.
5. **Club Diogenes, Sala de Forasteros.** Silencio y ventana a Pall Mall; Mycroft en su horario canónico, en la franja de la tarde.
6. **Kensington.** El consultorio de Watson (con un hueco en el segundo estante, el que el librero de EMPT ofrece llenar) y, desde el domingo, la **librería de Church Street**.
7. **Somerset House, testamentos.** 1 chelín por consulta y **prohibido copiar**: Ada sólo «memoriza» tres frases por visita.
8. **Park Lane 427, exterior** (desde el sábado). Verja de cinco pies, azafranes intactos, ventana a 20 pies, parada de coches a cien yardas, la multitud y Lestrade.

**Láminas:** dioramas 3D congelados que se generan **a partir del texto** de un documento: Reichenbach en dos ediciones (la mecanografiada muestra la raspadura, la impresa no), el Englischer Hof, la habitación de Adair según la encuesta y el banquillo de 1891. Comparar láminas es otra forma de cotejar.

---

## 6. Documentos dentro del juego

Unos treinta y dos, escritos con voz de época los **[nuestro]**. Se leen como objetos físicos.

| ID | Documento | Dónde | Detalles con peso |
|---|---|---|---|
| D01 | *Strand* dic. 1893, FINA impreso | oficina, Newnes, BM | «sheer», «none returning», «He said—», miedo a los «air-guns», «Pray give my greetings to Mrs. Watson», «the hand of the dead man». |
| D02 | Carbón del mecanografiado (nov. 1893) **[nuestro]** | oficina | Cortes A, B y C. Sombras de manchas en la línea de la «tisis» de la falsa inglesa. |
| D03 | Pruebas de galera corregidas **[nuestro]** | Newnes | Tachaduras, «omitir» con otra letra, «Meiringen» corregido, una mancha amarilla. |
| D04 | Hoja de ruta de pruebas **[nuestro]** | Newnes | «Pruebas FINA → F.O., p. M. H., jue. 9 nov.; devueltas mar. 14 nov.» |
| D05 | Pruebas de Watson **[nuestro]** | Watson | Sólo comas y una errata; no tiene los cortes. |
| D06 | Carta de Steiler a Watson, jun. 1891 **[nuestro]** | Watson | La habitación «para un amigo que caza», pagada en oro; una repisa con musgo donde trepan los buscadores de edelweiss. |
| D07 | Carta original de Holmes desde Reichenbach | Watson (no la presta) | Texto de FINA; muestra de letra. |
| D08 | Cartas del «coronel James Moriarty», *Morning Post*, lun. 9 y lun. 23 oct. 1893 **[nuestro]** | oficina, BM | Adjetivos repetidos («una persecución cruel, cruel»), metáforas de caza, «Conduit Street, W.» |
| D09 | Cartas del Coronel a Ada **[nuestro]** | oficina | Relieve seco a medio borrar «B. C. C.»; la letra de D08. Tras el informe 1: «No me diga que vive. Dígame dónde.» |
| D10 | «La aritmética del doctor Watson», *Westminster Gazette*, jue. 18 ene. 1894 **[nuestro]** | oficina | Herida, «James», Mrs. Turner, REDH, los setenta casos, la duda sobre la pared. Al dorso, «reexpedido: Montpellier». A lápiz: «No lo es.» |
| D11 | *Journal de Genève* (6 may. 1891) y Reuter (7 may.) | BM | Versión pública de la muerte. |
| D12 | *The Times*, juicio, Old Bailey, 13–17 jul. 1891 **[nuestro]** | BM | Sobre azul, Patterson, la objeción del «testigo muerto», Watson identificando la letra, la sentencia de Pryce y su frase desde el banquillo. |
| D13 | *The Times* 1892–1893, «Un viajero noruego en el Tíbet», con nota de la Royal Geographical Society **[nuestro]** | BM | «Comunicado por el Foreign Office»; una ceniza «que no figura entre las ciento cuarenta variedades del catálogo inglés». La Sociedad no conoce a Sigerson; Lhasa estaba cerrada. |
| D14 | *The Times*, sáb. 4 mar. 1893, defunciones **[nuestro]** | BM | «WATSON. — El 2, en Kensington, de tisis, Mary, amada esposa de John H. Watson, M.D.» |
| D15 | *Hart's Army List* 1894 | BM | Ningún coronel James Moriarty; sí «Moran, Sebastian, Col., ret.» (⚠ cómo listaba a los retirados). |
| D16 | Libros de Moran, 1881 y 1884 **[nuestro, títulos canónicos]** | BM | El cabrito atado, «apuntar a la silueta contra la luz», adjetivos repetidos. |
| D17 | *Whitaker's Almanack* 1888 (página reconstruida) | BM; caja del padre (anotado) | Página 534 marcada a lápiz en la copia del padre (⚠ método de VALL). |
| D18 | Somerset House: bienes de James Moriarty (1892) **[nuestro]** | Somerset House | Adjudicados a «su hermano, jefe de estación en el oeste de Inglaterra» (VALL). **No existe** sucesión de Sherlock Holmes. |
| D19 | Índice de Holmes | 221B | MORAN (texto canónico y «The second most dangerous man in London»), MORIARTY (hermano jefe de estación), PORLOCK **[nuestro]** (marca de agua de Holywell St., tinta de imprenta, Whitaker 1888, números de billetes). |
| D20 | Cuenta de la agencia de recortes **[nuestro]** | 221B | «Renovada por Mr. S. Sigerson; temas: S. Holmes, Dr. J. H. Watson; envío: poste restante, Montpellier.» |
| D21 | Cartas de lectores en Newnes **[nuestro]** | Newnes | Cancelaciones indignadas; el «Coronel» pide la dirección de Watson. |
| D22 | «El misterio de Park Lane», encuesta del 31 mar., 2 y 3 abr. | oficina, BM | Detalles de EMPT: nadie oyó el tiro, bala blanda, azafranes, dinero en pilas, la hoja con nombres de socios, los compañeros de whist del Bagatelle. Falsa pista de la prensa: anarquistas. |
| D23 | Cartas del padre desde Parkhurst (oct. 1893, feb. 1894) **[nuestro]** | oficina | Censuradas; números disfrazados de celda y cuentas; «un tal Johnson». |
| D24 | Caja del padre **[nuestro]** | oficina | Whitaker anotado, billete de £10 numerado, recibo de imprenta. |
| D25 | Reacciones de Holmes | variable | Tarjetas, telegramas, anuncios, la factura plantada, la nota del domingo, el carbón devuelto. |
| D26 | Diario de cada mañana y su columna personal | oficina | Contexto histórico, señuelos y respuestas. |
| D27 | Tomos de la *Strand* 1891–93 (escenas completas con páginas neutras) | oficina | SCAN (soberano), SIGN cap. 1 y COPP (críticas a Watson), SIGN y BOSC (140 cenizas), STUD y SIGN (herida), GREE (Mycroft), NAVA (el tratado). |
| D28 | *Memoirs* en libro, dic. 1893 | oficina | Falta CARD (easter egg). |
| D29 | Talonario de papeletas de Ada **[generado]** | oficina | Las consultas del jugador con fecha y asiento: su propio rastro. |
| D30 | Albarán ferroviario **[nuestro]** | librería, 221B | «1 busto de cera — O. Meunier, Grenoble — despachado el 24 de marzo». |
| D31 | Borradores de cartas a Watson no enviadas **[nuestro]** | librería | Opcional y emotivo. |
| D32 | Directorio Kelly 1894 | BM, Newnes | «Moran, Col. S., Conduit St.»; ninguna librería en la esquina de Church Street. |

---

## 7. Bucle central y estructura

**El día.** Por la mañana, en casa, llegan correo, telegramas y diario: ahí aparecen las reacciones. Siguen **dos franjas de campo** (mañana y tarde), una visita por franja con todo lo que se quiera hacer ahí. La **noche** es en casa: leer, redactar anuncios, telegramas e informes, mirar la calle.

**Pensar es gratis; actuar cuesta.** Leer, recortar, cotejar, proponer y comparar láminas no consume tiempo, y no hay reloj en tiempo real. Las visitas gastan franjas y dejan rastros que alguien puede leer. Hay **19 franjas de campo** (dos por día de martes a miércoles, con lugares cerrados el domingo, y una el jueves). La ruta mínima al mejor final usa unas 12 y una investigación cómoda, unas 16: el jugador elige sin pasar hambre (Pentiment; game_design_refs §3.7).

**Viajes.** Una franja y la tarifa de 1894 (1 chelín a 1 chelín 6 peniques en *hansom*). Ada tiene unas £7; el dinero sólo frena el abuso de anuncios y sobornos y es lo primero que se recorta.

**Compromisos** (acciones con consecuencia): los **informes al Coronel** (viernes 30, martes 3 y uno final el jueves), los **anuncios**, los **telegramas**, **mostrar** un documento a alguien, **acusar** ante Lestrade y **presentar pruebas** en la confrontación. Anuncios, telegramas e informes se redactan eligiendo destinatario, tema y firma entre las entradas del Índice, así el motor sabe a qué entidad se refieren sin interpretar texto libre.

**Por qué funciona.** El calendario es la columna narrativa (Overboard!): Adair muere el 30 y Holmes vuelve el 5 pase lo que pase. Lo deducido decide qué se entiende y cómo termina, no si la historia avanza, y quedarse quieto no es seguro (§11).

---

## 8. Sistema de deducción

### 8.1 Recolectar sin que el juego marque nada

- **Recorte libre:** se arrastra sobre cualquier texto, o se encuadra una región de una lámina o ilustración, y se recorta. Cada tramo tiene etiquetas ocultas (entidad, fecha, lugar, afirmación), así que el juego entiende el recorte sin haber decidido qué era recortable. Recortar lo irrelevante es parte de la deducción.
- **Los recortes sobreviven** aunque una reacción retire el documento. Holmes no lee el cuaderno.
- **El Índice** es del jugador y rima con el de Holmes: cualquier nombre, fecha o lugar recortado se vuelve entrada, y sirve para rellenar huecos, como tema de conversación (se puede preguntar a cualquiera por cualquier entrada) y para redactar compromisos.
- **El cursor es siempre una lupa.** Nada brilla; todo da al menos una línea neutra.
- **En Somerset House** se memorizan hasta tres fragmentos por visita, marcados «de memoria».

### 8.2 Cotejar

Se arrastra un recorte sobre otro y se marca *contradice* o *corrobora*. Los cotejos son del jugador y **no se validan**; validarlos sería marcar pistas. Hay un corcho opcional con hilos que no cambian de color.

### 8.3 Proponer: el Alegato

El escrito de Ada, en tres «pliegos». Cada ficha usa la forma «Campo: ___» para que el género o el número no delaten la respuesta en español (R7). Una ficha **aparece**, sin resolver, cuando Ada se cruza con su tema.

| Pliego | ID | Ficha |
|---|---|---|
| I «El texto» | P1 (C1) | Pasajes del mecanografiado que faltan en la *Strand*: ___ / ___ / ___ |
| | P2 (C2) | Por dónde pasaron las pruebas antes de volver a la imprenta: ___ |
| | P3 (C3) | Mano que hizo los cortes: ___ |
| | P4 (C4) | Cómo salió Holmes del sendero: ___ |
| | P5 (C5) | Dónde recibía Holmes su correo hasta marzo de 1894: ___ |
| | P6 (C6, opc.) | Identidad del explorador «Sigerson»: ___ |
| II «El coronel» | P7 (C7) | Pariente que administró los bienes del profesor: ___ · Coroneles Moriarty en el *Army List*: ___ |
| | P8 (C8) | Autor de las cartas «coronel James Moriarty»: ___ |
| | P9 (C9) | Lo que busca quien me paga: ___ |
| | P10 (C10) | Muerte de Adair. Autor: ___ · Arma: ___ |
| III «El juicio» | P11 (C11) | Nombre que Holmes daba a mi padre: ___ |
| | P12 (C12) | Situación del testigo principal en el juicio de julio de 1891: ___ |
| | P13 (C13) | Identidad del librero de Church Street: ___ · En Londres desde: ___ |
| | P14 (C14, opc.) | Despacho del busto desde Grenoble: ___ |
| | P15 (C15, opc.) | Cómo supo Holmes del duelo de Watson: ___ |

### 8.4 Validación

- **Lotes de tres.** Cuando tres fichas están completamente correctas, Ada las **pasa en limpio a máquina** (ráfaga de teclas, campanilla, carro). No hay respuesta casilla por casilla; lo no confirmado sigue a lápiz; las dos últimas se confirman de a pares (Obra Dinn).
- **Sin fuerza bruta.** Con 40 a 60 entradas y uno a tres campos por ficha, probar lotes de tres da del orden de 40⁶ combinaciones. Las fichas sólo aparecen cuando su tema existe. Confirmar no hace avanzar la historia: sirve para saber, y saber decide el final. Probar a ciegas no cuesta nada en el mundo, pero tampoco da premio.
- **Señal de suficiencia:** opción de ajustes **desactivada por defecto**. El título de una ficha pasa de lápiz a tinta cuando ya se leyeron fragmentos de dos rutas distintas, sin decir cuáles. Decisión abierta (§15).

### 8.5 La confrontación (acto III)

Escena al estilo Ace Attorney en la librería. Holmes sostiene cuatro afirmaciones, y cada una **acepta cualquier recorte válido** (R8):

1. «Soy un pobre librero, señorita.» Se refuta con el soberano y SCAN, la sombra alta, los dedos amarillos con la mancha de la prueba o la nota del domingo.
2. «El relato del doctor es sustancialmente cierto; yo sólo sobreviví.» Se refuta con los cortes A, B y C y la hoja de ruta.
3. «A la banda la condenaron pruebas, no mi silencio; mi ausencia no dañó a ningún inocente.» Se refuta con D12 y C11. Holmes: «I have been beaten four times—three times by men, and once by a woman. Veo que debo corregir la cifra».
4. «Su cliente es un hermano de luto.» Se refuta con C8 o C9. Si Ada no lo sabe, Holmes se lo dice, y eso baja el final.

Un error recibe respuesta en personaje («Eso prueba que leo a Bunyan, señorita»). Con **tres errores** Holmes da la entrevista por terminada y la escena queda incompleta, así que mostrarlo todo al azar no conviene.

---

## 9. Sistema de reacción de Holmes (núcleo)

### 9.1 Dos cerebros

El **Holmes-agente** sólo sabe lo que le llega por canales concretos, con demora según dónde esté, y actúa según P1–P4 y su carácter. El **director** lo sabe todo: regula el ritmo (un día de calma tras una reacción de nivel 3 o más), impone las invariantes del §10 y genera material si el jugador se estanca (dos franjas sin recortes, fichas ni lugares nuevos: el librero pasa por la calle con un libro, H16). **Nunca se reacciona a los fracasos del jugador**, sólo a acciones visibles (Alien: Isolation).

### 9.2 Canales: cómo se entera y cómo lo descubre el jugador

| Canal | Qué ve | Demora (acto I / desde el dom.) | Cómo lo descubre el jugador |
|---|---|---|---|
| Hebden → Mycroft | Pedidos de pruebas y cartas de FINA | +1 día / misma franja | Hoja de ruta; tarjeta del Diogenes. |
| Escribiente de Mycroft en la Sala de Lectura (K7, anteojos de color) | Papeletas de Ada: signatura y asiento | +1 día / +1 franja | «En uso, K7»; señalador del Diogenes. |
| Wiggins y un chico frente a la casa de Watson | Lugares que visita Ada | noche / +1 franja | Vistas de calle; con soborno, confiesa. |
| Mrs. Hudson, sin saberlo | Visitas a 221B | +1 día | «Se lo tengo que contar a Mr. Mycroft, señorita.» |
| Columna personal del *Times* | Anuncios de Ada | +1 día / mismo día | Se ve. |
| Mycroft en persona | Lo que Ada diga en la Sala de Forasteros | inmediato | Cita sus acciones. |
| **Ciegos** | Somerset House, el cuaderno, los informes, la ventana de noche | — | Nada reacciona («el perro no hizo nada durante la noche»). |

Los informes son privados: Holmes sólo se entera de ellos **por sus consecuencias**, lo que Moran hace con la información, y así deduce la filtración.

### 9.3 Escalera de postura

Sube por **amenaza** a P1–P4, nunca por errores: **0 Lector** (mira), **1 Corrector** (anota, telegrafía), **2 Archivero** (retira o presta papeles), **3 Titiritero** (planta pistas falsas para el cliente), **4 Interlocutor** (se reúne con ella). El patrón es legible: Holmes obstruye P1 y P2, no estorba lo del Coronel y lo de Porlock lo lleva al encuentro. Leer **dónde no obstruye** también es información.

### 9.4 Reacciones

Cada reacción es un parche declarativo (Overboard!): **cita la acción** que la disparó, **deja un rastro nuevo** y tiene una **variante que no corta** nada.

| ID | Disparador | Qué pasa (cita la acción) | Rastro que funciona como pista | ¿Corta? |
|---|---|---|---|---|
| H01 | Fijo, día 1 | Vuelve la carta de enero con «No lo es.» junto a «cortada a pico»; matasellos S.W. | Alguien sabe que la pared no es lisa (C4); reexpedición a Montpellier (C5); Pall Mall (C2). | No |
| H02 | Pedir en Newnes las pruebas de FINA | Tarjeta: «Mr. Mycroft Holmes saluda a Miss Pryce y le informa que la Sala de Forasteros abre de cinco menos cuarto a ocho menos veinte». Las pruebas «se enviaron al encuadernador». | La hoja de ruta sigue ahí; Mycroft vigila a Newnes (C2). | D03 |
| H03 | Papeletas sobre Sigerson, el juicio, monografías de Holmes o el *Army List* | «En uso, asiento K7.» El lector sale a almorzar y deja el volumen abierto. | Señalador del Diogenes: revela el canal. | No |
| H04 | Primera visita a Watson | Telegrama: «DEJE AL DOCTOR SU DUELO. UN LECTOR.», despachado en Pall Mall. | P2 a la vista; «Un lector» enlaza con H01. | No |
| H05 | Segunda visita a Watson, mostrarle el carbón o decirle que Holmes vive | Sus pruebas y la carta de Steiler quedan «prestadas a un caballero del Foreign Office». | Recibo «p.p. M. H.» (C2). | D05, D06 |
| H06 | Primera visita a 221B | Mrs. Hudson, compadecida, le deja ver la sala ese día. Al siguiente, «Mr. Mycroft pide que no se muestren». | Mycroft custodia los cuartos de un muerto y paga el alquiler (C4). | D19, D20 desde la 2.ª visita |
| H07 | Pedir el *Times* del 4 mar. 1893 | **Silencio:** las reacciones pendientes se atrasan 24 horas y las siguientes llegan con tono más suave. | La pausa llama la atención (C15); el recorte del aviso, en la librería. | No |
| H08 | Anuncio de Ada dirigido a Holmes | Sin respuesta directa; al día siguiente, «SIGERSON. — Florencia, el 12. — M.» | Señuelo para otro lector: primer indicio de un tercero (C9). | No |
| H09 | Desde el día 2 | Wiggins aparece donde Ada estuvo. Sobornado: «el caballero telegrafía desde Francia; los formularios dicen Montpellier». | C5; revela el canal; permite engañar a Holmes. | No |
| H10 | Acto II: el lunes si el informe 1 dio un paradero; si no, el martes | Factura de un hotel de Montpellier a nombre de «S. Sigerson», fechada el 3 de abril, en el volumen pedido. **Demasiado perfecta:** papel inglés con marca de un papelero londinense, fecha al estilo inglés, sin timbre fiscal francés (⚠). | Holmes está en Londres y quiere engañar al cliente (C9, C13). | No |
| H11 | Fijo, domingo 1, en mano | Nota sin sello que cita lo que Ada hizo el sábado. Ej.: «Su paraguas, señorita. Lo dejó junto a la parada de coches, a cien yardas: la misma distancia a la que nadie oyó el disparo». | Quien escribe está en Londres (C13); arma silenciosa (C10). | No |
| H12 | Mostrar el carbón o mencionarlo en un informe (Parker intenta comprarlo y Holmes lo ve) | El carbón desaparece; en la máquina queda una hoja escrita **con la propia máquina de Ada**: «Gracias. Se lo devolveré corregido. — Un lector». El miércoles vuelve con una mancha amarilla y «Meiringen» corregido. | La pedantería es una firma (C3). | D02 como objeto (los recortes quedan y el disparador exige haberlo leído) |
| H13 | Consultar el Whitaker de 1888 o la parte de Pryce en el juicio | Anuncio en clave Whitaker: «¿ERA PORLOCK SU PADRE? CHURCH STREET. CUATRO.» | C11, C13; invitación. | No |
| H14 | Cada visita a la librería | El escaparate comenta la última acción de Ada (*Bleak House* tras Somerset House; el jueves, los cuatro libros de EMPT). | Capa opcional. | No |
| H15 | Fijo, sábado 31 | Las reacciones del viernes no llegan. | Pausa del viajero (C13, C5). | No |
| H16 | Director, ante un estancamiento | El librero pasa por la calle de Ada. | Material nuevo. | No |
| H17 | Visita al Diogenes | Mycroft deduce la vida de Ada y cita sus papeletas y visitas; una vez dice «mi hermano detesta…» en presente. | Revela canales; testimonio para C4. | No |

**Reacciones de Moran** (ocultas hasta el giro): **M1**, cartas cada vez más exigentes («No me diga que vive. Dígame dónde.»); **M2**, Parker vigila de noche, salvo la del viernes 30; **M3**, su visita del lunes; **M4**, consecuencias deterministas de los informes: un paradero manda un agente a Montpellier (y Holmes deduce la filtración), el carbón hace que Parker ofrezca dinero, Porlock pone en peligro al padre (§12) y el informe final como cebo refuerza Camden House.

### 9.5 Cómo lo percibe el jugador sin explicación

No hay medidor de sospecha ni avisos de «Holmes reaccionó»: todo llega como objeto del mundo (el correo, una papeleta «en uso», un chico en la esquina, una ausencia, el tono de una carta). Se lee gracias a **la cita de la acción**, a **la regularidad del canal** y a **los cambios de régimen** (de burocrático y lento a teatral e inmediato; el sábado mudo; el domingo sin correo). El engaño es legítimo (sobornar a Wiggins, papeletas señuelo, lugares ciegos) y la reacción a un señuelo confirma el canal.

---

## 10. Grafo de pistas

Cada ruta usa documentos o lugares distintos de las demás.

| Conclusión | Rutas independientes | Corte posible | Ruta que **ninguna** reacción corta |
|---|---|---|---|
| C1 Texto intervenido | (a) D02 contra D01 · (b) D05 contra D01 · (c) D03 | H02 (c), H05 (b), H12 (a como objeto) | (a): los recortes quedan y H12 exige haber leído D02 |
| C2 Pruebas por el Foreign Office | (a) D04 · (b) D05 y testimonio de Watson · (c) H02 o el recibo de H05 · (d) Hebden | H05 (b) | (a), que nunca se retira, y (c) |
| C3 Holmes hizo los cortes | (a) estilo: el corte C es romanticismo según SIGN cap. 1 y COPP (D27), y el corte A sólo sirve al que sobrevivió · (b) letra de D03 contra D07 o D19 · (c) mancha amarilla («ácido pícrico», dice Watson) | H02 (b, c) | (a), todo en la oficina |
| C4 Salió trepando | (a) corte A y «none returning» · (b) D06, la repisa · (c) H01 · (d) C3: un muerto no corrige pruebas · (e) D18 sin sucesión y H06 | H05 (b), H06 (e) | (a) y (c) |
| C5 Correo en Montpellier | (a) sello al dorso de D10 · (b) D20 · (c) Wiggins (H09) | H06 (b) | (a) |
| C6 Sigerson es Holmes (opc.) | (a) D13 y las 140 cenizas (D27) · (b) D20 · (c) «comunicado por el F.O.» y C2 | H06 (b) | (a), (c) |
| C7 No existe el coronel | (a) D18, el hermano jefe de estación · (b) D15 · (c) D19 MORIARTY · (d) Watson: nunca le contestó · (e) D21 | H06 (c) | (a), lugar ciego, y (b) |
| C8 Moran escribió las cartas | (a) estilo: D08 y D09 contra D16 · (b) dirección: D08 contra D32 o D19 · (c) papel «B. C. C.» y el Bagatelle de D22 · (d) adjetivos repetidos en la visita | H06 (D19) | (a), (c), (d) |
| C9 El cliente busca el paradero de Holmes | (a) contradicción interna de M1 en D09 · (b) Parker vigila a Ada y a 221B · (c) H10, demasiado perfecta · (d) C8 | ninguna | todas |
| C10 Moran mató a Adair con fusil de aire | (a) D22 y los «air-guns» de D01 · (b) whist de D22 con el índice o el Bagatelle · (c) H11 · (d) Lestrade en Park Lane | sólo (d), si se agota su credibilidad | (a), (b) |
| C11 El padre era Porlock | (a) D19 PORLOCK y D24, por número de billete · (b) D23 descifrada con D17 · (c) H13 · (d) D12, la frase desde el banquillo | H06 (a) | (b): oficina más el Whitaker del BM o del padre |
| C12 El testigo vivía oculto durante el juicio | (a) D12 (julio de 1891) y C4 · (b) D12 y D13 (Sigerson vivo en 1892) | ninguna | (a) |
| C13 El librero es Holmes, en Londres desde el 1 | (a) soberano y SCAN · (b) sombra · (c) H11, domingo sin correo · (d) dedos amarillos y C3 · (e) H13 · (f) D32 y D30 | ninguna | (a), (b), (c) |
| C14 Regreso planeado (opc.) | (a) D30 · (b) Mrs. Hudson y el cajón del día 2 | H06 (b, si no hubo visita antes) | (a) |
| C15 Holmes supo de Mary por Ada (opc.) | (a) H07 y D29 · (b) el recorte en la librería · (c) Mycroft, si se lo confronta | ninguna | todas |

**Siempre queda una ruta.** Sólo cinco cosas cortan: H02, H05, H06, H12 y la credibilidad de Lestrade. En el **peor caso**, con todas disparadas, cada conclusión obligatoria (C1–C5, C7–C13) conserva al menos una ruta que vive en la **oficina de Ada** (D01, D02 ya recortado, D08–D10, D22–D24, D27, H01, H10, H11, H13), en un **lugar ciego** (Somerset House) o en **fuentes públicas que nadie retira** (el BM, los diarios).

**Invariantes comprobadas con tests:**
1. Toda conclusión obligatoria tiene 3 o más pistas en 2 o más documentos.
2. Para cada combinación alcanzable de disparadores de las 17 reacciones (se enumeran; son menos de 2¹⁷), cada conclusión obligatoria conserva al menos una ruta. Si un parche dejaría alguna en cero, el director aplica su variante que no corta.
3. Ninguna pista sola resuelve una ficha que pide dos pasos (H13 pregunta «¿era Porlock?», pero confirmarlo exige D23, D19 o D24).
4. Ninguna conclusión depende de un easter egg.

---

## 11. Reglas y estrategias degeneradas

| Estrategia | Por qué tienta | Por qué no conviene |
|---|---|---|
| Probar combinaciones en el Alegato | Validar es gratis | Lotes de 3 sin respuesta por casilla (del orden de 40⁶); confirmar no hace avanzar nada. |
| Contarle todo al Coronel | Parece cumplir el encargo | Moran lee cada informe: un paradero hace que Holmes se esconda más y revelar a Porlock pone en peligro al padre (F3). |
| Acusar a todos ante Lestrade | Es barato | Dos acusaciones sin hechos y no vuelve a recibirla; acusar no confirma nada. |
| Guardar, provocar a Holmes y recargar | Espiar la reacción | **Un único autoguardado** por franja, sin volver atrás, y reacciones deterministas. Dentro del mundo: «Holmes no olvida». |
| No hacer nada para no alertarlo | Evitar el costo | El calendario sigue: H01, H09, H11 y H16 traen material, los informes vencen y llega el 5 de abril. La pasividad lleva al peor final. |
| Ir a todos lados | Abarcarlo todo | 19 franjas; repetir un canal no da más de lo que ya dio. |
| Provocar reacciones para que Holmes revele respuestas | La reacción es pista | Las reacciones dicen qué teme y por dónde mira, nunca el valor de una ficha; algunas son señuelos (H08, H10). |
| Llenar la columna de anuncios | Es libre | Cuestan dinero, los leen dos cazadores y Holmes contesta una vez por tema. |
| Mostrarlo todo en la confrontación | Fuerza bruta | Tres errores y Holmes se va. |
| Sobornar siempre a Wiggins | Engañar es barato | A la segunda contradicción Holmes lo despide: «Un chelín compra a un chico, señorita; no compra un hecho». |
| Decirle a Watson que Holmes vive | Ganar un aliado | No le cree (canon), se cierra y dispara H05. |

**De dónde sale cada regla:** pensar gratis y actuar caro, para explorar sin castigo; el lote de 3, de Obra Dinn; informes privados con consecuencias y un Holmes que lee lo público pero no el cuaderno, de Orwell; reacciones deterministas con un solo guardado, de la lección de Undertale; ningún medidor de sospecha, de la luz del supervisor de Papers, Please; una confrontación que acepta cualquier prueba válida, para evitar la «lógica Ace Attorney».

---

## 12. Finales

El nivel del final depende de **lo confirmado a máquina antes de la mañana del jueves** y de la confrontación; las elecciones morales sólo cambian variantes.

| Final | Condición | Qué pasa | Coherencia con el canon |
|---|---|---|---|
| **F1 «Un lector que entenderá»** | C9, C11 y C13 confirmadas y confrontación completa | Moran cae (EMPT). Holmes, vía Mycroft, escribe al ministro del Interior (Asquith) y Pryce sale en libertad condicional en junio de 1894. Holmes le pide a Ada que no publique, «no por mí: por el doctor». | Holmes vive en público desde abril de 1894; su prohibición de publicar a Watson (1894–1903) gana un motivo más. El destino de Pryce es un hueco del canon. |
| **F2 «Fe de erratas»** | Ada publica su Alegato el jueves | Mycroft invoca la **Official Secrets Act de 1889** y el folleto se secuestra. Lo de Pryce depende de C11 y la confrontación. Holmes la despide con respeto frío. | Nada publicado sobrevive. |
| **F3 «El cabrito atado»** | C9 sin confirmar y algún informe reveló a Porlock o el paradero | Moran cae igual, por el centinela. En mayo Pryce muere en un «accidente» en las canteras de Parkhurst. | Moran sigue vivo; el veredicto queda sin especificar. |
| **F4 «La mano del muerto»** | C9 confirmada, C11 no | Moran cae; Pryce cumple la condena; ni Ada ni Holmes saben quién era Porlock. | Como F1. |

**Variantes:** pedir protección para el padre tras el giro (a Mycroft o al librero) evita F3. Hacer de cebo sólo cambia la escena; si Ada se niega: «Prefirió no atar un cabrito. Loable, e innecesario». Si Watson fue informado, el epílogo suma la culpa de Ada al leer «for the first and the last time in my life». Con C15, Holmes le pide que guarde el carbón «para el doctor, algún día».

**Epílogo común:** octubre de 1903 («some months later») y febrero de 1927 («There is at least one reader who will understand»).

---

## 13. Easter eggs

Viven en la pestaña **Marginalia** del cuaderno, sin contador. Nunca son necesarios, aparecen en lugares a los que el jugador ya va y hay como máximo uno por visita.

1. **Mrs. Turner** (SCAN): Mrs. Hudson explica quién la reemplazó en 1888.
2. **El *bull pup*** (STUD): Watson se ríe por única vez en el juego.
3. **«James»** (TWIS): «Mi segundo nombre es asunto mío, señorita» (no se afirma «Hamish»).
4. **El 4 de mayo** en STUD, en las perlas de SIGN y en Reichenbach. Holmes: «La coincidencia es el refugio del que no observa; en este caso, es sólo coincidencia».
5. ***Memoirs* sin CARD:** Hebden cuenta que Watson la retiró.
6. **WIST:** en el libro de casos de Watson, «1892» donde corresponde 1890; confunde los años del duelo.
7. **Johnson en Parkhurst**, en una carta del padre: «de mala pasta, pero comparte su tabaco» (ILLU).
8. **El hombre de anteojos de color de EMPT** es el escribiente de K7, que en Park Lane explica su teoría.
9. **El torso en los cimientos de New Scotland Yard** (1888), que Lestrade menciona refunfuñando.
10. **Martin Hewitt**, que el librero desdeña.
11. **Los diecisiete escalones**, la babucha persa y el «V. R.».
12. **El hueco del segundo estante** de Watson y la frase de EMPT: «It looks untidy, does it not?».

---

## 14. Interfaz, controles, presentación y audio

**Interfaz y controles.** Sin HUD: sólo el **calendario de escritorio** (fecha y franja) y la bolsa. Todo lo demás vive en objetos: el **lector** (papel, tipografía de imprenta o de máquina, zoom); el **cuaderno** (Recortes con filtros y búsqueda, Índice, Cotejos, Alegato, Marginalia); el **mapa**; la **ventana**. Ningún marcador, resaltado ni contador. Se juega con el ratón (clic para inspeccionar, arrastrar para recortar, cotejar o rotar láminas); Tab abre el cuaderno, C recorta, Esc cierra.

**Presentación 3D.** Cámara fija con encuadres por lugar, sin caminar. Estilo «grabado Paget»: post-proceso de 1 bit con tramado anclado a la vista y contornos por profundidad y normales, sobre papel crema. El color queda para los documentos, como dato de época (el papel verde del *Westminster*, el sobre azul). Personajes: maniquíes de primitivas con siluetas inconfundibles (Mycroft enorme, Watson con bombín, Moran con sombrero de ópera, el librero encorvado con libros, Parker bajito, Wiggins larguirucho). Las pistas visuales usan luz dinámica: la **sombra** del librero bajo un `OmniLight3D` de gas y el **destello** del soberano. Las láminas se arman con datos (utilería por variante de texto).

**Audio procedural** (`AudioStreamGenerator`): la máquina de escribir (clics con cuerpo resonante, campanilla, carro: el sonido de las confirmaciones); el **birimbao** de Parker (diente de sierra con barrido de formante); cascos sobre madera y sobre granito según el barrio; el siseo del gas, el tic-tac, las campanas del domingo; el «whiz» del fusil de aire y el vidrio; y en el epílogo, un violín sintético con unos compases de un *Lied ohne Worte* de Mendelssohn (dominio público).

**Tipografía:** `SystemFont` con fuentes del sistema (Georgia o Times New Roman para la imprenta, Courier New para la máquina). No se descarga ninguna.

---

## 15. Alcance para agentes de IA en Godot 4.7

**Objetivo:** unas 2 a 2,5 horas, con 8 lugares, 10 personajes, 15 conclusiones (12 obligatorias), unos 32 documentos (unas 25.000 palabras de texto de juego), 17 reacciones, 4 finales y 4 láminas.

**Orden de construcción:**
1. Modelo de datos (JSON o `.tres`): documentos con tramos etiquetados, entidades, fichas, rutas, reacciones como parches, calendario y biblia de canon.
2. Lector con selección y recorte (`RichTextLabel`), cuaderno y validador de lotes.
3. Franjas, mapa y conversaciones (tabla tema × personaje).
4. Motor de reacciones, director e invariantes; motor de Moran a partir de los informes.
5. Finales.
6. 3D: escenarios de CSG y primitivas, shader de grabado, generador de láminas.
7. Audio procedural.

**Tests** (*runner* propio *headless*, sin extensiones descargadas): invariantes del grafo (§10), plantillas sin fugas gramaticales, calendario, anacronismos, partidas simuladas (óptima, pasiva, fuerza bruta, «contarlo todo») y ritmo (nunca más de 2 franjas sin material nuevo).

**Qué recortar primero:** (1) el dinero; (2) C6 y C14; (3) Lestrade, cuyo papel pasa a la prensa; (4) las láminas más allá de Reichenbach; (5) el soborno de Wiggins y el escaparate (H14); (6) anuncios redactados, que pasan a opciones fijas; (7) la visita de Moran, que queda en cartas; (8) el final F2; (9) Park Lane como lugar, que queda sólo en la encuesta.

**No se recorta:** el carbón contra el impreso, la validación del Alegato, al menos 10 reacciones con canales que se puedan aprender, Porlock, la confrontación, el informe final, Camden House (aunque sea audio y una lámina) y el epílogo.

**Decisiones abiertas para el orquestador o el usuario:**
- **Señal de suficiencia:** opción desactivada por defecto; ¿se mantiene o se elimina?
- **Guardado:** único y automático, sin volver atrás; ¿se acepta?
- **Estilo:** grabado de 1 bit o sepia.
- **Datos a verificar** antes de redactar: el método Whitaker y la cita de Porlock en VALL, el horario dominical del BM, el timbre fiscal francés, el precio de un anuncio en el *Times* y cómo listaba el *Army List* a los retirados.
- **Riesgo de canon asumido:** el «coronel James Moriarty» como seudónimo de Moran. canon_characters §2.12 pide justificar cualquier elección sobre el coronel; aquí la justifican el *Army List*, la sucesión del profesor y el error del falsificador con el nombre «James». Conviene que lo revise un consejo o el auditor de canon.
