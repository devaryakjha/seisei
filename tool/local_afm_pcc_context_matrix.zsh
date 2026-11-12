#!/bin/zsh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
expected_system="seisei-ok"
expected_pcc="seisei-pcc-ok"

if [[ ! -t 0 || ! -t 1 ]]; then
  print -u2 "AFM/PCC context matrix requires a real terminal PTY."
  print -u2 "Run this script directly from Terminal.app, iTerm, or a Codex PTY session."
  exit 64
fi

print "AFM/PCC context matrix"
print
print "This script proves three separate things:"
print "1. Direct system-model fm access works."
print "2. Direct PCC fm access works from this terminal context."
print "3. Seisei's Dart backend can use the system model."
print "Seisei has no PCC mode until its native bridge can reach PCC."
print

print "> fm available --model system"
fm available --model system

print
print "> fm respond --no-stream 'Reply with exactly: ${expected_system}'"
system_response="$(fm respond --no-stream "Reply with exactly: ${expected_system}")"
print "${system_response}"
if [[ "${system_response}" != "${expected_system}" ]]; then
  print -u2 "Expected exactly '${expected_system}', got '${system_response}'."
  exit 1
fi

print
print "> fm available --model pcc"
fm available --model pcc

print
print "> fm respond --model pcc --no-stream 'Reply with exactly: ${expected_pcc}'"
pcc_response="$(fm respond --model pcc --no-stream "Reply with exactly: ${expected_pcc}")"
print "${pcc_response}"
if [[ "${pcc_response}" != "${expected_pcc}" ]]; then
  print -u2 "Expected exactly '${expected_pcc}', got '${pcc_response}'."
  exit 1
fi

print
print "> dart run bin/local_afm_smoke.dart"
(
  cd "${root}/packages/seisei_apple"
  dart run bin/local_afm_smoke.dart
)

print
print "AFM/PCC context matrix passed."
print "Direct PCC is usable from this terminal; Seisei uses the system model only."
