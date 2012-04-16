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
task :tests_default do
    sh "test/tc_magic_help.rb"
    sh "test/mass_test.rb"
end

desc "Run tests with Ruby 1.9"
task :tests_1_9 do
    ruby_bin = "/usr/bin/ruby1.9"
    sh ruby_bin, "test/tc_magic_help.rb"
    sh ruby_bin, "test/mass_test.rb", "/usr/share/ri/1.9/system"
end

desc "Run tests with Ruby 1.8.4"
task :tests_1_8_4 do
    ruby_bin = "/home/taw/local/ruby-1.8.4/bin/ruby"
    sh ruby_bin, "test/tc_magic_help.rb"
end

desc "Run all tests with Ruby default/1.8.4/1.9"
task :test => [:tests_default, :tests_1_8_4, :tests_1_9]

desc "Clean generated files"
task :clean do
    # Nothing to clean
end
