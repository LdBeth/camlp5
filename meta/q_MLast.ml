(* camlp5r pa_extend.cmo pa_extend_m.cmo q_MLast.cmo *)
(* $Id: q_MLast.ml,v 1.92 2007/09/18 02:33:32 deraugla Exp $ *)
(* Copyright (c) INRIA 2007 *)

value gram = Grammar.gcreate (Plexer.gmake ());

value antiquot k loc s f =
  let shift_bp =
    if k = "" then String.length "$"
    else String.length "$" + String.length k + String.length ":"
  in
  let shift_ep = String.length "$" in
  let loc =
    Ploc.make (Ploc.line_nb loc) (Ploc.bol_pos loc)
      (Ploc.first_pos loc + shift_bp, Ploc.last_pos loc - shift_ep)
  in
  try (loc, Grammar.Entry.parse f (Stream.of_string s)) with
  [ Ploc.Exc loc1 exc ->
      let shift = Ploc.first_pos loc in
      let loc =
        Ploc.make
          (Ploc.line_nb loc + Ploc.line_nb loc1 - 1)
          (if Ploc.line_nb loc1 = 1 then Ploc.bol_pos loc
           else shift + Ploc.bol_pos loc1)
          (shift + Ploc.first_pos loc1,
           shift + Ploc.last_pos loc1)
      in
      raise (Ploc.Exc loc exc) ]
;

module Qast =
  struct
    type t =
      [ Node of string and list t
      | List of list t
      | Tuple of list t
      | Option of option t
      | Int of string
      | Str of string
      | Bool of bool
      | Cons of t and t
      | Apply of string and list t
      | Record of list (string * t)
      | Loc
      | VaAnt of string and MLast.loc and string
      | VaVal of t ]
    ;
    value loc = Ploc.dummy;
    value expr_node m n =
      if m = "" then <:expr< $uid:n$ >> else <:expr< $uid:m$ . $uid:n$ >>
    ;
    value patt m n =
      if m = "" then <:patt< $uid:n$ >> else <:patt< $uid:m$ . $uid:n$ >>
    ;
    value rec to_expr m =
      fun
      [ Node n al ->
          List.fold_left (fun e a -> <:expr< $e$ $to_expr m a$ >>)
            (expr_node m n) al
      | List al ->
          List.fold_right (fun a e -> <:expr< [$to_expr m a$ :: $e$] >>) al
            <:expr< [] >>
      | Tuple al -> <:expr< ($list:List.map (to_expr m) al$) >>
      | Option None -> <:expr< None >>
      | Option (Some a) -> <:expr< Some $to_expr m a$ >>
      | Int s -> <:expr< $int:s$ >>
      | Str s -> <:expr< $str:s$ >>
      | Bool True -> <:expr< True >>
      | Bool False -> <:expr< False >>
      | Cons a1 a2 -> <:expr< [$to_expr m a1$ :: $to_expr m a2$] >>
      | Apply f al ->
          List.fold_left (fun e a -> <:expr< $e$ $to_expr m a$ >>)
            <:expr< $lid:f$ >> al
      | Record lal -> <:expr< {$list:List.map (to_expr_label m) lal$} >>
      | Loc -> <:expr< $lid:Ploc.name.val$ >>
      | VaAnt k loc x ->
          let (loc, e) = antiquot k loc x Pcaml.expr_eoi in
          <:expr< $anti:e$ >>
      | VaVal a ->
          let e = to_expr m a in
          if Pcaml.strict_mode.val then
            match e with
            [ <:expr< $anti:ee$ >> ->
                let loc = MLast.loc_of_expr ee in
                let ee = <:expr< Ploc.VaVal $ee$ >> in
                let loc = MLast.loc_of_expr e in
                <:expr< $anti:ee$ >>
            | _ -> <:expr< Ploc.VaVal $e$ >> ]
          else e ]
    and to_expr_label m (l, a) = (<:patt< MLast.$lid:l$ >>, to_expr m a);
    value rec to_patt m =
      fun
      [ Node n al ->
          List.fold_left (fun e a -> <:patt< $e$ $to_patt m a$ >>)
            (patt m n) al
      | List al ->
          List.fold_right (fun a p -> <:patt< [$to_patt m a$ :: $p$] >>) al
            <:patt< [] >>
      | Tuple al -> <:patt< ($list:List.map (to_patt m) al$) >>
      | Option None -> <:patt< None >>
      | Option (Some a) -> <:patt< Some $to_patt m a$ >>
      | Int s -> <:patt< $int:s$ >>
      | Str s -> <:patt< $str:s$ >>
      | Bool True -> <:patt< True >>
      | Bool False -> <:patt< False >>
      | Cons a1 a2 -> <:patt< [$to_patt m a1$ :: $to_patt m a2$] >>
      | Apply _ _ -> failwith "bad pattern"
      | Record lal -> <:patt< {$list:List.map (to_patt_label m) lal$} >>
      | Loc -> <:patt< _ >>
      | VaAnt k loc x ->
          let (loc, e) = antiquot k loc x Pcaml.patt_eoi in
          <:patt< $anti:e$ >>
      | VaVal a ->
          let p = to_patt m a in
          if Pcaml.strict_mode.val then
            match p with
            [ <:patt< $anti:pp$ >> ->
                let loc = MLast.loc_of_patt pp in
                let pp = <:patt< Ploc.VaVal $pp$ >> in
                let loc = MLast.loc_of_patt p in
                <:patt< $anti:pp$ >>
            | _ -> <:patt< Ploc.VaVal $p$ >> ]
          else p ]
    and to_patt_label m (l, a) = (<:patt< MLast.$lid:l$ >>, to_patt m a);
  end
;

value sig_item = Grammar.Entry.create gram "signature item";
value str_item = Grammar.Entry.create gram "structure item";
value ctyp = Grammar.Entry.create gram "type";
value patt = Grammar.Entry.create gram "pattern";
value expr = Grammar.Entry.create gram "expression";

value module_type = Grammar.Entry.create gram "module type";
value module_expr = Grammar.Entry.create gram "module expression";

value class_type = Grammar.Entry.create gram "class type";
value class_expr = Grammar.Entry.create gram "class expr";
value class_sig_item = Grammar.Entry.create gram "class signature item";
value class_str_item = Grammar.Entry.create gram "class structure item";

value ipatt = Grammar.Entry.create gram "ipatt";
value let_binding = Grammar.Entry.create gram "let_binding";
value type_declaration = Grammar.Entry.create gram "type_declaration";
value match_case = Grammar.Entry.create gram "match_case";
value constructor_declaration =
  Grammar.Entry.create gram "constructor_declaration";

value with_constr = Grammar.Entry.create gram "with_constr";
value poly_variant = Grammar.Entry.create gram "poly_variant";

value a_list = Grammar.Entry.create gram "a_list";
value a_list2 = Grammar.Entry.create gram "a_list2";
value a_opt = Grammar.Entry.create gram "a_opt";
value a_opt2 = Grammar.Entry.create gram "a_opt2";
value a_flag = Grammar.Entry.create gram "a_flag";
value a_flag2 = Grammar.Entry.create gram "a_flag2";
value a_UIDENT = Grammar.Entry.create gram "a_UIDENT";
value a_UIDENT2 = Grammar.Entry.create gram "a_UIDENT2";
value a_LIDENT = Grammar.Entry.create gram "a_LIDENT";
value a_LIDENT2 = Grammar.Entry.create gram "a_LIDENT2";
value a_INT = Grammar.Entry.create gram "a_INT";
value a_INT2 = Grammar.Entry.create gram "a_INT2";
value a_INT_l = Grammar.Entry.create gram "a_INT_l";
value a_INT_l2 = Grammar.Entry.create gram "a_INT_l2";
value a_INT_L = Grammar.Entry.create gram "a_INT_L";
value a_INT_L2 = Grammar.Entry.create gram "a_INT_L2";
value a_INT_n = Grammar.Entry.create gram "a_INT_n";
value a_INT_n2 = Grammar.Entry.create gram "a_INT_n2";
value a_FLOAT = Grammar.Entry.create gram "a_FLOAT";
value a_FLOAT2 = Grammar.Entry.create gram "a_FLOAT2";
value a_STRING = Grammar.Entry.create gram "a_STRING";
value a_STRING2 = Grammar.Entry.create gram "a_STRING2";
value a_CHAR = Grammar.Entry.create gram "a_CHAR";
value a_CHAR2 = Grammar.Entry.create gram "a_CHAR2";
value a_TILDEIDENT = Grammar.Entry.create gram "a_TILDEIDENT";
value a_TILDEIDENTCOLON = Grammar.Entry.create gram "a_TILDEIDENTCOLON";
value a_QUESTIONIDENT = Grammar.Entry.create gram "a_QUESTIONIDENT";
value a_QUESTIONIDENTCOLON = Grammar.Entry.create gram "a_QUESTIONIDENTCOLON";

value mksequence2 _ =
  fun
  [ Qast.VaVal (Qast.List [e]) -> e
  | el -> Qast.Node "ExSeq" [Qast.Loc; el] ]
;

value mksequence _ =
  fun
  [ Qast.List [e] -> e
  | el -> Qast.Node "ExSeq" [Qast.Loc; Qast.VaVal el] ]
;

value mkmatchcase _ p aso w e =
  let p =
    match aso with
    [ Qast.Option (Some p2) -> Qast.Node "PaAli" [Qast.Loc; p; p2]
    | Qast.Option None -> p
    | _ -> Qast.Node "PaAli" [Qast.Loc; p; aso] ]
  in
  Qast.Tuple [p; w; e]
;

value neg_string n =
  let len = String.length n in
  if len > 0 && n.[0] = '-' then String.sub n 1 (len - 1)
  else "-" ^ n
;

value mkumin _ f arg =
  match arg with
  [ Qast.Node "ExInt" [Qast.Loc; Qast.VaVal (Qast.Str n); Qast.Str c]
    when int_of_string n > 0 ->
      let n = neg_string n in
      Qast.Node "ExInt" [Qast.Loc; Qast.VaVal (Qast.Str n); Qast.Str c]
  | Qast.Node "ExFlo" [Qast.Loc; Qast.VaVal (Qast.Str n)]
    when float_of_string n > 0.0 ->
      let n = neg_string n in
      Qast.Node "ExFlo" [Qast.Loc; Qast.VaVal (Qast.Str n)]
  | _ ->
      match f with
      [ Qast.VaVal (Qast.Str f) | Qast.Str f ->
          let f = "~" ^ f in
          Qast.Node "ExApp"
            [Qast.Loc; Qast.Node "ExLid" [Qast.Loc; Qast.VaVal (Qast.Str f)];
             arg]
      | _ -> assert False ] ]
