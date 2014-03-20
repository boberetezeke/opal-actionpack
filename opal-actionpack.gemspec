# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'opal/actionpack/version'

Gem::Specification.new do |gem|
  gem.name          = 'opal-actionpack'
  gem.version       = Opal::Actionpack::VERSION
  gem.authors       = ['Steve Tuckner']
  gem.email         = ['stevetuckner@stewdle.com']
  gem.licenses      = ['MIT']
  gem.description   = %q{A small port of the glorious ActionPack for Opal}
  gem.summary       = %q{
                        This implements a subset of the rails/actionpack gem.
                        Currently it does some of the routing functionality,
                        and some rendering functionality. It doesn't do 
                        forms yet.
                      }
  gem.homepage      = 'http://opalrb.org'
  gem.rdoc_options << '--main' << 'README' <<
                      '--line-numbers' <<
                      '--include' << 'opal'

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']

  gem.add_dependency 'opal', ['>= 0.5.0', '< 1.0.0']
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'opal-rspec'
end
