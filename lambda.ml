
(* TYPE DEFINITIONS *)

type ty =
    TyBool
  | TyNat
  | TyString
  | TyTuple of ty list
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
  | TmTuple of term list
  | TmProj of int * term
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

exception Type_error of string
;;

exception Syntax_error of string
;;


(* CONTEXT MANAGEMENT *)

let emptyctx =
  []
;;

let addtbinding ctx x ty =
  (x, TyBind ty) :: ctx
;;

let addvbinding ctx x ty t =
  (x, TyTmBind (ty, t)) :: ctx
;;

let gettbinding ctx x =
  match List.assoc x ctx with
  | TyBind ty -> ty
  | TyTmBind (ty, _) -> ty
;;

let getvbinding ctx x =
  match List.assoc x ctx with
  | TyTmBind (_, t) -> t
  | _ -> raise Not_found
;;


(* TYPE MANAGEMENT (TYPING) *)

let rec string_of_ty ty = match ty with
    TyBool ->
      "Bool"
  | TyNat ->
      "Nat"
  | TyString ->
     "String"
  | TyTuple tys ->
      "{" ^ String.concat ", " (List.map string_of_ty tys) ^ "}"
  | TyArr (ty1, ty2) ->
      "(" ^ string_of_ty ty1 ^ ")" ^ " -> " ^ "(" ^ string_of_ty ty2 ^ ")"
  | TyAlias x ->
      x
;;

let resolve_ty ctx ty =
  let rec aux visited ty = match ty with
      TyBool ->
        TyBool
    | TyNat ->
        TyNat
    | TyString ->
        TyString
    | TyTuple tys ->
        TyTuple (List.map (aux visited) tys)
    | TyArr (ty1, ty2) ->
        TyArr (aux visited ty1, aux visited ty2)
    | TyAlias name ->
        if List.mem name visited then
          raise (Type_error ("cyclic type alias " ^ name))
        else (* SI es un alias, buscamos en el contexto si está y si es un alias de tipo o de término*)
          match List.assoc_opt name ctx with
              Some (TyBind real_ty) -> aux (name :: visited) real_ty
            | Some (TyTmBind _) ->
                raise (Type_error (name ^ " is a term binding, not a type alias"))
            | None ->
                raise (Type_error ("unknown type alias " ^ name))
  in
  aux [] ty
;;

let rec typeof ctx tm = match tm with
    (* T-True *)
    TmTrue ->
      TyBool

    (* T-False *)
  | TmFalse ->
      TyBool

    (* T-If *)
  | TmIf (t1, t2, t3) ->
      if resolve_ty ctx (typeof ctx t1) = TyBool then
        let tyT2 = resolve_ty ctx (typeof ctx t2) in
        if resolve_ty ctx (typeof ctx t3) = tyT2 then tyT2
        else raise (Type_error "arms of conditional have different types")
      else
        raise (Type_error "guard of conditional not a boolean")

    (* T-Zero *)
  | TmZero ->
      TyNat

    (* T-Succ *)
  | TmSucc t1 ->
      if resolve_ty ctx (typeof ctx t1) = TyNat then TyNat
      else raise (Type_error "argument of succ is not a number")

    (* T-Pred *)
  | TmPred t1 ->
      if resolve_ty ctx (typeof ctx t1) = TyNat then TyNat
      else raise (Type_error "argument of pred is not a number")

    (* T-Iszero *)
  | TmIsZero t1 ->
      if resolve_ty ctx (typeof ctx t1) = TyNat then TyBool
      else raise (Type_error "argument of iszero is not a number")

    (* T-Var *)
  | TmVar x ->
      (try resolve_ty ctx (gettbinding ctx x) with
       _ -> raise (Type_error ("no binding type for variable " ^ x)))

    (* T-Abs *)
  | TmAbs (x, tyT1, t2) ->
      let tyT1' = resolve_ty ctx tyT1 in
      let ctx' = addtbinding ctx x tyT1' in
      let tyT2 = resolve_ty ctx' (typeof ctx' t2) in
      TyArr (tyT1', tyT2)

    (* T-App *)
  | TmApp (t1, t2) ->
      let tyT1 = resolve_ty ctx (typeof ctx t1) in
      let tyT2 = resolve_ty ctx (typeof ctx t2) in
      (match tyT1 with
           TyArr (tyT11, tyT12) ->
             if tyT2 = tyT11 then tyT12
             else raise (Type_error "parameter type mismatch")
         | _ -> raise (Type_error "arrow type expected"))

    (* T-Let *)
  | TmLetIn (x, t1, t2) ->
      let tyT1 = resolve_ty ctx (typeof ctx t1) in
      let ctx' = addtbinding ctx x tyT1 in
      resolve_ty ctx' (typeof ctx' t2)

  | TmFix t1 ->
      let tyT1 = resolve_ty ctx (typeof ctx t1) in
      (match tyT1 with
           TyArr (tyT11, tyT12) ->
             if tyT11 = tyT12 then tyT11
             else raise (Type_error "result of body not compatible with domain")
         | _ -> raise (Type_error "arrow type expected"))

  | TmString _ ->
      TyString

  | TmConcat (t1, t2) ->
      if resolve_ty ctx (typeof ctx t1) = TyString && resolve_ty ctx (typeof ctx t2) = TyString then TyString
      else raise (Type_error "arguments of concat must be strings")

  | TmLength t ->
      if resolve_ty ctx (typeof ctx t) = TyString then TyNat
      else raise (Type_error "length requires a string argument")

  | TmTuple terms ->
      TyTuple (List.map (fun term -> resolve_ty ctx (typeof ctx term)) terms)

  | TmProj (index, term) ->
      (* La proyeccion devuelve el tipo guardado en la posicion solicitada. *)
      (match resolve_ty ctx (typeof ctx term) with
           TyTuple tys ->
             if index < 1 || index > List.length tys then
               raise (Type_error "tuple projection index out of bounds")
             else
               List.nth tys (index - 1)
         | _ -> raise (Type_error "tuple type expected in projection"))
