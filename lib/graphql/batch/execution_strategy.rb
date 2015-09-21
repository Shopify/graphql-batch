module GraphQL::Batch
  class ExecutionStrategy < GraphQL::Query::SerialExecution
    attr_reader :batched_queries

    def initialize
      @batched_queries = Hash.new{ |hash, key| hash[key] = [] }
    end

    class OperationResolution < GraphQL::Query::SerialExecution::OperationResolution
      def result
        result = super
        until execution_strategy.batched_queries.empty?
          queries = execution_strategy.batched_queries.shift.last
          queries.first.class.execute(queries)
        end
        result
      end
    end

    class SelectionResolution < GraphQL::Query::SerialExecution::SelectionResolution
      def result
        result_hash = super
        result_hash.each do |key, value|
          if value.is_a?(FieldResolution)
            value.result_hash = result_hash
          end
        end
        result_hash
      end
    end

    class FieldResolution < GraphQL::Query::SerialExecution::FieldResolution
      attr_accessor :result_hash

      def get_finished_value(raw_value)
        if raw_value.is_a?(QueryContainer)
          raw_value.query_listener = self
          raw_value.each_query do |query|
            execution_strategy.batched_queries[query.group_key] << query
          end
          self
        else
          super
        end
      end

      def query_completed(query)
        result_key = ast_node.alias || ast_node.name
        @result_hash[result_key] = get_finished_value(query.result)
      end
    end
  end
end
