#!/bin/zsh
set -euo pipefail

expected="seisei-pcc-ok"

if [[ ! -t 0 || ! -t 1 ]]; then
  print -u2 "Interactive PCC smoke requires a real terminal PTY."
  print -u2 "Run this script directly from Terminal.app, iTerm, or a Codex PTY session."
  exit 64
fi

print "Interactive PCC smoke target: direct fm CLI from a real terminal PTY."
print "This proves machine/account PCC access through fm, not Seisei's Dart subprocess backend."
print

print "> fm available --model pcc"
fm available --model pcc

print
print "> fm respond --model pcc --no-stream 'Reply with exactly: ${expected}'"
response="$(fm respond --model pcc --no-stream "Reply with exactly: ${expected}")"
print "${response}"

if [[ "${response}" != "${expected}" ]]; then
  print -u2 "Expected exactly '${expected}', got '${response}'."
  exit 1
fi

print
print "Interactive PCC smoke passed."
