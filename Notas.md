## Notas de la primera sesión de video

Lamda mli, presenta 3 tipos de termino, TVar, TAbs, TApp, para variables sueltas, abstracciones y , por ejemplo, `(Lx. x) y`, se vería así TmApp(TmAbs("x", TmVar "x"), TmVar "y")
 y eval va a aevaluar todo hasta llegar a un NoRuleApplies y devolver lo que tenga que devolver

Lexer.mli y parser.mly tienen la función de pasar de un string a un termino, para que el usuario teclee en una sintaxis cómoda.

EN el caso del analizador léxico simpemente tenemos tokens(variables solo permitimos en minuscula, ojo), solo es interesante explicar que cambia un poco sobre lex puro, token lexbuf es algo que no nos interesa, y para devolver tokens que cambian son STRINGV Lexing.lexeme lexbuf  (esto saca del lexbuf lo que necesitamos usando lexeme del modulo lexing)

El parser ya es un poco mas complejo pero no demasiado al tener que tener en centa los 3 terminos 

Tenemos varias reglas, la primera es básica, habrá un inicial S que tendrá un termino y un fin de fichero despues

Y este termino puede ser , una abstracción, con sus partes, entonces generamos un TmAbs con ambas partes , un let in, que es una aplicación de una abstracción.

Tambien puede ser un termino que aplicammos a un termino, o un termino atómico, ya sea entre paréntesis o no 

simplemente aplicar las funciones de análisis sintáctico y léxico es hacer s token sobre algo 

LLendomos a las implementaciones que veiamos antes, el tipo term y string_of_term, que es bastante manual y un poco lo que hicimos antes , y funcinoes auxiliares para diferecia de listas y unión de listas, porque vamos a trabajar con las variables listas , solo es un poco menos mecanico saber que en una apliacaicón, la variable libre es la unión , luego tenermos un fresh_name , que es lo mas sencillo del mundo, que es intentar con el nombre y si no funcinoa, meetrle una ' al nombre

La función de substitución , es un poco mas compleja , si es una variable, y el nombre es el correcto, cambio, sino, no, si es una abstracción, tengo que ver si aplica, y si aplica(la ariable nueva no puede ser  la que va con el lamda e y no puede estar en las variables libres de s, porque sino la capturaríamos), en el caso de que estas reglas no se cumplan, necesito hacer la substitución por una variable libre,

isval, nos dice si podemos seguir bajando, y por ultimo declaramos la apbstracción 

eval1, es la regla mas importante, simplemente traduce las reglas a nuestro código, es simplemente darle el valor de nuestro código, y se llama eval 1 porque es necesario llamarla hasta que no entre ninguna regla

El segundo video introduce mas tipo, como los naturales y una estructura como el if then else, en lamda.ml, no hay mucho que destacar, salvo que true y false no tienen variables libres y que un valor contiene a los valores numéricos, en mll, metemos los tokens necesarios para reconocer y en el mly,, los colocamos para crear las expresiones, no es muy complejo., es slimilar a lo que hicimos antes pero menos abstractos


Meteremos un tipo Tmfix para la nueva recursión