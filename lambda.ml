(* TYPE DEFINITIONS *)
open Format;;

type ty =
    TyBool
  | TyNat
  | TyString
  | TyList of ty
  | TyTuple of ty list
  | TyRecord of (string * ty) list
  | TyVariant of (string * ty) list
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
  | TmVariant of string * term * ty
  | TmCase of term * (string * string * term) list
;;


type command =
    Eval of term
  | Bind of string * term
  | BindTy of string * ty
  | Quit 
;;

type binding =
    TyBind of ty
  | TyTmBind of (ty * term);;

type context =
  (string * binding) list
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
  | TyList ty ->
      "List " ^ string_of_ty ty
  | TyTuple tys ->
      "{" ^ String.concat ", " (List.map string_of_ty tys) ^ "}"
  | TyRecord fields ->
      "{" ^ String.concat ", "
        (List.map (fun (label, field_ty) -> label ^ " : " ^ string_of_ty field_ty) fields) ^ "}"
  | TyVariant cases ->
      "<" ^ String.concat ", "
        (List.map (fun (label, case_ty) -> label ^ " : " ^ string_of_ty case_ty) cases) ^ ">"
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
    | TyList ty ->
        TyList (aux visited ty)
    | TyTuple tys ->
        TyTuple (List.map (aux visited) tys)
    | TyRecord fields ->
        TyRecord (List.map (fun (label, field_ty) -> (label, aux visited field_ty)) fields)
    | TyVariant cases ->
        TyVariant (List.map (fun (label, case_ty) -> (label, aux visited case_ty)) cases)
    | TyArr (ty1, ty2) ->
        TyArr (aux visited ty1, aux visited ty2)
    | TyAlias name ->
        if List.mem name visited then
          raise (Type_error ("cyclic type alias " ^ name))
        else
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

  | TmNil ty ->
      TyList (resolve_ty ctx ty)

  | TmCons (ty, t1, t2) ->
      let elem_ty = resolve_ty ctx ty in
      let ty1 = resolve_ty ctx (typeof ctx t1) in
      let ty2 = resolve_ty ctx (typeof ctx t2) in
      if ty1 = elem_ty && ty2 = TyList elem_ty then TyList elem_ty
      else raise (Type_error "cons requires a head of type T and a tail of type List T")

  | TmIsNil (ty, t) ->
      let elem_ty = resolve_ty ctx ty in
      if resolve_ty ctx (typeof ctx t) = TyList elem_ty then TyBool
      else raise (Type_error "isnil requires an argument of type List T")

  | TmHead (ty, t) ->
      let elem_ty = resolve_ty ctx ty in
      if resolve_ty ctx (typeof ctx t) = TyList elem_ty then elem_ty
      else raise (Type_error "head requires an argument of type List T")

  | TmTail (ty, t) ->
      let elem_ty = resolve_ty ctx ty in
      if resolve_ty ctx (typeof ctx t) = TyList elem_ty then TyList elem_ty
      else raise (Type_error "tail requires an argument of type List T")

  | TmTuple terms ->
      TyTuple (List.map (fun term -> resolve_ty ctx (typeof ctx term)) terms)

  | TmProj (index, term) ->
      (match resolve_ty ctx (typeof ctx term) with
           TyTuple tys ->
             if index < 1 || index > List.length tys then
               raise (Type_error "tuple projection index out of bounds")
             else
               List.nth tys (index - 1)
         | _ -> raise (Type_error "tuple type expected in projection"))

  | TmRecord fields ->
      TyRecord (List.map (fun (label, term) -> (label, resolve_ty ctx (typeof ctx term))) fields)

  | TmRecordProj (label, term) ->
      (match resolve_ty ctx (typeof ctx term) with
           TyRecord fields ->
             (match List.assoc_opt label fields with
                  Some ty -> ty
                | None -> raise (Type_error ("unknown record label " ^ label)))
         | _ -> raise (Type_error "record type expected in projection"))

  | TmVariant (label, t, ty) ->
      let ty' = resolve_ty ctx ty in
      (match ty' with
           TyVariant cases ->
             (match List.assoc_opt label cases with
                  Some label_ty ->
                    let t_ty = resolve_ty ctx (typeof ctx t) in
                    if t_ty = label_ty then ty'
                    else raise (Type_error
                      ("variant field " ^ label ^ " has wrong type"))
                | None ->
                    raise (Type_error
                      ("label " ^ label ^ " not found in variant type")))
         | _ ->
             raise (Type_error "variant type expected in variant construction"))

  | TmCase (t, branches) ->
      let variant_ty = resolve_ty ctx (typeof ctx t) in
      (match variant_ty with
           TyVariant cases ->
             (* Check that the set of branch labels matches the variant labels exactly *)
             let branch_labels = List.map (fun (l, _, _) -> l) branches in
             let case_labels   = List.map fst cases in
             if List.sort compare branch_labels <> List.sort compare case_labels then
               raise (Type_error "case branches do not match variant labels");
             (* Type each branch *)
             let branch_types = List.map (fun (label, x, body) ->
               let label_ty =
                 match List.assoc_opt label cases with
                   Some ty -> ty
                 | None ->
                     raise (Type_error ("unexpected label " ^ label ^ " in case"))
               in
               let ctx' = addtbinding ctx x label_ty in
               resolve_ty ctx' (typeof ctx' body)
             ) branches in
             (* All branches must have the same type *)
             (match branch_types with
                  [] -> raise (Type_error "empty case expression")
                | first :: rest ->
                    if List.for_all (fun ty -> ty = first) rest then first
                    else raise (Type_error "case branches have different types"))
         | _ ->
             raise (Type_error "variant type expected in case expression"))
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
  | TmNil ty ->
      "nil[" ^ string_of_ty ty ^ "]"
  | TmCons (ty, t1, t2) ->
      "cons[" ^ string_of_ty ty ^ "] " ^ "(" ^ string_of_term t1 ^ ") " ^ "(" ^ string_of_term t2 ^ ")"
  | TmIsNil (ty, t) ->
      "isnil[" ^ string_of_ty ty ^ "] " ^ "(" ^ string_of_term t ^ ")"
  | TmHead (ty, t) ->
      "head[" ^ string_of_ty ty ^ "] " ^ "(" ^ string_of_term t ^ ")"
  | TmTail (ty, t) ->
      "tail[" ^ string_of_ty ty ^ "] " ^ "(" ^ string_of_term t ^ ")"
  | TmTuple terms ->
      "{" ^ String.concat ", " (List.map string_of_term terms) ^ "}"
  | TmProj (index, term) ->
      "(" ^ string_of_term term ^ ")." ^ string_of_int index
  | TmRecord fields ->
      "{" ^ String.concat ", "
        (List.map (fun (label, term) -> label ^ " = " ^ string_of_term term) fields) ^ "}"
  | TmRecordProj (label, term) ->
      "(" ^ string_of_term term ^ ")." ^ label
  | TmVariant (label, t, _ty) ->
      "<" ^ label ^ " = " ^ string_of_term t ^ ">"
  | TmCase (t, branches) ->
      "case " ^ string_of_term t ^ " of " ^
      String.concat " | "
        (List.map (fun (label, x, body) ->
          "<" ^ label ^ "=" ^ x ^ "> => " ^ string_of_term body) branches)
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
    TmTrue -> []
  | TmFalse -> []
  | TmIf (t1, t2, t3) ->
      lunion (lunion (free_vars t1) (free_vars t2)) (free_vars t3)
  | TmZero -> []
  | TmSucc t -> free_vars t
  | TmPred t -> free_vars t
  | TmIsZero t -> free_vars t
  | TmVar s -> [s]
  | TmAbs (s, _, t) -> ldif (free_vars t) [s]
  | TmApp (t1, t2) -> lunion (free_vars t1) (free_vars t2)
  | TmLetIn (s, t1, t2) ->
      lunion (ldif (free_vars t2) [s]) (free_vars t1)
  | TmFix t -> free_vars t
  | TmString _ -> []
  | TmConcat (t1, t2) -> lunion (free_vars t1) (free_vars t2)
  | TmLength t -> free_vars t
  | TmNil _ -> []
  | TmCons (_, t1, t2) -> lunion (free_vars t1) (free_vars t2)
  | TmIsNil (_, t) -> free_vars t
  | TmHead (_, t) -> free_vars t
  | TmTail (_, t) -> free_vars t
  | TmTuple terms ->
      List.fold_left (fun vars term -> lunion vars (free_vars term)) [] terms
  | TmProj (_, term) -> free_vars term
  | TmRecord fields ->
      List.fold_left (fun vars (_, term) -> lunion vars (free_vars term)) [] fields
  | TmRecordProj (_, term) -> free_vars term
  | TmVariant (_, t, _) -> free_vars t
  | TmCase (t, branches) ->
      List.fold_left (fun vars (_, x, body) ->
        lunion vars (ldif (free_vars body) [x])
      ) (free_vars t) branches
