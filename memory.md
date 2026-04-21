# Lambda Calculus Interpreter Practice Report

## 1. Introduction

This project extends the `lambda-3` interpreter provided for the Programming Language Design laboratory sessions. The goal of the practice was to study the original OCaml implementation and then improve it with new usability features and new language constructs.

The current version of our interpreter implements the following extensions from the assignment:

- Multi-line input using `;;` as the end-of-command marker.
- Direct recursive definitions through `fix` and `letrec`.
- A global functional context for term bindings.
- Global type aliases.
- Support for the `String` type, string literals, concatenation, and a `length` operator.
- Support for tuples and positional projection.

This report is divided into two parts, as requested in the assignment:

- A short user manual describing the new language features and their syntax.
- A short technical manual describing the modified modules and the implementation strategy.

## 2. User Manual

### 2.1. Running the interpreter

The interpreter is compiled with:

```bash
make
```

and executed with:

```bash
./top
```

When the program starts, it opens an interactive loop:

```text
Evaluator of lambda expressions...
>>
```

Each command must end with `;;`. This is especially useful because the interpreter now accepts multi-line expressions.

### 2.2. Multi-line expressions

One of the requested usability improvements was the ability to write expressions across several lines. In our implementation, a command is considered complete only when the sequence `;;` is found. Therefore, line breaks are accepted inside an expression.

Example:

```text
>> letrec sum: Nat -> Nat -> Nat =
     lambda n: Nat. lambda m: Nat.
       if iszero n then m
       else succ (sum (pred n) m)
   in
     sum 2 3;;
- : Nat = 5
```

This makes large terms much easier to write and read than in the original single-line loop.

### 2.3. Recursive definitions

The interpreter supports explicit fixed points through `fix`, and also direct recursive definitions through `letrec`.

The syntax is:

```text
letrec f : T = term in body
```

Internally, this construct is translated into a `let` whose bound expression uses `fix`.

Example:

```text
>> letrec sum: Nat -> Nat -> Nat =
     lambda n: Nat. lambda m: Nat.
       if iszero n then m
       else succ (sum (pred n) m)
   in
     sum 2 3;;
- : Nat = 5
```

This extension allows direct recursive programming without manually writing the fixed-point combinator every time.

The assignment also requested additional recursive examples based on natural-number addition. The following terms are included as examples of multiple recursion patterns.

Product:

```text
letrec sum: Nat -> Nat -> Nat =
  lambda n: Nat. lambda m: Nat.
    if iszero n then m
    else succ (sum (pred n) m)
in
letrec prod: Nat -> Nat -> Nat =
  lambda n: Nat. lambda m: Nat.
    if iszero n then 0
    else sum m (prod (pred n) m)
in
  prod 12 5;;
```

Fibonacci:

```text
letrec sum: Nat -> Nat -> Nat =
  lambda n: Nat. lambda m: Nat.
    if iszero n then m
    else succ (sum (pred n) m)
in
letrec fib: Nat -> Nat =
  lambda n: Nat.
    if iszero n then 0
    else if iszero (pred n) then 1
    else sum (fib (pred n)) (fib (pred (pred n)))
in
  fib 10;;
```

Factorial:

```text
letrec sum: Nat -> Nat -> Nat =
  lambda n: Nat. lambda m: Nat.
    if iszero n then m
    else succ (sum (pred n) m)
in
letrec prod: Nat -> Nat -> Nat =
  lambda n: Nat. lambda m: Nat.
    if iszero n then 0
    else sum m (prod (pred n) m)
in
letrec fact: Nat -> Nat =
  lambda n: Nat.
    if iszero n then 1
    else prod n (fact (pred n))
in
  fact 5;;
```

### 2.4. Global context for terms and type aliases

The interpreter includes a global context that stores both term bindings and type bindings.

Term binding syntax:

```text
identifier = term;;
```

Example:

```text
>> x = true;;
x : Bool = true
>> id = lambda x:Bool. x;;
id : (Bool) -> (Bool) = (lambda x:Bool. x)
>> id x;;
- : Bool = true
```

Type alias syntax:

```text
Identifier = Type;;
```

Example:

```text
>> N = Nat;;
N = Nat
>> lambda x:N. x;;
- : (Nat) -> (Nat) = (lambda x:N. x)
```

The context is functional, not imperative. Technically, it is represented as a list of bindings where each new definition is added to the front. Lookups always return the most recent binding, while older bindings remain in the context. This design matches the style of a lambda calculus interpreter and avoids destructive updates.

### 2.5. Strings

The interpreter supports the base type `String`, string literals, concatenation with `concat`, and the operator `length`.

Examples:

```text
>> concat "hello" " world";;
- : String = "hello world"
>> length "hello";;
- : Nat = 5
```