;;


(* TERMS MANAGEMENT (EVALUATION) *)

let rec string_of_term = function
    TmTrue ->
      "true"
  | TmFalse ->
      "false"
  | TmIf (t1,t2,t3) ->
      "if " ^ "(" ^ string_of_term t1 ^ ")" ^
      " then " ^ "(" ^ string_of_term t2 ^ ")" ^
      " else " ^ "(" ^ string_of_term t3 ^ ")"
  | TmZero ->
      "0"
  | TmSucc t ->
     let rec f n t' = match t' with
          TmZero -> string_of_int n
        | TmSucc s -> f (n+1) s
        | _ -> "succ " ^ "(" ^ string_of_term t ^ ")"
      in f 1 t
  | TmPred t ->
      "pred " ^ "(" ^ string_of_term t ^ ")"
  | TmIsZero t ->
      "iszero " ^ "(" ^ string_of_term t ^ ")"
  | TmVar s ->
      s
  | TmAbs (s, tyS, t) ->
      "(lambda " ^ s ^ ":" ^ string_of_ty tyS ^ ". " ^ string_of_term t ^ ")"
  | TmApp (t1, t2) ->
      "(" ^ string_of_term t1 ^ " " ^ string_of_term t2 ^ ")"
  | TmLetIn (s, t1, t2) ->
      "let " ^ s ^ " = " ^ string_of_term t1 ^ " in " ^ string_of_term t2
  | TmFix t ->
      "fix " ^ "(" ^ string_of_term t ^ ")"
  | TmString s ->
      "\"" ^ s ^ "\""
  | TmConcat (t1, t2) ->
      "concat " ^ "(" ^ string_of_term t1 ^ ") " ^ "(" ^ string_of_term t2 ^ ")"
  | TmLength t ->
      "length " ^ "(" ^ string_of_term t ^ ")"
  | TmTuple terms ->
      "{" ^ String.concat ", " (List.map string_of_term terms) ^ "}"
  | TmProj (index, term) ->
      "proj " ^ string_of_int index ^ " (" ^ string_of_term term ^ ")"
;;

let rec ldif l1 l2 = match l1 with
    [] -> []
  | h::t -> if List.mem h l2 then ldif t l2 else h::(ldif t l2)
;;

let rec lunion l1 l2 = match l1 with
    [] -> l2
  | h::t -> if List.mem h l2 then lunion t l2 else h::(lunion t l2)
;;

