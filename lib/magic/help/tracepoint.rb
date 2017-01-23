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
          if ev.defined_class == ArgumentError and meth == :new
            # This generally happens instead of c_call when calling function
            # with wrong number of arguments

          else
            call_event = {cls: ev.defined_class, meth: ev.method_id, self: ev.self}
          end
          throw :done
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
        if cls.singleton_class? or meth == :new
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
