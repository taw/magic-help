#!/usr/bin/env ruby

require "minitest/autorun"
require_relative "../lib/magic_help"
require "fileutils"

class Test_Magic_Help < Minitest::Test
  def self.test_order
    :alpha
  end

  def assert_irb_help(expected, *args, &block)
    got = Magic::Help.resolve_help_query(*args, &block)
    if expected == nil
      assert_nil(got)
    else
      assert_equal(expected, got)
    end
  end

  def test_argument_number_mismatch
    # Correct number of arguments
    assert_irb_help("FileUtils::compare_file"){ FileUtils.compare_file 1, 2 }
    # Various incorrect argument counts
    assert_irb_help("FileUtils::compare_file"){ FileUtils.compare_file }
    assert_irb_help("FileUtils::compare_file"){ FileUtils.compare_file 1 }
    assert_irb_help("FileUtils::compare_file"){ FileUtils.compare_file 1, 2, 3 }
  end

  def test_argumenterror_new
    assert_irb_help("ArgumentError::new"){ ArgumentError.new }
  end

  def test_class
    assert_irb_help("Array"){ Array }
    assert_irb_help("Array"){ [] }
    x = [1, 2, 3]
    assert_irb_help("Array"){ x }
  end

  def test_method
    assert_irb_help("Array#sort"){ [].sort }
    x = [1, 2, 3]
    assert_irb_help("Array#sort"){ x.sort }
    im  = Array.instance_method(:sort)
    assert_irb_help("Array#sort"){ im }
    m = [].method(:sort)
    assert_irb_help("Array#sort"){ m }
    um = [].method(:sort).unbind
    assert_irb_help("Array#sort"){ um }
  end

  def test_class_method
    assert_irb_help("Dir#[]"){ Dir[""] }
    m  = Dir.method(:[])
    assert_irb_help("Dir::[]"){ m }
    um = Dir.method(:[]).unbind
    assert_irb_help("Dir::[]"){ um }
  end

  def test_module
    assert_irb_help("Enumerable", Enumerable)
    assert_irb_help("Enumerable"){ Enumerable }
    assert_irb_help("Enumerable", "Enumerable")
    um = Enumerable.instance_method(:map)
    assert_irb_help("Enumerable#map"){ um }
    um2 = Range.instance_method(:any?)
    assert_irb_help("Enumerable#any?"){ um2 }
    m = (0..1).method(:any?)
    assert_irb_help("Enumerable#any?"){ m }
  end

  def test_method_inherited
    f = File.open(__FILE__)
    assert_irb_help("IO#sync"){ f.sync }
    im = File.instance_method(:sync)
    assert_irb_help("IO#sync"){ im }
    m  = f.method(:sync)
    assert_irb_help("IO#sync"){ m }
    um = f.method(:sync).unbind
    assert_irb_help("IO#sync"){ um }
  end

  def test_string
    assert_irb_help("Array",    "Array" )
    assert_irb_help("Array#[]", "Array#[]")
    assert_irb_help("Dir::[]",  "Dir::[]" )
    assert_irb_help("Array#[]", "Array.[]")
    assert_irb_help("Dir::[]",  "Dir.[]" )
    assert_irb_help("IO#sync",  "File#sync" )
  end

  def test_string_bogus
    assert_irb_help("Xyzzy#foo",  "Xyzzy#foo")
    assert_irb_help("Xyzzy::foo", "Xyzzy::foo")
    assert_irb_help("Xyzzy.foo",  "Xyzzy.foo")

    assert_irb_help("Array#xyzzy",  "Array#xyzzy")
    assert_irb_help("Array::xyzzy", "Array::xyzzy")
    assert_irb_help("Array.xyzzy",  "Array.xyzzy")
  end

  def test_operators
    assert_irb_help("Fixnum#+"){ 2 + 2 }
    assert_irb_help("Float#+"){ 2.0 + 2.0 }
    assert_irb_help("Array#[]"){ [][] }
    # =~ is instance method of Kernel, but is documented as instance method of Object
    # assert_irb_help("Kernel#=~"){ [] =~ [] }
    assert_irb_help("Object#=~"){ [] =~ [] }
  end

  def test_nil
    assert_irb_help(nil)
    assert_irb_help("NilClass"){ nil }
    assert_irb_help("NilClass"){ }
  end

  def test_superclass
    # superclass is a method of Class
    # So Foo::superclass should find Class#superclass

    assert_irb_help("Class#superclass"){ Float.superclass }
    assert_irb_help("Class#superclass", "Float::superclass")
    assert_irb_help("Class#superclass", "Float.superclass")

    assert_irb_help("Class#superclass"){ Class.superclass }
    assert_irb_help("Class#superclass"){ "Class.superclass" }
    assert_irb_help("Class#superclass"){ "Class::superclass" }
  end

  def test_class_new
    # Most classes do not override Class#new, but have
    # Documentation for Foo.new anyway (it actually documents Foo#initialize)

    # First, handling of Class#new (default creator of instances)
    # and Class::new (creator of new classses)
    assert_irb_help("Class::new"){ Class.new }
    assert_irb_help("Class::new"){ Class::new }
    assert_irb_help("Class#new",  "Class#new")
    assert_irb_help("Class::new", "Class::new")
    assert_irb_help("Class#new",  "Class.new")

    # Module::new is documented and it uses default Class#new
    assert_irb_help("Module::new"){ Module.new }
    assert_irb_help("Module::new", "Module.new")
    assert_irb_help("Module::new", "Module::new")

    # IO::new is documented and it has separate implementation
    assert_irb_help("IO::new"){ IO.new }
    assert_irb_help("IO::new", "IO.new")
    assert_irb_help("IO::new", "IO::new")

    # File::new is documented and it uses IO::new
    assert_irb_help("File::new"){ File.new }
    assert_irb_help("File::new", "File.new")
    assert_irb_help("File::new", "File::new")
  end

  # This tests work-arounds for bugs in Ruby documentation !!!
  # In the perfect world it should totally fail !!!
  def test_object_methods
    # Documentation mixes some Kernel and Object methods

    # Ruby has Kernel#__id__ but documentation has Object#__id__
    assert_irb_help("BasicObject#__id__"){ __id__ }
    assert_irb_help("BasicObject#__id__"){ 42.__id__ }
    assert_irb_help("BasicObject#__id__", "Object#__id__")
    assert_irb_help("BasicObject#__id__", "Object.__id__")
    assert_irb_help("Kernel#__id__", "Kernel#__id__")
    assert_irb_help("BasicObject#__id__", "Kernel.__id__")

    # Ruby has Kernel#sprintf and documentation has Kernel#sprintf
    assert_irb_help("Kernel#sprintf"){ sprintf }
    assert_irb_help("Kernel#sprintf", "Object#sprintf")
    assert_irb_help("Kernel#sprintf", "Object.sprintf")
    assert_irb_help("Kernel#sprintf", "Kernel#sprintf")
    assert_irb_help("Kernel#sprintf", "Kernel.sprintf")

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
    assert_nil(m, "'time.rb' should not be included (it interferes with testing)")
    assert_irb_help("Time::rfc2822"){ Time::rfc2822 }
    # TODO: assert_irb_help("Time::rfc2822"){ Time.rfc2822 }
    assert_irb_help("Time::rfc2822", "Time::rfc2822")
    # TODO: assert_irb_help("Time::rfc2822", "Time.rfc2822")
    assert_irb_help("Time.rfc2822", "Time.rfc2822")
  end

  def test_method_missing_explicit
    assert_irb_help("Kernel#method_missing", "Kernel#method_missing")
    assert_irb_help("BasicObject#method_missing", "Kernel.method_missing")
    assert_irb_help("BasicObject#method_missing", "Float#method_missing")
    assert_irb_help("BasicObject#method_missing", "Float.method_missing")
    assert_irb_help("Kernel#method_missing"){ 42.method_missing }
    assert_irb_help("Kernel#method_missing"){ method_missing }
  end

  def test_longpath
    assert_irb_help("File::Stat::new", "File::Stat.new")
    assert_irb_help("File::Stat::new"){ File::Stat.new }
    assert_irb_help("File::Stat::new"){ File::Stat::new }
    fs = File::Stat.new(__FILE__)
    assert_irb_help("File::Stat#size"){ fs.size }
    assert_irb_help("File::Stat#size", "File::Stat#size")
    assert_irb_help("File::Stat#size", "File::Stat.size")
  end

  def test_private
    # help should ignore public/protected/private
    # private is a private function of Module
    assert_irb_help("Module#private", "Module#private")
    assert_irb_help("Module#private", "Module.private")
    assert_irb_help("Module#private", "Module::private")

    assert_irb_help("Module#private", "Class#private")
    assert_irb_help("Module#private", "Class.private")
    assert_irb_help("Module#private", "Class::private")

    assert_irb_help("Module#private", "Float.private")
    assert_irb_help("Module#private", "Float::private")

    assert_irb_help("Module#private"){ Module::private }
    assert_irb_help("Module#private"){ Module.private }

    assert_irb_help("Module#private"){ Class::private }
    assert_irb_help("Module#private"){ Class.private }

    assert_irb_help("Module#private"){ Float::private }
    assert_irb_help("Module#private"){ Float.private }

    assert_irb_help("BasicObject#singleton_method_added"){ "".singleton_method_added }
    assert_irb_help("BasicObject#singleton_method_added"){ singleton_method_added }
  end
end
