Pod::Spec.new do |s|
  s.name             = 'seisei_apple'
  s.version          = '0.3.0-dev.0'
  s.summary          = 'Apple Foundation Models provider and Flutter bridge for Seisei.'
  s.description      = <<-DESC
Apple Foundation Models provider and native Flutter bridge for Seisei.
                       DESC
  s.homepage         = 'https://github.com/devaryakjha/seisei'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Seisei' => 'dev.jha.arya@gmail.com' }
  s.source           = { :path => '.' }
  # The plugin and its core share one module under CocoaPods.
  s.source_files = 'seisei_apple/Sources/**/*.swift'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  # Swift 5 language mode, as in Package.swift: Flutter's FlutterMethodNotImplemented
  # is a mutable global that Swift 6 mode rejects.
  s.swift_version = '5.0'
end