Typing rules:

- A string literal has type `String`.
- `concat t1 t2` requires both arguments to have type `String`.
- `length t` requires `t` to have type `String` and returns `Nat`.

Operationally, concatenation is evaluated left to right, and `length` returns the corresponding natural number in the internal unary representation before printing it as a decimal numeral.

### 2.6. Tuples and projection

The interpreter supports tuples with any finite number of components, possibly of different types. Tuple types are written with braces and preserve the type of each component in order.

Examples:

```text
>> {true, 0};;
- : {Bool, Nat} = {true, 0}
>> proj 2 {true, 0, "hola"};;
- : Nat = 0
>> lambda x: {Bool, Nat}. proj 2 x;;
- : ({Bool, Nat}) -> (Nat) = (lambda x:{Bool, Nat}. proj 2 (x))
```

Projection is positional and starts at index `1`.

Typing rules:

- A tuple `{t1, ..., tn}` has type `{T1, ..., Tn}` if each component `ti` has type `Ti`.
- `proj i t` is well typed only if `t` has tuple type and `i` is within bounds.

Evaluation rules:

- Tuple components are evaluated from left to right.
- A projection over a fully evaluated tuple returns the selected component.

## 3. Technical Notes

### 3.1. Modified modules

The implementation mainly modifies the following files:

- `main.ml`
- `lambda.ml`
- `lambda.mli`
- `parser.mly`
- `lexer.mll`

### 3.2. `main.ml`

The main change in `main.ml` is the new input-reading function. Instead of reading a single line and parsing it immediately, the interpreter now accumulates input until it finds `;;`. This makes multi-line commands possible while preserving a simple interactive interface.

The top-level loop remains responsible for:

- Printing the prompt.
- Invoking the lexer and parser.
- Executing commands.
- Reporting lexical, syntactic, and typing errors.

### 3.3. `lambda.ml` and `lambda.mli`

These files contain most of the semantic changes.

New types and terms were added to the abstract syntax:

- `TyString`
- `TyTuple of ty list`
- `TyAlias of string`
- `TmFix`
- `TmString`
- `TmConcat`
- `TmLength`
- `TmTuple of term list`
- `TmProj of int * term`

The command language was also extended with:

- `Bind of string * term`
- `BindTy of string * ty`

The context now stores either type bindings or term bindings:

- `TyBind of ty`
- `TyTmBind of (ty * term)`

Several groups of functions were extended accordingly.

Typing:

- `resolve_ty` resolves type aliases recursively and detects cyclic aliases.
- `typeof` was extended with typing rules for recursion, strings, tuples, projections, and context lookups.

Evaluation:

- `subst` and `free_vars` were extended so that all new term forms are handled correctly.
- `isval` now recognizes strings and tuples of values.
- `eval1` includes reduction rules for `fix`, `concat`, `length`, tuples, projection, and global variables.
- `eval` applies small-step evaluation repeatedly and then replaces remaining free variables using the global context.

Printing:

- `string_of_ty` and `string_of_term` were extended to print the new constructs.

Command execution:

- `execute` now handles term definitions, type aliases, ordinary evaluation requests, and `Quit`.

### 3.4. `parser.mly`

The parser was extended to recognize:

- Global term bindings.
- Global type aliases.
- `letrec`.
- `fix`.
- String literals and the `String` type.
- `concat` and `length`.
- Tuple expressions.
- Tuple types.
- Positional projection with `proj`.

An important design decision is that `letrec` is not evaluated by a special runtime rule. Instead, it is translated directly by the parser into:

```text
let x = fix (lambda x:T. term) in body
```

This keeps the evaluator simpler because recursion is ultimately handled by the already defined `fix` construct.

### 3.5. `lexer.mll`

The lexer was updated with the new reserved words and symbols required by the extensions:

- `letrec`
- `fix`
- `String`
- `concat`
- `length`
- `proj`
- `{`, `}`, and `,`
- string literals

It also distinguishes:

- lowercase identifiers for term variables
- uppercase identifiers for type aliases

This distinction makes user input less ambiguous and simplifies parsing.

## 4. Design Decisions

The most relevant implementation decisions were the following:

- Multi-line input was implemented at the interactive loop level, using `;;` as an explicit terminator.
- Recursive definitions were implemented by translating `letrec` into `fix`, instead of duplicating recursion logic in the evaluator.
- The global context was implemented as a functional list of bindings, where new definitions shadow older ones.
- Type aliases are resolved explicitly with cycle detection.
- Tuples were implemented using OCaml lists inside the abstract syntax tree, but only as an internal representation of tuple components, not as a replacement for lambda-calculus lists.

These decisions keep the implementation relatively small while still covering the requested extensions in a clear way.


