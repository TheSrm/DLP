open Parsing;;
open Lexing;;

open Lambda;;
open Parser;;
open Lexer;;

let read_command () =
  let buffer = Buffer.create 64 in
  let semis_index s =
    let rec aux i =
      if i + 1 >= String.length s then None
      else if s.[i] = ';' && s.[i + 1] = ';' then Some i
      else aux (i + 1)
    in
    aux 0
  in
  let rec loop () =
    let line = read_line () in
    match semis_index line with
    | Some i ->
        Buffer.add_substring buffer line 0 i;
        Buffer.contents buffer
    | None ->
        Buffer.add_string buffer line;
        Buffer.add_char buffer '\n';
        loop ()
  in
  loop ()
;;

let top_level_loop () =
  print_endline "Evaluator of lambda expressions...";
  let rec loop ctx =
    print_string ">> ";
    flush stdout;
    try
      let c = input token (from_string (read_command ())) in
      loop (execute ctx c)
    with
    | End_of_file ->
        print_endline "...bye!!!"
    | Lexical_error ->
        print_endline "lexical error";
        loop ctx
    | Parse_error ->
        print_endline "syntax error";
        loop ctx
    | Type_error e ->
        print_endline ("type error: " ^ e);
        loop ctx
  in
  loop emptyctx
;;

top_level_loop ()
;;
