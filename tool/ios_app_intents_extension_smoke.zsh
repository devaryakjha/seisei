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

if ! command -v xcodebuild >/dev/null 2>&1; then
  print -u2 "xcodebuild is required for the packaged iOS App Intents extension smoke."
  exit 127
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  print -u2 "xcodegen is required for the packaged iOS App Intents extension smoke."
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
derived_data="${tmp}/DerivedData"

print "iOS App Intents extension smoke"
print "Flutter root: ${flutter_root}"
print "iPhoneSimulator SDK: ${sdk}"
print "Extension-safe Flutter framework: ${flutter_framework}"
print "Xcode: $(xcodebuild -version | tr '\n' ' ')"

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

print "Swift application-extension typecheck passed."
print "> generate temporary iOS host app and App Intents extension"
mkdir -p "${tmp}/Host" "${tmp}/Extension" "${tmp}/Sources/seisei_flutter_intents"
cp "${source_file}" "${tmp}/Sources/seisei_flutter_intents/SeiseiFlutterIntentsPlugin.swift"

cat >"${tmp}/Host/App.swift" <<'SWIFT'
import SwiftUI

@main
struct SeiseiSmokeHostApp: App {
  var body: some Scene {
    WindowGroup {
      Text("Seisei")
    }
  }
}
SWIFT

cat >"${tmp}/Host/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
</dict>
</plist>
PLIST

cat >"${tmp}/Extension/SeiseiExtension.swift" <<'SWIFT'
import AppIntents
import ExtensionFoundation
import Flutter

@main
struct SeiseiSmokeExtension: AppIntentsExtension {}

struct SeiseiSmokeIntent: AppIntent {
  static let title: LocalizedStringResource = "Seisei Smoke"

  @MainActor
  func perform() async throws -> some IntentResult {
    let host = SeiseiFlutterIntentsEngineHost()
    _ = host.isStarted
    return .result()
  }
}
SWIFT

cat >"${tmp}/Extension/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>EXAppExtensionAttributes</key>
  <dict>
    <key>EXExtensionPointIdentifier</key>
    <string>com.apple.appintents-extension</string>
  </dict>
</dict>
</plist>
PLIST

cat >"${tmp}/project.yml" <<YAML
name: SeiseiExtensionSmoke
options:
  bundleIdPrefix: dev.jha.seisei.extension-smoke
settings:
  base:
    SWIFT_VERSION: 5.9
    IPHONEOS_DEPLOYMENT_TARGET: '17.0'
targets:
  SeiseiSmokeHost:
    type: application
    platform: iOS
    sources: [Host]
    info:
      path: Host/Info.plist
      properties:
        CFBundleDisplayName: SeiseiSmokeHost
        UILaunchScreen: {}
    dependencies:
      - target: SeiseiSmokeExtension
        embed: true
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: dev.jha.seisei.extension-smoke.host
  SeiseiSmokeExtension:
    type: app-extension
    platform: iOS
    sources:
      - Extension
      - Sources/seisei_flutter_intents
    info:
      path: Extension/Info.plist
      properties:
        CFBundleDisplayName: SeiseiSmokeExtension
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: dev.jha.seisei.extension-smoke.extension
        APPLICATION_EXTENSION_API_ONLY: YES
        FRAMEWORK_SEARCH_PATHS: ["${flutter_framework}"]
        LD_RUNPATH_SEARCH_PATHS: ["\$(inherited)", "@executable_path/Frameworks", "@executable_path/../../Frameworks"]
    dependencies:
      - framework: ${flutter_framework}/Flutter.framework
YAML

(
  cd "${tmp}"
  xcodegen generate --quiet
)

build_log="${tmp}/xcodebuild.log"
print "> xcodebuild temporary host with embedded App Intents extension"
if ! xcodebuild \
  -derivedDataPath "${derived_data}" \
  -project "${tmp}/SeiseiExtensionSmoke.xcodeproj" \
  -scheme SeiseiSmokeHost \
  -sdk iphonesimulator \
  -destination "generic/platform=iOS Simulator" \
  CODE_SIGNING_ALLOWED=NO \
  build >"${build_log}" 2>&1; then
  print -u2 "xcodebuild failed. Relevant log lines:"
  grep -E "error:|warning:|BUILD FAILED|ExtractAppIntentsMetadata|Metadata.appintents|Flutter|ValidateEmbeddedBinary" "${build_log}" | tail -120 >&2 || true
  exit 1
fi

extension_bundle="$(find "${derived_data}/Build/Products" -path "*/SeiseiSmokeHost.app/PlugIns/SeiseiSmokeExtension.appex" -type d | head -1)"
if [[ -z "${extension_bundle}" ]]; then
  print -u2 "xcodebuild succeeded but no embedded SeiseiSmokeExtension.appex was found."
  exit 1
fi

metadata_file="${extension_bundle}/Metadata.appintents"
if [[ ! -d "${metadata_file}" ]]; then
  print -u2 "xcodebuild produced ${extension_bundle}, but Metadata.appintents was missing."
  exit 1
fi

grep -E "ExtractAppIntentsMetadata|Metadata.appintents|ValidateEmbeddedBinary|BUILD SUCCEEDED" "${build_log}" | tail -40 || true
print "Packaged extension: ${extension_bundle}"
print "iOS App Intents extension smoke passed."
print "This proves the iOS host helper compiles in application-extension mode, links Flutter's extension-safe iOS engine, and packages an embedded App Intents extension with metadata. It does not launch the extension process or prove runtime Flutter engine startup."
