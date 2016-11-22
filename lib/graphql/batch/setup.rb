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
