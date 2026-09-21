#!/usr/bin/env bash
# Type a string on the guest's keyboard through the monitor: run/type.sh 'echo hi' [enter]
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
s="$1"
for ((i=0; i<${#s}; i++)); do
  c="${s:$i:1}"
  case "$c" in
    ' ') k=spc;; '-') k=minus;; '.') k=dot;; '/') k=slash;; ',') k=comma;; '=') k=equal;; ';') k=semicolon;;
    "'") k=apostrophe;; '\') k=backslash;; '[') k=bracket_left;; ']') k=bracket_right;; '`') k=grave_accent;;
    [A-Z]) k="shift-$(tr 'A-Z' 'a-z' <<<"$c")";;
    '!') k=shift-1;; '@') k=shift-2;; '#') k=shift-3;; '$') k=shift-4;; '%') k=shift-5;; '^') k=shift-6;; '&') k=shift-7;; '*') k=shift-8;; '(') k=shift-9;; ')') k=shift-0;;
    '_') k=shift-minus;; '+') k=shift-equal;; ':') k=shift-semicolon;; '"') k=shift-apostrophe;; '<') k=shift-comma;; '>') k=shift-dot;; '?') k=shift-slash;; '|') k=shift-backslash;; '~') k=shift-grave_accent;;
    *) k="$c";;
  esac
  "$ROOT/run/mon.sh" "sendkey $k" >/dev/null; sleep 0.05
done
[ "${2:-}" = enter ] && "$ROOT/run/mon.sh" "sendkey ret" >/dev/null
true