;

value mkuminpat _ f is_int s =
  let s =
    match s with
    [ Qast.Str s -> Qast.Str (neg_string s)
    | s -> failwith "bad unary minus" ]
  in
  match is_int with
  [ Qast.Bool True -> Qast.Node "PaInt" [Qast.Loc; Qast.VaVal s; Qast.Str ""]
  | Qast.Bool False -> Qast.Node "PaFlo" [Qast.Loc; Qast.VaVal s]
  | _ -> assert False ]
;

value mklistexp _ last =
  loop True where rec loop top =
    fun
    [ Qast.List [] ->
        match last with
        [ Qast.Option (Some e) -> e
        | Qast.Option None ->
            Qast.Node "ExUid" [Qast.Loc; Qast.VaVal (Qast.Str "[]")]
        | a -> a ]
    | Qast.List [e1 :: el] ->
        Qast.Node "ExApp"
          [Qast.Loc;
           Qast.Node "ExApp"
             [Qast.Loc;
              Qast.Node "ExUid" [Qast.Loc; Qast.VaVal (Qast.Str "::")]; e1];
           loop False (Qast.List el)]
    | a -> a ]
;

value mklistpat _ last =
  loop True where rec loop top =
    fun
    [ Qast.List [] ->
        match last with
        [ Qast.Option (Some p) -> p
        | Qast.Option None ->
            Qast.Node "PaUid" [Qast.Loc; Qast.VaVal (Qast.Str "[]")]
        | a -> a ]
    | Qast.List [p1 :: pl] ->
        Qast.Node "PaApp"
          [Qast.Loc;
           Qast.Node "PaApp"
             [Qast.Loc;
              Qast.Node "PaUid" [Qast.Loc; Qast.VaVal (Qast.Str "::")]; p1];
           loop False (Qast.List pl)]
    | a -> a ]
;

value append_elem el e = Qast.Apply "@" [el; Qast.List [e]];

