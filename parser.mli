type token =
  | LAMBDA
  | TRUE
  | FALSE
  | IF
  | THEN
  | ELSE
  | SUCC
  | PRED
  | ISZERO
  | LET
  | IN
  | BOOL
  | NAT
  | LETREC
  | LPAREN
  | RPAREN
  | DOT
  | EQ
  | COLON
  | ARROW
  | EOF
  | INTV of (
# 29 "parser.mly"
        int
# 27 "parser.mli"
)
  | IDV of (
# 30 "parser.mly"
        string
# 32 "parser.mli"
)

val s :
  (Lexing.lexbuf  -> token) -> Lexing.lexbuf -> Lambda.term
