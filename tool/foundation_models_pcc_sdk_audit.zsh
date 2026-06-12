#!/usr/bin/env zsh
set -euo pipefail

if ! command -v xcrun >/dev/null 2>&1; then
  print -u2 "xcrun is required for the FoundationModels PCC SDK audit."
  exit 127
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  print -u2 "xcodebuild is required for the FoundationModels PCC SDK audit."
  exit 127
fi

if ! command -v rg >/dev/null 2>&1; then
  print -u2 "rg is required for the FoundationModels PCC SDK audit."
  exit 127
fi

sdk="$(xcrun --sdk macosx --show-sdk-path)"
interfaces=(
  "${sdk}"/System/Library/Frameworks/FoundationModels.framework/Versions/A/Modules/FoundationModels.swiftmodule/*.swiftinterface(N)
)

if (( ${#interfaces[@]} == 0 )); then
  print -u2 "No FoundationModels Swift interfaces found in ${sdk}."
  exit 1
fi

tmp="$(mktemp -d /tmp/seisei_foundation_models_pcc_audit.XXXXXX)"
trap 'rm -rf "${tmp}"' EXIT

print "FoundationModels PCC SDK audit"
print "Xcode: $(xcodebuild -version | tr '\n' ' ')"
print "macOS SDK: ${sdk}"
print "Swift interfaces:"
for interface in "${interfaces[@]}"; do
  print "  ${interface}"
done

print
print "> search FoundationModels public Swift interfaces for PCC/cloud model tokens"
if rg -n "PrivateCloud|Private Cloud|\\bPCC\\b|\\bpcc\\b|ComputeLanguageModel|Cloud.*LanguageModel|LanguageModel.*Cloud" "${interfaces[@]}"; then
  print -u2 "Unexpected PCC/cloud model token found in FoundationModels public Swift interfaces."
  exit 1
fi
print "No public PCC/cloud language-model token found."

cat >"${tmp}/SystemProbe.swift" <<'SWIFT'
import FoundationModels

@available(macOS 26.0, *)
func makeSystemSession() {
  _ = LanguageModelSession(model: SystemLanguageModel.default)
}
SWIFT

print
print "> compile positive system-model probe"
xcrun swiftc \
  -typecheck \
  -target arm64e-apple-macos26.0 \
  -sdk "${sdk}" \
  "${tmp}/SystemProbe.swift"
print "SystemLanguageModel probe compiled."

cat >"${tmp}/PrivateCloudProbe.swift" <<'SWIFT'
import FoundationModels

@available(macOS 26.0, *)
func makePccSession() {
  _ = LanguageModelSession(model: PrivateCloudComputeLanguageModel())
}
SWIFT

private_cloud_log="${tmp}/PrivateCloudProbe.log"
print
print "> compile expected-negative PrivateCloudComputeLanguageModel probe"
if xcrun swiftc \
  -typecheck \
  -target arm64e-apple-macos26.0 \
  -sdk "${sdk}" \
  "${tmp}/PrivateCloudProbe.swift" >"${private_cloud_log}" 2>&1; then
  print -u2 "PrivateCloudComputeLanguageModel unexpectedly compiled."
  exit 1
fi
if ! grep -q "cannot find 'PrivateCloudComputeLanguageModel' in scope" "${private_cloud_log}"; then
  print -u2 "Unexpected PrivateCloudComputeLanguageModel compiler output:"
  cat "${private_cloud_log}" >&2
  exit 1
fi
grep "cannot find 'PrivateCloudComputeLanguageModel' in scope" "${private_cloud_log}"

cat >"${tmp}/PccMemberProbe.swift" <<'SWIFT'
import FoundationModels

@available(macOS 26.0, *)
func makePccSession() {
  _ = LanguageModelSession(model: .pcc)
}
SWIFT

pcc_member_log="${tmp}/PccMemberProbe.log"
print
print "> compile expected-negative SystemLanguageModel.pcc probe"
if xcrun swiftc \
  -typecheck \
  -target arm64e-apple-macos26.0 \
  -sdk "${sdk}" \
  "${tmp}/PccMemberProbe.swift" >"${pcc_member_log}" 2>&1; then
  print -u2 "SystemLanguageModel.pcc unexpectedly compiled."
  exit 1
fi
if ! grep -q "type 'SystemLanguageModel' has no member 'pcc'" "${pcc_member_log}"; then
  print -u2 "Unexpected SystemLanguageModel.pcc compiler output:"
  cat "${pcc_member_log}" >&2
  exit 1
fi
grep "type 'SystemLanguageModel' has no member 'pcc'" "${pcc_member_log}"

print
print "FoundationModels PCC SDK audit passed."
print "The local public SDK supports SystemLanguageModel sessions, but no compileable public native PCC model path was found."
