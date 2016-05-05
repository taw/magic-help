task :default => :package

desc "Build magic_help package"
task :package do
  project = "magic_help"

  # This is pretty ugly, but DRY
  File.read("#{project}.gemspec") =~ /^\s*s.version\s*=\s*"(.*?)"/
  version = $1

  files = FileList["lib/*.rb", "test/*.rb", "Rakefile", "*.gemspec"]
  files = files.map{|fn| "#{project}/#{fn}" }

  sh "gem", "build", "#{project}.gemspec"
  mv FileList["*.gem"].to_a, "../website/packages/"
  Dir.chdir("..") {
    sh "tar", "-z", "-c", "-f", "website/packages/#{project}-#{version}.tar.gz", *files
    sh "zip", "-q", "website/packages/#{project}-#{version}.zip", *files
  }
end

desc "Run tests with default Ruby"
task :test do
  sh "test/tc_magic_help.rb"
  sh "test/mass_test.rb"
end

desc "Clean generated files"
task :clean do
  # Nothing to clean
end
