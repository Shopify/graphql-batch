require_relative 'graphql_test'

class GraphQL::ExecutionStrategyTest < GraphQL::GraphQLTest
  LegacySchema = GraphQL::Schema.define do
    query QueryType
    mutation MutationType

    query_execution_strategy GraphQL::Batch::ExecutionStrategy
    mutation_execution_strategy GraphQL::Batch::MutationExecutionStrategy
  end

  def schema
    LegacySchema
  end
end
