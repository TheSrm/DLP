
open Parsing;;
open Lexing;;

open Lambda;;
open Parser;;
open Lexer;;

let top_level_loop () =
  print_endline "Evaluator of lambda expressions...";

  let read_until_double_semi () =
    let rec aux acc =
      let line = read_line () in
      try
        let i = String.index line ';' in
        if i + 1 < String.length line && line.[i + 1] = ';' then
          acc ^ String.sub line 0 i
        else
          aux (acc ^ line ^ " ")
      with Not_found ->
        aux (acc ^ line ^ " ")
    in
    aux ""
  in

  let rec loop ctx =
    print_string ">> ";
    flush stdout;
    try
      let input = read_until_double_semi () in
      let tm = s token (from_string input) in
      let tyTm = typeof ctx tm in
      print_endline (string_of_term (eval tm) ^ " : " ^ string_of_ty tyTm);
      loop ctx
    with
       Lexical_error ->
         print_endline "lexical error";
         loop ctx
     | Parse_error ->
         print_endline "syntax error";
         loop ctx
     | Type_error e ->
         print_endline ("type error: " ^ e);
         loop ctx
     | End_of_file ->
         print_endline "...bye!!!"
  in
    loop emptyctx
  ;;

top_level_loop ()
;;

