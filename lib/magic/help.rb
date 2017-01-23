require_relative "help/irb"
require_relative "help/tracepoint"

module Magic
  module Help
    def self.help_method_extract(m)
      unless m.inspect =~ %r[\A#<(?:Unbound)?Method: (.*?)>\Z]
        raise "Cannot parse result of #{m.class}#inspect: #{m.inspect}"
      end
      $1.sub(/\A.*?\((.*?)\)(.*)\Z/){ "#{$1}#{$2}" }.sub(/\./, "::").sub(/#<Class:(.*?)>#/) { "#{$1}::" }
    end

    # Magic::Help.postprocess is used to postprocess queries in two cases:
    # * help "Foo.bar" queries - res defined, more hacks
    # * help { Foo.bar } queries - res not defined, fewer hacks
    def self.postprocess(m, res=nil)
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

      m
    end

    def self.resolve_help_res(res)
      query = case res
      when Module
        res.to_s
      when UnboundMethod, Method
        help_method_extract(res)
      when /\A(.*)(#|::|\.)(.*)\Z/
        cp, k, m = $1, $2, $3
        begin
          # For multielement paths like File::Stat const_get must be
          # called multiple times, that is:
          # Object.const_get("File").const_get("Stat")
          cls = cp.split(/::/).inject(Object){|c, path_elem| c.const_get(path_elem) }
          case k
          when "#"
            m = cls.instance_method(m)
            m = help_method_extract(m)
          when "::"
            m = cls.method(m)
            # Make sure a module method is returned
            # It fixes `Class::new' resolving to `Class#new'
            # (Class::new and Class#new are the same thing,
            # but their documentations are different)
            m = help_method_extract(m)
            m = m.sub(/\#/, "::") if cls == Class && m == "Class#new"
          when "."
            begin
              m = cls.instance_method(m)
            rescue NameError
              m = cls.method(m)
            end
            m = help_method_extract(m)
          end
          postprocess(m, res)
        rescue NameError
          res
        end
      when String
        res
      else
        res.class.to_s
      end
      query
    end

    def self.resolve_help_query(*args, &block)
      raise ArgumentError, "wrong number of arguments (#{args.size} for 1)" if args.size > 1
      raise ArgumentError, "help cannot take both arguments and block" if args.size > 0 and block_given?
      if block_given?
        resolve_help_block(&block)
      elsif args.empty?
        # No block, no arguments
        nil
      else
        resolve_help_res(args[0])
      end
    end
  end
end
