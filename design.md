# GDD - Books

## Reglas de desarrollo
-No importa que el codigo sea prolijo, siga patrones de dise;o o mejores practicas de ingenieria de software
-El codigo solamente requiere ser entendido por agentes de IA
-Las features principales del videojuego deben estar probadas y tener buena cobertura para evitar bugs
-El codigo debe ser pusheado a https://github.com/francobarrera2499/Books.git , pero no es necesario hacer commit atomicos, la idea es commitear milestones
-ESTA PROHIBIDO acceder a cualquier directorio/archivo que se encuentre fuera de nuestro directorio C:\Dev\books. 
-ESTA PROHIBIDO acceder a repositorios del usuario https://github.com/francobarrera2499 que no sea el brindado anteriormente
-Esta permitido acceder a todo lo que este en internet como las cronicas, recursos de game design, documentacion del motor, referncias a otros juegos, credenciales de git, entre otros
-Las reglas de prohibicion tienen mayor peso que las de permiso, asi que cualquier abiguedad entre ellas, se consulta, nunca se la asume
-El videojuego tiene que ser 3D y esta implementado en GODOT. Que sea 3D no significa que tengamos que movernos con WASD necesariamente o que no pueda haber cuestiones en 2D, pero tiene que esta bien pensado lo que hacemos
-Se pueden implementar cuestiones de AGENTS COUNCIL para evaluaciones profundas de ser necesarias, pero no son obligatorias
-La proridad es hacer un videojuego excelente, con menanicas, historia y feeling pulido; pero a la vez no desperdiciar tokens, de ahi salen reglas como la de que el codigo solamente es para IA, no necesita estar bien escrito para que una persona lo lea
-Al desplegar agentes en paralelo, estos deben seguir los mismos permisos y prohibiciones que te di

## Dise;o del videojuego
-El videojuego debe ser una historia basada en las cronicas de sherlock holmes publicadas, no necesariamente todas, pero que sea basado en ellas en un must
-El game loop del juego trata de investigar las publicaciones de las cronicas de sherlock, mientras el ya sabe que lo investigamos y reacciona. La reaccion es justamente lo importante del juego.
-El juego tiene que estar orientado en la epoca de las cronicas, y eso incluye toda la ambientacion
-La relacion entre las cronicas elegidas tiene que ser consistente, no puede haber saltos en el tiempo o cuestiones que no tengan sentido. En el caso que existan, tienen que ser intencionales por alguna mecanica de juego o algo relacionado
-Podemos incluir cuestiones que no tengan que ver con la investigacion principal pero que revelen easter eggs para el jugador, como secretos de los personajes o cosas asi. Debemos considerar el balance entre lo que si importa y lo que es easter egg para no contaminar todo con caminos alternativos de easter eggs.
-Las referencias en las que me baso para pensar esta idea son SHADOWS OF A DOUBT, RETURN OF THE OBRA DINN, THE CASE OF THE GOLDEN IDOL, PAPERS PLEASE, ACE ATTORNEY, pero podemos considerar otros. La idea es entender que hicieron bien estos juegos y aprender de ello
-La historia tiene que ser memorable y profunda. No existen limitaciones sobre como lograr esto
-Las reglas de dise;o del videojuego tienen que estar sustentadas, no pueden salir cosas como por ejemplo, si matar a todos los sospechosos sale más barato que deducir, se mata a todos
-MUST: la deduccion es el principal foco de este juego, ninguna conclusion puede resultar sin pista alcanzable y las conclusioens deben ser accesibles desde varios lugares. Si la reaccion de holmes afecta a las pistas, aun tiene que poder llegarse por otro lado
-Todo sirve como pista y las mecanicas tienen que favorecer esto. Ninguna pista es entregada por el juego, la idea es que el jugador razone que se considera un pista para el y que no, y que decida tambien que quiere hacer con eso.
-La UI tiene que ser limpia y no llenar las vistas de informacion apabuyante
-Podemos usar placeholders, pero tienen que entenderse aun faltando la version final
-Los personajes que participen tienen que tener personalidades distintas, e incluso esto puede revelar cosas. Considera que si es propio de la cronica tenga sentido y no le inventemos una personalidad a un personaje que ya la tiene, al menos que justifiquemos con algo como una personalidad oculta o cosas asi. Que haga sentido es un MUST
-Los lugares pueden ser de la cronica como adicionados nuestros, pero al igual que todo lo demas, tiene que hacer sentido con el resto del mundo