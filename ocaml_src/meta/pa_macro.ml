(* camlp5r *)
(* This file has been generated by program: do not edit! *)

(*
Added statements:

  In structure items:

     DEFINE <uident>
     DEFINE <uident> = <expression>
     DEFINE <uident> <parameters> = <expression>
     IFDEF <dexpr> THEN <structure_items> END
     IFDEF <dexpr> THEN <structure_items> ELSE <structure_items> END
     IFNDEF <dexpr> THEN <structure_items> END
     IFNDEF <dexpr> THEN <structure_items> ELSE <structure_items> END

  In signature items:

     DEFINE <uident>
     DEFINE <uident> = <type>
     DEFINE <uident> <parameters> = <type>
     IFDEF <dexpr> THEN <signature_items> END
     IFDEF <dexpr> THEN <signature_items> ELSE <signature_items> END
     IFNDEF <dexpr> THEN <signature_items> END
     IFNDEF <dexpr> THEN <signature_items> ELSE <signature_items> END

  In expressions:

     IFDEF <dexpr> THEN <expression> ELSE <expression> END
     IFNDEF <dexpr> THEN <expression> ELSE <expression> END
     __FILE__
     __LOCATION__

  In patterns:

     IFDEF <dexpr> THEN <pattern> ELSE <pattern> END
     IFNDEF <dexpr> THEN <pattern> ELSE <pattern> END

  In types:

     IFDEF <dexpr> THEN <type> ELSE <type> END
     IFNDEF <dexpr> THEN <type> ELSE <type> END

  In constructors declarations and in match cases:

     IFDEF <dexpr> THEN <item> ELSE <item> END
     IFNDEF <dexpr> THEN <item> ELSE <item> END
     IFDEF <dexpr> THEN <item> END
     IFNDEF <dexpr> THEN <item> END

  A <dexpr> is either:

     <dexpr> OR <dexpr>
     <dexpr> AND <dexpr>
     NOT <dexpr>
     ( <dexpr> )
     <uident>

  As Camlp5 options:

     -D<uident>
     -U<uident>

  After having used a DEFINE <uident> followed by "= <expression>", you
  can use it in expressions *and* in patterns. If the expression defining
  the macro cannot be used as a pattern, there is an error message if
  it is used in a pattern.

  The expression __FILE__ returns the current compiled file name.
  The expression __LOCATION__ returns the current location of itself.

*)

