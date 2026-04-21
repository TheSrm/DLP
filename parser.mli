type token =
  | LAMBDA
  | TRUE
  | FALSE
  | IF
  | THEN
  | CONCAT
  | ELSE
  | SUCC
  | PRED
  | ISZERO
  | LET
  | IN
  | BOOL
  | NAT
  | STRING
  | QUIT
  | LETREC
  | FIX
  | LENGTH
  | LPAREN
  | RPAREN
  | LBRACE
  | RBRACE
  | COMMA
  | DOT
  | EQ
  | COLON
  | ARROW
  | EOF
  | INTV of (
# 34 "parser.mly"
        int
# 35 "parser.mli"
)
  | IDV of (
# 35 "parser.mly"
        string
# 40 "parser.mli"
)
  | IDT of (
# 36 "parser.mly"
        string
# 45 "parser.mli"
)
  | STRINGV of (
# 37 "parser.mly"
        string
# 50 "parser.mli"
)

val input :
  (Lexing.lexbuf  -> token) -> Lexing.lexbuf -> Lambda.command
