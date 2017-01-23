module Magic
  module Help
    def self.resolve_help_block(&block)
      call_event = nil
      done = false
      res = nil

      trace = TracePoint.new do |ev|
        next if done
        case ev.event
        when :call
          call_event = {cls: ev.defined_class, meth: ev.method_id, self: ev.self}
          throw :done
        when :c_call
          if ev.self == ArgumentError and ev.method_id == :new
            # Function was called without full number of arguments
            # There doesn't seem to be any way to recover from this in ruby 2.x
            # In 1.8 we'd get extra return event
            call_event = {cls: ev.defined_class, meth: ev.method_id, self: ev.self}
            throw :done
          elsif ev.defined_class == BasicObject and ev.method_id == :method_missing
            call_event = {cls: ev.self, meth: "???", self: ev.self}
            throw :done
          else
            call_event = {cls: ev.defined_class, meth: ev.method_id, self: ev.self}
            throw :done
          end
        else
          # Ignore everything eles
        end
      end
      catch(:done) do
        trace.enable
        res = yield
      end
      done = true
      trace.disable

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