EXTEND
  GLOBAL: sig_item str_item ctyp patt expr module_type module_expr class_type
    class_expr class_sig_item class_str_item let_binding type_declaration
    constructor_declaration match_case ipatt with_constr poly_variant;
  module_expr:
    [ [ "functor"; "("; i = a_UIDENT2; ":"; t = module_type; ")"; "->";
        me = SELF ->
          Qast.Node "MeFun" [Qast.Loc; i; t; me]
      | "struct"; st = SV LIST0 [ s = str_item; ";" -> s ]; "end" ->
          Qast.Node "MeStr" [Qast.Loc; st] ]
    | [ me1 = SELF; me2 = SELF -> Qast.Node "MeApp" [Qast.Loc; me1; me2] ]
    | [ me1 = SELF; "."; me2 = SELF ->
          Qast.Node "MeAcc" [Qast.Loc; me1; me2] ]
    | "simple"
      [ i = a_UIDENT2 -> Qast.Node "MeUid" [Qast.Loc; i]
      | "("; me = SELF; ":"; mt = module_type; ")" ->
          Qast.Node "MeTyc" [Qast.Loc; me; mt]
      | "("; me = SELF; ")" -> me ] ]
  ;
  str_item:
    [ "top"
      [ "declare"; st = SV LIST0 [ s = str_item; ";" -> s ]; "end" ->
          Qast.Node "StDcl" [Qast.Loc; st]
      | "exception"; ctl = constructor_declaration; b = rebind_exn ->
          let (_, c, tl) =
            match ctl with
            [ Qast.Tuple [xx1; xx2; xx3] -> (xx1, xx2, xx3)
            | _ -> match () with [] ]
          in
          Qast.Node "StExc" [Qast.Loc; c; tl; b]
      | "external"; i = a_LIDENT2; ":"; t = ctyp; "=";
        pd = SV LIST1 a_STRING ->
          Qast.Node "StExt" [Qast.Loc; i; t; pd]
      | "include"; me = module_expr -> Qast.Node "StInc" [Qast.Loc; me]
      | "module"; r = SV FLAG "rec"; l = SV LIST1 mod_binding SEP "and" ->
          Qast.Node "StMod" [Qast.Loc; r; l]
      | "module"; "type"; i = a_UIDENT2; "="; mt = module_type ->
          Qast.Node "StMty" [Qast.Loc; i; mt]
      | "open"; i = mod_ident2 -> Qast.Node "StOpn" [Qast.Loc; i]
      | "type"; tdl = SV LIST1 type_declaration SEP "and" ->
          Qast.Node "StTyp" [Qast.Loc; tdl]
      | "value"; r = SV FLAG "rec"; l = SV LIST1 let_binding SEP "and" ->
          Qast.Node "StVal" [Qast.Loc; r; l]
      | e = expr -> Qast.Node "StExp" [Qast.Loc; e] ] ]
  ;
  rebind_exn:
    [ [ "="; a = mod_ident2 -> a
      | -> Qast.VaVal (Qast.List []) ] ]
  ;
  mod_binding:
    [ [ i = a_UIDENT; me = mod_fun_binding -> Qast.Tuple [i; me] ] ]
  ;
  mod_fun_binding:
    [ RIGHTA
      [ "("; m = a_UIDENT2; ":"; mt = module_type; ")"; mb = SELF ->
          Qast.Node "MeFun" [Qast.Loc; m; mt; mb]
      | ":"; mt = module_type; "="; me = module_expr ->
          Qast.Node "MeTyc" [Qast.Loc; me; mt]
      | "="; me = module_expr -> me ] ]
  ;
  module_type:
    [ [ "functor"; "("; i = a_UIDENT2; ":"; t = SELF; ")"; "->"; mt = SELF ->
          Qast.Node "MtFun" [Qast.Loc; i; t; mt] ]
    | [ mt = SELF; "with"; wcl = SV LIST1 with_constr SEP "and" ->
          Qast.Node "MtWit" [Qast.Loc; mt; wcl] ]
    | [ "sig"; sg = SV LIST0 [ s = sig_item; ";" -> s ]; "end" ->
          Qast.Node "MtSig" [Qast.Loc; sg] ]
    | [ m1 = SELF; m2 = SELF -> Qast.Node "MtApp" [Qast.Loc; m1; m2] ]
    | [ m1 = SELF; "."; m2 = SELF -> Qast.Node "MtAcc" [Qast.Loc; m1; m2] ]
    | "simple"
      [ i = a_UIDENT2 -> Qast.Node "MtUid" [Qast.Loc; i]
      | i = a_LIDENT2 -> Qast.Node "MtLid" [Qast.Loc; i]
      | "'"; i = ident2 -> Qast.Node "MtQuo" [Qast.Loc; i]
      | "("; mt = SELF; ")" -> mt ] ]
  ;
  sig_item:
    [ "top"
      [ "declare"; st = SV LIST0 [ s = sig_item; ";" -> s ]; "end" ->
          Qast.Node "SgDcl" [Qast.Loc; st]
      | "exception"; ctl = constructor_declaration ->
          let (_, c, tl) =
            match ctl with
            [ Qast.Tuple [xx1; xx2; xx3] -> (xx1, xx2, xx3)
            | _ -> match () with [] ]
          in
          Qast.Node "SgExc" [Qast.Loc; c; tl]
      | "external"; i = a_LIDENT2; ":"; t = ctyp; "=";
        pd = SV LIST1 a_STRING ->
          Qast.Node "SgExt" [Qast.Loc; i; t; pd]
      | "include"; mt = module_type -> Qast.Node "SgInc" [Qast.Loc; mt]
      | "module"; rf = SV FLAG "rec";
        l = SV LIST1 mod_decl_binding SEP "and" ->
          Qast.Node "SgMod" [Qast.Loc; rf; l]
      | "module"; "type"; i = a_UIDENT2; "="; mt = module_type ->
          Qast.Node "SgMty" [Qast.Loc; i; mt]
      | "open"; i = mod_ident2 -> Qast.Node "SgOpn" [Qast.Loc; i]
      | "type"; tdl = SV LIST1 type_declaration SEP "and" ->
          Qast.Node "SgTyp" [Qast.Loc; tdl]
      | "value"; i = a_LIDENT2; ":"; t = ctyp ->
          Qast.Node "SgVal" [Qast.Loc; i; t] ] ]
  ;
  mod_decl_binding:
    [ [ i = a_UIDENT; mt = module_declaration -> Qast.Tuple [i; mt] ] ]
  ;
  module_declaration:
    [ RIGHTA
      [ ":"; mt = module_type -> mt
      | "("; i = a_UIDENT2; ":"; t = module_type; ")"; mt = SELF ->
          Qast.Node "MtFun" [Qast.Loc; i; t; mt] ] ]
  ;
  with_constr:
    [ [ "type"; i = mod_ident2; tpl = SV LIST0 type_parameter; "=";
        pf = SV FLAG "private"; t = ctyp ->
          Qast.Node "WcTyp" [Qast.Loc; i; tpl; pf; t]
      | "module"; i = mod_ident2; "="; me = module_expr ->
          Qast.Node "WcMod" [Qast.Loc; i; me] ] ]
  ;
  expr:
    [ "top" RIGHTA
      [ "let"; r = SV FLAG "rec"; l = SV LIST1 let_binding SEP "and"; "in";
        x = SELF ->
          Qast.Node "ExLet" [Qast.Loc; r; l; x]
      | "let"; "module"; m = a_UIDENT2; mb = mod_fun_binding; "in";
        e = SELF ->
          Qast.Node "ExLmd" [Qast.Loc; m; mb; e]
      | "fun"; "["; l = SV LIST0 match_case SEP "|"; "]" ->
          Qast.Node "ExFun" [Qast.Loc; l]
      | "fun"; p = ipatt; e = fun_def ->
          Qast.Node "ExFun"
            [Qast.Loc;
             Qast.VaVal
               (Qast.List [Qast.Tuple [p; Qast.VaVal (Qast.Option None); e]])]
      | "match"; e = SELF; "with"; "["; l = SV LIST0 match_case SEP "|";
        "]" ->
          Qast.Node "ExMat" [Qast.Loc; e; l]
      | "match"; e = SELF; "with"; p1 = ipatt; "->"; e1 = SELF ->
          Qast.Node "ExMat"
            [Qast.Loc; e;
             Qast.VaVal
               (Qast.List
                  [Qast.Tuple [p1; Qast.VaVal (Qast.Option None); e1]])]
      | "try"; e = SELF; "with"; "["; l = SV LIST0 match_case SEP "|"; "]" ->
          Qast.Node "ExTry" [Qast.Loc; e; l]
      | "try"; e = SELF; "with"; p1 = ipatt; "->"; e1 = SELF ->
          Qast.Node "ExTry"
            [Qast.Loc; e;
             Qast.VaVal
               (Qast.List
                  [Qast.Tuple [p1; Qast.VaVal (Qast.Option None); e1]])]
      | "if"; e1 = SELF; "then"; e2 = SELF; "else"; e3 = SELF ->
          Qast.Node "ExIfe" [Qast.Loc; e1; e2; e3]
      | "do"; "{"; seq = sequence2; "}" -> mksequence2 Qast.Loc seq
      | "for"; i = a_LIDENT2; "="; e1 = SELF; df = direction_flag2; e2 = SELF;
        "do"; "{"; seq = sequence2; "}" ->
          Qast.Node "ExFor" [Qast.Loc; i; e1; e2; df; seq]
      | "while"; e = SELF; "do"; "{"; seq = sequence2; "}" ->
          Qast.Node "ExWhi" [Qast.Loc; e; seq] ]
    | "where"
      [ e = SELF; "where"; rf = SV FLAG "rec"; lb = let_binding ->
          Qast.Node "ExLet" [Qast.Loc; rf; Qast.VaVal (Qast.List [lb]); e] ]
    | ":=" NONA
      [ e1 = SELF; ":="; e2 = SELF; dummy ->
          Qast.Node "ExAss" [Qast.Loc; e1; e2] ]
    | "||" RIGHTA
      [ e1 = SELF; "||"; e2 = SELF ->
          Qast.Node "ExApp"
            [Qast.Loc;
             Qast.Node "ExApp"
               [Qast.Loc;
                Qast.Node "ExLid" [Qast.Loc; Qast.VaVal (Qast.Str "||")]; e1];
             e2] ]
    | "&&" RIGHTA
      [ e1 = SELF; "&&"; e2 = SELF ->
          Qast.Node "ExApp"
            [Qast.Loc;
             Qast.Node "ExApp"
               [Qast.Loc;
                Qast.Node "ExLid" [Qast.Loc; Qast.VaVal (Qast.Str "&&")]; e1];
             e2] ]
    | "<" LEFTA
      [ e1 = SELF; "<"; e2 = SELF ->
          Qast.Node "ExApp"
            [Qast.Loc;
             Qast.Node "ExApp"
               [Qast.Loc;
                Qast.Node "ExLid" [Qast.Loc; Qast.VaVal (Qast.Str "<")]; e1];
             e2]
      | e1 = SELF; ">"; e2 = SELF ->
          Qast.Node "ExApp"
            [Qast.Loc;
             Qast.Node "ExApp"
               [Qast.Loc;
                Qast.Node "ExLid" [Qast.Loc; Qast.VaVal (Qast.Str ">")]; e1];
             e2]
      | e1 = SELF; "<="; e2 = SELF ->
          Qast.Node "ExApp"
            [Qast.Loc;
             Qast.Node "ExApp"
               [Qast.Loc;
                Qast.Node "ExLid" [Qast.Loc; Qast.VaVal (Qast.Str "<=")]; e1];
             e2]
      | e1 = SELF; ">="; e2 = SELF ->
          Qast.Node "ExApp"
            [Qast.Loc;
             Qast.Node "ExApp"
               [Qast.Loc;
                Qast.Node "ExLid" [Qast.Loc; Qast.VaVal (Qast.Str ">=")]; e1];
             e2]
      | e1 = SELF; "="; e2 = SELF ->
          Qast.Node "ExApp"
            [Qast.Loc;
             Qast.Node "ExApp"
               [Qast.Loc;
                Qast.Node "ExLid" [Qast.Loc; Qast.VaVal (Qast.Str "=")]; e1];
             e2]
      | e1 = SELF; "<>"; e2 = SELF ->
          Qast.Node "ExApp"
            [Qast.Loc;
             Qast.Node "ExApp"
               [Qast.Loc;
                Qast.Node "ExLid" [Qast.Loc; Qast.VaVal (Qast.Str "<>")]; e1];
             e2]
      | e1 = SELF; "=="; e2 = SELF ->
          Qast.Node "ExApp"
            [Qast.Loc;
             Qast.Node "ExApp"
               [Qast.Loc;
                Qast.Node "ExLid" [Qast.Loc; Qast.VaVal (Qast.Str "==")]; e1];
             e2]
      | e1 = SELF; "!="; e2 = SELF ->
          Qast.Node "ExApp"
            [Qast.Loc;
             Qast.Node "ExApp"
               [Qast.Loc;
                Qast.Node "ExLid" [Qast.Loc; Qast.VaVal (Qast.Str "!=")]; e1];
             e2] ]
    | "^" RIGHTA
      [ e1 = SELF; "^"; e2 = SELF ->
          Qast.Node "ExApp"
            [Qast.Loc;
             Qast.Node "ExApp"
               [Qast.Loc;
                Qast.Node "ExLid" [Qast.Loc; Qast.VaVal (Qast.Str "^")]; e1];
             e2]
      | e1 = SELF; "@"; e2 = SELF ->
          Qast.Node "ExApp"
            [Qast.Loc;
             Qast.Node "ExApp"
               [Qast.Loc;
                Qast.Node "ExLid" [Qast.Loc; Qast.VaVal (Qast.Str "@")]; e1];
             e2] ]
    | "+" LEFTA
      [ e1 = SELF; "+"; e2 = SELF ->
          Qast.Node "ExApp"
            [Qast.Loc;
             Qast.Node "ExApp"
               [Qast.Loc;
                Qast.Node "ExLid" [Qast.Loc; Qast.VaVal (Qast.Str "+")]; e1];
             e2]
      | e1 = SELF; "-"; e2 = SELF ->
          Qast.Node "ExApp"
            [Qast.Loc;
             Qast.Node "ExApp"
               [Qast.Loc;
                Qast.Node "ExLid" [Qast.Loc; Qast.VaVal (Qast.Str "-")]; e1];
             e2]
      | e1 = SELF; "+."; e2 = SELF ->
          Qast.Node "ExApp"
            [Qast.Loc;
             Qast.Node "ExApp"
               [Qast.Loc;
                Qast.Node "ExLid" [Qast.Loc; Qast.VaVal (Qast.Str "+.")]; e1];
             e2]
      | e1 = SELF; "-."; e2 = SELF ->
          Qast.Node "ExApp"
            [Qast.Loc;
             Qast.Node "ExApp"
               [Qast.Loc;
                Qast.Node "ExLid" [Qast.Loc; Qast.VaVal (Qast.Str "-.")]; e1];
             e2] ]
    | "*" LEFTA
      [ e1 = SELF; "*"; e2 = SELF ->
          Qast.Node "ExApp"
            [Qast.Loc;
             Qast.Node "ExApp"
               [Qast.Loc;
                Qast.Node "ExLid" [Qast.Loc; Qast.VaVal (Qast.Str "*")]; e1];
             e2]
      | e1 = SELF; "/"; e2 = SELF ->
          Qast.Node "ExApp"
            [Qast.Loc;
             Qast.Node "ExApp"
               [Qast.Loc;
                Qast.Node "ExLid" [Qast.Loc; Qast.VaVal (Qast.Str "/")]; e1];
             e2]
      | e1 = SELF; "*."; e2 = SELF ->
          Qast.Node "ExApp"
            [Qast.Loc;
             Qast.Node "ExApp"
               [Qast.Loc;
                Qast.Node "ExLid" [Qast.Loc; Qast.VaVal (Qast.Str "*.")]; e1];
             e2]
      | e1 = SELF; "/."; e2 = SELF ->
          Qast.Node "ExApp"
            [Qast.Loc;
             Qast.Node "ExApp"
               [Qast.Loc;
                Qast.Node "ExLid" [Qast.Loc; Qast.VaVal (Qast.Str "/.")]; e1];
             e2]
      | e1 = SELF; "land"; e2 = SELF ->
          Qast.Node "ExApp"
            [Qast.Loc;
             Qast.Node "ExApp"
               [Qast.Loc;
                Qast.Node "ExLid" [Qast.Loc; Qast.VaVal (Qast.Str "land")];
                e1];
             e2]
      | e1 = SELF; "lor"; e2 = SELF ->
          Qast.Node "ExApp"
            [Qast.Loc;
             Qast.Node "ExApp"
               [Qast.Loc;
                Qast.Node "ExLid" [Qast.Loc; Qast.VaVal (Qast.Str "lor")];
                e1];
             e2]
      | e1 = SELF; "lxor"; e2 = SELF ->
          Qast.Node "ExApp"
            [Qast.Loc;
             Qast.Node "ExApp"
               [Qast.Loc;
                Qast.Node "ExLid" [Qast.Loc; Qast.VaVal (Qast.Str "lxor")];
                e1];
             e2]
      | e1 = SELF; "mod"; e2 = SELF ->
          Qast.Node "ExApp"
            [Qast.Loc;
             Qast.Node "ExApp"
               [Qast.Loc;
                Qast.Node "ExLid" [Qast.Loc; Qast.VaVal (Qast.Str "mod")];
                e1];
             e2] ]
    | "**" RIGHTA
      [ e1 = SELF; "**"; e2 = SELF ->
          Qast.Node "ExApp"
            [Qast.Loc;
             Qast.Node "ExApp"
               [Qast.Loc;
                Qast.Node "ExLid" [Qast.Loc; Qast.VaVal (Qast.Str "**")]; e1];
             e2]
      | e1 = SELF; "asr"; e2 = SELF ->
          Qast.Node "ExApp"
            [Qast.Loc;
             Qast.Node "ExApp"
               [Qast.Loc;
                Qast.Node "ExLid" [Qast.Loc; Qast.VaVal (Qast.Str "asr")];
                e1];
             e2]
      | e1 = SELF; "lsl"; e2 = SELF ->
          Qast.Node "ExApp"
            [Qast.Loc;
             Qast.Node "ExApp"
               [Qast.Loc;
                Qast.Node "ExLid" [Qast.Loc; Qast.VaVal (Qast.Str "lsl")];
                e1];
             e2]
      | e1 = SELF; "lsr"; e2 = SELF ->
          Qast.Node "ExApp"
            [Qast.Loc;
             Qast.Node "ExApp"
               [Qast.Loc;
                Qast.Node "ExLid" [Qast.Loc; Qast.VaVal (Qast.Str "lsr")];
                e1];
             e2] ]
    | "unary minus" NONA
      [ "-"; e = SELF -> mkumin Qast.Loc (Qast.Str "-") e
      | "-."; e = SELF -> mkumin Qast.Loc (Qast.Str "-.") e ]
    | "apply" LEFTA
      [ e1 = SELF; e2 = SELF -> Qast.Node "ExApp" [Qast.Loc; e1; e2]
      | "assert"; e = SELF -> Qast.Node "ExAsr" [Qast.Loc; e]
      | "lazy"; e = SELF -> Qast.Node "ExLaz" [Qast.Loc; e] ]
    | "." LEFTA
      [ e1 = SELF; "."; "("; e2 = SELF; ")" ->
          Qast.Node "ExAre" [Qast.Loc; e1; e2]
      | e1 = SELF; "."; "["; e2 = SELF; "]" ->
          Qast.Node "ExSte" [Qast.Loc; e1; e2]
      | e = SELF; "."; "{"; el = SV LIST1 expr SEP ","; "}" ->
          Qast.Node "ExBae" [Qast.Loc; e; el]
      | e1 = SELF; "."; e2 = SELF -> Qast.Node "ExAcc" [Qast.Loc; e1; e2] ]
    | "~-" NONA
      [ "~-"; e = SELF ->
          Qast.Node "ExApp"
            [Qast.Loc;
             Qast.Node "ExLid" [Qast.Loc; Qast.VaVal (Qast.Str "~-")]; e]
      | "~-."; e = SELF ->
          Qast.Node "ExApp"
            [Qast.Loc;
             Qast.Node "ExLid" [Qast.Loc; Qast.VaVal (Qast.Str "~-.")]; e] ]
    | "simple"
      [ s = a_INT2 -> Qast.Node "ExInt" [Qast.Loc; s; Qast.Str ""]
      | s = a_INT_l2 -> Qast.Node "ExInt" [Qast.Loc; s; Qast.Str "l"]
      | s = a_INT_L2 -> Qast.Node "ExInt" [Qast.Loc; s; Qast.Str "L"]
      | s = a_INT_n2 -> Qast.Node "ExInt" [Qast.Loc; s; Qast.Str "n"]
      | s = a_FLOAT2 -> Qast.Node "ExFlo" [Qast.Loc; s]
      | s = a_STRING2 -> Qast.Node "ExStr" [Qast.Loc; s]
      | s = a_CHAR2 -> Qast.Node "ExChr" [Qast.Loc; s]
      | i = a_LIDENT2 -> Qast.Node "ExLid" [Qast.Loc; i]
      | i = a_UIDENT2 -> Qast.Node "ExUid" [Qast.Loc; i]
      | "["; "]" -> Qast.Node "ExUid" [Qast.Loc; Qast.VaVal (Qast.Str "[]")]
      | "["; el = SLIST1 expr SEP ";"; last = cons_expr_opt; "]" ->
          mklistexp Qast.Loc last el
      | "[|"; el = SV LIST0 expr SEP ";"; "|]" ->
          Qast.Node "ExArr" [Qast.Loc; el]
      | "{"; lel = SV LIST1 label_expr SEP ";"; "}" ->
          Qast.Node "ExRec" [Qast.Loc; lel; Qast.Option None]
      | "{"; "("; e = SELF; ")"; "with"; lel = SV LIST1 label_expr SEP ";";
        "}" ->
          Qast.Node "ExRec" [Qast.Loc; lel; Qast.Option (Some e)]
      | "("; ")" -> Qast.Node "ExUid" [Qast.Loc; Qast.VaVal (Qast.Str "()")]
      | "("; e = SELF; ":"; t = ctyp; ")" ->
          Qast.Node "ExTyc" [Qast.Loc; e; t]
      | "("; e = SELF; ","; el = SLIST1 expr SEP ","; ")" ->
          Qast.Node "ExTup" [Qast.Loc; Qast.VaVal (Qast.Cons e el)]
      | "("; e = SELF; ")" -> e
      | "("; el = SV LIST1 expr SEP ","; ")" ->
          Qast.Node "ExTup" [Qast.Loc; el] ] ]
  ;
  cons_expr_opt:
    [ [ "::"; e = expr -> Qast.Option (Some e)
      | -> Qast.Option None ] ]
  ;
  dummy:
    [ [ -> () ] ]
  ;
  sequence2:
    [ [ seq = sequence -> Qast.VaVal seq
      | seq = SV LIST1 expr SEP ";" -> seq ] ]
  ;
  sequence:
    [ [ "let"; rf = SV FLAG "rec"; l = SV LIST1 let_binding SEP "and"; "in";
        el = SELF ->
          Qast.List
            [Qast.Node "ExLet" [Qast.Loc; rf; l; mksequence Qast.Loc el]]
      | e = expr; ";"; el = SELF -> Qast.Cons e el
      | e = expr; ";" -> Qast.List [e]
      | e = expr -> Qast.List [e] ] ]
  ;
  let_binding:
    [ [ p = ipatt; e = fun_binding -> Qast.Tuple [p; e] ] ]
  ;
  fun_binding:
    [ RIGHTA
      [ p = ipatt; e = SELF ->
          Qast.Node "ExFun"
            [Qast.Loc;
             Qast.VaVal
               (Qast.List [Qast.Tuple [p; Qast.VaVal (Qast.Option None); e]])]
      | "="; e = expr -> e
      | ":"; t = ctyp; "="; e = expr -> Qast.Node "ExTyc" [Qast.Loc; e; t] ] ]
  ;
  match_case:
    [ [ p = patt; aso = as_patt_opt; w = SV OPT when_expr; "->"; e = expr ->
          mkmatchcase Qast.Loc p aso w e ] ]
  ;
  as_patt_opt:
    [ [ "as"; p = patt -> Qast.Option (Some p)
      | -> Qast.Option None ] ]
  ;
  when_expr:
    [ [ "when"; e = expr -> e ] ]
  ;
  label_expr:
    [ [ i = patt_label_ident; e = fun_binding -> Qast.Tuple [i; e] ] ]
  ;
  fun_def:
    [ RIGHTA
      [ p = ipatt; e = SELF ->
          Qast.Node "ExFun"
            [Qast.Loc;
             Qast.VaVal
               (Qast.List [Qast.Tuple [p; Qast.VaVal (Qast.Option None); e]])]
      | "->"; e = expr -> e ] ]
  ;
  patt:
    [ LEFTA
      [ p1 = SELF; "|"; p2 = SELF -> Qast.Node "PaOrp" [Qast.Loc; p1; p2] ]
    | NONA
      [ p1 = SELF; ".."; p2 = SELF -> Qast.Node "PaRng" [Qast.Loc; p1; p2] ]
    | LEFTA
      [ p1 = SELF; p2 = SELF -> Qast.Node "PaApp" [Qast.Loc; p1; p2] ]
    | LEFTA
      [ p1 = SELF; "."; p2 = SELF -> Qast.Node "PaAcc" [Qast.Loc; p1; p2] ]
    | "simple"
      [ s = a_LIDENT2 -> Qast.Node "PaLid" [Qast.Loc; s]
      | s = a_UIDENT2 -> Qast.Node "PaUid" [Qast.Loc; s]
      | s = a_INT2 -> Qast.Node "PaInt" [Qast.Loc; s; Qast.Str ""]
      | s = a_INT_l2 -> Qast.Node "PaInt" [Qast.Loc; s; Qast.Str "l"]
      | s = a_INT_L2 -> Qast.Node "PaInt" [Qast.Loc; s; Qast.Str "L"]
      | s = a_INT_n2 -> Qast.Node "PaInt" [Qast.Loc; s; Qast.Str "n"]
      | s = a_FLOAT2 -> Qast.Node "PaFlo" [Qast.Loc; s]
      | s = a_STRING2 -> Qast.Node "PaStr" [Qast.Loc; s]
      | s = a_CHAR2 -> Qast.Node "PaChr" [Qast.Loc; s]
      | "-"; s = a_INT -> mkuminpat Qast.Loc (Qast.Str "-") (Qast.Bool True) s
      | "-"; s = a_FLOAT ->
          mkuminpat Qast.Loc (Qast.Str "-") (Qast.Bool False) s
      | "["; "]" -> Qast.Node "PaUid" [Qast.Loc; Qast.VaVal (Qast.Str "[]")]
      | "["; pl = SLIST1 patt SEP ";"; last = cons_patt_opt; "]" ->
          mklistpat Qast.Loc last pl
      | "[|"; pl = SV LIST0 patt SEP ";"; "|]" ->
          Qast.Node "PaArr" [Qast.Loc; pl]
      | "{"; lpl = SV LIST1 label_patt SEP ";"; "}" ->
          Qast.Node "PaRec" [Qast.Loc; lpl]
      | "("; p = paren_patt; ")" -> p
      | "_" -> Qast.Node "PaAny" [Qast.Loc] ] ]
  ;
  paren_patt:
    [ [ p = patt; ":"; t = ctyp -> Qast.Node "PaTyc" [Qast.Loc; p; t]
      | p = patt; "as"; p2 = patt -> Qast.Node "PaAli" [Qast.Loc; p; p2]
      | p = patt; ","; pl = SLIST1 patt SEP "," ->
          Qast.Node "PaTup" [Qast.Loc; Qast.VaVal (Qast.Cons p pl)]
      | p = patt -> p
      | pl = SV LIST1 patt SEP "," -> Qast.Node "PaTup" [Qast.Loc; pl]
      | -> Qast.Node "PaUid" [Qast.Loc; Qast.VaVal (Qast.Str "()")] ] ]
  ;
  cons_patt_opt:
    [ [ "::"; p = patt -> Qast.Option (Some p)
      | -> Qast.Option None ] ]
  ;
  label_patt:
    [ [ i = patt_label_ident; "="; p = patt -> Qast.Tuple [i; p] ] ]
  ;
  patt_label_ident:
    [ LEFTA
      [ p1 = SELF; "."; p2 = SELF -> Qast.Node "PaAcc" [Qast.Loc; p1; p2] ]
    | "simple" RIGHTA
      [ i = a_UIDENT2 -> Qast.Node "PaUid" [Qast.Loc; i]
      | i = a_LIDENT2 -> Qast.Node "PaLid" [Qast.Loc; i] ] ]
  ;
  ipatt:
    [ [ "{"; lpl = SV LIST1 label_ipatt SEP ";"; "}" ->
          Qast.Node "PaRec" [Qast.Loc; lpl]
      | "("; p = paren_ipatt; ")" -> p
      | s = a_LIDENT2 -> Qast.Node "PaLid" [Qast.Loc; s]
      | "_" -> Qast.Node "PaAny" [Qast.Loc] ] ]
  ;
  paren_ipatt:
    [ [ p = ipatt; ":"; t = ctyp -> Qast.Node "PaTyc" [Qast.Loc; p; t]
      | p = ipatt; "as"; p2 = ipatt -> Qast.Node "PaAli" [Qast.Loc; p; p2]
      | p = ipatt; ","; pl = SLIST1 ipatt SEP "," ->
          Qast.Node "PaTup" [Qast.Loc; Qast.VaVal (Qast.Cons p pl)]
      | p = ipatt -> p
      | pl = SV LIST1 ipatt SEP "," -> Qast.Node "PaTup" [Qast.Loc; pl]
      | -> Qast.Node "PaUid" [Qast.Loc; Qast.VaVal (Qast.Str "()")] ] ]
  ;
  label_ipatt:
    [ [ i = patt_label_ident; "="; p = ipatt -> Qast.Tuple [i; p] ] ]
  ;
  type_declaration:
    [ [ n = type_patt; tpl = SV LIST0 type_parameter; "=";
        pf = SV FLAG "private"; tk = ctyp; cl = SV LIST0 constrain ->
          Qast.Record
            [("tdNam", n); ("tdPrm", tpl); ("tdPrv", pf); ("tdDef", tk);
             ("tdCon", cl)] ] ]
  ;
  type_patt:
    [ [ n = a_LIDENT2 -> Qast.Tuple [Qast.Loc; n] ] ]
  ;
  constrain:
    [ [ "constraint"; t1 = ctyp; "="; t2 = ctyp -> Qast.Tuple [t1; t2] ] ]
  ;
  type_parameter:
    [ [ i = typevar2 ->
          Qast.Tuple [i; Qast.Tuple [Qast.Bool False; Qast.Bool False]]
      | "+"; "'"; i = ident2 ->
          Qast.Tuple [i; Qast.Tuple [Qast.Bool True; Qast.Bool False]]
      | "-"; "'"; i = ident2 ->
          Qast.Tuple [i; Qast.Tuple [Qast.Bool False; Qast.Bool True]] ] ]
  ;
  ctyp:
    [ LEFTA
      [ t1 = SELF; "=="; t2 = SELF -> Qast.Node "TyMan" [Qast.Loc; t1; t2] ]
    | LEFTA
      [ t1 = SELF; "as"; t2 = SELF -> Qast.Node "TyAli" [Qast.Loc; t1; t2] ]
    | LEFTA
      [ "!"; pl = SV LIST1 typevar; "."; t = SELF ->
          Qast.Node "TyPol" [Qast.Loc; pl; t] ]
    | "arrow" RIGHTA
      [ t1 = SELF; "->"; t2 = SELF -> Qast.Node "TyArr" [Qast.Loc; t1; t2] ]
    | "apply" LEFTA
      [ t1 = SELF; t2 = SELF -> Qast.Node "TyApp" [Qast.Loc; t1; t2] ]
    | LEFTA
      [ t1 = SELF; "."; t2 = SELF -> Qast.Node "TyAcc" [Qast.Loc; t1; t2] ]
    | "simple"
      [ i = typevar2 -> Qast.Node "TyQuo" [Qast.Loc; i]
      | "_" -> Qast.Node "TyAny" [Qast.Loc]
      | i = a_LIDENT2 -> Qast.Node "TyLid" [Qast.Loc; i]
      | i = a_UIDENT2 -> Qast.Node "TyUid" [Qast.Loc; i]
      | "("; t = SELF; "*"; tl = SLIST1 ctyp SEP "*"; ")" ->
          Qast.Node "TyTup" [Qast.Loc; Qast.VaVal (Qast.Cons t tl)]
      | "("; t = SELF; ")" -> t
      | "("; tl = SV LIST1 ctyp SEP "*"; ")" ->
          Qast.Node "TyTup" [Qast.Loc; tl]
      | "["; cdl = SV LIST0 constructor_declaration SEP "|"; "]" ->
          Qast.Node "TySum" [Qast.Loc; cdl]
      | "{"; ldl = SV LIST1 label_declaration SEP ";"; "}" ->
          Qast.Node "TyRec" [Qast.Loc; ldl] ] ]
  ;
  constructor_declaration:
    [ [ ci = a_UIDENT2; "of"; cal = SV LIST1 ctyp SEP "and" ->
          Qast.Tuple [Qast.Loc; ci; cal]
      | ci = a_UIDENT2 ->
          Qast.Tuple [Qast.Loc; ci; Qast.VaVal (Qast.List [])] ] ]
  ;
  label_declaration:
    [ [ i = a_LIDENT; ":"; mf = SFLAG "mutable"; t = ctyp ->
          Qast.Tuple [Qast.Loc; i; mf; t] ] ]
  ;
  ident2:
    [ [ s = ANTIQUOT -> Qast.VaVal (Qast.VaAnt "" loc s)
      | s = ANTIQUOT "a" -> Qast.VaAnt "a" loc s
      | i = ident -> Qast.VaVal i ] ]
  ;
  ident:
    [ [ i = a_LIDENT -> i
      | i = a_UIDENT -> i ] ]
  ;
  mod_ident2:
    [ [ sl = mod_ident -> Qast.VaVal sl
      | s = ANTIQUOT "list" -> Qast.VaVal (Qast.VaAnt "list" loc s)
      | s = ANTIQUOT "alist" -> Qast.VaAnt "alist" loc s
      | s = ANTIQUOT -> Qast.VaVal (Qast.VaAnt "" loc s)
      | s = ANTIQUOT "a" -> Qast.VaAnt "a" loc s ] ]
  ;
  mod_ident:
    [ RIGHTA
      [ i = a_UIDENT -> Qast.List [i]
      | i = a_LIDENT -> Qast.List [i]
      | i = a_UIDENT; "."; j = SELF -> Qast.Cons i j ] ]
  ;
  (* Objects and Classes *)
  str_item:
    [ [ "class"; cd = SV LIST1 class_declaration SEP "and" ->
          Qast.Node "StCls" [Qast.Loc; cd]
      | "class"; "type"; ctd = SV LIST1 class_type_declaration SEP "and" ->
          Qast.Node "StClt" [Qast.Loc; ctd] ] ]
  ;
  sig_item:
    [ [ "class"; cd = SV LIST1 class_description SEP "and" ->
          Qast.Node "SgCls" [Qast.Loc; cd]
      | "class"; "type"; ctd = SV LIST1 class_type_declaration SEP "and" ->
          Qast.Node "SgClt" [Qast.Loc; ctd] ] ]
  ;
  class_declaration:
    [ [ vf = SFLAG "virtual"; i = a_LIDENT; ctp = class_type_parameters;
        cfb = class_fun_binding ->
          Qast.Record
            [("ciLoc", Qast.Loc); ("ciVir", vf); ("ciPrm", ctp); ("ciNam", i);
             ("ciExp", cfb)] ] ]
  ;
  class_fun_binding:
    [ [ "="; ce = class_expr -> ce
      | ":"; ct = class_type; "="; ce = class_expr ->
          Qast.Node "CeTyc" [Qast.Loc; ce; ct]
      | p = ipatt; cfb = SELF -> Qast.Node "CeFun" [Qast.Loc; p; cfb] ] ]
  ;
  class_type_parameters:
    [ [ -> Qast.Tuple [Qast.Loc; Qast.List []]
      | "["; tpl = SLIST1 type_parameter SEP ","; "]" ->
          Qast.Tuple [Qast.Loc; tpl] ] ]
  ;
  class_fun_def:
    [ [ p = ipatt; ce = SELF -> Qast.Node "CeFun" [Qast.Loc; p; ce]
      | "->"; ce = class_expr -> ce ] ]
  ;
  class_expr:
    [ "top"
      [ "fun"; p = ipatt; ce = class_fun_def ->
          Qast.Node "CeFun" [Qast.Loc; p; ce]
      | "let"; rf = SV FLAG "rec"; lb = SV LIST1 let_binding SEP "and"; "in";
        ce = SELF ->
          Qast.Node "CeLet" [Qast.Loc; rf; lb; ce] ]
    | "apply" LEFTA
      [ ce = SELF; e = expr LEVEL "label" ->
          Qast.Node "CeApp" [Qast.Loc; ce; e] ]
    | "simple"
      [ ci = class_longident2; "["; ctcl = SV LIST1 ctyp SEP ","; "]" ->
          Qast.Node "CeCon" [Qast.Loc; ci; ctcl]
      | ci = class_longident2 ->
          Qast.Node "CeCon" [Qast.Loc; ci; Qast.VaVal (Qast.List [])]
      | "object"; cspo = SV OPT class_self_patt; cf = class_structure;
        "end" ->
          Qast.Node "CeStr" [Qast.Loc; cspo; cf]
      | "("; ce = SELF; ":"; ct = class_type; ")" ->
          Qast.Node "CeTyc" [Qast.Loc; ce; ct]
      | "("; ce = SELF; ")" -> ce ] ]
  ;
  class_structure:
    [ [ cf = SV LIST0 [ cf = class_str_item; ";" -> cf ] -> cf ] ]
  ;
  class_self_patt:
    [ [ "("; p = patt; ")" -> p
      | "("; p = patt; ":"; t = ctyp; ")" ->
          Qast.Node "PaTyc" [Qast.Loc; p; t] ] ]
  ;
  class_str_item:
    [ [ "declare"; st = SV LIST0 [ s = class_str_item; ";" -> s ]; "end" ->
          Qast.Node "CrDcl" [Qast.Loc; st]
      | "inherit"; ce = class_expr; pb = SV OPT as_lident ->
          Qast.Node "CrInh" [Qast.Loc; ce; pb]
      | "value"; mf = SV FLAG "mutable"; lab = label2; e = cvalue_binding ->
          Qast.Node "CrVal" [Qast.Loc; lab; mf; e]
      | "method"; "virtual"; pf = SV FLAG "private"; l = label2; ":";
        t = ctyp ->
          Qast.Node "CrVir" [Qast.Loc; l; pf; t]
      | "method"; pf = SV FLAG "private"; l = label2; topt = SV OPT polyt;
        e = fun_binding ->
          Qast.Node "CrMth" [Qast.Loc; l; pf; e; topt]
      | "type"; t1 = ctyp; "="; t2 = ctyp ->
          Qast.Node "CrCtr" [Qast.Loc; t1; t2]
      | "initializer"; se = expr -> Qast.Node "CrIni" [Qast.Loc; se] ] ]
  ;
  as_lident:
    [ [ "as"; i = a_LIDENT -> i ] ]
  ;
  polyt:
    [ [ ":"; t = ctyp -> t ] ]
  ;
  cvalue_binding:
    [ [ "="; e = expr -> e
      | ":"; t = ctyp; "="; e = expr -> Qast.Node "ExTyc" [Qast.Loc; e; t]
      | ":"; t = ctyp; ":>"; t2 = ctyp; "="; e = expr ->
          Qast.Node "ExCoe" [Qast.Loc; e; Qast.Option (Some t); t2]
      | ":>"; t = ctyp; "="; e = expr ->
          Qast.Node "ExCoe" [Qast.Loc; e; Qast.Option None; t] ] ]
  ;
  label2:
    [ [ i = a_LIDENT2 -> i ] ]
  ;
  label:
    [ [ i = a_LIDENT -> i ] ]
  ;
  class_type:
    [ [ "["; t = ctyp; "]"; "->"; ct = SELF ->
          Qast.Node "CtFun" [Qast.Loc; t; ct]
      | id = clty_longident2; "["; tl = SV LIST1 ctyp SEP ","; "]" ->
          Qast.Node "CtCon" [Qast.Loc; id; tl]
      | id = clty_longident2 ->
          Qast.Node "CtCon" [Qast.Loc; id; Qast.VaVal (Qast.List [])]
      | "object"; cst = SV OPT class_self_type;
        csf = SV LIST0 [ csf = class_sig_item; ";" -> csf ]; "end" ->
          Qast.Node "CtSig" [Qast.Loc; cst; csf] ] ]
  ;
  class_self_type:
    [ [ "("; t = ctyp; ")" -> t ] ]
  ;
  class_sig_item:
    [ [ "declare"; st = SV LIST0 [ s = class_sig_item; ";" -> s ]; "end" ->
          Qast.Node "CgDcl" [Qast.Loc; st]
      | "inherit"; cs = class_type -> Qast.Node "CgInh" [Qast.Loc; cs]
      | "value"; mf = SV FLAG "mutable"; l = label2; ":"; t = ctyp ->
          Qast.Node "CgVal" [Qast.Loc; l; mf; t]
      | "method"; "virtual"; pf = SV FLAG "private"; l = label2; ":";
        t = ctyp ->
          Qast.Node "CgVir" [Qast.Loc; l; pf; t]
      | "method"; pf = SV FLAG "private"; l = label2; ":"; t = ctyp ->
          Qast.Node "CgMth" [Qast.Loc; l; pf; t]
      | "type"; t1 = ctyp; "="; t2 = ctyp ->
          Qast.Node "CgCtr" [Qast.Loc; t1; t2] ] ]
  ;
  class_description:
    [ [ vf = SFLAG "virtual"; n = a_LIDENT; ctp = class_type_parameters; ":";
        ct = class_type ->
          Qast.Record
            [("ciLoc", Qast.Loc); ("ciVir", vf); ("ciPrm", ctp); ("ciNam", n);
             ("ciExp", ct)] ] ]
  ;
  class_type_declaration:
    [ [ vf = SFLAG "virtual"; n = a_LIDENT; ctp = class_type_parameters; "=";
        cs = class_type ->
          Qast.Record
            [("ciLoc", Qast.Loc); ("ciVir", vf); ("ciPrm", ctp); ("ciNam", n);
             ("ciExp", cs)] ] ]
  ;
  expr: LEVEL "apply"
    [ LEFTA
      [ "new"; i = class_longident2 -> Qast.Node "ExNew" [Qast.Loc; i]
      | "object"; cspo = SV OPT class_self_patt; cf = class_structure;
        "end" ->
          Qast.Node "ExObj" [Qast.Loc; cspo; cf] ] ]
  ;
  expr: LEVEL "."
    [ [ e = SELF; "#"; lab = label2 ->
          Qast.Node "ExSnd" [Qast.Loc; e; lab] ] ]
  ;
  expr: LEVEL "simple"
    [ [ "("; e = SELF; ":"; t = ctyp; ":>"; t2 = ctyp; ")" ->
          Qast.Node "ExCoe" [Qast.Loc; e; Qast.Option (Some t); t2]
      | "("; e = SELF; ":>"; t = ctyp; ")" ->
          Qast.Node "ExCoe" [Qast.Loc; e; Qast.Option None; t]
      | "{<"; fel = SV LIST0 field_expr SEP ";"; ">}" ->
          Qast.Node "ExOvr" [Qast.Loc; fel] ] ]
  ;
  field_expr:
    [ [ l = label; "="; e = expr -> Qast.Tuple [l; e] ] ]
  ;
  ctyp: LEVEL "simple"
    [ [ "#"; id = class_longident2 -> Qast.Node "TyCls" [Qast.Loc; id]
      | "<"; ml = SV LIST0 field SEP ";"; v = SV FLAG ".."; ">" ->
          Qast.Node "TyObj" [Qast.Loc; ml; v] ] ]
  ;
  field:
    [ [ lab = a_LIDENT; ":"; t = ctyp -> Qast.Tuple [lab; t] ] ]
  ;
  typevar2:
    [ [ "'"; i = ident2 -> i ] ]
  ;
  typevar:
    [ [ "'"; i = ident -> i ] ]
  ;
  clty_longident2:
    [ [ v = clty_longident -> Qast.VaVal v
      | s = ANTIQUOT "list" -> Qast.VaVal (Qast.VaAnt "list" loc s)
      | s = ANTIQUOT "alist" -> Qast.VaAnt "alist" loc s ] ]
  ;
  clty_longident:
    [ [ m = a_UIDENT; "."; l = SELF -> Qast.Cons m l
      | i = a_LIDENT -> Qast.List [i] ] ]
  ;
  class_longident2:
    [ [ v = class_longident -> Qast.VaVal v
      | s = ANTIQUOT "list" -> Qast.VaVal (Qast.VaAnt "list" loc s)
      | s = ANTIQUOT "alist" -> Qast.VaAnt "alist" loc s ] ]
  ;
  class_longident:
    [ [ m = a_UIDENT; "."; l = SELF -> Qast.Cons m l
      | i = a_LIDENT -> Qast.List [i] ] ]
  ;
  (* Labels *)
  ctyp: AFTER "arrow"
    [ NONA
      [ i = tildeidentcolon; t = SELF -> Qast.Node "TyLab" [Qast.Loc; i; t]
      | i = questionidentcolon; t = SELF ->
          Qast.Node "TyOlb" [Qast.Loc; i; t] ] ]
  ;
  tildeident:
    [ [ i = a_TILDEIDENT -> Qast.VaVal i
      | a = TILDEANTIQUOT "a" -> Qast.VaAnt "a" loc a
      | a = TILDEANTIQUOT -> Qast.VaVal (Qast.VaAnt "" loc a) ] ]
  ;
  tildeidentcolon:
    [ [ i = a_TILDEIDENTCOLON -> Qast.VaVal i
      | a = TILDEANTIQUOTCOLON "a" -> Qast.VaAnt "a" loc a
      | a = TILDEANTIQUOTCOLON -> Qast.VaVal (Qast.VaAnt "" loc a) ] ]
  ;
  questionident:
    [ [ i = a_QUESTIONIDENT -> Qast.VaVal i
      | a = QUESTIONANTIQUOT "a" -> Qast.VaAnt "a" loc a
      | a = QUESTIONANTIQUOT -> Qast.VaVal (Qast.VaAnt "" loc a) ] ]
  ;
  questionidentcolon:
    [ [ i = a_QUESTIONIDENTCOLON -> Qast.VaVal i
      | a = QUESTIONANTIQUOTCOLON "a" -> Qast.VaAnt "a" loc a
      | a = QUESTIONANTIQUOTCOLON -> Qast.VaVal (Qast.VaAnt "" loc a) ] ]
  ;
  ctyp: LEVEL "simple"
    [ [ "["; "="; rfl = poly_variant_list; "]" ->
          Qast.Node "TyVrn" [Qast.Loc; rfl; Qast.Option None]
      | "["; ">"; rfl = poly_variant_list; "]" ->
          Qast.Node "TyVrn"
            [Qast.Loc; rfl; Qast.Option (Some (Qast.Option None))]
      | "["; "<"; rfl = poly_variant_list; "]" ->
          Qast.Node "TyVrn"
            [Qast.Loc; rfl;
             Qast.Option
               (Some (Qast.Option (Some (Qast.VaVal (Qast.List [])))))]
      | "["; "<"; rfl = poly_variant_list; ">"; ntl = SV LIST1 name_tag;
        "]" ->
          Qast.Node "TyVrn"
            [Qast.Loc; rfl; Qast.Option (Some (Qast.Option (Some ntl)))] ] ]
  ;
  poly_variant_list:
    [ [ rfl = SV LIST0 poly_variant SEP "|" -> rfl ] ]
  ;
  poly_variant:
    [ [ "`"; i = ident2 ->
          Qast.Node "PvTag"
            [i; Qast.VaVal (Qast.Bool True); Qast.VaVal (Qast.List [])]
      | "`"; i = ident2; "of"; ao = SV FLAG "&"; l = SV LIST1 ctyp SEP "&" ->
          Qast.Node "PvTag" [i; ao; l]
      | t = ctyp -> Qast.Node "PvInh" [t] ] ]
  ;
  name_tag:
    [ [ "`"; i = ident -> i ] ]
  ;
  patt: LEVEL "simple"
    [ [ "`"; s = ident2 -> Qast.Node "PaVrn" [Qast.Loc; s]
      | "#"; sl = mod_ident2 -> Qast.Node "PaTyp" [Qast.Loc; sl]
      | i = tildeidentcolon; p = SELF ->
          Qast.Node "PaLab" [Qast.Loc; i; Qast.Option (Some p)]
      | i = tildeident -> Qast.Node "PaLab" [Qast.Loc; i; Qast.Option None]
      | i = questionidentcolon; "("; p = patt_tcon; eo = SV OPT eq_expr;
        ")" ->
          Qast.Node "PaOlb"
            [Qast.Loc; i; Qast.Option (Some (Qast.Tuple [p; eo]))]
      | i = questionident -> Qast.Node "PaOlb" [Qast.Loc; i; Qast.Option None]
      | "?"; "("; p = patt_tcon; eo = SV OPT eq_expr; ")" ->
          Qast.Node "PaOlb"
            [Qast.Loc; Qast.VaVal (Qast.Str "");
             Qast.Option (Some (Qast.Tuple [p; eo]))] ] ]
  ;
  patt_tcon:
    [ [ p = patt; ":"; t = ctyp -> Qast.Node "PaTyc" [Qast.Loc; p; t]
      | p = patt -> p ] ]
  ;
  ipatt:
    [ [ i = tildeidentcolon; p = SELF ->
          Qast.Node "PaLab" [Qast.Loc; i; Qast.Option (Some p)]
      | i = tildeident -> Qast.Node "PaLab" [Qast.Loc; i; Qast.Option None]
      | i = questionidentcolon; "("; p = ipatt_tcon; eo = SV OPT eq_expr;
        ")" ->
          Qast.Node "PaOlb"
            [Qast.Loc; i; Qast.Option (Some (Qast.Tuple [p; eo]))]
      | i = questionident -> Qast.Node "PaOlb" [Qast.Loc; i; Qast.Option None]
      | "?"; "("; p = ipatt_tcon; eo = SV OPT eq_expr; ")" ->
          Qast.Node "PaOlb"
            [Qast.Loc; Qast.VaVal (Qast.Str "");
             Qast.Option (Some (Qast.Tuple [p; eo]))] ] ]
  ;
  ipatt_tcon:
    [ [ p = ipatt; ":"; t = ctyp -> Qast.Node "PaTyc" [Qast.Loc; p; t]
      | p = ipatt -> p ] ]
  ;
  eq_expr:
    [ [ "="; e = expr -> e ] ]
  ;
  expr: AFTER "apply"
    [ "label" NONA
      [ i = tildeidentcolon; e = SELF ->
          Qast.Node "ExLab" [Qast.Loc; i; Qast.Option (Some e)]
      | i = tildeident -> Qast.Node "ExLab" [Qast.Loc; i; Qast.Option None]
      | i = questionidentcolon; e = SELF ->
          Qast.Node "ExOlb" [Qast.Loc; i; Qast.Option (Some e)]
      | i = questionident ->
          Qast.Node "ExOlb" [Qast.Loc; i; Qast.Option None] ] ]
  ;
  expr: LEVEL "simple"
    [ [ "`"; s = ident2 -> Qast.Node "ExVrn" [Qast.Loc; s] ] ]
  ;
  direction_flag2:
    [ [ df = direction_flag -> Qast.VaVal df
      | s = ANTIQUOT "to" -> Qast.VaVal (Qast.VaAnt "to" loc s)
      | s = ANTIQUOT "ato" -> Qast.VaAnt "ato" loc s ] ]
  ;
  direction_flag:
    [ [ "to" -> Qast.Bool True
      | "downto" -> Qast.Bool False ] ]
  ;
  (* Antiquotations for local entries *)
  patt_label_ident: LEVEL "simple"
    [ [ a = ANTIQUOT -> Qast.VaAnt "" loc a ] ]
  ;
  mod_ident:
    [ [ a = ANTIQUOT -> Qast.VaAnt "" loc a ] ]
  ;
  clty_longident:
    [ [ a = a_list -> a ] ]
  ;
  class_longident:
    [ [ a = a_list -> a ] ]
  ;
  direction_flag:
    [ [ a = ANTIQUOT "to" -> Qast.VaAnt "to" loc a ] ]
  ;
  typevar2:
    [ [ "'"; a = ANTIQUOT -> Qast.VaVal (Qast.VaAnt "" loc a)
      | "'"; a = ANTIQUOT "a" -> Qast.VaAnt "a" loc a ] ]
  ;
