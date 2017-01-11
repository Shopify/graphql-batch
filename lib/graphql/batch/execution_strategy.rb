warn "GraphQL::Batch::ExecutionStrategy is deprecated, instead use `lazy_resolve(Promise, :sync)` and `instrument(:query, GraphQL::Batch::Setup)` in GraphQL::Schema.define"

module GraphQL::Batch
  class ExecutionStrategy < GraphQL::Query::SerialExecution
    def execute(_, _, query)
      GraphQL::Batch.batch do
        as_promise_unless_resolved(super)
      end
    rescue GraphQL::InvalidNullError => err
      err.parent_error? || query.context.errors.push(err)
      nil
    end

    # Needed for MutationExecutionStrategy
    def deep_sync(result) #:nodoc:
      Promise.sync(as_promise_unless_resolved(result))
    end

    private

    def as_promise_unless_resolved(result)
      all_promises = []
      each_promise(result) do |obj, key, promise|
        obj[key] = nil
        all_promises << promise.then do |value|
          obj[key] = value
          as_promise_unless_resolved(value)
        end
      end
      return result if all_promises.empty?
      ::Promise.all(all_promises).then { result }
    end

    def each_promise(obj, &block)
      case obj
      when Array
        obj.each_with_index do |value, idx|
          each_promise_in_entry(obj, idx, value, &block)
        end
      when Hash
        obj.each do |key, value|
          each_promise_in_entry(obj, key, value, &block)
        end
      end
    end

    def each_promise_in_entry(obj, key, value, &block)
      if value.is_a?(::Promise)
        yield obj, key, value
      else
        each_promise(value, &block)
      end
    end

    class FieldResolution < GraphQL::Query::SerialExecution::FieldResolution
      def get_finished_value(raw_value)
        if raw_value.is_a?(::Promise)
          raw_value.then(->(result) { super(result) }, lambda do |error|
            error.is_a?(GraphQL::ExecutionError) ? super(error) : raise(error)
          end)
        else
          super
        end
      end
    end
  end
end
