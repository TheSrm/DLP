%{
  open Lambda;;
%}

%token LAMBDA
%token TRUE
%token FALSE
%token IF
%token THEN
%token CONCAT
%token ELSE
%token SUCC
%token PRED
%token ISZERO
%token LET
%token IN
%token BOOL
%token NAT
%token STRING
%token QUIT
%token LETREC
%token FIX

%token LPAREN
%token RPAREN
%token DOT
%token EQ
%token COLON
%token ARROW
%token EOF
%token LENGTH

%token <int> INTV
%token <string> IDV
%token <string> STRINGV

%start input
%type <Lambda.command> input

%%

input :
    IDV EQ term EOF
        {Bind ($1, $3)}
  | term EOF
      {Eval $1 }
  | QUIT EOF
      { Quit }

term :
    appTerm
      { $1 }
  | IF term THEN term ELSE term
      { TmIf ($2, $4, $6) }
  | LAMBDA IDV COLON ty DOT term
      { TmAbs ($2, $4, $6) }
  | LET IDV EQ term IN term
      { TmLetIn ($2, $4, $6) }
  | LETREC IDV COLON ty EQ term IN term
      { TmLetIn ($2, TmFix (TmAbs ($2, $4, $6)), $8) }

appTerm :
    atomicTerm
      { $1 }
  | SUCC atomicTerm
      { TmSucc $2 }
  | PRED atomicTerm
      { TmPred $2 }
  | ISZERO atomicTerm
      { TmIsZero $2 }
  | appTerm atomicTerm
      { TmApp ($1, $2) }
  |  FIX atomicTerm (*Implementado para hacer que si escribo algo que pueda volver a meterlo de vuelta *)
      { TmFix $2 }
  | CONCAT atomicTerm atomicTerm
        { TmConcat ($2, $3) }
  | LENGTH atomicTerm
            { TmLength $2 }
            
atomicTerm :
    LPAREN term RPAREN
      { $2 }
  | TRUE
      { TmTrue }
  | FALSE
      { TmFalse }
  | IDV
      { TmVar $1 }
  | STRINGV
      { TmString $1 }
  | INTV
      { let rec f = function
            0 -> TmZero
          | n -> TmSucc (f (n-1))
        in f $1 }

ty :
    atomicTy
      { $1 }
  | atomicTy ARROW ty
      { TyArr ($1, $3) }

atomicTy :
    LPAREN ty RPAREN
      { $2 }
  | BOOL
      { TyBool }
  | NAT
      { TyNat }
  | STRING
      { TyString }