let rec free_vars tm = match tm with
    TmTrue ->
      []
  | TmFalse ->
      []
  | TmIf (t1, t2, t3) ->
      lunion (lunion (free_vars t1) (free_vars t2)) (free_vars t3)
  | TmZero ->
      []
  | TmSucc t ->
      free_vars t
  | TmPred t ->
      free_vars t
  | TmIsZero t ->
      free_vars t
  | TmVar s ->
      [s]
  | TmAbs (s, _, t) ->
      ldif (free_vars t) [s]
  | TmApp (t1, t2) ->
      lunion (free_vars t1) (free_vars t2)
  | TmLetIn (s, t1, t2) ->
      lunion (ldif (free_vars t2) [s]) (free_vars t1)
  | TmFix t ->
      free_vars t
  | TmString _ ->
      []
  | TmConcat (t1, t2) ->
      lunion (free_vars t1) (free_vars t2)
  | TmLength t ->
      free_vars t
  | TmTuple terms ->
      (* Las variables libres de una tupla son la union de las de cada componente. *)
      List.fold_left (fun vars term -> lunion vars (free_vars term)) [] terms
  | TmProj (_, term) ->
      free_vars term
;;

let rec fresh_name x l =
  if not (List.mem x l) then x else fresh_name (x ^ "'") l
;;

let rec subst x s tm = match tm with
    TmTrue ->
      TmTrue
  | TmFalse ->
      TmFalse
  | TmIf (t1, t2, t3) ->
      TmIf (subst x s t1, subst x s t2, subst x s t3)
  | TmZero ->
      TmZero
  | TmSucc t ->
      TmSucc (subst x s t)
  | TmPred t ->
      TmPred (subst x s t)
  | TmIsZero t ->
      TmIsZero (subst x s t)
  | TmVar y ->
      if y = x then s else tm
  | TmAbs (y, tyY, t) ->
      if y = x then tm
      else let fvs = free_vars s in
           if not (List.mem y fvs)
           then TmAbs (y, tyY, subst x s t)
           else let z = fresh_name y (free_vars t @ fvs) in
                TmAbs (z, tyY, subst x s (subst y (TmVar z) t))
  | TmApp (t1, t2) ->
      TmApp (subst x s t1, subst x s t2)
  | TmLetIn (y, t1, t2) ->
      if y = x then TmLetIn (y, subst x s t1, t2)
      else let fvs = free_vars s in
           if not (List.mem y fvs)
           then TmLetIn (y, subst x s t1, subst x s t2)
           else let z = fresh_name y (free_vars t2 @ fvs) in
                TmLetIn (z, subst x s t1, subst x s (subst y (TmVar z) t2))
  | TmFix t ->
      TmFix (subst x s t)
  | TmString s ->
      TmString s
  | TmConcat (t1, t2) ->
      TmConcat (subst x s t1, subst x s t2)
  | TmLength t ->
      TmLength (subst x s t)
  | TmTuple terms ->
      (* La sustitucion se aplica por separado a cada componente de la tupla. *)
      TmTuple (List.map (subst x s) terms)
  | TmProj (index, term) ->
      TmProj (index, subst x s term)
;;

let rec isnumericval tm = match tm with
    TmZero -> true
  | TmSucc t -> isnumericval t
  | _ -> false
;;

let rec isval tm = match tm with
    TmTrue  -> true
  | TmFalse -> true
  | TmAbs _ -> true
  | TmString _ -> true
  | TmTuple terms -> List.for_all isval terms
  | t when isnumericval t -> true
  | _ -> false
;;

let rec nat_of_int n =
  if n <= 0 then TmZero else TmSucc (nat_of_int (n - 1))
;;



exception NoRuleApplies
;;

