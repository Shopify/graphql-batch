module GraphQL::Batch
  class ExecutionStrategy < GraphQL::Query::SerialExecution
    class OperationResolution < GraphQL::Query::SerialExecution::OperationResolution
      def result
        GraphQL::Batch::Promise.resolve(super).sync
      ensure
        GraphQL::Batch::Executor.current.clear
      end
    end

    class SelectionResolution < GraphQL::Query::SerialExecution::SelectionResolution
      def result
        as_promise_unless_resolved(super)
      end

      private

      def as_promise_unless_resolved(result)
        all_promises = []
        each_promise(result) do |obj, key, promise|
          obj[key] = nil
          all_promises << promise.then { |value| obj[key] = value }
        end
        return result if all_promises.empty?
        Promise.all(all_promises).then { result }
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
    end

    class FieldResolution < GraphQL::Query::SerialExecution::FieldResolution
      def get_finished_value(raw_value)
        if raw_value.is_a?(::Promise)
          raw_value.then { |result| super(result) }
        else
          super
        end
      end
    end
  end
end
