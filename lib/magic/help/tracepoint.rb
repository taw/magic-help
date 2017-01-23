module Magic
  module Help
    def self.resolve_help_block(&block)
      call_event = nil
      done = false
      res = nil

      # We want to capture calls to method_missing too
      # This should be available via TracePoint but isn't
      original_method_missing = BasicObject.instance_method(:method_missing)
      BasicObject.class_eval do
        define_method(:method_missing) do |*args|
          if args.empty?
            # This is presumably called on self, and without arguments
            throw :done, {cls: method(:method_missing).owner, meth: :method_missing, self: self}
          end

          if self.is_a?(Class)
            throw :done, {cls: self.singleton_class, meth: args[0], self: self}
          else
            throw :done, {cls: self.class, meth: args[0], self: self}
          end
        end
      end

      trace = TracePoint.new do |ev|
        next if done
        case ev.event
        when :call, :c_call
          if ev.defined_class == BasicObject and ev.method_id == :method_missing
            done = true
            # Let it reach our special handler
          # elsif ev.self == ArgumentError and ev.method_id == :new
            # Function was called without full number of arguments
            # There doesn't seem to be any way to recover from this in ruby 2.x
            # In 1.8 we'd get extra return event
            #
            # It's possible to hack argument name from stack trace,
            # (with massive hacking)
            # but not self/class, so it's not most useful
          else
            done = true
            throw :done, {cls: ev.defined_class, meth: ev.method_id, self: ev.self}
          end
        else
          # Ignore everything eles
        end
      end
      call_event = catch(:done) do
        trace.enable
        res = yield
        nil
      end
      done = true
      trace.disable

      BasicObject.instance_eval do
        define_method(:method_missing, original_method_missing)
        # It was originally private, restore it as such
        private :method_missing
      end

      if call_event
        cls = call_event[:cls]
        meth = call_event[:meth]
        bound_self = call_event[:self]
        is_singleton = (cls.is_a?(Class) and cls.singleton_class?)
        if is_singleton or meth == :new
          query = "#{bound_self}::#{meth}"
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
