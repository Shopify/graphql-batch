module GraphQL::Batch
  module Setup
    extend self

    def before_query(query)
      raise NestedError if GraphQL::Batch::Executor.current
      GraphQL::Batch::Executor.current = GraphQL::Batch::Executor.new
    end

    def after_query(query)
      GraphQL::Batch::Executor.current = nil
    end
  end
end

GraphQL::Schema.accepts_definitions(
  use_graphql_batch: ->(schema) {
    return if schema.metadata[:graphql_batch_setup]
    schema.instrument(:query, GraphQL::Batch::Setup)
    schema.lazy_methods.set(Promise, :sync)
    schema.metadata[:graphql_batch_setup] = true
  }
)
