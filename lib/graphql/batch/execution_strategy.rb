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
          if value.is_a?(Resolver)
            value.result_hash = result_hash
          end
        end
        result_hash
      end
    end

    class FieldResolution < GraphQL::Query::SerialExecution::FieldResolution
      def get_finished_value(raw_value)
        if raw_value.is_a?(Query)
          raw_value = GraphQL::Batch::QueryResolver.new(raw_value)
        end
        if raw_value.is_a?(Resolver)
          resolver = raw_value
          resolver.field_resolution = self
          resolver.each_query do |query|
            execution_strategy.batched_queries[query.group_key] << query
          end
          resolver
        else
          super
        end
      end
    end
  end
end
