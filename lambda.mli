
type ty =
    TyBool
  | TyNat
  | TyString 
  | TyList of ty
  | TyTuple of ty list
  | TyRecord of (string * ty) list
  | TyArr of ty * ty
  | TyAlias of string
;;



type term =
    TmTrue
  | TmFalse
  | TmIf of term * term * term
  | TmZero
  | TmSucc of term
  | TmPred of term
  | TmIsZero of term
  | TmVar of string
  | TmAbs of string * ty * term
  | TmApp of term * term
  | TmLetIn of string * term * term
  | TmFix of term
  | TmString of string
  | TmConcat of term * term
  | TmLength of term
  | TmNil of ty
  | TmCons of ty * term * term
  | TmIsNil of ty * term
  | TmHead of ty * term
  | TmTail of ty * term
  | TmTuple of term list
  | TmProj of int * term
  | TmRecord of (string * term) list
  | TmRecordProj of string * term
;;

type command =
    Eval of term
  | Bind of string * term
  | BindTy of string * ty
  | Quit 
;;

type biding =
    TyBind of ty
  | TyTmBind of (ty * term);;

type context =
  (string * biding) list
;;


val emptyctx : context;;
val addtbinding : context -> string -> ty -> context;;
val addvbinding : context -> string -> ty -> term -> context;;

val gettbinding : context -> string -> ty;;
val getvbinding : context -> string -> term;;
val resolve_ty : context -> ty -> ty;;

val string_of_ty : ty -> string;;
exception Type_error of string;;
exception Syntax_error of string;;
val typeof : context -> term -> ty;;

val string_of_term : term -> string;;
exception NoRuleApplies;;
val eval : context -> term -> term;;

val execute : context -> command -> context;;
