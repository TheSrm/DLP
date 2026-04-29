{
  open Parser;;
  exception Lexical_error;;
}

rule token = parse
    [' ' '\t' '\n' '\r']  { token lexbuf }
  | "lambda"    { LAMBDA }
  | "L"         { LAMBDA }
  | "true"      { TRUE }
  | "false"     { FALSE }
  | "if"        { IF }
  | "then"      { THEN }
  | "else"      { ELSE }
  | "succ"      { SUCC }
  | "pred"      { PRED }
  | "iszero"    { ISZERO }
  | "let"       { LET }
  | "letrec"    { LETREC }
  | "in"        { IN }
  | "Bool"      { BOOL }
  | "Nat"       { NAT }
  | "String"    { STRING }
  | "List"      { LIST }
  | "Exit"      { QUIT }
  | "fix"       { FIX }
  | "length"    { LENGTH }
  | "nil"       { NIL }
  | "cons"      { CONS }
  | "isnil"     { ISNIL }
  | "head"      { HEAD }
  | "tail"      { TAIL }
  | '('         { LPAREN }
  | ')'         { RPAREN }
  | '['         { LBRACKET }
  | ']'         { RBRACKET }
  | '{'         { LBRACE }
  | '}'         { RBRACE }
  | ','         { COMMA }
  | '.'         { DOT }
  | '='         { EQ }
  | ':'         { COLON }
  | "->"        { ARROW }
  | "concat"    { CONCAT }
  | ['0'-'9']+  { INTV (int_of_string (Lexing.lexeme lexbuf)) }
  | ['A'-'Z']['A'-'Z' 'a'-'z' '_' '0'-'9']*
                { IDT (Lexing.lexeme lexbuf) }
  | ['a'-'z']['a'-'z' '_' '0'-'9']*
                { IDV (Lexing.lexeme lexbuf) }
  | '"' [^ '"' '\n']* '"' 
                            { let s = Lexing.lexeme lexbuf in
                              STRINGV (String.sub s 1 (String.length s - 2))}
  | eof         { EOF }
  | _           { raise Lexical_error }