END;

EXTEND
  GLOBAL: str_item sig_item;
  str_item:
    [ [ "#"; n = a_LIDENT2; dp = dir_param ->
          Qast.Node "StDir" [Qast.Loc; n; dp] ] ]
  ;
  sig_item:
    [ [ "#"; n = a_LIDENT2; dp = dir_param ->
          Qast.Node "SgDir" [Qast.Loc; n; dp] ] ]
  ;
  dir_param:
    [ [ a = ANTIQUOT "opt" -> Qast.VaVal (Qast.VaAnt "opt" loc a)
      | a = ANTIQUOT "aopt" -> Qast.VaAnt "opt" loc a
      | e = expr -> Qast.VaVal (Qast.Option (Some e))
      | -> Qast.VaVal (Qast.Option None) ] ]
  ;
END;

(* Antiquotations *)

EXTEND
  module_expr: LEVEL "simple"
    [ [ a = ANTIQUOT "mexp" -> Qast.VaAnt "mexp" loc a
      | a = ANTIQUOT -> Qast.VaAnt "" loc a ] ]
  ;
  str_item: LEVEL "top"
    [ [ a = ANTIQUOT "stri" -> Qast.VaAnt "stri" loc a
      | a = ANTIQUOT -> Qast.VaAnt "" loc a ] ]
  ;
  module_type: LEVEL "simple"
    [ [ a = ANTIQUOT "mtyp" -> Qast.VaAnt "mtyp" loc a
      | a = ANTIQUOT -> Qast.VaAnt "" loc a ] ]
  ;
  sig_item: LEVEL "top"
    [ [ a = ANTIQUOT "sigi" -> Qast.VaAnt "sigi" loc a
      | a = ANTIQUOT -> Qast.VaAnt "" loc a ] ]
  ;
  expr: LEVEL "simple"
    [ [ a = ANTIQUOT "exp" -> Qast.VaAnt "exp" loc a
      | a = ANTIQUOT "" -> Qast.VaAnt "" loc a
      | a = ANTIQUOT "anti" ->
          Qast.Node "ExAnt" [Qast.Loc; Qast.VaAnt "anti" loc a] ] ]
  ;
  patt: LEVEL "simple"
    [ [ a = ANTIQUOT "pat" -> Qast.VaAnt "pat" loc a
      | a = ANTIQUOT -> Qast.VaAnt "" loc a
      | a = ANTIQUOT "anti" ->
          Qast.Node "PaAnt" [Qast.Loc; Qast.VaAnt "anti" loc a] ] ]
  ;
  ipatt:
    [ [ a = ANTIQUOT "pat" -> Qast.VaAnt "pat" loc a
      | a = ANTIQUOT -> Qast.VaAnt "" loc a
      | a = ANTIQUOT "anti" ->
          Qast.Node "PaAnt" [Qast.Loc; Qast.VaAnt "anti" loc a] ] ]
  ;
  ctyp: LEVEL "simple"
    [ [ a = ANTIQUOT "typ" -> Qast.VaAnt "typ" loc a
      | a = ANTIQUOT -> Qast.VaAnt "" loc a ] ]
  ;
  class_expr: LEVEL "simple"
    [ [ a = ANTIQUOT -> Qast.VaAnt "" loc a ] ]
  ;
  class_str_item:
    [ [ a = ANTIQUOT -> Qast.VaAnt "" loc a ] ]
  ;
  class_sig_item:
    [ [ a = ANTIQUOT -> Qast.VaAnt "" loc a ] ]
  ;
  class_type:
    [ [ a = ANTIQUOT -> Qast.VaAnt "" loc a ] ]
  ;
  a_list:
    [ [ a = ANTIQUOT "list" -> Qast.VaAnt "list" loc a
      | a = ANTIQUOT "alist" -> Qast.VaAnt "list" loc a ] ]
  ;
  a_list2:
    [ [ a = ANTIQUOT "list" -> Qast.VaVal (Qast.VaAnt "list" loc a)
      | a = ANTIQUOT "alist" -> Qast.VaAnt "alist" loc a ] ]
  ;
  a_opt:
    [ [ a = ANTIQUOT "opt" -> Qast.VaAnt "opt" loc a ] ]
  ;
  a_opt2:
    [ [ a = ANTIQUOT "opt" -> Qast.VaVal (Qast.VaAnt "opt" loc a)
      | a = ANTIQUOT "aopt" -> Qast.VaAnt "aopt" loc a ] ]
  ;
  a_flag:
    [ [ a = ANTIQUOT "flag" -> Qast.VaAnt "flag" loc a
      | a = ANTIQUOT "aflag" -> Qast.VaAnt "aflag" loc a ] ]
  ;
  a_flag2:
    [ [ a = ANTIQUOT "flag" -> Qast.VaVal (Qast.VaAnt "flag" loc a)
      | a = ANTIQUOT "aflag" -> Qast.VaAnt "aflag" loc a ] ]
  ;
  (* compatibility; deprecated since version 4.07 *)
  a_opt:
    [ [ a = ANTIQUOT "when" -> Qast.VaAnt "when" loc a ] ]
  ;
  (* compatibility; deprecated since version 4.07 *)
  a_flag:
    [ [ a = ANTIQUOT "opt" -> Qast.VaAnt "opt" loc a ] ]
  ;
  (* compatibility; deprecated since version 4.07 *)
  a_flag2:
    [ [ a = ANTIQUOT "opt" -> Qast.VaVal (Qast.VaAnt "opt" loc a) ] ]
  ;
  a_UIDENT:
    [ [ a = ANTIQUOT "uid" -> Qast.VaAnt "uid" loc a
      | a = ANTIQUOT -> Qast.VaAnt "" loc a
      | i = UIDENT -> Qast.Str i ] ]
  ;
  a_UIDENT2:
    [ [ a = ANTIQUOT "uid" -> Qast.VaVal (Qast.VaAnt "uid" loc a)
      | a = ANTIQUOT "auid" -> Qast.VaAnt "" loc a
      | a = ANTIQUOT -> Qast.VaVal (Qast.VaAnt "" loc a)
      | i = UIDENT -> Qast.VaVal (Qast.Str i) ] ]
  ;
  a_LIDENT:
    [ [ a = ANTIQUOT "lid" -> Qast.VaAnt "lid" loc a
      | a = ANTIQUOT -> Qast.VaAnt "" loc a
      | i = LIDENT -> Qast.Str i ] ]
  ;
  a_LIDENT2:
    [ [ a = ANTIQUOT "lid" -> Qast.VaVal (Qast.VaAnt "lid" loc a)
      | a = ANTIQUOT "alid" -> Qast.VaAnt "" loc a
      | a = ANTIQUOT -> Qast.VaVal (Qast.VaAnt "" loc a)
      | i = LIDENT -> Qast.VaVal (Qast.Str i) ] ]
  ;
  a_INT:
    [ [ a = ANTIQUOT "int" -> Qast.VaAnt "int" loc a
      | a = ANTIQUOT -> Qast.VaAnt "" loc a
      | s = INT -> Qast.Str s ] ]
  ;
  a_INT2:
    [ [ a = ANTIQUOT "int" -> Qast.VaVal (Qast.VaAnt "int" loc a)
      | a = ANTIQUOT "aint" -> Qast.VaAnt "int" loc a
      | a = ANTIQUOT -> Qast.VaVal (Qast.VaAnt "" loc a)
      | s = INT -> Qast.VaVal (Qast.Str s) ] ]
  ;
  a_INT_l:
    [ [ a = ANTIQUOT "int32" -> Qast.VaAnt "int32" loc a
      | a = ANTIQUOT -> Qast.VaAnt "" loc a
      | s = INT_l -> Qast.Str s ] ]
  ;
  a_INT_l2:
    [ [ a = ANTIQUOT "int32" -> Qast.VaVal (Qast.VaAnt "int32" loc a)
      | a = ANTIQUOT "aint32" -> Qast.VaAnt "int32" loc a
      | a = ANTIQUOT -> Qast.VaVal (Qast.VaAnt "" loc a)
      | s = INT_l -> Qast.VaVal (Qast.Str s) ] ]
  ;
  a_INT_L:
    [ [ a = ANTIQUOT "int64" -> Qast.VaAnt "int64" loc a
      | a = ANTIQUOT -> Qast.VaAnt "" loc a
      | s = INT_L -> Qast.Str s ] ]
  ;
  a_INT_L2:
    [ [ a = ANTIQUOT "int64" -> Qast.VaVal (Qast.VaAnt "int64" loc a)
      | a = ANTIQUOT "aint64" -> Qast.VaAnt "int64" loc a
      | a = ANTIQUOT -> Qast.VaVal (Qast.VaAnt "" loc a)
      | s = INT_L -> Qast.VaVal (Qast.Str s) ] ]
  ;
  a_INT_n:
    [ [ a = ANTIQUOT "nativeint" -> Qast.VaAnt "nativeint" loc a
      | a = ANTIQUOT -> Qast.VaAnt "" loc a
      | s = INT_n -> Qast.Str s ] ]
  ;
  a_INT_n2:
    [ [ a = ANTIQUOT "nativeint" -> Qast.VaVal (Qast.VaAnt "nativeint" loc a)
      | a = ANTIQUOT "anativeint" -> Qast.VaAnt "nativeint" loc a
      | a = ANTIQUOT -> Qast.VaVal (Qast.VaAnt "" loc a)
      | s = INT_n -> Qast.VaVal (Qast.Str s) ] ]
  ;
  a_FLOAT:
    [ [ a = ANTIQUOT "flo" -> Qast.VaAnt "flo" loc a
      | a = ANTIQUOT -> Qast.VaAnt "" loc a
      | s = FLOAT -> Qast.Str s ] ]
  ;
  a_FLOAT2:
    [ [ a = ANTIQUOT "flo" -> Qast.VaVal (Qast.VaAnt "flo" loc a)
      | a = ANTIQUOT "aflo" -> Qast.VaAnt "flo" loc a
      | a = ANTIQUOT -> Qast.VaVal (Qast.VaAnt "" loc a)
      | s = FLOAT -> Qast.VaVal (Qast.Str s) ] ]
  ;
  a_STRING:
    [ [ a = ANTIQUOT "str" -> Qast.VaAnt "str" loc a
      | a = ANTIQUOT -> Qast.VaAnt "" loc a
      | s = STRING -> Qast.Str s ] ]
  ;
  a_STRING2:
    [ [ a = ANTIQUOT "str" -> Qast.VaVal (Qast.VaAnt "str" loc a)
      | a = ANTIQUOT "astr" -> Qast.VaAnt "str" loc a
      | a = ANTIQUOT -> Qast.VaVal (Qast.VaAnt "" loc a)
      | s = STRING -> Qast.VaVal (Qast.Str s) ] ]
  ;
  a_CHAR:
    [ [ a = ANTIQUOT "chr" -> Qast.VaAnt "chr" loc a
      | a = ANTIQUOT -> Qast.VaAnt "" loc a
      | s = CHAR -> Qast.Str s ] ]
  ;
  a_CHAR2:
    [ [ a = ANTIQUOT "chr" -> Qast.VaVal (Qast.VaAnt "chr" loc a)
      | a = ANTIQUOT "achr" -> Qast.VaAnt "chr" loc a
      | a = ANTIQUOT -> Qast.VaVal (Qast.VaAnt "" loc a)
      | s = CHAR -> Qast.VaVal (Qast.Str s) ] ]
  ;
  a_TILDEIDENT:
    [ [ s = TILDEIDENT -> Qast.Str s
      | "~"; a = ANTIQUOT -> Qast.VaAnt "" loc a ] ]
  ;
  a_TILDEIDENTCOLON:
    [ [ s = TILDEIDENTCOLON -> Qast.Str s
      | "~"; a = ANTIQUOT; ":" -> Qast.VaAnt "" loc a ] ]
  ;
  a_QUESTIONIDENT:
    [ [ s = QUESTIONIDENT -> Qast.Str s
      | "?"; a = ANTIQUOT -> Qast.VaAnt "" loc a ] ]
  ;
  a_QUESTIONIDENTCOLON:
    [ [ s = QUESTIONIDENTCOLON -> Qast.Str s
      | "?"; a = ANTIQUOT; ":" -> Qast.VaAnt "" loc a ] ]
  ;
