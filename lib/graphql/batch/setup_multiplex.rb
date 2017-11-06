module GraphQL::Batch
  class SetupMultiplex
    def initialize(schema, executor_class:)
      @schema = schema
      @executor_class = executor_class
    end

    def before_multiplex(multiplex)
      Setup.start_batching(@executor_class)
    end

    def after_multiplex(multiplex)
      Setup.end_batching
    end

    def instrument(type, field)
      Setup.instrument_field(@schema, type, field)
    end
  end
end