(* #load "pa_extend.cmo";; *)
(* #load "q_MLast.cmo";; *)

open Pcaml;;

type macro_value =
    MvExpr of string list * MLast.expr
  | MvType of string list * MLast.ctyp
  | MvNone
;;

type 'a item_or_def =
    SdStr of 'a
  | SdDef of string * macro_value
  | SdUnd of string
  | SdNop
;;

let rec list_remove x =
  function
    (y, _) :: l when y = x -> l
  | d :: l -> d :: list_remove x l
  | [] -> []
;;

let oversion =
  let v = String.copy Pconfig.ocaml_version in
  for i = 0 to String.length v - 1 do
    match v.[i] with
      '0'..'9' -> ()
    | _ -> v.[i] <- '_'
  done;
  v
;;

let defined =
  ref ["CAMLP5", MvNone; "CAMLP5_4_02", MvNone; "OCAML_" ^ oversion, MvNone]
;;

let is_defined i =
  i = "STRICT" && !(Pcaml.strict_mode) || List.mem_assoc i !defined
;;

let print_defined () =
  List.iter
    (fun (d, v) ->
       print_string d;
       begin match v with
         MvExpr (_, _) -> print_string " = <expr>"
       | MvType (_, _) -> print_string " = <type>"
       | MvNone -> ()
       end;
       print_newline ())
    !defined;
  if !(Sys.interactive) then () else exit 0
;;

let loc = Ploc.dummy;;

let subst mloc env =
  let rec loop =
    function
      MLast.ExLet (_, rf, pel, e) ->
        let pel = List.map (fun (p, e) -> p, loop e) pel in
        MLast.ExLet (loc, rf, pel, loop e)
    | MLast.ExIfe (_, e1, e2, e3) ->
        MLast.ExIfe (loc, loop e1, loop e2, loop e3)
    | MLast.ExApp (_, e1, e2) -> MLast.ExApp (loc, loop e1, loop e2)
    | MLast.ExLid (_, x) | MLast.ExUid (_, x) as e ->
        (try MLast.ExAnt (loc, List.assoc x env) with Not_found -> e)
    | MLast.ExTup (_, x) -> MLast.ExTup (loc, List.map loop x)
    | MLast.ExRec (_, pel, None) ->
        let pel = List.map (fun (p, e) -> p, loop e) pel in
        MLast.ExRec (loc, pel, None)
    | e -> e
  in
  loop
;;

let substp mloc env =
  let rec loop =
    function
      MLast.ExAcc (_, e1, e2) -> MLast.PaAcc (loc, loop e1, loop e2)
    | MLast.ExApp (_, e1, e2) -> MLast.PaApp (loc, loop e1, loop e2)
    | MLast.ExLid (_, x) ->
        begin try MLast.PaAnt (loc, List.assoc x env) with
          Not_found -> MLast.PaLid (loc, x)
        end
    | MLast.ExUid (_, x) ->
        begin try MLast.PaAnt (loc, List.assoc x env) with
          Not_found -> MLast.PaUid (loc, x)
        end
    | MLast.ExInt (_, x, "") -> MLast.PaInt (loc, x, "")
    | MLast.ExTup (_, x) -> MLast.PaTup (loc, List.map loop x)
    | MLast.ExRec (_, pel, None) ->
        let ppl = List.map (fun (p, e) -> p, loop e) pel in
        MLast.PaRec (loc, ppl)
    | x ->
        Ploc.raise mloc
          (Failure
             "this macro cannot be used in a pattern (see its definition)")
  in
  loop
;;

let substt mloc env =
  let rec loop =
    function
      MLast.TyArr (_, t1, t2) -> MLast.TyArr (loc, loop t1, loop t2)
    | MLast.TyApp (_, t1, t2) -> MLast.TyApp (loc, loop t1, loop t2)
    | MLast.TyTup (_, tl) -> MLast.TyTup (loc, List.map loop tl)
    | MLast.TyLid (_, x) | MLast.TyUid (_, x) as t ->
        (try List.assoc x env with Not_found -> t)
    | t -> t
  in
  loop
;;

let incorrect_number loc l1 l2 =
  Ploc.raise loc
    (Failure
       (Printf.sprintf "expected %d parameters; found %d" (List.length l2)
          (List.length l1)))
;;

let define eo x =
  begin match eo with
    MvExpr ([], e) ->
      Grammar.extend
        [Grammar.Entry.obj (expr : 'expr Grammar.Entry.e),
         Some (Gramext.Level "simple"),
         [None, None,
          [[Gramext.Stoken ("UIDENT", x)],
           Gramext.action
             (fun _ (loc : Ploc.t) ->
                (Reloc.expr (fun _ -> loc) 0 e : 'expr))]];
         Grammar.Entry.obj (patt : 'patt Grammar.Entry.e),
         Some (Gramext.Level "simple"),
         [None, None,
          [[Gramext.Stoken ("UIDENT", x)],
           Gramext.action
             (fun _ (loc : Ploc.t) ->
                (let p = substp loc [] e in Reloc.patt (fun _ -> loc) 0 p :
                 'patt))]]]
  | MvExpr (sl, e) ->
      Grammar.extend
        [Grammar.Entry.obj (expr : 'expr Grammar.Entry.e),
         Some (Gramext.Level "apply"),
         [None, None,
          [[Gramext.Stoken ("UIDENT", x); Gramext.Sself],
           Gramext.action
             (fun (param : 'expr) _ (loc : Ploc.t) ->
                (let el =
                   match param with
                     MLast.ExTup (_, el) -> el
                   | e -> [e]
                 in
                 if List.length el = List.length sl then
                   let env = List.combine sl el in
                   let e = subst loc env e in Reloc.expr (fun _ -> loc) 0 e
                 else incorrect_number loc el sl :
                 'expr))]];
         Grammar.Entry.obj (patt : 'patt Grammar.Entry.e),
         Some (Gramext.Level "simple"),
         [None, None,
          [[Gramext.Stoken ("UIDENT", x); Gramext.Sself],
           Gramext.action
             (fun (param : 'patt) _ (loc : Ploc.t) ->
                (let pl =
                   match param with
                     MLast.PaTup (_, pl) -> pl
                   | p -> [p]
                 in
                 if List.length pl = List.length sl then
                   let env = List.combine sl pl in
                   let p = substp loc env e in Reloc.patt (fun _ -> loc) 0 p
                 else incorrect_number loc pl sl :
                 'patt))]]]
  | MvType ([], t) ->
      Grammar.extend
        [Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e),
         Some (Gramext.Level "simple"),
         [None, None,
          [[Gramext.Stoken ("UIDENT", x)],
           Gramext.action (fun _ (loc : Ploc.t) -> (t : 'ctyp))]]]
  | MvType (sl, t) ->
      Grammar.extend
        [Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e),
         Some (Gramext.Level "apply"),
         [None, None,
          [[Gramext.Stoken ("UIDENT", x); Gramext.Sself],
           Gramext.action
             (fun (param : 'ctyp) _ (loc : Ploc.t) ->
                (let tl =
                   match param with
                     MLast.TyTup (_, tl) -> tl
                   | t -> [t]
                 in
                 if List.length tl = List.length sl then
                   let env = List.combine sl tl in
                   let t = substt loc env t in t
                 else incorrect_number loc tl sl :
                 'ctyp))]]]
  | MvNone -> ()
  end;
  defined := (x, eo) :: !defined
;;

let undef x =
  try
    let eo = List.assoc x !defined in
    begin match eo with
      MvExpr ([], _) ->
        Grammar.delete_rule expr [Gramext.Stoken ("UIDENT", x)];
        Grammar.delete_rule patt [Gramext.Stoken ("UIDENT", x)]
    | MvExpr (_, _) ->
        Grammar.delete_rule expr
          [Gramext.Stoken ("UIDENT", x); Gramext.Sself];
        Grammar.delete_rule patt [Gramext.Stoken ("UIDENT", x); Gramext.Sself]
    | MvType ([], _) ->
        Grammar.delete_rule ctyp [Gramext.Stoken ("UIDENT", x)]
    | MvType (_, _) ->
        Grammar.delete_rule ctyp [Gramext.Stoken ("UIDENT", x); Gramext.Sself]
    | MvNone -> ()
    end;
    defined := list_remove x !defined
  with Not_found -> ()
;;

Grammar.extend
  (let _ = (expr : 'expr Grammar.Entry.e)
   and _ = (patt : 'patt Grammar.Entry.e)
   and _ = (str_item : 'str_item Grammar.Entry.e)
   and _ = (sig_item : 'sig_item Grammar.Entry.e)
   and _ =
     (constructor_declaration : 'constructor_declaration Grammar.Entry.e)
   and _ = (match_case : 'match_case Grammar.Entry.e) in
   let grammar_entry_create s =
     Grammar.create_local_entry (Grammar.of_entry expr) s
   in
   let str_macro_def : 'str_macro_def Grammar.Entry.e =
     grammar_entry_create "str_macro_def"
   and sig_macro_def : 'sig_macro_def Grammar.Entry.e =
     grammar_entry_create "sig_macro_def"
   and str_item_or_macro : 'str_item_or_macro Grammar.Entry.e =
     grammar_entry_create "str_item_or_macro"
   and sig_item_or_macro : 'sig_item_or_macro Grammar.Entry.e =
     grammar_entry_create "sig_item_or_macro"
   and opt_macro_expr : 'opt_macro_expr Grammar.Entry.e =
     grammar_entry_create "opt_macro_expr"
   and opt_macro_type : 'opt_macro_type Grammar.Entry.e =
     grammar_entry_create "opt_macro_type"
   and dexpr : 'dexpr Grammar.Entry.e = grammar_entry_create "dexpr"
   and uident : 'uident Grammar.Entry.e = grammar_entry_create "uident" in
   [Grammar.Entry.obj (str_item : 'str_item Grammar.Entry.e),
    Some Gramext.First,
    [None, None,
     [[Gramext.Snterm
         (Grammar.Entry.obj
            (str_macro_def : 'str_macro_def Grammar.Entry.e))],
      Gramext.action
        (fun (x : 'str_macro_def) (loc : Ploc.t) ->
           (match x with
              SdStr [si] -> si
            | SdStr sil -> MLast.StDcl (loc, sil)
            | SdDef (x, eo) -> define eo x; MLast.StDcl (loc, [])
            | SdUnd x -> undef x; MLast.StDcl (loc, [])
            | SdNop -> MLast.StDcl (loc, []) :
            'str_item))]];
    Grammar.Entry.obj (sig_item : 'sig_item Grammar.Entry.e),
    Some Gramext.First,
    [None, None,
     [[Gramext.Snterm
         (Grammar.Entry.obj
            (sig_macro_def : 'sig_macro_def Grammar.Entry.e))],
      Gramext.action
        (fun (x : 'sig_macro_def) (loc : Ploc.t) ->
           (match x with
              SdStr [si] -> si
            | SdStr sil -> MLast.SgDcl (loc, sil)
            | SdDef (x, eo) -> define eo x; MLast.SgDcl (loc, [])
            | SdUnd x -> undef x; MLast.SgDcl (loc, [])
            | SdNop -> MLast.SgDcl (loc, []) :
            'sig_item))]];
    Grammar.Entry.obj (str_macro_def : 'str_macro_def Grammar.Entry.e), None,
    [None, None,
     [[Gramext.Stoken ("", "IFNDEF");
       Gramext.Snterm (Grammar.Entry.obj (dexpr : 'dexpr Grammar.Entry.e));
       Gramext.Stoken ("", "THEN");
       Gramext.Snterm
         (Grammar.Entry.obj
            (str_item_or_macro : 'str_item_or_macro Grammar.Entry.e));
       Gramext.Stoken ("", "ELSE");
       Gramext.Snterm
         (Grammar.Entry.obj
            (str_item_or_macro : 'str_item_or_macro Grammar.Entry.e));
       Gramext.Stoken ("", "END")],
      Gramext.action
        (fun _ (d2 : 'str_item_or_macro) _ (d1 : 'str_item_or_macro) _
             (e : 'dexpr) _ (loc : Ploc.t) ->
           (if e then d2 else d1 : 'str_macro_def));
      [Gramext.Stoken ("", "IFNDEF");
       Gramext.Snterm (Grammar.Entry.obj (dexpr : 'dexpr Grammar.Entry.e));
       Gramext.Stoken ("", "THEN");
       Gramext.Snterm
         (Grammar.Entry.obj
            (str_item_or_macro : 'str_item_or_macro Grammar.Entry.e));
       Gramext.Stoken ("", "END")],
      Gramext.action
        (fun _ (d : 'str_item_or_macro) _ (e : 'dexpr) _ (loc : Ploc.t) ->
           (if e then SdNop else d : 'str_macro_def));
      [Gramext.Stoken ("", "IFDEF");
       Gramext.Snterm (Grammar.Entry.obj (dexpr : 'dexpr Grammar.Entry.e));
       Gramext.Stoken ("", "THEN");
       Gramext.Snterm
         (Grammar.Entry.obj
            (str_item_or_macro : 'str_item_or_macro Grammar.Entry.e));
       Gramext.Stoken ("", "ELSE");
       Gramext.Snterm
         (Grammar.Entry.obj
            (str_item_or_macro : 'str_item_or_macro Grammar.Entry.e));
       Gramext.Stoken ("", "END")],
      Gramext.action
        (fun _ (d2 : 'str_item_or_macro) _ (d1 : 'str_item_or_macro) _
             (e : 'dexpr) _ (loc : Ploc.t) ->
           (if e then d1 else d2 : 'str_macro_def));
      [Gramext.Stoken ("", "IFDEF");
       Gramext.Snterm (Grammar.Entry.obj (dexpr : 'dexpr Grammar.Entry.e));
       Gramext.Stoken ("", "THEN");
       Gramext.Snterm
         (Grammar.Entry.obj
            (str_item_or_macro : 'str_item_or_macro Grammar.Entry.e));
       Gramext.Stoken ("", "END")],
      Gramext.action
        (fun _ (d : 'str_item_or_macro) _ (e : 'dexpr) _ (loc : Ploc.t) ->
           (if e then d else SdNop : 'str_macro_def));
      [Gramext.Stoken ("", "UNDEF");
       Gramext.Snterm (Grammar.Entry.obj (uident : 'uident Grammar.Entry.e))],
      Gramext.action
        (fun (i : 'uident) _ (loc : Ploc.t) -> (SdUnd i : 'str_macro_def));
      [Gramext.Stoken ("", "DEFINE_TYPE");
       Gramext.Snterm (Grammar.Entry.obj (uident : 'uident Grammar.Entry.e));
       Gramext.Snterm
         (Grammar.Entry.obj
            (opt_macro_type : 'opt_macro_type Grammar.Entry.e))],
      Gramext.action
        (fun (def : 'opt_macro_type) (i : 'uident) _ (loc : Ploc.t) ->
           (SdDef (i, def) : 'str_macro_def));
      [Gramext.Stoken ("", "DEFINE");
       Gramext.Snterm (Grammar.Entry.obj (uident : 'uident Grammar.Entry.e));
       Gramext.Snterm
         (Grammar.Entry.obj
            (opt_macro_expr : 'opt_macro_expr Grammar.Entry.e))],
      Gramext.action
        (fun (def : 'opt_macro_expr) (i : 'uident) _ (loc : Ploc.t) ->
           (SdDef (i, def) : 'str_macro_def))]];
    Grammar.Entry.obj (sig_macro_def : 'sig_macro_def Grammar.Entry.e), None,
    [None, None,
     [[Gramext.Stoken ("", "IFNDEF");
       Gramext.Snterm (Grammar.Entry.obj (dexpr : 'dexpr Grammar.Entry.e));
       Gramext.Stoken ("", "THEN");
       Gramext.Snterm
         (Grammar.Entry.obj
            (sig_item_or_macro : 'sig_item_or_macro Grammar.Entry.e));
       Gramext.Stoken ("", "ELSE");
       Gramext.Snterm
         (Grammar.Entry.obj
            (sig_item_or_macro : 'sig_item_or_macro Grammar.Entry.e));
       Gramext.Stoken ("", "END")],
      Gramext.action
        (fun _ (d2 : 'sig_item_or_macro) _ (d1 : 'sig_item_or_macro) _
             (e : 'dexpr) _ (loc : Ploc.t) ->
           (if e then d2 else d1 : 'sig_macro_def));
      [Gramext.Stoken ("", "IFNDEF");
       Gramext.Snterm (Grammar.Entry.obj (dexpr : 'dexpr Grammar.Entry.e));
       Gramext.Stoken ("", "THEN");
       Gramext.Snterm
         (Grammar.Entry.obj
            (sig_item_or_macro : 'sig_item_or_macro Grammar.Entry.e));
       Gramext.Stoken ("", "END")],
      Gramext.action
        (fun _ (d : 'sig_item_or_macro) _ (e : 'dexpr) _ (loc : Ploc.t) ->
           (if e then SdNop else d : 'sig_macro_def));
      [Gramext.Stoken ("", "IFDEF");
       Gramext.Snterm (Grammar.Entry.obj (dexpr : 'dexpr Grammar.Entry.e));
       Gramext.Stoken ("", "THEN");
       Gramext.Snterm
         (Grammar.Entry.obj
            (sig_item_or_macro : 'sig_item_or_macro Grammar.Entry.e));
       Gramext.Stoken ("", "ELSE");
       Gramext.Snterm
         (Grammar.Entry.obj
            (sig_item_or_macro : 'sig_item_or_macro Grammar.Entry.e));
       Gramext.Stoken ("", "END")],
      Gramext.action
        (fun _ (d2 : 'sig_item_or_macro) _ (d1 : 'sig_item_or_macro) _
             (e : 'dexpr) _ (loc : Ploc.t) ->
           (if e then d1 else d2 : 'sig_macro_def));
      [Gramext.Stoken ("", "IFDEF");
       Gramext.Snterm (Grammar.Entry.obj (dexpr : 'dexpr Grammar.Entry.e));
       Gramext.Stoken ("", "THEN");
       Gramext.Snterm
         (Grammar.Entry.obj
            (sig_item_or_macro : 'sig_item_or_macro Grammar.Entry.e));
       Gramext.Stoken ("", "END")],
      Gramext.action
        (fun _ (d : 'sig_item_or_macro) _ (e : 'dexpr) _ (loc : Ploc.t) ->
           (if e then d else SdNop : 'sig_macro_def));
      [Gramext.Stoken ("", "UNDEF");
       Gramext.Snterm (Grammar.Entry.obj (uident : 'uident Grammar.Entry.e))],
      Gramext.action
        (fun (i : 'uident) _ (loc : Ploc.t) -> (SdUnd i : 'sig_macro_def));
      [Gramext.Stoken ("", "DEFINE_TYPE");
       Gramext.Snterm (Grammar.Entry.obj (uident : 'uident Grammar.Entry.e));
       Gramext.Snterm
         (Grammar.Entry.obj
            (opt_macro_type : 'opt_macro_type Grammar.Entry.e))],
      Gramext.action
        (fun (def : 'opt_macro_type) (i : 'uident) _ (loc : Ploc.t) ->
           (SdDef (i, def) : 'sig_macro_def));
      [Gramext.Stoken ("", "DEFINE");
       Gramext.Snterm (Grammar.Entry.obj (uident : 'uident Grammar.Entry.e));
       Gramext.Snterm
         (Grammar.Entry.obj
            (opt_macro_type : 'opt_macro_type Grammar.Entry.e))],
      Gramext.action
        (fun (def : 'opt_macro_type) (i : 'uident) _ (loc : Ploc.t) ->
           (SdDef (i, def) : 'sig_macro_def))]];
    Grammar.Entry.obj
      (str_item_or_macro : 'str_item_or_macro Grammar.Entry.e),
    None,
    [None, None,
     [[Gramext.Slist1
         (Gramext.Snterm
            (Grammar.Entry.obj (str_item : 'str_item Grammar.Entry.e)))],
      Gramext.action
        (fun (si : 'str_item list) (loc : Ploc.t) ->
           (SdStr si : 'str_item_or_macro));
      [Gramext.Snterm
         (Grammar.Entry.obj
            (str_macro_def : 'str_macro_def Grammar.Entry.e))],
      Gramext.action
        (fun (d : 'str_macro_def) (loc : Ploc.t) ->
           (d : 'str_item_or_macro))]];
    Grammar.Entry.obj
      (sig_item_or_macro : 'sig_item_or_macro Grammar.Entry.e),
    None,
    [None, None,
     [[Gramext.Slist1
         (Gramext.Snterm
            (Grammar.Entry.obj (sig_item : 'sig_item Grammar.Entry.e)))],
      Gramext.action
        (fun (si : 'sig_item list) (loc : Ploc.t) ->
           (SdStr si : 'sig_item_or_macro));
      [Gramext.Snterm
         (Grammar.Entry.obj
            (sig_macro_def : 'sig_macro_def Grammar.Entry.e))],
      Gramext.action
        (fun (d : 'sig_macro_def) (loc : Ploc.t) ->
           (d : 'sig_item_or_macro))]];
    Grammar.Entry.obj (opt_macro_expr : 'opt_macro_expr Grammar.Entry.e),
    None,
    [None, None,
     [[], Gramext.action (fun (loc : Ploc.t) -> (MvNone : 'opt_macro_expr));
      [Gramext.Stoken ("", "=");
       Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e))],
      Gramext.action
        (fun (e : 'expr) _ (loc : Ploc.t) ->
           (MvExpr ([], e) : 'opt_macro_expr));
      [Gramext.Slist1 (Gramext.Stoken ("LIDENT", ""));
       Gramext.Stoken ("", "=");
       Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e))],
      Gramext.action
        (fun (e : 'expr) _ (pl : string list) (loc : Ploc.t) ->
           (MvExpr (pl, e) : 'opt_macro_expr))]];
    Grammar.Entry.obj (opt_macro_type : 'opt_macro_type Grammar.Entry.e),
    None,
    [None, None,
     [[], Gramext.action (fun (loc : Ploc.t) -> (MvNone : 'opt_macro_type));
      [Gramext.Stoken ("", "=");
       Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e))],
      Gramext.action
        (fun (t : 'ctyp) _ (loc : Ploc.t) ->
           (MvType ([], t) : 'opt_macro_type));
      [Gramext.Slist1 (Gramext.Stoken ("LIDENT", ""));
       Gramext.Stoken ("", "=");
       Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e))],
      Gramext.action
        (fun (t : 'ctyp) _ (pl : string list) (loc : Ploc.t) ->
           (MvType (pl, t) : 'opt_macro_type))]];
    Grammar.Entry.obj (expr : 'expr Grammar.Entry.e),
    Some (Gramext.Level "top"),
    [None, None,
     [[Gramext.Stoken ("", "IFNDEF");
       Gramext.Snterm (Grammar.Entry.obj (dexpr : 'dexpr Grammar.Entry.e));
       Gramext.Stoken ("", "THEN"); Gramext.Sself;
       Gramext.Stoken ("", "ELSE"); Gramext.Sself;
       Gramext.Stoken ("", "END")],
      Gramext.action
        (fun _ (e2 : 'expr) _ (e1 : 'expr) _ (e : 'dexpr) _ (loc : Ploc.t) ->
           (if e then e2 else e1 : 'expr));
      [Gramext.Stoken ("", "IFDEF");
       Gramext.Snterm (Grammar.Entry.obj (dexpr : 'dexpr Grammar.Entry.e));
       Gramext.Stoken ("", "THEN"); Gramext.Sself;
       Gramext.Stoken ("", "ELSE"); Gramext.Sself;
       Gramext.Stoken ("", "END")],
      Gramext.action
        (fun _ (e2 : 'expr) _ (e1 : 'expr) _ (e : 'dexpr) _ (loc : Ploc.t) ->
           (if e then e1 else e2 : 'expr))]];
    Grammar.Entry.obj (expr : 'expr Grammar.Entry.e),
    Some (Gramext.Level "simple"),
    [None, None,
     [[Gramext.Stoken ("LIDENT", "__LOCATION__")],
      Gramext.action
        (fun _ (loc : Ploc.t) ->
           (let bp = string_of_int (Ploc.first_pos loc) in
            let ep = string_of_int (Ploc.last_pos loc) in
            MLast.ExTup
              (loc, [MLast.ExInt (loc, bp, ""); MLast.ExInt (loc, ep, "")]) :
            'expr));
      [Gramext.Stoken ("LIDENT", "__FILE__")],
      Gramext.action
        (fun _ (loc : Ploc.t) ->
           (MLast.ExStr (loc, !(Pcaml.input_file)) : 'expr))]];
    Grammar.Entry.obj (patt : 'patt Grammar.Entry.e), None,
    [None, None,
     [[Gramext.Stoken ("", "IFNDEF");
       Gramext.Snterm (Grammar.Entry.obj (dexpr : 'dexpr Grammar.Entry.e));
       Gramext.Stoken ("", "THEN"); Gramext.Sself;
       Gramext.Stoken ("", "ELSE"); Gramext.Sself;
       Gramext.Stoken ("", "END")],
      Gramext.action
        (fun _ (p2 : 'patt) _ (p1 : 'patt) _ (e : 'dexpr) _ (loc : Ploc.t) ->
           (if e then p2 else p1 : 'patt));
      [Gramext.Stoken ("", "IFDEF");
       Gramext.Snterm (Grammar.Entry.obj (dexpr : 'dexpr Grammar.Entry.e));
       Gramext.Stoken ("", "THEN"); Gramext.Sself;
       Gramext.Stoken ("", "ELSE"); Gramext.Sself;
       Gramext.Stoken ("", "END")],
      Gramext.action
        (fun _ (p2 : 'patt) _ (p1 : 'patt) _ (e : 'dexpr) _ (loc : Ploc.t) ->
           (if e then p1 else p2 : 'patt))]];
    Grammar.Entry.obj
      (constructor_declaration : 'constructor_declaration Grammar.Entry.e),
    Some Gramext.First,
    [None, None,
     [[Gramext.Stoken ("", "IFNDEF");
       Gramext.Snterm (Grammar.Entry.obj (dexpr : 'dexpr Grammar.Entry.e));
       Gramext.Stoken ("", "THEN"); Gramext.Sself;
       Gramext.Stoken ("", "ELSE"); Gramext.Sself;
       Gramext.Stoken ("", "END")],
      Gramext.action
        (fun _ (y : 'constructor_declaration) _ (x : 'constructor_declaration)
             _ (e : 'dexpr) _ (loc : Ploc.t) ->
           (if e then y else x : 'constructor_declaration));
      [Gramext.Stoken ("", "IFNDEF");
       Gramext.Snterm (Grammar.Entry.obj (dexpr : 'dexpr Grammar.Entry.e));
       Gramext.Stoken ("", "THEN"); Gramext.Sself;
       Gramext.Stoken ("", "END")],
      Gramext.action
        (fun _ (x : 'constructor_declaration) _ (e : 'dexpr) _
             (loc : Ploc.t) ->
           (if e then raise Grammar.SkipItem else x :
            'constructor_declaration));
      [Gramext.Stoken ("", "IFDEF");
       Gramext.Snterm (Grammar.Entry.obj (dexpr : 'dexpr Grammar.Entry.e));
       Gramext.Stoken ("", "THEN"); Gramext.Sself;
       Gramext.Stoken ("", "ELSE"); Gramext.Sself;
       Gramext.Stoken ("", "END")],
      Gramext.action
        (fun _ (y : 'constructor_declaration) _ (x : 'constructor_declaration)
             _ (e : 'dexpr) _ (loc : Ploc.t) ->
           (if e then x else y : 'constructor_declaration));
      [Gramext.Stoken ("", "IFDEF");
       Gramext.Snterm (Grammar.Entry.obj (dexpr : 'dexpr Grammar.Entry.e));
       Gramext.Stoken ("", "THEN"); Gramext.Sself;
       Gramext.Stoken ("", "END")],
      Gramext.action
        (fun _ (x : 'constructor_declaration) _ (e : 'dexpr) _
             (loc : Ploc.t) ->
           (if e then x else raise Grammar.SkipItem :
            'constructor_declaration))]];
    Grammar.Entry.obj (match_case : 'match_case Grammar.Entry.e),
    Some Gramext.First,
    [None, None,
     [[Gramext.Stoken ("", "IFNDEF");
       Gramext.Snterm (Grammar.Entry.obj (dexpr : 'dexpr Grammar.Entry.e));
       Gramext.Stoken ("", "THEN"); Gramext.Sself;
       Gramext.Stoken ("", "ELSE"); Gramext.Sself;
       Gramext.Stoken ("", "END")],
      Gramext.action
        (fun _ (y : 'match_case) _ (x : 'match_case) _ (e : 'dexpr) _
             (loc : Ploc.t) ->
           (if e then y else x : 'match_case));
      [Gramext.Stoken ("", "IFNDEF");
       Gramext.Snterm (Grammar.Entry.obj (dexpr : 'dexpr Grammar.Entry.e));
       Gramext.Stoken ("", "THEN"); Gramext.Sself;
       Gramext.Stoken ("", "END")],
      Gramext.action
        (fun _ (x : 'match_case) _ (e : 'dexpr) _ (loc : Ploc.t) ->
           (if e then raise Grammar.SkipItem else x : 'match_case));
      [Gramext.Stoken ("", "IFDEF");
       Gramext.Snterm (Grammar.Entry.obj (dexpr : 'dexpr Grammar.Entry.e));
       Gramext.Stoken ("", "THEN"); Gramext.Sself;
       Gramext.Stoken ("", "ELSE"); Gramext.Sself;
       Gramext.Stoken ("", "END")],
      Gramext.action
        (fun _ (y : 'match_case) _ (x : 'match_case) _ (e : 'dexpr) _
             (loc : Ploc.t) ->
           (if e then x else y : 'match_case));
      [Gramext.Stoken ("", "IFDEF");
       Gramext.Snterm (Grammar.Entry.obj (dexpr : 'dexpr Grammar.Entry.e));
       Gramext.Stoken ("", "THEN"); Gramext.Sself;
       Gramext.Stoken ("", "END")],
      Gramext.action
        (fun _ (x : 'match_case) _ (e : 'dexpr) _ (loc : Ploc.t) ->
           (if e then x else raise Grammar.SkipItem : 'match_case))]];
    Grammar.Entry.obj (dexpr : 'dexpr Grammar.Entry.e), None,
    [None, None,
     [[Gramext.Sself; Gramext.Stoken ("", "OR"); Gramext.Sself],
      Gramext.action
        (fun (y : 'dexpr) _ (x : 'dexpr) (loc : Ploc.t) ->
           (x || y : 'dexpr))];
     None, None,
     [[Gramext.Sself; Gramext.Stoken ("", "AND"); Gramext.Sself],
      Gramext.action
        (fun (y : 'dexpr) _ (x : 'dexpr) (loc : Ploc.t) ->
           (y && y : 'dexpr))];
     None, None,
     [[Gramext.Stoken ("", "NOT"); Gramext.Sself],
      Gramext.action (fun (x : 'dexpr) _ (loc : Ploc.t) -> (not x : 'dexpr))];
     None, None,
     [[Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", ")")],
      Gramext.action (fun _ (x : 'dexpr) _ (loc : Ploc.t) -> (x : 'dexpr));
      [Gramext.Snterm (Grammar.Entry.obj (uident : 'uident Grammar.Entry.e))],
      Gramext.action
        (fun (i : 'uident) (loc : Ploc.t) -> (is_defined i : 'dexpr))]];
    Grammar.Entry.obj (uident : 'uident Grammar.Entry.e), None,
    [None, None,
     [[Gramext.Stoken ("UIDENT", "")],
      Gramext.action (fun (i : string) (loc : Ploc.t) -> (i : 'uident))]]]);;

Pcaml.add_option "-D" (Arg.String (define MvNone))
  "<string> Define for IFDEF instruction.";;

Pcaml.add_option "-U" (Arg.String undef)
  "<string> Undefine for IFDEF instruction.";;

Pcaml.add_option "-defined" (Arg.Unit print_defined)
  " Print the defined macros and exit.";;
