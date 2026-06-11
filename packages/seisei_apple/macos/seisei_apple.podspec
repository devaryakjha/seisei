Pod::Spec.new do |s|
  s.name             = 'seisei_apple'
  s.version          = '0.1.0-dev.0'
  s.summary          = 'Apple Foundation Models provider and Flutter bridge for Seisei.'
  s.description      = <<-DESC
Apple Foundation Models provider and native Flutter bridge for Seisei.
                       DESC
  s.homepage         = 'https://github.com/devaryakjha/seisei'
  s.author           = { 'Seisei' => 'dev.jha.arya@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'seisei_apple/Sources/seisei_apple/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '6.0'
end
