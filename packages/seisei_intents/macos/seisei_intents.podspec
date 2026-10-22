Pod::Spec.new do |s|
  s.name             = 'seisei_intents'
  s.version          = '0.2.0-dev.0'
  s.summary          = 'Flutter runtime bridge for Seisei app actions and generated App Intents.'
  s.description      = <<-DESC
Flutter runtime bridge and Apple-platform headless engine helpers for Seisei app actions and generated App Intents.
                       DESC
  s.homepage         = 'https://github.com/devaryakjha/seisei'
  s.author           = { 'Seisei' => 'dev.jha.arya@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'seisei_intents/Sources/seisei_intents/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.15'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '6.0'
end