END;

value quot_mod = ref [];
value any_quot_mod = ref "MLast";

Pcaml.add_option "-qmod"
  (Arg.String
     (fun s ->
        match try Some (String.index s ',') with [ Not_found -> None ] with
        [ Some i ->
            let q = String.sub s 0 i in
            let m = String.sub s (i + 1) (String.length s - i - 1) in
            quot_mod.val := [(q, m) :: quot_mod.val]
        | None ->
            any_quot_mod.val := s ]))
  "<q>,<m> Set quotation module <m> for quotation <q>."
;

value apply_entry e q =
  let f s = Grammar.Entry.parse e (Stream.of_string s) in
  let m () =
    try List.assoc q quot_mod.val with
    [ Not_found -> any_quot_mod.val ]
  in
  let expr s = Qast.to_expr (m ()) (f s) in
  let patt s = Qast.to_patt (m ()) (f s) in
  Quotation.ExAst (expr, patt)
;

let sig_item_eoi = Grammar.Entry.create gram "signature item" in
let str_item_eoi = Grammar.Entry.create gram "structure item" in
let ctyp_eoi = Grammar.Entry.create gram "type" in
let patt_eoi = Grammar.Entry.create gram "pattern" in
let expr_eoi = Grammar.Entry.create gram "expression" in
let module_type_eoi = Grammar.Entry.create gram "module type" in
let module_expr_eoi = Grammar.Entry.create gram "module expression" in
let class_type_eoi = Grammar.Entry.create gram "class type" in
let class_expr_eoi = Grammar.Entry.create gram "class expression" in
let class_sig_item_eoi = Grammar.Entry.create gram "class signature item" in
let class_str_item_eoi = Grammar.Entry.create gram "class structure item" in
let with_constr_eoi = Grammar.Entry.create gram "with constr" in
let poly_variant_eoi = Grammar.Entry.create gram "polymorphic variant" in
do {
  EXTEND
    sig_item_eoi: [ [ x = sig_item; EOI -> x ] ];
    str_item_eoi: [ [ x = str_item; EOI -> x ] ];
    ctyp_eoi: [ [ x = ctyp; EOI -> x ] ];
    patt_eoi: [ [ x = patt; EOI -> x ] ];
    expr_eoi: [ [ x = expr; EOI -> x ] ];
    module_type_eoi: [ [ x = module_type; EOI -> x ] ];
    module_expr_eoi: [ [ x = module_expr; EOI -> x ] ];
    class_type_eoi: [ [ x = class_type; EOI -> x ] ];
    class_expr_eoi: [ [ x = class_expr; EOI -> x ] ];
    class_sig_item_eoi: [ [ x = class_sig_item; EOI -> x ] ];
    class_str_item_eoi: [ [ x = class_str_item; EOI -> x ] ];
    with_constr_eoi: [ [ x = with_constr; EOI -> x ] ];
    poly_variant_eoi: [ [ x = poly_variant; EOI -> x ] ];
  END;
  List.iter (fun (q, f) -> Quotation.add q (f q))
    [("sig_item", apply_entry sig_item_eoi);
     ("str_item", apply_entry str_item_eoi);
     ("ctyp", apply_entry ctyp_eoi);
     ("patt", apply_entry patt_eoi);
     ("expr", apply_entry expr_eoi);
     ("module_type", apply_entry module_type_eoi);
     ("module_expr", apply_entry module_expr_eoi);
     ("class_type", apply_entry class_type_eoi);
     ("class_expr", apply_entry class_expr_eoi);
     ("class_sig_item", apply_entry class_sig_item_eoi);
     ("class_str_item", apply_entry class_str_item_eoi);
     ("with_constr", apply_entry with_constr_eoi);
     ("poly_variant", apply_entry poly_variant_eoi)];
};

