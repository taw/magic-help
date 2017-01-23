module Magic
  module Help
    def self.resolve_help_block(&block)
      call_event = nil
      done = false

      trace = TracePoint.new do |ev|
        next if done
        case ev.event
        when :call
          call_event = {cls: ev.defined_class, meth: ev.method_id, self: ev.self}
          done = true
        when :c_call
          call_event = {cls: ev.defined_class, meth: ev.method_id, self: ev.self}
          done = true
        else
          # Ignore everything eles
        end
      end
      trace.enable
      res = yield
      done = true
      trace.disable

      if call_event
        cls = call_event[:cls]
        meth = call_event[:meth]
        bound_self = call_event[:self]
        if cls.singleton_class?
          query = "#{self}::#{meth}"
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
