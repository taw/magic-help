Gem::Specification.new do |s|
  s.name     = "magic-help"
  s.version  = "0.20201211"
  s.author   = "Tomasz Wegrzanowski"
  s.email    = "Tomasz.Wegrzanowski@gmail.com"
  s.homepage = "https://github.com/taw/magic-help"

  s.files      = Dir["lib/**/*.rb"]
  s.test_files = Dir["test/*.rb"]
  s.summary = "Plugin for irb providing more intuitive documentation access."

  s.add_development_dependency "rake"
  s.add_development_dependency "minitest"
end
