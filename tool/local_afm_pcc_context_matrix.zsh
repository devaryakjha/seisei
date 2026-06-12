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
print "This script proves four separate things:"
print "1. Direct system-model fm access works."
print "2. Direct PCC fm access works from this terminal context."
print "3. Seisei's current Dart backend can use the system model."
print "4. Seisei's current Dart backend still cannot use PCC in its captured subprocess context."
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
print "> dart run bin/local_afm_smoke.dart --mode pcc"
print "  expected: current Seisei FmCliBackend reports PCC unavailable"
pcc_backend_output="$(
  cd "${root}/packages/seisei_apple"
  dart run bin/local_afm_smoke.dart --mode pcc 2>&1
)" && {
  print -u2 "${pcc_backend_output}"
  print -u2 "Expected Seisei's current PCC backend check to fail in this context."
  exit 1
}

print "${pcc_backend_output}"
if ! print "${pcc_backend_output}" | grep -q "PCC mode is unavailable"; then
  print -u2 "Expected backend output to explain PCC mode is unavailable."
  exit 1
fi

print
print "AFM/PCC context matrix passed."
print "Direct PCC is usable from this terminal; Seisei's current Dart subprocess backend is still PCC-negative."
