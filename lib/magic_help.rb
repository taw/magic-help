#!/usr/bin/env ruby

require 'irb'
require 'irb/extend-command'

# Now let's hack irb not to alias irb_help -> help
# It saves us a silly warning at startup:
#     irb: warn: can't alias help from irb_help.
module IRB::ExtendCommandBundle # :nodoc:
    @ALIASES.delete_if{|a| a == [:help, :irb_help, NO_OVERRIDE]}
end

# help_hacks is used to postprocess queries in two cases:
# * help "Foo.bar" queries - res defined, more hacks
# * help { Foo.bar } queries - res not defined, fewer hacks
def help_hacks(m, res=nil)
    # Kernel#method_missing here means class was found but method wasn't
    # It is possible that such method exists, it was simply not included.
    # Example - Time::rfc2822 from time.rb.
    #
    # Do not correct it if actual method_missing was called.
    if res and m == "Kernel#method_missing"
        m = res unless res =~ /\A(?:.*)(?:\#|::|\.)method_missing\Z/
    # Most classes do not override Foo::new, but provide new documentation anyway !
    # Two cases are possible
    # * Class#new is used
    # * Bar::new is used, for Bar being some ancestor of Foo
    elsif res and (m =~ /\A(.*)\#new\Z/ or m =~ /\A(.*)::new\Z/)
        cls = $1
        # Do not correct requests for Foo#new
        # If Foo#new became Class#new, it must have been
        # by some evil metaclass hackery.
        #
        # Foo.new or Foo::new both become Foo::new
        if res =~ /\A(.*)(::|\.)new\Z/
            cls_requested, k = $1, $2
            # Condition just to get "Class#new" working correctly
            # Otherwise it would be changed to "Class::new"
            m = "#{cls_requested}::new" unless cls == cls_requested
        end
    end
    
    # Most Kernel methods are documented as if they were Object methods.
    # * private are in Kernel (except for four below)
    # * public are in Object (all of them)
    if m =~ /\AKernel(\#|::|\.)([^\#\:\.]+)\Z/
        k, mn = $1, $2
        exceptions = ["singleton_method_added", "remove_instance_variable", "singleton_method_removed", "singleton_method_undefined"]
        correctly_located_docs = Kernel.private_instance_methods - exceptions
        unless correctly_located_docs.include?(mn)
            m = "Object#{k}#{mn}"
        end
    end
            
    m
end

# help is a Do-What-I-Mean help function.
# It can be called with either a block or a single argument.
# When called with single argument, it behaves like normal
# help function, except for being much smarter:
#
#  help "Array"         - help on Array
#  help "Array#sort"    - help on Array#sort
#  help "File#sync="    - help on IO#sync=
#
#  help { [].sort }     - help on Array#sort
#  help { obj.foo = 1 } - help on obj.foo=
#  help { Array }       - help on Array
#  help { [] }          - help on Array
#  help { Dir["*"] }    - help on Dir::[]
def magic_help(*args)
    raise ArgumentError, "wrong number of arguments (#{args.size} for 1)" if args.size > 1
    raise ArgumentError, "help cannot take both arguments and block" if args.size > 0 and block_given?

    if block_given?
        call_event = nil
        res = nil
        done = false
        res_mm = nil
        argument_error = false
        
        # We want to capture calls to method_missing too
        original_method_missing = Kernel.instance_method(:method_missing)
        Kernel.class_eval {
            def method_missing(*args)
                throw :magically_irb_helped, [self, *args]
            end
        }

        tf = lambda{|*args|
            return if done
            event = args[0]
            if argument_error
                if event == 'return'
                    done = true
                    # For functions called with wrong number of arguments,
                    # call event is not generated (function is never called),
                    # but the return event is !
                    call_event = args
                    throw :magically_irb_helped
                end
            elsif event == 'call' or event == 'c-call'
                call_event = args
                if call_event.values_at(0, 3, 5) == ['c-call', :new, Class] and
                   eval("self", call_event[4]) == ArgumentError
                    argument_error = true
                else
                    done = true
                    # Let Kernel#method_missing run, otherwise throw
                    unless call_event.values_at(0, 3, 5) == ['call', :method_missing, Kernel]
                        throw :magically_irb_helped
                    end
                end
            end
        }
        res_mm = catch(:magically_irb_helped) {
            set_trace_func tf
            res = yield()
            done = true
            nil
        }
        done = true
        set_trace_func nil
        Kernel.instance_eval {
            define_method(:method_missing, original_method_missing)
            # It was originally private, restore it as such
            private :method_missing
        }
        # Handle captured method_missing

        if res_mm
            # This is explicit Foo#method_missing:
            # It shouldn't really be allowed as it's private.
            if res_mm.size == 1
                query = "Kernel#method_missing"
                irb_help query
                return
            else
                bound_self, meth = *res_mm
                # method_missing is called if:
                # * there was no such method
                # * there was a method, but a private one only
                begin
                    # Surprise ! A private method !
                    m = bound_self.method(meth)
                    query = help_method_extract(m)
                rescue NameError
                    # No such method
                    if bound_self.is_a? Class
                        query = "#{bound_self}::#{meth}"
                    else
                        query = "#{bound_self.class}.#{meth}"
                    end
                end
            end
            query = help_hacks(query)
            irb_help query
            return
        # Handle normal call events
        elsif call_event
            meth, bind, cls = call_event[3], call_event[4], call_event[5]
            bound_self = eval('self', bind)
            if meth == :new
                #puts "Warning: Class.new called: #{call_event.inspect}"
                #puts "self is #{bound_self}"
                cls = bound_self
            end

            # Foo::bar and Foo#bar look the same
            # Check whether self == Foo to tell them apart
            #
            # Only Class::new is documented as such,
            # all other Class::foo are really Class#foo
            if bound_self == cls && (bound_self != Class || meth == :new)
                query = "#{cls}::#{meth}"
            else
                query = "#{cls}##{meth}"
            end
            query = help_hacks(query)
            irb_help query
            return
        end
    elsif !args.empty?
        res = args[0]
    else
        # No block, no arguments
        return
    end

    query = case res
    when Module
        res.to_s
    when UnboundMethod, Method
        help_method_extract(res)
    when /\A(.*)(#|::|\.)(.*)\Z/
        cp, k, m = $1, $2, $3
        #puts "help for string : <#{cp}> <#{k}> <#{m}>"
        begin
            # For multielement paths like File::Stat const_get must be
            # called multiple times, that is:
            # Object.const_get("File").const_get("Stat")
            c = cp.split(/::/).inject(Object){|c, path_elem| c.const_get(path_elem) }
            #puts "Const is: <#{c.inspect}>"
            case k
            when "#"
                m = c.instance_method(m)
                m = help_method_extract(m)
            when "::"
                m = c.method(m)
                # Make sure a module method is returned
                # It fixes `Class::new' resolving to `Class#new'
                # (Class::new and Class#new are the same thing,
                # but their documentations are different)
                m = help_method_extract(m)
                m = m.sub(/\#/, "::") if c == Class && m == "Class#new"
            when "."
                begin
                    m = c.instance_method(m)
                rescue NameError
                    m = c.method(m)
                end
                m = help_method_extract(m)
            end
            help_hacks(m, res)
        rescue NameError
            res
        end
    when String
        res
    else
        res.class.to_s
    end
    irb_help query
end

def help_method_extract(m) # :nodoc:
    unless m.inspect =~ %r[\A#<(?:Unbound)?Method: (.*?)>\Z]
        raise "Cannot parse result of #{m.class}#inspect: #{m.inspect}"
    end
    $1.sub(/\A.*?\((.*?)\)(.*)\Z/){ "#{$1}#{$2}" }.sub(/\./, "::").sub(/#<Class:(.*?)>#/) { "#{$1}::" }
end