do {
  let expr_eoi = Grammar.Entry.create Pcaml.gram "expr_eoi" in
  EXTEND
    expr_eoi:
      [ [ e = Pcaml.expr; EOI ->
            let loc = Ploc.make_unlined (0, 0) in
            if Pcaml.strict_mode.val then <:expr< Ploc.VaVal $anti:e$ >>
            else <:expr< $anti:e$ >>
        | a = ANTIQUOT_LOC; EOI ->
            let loc = Ploc.make_unlined (0, 0) in
            if Pcaml.strict_mode.val then
              let a =
                let i = String.index a ':' in
                let i = String.index_from a (i + 1) ':' in
                let a = String.sub a (i + 1) (String.length a - i - 1) in
                Grammar.Entry.parse Pcaml.expr_eoi (Stream.of_string a)
              in
              <:expr< Ploc.VaAnt $anti:a$ >>
            else <:expr< failwith "antiquot" >> ] ]
    ;
  END;
  let expr s =
    Ploc.call_with Plexer.force_antiquot_loc True
      (Grammar.Entry.parse expr_eoi) (Stream.of_string s)
  in
  let patt_eoi = Grammar.Entry.create Pcaml.gram "patt_eoi" in
  EXTEND
    patt_eoi:
      [ [ p = Pcaml.patt; EOI ->
            let loc = Ploc.make_unlined (0, 0) in
            if Pcaml.strict_mode.val then <:patt< Ploc.VaVal $anti:p$ >>
            else <:patt< $anti:p$ >>
        | a = ANTIQUOT_LOC; EOI ->
            let loc = Ploc.make_unlined (0, 0) in
            if Pcaml.strict_mode.val then
              let a =
                let i = String.index a ':' in
                let i = String.index_from a (i + 1) ':' in
                let a = String.sub a (i + 1) (String.length a - i - 1) in
                Grammar.Entry.parse Pcaml.patt_eoi (Stream.of_string a)
              in
              <:patt< Ploc.VaAnt $anti:a$ >>
            else <:patt< failwith "antiquot" >> ] ]
    ;
  END;
  let patt s =
    Ploc.call_with Plexer.force_antiquot_loc True
      (Grammar.Entry.parse patt_eoi) (Stream.of_string s)
  in
  Quotation.add "vala" (Quotation.ExAst (expr, patt));
};
