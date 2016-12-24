#!/usr/bin/env ruby

require "minitest/autorun"
require "magic_help"
require "fileutils"

$irb_help = nil

# Use fake irb_help for testing
class Object
  def irb_help(arg)
    $irb_help = arg
  end
end

class Test_Magic_Help < Minitest::Test
  def assert_irb_help(expected)
    $irb_help = nil
    yield
    got = $irb_help
    $irb_help = nil
    assert_equal(expected, got)
  end

  def test_argument_number_mismatch
    # Correct number of arguments
    assert_irb_help("FileUtils::compare_file") { help { FileUtils.compare_file 1, 2 } }
    # Various incorrect argument counts
    assert_irb_help("FileUtils::compare_file") { help { FileUtils.compare_file } }
    assert_irb_help("FileUtils::compare_file") { help { FileUtils.compare_file 1 } }
    assert_irb_help("FileUtils::compare_file") { help { FileUtils.compare_file 1, 2, 3 } }
  end

  def test_argumenterror_new
    assert_irb_help("ArgumentError::new") { help { ArgumentError.new } }
  end

  def test_class
    assert_irb_help("Array") { help { Array } }
    assert_irb_help("Array") { help { [] } }
    x = [1, 2, 3]
    assert_irb_help("Array") { help { x } }
  end

  def test_method
    assert_irb_help("Array#sort") { help { [].sort } }
    x = [1, 2, 3]
    assert_irb_help("Array#sort") { help { x.sort } }
    im  = Array.instance_method(:sort)
    assert_irb_help("Array#sort") { help { im } }
    m = [].method(:sort)
    assert_irb_help("Array#sort") { help { m } }
    um = [].method(:sort).unbind
    assert_irb_help("Array#sort") { help { um } }
  end

  def test_class_method
    assert_irb_help("Dir::[]") { help { Dir[""] } }
    m  = Dir.method(:[])
    assert_irb_help("Dir::[]") { help { m } }
    um = Dir.method(:[]).unbind
    assert_irb_help("Dir::[]") { help { um } }
  end

  def test_module
    assert_irb_help("Enumerable") { help Enumerable }
    assert_irb_help("Enumerable") { help { Enumerable } }
    assert_irb_help("Enumerable") { help "Enumerable" }
    um = Enumerable.instance_method(:map)
    assert_irb_help("Enumerable#map") { help { um } }
    um2 = Array.instance_method(:any?)
    assert_irb_help("Enumerable#any?") { help { um2 } }
    m = [].method(:any?)
    assert_irb_help("Enumerable#any?") { help { m } }
  end

  def test_method_inherited
    f = File.open(__FILE__)
    assert_irb_help("IO#sync") { help { f.sync } }
    im = File.instance_method(:sync)
    assert_irb_help("IO#sync") { help { im } }
    m  = f.method(:sync)
    assert_irb_help("IO#sync") { help { m } }
    um = f.method(:sync).unbind
    assert_irb_help("IO#sync") { help { um } }
  end

  def test_string
    assert_irb_help("Array")    { help "Array" }
    assert_irb_help("Array#[]") { help "Array#[]" }
    assert_irb_help("Dir::[]")  { help "Dir::[]" }
    assert_irb_help("Array#[]") { help "Array.[]" }
    assert_irb_help("Dir::[]")  { help "Dir.[]" }
    assert_irb_help("IO#sync")  { help "File#sync" }
  end

  def test_string_bogus
    assert_irb_help("Xyzzy#foo")  { help "Xyzzy#foo" }
    assert_irb_help("Xyzzy::foo") { help "Xyzzy::foo" }
    assert_irb_help("Xyzzy.foo")  { help "Xyzzy.foo" }

    assert_irb_help("Array#xyzzy")  { help "Array#xyzzy" }
    assert_irb_help("Array::xyzzy") { help "Array::xyzzy" }
    assert_irb_help("Array.xyzzy")  { help "Array.xyzzy" }
  end

  def test_operators
    assert_irb_help("Fixnum#+")  { help { 2 + 2 } }
    assert_irb_help("Float#+")   { help { 2.0 + 2.0 } }
    assert_irb_help("Array#[]")  { help { [][] } }
    # =~ is instance method of Kernel, but is documented as instance method of Object
    # assert_irb_help("Kernel#=~") { help { [] =~ [] } }
    assert_irb_help("Object#=~") { help { [] =~ [] } }
  end

  def test_nil
    assert_irb_help(nil)         { help }
    assert_irb_help("NilClass")  { help { nil } }
    assert_irb_help("NilClass")  { help { } }
  end

  def test_superclass
    # superclass is a method of Class
    # So Foo::superclass should find Class#superclass

    assert_irb_help("Class#superclass") { help { Float.superclass } }
    assert_irb_help("Class#superclass") { help "Float::superclass" }
    assert_irb_help("Class#superclass") { help "Float.superclass" }

    assert_irb_help("Class#superclass") { help { Class.superclass } }
    assert_irb_help("Class#superclass") { help { "Class.superclass" } }
    assert_irb_help("Class#superclass") { help { "Class::superclass" } }
  end

  def test_class_new
    # Most classes do not override Class#new, but have
    # Documentation for Foo.new anyway (it actually documents Foo#initialize)

    # First, handling of Class#new (default creator of instances)
    # and Class::new (creator of new classses)
    assert_irb_help("Class::new") { help { Class.new } }
    assert_irb_help("Class::new") { help { Class::new } }
    assert_irb_help("Class#new")  { help "Class#new" }
    assert_irb_help("Class::new") { help "Class::new" }
    assert_irb_help("Class#new")  { help "Class.new" }

    # Module::new is documented and it uses default Class#new
    assert_irb_help("Module::new") { help { Module.new } }
    assert_irb_help("Module::new") { help "Module.new" }
    assert_irb_help("Module::new") { help "Module::new" }

    # IO::new is documented and it has separate implementation
    assert_irb_help("IO::new") { help { IO.new } }
    assert_irb_help("IO::new") { help "IO.new" }
    assert_irb_help("IO::new") { help "IO::new" }

    # File::new is documented and it uses IO::new
    assert_irb_help("File::new") { help { File.new } }
    assert_irb_help("File::new") { help "File.new" }
    assert_irb_help("File::new") { help "File::new" }
  end

  # This tests work-arounds for bugs in Ruby documentation !!!
  # In the perfect world it should totally fail !!!
  def test_object_methods
    # Documentation mixes some Kernel and Object methods

    # Ruby has Kernel#__id__ but documentation has Object#__id__
    assert_irb_help("Object#__id__") { help { __id__ } }
    assert_irb_help("Object#__id__") { help { 42.__id__ } }
    assert_irb_help("Object#__id__") { help "Object#__id__" }
    assert_irb_help("Object#__id__") { help "Object.__id__" }
    assert_irb_help("Object#__id__") { help "Kernel#__id__" }
    assert_irb_help("Object#__id__") { help "Kernel.__id__" }

    # Ruby has Kernel#sprintf and documentation has Kernel#sprintf
    assert_irb_help("Kernel#sprintf") { help { sprintf } }
    assert_irb_help("Kernel#sprintf") { help "Object#sprintf" }
    assert_irb_help("Kernel#sprintf") { help "Object.sprintf" }
    assert_irb_help("Kernel#sprintf") { help "Kernel#sprintf" }
    assert_irb_help("Kernel#sprintf") { help "Kernel.sprintf" }

    # TODO: For completion - Object method documented in Object
    # TODO: For completion - Object method documented in Kernel
    # TODO: For completion - class methods of both
  end

  def test_method_missing
    # We don't want to document Kernel#method_missing

    # Time::rfc2822 is defined in time.rb, which is not included.
    m = begin
      Time.method(:rfc2822)
    rescue NameError
      nil
    end
    assert_equal(nil, m, "'time.rb' should not be included (it interferes with testing)")
    assert_irb_help("Time::rfc2822") { help { Time::rfc2822 } }
    # TODO: assert_irb_help("Time::rfc2822") { help { Time.rfc2822 } }
    assert_irb_help("Time::rfc2822") { help "Time::rfc2822" }
    # TODO: assert_irb_help("Time::rfc2822") { help "Time.rfc2822" }
    assert_irb_help("Time.rfc2822") { help "Time.rfc2822" }
  end

  def test_method_missing_explicit
    assert_irb_help("Kernel#method_missing") { help "Kernel#method_missing" }
    assert_irb_help("Kernel#method_missing") { help "Kernel.method_missing" }
    assert_irb_help("Kernel#method_missing") { help "Float#method_missing" }
    assert_irb_help("Kernel#method_missing") { help "Float.method_missing" }
    assert_irb_help("Kernel#method_missing") { help { 42.method_missing } }
    assert_irb_help("Kernel#method_missing") { help { method_missing } }
  end

  def test_longpath
    assert_irb_help("File::Stat::new") { help "File::Stat.new" }
    assert_irb_help("File::Stat::new") { help { File::Stat.new } }
    assert_irb_help("File::Stat::new") { help { File::Stat::new } }
    fs = File::Stat.new(__FILE__)
    assert_irb_help("File::Stat#size") { help { fs.size } }
    assert_irb_help("File::Stat#size") { help "File::Stat#size" }
    assert_irb_help("File::Stat#size") { help "File::Stat.size" }
  end

  def test_private
    # help should ignore public/protected/private
    # private is a private function of Module
    assert_irb_help("Module#private") { help "Module#private" }
    assert_irb_help("Module#private") { help "Module.private" }
    assert_irb_help("Module#private") { help "Module::private" }

    assert_irb_help("Module#private") { help "Class#private" }
    assert_irb_help("Module#private") { help "Class.private" }
    assert_irb_help("Module#private") { help "Class::private" }

    assert_irb_help("Module#private") { help "Float.private" }
    assert_irb_help("Module#private") { help "Float::private" }

    assert_irb_help("Module#private") { help { Module::private } }
    assert_irb_help("Module#private") { help { Module.private } }

    assert_irb_help("Module#private") { help { Class::private } }
    assert_irb_help("Module#private") { help { Class.private } }

    assert_irb_help("Module#private") { help { Float::private } }
    assert_irb_help("Module#private") { help { Float.private } }

    assert_irb_help("Object#singleton_method_added") { help { "".singleton_method_added } }
    assert_irb_help("Object#singleton_method_added") { help { singleton_method_added } }
  end
end
