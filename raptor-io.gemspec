# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'raptor-io/version'

Gem::Specification.new do |spec|
  spec.required_ruby_version = '>= 1.9.2'

  spec.name          = 'raptor-io'
  spec.version       = RaptorIO::VERSION
  spec.date          = Time.now.strftime( '%Y-%m-%d' )
  spec.authors       = ['Metasploit Hackers']
  spec.email         = ['metasploit-hackers@lists.sourceforge.org']
  spec.description   = %q{Provides a variety of classes useful for security testing and exploit development.}
  spec.summary       = 'RaptorIO security library.'
  spec.homepage      = 'https://github.com/rapid7/raptor'
  spec.license       = 'BSD'

  spec.files         = Dir.glob('lib/**/**')
  spec.executables   = Dir.glob('bin/*')
  spec.test_files    = Dir.glob('{test,spec,features}/**/**')
  spec.require_paths = ['lib']

  spec.extra_rdoc_files  = %w(README.md LICENSE)

  spec.add_dependency 'rubyntlm'

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'yard'
  spec.add_development_dependency 'simplecov', '0.5.4'

  # Test web-servers
  if RUBY_PLATFORM !~ /java/
    spec.add_development_dependency 'thin'
  end
  spec.add_development_dependency 'sinatra'
  spec.add_development_dependency 'sinatra-contrib'

  # Markdown dependency for YARD.
  if RUBY_PLATFORM =~ /java/
    spec.add_development_dependency 'kramdown'
  else
    spec.add_development_dependency 'redcarpet'
  end

  # Pretty-dumps objects to the screen.
  spec.add_development_dependency 'awesome_print'
end
