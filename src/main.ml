(* Lambda-calculus lexical analyzer and parser. *)

exception Syntax_error of string
exception Reduction_limit of int

type expr = Var of string | Abs of string * expr | App of expr * expr

type token =
  | Tok_lambda
  | Tok_lparen
  | Tok_rparen
  | Tok_identifier of string
  | Tok_eof

let usage_msg =
  "Usage: dune exec main -- <input-file>\n\
  \   or: dune exec main -- <num> <op> <num>  (where op is +, *, or -)"

let max_reduction_steps = 1000
let is_letter c = ('a' <= c && c <= 'z') || ('A' <= c && c <= 'Z')
let is_digit c = '0' <= c && c <= '9'
let is_alphanum c = is_letter c || is_digit c

let unexpected_character c =
  raise (Syntax_error ("Unexpected character: " ^ String.make 1 c))

(* Read the entire contents of a file into a string. *)
let read_file filename =
  let channel = open_in filename in
  try
    let len = in_channel_length channel in
    let result = really_input_string channel len in
    close_in_noerr channel;
    result
  with e ->
    close_in_noerr channel;
    raise e

let tokenize source : token list =
  let len = String.length source in
  let rec lex idx acc =
    if idx >= len then List.rev (Tok_eof :: acc)
    else
      match source.[idx] with
      | ' ' | '\t' | '\r' -> lex (idx + 1) acc
      | '\n' -> lex (idx + 1) acc
      | '\\' -> lex (idx + 1) (Tok_lambda :: acc)
      | '(' -> lex (idx + 1) (Tok_lparen :: acc)
      | ')' -> lex (idx + 1) (Tok_rparen :: acc)
      | c when is_letter c ->
          let stop =
            let rec advance j =
              if j < len && is_alphanum source.[j] then advance (j + 1) else j
            in
            advance (idx + 1)
          in
          let name = String.sub source idx (stop - idx) in
          lex stop (Tok_identifier name :: acc)
      | c -> unexpected_character c
  in
  lex 0 []

let expect_identifier tokens =
  match tokens with
  | Tok_identifier name :: rest -> (name, rest)
  | [] -> raise (Syntax_error "Missing variable after lambda")
  | Tok_eof :: _ -> raise (Syntax_error "Missing variable after lambda")
  | Tok_lparen :: _ -> raise (Syntax_error "Missing variable after lambda")
  | Tok_rparen :: _ -> raise (Syntax_error "Missing variable after lambda")
  | Tok_lambda :: _ -> raise (Syntax_error "Missing variable after lambda")

let rec parse_expression tokens =
  match tokens with
  | Tok_lambda :: _ -> parse_abstraction tokens
  | _ -> parse_application tokens

and parse_abstraction tokens =
  match tokens with
  | Tok_lambda :: rest ->
      let var, rest_tokens = expect_identifier rest in
      let rest_tokens =
        match rest_tokens with
        | Tok_eof :: _ ->
            raise (Syntax_error "Missing expression after lambda abstraction")
        | _ -> rest_tokens
      in
      let body, remaining = parse_expression rest_tokens in
      (Abs (var, body), remaining)
  | _ -> assert false

and parse_application tokens =
  let lhs, rest = parse_atom tokens in
  parse_application_tail lhs rest

and parse_application_tail lhs tokens =
  match tokens with
  | Tok_identifier _ :: _ | Tok_lparen :: _ | Tok_lambda :: _ ->
      let rhs, rest = parse_atom tokens in
      parse_application_tail (App (lhs, rhs)) rest
  | _ -> (lhs, tokens)

and parse_atom tokens =
  match tokens with
  | Tok_identifier name :: rest -> (Var name, rest)
  | Tok_lparen :: rest -> (
      let expr, rest_after_expr = parse_expression rest in
      match rest_after_expr with
      | Tok_rparen :: rest_final -> (expr, rest_final)
      | Tok_eof :: _ -> raise (Syntax_error "Missing closing parenthesis")
      | _ -> raise (Syntax_error "Missing closing parenthesis"))
  | Tok_lambda :: _ -> parse_abstraction tokens
  | Tok_rparen :: _ ->
      raise (Syntax_error "Missing expression after opening parenthesis")
  | Tok_eof :: _ -> raise (Syntax_error "Unexpected end of input")
  | [] -> raise (Syntax_error "Unexpected end of input")

