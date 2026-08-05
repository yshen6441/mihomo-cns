Pod::Spec.new do |s|
  s.name             = 'libclash_vpn_service'
  s.version          = '0.12.15'
  s.summary          = 'VPN service plugin for Clash Mi (reimplemented).'
  s.homepage         = 'https://github.com/clashmi'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Clash Mi' => 'dev@clashmi.app' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
