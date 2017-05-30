require_relative 'graphql_test'

class GraphQL::ExecutionStrategyTest < GraphQL::GraphQLTest
  LegacySchema = GraphQL::Schema.define do
    query QueryType
    mutation MutationType

    query_execution_strategy GraphQL::Batch::ExecutionStrategy
    mutation_execution_strategy GraphQL::Batch::MutationExecutionStrategy
  end

  class ExecutorWithSilencedWarn < GraphQL::Query::Executor
    def warn(message)
    end
  end

  def schema_execute(query_string, **kwargs)
    query = GraphQL::Query.new(LegacySchema, query_string, **kwargs)
    ExecutorWithSilencedWarn.new(query).result
  end
end
