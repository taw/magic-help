#!/usr/bin/env ruby -Ilib

# This only tests how many items magic/help BREAKS,
# that is - how many would work otherwise.

require 'magic_help'

# Use fake irb_help for testing
$irb_help = nil

class Object
  def irb_help(arg)
    $irb_help = arg
  end
end

# A convenience method
def try_help(*args, &blk)
  $irb_help = nil
  help(*args, &blk)
  rv, $irb_help = $irb_help, nil
  rv
end

# Extract documentation

# FIXME: Hardcoded paths are not cross-platform compatible
if RUBY_VERSION > '1.9'
  default_ri_root_path = "/usr/share/ri/1.9/system"
  default_ri_root_path = "/home/taw/local/ruby1.9.3/share/ri/1.9.1/system/" # OSX ...
else
  default_ri_root_path = "/usr/share/ri/1.8/system"
end
ri_root_path = ARGV.shift || default_ri_root_path

docs = Dir["#{ri_root_path}/**/*"]

docs_class = []
docs_imeth = []
docs_cmeth = []

docs.each{|fn|
  next if File.directory?(fn)
  raise "Weird path: #{fn}" unless fn[0, ri_root_path.size] == ri_root_path
  fn = fn[ri_root_path.size..-1].sub(/^\/*/, "")
  # gsub after split to deal with Fixnum#/ etc.
  path = fn.split(/\//).map{|x| x.gsub(/%(..)/){$1.hex.chr}}
  case path[-1]
  when /\A(.*)-i\.(yaml|ri)\Z/
    docs_imeth << path[0..-2] + [$1]
  when /\A(.*)-c\.(yaml|ri)\Z/
    docs_cmeth << path[0..-2] + [$1]
  when /\Acdesc-(.*)\.(yaml|ri)\Z/
    raise "Malformatted file name: #{fn}" unless $1 == path[-2]
    docs_class << path[0..-2]
  else
    # Ignore
  end
}

# Go over documentation

cl_nc = []
cl_ni = []
cl_fc = []
cl_fi = []

docs_class.each{|class_path|
  class_name = class_path.join("::")
  begin
    cls = class_path.inject(Object){|cls,path_elem| cls.const_get(path_elem)}
  rescue NameError
    rv = try_help class_name
    if rv == class_name
      cl_nc << class_name
    else
      cl_ni << [class_name, rv]
    end
    next
  end
  rv1  = try_help class_name
  rv2 = try_help cls
  if rv1 == class_name && rv2 == class_name
    cl_fc << class_name
  else
    cl_fi << [class_name, rv1, rv2]
  end
}

print <<EOS
Class documentation:
* #{docs_class.size} classes
* #{cl_fc.size} correct
* #{cl_fi.size} incorrect
* #{cl_nc.size} could not be verified (seem ok)
* #{cl_ni.size} could not be verified (seem bad)
EOS
if cl_fi.size != 0
  puts "\nIncorrect:"
  cl_fi.each{|ex,rv1,rv2|
    puts "* #{ex} - #{rv1}/#{rv2}"
  }
end

cm_nc = [] # Class not found
cm_ni = []
cm_fc = []
cm_fi = []

docs_cmeth.each{|path|
  class_path, method_name = path[0..-2], path[-1]
  class_name = class_path.join("::")
  begin
    cls = class_path.inject(Object){|cls,path_elem| cls.const_get(path_elem)}
  rescue NameError
    expected = "#{class_name}::#{method_name}"
    rv = try_help expected
    if rv == expected
      cm_nc << expected
    else
      cm_ni << [expected, rv]
    end
    next
  end
  expected = "#{class_name}::#{method_name}"
  rv1 = try_help "#{class_name}::#{method_name}"
  # cls.send(:method_name) would find help for Object#send ...
  rv2 = eval "try_help { cls.#{method_name}() }"
  if rv1 == expected && rv2 == expected
    cm_fc << expected
  else
    cm_fi << [expected, rv1, rv2]
  end
}

print <<EOS

Class method documentation:
* #{docs_cmeth.size} class methods
* #{cm_fc.size} correct
* #{cm_fi.size} incorrect
* #{cm_nc.size} could not be verified (seem ok)
* #{cm_ni.size} could not be verified (seem bad)
EOS
if cm_fi.size != 0
  puts "\nIncorrect:"
  cm_fi.each{|ex,rv1,rv2|
    puts "* #{ex} - #{rv1}/#{rv2}"
  }
end

# And instance methods

im_nc = [] # Class not found
im_ni = []
im_fc = []
im_fi = []

docs_imeth.each{|path|
  class_path, method_name = path[0..-2], path[-1]
  class_name = class_path.join("::")
  begin
    cls = class_path.inject(Object){|cls,path_elem| cls.const_get(path_elem)}
  rescue NameError
    expected = "#{class_name}.#{method_name}"
    rv = try_help expected
    if rv == expected
      im_nc << expected
    else
      im_ni << [expected, rv]
    end
    next
  end
  expected = "#{class_name}##{method_name}"
  rv1 = try_help "#{class_name}##{method_name}"
  # We don't know how to create a real cls object.
  # We could try some hacks or mock objects later.

  if rv1 == expected
    im_fc << expected
  else
    im_fi << [expected, rv1]
  end
}

print <<EOS

Instance method documentation:
* #{docs_imeth.size} instance methods
* #{im_fc.size} correct
* #{im_fi.size} incorrect
* #{im_nc.size} could not be verified (seem ok)
* #{im_ni.size} could not be verified (seem bad)
EOS
if im_fi.size != 0
  puts "\nIncorrect:"
  im_fi.each{|ex,rv1|
    puts "* #{ex} - #{rv1}"
  }
end

print <<EOS

Summary:
* #{docs_class.size + docs_cmeth.size  + docs_imeth.size} documentation items
* #{cl_fc.size + cm_fc.size + im_fc.size} correct
* #{cl_fi.size + cm_fi.size + im_fi.size} incorrect
* #{cl_nc.size + cm_nc.size + im_nc.size} could not be verified (seem ok)
* #{cl_ni.size + cm_ni.size + im_ni.size} could not be verified (seem bad)
EOS
