require_relative 'graphql_test'

has_lazy_resolve = nil
GraphQL::Schema.define do
  has_lazy_resolve = respond_to?(:lazy_resolve)
end

if has_lazy_resolve
  class GraphQL::LazyResolveTest < GraphQL::GraphQLTest
    LazyResolveSchema = GraphQL::Schema.define do
      query QueryType
      mutation MutationType
      lazy_resolve(Promise, :sync)
      instrument(:query, GraphQL::Batch::Setup)
    end

    def schema
      LazyResolveSchema
    end
  end
end
