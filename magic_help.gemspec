require 'rubygems'

spec = Gem::Specification.new do |s|
    s.name     = 'magic_help'
    s.version  = "0.20120416"
    s.author   = "Tomasz Wegrzanowski"
    s.email    = "Tomasz.Wegrzanowski@gmail.com"
    s.homepage = "https://github.com/taw/magic-help"
    
    s.files      = ["lib/magic_help.rb"]
    s.test_files = ["test/tc_magic_help.rb", "test/mass_test.rb"]
    s.summary = "Plugin for irb providing more intuitive documentation access."
end

if $0==__FILE__
    Gem::manage_gems
    Gem::Builder.new(spec).build
end
