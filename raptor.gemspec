# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'raptor/version'

Gem::Specification.new do |spec|
  spec.name          = 'raptor'
  spec.version       = Raptor::VERSION
  spec.date          = Time.now.strftime( '%Y-%m-%d' )
  spec.authors       = ['Metasploit Hackers']
  spec.email         = ['metasploit-hackers@lists.sourceforge.org']
  spec.description   = %q{Provides a variety of classes useful for security testing and exploit development.}
  spec.summary       = 'Raptor security library.'
  spec.homepage      = 'https://github.com/rapid7/raptor'
  spec.license       = 'MIT'

  spec.files         = Dir.glob('lib/**/**')
  spec.executables   = Dir.glob('bin/*')
  spec.test_files    = Dir.glob('{test,spec,features}/**/**')
  spec.require_paths = ['lib']

  spec.extra_rdoc_files  = %w(README.md LICENSE)

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
end
