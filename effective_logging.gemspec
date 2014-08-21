$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "effective_logging/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "effective_logging"
  s.version     = EffectiveLogging::VERSION
  s.email       = ["info@codeandeffect.com"]
  s.authors     = ["Code and Effect"]
  s.homepage    = "https://github.com/code-and-effect/effective_logging"
  s.summary     = "TODO"
  s.description = "TODO"

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.md"]
  s.test_files = Dir["spec/**/*"]

  s.add_dependency "rails"
  s.add_dependency "coffee-rails"
  s.add_dependency "devise"
  s.add_dependency "haml"
  s.add_dependency "migrant"

end
