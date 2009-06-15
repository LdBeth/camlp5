(* camlp5r *)
(* This file has been generated by program: do not edit! *)
(* Copyright (c) INRIA 2007-2008 *)

exception GiveUp;;

let line_length = ref 78;;
let horiz_ctx = ref false;;

let after_print s =
  if !horiz_ctx then
    if String.contains s '\n' || String.length s > !line_length then
      raise GiveUp
    else s
  else s
;;

let sprintf fmt = Printf.kprintf after_print fmt;;

let horiz_vertic horiz vertic =
  try Ploc.call_with horiz_ctx true horiz () with
    GiveUp -> if !horiz_ctx then raise GiveUp else vertic ()
;;

let horizontally () = !horiz_ctx;;