let parse tokens : expr =
  let expr, rest = parse_expression tokens in
  match rest with
  | [ Tok_eof ] -> expr
  | Tok_eof :: _ -> raise (Syntax_error "Input string not fully parsed")
  | _ -> raise (Syntax_error "Input string not fully parsed")

let rec render expr =
  match expr with
  | Var name -> name
  | App (lhs, rhs) ->
      let left = render lhs in
      let right = render rhs in
      "(" ^ left ^ " " ^ right ^ ")"
  | Abs (name, body) ->
      let body_str = render body in
      "(\\" ^ name ^ " " ^ body_str ^ ")"

(* Beta-reduction and alpha-conversion *)

(* List membership check *)
let rec mem x lst =
  match lst with [] -> false | h :: t -> if h = x then true else mem x t

(* List filter *)
let rec filter pred lst =
  match lst with
  | [] -> []
  | h :: t -> if pred h then h :: filter pred t else filter pred t

(* Convert integer to string *)
let int_to_string n =
  if n = 0 then "0"
  else
    let rec digits acc n =
      if n = 0 then acc
      else
        let digit = n mod 10 in
        let char = char_of_int (digit + int_of_char '0') in
        digits (String.make 1 char ^ acc) (n / 10)
    in
    digits "" n

(* Collect all free variables in an expression. *)
let rec free_vars expr =
  match expr with
  | Var x -> [ x ]
  | App (e1, e2) -> free_vars e1 @ free_vars e2
  | Abs (x, body) -> filter (fun v -> v <> x) (free_vars body)

(* Generate a fresh variable name not in the given list. *)
let fresh_var base_name avoid_list =
  let rec try_name n =
    let candidate = if n = 0 then base_name else base_name ^ int_to_string n in
    if mem candidate avoid_list then try_name (n + 1) else candidate
  in
  try_name 0

(* Alpha-convert: rename bound variable old_name to new_name in expression. *)
let rec alpha_convert old_name new_name expr =
  match expr with
  | Var x -> if x = old_name then Var new_name else Var x
  | App (e1, e2) ->
      App
        (alpha_convert old_name new_name e1, alpha_convert old_name new_name e2)
  | Abs (x, body) ->
      if x = old_name then Abs (new_name, alpha_convert old_name new_name body)
      else Abs (x, alpha_convert old_name new_name body)

(* Substitute: replace variable x with expression n in expression m. *)
let rec substitute m x n =
  match m with
  | Var y -> if y = x then n else Var y
  | App (e1, e2) -> App (substitute e1 x n, substitute e2 x n)
  | Abs (y, body) ->
      if y = x then Abs (y, body)
      else
        let free_in_n = free_vars n in
        if mem y free_in_n then
          let all_vars = free_vars m @ free_vars n in
          let fresh = fresh_var y all_vars in
          let renamed_body = alpha_convert y fresh body in
          Abs (fresh, substitute renamed_body x n)
        else Abs (y, substitute body x n)

(* Attempt one beta-reduction step using Normal Order (leftmost-outermost). *)
let rec beta_reduce_step expr =
  match expr with
  | Var _ -> None
  | App (Abs (x, body), arg) ->
      (* Beta-redex found: (λx.body) arg → body[x:=arg] *)
      Some (substitute body x arg)
  | App (lhs, rhs) -> (
      (* Try to reduce function first (Normal Order) *)
      match beta_reduce_step lhs with
      | Some lhs' -> Some (App (lhs', rhs))
      | None -> (
          (* If function is irreducible, try argument *)
          match beta_reduce_step rhs with
          | Some rhs' -> Some (App (lhs, rhs'))
          | None -> None))
  | Abs (x, body) -> (
      (* Reduce under lambda *)
      match beta_reduce_step body with
      | Some body' -> Some (Abs (x, body'))
      | None -> None)

(* Reduce expression to normal form with step limit. *)
let rec reduce expr step_count =
  if step_count >= max_reduction_steps then raise (Reduction_limit step_count)
  else
    match beta_reduce_step expr with
    | None -> expr
    | Some expr' -> reduce expr' (step_count + 1)

let process_expression line =
  let tokens = tokenize line in
  let ast = parse tokens in
  let reduced = reduce ast 0 in
  render reduced

