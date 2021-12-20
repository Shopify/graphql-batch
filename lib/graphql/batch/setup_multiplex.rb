module GraphQL::Batch
  class SetupMultiplex
    def initialize(schema, executor_class:)
      @schema = schema
      @executor_class = executor_class
    end

    def before_multiplex(multiplex)
      GraphQL::Batch::Executor.start_batch(@executor_class)
    end

    def after_multiplex(multiplex)
      GraphQL::Batch::Executor.end_batch
    end
  end
end
