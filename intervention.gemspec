lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'intervention/version'

Gem::Specification.new do |spec|
  spec.name         = 'intervention'
  spec.summary      = 'Intervention: Super simple proxy'
  spec.description  = 'A simple proxy that can be configured to perform actions upon a request or response'
  spec.homepage     = 'http://benslaughter.github.io/intervention/'
  spec.version      = Intervention::VERSION
  spec.date         = Intervention::DATE
  spec.license      = 'MIT'

  spec.author       = 'Ben Slaughter'
  spec.email        = 'b.p.slaughter@gmail.com'

  spec.files        = ['README.md', 'License.md', 'History.md']
  spec.files        += Dir.glob("lib/**/*.rb")
  spec.files        += Dir.glob("spec/**/*")
  spec.test_files   = Dir.glob("spec/**/*")
  spec.require_path = 'lib'

  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'yard'
  spec.add_development_dependency 'coveralls'
  spec.add_development_dependency 'pry', '~> 0.9.12.2'
  spec.add_development_dependency 'rspec', '~> 2.13.0'
  spec.add_runtime_dependency 'hashie', '~> 2.0.5'
end