(* Split string into lines *)
let split_lines source =
  let len = String.length source in
  let rec split_at start idx acc =
    if idx >= len then
      if start = idx then List.rev acc
      else List.rev (String.sub source start (idx - start) :: acc)
    else if source.[idx] = '\n' then
      let line = String.sub source start (idx - start) in
      split_at (idx + 1) (idx + 1) (line :: acc)
    else split_at start (idx + 1) acc
  in
  if len = 0 then [] else split_at 0 0 []

(* List map *)
let rec map f lst = match lst with [] -> [] | h :: t -> f h :: map f t

let is_blank_line line =
  let rec loop idx =
    if idx >= String.length line then true
    else
      match line.[idx] with ' ' | '\t' | '\r' -> loop (idx + 1) | _ -> false
  in
  loop 0

let process_file filename =
  let source = read_file filename in
  let expressions = split_lines source in
  let non_blank = filter (fun line -> not (is_blank_line line)) expressions in
  map process_expression non_blank

(* Church numerals and arithmetic *)

(* Encode an integer as a Church numeral: n = λf.λx.f^n(x) *)
let church_encode n =
  if n < 0 then
    raise (Invalid_argument "Cannot encode negative number as Church numeral")
  else
    let rec apply_n_times f x count =
      if count = 0 then x else App (f, apply_n_times f x (count - 1))
    in
    let f_var = Var "f" in
    let x_var = Var "x" in
    Abs ("f", Abs ("x", apply_n_times f_var x_var n))

(* Church addition: λm.λn.λf.λx.m f (n f x) *)
let church_add =
  let m = Var "m" in
  let n = Var "n" in
  let f = Var "f" in
  let x = Var "x" in
  Abs
    ("m", Abs ("n", Abs ("f", Abs ("x", App (App (m, f), App (App (n, f), x))))))

(* Church multiplication: λm.λn.λf.m (n f) *)
let church_mult =
  let m = Var "m" in
  let n = Var "n" in
  let f = Var "f" in
  Abs ("m", Abs ("n", Abs ("f", App (m, App (n, f)))))

(* Church predecessor (used for subtraction): λn.λf.λx.n (λg.λh.h (g f)) (λu.x) (λu.u) *)
let church_pred =
  let n = Var "n" in
  let f = Var "f" in
  let x = Var "x" in
  let g = Var "g" in
  let h = Var "h" in
  let u = Var "u" in
  Abs
    ( "n",
      Abs
        ( "f",
          Abs
            ( "x",
              App
                ( App
                    ( App (n, Abs ("g", Abs ("h", App (h, App (g, f))))),
                      Abs ("u", x) ),
                  Abs ("u", u) ) ) ) )

(* Church subtraction (monus): λm.λn.n pred m *)
let church_sub =
  let m = Var "m" in
  let n = Var "n" in
  Abs ("m", Abs ("n", App (App (n, church_pred), m)))

(* Parse arithmetic expression from command line arguments *)
let parse_arithmetic () =
  if Array.length Sys.argv <> 4 then
    raise
      (Invalid_argument
         "Arithmetic mode requires exactly 3 arguments: <num> <op> <num>")
  else
    let num1_str = Sys.argv.(1) in
    let op_str = Sys.argv.(2) in
    let num2_str = Sys.argv.(3) in
    let num1 = int_of_string num1_str in
    let num2 = int_of_string num2_str in
    let church1 = church_encode num1 in
    let church2 = church_encode num2 in
    match op_str with
    | "+" -> App (App (church_add, church1), church2)
    | "*" -> App (App (church_mult, church1), church2)
    | "-" -> App (App (church_sub, church1), church2)
    | _ ->
        raise
          (Invalid_argument
             ("Unknown operator: " ^ op_str ^ " (supported: +, *, -)"))

(* List iteration *)
let rec iter f lst =
  match lst with
  | [] -> ()
  | h :: t ->
      f h;
      iter f t

let () =
  match Array.length Sys.argv with
  | 2 ->
      (* File mode: interpret expressions from file *)
      let input_file = Sys.argv.(1) in
      let outputs = process_file input_file in
      iter print_endline outputs
  | 4 ->
      (* Arithmetic mode: <num> <op> <num> *)
      let expr = parse_arithmetic () in
      let result = reduce expr 0 in
      print_endline (render result)
  | _ ->
      prerr_endline usage_msg;
      raise (Invalid_argument "Invalid number of arguments")