;;

let rec fresh_name x l =
  if not (List.mem x l) then x else fresh_name (x ^ "'") l
;;

let rec subst x s tm = match tm with
    TmTrue -> TmTrue
  | TmFalse -> TmFalse
  | TmIf (t1, t2, t3) ->
      TmIf (subst x s t1, subst x s t2, subst x s t3)
  | TmZero -> TmZero
  | TmSucc t -> TmSucc (subst x s t)
  | TmPred t -> TmPred (subst x s t)
  | TmIsZero t -> TmIsZero (subst x s t)
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
  | TmFix t -> TmFix (subst x s t)
  | TmString str -> TmString str
  | TmConcat (t1, t2) -> TmConcat (subst x s t1, subst x s t2)
  | TmLength t -> TmLength (subst x s t)
  | TmNil ty -> TmNil ty
  | TmCons (ty, t1, t2) -> TmCons (ty, subst x s t1, subst x s t2)
  | TmIsNil (ty, t) -> TmIsNil (ty, subst x s t)
  | TmHead (ty, t) -> TmHead (ty, subst x s t)
  | TmTail (ty, t) -> TmTail (ty, subst x s t)
  | TmTuple terms -> TmTuple (List.map (subst x s) terms)
  | TmProj (index, term) -> TmProj (index, subst x s term)
  | TmRecord fields ->
      TmRecord (List.map (fun (label, term) -> (label, subst x s term)) fields)
  | TmRecordProj (label, term) ->
      TmRecordProj (label, subst x s term)
  | TmVariant (label, t, ty) ->
      TmVariant (label, subst x s t, ty)
  | TmCase (t, branches) ->
      TmCase (subst x s t,
        List.map (fun (label, y, body) ->
          if y = x then (label, y, body)
          else let fvs = free_vars s in
               if not (List.mem y fvs)
               then (label, y, subst x s body)
               else let z = fresh_name y (free_vars body @ fvs) in
                    (label, z, subst x s (subst y (TmVar z) body))
        ) branches)
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
  | TmNil _ -> true
  | TmCons (_, t1, t2) -> isval t1 && isval t2
  | TmTuple terms -> List.for_all isval terms
  | TmRecord fields -> List.for_all (fun (_, term) -> isval term) fields
  | TmVariant (_, t, _) -> isval t
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
    TmIf (TmTrue, t2, _) -> t2
    (* E-IfFalse *)
  | TmIf (TmFalse, _, t3) -> t3
    (* E-If *)
  | TmIf (t1, t2, t3) ->
      let t1' = eval1 ctx t1 in
      TmIf (t1', t2, t3)
    (* E-Succ *)
  | TmSucc t1 ->
      let t1' = eval1 ctx t1 in
      TmSucc t1'
    (* E-PredZero *)
  | TmPred TmZero -> TmZero
    (* E-PredSucc *)
  | TmPred (TmSucc nv1) when isnumericval nv1 -> nv1
    (* E-Pred *)
  | TmPred t1 ->
      let t1' = eval1 ctx t1 in
      TmPred t1'
    (* E-IszeroZero *)
  | TmIsZero TmZero -> TmTrue
    (* E-IszeroSucc *)
  | TmIsZero (TmSucc nv1) when isnumericval nv1 -> TmFalse
    (* E-Iszero *)
  | TmIsZero t1 ->
      let t1' = eval1 ctx t1 in
      TmIsZero t1'
    (* E-AppAbs *)
  | TmApp (TmAbs(x, _, t12), v2) when isval v2 ->
      subst x v2 t12
    (* E-App2 *)
  | TmApp (v1, t2) when isval v1 ->
      let t2' = eval1 ctx t2 in
      TmApp (v1, t2')
    (* E-App1 *)
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
    (* E-FixBeta *)
  | TmFix (TmAbs(x, _, t)) ->
      subst x tm t
    (* E-Fix *)
  | TmFix t1 ->
      let t1' = eval1 ctx t1 in
      TmFix t1'
    (* E-Concat *)
  | TmConcat (TmString s1, TmString s2) ->
      TmString (s1 ^ s2)
  | TmConcat (TmString s1, t2) ->
      let t2' = eval1 ctx t2 in
      TmConcat (TmString s1, t2')
  | TmConcat (t1, t2) ->
      let t1' = eval1 ctx t1 in
      TmConcat (t1', t2)
    (* E-Length *)
  | TmLength (TmString s) ->
      nat_of_int (String.length s)
  | TmLength t ->
      let t' = eval1 ctx t in
      TmLength t'
  | TmCons (ty, t1, t2) when not (isval t1) ->
      TmCons (ty, eval1 ctx t1, t2)
  | TmCons (ty, t1, t2) when isval t1 && not (isval t2) ->
      TmCons (ty, t1, eval1 ctx t2)
  | TmIsNil (_, TmNil _) ->
      TmTrue
  | TmIsNil (_, TmCons (_, v1, v2)) when isval v1 && isval v2 ->
      TmFalse
  | TmIsNil (ty, t) ->
      let t' = eval1 ctx t in
      TmIsNil (ty, t')
  | TmHead (_, TmCons (_, v1, v2)) when isval v1 && isval v2 ->
      v1
  | TmHead (_, TmNil _) ->
      raise (Type_error "head applied to an empty list")
  | TmHead (ty, t) ->
      let t' = eval1 ctx t in
      TmHead (ty, t')
  | TmTail (_, TmCons (_, v1, v2)) when isval v1 && isval v2 ->
      v2
  | TmTail (_, TmNil _) ->
      raise (Type_error "tail applied to an empty list")
  | TmTail (ty, t) ->
      let t' = eval1 ctx t in
      TmTail (ty, t')
  | TmTuple terms ->
      eval_tuple_elements ctx [] terms
  | TmProj (index, TmTuple terms) when List.for_all isval terms ->
      if index < 1 || index > List.length terms then
        raise NoRuleApplies
      else
        List.nth terms (index - 1)
  | TmProj (index, term) ->
      let term' = eval1 ctx term in
      TmProj (index, term')
  | TmRecord fields ->
      eval_record_fields ctx [] fields
  | TmRecordProj (label, TmRecord fields) when List.for_all (fun (_, term) -> isval term) fields ->
      (match List.assoc_opt label fields with
           Some term -> term
         | None -> raise NoRuleApplies)
  | TmRecordProj (label, term) ->
      let term' = eval1 ctx term in
      TmRecordProj (label, term')
  | TmVariant (label, t, ty) when not (isval t) ->
      TmVariant (label, eval1 ctx t, ty)
  | TmCase (TmVariant (label, v, _), branches) when isval v ->
      (match List.find_opt (fun (l, _, _) -> l = label) branches with
           Some (_, x, body) -> subst x v body
         | None -> raise NoRuleApplies)
  | TmCase (t, branches) ->
      let t' = eval1 ctx t in
      TmCase (t', branches)
  | TmVar x ->
      getvbinding ctx x
  | _ ->
      raise NoRuleApplies
and eval_tuple_elements ctx evaluated pending =
  match pending with
  | [] -> raise NoRuleApplies
  | term :: rest ->
      if isval term then
        eval_tuple_elements ctx (term :: evaluated) rest
      else
        let term' = eval1 ctx term in
        TmTuple (List.rev_append evaluated (term' :: rest))
and eval_record_fields ctx evaluated pending =
  match pending with
  | [] -> raise NoRuleApplies
  | (label, term) :: rest ->
      if isval term then
        eval_record_fields ctx ((label, term) :: evaluated) rest
      else
        let term' = eval1 ctx term in
        TmRecord (List.rev_append evaluated ((label, term') :: rest))
;;

let apply_ctx ctx tm =
  List.fold_left (fun t x -> subst x (getvbinding ctx x) t) tm (free_vars tm)
;;

let rec eval ctx tm =
  try
    let tm' = eval1 ctx tm in
    eval ctx tm'
  with
    NoRuleApplies -> apply_ctx ctx tm
;;


(* PRETTY PRINTER *)

let rec int_of_numeric_term acc = function
    TmZero -> Some acc
  | TmSucc t -> int_of_numeric_term (acc + 1) t
  | _ -> None
;;

(* print_ty prints a type with minimal parentheses.
   Arrows are right-associative, so we only parenthesise the left side
   when it is itself an arrow. *)
let rec print_ty ty = match ty with
    TyArr (ty1, ty2) ->
      (match ty1 with
         TyArr _ ->
           print_string "(";
           print_ty ty1;
           print_string ")"
       | _ ->
           print_ty ty1);
      print_string " -> ";
      print_ty ty2
  | TyTuple tys ->
      open_box 1;
      print_string "{";
      let rec aux = function
          [] -> ()
        | [t] -> print_ty t
        | t :: rest ->
            print_ty t;
            print_string ",";
            print_space ();
            aux rest
      in aux tys;
      print_string "}";
      close_box ()
  | TyRecord fields ->
      open_box 1;
      print_string "{";
      let rec aux = function
          [] -> ()
        | [(label, field_ty)] ->
            print_string label;
            print_string " : ";
            print_ty field_ty
        | (label, field_ty) :: rest ->
            print_string label;
            print_string " : ";
            print_ty field_ty;
            print_string ",";
            print_space ();
            aux rest
      in aux fields;
      print_string "}";
      close_box ()
  | TyVariant cases ->
      open_box 1;
      print_string "<";
      let rec aux = function
          [] -> ()
        | [(label, case_ty)] ->
            print_string label;
            print_string " : ";
            print_ty case_ty
        | (label, case_ty) :: rest ->
            print_string label;
            print_string " : ";
            print_ty case_ty;
            print_string ",";
            print_space ();
            aux rest
      in aux cases;
      print_string ">";
      close_box ()
  | TyBool    -> print_string "Bool"
  | TyNat     -> print_string "Nat"
  | TyString  -> print_string "String"
  | TyList ty ->
      print_string "List ";
      (match ty with
         TyArr _ ->
           print_string "(";
           print_ty ty;
           print_string ")"
       | _ ->
           print_ty ty)
  | TyAlias x -> print_string x
;;

(* print_term handles the top level: if/then/else, lambda, let, letrec, case.
   Anything it does not recognise is delegated to print_appTerm. *)
let rec print_term tm = match tm with
    TmIf (t1, t2, t3) ->
      open_hovbox 0;
      print_string "if ";
      print_term t1;
      print_string " then ";
      print_term t2;
      print_string " else ";
      print_term t3;
      close_box ()
  | TmAbs (x, ty, t) ->
      open_box 0;
      print_string ("lambda " ^ x ^ ":");
      print_ty ty;
      print_string ".";
      print_term t;
      close_box ()
  | TmLetIn (x, TmFix (TmAbs (x', ty, t1)), t2) when x = x' ->
      (* letrec is printed as letrec, not as let/fix *)
      open_hovbox 0;
      print_string ("letrec " ^ x ^ " : ");
      print_ty ty;
      print_string " = ";
      print_term t1;
      print_string " in ";
      print_term t2;
      close_box ()
  | TmLetIn (x, t1, t2) ->
      open_hovbox 0;
      print_string ("let " ^ x ^ " = ");
      print_term t1;
      print_string " in ";
      print_term t2;
      close_box ()
  | TmCase (t, branches) ->
      open_hovbox 0;
      print_string "case ";
      print_term t;
      print_string " of";
      print_space ();
      let rec aux = function
          [] -> ()
        | [(label, x, body)] ->
            print_string ("<" ^ label ^ "=" ^ x ^ "> => ");
            print_term body
        | (label, x, body) :: rest ->
            print_string ("<" ^ label ^ "=" ^ x ^ "> => ");
            print_term body;
            print_string " | ";
            aux rest
      in aux branches;
      close_box ()
  | _ ->
      print_appTerm tm

(* print_appTerm handles function application and prefix operators.
   Anything else is delegated to print_projTerm. *)
and print_appTerm tm = match tm with
    TmApp (t1, t2) ->
      open_box 2;
      print_appTerm t1;
      print_space ();
      print_projTerm t2;
      close_box ()
  | TmSucc t ->
      (match int_of_numeric_term 0 (TmSucc t) with
         Some n -> print_string (string_of_int n)
       | None ->
           open_box 2;
           print_string "succ"; print_space ();
           print_projTerm t;
           close_box ())
  | TmPred t ->
      open_box 2;
      print_string "pred"; print_space ();
      print_projTerm t;
      close_box ()
  | TmIsZero t ->
      open_box 2;
      print_string "iszero"; print_space ();
      print_projTerm t;
      close_box ()
  | TmFix t ->
      open_box 2;
      print_string "fix"; print_space ();
      print_projTerm t;
      close_box ()
  | TmConcat (t1, t2) ->
      open_box 2;
      print_string "concat"; print_space ();
      print_projTerm t1; print_space ();
      print_projTerm t2;
      close_box ()
  | TmLength t ->
      open_box 2;
      print_string "length"; print_space ();
      print_projTerm t;
      close_box ()
  | TmCons (ty, t1, t2) ->
      open_box 2;
      print_string "cons[";
      print_ty ty;
      print_string "]";
      print_space ();
      print_projTerm t1;
      print_space ();
      print_projTerm t2;
      close_box ()
  | TmIsNil (ty, t) ->
      open_box 2;
      print_string "isnil[";
      print_ty ty;
      print_string "]";
      print_space ();
      print_projTerm t;
      close_box ()
  | TmHead (ty, t) ->
      open_box 2;
      print_string "head[";
      print_ty ty;
      print_string "]";
      print_space ();
      print_projTerm t;
      close_box ()
  | TmTail (ty, t) ->
      open_box 2;
      print_string "tail[";
      print_ty ty;
      print_string "]";
      print_space ();
      print_projTerm t;
      close_box ()
  | _ ->
      print_projTerm tm

(* print_projTerm handles dot-projection, possibly chained. *)
and print_projTerm tm = match tm with
    TmProj (i, t) ->
      open_box 0;
      print_projTerm t;
      print_string ("." ^ string_of_int i);
      close_box ()
  | TmRecordProj (label, t) ->
      open_box 0;
      print_projTerm t;
      print_string ("." ^ label);
      close_box ()
  | _ ->
      print_atomicTerm tm

(* print_atomicTerm handles literals, variables, tuples, records, and variants.
   Any term that belongs to a higher level is wrapped in parentheses. *)
and print_atomicTerm tm = match tm with
    TmTrue     -> print_string "true"
  | TmFalse    -> print_string "false"
  | TmZero     -> print_string "0"
  | TmVar x    -> print_string x
  | TmString s -> print_string ("\"" ^ s ^ "\"")
  | TmNil ty ->
      print_string "nil[";
      print_ty ty;
      print_string "]"
  | TmSucc _ as t ->
      (match int_of_numeric_term 0 t with
         Some n -> print_string (string_of_int n)
       | None ->
           open_box 1;
           print_string "(";
           print_term t;
           print_string ")";
           close_box ())
  | TmTuple terms ->
      open_box 1;
      print_string "{";
      let rec aux = function
          [] -> ()
        | [t] -> print_term t
        | t :: rest ->
            print_term t;
            print_string ",";
            print_space ();
            aux rest
      in aux terms;
      print_string "}";
      close_box ()
  | TmRecord fields ->
      open_box 1;
      print_string "{";
      let rec aux = function
          [] -> ()
        | [(label, term)] ->
            print_string label;
            print_string " = ";
            print_term term
        | (label, term) :: rest ->
            print_string label;
            print_string " = ";
            print_term term;
            print_string ",";
            print_space ();
            aux rest
      in aux fields;
      print_string "}";
      close_box ()
  | TmVariant (label, t, _ty) ->
      open_box 1;
      print_string ("<" ^ label ^ " = ");
      print_term t;
      print_string ">";
      close_box ()
  | _ ->
      open_box 1;
      print_string "(";
      print_term tm;
      print_string ")";
      close_box ()
;;

(* pretty_printer is the single entry point used by execute.
   's' is the label printed before the colon (either "-" or the bound name). *)
let pretty_printer s ty tm =
  pp_set_margin std_formatter 1000;
  open_hovbox 0;
  print_string s;
  print_string " : ";
  print_ty ty;
  print_string " = ";
  print_term tm;
  close_box ();
  force_newline ();
  print_flush ()
;;

let execute ctx = function
    Eval tm ->
      let tyTm = typeof ctx tm in
      let tm' = eval ctx tm in
      pretty_printer "-" tyTm tm';
      ctx
  | Bind (x, tm) ->
      let tyTm = typeof ctx tm in
      let tm' = eval ctx tm in
      pretty_printer x tyTm tm';
      addvbinding ctx x tyTm tm'
  | BindTy (x, ty) ->
      let ty' = resolve_ty ctx ty in
      print_string (x ^ " = ");
      print_ty ty';
      force_newline ();
      print_flush ();
      addtbinding ctx x ty'
  | Quit ->
      raise End_of_file
;;