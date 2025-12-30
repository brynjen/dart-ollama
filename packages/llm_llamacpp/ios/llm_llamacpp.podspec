Pod::Spec.new do |s|
  s.name             = 'llm_llamacpp'
  s.version          = '0.1.0'
  s.summary          = 'llama.cpp FFI plugin for Flutter'
  s.description      = <<-DESC
llama.cpp backend implementation for LLM interactions. Enables local on-device inference with GGUF models.
                       DESC
  s.homepage         = 'https://github.com/brynjen/dart-ollama'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'brynjen' => 'brynjen@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # Vendored framework containing libllama
  s.vendored_frameworks = 'Frameworks/llama.xcframework'
end

