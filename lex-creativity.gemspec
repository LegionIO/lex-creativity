# frozen_string_literal: true

require_relative 'lib/legion/extensions/creativity/version'

Gem::Specification.new do |spec|
  spec.name          = 'lex-creativity'
  spec.version       = Legion::Extensions::Creativity::VERSION
  spec.authors       = ['Matthew Iverson']
  spec.email         = ['matt@legionIO.com']
  spec.summary       = 'Divergent thinking and conceptual blending engine for LegionIO cognitive agents'
  spec.description   = 'Generates novel ideas via divergent, convergent, and combinational creativity modes; ' \
                       'tracks creative potential via EMA; incubates and evaluates ideas using Guilford quality factors'
  spec.homepage      = 'https://github.com/LegionIO/lex-creativity'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.4'

  spec.files = Dir['lib/**/*']
  spec.require_paths = ['lib']

  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.add_development_dependency 'legion-gaia'
end
