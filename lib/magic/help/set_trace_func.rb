# This is 1.8 API, it's still there in 2.0 but they broke it a bit

module Magic
  module Help
    def self.resolve_help_block(&block)
      call_event = nil
      res = nil
      done = false
      res_mm = nil
      argument_error = false

      # We want to capture calls to method_missing too
      original_method_missing = BasicObject.instance_method(:method_missing)
      BasicObject.class_eval {
        def method_missing(*args)
          throw :magically_irb_helped, [self, *args]
        end
      }

      tf = lambda{|*xargs|
        return if done
        event = xargs[0]
        if argument_error
          if event == "return"
            done = true
            # For functions called with wrong number of arguments,
            # call event is not generated (function is never called),
            # but the return event is !
            call_event = xargs
            throw :magically_irb_helped
          end
        elsif event == "call" or event == "c-call"
          call_event = xargs
          if call_event.values_at(0, 3, 5) == ["c-call", :new, Class] and
            eval("self", call_event[4]) == ArgumentError
            argument_error = true
          else
            done = true
            # Let Kernel#method_missing run, otherwise throw
            unless call_event.values_at(0, 3, 5) == ["call", :method_missing, BasicObject]
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
      BasicObject.instance_eval {
        define_method(:method_missing, original_method_missing)
        # It was originally private, restore it as such
        private :method_missing
      }
      # Handle captured method_missing

      if res_mm
        # This is explicit Foo#method_missing:
        # It shouldn't really be allowed as it's private.
        if res_mm.size == 1
          return "Kernel#method_missing"
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
        postprocess(query)
      # Handle normal call events
      elsif call_event
        meth, bind, cls = call_event[3], call_event[4], call_event[5]
        bound_self = bind.receiver
        if meth == :new
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
        postprocess(query)
      else
        resolve_help_res(res)
      end
    end
  end
end
