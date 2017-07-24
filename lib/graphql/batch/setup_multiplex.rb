module GraphQL::Batch
  module SetupMultiplex
    extend self

    def before_multiplex(multiplex)
      raise NestedError if GraphQL::Batch::Executor.current
      GraphQL::Batch::Executor.current = GraphQL::Batch::Executor.new
    end

    def after_multiplex(multiplex)
      GraphQL::Batch::Executor.current = nil
    end
  end
end