let rec eval1 ctx tm = match tm with
    (* E-IfTrue *)
    TmIf (TmTrue, t2, _) ->
      t2

    (* E-IfFalse *)
  | TmIf (TmFalse, _, t3) ->
      t3

    (* E-If *)
  | TmIf (t1, t2, t3) ->
      let t1' = eval1 ctx t1 in
      TmIf (t1', t2, t3)

    (* E-Succ *)
  | TmSucc t1 ->
      let t1' = eval1 ctx t1 in
      TmSucc t1'

    (* E-PredZero *)
  | TmPred TmZero ->
      TmZero

    (* E-PredSucc *)
  | TmPred (TmSucc nv1) when isnumericval nv1 ->
      nv1

    (* E-Pred *)
  | TmPred t1 ->
      let t1' = eval1 ctx t1 in
      TmPred t1'

    (* E-IszeroZero *)
  | TmIsZero TmZero ->
      TmTrue

    (* E-IszeroSucc *)
  | TmIsZero (TmSucc nv1) when isnumericval nv1 ->
      TmFalse

    (* E-Iszero *)
  | TmIsZero t1 ->
      let t1' = eval1 ctx t1 in
      TmIsZero t1'

    (* E-AppAbs *)
  | TmApp (TmAbs(x, _, t12), v2) when isval v2 ->
      subst x v2 t12

    (* E-App2: evaluate argument before applying function *)
  | TmApp (v1, t2) when isval v1 ->
      let t2' = eval1 ctx t2 in
      TmApp (v1, t2')

    (* E-App1: evaluate function before argument *)
  | TmApp (t1, t2) ->
      let t1' = eval1 ctx t1 in
      TmApp (t1', t2)

    (* E-LetV *)
  | TmLetIn (x, v1, t2) when isval v1 ->
      subst x v1 t2

    (* E-Let *)
  | TmLetIn(x, t1, t2) ->
      let t1' = eval1 ctx t1 in
      TmLetIn (x, t1', t2)
    (*E -FixBeta*) (*Si nos llega un termino totalmente evaluado, hago la recursividad como tal *)
  | TmFix (TmAbs(x, _, t)) ->
      subst x tm  t

   (* E-Fix *)
  | TmFix t1 ->
      let t1' = eval1 ctx t1 in
      TmFix t1'

   (* E-Concat *) 
  | TmConcat (TmString s1, TmString s2) ->
      TmString (s1 ^ s2)
      
    (* E-Concat *) 
  | TmConcat (TmString s1, t2) ->
      let t2' = eval1 ctx t2 in
      TmConcat (TmString s1, t2')

     (* E-Concat *) 
  | TmConcat (t1, TmString s2) ->
    let t1' = eval1 ctx t1 in
    TmConcat (t1', TmString s2)

  | TmConcat (t1, t2) ->
      let t1' = eval1 ctx t1 in
      TmConcat (t1', t2)

  | (* E-Length *)
    TmLength (TmString s) ->
      nat_of_int (String.length s)

  | (* E-LengthEval *)
    TmLength t ->
      let t' = eval1 ctx t in
      TmLength t'

  | TmTuple terms ->
      (* Se evaluan las componentes de izquierda a derecha hasta que todas sean valores. *)
      eval_tuple_elements ctx [] terms

  | TmProj (index, TmTuple terms) when List.for_all isval terms ->
      if index < 1 || index > List.length terms then
        raise NoRuleApplies
      else
        List.nth terms (index - 1)

  | TmProj (index, term) ->
      let term' = eval1 ctx term in
      TmProj (index, term')

  | TmVar x ->
    getvbinding ctx x 
  | _ ->
      raise NoRuleApplies
and eval_tuple_elements ctx evaluated pending =
  match pending with
  | [] ->
      raise NoRuleApplies
  | term :: rest ->
      if isval term then
        eval_tuple_elements ctx (term :: evaluated) rest
      else
        (* Se reconstruye la tupla tras reducir un paso la primera componente reducible. *)
        let term' = eval1 ctx term in
        TmTuple (List.rev_append evaluated (term' :: rest))
;;

let apply_ctx ctx tm =  List.fold_left (fun t x -> subst  x (getvbinding ctx x) t) tm (free_vars tm);;

let rec eval  ctx tm =
  try
    let tm' = eval1 ctx tm in
    eval ctx tm'
  with
    NoRuleApplies -> apply_ctx ctx tm
;;




let execute ctx = function
    Eval tm ->
      let tyTm = typeof ctx tm in
      let tm' = eval ctx tm in
      print_endline ("- : " ^ string_of_ty tyTm ^ " = " ^ string_of_term tm');
      ctx
  | Bind (x, tm) -> 
      let tyTm = typeof ctx tm in
      let tm' = eval ctx tm in
      print_endline (x ^ " : " ^ string_of_ty tyTm ^ " = " ^ string_of_term tm');
      addvbinding ctx x tyTm tm'
  | BindTy (x, ty) ->
      let ty' = resolve_ty ctx ty in
      print_endline (x ^ " = " ^ string_of_ty ty');
      addtbinding ctx x ty'
  | Quit ->
      raise End_of_file;;
