module GraphQL::Batch
  class ExecutionStrategy < GraphQL::Query::SerialExecution
    class OperationResolution < GraphQL::Query::SerialExecution::OperationResolution
      def result
        GraphQL::Batch.execute(super)
      end
    end

    class SelectionResolution < GraphQL::Query::SerialExecution::SelectionResolution
      def result
        wrap_queries(super)
      end

      private

      def wrap_queries(obj)
        queries = nil
        case obj
        when Array
          array = obj
          array.each_with_index do |value, i|
            value = wrap_queries(value)
            if value.is_a?(QueryContainer)
              array[i] = nil
              queries ||= []
              queries << value.then do |result|
                array[i] = result
              end
            end
          end
        when Hash
          hash = obj
          hash.each do |key, value|
            value = wrap_queries(value)
            if value.is_a?(QueryContainer)
              hash[key] = nil
              queries ||= []
              queries << value.then do |result|
                hash[key] = result
              end
            end
          end
        end
        queries ? QueryGroup.new(queries).then { obj } : obj
      end
    end

    class FieldResolution < GraphQL::Query::SerialExecution::FieldResolution
      def get_finished_value(raw_value)
        if raw_value.is_a?(QueryContainer)
          raw_value.then do |result|
            super(result)
          end.rescue(GraphQL::ExecutionError) do |err|
            super(err)
          end
        else
          super
        end
      end
    end
  end
end
