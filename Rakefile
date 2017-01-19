task :default => :test

desc "Build magic_help package"
task :package do
  project = "magic_help"

  # This is pretty ugly, but DRY
  File.read("#{project}.gemspec") =~ /^\s*s.version\s*=\s*"(.*?)"/
  version = $1

  files = FileList["lib/*.rb", "test/*.rb", "Rakefile", "*.gemspec"]
  files = files.map{|fn| "#{project}/#{fn}" }
  sh "gem", "build", "#{project}.gemspec"
end

desc "Run tests with default Ruby"
task :test do
  sh "ruby test/tc_magic_help.rb"
  sh "ruby test/mass_test.rb"
end

desc "Clean generated files"
task :clean do
  # Nothing to clean
end
