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
%token LIST
%token QUIT
%token LETREC
%token FIX
%token LENGTH
%token NIL
%token CONS
%token ISNIL
%token HEAD
%token TAIL
%token CASE
%token OF
%token AS
%token LPAREN
%token RPAREN
%token LBRACKET
%token RBRACKET
%token LBRACE
%token RBRACE
%token LANGLE
%token RANGLE
%token PIPE
%token COMMA
%token DOT
%token EQ
%token COLON
%token ARROW
%token FATARROW
%token EOF
%token <int> INTV
%token <string> IDV
%token <string> IDT
%token <string> STRINGV

%nonassoc FATARROW
%left PIPE

%start input
%type <Lambda.command> input

%%

input :
    IDV EQ term EOF
        {Bind ($1, $3)}
  | IDT EQ ty EOF
      {BindTy ($1, $3)}
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
  | CASE term OF caseBranches
      { TmCase ($2, $4) }

appTerm :
    projTerm
      { $1 }
  | SUCC projTerm
      { TmSucc $2 }
  | PRED projTerm
      { TmPred $2 }
  | ISZERO projTerm
      { TmIsZero $2 }
  | appTerm projTerm
      { TmApp ($1, $2) }
  | FIX projTerm
      { TmFix $2 }
  | CONCAT projTerm projTerm
      { TmConcat ($2, $3) }
  | LENGTH projTerm
      { TmLength $2 }
  | CONS LBRACKET ty RBRACKET projTerm projTerm
      { TmCons ($3, $5, $6) }
  | ISNIL LBRACKET ty RBRACKET projTerm
      { TmIsNil ($3, $5) }
  | HEAD LBRACKET ty RBRACKET projTerm
      { TmHead ($3, $5) }
  | TAIL LBRACKET ty RBRACKET projTerm
      { TmTail ($3, $5) }

projTerm :
    atomicTerm
      { $1 }
  | projTerm DOT INTV
      { TmProj ($3, $1) }
  | projTerm DOT IDV
      { TmRecordProj ($3, $1) }

atomicTerm :
    LPAREN term RPAREN
      { $2 }
  | LBRACE recordTerms RBRACE
      { TmRecord $2 }
  | LBRACE tupleTerms RBRACE
      { TmTuple $2 }
  | LBRACE term RBRACE
      { TmTuple [$2] }
  | LANGLE IDV EQ term RANGLE AS ty
      { TmVariant ($2, $4, $7) }
  | TRUE
      { TmTrue }
  | FALSE
      { TmFalse }
  | IDV
      { TmVar $1 }
  | STRINGV
      { TmString $1 }
  | NIL LBRACKET ty RBRACKET
      { TmNil $3 }
  | INTV
      { let rec f = function
            0 -> TmZero
          | n -> TmSucc (f (n-1))
        in f $1 }

ty :
    atomicTy
      { $1 }
  | LIST atomicTy
      { TyList $2 }
  | atomicTy ARROW ty
      { TyArr ($1, $3) }

atomicTy :
    LPAREN ty RPAREN
      { $2 }
  | LBRACE recordTypes RBRACE
      { TyRecord $2 }
  | LBRACE tupleTypes RBRACE
      { TyTuple $2 }
  | LBRACE ty RBRACE
      { TyTuple [$2] }
  | LANGLE variantTypes RANGLE
      { TyVariant $2 }
  | BOOL
      { TyBool }
  | NAT
      { TyNat }
  | STRING
      { TyString }
  | IDT
      { TyAlias $1 }

tupleTerms :
    term COMMA term
      { [$1; $3] }
  | term COMMA tupleTerms
      { $1 :: $3 }

recordTerms :
    IDV EQ term
      { [($1, $3)] }
  | IDV EQ term COMMA recordTerms
      { ($1, $3) :: $5 }

tupleTypes :
    ty COMMA ty
      { [$1; $3] }
  | ty COMMA tupleTypes
      { $1 :: $3 }

recordTypes :
    IDV COLON ty
      { [($1, $3)] }
  | IDV COLON ty COMMA recordTypes
      { ($1, $3) :: $5 }

variantTypes :
    IDV COLON ty
      { [($1, $3)] }
  | IDV COLON ty COMMA variantTypes
      { ($1, $3) :: $5 }

caseBranches :
    caseBranch
      { [$1] }
  | caseBranch PIPE caseBranches
      { $1 :: $3 }

caseBranch :
    LANGLE IDV EQ IDV RANGLE FATARROW appTerm
      { ($2, $4, $7) }
