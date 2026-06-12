#!/usr/bin/env zsh
set -euo pipefail

script_dir="${0:A:h}"
repo_root="${script_dir:h}"

if ! command -v flutter >/dev/null 2>&1; then
  print -u2 "flutter must be on PATH. Try: PATH=/Users/arya/fvm/cache.git/bin:\$PATH $0"
  exit 127
fi

if ! command -v xcrun >/dev/null 2>&1; then
  print -u2 "xcrun is required for the iOS App Intents extension smoke."
  exit 127
fi

flutter_bin="$(command -v flutter)"
flutter_root="${flutter_bin:A:h:h}"
sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
flutter_framework="${flutter_root}/bin/cache/artifacts/engine/ios/extension_safe/Flutter.xcframework/ios-arm64_x86_64-simulator"
source_file="${repo_root}/packages/seisei_flutter_intents/ios/seisei_flutter_intents/Sources/seisei_flutter_intents/SeiseiFlutterIntentsPlugin.swift"

if [[ ! -d "${flutter_framework}" ]]; then
  print -u2 "Missing Flutter extension-safe iOS framework at:"
  print -u2 "  ${flutter_framework}"
  print -u2 "Run: flutter precache --ios"
  exit 1
fi

tmp="$(mktemp -d /tmp/seisei_ios_extension_smoke.XXXXXX)"
trap 'rm -rf "${tmp}"' EXIT

print "iOS App Intents extension smoke"
print "Flutter root: ${flutter_root}"
print "iPhoneSimulator SDK: ${sdk}"
print "Extension-safe Flutter framework: ${flutter_framework}"

print "> emit seisei_flutter_intents Swift module in application-extension mode"
xcrun swiftc \
  -emit-module \
  -parse-as-library \
  -module-name seisei_flutter_intents \
  -target arm64-apple-ios17.0-simulator \
  -sdk "${sdk}" \
  -F "${flutter_framework}" \
  -application-extension \
  -emit-module-path "${tmp}/seisei_flutter_intents.swiftmodule" \
  "${source_file}"

cat >"${tmp}/ExtensionSmoke.swift" <<'SWIFT'
import AppIntents
import ExtensionFoundation
import seisei_flutter_intents

@main
struct SeiseiExtension: AppIntentsExtension {}

struct SeiseiSmokeIntent: AppIntent {
  static let title: LocalizedStringResource = "Seisei Smoke"

  func perform() async throws -> some IntentResult {
    let host = SeiseiFlutterIntentsEngineHost()
    _ = await host.isStarted
    return .result()
  }
}
SWIFT

print "> typecheck App Intents extension source in application-extension mode"
xcrun swiftc \
  -typecheck \
  -parse-as-library \
  -target arm64-apple-ios17.0-simulator \
  -sdk "${sdk}" \
  -F "${flutter_framework}" \
  -I "${tmp}" \
  -application-extension \
  "${tmp}/ExtensionSmoke.swift"

print "iOS App Intents extension smoke passed."
print "This proves the iOS host helper typechecks with Flutter's extension-safe engine; it does not package a host extension target or prove runtime engine startup."
